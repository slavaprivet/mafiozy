// Presentation-only submerged exit support. Seat identity, the 0.3 s E hold,
// vehicle motion and the existing swimming controller remain owned by walk.
import {vehicleDeparturePoint,vehicleSeatPoint} from './vehicle_seats.mjs';
const finite=Number.isFinite;
const valid=p=>p&&[p.x,p.y,p.z].every(finite);
const copy=p=>({x:p.x,y:p.y,z:p.z});
const waterSample=(waterAt,x,z)=>{const w=waterAt(x,z);return w&&w.depth>0&&finite(w.level)?w:null;};

export function vehicleWaterDeparturePoint({THREE,car,state,seatId,distance,progress}){
 if(!car?.object)throw Error('Actual posed vehicle required');
 const localState={...state,x:0,z:0,yaw:0};
 const local=vehicleDeparturePoint(localState,seatId,distance,progress);
 // Underwater the occupant swims sideways through their own doorway; there
 // is no gravity-driven step down onto the chassis' local y=0 plane. The dry
 // departure curve lowers the root into sloping lakebed near its end. Keep
 // the actual seat-root height until outside, then the collision-tested
 // water surface controller owns the continuous ascent. No floor snapping.
 local.y=vehicleSeatPoint(localState,seatId).y;
 const world=car.object.localToWorld(new THREE.Vector3(local.x,local.y,local.z));
 return {...local,...copy(world)};
}

export function vehicleWaterSeatPoint({THREE,car,state,seatId}){
 if(!car?.object)throw Error('Actual posed vehicle required');
 const local=vehicleSeatPoint({...state,x:0,z:0,yaw:0},seatId);
 return copy(car.object.localToWorld(new THREE.Vector3(local.x,local.y,local.z)));
}

// Caller supplies its real capsule/solid-world predicate, excluding only the
// occupied car while crossing its own doorway. Never use a permissive default.
export function canAscendFromVehicle({position,waterAt,canOccupy,bodyHeight=1.1}){
 if(!valid(position)||typeof canOccupy!=='function')return false;
 const water=waterSample(waterAt,position.x,position.z);if(!water)return false;
 const target=Math.max(position.y,water.level-.05),steps=Math.max(1,Math.ceil((target-position.y)/.12));
 for(let i=0;i<=steps;i++)if(!canOccupy({...position,y:position.y+(target-position.y)*i/steps},bodyHeight))return false;
 return true;
}

export function createVehicleWaterExitSurface({position,groundHeight,waterAt,canOccupy,riseSpeed=.9,bodyHeight=1.1}){
 if(!valid(position)||typeof groundHeight!=='function'||typeof waterAt!=='function'||typeof canOccupy!=='function'||!finite(riseSpeed)||riseSpeed<=0)throw Error('Finite submerged exit position and real collision samplers required');
 let state={...copy(position),grounded:false,blocked:false,velocityY:0,water:waterSample(waterAt,position.x,position.z)};
 function floorHeight(x,z){const floor=groundHeight(x,z,state.y);if(!finite(floor))throw Error('Finite exit floor required');return floor;}
 function update({x=state.x,z=state.z,dt=0}={}){
  if(![x,z,dt].every(finite)||dt<0)throw Error('Finite water exit update required');
  const time=Math.min(.1,dt),old=copy(state);let blocked=false;
  // Sweep horizontal inertia before ascending. A slow frame cannot pass a wall.
  const steps=Math.max(1,Math.ceil(Math.hypot(x-old.x,z-old.z)/.12));
  for(let i=1;i<=steps;i++){
   const p={x:old.x+(x-old.x)*i/steps,y:state.y,z:old.z+(z-old.z)*i/steps};
   if(!canOccupy(p,bodyHeight)){blocked=true;break;}state.x=p.x;state.z=p.z;
  }
  const floor=floorHeight(state.x,state.z),water=waterSample(waterAt,state.x,state.z),target=water?Math.max(floor,water.level-.05):floor;
  const delta=Math.max(-riseSpeed*time,Math.min(riseSpeed*time,target-state.y));
  const verticalSteps=Math.max(1,Math.ceil(Math.abs(delta)/.08)),fromY=state.y;
  for(let i=1;i<=verticalSteps;i++){
   const p={x:state.x,y:fromY+delta*i/verticalSteps,z:state.z};
   if(!canOccupy(p,bodyHeight)){blocked=true;break;}state.y=p.y;
  }
  state={...state,water,floorY:floor,grounded:Math.abs(state.y-target)<1e-6,blocked,velocityY:time?(state.y-old.y)/time:0};
  return {...state};
 }
 return {update,floorHeight,get state(){return {...state};}};
}
