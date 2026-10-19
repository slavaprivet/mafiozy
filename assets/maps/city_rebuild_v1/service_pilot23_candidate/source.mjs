// Isolated single-printshop source activation proposal. World does not import it.
import {createServiceEmployee23,stepServiceEmployee23,serviceEligibility23} from './employee.mjs';
import {advanceStationaryServiceActor} from '../npc_stationary_service_adapter.mjs';
const PILOT='REBUILD-VISUAL-print_shop-001';
const yes=(fn,...args)=>{try{return fn?.(...args)===true;}catch{return false;}};
export function createStationaryServiceSource23({station,host,metresPerCell=4.1}){
 const layout=station?.layout;
 if(layout?.buildingId!==PILOT||!Array.isArray(host?.npcs)||typeof host.spawnNpc!=='function'||!yes(host.validateLayout,layout)||!Number.isFinite(metresPerCell)||!(metresPerCell>0))throw Error('Certified single printshop source host required');
 const employmentId=layout.stationId+':employee',token=layout.revision+':'+employmentId;
 let body=null,sourceGeneration=0,birth=null,pending=null,death=null,lastNow=-Infinity,retryAt=0,seed=230000,disposed=false,births=0;
 const state=createServiceEmployee23({layout,employeeId:employmentId,employeeGeneration:1,initialPhase:'backroom'}, {validateLayout:()=>true});
 function bindingMatches(n){const m=n?._stationaryService;return n===body&&m?.employmentId===employmentId&&m.generation===sourceGeneration&&m.buildingId===layout.buildingId&&m.siteRevision===layout.revision;}
 function owned(n){return !disposed&&bindingMatches(n)&&sourceGeneration===state.generation&&host.npcs.includes(n);}
 function sourceBusy(n,now){return !n||!bindingMatches(n)||!host.npcs.includes(n)||!yes(host.canControl,n,now)||n.dead||n.alive===false||!Number.isFinite(n.hp)||n.hp<=0;}
 function position(n){let y=NaN;try{y=host.groundHeight(n);}catch{}return{x:n.c*metresPerCell,y,z:n.r*metresPerCell};}
 function occupants(){try{return host.occupants();}catch{return null;}}
 function view(){
  if(!body)return null;
  const busy=sourceBusy(body,lastNow),dead=body.dead===true||body.alive===false||body.hp===0;
  if(dead&&!death&&yes(host.verifyDeath,body,lastNow))death={sourceId:body.id,generation:sourceGeneration,at:body.deadAt,key:employmentId+':'+body.id+':'+body.deadAt};
  return{id:employmentId,generation:sourceGeneration,hp:body.hp,dead:body.dead,alive:body.alive,deadAt:body.deadAt,deathReceiptId:death?.key,position:position(body),medicalOwned:busy&&!dead};
 }
 const lifecycleHost={validateLayout:()=>true,isCurrentSite:l=>yes(host.isCurrentSite,l),
  verifyDeath:a=>!!death&&a.deathReceiptId===death.key&&a.deadAt===death.at&&a.generation===death.generation,
  verifySpawnReceipt:r=>r===birth&&r.sourceBodyId===body?.id&&r.generation===sourceGeneration,
  canSpawnInClosedRoom:()=>canBirth(lastNow),
  doorSweepClear:()=>station.sweptClear(station.doorState.fraction,0,occupants()),
  ownsServiceSlot:q=>yes(host.ownsServiceSlot,q)};
 function canBirth(now){
  return !disposed&&yes(host.isCurrentSite,layout)&&station.doorState.fraction<=.01&&
   yes(host.canSpawnHidden,layout,now)&&yes(host.canOccupySpawn,layout.spawn,now);
 }
 function spawn(now,request=null){
  if(now<retryAt||!canBirth(now))return false;
  retryAt=now+500;
  const previous=body,generation=request?.generation||1;
  if(request&&(!death||now<death.at+60000||state.generation+1!==generation))return false;
  let fresh;try{fresh=host.spawnNpc(++seed,{cityOnly:true});}catch{return false;}
  // The existing factory has not published the object. Set birth coordinates
  // only before insertion, never relocate a rendered/source resident.
  if(!fresh||typeof fresh.id!=='string'||!fresh.id.startsWith('resident_')||host.npcs.some(n=>n===fresh||n.id===fresh.id)||!Number.isFinite(fresh.hp)||fresh.hp<=0||fresh.dead||fresh._cashier||fresh._uniqueNpc||fresh._said||fresh._invulnerable||fresh._arc?.panicMult===0)return false;
  if(body!==previous||!canBirth(now))return false;
  fresh.r=fresh.tr=layout.spawn.z/metresPerCell;fresh.c=fresh.tc=layout.spawn.x/metresPerCell;
  fresh.walking=false;fresh.walkPhase=0;fresh.name='Продавец газет';
  fresh._stationaryService={employmentId,generation,buildingId:layout.buildingId,siteRevision:layout.revision};
  if(request)birth={accepted:true,requestId:request.requestId,buildingId:layout.buildingId,siteRevision:layout.revision,employeeId:employmentId,generation,sourceBodyId:fresh.id,spawnedAt:now,position:{...layout.spawn},authority:'session-source'};
  body=fresh;sourceGeneration=generation;host.npcs.push(fresh);births++;pending=null;death=null;return true;
 }
 const movementHost={identity:n=>({id:n._stationaryService?.employmentId,generation:n._stationaryService?.generation}),
  hasControl:({actor,controlToken})=>controlToken===token&&owned(actor)&&!sourceBusy(actor,lastNow)&&yes(host.isCurrentSite,layout),
  canSweep:(from,to)=>yes(host.canSweep,from,to,body),
  isStationFloor:(point,y)=>yes(host.isStationFloor,point,y,body)};
 function tick(now,dt){
  if(disposed||!Number.isFinite(now)||now<lastNow||!Number.isFinite(dt)||dt<0||!yes(host.isCurrentSite,layout))return{status:'hold',reason:'stale-service-source'};
  lastNow=now;
  if(!body&&!spawn(now))return{status:'hold',reason:'initial-backroom-not-ready'};
  if(pending)spawn(now,pending);
  let result=stepServiceEmployee23(state,{now,actor:view(),siteRevision:layout.revision,door:station.doorState,...(birth?{spawnReceipt:birth}:{})},lifecycleHost);
  if(result.intent?.kind==='respawn-in-backroom'){
   pending=result.intent;
   if(spawn(now,pending))result=stepServiceEmployee23(state,{now,actor:view(),siteRevision:layout.revision,door:station.doorState,spawnReceipt:birth},lifecycleHost);
  }
  let returnMovement=null;
  if(typeof host.advanceEmployeeReturn==='function'){
   try{returnMovement=host.advanceEmployeeReturn({actor:body,now,dt,generation:state.generation,employeeId:employmentId,
    controlled:owned(body)&&!sourceBusy(body,now),returning:state.phase==='returning'&&result.intent?.kind==='walk',
    hasControl:()=>owned(body)&&!sourceBusy(body,now)&&yes(host.isCurrentSite,layout)});}catch{returnMovement={status:'hold',reason:'return-host-unavailable'};}
  }
  if(result.intent?.kind==='walk'&&owned(body)&&!sourceBusy(body,now)){
   const movement=returnMovement||advanceStationaryServiceActor({actor:body,target:result.intent.target,actorId:employmentId,generation:state.generation,controlToken:token,dt,metresPerCell},movementHost);
   result={...result,movement};
  }else if(result.intent?.kind==='set-service-door'&&owned(body)&&!sourceBusy(body,now)){
   const actorPosition=position(body),nearby=occupants();
   if(owned(body)&&!sourceBusy(body,now)&&yes(host.isCurrentSite,layout))result={...result,doorRequest:station.requestDoor(result.intent.open,{actorPosition,occupants:nearby})};
  }
  if(station.needsUpdate){const nearby=occupants();if(yes(host.isCurrentSite,layout))if(station.update(dt,nearby))host.onServiceDoorChanged?.();}
  return result;
 }
 return{tick,owns:n=>owned(n),ownsCalmMovement:(n,now)=>owned(n)&&!sourceBusy(n,now),
  serviceAccess({customer,visitId,now}){return serviceEligibility23(state,{now,actor:view(),customer,visitId,siteRevision:layout.revision},lifecycleHost);},
  get actor(){return body;},get lifecycle(){return state;},get stats(){return{births,employmentId,sourceBodyId:body?.id,generation:state.generation,phase:state.phase};},
  dispose(){host.advanceEmployeeReturn?.dispose?.();disposed=true;state.available=false;if(body&&!body.dead&&body._stationaryService?.employmentId===employmentId)delete body._stationaryService;}};
}
