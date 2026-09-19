import {createNpcTrafficVehicleBinding,resolveNpcVehicleBinding,applyNpcVehicleBinding} from './npc_vehicle_pose.mjs';
import {entryPose} from './car_entry.mjs';

const clamp=value=>Math.max(0,Math.min(1,Number(value)||0));
const posePhases=new Set(['driving','enter','exit']);
const doorPhases=new Set(['approach','open','enter','exit','driving']);

// Source state and its exact actor remain authoritative. This helper owns only
// the hero's visual pose/temporary visibility and the selected door presentation.
// setDoorPose lets the traffic owner flush its existing render batches; it must
// not create a second vehicle or feed the car into local fleet physics.
export function createWorldVehiclePlayerPose({THREE,getVehicle,setDoorPose}={}){
 const bindings=new WeakMap();let walker=null,ownsPose=false,hidden=false,wasVisible=true,door=null,disposed=false;
 const enabled=state=>state?.active===true&&!state.dead&&!state.healthDead&&!state.custodyOwned&&!state.healthCustody;
 function reveal(){if(hidden&&walker){walker.object.visible=wasVisible;hidden=false;}}
 function writeDoor(actor,carId,seatId,doorId,open){
  if(door?.actor===actor&&door.seatId===seatId&&door.open===open)return;
  const value={actor,carId,seatId,doorId,open};
  if(setDoorPose)setDoorPose(value);else actor.setDoorById?.(open,doorId);
  door=value;
 }
 function releaseDoor(){if(door&&door.open!==0)writeDoor(door.actor,door.carId,door.seatId,door.doorId,0);door=null;}
 function prepare(nextWalker,state){
  const active=!disposed&&enabled(state),nextOwns=active&&posePhases.has(state.phase);
  if(walker&&(walker!==nextWalker||ownsPose&&!nextOwns)){reveal();if(ownsPose)walker.reset();}
  // pull_driver has a separate animation owner; never close its door during
  // that handoff. Death/custody likewise take over the source vehicle pose.
  if(!active||!doorPhases.has(state.phase)){if(state?.phase==='pull_driver'||state?.dead||state?.healthDead||state?.custodyOwned||state?.healthCustody)door=null;else releaseDoor();}
  walker=nextWalker;ownsPose=nextOwns;
  return {active,ownsPose,phase:state?.phase||null};
 }
 function apply(nextWalker,state,dt=0){
  const status=prepare(nextWalker,state);if(!status.active||!walker||!doorPhases.has(state.phase))return {...status,bound:false};
  const carId=String(state.presentationCarId||state.sourceCarId||''),seatId=state.seatId,actor=carId&&getVehicle?.(carId),seat=actor?.seats?.find(s=>s.id===seatId);
  const available=actor?.object?.parent&&seat&&(()=>{for(let o=actor.object;o;o=o.parent)if(o.visible===false)return false;return true;})();
  if(!available){
   if(ownsPose&&!hidden){wasVisible=walker.object.visible;walker.object.visible=false;hidden=true;}
   return {...status,bound:false,carId,seatId,reason:'vehicle-unavailable'};
  }
  if(door&&(door.actor!==actor||door.seatId!==seatId))releaseDoor();
  const progress=clamp(state.progress),doorOpen=state.phase==='open'?progress:state.phase==='enter'?entryPose(progress).door:state.phase==='exit'?entryPose(progress,true).door:0;
  writeDoor(actor,carId,seatId,seat.doorId||seatId,doorOpen);
  if(!ownsPose)return {...status,bound:false,carId,seatId,doorOpen};
  let vehicle=bindings.get(actor);if(!vehicle){vehicle=createNpcTrafficVehicleBinding({THREE,actor});if(vehicle)bindings.set(actor,vehicle);}
  const phase=state.phase==='enter'?'board':state.phase==='exit'?'exit':'drive';
  const binding=resolveNpcVehicleBinding({civilianTripRiding:phase==='drive',civilianTripPhase:phase,civilianTripCarId:carId,vehicleSeatId:seatId,civilianTripProgress:progress},()=>vehicle);
  if(!binding)return {...status,bound:false,carId,seatId,reason:'seat-unavailable'};
  reveal();applyNpcVehicleBinding({THREE,walker,binding,dt:Math.max(0,Math.min(.1,Number(dt)||0))});
  return {...status,bound:true,carId,sourceCarId:state.sourceCarId,seatId,doorOpen,progress};
 }
 function dispose(){if(disposed)return;disposed=true;reveal();if(ownsPose)walker?.reset();releaseDoor();walker=null;ownsPose=false;}
 return {prepare,apply,dispose};
}
