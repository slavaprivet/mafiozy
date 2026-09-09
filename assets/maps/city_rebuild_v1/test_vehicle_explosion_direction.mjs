import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createDemoCar} from './car_drive.mjs';
import {createVehicleDamage} from './vehicle_damage.mjs';
const T=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
class RoundedBox extends T.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
test('exploded parts scatter away from a translated rotated car rather than the world origin',()=>{
 for(const yaw of [0,Math.PI/2,Math.PI]){
  const scene=new T.Scene(),car=createDemoCar(T,RoundedBox);car.object.position.set(300,0,400);car.object.rotation.y=yaw;scene.add(car.object);scene.updateMatrixWorld(true);
  const damage=createVehicleDamage(T,car,{scene});damage.blastImpact({damage:1000});damage.update(1.56);
  const center=car.object.getWorldPosition(new T.Vector3()),before=damage.debrisObject.children.map(part=>part.position.clone());damage.update(.1);
  assert.equal(before.length,10);
  for(const [i,part]of damage.debrisObject.children.entries()){
   const outward=before[i].clone().sub(center),delta=part.position.clone().sub(before[i]);outward.y=delta.y=0;
   assert(outward.dot(delta)>0,part.name+' ejects away from its own car at yaw '+yaw);
   assert(delta.length()<1,'bounded cosmetic launch velocity');
  }
  damage.dispose();
 }
});
