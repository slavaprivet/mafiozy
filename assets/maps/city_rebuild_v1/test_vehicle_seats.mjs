import assert from 'node:assert/strict';
import {VEHICLE_SEATS,vehicleSeat,canControlVehicle,inputForVehicleSeat,vehicleSeatPoint,vehicleDoorPoint,findVehicleEntry,vehicleEntryPoint,vehicleDeparturePoint,planVehicleSeatExit} from './vehicle_seats.mjs';
import {carOverlapsCircle} from './car_drive.mjs';
const open=()=>true,base={x:20,z:30,yaw:0,speed:0};
for(const yaw of [0,Math.PI/2,Math.PI,-Math.PI/2])for(const seat of VEHICLE_SEATS){
 const car={...base,yaw},outside=vehicleDoorPoint(car,seat.id),candidate=findVehicleEntry(car,outside,open);
 assert.equal(candidate.seatId,seat.id,'nearest door selects that exact seat');
 assert.equal(candidate.canDrive,seat.id==='front_left');
 assert(!findVehicleEntry(car,outside,open,{occupiedSeats:VEHICLE_SEATS.map(s=>s.id)}));
 const entry=vehicleEntryPoint(car,seat.id,1),target=vehicleSeatPoint(car,seat.id);
 assert(Math.hypot(entry.x-target.x,entry.z-target.z)<1e-6);assert.equal(entry.pose.cabinSlide,0,'passengers never slide across to driver');
 assert.equal(entry.pose.driver,seat.canDrive);
 for(const speed of [0,2,16,-5]){
  const moving={...car,speed},plan=planVehicleSeatExit(moving,seat.id,open,open);assert(plan);
  assert.equal(plan.doorId,seat.doorId);assert.equal(plan.kind,Math.abs(speed)>15/3.6?'tumble':'walk');
  const end=vehicleDeparturePoint(plan.predictedCar,seat.id,plan.distance,1);
  assert(!carOverlapsCircle(plan.predictedCar,end.x,end.z,.58));
  const start=vehicleDeparturePoint(moving,seat.id,plan.distance,0),origin=vehicleSeatPoint(moving,seat.id);
  assert(Math.hypot(start.x-origin.x,start.z-origin.z)<1e-6,'exit begins at occupied seat');
 }
}
assert.equal(planVehicleSeatExit(base,'front_left',open,(x,z)=>x<21.2),null,'blocked own door refuses rather than teleporting across cabin');
assert.equal(findVehicleEntry({...base,speed:.51},vehicleDoorPoint(base,'front_left'),open),null);
const input={forward:true,left:true,handbrake:true};assert.equal(inputForVehicleSeat('front_left',input),input);
for(const id of [null,'front_right','rear_left','rear_right']){assert(!canControlVehicle(id));assert.deepEqual(inputForVehicleSeat(id,input),{})}
assert.throws(()=>vehicleSeat('missing'));
console.log('PASS four door/seat identities at four headings, driver-only input, no cross-cabin slide, 64 moving seat exits, blocked own door');
