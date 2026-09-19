import {advanceEntryHold,HOLD_SECONDS} from './car_entry.mjs';
import {findVehicleEntry,vehicleSeat} from './vehicle_seats.mjs';

// This adapter never adds a car to the local fleet or grants ownership. The
// source bridge decides locks, police restrictions, occupancy and every action.
// A source-approved ID change (traffic -> quest) is explicit, never guessed by
// proximity/model; both identities remain available to the walk host.
export function createWorldVehiclePlayerAccess({traffic,bridge,worldScale=4.1,now=()=>performance.now()}={}){
 const records=new Map();let requestSequence=0,operation=null,held=0,holdKey='',armed=true,disposed=false;
 const denied=reason=>({accepted:false,pending:false,reason});
 function access(carId,requestId){
  if(disposed||typeof bridge?.getWalkVehicleAccess!=='function')return {available:false,reason:'source-unavailable',seats:[]};
  try{return bridge.getWalkVehicleAccess({carId,requestId})||{available:false,reason:'source-unavailable',seats:[]};}
  catch{return {available:false,reason:'source-unavailable',seats:[]};}
 }
 function getRecord(carId,receipt=null){
  const presentationCarId=receipt?.presentationCarId||carId,car=traffic?.getActor(presentationCarId);
  if(!car?.object?.parent)return null;
  let record=records.get(carId);
  if(!record){record={id:carId,sourceCarId:carId,presentationCarId,sourceOwned:true,car,state:{}};records.set(carId,record);}
  record.car=car;record.presentationCarId=presentationCarId;
  const object=car.object,s=record.state;
  Object.assign(s,{x:object.position.x,z:object.position.z,y:object.position.y,yaw:object.rotation.y,seats:car.seats,vehicleProfile:car.profile,speed:Number(receipt?.speed)||0});
  return record;
 }
 function findEntry(position,walkAllowed,{range=1.3}={}){
  if(disposed||!position||operation?.pending)return null;
  let nearest=null;
  for(const row of traffic?.getActors()||[]){
   const car=row.actor||traffic.getActor(row.id),p=car?.object?.position;
   if(!p||car.object.visible===false||!Array.isArray(car.seats)||!car.seats.length||Math.hypot(p.x-position.x,p.z-position.z)>(car.profile?.halfLength||3)+range+2.5)continue;
   const permission=access(row.id);if(permission.available!==true)continue;
   const record=getRecord(row.id,permission);if(!record)continue;
   const allowed=new Set((permission.seats||[]).filter(s=>s.available===true).map(s=>s.id));
   const occupiedSeats=(car.seats||[]).filter(s=>!allowed.has(s.id)).map(s=>s.id);
   const candidate=findVehicleEntry(record.state,position,walkAllowed,{range,occupiedSeats});
   if(candidate&&candidate.near<(nearest?.near??Infinity))nearest={...candidate,record,sourceCarId:record.sourceCarId,presentationCarId:record.presentationCarId,sourceOwned:true,label:`${car.profile?.label||'Машина'} · ${candidate.label}`};
  }
  return nearest;
 }
 function advanceHold(pressed,candidate,dt){
  if(!pressed){held=0;holdKey='';armed=true;return {elapsed:0,ready:false};}
  const key=candidate?`${candidate.sourceCarId}:${candidate.seatId}`:'';
  if(key!==holdKey){held=0;holdKey=key;}
  const result=advanceEntryHold(held,pressed,armed&&!!key&&!operation?.pending,dt,HOLD_SECONDS);held=result.elapsed;
  if(result.ready)armed=false;
  return result;
 }
 const playerPoint=point=>point&&[point.x,point.z,point.yaw].every(Number.isFinite)?{r:point.z/worldScale,c:point.x/worldScale,ang:Math.PI/2-point.yaw}:null;
 function acceptReceipt(request,receipt){
  if(!receipt||receipt.accepted!==true)return {...denied(receipt?.reason||'source-denied'),pending:receipt?.pending===true,requestId:request.requestId,sourceCarId:request.carId,seatId:request.seatId};
  // Do not accept a different seat or unrelated car silently, especially when
  // the server only supports a subset of the rendered vehicle's four seats.
  if(receipt.sourceCarId!==request.carId||receipt.seatId!==request.seatId)return denied('source-identity-mismatch');
  return {...receipt,requestId:request.requestId,sourceCarId:request.carId,seatId:request.seatId,pending:receipt.pending===true};
 }
 async function request(action,{carId,seatId,player,pose,requestId}={}){
  if(!['enter','exit','drive'].includes(action))return denied('unknown-action');
  if(disposed||typeof bridge?.performWalkVehicleAction!=='function')return denied('source-unavailable');
  if(operation?.pending)return denied('source-pending');
  const permission=access(carId),record=getRecord(carId,permission);
  if(!record)return denied('vehicle-unloaded');
  try{vehicleSeat(seatId,record.state);}catch{return denied('seat-unavailable');}
  if(action==='enter'&&(permission.available!==true||!permission.seats?.some(s=>s.id===seatId&&s.available===true)))return denied(permission.reason||'seat-unavailable');
  if(action!=='enter'&&permission.occupiedSeatId!==seatId)return denied('not-occupant');
  if(action==='drive'&&(seatId!=='front_left'||permission.canDrive!==true))return denied('not-driver');
  const sourcePlayer=playerPoint(player);if(!sourcePlayer)return denied('invalid-player-position');
  const payload={action,carId,seatId,requestId:requestId||`walk-vehicle:${++requestSequence}`,player:sourcePlayer};
  if(action==='drive'){
   if(!pose||![pose.x,pose.z,pose.yaw,pose.vx,pose.vz].every(Number.isFinite))return denied('invalid-drive-pose');
   payload.pose={r:pose.z/worldScale,c:pose.x/worldScale,ang:Math.PI/2-pose.yaw,vr:pose.vz/worldScale,vc:pose.vx/worldScale,steer:Number(pose.steer)||0};
  }
  const pending={...payload,pending:true,accepted:false,startedAt:now()};operation=pending;
  let result;try{result=acceptReceipt(payload,await bridge.performWalkVehicleAction(payload));}catch{result={...denied('source-unavailable'),requestId:payload.requestId};}
  if(disposed||operation!==pending)return denied('superseded');
  operation={...result,action,carId,startedAt:pending.startedAt};return {...operation};
 }
 function poll(){
  if(!operation?.pending)return operation?{...operation}:null;
  const receipt=access(operation.carId,operation.requestId);
  if(receipt.pending===true)return {...operation};
  // Query replies must carry an explicit operation result; lack of a packet
  // is not confirmation, and cannot give local driving authority.
  if(typeof receipt.accepted!=='boolean')return {...operation};
  operation={...acceptReceipt({...operation,carId:operation.carId},receipt),action:operation.action,carId:operation.carId,startedAt:operation.startedAt};
  return {...operation};
 }
 return {access,getRecord,findEntry,advanceHold,request,poll,get operation(){return operation?{...operation}:null;},dispose(){disposed=true;records.clear();held=0;holdKey='';}};
}
