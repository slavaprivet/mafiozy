import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {loadArtistFleetModels} from './vehicle_fleet_models.mjs';
import {createVehicleFleet} from './vehicle_fleet.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
class RoundedBox extends T.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
test('separate taxi variant loads with real doors, wheel design, roof sign and independent paint',async()=>{
 const loads=[];const loader={async loadAsync(url){loads.push(url);const bytes=await readFile(new URL(url,import.meta.url));return new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')}};
 const cars=await loadArtistFleetModels({THREE:T,loader,RoundedBox,includeTaxi:true});assert.equal(cars.length,13);assert.equal(loads.length,12,'taxi shares immutable parsed source, not an extra request');
 const taxi=cars.find(c=>c.profile.id==='city_taxi'),sedan=cars.find(c=>c.profile.id==='compact_sedan');assert(taxi&&sedan);assert.equal(taxi.profile.label,'Easton Taxi');assert.equal(taxi.seats.length,4);
 assert.notEqual(taxi.hoodSpec.lid.material,sedan.hoodSpec.lid.material);assert.notEqual(taxi.hoodSpec.lid.material.color.getHexString(),sedan.hoodSpec.lid.material.color.getHexString());
 assert.equal(taxi.hoodSpec.lid.material.color.getHexString(),'f4bd22');assert(taxi.object.getObjectByName('Taxi_roof_sign'));assert(taxi.object.getObjectByName('Taxi_letters_1'));assert(taxi.object.getObjectByName('Taxi_letters_-1'));
 for(const [id,door]of taxi.doors){const checks=door.getObjectByName('Taxi_checkers_'+id);assert(checks);taxi.object.updateMatrixWorld(true);const before=checks.matrixWorld.clone();taxi.setDoorById(1,id);taxi.object.updateMatrixWorld(true);assert(!before.equals(checks.matrixWorld),'checks follow opening '+id);taxi.setDoorById(0,id)}
 assert(taxi.wheels.every(w=>w.wheel.userData.wheelDesign==='city_taxi'));
 const scene=new T.Scene(),fleet=createVehicleFleet(T,{scene,RoundedBox,world:()=>()=>true});const record=fleet.addCar(taxi,{x:5,z:6,yaw:.4});assert.equal(record.id,'city_taxi');assert(record.trunk.enabled&&record.hood.enabled);
 record.damage.blastImpact({damage:100});assert.equal(sedan.object.userData.vehicleFleetId,undefined);fleet.reset();assert.equal(taxi.hoodSpec.lid.material.color.getHexString(),'f4bd22');fleet.dispose();
});
