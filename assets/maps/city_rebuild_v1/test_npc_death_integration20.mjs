import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {normalizeNpcSnapshot} from './npc_population.mjs';
import {normalizeNpcLifecycle} from './npc_source_lifecycle.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {clone}=await import('./vendor/three_skeleton_utils.mjs');
let checks=0;
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url));
 const source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const id='fatal-integration-'+sex,make=()=>createNpcActor({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id,sex});
 const record=(cause='bullet',key='1000')=>({version:1,confirmed:true,fatal:true,targetId:id,eventId:'fatal:'+key,deathKey:key,cause,travelWorld:{x:1,y:0,z:0}});
 const row=(r=record(),key=1000)=>({id,r:0,c:0,ang:.35,dead:true,deathConfirmed:true,deadAt:key,deathRecord:r});
 const tick=(a,r,t)=>a.update(0,normalizeNpcSnapshot(r,{time:t,sourceNowMs:t*1000}));
 const sig=a=>Object.values(a.walker.artistContext().bones).flatMap(b=>b.matrixWorld.elements);
 const near=(a,b)=>assert(Math.max(...a.map((v,i)=>Math.abs(v-b[i])))<1e-7);
 for(const cause of ['bullet','melee','super','kick','dropkick','blast']){
  const a=make(),r=row(record(cause));
  a.syncSourceLifecycle(normalizeNpcLifecycle(r,{time:1,sourceNowMs:1000}),1);
  tick(a,r,1.3);assert.equal(a.diagnostics().deathProfile.cause,cause);
  assert.equal(a.diagnostics().surface.reaction.age,.30000000000000004);
  const selected=a.diagnostics().deathProfile;assert(Math.abs(selected.directionLocal.x-Math.cos(Math.PI/2-.35))<1e-10);
  const saved=JSON.parse(JSON.stringify(a.saveSurfaceState())),b=make();b.restoreSurfaceState(saved);
  tick(b,{id,r:0,c:0,ang:.35},1.3);near(sig(a),sig(b));
  // Repeated snapshots, altered records and late receipts cannot replace a pose.
  tick(a,row(record('blast')),1.3);assert.equal(a.diagnostics().deathProfile.cause,cause);
  const stable=JSON.stringify(b.saveSurfaceState()),bad=structuredClone(saved);bad.deathPresentation.record.targetId='other';
  assert.throws(()=>b.restoreSurfaceState(bad));assert.equal(JSON.stringify(b.saveSurfaceState()),stable);
  tick(a,{id,r:0,c:0,dead:false},2);assert.equal(a.diagnostics().deathProfile.known,false);assert.notEqual(a.surface.state.kind,'dead');
  tick(a,row(record('kick','3000'),3000),3.3);assert.equal(a.diagnostics().deathProfile.cause,'kick');
  a.dispose();b.dispose();checks++;
 }
 for(const invalid of [null,{...record(),targetId:'wrong'},{...record(),deathKey:'999'},{...record(),fatal:false},{...record(),cause:'invented'}]){
  const a=make(),b=make();tick(a,row(invalid),1.6);tick(b,row(null),1.6);near(sig(a),sig(b));
  tick(a,row(record()),1.6);near(sig(a),sig(b));assert.equal(a.diagnostics().deathProfile.known,false);
  const saved=a.saveSurfaceState();delete saved.deathPresentation;b.restoreSurfaceState(saved);tick(b,row(null),1.6);near(sig(a),sig(b));
  a.dispose();b.dispose();checks++;
 }
 const crawler=make();
 for(let frame=0;frame<8;frame++)tick(crawler,{id,r:0,c:0,dead:false,deathConfirmed:false,hp:1,downed:true,forcedCrawl:true,walking:true},.2+frame*.1);
 assert.equal(crawler.diagnostics().sourceDown,false,'medical crawler keeps locomotion');
 const crawlerRow={...row(record('bullet')),downed:false,deathFromDowned:true};
 tick(crawler,crawlerRow,1);assert.equal(crawler.diagnostics().surface.reaction.age,0,'prone entry must not age authoritative death');
 assert(crawler.walker.artistContext().bones.head.getWorldPosition(new THREE.Vector3()).y<.8,'prone fatal does not stand up');
 const crawlerSaved=JSON.parse(JSON.stringify(crawler.saveSurfaceState()));assert.equal(crawlerSaved.sourceDeathClock.at,1);
 const restoredCrawler=make();restoredCrawler.restoreSurfaceState(crawlerSaved,{time:1.1,elapsedSeconds:.1});tick(restoredCrawler,crawlerRow,1.1);
 assert(Math.abs(restoredCrawler.diagnostics().surface.reaction.age-.1)<1e-9);assert.equal(restoredCrawler.saveSurfaceState().sourceDeathClock.at,1);
 crawler.dispose();restoredCrawler.dispose();checks++;
 const a=make();tick(a,{id,r:0,c:0,dead:false,deathRecord:record()},1);assert.equal(a.surface.state.kind,'idle');
 tick(a,row({...record(),deathKey:'dead'},0),2);assert.equal(a.diagnostics().deathProfile.known,false);a.dispose();checks++;
}
console.log(JSON.stringify({pass:true,checks,scope:'actual male/female source lifecycle -> actor pose, record/epoch matching, frozen choice, save/recreate, invalid atomic restore, legacy, respawn; no LIVE/FPS'}));
