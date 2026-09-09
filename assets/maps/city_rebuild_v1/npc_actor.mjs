import {resolveNpcVehicleBinding,applyNpcVehicleBinding} from './npc_vehicle_pose.mjs';
import {createHeroWalker,HERO_ASSET} from './hero_walk.mjs';
import {createArtist14Surface} from './hero_artist14_surface.mjs';
import {createArtist14Pose} from './hero_artist14_pose.mjs';
import {createNpcActivityPose} from './npc_activity_pose.mjs';
import {loadVerifiedGlbBytes} from './verified_glb_bytes.mjs';
import {normalizeNpcLifecycle} from './npc_source_lifecycle.mjs';

export const NPC_ASSETS=Object.freeze({male:HERO_ASSET,female:Object.freeze({url:new URL('./hero_models/player_female.298d50e6244a.glb',import.meta.url).href,bytes:641836,sha256:'298d50e6244a7f17cf9cb66530fc34645fec0f19b575fe99d1df514709e90c40'})});
// Keep loading separate from actor creation: the roster loads once and clones per ID.
export async function loadNpcSources({loader,signal}={}){
 if(!loader)throw Error('NPC GLTFLoader required');
 return Object.fromEntries(await Promise.all(Object.entries(NPC_ASSETS).map(async([sex,asset])=>{
  const bytes=await loadVerifiedGlbBytes({asset,signal});
  const gltf=await loader.parseAsync(bytes,asset.url.slice(0,asset.url.lastIndexOf('/')+1));return [sex,gltf.scene];
 })));
}

// SkeletonUtils.clone must be supplied by the host using its existing THREE version.
// Every GPU resource object is private: disposing one NPC cannot dispose the template,
// another NPC, or a weapon prototype. Texture image pixels may safely remain shared.
// Source GLBs are immutable templates for a population lifetime. Reusing these
// identity-only indexes avoids walking the same template for each spawned actor;
// the clones and every actor-owned resource remain private.
const sourceBoneCache=new WeakMap(),sourceResourceCache=new WeakMap();
function sourceBones(source){let result=sourceBoneCache.get(source);if(result)return result;result=new Set();source.traverse(o=>{if(o.isBone)result.add(o);});sourceBoneCache.set(source,result);return result;}
function skeletonClone(source,cloneSkeleton){
 const clone=cloneSkeleton(source);if(!clone||clone===source)throw Error('NPC requires an independent SkeletonUtils clone');
 const bones=sourceBones(source);
 clone.traverse(o=>{if(o.isSkinnedMesh&&o.skeleton.bones.some(b=>bones.has(b)))throw Error('NPC clone shares source skeleton');});
 return clone;
}
function privateClone(source,cloneSkeleton){
 const clone=skeletonClone(source,cloneSkeleton);
 const geometries=new Map(),materials=new Map(),textures=new Map();
 const materialCopy=m=>{if(materials.has(m))return materials.get(m);const copy=m.clone();materials.set(m,copy);for(const[key,value]of Object.entries(copy))if(value?.isTexture){if(!textures.has(value))textures.set(value,value.clone());copy[key]=textures.get(value);}return copy;};
 clone.traverse(o=>{if(o.geometry){if(!geometries.has(o.geometry))geometries.set(o.geometry,o.geometry.clone());o.geometry=geometries.get(o.geometry);}if(o.material)o.material=Array.isArray(o.material)?o.material.map(materialCopy):materialCopy(o.material);});
 return clone;
}
function resources(root){const result=new Set();root.traverse(o=>{if(o.geometry)result.add(o.geometry);for(const m of Array.isArray(o.material)?o.material:o.material?[o.material]:[]){result.add(m);for(const v of Object.values(m))if(v?.isTexture)result.add(v);}});return result;}
function sourceResources(root){let result=sourceResourceCache.get(root);if(result)return result;result=resources(root);sourceResourceCache.set(root,result);return result;}
const finitePosition=p=>p&&Number.isFinite(p.x)&&Number.isFinite(p.y)&&Number.isFinite(p.z);
const EMPTY_AIM=Object.freeze({}),COWER_POSTURE=Object.freeze({target:'crouch',value:1}),DEATH_BASE_POSTURE=Object.freeze({target:'stand',value:0});
function lifeGesture(life={}){
 const state=[life.state,life.lifeState,life.gesture].filter(Boolean).join(' ').toLowerCase();
 if(life.cuffed||life.arrested||['cuffing','escort','loading','transport','unloading','handoff','prison_escort','booking'].includes(life.arrestPhase))return 'cuffed';
 if(life.surrendering||/surrender/.test(state))return 'surrender';
 if(life.cowering||/cower/.test(state))return 'cower';
 if(life.medicCarry||/medic.?carry/.test(state))return 'carry';
 if(life.helping||/helping|first.?aid|treating/.test(state))return 'help';
 if((life.phoneCalling||/phone|calling/.test(state))&&!life.panic&&!life.fleeing&&!/panic|flee/.test(state))return 'phone';
 if(life.talking||life.social||/talk|social/.test(state))return 'talk';
 return null;
}
function applyLifeGesture(THREE,c,gesture,time,blend){
 const wave=Math.sin(time*4),targets={
  cuffed:[[-.18,2.1,-.38],[.18,2.1,-.38]],
  surrender:[[-.82,4.45,.18],[.82,4.45,.18]],
  cower:[[-.38,3.95,.55],[.38,3.95,.55]],
  carry:[[-.55,2.8,.85],[.55,2.8,.85]],
  help:[[-.42,2.3,.85+wave*.08],[.42,2.3,.85-wave*.08]],
  phone:[null,[.72,4.1,.15]],
  talk:[[-.65,2.8+wave*.12,.62],[.65,3.05-wave*.16,.65]]
 }[gesture];
 if(!targets)return;
 c.rotateAdd('chest',(gesture==='cower'?.16:gesture==='help'?.12:0)*blend,gesture==='talk'?wave*.06*blend:0);
 c.rotateAdd('head',(gesture==='cower'?.15:gesture==='help'?.18:0)*blend,gesture==='phone'?-.12*blend:0);
 c.object.updateMatrixWorld(true);
 for(const [index,side]of ['l','r'].entries())if(targets[index]){
  const goal=c.offset.localToWorld(new THREE.Vector3(...targets[index])),start=c.worldPosition('socket_hand_'+side);
  c.reachPalm(side,start.lerp(goal,blend),c.bones['hand_'+side].getWorldQuaternion(new THREE.Quaternion()));
 }
 c.object.updateMatrixWorld(true);
}

export function createNpcActor({THREE,scene,source,cloneSkeleton,id,sex='male',height=1.9,build='average',applyAppearance,appearanceOwnsResources=false,getVehicle=null}={}){
 if(!THREE||!scene?.isObject3D||!source?.isObject3D||typeof cloneSkeleton!=='function')throw Error('NPC THREE, scene, source and SkeletonUtils.clone required');
 if(id===null||id===undefined||String(id).trim()==='')throw Error('Persistent NPC id required');
 if(!Number.isFinite(height))throw Error('Invalid NPC height');
 const creationStart=performance.now(),creationTimings={};let creationMark=creationStart;
 const persistentId=String(id),targetHeight=Math.max(1.65,Math.min(2.05,height)),appearanceOwns=appearanceOwnsResources===true&&typeof applyAppearance==='function',templateResources=appearanceOwns?sourceResources(source):null,clone=appearanceOwns?skeletonClone(source,cloneSkeleton):privateClone(source,cloneSkeleton),owned=appearanceOwns?new Set():resources(clone);
 creationTimings.clone=performance.now()-creationMark;creationMark=performance.now();
 let walker,surface,activityPose,weapon=null,disposed=false,time=0,lastPosition={x:0,y:0,z:0},lastYaw=0,lastSurface=null,appearance,gesture=null,gestureBlend=0,sourceDown={active:false,at:0,releaseAt:null},sourceFall=null,sourceDeathKey=null,sourceDeathAt=null;
 // update() consumers use these values synchronously. Keep input buffers private
 // to this actor so crowd animation does not allocate argument objects every pose.
 const presentationInput={posture:null,action:null,reloadProgress:undefined,slowWalking:false,motionSpeed:undefined},activityInput={life:null,time:0,blocked:false,armed:false,groundY:0},surfaceInput={time:0,waterLevel:undefined,inWater:false,moving:false,fast:false,chestWorldY:undefined,groundWorldY:0,blocked:false};
 const own=root=>{for(const resource of resources(root))if(!templateResources?.has(resource))owned.add(resource);};
 try{
  if(applyAppearance)appearance=applyAppearance(clone,{id:persistentId,sex,height:targetHeight,build});
  own(clone);creationTimings.appearance=performance.now()-creationMark;creationMark=performance.now();walker=createHeroWalker({THREE,scene:clone,targetHeight});
  creationTimings.walker=performance.now()-creationMark;creationMark=performance.now();
  walker.object.name='NPC_'+persistentId;walker.object.userData.npcId=persistentId;scene.add(walker.object);
  const pose=createArtist14Pose(THREE),context=walker.artistContext();activityPose=createNpcActivityPose({THREE,walker});
  surface=createArtist14Surface({THREE,context,scene,
   applySwim(s,c){const dead=surface?.state.kind==='dead';c.object.position.y=lastPosition.y+(sourceFall?0:s.liftWorld);c.object.updateMatrixWorld(true);if(sourceFall)pose.reaction(sourceFall,c);else if(!dead)pose.swim(s,c);if(weapon)weapon.visible=dead||!!sourceFall||s.blend<.1;},
   applyReaction(s,c){pose.reaction(s.kind==='dead'&&sourceDeathAt!==null?{...s,age:Math.max(0,time-sourceDeathAt)}:s,c);}
  });own(clone);creationTimings.surface=performance.now()-creationMark;creationTimings.total=performance.now()-creationStart;
 }catch(error){surface?.dispose();walker?.object.removeFromParent();for(const r of owned)r.dispose?.();throw error;}
 function mountWeapon(node=null){
  if(disposed)return null;
  const next=node?privateClone(node,cloneSkeleton):null;
  if(weapon){const old=weapon;walker.mountWeapon(null);for(const r of resources(old)){r.dispose?.();owned.delete(r);}}
  weapon=next;if(weapon)own(weapon);walker.mountWeapon(weapon);return weapon;
 }
 function receive(event){
  if(disposed||event?.confirmed!==true)return false;
  if(event.targetId!==undefined&&String(event.targetId)!==persistentId)return false;
  const wasDead=surface.state.kind==='dead',accepted=surface.receive(event);
  if(accepted&&!wasDead&&surface.state.kind==='dead'){sourceDeathKey=null;sourceDeathAt=null;}
  return accepted;
 }
 function syncSourceLifecycle(lifecycle={},atTime=time){
  if(disposed)return;
  // A sparse snapshot, temporary downing or custody never revives a corpse.
  // Hydrating an unknown death timestamp also must not replay its fall.
  const newEpoch=lifecycle.dead&&sourceDeathKey&&sourceDeathKey!=='dead'&&lifecycle.key!=='dead'&&sourceDeathKey!==lifecycle.key;
  if(sourceDeathKey&&(lifecycle.explicitAlive||newEpoch)){surface.reset();sourceDeathKey=null;sourceDeathAt=null;sourceDown={active:false,at:atTime,releaseAt:null};sourceFall=null;}
  if(!lifecycle.dead)return;
  const oldAge=sourceDeathAt===null?null:Math.max(0,atTime-sourceDeathAt),alreadyDead=surface.state.kind==='dead';
  if(!alreadyDead)receive({confirmed:true,id:`world-death:${persistentId}:${lifecycle.key}`,targetId:persistentId,dead:true,side:lifecycle.side});
  if(sourceDeathAt===null)sourceDeathAt=atTime-(Number.isFinite(lifecycle.age)?lifecycle.age:alreadyDead?Math.max(0,atTime-surface.state.at):0);
  else if(Number.isFinite(lifecycle.age)&&lifecycle.age>oldAge)sourceDeathAt=atTime-lifecycle.age;
  sourceDeathKey=lifecycle.key||'dead';
 }
 function update(dt,snapshot={}){
  if(disposed)return null;if(!Number.isFinite(dt)||dt<0)throw Error('Invalid NPC dt');
  dt=Math.min(.25,dt);time=Number.isFinite(snapshot.time)?snapshot.time:time+dt;
  if(snapshot.position!==undefined){if(!finitePosition(snapshot.position))throw Error('NPC position must be finite world coordinates');lastPosition.x=snapshot.position.x;lastPosition.y=snapshot.position.y;lastPosition.z=snapshot.position.z;}
  if(snapshot.yaw!==undefined){if(!Number.isFinite(snapshot.yaw))throw Error('Invalid NPC yaw');lastYaw=snapshot.yaw;}
  walker.object.position.set(lastPosition.x,lastPosition.y,lastPosition.z);walker.object.rotation.set(0,lastYaw,0);walker.object.visible=snapshot.visible!==false;
  // Events are host-confirmed receipts; neither HP nor an animation snapshot creates damage.
  syncSourceLifecycle(snapshot.lifecycle||normalizeNpcLifecycle(snapshot.life||{},{time,sourceNowMs:snapshot.sourceNowMs}),time);
  if(snapshot.hit)receive(snapshot.hit);
  const stun=snapshot.stun||{},sourceActive=stun.active===true;
  if(sourceActive){if(!sourceDown.active)sourceDown.at=time-(Number.isFinite(stun.age)?Math.max(0,stun.age):0);sourceDown.active=true;sourceDown.releaseAt=null;}
  else if(sourceDown.active){
   sourceDown.active=false;const endedAge=Number.isFinite(stun.endedAge)?Math.max(0,stun.endedAge):0,endTime=time-endedAge;
   // If a short stun ends mid-fall, start recovery at the same tilt instead of snapping flat.
   const weight=THREE.MathUtils.smoothstep(Math.max(0,endTime-sourceDown.at),.03,.62);let lo=0,hi=1;
   for(let i=0;i<18;i++){const mid=(lo+hi)/2;if(THREE.MathUtils.smoothstep(mid,0,1)<1-weight)lo=mid;else hi=mid;}
   sourceDown.releaseAt=endTime-(lo+hi)/2*1.15;
  }
  const recovering=sourceDown.releaseAt!==null&&time-sourceDown.releaseAt<1.15;
  sourceFall=sourceDown.active?{kind:'fall',age:Math.min(.75,Math.max(0,time-sourceDown.at)),side:1}:recovering?{kind:'fall',age:1.55+Math.max(0,time-sourceDown.releaseAt),side:1}:null;
  if(surface.state.kind==='dead'||surface.state.kind==='fall')sourceFall=null;
  const vehicleBinding=resolveNpcVehicleBinding(snapshot.life,getVehicle);
  const reaction=surface.state.kind,locked=reaction==='dead'||reaction==='fall'||!!sourceFall,moving=!!snapshot.moving&&!locked&&!vehicleBinding;
  const life=snapshot.life||{},requestedGesture=lifeGesture(life),running=!!snapshot.running||(!Number.isFinite(snapshot.motionSpeed)&&/panic|flee/.test(String(life.state||'')));
  const deepWater=snapshot.inWater&&Number.isFinite(snapshot.waterLevel)&&snapshot.waterLevel>(snapshot.chestWorldY??lastPosition.y+3*walker.scale);
  const busyLife=locked||reaction!=='idle'||deepWater||(lastSurface?.swim.blend||0)>.05||snapshot.jump||snapshot.vehicle||vehicleBinding||snapshot.tumble||(snapshot.action&&(snapshot.action.type&&snapshot.action.type!=='none'||snapshot.action.blocking||snapshot.action.charge>0));
  const nextGesture=!busyLife&&!weapon?requestedGesture:null;
  if(nextGesture!==gesture){gesture=nextGesture;gestureBlend=0;}
  gestureBlend+=(Number(!!gesture)-gestureBlend)*(1-Math.exp(-dt*12));
  presentationInput.posture=reaction==='dead'?DEATH_BASE_POSTURE:!busyLife&&requestedGesture==='cower'?COWER_POSTURE:snapshot.posture;presentationInput.action=locked?null:snapshot.action;presentationInput.reloadProgress=locked?undefined:snapshot.reloadProgress;presentationInput.gaitDistance=Number.isFinite(snapshot.gaitDistance)?Math.max(0,snapshot.gaitDistance):undefined;presentationInput.slowWalking=!!snapshot.slowWalking;presentationInput.motionSpeed=Number.isFinite(snapshot.motionSpeed)?Math.max(0,snapshot.motionSpeed):undefined;
  walker.update(dt,moving,running,weapon,snapshot.aim||EMPTY_AIM,presentationInput);
  activityInput.life=life;activityInput.time=time;activityInput.blocked=busyLife||!!life.panic||/panic|flee/.test(String(life.lifeState||''));activityInput.armed=!!weapon;activityInput.groundY=lastPosition.y;activityPose.apply(activityInput);
  if(gesture)applyLifeGesture(THREE,walker.artistContext(),gesture,time,gestureBlend);
  if(!locked&&snapshot.jump&&Number.isFinite(snapshot.jump.progress))walker.jumpPose(snapshot.jump.progress,snapshot.jump.directional!==false,weapon,snapshot.aim||{});
  if(!locked&&snapshot.vehicle)walker.vehiclePose(snapshot.vehicle.seated||0,snapshot.vehicle.reach||0,snapshot.vehicle);
  if(!locked&&snapshot.tumble&&Number.isFinite(snapshot.tumble.progress))walker.tumblePose(snapshot.tumble.progress,snapshot.tumble.rolls||1);
  if(vehicleBinding&&!locked&&reaction==='idle'&&!deepWater&&(lastSurface?.swim.blend||0)<.05&&!snapshot.jump&&!snapshot.tumble&&!(snapshot.action?.type&&snapshot.action.type!=='none'))applyNpcVehicleBinding({THREE,walker,binding:vehicleBinding,dt});
  surfaceInput.time=time;surfaceInput.waterLevel=snapshot.waterLevel;surfaceInput.inWater=!!snapshot.inWater;surfaceInput.moving=moving;surfaceInput.fast=running;surfaceInput.chestWorldY=snapshot.chestWorldY;surfaceInput.groundWorldY=lastPosition.y;surfaceInput.blocked=locked||!!snapshot.swimBlocked;lastSurface=surface.update(dt,surfaceInput);
  if(lastSurface.reaction.kind==='dead'&&sourceDeathAt!==null)lastSurface.reaction.age=Math.max(0,time-sourceDeathAt);
  walker.object.updateMatrixWorld(true);return lastSurface;
 }
 function saveSurfaceState(){if(disposed)throw Error('NPC disposed');const saved=surface.snapshot();if(saved.reaction.kind==='dead'&&sourceDeathAt!==null)saved.reaction.age=Math.max(0,time-sourceDeathAt);return {version:1,id:persistentId,sex,height:targetHeight,sourceDeathKey:sourceDeathKey,sourceDown:{active:sourceDown.active,age:Math.max(0,time-sourceDown.at),releaseAge:sourceDown.releaseAt===null?null:Math.max(0,time-sourceDown.releaseAt)},surface:saved};}
 function restoreSurfaceState(data,options={}){if(disposed)throw Error('NPC disposed');if(data?.version!==1||data.id!==persistentId||data.sex!==sex||data.height!==targetHeight)throw Error('NPC surface identity/asset mismatch');const down=data.sourceDown;if(down&&(typeof down.active!=='boolean'||!Number.isFinite(down.age)||down.age<0||down.releaseAge!==null&&(!Number.isFinite(down.releaseAge)||down.releaseAge<0)))throw Error('Invalid NPC downed state');if(data.sourceDeathKey!=null&&(typeof data.sourceDeathKey!=='string'||!data.sourceDeathKey))throw Error('Invalid NPC death key');surface.restore(data.surface,options);time=options.time??data.surface.time+(options.elapsedSeconds??0);const elapsed=options.elapsedSeconds??0;sourceDown=down?{active:down.active,at:time-down.age-elapsed,releaseAt:down.releaseAge===null?null:time-down.releaseAge-elapsed}:{active:false,at:time,releaseAt:null};sourceFall=null;sourceDeathKey=data.sourceDeathKey||null;sourceDeathAt=sourceDeathKey&&data.surface.reaction.kind==='dead'?time-data.surface.reaction.age-elapsed:null;return true;}
 function dispose(){if(disposed)return;disposed=true;const current=resources(clone),woundMaterials=new Set();clone.getObjectByName('PersistentBulletWounds')?.traverse(o=>{for(const m of Array.isArray(o.material)?o.material:o.material?[o.material]:[])woundMaterials.add(m);});surface.dispose();for(const m of woundMaterials)m.dispose();clone.traverse(o=>{if(o.isSkinnedMesh)o.skeleton.dispose();});walker.dispose();for(const r of owned)if(!current.has(r))r.dispose?.();owned.clear();weapon=null;}
 return {id:persistentId,sex,height:targetHeight,object:walker.object,walker,surface,appearance,update,receive,mountWeapon,saveSurfaceState,restoreSurfaceState,syncSourceLifecycle,saveSourceDeathKey:()=>sourceDeathKey,dispose,
  get weapon(){return weapon;},diagnostics:()=>({creationMs:{...creationTimings},id:persistentId,sex,height:targetHeight,disposed,weapon:!!weapon,lifeGesture:gesture,sourceDown:sourceDown.active,sourceRecovering:!!sourceFall&&!sourceDown.active,reaction:surface.state.kind,surface:lastSurface,walker:walker.diagnostics()})};
}

