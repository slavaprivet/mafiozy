import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {VEHICLE_SEATS,vehicleDeparturePoint,vehicleSeatPoint} from './vehicle_seats.mjs';
import {createVehicleWaterExitSurface,canAscendFromVehicle,vehicleWaterDeparturePoint,vehicleWaterSeatPoint} from './vehicle_water_exit.mjs';
import {createExitSwimHandoff} from './vehicle_exit_surface.mjs';
const THREE=await import(pathToFileURL((process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const waterAt=()=>({level:1,depth:8,floor:-7}),groundHeight=()=>-7,clear=p=>p.y>=-7&&Math.abs(p.x)<20&&Math.abs(p.z)<20;
for(const fps of [20,30,60,120]){
 const position={x:3,y:-6,z:4},surface=createVehicleWaterExitSurface({position,groundHeight,waterAt,canOccupy:clear});
 assert.equal(surface.state.y,-6);assert.equal(surface.update({dt:0}).y,-6,'no first-frame teleport to surface');
 let last=-6,sample;
 for(let i=0;i<fps*10;i++){
  sample=surface.update({dt:1/fps});assert.ok(sample.y-last<=.9/fps+1e-8);assert.ok(sample.y>=last);assert.equal(sample.x,3);assert.equal(sample.z,4);last=sample.y;if(sample.grounded)break;
 }
 assert.equal(sample.grounded,true);assert.ok(Math.abs(sample.y-.95)<1e-8);
 const handoff=createExitSwimHandoff({fromY:sample.y,waterLevel:1});assert.equal(handoff.update(-7,0),sample.y,'existing cold swim handoff preserves continuous exit');
}
const position={x:0,y:-5,z:0};assert.equal(canAscendFromVehicle({position,waterAt,canOccupy:clear}),true);
const ceiling=p=>clear(p)&&p.y+1.1<=-2;
assert.equal(canAscendFromVehicle({position,waterAt,canOccupy:ceiling}),false,'solid ceiling blocks exit plan');
const surface=createVehicleWaterExitSurface({position,waterAt,groundHeight,canOccupy:ceiling});
for(let i=0;i<400;i++)surface.update({dt:1/60});assert.ok(surface.state.y+1.1<=-2);assert.equal(surface.state.grounded,false);assert.equal(surface.state.blocked,true);
const wall=createVehicleWaterExitSurface({position,waterAt,groundHeight,canOccupy:p=>clear(p)&&p.x<1});const stopped=wall.update({x:4,z:0,dt:.1});assert.ok(stopped.x<1,'horizontal sweep preserves walls');
const car={object:new THREE.Group()},state={x:10,z:12,yaw:.8,seats:VEHICLE_SEATS};car.object.position.set(10,-4,12);car.object.rotation.set(.2,.8,.4);car.object.updateWorldMatrix(true,true);
for(const seat of VEHICLE_SEATS)for(const progress of [0,.25,.5,1]){
 const actual=vehicleWaterDeparturePoint({THREE,car,state,seatId:seat.id,distance:2.4,progress});
 const local=vehicleDeparturePoint({...state,x:0,z:0,yaw:0},seat.id,2.4,progress);local.y=vehicleSeatPoint({...state,x:0,z:0,yaw:0},seat.id).y;
 const expected=car.object.localToWorld(new THREE.Vector3(local.x,local.y,local.z));
 assert.ok(expected.distanceTo(new THREE.Vector3(actual.x,actual.y,actual.z))<1e-9);assert.deepEqual(actual.pose,local.pose);
}
// Regression: the old dry exit ends exactly on the tilted base plane. A real
// radius .58 capsule intersects the uphill bed although its centre is clear.
const tilted={object:new THREE.Group()},tiltedState={x:0,z:0,yaw:0,seats:VEHICLE_SEATS};tilted.object.position.y=-4;tilted.object.rotation.z=Math.atan(.2);tilted.object.updateWorldMatrix(true,true);
const bed=(x,z)=>-4+.2*x,capsule=p=>[[0,0],[.58,0],[-.58,0],[0,.58],[0,-.58]].every(([x,z])=>bed(p.x+x,p.z+z)<=p.y+.08);
let legacyBlocked=0;
for(const seat of VEHICLE_SEATS)for(let i=0;i<=24;i++){
 const p=vehicleWaterDeparturePoint({THREE,car:tilted,state:tiltedState,seatId:seat.id,distance:2.4,progress:i/24});assert.equal(capsule(p),true,seat.id+' water doorway must clear unchanged sloped-bed capsule test');
 const local=vehicleDeparturePoint(tiltedState,seat.id,2.4,i/24),old=tilted.object.localToWorld(new THREE.Vector3(local.x,local.y,local.z));if(!capsule(old))legacyBlocked++;
 if(i===0){const seated=vehicleWaterSeatPoint({THREE,car:tilted,state:tiltedState,seatId:seat.id});assert.ok(Math.hypot(p.x-seated.x,p.y-seated.y,p.z-seated.z)<1e-12,'water exit starts at actual seated position');}
}
assert.ok(legacyBlocked>0,'fixture reproduces legacy bed collision without relaxing collision tolerance');
for(const seat of VEHICLE_SEATS){
 const actual=vehicleWaterSeatPoint({THREE,car,state,seatId:seat.id}),local=vehicleSeatPoint({...state,x:0,z:0,yaw:0},seat.id);
 const expected=car.object.localToWorld(new THREE.Vector3(local.x,local.y,local.z));assert.ok(expected.distanceTo(new THREE.Vector3(actual.x,actual.y,actual.z))<1e-9,'abort returns to actual submerged seat');
}
console.log('PASS submerged vehicle exit: four own-door trajectories use actual sunk/rolled pose, no shore/surface teleport, continuous ascent, preserved walls/ceilings and cold swim handoff');
