// Isolated source-state candidate. Emits intentions only: no NPC spawn, HP,
// movement, door mutation, money, stock, renderer visibility or server authority.
const id=x=>typeof x==='string'&&x.length>0&&x.length<=240;
const point=p=>p&&['x','y','z'].every(k=>Number.isFinite(p[k]));
const generation=n=>Number.isSafeInteger(n)&&n>=1;
const clone=x=>JSON.parse(JSON.stringify(x));
const distance=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y,a.z-b.z);
const alive=a=>a&&!a.dead&&a.alive!==false&&Number.isFinite(a.hp)&&a.hp>0;
const occupied=a=>a.panic||a.combat||a.custody||a.medicalOwned||a.reportingCrime;
const safeCall=(fn,...args)=>{try{return typeof fn==='function'&&fn(...args)===true}catch{return false}};
const sameSpawn=(a,b)=>!!a&&!!b&&['accepted','requestId','buildingId','siteRevision','employeeId','generation','spawnedAt','authority'].every(k=>a[k]===b[k])&&point(a.position)&&point(b.position)&&['x','y','z'].every(k=>a.position[k]===b.position[k]);
export function createServiceEmployee23({layout,employeeId,employeeGeneration,initialPhase='working'},host={}){
 if(!layout||!id(layout.buildingId)||!id(layout.revision)||!id(layout.stationId)||!id(layout.roomId)||!id(layout.doorId)||!id(employeeId)||!generation(employeeGeneration)||!['working','backroom'].includes(initialPhase)||!['spawn','doorInside','doorOutside','work','customer'].every(k=>point(layout[k]))||!safeCall(host.validateLayout,layout))throw Error('Certified service layout required');
 return{version:1,layout:clone(layout),employeeId,generation:employeeGeneration,phase:initialPhase,death:null,respawn:null,lastNow:0,available:false};
}
export function stepServiceEmployee23(state,snapshot,host={}){
 state.available=false;
 const {now,actor,door}=snapshot||{},layout=state.layout;
 if(!Number.isFinite(now)||now<state.lastNow||snapshot.siteRevision!==layout.revision||!safeCall(host.isCurrentSite,layout))return{status:'hold',reason:'stale-site-or-clock'};
 state.lastNow=now;
 // The host supplies a persistent source actor record, never renderer presence.
 if(actor&&actor.id!==state.employeeId)return{status:'hold',reason:'wrong-employee'};
 const receipt=snapshot.spawnReceipt;
 if(receipt&&sameSpawn(receipt,state.lastSpawn)&&!safeCall(host.verifySpawnReceipt,receipt,layout))return{status:'hold',reason:'unverified-respawn'};
 if(receipt&&!sameSpawn(receipt,state.lastSpawn)){
  const pending=state.respawn;
  const diedAfterSpawn=actor&&(actor.dead===true||actor.alive===false||actor.hp===0)&&Number.isFinite(actor.deadAt)&&actor.deadAt>=receipt.spawnedAt&&actor.deadAt<=now&&id(actor.deathReceiptId)&&safeCall(host.verifyDeath,actor);
  if(!pending||receipt.accepted!==true||receipt.requestId!==pending.requestId||receipt.buildingId!==layout.buildingId||receipt.siteRevision!==layout.revision||receipt.employeeId!==state.employeeId||receipt.generation!==state.generation+1||!generation(receipt.generation)||!Number.isFinite(receipt.spawnedAt)||receipt.spawnedAt<state.death.dueAt||receipt.spawnedAt<pending.issuedAt||receipt.spawnedAt>now||!point(receipt.position)||distance(receipt.position,layout.spawn)>.05||!alive(actor)&&!diedAfterSpawn||actor.generation!==receipt.generation||!point(actor.position)||!diedAfterSpawn&&distance(actor.position,receipt.position)>.05||!safeCall(host.verifySpawnReceipt,receipt,layout))return{status:'hold',reason:'unverified-respawn'};
  state.generation=receipt.generation;state.phase='backroom';state.death=null;state.respawn=null;state.lastSpawn=clone(receipt);
 }
 if(actor&&actor.generation!==state.generation)return{status:'hold',reason:'generation-mismatch'};
 if(actor&&!alive(actor)){
  if(!actor.dead&&actor.alive!==false&&actor.hp!==0)return{status:'hold',reason:'invalid-health'};
  if(!state.death){
   if(!Number.isFinite(actor.deadAt)||actor.deadAt>now||actor.deadAt<0||!id(actor.deathReceiptId)||!safeCall(host.verifyDeath,actor))return{status:'hold',reason:'unverified-death'};
   state.death={at:actor.deadAt,dueAt:actor.deadAt+60000,receiptId:actor.deathReceiptId};state.phase='dead';
  }
 }
 if(state.death){
  if(now<state.death.dueAt)return{status:'unavailable',reason:'employee-dead',until:state.death.dueAt,cancelService:true};
  if(state.respawn)return{status:'pending',reason:now-state.respawn.issuedAt>5000?'respawn-confirmation-required':'respawn-pending',requestId:state.respawn.requestId,cancelService:true};
  if(!generation(state.generation+1))return{status:'hold',reason:'generation-overflow'};
  if(!door||door.id!==layout.doorId||!Number.isFinite(door.fraction)||door.fraction<0||door.fraction>.01||!safeCall(host.canSpawnInClosedRoom,layout,now))return{status:'unavailable',reason:'backroom-not-ready',cancelService:true};
  state.respawn={requestId:`${layout.stationId}:${state.employeeId}:${state.generation+1}:respawn`,issuedAt:now};
  return{status:'intent',intent:{kind:'respawn-in-backroom',...state.respawn,employeeId:state.employeeId,generation:state.generation+1,buildingId:layout.buildingId,siteRevision:layout.revision,position:clone(layout.spawn)},cancelService:true};
 }
 if(!alive(actor)||!point(actor.position))return{status:'hold',reason:'source-employee-unavailable'};
 if(occupied(actor))return{status:'hold',reason:'existing-crime-or-medical-owner',cancelService:true};
 const walk=target=>({status:'intent',intent:{kind:'walk',employeeId:state.employeeId,generation:state.generation,buildingId:layout.buildingId,siteRevision:layout.revision,target:clone(target),requireSweptMovement:true}});
 const setDoor=open=>({status:'intent',intent:{kind:'set-service-door',doorId:layout.doorId,buildingId:layout.buildingId,siteRevision:layout.revision,open,requireClearSweep:true}});
 if(['backroom','opening','exiting','closing'].includes(state.phase)){
  if(!door||door.id!==layout.doorId||!Number.isFinite(door.fraction)||door.fraction<0||door.fraction>1)return{status:'hold',reason:'service-door-unavailable'};
  if(state.phase==='backroom'){
   if(distance(actor.position,layout.doorInside)>.12)return walk(layout.doorInside);
   state.phase='opening';
  }
  if(state.phase==='opening'){
   if(door.fraction<.95)return setDoor(true);
   state.phase='exiting';
  }
  if(state.phase==='exiting'){
   if(door.fraction<.95)return setDoor(true);
   if(distance(actor.position,layout.doorOutside)>.12)return walk(layout.doorOutside);
   state.phase='closing';
  }
  if(state.phase==='closing'){
   if(door.fraction>.01){if(!safeCall(host.doorSweepClear,layout,actor))return{status:'hold',reason:'door-sweep-occupied'};return setDoor(false);}
   state.phase='returning';
  }
 }
 if(distance(actor.position,layout.work)>.12){state.phase='returning';return walk(layout.work);}
 state.phase='working';state.available=true;
 return{status:'working',available:true,employeeId:state.employeeId,generation:state.generation};
}
// Re-evaluate at atomic commit time as well. A prior quote is not permission to
// spend after the employee dies, leaves, panics or is replaced by a generation.
export function serviceEligibility23(state,{now,actor,customer,siteRevision,visitId}={},host={}){
 const layout=state.layout;
 if(now!==state.lastNow||siteRevision!==layout.revision||!safeCall(host.isCurrentSite,layout))return{eligible:false,reason:'fresh-source-required'};
 if(!state.available||state.phase!=='working'||state.death||actor?.id!==state.employeeId||actor.generation!==state.generation||!alive(actor)||occupied(actor)||!point(actor.position)||distance(actor.position,layout.work)>.12)return{eligible:false,reason:'employee-unavailable'};
 if(!id(customer?.id)||!generation(customer.generation)||!alive(customer)||occupied(customer)||!point(customer.position)||distance(customer.position,layout.customer)>.2||!id(visitId)||!safeCall(host.ownsServiceSlot,{stationId:layout.stationId,customerId:customer.id,generation:customer.generation,visitId}))return{eligible:false,reason:'customer-arrival-or-slot-required'};
 return{eligible:true,buildingId:layout.buildingId,siteRevision:layout.revision,stationId:layout.stationId,employeeId:state.employeeId,employeeGeneration:state.generation,customerId:customer.id,customerGeneration:customer.generation,visitId};
}
