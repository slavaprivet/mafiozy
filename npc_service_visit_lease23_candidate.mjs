// Single-station customer lease/movement adapter. Not imported by world.
import {advanceStationaryServiceActor} from './assets/maps/city_rebuild_v1/npc_stationary_service_adapter.mjs';
const exitCertificates=new WeakMap();
const yes=(fn,...args)=>{try{return fn?.(...args)===true;}catch{return false;}};
function servicePoints(layout,host,visit,metresPerCell){
 const inside=visit?.door?.inside;let entrance;try{entrance=host.entranceInside(visit);}catch{return null;}
 if(!inside||!entrance||![inside.r,inside.c,entrance.r,entrance.c].every(Number.isFinite))return null;
 const point=p=>({r:p.z/metresPerCell,c:p.x/metresPerCell,y:p.y}),via=point(layout.customerVia);
 via.r+=inside.r-entrance.r;via.c+=inside.c-entrance.c;
 return[{r:inside.r,c:inside.c,y:layout.customer.y},via,point(layout.customer)];
}
// A cancelled purchase loses its service slot. The existing source visit still
// owns physical exit, through independently current geometry/control guards.
export function createServiceExitMovement23({layout,host,metresPerCell=4.1}){
 if(!yes(host.validateLayout,layout))throw Error('Certified source exit required');
 return input=>{
  const {npc,visit,target,now,dt}=input,route=visit?._serviceRoute23,binding=exitCertificates.get(route?.certificate);
  const allowed=()=>{
   if(visit?.phase!=='exiting'||!route||binding?.npc!==npc||binding.visit!==visit||binding.visitId!==route.visitId||route.certificate.stamp!==route.stamp||route.buildingId!==layout.buildingId||route.siteRevision!==layout.revision||!yes(host.isCurrentSite,layout)||!yes(host.canControl,npc,visit,now))return false;
   try{const id=host.identity(npc);return host.currentVisit(npc)===visit&&id.id===route.customerId&&id.generation===route.generation;}catch{return false;}
  };
  const points=servicePoints(layout,host,visit,metresPerCell);
  if(!allowed()||!points||!Array.isArray(route.points)||route.points.length!==points.length||!points.every((p,i)=>['r','c','y'].every(k=>p[k]===route.points[i][k]))||!points.some(p=>['r','c','y'].every(k=>p[k]===target?.[k])))return{status:'hold',reason:'source-exit-owner-or-certificate'};
  return advanceStationaryServiceActor({actor:npc,target:{x:target.c*metresPerCell,y:target.y,z:target.r*metresPerCell},actorId:route.customerId,generation:route.generation,controlToken:'exit:'+visit.id+':'+route.stamp,dt,metresPerCell,arrivalMetres:.01},
   {identity:host.identity,hasControl:allowed,canSweep:(from,to)=>yes(host.canSweep,from,to,npc),isStationFloor:(p,y)=>yes(host.isStationFloor,p,y,npc)});
 };
}
export function createServiceVisitLease23({layout,host,metresPerCell=4.1}){
 if(!layout?.customerVia||!yes(host.validateLayout,layout)||!Number.isFinite(metresPerCell)||metresPerCell<=0)throw Error('Certified service route required');
 const point=p=>({r:p.z/metresPerCell,c:p.x/metresPerCell,y:p.y});
 let lease=null,serial=0,disposed=false;
 function identity(n){try{return host.identity(n);}catch{return null;}}
 function valid(now){
  if(disposed||!lease||!Number.isFinite(now)||now<lease.lastNow||now>lease.until||!yes(host.isCurrentSite,layout))return false;
  const n=lease.npc,id=identity(n);
  let visit;try{visit=host.currentVisit(n);}catch{return false;}
  return yes(host.isPresent,n)&&!n.dead&&n.alive!==false&&Number.isFinite(n.hp)&&n.hp>0&&id?.id===lease.customerId&&id.generation===lease.generation&&visit===lease.visit&&visit.id===lease.visitId&&yes(host.canControl,n,visit,now);
 }
 function owns(input){return valid(input.now)&&lease.npc===input.npc&&lease.visit===input.visit;}
 function release(input){if(lease?.npc!==input.npc||lease.visit!==input.visit)return false;lease=null;return true;}
 function acquire(input){
  const {npc,visit,now}=input;if(disposed||!Number.isFinite(now)||!yes(host.isCurrentSite,layout))return false;
  if(lease&&!valid(now))lease=null;
  if(owns(input)){lease.lastNow=now;lease.until=now+20000;return true;}
  if(lease||!yes(host.employeeReady,now)||!yes(host.canControl,npc,visit,now)||typeof visit?.id!=='string'||!visit.id||(visit.door?.instanceId||visit.door?.id)!==layout.buildingId)return false;
  const id=identity(npc);
  let current;try{current=host.currentVisit(npc);}catch{return false;}
  if(typeof id?.id!=='string'||!id.id||!Number.isSafeInteger(id.generation)||id.generation<1||npc.dead||npc.alive===false||!Number.isFinite(npc.hp)||npc.hp<=0||current!==visit)return false;
  const token=JSON.stringify([layout.buildingId,layout.revision,layout.stationId,id.id,id.generation,visit.id,++serial]);
  lease={npc,visit,visitId:visit.id,customerId:id.id,generation:id.generation,token,lastNow:now,until:now+20000};return true;
 }
 function touch(input){if(!owns(input))return false;lease.lastNow=input.now;lease.until=input.now+20000;return true;}
 function target(input){return owns(input)?{...point(layout.customer),stamp:lease.token}:null;}
 function route(input){
  if(!owns(input))return null;
  if(lease.route)return lease.route;
  // Preserve the actual public-door entry lane until past its open leaf.
  // Moving sideways toward the nominal centre too early clips that leaf.
  const points=servicePoints(layout,host,input.visit,metresPerCell);
  if(!points||!yes(host.validateRoute,points,input.npc))return null;
  lease.route=Object.freeze({visitId:lease.visitId,stamp:lease.token,buildingId:layout.buildingId,siteRevision:layout.revision,customerId:lease.customerId,generation:lease.generation,points:Object.freeze(points.map(p=>Object.freeze(p)))});
  exitCertificates.set(lease.route,{npc:lease.npc,visit:lease.visit,visitId:lease.visitId});
  return lease.route;
 }
 function move(input){
  if(!owns(input)||!yes(host.canControl,input.npc,input.visit,input.now))return{status:'hold',reason:'service-visit-owner'};
  const certificate=route(input),p=input.target;
  if(!certificate?.points.some(q=>q.r===p?.r&&q.c===p?.c&&q.y===p?.y))return{status:'hold',reason:'uncertified-service-waypoint'};
  const token=lease.token,generation=lease.generation,actorId=lease.customerId;
  return advanceStationaryServiceActor({actor:input.npc,target:{x:p.c*metresPerCell,y:p.y,z:p.r*metresPerCell},actorId,generation,controlToken:token,dt:input.dt,metresPerCell,arrivalMetres:.01},
   {identity,hasControl:()=>owns(input)&&lease.token===token&&yes(host.canControl,input.npc,input.visit,input.now),
    canSweep:(from,to)=>yes(host.canSweep,from,to,input.npc),isStationFloor:(at,y)=>yes(host.isStationFloor,at,y,input.npc)});
 }
 return{acquireServiceVisit:acquire,touchServiceVisit:touch,releaseServiceVisit:release,getServiceArrivalTarget:target,getServiceRoute:route,advanceServiceVisit:move,
  ownsServiceSlot:({customerId,generation,visitId})=>{let now;try{now=host.now();}catch{return false;}return !!lease&&valid(now)&&lease.customerId===customerId&&lease.generation===generation&&lease.visitId===visitId;},
  disposeServiceVisits(){disposed=true;lease=null;},
  snapshot:()=>lease?{customerId:lease.customerId,generation:lease.generation,visitId:lease.visitId,until:lease.until}:null};
}
