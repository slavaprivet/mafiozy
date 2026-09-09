import {createArtistVehicle,ARTIST_VEHICLE_PROFILE_BY_ID} from './vehicle_fleet_models.mjs';
import {carOverlapsCircle} from './car_drive.mjs';
import {createVehicleRenderBatches} from './vehicle_render_batches.mjs';

export function trafficActorBlocks(actor,x,z,radius=0,{y,height=1.9}={}){
 const object=actor?.object,profile=actor?.profile||object?.userData?.vehicleProfile;
 if(!object||object.visible===false||!profile||![x,z,radius].every(Number.isFinite)||radius<0)return false;
 const scale=object.scale||{x:1,y:1,z:1},position=object.position;
 if(Number.isFinite(y)){
  const low=position.y+(profile.bounds?.min?.[1]||0)*scale.y,high=position.y+(profile.bounds?.max?.[1]??profile.height??0)*scale.y;
  if(y+Math.max(0,Number(height)||0)<Math.min(low,high)||y>Math.max(low,high))return false;
 }
 return carOverlapsCircle({x:position.x,z:position.z,yaw:object.rotation.y,vehicleProfile:{halfWidth:profile.halfWidth*Math.abs(scale.x),halfLength:profile.halfLength*Math.abs(scale.z)}},x,z,radius);
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
 return {id:row.id,profileId,x,z,y:groundHeight(x,z)+(Number(row.elevation)||0),yaw:Math.PI/2-row.ang,paint:row.paint,braking:!!row.braking,parked:!!row.parked,steer:Number.isFinite(row.steer)?Math.max(-.6,Math.min(.6,row.steer)):0,
  presentation:{model:row.model,damageRatio:row.damageRatio,wrecked:!!row.wrecked,burning:!!row.burning,emergencyLights:!!row.emergencyLights}};
}
function release(root,{textures=false}={}){
 const resources=new Set();root?.traverse(o=>{if(o.geometry)resources.add(o.geometry);for(const m of Array.isArray(o.material)?o.material:o.material?[o.material]:[]){resources.add(m);if(textures)for(const value of Object.values(m))if(value?.isTexture)resources.add(value)}});for(const resource of resources)resource.dispose?.();root?.removeFromParent?.();
}
export function createWorldTrafficPresentation({THREE,RoundedBox,loader,scene,groundHeight=()=>0,originR=0,originC=0,worldScale=4.1,teleportDistance=15,baseUrl=new URL('./models/artist_vehicle_pack/',import.meta.url).href,vehicleFactory=createArtistVehicle}={}){
 const actors=new Map(),targets=new Map(),sources=new Map(),loads=new Map(),failed=new Map(),unsupported=new Map();let disposed=false,tail=Promise.resolve(),created=0;
 const options={groundHeight,originR,originC,worldScale};
 function request(profileId){
  if(sources.has(profileId)||loads.has(profileId)||failed.has(profileId))return;
  const job=tail.then(async()=>{
   if(disposed)return;
   const gltf=await loader.loadAsync(baseUrl.replace(/\/?$/,'/')+ARTIST_VEHICLE_PROFILE_BY_ID[profileId].modelFile);
   if(disposed){release(gltf.scene,{textures:true});return}sources.set(profileId,gltf.scene);
  }).catch(error=>failed.set(profileId,String(error?.message||error))).finally(()=>loads.delete(profileId));
  loads.set(profileId,job);tail=job;
 }
 function sync(rows){
  if(disposed)return;const next=new Map();unsupported.clear();
  for(const row of rows||[]){const pose=normalizeWorldTraffic(row,options);if(!pose){if(row?.id)unsupported.set(row.id,String(row.model||'invalid'));continue}if(next.has(pose.id))continue;next.set(pose.id,pose);request(pose.profileId)}
  for(const [id,record] of actors)if(!next.has(id)||next.get(id).profileId!==record.profileId){record.renderBatches?.dispose();release(record.actor.object);actors.delete(id)}
  targets.clear();for(const [id,pose] of next)targets.set(id,pose);
 }
 function update(dt=0){
  if(disposed)return;dt=Math.max(0,Math.min(.1,Number(dt)||0));
  for(const [id,pose] of targets){if(actors.has(id)||!sources.has(pose.profileId))continue;
   const actor=vehicleFactory(THREE,RoundedBox,sources.get(pose.profileId),pose.profileId),presentation={...pose.presentation};actor.object.position.set(pose.x,pose.y,pose.z);actor.object.rotation.y=pose.yaw;actor.object.userData.sourceVehicleId=id;actor.object.userData.sourcePresentation=presentation;const renderBatches=THREE?.BatchedMesh?createVehicleRenderBatches({THREE,root:actor.object}):null;scene.add(actor.object);actors.set(id,{actor,profileId:pose.profileId,driveState:{distance:0,steer:0,braking:null},presentation,renderBatches});created++;break;
  }
  for(const [id,record] of actors){const {actor,driveState,presentation}=record;
   const pose=targets.get(id),object=actor.object,p=object.position,dx=pose.x-p.x,dz=pose.z-p.z,distance=Math.hypot(dx,dz),teleport=distance>teleportDistance,alpha=teleport?1:1-Math.exp(-18*dt),oldX=p.x,oldZ=p.z;
   p.set(p.x+dx*alpha,p.y+(pose.y-p.y)*alpha,p.z+dz*alpha);
   const angle=Math.atan2(Math.sin(pose.yaw-object.rotation.y),Math.cos(pose.yaw-object.rotation.y));object.rotation.y+=angle*alpha;
   const signed=teleport?0:Math.hypot(p.x-oldX,p.z-oldZ)*((p.x-oldX)*Math.sin(object.rotation.y)+(p.z-oldZ)*Math.cos(object.rotation.y)<0?-1:1);
   if(/^#[\da-f]{3}(?:[\da-f]{3})?$/i.test(pose.paint||'')&&object.userData.sourcePaint!==pose.paint){
    object.traverse?.(mesh=>{if(mesh.name?.endsWith('_LowerBody'))for(const material of Array.isArray(mesh.material)?mesh.material:[mesh.material])material?.color?.set(pose.paint)});object.userData.sourcePaint=pose.paint;
   }
   // Wheels and brake lamps are the only per-frame vehicle presentation work.
   // A parked/settled source has no visual state to advance, so preserve its
   // exact final pose until distance, steering, or braking actually changes.
   if(signed!==0||driveState.steer!==pose.steer||driveState.braking!==pose.braking){driveState.distance=signed;driveState.steer=pose.steer;driveState.braking=pose.braking;actor.update(driveState,pose.braking);}
   if(presentation.model!==pose.presentation.model||presentation.damageRatio!==pose.presentation.damageRatio||presentation.wrecked!==pose.presentation.wrecked||presentation.burning!==pose.presentation.burning||presentation.emergencyLights!==pose.presentation.emergencyLights){presentation.model=pose.presentation.model;presentation.damageRatio=pose.presentation.damageRatio;presentation.wrecked=pose.presentation.wrecked;presentation.burning=pose.presentation.burning;presentation.emergencyLights=pose.presentation.emergencyLights;}
   record.renderBatches?.update();
  }
 }
 return {sync,update,getActor:id=>actors.get(id)?.actor||null,getActors:()=>[...actors].map(([id,record])=>({id,actor:record.actor,object:record.actor.object})),blocks(x,z,radius=0,{ignoreId,...options}={}){if(disposed)return false;for(const [id,record] of actors)if(id!==ignoreId&&trafficActorBlocks(record.actor,x,z,radius,options))return true;return false;},whenIdle:()=>tail,diagnostics:()=>({actors:actors.size,created,renderBatches:[...actors.values()].reduce((total,r)=>{for(const key of ['batches','members','activeMembers','fallbackMembers'])total[key]+=(r.renderBatches?.stats[key]||0);return total},{batches:0,members:0,activeMembers:0,fallbackMembers:0}),cachedModels:sources.size,loading:loads.size,failed:[...failed],unsupported:[...unsupported],limitations:['source damage/sirens retained as metadata; no destructive effects applied','family silhouettes approximate source variants; no extra simulation']}),dispose(){if(disposed)return;disposed=true;for(const {actor,renderBatches} of actors.values()){renderBatches?.dispose();release(actor.object);}actors.clear();targets.clear();for(const source of sources.values())release(source,{textures:true});sources.clear()}};
}
