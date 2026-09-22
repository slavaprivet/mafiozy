// CPU-only actual actor ABBA; no runtime edit, GPU or game-FPS assertion.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {clone} from './test_npc_death_offline_setup.mjs';
const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const guard='    if(waterLevel===null&&!record.meshes.some(entry=>entry.hasWet))return;';
let baselineLoads=0,candidateLoads=0;
registerHooks({resolve(specifier,context,next){
 if(specifier==='three')return next(pathToFileURL(vendor+'/build/three.module.js').href,context);
 const tag=context.parentURL&&new URL(context.parentURL).searchParams.get('wetCost');
 if(tag&&specifier.startsWith('.')&&specifier.endsWith('.mjs')){const url=new URL(specifier,context.parentURL);url.searchParams.set('wetCost',tag);return next(url.href,context);}
 return next(specifier,context);
},load(url,context,next){const result=next(url,context),u=new URL(url),tag=u.searchParams.get('wetCost');if(!tag||!u.pathname.endsWith('/artist14/wet_clothing.mjs'))return result;
 let source=String(result.source);assert.equal(source.split(guard).length,2,'exact reviewed fast-path anchor');if(tag==='baseline'){source=source.replace(guard,'');baselineLoads++;}else candidateLoads++;
 // Private test instrumentation only; same exports/logic on both isolated graphs.
 source='export const testWetRecords=new WeakMap();\n'+source.replace('records.set(model,record);return model;','records.set(model,record);testWetRecords.set(model,record);return model;').replace('const elapsed=record.elapsed;record.elapsed=0;','const elapsed=record.elapsed;record.elapsed=0;record.testDrains=(record.testDrains||0)+1;').replace('const root=model.root||model;root.updateWorldMatrix(true,true);','record.testMatrixPasses=(record.testMatrixPasses||0)+1;const root=model.root||model;root.updateWorldMatrix(true,true);');
 return {...result,source};}});
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const modules={};for(const tag of ['baseline','candidate'])modules[tag]={actor:await import('./npc_actor.mjs?wetCost='+tag),wet:await import('./artist14/wet_clothing.mjs?wetCost='+tag)};
assert.equal(baselineLoads,1);assert.equal(candidateLoads,1);
let checks=0;const results=[];
const summary=values=>{const sorted=[...values].sort((a,b)=>a-b);return {p50:+sorted[Math.floor(sorted.length*.5)].toFixed(4),p95:+sorted[Math.floor(sorted.length*.95)].toFixed(4)}};
function fixture(tag,sex,source){const scene=new T.Scene(),actor=modules[tag].actor.createNpcActor({THREE:T,scene,source,cloneSkeleton:clone,id:sex,sex}),record=modules[tag].wet.testWetRecords.get(actor.surface.model);assert(record?.meshes.length);return {tag,actor,record,scene};}
function shaderValues(mesh){return (Array.isArray(mesh.material)?mesh.material:[mesh.material]).map(material=>{const shader={uniforms:{},vertexShader:'#include <common>\n#include <project_vertex>',fragmentShader:'#include <common>\n#include <color_fragment>\n#include <roughnessmap_fragment>'};material.onBeforeCompile(shader,null);return Object.fromEntries(Object.entries(shader.uniforms).map(([key,u])=>[key,u.value]));});}
function parity(a,b){
 for(const f of [a,b]){const state=f.actor.surface.performanceState();assert.equal(state.wetMeshes,f.record.meshes.filter(e=>e.hasWet).length);assert.equal(state.reaction,f.actor.surface.state.kind);assert.equal(state.particles,f.actor.surface.particles.count);assert.equal(state.activeBleedingWounds,f.actor.surface.bleedingStats().activeWounds);assert.equal(state.inWater,f.record.meshes.some(e=>e.uniforms.uClothingInWater.value===1));}
 assert.deepEqual(a.actor.surface.performanceState(),b.actor.surface.performanceState());
 assert.equal(a.record.elapsed,b.record.elapsed,'sample remainder');assert.equal(a.record.testDrains,b.record.testDrains,'drained sample count');assert.equal(a.record.meshes.length,b.record.meshes.length);
 for(let i=0;i<a.record.meshes.length;i++){const x=a.record.meshes[i],y=b.record.meshes[i];assert.equal(x.hasWet,y.hasWet);assert.equal(x.wet.version,y.wet.version);assert.equal(x.wet.count,y.wet.count);assert.deepEqual(x.wet.array,y.wet.array);assert.deepEqual(x.uniforms,y.uniforms);assert.deepEqual(shaderValues(x.mesh),shaderValues(y.mesh));assert.deepEqual(x.mesh.matrixWorld.elements,y.mesh.matrixWorld.elements);}
 const matrices=f=>{const out=[];f.actor.object.traverse(n=>out.push(n.matrixWorld.toArray()));return out};assert.deepEqual(matrices(a),matrices(b));assert.deepEqual(a.actor.surface.snapshot(),b.actor.surface.snapshot());assert.equal(a.actor.surface.particles.count,b.actor.surface.particles.count);checks++;
}
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(modules.baseline.actor.NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const a=fixture('baseline',sex,source),b=fixture('candidate',sex,source);let time=0;
 const step=(dt,input={})=>{time+=dt;const snapshot={time,position:{x:time*.1,y:0,z:time*.2},yaw:time*.05,moving:true,motionSpeed:1.8,...input};a.actor.update(dt,snapshot);b.actor.update(dt,snapshot);parity(a,b);};
 for(const dt of [.03,.02,.04,.1,.2,.01])step(dt);assert(a.record.testMatrixPasses>0);assert.equal(b.record.testMatrixPasses||0,0);
 step(.08,{inWater:true,waterLevel:.7});assert(b.record.meshes.some(e=>e.hasWet));step(.025,{inWater:true,waterLevel:.9});step(.08,{inWater:true,waterLevel:.9});
 step(.025,{inWater:false});step(.03,{inWater:false});step(.04,{inWater:false});step(.2,{inWater:false});
 // Near-dry restored state reaches zero through the unchanged live drying loop.
 const saved=a.actor.surface.snapshot();let maxWet=0;for(const entry of a.record.meshes)for(const value of entry.wet.array)maxWet=Math.max(maxWet,value);const untilAlmostDry=Math.round(maxWet*255)/255*90-.01;for(const f of [a,b])f.actor.surface.restore(saved,{elapsedSeconds:untilAlmostDry,time});parity(a,b);assert(b.record.meshes.some(e=>e.hasWet),'leave positive wetness for actual drying branch');step(.2);assert(b.record.meshes.every(e=>!e.hasWet));const passes=b.record.testMatrixPasses;step(.1);assert.equal(b.record.testMatrixPasses,passes);
 // Dry reset keeps its existing sample-clock semantics; fresh immersion still works.
 for(const f of [a,b])f.actor.surface.reset();parity(a,b);step(.025);step(.03,{inWater:true,waterLevel:.5});step(.08,{inWater:true,waterLevel:.5});assert(b.record.meshes.some(e=>e.hasWet));
 const contact=a.actor.walker.artistContext().bones.chest.getWorldPosition(new T.Vector3()),hit={id:'wet-contact',confirmed:true,kind:'punch',zone:'chest',point:{x:contact.x,y:contact.y,z:contact.z},knockdown:false};for(const f of [a,b])assert.equal(f.actor.receive(hit),true);step(.1,{inWater:true,waterLevel:.5});
 a.actor.dispose();b.actor.dispose();
 // Four independent actual actors, whole update measured in ABBA order. Each
 // actor gets identical moving dry snapshots; .1s guarantees a wet sample drain.
 const actors=['baseline','candidate','candidate','baseline'].map(tag=>fixture(tag,sex,source)),times={baseline:[],candidate:[]};
 for(let round=0;round<24;round++)for(const f of actors){const snapshot={time:(round+1)*.1,position:{x:round*.03,y:0,z:round*.02},yaw:round*.01,moving:true,motionSpeed:1.8};const start=performance.now();f.actor.update(.1,snapshot);const elapsed=performance.now()-start;if(round>=8)times[f.tag].push(elapsed);}
 parity(actors[0],actors[1]);results.push({sex,wetMeshes:actors[0].record.meshes.length,wetVertices:actors[0].record.meshes.reduce((sum,e)=>sum+e.wet.count,0),wholeActorUpdateMs:{baseline:summary(times.baseline),candidate:summary(times.candidate)},wetMatrixPasses:{baseline:actors[0].record.testMatrixPasses||0,candidate:actors[1].record.testMatrixPasses||0},drains:actors[0].record.testDrains});for(const f of actors)f.actor.dispose();
}
console.log(JSON.stringify({checks,results,scope:'CPU actual male/female actor.update ABBA, exact Float32 wetness/uniforms/matrices/surface snapshots/sample clocks; no GPU or whole-game FPS'}));
