// Original production defect audit, now a regression for prone death continuity.
// --report-only remains available for diagnostics.
import fs from 'node:fs';import assert from 'node:assert/strict';import {registerHooks} from 'node:module';import {pathToFileURL} from 'node:url';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';import {normalizeNpcSnapshot} from './npc_population.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)}});
const {clone}=await import('./vendor/three_skeleton_utils.mjs');
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js')),watched=['head','chest','hand_l','hand_r','foot_l','foot_r'],report=[];
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 for(const moving of [false,true]){
  const id='prone-death-audit20_'+sex,a=createNpcActor({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id,sex}),row={id,r:0,c:0,dead:false,deathConfirmed:false,hp:1,downed:true,downedAt:1000,downedUntil:0,forcedCrawl:true,panic:true,walking:moving};
  for(let i=0;i<10;i++)a.update(.1,normalizeNpcSnapshot(row,{time:10+i*.1,sourceNowMs:10000+i*100}));
  const c=a.walker.artistContext(),before=Object.fromEntries(watched.map(n=>[n,c.worldPosition(n).clone()])),beforeQ=c.visualPivot.quaternion.clone(),root=a.object.position.clone();
  a.update(.016,normalizeNpcSnapshot({...row,dead:true,deathConfirmed:true,downed:false,forcedCrawl:false,walking:false,deathFromDowned:true,deadAt:10916},{time:10.916,sourceNowMs:10916}));
  const step=Math.max(...watched.map(n=>before[n].distanceTo(c.worldPosition(n)))),angle=beforeQ.angleTo(c.visualPivot.quaternion),rawAge=a.saveSurfaceState().surface.reaction.age;
  assert.equal(rawAge,0,'downed origin must never invent source age');assert.equal(a.surface.state.kind,'dead');assert(a.object.position.distanceTo(root)<1e-9);
  report.push({sex,moving,firstStepM:step,pivotAngle:angle,rawAge,rootPreserved:true});a.dispose();
 }
}
const pass=report.every(r=>r.firstStepM<.05&&r.pivotAngle<.05);console.log(JSON.stringify({pass,integrated:true,report},null,2));
if(!process.argv.includes('--report-only'))assert(pass,'prone -> death still snaps/flips; separate settled-prone target required');
