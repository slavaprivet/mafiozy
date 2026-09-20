// Read-only picking/target resolution; destructive gameplay effects are host-owned.
const EFFECTS={plant_bomb:'blast',explode:'blast',explosion:'blast',vehicle_blast:'blast',breach_door:'breach',unlock_safe:'unlock',unlock_door:'unlock',unlock:'unlock',cut_fence:'cut',cut:'cut',disable_power:'disablePower',intimidate:'intimidate'};
export function createMercenaryTargets({THREE,camera,getRoots=()=>[],getPickRoots=null,getFleet=()=>[],getTraffic=()=>[],getBuildings=()=>[],getNpcs=()=>[],getVehicleLock=()=>null,pickingProbe=null,skinPickingMemo=null,onVehicleBlast,onDoorBlast,onDoorBreach,onUnlock,onFenceCut,onDisablePower,onIntimidate}){
 const ray=new THREE.Raycaster(),screen=new THREE.Vector2(),center=new THREE.Vector3(),side=new THREE.Vector3(),cameraDelta=new THREE.Vector3(),contact=new THREE.Vector3(),normal=new THREE.Vector3(),q=new THREE.Quaternion(),vehicleSides=new WeakMap(),byId=new Map(),byObject=new Map(),done=new Set(),pending=new Map(),requests=new Map();let disposed=false;ray.far=80;
 const array=v=>Array.isArray(v)?v:v instanceof Map?[...v.values()]:[];
 const objectOf=r=>r?.object||r?.car?.object||r?.actor?.object||r?.visual||(r?.isObject3D?r:null);
 function register(r,kind,prefix){const object=objectOf(r);if(!object)return;const meta=object.userData?.mercenaryTarget||{},sourceId=r.id??object.userData?.vehicleFleetId??object.userData?.sourceVehicleId??object.userData?.sourceNpcId??object.uuid,id=meta.id||prefix+sourceId;const record={id,kind:meta.kind||kind,sourceId,object,meta,damage:r.damage||r.actor?.damage,profile:r.car?.profile||r.actor?.profile||r.profile};byId.set(id,record);byObject.set(object,record);return record;}
 function refresh(){
  byId.clear();byObject.clear();
  const fleet=getFleet(),traffic=getTraffic();for(const r of array(fleet?.records||fleet))register(r,'vehicle','fleet:');
  for(const r of array(traffic?.getActors?.()||traffic))register(r,'vehicle','traffic:');
  const npcs=array(getNpcs());skinPickingMemo?.syncNpcRoots(npcs.map(objectOf).filter(Boolean));
  for(const r of npcs)register(r,r.kind==='player'?'player':'npc','npc:');
  for(const r of array(getBuildings())){const o=objectOf(r);if(o?.userData?.mercenaryTarget)register(r,o.userData.mercenaryTarget.kind,'object:');}
 }
 function visible(o){for(let n=o;n;n=n.parent)if(n.visible===false)return false;return true;}
 function recognize(o){
  // Resolve the registered whole actor/vehicle before decorative child names.
  // A car door or a safe door is part of that target, not a building door.
  for(let n=o;n;n=n.parent)if(byObject.has(n))return byObject.get(n);
  for(let n=o;n;n=n.parent){const d=n.userData||{};if(d.mercenaryTarget?.kind)return register(n,d.mercenaryTarget.kind,'object:');if(d.vehicleFleetId)return register({id:d.vehicleFleetId,object:n},'vehicle','fleet:');if(d.sourceVehicleId)return register({id:d.sourceVehicleId,object:n},'vehicle','traffic:');}
  for(let n=o;n;n=n.parent){
   if(byObject.has(n))return byObject.get(n);
   const d=n.userData||{},meta=d.mercenaryTarget;
   if(meta?.kind)return register(n,meta.kind,'object:');
   if(d.vehicleFleetId)return register({id:d.vehicleFleetId,object:n},'vehicle','fleet:');
   if(d.sourceVehicleId)return register({id:d.sourceVehicleId,object:n},'vehicle','traffic:');
   // Names only identify possible targets; they never imply a real locked state.
   const name=String(n.name||'');let kind=/\bSafe\b|(?:^|_)Safe(?:_|$)/i.test(name)?'safe':/^(?:Entry_|Interior_)?Door(?:_|$)/i.test(name)?'door':/(?:^|_)(?:Fence|WireFence)(?:_|$)/i.test(name)?'fence':null;
   if(kind)return register(n,kind,'object:');
  }return null;
 }
 function describe(r){
  if(!r)return null;const {object,meta}=r;object.updateWorldMatrix(true,false);object.getWorldPosition(center);side.copy(center);
  if(r.kind==='vehicle'){
   // Use authored collision dimensions where available. Approach the nearest side,
   // never the car centre, and recompute world transform for moving traffic.
   const d=object.userData,halfWidth=(Number(d.collisionHalfWidth??r.profile?.collisionHalfWidth??d.halfWidth??r.profile?.halfWidth)||1)*Math.abs(object.scale.x);
   object.getWorldQuaternion(q);side.set(halfWidth+.84,0,0).applyQuaternion(q);
   camera?.getWorldPosition?.(center);cameraDelta.copy(center).sub(object.getWorldPosition(center));let sideSign=vehicleSides.get(object);if(sideSign===undefined){sideSign=side.dot(cameraDelta)<0?-1:1;vehicleSides.set(object,sideSign);}if(sideSign<0)side.negate();normal.copy(side).normalize();contact.copy(center).addScaledVector(normal,halfWidth);contact.y+=.65;side.add(center);
  }
  const approach=meta.getApproachPosition?.();if(approach&&Number.isFinite(approach.x)&&Number.isFinite(approach.z))side.set(approach.x,Number.isFinite(approach.y)?approach.y:side.y,approach.z);
  const pointValue=p=>p&&[p.x,p.y,p.z].every(Number.isFinite)?{x:p.x,y:p.y,z:p.z}:undefined;
  const workPoint=pointValue(r.kind==='vehicle'?contact:meta.getWorkPoint?.()),workNormal=pointValue(r.kind==='vehicle'?normal:meta.getWorkNormal?.()),supportPoint=pointValue(meta.getSupportPoint?.());
  const loot=meta.getLootPosition?.(),lootPosition=loot&&Number.isFinite(loot.x)&&Number.isFinite(loot.z)?{x:loot.x,y:Number.isFinite(loot.y)?loot.y:side.y,z:loot.z}:null;
  const d=object.userData,vehicleState=r.damage?.state,vehicleDone=r.kind==='vehicle'&&(vehicleState?.wrecked===true||vehicleState?.destroying===true||Number.isFinite(vehicleState?.hp)&&vehicleState.hp<=0||d.wrecked===true||d.destroyed===true),vehicleLock=r.kind==='vehicle'?getVehicleLock(r.sourceId):null;return {...meta,workPoint,workNormal,supportPoint,workRange:r.kind==='vehicle'?.08:meta.workRange,id:r.id,kind:r.kind,sourceId:r.sourceId,object,position:{x:side.x,y:side.y,z:side.z},lootPosition,center:{x:center.x,y:center.y,z:center.z},valid:visible(object)&&d.destroyed!==true&&!vehicleDone,destroyed:d.destroyed===true||vehicleDone,wrecked:vehicleState?.wrecked===true,lockpickable:vehicleLock?.lockpickable??meta.lockpickable,breachable:r.kind==='door'?meta.breachable===true&&typeof meta.breakOpen==='function':meta.breachable,bombable:r.kind==='door'?meta.bombable===true&&typeof meta.blast==='function':meta.bombable,locked:vehicleLock?vehicleLock.locked===true:d.locked===true||(meta.locked===true&&d.locked!==false),lockable:d.lockable===true||d.locked===true||meta.lockable===true,label:meta.label||d.label||object.name||r.kind,opened:d.mercenaryOpened===true,cut:d.mercenaryCut===true};
 }
 function roots(){return array(getRoots()).map(objectOf).filter(Boolean);}
 const intersect=(raycaster,candidates)=>skinPickingMemo?skinPickingMemo.intersect(raycaster,candidates):raycaster.intersectObjects(candidates,true);
 const assistBox=new THREE.Box3(),assistInverse=new THREE.Matrix4(),assistRay=new THREE.Ray(),assistPoint=new THREE.Vector3(),assistCenter=new THREE.Vector3(),sight=new THREE.Raycaster();
 function assistedPick(blocker){
  let best=null,bestDistance=Infinity;const measuring=pickingProbe?.active===true;
  for(const r of byId.values()){
   if(measuring)pickingProbe.count('assistScanned');
   if(!['safe','power_panel','door','npc','player'].includes(r.kind)||!visible(r.object))continue;
   const bounds=r.meta.highlightBounds||(['npc','player'].includes(r.kind)?{min:[-.4,0,-.4],max:[.4,1.9,.4]}:null);if(!bounds?.min||!bounds?.max)continue;
   r.object.updateWorldMatrix(true,false);assistInverse.copy(r.object.matrixWorld).invert();assistRay.copy(ray.ray).applyMatrix4(assistInverse);
   assistBox.min.fromArray(bounds.min);assistBox.max.fromArray(bounds.max);assistBox.getCenter(assistCenter).applyMatrix4(r.object.matrixWorld);
   // Compact props get a generous selection band; no visual or collision size changes.
   const padding=Math.min(1.2,Math.max(r.kind==='npc'||r.kind==='player'?.25:.6,assistCenter.distanceTo(ray.ray.origin)*.018));
   assistBox.expandByScalar(padding);if(!assistRay.intersectBox(assistBox,assistPoint))continue;assistPoint.applyMatrix4(r.object.matrixWorld);
   const distance=assistPoint.distanceTo(ray.ray.origin);if(distance>ray.far||distance>=bestDistance||blocker&&blocker.distance+.05<distance)continue;
   if(measuring)pickingProbe.count('assistLosQueries');
   sight.ray.origin.copy(ray.ray.origin);sight.ray.direction.copy(assistCenter).sub(sight.ray.origin).normalize();sight.far=sight.ray.origin.distanceTo(assistCenter)+.01;
   const candidates=typeof getPickRoots==='function'?getPickRoots(sight.ray.origin,sight.ray.direction,sight.far):roots();
   const losHits=measuring?pickingProbe.measure('assistLosMs',()=>intersect(sight,candidates)):intersect(sight,candidates);
   const first=losHits.find(hit=>visible(hit.object)&&hit.object.userData?.mercenaryPickIgnore!==true);
   if(!first||recognize(first.object)?.id!==r.id)continue;
   best={...describe(r),distance,hitPoint:{x:assistPoint.x,y:assistPoint.y,z:assistPoint.z},assisted:true};bestDistance=distance;
  }return best;
 }
 function pick(){
  if(disposed)return null;refresh();pickingProbe?.mark('registryMs');ray.setFromCamera(screen,camera);pickingProbe?.mark('raySetupMs');
  const candidates=typeof getPickRoots==='function'?getPickRoots(ray.ray.origin,ray.ray.direction,ray.far):roots();pickingProbe?.mark('candidateQueryMs');
  const hits=pickingProbe?.active?pickingProbe.intersect(ray,candidates,object=>byObject.get(object)?.kind):intersect(ray,candidates);
  const hit=hits.find(hit=>visible(hit.object)&&hit.object.userData?.mercenaryPickIgnore!==true),r=hit&&recognize(hit.object);
  // A small switchbox just in front of a fence must win over that fence behind it.
  const assisted=r&&['npc','player','vehicle','safe','power_panel','door'].includes(r.kind)?null:assistedPick(hit);
  const result=assisted||(r?{...describe(r),distance:hit.distance,hitPoint:{x:hit.point.x,y:hit.point.y,z:hit.point.z},instanceId:hit.instanceId}:null);
  pickingProbe?.selected(result,hit||null);return result;
 }
 function pickGround(){
  if(disposed)return null;refresh();ray.setFromCamera(screen,camera);
  for(const hit of intersect(ray,typeof getPickRoots==='function'?getPickRoots(ray.ray.origin,ray.ray.direction,ray.far):roots())){
   if(!visible(hit.object)||hit.object.userData?.mercenaryPickIgnore===true)continue;
   if(hit.distance>80||recognize(hit.object)||hit.object.userData?.nativeTerrainKind==='water')return null;
   const normal=hit.face?.normal?.clone().transformDirection(hit.object.matrixWorld);
   if(!normal||normal.y<.65)return null;
   return {x:hit.point.x,y:hit.point.y,z:hit.point.z};
  }return null;
 }
 function hasLineOfSight(from,to,targetId){
  if(!from||!to)return false;refresh();sight.ray.origin.set(from.x,from.y+1.15,from.z);assistCenter.set(to.x,to.y+1.05,to.z);sight.ray.direction.copy(assistCenter).sub(sight.ray.origin);sight.far=sight.ray.direction.length();if(sight.far<.01)return true;sight.ray.direction.normalize();
  const candidates=typeof getPickRoots==='function'?getPickRoots(sight.ray.origin,sight.ray.direction,sight.far):roots();
  const key=v=>String(v??'').replace(/^npc:/,'').replace(/^(?:npc_|crew_)/,'');
  for(const hit of intersect(sight,candidates)){if(!visible(hit.object)||hit.object.userData?.mercenaryPickIgnore===true)continue;const r=recognize(hit.object);if(r&&(key(r.id)===key(targetId)||key(r.sourceId)===key(targetId)))return true;return false;}return true;
 }
 // Only immediate adapter resolution after pick reuses its registry; commands
 // and effects use the default fresh registry and every call describes live pose.
 function get(id,{reuseRegistry=false}={}){
  if(disposed)return null;const previous=byId.get(id);if(!reuseRegistry)refresh();let r=byId.get(id);
  if(!r&&previous&&roots().some(root=>{for(let p=previous.object;p;p=p.parent)if(p===root)return true;return false;})){r=recognize(previous.object);}
  return describe(r);
 }
 function performEffect(effect={}){
  if(disposed)return {ok:false,reason:'disposed'};const rawKey=effect.actionId??effect.id??effect.effectId,key=rawKey==null?null:String(rawKey),signature=String(effect.kind||effect.type)+'@'+String(effect.targetId);if(key&&requests.has(key)&&requests.get(key)!==signature)return {ok:false,reason:'request_conflict'};if(key&&done.has(key))return {ok:true,duplicate:true};if(key&&pending.has(key))return pending.get(key);
  const target=get(effect.targetId),kind=EFFECTS[effect.kind||effect.type];if(!target?.valid)return {ok:false,reason:'target_unavailable'};
  let fn;if(kind==='blast'&&target.kind==='vehicle')fn=onVehicleBlast;
  else if(kind==='blast'&&target.kind==='door'){if(target.opened||!target.locked||target.bombable!==true)return {ok:false,reason:'door_not_bombable'};fn=onDoorBlast;}
  else if(kind==='breach'&&target.kind==='door'){if(target.opened||!target.locked||target.breachable!==true)return {ok:false,reason:'door_not_breachable'};fn=onDoorBreach;}
  else if(kind==='unlock'&&['safe','door','vehicle'].includes(target.kind)){if(target.opened||!target.locked)return {ok:false,reason:'not_locked'};fn=onUnlock;}
  else if(kind==='cut'&&target.kind==='fence'){if(target.cut)return {ok:false,reason:'already_cut'};fn=onFenceCut;}
  else if(kind==='disablePower'&&target.kind==='power_panel'){if(target.powered!==true||target.disabled)return {ok:false,reason:'power_already_off'};fn=onDisablePower;}
  else if(kind==='intimidate'&&target.kind==='npc')fn=onIntimidate;
  if(typeof fn!=='function')return {ok:false,reason:'effect_not_connected'};if(key)requests.set(key,signature);
  function confirmed(result){
   if(result!==true&&result?.ok!==true)return {ok:false,reason:result?.reason||'effect_rejected'};
   // The authority may have completed the effect while the presentation target
   // disappeared. Preserve its success receipt without mutating a stale/new object.
   const live=get(target.id),same=live?.valid&&live.object===target.object;
   if(same&&(kind==='unlock'||kind==='breach'||kind==='blast'&&target.kind==='door')){live.object.userData.locked=false;live.object.userData.mercenaryOpened=true;}
   if(same&&kind==='cut')live.object.userData.mercenaryCut=true;
   if(same&&kind==='disablePower'){live.object.userData.mercenaryTarget.powered=false;live.object.userData.mercenaryTarget.disabled=true;}
   if(key&&!disposed)done.add(key);return {ok:true,targetId:target.id,...(!same?{presentationUnavailable:true}:{})};
  }
  try{
   const result=fn(target,effect);
   if(result&&typeof result.then==='function'){
    const receipt=Promise.resolve(result).then(confirmed,()=>({ok:false,reason:'effect_rejected'})).finally(()=>{if(key)pending.delete(key);});if(key)pending.set(key,receipt);return receipt;
   }
   return confirmed(result);
  }catch{return {ok:false,reason:'effect_rejected'};}
 }
 return {pick,pickGround,get,hasLineOfSight,performEffect,dispose(){disposed=true;byId.clear();byObject.clear();done.clear();pending.clear();requests.clear();}};
}
