import {createArtistVehicle,ARTIST_VEHICLE_PROFILE_BY_ID,loadArtistVehicleSource,releaseArtistVehicleSourceCache} from './vehicle_fleet_models.mjs';
import {carOverlapsCircle} from './car_drive.mjs';
import {createVehicleRenderBatches,getVehicleRenderSourceMaterial} from './vehicle_render_batches.mjs';
import {createVehicleWheelRenderBatches} from './vehicle_wheel_render_batches.mjs';

export function trafficActorBlocks(actor,x,z,radius=0,{y,height=1.9}={}){
 const object=actor?.object,profile=actor?.profile||object?.userData?.vehicleProfile;
 if(!object||object.visible===false||!profile||![x,z,radius].every(Number.isFinite)||radius<0)return false;
 const scale=object.scale||{x:1,y:1,z:1},position=object.position;
 const halfWidth=profile.halfWidth*Math.abs(scale.x),halfLength=profile.halfLength*Math.abs(scale.z),reach=halfWidth+halfLength+radius;
 // Pedestrian sweeps sample several points. Reject distant source cars before
 // allocating their oriented hull or running per-edge circle contacts.
 if(Math.abs(x-position.x)>reach||Math.abs(z-position.z)>reach)return false;
 if(Number.isFinite(y)){
  const low=position.y+(profile.bounds?.min?.[1]||0)*scale.y,high=position.y+(profile.bounds?.max?.[1]??profile.height??0)*scale.y;
  if(y+Math.max(0,Number(height)||0)<Math.min(low,high)||y>Math.max(low,high))return false;
 }
 return carOverlapsCircle({x:position.x,z:position.z,yaw:object.rotation.y,vehicleProfile:{halfWidth,halfLength}},x,z,radius);
}
export const npcVehicleBlocks=trafficActorBlocks;

export function worldTrafficProfile(row){
 const model=String(row?.model||'');
 if(row?.helicopter||/heli|tow|armored|swat|paddyvan/i.test(model)||row?.emergency==='tow')return null;
 if(ARTIST_VEHICLE_PROFILE_BY_ID[model])return model;
 if(row?.bus||model==='city_bus')return 'city_bus';
 if(row?.emergency==='ambulance'||model==='ambulance')return 'city_ambulance';
 if(row?.emergency==='fire'||model==='firetruck')return 'fire_engine';
 if(row?.emergency==='police'||row?.policePatrol||model==='police')return 'police_interceptor';
 if(row?.pickup||model==='pickup'||model==='truck')return 'utility_pickup';
 if(row?.suv||/suv|jeep/.test(model))return 'city_suv';
 if(row?.van||/van/.test(model))return 'delivery_van';
 if(row?.sport||row?.cabrio||row?.muscle||/sport|coupe|supercar|lambo|ferrari|porsche/.test(model))return 'sport_coupe';
 if(/hatch/.test(model))return 'city_hatchback';
 if(/wagon/.test(model))return 'family_wagon';
 if(row?.limo||row?.classic||/limo|executive/.test(model))return 'executive_sedan';
 if(/sedan|taxi/.test(model))return 'compact_sedan';
 return null;
}
export function normalizeWorldTraffic(row,{worldScale=4.1,originR=0,originC=0,groundHeight=()=>0}={}){
 if(!row||typeof row.id!=='string'||!row.id||![row.r,row.c,row.ang].every(Number.isFinite))return null;
 const profileId=worldTrafficProfile(row);if(!profileId)return null;
 const x=(row.c-originC)*worldScale,z=(row.r-originR)*worldScale;
 return {id:row.id,previousPresentationId:row.previousPresentationId||row.sourceVehicleId||null,originPresentationId:row.sourceVehicleId||null,profileId,x,z,y:groundHeight(x,z)+(Number(row.elevation)||0),yaw:Math.PI/2-row.ang,paint:row.paint,braking:!!row.braking,parked:!!row.parked,steer:Number.isFinite(row.steer)?Math.max(-.6,Math.min(.6,row.steer)):0,
  hasSteer:Number.isFinite(row.steer),presentation:{model:row.model,damageRatio:row.damageRatio,wrecked:!!row.wrecked,burning:!!row.burning,emergencyLights:!!row.emergencyLights}};
}
function release(root,{textures=false}={}){
 const resources=new Set();root?.traverse(o=>{if(o.geometry)resources.add(o.geometry);for(const m of Array.isArray(o.material)?o.material:o.material?[o.material]:[]){resources.add(m);if(textures)for(const value of Object.values(m))if(value?.isTexture)resources.add(value)}});for(const resource of resources)resource.dispose?.();root?.removeFromParent?.();
}
function createTrafficEmergencyLamps(root){
 const lamps=[],owned=[];
 root.traverse?.(mesh=>{
  if(!mesh.isMesh||!/_Lightbar(?:Red|Blue)$/.test(mesh.name))return;
  // Artist cars own materials per car but may share them with coloured trim.
  // Clone only these two lamp materials before the render-batch owner starts.
  const original=mesh.material,materials=(Array.isArray(mesh.material)?mesh.material:[mesh.material]).map(material=>{
   const owned=material.clone();owned.emissiveIntensity=0;return owned;
  });
  mesh.material=Array.isArray(mesh.material)?materials:materials[0];
  owned.push({mesh,original,assigned:mesh.material});
  for(const material of materials)lamps.push({material,phase:mesh.name.endsWith('Red')?0:1});
 });
 let previous=-1;
 return {count:lamps.length,update(active,time){
  if(!lamps.length)return false;
  const phase=active?Math.floor(Math.max(0,time)/.17)%2:-1;
  if(phase===previous)return false;previous=phase;
  for(const lamp of lamps)lamp.material.emissiveIntensity=phase===lamp.phase?3.2:0;
  return true;
 },dispose(){for(const entry of owned)if(entry.mesh.material===entry.assigned)entry.mesh.material=entry.original;for(const lamp of lamps)lamp.material.dispose();owned.length=0;lamps.length=0;}};
}
export function createWorldTrafficPresentation({THREE,RoundedBox,loader,scene,groundHeight=()=>0,originR=0,originC=0,worldScale=4.1,teleportDistance=15,baseUrl=new URL('./models/artist_vehicle_pack/',import.meta.url).href,vehicleFactory=createArtistVehicle,renderBatchFactory=createVehicleRenderBatches,detailOptimization=true,wheelRenderOptimization=false}={}){
 const actors=new Map(),targets=new Map(),sources=new Map(),loads=new Map(),failed=new Map(),unsupported=new Map(),playerControlled=new WeakSet();let disposed=false,tail=Promise.resolve(),created=0,emergencyClock=0;
 const options={groundHeight,originR,originC,worldScale};
 const wheelsEnabled=!!wheelRenderOptimization&&!!detailOptimization&&!!THREE?.BatchedMesh;
 function request(profileId){
  if(sources.has(profileId)||loads.has(profileId)||failed.has(profileId))return;
  const job=tail.then(async()=>{
   if(disposed)return;
   const source=await loadArtistVehicleSource({loader,url:baseUrl.replace(/\/?$/,'/')+ARTIST_VEHICLE_PROFILE_BY_ID[profileId].modelFile});
   if(disposed)return;sources.set(profileId,source);
  }).catch(error=>failed.set(profileId,String(error?.message||error))).finally(()=>loads.delete(profileId));
  loads.set(profileId,job);tail=job;
 }
 function sync(rows){
  if(disposed)return;const next=new Map();unsupported.clear();
  for(const row of rows||[]){const pose=normalizeWorldTraffic(row,options);if(!pose){if(row?.id)unsupported.set(row.id,String(row.model||'invalid'));continue}if(next.has(pose.id))continue;next.set(pose.id,pose);request(pose.profileId)}
  // Ownership changes the source ID, not the physical car or its open doors.
  for(const [id,pose]of next){const previous=[pose.previousPresentationId,pose.originPresentationId].find(key=>key&&actors.has(key)&&!next.has(key)),record=previous&&actors.get(previous);if(!actors.has(id)&&record&&!next.has(previous)&&record.profileId===pose.profileId){actors.delete(previous);actors.set(id,record);record.actor.object.userData.sourceVehicleId=id;}}
  for(const [id,record] of actors)if(!next.has(id)||next.get(id).profileId!==record.profileId){record.wheelRenderBatches?.dispose();record.renderBatches?.dispose();record.emergencyLamps.dispose();release(record.actor.object);actors.delete(id)}
  targets.clear();for(const [id,pose] of next)targets.set(id,pose);
 }
 function update(dt=0){
  if(disposed)return;emergencyClock+=Number.isFinite(Number(dt))?Math.max(0,Number(dt)):0;dt=Math.max(0,Math.min(.1,Number(dt)||0));
  for(const [id,pose] of targets){if(actors.has(id)||!sources.has(pose.profileId))continue;
   const actor=wheelsEnabled?vehicleFactory(THREE,RoundedBox,sources.get(pose.profileId),pose.profileId,{wheelRenderOptimization:true}):vehicleFactory(THREE,RoundedBox,sources.get(pose.profileId),pose.profileId),presentation={...pose.presentation};actor.object.position.set(pose.x,pose.y,pose.z);actor.object.rotation.y=pose.yaw;actor.object.userData.sourceVehicleId=id;actor.object.userData.sourcePresentation=presentation;const emergencyLamps=createTrafficEmergencyLamps(actor.object);const renderBatches=THREE?.BatchedMesh?renderBatchFactory({THREE,root:actor.object,includeDoors:true,includeBody:true,detailOptimization}):null;const wheelRenderBatches=wheelsEnabled?createVehicleWheelRenderBatches({THREE,car:actor,multiDraw:true}):null;scene.add(actor.object);actors.set(id,{actor,profileId:pose.profileId,driveState:{distance:0,steer:0,braking:null},presentation,renderBatches,wheelRenderBatches,emergencyLamps});created++;break;
  }
  for(const [id,record] of actors){const {actor,driveState,presentation}=record;
   const pose=targets.get(id),object=actor.object,p=object.position,dx=pose.x-p.x,dz=pose.z-p.z,distance=Math.hypot(dx,dz),teleport=distance>teleportDistance,alpha=teleport?1:1-Math.exp(-18*dt),oldX=p.x,oldZ=p.z;
   if(playerControlled.has(actor)){
    record.emergencyLamps.update(pose.presentation.emergencyLights&&!pose.presentation.wrecked&&object.visible!==false,emergencyClock);
    continue;
   }
   p.set(p.x+dx*alpha,p.y+(pose.y-p.y)*alpha,p.z+dz*alpha);
   const angle=Math.atan2(Math.sin(pose.yaw-object.rotation.y),Math.cos(pose.yaw-object.rotation.y));object.rotation.y+=angle*alpha;
   const signed=teleport?0:Math.hypot(p.x-oldX,p.z-oldZ)*((p.x-oldX)*Math.sin(object.rotation.y)+(p.z-oldZ)*Math.cos(object.rotation.y)<0?-1:1);
   const motion=object.userData.sourceMotion||(object.userData.sourceMotion={speed:0,turnRate:0});motion.speed=dt>0?signed/dt:0;motion.turnRate=dt>0&&!teleport?angle*alpha/dt:0;
   if(/^#[\da-f]{3}(?:[\da-f]{3})?$/i.test(pose.paint||'')&&object.userData.sourcePaint!==pose.paint){
    // Batching installs an invisible proxy on source meshes. Paint the authored
    // material shared by the batches, never that proxy (which would invalidate
    // every member sharing it). A genuine per-part replacement stays authoritative.
    object.traverse?.(mesh=>{if(mesh.name?.endsWith('_LowerBody')){const sourceMaterial=getVehicleRenderSourceMaterial(mesh);for(const material of Array.isArray(sourceMaterial)?sourceMaterial:[sourceMaterial])material?.color?.set(pose.paint)}});object.userData.sourcePaint=pose.paint;
   }
   // Wheels and brake lamps are the only per-frame vehicle presentation work.
   // A parked/settled source has no visual state to advance, so preserve its
   // exact final pose until distance, steering, or braking actually changes.
   // Legacy traffic publishes its actual pose but no steering input. Derive
   // the front-wheel angle from that travelled arc (including reverse gear).
   // An authored steering value remains authoritative; no source AI is changed.
   const wheelBase=actor.profile.wheelBase||ARTIST_VEHICLE_PROFILE_BY_ID[pose.profileId].wheelBase;
   const desiredSteer=pose.hasSteer?pose.steer:teleport?0:Math.abs(signed)>.001?Math.max(-.6,Math.min(.6,Math.atan(wheelBase*angle*alpha/signed))):pose.parked?0:driveState.steer;
   let steer=pose.hasSteer||teleport?desiredSteer:driveState.steer+(desiredSteer-driveState.steer)*alpha;
   if(Math.abs(steer-desiredSteer)<.0001)steer=desiredSteer;
   const driveChanged=signed!==0||driveState.steer!==steer||driveState.braking!==pose.braking;
   if(driveChanged){driveState.distance=signed;driveState.steer=steer;driveState.braking=pose.braking;actor.update(driveState,pose.braking);}
   if(presentation.model!==pose.presentation.model||presentation.damageRatio!==pose.presentation.damageRatio||presentation.wrecked!==pose.presentation.wrecked||presentation.burning!==pose.presentation.burning||presentation.emergencyLights!==pose.presentation.emergencyLights){presentation.model=pose.presentation.model;presentation.damageRatio=pose.presentation.damageRatio;presentation.wrecked=pose.presentation.wrecked;presentation.burning=pose.presentation.burning;presentation.emergencyLights=pose.presentation.emergencyLights;}
   record.emergencyLamps.update(pose.presentation.emergencyLights&&!pose.presentation.wrecked&&object.visible!==false,emergencyClock);
   // Batched cabin parts are fixed in the actor's local frame, so root
   // interpolation needs no batch rebuild.  Recheck only after the authored
   // per-vehicle presentation has actually advanced.
   if(driveChanged)record.renderBatches?.update();
   // Unlike fixed cabin batches, opt-in wheel batches also validate external
   // wheel visibility/material/geometry edits while a source car is stationary.
   record.wheelRenderBatches?.update();
  }
 }
 function setNpcAccess(id,phase,progress=0,seatId='front_left'){
  const record=actors.get(id);if(!record?.actor.setDoorById)return false;
  const p=Math.max(0,Math.min(1,Number(progress)||0));
  if(!record.actor.seats?.some(seat=>seat.id===seatId))return false;
  const open=phase==='open'||phase==='pull_driver'?1:phase==='board'||phase==='exit'?Math.min(1,p/.14,(1-p)/.14):0;
  const doors=record.npcDoorStates??=new Map();if(doors.get(seatId)===open)return true;
  record.actor.setDoorById(open,seatId);doors.set(seatId,open);record.renderBatches?.update();return true;
 }
 function setDoorPose({carId,seatId,doorId=seatId,open}={}){
  const record=actors.get(carId);if(!record?.actor.seats?.some(seat=>seat.id===seatId)||!Number.isFinite(open))return false;
  const value=Math.max(0,Math.min(1,open)),doors=record.npcDoorStates??=new Map();if(doors.get(seatId)===value)return true;
  record.actor.setDoorById(value,doorId);doors.set(seatId,value);record.renderBatches?.update();return true;
 }
 function claimPlayerControl(id){const record=actors.get(id);if(!record)return null;playerControlled.add(record.actor);record.renderBatches?.dispose();record.renderBatches=null;record.wheelRenderBatches?.dispose();record.wheelRenderBatches=null;return record.actor;}
 function releasePlayerControl(actorOrId){const actor=typeof actorOrId==='string'?actors.get(actorOrId)?.actor:actorOrId;if(!actor)return false;return playerControlled.delete(actor);}
 return {sync,update,setNpcAccess,setDoorPose,claimPlayerControl,releasePlayerControl,getActor:id=>actors.get(id)?.actor||null,getActors:()=>[...actors].map(([id,record])=>({id,actor:record.actor,object:record.actor.object})),blocks(x,z,radius=0,{ignoreId,...options}={}){if(disposed)return false;for(const [id,record] of actors)if(id!==ignoreId&&trafficActorBlocks(record.actor,x,z,radius,options))return true;return false;},whenIdle:()=>tail,diagnostics:()=>({actors:actors.size,created,playerControlled:[...actors.values()].filter(r=>playerControlled.has(r.actor)).length,renderBatches:[...actors.values()].reduce((total,r)=>{for(const key of ['batches','members','activeMembers','fallbackMembers','fixtureMembers','fixtureBatches'])total[key]+=(r.renderBatches?.stats[key]||0);return total},{batches:0,members:0,activeMembers:0,fallbackMembers:0,fixtureMembers:0,fixtureBatches:0}),wheelRenderBatches:[...actors.values()].reduce((total,r)=>{for(const key of ['batches','members','activeBatches','activeMembers','fallbackMembers'])total[key]+=(r.wheelRenderBatches?.stats[key]||0);return total},{batches:0,members:0,activeBatches:0,activeMembers:0,fallbackMembers:0}),cachedModels:sources.size,loading:loads.size,failed:[...failed],unsupported:[...unsupported],limitations:['source damage retained as metadata; no destructive effects or siren audio applied','family silhouettes approximate source variants; no extra simulation']}),dispose(){if(disposed)return;disposed=true;for(const {actor,renderBatches,wheelRenderBatches,emergencyLamps} of actors.values()){wheelRenderBatches?.dispose();renderBatches?.dispose();emergencyLamps.dispose();release(actor.object);}actors.clear();targets.clear();sources.clear();releaseArtistVehicleSourceCache(loader)}};
}
