import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createVehicleInterior} from './vehicle_interiors.mjs';
import {createDemoCar,DRIVER_SEAT,CAR} from './car_drive.mjs';
const THREE=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
class TestBox extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
const car=createDemoCar(THREE,TestBox),{interior,anchors}=car;
car.object.updateMatrixWorld(true);
const bounds=node=>new THREE.Box3().setFromObject(node);
assert.equal(interior.parts.seats.length,4);assert.equal(car.doors.size,4);assert.equal(anchors.rear.length,2);
assert.deepEqual(anchors.driver,DRIVER_SEAT);assert(anchors.driver.side>0,'driver and wheel stay on +X / left');
assert.equal(interior.wheel.parent.position.x,DRIVER_SEAT.side);
const floor=bounds(interior.object.getObjectByName('Cabin_floor'));
assert(Math.abs(floor.max.y-anchors.floorTop)<1e-6);
for(const seat of interior.parts.seats){const b=bounds(seat);assert(b.min.y>=floor.max.y+.029,'seat cushion supported above open cabin floor');assert(Math.abs(b.max.y-anchors.cushionTop)<1e-6);assert(b.max.x<.87&&b.min.x>-.87,'seats inside cabin side walls')}
const front=bounds(interior.object.getObjectByName('front_left_back')),rear=bounds(interior.object.getObjectByName('rear_left_cushion'));
assert(front.min.z>rear.max.z+.2,'rear row has a separate leg space');
const cabinProbe=new THREE.Vector3(0,.82,-.15);
assert(!car.object.children.filter(n=>n.isMesh&&!n.material.transparent).some(n=>bounds(n).containsPoint(cabinProbe)),'exterior shell does not fill the cabin with a solid box');
for(const side of [-1,1]){
 const door=car.doors.get(side),rearDoor=car.doors.get('rear_'+(side>0?'left':'right'));
 car.setDoor(1,side);assert.equal(Math.sign(door.rotation.y),-side);assert.equal(rearDoor.rotation.y,0);
 car.setRearDoor(1,side);assert.equal(Math.sign(rearDoor.rotation.y),-side);car.setRearDoor(0,side);car.setDoor(0);
}
let glazing=0;car.object.traverse(node=>{if(node.isMesh&&node.material.transparent){glazing++;assert(node.material.opacity<.4&&!node.material.depthWrite)}});assert(glazing>=6,'windscreens and all four door windows are see-through');
car.update({steer:.3,distance:1});assert(interior.wheel.rotation.z<0);assert(car.wheels.every(w=>w.wheel.rotation.x>0));
const point=new THREE.Vector3();
for(let steering=-.56;steering<=.561;steering+=.07){
 car.update({steer:steering,distance:0});car.object.updateMatrixWorld(true);
 const grips=car.getSteeringGrips();
 for(const grip of Object.values(grips)){const localGrip=interior.wheel.worldToLocal(grip.clone());assert(Math.abs(Math.hypot(localGrip.x,localGrip.y)-.18)<1e-6,'hands target actual rim throughout steering');assert(Math.abs(localGrip.z+.025)<1e-6)}
 for(const item of car.wheels){const tire=item.tire,positions=tire.geometry.attributes.position;
  for(let i=0;i<positions.count;i++){
   point.fromBufferAttribute(positions,i).applyMatrix4(tire.matrixWorld);
   assert(Math.abs(point.x)<=CAR.halfWidth,'collision envelope includes tires at full steering');
   for(const mesh of car.shell){const b=mesh.userData.bodyBox,a=mesh.userData.wheelArch;
    if(b)assert(![point.x,point.y,point.z].every((v,j)=>v>b.min[j]+.001&&v<b.max[j]-.001),'tire clears '+mesh.name);
    if(a&&Math.abs(point.x)>a.inner&&Math.abs(point.x)<a.outer&&point.z>a.from&&point.z<a.to){
     const lower=Math.max(a.bottom,...[-1.35,1.3].map(z=>Math.abs(point.z-z)<a.radius?.43+Math.sqrt(a.radius*a.radius-(point.z-z)**2):a.bottom));
     assert(point.y<=lower+.001||point.y>=a.top-.001,'tire clears real arch '+mesh.name);
    }
   }
  }
 }
}
const truck=createVehicleInterior(THREE,TestBox,{family:'truck'});truck.object.updateMatrixWorld(true);
assert.equal(truck.parts.seats.length,2);assert.equal(truck.anchors.rear.length,0);assert(truck.cargo.children.length>4);
assert(bounds(truck.cargo).max.z<bounds(truck.object.getObjectByName('front_left_cushion')).min.z,'cargo stays behind truck cab');
assert.equal(createVehicleInterior(THREE,TestBox,{family:'coupe'}).parts.seats.length,2);
assert.throws(()=>createVehicleInterior(THREE,TestBox,{family:'unknown'}));
console.log('PASS open cabin floor, seat support/spacing, left steering anchor, four opening doors, transparent windows, truck cab/cargo separation');
