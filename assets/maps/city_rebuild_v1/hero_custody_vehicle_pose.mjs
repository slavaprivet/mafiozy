import {createNpcTrafficVehicleBinding,resolveNpcVehicleBinding,applyNpcVehicleBinding} from './npc_vehicle_pose.mjs';

// Presentation only: the source retains vehicle ownership and the hero root.
export function createHeroCustodyVehiclePose({THREE,getVehicle}={}){
 const bindings=new WeakMap();let currentWalker=null,active=false,hidden=false;
 const requested=source=>source?.arrestPhase==='transport'&&!source.healthDead&&!source.dead;
 function prepare(walker,source){
  const next=requested(source);
  if(currentWalker&&(!next||currentWalker!==walker)){
   currentWalker.reset();if(hidden)currentWalker.object.visible=true;hidden=false;
  }
  currentWalker=next?walker:null;active=next;return {active};
 }
 function apply(walker,source,dt=0){
  if(!active||currentWalker!==walker)return {active:false,bound:false};
  const id=String(source.custodyVehicleId||''),seatId=source.custodySeatId;
  const actor=id&&getVehicle?.(id);
  let vehicle=actor&&bindings.get(actor);
  if(actor&&!vehicle){vehicle=createNpcTrafficVehicleBinding({THREE,actor});if(vehicle)bindings.set(actor,vehicle);}
  const binding=['rear_left','rear_right'].includes(seatId)&&resolveNpcVehicleBinding({civilianTripRiding:true,civilianTripPhase:'drive',civilianTripCarId:id,vehicleSeatId:seatId},()=>vehicle);
  // Loading is asynchronous. Never expose an upright hero in the car roof
  // while the exact source vehicle or its reserved passenger seat is absent.
  if(!binding){walker.object.visible=false;hidden=true;return {active:true,bound:false,carId:id,seatId};}
  if(hidden)walker.object.visible=true;hidden=false;
  applyNpcVehicleBinding({THREE,walker,binding,dt});
  return {active:true,bound:true,carId:id,seatId};
 }
 return {prepare,apply};
}
