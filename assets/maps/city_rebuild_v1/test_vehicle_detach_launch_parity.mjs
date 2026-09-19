import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createVehicleDamage,measureVehicleDetachedBounds} from './vehicle_damage.mjs';
import {createDemoCar} from './car_drive.mjs';

const T=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const scene=new T.Scene(),car=createDemoCar(T,T.BoxGeometry);scene.add(car.object);
const damage=createVehicleDamage(T,car,{scene});
const source=[...car.doors.values()].find(node=>node.name==='Door_front_left');
const sourceIndex=[...car.doors.values(),...car.shell.filter(mesh=>['Hood_lid','Trunk_lid'].includes(mesh.name)),...car.wheels.map(wheel=>wheel.pivot)].indexOf(source);
car.object.updateWorldMatrix(true,true);damage.debrisObject.updateWorldMatrix(true,false);
const expectedMatrix=new T.Matrix4().copy(damage.debrisObject.matrixWorld).invert().multiply(source.matrixWorld);
const expectedPosition=new T.Vector3(),expectedQuaternion=new T.Quaternion(),expectedScale=new T.Vector3();
expectedMatrix.decompose(expectedPosition,expectedQuaternion,expectedScale);
const origin=damage.debrisObject.worldToLocal(car.object.getWorldPosition(new T.Vector3()));
const expectedVelocity=expectedPosition.clone().sub(origin);expectedVelocity.y=0;expectedVelocity.normalize().multiplyScalar(3.5+sourceIndex%3*.65);expectedVelocity.y=4;
const bounds=measureVehicleDetachedBounds(T,source),size=bounds.getSize(new T.Vector3());
const thin=size.x<=size.y&&size.x<=size.z?new T.Vector3(1,0,0):size.y<=size.z?new T.Vector3(0,1,0):new T.Vector3(0,0,1);
const expectedLanding=new T.Quaternion().setFromAxisAngle(new T.Vector3(0,1,0),Math.PI).multiply(new T.Quaternion().setFromUnitVectors(thin,new T.Vector3(0,1,0)));
const hood=car.shell.find(mesh=>mesh.name==='Hood_lid'),point=car.object.localToWorld(new T.Vector3(0,1,1));
const random=Math.random;Math.random=()=>.5;
try{damage.impact({object:hood,point,normal:new T.Vector3(0,1,0),damage:999,shotId:'fixed-launch'});damage.update(1.56)}finally{Math.random=random}
const released=damage.debrisObject.children.find(node=>node.name===source.name);
assert(released,'the same real left-front door is released');
assert(released.position.distanceTo(expectedPosition)<1e-12,'cached parent transform retains exact release position');
assert(Math.abs(1-Math.abs(released.quaternion.dot(expectedQuaternion)))<1e-12,'cached parent transform retains exact release rotation');
// At fixed random .5 the first source has angle 0, strength 1 and the same
// yaw/axis landing orientation.  The part is still at born time (no travel).
assert(released.scale.distanceTo(expectedScale)<1e-12);
assert.equal(released.position.y,expectedPosition.y);
damage.update(.01);
const travel=(1-Math.exp(-.01*.65))/.65;
assert(Math.abs(released.position.x-(expectedPosition.x+expectedVelocity.x*travel))<1e-12);
assert(Math.abs(released.position.y-Math.max(.20,expectedPosition.y+expectedVelocity.y*.01-4.9*.0001))<1e-12);
damage.update(1);
const landingPose=expectedQuaternion.clone().slerp(expectedLanding,.21);
assert(Math.abs(1-Math.abs(released.quaternion.dot(landingPose)))<1e-12,'cached scratch landing has the exact former yaw and thin-axis pose');
damage.dispose();
console.log('PASS cached wreck transform preserves fixed-seed real-door launch position, rotation, scale and trajectory');
