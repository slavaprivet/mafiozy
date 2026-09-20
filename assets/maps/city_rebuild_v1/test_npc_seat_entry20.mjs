// Actual male/female GLBs: newly observed seating never consumes standing time.
// The before implementation is reconstructed in memory by reverting only the
// guarded dt branch. No production file is rewritten by this test.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {createNpcActivityPose} from './npc_activity_pose.mjs';
const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {clone}=await import('./vendor/three_skeleton_utils.mjs');
const sourceText=fs.readFileSync(new URL('./npc_activity_pose.mjs',import.meta.url),'utf8');
const fixedBranch='weight=clamp(age/.5);}else weight=Math.min(1,weight+dt/.5);';
assert.equal(sourceText.split(fixedBranch).length,2,'baseline reconstruction targets exactly the approved branch');
const beforeText=sourceText.replace(fixedBranch,'weight=clamp(age/.5);}weight=Math.min(1,weight+dt/.5);');
const {createNpcActivityPose:createBefore}=await import('data:text/javascript;base64,'+Buffer.from(beforeText).toString('base64'));
const results=[],timings={before:[],after:[]},steadyTimings={before:[],after:[]};
const disposeOverlay=overlay=>{const resources=new Set();overlay.phone.traverse(o=>{if(o.geometry)resources.add(o.geometry);if(o.material)resources.add(o.material)});overlay.phone.removeFromParent();for(const resource of resources)resource.dispose()};
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url));
 const source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const actor=createNpcActor({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:'seat_entry20_'+sex,sex});
 const c=actor.walker.artistContext(),root=[4.1,0,8.2];actor.object.position.fromArray(root);actor.object.rotation.y=.2;
 const reset=()=>{actor.walker.reset();c.object.updateMatrixWorld(true)};
 const seat={id:'seat_entry20-bench',c:1,r:2,height:.46,yaw:.2,phase:'sit',since:1250};
 const pose=(overlay,time,life={},extra={})=>{reset();const before=c.worldPosition('socket_hand_r');overlay.apply({time,life,...extra});assert.deepEqual(actor.object.position.toArray(),root,'source root preserved');assert.equal(actor.object.rotation.y,.2,'source yaw preserved');return before.distanceTo(c.worldPosition('socket_hand_r'))};
 const overlays={before:createBefore({THREE,walker:actor.walker}),after:createNpcActivityPose({THREE,walker:actor.walker})};
 for(const mode of ['before','after']){
  const overlay=overlays[mode];pose(overlay,1);
  const handJump=pose(overlay,1.25,{seat}),weight=overlay.diagnostics().seated;
  assert.equal(weight,mode==='before'?.5:0);
  assert(mode==='before'?handJump>.1:handJump<1e-8,'actual GLB zero-age entry contrast');
  results.push({sex,scenario:'new-seat-after-250ms-standing',mode,weight,handJumpMetres:handJump});
 }
 const after=overlays.after;
 for(const [time,weight]of [[1.5,.5],[1.75,1]]){pose(after,time,{seat});assert.equal(after.diagnostics().seated,weight,'existing seat keeps elapsed blend');}
 // Normal phase progression does not restart entry or invent a new identity.
 pose(after,1.8,{seat:{...seat,phase:'rest'}});assert.equal(after.diagnostics().seated,1);
 pose(after,2);assert(Math.abs(after.diagnostics().seated-.6)<1e-8,'exit retains gradual fade');
 pose(after,2.25);assert(Math.abs(after.diagnostics().seated-.1)<1e-8);
 pose(after,2.5);assert.equal(after.diagnostics().seated,0);assert.equal(after.diagnostics().seatId,null);assert(c.visualPivot.position.length()<1e-8);
 // Late observation: source age, not source age plus previous frame interval.
 for(const mode of ['before','after']){
  const overlay=overlays[mode];pose(overlay,3,{}, {blocked:true});pose(overlay,3.25,{seat:{...seat,since:3000}});
  const weight=overlay.diagnostics().seated;assert.equal(weight,mode==='before'?1:.5);
  results.push({sex,scenario:'late-observer-seat-age-250ms',mode,weight});
 }
 // Entry without a timestamp starts from neutral; old/future timestamps clamp.
 for(const [since,expected]of [[undefined,0],[1000,1],[6000,0]]){
  pose(after,4,{}, {blocked:true});pose(after,4.25,{seat:{...seat,since}});assert.equal(after.diagnostics().seated,expected);
 }
 for(const [life,extra]of [[{cowering:true},{}],[{surrendering:true},{}],[{cuffed:true},{}],[{fleeing:true},{}],[{}, {armed:true}],[{}, {blocked:true}]]){
  pose(after,5,{}, {blocked:true});pose(after,5.25,{seat:{...seat,since:1000}});assert.equal(after.diagnostics().seated,1);
  const handJump=pose(after,5.5,{seat,...life},extra);assert.equal(after.diagnostics().seated,0);assert.equal(after.diagnostics().seatId,null);assert(handJump<1e-8,'blocked/threat/armed must not retain bench pose');
 }
 // Actual mounted weapon survives a source seating request, unchanged grip.
 const gun=new THREE.Group();gun.add(new THREE.Mesh(new THREE.BoxGeometry(.1,.1,.2),new THREE.MeshStandardMaterial()));const mounted=actor.mountWeapon(gun);
 const snapshot={time:6,position:{x:root[0],y:root[1],z:root[2]},yaw:.2};actor.update(.1,snapshot);
 const neutralHand=c.worldPosition('socket_hand_r'),weaponParent=mounted.parent;
 actor.update(.1,{...snapshot,life:{seat:{...seat,since:1000}}});assert(mounted.parent===weaponParent&&weaponParent,'weapon stays mounted');assert(c.worldPosition('socket_hand_r').distanceTo(neutralHand)<1e-8,'armed seat cannot replace grip');assert.deepEqual(actor.object.position.toArray(),root);
 actor.mountWeapon(null);gun.traverse(o=>{o.geometry?.dispose();o.material?.dispose()});
 // Lightweight alternating A/B. Same rig and elapsed seated/entry/exit cycle;
 // reset and actor construction excluded; includes only overlay.apply CPU.
 for(let cycle=0;cycle<18;cycle++){
  const t=10+cycle*2;
  for(const [offset,seated]of [[0,false],[.25,true],[.5,true],[.75,true],[1,false],[1.25,false],[1.5,false]]){
   const time=t+offset,life=seated?{seat:{...seat,since:(t+.25)*1000}}:{};
   for(const mode of cycle%2?['after','before']:['before','after']){
    reset();const start=performance.now();overlays[mode].apply({time,life});const elapsed=performance.now()-start;
    if(cycle>=4)timings[mode].push(elapsed);
   }
  }
 }
 // Separate identical fully seated work from the mixed cycle: the fixed
 // zero-age frame correctly avoids IK, which changes its median workload.
 for(let frame=0;frame<36;frame++)for(const mode of frame%2?['after','before']:['before','after']){
  reset();const start=performance.now();overlays[mode].apply({time:50+frame*.05,life:{seat:{...seat,since:1000}}});const elapsed=performance.now()-start;
  if(frame>=4)steadyTimings[mode].push(elapsed);
 }
 for(const overlay of Object.values(overlays))disposeOverlay(overlay);actor.dispose();
}
const stats=values=>{const sorted=[...values].sort((a,b)=>a-b);return {samples:sorted.length,p50:sorted[Math.floor(sorted.length*.5)],p95:sorted[Math.floor(sorted.length*.95)]}};
console.log(JSON.stringify({pass:true,results,cpuMs:{mixedCycle:{before:stats(timings.before),after:stats(timings.after)},fullySeated:{before:stats(steadyTimings.before),after:stats(steadyTimings.after)}},limits:'Two actual GLBs; lightweight overlay CPU A/B only. No renderer, GPU, full-scene FPS or LIVE acceptance.'},null,2));
