import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createWaterInteractionInputSampler} from './water_interaction_inputs.mjs';
import {ARTIST_VEHICLE_PROFILES} from './vehicle_fleet_models.mjs';
const THREE=await import(pathToFileURL((process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const sampler=createWaterInteractionInputSampler({THREE}),hero={object:new THREE.Group()},records=[];
let diagnosticsCalls=0;hero.scale=.95;hero.diagnostics=()=>{diagnosticsCalls++;return {sourceBounds:{min:[-.6,0,-.3],max:[.6,2,.3]}}};
hero.object.position.set(7,1,9);
for(const profile of ARTIST_VEHICLE_PROFILES){
 const object=new THREE.Group(),wheels=[];object.position.set(820,1,406);object.rotation.set(.12,1.2,.15);
 for(const x of [-profile.width*.4,profile.width*.4])for(const z of [-profile.wheelBase/2,profile.wheelBase/2]){
  const pivot=new THREE.Group();pivot.position.set(x,profile.wheelRadius,z);object.add(pivot);wheels.push({pivot,rollingRadius:profile.wheelRadius});
 }
 object.updateWorldMatrix(true,true);records.push({id:profile.id,car:{object,wheels,profile},state:{yaw:1.2,vehicleProfile:profile}});
}
const before=records.map(r=>({matrix:r.car.object.matrixWorld.toArray(),p:r.car.wheels.map(w=>w.pivot.position.toArray())}));
let result=sampler.sample({hero,records,dt:1/60});assert.equal(result.vehicles.length,12);assert.equal(result.hero.teleport,true);assert.deepEqual(result.hero.position,{x:7,y:1,z:9});
assert.equal(result.hero.footprint.width,1.14);
for(let i=0;i<records.length;i++){
 const input=result.vehicles[i],r=records[i];assert.equal(input.massKg,r.car.profile.massKg);assert.equal(input.footprint.length,r.car.profile.length);assert.equal(input.contactPoints.length,4);
 const pivot=r.car.wheels[0].pivot,expected=pivot.getWorldPosition(new THREE.Vector3()),e=pivot.matrixWorld.elements;expected.y-=r.car.profile.wheelRadius*Math.hypot(e[5],e[9]);
 const contact=input.contactPoints[0];assert.ok(expected.distanceTo(new THREE.Vector3(contact.x,contact.y,contact.z))<1e-8);
 assert.equal(contact.front,false,'rear-first source wheel order must not become front spray');assert.equal(input.contactPoints[1].front,true);
 assert.deepEqual(r.car.object.matrixWorld.toArray(),before[i].matrix);assert.deepEqual(r.car.wheels.map(w=>w.pivot.position.toArray()),before[i].p);
}
hero.object.position.x+=.1;hero.object.position.y=0;
result=sampler.sample({hero,records,dt:.1,heroVelocityY:-7});assert.ok(Math.abs(result.hero.velocity.x-1)<1e-10);assert.equal(result.hero.velocity.y,-7);assert.equal(result.hero.teleport,false);
result=sampler.sample({hero,records,dt:.1,occupiedSeat:'driver'});assert.equal(result.hero.enabled,false);assert.equal(result.hero.teleport,true);
result=sampler.sample({hero,records,dt:.1});assert.equal(result.hero.enabled,true);assert.equal(result.hero.teleport,true,'exit re-seeds rather than impact from car seat');
records[0].car.wheels[0].pivot.userData.detached=true;result=sampler.sample({hero,records,dt:.1});assert.equal(result.vehicles[0].contactPoints.length,3);
for(const w of records[0].car.wheels)w.pivot.userData.detached=true;assert.equal(sampler.sample({records,dt:.1}).vehicles[0].enabled,false);
hero.object.position.x+=100;assert.equal(sampler.sample({hero,dt:.1}).hero.teleport,true);assert.equal(sampler.sample({hero,dt:2}).hero.teleport,true);
sampler.reset();assert.equal(sampler.sample({hero,dt:.1}).hero.teleport,true);
assert.deepEqual(sampler.sample(),{hero:null,vehicles:[]});
assert.equal(diagnosticsCalls,1,'source-bound diagnostics cached rather than allocated per frame');
console.log('PASS water input adapter: actual 12 masses/dimensions, posed wheel contacts, no solver writes, landing velocity, seat/teleport reset, detached wheels');
