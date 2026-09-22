// Production persistence regression; baseline is exact in-memory rollback. Mixed expired-stun correction is NOT
// installed here. Actual sourceDeathAt survives save before the first pose.
import assert from 'node:assert/strict';import fs from 'node:fs';import {registerHooks} from 'node:module';import {pathToFileURL} from 'node:url';
const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const actorUrl=new URL('./npc_actor.mjs',import.meta.url),production=fs.readFileSync(actorUrl,'utf8').replaceAll('\r\n','\n');
const once=(s,a,b)=>{assert.equal(s.split(a).length,2,'persistence patch anchor needs review');return s.replace(a,b)};
const substitutions=[["sourceDeathKey:sourceDeathKey,", "sourceDeathKey:sourceDeathKey,sourceDeathClock:sourceDeathAt===null?null:{at:sourceDeathAt,snapshotAt:time},"], ["const visual=data.reactionVisual;", "const deathClock=data.sourceDeathClock;let restoredDeathAt=null;\n  if(deathClock!==undefined&&deathClock!==null){\n   if(typeof deathClock!=='object'||Array.isArray(deathClock)||!Number.isFinite(deathClock.at)||!Number.isFinite(deathClock.snapshotAt)||deathClock.snapshotAt!==data.surface?.time||!Number.isFinite(deathClock.snapshotAt-deathClock.at)||data.surface?.reaction?.kind!=='dead'||typeof data.sourceDeathKey!=='string'||!data.sourceDeathKey||Math.max(0,deathClock.snapshotAt-deathClock.at)!==data.surface.reaction.age)throw Error('Invalid source death clock');\n   const restoredTime=options.time??data.surface.time+(options.elapsedSeconds??0);\n   restoredDeathAt=deathClock.at+(restoredTime-deathClock.snapshotAt)-(options.elapsedSeconds??0);\n   if(!Number.isFinite(restoredDeathAt))throw Error('Invalid restored source death clock');\n  }\n  const visual=data.reactionVisual;"], ["sourceDeathAt=sourceDeathKey&&data.surface.reaction.kind==='dead'?time-data.surface.reaction.age-elapsed:null;", "sourceDeathAt=deathClock!=null?restoredDeathAt:sourceDeathKey&&data.surface.reaction.kind==='dead'?time-data.surface.reaction.age-elapsed:null;"]];
const candidate=production;let original=production;for(const [before,after]of substitutions)original=once(original,after,before);
const beforeUrl=actorUrl.href+'?death-clock20-before',afterUrl=actorUrl.href+'?death-clock20-prototype',populationUrl=new URL('./npc_population.mjs',import.meta.url);
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)},load(u,c,next){const r=next(u,c);if(u===beforeUrl)return {...r,source:original};if(u===afterUrl)return {...r,source:candidate};if(u===populationUrl.href+'?death-clock20-before')return {...r,source:once(String(r.source),"'./npc_actor.mjs'","'./npc_actor.mjs?death-clock20-before'")};if(u===populationUrl.href+'?death-clock20-after')return {...r,source:once(String(r.source),"'./npc_actor.mjs'","'./npc_actor.mjs?death-clock20-prototype'")};return r}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js')),{clone}=await import('./vendor/three_skeleton_utils.mjs');
const {createNpcActor:createBefore,NPC_ASSETS}=await import(beforeUrl),{createNpcActor:createAfter}=await import(afterUrl),rows=[];
const maxBoneDiff=(a,b)=>{const ac=a.walker.artistContext(),bc=b.walker.artistContext();let d=0;for(const name of Object.keys(ac.bones))for(let i=0;i<16;i++)d=Math.max(d,Math.abs(ac.bones[name].matrixWorld.elements[i]-bc.bones[name].matrixWorld.elements[i]));return d};
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const make=create=>{const a=create({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:'clock20_'+sex,sex});a.update(0,{time:10,position:{x:4,y:0,z:-3},yaw:.4});a.mountWeapon(new THREE.Group());return a};
 const life={dead:true,key:'source15',age:0,side:-1},originalBefore=make(createBefore),pending=make(createAfter);for(const a of [originalBefore,pending])a.syncSourceLifecycle(life,15);
 const badSaved=originalBefore.saveSurfaceState();originalBefore.restoreSurfaceState(badSaved,{time:15,elapsedSeconds:5});originalBefore.update(.001,{time:15});assert.equal(originalBefore.saveSurfaceState().surface.reaction.age,5,'reproduce current pre-first-pose clock bug');
 const saved=JSON.parse(JSON.stringify(pending.saveSurfaceState()));assert.deepEqual(saved.sourceDeathClock,{at:15,snapshotAt:10});assert.equal(saved.surface.time,10);assert.equal(saved.surface.reaction.age,0);
 for(const [label,options,renderTime,expectedAge,expectedAt]of [
  ['cull-gap',{time:15,elapsedSeconds:5},15,0,15],
  ['later-cull-gap',{time:16,elapsedSeconds:6},16,1,15],
  ['shifted-local-clock',{time:500,elapsedSeconds:5},500,0,500],
  ['elapsed-only',{elapsedSeconds:5},15,0,15],
  ['same-clock-then-render',{time:10,elapsedSeconds:0},15,0,15],
  ['restore-before-source-death',{time:14.75,elapsedSeconds:4.75},15.01,.01,15]
 ]){
  const a=make(createAfter),reference=make(createBefore),weapon=a.weapon;a.restoreSurfaceState(saved,options);a.update(.001,{time:renderTime});reference.syncSourceLifecycle({...life,age:expectedAge},renderTime);reference.update(.001,{time:renderTime});
  const now=a.saveSurfaceState();assert(Math.abs(now.surface.reaction.age-expectedAge)<1e-9);assert.equal(now.sourceDeathClock.at,expectedAt);assert(maxBoneDiff(a,reference)<1e-7,'actual displayed bones follow corrected clock, not only save projection');assert.equal(a.weapon,weapon);assert.deepEqual(a.object.position.toArray(),[4,0,-3]);assert.equal(a.surface.state.kind,'dead');
  rows.push({sex,scenario:label,rawAge:now.surface.reaction.age,sourceAt:now.sourceDeathClock.at,actualBoneDifference:maxBoneDiff(a,reference)});a.dispose();reference.dispose();
 }
 // Repeated configure/sync calls before pose leave the same authoritative at.
 pending.syncSourceLifecycle({...life,age:1},16);pending.syncSourceLifecycle({...life,age:2},17);assert.deepEqual(pending.saveSurfaceState().sourceDeathClock,{at:15,snapshotAt:10});
 const repeated=make(createAfter);repeated.restoreSurfaceState(pending.saveSurfaceState(),{time:17,elapsedSeconds:7});repeated.update(.001,{time:17});assert.equal(repeated.saveSurfaceState().surface.reaction.age,2);repeated.dispose();
 pending.syncSourceLifecycle({dead:true,key:'epoch18',age:0,side:1},18);assert.deepEqual(pending.saveSurfaceState().sourceDeathClock,{at:18,snapshotAt:10});const epoch=make(createAfter);epoch.restoreSurfaceState(pending.saveSurfaceState(),{time:18,elapsedSeconds:8});epoch.update(.001,{time:18});assert.equal(epoch.saveSurfaceState().surface.reaction.age,0);assert.equal(epoch.saveSourceDeathKey(),'epoch18');epoch.dispose();
 // Same actor death -> explicit respawn -> new death cannot carry stale clock.
 pending.syncSourceLifecycle({dead:false,explicitAlive:true},18);pending.update(.001,{time:18});assert.equal(pending.saveSurfaceState().sourceDeathClock,null);assert.equal(pending.surface.state.kind,'idle');pending.syncSourceLifecycle({dead:true,key:'source21',age:0,side:1},21);const reused=make(createAfter);reused.restoreSurfaceState(pending.saveSurfaceState(),{time:21,elapsedSeconds:3});reused.update(.001,{time:21});assert.equal(reused.saveSurfaceState().sourceDeathClock.at,21);assert.equal(reused.saveSurfaceState().surface.reaction.age,0);reused.dispose();
 // Existing saves lack this optional metadata and must remain unchanged.
 const legacy=make(createBefore);legacy.syncSourceLifecycle(life,15);legacy.update(.001,{time:15.2});const legacySaved=legacy.saveSurfaceState();assert.equal(legacySaved.sourceDeathClock,undefined);
 for(const elapsed of [0,30]){const a=make(createAfter),b=make(createBefore),options={time:15.2+elapsed,elapsedSeconds:elapsed};a.restoreSurfaceState(legacySaved,options);b.restoreSurfaceState(legacySaved,options);a.update(.001,{time:options.time});b.update(.001,{time:options.time});assert.equal(a.saveSurfaceState().surface.reaction.age,b.saveSurfaceState().surface.reaction.age);assert(maxBoneDiff(a,b)<1e-7,'legacy restore pose unchanged');a.dispose();b.dispose()}
 // Receipt-only death has no canonical sourceDeathAt and keeps old semantics.
 const receipt=make(createAfter);receipt.receive({id:'receipt20',confirmed:true,dead:true});assert.equal(receipt.saveSurfaceState().sourceDeathClock,null);receipt.dispose();
 const target=make(createAfter),targetBefore=target.saveSurfaceState();
 const badClocks=['wrong',[],{}, {at:Infinity,snapshotAt:10},{at:15,snapshotAt:9},{at:0,snapshotAt:10}];
 for(const bad of badClocks){assert.throws(()=>target.restoreSurfaceState({...saved,sourceDeathClock:bad},{time:15,elapsedSeconds:5}),/Invalid source death clock/);assert.deepEqual(target.saveSurfaceState(),targetBefore,'invalid clock rejected atomically');}
 assert.throws(()=>target.restoreSurfaceState({...saved,sourceDeathClock:{at:Number.MAX_VALUE,snapshotAt:10}},{time:Number.MAX_VALUE,elapsedSeconds:0}),/Invalid restored source death clock/);assert.deepEqual(target.saveSurfaceState(),targetBefore);
 const alive=target.saveSurfaceState();assert.throws(()=>target.restoreSurfaceState({...alive,sourceDeathClock:{at:10,snapshotAt:10}}),/Invalid source death clock/);assert.deepEqual(target.saveSurfaceState(),targetBefore);
 target.dispose();legacy.dispose();originalBefore.dispose();pending.dispose();
}
// Real population cull/reentry path, including its time-stepDt restoration.
const nativeFetch=globalThis.fetch;globalThis.fetch=async(u,o)=>String(u).startsWith('file:')?{ok:true,arrayBuffer:async()=>{const b=fs.readFileSync(new URL(u));return b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength)}}:nativeFetch(u,o);
try{
 for(const mode of ['before','after']){
  const {createNpcPopulation}=await import(populationUrl.href+'?death-clock20-'+mode);let focus={x:0,z:0};
  const population=await createNpcPopulation({THREE,scene:new THREE.Scene(),loader:new GLTFLoader(),cloneSkeleton:clone,getFocus:()=>focus});
  const row={id:'cull_death20',r:0,c:0,weapon:'fists',dead:false};population.sync([row],10,10000);population.update(.04,10);const actor=population.getActor(row.id);assert(actor);
  focus={x:500,z:0};population.update(.04,10.05);assert(!actor.object.visible);
  population.sync([{...row,dead:true,deathConfirmed:true,deadAt:15000}],15,15000);assert.equal(actor.surface.state.kind,'dead');
  focus={x:0,z:0};population.update(.04,15.01);const age=actor.saveSurfaceState().surface.reaction.age,head=actor.walker.artistContext().worldPosition('head').y;
  assert(actor.object.visible);if(mode==='after'){assert(Math.abs(age-.01)<1e-7,'real cull restores source age rather than time since previous pose');assert(head>1,'fresh death remains first-frame standing rather than old corpse')}else assert(age>4,'baseline real cull reproduces aged corpse');
  rows.push({scenario:'real-population-cull-reentry',mode,rawAge:age,headY:head});population.dispose();
 }
}finally{globalThis.fetch=nativeFetch}
console.log(JSON.stringify({prototypeOnly:false,integrated:true,pass:true,rows,scope:'Persistence only; mixed expired-stun patch absent. Actual rigs and population cull path, production clock patch; no LIVE/GPU/FPS acceptance.'},null,2));
