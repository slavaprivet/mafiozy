// Short CPU-only cost check. No renderer, GPU, browser, or FPS assertion.
import {readFileSync} from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {ARTIST_VEHICLE_PROFILES,createArtistVehicle} from './vehicle_fleet_models.mjs';
import {updateVehicleWheelVisuals} from './vehicle_wheels.mjs';
import {createVehicleWheelRenderBatches} from './vehicle_wheel_render_batches.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import('three'),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js')),{RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const records=[];
for(const profile of ARTIST_VEHICLE_PROFILES){
 const bytes=readFileSync(new URL('models/artist_vehicle_pack/'+profile.modelFile,import.meta.url)),source=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
 const car=createArtistVehicle(T,RoundedBoxGeometry,source,profile,{wheelRenderOptimization:true}),batch=createVehicleWheelRenderBatches({THREE:T,car,multiDraw:true});records.push({car,batch});
}
const quant=(a,p)=>a.slice().sort((x,y)=>x-y)[Math.floor((a.length-1)*p)];
const results=[];
for(const moving of [false,true]){
 const samples=[[],[]];
 for(let i=0;i<144;i++)for(let turn=0;turn<2;turn++){
  const mode=(i+turn)%2,state={distance:moving?.2:0,steer:moving?Math.sin(i*.17)*.4:0};
  const start=performance.now();for(const {car,batch}of records){updateVehicleWheelVisuals(car.wheels,state,car.profile.wheelRadius);if(mode)batch.update();}const elapsed=performance.now()-start;
  if(i>=24)samples[mode].push(elapsed);
 }
 results.push({moving,samples:120,transformOnly:{p50:quant(samples[0],.5),p95:quant(samples[0],.95)},transformPlusBatchUpdate:{p50:quant(samples[1],.5),p95:quant(samples[1],.95)}});
}
console.log(JSON.stringify({scope:'Short coarse CPU microbenchmark, actual 12 cars; no GPU/FPS. Before excludes wheel batching; after includes its matrix/geometry/material checks and bounds rebuilds.',models:records.length,sourceMeshes:records.reduce((n,r)=>n+r.batch.stats.members,0),batches:records.reduce((n,r)=>n+r.batch.stats.batches,0),structuralDrawsPerPass:{before:records.reduce((n,r)=>n+r.batch.stats.members,0),after:records.reduce((n,r)=>n+r.batch.stats.batches,0)},results},null,2));
for(const {batch}of records)batch.dispose();
