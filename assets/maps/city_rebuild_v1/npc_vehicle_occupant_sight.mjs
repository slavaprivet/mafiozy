// Geometry and sequence proof only. Source/Walk own HP and effect dispatch.
// Sight through glass and physical bullet contact are deliberately separate.
import {isBreakableGlass} from './glass_breakage.mjs';
import {createNpcContactRay} from './npc_contact_ray.mjs';

export function createVehicleOccupantSight({THREE,getTarget,getObserver=()=>null,getActors=()=>[],environmentClear=()=>false,obstacles=()=>[],local=()=>false,now=()=>performance.now(),maxProbesPerFrame=1,maxSightProbesPerFrame=2,sightCacheMs=120}={}){
 const eye=new THREE.Vector3(),end=new THREE.Vector3(),direction=new THREE.Vector3(),seatPoint=new THREE.Vector3(),actorPoint=new THREE.Vector3(),ray=new THREE.Raycaster(),carMeshes=new WeakMap(),pendingAt=new Map();
 const contact=createNpcContactRay({THREE,getActors,obstacles:(...args)=>obstacles(...args)});
 const sightCache=new Map(),sightQueue=[],proofs=new WeakMap();
 let frameId=null,probes=0,sightProbes=0;
 const visible=node=>{for(let n=node;n;n=n.parent)if(n.visible===false)return false;return true;};
 const beneath=(node,root)=>{for(let n=node;n;n=n.parent)if(n===root)return true;return false;};
 const material=hit=>Array.isArray(hit.object.material)?hit.object.material[hit.face?.materialIndex??0]:hit.object.material;
 const glass=hit=>isBreakableGlass(hit.object,material(hit));
 function current(request){
  const target=getTarget?.();
  if(!local()||!target||target.phase!=='drive'||target.exitPending||target.dead||!target.id||!target.car?.object||!target.actor?.object)return null;
  if(request.targetId!==target.id||![request.toR,request.toC,target.r,target.c].every(Number.isFinite)||Math.hypot(request.toR-target.r,request.toC-target.c)>.02)return null;
  // This slice handles the real hero root at its current authored seat. It is
  // not suitable for source NPC roots which deliberately stay at authority r/c.
  const seat=target.car.seats?.find(seat=>seat.id===target.seatId)?.anchor;if(!seat)return null;
  target.car.object.updateWorldMatrix(true,false);seatPoint.set(seat.side,seat.y,seat.front);target.car.object.localToWorld(seatPoint);
  target.actor.object.getWorldPosition(actorPoint);
  if(actorPoint.distanceTo(seatPoint)>.06||Math.hypot(seatPoint.x-target.c*4.1,seatPoint.z-target.r*4.1)>.06)return null;
  const head=target.actor.object.getObjectByName('head');
  if(!head||!visible(target.car.object)||!visible(target.actor.object))return null;
  head.getWorldPosition(end);
  if(![end.x,end.y,end.z,request.origin?.x,request.origin?.y,request.origin?.z].every(Number.isFinite))return null;
  eye.copy(request.origin);direction.subVectors(end,eye);if(direction.lengthSq()<.01)return null;direction.normalize();
  return target;
 }
 function observer(request){const ref=getObserver(request.sourceId);return ref&&ref.alive!==false&&!ref.dead&&!(Number.isFinite(ref.hp)&&ref.hp<=0)?ref:null;}
 const sourcePose=source=>[source.r??source.y,source.c??source.x,source.ang].join(',');
 const stamp=target=>[...eye.toArray(),...end.toArray(),...target.car.object.matrixWorld.elements,target.r,target.c,target.visibilityRevision??0].join(',');
 function inspectFresh(request){
  const target=current(request);if(!target)return {visible:false,reason:'target_not_current_seated'};
  const distance=eye.distanceTo(end);
  // Host must use native static/terrain/OTHER-vehicle queries for this exact
  // segment. Only this current target car is handled by precise geometry here.
  if(!environmentClear({origin:eye,target:end,excludeVehicle:target.car}))return {visible:false,reason:'environment_cover'};
  let collection=carMeshes.get(target.car.object);if(!collection||collection.revision!==target.visibilityRevision){const meshes=[];target.car.object.traverse(n=>{if(n.isMesh)meshes.push(n)});collection={meshes,revision:target.visibilityRevision};carMeshes.set(target.car.object,collection);}const meshes=collection.meshes;
  target.car.object.updateMatrixWorld(true);ray.set(eye,direction);ray.near=.01;ray.far=distance-.005;
  const hits=ray.intersectObjects(meshes,false).filter(hit=>visible(hit.object)&&beneath(hit.object,target.car.object));
  const cover=hits.find(hit=>!glass(hit));
  if(cover)return {visible:false,reason:'own_opaque_cover',object:cover.object.name||cover.object.uuid};
  return {visible:true,reason:hits.length?'visible_through_glass':'visible_open_aperture',targetId:target.id,point:{x:end.x,y:end.y,z:end.z},glassAhead:hits.some(glass)};
 }
 function inspect(request){
  const source=observer(request),target=current(request);if(!source||!target)return {visible:false,reason:'actor_not_current_alive_seated'};
  const key=String(request.sourceId),time=now(),signature=stamp(target)+'|'+sourcePose(source);let entry=sightCache.get(key);
  // This broadphase check remains fresh even when the own-car aperture result
  // is cached. A moving OTHER car or closing native door still blocks now.
  if(!environmentClear({origin:eye,target:end,excludeVehicle:target.car}))return {visible:false,reason:'environment_cover'};
  if(entry?.source===source&&entry.car===target.car&&entry.actor===target.actor&&entry.signature===signature&&time>=entry.at&&time-entry.at<=sightCacheMs)return entry.result;
  if(!entry){entry={};sightCache.set(key,entry);}entry.requestedAt=time;
  if(!sightQueue.includes(key))sightQueue.push(key);
  while(sightQueue.length&&time-(sightCache.get(sightQueue[0])?.requestedAt??-Infinity)>250)sightQueue.shift();
  while(sightCache.size>64){const old=sightCache.keys().next().value;sightCache.delete(old);const index=sightQueue.indexOf(old);if(index>=0)sightQueue.splice(index,1);}
  if(sightProbes>=maxSightProbesPerFrame||sightQueue[0]!==key)return {visible:null,pending:true,reason:'sight_budget'};
  sightProbes++;sightQueue.shift();const result=inspectFresh(request);
  Object.assign(entry,{source,car:target.car,actor:target.actor,signature,result,at:time});return result;
 }
 function prepareAttack(request){
  const key=String(request.sourceId||''),time=now();if(!key)return {accepted:false,reason:'source_required'};
  const source=observer(request);if(!source)return {accepted:false,reason:'source_not_alive'};const sourceSignature=sourcePose(source);
  if(time<(pendingAt.get(key)??-Infinity))return {accepted:false,reason:'probe_backoff'};
  if(probes>=maxProbesPerFrame)return {accepted:false,reason:'frame_budget'};
  probes++;pendingAt.delete(key);pendingAt.set(key,time+250);while(pendingAt.size>64)pendingAt.delete(pendingAt.keys().next().value);
  // A due real shot always recomputes geometry; cached vision never authorizes
  // damage. This has its own one-probe budget and does not alter source cadence.
  const sight=inspectFresh(request);if(!sight.visible)return {accepted:false,reason:sight.reason};
  const target=current(request);if(!target)return {accepted:false,reason:'target_changed'};
  const signature=stamp(target),offset=request.aimOffset;
  if(offset){if(![offset.x,offset.y,offset.z].every(Number.isFinite)||Math.hypot(offset.x,offset.y,offset.z)>3)return {accepted:false,reason:'invalid_source_spread'};end.add(offset);direction.subVectors(end,eye).normalize();}
  const hit=contact({origin:eye,direction,range:eye.distanceTo(end)+.3,projectileOnly:true});
  // Re-read seat/identity after physical work; no stale proof survives a switch.
  if(getTarget()?.car!==target.car||getTarget()?.actor!==target.actor||getTarget()?.phase!=='drive')return {accepted:false,reason:'target_changed'};
  if(observer(request)!==source||sourcePose(source)!==sourceSignature)return {accepted:false,reason:'source_changed'};
  const own=!!hit&&beneath(hit.object,target.car.object),actor=!!hit&&beneath(hit.object,target.actor.object);
  if(hit&&!own&&!actor)return {accepted:false,reason:'other_body_or_cover'};
  const result=Object.freeze({accepted:true,kind:!hit?'miss':own?(glass(hit)?'vehicle_glass':'vehicle_body'):'occupant',targetId:target.id,car:target.car,hit,origin:eye.clone(),direction:direction.clone(),end:{x:end.x,y:end.y,z:end.z},sight,at:time,sourceId:key,sequence:(+source._shotSeq||0)+1});
  proofs.set(result,{source,sourceSignature,target:target.actor,car:target.car,signature,request:{...request,origin:request.origin.clone()},frameId,spent:false});return result;
 }
 function consume(proof,dispatch){
  const entry=proofs.get(proof),time=now();
  if(!entry||entry.spent||typeof dispatch!=='function'||!local()||frameId!==entry.frameId||time<proof.at||time-proof.at>50)return false;
  const source=observer(entry.request),target=current(entry.request);
  if(source!==entry.source||sourcePose(source)!==entry.sourceSignature||source._shotSeq!==proof.sequence||!target||target.actor!==entry.target||target.car!==entry.car||stamp(target)!==entry.signature)return false;
  // Source owns _markPoliceShot + its existing 900..1450ms cadence. This consumes
  // exactly that incremented sequence once, synchronously before another frame.
  entry.spent=true;dispatch(proof);return true;
 }
 return {inspect,prepareAttack,consume,beginFrame(id){if(id!==frameId){frameId=id;probes=0;sightProbes=0;}},stats:()=>({probes,sightProbes,pendingSight:sightQueue.length,cachedSight:sightCache.size,backoffs:pendingAt.size,maxProbesPerFrame,maxSightProbesPerFrame})};
}
