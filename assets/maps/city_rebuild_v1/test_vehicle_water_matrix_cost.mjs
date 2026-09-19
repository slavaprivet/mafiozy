// Actual authored GLBs, exact old/new gameplay parity and scoped CPU benchmark.
// Run: node assets/maps/city_rebuild_v1/test_vehicle_water_matrix_cost.mjs
// No GPU or browser. Timings are the 12-car water workload, NOT whole-game FPS.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {ARTIST_VEHICLE_PROFILES,createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createVehicleHood} from './vehicle_hood.mjs';
import * as optimized from './vehicle_water_state.mjs';

const vendor=(process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
class Box extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d)}}

// Reconstruct only the pre-optimization matrix calls. The physics, envelope,
// engine-vertex cache, latches and water admission stay the production code in
// both versions, so this A/B cannot accidentally benchmark older game logic.
let legacySource=fs.readFileSync(new URL('./vehicle_water_state.mjs',import.meta.url),'utf8').replace(/\r/g,'');
function replaceOnce(from,to){assert.equal(legacySource.split(from).length,2,'baseline anchor: '+from);legacySource=legacySource.replace(from,to);}
replaceOnce('const cache=engineMeshes(car);let best=null;','car.object.updateWorldMatrix(true,true);const cache=engineMeshes(car);let best=null;');
replaceOnce('mesh.updateWorldMatrix(true,false);','');
replaceOnce('car.object.updateWorldMatrix(true,false);\n  const origin=new THREE.Vector3().setFromMatrixPosition(car.object.matrixWorld),supportY=origin.y;',
  'car.object.updateWorldMatrix(true,true);\n  const origin=new THREE.Vector3();car.object.getWorldPosition(origin);const supportY=origin.y;');
replaceOnce('car.object.position.copy(local);car.object.updateWorldMatrix(true,false);','car.object.position.copy(local);car.object.updateWorldMatrix(true,true);');
const legacy=await import('data:text/javascript;base64,'+Buffer.from(legacySource).toString('base64'));
const waterAt=()=>({level:0,depth:600,floor:-600});
const sources=[];
for(const profile of ARTIST_VEHICLE_PROFILES){
  const bytes=fs.readFileSync(new URL('./models/artist_vehicle_pack/'+profile.modelFile,import.meta.url));
  const gltf=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
  sources.push({profile,scene:gltf.scene});
}
function fixture(source){
  const car=createArtistVehicle(THREE,Box,source.scene.clone(true),source.profile);
  car.hood=createVehicleHood(THREE,Box,car);
  const world=new THREE.Group(),parent=new THREE.Group();world.add(parent);parent.add(car.object);
  const state={x:0,z:0,yaw:0,speed:0,vehicleProfile:car.profile};
  return {car,state,parent,world};
}
const before=sources.map(fixture),after=sources.map(fixture);
function pose(f,frame,scenario){
  const t=frame/60,root=f.car.object;
  root.position.set(Math.sin(t*.6)*3,scenario==='dry'?3:scenario==='sinking'?(frame===0?.1:-500):-.03,Math.cos(t*.4)*2);
  root.rotation.set(scenario==='moving'?Math.sin(t)*.21:0,t*.1,scenario==='moving'?Math.cos(t)*.16:0);
  f.car.hood.bay.position.y=Math.sin(t*.7)*.035;
  f.car.hood.hinge.rotation.x=Math.sin(t)*.8;
}
function reset(fixtures,api){for(const f of fixtures)api.resetVehicleWater(f.car,f.state);}
function step(f,api,scenario){return api.stepVehicleWater({THREE,...f,waterAt:scenario==='dry'?()=>null:waterAt,dt:1/60});}
function matrices(f){const a=[];f.world.traverse(n=>a.push(n.matrixWorld.toArray()));return a;}
let framesCompared=0,matricesCompared=0;
for(const scenario of ['dry','shallow','sinking','moving']){
  reset(before,legacy);reset(after,optimized);
  for(let frame=0;frame<90;frame++)for(let i=0;i<sources.length;i++){
    const a=before[i],b=after[i];pose(a,frame,scenario);pose(b,frame,scenario);
    // Parent transforms are deliberately not updated by the fixture: the water
    // sampler must update dirty ancestors itself, including nonuniform scale.
    if(frame===20||frame===50)for(const f of [a,b]){
      f.parent.position.set(1,.13,-2);f.parent.rotation.set(.13,.35,-.09);f.parent.scale.set(1.1,.85,1.25);
      f.world.position.set(-2,.06,3);f.world.rotation.y=.24;
    }
    assert.deepEqual(step(b,optimized,scenario),step(a,legacy,scenario),sources[i].profile.id+' '+scenario+' frame '+frame);
    assert.deepEqual(b.car.object.position.toArray(),a.car.object.position.toArray());
    assert.deepEqual(optimized.sampleVehicleEngineHighPoint({THREE,car:b.car}),legacy.sampleVehicleEngineHighPoint({THREE,car:a.car}));
    // Direct engine matrices are fresh immediately, without rendering.
    const engineMatrices=f=>{const m=[];f.car.hood.bay.traverse(n=>{if(/^(Engine_block|Engine_valve_cover|Valve_cover_rib|Oil_filler_cap)$/.test(n.name))m.push(n.matrixWorld.toArray())});return m};
    assert.deepEqual(engineMatrices(b),engineMatrices(a));
    // Existing downstream consumers update their own branches on demand.
    for(let w=0;w<a.car.wheels.length;w++)assert.deepEqual(b.car.wheels[w].pivot.getWorldPosition(new THREE.Vector3()).toArray(),a.car.wheels[w].pivot.getWorldPosition(new THREE.Vector3()).toArray());
    // Normal renderer matrix traversal leaves EVERY descendant identical.
    a.world.updateMatrixWorld(true);b.world.updateMatrixWorld(true);
    const expected=matrices(a),actual=matrices(b);assert.deepEqual(actual,expected);matricesCompared+=actual.length;framesCompared++;
  }
}

// Cached support indices must respond to damaged engine geometry and mounts.
// Branch updates must also cover a replacement/reparented bay and manual matrix.
for(let i=0;i<sources.length;i++){
  const a=before[i],b=after[i];
  const same=label=>assert.deepEqual(optimized.sampleVehicleEngineHighPoint({THREE,car:b.car}),legacy.sampleVehicleEngineHighPoint({THREE,car:a.car}),sources[i].profile.id+' '+label);
  same('cache warm');
  for(const f of [a,b]){
    const mesh=f.car.hood.bay.getObjectByName('Engine_block');mesh.geometry=mesh.geometry.clone();
    const attr=mesh.geometry.attributes.position;attr.setY(0,attr.getY(0)+4);attr.needsUpdate=true;
  }
  same('changed vertex/version');
  for(const f of [a,b]){
    const mesh=f.car.hood.bay.getObjectByName('Engine_block'),attr=mesh.geometry.attributes.position.clone();attr.setY(1,attr.getY(1)+6);mesh.geometry.setAttribute('position',attr);
    mesh.position.set(.09,-.12,.03);mesh.rotation.z=.41;
  }
  same('replaced buffer and moved engine');
  for(const f of [a,b]){
    const mount=new THREE.Group();mount.position.set(.1,-.31,.25);mount.rotation.set(.22,0,.17);f.car.object.add(mount);mount.add(f.car.hood.bay);
  }
  same('reparented mount');
  for(const f of [a,b]){
    const bay=f.car.hood.bay,copy=bay.clone(true);bay.parent.add(copy);bay.removeFromParent();f.car.hood.bay=copy;
    copy.matrixAutoUpdate=false;copy.matrix.makeRotationX(.38);copy.matrix.setPosition(.12,-.2,.08);
  }
  same('replacement bay and manual matrix');
  for(const f of [a,b]){f.car.hood.bay.removeFromParent();f.car.hood=null;f.car.hoodSpec.core.position.y-=.27;f.car.hoodSpec.core.rotation.z=.29;}
  same('fallback core');
  assert.equal(optimized.sampleVehicleEngineHighPoint({THREE,car:b.car}).source,'engine-core');
  for(const f of [a,b]){f.car.hoodSpec.core.removeFromParent();f.car.hoodSpec.core=null;}
  same('missing engine');
  assert.equal(optimized.sampleVehicleEngineHighPoint({THREE,car:b.car}),null);
}
console.log(JSON.stringify({parity:'PASS',models:sources.length,framesCompared,matricesCompared,checks:'dry/shallow/sinking/moving; pitch/roll; transformed parents; mount/reparent/replacement; vertex/version/attribute; engine matrices; wheel queries; all render matrices'}));

// Fresh, undeformed fixtures for reproducible timings; timed region does not
// include model load, pose setup, assertions, counters or baseline imports.
const a=sources.map(fixture),b=sources.map(fixture);
let worldVisits=0,renderVisits=0;
const updateWorld=THREE.Object3D.prototype.updateWorldMatrix,updateRender=THREE.Object3D.prototype.updateMatrixWorld;
function count(fixtures,api,scenario){
  reset(fixtures,api);for(const f of fixtures){pose(f,0,scenario);step(f,api,scenario);pose(f,1,scenario);}
  worldVisits=renderVisits=0;
  THREE.Object3D.prototype.updateWorldMatrix=function(...args){worldVisits++;return updateWorld.apply(this,args)};
  THREE.Object3D.prototype.updateMatrixWorld=function(...args){renderVisits++;return updateRender.apply(this,args)};
  try{for(const f of fixtures)step(f,api,scenario);const waterVisits=worldVisits;for(const f of fixtures)f.world.updateMatrixWorld(true);return {waterVisits,renderVisits};}
  finally{THREE.Object3D.prototype.updateWorldMatrix=updateWorld;THREE.Object3D.prototype.updateMatrixWorld=updateRender;}
}
function quantile(list,p){const values=[...list].sort((a,b)=>a-b);return +values[Math.floor((values.length-1)*p)].toFixed(4);}
const samples=Math.max(100,Number(process.env.WATER_BENCH_SAMPLES)||600),warmup=200,results=[];
function run(fixtures,api,scenario,frame,render){
  for(const f of fixtures)pose(f,frame,scenario);
  const start=performance.now();for(const f of fixtures)step(f,api,scenario);
  if(render)for(const f of fixtures)f.world.updateMatrixWorld(true);
  return performance.now()-start;
}
for(const scenario of ['dry','shallow','sinking','moving']){
  const visitsBefore=count(a,legacy,scenario),visitsAfter=count(b,optimized,scenario);
  assert(visitsAfter.waterVisits<visitsBefore.waterVisits*.2,scenario+' matrix traversal reduction');
  assert.equal(visitsAfter.renderVisits,visitsBefore.renderVisits,scenario+' no extra downstream render traversal');
  for(const render of [false,true]){
    reset(a,legacy);reset(b,optimized);const oldTimes=[],newTimes=[];
    for(let frame=0;frame<warmup+samples;frame++){
      let oldMs,newMs;
      // Alternate A/B order each frame to reduce clock/temperature ordering bias.
      if(frame%2){newMs=run(b,optimized,scenario,frame,render);oldMs=run(a,legacy,scenario,frame,render);}
      else{oldMs=run(a,legacy,scenario,frame,render);newMs=run(b,optimized,scenario,frame,render);}
      if(frame>=warmup){oldTimes.push(oldMs);newTimes.push(newMs);}
    }
    results.push({scenario,scope:render?'water + normal CPU matrix propagation':'water update only',cars:12,samples,warmup,
      beforeMs:{p50:quantile(oldTimes,.5),p95:quantile(oldTimes,.95)},afterMs:{p50:quantile(newTimes,.5),p95:quantile(newTimes,.95)},matrixVisitsBefore:visitsBefore,matrixVisitsAfter:visitsAfter});
  }
}
console.log(JSON.stringify({benchmark:'CPU only; no draw calls, GPU, frame intervals or whole-scene FPS measured',node:process.version,results},null,2));
