// Real actor/GLB regression for slow continuous frames versus actual hidden gaps.
// No browser, GPU, simulation cadence changes or synthetic substitute actor.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createNpcPopulation} from './npc_population.mjs';
const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {clone}=await import('./vendor/three_skeleton_utils.mjs');
let focus={x:0,z:0},water=true,time=1;
const originalFetch=globalThis.fetch;
globalThis.fetch=async(u,o)=>String(u).startsWith('file:')?{ok:true,arrayBuffer:async()=>{const b=fs.readFileSync(new URL(u));return b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength)}}:originalFetch(u,o);
let population;
try{population=await createNpcPopulation({THREE,scene:new THREE.Scene(),loader:new GLTFLoader(),cloneSkeleton:clone,getFocus:()=>focus,waterAt:()=>water?{level:1,depth:1}:null,profile:true});}
finally{globalThis.fetch=originalFetch;}
const rows=[5,25,45].map((x,i)=>({id:'continuity_'+['near','mid','far'][i],r:0,c:x/4.1,weapon:'fists'}));
population.sync(rows,time);population.update(.04,time);
const actors=rows.map(row=>population.getActor(row.id)),counts=actors.map(()=>({save:0,restore:0,update:0}));
const originals=actors.map(actor=>({save:actor.saveSurfaceState,restore:actor.restoreSurfaceState,update:actor.update}));
for(let i=0;i<actors.length;i++){
 const actor=actors[i],methods=originals[i];
 actor.saveSurfaceState=function(...a){counts[i].save++;return methods.save.apply(this,a)};
 actor.restoreSurfaceState=function(...a){counts[i].restore++;return methods.restore.apply(this,a)};
 actor.update=function(dt,snapshot){counts[i].update++;assert.equal(snapshot.time,time,'absolute presentation clock must not be capped');assert(dt>=0&&dt<=.25,'existing bounded pose integration is unchanged');return methods.update.call(this,dt,snapshot)};
}
const resetCounts=()=>counts.forEach(c=>{c.save=c.restore=c.update=0});
const tick=delay=>{time+=delay;population.sync(rows,time);population.update(.04,time)};
let passed=0;const failures=[],reports=[];
function check(name,fn){try{fn();passed++;console.log('PASS '+name)}catch(e){failures.push({name,message:e.message});console.error('FAIL '+name+' — '+e.message)}}
for(const delay of [.16,.3,.6])check('continuous visible near/mid/far at '+delay+'s uses no persistent-state restore',()=>{
 resetCounts();for(let frame=0;frame<12;frame++)tick(delay);
 reports.push({delay,counts:counts.map(c=>({...c}))});
 assert.deepEqual(counts.map(c=>c.restore),[0,0,0]);assert.deepEqual(counts.map(c=>c.save),[0,0,0]);assert.deepEqual(counts.map(c=>c.update),[12,12,12],'no pose/LOD cadence reduction');
 assert(actors.every(a=>a.object.visible));
});
check('a small ordinary LOD skip followed by a 600ms frame is not an offscreen absence',()=>{
 resetCounts();time+=.016;population.sync(rows,time);population.update(.016,time);tick(.6);
 assert.deepEqual(counts.map(c=>c.restore),[0,0,0]);assert.equal(counts[0].update,2);assert.equal(counts[1].update,1);assert.equal(counts[2].update,1);
});
check('actual hidden then visible gap restores exactly once, then slow visible frames stay continuous',()=>{
 resetCounts();focus={x:500,z:0};for(let frame=0;frame<5;frame++)tick(.3);
 assert(actors.every(a=>!a.object.visible));assert.deepEqual(counts.map(c=>c.update),[0,0,0]);assert.deepEqual(counts.map(c=>c.restore),[0,0,0]);
 focus={x:0,z:0};tick(.6);assert.deepEqual(counts.map(c=>c.restore),[1,1,1]);
 for(let frame=0;frame<4;frame++)tick(.6);assert.deepEqual(counts.map(c=>c.restore),[1,1,1]);assert(actors.every(a=>a.object.visible));
});
check('source omission reentry keeps its explicit persistence restore without a second pose restore',()=>{
 resetCounts();focus={x:500,z:0};tick(.3);time+=.3;population.sync([],time);population.update(.04,time);assert(actors.every(a=>!a.object.visible));
 focus={x:0,z:0};tick(.6);assert.deepEqual(counts.map(c=>c.restore),[1,1,1]);tick(.6);assert.deepEqual(counts.map(c=>c.restore),[1,1,1]);
});
check('explicit page-hidden/QA hold marker restores once on resume without changing clocks or visibility',()=>{
 resetCounts();const before=actors.map(a=>a.object.position.toArray()),savedTime=time;
 population.markPoseInterrupted();population.markPoseInterrupted();assert.equal(time,savedTime);assert.deepEqual(actors.map(a=>a.object.position.toArray()),before);assert(actors.every(a=>a.object.visible));assert.deepEqual(counts.map(c=>({...c})),actors.map(()=>({save:0,restore:0,update:0})));
 // No population updates occur while the host tab or explicit QA is paused.
 time+=5;population.sync(rows,time);population.update(.04,time);assert.deepEqual(counts.map(c=>c.restore),[1,1,1]);assert.deepEqual(counts.map(c=>c.update),[1,1,1]);
 tick(.6);tick(.6);assert.deepEqual(counts.map(c=>c.restore),[1,1,1]);
});
check('wet clothes dry, confirmed bruise/death receipts and absolute reaction age survive continuous slow frames',()=>{
 const actor=actors[0],ctx=actor.walker.artistContext();actor.object.updateMatrixWorld(true);
 const point=ctx.bones.head.getWorldPosition(new THREE.Vector3());assert(population.receive(rows[0].id,{id:'continuity-bruise',confirmed:true,point,zone:'head'}));
 assert(population.receive(rows[0].id,{id:'continuity-death',confirmed:true,dead:true}));
 const saved=originals[0].save.call(actor),wet=[];actor.object.traverse(o=>{const a=o.geometry?.attributes.aClothingWetness;if(a)wet.push(a)});
 const sum=()=>wet.reduce((all,a)=>all+a.array.reduce((s,v)=>s+v,0),0),before=sum(),deathAt=time;assert(before>0,'real clothing wet before drying');water=false;
 resetCounts();for(let frame=0;frame<8;frame++)tick(.6);
 const current=originals[0].save.call(actor);assert.equal(actor.surface.state.kind,'dead');assert(Math.abs(current.surface.reaction.age-(time-deathAt))<1e-8,'death age follows wall clock, not capped dt');
 assert.equal(current.surface.time,time);assert.deepEqual(current.surface.receipts,saved.surface.receipts);assert.deepEqual(current.surface.bruises,saved.surface.bruises);assert(sum()<before,'existing wetness integration still dries');assert.deepEqual(counts.map(c=>c.restore),[0,0,0]);
 focus={x:500,z:0};for(let frame=0;frame<5;frame++)tick(.6);focus={x:0,z:0};tick(.6);
 const returned=originals[0].save.call(actor);assert.equal(actor.surface.state.kind,'dead');assert.deepEqual(returned.surface.receipts,saved.surface.receipts);assert.deepEqual(returned.surface.bruises,saved.surface.bruises);assert(Math.abs(returned.surface.reaction.age-(time-deathAt))<1e-8);assert.deepEqual(counts.map(c=>c.restore),[1,1,1]);
});
population.dispose();population.markPoseInterrupted();console.log(JSON.stringify({passed,failures,reports,scope:'real GLB CPU regression; restore counts, not full-scene FPS'},null,2));if(failures.length)process.exitCode=1;

// Optional short A/B: six actual actors, warmed and continuously visible. The
// legacy module changes only the continuity discriminator in memory; no files
// are rewritten, and actor/source/simulation dt policies are identical.
if(process.argv.includes('--benchmark')&&!failures.length){
 const legacyUrl=new URL('./npc_population.mjs?continuity-baseline',import.meta.url).href;
 const hook=registerHooks({load(url,context,next){const result=next(url,context);if(url!==legacyUrl)return result;const text=String(result.source),anchor='record.poseInterrupted&&gap>stepDt+.001&&gap>.25';assert.equal(text.split(anchor).length,2);return {...result,source:text.replace(anchor,'gap>stepDt+.001&&gap>.25')}}});
 let legacyCreate;try{({createNpcPopulation:legacyCreate}=await import(legacyUrl));}finally{hook.deregister();}
 const fixtures=[];
 globalThis.fetch=async(u,o)=>String(u).startsWith('file:')?{ok:true,arrayBuffer:async()=>{const b=fs.readFileSync(new URL(u));return b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength)}}:originalFetch(u,o);
 try{
  for(const create of [legacyCreate,createNpcPopulation]){
   const p=await create({THREE,scene:new THREE.Scene(),loader:new GLTFLoader(),cloneSkeleton:clone,getFocus:()=>({x:0,z:0}),waterAt:()=>({level:1,depth:1}),profile:true});
   const entities=[2,8,18,25,40,60].map((x,i)=>({id:'benchmark_continuity_'+i,r:0,c:x/4.1,weapon:'fists'}));p.sync(entities,1);p.update(.04,1);let restores=0;
   for(const row of entities){const a=p.getActor(row.id),original=a.restoreSurfaceState;a.restoreSurfaceState=function(...args){restores++;return original.apply(this,args)}}
   fixtures.push({population:p,entities,get restores(){return restores}});
  }
 }finally{globalThis.fetch=originalFetch;}
 const quantile=(values,q)=>+([...values].sort((a,b)=>a-b)[Math.floor((values.length-1)*q)]).toFixed(4),bench=[];let at=1;
 for(const delay of [.3,.6]){
  const times=[[],[]],restoreTimes=[[],[]],warmup=8,samples=24;let beforeCounts;
  for(let frame=0;frame<warmup+samples;frame++){
   at+=delay;if(frame===warmup)beforeCounts=fixtures.map(f=>f.restores);
   for(const i of frame%2?[1,0]:[0,1]){
    const f=fixtures[i];f.population.sync(f.entities,at);const start=performance.now();f.population.update(.04,at);const elapsed=performance.now()-start;
    if(frame>=warmup){times[i].push(elapsed);restoreTimes[i].push(f.population.diagnostics().cpu.last.poseRestore);}
   }
  }
  const restoreCounts=fixtures.map((f,i)=>f.restores-beforeCounts[i]);assert.deepEqual(restoreCounts,[samples*6,0]);
  bench.push({delay,actors:6,warmup,samples,scope:'population.update CPU including opt-in timers; sync/load excluded; no renderer/GPU',before:{p50:quantile(times[0],.5),p95:quantile(times[0],.95),restoreMsP50:quantile(restoreTimes[0],.5),restores:restoreCounts[0]},after:{p50:quantile(times[1],.5),p95:quantile(times[1],.95),restoreMsP50:quantile(restoreTimes[1],.5),restores:restoreCounts[1]}});
 }
 for(const f of fixtures)f.population.dispose();console.log(JSON.stringify({benchmark:bench,node:process.version},null,2));
}
