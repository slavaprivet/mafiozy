import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createHeroWalker} from './hero_walk.mjs';
import {ARSENAL,createWeaponModel} from './hero_arsenal.mjs';
import {createArtistVehicle,ARTIST_VEHICLE_PROFILES} from './vehicle_fleet_models.mjs';
import {createDemoCar} from './car_drive.mjs';
import {VEHICLE_SEATS} from './vehicle_seats.mjs';
import {weaponHeadClearance} from './hero_weapon_clearance.mjs';
import {vehicleWindowFrame,planVehicleWindowShot,applyVehicleWindowPose,setVehicleWindowOpen} from './vehicle_window_fire.mjs';
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c);}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
class Box extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
async function glb(url){const b=fs.readFileSync(new URL(url,import.meta.url));return(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene;}
const heroes=[];for(const model of ['player_male.8130dfb1f7eb.glb','player_female.298d50e6244a.glb'])heroes.push({model,hero:createHeroWalker({THREE,scene:await glb('./hero_models/'+model)})});
let cases=0,allowed=0,rejected=0,maxGripError=0,maxBoneShift=0,sedanDirectAllowed=0;const report=[];
for(const profile of [...ARTIST_VEHICLE_PROFILES,{id:'legacy_demo'}]){
 const car=profile.id==='legacy_demo'?Object.assign(createDemoCar(THREE,Box),{seats:VEHICLE_SEATS}):createArtistVehicle(THREE,Box,await glb('./models/artist_vehicle_pack/'+profile.id+'.glb'),profile.id);let carAllowed=0,carRejected=0;
 for(const {model,hero}of heroes){const c=hero.artistContext();
 for(const seat of car.seats){const frame=vehicleWindowFrame(THREE,car,seat.id);assert.ok(frame,'own window aperture available');
 const door=car.doors.get(seat.id)||car.doors.get(seat.id==='front_left'?1:-1);let pane=door.getObjectByName('Fitted_door_glass_'+seat.id);if(!pane)door.traverse(n=>{if(!pane&&n.isMesh&&n.material?.transparent)pane=n});const original=pane.visible;
 setVehicleWindowOpen(car,seat.id,true);assert.equal(pane.visible,false);setVehicleWindowOpen(car,seat.id,true);
 for(const angle of profile.id==='compact_sedan'?[0,-.35,.35]:[0])for(const {id}of ARSENAL.filter(w=>w.id!=='none')){
 const weapon=createWeaponModel(THREE,id);hero.mountWeapon(weapon);
 for(const yaw of profile.id==='compact_sedan'?[0,1.1]:[.7]){
 car.object.position.set(12,.3,9);car.object.rotation.set(0,yaw,0);car.object.updateMatrixWorld(true);
 hero.object.position.copy(car.object.localToWorld(new THREE.Vector3(seat.anchor.side,seat.anchor.y,seat.anchor.front)));hero.object.quaternion.copy(car.object.getWorldQuaternion(new THREE.Quaternion()));if(car.poseOccupant)car.poseOccupant(hero,seat.id,{steer:.2,dt:1/60});else hero.vehiclePose(1,0,{driver:seat.canDrive,steeringGrips:car.getSteeringGrips(),steer:.2,dt:1/60});
 const pinned=['thigh_l','thigh_r','shin_l','shin_r','foot_l','foot_r'].map(n=>c.worldPosition(n)),root=hero.object.position.clone(),boneLengths=Object.entries(c.bones).map(([n,b])=>[n,b.matrix.elements.slice()]);
 const aim=new THREE.Vector3(seat.side*Math.cos(angle),0,Math.sin(angle)).applyQuaternion(car.object.quaternion);
 const plan=planVehicleWindowShot({vehicleState:{yaw,speed:yaw?18:0},seatId:seat.id,aimDirection:aim,weaponId:id,frame});assert.ok(plan.allowed);
 assert.equal(planVehicleWindowShot({vehicleState:{yaw},seatId:seat.id,aimDirection:aim.clone().negate(),weaponId:id,frame}).allowed,false,'opposite passenger/cabin blocked');
 const out=applyVehicleWindowPose(THREE,c,{plan,car,weapon});assert.ok(out.applied);
 for(const [i,n]of ['thigh_l','thigh_r','shin_l','shin_r','foot_l','foot_r'].entries()){const shift=c.worldPosition(n).distanceTo(pinned[i]);maxBoneShift=Math.max(maxBoneShift,shift);assert.ok(shift<1e-7,'seated lower body fixed');}assert.ok(hero.object.position.distanceTo(root)<1e-9);
 for(const [n,elements]of boneLengths){const a=new THREE.Vector3(),b=new THREE.Vector3(),q=new THREE.Quaternion();c.bones[n].matrix.decompose(a,q,b);const rp=new THREE.Vector3(),rs=new THREE.Vector3();new THREE.Matrix4().fromArray(elements).decompose(rp,q,rs);assert.ok(a.distanceTo(rp)<1e-7&&b.distanceTo(rs)<1e-6,'no bone translation or scale changes');}
 const grips=[[out.shootingHand,[0,-.13,-.02]],...(weapon.userData.twoHanded?[['l',weapon.userData.supportGrip]]:[])];
 for(const [s,p]of grips){const error=c.worldPosition('socket_hand_'+s).distanceTo(weapon.localToWorld(new THREE.Vector3(...p)));maxGripError=Math.max(maxGripError,error);if(out.reachable)assert.ok(error<.003,'authored grip retained');}
 if(out.canFire){allowed++;carAllowed++;assert.ok(out.outside&&out.ownCarClear&&out.selfClear);assert.ok(weaponHeadClearance(THREE,c,weapon,{origin:out.gunPosition,quaternion:weapon.getWorldQuaternion(new THREE.Quaternion())}).clear);assert.ok(out.direction.dot(aim)>.999999,'physical barrel agrees with reticle');if(profile.id==='compact_sedan'&&angle===0)sedanDirectAllowed++;}
 else{rejected++;carRejected++;assert.ok(out.reason.length>0,'blocked angle has a player-readable hint');}
 cases++;
 }
 }
 setVehicleWindowOpen(car,seat.id,false);assert.equal(pane.visible,original,'restore original glass state');
 }
 }
 report.push({car:profile.id,allowed:carAllowed,rejected:carRejected});
}
assert.ok(sedanDirectAllowed>=200,'sedan supports all firearm families on both sides');
assert.equal(planVehicleWindowShot({}).allowed,false);assert.equal(applyVehicleWindowPose(THREE,null,{}).canFire,false);
console.log(JSON.stringify({passed:true,cases,allowed,rejected,sedanDirectAllowed,maxGripError,maxBoneShift,report,checks:['all_12_actual_car_GLB','both_actual_hero_GLB','all_14_weapons','every_seat_own_window','stationary_and_moving_transform','yaw_and_side_angles','no_cabin_shots','actual_hull_bore_raycast','head_neck_full_prop_clearance','physical_barrel_direction','hips_legs_root_fixed','no_bone_scale_or_translation','authored_grips','window_visibility_restoration']}));
