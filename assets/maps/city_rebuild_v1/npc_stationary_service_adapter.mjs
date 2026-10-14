// Opt-in stationary-service boundary for the existing resident checkout.
// Checkout never writes money; the optional movement executor uses host-owned sweeps.
const name=x=>typeof x==='string'&&x.length>0;
const money=x=>Number.isSafeInteger(x)&&x>=0&&x<=0x7fffffff;
export function createStationaryServiceAdapter({buildingId,mode='session',getServiceAccess,getNeedsBinding=()=>null}={}){
 if(!name(buildingId)||mode!=='session'||typeof getServiceAccess!=='function'||typeof getNeedsBinding!=='function')throw Error('Session stationary service adapter required');
 const stamp=a=>JSON.stringify([buildingId,a.siteRevision,a.stationId,a.employeeId,a.employeeGeneration,a.customerId,a.customerGeneration,a.visitId]);
 function accessFor({npc,visit,now}){
  const a=getServiceAccess({npc,visit,now});
  if(a?.eligible!==true||a.buildingId!==buildingId||a.customerId!==String(npc.id)||!name(a.siteRevision)||!name(a.stationId)||!name(a.employeeId)||!Number.isSafeInteger(a.employeeGeneration)||a.employeeGeneration<1||!Number.isSafeInteger(a.customerGeneration)||a.customerGeneration<1||!name(a.visitId)||(visit.door.instanceId||visit.door.id)!==buildingId)return null;
  return a;
 }
 return{
  canServe(input){const a=accessFor(input);return a?{available:true,stamp:stamp(a)}:{available:false,reason:'employee-or-customer-unavailable'};},
  onPurchase(input){
   const {npc,visit,receipt,balanceBefore,balanceAfter}=input,wallet=npc._residentWallet,order=visit.commerce,a=accessFor(input);
   // These are the actual source-owned order and receipt objects, not a UI
   // price or a proximity event. Any intervening debit requires reconciliation.
   if(!a||!order?.settled||order.phase!=='complete'||order.serviceStamp!==stamp(a)||!wallet?.receipts.includes(receipt)||receipt.id!==order.id||receipt.doorId!==visit.door.id||receipt.item!==order.item.item||receipt.price!==order.item.price||!money(balanceBefore)||!money(balanceAfter)||balanceBefore-receipt.price!==balanceAfter||wallet.balance!==balanceAfter)return{accepted:false,reason:'account-sync-required'};
   const binding=getNeedsBinding(npc);if(!binding)return{accepted:true,mirrored:false};
   const {state,applyReceipt}=binding;
   if(state?.mode!=='session'||state.npcId!==String(npc.id)||typeof applyReceipt!=='function'||state.account.cash!==balanceBefore||state.goal?.kind!=='shop'||state.goal.placeId!==visit.door.id)return{accepted:false,reason:'account-sync-required'};
   const event={id:'resident-commerce:'+receipt.id,npcId:state.npcId,accepted:true,sequence:state.account.sequence+1,authority:'session',kind:'purchase',goalId:state.goal.id,placeId:receipt.doorId,visitId:a.visitId,amount:receipt.price,completedAt:input.now};
   const result=applyReceipt(state,event,{
    verifyReceipt:r=>r===event&&wallet.receipts.includes(receipt)&&wallet.balance===balanceAfter,
    hasPhysicalArrival:r=>r.npcId===a.customerId&&r.goalId===event.goalId&&r.placeId===event.placeId&&r.visitId===a.visitId&&accessFor(input)!==null
   });
   return result.accepted?{accepted:true,mirrored:true,receiptId:event.id}:{accepted:false,reason:'account-sync-required',detail:result.reason};
  }
 };
}

// Precise ground-floor station movement, opt-in under an existing source owner.
// Paths come from certified station waypoints; this is not a new pathfinder.
export function advanceStationaryServiceActor({actor,target,actorId,generation,controlToken,dt,speedMps=1.25,metresPerCell=4.1,arrivalMetres=.08}={},host={}){
 if(!actor||!name(actorId)||!name(controlToken)||!Number.isSafeInteger(generation)||generation<1||!target||![target.x,target.y,target.z,actor.r,actor.c,dt,speedMps,metresPerCell,arrivalMetres].every(Number.isFinite)||metresPerCell<=0||speedMps<=0||speedMps>3||arrivalMetres<0||arrivalMetres>.12||dt<0)return{status:'hold',reason:'invalid-service-movement',movedMetres:0};
 let movedMetres=0;
 const permitted=()=>{
  if(actor.dead||actor.alive===false||!Number.isFinite(actor.hp)||actor.hp<=0)return false;
  try{const identity=host.identity?.(actor);return identity?.id===actorId&&identity.generation===generation&&host.hasControl?.({actor,actorId,generation,controlToken})===true;}catch{return false;}
 };
 if(!permitted())return{status:'hold',reason:'source-owner-or-generation',movedMetres};
 if(dt===0||dt>1)return{status:'hold',reason:'elapsed-gap',movedMetres};
 const goalR=target.z/metresPerCell,goalC=target.x/metresPerCell,seconds=Math.min(dt,.35),steps=Math.ceil(seconds/.05),stepTime=seconds/steps;
 for(let i=0;i<steps;i++){
  if(!permitted())return{status:'hold',reason:'source-owner-or-generation',movedMetres};
  const dr=goalR-actor.r,dc=goalC-actor.c,distance=Math.hypot(dr,dc)*metresPerCell;
  if(distance<=arrivalMetres){
   const position={r:actor.r,c:actor.c};let safe=false;
   try{safe=host.isStationFloor?.(position,target.y)===true&&host.canSweep?.(position,position)===true;}catch{}
   if(!permitted())return{status:'hold',reason:'source-owner-or-generation',movedMetres};
   actor.walking=false;
   return safe?{status:'arrived',movedMetres}:{status:'blocked',reason:'service-arrival-occupied-or-floor',movedMetres};
  }
  const step=Math.min(distance,speedMps*stepTime),ratio=step/distance,next={r:actor.r+dr*ratio,c:actor.c+dc*ratio},from={r:actor.r,c:actor.c};
  let safe=false;
  try{safe=host.canSweep?.(from,next)===true&&host.isStationFloor?.(next,target.y)===true;}catch{}
  if(!permitted())return{status:'hold',reason:'source-owner-or-generation',movedMetres};
  if(!safe){actor.walking=false;return{status:'blocked',reason:'service-path-occupied',movedMetres};}
  actor.r=next.r;actor.c=next.c;actor.ang=Math.atan2(dr,dc);actor.walking=true;actor.walkPhase=(actor.walkPhase||0)+stepTime*8;movedMetres+=step;
 }
 const arrived=Math.hypot(goalR-actor.r,goalC-actor.c)*metresPerCell<=arrivalMetres;if(arrived)actor.walking=false;
 return{status:arrived?'arrived':'moving',movedMetres};
}
