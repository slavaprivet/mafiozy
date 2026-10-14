import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {clone} from './assets/maps/city_rebuild_v1/test_npc_death_offline_setup.mjs';
import * as baseline from './assets/maps/city_rebuild_v1/npc_population.mjs';
import {createNpcBlastPresentation20} from './assets/maps/city_rebuild_v1/npc_blast_presentation20.mjs';
import {createNpcBlastPartsPrototype20} from './assets/maps/city_rebuild_v1/npc_blast_parts_prototype20.mjs';

const root=new URL('./assets/maps/city_rebuild_v1/',import.meta.url),populationUrl=new URL('npc_population.mjs',root);
const sourceBytes=fs.readFileSync(populationUrl),source=sourceBytes.toString('utf8').replaceAll('\r\n','\n');
const anchor="   lodCounts[tier]++;record.poseElapsed=Math.min(.25,record.poseElapsed+poseDelta);const gpuVisible=!focus||distance<=renderDistance||src.id===inspectId,visible=gpuVisible&&!src.carried&&!src.evacuated;";
const replacement=`   // A complete blast replacement already owns the visual, even after its TTL.
   // Still observe source epochs before suppressing pose work: respawn/new death
   // may arrive through the retained source row between snapshot refreshes.
   let visualReplaced=record.actor.isDeathVisualReplaced(record.deathKey);
   if(visualReplaced){
    record.actor.syncSourceLifecycle(normalizeNpcLifecycle(src,{time,sourceNowMs:sourceNow()}),time);
    record.deathKey=record.actor.saveSourceDeathKey();
    visualReplaced=record.actor.isDeathVisualReplaced(record.deathKey);
   }
   lodCounts[tier]++;record.poseElapsed=Math.min(.25,record.poseElapsed+poseDelta);const gpuVisible=!focus||distance<=renderDistance||src.id===inspectId,visible=gpuVisible&&!src.carried&&!src.evacuated&&!visualReplaced;`;
assert.equal(source.split(anchor).length,2,'Review candidate against current production loop; do not silently patch another revision');
const surfaceUrl=new URL('hero_artist14_surface.mjs',root),surfaceBytes=fs.readFileSync(surfaceUrl),surfaceSource=surfaceBytes.toString('utf8').replaceAll('\r\n','\n');
const surfaceAnchor=' return {receive,update,reset,dispose,snapshot,restore,performanceState:';
assert.equal(surfaceSource.split(surfaceAnchor).length,2,'Review contact-effect guard against current surface owner');
const surfaceReplacement=` // The sibling particle draw can outlive its whole-body visual. Pending
 // receive() emissions are private until update() publishes mesh.count.
 function hasActiveContactEffects(){
  if(bleed.count>0||wasIn||time-exitAt<5)return true;
  for(const particle of particles)if(particle.life>0)return true;
  return false;
 }
 function advanceReplacedVisualClock(now){
  if(reaction.kind!=='dead'||!Number.isFinite(now)||now<time||hasActiveContactEffects())return false;
  time=now;return true;
 }
 return {receive,update,reset,dispose,snapshot,restore,hasActiveContactEffects,advanceReplacedVisualClock,performanceState:`;
const absoluteImports=text=>text.replace(/from '(\.\/[^']+)'/g,(_,specifier)=>`from '${new URL(specifier,root).href}'`);
const dataUrl=text=>'data:text/javascript;base64,'+Buffer.from(text).toString('base64');
const surfaceCandidateUrl=dataUrl(absoluteImports(surfaceSource.replace(surfaceAnchor,surfaceReplacement)));
const actorBytes=fs.readFileSync(new URL('npc_actor.mjs',root));
const actorSource=actorBytes.toString('utf8').replaceAll('\r\n','\n');
const actorAnchor='  const vehicleBinding=resolveNpcVehicleBinding(snapshot.life,getVehicle);';
const actorReplacement=`  // Complete blast parts own this body. Keep lifecycle/receipt clocks above
  // current, but skip bones and skin work only when no contact effect remains.
  if(deathPresentation.isReplaced(sourceDeathKey)&&lastSurface?.reaction.kind==='dead'&&lastSurface.reaction.age>=.62&&gaitOutput.gait===0&&surface.advanceReplacedVisualClock(time)){
   walker.object.visible=false;surface.particles.visible=false;
   if(lastSurface?.reaction.kind==='dead'&&sourceDeathAt!==null)lastSurface.reaction.age=Math.max(0,time-sourceDeathAt);
   return lastSurface;
  }
`+actorAnchor;
assert.equal(actorSource.split(actorAnchor).length,2,'Review skip against current actor update sequence');
const actorModule=text=>absoluteImports(text).replaceAll('import.meta.url',JSON.stringify(new URL('npc_actor.mjs',root).href)).replace(new URL('hero_artist14_surface.mjs',root).href,surfaceCandidateUrl);
const actorCandidate=actorModule(actorSource.replace(actorAnchor,actorReplacement));
const unsafe=await import(dataUrl(absoluteImports(source.replace(anchor,replacement))));
const safeReplacement=replacement.replace('&&!visualReplaced;', '&&!(visualReplaced&&!record.actor.surface.hasActiveContactEffects());');
const stalledCandidate=await import(dataUrl(absoluteImports(source.replace(anchor,safeReplacement)).replace(new URL('npc_actor.mjs',root).href,dataUrl(actorModule(actorSource)))));
const candidateSource=absoluteImports(source).replace(new URL('npc_actor.mjs',root).href,dataUrl(actorCandidate));
const candidate=await import(dataUrl(candidateSource));
const vendor=process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const threeUrl=pathToFileURL(vendor+'/build/three.module.js').href;
registerHooks({resolve(s,c,next){return next(s==='three'?threeUrl:s,c)}});
const THREE=await import(threeUrl),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const sourceApi=vm.createContext({});
for(const file of ['npc_death_record20_source.js','npc_blast_record20_source.js'])vm.runInContext(fs.readFileSync(new URL(file,root),'utf8'),sourceApi);
const reports=[];
function fatalRow({id='blast-skip23',sex='male',distance=5,at=1000,weapon='rpg'}={}){
 const entity={id,dead:true,deadAt:at};entity._deathRecord20=sourceApi.createNpcFatalRecord20({entity,targetId:id,weapon,dirR:0,dirC:1,now:at});
 if(weapon==='rpg')entity._deathRecord20=sourceApi.enrichNpcBlastRecord20({entity,previousRecord:null,originSource:{r:0,c:0}});
 return {id,r:0,c:distance/4.1,ang:0,weapon:'fists',look:{gender:sex==='female'?1:0,height:1.9},dead:true,deathConfirmed:true,deadAt:at,deathRecord:entity._deathRecord20};
}
async function fixture(module,{sex='male',distance=5,fps=60,cacheSeconds=8,partOptions={},rows:initialRows=null,inspect=false,waterAt=()=>null}={}){
 const scene=new THREE.Scene(),focus={x:0,z:0};let time=1,rows=initialRows||[fatalRow({sex,distance})],population;
 const id=rows[0].id,counts={actor:0,walker:0,surface:0,restores:0,created:0},wrapped=new WeakSet(),frames=[];
 const parts=createNpcBlastPartsPrototype20(THREE,scene,{groundHeight:()=>0,clock:()=>0,...partOptions});
 const host=createNpcBlastPresentation20({parts,getActor:id=>population?.getActor(id),groundHeight:()=>0});
 const bridge={getWorldClock:()=>({now:time*1000}),getDynamicEntities:()=>({npcs:rows})};
 function instrument(){for(const row of population.getActors()){
  const actor=population.getActor(row.id);if(wrapped.has(actor))continue;wrapped.add(actor);counts.created++;
  for(const [owner,key,metric]of [[actor,'update','actor'],[actor.walker,'update','walker'],[actor.surface,'update','surface'],[actor,'restoreSurfaceState','restores']]){const original=owner[key];owner[key]=function(...args){counts[metric]++;return original.apply(this,args)};}
 }}
 population=await module.createNpcPopulation({THREE,scene,loader:new GLTFLoader(),cloneSkeleton:clone,bridge,maxActors:4,cacheSeconds,waterAt,getFocus:()=>focus,getInspectId:()=>inspect?id:null,profile:true,
  onSnapshot:(snapshot,{time})=>host.sync(snapshot.npcs,{now:time,sourceNowMs:time*1000}),onBeforePose:instrument});
 function tick(at=time+1/fps){
  const dt=Math.min(.25,Math.max(0,at-time));time=at;const before=JSON.stringify(rows);population.update(dt,time);
  const actor=population.getActor(id),beforeHostVisible=actor?.object.visible,marked=actor?.isDeathVisualReplaced(actor.saveSourceDeathKey());
  host.update(time);assert.equal(JSON.stringify(rows),before,'visuals cannot mutate authoritative death, HP or position');
  frames.push({time,beforeHostVisible,afterHostVisible:actor?.object.visible,marked,counts:{...counts},parts:parts.stats().parts,poseMs:population.diagnostics().cpu.last.pose});
  return frames.at(-1);
 }
 function untilReplaced(){for(let n=0;n<Math.ceil(7.7*fps);n++){tick();const actor=population.getActor(id);if(actor?.isDeathVisualReplaced(String(rows[0].deadAt)))return actor;}assert.fail('actual bounded parts did not finish before source TTL');}
 function settle(){while(time<1.7)tick();}
 function sync(nextRows,at=time+.11){rows=nextRows;return tick(at);}
 const snapshotCounts=()=>({...counts});
 return {population,host,parts,scene,focus,id,counts,frames,tick,untilReplaced,settle,sync,snapshotCounts,get actor(){return population.getActor(id)},get rows(){return rows},get time(){return time},dispose(){host.dispose();population.dispose();assert.equal(scene.children.length,0);}};
}
const percentiles=values=>{values.sort((a,b)=>a-b);return {p50Ms:values[Math.floor(values.length*.5)],p95Ms:values[Math.floor(values.length*.95)]};};
const delta=(after,before)=>Object.fromEntries(Object.keys(after).map(k=>[k,after[k]-before[k]]));
function fragmentHash(scene){
 const hash=createHash('sha256');scene.traverse(node=>{if(!node.isMesh||!node.geometry?.userData.blastBytes20)return;hash.update(Buffer.from(node.geometry.attributes.position.array.buffer));hash.update(Buffer.from(node.geometry.index.array.buffer));});return hash.digest('hex');
}

for(const sex of ['male','female'])for(const distance of [5,45])test(`actual population → GLB actor → parts reproduces wasted poses (${sex}, ${distance} m)`,async()=>{
 const results={};for(const [name,module]of [['baseline',baseline],['candidate',candidate]]){
  const f=await fixture(module,{sex,distance});f.untilReplaced();f.settle();assert.equal(f.parts.stats().parts,6);const geometryHash=fragmentHash(f.scene),start=f.snapshotCounts(),samples=[];
  for(let i=0;i<60;i++)samples.push(f.tick());const calls=delta(f.snapshotCounts(),start);
  assert(samples.every(frame=>frame.afterHostVisible===false),'whole body remains hidden after host update');
  if(name==='baseline'){assert.equal(calls.actor,distance===5?60:10);assert(samples.some(frame=>frame.beforeHostVisible),'population keeps unhiding the replaced body');}
  else{assert.equal(calls.actor,distance===5?60:10,'cheap actor lifecycle entry still runs at existing LOD cadence');assert.equal(calls.walker,0);assert.equal(calls.surface,0);assert.equal(f.actor.surface.particles.count,0);}
  results[name]={calls,geometryHash,readyAt:f.frames.find(frame=>frame.parts===6).time,isolatedPoseCost:percentiles(samples.map(frame=>frame.poseMs))};f.dispose();
 }
 assert.equal(results.candidate.geometryHash,results.baseline.geometryHash,'skip starts only after identical complete fragments are ready');
 assert.equal(results.candidate.readyAt,results.baseline.readyAt,'parts admission/readiness cadence unchanged');
 reports.push({sex,distance,updates:60,...results});
});

for(const fps of [7,15,60])test(`source-clock TTL, focus/inspection LOD and replacement stay correct at ${fps} FPS`,async()=>{
 const f=await fixture(candidate,{fps,sex:'female',distance:45,inspect:true});f.untilReplaced();f.settle();const at=f.snapshotCounts();
 for(let i=0;i<fps;i++)f.tick();assert.equal(f.counts.walker,at.walker,'inspection must not force an invisible replacement through pose');
 f.focus.x=1000;f.tick();assert.equal(f.actor.object.visible,false);f.focus.x=0;f.tick();assert.equal(f.actor.object.visible,false);
 f.tick(Math.max(10,f.time+.2));assert.equal(f.parts.stats().parts,0);assert.equal(f.host.diagnostics().deaths,0);assert.equal(f.actor.object.visible,false);assert(f.actor.isDeathVisualReplaced('1000'));
 const saved=f.actor.saveSurfaceState();assert.equal(saved.deathPresentation.visualReplaced,true);assert.equal(saved.sourceDeathKey,'1000');
 const before=f.snapshotCounts();f.sync([{id:f.id,r:0,c:45/4.1,dead:false,look:{gender:1,height:1.9}}]);assert.equal(f.counts.actor-before.actor,1,'reentry poses immediately with accumulated LOD interval');assert.equal(f.actor.surface.state.kind,'idle');assert(f.actor.object.visible);assert(!f.actor.isDeathVisualReplaced('1000'));f.dispose();
});

test('replacement persists through snapshot absence, GPU eviction and recreation after fragments TTL',async()=>{
 const f=await fixture(candidate,{cacheSeconds:.25});f.untilReplaced();const first=f.actor,row=f.rows[0];
 f.sync([]);assert.equal(first.object.visible,false);assert.equal(first.surface.particles.visible,false);f.tick(f.time+.4);assert.equal(f.actor,undefined);assert.equal(f.population.diagnostics().serialized,1);
 f.sync([row],10);const restored=f.actor;assert.notEqual(restored,first);assert(restored.isDeathVisualReplaced('1000'));assert.equal(restored.object.visible,false);assert.equal(f.parts.stats().parts,0);
 const saved=restored.saveSurfaceState();assert.equal(saved.sourceDeathClock.at,1);assert.equal(saved.sourceDeathClock.snapshotAt,10);assert.equal(saved.surface.reaction.age,9);
 const before=f.snapshotCounts();for(let i=0;i<60;i++)f.tick();assert.equal(f.counts.walker,before.walker);assert.equal(f.parts.stats().admitted,1,'recreated visual does not replay fragments');f.dispose();
});

test('explicit alive and a fresh death epoch reuse an ID without inheriting old suppression',async()=>{
 const f=await fixture(candidate);f.untilReplaced();const actor=f.actor;
 f.sync([{id:f.id,r:0,c:5/4.1,dead:false}]);assert.equal(f.actor,actor);assert.equal(actor.surface.state.kind,'idle');assert(actor.object.visible);assert(!actor.isDeathVisualReplaced('1000'));
 const nextAt=Math.ceil((f.time+.2)*1000),next=fatalRow({id:f.id,at:nextAt});f.sync([next],nextAt/1000);
 assert.equal(actor.surface.state.kind,'dead');assert.equal(actor.saveSourceDeathKey(),String(nextAt));assert(!actor.isDeathVisualReplaced(String(nextAt)));assert(actor.object.visible,'new whole corpse remains during pending fragment preparation');
 f.untilReplaced();assert(actor.isDeathVisualReplaced(String(nextAt)));assert.equal(f.parts.stats().admitted,2);assert.equal(f.parts.stats().parts,6);f.dispose();
});

test('new confirmed bullet death and retained-row respawn are observed before a skipped pose',async()=>{
 for(const mode of ['bullet','alive']){
  const f=await fixture(candidate);f.untilReplaced();const row=f.rows[0],before=f.snapshotCounts(),at=f.time+1/60;
  if(mode==='bullet'){const next=fatalRow({id:f.id,at:Math.ceil(at*1000),weapon:'tt_pistol'});for(const key of Object.keys(row))delete row[key];Object.assign(row,next);}
  else{for(const key of Object.keys(row))delete row[key];Object.assign(row,{id:f.id,r:0,c:5/4.1,dead:false});}
  const result=f.tick(at);assert.equal(f.counts.actor-before.actor,1,'retained row change clears skip without waiting for source polling');assert(!f.actor.isDeathVisualReplaced('1000'));assert(result.beforeHostVisible);
  f.tick(f.time+.11);assert(f.actor.object.visible,'host sees the next source snapshot');assert.equal(f.actor.surface.state.kind,mode==='bullet'?'dead':'idle');assert.equal(f.parts.stats().admitted,1,'bullet/alive never starts blast parts');f.dispose();
 }
});

test('sparse source and temporary downing do not revive a previously replaced corpse',async()=>{
 const f=await fixture(candidate);f.untilReplaced();f.settle();const before=f.snapshotCounts();
 for(const extra of [{},{downed:true},{dead:true,meleeStunned:true}]){f.sync([{id:f.id,r:0,c:5/4.1,...extra}]);assert.equal(f.actor.surface.state.kind,'dead');assert(f.actor.isDeathVisualReplaced('1000'));assert.equal(f.actor.object.visible,false);}
 assert.equal(f.counts.walker,before.walker);f.dispose();
});

test('rejected geometry, pending parts and ordinary corpses retain normal pose work',async()=>{
 for(const options of [{partOptions:{maxTrianglesPerVictim:1}},{rows:[fatalRow({weapon:'tt_pistol'})]}]){
  const f=await fixture(candidate,options);f.tick();const before=f.snapshotCounts();for(let i=0;i<60;i++)f.tick();assert.equal(f.counts.actor-before.actor,60);assert.equal(f.parts.stats().parts,0);assert(f.actor.object.visible);assert(!f.actor.isDeathVisualReplaced('1000'));f.dispose();
 }
 const pending=await fixture(candidate);pending.tick();assert(pending.actor.object.visible);assert.equal(pending.parts.stats().parts,0);assert(pending.parts.stats().pendingVictims>0);const before=pending.snapshotCounts();pending.tick();assert.equal(pending.counts.actor-before.actor,1,'pending replacement needs a valid whole actor');pending.dispose();
});

test('unsafe visibility-only skip loses pending contact particles; guarded candidate matches production particles exactly',async()=>{
 const traces={};for(const [name,module]of [['baseline',baseline],['unsafe',unsafe],['stalled-clock',stalledCandidate],['candidate',candidate]]){
  const f=await fixture(module);f.untilReplaced();for(let i=0;i<120;i++)f.tick();assert.equal(f.actor.surface.particles.count,0);
  // Surface accepts the exact confirmed world point even when it is outside
  // the currently posed skin (e.g. a newer source transform than the pose).
  // No bone binding exists here, so bleedingStats alone cannot see this work.
  assert(f.population.receive(f.id,{id:'pending-contact',confirmed:true,kind:'punch',point:{x:15,y:1,z:0}}));
  assert.equal(f.actor.surface.bleedingStats().activeWounds,0);assert.equal(f.actor.surface.particles.count,0,'private receive emissions are not yet published as instances');
  const before=f.snapshotCounts(),trace=[];
  for(let i=0;i<60;i++){
   f.tick();const mesh=f.actor.surface.particles;
   trace.push({visible:mesh.visible,count:mesh.count,instances:Array.from(mesh.instanceMatrix.array.slice(0,mesh.count*16)),colours:mesh.instanceColor?Array.from(mesh.instanceColor.array.slice(0,mesh.count*3)):[]});
   assert.equal(f.actor.object.visible,false,'whole body stays replaced while its contact draw is live');
  }
  if(name==='unsafe'){assert(trace.every(frame=>!frame.visible));assert.equal(f.counts.actor,before.actor);}
  else if(name==='stalled-clock'){assert(trace.every(frame=>frame.count===0),'population resume restore discards newly received private particles');assert(f.counts.restores>before.restores);}
  else{assert(trace.some(frame=>frame.visible&&frame.count>0),'accepted particles remain visible');assert(trace.slice(-10).every(frame=>frame.count===0));}
  if(name==='candidate'){const drained=f.snapshotCounts();for(let i=0;i<20;i++)f.tick();assert.equal(f.counts.walker,drained.walker,'full poses stop only after contact effects drain');}
  traces[name]=trace;f.dispose();
 }
 assert.deepEqual(traces.candidate.map(row=>({...row,visible:row.count>0?row.visible:null})),traces.baseline.map(row=>({...row,visible:row.count>0?row.visible:null})),'particle positions/colours/counts and visible active frames remain byte-exact');
 reports.push({pendingContactCounterexample:{unsafeLostVisibleEffect:true,stalledClockLostNewContact:true,candidateParticleTraceExact:true}});
});

test('active bleeding and its final falling drops finish before skipping the replaced actor',async()=>{
 const traces={};for(const [name,module]of [['baseline',baseline],['candidate',candidate]]){
  const f=await fixture(module);f.untilReplaced();for(let i=0;i<120;i++)f.tick();
  const context=f.actor.walker.artistContext(),point=context.bones.chest.getWorldPosition(new THREE.Vector3());
  assert(f.population.receive(f.id,{id:'body-contact',confirmed:true,kind:'bullet',boneName:'chest',point}));assert.equal(f.actor.surface.bleedingStats().activeWounds,1);
  const trace=[];for(let i=0;i<570;i++){
   f.tick();const surface=f.actor.surface,mesh=surface.particles;
   trace.push({count:mesh.count,drops:surface.bleedingStats().emittedDrops,active:surface.bleedingStats().activeWounds,instances:Array.from(mesh.instanceMatrix.array.slice(0,mesh.count*16)),visible:mesh.count>0?mesh.visible:null});
   assert.equal(f.actor.object.visible,false);
  }
  assert(trace.some(frame=>frame.drops>0));assert(trace.slice(-20).every(frame=>frame.count===0&&frame.active===0));
  if(name==='candidate'){assert.equal(f.actor.surface.hasActiveContactEffects(),false);const before=f.snapshotCounts();for(let i=0;i<20;i++)f.tick();assert.equal(f.counts.walker,before.walker);}
  traces[name]=trace;f.dispose();
 }
 assert.deepEqual(traces.candidate,traces.baseline,'persistent bleed schedule and all drop transforms stay exact, including after parts TTL');
 reports.push({persistentBleed:{frames:570,traceExact:true,skipOnlyAfterDrain:true}});
});

test('water entry/exit and shedding window conservatively retain effect updates',async()=>{
 let water={level:.2,depth:.2};const f=await fixture(candidate,{waterAt:()=>water});f.untilReplaced();
 assert.equal(f.actor.surface.hasActiveContactEffects(),true,'being in water keeps the established emitter path available');
 let before=f.snapshotCounts();for(let i=0;i<10;i++)f.tick();assert.equal(f.counts.actor-before.actor,10);
 water=null;f.tick();assert.equal(f.actor.surface.hasActiveContactEffects(),true,'exit shedding can emit later, even with zero published particles');
 before=f.snapshotCounts();for(let i=0;i<240;i++)f.tick();assert.equal(f.counts.actor-before.actor,240);
 for(let i=0;i<120;i++)f.tick();assert.equal(f.actor.surface.hasActiveContactEffects(),false);
 before=f.snapshotCounts();for(let i=0;i<20;i++)f.tick();assert.equal(f.counts.walker,before.walker);assert.equal(f.actor.object.visible,false);f.dispose();
});

test('death finishes its authored fall and inherited walking blend before pose skipping begins',async()=>{
 const row={id:'moving-before-blast23',r:0,c:1,ang:0,dead:false,walking:true,look:{gender:0,height:1.9}},f=await fixture(candidate,{rows:[row]});
 for(let i=0;i<120;i++){row.c+=1.2/60/4.1;f.tick();}assert(f.actor.walker.diagnostics().gait>.5);
 const deathAt=Math.ceil((f.time+.11)*1000);f.sync([fatalRow({id:f.id,distance:row.c*4.1,at:deathAt})],deathAt/1000);f.untilReplaced();
 const pending=f.snapshotCounts();f.tick();assert.equal(f.counts.walker-pending.walker,1,'complete fragments do not prematurely freeze an unfinished fall/gait');
 for(let i=0;i<120;i++)f.tick();assert.equal(f.actor.walker.diagnostics().gait,0);const settled=f.snapshotCounts();
 for(let i=0;i<60;i++)f.tick();assert.equal(f.counts.walker,settled.walker);assert.equal(f.counts.surface,settled.surface);f.dispose();
});

test('production files stay unchanged and the actual browser ordering is present',()=>{
 assert.deepEqual(fs.readFileSync(populationUrl),sourceBytes,'isolated proposal must not mutate production');assert.deepEqual(fs.readFileSync(surfaceUrl),surfaceBytes);assert.deepEqual(fs.readFileSync(new URL('npc_actor.mjs',root)),actorBytes);
 const walk=fs.readFileSync(new URL('walk_preview.mjs',root),'utf8');assert.match(walk,/npcPopulation\.update\(dt,now\);npcBlastPresentation\?\.update\(now\)/);
 console.log(JSON.stringify({status:'ISOLATED CANDIDATE ONLY',populationSha256:createHash('sha256').update(sourceBytes).digest('hex'),reports,limits:'Actual production population/actor/GLBs/parts/host; no browser, renderer or loaded-scene FPS evidence.'},null,2));
});
