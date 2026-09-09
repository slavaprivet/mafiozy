import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createStableEntryLights} from './stable_entry_lights.mjs';
const THREE=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const scene=new THREE.Scene(),building=new THREE.Group(),room=new THREE.Group();scene.add(building);building.add(room);building.position.set(5,2,-10);building.rotation.y=.9;
const source=new THREE.PointLight('#ffd2a0',6,7,2);source.position.set(1,2,3);room.add(source);
scene.updateMatrixWorld(true);const point=source.getWorldPosition(new THREE.Vector3()),mask=source.layers.mask;
const pool=createStableEntryLights(THREE,[{object:room}],scene),slot=scene.getObjectByName('Stable_Entry_Light_Slots').children[0];
assert(slot.position.distanceTo(point)<1e-10);assert.equal(slot.intensity,6);assert.equal(slot.distance,7);assert.equal(slot.decay,2);assert.equal(slot.color.getHex(),source.color.getHex());assert.equal(source.layers.mask,0);assert.equal(source.parent,room);
building.visible=false;pool.update();assert.equal(slot.intensity,0);assert(slot.visible);assert.equal(source.intensity,6);
building.visible=true;source.intensity=9;source.color.set('red');pool.update();assert.equal(slot.intensity,9);assert.equal(slot.color.getHex(),source.color.getHex());
source.visible=false;pool.update();assert.equal(slot.intensity,0);pool.dispose();assert.equal(source.layers.mask,mask);assert.equal(source.parent,room);assert(!scene.getObjectByName('Stable_Entry_Light_Slots'));
console.log('PASS stable slots preserve exact source light, ancestor culling, edits, ownership and disposal');

// Hundreds of visible zero-intensity slots still overflow fragment uniforms.
// Keep source ownership while a fixed nearest set reaches the shader.
const city=new THREE.Scene(),rooms=[],originals=[];
for(let i=0;i<600;i++){
 const room=new THREE.Group();room.position.set(i*3,0,0);city.add(room);
 const light=new THREE.PointLight(0xffdcac,7+i%3,9,2);light.position.y=2;room.add(light);rooms.push({object:room});originals.push(light);
}
let focus=new THREE.Vector3();const bounded=createStableEntryLights(THREE,rooms,city,{maxLights:400,getFocus:()=>focus});
const lights=city.getObjectByName('Stable_Entry_Light_Slots').children;
assert.equal(lights.length,32,'hard GPU budget applies even to an excessive requested pool');
assert.equal(bounded.stats().sourceLights,600);assert.equal(bounded.stats().activeLights,32);
assert(originals.every(light=>light.layers.mask===0));
assert.equal(lights[0].userData.roomLightSource,originals[0].uuid);
focus.set(599*3,0,0);bounded.update();assert.equal(lights[0].userData.roomLightSource,originals[599].uuid);
assert.equal(lights[0].intensity,originals[599].intensity);assert.equal(lights[0].distance,9);
const identities=lights.map(light=>light.uuid);rooms[599].object.visible=false;bounded.update();
assert.notEqual(lights[0].userData.roomLightSource,originals[599].uuid);assert.deepEqual(lights.map(light=>light.uuid),identities);
for(const room of rooms)room.object.visible=false;bounded.update();assert(lights.every(light=>light.intensity===0&&light.visible));
assert.equal(bounded.stats().activeLights,0);assert.equal(lights.length,32,'culling never changes shader slot count');
bounded.dispose();assert(originals.every(light=>light.layers.mask===1));assert.equal(city.getObjectByName('Stable_Entry_Light_Slots'),undefined);
const empty=createStableEntryLights(THREE,[],city);assert.equal(empty.stats().fixedLights,0);empty.update();empty.dispose();
console.log('PASS 600 room sources capped to32 permanent slots, camera-nearest reassignment, no slot churn, complete mask restore');
