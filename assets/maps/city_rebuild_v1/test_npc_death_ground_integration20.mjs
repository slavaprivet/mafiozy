import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor',actorUrl=new URL('./npc_actor.mjs',import.meta.url);
const sourceText=fs.readFileSync(actorUrl,'utf8'),anchor="s.kind==='dead'&&presented.rawAge>=.62?deathGroundContext:c";
assert.equal(sourceText.split(anchor).length,2,'exact one integration anchor');
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)},load(u,c,next){const result=next(u,c);return u===actorUrl.href+'?no-ground-memo20'?{...result,source:sourceText.replace(anchor,'c')}:result;}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js')),{clone}=await import('./vendor/three_skeleton_utils.mjs');
const after=await import('./npc_actor.mjs'),before=await import('./npc_actor.mjs?no-ground-memo20');
const stats=a=>{a.sort((x,y)=>x-y);return {p50:a[Math.floor(a.length*.5)],p95:a[Math.floor(a.length*.95)]}};
const reports=[];
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(after.NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const make=api=>api.createNpcActor({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:'ground-integration',sex});
 for(const cause of ['bullet','melee','unknown']){
  const a=make(before),b=make(after),record=cause==='unknown'?null:{version:1,confirmed:true,fatal:true,targetId:a.id,eventId:'fatal',deathKey:'1000',cause,travelWorld:{x:1,y:0,z:0}},cost={before:[],after:[]};
  const snapshot={time:1,position:{x:0,y:0,z:0},yaw:.4,life:{dead:true,deathConfirmed:true,deadAt:1000,deathRecord:record}};
  const tick=(actor,t)=>{snapshot.time=t;snapshot.sourceNowMs=t*1000;actor.update(.016,snapshot);};
  tick(a,1);tick(b,1);
  for(let frame=0;frame<90;frame++){
   const t=1.7+frame/60;
   for(const mode of frame%2?['after','before']:['before','after']){const at=performance.now();tick(mode==='before'?a:b,t);if(frame>=20)cost[mode].push(performance.now()-at);}
   const ac=a.walker.artistContext(),bc=b.walker.artistContext();for(const name of Object.keys(ac.bones))assert(Math.max(...ac.bones[name].matrixWorld.elements.map((v,i)=>Math.abs(v-bc.bones[name].matrixWorld.elements[i])))<1e-8,'exact actual pose '+sex+' '+cause);
  }
  const steady=b.diagnostics().deathGround;assert(steady.hits>=80,'actor actually reuses settled correction');
  snapshot.position={x:137.125,y:3.4,z:-89.25};snapshot.yaw=.91;tick(a,4);tick(b,4);assert(b.diagnostics().deathGround.misses>steady.misses,'moving support/root invalidates');
  const pa=a.walker.artistContext().visualPivot.position,pb=b.walker.artistContext().visualPivot.position;assert(pa.distanceTo(pb)<1e-8);
  reports.push({sex,cause,steady,cpuMs:{before:stats(cost.before),after:stats(cost.after)}});a.dispose();b.dispose();
 }
}
console.log(JSON.stringify({pass:true,reports,limits:'Actual actor CPU steady corpse; no common-scene FPS measurement.'},null,2));
