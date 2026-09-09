// Seat identity is independent of whether the occupant is allowed to drive.
import {SEDAN_DRIVER_SEAT} from './vehicle_interiors.mjs';
import {stepCar,carOverlapsCircle} from './car_drive.mjs';
import {entryPose} from './car_entry.mjs';
import {EXIT,exitKind} from './car_exit.mjs';
import {circleFits} from './walk_motion.mjs';
export const VEHICLE_SEATS=Object.freeze([
 Object.freeze({id:'front_left',doorId:'front_left',label:'Водитель',side:1,canDrive:true,anchor:SEDAN_DRIVER_SEAT}),
 Object.freeze({id:'front_right',doorId:'front_right',label:'Передний пассажир',side:-1,canDrive:false,anchor:Object.freeze({side:-.43,front:-.15,y:SEDAN_DRIVER_SEAT.y})}),
 Object.freeze({id:'rear_left',doorId:'rear_left',label:'Задний левый пассажир',side:1,canDrive:false,anchor:Object.freeze({side:.43,front:-1.15,y:SEDAN_DRIVER_SEAT.y})}),
 Object.freeze({id:'rear_right',doorId:'rear_right',label:'Задний правый пассажир',side:-1,canDrive:false,anchor:Object.freeze({side:-.43,front:-1.15,y:SEDAN_DRIVER_SEAT.y})}),
]);
export function vehicleSeat(id,car){const seat=(car?.seats||VEHICLE_SEATS).find(item=>item.id===id);if(!seat)throw Error('Unknown vehicle seat '+id);return seat}
export const canControlVehicle=seatId=>seatId==='front_left';
export const inputForVehicleSeat=(seatId,input)=>canControlVehicle(seatId)?input:{};
function local(car,side,front,y=0){const sin=Math.sin(car.yaw),cos=Math.cos(car.yaw);return{x:car.x+side*cos+front*sin,z:car.z-side*sin+front*cos,y}}
export function vehicleSeatPoint(car,seatId){const a=vehicleSeat(seatId,car).anchor;return local(car,a.side,a.front,a.y)}
export function vehicleDoorPoint(car,seatId,distance=1.9){const seat=vehicleSeat(seatId,car),offset=(seat.doorDistance??1.9)-1.9;return local(car,seat.side*(distance+offset),seat.doorFront??seat.anchor.front)}
export function findVehicleEntry(car,hero,walkAllowed,{range=1.3,occupiedSeats=[]}={}){
 if(!car||!hero||Math.abs(car.speed)>.5)return null;
 let nearest=null;
 for(const seat of car.seats||VEHICLE_SEATS){
  if(occupiedSeats.includes(seat.id))continue;
  for(const distance of [1.9,2.4]){
   const outside=vehicleDoorPoint(car,seat.id,distance),near=Math.hypot(hero.x-outside.x,hero.z-outside.z);
   if(near>range||near>=(nearest?.near??Infinity)||!circleFits(outside.x,outside.z,walkAllowed,.36)||carOverlapsCircle(car,outside.x,outside.z,.36))continue;
   nearest={seatId:seat.id,doorId:seat.doorId,side:seat.side,canDrive:seat.canDrive,label:seat.label,distance,outside,near};
  }
 }return nearest;
}
export function vehicleEntryPoint(car,seatId,progress,outside=vehicleDoorPoint(car,seatId)){
 const seat=vehicleSeat(seatId,car),target=vehicleSeatPoint(car,seatId),pose={...entryPose(progress),cabinSlide:0,side:seat.side,driver:seat.canDrive};
 return{x:outside.x+(target.x-outside.x)*pose.seat,z:outside.z+(target.z-outside.z)*pose.seat,y:target.y*pose.seat+.08*Math.sin(Math.PI*pose.seat),yaw:car.yaw-seat.side*(1-pose.seat)*Math.PI/2,pose};
}
export function vehicleDeparturePoint(car,seatId,distance,progress){
 const seat=vehicleSeat(seatId,car),target=vehicleSeatPoint(car,seatId),outside=vehicleDoorPoint(car,seatId,distance),pose={...entryPose(progress,true),cabinSlide:0,side:seat.side,driver:seat.canDrive};
 return{x:outside.x+(target.x-outside.x)*pose.seat,z:outside.z+(target.z-outside.z)*pose.seat,y:target.y*pose.seat+.08*Math.sin(Math.PI*pose.seat),pose};
}
export function planVehicleSeatExit(car,seatId,carAllowed,walkAllowed){
 const seat=vehicleSeat(seatId,car);
 // Each occupant leaves through their own door. A blocked door refuses exit;
 // changing seats or walking through another occupant is a separate mechanic.
 for(const distance of [1.9,2.4]){
  let predicted={...car},clear=true;
  for(let i=0;i<=44;i++){
   if(i)predicted=stepCar(predicted,{},EXIT.releaseSeconds/44,carAllowed);
   const point=vehicleDeparturePoint(predicted,seatId,distance,i/44);
   if(!circleFits(point.x,point.z,walkAllowed,EXIT.radius)){clear=false;break}
  }
  const landing=vehicleDoorPoint(predicted,seatId,distance);
  if(clear&&!carOverlapsCircle(predicted,landing.x,landing.z,EXIT.radius))return{seatId,doorId:seat.doorId,side:seat.side,distance,kind:exitKind(car.speed),predictedCar:predicted};
 }return null;
}
