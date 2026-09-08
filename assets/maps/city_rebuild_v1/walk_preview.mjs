// An isolated inspection scene. No game socket, persistence, NPC simulation or main mutation.
import * as THREE from 'three';
import {ensureVehicleExitVisible} from './vehicle_exit_camera.mjs';
import {createArtist14Input} from './hero_artist14_input.mjs';
import {createArtist14Surface} from './hero_artist14_surface.mjs';
import {createArtist14Pose} from './hero_artist14_pose.mjs';
import {createCrashPartner} from './crash_partner.mjs';
import {createBlastResponse} from './blast_response.mjs';
import {stepBlastKnockback} from './vehicle_blast_motion.mjs';
import {createVehicleRollover} from './vehicle_rollover.mjs';
import {installFastWalkStartup} from './point_light_loop.mjs';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {RoomEnvironment} from 'three/addons/environments/RoomEnvironment.js';
import {RoundedBoxGeometry} from 'three/addons/geometries/RoundedBoxGeometry.js';
import {createDemoCar,carFits,stepCar,createCarWorld,carCorners,pointInPolygon,carOverlapsCircle,DRIVER_SEAT} from './car_drive.mjs';
import {advanceEntryHold,entryPose,TRANSITION_SECONDS,HOLD_SECONDS,EXIT_HOLD_SECONDS} from './car_entry.mjs';
import {createTireTracks} from './tire_tracks.mjs';
import {applyBuildingDoorsGlass} from './building_doors_glass.mjs';
import {resolveBuildingCameraPosition} from './building_entry.mjs';
import {EXIT,planMovingExit,departurePoint,launchExitBody,stepExitBody} from './car_exit.mjs';
import {loadHeroWalker} from './hero_walk.mjs';
import {createHeroPosture,requestHeroPosture,resetHeroPosture,stepHeroPosture,posturePresentation} from './hero_posture.mjs';
import {JUMP,jumpDirection,launchJump,stepJump,tryDiveJump} from './hero_jump.mjs';
import {ARSENAL,createWeaponModel} from './hero_arsenal.mjs';
import {createWeaponHud} from './weapon_hud.mjs';
import {createWeaponQuickKey} from './weapon_quick_key.mjs';
import {createWeaponFireState,stepWeaponFire,sampleWeaponRecoil,weaponFireProfile} from './hero_weapon_fire.mjs';
import {createWeaponEffects,resolveWeaponShotTransforms} from './weapon_effects.mjs';
import {initCarPhysicsQa} from './car_physics_qa.mjs';
import {VEHICLE_SEATS,vehicleSeat,vehicleSeatPoint,vehicleDoorPoint,findVehicleEntry,vehicleEntryPoint,vehicleDeparturePoint,planVehicleSeatExit,canControlVehicle,inputForVehicleSeat} from './vehicle_seats.mjs';
import {createVehicleDamage} from './vehicle_damage.mjs';
import {createGlassBreakage} from './glass_breakage.mjs';
import {circleFits,movePedestrian} from './walk_motion.mjs';
import {createWalkCollisionIndex} from './walk_collision_index.mjs';
import {createStableEntryLights} from './stable_entry_lights.mjs';
import {createSurfaceMotion,resolveJumpSurface} from './surface_motion.mjs';
import {residentialWindowCacheStats} from './residential_windows.mjs';
import {createWindowedBuildingEntry} from './building_window_integration.mjs';
import {createStreetLighting} from './street_lighting.mjs';
import {createTyreDamage} from './tyre_damage.mjs';
const $=id=>document.getElementById(id), M=4.1, root='/assets/maps/city_rebuild_v1/';
const exitQaMode=new URLSearchParams(location.search).get('carexitqa')==='1';
let exitQaPaused=false;
const scene=new THREE.Scene();scene.background=new THREE.Color('#bfd1d6');scene.fog=new THREE.Fog('#bfd1d6',180,550);
const camera=new THREE.PerspectiveCamera(45,innerWidth/innerHeight,.2,1500);
const renderer=new THREE.WebGLRenderer({antialias:true,powerPreference:'high-performance'});
const startup=installFastWalkStartup({THREE,renderer,scene,camera,isReady:()=>!!hero&&!!car});
renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));renderer.setSize(innerWidth,innerHeight);
renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1;
$('viewport').append(renderer.domElement);
const pmrem=new THREE.PMREMGenerator(renderer),room=new RoomEnvironment();
const environment=pmrem.fromScene(room,.04);scene.environment=environment.texture;scene.environmentIntensity=.45;room.dispose();pmrem.dispose();
const ambient=new THREE.HemisphereLight('#e8f3ff','#889973',.8);scene.add(ambient);
const sun=new THREE.DirectionalLight('#fff0d4',1.7);sun.position.set(-75,130,90);sun.castShadow=true;
sun.shadow.mapSize.set(2048,2048);Object.assign(sun.shadow.camera,{left:-90,right:90,top:90,bottom:-90,near:1,far:320});sun.shadow.bias=-.0003;sun.shadow.normalBias=.04;scene.add(sun,sun.target);
const controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=true;controls.maxPolarAngle=Math.PI*.92;controls.minDistance=3;controls.maxDistance=16;controls.rotateSpeed=.65;
controls.target.set(60*M,0,30*M);camera.position.copy(controls.target).add(new THREE.Vector3(45,75,95));
const loader=new GLTFLoader(),templates=new Map(),content=new THREE.Group();scene.add(content);
let topology=null,instances=[],bodies=[],loaded=0,failed=0,busy=false,walking=false,revision='',lastLoadAt=0,hero=null;
let buildingEntries=[],buildingBodies=[],carBodies=[],buildingKeyConsumed=false,buildingQaMove=null,cameraBeforeBuildingClamp=null;
let entryBodyVersions=[],walkCollisionIndex=null;
let stableEntryLights=null;
let streetLighting=createStreetLighting({THREE,scene,maxLights:8,maxFixtures:192,groundHeight,staticPlacement:true}),environmentNight=0;
const surfaceMotion=createSurfaceMotion();
let tyres=null;
let crashPartner=null,blastResponse=null,heroBlast=null,heroBlastSource=null;let carRollover=null;let car=null,carState=null,carDamage=null,carQa=null,occupiedSeat=null,driveAllowed=()=>false,transition=null,entryHeld=0,entryArmed=true,pointerHeld=false,lastDoorSide=1,followCarCamera=true;
let jump=null,jumpCount=0;
const artistInput=createArtist14Input({now:()=>performance.now()/1000}),artistPose=createArtist14Pose(THREE);
let artistSurface=null,artistSurfaceState=null,artistAction={action:{type:'none'},start:null},artistDropId=0,artistDropDistance=0;
const artistBusy=()=>['hit','fall','dead'].includes(artistSurface?.state.kind),artistSwimming=()=>artistSurfaceState?.swim.active===true;
function artistAllowed(){return !!hero&&walking&&!occupiedSeat&&!transition&&!busy&&!arsenalOpen()&&$('scene-menu').hidden&&!heroBlast&&!artistBusy()&&!artistSwimming();}
function artistMeleeContext(){return {time:performance.now()/1000,allowed:artistAllowed()&&heroPosture.value<.001,armed:currentWeapon.id!=='none',airborne:!!jump,yaw:hero?.object.rotation.y||0,airHeight:hero?Math.max(0,hero.object.position.y-groundHeight(hero.object.position.x,hero.object.position.z)):0};}
function artistUpdate(dt,moved,running){
 if(!artistSurface||!hero)return;const pos=hero.object.position,before=pos.clone(),water=waterAt(pos.x,pos.z),floor=groundHeight(pos.x,pos.z),unit=hero.scale;
 artistSurfaceState=artistSurface.update(dt,{time:performance.now()/1000,waterLevel:water?.level??null,inWater:!!water&&water.depth>0,moving:moved,fast:running,chestWorldY:floor+3.08*unit,groundWorldY:floor,blocked:!!occupiedSeat||!!transition||!!jump||!!heroBlast});
 if(!occupiedSeat&&!transition&&!jump){const shift=pos.clone().sub(before);camera.position.add(shift);controls.target.add(shift);}
 if(weaponModel&&artistSurfaceState.swim.blend>.1)weaponModel.visible=false;
 document.body.dataset.artist14=JSON.stringify({revision:'artist14-game-v14',swim:artistSurfaceState.swim.active,fast:artistSurfaceState.swim.fast,reaction:artistSurfaceState.reaction.kind,melee:artistAction.action.type,shedding:artistSurfaceState.shedding});
}
document.addEventListener('artist14:hit',event=>{if(event.detail?.target==='hero'&&artistSurface?.receive(event.detail)){artistInput.cancel();releaseControls();}});
document.addEventListener('artist14:restore',event=>{if(event.detail?.confirmed===true)artistSurface?.reset();});
const heroPosture=createHeroPosture();let postureMotion=posturePresentation(heroPosture),animationQaMoveUntil=0,animationQaMoveDirection=null,animationQaJumpPending=false;
let currentWeapon=ARSENAL[0],weaponModel=null,weaponHud=null,lastWeaponId=null;
const tireTracks=createTireTracks(THREE,{surfaceAt:(x,z)=>[0,9,19].includes(topology?.grid?.[Math.floor(z/M)]?.[Math.floor(x/M)])});scene.add(tireTracks.object);
let glass=createGlassBreakage(THREE,scene,{groundHeight});
const fireStates=new Map(),effects=createWeaponEffects(THREE,scene,{onImpact(payload){carDamage?.impact(payload);crashPartner?.damage.impact(payload);if(payload.explosive)blastResponse?.enqueue({point:payload.point,power:1.4,radius:11});tyres?.hit(payload);glass.hit(payload.hit,{direction:payload.direction,impulse:payload.damage,weaponId:payload.weaponId})}}),aimRay=new THREE.Raycaster();
let triggerHeld=false,triggerPressed=false,reloadPressed=false,aiming=false,aimBlend=0,savedCameraOffset=null;
blastResponse=createBlastResponse(THREE,scene,{getHero:()=>hero,getVehicles:()=>[{car,damage:carDamage,roll:carRollover},...(crashPartner?[{car:crashPartner.car,damage:crashPartner.damage,roll:crashPartner.roll}]:[])],getRoots:()=>[content],getGlass:()=>glass,groundHeight,onHeroLaunch(body,event){if(heroBlast&&body.strength<heroBlast.strength*.65)return;heroBlastSource=occupiedSeat?car:event.source;occupiedSeat=null;transition=null;jump=null;heroBlast=body;releaseControls();releaseWeapon();keys.clear();hero.object.rotation.z=0;hero.reset();setWalking(true);for(const id of ['district','walk','reload'])$(id).disabled=false;}});
function combatAllowed(){return !artistSwimming()&&!artistBusy()&&!!hero&&walking&&!occupiedSeat&&!transition&&!heroBlast&&!busy&&!arsenalOpen()&&$('scene-menu').hidden&&currentWeapon.id!=='none'}
function releaseWeapon(){triggerHeld=false;triggerPressed=false;reloadPressed=false;aiming=false}
function fireState(){if(!fireStates.has(currentWeapon.id))fireStates.set(currentWeapon.id,createWeaponFireState(currentWeapon.id));return fireStates.get(currentWeapon.id)}
function updateCombat(dt){
 const allowed=combatAllowed();if(!allowed)releaseWeapon();
 const result=stepWeaponFire(fireState(),{triggerHeld:allowed&&triggerHeld,triggerPressed:allowed&&triggerPressed,reload:allowed&&reloadPressed,aiming},dt);fireStates.set(currentWeapon.id,result.state);triggerPressed=false;reloadPressed=false;
 effects.update(dt);
 const recoil=sampleWeaponRecoil(result.state),forward=camera.getWorldDirection(new THREE.Vector3());
 const active=allowed&&(aiming||triggerHeld||result.shots.length||recoil.normalized>0||result.state.reloadRemaining>0),aimPitch=Math.asin(THREE.MathUtils.clamp(forward.y,-.958,.958)),aimYaw=Math.atan2(forward.x,forward.z),profile=weaponFireProfile(currentWeapon.id),reloadProgress=result.state.reloadRemaining>0&&profile?1-result.state.reloadRemaining/profile.reloadSeconds:0;
 weaponHud?.setState({weaponId:currentWeapon.id,...result.state,disabled:!!occupiedSeat||!!transition});
 weaponHud?.setScopeVisible(allowed&&aiming&&currentWeapon.id==='sniper');
 $('cross').style.display=allowed&&(aiming||triggerHeld)&&!(aiming&&currentWeapon.id==='sniper')?'block':'none';
 document.body.dataset.heroFire=JSON.stringify({id:currentWeapon.id,allowed,walking,busy,arsenalOpen:arsenalOpen(),aiming,triggerHeld,magazine:result.state.magazine,reserve:result.state.reserveAmmo,reloading:result.state.reloadRemaining,recoil:recoil.normalized,...effects.stats()});
 return {allowed,active,result,recoil,forward,aim:{aimYaw,aimPitch,recoil:recoil.normalized,recoilYaw:recoil.recoilYaw},reloadProgress};
}
function emitCombatShots(combat){
 if(!combat?.allowed||!weaponModel||!combat.result.shots.length)return;
 camera.updateMatrixWorld();scene.updateMatrixWorld(true);aimRay.set(camera.position,combat.forward);aimRay.near=0;aimRay.far=100;
 const obstacles=[content,...(car?[car.object]:[]),...(crashPartner?[crashPartner.car.object]:[])],hit=aimRay.intersectObjects(obstacles,true).find(h=>h.object.visible),target=hit?hit.point:aimRay.ray.at(100,new THREE.Vector3()),transforms=resolveWeaponShotTransforms(THREE,weaponModel);
 for(const shot of combat.result.shots)effects.shoot(shot,transforms,target,obstacles);
}
function updateAimCamera(dt){
 const desired=aiming&&combatAllowed()?1:0;
 controls.maxPolarAngle=Math.PI*(desired?.92:.48);
 const scoped=!!desired&&currentWeapon.id==='sniper';
 if(desired&&!savedCameraOffset)savedCameraOffset=camera.position.clone().sub(controls.target);
 aimBlend+=(desired-aimBlend)*(1-Math.exp(-14*dt));
 if(savedCameraOffset){
  const forward=camera.getWorldDirection(new THREE.Vector3()),right=new THREE.Vector3().crossVectors(forward,new THREE.Vector3(0,1,0)).normalize();
  const target=hero.object.position.clone().add(new THREE.Vector3(0,postureEyeHeight(),0)).addScaledVector(right,scoped?0:.75),behind=forward.clone().multiplyScalar(scoped?-.12:-4.2);
  if(desired){if(scoped)camera.position.copy(target).add(behind);else camera.position.lerp(target.clone().add(behind),1-Math.exp(-10*dt));camera.position.y=Math.max(.3,camera.position.y);controls.target.copy(camera.position).addScaledVector(forward,4.2);camera.lookAt(controls.target);const radius=Math.hypot(savedCameraOffset.x,savedCameraOffset.z),horizontal=Math.hypot(forward.x,forward.z);if(horizontal>.001){savedCameraOffset.x=-forward.x/horizontal*radius;savedCameraOffset.z=-forward.z/horizontal*radius}}
  else {const normal=hero.object.position.clone().add(new THREE.Vector3(0,postureEyeHeight(),0));controls.target.copy(normal);camera.position.lerp(normal.clone().add(savedCameraOffset),1-Math.exp(-14*dt));camera.lookAt(normal);if(aimBlend<.005)savedCameraOffset=null}
 }
 if(hero)hero.object.visible=!scoped;
 camera.fov=(scoped?14:45-3*aimBlend)+sampleWeaponRecoil(fireState()).normalized*.7;camera.updateProjectionMatrix();
 document.body.dataset.sniperScope=scoped?'active':'off';
}
let exitNotice='',exitNoticeUntil=0;
function receiveVehicleContact(contact){if(!car||!carState)return false;const damaged=carDamage.contactImpact(contact),rolled=carRollover.impact(contact,carState.yaw);return damaged||rolled}
function carLocal(side,front=0,y=0){const {x,z,yaw}=carState;return new THREE.Vector3(x+Math.cos(yaw)*side+Math.sin(yaw)*front,y,z-Math.sin(yaw)*side+Math.cos(yaw)*front)}
function pedestrianAllowed(x,z){return canWalk(x,z)&&(!crashPartner||!crashPartner.overlaps(x,z))&&(!carState||!pointInPolygon(x,z,carCorners(carState.x,carState.z,carState.yaw)))}
function unattendedAllowed(x,z){return driveAllowed(x,z)}
unattendedAllowed.contactAt=(...args)=>driveAllowed.contactAt?.(...args);
unattendedAllowed.poseAllowed=(x,z,yaw)=>driveAllowed.poseAllowed(x,z,yaw)&&(!hero||!carOverlapsCircle({x,z,yaw},hero.object.position.x,hero.object.position.z,transition?.phase==='body'?EXIT.radius:.36));
function carExitSpot(seatId='front_left'){if(!carState)return null;for(const distance of [1.9,2.4]){const p=vehicleDoorPoint(carState,seatId,distance);if(circleFits(p.x,p.z,pedestrianAllowed))return new THREE.Vector3(p.x,p.y,p.z)}return null}
function entrySpot(){
 if(!hero||!carState||transition||jump||heroBlast)return null;if(occupiedSeat)return carExitSpot(occupiedSeat);if(carDamage?.disabled||carRollover?.unstable)return null;
 const candidate=findVehicleEntry(carState,hero.object.position,canWalk);if(!candidate)return null;
 const from=hero.object.position,to=candidate.outside;for(let i=0;i<=12;i++){const t=i/12;if(!circleFits(from.x+(to.x-from.x)*t,from.z+(to.z-from.z)*t,pedestrianAllowed))return null}return candidate;
}
function entryEligible(){return !!entrySpot()}
function beginCarTransition(){
 if(!entryEligible())return;entryArmed=false;entryHeld=0;pointerHeld=false;keys.clear();
 setArsenalOpen(false);
 if(occupiedSeat){
  const plan=planVehicleSeatExit(carState,occupiedSeat,driveAllowed,canWalk);
  if(!plan){exitNotice='Нет безопасного места сбоку — отъедь от препятствия';exitNoticeUntil=performance.now()+2500;return}
  lastDoorSide=plan.side;transition={exiting:true,phase:'door',elapsed:0,...plan,door:0};
 }else{
  const candidate=entrySpot();lastDoorSide=candidate.side;transition={exiting:false,elapsed:0,...candidate,from:hero.object.position.clone(),outside:new THREE.Vector3(candidate.outside.x,candidate.outside.y,candidate.outside.z)};carState.speed=0;carState.distance=0;
 }
 resetHeroPosture(heroPosture);postureMotion=posturePresentation(heroPosture);$('district').disabled=true;$('walk').disabled=true;$('reload').disabled=true;controls.enablePan=false;hero.reset();
}
function finishExit(){hero.object.rotation.z=0;transition=null;occupiedSeat=null;car.setDoorById(0,'front_left');hero.reset();hero.object.position.y=groundHeight(hero.object.position.x,hero.object.position.z);surfaceMotion.reset(hero.object.position);setWalking(true);ensureVehicleExitVisible(THREE,{hero,car,camera,controls,eyeHeight:postureEyeHeight()});keys.clear();$('district').disabled=false;$('walk').disabled=false;$('reload').disabled=false;if(exitQaMode&&$('exit-qa-status'))$('exit-qa-status').textContent='Тест выхода завершён';}
function abortExit(){
 occupiedSeat=transition?.seatId||occupiedSeat;transition=null;car.setDoorById(0,occupiedSeat);hero.reset();const p=vehicleSeatPoint(carState,occupiedSeat);hero.object.position.set(p.x,p.y,p.z);hero.object.rotation.y=carState.yaw;hero.vehiclePose(1,0,{driver:canControlVehicle(occupiedSeat),steeringGrips:car.getSteeringGrips()});
 exitNotice='Выход отменён: рядом препятствие';exitNoticeUntil=performance.now()+2500;
}
function updateMovingExit(dt){
 const t=transition;
 if(t.phase==='door'){
  t.elapsed+=dt;const p=Math.min(1,t.elapsed/EXIT.releaseSeconds),point=vehicleDeparturePoint(carState,t.seatId,t.distance,p);
  const roll=carRollover?.stats().angle||0;if(roll){const a=vehicleSeat(t.seatId).anchor,flat=vehicleSeatPoint(carState,t.seatId);car.object.updateWorldMatrix(true,false);const tilted=car.object.localToWorld(new THREE.Vector3(a.side,a.y,a.front));point.x+=(tilted.x-flat.x)*(1-p);point.y+=(tilted.y-flat.y)*(1-p);point.z+=(tilted.z-flat.z)*(1-p);}hero.object.rotation.z=roll*(1-p);
  if(!circleFits(point.x,point.z,canWalk,EXIT.radius)){abortExit();return}
  hero.object.position.set(point.x,point.y,point.z);hero.object.rotation.y=carState.yaw-t.side*(1-point.pose.seat)*Math.PI/2;
  const fold=t.kind==='tumble'?Math.max(point.pose.fold,THREE.MathUtils.smoothstep(p,.35,.9)):point.pose.fold;
  hero.vehiclePose(fold,point.pose.reach,point.pose);t.door=Math.min(1,p/.2);car.setDoorById(t.door,t.doorId);
  if(p>=1){
   if(carOverlapsCircle(carState,point.x,point.z,EXIT.radius)){abortExit();return}
   t.phase='body';t.body=launchExitBody(point,carState,t.side,t.kind);t.elapsed=0;occupiedSeat=null;hero.reset();
   hero.object.position.set(t.body.x,t.body.y,t.body.z);hero.object.rotation.y=t.body.heading;
   if(t.kind==='tumble')hero.tumblePose(0,t.body.rolls);
  }
 }else{
  t.body=stepExitBody(t.body,dt,pedestrianAllowed);t.elapsed=t.body.elapsed;
  if(exitQaMode&&$('exit-qa-status'))$('exit-qa-status').textContent=t.kind==='tumble'?'Перекат':'Шаг из машины';
  hero.object.position.set(t.body.x,t.body.y,t.body.z);hero.object.rotation.y=t.body.heading;
  if(t.kind==='tumble')hero.tumblePose(t.body.progress,t.body.rolls);else hero.update(dt,Math.hypot(t.body.vx,t.body.vz)>.15,false);
  t.door=Math.max(0,1-t.elapsed/.3);car.setDoorById(t.door,t.doorId);if(t.body.done)finishExit();
  if(exitQaMode&&t.kind==='tumble'&&t.body.progress>=.23&&!t.body.done&&$('exit-qa-freeze')?.checked)exitQaPaused=true;
 }
}
function updateCarInteraction(dt){
 if(!car||!hero)return;
 if(transition?.exiting){updateMovingExit(dt);$('car').textContent=transition?.kind==='tumble'?'Выпрыгиваем…':'Выходим…';}
 else if(transition){
  const t=transition;t.elapsed+=dt;const p=Math.min(1,t.elapsed/TRANSITION_SECONDS),outside=t.from.clone().lerp(t.outside,Math.min(1,p/.25)),point=vehicleEntryPoint(carState,t.seatId,p,outside),pose=point.pose;
  hero.object.position.set(point.x,point.y,point.z);hero.object.rotation.y=point.yaw;hero.vehiclePose(pose.fold,pose.reach,pose);t.door=pose.door;car.setDoorById(pose.door,t.doorId);
  $('car').textContent=t.exiting?'Выходим…':'Садимся…';
  if(pose.done){occupiedSeat=t.seatId;transition=null;car.setDoorById(0,t.doorId);hero.reset();setWalking(true);keys.clear();$('district').disabled=true;$('walk').disabled=true;$('reload').disabled=true;}
 }else{
  const pressed=(keys.has('KeyE')&&!buildingKeyConsumed)||pointerHeld;if(!pressed)entryArmed=true;
  const holdDuration=occupiedSeat?EXIT_HOLD_SECONDS:HOLD_SECONDS;
  const hold=advanceEntryHold(entryHeld,pressed&&entryArmed,entryEligible()&&(occupiedSeat||pointerHeld||nearestInteraction()?.kind==='car'),dt,holdDuration);entryHeld=hold.elapsed;
  $('car').textContent=entryHeld>0?`Удерживай E · ${Math.round(entryHeld/holdDuration*100)}%`:occupiedSeat?'Удерживай E 0,3 с — выйти':'Удерживай E 0,3 с — сесть';
  if(hold.ready)beginCarTransition();
 }
 const state=transition?(transition.exiting?(transition.phase==='body'?(transition.kind==='tumble'?'tumbling':'stepping_off'):'exiting'):'entering'):occupiedSeat?(canControlVehicle(occupiedSeat)?'driving':'passenger'):'on_foot';
 $('drive-status').textContent=performance.now()<exitNoticeUntil?exitNotice:transition?(transition.exiting?(transition.kind==='tumble'?'Выпадение и перекат…':'Выход на ходу…'):`Посадка · ${vehicleSeat(transition.seatId).label}`):occupiedSeat?`${vehicleSeat(occupiedSeat).label} · ${Math.round(Math.abs(carState.speed)*3.6)} км/ч · E 0,3 с — ${Math.abs(carState.speed)>EXIT.tumbleSpeed?'выпрыгнуть':'выйти'}${carDamage?.disabled?' · машина уничтожена':carState.bumped?' · препятствие':''}`:carDamage?.disabled?'Машина уничтожена':entryEligible()?`E · удержать 0,3 с — ${entrySpot().label}`:Math.abs(carState.speed)>.5?'Машина катится по инерции':'Подойди к нужной двери машины';
 document.body.dataset.carDrive=JSON.stringify({state,occupiedSeat,driving:canControlVehicle(occupiedSeat),speed:carState.speed,x:carState.x,z:carState.z,yaw:carState.yaw,steer:carState.steer||0,hold:entryHeld,doorSide:lastDoorSide,doorId:transition?.doorId||null,door:transition?.door||0,exitKind:transition?.kind||null,exitProgress:transition?.body?.progress||0,wheelSpin:car.wheels[0].wheel.rotation.x,handbrake:!!carState.handbrake});
}
function updateCarPrompt(){
 const prompt=$('car-prompt'),candidate=nearestInteraction(),selected=candidate?.kind==='car'?candidate.spot:null;car?.setHighlightedDoor(null);
 if(!car||!hero||occupiedSeat||transition||!selected){prompt.hidden=true;return}
 // Project after OrbitControls AND render updated camera matrices, never from the previous frame.
 const anchor=car.anchors.doors.find(door=>door.id===selected.doorId).handle,screen=carLocal(anchor.side,anchor.front,1.95).project(camera);prompt.hidden=screen.z<-1||screen.z>1||Math.abs(screen.x)>1.1||Math.abs(screen.y)>1.1;
 $('car-seat-label').textContent=selected.label;
 if(!prompt.hidden){const x=Math.round((screen.x+1)*innerWidth/2),y=Math.round((1-screen.y)*innerHeight/2);prompt.style.transform=`translate3d(${x}px,${y}px,0) translate(-50%,-100%)`;$('car-hold-progress').style.transform=`scaleX(${entryHeld/HOLD_SECONDS})`}
}
function waterAt(x,z){
 const r=Math.floor(z/M),c=Math.floor(x/M);if(topology?.grid?.[r]?.[c]!==16||topology?.protectedMask?.[r]?.[c])return null;
 let shore=3.5;for(let rr=r-1;rr<=r+1;rr++)for(let cc=c-1;cc<=c+1;cc++){if(topology?.grid?.[rr]?.[cc]===16)continue;const dx=Math.max(cc*M-x,0,x-(cc+1)*M),dz=Math.max(rr*M-z,0,z-(rr+1)*M);shore=Math.min(shore,Math.hypot(dx,dz));}
 const floor=-Math.min(2.4,shore*.9);return {level:-.18,depth:Math.max(0,-.18-floor),floor};
}
function groundHeight(x,z){for(const entry of buildingEntries){const y=entry.floorHeight(x,z);if(y!==null)return y}const water=waterAt(x,z);return water?water.floor:0}
function ceilingHeight(x,z){let height=Infinity;for(const entry of buildingEntries){const y=entry.ceilingHeight({x,z});if(y!==null)height=Math.min(height,y)}return height}
function canOccupyPostureHeight(height,x=hero?.object.position.x,z=hero?.object.position.z){
 if(!Number.isFinite(x)||!Number.isFinite(z))return false;const floor=groundHeight(x,z);if(ceilingHeight(x,z)<floor+height-.03)return false;const r=z/M,c=x/M;
 for(const body of walkCollisionIndex?.(c,r)||[]){if(body.maxYM!==undefined&&body.maxYM<floor+.05)continue;if(body.minYM!==undefined&&body.minYM>floor+height)continue;if(inPolygon(r,c,body.polygonCR))return false}return true;
}
function postureEyeHeight(){return postureMotion?.eyeHeight||1.1}
function setHeroPosture(target){
 if(!hero||occupiedSeat||transition||jump||heroBlast||busy||!walking)return false;
 const accepted=requestHeroPosture(heroPosture,target,{canOccupyHeight:height=>canOccupyPostureHeight(height)});if(accepted&&target!=='prone'){animationQaMoveUntil=0;animationQaMoveDirection=null}if(!accepted){exitNotice='Над головой мало места, чтобы подняться';exitNoticeUntil=performance.now()+1800}return accepted;
}
function resetFootSupport(){if(!hero)return;hero.object.position.y=groundHeight(hero.object.position.x,hero.object.position.z);surfaceMotion.reset(hero.object.position)}
function insideBuilding(){return !!hero&&buildingEntries.some(entry=>entry.containsInterior(hero.object.position))}
function nearestInteraction(){
 if(!hero||!walking||occupiedSeat||transition||jump||heroBlast||busy||arsenalOpen()||!$('scene-menu').hidden)return null;
 const candidates=[];
 for(const entry of buildingEntries){const proximity=entry.proximity(hero.object.position);if(proximity)candidates.push({kind:'building',entry,...proximity})}
 const spot=entrySpot();if(spot)candidates.push({kind:'car',distance:spot.near,spot});
 return candidates.sort((a,b)=>a.distance-b.distance)[0]||null;
}
function interactWithBuilding(){
 const candidate=nearestInteraction();if(candidate?.kind!=='building')return false;
 buildingKeyConsumed=true;entryHeld=0;pointerHeld=false;releaseWeapon();
 const result=candidate.entry.interact(hero.object.position);
 if(!result.accepted&&result.reason==='door-sweep-occupied'){exitNotice='Отойдите от створок, чтобы закрыть дверь';exitNoticeUntil=performance.now()+1800}
 return true;
}
function updateBuildingEntries(dt){
 let changed=!walkCollisionIndex||entryBodyVersions.length!==buildingEntries.length;
 for(let i=0;i<buildingEntries.length;i++){const entry=buildingEntries[i];entry.update(dt,hero?.object.position);const next=entry.getCollisionBodies();if(entryBodyVersions[i]!==next){entryBodyVersions[i]=next;changed=true}}
 if(changed){entryBodyVersions.length=buildingEntries.length;buildingBodies=entryBodyVersions.flat();walkCollisionIndex=createWalkCollisionIndex([bodies,buildingBodies])}
}
function updateBuildingPrompt(){
 const prompt=$('building-prompt'),candidate=nearestInteraction();
 if(candidate?.kind!=='building'){prompt.hidden=true;return}
 const screen=candidate.anchor.clone().project(camera);
 prompt.hidden=screen.z<-1||screen.z>1||Math.abs(screen.x)>1.1||Math.abs(screen.y)>1.1;
 $('building-action').textContent=candidate.action;
 if(!prompt.hidden)prompt.style.transform=`translate3d(${Math.round((screen.x+1)*innerWidth/2)}px,${Math.round((1-screen.y)*innerHeight/2)}px,0) translate(-50%,-100%)`;
 if(!transition&&!occupiedSeat&&!jump&&performance.now()>=exitNoticeUntil)$('drive-status').textContent='E — дверь · WASD — пройти';
}
function restoreBuildingCamera(){
 if(!cameraBeforeBuildingClamp)return;
 camera.position.copy(cameraBeforeBuildingClamp.position);controls.target.copy(cameraBeforeBuildingClamp.target);camera.quaternion.copy(cameraBeforeBuildingClamp.quaternion);camera.updateMatrixWorld();cameraBeforeBuildingClamp=null;
}
function clampBuildingCamera(){
 if(!hero||occupiedSeat||transition)return;
 const relevant=buildingEntries.filter(entry=>entry.containsInterior(hero.object.position)||entry.proximity(hero.object.position,12));
 if(!relevant.length)return;
 for(const entry of relevant)entry.visual.updateWorldMatrix(true,true);
 const origin=hero.object.position.clone().add(new THREE.Vector3(0,aiming?1.5:1.1,0));
 const corrected=resolveBuildingCameraPosition({THREE,from:origin,desired:camera.position,objects:relevant.map(entry=>entry.visual),ceilingY:aiming?Infinity:(relevant.find(entry=>entry.containsInterior(hero.object.position))?.ceilingHeight(hero.object.position)??Infinity)});
 if(corrected.distanceToSquared(camera.position)<1e-8)return;
 cameraBeforeBuildingClamp={position:camera.position.clone(),target:controls.target.clone(),quaternion:camera.quaternion.clone()};
 const shift=corrected.clone().sub(camera.position);camera.position.copy(corrected);
 if(aiming)controls.target.add(shift);else camera.lookAt(controls.target);
 camera.updateMatrixWorld();
}
function initBuildingQa(){
 if(new URLSearchParams(location.search).get('buildingqa')!=='1')return;
 const panel=document.createElement('div');panel.id='building-qa';panel.style.cssText='position:absolute;top:55px;right:12px;z-index:6;padding:8px;background:#142b32;border:1px solid #d7b85e;display:flex;gap:5px;flex-wrap:wrap;max-width:440px';
 const add=(label,callback)=>{const button=document.createElement('button');button.textContent=label;button.onclick=callback;panel.append(button)};
 const available=()=>hero&&!occupiedSeat&&!transition&&!jump&&!heroBlast&&!busy;
 const choice=document.createElement('select');choice.id='building-qa-choice';choice.setAttribute('aria-label','Здание для проверки комнаты');
 for(const entry of buildingEntries)choice.add(new Option(`${entry.instance.assetId} · ${entry.instance.id}`,entry.instance.id));panel.append(choice);
 add('QA: к выбранной двери',()=>{
  if(!available()||!buildingEntries.length)return;
  releaseControls();restoreBuildingCamera();savedCameraOffset=null;aimBlend=0;
  const entry=buildingEntries.find(e=>e.instance.id===choice.value)||buildingEntries[0],point=entry.approachPoint();
  if(!circleFits(point.x,point.z,pedestrianAllowed))return;
  point.y=groundHeight(point.x,point.z);hero.object.position.copy(point);surfaceMotion.reset(point);const facing=entry.roomPoint().sub(point);facing.y=0;facing.normalize();hero.object.rotation.y=Math.atan2(facing.x,facing.z);
  hero.reset();setWalking(true);$('scene-menu').hidden=true;setArsenalOpen(false);
  controls.target.copy(point).add(new THREE.Vector3(0,1.1,0));camera.position.copy(point).addScaledVector(facing,-5).add(new THREE.Vector3(0,2.6,0));camera.lookAt(controls.target);setFreeMouse(false);
 });
 add('QA: нажать E',()=>{if(available())interactWithBuilding()});
 for(const [label,method] of [['QA: пройти внутрь','roomPoint'],['QA: центр комнаты','roomCenterPoint'],['QA: хранилище','vaultPoint'],['QA: выйти наружу','approachPoint']])add(label,()=>{
  if(!available())return;const entry=buildingEntries.find(e=>e.containsInterior(hero.object.position)||e.proximity(hero.object.position,4));if(!entry)return;
  if(method==='vaultPoint'&&!entry.vaultPoint)return;releaseControls();setFreeMouse(false);const targets=method==='vaultPoint'?[entry.roomCenterPoint(),entry.vaultPoint()]:method==='roomCenterPoint'?[entry.roomPoint(),entry.roomCenterPoint()]:method==='approachPoint'?[entry.roomPoint(),entry.approachPoint()]:[entry.roomPoint()];buildingQaMove={entry,target:targets.shift(),remaining:targets,elapsed:0};
 });
 add('QA: прыжок',()=>{if(available())beginJump()});
 const status=document.createElement('span');status.id='building-qa-status';status.style.cssText='flex-basis:100%;color:#ffdfa4';status.textContent='Проверка входа в той же сцене';panel.append(status);document.body.append(panel);
}
function initCar(){
 if(car||!hero)return;const hr=hero.object.position.z/M,hc=hero.object.position.x/M;let best=null;
 for(let r=Math.max(1,Math.floor(hr)-18);r<Math.min(topology.grid.length-1,hr+18);r++)for(let c=Math.max(1,Math.floor(hc)-18);c<Math.min(topology.grid[r].length-1,hc+18);c++){
  if(!topology.roadMask[r][c])continue;for(const yaw of [0,Math.PI/2,Math.PI,-Math.PI/2]){const x=(c+.5)*M,z=(r+.5)*M,d=(r-hr)**2+(c-hc)**2;if(best&&d>=best.d)continue;
   const clearAhead=[0,3,6,10].every(offset=>carFits(x+Math.sin(yaw)*offset,z+Math.cos(yaw)*offset,yaw,driveAllowed));
   if(clearAhead){carState={x,z,yaw,speed:0,steer:0,d};if(carExitSpot())best=carState;}
  }
 }
 if(!best){carState=null;fail('Не найден безопасный участок для машины');return}carState=best;car=createDemoCar(THREE,RoundedBoxGeometry);car.object.position.set(best.x,0,best.z);car.object.rotation.y=best.yaw;scene.add(car.object);
 carRollover=createVehicleRollover(THREE,car);
 carDamage=createVehicleDamage(THREE,car,{onExplosion(){blastResponse?.enqueue({point:car.object.localToWorld(new THREE.Vector3(0,1,0)),power:1,radius:10,source:car});glass.shatterAll(car.object,{impulse:80,weaponId:'vehicle_explosion'});exitNotice='Машина уничтожена';exitNoticeUntil=performance.now()+2500;if(occupiedSeat&&!transition)beginCarTransition()}});glass.prepare(car.object);
 tyres=createTyreDamage(THREE,car,{groundHeight});
 crashPartner=createCrashPartner(THREE,{scene,RoundedBox:RoundedBoxGeometry,mainCar:car,mainState:()=>carState,world:()=>driveAllowed,mainDamage:carDamage,mainRoll:carRollover,onExplosion(event){blastResponse?.enqueue({point:event.vehicle.object.localToWorld(new THREE.Vector3(0,1,0)),power:1,radius:10,source:event.vehicle})}});if(crashPartner)glass.prepare(crashPartner.car.object);
 const p=carExitSpot();hero.object.position.copy(p);resetFootSupport();controls.target.copy(p).y=hero.object.position.y+1.1;camera.position.copy(carLocal(4,-6,3));
 const button=document.createElement('button');button.id='car';button.textContent='Удерживай E 0,3 с — сесть';button.onpointerdown=e=>{if(e.button!==0)return;e.preventDefault();button.setPointerCapture(e.pointerId);pointerHeld=true};button.onpointerup=button.onpointercancel=()=>{pointerHeld=false};$('controls').append(button);
 if(new URLSearchParams(location.search).get('carqa')==='1'||new URLSearchParams(location.search).get('carphysicsqa')==='1')carQa=initCarPhysicsQa({document,
  onInput(input){for(const [name,key] of Object.entries({forward:'KeyW',reverse:'KeyS',left:'KeyA',right:'KeyD',handbrake:'Space'})){if(input[name])keys.add(key);else keys.delete(key)}},
  onRelease(){keys.clear();pointerHeld=false},onEntryHold(pressed){pointerHeld=pressed},
  onReset(){releaseControls();glass.reset(car.object);carDamage.reset();carRollover?.reset();crashPartner?.reset();blastResponse?.reset();heroBlast=null;hero.object.rotation.z=0;tyres.reset();tireTracks.clear();transition=null;jump=null;occupiedSeat=null;entryArmed=true;resetHeroPosture(heroPosture);postureMotion=posturePresentation(heroPosture);hero.reset();carState={...best,speed:0,steer:0,yawRate:0,travelYaw:best.yaw};car.object.position.set(best.x,0,best.z);car.object.rotation.y=best.yaw;car.setDoorById(0,'front_left');hero.object.position.copy(carExitSpot());resetFootSupport();hero.object.rotation.y=best.yaw;setWalking(true);controls.target.copy(hero.object.position).y=hero.object.position.y+postureEyeHeight();camera.position.copy(carLocal(4,-6,3));for(const id of ['district','walk','reload'])$(id).disabled=false;setFreeMouse(false)}
 });
 car.object.userData.receiveCollision=receiveVehicleContact;
 if(carQa){for(const speed of [3,16]){const b=document.createElement('button');b.textContent=speed===3?'QA: слабый боковой удар':'QA: сильный боковой удар';b.onclick=()=>{const point=carLocal(1.28,0,.8),normal={x:Math.cos(carState.yaw),y:0,z:-Math.sin(carState.yaw)};receiveVehicleContact({point,normal,impactSpeed:speed,slideSpeed:0})};carQa.panel.append(b)}}
 if(carQa)for(const seat of VEHICLE_SEATS){const button=document.createElement('button');button.textContent=`QA: к двери — ${seat.label}`;button.setAttribute('aria-label',button.textContent);button.onclick=()=>{if(occupiedSeat||transition||jump||heroBlast)return;const point=carExitSpot(seat.id);if(!point)return;releaseControls();hero.object.position.copy(point);resetFootSupport();controls.target.copy(point).y=hero.object.position.y+1.1;camera.position.copy(carLocal(seat.side*4,-5,3));setFreeMouse(false)};carQa.panel.append(button)}
 if(exitQaMode){
  // Explicit UI fixture for slow-motion visual QA; absent from the normal demo URL.
  const panel=document.createElement('div'),label=document.createElement('span');label.id='exit-qa-status';label.textContent='Проверка выхода · замедлено 4×';panel.append(label);
  const pauseLabel=document.createElement('label'),pause=document.createElement('input');pause.type='checkbox';pause.id='exit-qa-freeze';pause.onchange=()=>{if(!pause.checked)exitQaPaused=false};pauseLabel.append(pause,'Пауза на кувырке');panel.append(pauseLabel);
  for(const speed of [8,60]){const test=document.createElement('button');test.textContent=`Тест выхода ${speed} км/ч`;test.onclick=()=>{
   glass.reset(car.object);carDamage.reset();carRollover?.reset();crashPartner?.reset();blastResponse?.reset();heroBlast=null;hero.object.rotation.z=0;tyres.reset();tireTracks.clear();transition=null;exitQaPaused=false;hero.reset();keys.clear();carState={...best,speed:speed/3.6,steer:0,yawRate:0,travelYaw:best.yaw};car.object.position.set(best.x,0,best.z);car.object.rotation.y=best.yaw;car.setDoorById(0,'front_left');occupiedSeat='front_left';
   hero.object.position.copy(carLocal(DRIVER_SEAT.side,DRIVER_SEAT.front,DRIVER_SEAT.y));hero.object.rotation.y=best.yaw;hero.vehiclePose(1,0);controls.target.copy(hero.object.position).y=1;camera.position.copy(carLocal(6,-8,4));setFreeMouse(false);label.textContent='Дверь открывается';beginCarTransition();
  };panel.append(test)}document.querySelector('footer').append(panel);
 }
}
const errors=[];function fail(message){errors.push(message);$('errors').textContent=errors.slice(-3).join(' · ')}
function safeUrl(url){const u=new URL(url,location.origin);if(u.origin!==location.origin||!/^\/assets\/(maps\/city_rebuild_v1|buildings\/city_v3|decor\/civic_park_v2)\//.test(u.pathname))throw Error('Недопустимый URL модели');return u.href}
async function getJson(name,optional=false){const res=await fetch(root+name,{cache:'no-store'});if(optional&&res.status===404)return null;if(!res.ok)throw Error(name+': HTTP '+res.status);return res.json()}
async function template(binding){
 const key=binding.sha256;if(!key||!binding.url)throw Error('Нет хеша/URL модели');
 if(!templates.has(key))templates.set(key,(async()=>{const response=await fetch(safeUrl(binding.url));if(!response.ok)throw Error('GLB HTTP '+response.status);const bytes=await response.arrayBuffer();if(bytes.byteLength!==binding.bytes)throw Error('Размер GLB не совпал');const digest=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),n=>n.toString(16).padStart(2,'0')).join('');if(digest!==key.toLowerCase())throw Error('Хеш GLB не совпал');const gltf=await loader.parseAsync(bytes,new URL('.',safeUrl(binding.url)).href);
 gltf.scene.traverse(node=>{if(/(^|[_\s])(collision|collider|clearance|socket|anchor|keepout|nav|proxy|datum)([_\s]|$)/i.test(node.name)||/^(COLLISION|SOCKET|CLEARANCE|NAV_|COL_)/i.test(node.name))node.visible=false;
 if(node.isMesh){node.castShadow=true;node.receiveShadow=true;const mats=Array.isArray(node.material)?node.material:[node.material];for(const material of mats){if(material.transparent){material.depthWrite=false;material.side=THREE.FrontSide;material.forceSinglePass=true;material.envMapIntensity=.35}}}});
 return gltf.scene;})());return templates.get(key);
}
function clearContent({recreate=true}={}){restoreBuildingCamera();stableEntryLights?.dispose();stableEntryLights=null;glass.dispose();while(content.children.length){const node=content.children.pop();node.parent=null;node.userData.roomReveals?.dispose();node.userData.streetLighting?.dispose();node.userData.buildingEntry?.dispose();node.userData.residentialWindows?.dispose();node.userData.doorsGlass?.dispose();if(node.userData.owned)node.traverse(x=>{x.geometry?.dispose();if(x.material){for(const m of Array.isArray(x.material)?x.material:[x.material])m.dispose()}})}streetLighting.dispose();instances=[];bodies=[];carBodies=[];buildingBodies=[];buildingEntries=[];entryBodyVersions=[];walkCollisionIndex=null;buildingQaMove=null;document.body.dataset.windowCacheAfterClear=JSON.stringify(residentialWindowCacheStats());if(recreate){glass=createGlassBreakage(THREE,scene,{groundHeight});streetLighting=createStreetLighting({THREE,scene,maxLights:8,maxFixtures:192,groundHeight,staticPlacement:true});if(car)glass.prepare(car.object);if(crashPartner)glass.prepare(crashPartner.car.object)}}
function terrain(grid,protectedMask,asphalt){
 const palettes={0:'#525a5a',8:'#789274',9:'#c4c1ab',14:'#d9c698',16:'#4f9eb0',19:'#858e89'},vertices=new Map();
 for(let r=0;r<grid.length;r++)for(let c=0;c<grid[r].length;c++){const t=grid[r][c],key=protectedMask?.[r]?.[c]?'protected':t;const arr=vertices.get(key)||[];vertices.set(key,arr);const x=c*M,z=r*M,y=t===16?-.18:0;arr.push(x,y,z,x+M,y,z+M,x+M,y,z,x,y,z,x,y,z+M,x+M,y,z+M)}
 for(const [key,data] of vertices){const geo=new THREE.BufferGeometry();geo.setAttribute('position',new THREE.Float32BufferAttribute(data,3));geo.computeVertexNormals();const water=key===16;const mat=new THREE.MeshStandardMaterial({color:key==='protected'?'#9a9990':palettes[key]||'#788275',roughness:water?.22:.88,metalness:water?.14:0});if(key===0&&asphalt?.baseColorFactor){mat.color.fromArray(asphalt.baseColorFactor);mat.roughness=asphalt.roughnessFactor??.8;mat.metalness=asphalt.metallicFactor??0}const mesh=new THREE.Mesh(geo,mat);mesh.receiveShadow=!water;mesh.userData.owned=true;content.add(mesh)}
}
function inPolygon(r,c,polygon){if(!polygon?.length)return false;let inside=false;for(let i=0,j=polygon.length-1;i<polygon.length;j=i++){const a=polygon[i],b=polygon[j];if(((a[1]>r)!==(b[1]>r))&&(c<(b[0]-a[0])*(r-a[1])/(b[1]-a[1])+a[0]))inside=!inside}return inside}
function canWalk(x,z){const r=z/M,c=x/M,rr=Math.floor(r),cc=Math.floor(c);if(!topology?.walkableMask?.[rr]?.[cc]&&!waterAt(x,z))return false;const floor=groundHeight(x,z),bodyHeight=postureMotion?.height||1.9;if(ceilingHeight(x,z)<floor+bodyHeight-.03)return false;for(const body of walkCollisionIndex?.(c,r)||[]){if(body.maxYM!==undefined&&body.maxYM<floor+.05)continue;if(body.minYM!==undefined&&body.minYM>floor+bodyHeight)continue;if(inPolygon(r,c,body.polygonCR))return false}return true}
function focus(instance){restoreBuildingCamera();const t=instance?.transform?.positionM||[60*M,0,30*M];const pos=new THREE.Vector3(t[0],0,t[2]);let landing=pos.clone().add(new THREE.Vector3(0,0,20));for(let radius=15;radius<60&&!circleFits(landing.x,landing.z,canWalk);radius+=5){for(let a=0;a<Math.PI*2;a+=Math.PI/6){const test=pos.clone().add(new THREE.Vector3(Math.sin(a)*radius,0,Math.cos(a)*radius));if(circleFits(test.x,test.z,canWalk)){landing=test;break}}}if(!circleFits(landing.x,landing.z,canWalk)){fail('Для этой точки не найден безопасный подход');return}landing.y=groundHeight(landing.x,landing.z);controls.target.copy(landing);if(hero){resetHeroPosture(heroPosture);postureMotion=posturePresentation(heroPosture);hero.object.position.copy(landing);surfaceMotion.reset(landing);hero.reset();controls.target.y=landing.y+postureEyeHeight();camera.position.copy(landing).add(new THREE.Vector3(8,11,14))}else camera.position.copy(landing).add(new THREE.Vector3(35,50,65));controls.update()}
function records(data){return data?.instances||[]}
async function refresh(){if(busy||jump||insideBuilding()||buildingQaMove)return;busy=true;$('status').textContent='Читаю свежую расстановку…';
 try{const [top,bld,dec]=await Promise.all([getJson('topology_for_placement.json'),getJson('buildings_placement.v1.json',true),getJson('decor_placement.v1.json',true)]);if(!Array.isArray(top.grid)||top.grid.length!==200)throw Error('Нет полной сетки: сцена не заменена');
 const nextRevision=JSON.stringify([top.sourceSha256,bld?.sourceFingerprint,bld?.instances,dec?.instances]);if(nextRevision===revision){$('status').textContent=`В сцене ${loaded} 3D-объектов. Расстановка не изменилась.`;return}
 // Stage models before touching the last visible generation. Failed GLBs never become boxes.
 const all=[...records(bld),...records(dec)],unique=new Map();for(const item of all)if(item.binding)unique.set(item.binding.sha256,item.binding);loaded=0;failed=0;
 const queue=[...unique.values()];await Promise.all(Array.from({length:Math.min(3,queue.length)},async()=>{while(queue.length){const binding=queue.shift();try{await template(binding)}catch(e){failed++;templates.delete(binding.sha256);fail(e.message)}$('status').textContent=`Загрузка моделей: ${templates.size}/${unique.size} типов…`}}));
 clearContent();topology=top;terrain(top.grid,top.protectedMask,dec?.surfaces?.[0]?.materialDescriptor);
 for(const item of all){if(!item.binding||!templates.has(item.binding.sha256))continue;const source=await templates.get(item.binding.sha256);const group=new THREE.Group(),visual=source.clone(true),t=item.transform||{},offset=t.modelLocalOffsetM||[0,0,0];visual.traverse(node=>{if((item.hideNodeNames||[]).includes(node.name))node.visible=false});visual.position.fromArray(offset);group.userData.doorsGlass=applyBuildingDoorsGlass(visual,item);group.add(visual);group.position.fromArray(t.positionM||[item.c*M,0,item.r*M]);group.rotation.y=THREE.MathUtils.degToRad(t.yawDegrees||0);group.scale.setScalar(t.uniformScale??1);group.userData.instance=item;content.add(group);group.updateMatrixWorld(true);const {entry,windows,roomReveals}=createWindowedBuildingEntry({THREE,visual,instance:item,metresPerCell:M});group.userData.buildingEntry=entry;group.userData.residentialWindows=windows;group.userData.roomReveals=roomReveals;if(entry)buildingEntries.push(entry);else bodies.push(...(item.collision?.worldBodies||[]));group.userData.streetLighting=streetLighting.prepare(visual,item);glass.prepare(visual);carBodies.push(...(item.collision?.worldBodies||[]));instances.push(group);loaded++}
 stableEntryLights=createStableEntryLights(THREE,buildingEntries,scene);
 updateBuildingEntries(0);driveAllowed=createCarWorld(topology,carBodies,M);
 const buildings=records(bld),select=$('district'),old=select.value;select.replaceChildren(new Option('Выбрать здание…',''));const byType=new Map();for(const item of buildings){const key=item.district||item.assetId||item.id;if(!byType.has(key))byType.set(key,item)}for(const [key,item] of byType){select.add(new Option(key,item.id))}select.value=old;
 select.onchange=()=>focus(buildings.find(x=>x.id===select.value));if(!revision&&buildings.length)focus(buildings[0]);revision=nextRevision;lastLoadAt=Date.now();
 $('status').textContent=`Установлено ${loaded} 3D-объектов: ${buildings.length} зданий, ${records(dec).length} элементов декора. ${failed?'Ошибок загрузки: '+failed+'.':'Хеши загруженных моделей проверены.'}`;
 document.body.dataset.buildingDoorsGlass=JSON.stringify(instances.map(g=>g.userData.doorsGlass?.report).filter(Boolean));document.body.dataset.residentialWindows=JSON.stringify({buildings:instances.filter(g=>g.userData.residentialWindows).length,windows:instances.reduce((n,g)=>n+(g.userData.residentialWindows?.report.windows||0),0),cache:residentialWindowCacheStats()});document.body.dataset.rebuildProof=JSON.stringify({loaded,planned:all.length,buildings:buildings.length,decor:records(dec).length,failed,mode:'isolated_walk_preview',pendingHost:top.pendingHostSnapshot!==false});
 }catch(error){fail(error.message);$('status').textContent='Ожидаем проверенные файлы расстановки. Последняя сцена сохранена.'}finally{busy=false}}
$('reload').onclick=refresh;
$('night-toggle').onclick=()=>{environmentNight=environmentNight?0:1;const night=!!environmentNight;$('night-toggle').setAttribute('aria-pressed',String(night));$('night-toggle').textContent=night?'Вернуть дневной свет':'Вечерний свет';ambient.intensity=night?.20:.8;sun.intensity=night?.12:1.7;scene.environmentIntensity=night?.18:.45;scene.background.set(night?'#1b2937':'#bfd1d6');scene.fog.color.copy(scene.background)};
function setWalking(enabled){walking=enabled;$('walk').setAttribute('aria-pressed',String(walking));controls.enablePan=!walking;$('cross').style.display='none';if(walking&&hero){const shift=hero.object.position.clone().add(new THREE.Vector3(0,postureEyeHeight(),0)).sub(controls.target);controls.target.add(shift);camera.position.add(shift)}}
 $('walk').onclick=()=>{if(!occupiedSeat&&!transition&&!jump&&!heroBlast)setWalking(!walking)};
function arsenalOpen(){return weaponHud?.isOpen()??false}
function disposeWeapon(model){
 if(!model)return;model.removeFromParent();const geometries=new Set(),materials=new Set();model.traverse(node=>{if(node.geometry)geometries.add(node.geometry);for(const material of Array.isArray(node.material)?node.material:node.material?[node.material]:[])materials.add(material)});for(const geometry of geometries)geometry.dispose();for(const material of materials)material.dispose();
}
function updateWeaponUi(){
 weaponHud?.setState({weaponId:currentWeapon.id,...fireState(),disabled:!!occupiedSeat||!!transition});
 document.body.dataset.heroWeapon=JSON.stringify({id:currentWeapon.id,label:currentWeapon.label,family:currentWeapon.family,twoHanded:currentWeapon.twoHanded,visualOnly:true});
}
function equipWeapon(id){
 const next=ARSENAL.find(item=>item.id===id);if(!next||occupiedSeat||transition||jump||heroBlast)return false;
 artistInput.cancel();releaseWeapon();hero?.mountWeapon(null);disposeWeapon(weaponModel);weaponModel=null;currentWeapon=next;
 if(id!=='none')lastWeaponId=id;
 if(hero&&id!=='none'){weaponModel=createWeaponModel({THREE,id});hero.mountWeapon(weaponModel)}
 updateWeaponUi();setArsenalOpen(false);return true;
}
function setArsenalOpen(open){
 weaponHud?.setOpen(!!open&&!occupiedSeat&&!transition&&!jump&&!heroBlast);
}
function initArsenal(){
 weaponHud=createWeaponHud({document,host:$('weapon-hud'),arsenal:ARSENAL,onSelect:equipWeapon,onOpenChange(open){if(open){releaseControls();setFreeMouse(false);if(document.pointerLockElement)document.exitPointerLock()}}});
 document.addEventListener('pointerdown',e=>{if(arsenalOpen()&&!$('weapon-hud').contains(e.target))setArsenalOpen(false)});updateWeaponUi();
}
initArsenal();
const quickWeaponKey=createWeaponQuickKey({enabled:()=>!!hero&&!occupiedSeat&&!transition&&!jump&&!heroBlast&&!busy&&$('scene-menu').hidden,onTap(){if(arsenalOpen()){setArsenalOpen(false);return}if(currentWeapon.id!=='none')equipWeapon('none');else if(lastWeaponId)equipWeapon(lastWeaponId);else setArsenalOpen(true)},onHold(){setArsenalOpen(true)}});
addEventListener('keyup',e=>{if(e.code==='KeyQ'){e.preventDefault();quickWeaponKey.up()}});
addEventListener('blur',()=>quickWeaponKey.cancel());document.addEventListener('visibilitychange',()=>{if(document.hidden)quickWeaponKey.cancel()});
const keys=new Set();addEventListener('keydown',e=>{if(/INPUT|SELECT|TEXTAREA/.test(e.target.tagName)||arsenalOpen())return;if(['KeyW','KeyA','KeyS','KeyD','ShiftLeft','ShiftRight'].includes(e.code)){buildingQaMove=null;keys.add(e.code);if(walking)e.preventDefault()}});addEventListener('keyup',e=>{keys.delete(e.code);if(e.code==='KeyE')buildingKeyConsumed=false});addEventListener('blur',()=>keys.clear());
addEventListener('keydown',e=>{
 if(/INPUT|SELECT|TEXTAREA/.test(e.target.tagName))return;
 if(e.code==='KeyQ'){e.preventDefault();quickWeaponKey.down(e.repeat);return}
 if(arsenalOpen()){if(e.code==='Escape'){e.preventDefault();setArsenalOpen(false)}return}
 if((e.code==='ControlLeft'||e.code==='ControlRight')&&!e.repeat){e.preventDefault();setHeroPosture(heroPosture.target==='crouch'?'stand':'crouch');return}
 if(e.code==='KeyZ'&&!e.repeat){e.preventDefault();setHeroPosture(heroPosture.target==='prone'?'stand':'prone');return}
 if(e.code==='KeyE'){
  e.preventDefault();
  if(e.repeat&&buildingKeyConsumed)return;
  if(!e.repeat&&interactWithBuilding())return;
  if(!$('scene-menu').hidden||jump||busy)return;
  keys.add(e.code);
 }
 if(e.code==='Space'){e.preventDefault();if(!e.repeat&&!keys.has('Space'))beginJump(e.timeStamp);keys.add(e.code)}
 if(e.code==='KeyC'){restoreBuildingCamera();followCarCamera=true;if(!occupiedSeat&&hero){const back=new THREE.Vector3(0,2.8,-6).applyAxisAngle(new THREE.Vector3(0,1,0),hero.object.rotation.y);controls.target.copy(hero.object.position).y=hero.object.position.y+postureEyeHeight();camera.position.copy(hero.object.position).add(back)}}
 if(e.code==='Escape'){$('scene-menu').hidden=true;setArsenalOpen(false);setFreeMouse(false);if(document.pointerLockElement)document.exitPointerLock();releaseControls()}
});
function beginJump(pressTime=performance.now()){ 
 if(artistSwimming()||artistBusy()||artistAction.action.type!=='none')return;
 if(!hero||!walking||occupiedSeat||transition||heroBlast||busy||(!jump&&surfaceMotion.state?.grounded===false)||!$('scene-menu').hidden)return;
 if(heroPosture.value>.001){if(!setHeroPosture('stand'))animationQaJumpPending=false;return}
 const forward=controls.target.clone().sub(camera.position);
 const direction=jumpDirection(forward,{forward:keys.has('KeyW'),back:keys.has('KeyS'),left:keys.has('KeyA'),right:keys.has('KeyD')});
 if(jump){const diveDirection=Math.hypot(direction.x,direction.z)?direction:jump.directional?{x:jump.dx,z:jump.dz}:jumpDirection(forward,{forward:true});const next=tryDiveJump(jump,diveDirection,pressTime);if(next!==jump){jump=next;hero.object.rotation.y=Math.atan2(jump.dx,jump.dz)}return;}buildingQaMove=null;jump={...launchJump(hero.object.position,direction,{startedAt:pressTime}),baseY:groundHeight(hero.object.position.x,hero.object.position.z)};jumpCount++;entryHeld=0;pointerHeld=false;hero.reset();
 if(jump.directional)hero.object.rotation.y=Math.atan2(direction.x,direction.z);
 for(const id of ['district','walk','reload'])$(id).disabled=true;
}
function updateJump(dt){
 const bodyHeight=hero.height||1.9,allowed=(x,z)=>pedestrianAllowed(x,z)&&groundHeight(x,z)<=hero.object.position.y+.28&&ceilingHeight(x,z)>=hero.object.position.y+bodyHeight-.03;
 jump=stepJump(jump,dt,allowed);const floor=groundHeight(jump.x,jump.z);jump=resolveJumpSurface(jump,{floor,ceiling:ceilingHeight(jump.x,jump.z),bodyHeight,previousY:hero.object.position.y,dt,flightTime:JUMP.flight});const worldY=jump.worldY;hero.object.position.set(jump.x,worldY,jump.z);const pose={...jump};
 document.body.dataset.heroJump=JSON.stringify({...jump,count:jumpCount});
 if(jump.done){surfaceMotion.reset(hero.object.position,{grounded:worldY<=floor+.02,velocityY:jump.falling?jump.fallVelocity:0});jump=null;for(const id of ['district','walk','reload'])$(id).disabled=false;}
 return pose;
}
const releaseControls=()=>{artistInput.cancel();keys.clear();entryHeld=0;pointerHeld=false;buildingKeyConsumed=false;buildingQaMove=null;animationQaMoveUntil=0;animationQaMoveDirection=null;animationQaJumpPending=false;releaseWeapon()};addEventListener('blur',releaseControls);document.addEventListener('visibilitychange',()=>{if(document.hidden)releaseControls()});
renderer.domElement.addEventListener('contextmenu',e=>e.preventDefault());
// Pointer down/up describes the first/last held mouse button, so a second
// button in the RMB+LMB chord must use mouse down/up instead.
renderer.domElement.addEventListener('mousedown',e=>{if(currentWeapon.id==='none'){if(!artistAllowed())return;if(heroPosture.value>.001){setHeroPosture('stand');return;}if(e.button===2){e.preventDefault();artistInput.block(true);}if(e.button===0)artistAction=artistInput.press(artistMeleeContext());return;}if(!combatAllowed())return;if(e.button===2){e.preventDefault();aiming=true;setFreeMouse(true)}if(e.button===0){triggerHeld=true;triggerPressed=true}});
document.addEventListener('mouseup',e=>{if(e.button===0){triggerHeld=false;artistAction=artistInput.release(artistMeleeContext());}if(e.button===2){aiming=false;artistInput.block(false);}});
renderer.domElement.addEventListener('lostpointercapture',()=>artistInput.release({time:performance.now()/1000,cancelled:true}));
renderer.domElement.addEventListener('pointercancel',()=>artistInput.cancel());
document.addEventListener('pointermove',e=>{if(e.pointerType==='mouse'&&Number.isInteger(e.buttons)&&!(e.buttons&1))artistInput.release({time:performance.now()/1000,cancelled:true});});
renderer.domElement.addEventListener('pointercancel',releaseWeapon);
addEventListener('keydown',e=>{if(e.code==='KeyR'&&!e.repeat&&combatAllowed()&&!/INPUT|SELECT|TEXTAREA/.test(e.target.tagName)){e.preventDefault();reloadPressed=true}});
let orbitActive=false;controls.addEventListener('start',()=>{orbitActive=true;followCarCamera=false});controls.addEventListener('end',()=>{orbitActive=false});
let freeMouseLook=true,mouseOnScene=false,edgeTurn=0;
function setFreeMouse(enabled){freeMouseLook=enabled;controls.enabled=!enabled;controls.enableDamping=!enabled;edgeTurn=0;renderer.domElement.style.cursor=enabled?'none':'default';$('camera-help').textContent=enabled?'Мышь без кнопок — камера · Esc — курсор · колесо — приближение · C — за спину':'Клик по сцене — свободная камера мышью';document.body.dataset.mouseLook=enabled?'free':'cursor'}
function turnCamera(dx,dy){restoreBuildingCamera();followCarCamera=false;const spherical=new THREE.Spherical().setFromVector3(camera.position.clone().sub(controls.target));spherical.theta-=dx;spherical.phi=THREE.MathUtils.clamp(spherical.phi-dy,.2,Math.PI*(aiming?.92:.48));camera.position.copy(controls.target).add(new THREE.Vector3().setFromSpherical(spherical));camera.lookAt(controls.target);document.body.dataset.cameraOrbit=JSON.stringify({theta:spherical.theta,phi:spherical.phi,mode:document.pointerLockElement?'locked':'free'})}
$('menu-toggle').onclick=()=>{$('scene-menu').hidden=!$('scene-menu').hidden;setFreeMouse(false);releaseControls()};
renderer.domElement.addEventListener('click',()=>{setFreeMouse(true);if(!document.pointerLockElement&&renderer.domElement.requestPointerLock){try{renderer.domElement.requestPointerLock()?.catch(()=>setFreeMouse(true))}catch{setFreeMouse(true)}}});
document.addEventListener('pointerlockchange',()=>{const locked=document.pointerLockElement===renderer.domElement;setFreeMouse(locked);orbitActive=false;followCarCamera=false;if(!locked)releaseControls()});
renderer.domElement.addEventListener('mouseenter',()=>{mouseOnScene=true;edgeTurn=0});renderer.domElement.addEventListener('mouseleave',()=>{mouseOnScene=false;edgeTurn=0});
document.addEventListener('mousemove',e=>{const locked=document.pointerLockElement===renderer.domElement;if(!freeMouseLook||(!locked&&e.target!==renderer.domElement))return;const rect=renderer.domElement.getBoundingClientRect();edgeTurn=locked?0:e.clientX<rect.left+22?1:e.clientX>rect.right-22?-1:0;turnCamera(THREE.MathUtils.clamp(e.movementX,-80,80)*.004,THREE.MathUtils.clamp(e.movementY,-80,80)*.003)});
renderer.domElement.addEventListener('wheel',e=>{if(!freeMouseLook)return;e.preventDefault();restoreBuildingCamera();const offset=camera.position.clone().sub(controls.target),length=THREE.MathUtils.clamp(offset.length()*Math.exp(e.deltaY*.001),controls.minDistance,16);camera.position.copy(controls.target).add(offset.setLength(length))},{passive:false});
setFreeMouse(true);
// Visible, opt-in QA controls exercise the same input state as held mouse buttons.
if(new URLSearchParams(location.search).get('weaponqa')==='1'){
 const panel=document.createElement('div');panel.style.cssText='position:absolute;top:10px;left:10px;z-index:5;background:#142b32;padding:8px';
 const aimButton=document.createElement('button');aimButton.textContent='QA: удерживать прицел';aimButton.onclick=()=>{if(combatAllowed()){aiming=!aiming;setFreeMouse(false)}};
 const fireButton=document.createElement('button');fireButton.textContent='QA: очередь 1 с';fireButton.onclick=()=>{if(combatAllowed()){triggerHeld=true;triggerPressed=true;setTimeout(()=>{triggerHeld=false},1000)}};
 panel.append(aimButton,fireButton);document.body.append(panel);
}
if(new URLSearchParams(location.search).get('animationqa')==='1'){
 const panel=document.createElement('div'),status=document.createElement('div'),weaponQa=new URLSearchParams(location.search).get('weaponqa')==='1';panel.id='animation-qa';panel.style.cssText=`position:absolute;top:${weaponQa?58:10}px;left:10px;z-index:6;display:flex;flex-wrap:wrap;gap:6px;max-width:520px;padding:8px;border:1px solid #d7b85e;border-radius:8px;background:#142b32ee;color:#fff1bd`;status.style.cssText='flex-basis:100%;font-weight:700';status.textContent='Animation QA · stand';
 const button=(label,action)=>{const node=document.createElement('button');node.type='button';node.textContent=label;node.onclick=()=>{action();status.textContent=`Animation QA · ${heroPosture.target}`};return node};
 panel.append(status,button('Стоять',()=>setHeroPosture('stand')),button('Присесть',()=>setHeroPosture('crouch')),button('Лечь',()=>setHeroPosture('prone')),button('Ползти 2 с',startAnimationQaCrawl),button('Прыжок',()=>{animationQaJumpPending=heroPosture.value>.001;beginJump()}),button('Вид спереди',()=>{if(!hero)return;setFreeMouse(false);controls.target.copy(hero.object.position).y+=.65;camera.position.copy(hero.object.position).add(new THREE.Vector3(2,1.25,3).applyAxisAngle(new THREE.Vector3(0,1,0),hero.object.rotation.y));camera.lookAt(controls.target);}),button('Перезарядить',()=>{if(combatAllowed())reloadPressed=true;}),button('Удар ЛКМ',()=>{if(!artistAllowed()||currentWeapon.id!=='none')return;artistAction=artistInput.press(artistMeleeContext());setTimeout(()=>{artistAction=artistInput.release(artistMeleeContext());},180);}));document.body.append(panel);
}
function startAnimationQaCrawl(){
 if(!setHeroPosture('prone')&&heroPosture.target!=='prone')return;const forward=controls.target.clone().sub(camera.position);forward.y=0;if(!forward.lengthSq())forward.set(0,0,1);forward.normalize();const right=new THREE.Vector3(-forward.z,0,forward.x),origin=hero.object.position;
 animationQaMoveDirection=[forward,right,right.clone().negate(),forward.clone().negate()].find(direction=>circleFits(origin.x+direction.x*.8,origin.z+direction.z*.8,pedestrianAllowed))||forward;animationQaMoveUntil=performance.now()+2600;
}
const clock=new THREE.Clock();let lastCull=0,lastStats=0;
function moveHeroOnFoot(delta){
 const before=hero.object.position.clone(),grounded=surfaceMotion.state?.grounded!==false,allowed=(x,z)=>pedestrianAllowed(x,z)&&(!grounded||surfaceMotion.canMove(before,{x,z},groundHeight)),result=movePedestrian(before,delta,allowed);
 if(result.moved){hero.object.position.set(result.x,before.y,result.z);const shift=hero.object.position.clone().sub(before);hero.object.rotation.y=Math.atan2(shift.x,shift.z);controls.target.add(shift);camera.position.add(shift)}
 return result.moved;
}
function frame(){requestAnimationFrame(frame);const dt=Math.min(clock.getDelta(),.04)*(exitQaMode?(exitQaPaused?0:.25):1);if(document.hidden)return;
 restoreBuildingCamera();updateBuildingEntries(dt);
 if(hero&&!occupiedSeat&&!transition&&!jump&&!heroBlast)postureMotion=stepHeroPosture(heroPosture,dt,{canOccupyHeight:height=>canOccupyPostureHeight(height)});
 if(animationQaJumpPending&&!jump&&heroPosture.value<=.001){animationQaJumpPending=false;beginJump()}
 crashPartner?.update(dt);
 artistAction=artistInput.step(artistMeleeContext());
 let moved=false,carStepped=false;const running=keys.has('ShiftLeft')||keys.has('ShiftRight'),qaCrawl=performance.now()<animationQaMoveUntil;
 if(car&&(!transition||transition.exiting)){
  const seated=!!occupiedSeat&&!transition,controlled=canControlVehicle(occupiedSeat)&&!artistBusy()&&!transition&&!carDamage?.disabled&&!carRollover?.unstable,detached=!occupiedSeat&&transition?.phase!=='door',old=car.object.position.clone();
  const input=controlled?inputForVehicleSeat(occupiedSeat,{forward:keys.has('KeyW'),reverse:keys.has('KeyS'),left:keys.has('KeyA'),right:keys.has('KeyD'),handbrake:keys.has('Space')}):{};
  if(carDamage?.disabled||carRollover?.unstable)carState={...carState,speed:0,yawRate:0};carState.tyreEffects=tyres?.effects;const before=carState;
  carState=stepCar(carState,input,dt,crashPartner?crashPartner.blockingWorld(detached?unattendedAllowed:driveAllowed):(detached?unattendedAllowed:driveAllowed));car.object.position.set(carState.x,0,carState.z);car.object.rotation.y=carState.yaw;if(carState.contact?.otherVehicle)crashPartner?.resolve(before,carState,carState.contact);else{carDamage?.collision(before,carState);if(carState.contact)carRollover?.impact(carState.contact,carState.yaw);}carRollover?.update(dt);
  tyres?.update(carState,dt);carStepped=true;
  if(seated){
   const shift=car.object.position.clone().sub(old);controls.target.add(shift);camera.position.add(shift);controls.minDistance=7;controls.target.lerp(carLocal(0,2,1),1-Math.exp(-5*dt));
   if(!orbitActive&&followCarCamera)camera.position.lerp(carLocal(.7,-9-Math.abs(carState.speed)*.08,4),1-Math.exp(-3*dt));
   const anchor=vehicleSeat(occupiedSeat).anchor;car.object.updateWorldMatrix(true,false);const seat=car.object.localToWorld(new THREE.Vector3(anchor.side,anchor.y,anchor.front));hero.object.position.copy(seat);hero.object.quaternion.copy(car.object.quaternion);
  }
  car.update(carState,controlled&&keys.has('KeyS'));
 }
 if(tyres&&!carStepped)tyres.update({...carState,distance:0},dt);carDamage?.update(dt);blastResponse?.update();
 if(!occupiedSeat&&!transition&&!jump&&!heroBlast&&!artistBusy()&&artistAction.action.type!=='dropkick'&&entryHeld===0&&walking&&(keys.size||qaCrawl)&&hero){const forward=controls.target.clone().sub(camera.position);forward.y=0;forward.normalize();const right=new THREE.Vector3().crossVectors(forward,new THREE.Vector3(0,1,0));const delta=new THREE.Vector3();if(keys.has('KeyW'))delta.add(forward);if(qaCrawl&&animationQaMoveDirection)delta.add(animationQaMoveDirection);if(keys.has('KeyS'))delta.sub(forward);if(keys.has('KeyD'))delta.add(right);if(keys.has('KeyA'))delta.sub(right);if(delta.lengthSq())delta.normalize().multiplyScalar(dt*(artistSwimming()?(running?3.4:2)*hero.scale:postureMotion.maxSpeed));moved=moveHeroOnFoot(delta)}
 if(buildingQaMove&&hero&&!occupiedSeat&&!transition&&!jump&&!heroBlast&&!artistBusy()&&artistAction.action.type!=='dropkick'){const qa=buildingQaMove;qa.elapsed+=dt;const delta=qa.target.clone().sub(hero.object.position);delta.y=0;const distance=delta.length();if(distance<.04){if(qa.remaining.length){qa.target=qa.remaining.shift();qa.elapsed=0}else buildingQaMove=null}else if(qa.elapsed>20)buildingQaMove=null;else moved=moveHeroOnFoot(delta.setLength(Math.min(distance,dt*postureMotion.maxSpeed)))||moved}
 if(hero&&!occupiedSeat&&!transition&&!jump&&!heroBlast){if(!surfaceMotion.state)surfaceMotion.reset(hero.object.position);const before=hero.object.position.clone(),supported=surfaceMotion.update({x:before.x,z:before.z,dt,floorHeight:groundHeight});hero.object.position.set(supported.x,supported.y,supported.z);const shift=hero.object.position.clone().sub(before);controls.target.add(shift);camera.position.add(shift)}
 if(heroBlast&&hero){const old=hero.object.position.clone(),allowed=(x,z)=>canWalk(x,z)&&(heroBlastSource===car||!carOverlapsCircle(carState,x,z,.58))&&(!crashPartner||heroBlastSource===crashPartner.car||!crashPartner.overlaps(x,z,.58));heroBlast=stepBlastKnockback(heroBlast,dt,allowed,{groundHeight,ceilingHeight:(x,z)=>buildingEntries.find(e=>e.containsInterior({x,z}))?.ceilingHeight({x,z})});hero.object.position.set(heroBlast.x,heroBlast.y,heroBlast.z);hero.object.rotation.set(0,heroBlast.heading,0);const shift=hero.object.position.clone().sub(old);controls.target.add(shift);camera.position.add(shift);if(heroBlast.done){heroBlast=null;heroBlastSource=null;hero.reset();resetFootSupport();}}
 if(artistAction.action.type==='dropkick'&&artistAction.start){
  const attack=artistAction.start,age=performance.now()/1000-attack.time,ease=THREE.MathUtils.smoothstep;
  if(artistDropId!==attack.id){artistDropId=attack.id;artistDropDistance=0;jump=null;for(const id of ['district','walk','reload'])$(id).disabled=false;surfaceMotion.reset(hero.object.position,{grounded:false});}
  const distance=(2.8*ease(age,0,.34)+.35*ease(age,.34,.58))*hero.scale,delta=Math.max(0,distance-artistDropDistance);artistDropDistance=distance;
  moveHeroOnFoot(new THREE.Vector3(Math.sin(attack.yaw)*delta,0,Math.cos(attack.yaw)*delta));hero.object.rotation.y=attack.yaw;hero.object.position.y=groundHeight(hero.object.position.x,hero.object.position.z)+attack.airHeight*(1-ease(age,.10,.65));
 }
 const jumpFrame=jump?updateJump(dt):null;
 updateCarInteraction(dt);
 tireTracks.update(carState,dt);
 if(weaponModel)weaponModel.visible=!occupiedSeat&&!transition;
 if(jump)$('drive-status').textContent=jump.elapsed<JUMP.flight?(jump.mode==='dive'?'Max Payne':jump.directional?'Обычный прыжок в сторону':'Прыжок вверх'):'Приземление…';
 if(!occupiedSeat&&hero&&!savedCameraOffset){controls.minDistance=3;const offset=new THREE.Vector3(hero.object.position.x,hero.object.position.y+postureEyeHeight(),hero.object.position.z).sub(controls.target);controls.target.add(offset);camera.position.add(offset)}
 if(freeMouseLook&&mouseOnScene&&edgeTurn&&document.hasFocus())turnCamera(-edgeTurn*dt*1.1,0);
 controls.update();updateAimCamera(dt);clampBuildingCamera();const combat=updateCombat(dt);
 if(hero&&!transition){
  if(heroBlast)hero.tumblePose(heroBlast.progress,heroBlast.rolls);else if(occupiedSeat)hero.vehiclePose(1,0,{driver:canControlVehicle(occupiedSeat),steeringGrips:car.getSteeringGrips(),steer:carState.steer,dt});
  else if(jumpFrame){const armed=currentWeapon.id==='none'?null:currentWeapon,aim=combat.active?combat.aim:{aimYaw:hero.object.rotation.y,aimPitch:0,recoil:combat.recoil.normalized,recoilYaw:combat.recoil.recoilYaw};hero.jumpPose(jumpFrame.progress,jumpFrame.mode==='dive'&&jumpFrame.directional,armed,aim)}
  else {if(combat.active)hero.object.rotation.y=combat.aim.aimYaw;hero.update(dt,moved,running,currentWeapon.id==='none'?null:currentWeapon,combat.active?combat.aim:{}, {posture:heroPosture,reloadProgress:combat.reloadProgress,action:artistAction.action})}
 }
 artistUpdate(dt,moved,running);emitCombatShots(combat);glass.update(dt);const now=performance.now();if(now-lastCull>250){for(const node of instances)node.visible=node.position.distanceToSquared(controls.target)<220*220;sun.position.copy(controls.target).add(new THREE.Vector3(-75,130,90));sun.target.position.copy(controls.target);lastCull=now}stableEntryLights?.update();streetLighting.update({focus:hero?.object.position||controls.target,night:environmentNight});renderer.render(scene,camera);updateCarPrompt();updateBuildingPrompt();
 if(now-lastStats>1000){document.body.dataset.vehicleDamage=JSON.stringify(carDamage?.stats()||{});document.body.dataset.tyreDamage=JSON.stringify(tyres?.stats()||{});document.body.dataset.streetLighting=JSON.stringify(streetLighting.stats());document.body.dataset.surfaceMotion=JSON.stringify(surfaceMotion.state);document.body.dataset.glassBreakage=JSON.stringify(glass.stats())}
 if(now-lastStats>1000){
  document.body.dataset.tireTracks=JSON.stringify({active:tireTracks.pool.active,count:tireTracks.pool.count});
  $('stats').textContent=`${hero?'Персонаж Художника 13 · ':''}Вызовы отрисовки: ${renderer.info.render.calls} · r ${Math.round(controls.target.z/M)}, c ${Math.round(controls.target.x/M)}`;
  if(hero){
   document.body.dataset.heroWalk=JSON.stringify({loaded:true,x:hero.object.position.x,y:hero.object.position.y,z:hero.object.position.z,moving:moved,running,mode:'isolated_walk',height:postureMotion.height,eyeHeight:postureMotion.eyeHeight,posture:heroPosture.target,postureValue:heroPosture.value,postureBlocked:postureMotion.blocked});
   const current=buildingEntries.find(entry=>entry.containsInterior(hero.object.position));
   document.body.dataset.buildingEntry=JSON.stringify({count:buildingEntries.length,inside:current?.instance.id||null,floorY:groundHeight(hero.object.position.x,hero.object.position.z),heroY:hero.object.position.y,cameraClamped:!!cameraBeforeBuildingClamp,doors:buildingEntries.map(entry=>entry.report)});
   if($('building-qa-status'))$('building-qa-status').textContent=`${current?'Внутри комнаты':'Снаружи'} · пол ${groundHeight(hero.object.position.x,hero.object.position.z).toFixed(2)} · герой ${hero.object.position.y.toFixed(2)} · ${buildingQaMove?'идёт':'стоит'} · камера ${cameraBeforeBuildingClamp?'перед стеной':'свободна'}`;
  }
  lastStats=now;
 }
}
addEventListener('resize',()=>{camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight)});
addEventListener('pagehide',()=>{quickWeaponKey.cancel();weaponHud?.dispose();carQa?.dispose();clearContent({recreate:false});tyres?.dispose();carDamage?.dispose();artistSurface?.dispose();effects.dispose();crashPartner?.dispose();blastResponse?.dispose();tireTracks.dispose()},{once:true});
async function start(){await refresh();if(!topology)return;try{hero=await loadHeroWalker({THREE,loader,targetHeight:1.9});scene.add(hero.object);artistSurface=createArtist14Surface({THREE,context:hero.artistContext(),scene,applySwim:(sample,ctx)=>{if(occupiedSeat||transition||jump||heroBlast)return;if(sample.blend>0)ctx.object.position.y=groundHeight(ctx.object.position.x,ctx.object.position.z)+sample.liftWorld;artistPose.swim(sample,ctx);},applyReaction:(sample,ctx)=>{if(!occupiedSeat&&!transition&&!heroBlast)artistPose.reaction(sample,ctx);}});focus(instances[0]?.userData.instance);setWalking(true);$('walk').textContent='Управлять персонажем';initCar();equipWeapon(currentWeapon.id);initBuildingQa();}catch(e){fail('Персонаж не загружен: '+e.message)}}
start();frame();setInterval(()=>{if(!document.hidden&&!busy&&!occupiedSeat&&!transition&&!jump&&!heroBlast&&!aiming&&!triggerHeld&&!savedCameraOffset&&Math.abs(carState?.speed||0)<.01)refresh()},15000);
