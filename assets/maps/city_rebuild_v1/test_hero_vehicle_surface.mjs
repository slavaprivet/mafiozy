import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroVehicleSurface} from './hero_vehicle_surface.mjs';
import {ARTIST_VEHICLE_PROFILES,createArtistVehicle} from './vehicle_fleet_models.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const cars=[],results=[];let time=1;
for(const profile of ARTIST_VEHICLE_PROFILES){
 const bytes=fs.readFileSync(new URL('./models/artist_vehicle_pack/'+profile.modelFile,import.meta.url));
 const gltf=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
 const car=createArtistVehicle(T,RoundedBoxGeometry,gltf.scene,profile),record={car,state:{speed:0}};cars.push(record);
 const helper=createHeroVehicleSurface({THREE:T,getVehicles:()=>[record]});helper.update(time);
 // Real roof and hood geometry centers, without assuming a common vehicle box.
 let roof;car.object.traverse(n=>{if(n.userData.vehicleRoof)roof=n});assert.ok(roof,profile.id+' authored roof');
 const roofBox=new T.Box3().setFromObject(roof),roofCenter=roofBox.getCenter(new T.Vector3()),hoodCenter=new T.Box3().setFromObject(car.hoodSpec.lid).getCenter(new T.Vector3());
 const roofHit=helper.sample(roofCenter.x,roofCenter.z,0),hoodHit=helper.sample(hoodCenter.x,hoodCenter.z,0);
 assert.ok(roofHit?.stable,profile.id+' stable roof '+JSON.stringify(roofHit&&{top:roofHit.top,stable:roofHit.stable}));assert.ok(roofHit.top>=roofBox.max.y-.001);
 assert.ok(hoodHit,profile.id+' hood collision');
 if(!['city_bus'].includes(profile.id))assert.ok(roofHit.top>hoodHit.top+.05,profile.id+' roof higher than hood');
 assert.ok(helper.blocks(roofCenter.x,roofCenter.z,0,1.9));assert.ok(helper.blocks(roofCenter.x,roofCenter.z,roofHit.top-.2,1.9));assert.equal(helper.blocks(roofCenter.x,roofCenter.z,roofHit.top+.01,1.9),false);
 assert.equal(helper.supportHeight(roofCenter.x,roofCenter.z,roofHit.top),roofHit.top);assert.equal(helper.supportHeight(roofCenter.x,roofCenter.z,0),-Infinity);
 const localRoof=roofCenter.clone(),localHood=hoodCenter.clone();
 car.object.position.set(30,2,-17);car.object.rotation.y=1.21;car.object.scale.set(1.2,1.15,.85);helper.update(time+=1);helper.update(time+=1);
 const worldRoof=localRoof.clone().applyMatrix4(car.object.matrixWorld),worldHood=localHood.clone().applyMatrix4(car.object.matrixWorld);
 const moved=helper.sample(worldRoof.x,worldRoof.z);assert.ok(moved?.stable);assert.ok(Math.abs(moved.top-(2+roofHit.top*1.15))<1e-5,profile.id+' yaw/nonuniform scale top');assert.ok(helper.sample(worldHood.x,worldHood.z));
 assert.ok(helper.blocks(worldRoof.x,worldRoof.z,2,1.9));assert.equal(helper.blocks(worldRoof.x,worldRoof.z,moved.top+.01,1.9),false);assert.equal(helper.sample(0,0),null);
 record.state.speed=2;helper.update(time+=.1);assert.equal(helper.sample(worldRoof.x,worldRoof.z).stable,false);assert.equal(helper.supportHeight(worldRoof.x,worldRoof.z,moved.top),-Infinity);assert.ok(helper.blocks(worldRoof.x,worldRoof.z,2,1.9));
 record.state.speed=0;helper.update(time+=1);record.state.waterState={inWater:true};helper.update(time+=1);assert.equal(helper.sample(worldRoof.x,worldRoof.z).stable,false);record.state.waterState.inWater=false;
 car.object.rotation.z=.15;helper.update(time+=1);assert.equal(helper.sample(worldRoof.x,worldRoof.z).stable,false);assert.ok(helper.blocks(worldRoof.x,worldRoof.z,2,1.9));car.object.rotation.z=0;helper.update(time+=1);helper.update(time+=1);
 const builds=helper.diagnostics().builds;let traversals=0;const original=car.object.traverse;car.object.traverse=()=>{traversals++;throw Error('No traversal after bake')};
 const start=performance.now();for(let i=0;i<1000;i++){helper.update(time+i/60);helper.sample(worldRoof.x,worldRoof.z);helper.blocks(worldRoof.x,worldRoof.z,moved.top+.01,1.9,.36)}const updateAndQueriesMs=(performance.now()-start)/1000;
 car.object.traverse=original;assert.equal(traversals,0);assert.equal(helper.diagnostics().builds,builds);
 // A deforming roof cannot leave an outdated climb surface usable.
 roof.geometry.attributes.position.needsUpdate=true;helper.update(time+=20);assert.equal(helper.sample(worldRoof.x,worldRoof.z).stable,false);
 results.push({id:profile.id,roof:roofHit.top,hood:hoodHit.top,updateAndQueriesMs,triangles:helper.diagnostics().triangles});helper.dispose();
 car.object.position.set(cars.length*15,0,0);car.object.rotation.set(0,0,0);car.object.scale.setScalar(1);
}
const fleet=createHeroVehicleSurface({THREE:T,getVehicles:()=>cars});for(let i=0;i<12;i++)fleet.update(i/60);assert.equal(fleet.diagnostics().builds,12);
const start=performance.now();for(let i=0;i<2000;i++){fleet.update(2+i/60);for(let q=0;q<12;q++)fleet.blocks(1000+q,1000,0,1.9)}const fleetMs=(performance.now()-start)/2000;
assert.equal(fleet.diagnostics().triangleTests,0,'far broadphase never visits triangles');
console.log('PASS 12 actual GLBs: roof/hood height, rotated/scaled solid volumes, stable support, moving/tilted/wet rejection, deformation invalidation, bounded builds and traversal-free hot path');
console.log(JSON.stringify({fleetUpdateAnd12FarQueriesMs:fleetMs,results},null,2));
