// In-memory proposal only: expired source stun and a fresh source death in one
// late snapshot. Does not write actor, source clocks, health or production files.
import assert from 'node:assert/strict';import fs from 'node:fs';import {registerHooks} from 'node:module';import {pathToFileURL} from 'node:url';
const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor',actorUrl=new URL('./npc_actor.mjs',import.meta.url),original=fs.readFileSync(actorUrl,'utf8').replaceAll('\r\n','\n');
const once=(s,a,b)=>{assert.equal(s.split(a).length,2,'review changed actor anchor');return s.replace(a,b)};
let candidate=once(original,'let sourceDownVisualBias=0,deathVisualBias=0,deathVisualSide=1;','let sourceDownVisualBias=0,deathVisualBias=0,deathVisualSide=1,deathPendingHeld=false;');
candidate=once(candidate,'const inherited=continuityAt(presentationAt),wasDead=',"const heldAtDeath=sourceDown.active&&surface.state.kind!=='fall',inherited=continuityAt(presentationAt),wasDead=");
candidate=once(candidate,"if(accepted&&!wasDead&&surface.state.kind==='dead'){deathVisualBias=", "if(accepted&&!wasDead&&surface.state.kind==='dead'){deathPendingHeld=heldAtDeath;deathVisualBias=");
candidate=once(candidate,"  if(s.kind!=='fall'&&s.kind!=='dead')return s;", "  if(s.kind!=='fall'&&s.kind!=='dead')return s;\n  if(s.kind==='dead')deathPendingHeld=false;");
candidate=once(candidate,'sourceDownVisualBias=0;deathVisualBias=0;deathVisualSide=1;}', 'sourceDownVisualBias=0;deathVisualBias=0;deathVisualSide=1;deathPendingHeld=false;}');
candidate=once(candidate,'  const stun=snapshot.stun||{},sourceActive=stun.active===true;',`  const stun=snapshot.stun||{},sourceActive=stun.active===true;
  if(deathPendingHeld&&sourceDeathAt!==null&&sourceDown.active&&stun.active===false&&Number.isFinite(stun.endedAge)&&stun.endedAge>=0){
   const endedAt=time-stun.endedAge;
   if(endedAt<=sourceDeathAt){
    const atEnd=THREE.MathUtils.smoothstep(Math.max(0,endedAt-sourceDown.at+sourceDownVisualBias),.03,.62);let lo=0,hi=1;
    for(let i=0;i<24;i++){const mid=(lo+hi)/2;if(THREE.MathUtils.smoothstep(mid,0,1)<1-atEnd)lo=mid;else hi=mid;}
    const inheritedWeight=1-THREE.MathUtils.smoothstep((sourceDeathAt-endedAt)/1.15+(lo+hi)/2,0,1);
    deathVisualBias=fallingAgeForWeight(inheritedWeight);deathVisualSide=inheritedWeight>0?1:surface.state.side;
   }
  }`);
candidate=once(candidate,'deathSide:deathVisualSide},surface:saved','deathSide:deathVisualSide,pendingHeld:deathPendingHeld},surface:saved');
candidate=once(candidate,'const visual=data.reactionVisual;if(visual&&(',"const visual=data.reactionVisual;if(visual&&visual.pendingHeld!==undefined&&typeof visual.pendingHeld!=='boolean')throw Error('Invalid pending held visual');if(visual&&(");
candidate=once(candidate,'deathVisualSide=visual?.deathSide??data.surface.reaction.side;time=', 'deathVisualSide=visual?.deathSide??data.surface.reaction.side;deathPendingHeld=visual?.pendingHeld===true;time=');
const beforeUrl=actorUrl.href+'?late-stun20-before',afterUrl=actorUrl.href+'?late-stun20-prototype';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)},load(u,c,next){const r=next(u,c);return u===beforeUrl?{...r,source:original}:u===afterUrl?{...r,source:candidate}:r}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js')),{clone}=await import('./vendor/three_skeleton_utils.mjs');
const {createNpcActor:createBefore,NPC_ASSETS}=await import(beforeUrl),{createNpcActor:createAfter}=await import(afterUrl),rows=[],unresolved=[];
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const make=create=>{const a=create({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:'late_death20_'+sex,sex});a.update(0,{time:10,position:{x:4,y:0,z:-3},yaw:.4,stun:{active:true,age:1}});return a};
 const head=a=>a.walker.artistContext().worldPosition('head').y,pivot=a=>a.walker.artistContext().visualPivot.quaternion.clone();
 for(const mode of ['inline','external'])for(const endedAge of [4,.1,0]){
  const before=make(createBefore),after=make(createAfter),reference=make(createBefore),lifecycle={dead:true,key:'fresh15',age:0,side:-1};
  // Reference receives the release on time and then the same death, so the
  // expected pose is existing authored recovery, never a synthetic target.
  reference.update(.001,{time:15-endedAge,stun:{active:false,endedAge:0}});
  reference.update(.001,{time:15,lifecycle,stun:{active:false,endedAge}});
  for(const actor of [before,after]){if(mode==='external')actor.syncSourceLifecycle(lifecycle,15);actor.update(.001,{time:15,lifecycle,stun:{active:false,endedAge}});assert.equal(actor.surface.state.kind,'dead');assert.equal(actor.saveSurfaceState().surface.reaction.age,0);assert.deepEqual(actor.object.position.toArray(),[4,0,-3]);assert.equal(actor.object.rotation.y,.4);}
  assert(pivot(after).angleTo(pivot(reference))<1e-5&&Math.abs(head(after)-head(reference))<1e-5,'late snapshot matches on-time authored recovery');
  if(endedAge===4)assert(head(before)<.5&&head(after)>1,'baseline incorrectly inherits stale held pose');
  const current=head(after);after.update(.001,{time:15.001,lifecycle:{...lifecycle,age:.001},stun:{active:false,endedAge:4}});assert(Math.abs(head(after)-current)<.02,'later contradictory expired snapshot cannot restart an already-rendered death');
  rows.push({sex,mode,endedAge,beforeHead:head(before),afterHeadAtDeath:current,referenceHead:head(reference)});before.dispose();after.dispose();reference.dispose();
 }
 for(const stun of [{active:false},{active:true,endedAge:4}]){const before=make(createBefore),after=make(createAfter);for(const a of [before,after])a.update(.001,{time:15,lifecycle:{dead:true,key:'no-expiry',age:0},stun});assert(pivot(before).angleTo(pivot(after))<1e-8,'no invented expiry without explicit endedAge/inactive contract');before.dispose();after.dispose();}
 // Save between external lifecycle and its first pose: carry pending state.
 const pending=make(createAfter);pending.syncSourceLifecycle({dead:true,key:'pending15',age:0},15);const saved=pending.saveSurfaceState();assert.equal(saved.reactionVisual.pendingHeld,true);const restored=make(createAfter);restored.restoreSurfaceState(saved,{time:15,elapsedSeconds:5});restored.update(.001,{time:15,lifecycle:{dead:true,key:'pending15',age:0},stun:{active:false,endedAge:4}});
 const baselinePending=make(createBefore);baselinePending.syncSourceLifecycle({dead:true,key:'pending15',age:0},15);const baselineSaved=baselinePending.saveSurfaceState();baselinePending.restoreSurfaceState(baselineSaved,{time:15,elapsedSeconds:5});baselinePending.update(.001,{time:15,lifecycle:{dead:true,key:'pending15',age:0},stun:{active:false,endedAge:4}});const baselineAge=baselinePending.saveSurfaceState().surface.reaction.age;assert.equal(baselineAge,5,'pre-first-pose raw-age defect already exists without mixed-expiry prototype');baselinePending.dispose();
 if(head(restored)<=1||restored.saveSurfaceState().surface.reaction.age!==0)unresolved.push({sex,scenario:'save-between-external-sync-and-first-update',savedPrivateTime:saved.surface.time,externalSourceDeathAt:15,baselineRestoredRawDeathAge:baselineAge,restoredRawDeathAge:restored.saveSurfaceState().surface.reaction.age,headAfterRestore:head(restored),expected:'source death age0 and neutral start; separate pre-existing clock-order contract requires review'});
 pending.dispose();restored.dispose();
}
console.log(JSON.stringify({prototypeOnly:true,integrated:false,corePass:true,productionReady:unresolved.length===0,rows,unresolved,limits:'Actual male/female CPU snapshots; no production edits, profile selection, source-clock edits or LIVE/GPU acceptance. Unresolved pre-first-pose save ordering is reported rather than hidden.'},null,2));
if(unresolved.length)process.exitCode=1;
