import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {pathToFileURL} from 'node:url';

const source=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
const section=source.slice(source.indexOf('function emitCombatShots('),source.indexOf('function updateAimCamera('));
const updates=[],obstacles=[{id:'near-building',updateWorldMatrix(...args){updates.push([this.id,args])}},{id:'car',updateWorldMatrix(...args){updates.push([this.id,args])}}],target={x:4,y:2,z:17},shots=[];
let cameraUpdates=0,sceneUpdates=0;
const context={
 camera:{position:{x:0,y:1,z:0},updateMatrixWorld(){cameraUpdates++}},scene:{updateMatrixWorld(){sceneUpdates++}},
 aimRay:{set(){},near:null,far:null,intersectObjects(items){assert.equal(items,obstacles);return[{object:{visible:true,parent:null},point:target}];},ray:{at(){throw Error('hit target should be used')}}},
 weaponModel:{},THREE:{Vector3:class{}},heroCover:{active:false},occupiedSeat:false,
 shotObstacles(){return obstacles},resolveWeaponShotTransforms(){return{origin:{clone(){return{addScaledVector(){return this}}}}}},effects:{shoot(...args){shots.push(args)},},
};
vm.runInNewContext(section,context);
context.emitCombatShots({allowed:true,forward:{x:0,y:0,z:1},result:{shots:[{id:'shot-1'}]}});
assert.equal(cameraUpdates,1);assert.equal(sceneUpdates,0,'shot path must not walk unrelated scene branches');assert.deepEqual(updates,[['near-building',[true,true]],['car',[true,true]]],'every exact ray obstacle receives a current world matrix');
assert.equal(shots.length,1);assert.equal(shots[0][2],target,'same authoritative ray hit is used by projectile effect');
const T=await import(pathToFileURL((process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/')+'build/three.module.js'));
function realShotScene(){
 const scene=new T.Scene(),building=new T.Group(),car=new T.Group(),unrelated=new T.Group(),box=new T.BoxGeometry(2,2,2);building.name='building';car.name='car';unrelated.name='npc-not-a-shot-obstacle';building.add(new T.Mesh(box,new T.MeshBasicMaterial()));car.add(new T.Mesh(box,new T.MeshBasicMaterial()));unrelated.add(new T.Mesh(box,new T.MeshBasicMaterial()));building.position.set(0,0,12);car.position.set(0,0,8);unrelated.position.set(0,0,4);scene.add(building,car,unrelated);scene.updateMatrixWorld(true);building.position.z=14;car.position.z=9;unrelated.position.z=2;return{scene,building,car,unrelated};
}
const baselineScene=realShotScene(),scopedScene=realShotScene(),ray=new T.Raycaster(new T.Vector3(0,0,0),new T.Vector3(0,0,1),0,100);baselineScene.scene.updateMatrixWorld(true);const baseline=ray.intersectObjects([baselineScene.building,baselineScene.car],true)[0];scopedScene.building.updateWorldMatrix(true,true);scopedScene.car.updateWorldMatrix(true,true);const scoped=ray.intersectObjects([scopedScene.building,scopedScene.car],true)[0];assert.equal(scoped.object.parent.name,baseline.object.parent.name);assert.ok(Math.abs(scoped.distance-baseline.distance)<1e-8,'selected root world transforms produce the exact legacy ray distance');assert.equal(scopedScene.unrelated.matrixWorld.elements[14],4,'unrelated scene child remains outside the shot-matrix walk');
console.log('PASS combat shot updates only selected ray obstacles, not the whole scene');
