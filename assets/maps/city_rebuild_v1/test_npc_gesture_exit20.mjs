// Production regression. Baseline reverses only the approved help/talk patch
// in memory; this test never rewrites production or the phone/cash handlers.
// Help/talk calm release only; phone, surrender and crime remain unchanged.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const url=new URL('./npc_actor.mjs',import.meta.url),candidate=fs.readFileSync(url,'utf8').replaceAll('\r\n','\n');
const replaceOnce=(source,from,to)=>{assert.equal(source.split(from).length,2,'regression source anchor must be reviewed after concurrent integration');return source.replace(from,to)};
let original=replaceOnce(candidate,'gesture=null,gestureBlend=0,outgoingGesture=null,outgoingAt=0,outgoingBlend=0,outgoingPoseTime=0,lastGesturePoseTime=0,lifeGestureApplied=false,','gesture=null,gestureBlend=0,');
original=replaceOnce(original,
 `  const calmReleaseAllowed=!busyLife&&!weapon&&!escaping&&!moving&&!requestedGesture&&!life.activity&&!life.seat&&!life.professionAction&&!life.mercenaryAction&&!life.policeObservation&&!life.hijackReaction&&!snapshot.inWater;
  if(!calmReleaseAllowed)outgoingGesture=null;
  if(nextGesture!==gesture){
   if(calmReleaseAllowed&&lifeGestureApplied&&(gesture==='help'||gesture==='talk')){outgoingGesture=gesture;outgoingAt=lastGesturePoseTime;outgoingBlend=gestureBlend;outgoingPoseTime=lastGesturePoseTime;}
   gesture=nextGesture;gestureBlend=0;
  }`, '  if(nextGesture!==gesture){gesture=nextGesture;gestureBlend=0;}');
// The phone/cash owner's integration routes phone through its own visual.
// Support both reviewed anchors without writing or bypassing that integration.
const guard=original.includes("if(gesture&&gesture!=='phone'&&!socialApplied")?"gesture&&gesture!=='phone'":"gesture";
original=replaceOnce(original,
 `  lifeGestureApplied=false;
  if(${guard}&&!socialApplied&&!(gesture==='talk'&&life.activity&&typeof life.activity==='object')){applyLifeGesture(THREE,walker.artistContext(),gesture,time,gestureBlend);lastGesturePoseTime=time;lifeGestureApplied=true;}
  if(outgoingGesture){
   const releaseAge=Math.max(0,time-outgoingAt),releaseWeight=outgoingBlend*(1-THREE.MathUtils.smoothstep(releaseAge,0,.3));
   if(releaseAge>=.3)outgoingGesture=null;
   else applyLifeGesture(THREE,walker.artistContext(),outgoingGesture,outgoingPoseTime,releaseWeight);
  }`, `  if(${guard}&&!socialApplied&&!(gesture==='talk'&&life.activity&&typeof life.activity==='object'))applyLifeGesture(THREE,walker.artistContext(),gesture,time,gestureBlend);`);
const baselineUrl=url.href+'?gesture-exit20-before',candidateUrl=url.href+'?gesture-exit20-production';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)},load(u,c,next){const result=next(u,c);if(u===baselineUrl)return {...result,source:original};if(u===candidateUrl)return {...result,source:candidate};return result}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {clone}=await import('./vendor/three_skeleton_utils.mjs');
const {createNpcActor:createBefore,NPC_ASSETS}=await import(baselineUrl),{createNpcActor:createAfter}=await import(candidateUrl);
const rows=[],priorities=[],performanceMs={before:[],after:[]},position={x:4.1,y:0,z:8.2},yaw=.2;
const maxDifference=(a,b)=>{const ac=a.walker.artistContext(),bc=b.walker.artistContext();let error=0;for(const name of Object.keys(ac.bones))for(let i=0;i<16;i++)error=Math.max(error,Math.abs(ac.bones[name].matrixWorld.elements[i]-bc.bones[name].matrixWorld.elements[i]));return error};
const tick=(actor,time,life={},extra={},dt=1/60)=>{actor.update(dt,{time,position,yaw,life,...extra});assert.deepEqual(actor.object.position.toArray(),[position.x,position.y,position.z]);assert.equal(actor.object.rotation.y,yaw)};
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url));
 const source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const createPair=()=>[createBefore,createAfter].map(create=>create({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:'gesture_exit20_'+sex,sex}));
 for(const gesture of ['help','talk'])for(const fps of [60,10]){
  const pair=createPair(),life=gesture==='help'?{helping:true}:{talking:true},dt=1/fps;
  for(let frame=0;frame<Math.ceil(.75/dt);frame++)for(const actor of pair)tick(actor,1+frame*dt,life,{},dt);
  const releaseAt=1+Math.ceil(.75/dt)*dt,previous=pair.map(a=>a.walker.artistContext().worldPosition('socket_hand_r')),steps=[[],[]];
  for(let frame=0;frame<Math.ceil(.45/dt);frame++)for(let index=0;index<2;index++){
   const actor=pair[index],start=performance.now();tick(actor,releaseAt+frame*dt,{}, {},dt);performanceMs[index?'after':'before'].push(performance.now()-start);
   const hand=actor.walker.artistContext().worldPosition('socket_hand_r');steps[index].push(hand.distanceTo(previous[index]));previous[index]=hand;
   assert.equal(actor.diagnostics().lifeGesture,null,'outgoing presentation never retains logical source gesture');
  }
  assert(maxDifference(...pair)<1e-8,'finite release ends in baseline pose');
  const beforeMax=Math.max(...steps[0]),afterMax=Math.max(...steps[1]);assert(beforeMax>.15);assert(afterMax<beforeMax*.65,'release distributes movement rather than snapping');
  rows.push({sex,gesture,fps,beforeMaxHandStepMetres:beforeMax,afterMaxHandStepMetres:afterMax,afterFirstStepMetres:steps[1][0],neutralAfterSeconds:.3});pair.forEach(a=>a.dispose());
 }
 const scenarios=[
  ['combat',{}, {action:{type:'punch',progress:.35}}],
  ['flee',{fleeing:true},{}],['panic',{panic:true},{}],['movement',{}, {moving:true,motionSpeed:1.2,gaitDistance:.02}],
  ['custody',{cuffed:true},{}],['surrender',{surrendering:true},{}],
  ['new-gesture',{talking:true},{}],
  ['new-shop',{activity:{kind:'shop',phase:'pay',since:1000,payAt:1700,until:5000}},{}],
  ['new-seat',{seat:{id:'test-seat20',c:1,r:2,height:.46,yaw:.2,phase:'sit',since:1000}},{}],
  ['new-profession',{professionAction:{type:'heal',progress:.5}},{}],
  ['weapon',{},{}],['source-stun',{}, {stun:{active:true,age:.1}}],
  ['death',{}, {hit:{id:'test-death20',confirmed:true,dead:true}}]
 ];
 for(const [name,life,extra]of scenarios){
  const pair=createPair();for(let frame=0;frame<45;frame++)for(const actor of pair)tick(actor,1+frame/60,{helping:true});
  // Begin the fade, then preempt it on the very next frame.
  for(const actor of pair)tick(actor,1.75);
  let gun=null,mounts=null,mountParents=null;
  if(name==='weapon'){gun=new THREE.Group();gun.add(new THREE.Mesh(new THREE.BoxGeometry(.1,.1,.2),new THREE.MeshStandardMaterial()));mounts=pair.map(a=>a.mountWeapon(gun));}
  if(mounts)mountParents=mounts.map(m=>m.parent);
  pair.forEach(a=>tick(a,1.75+1/60,life,extra));
  const difference=maxDifference(...pair);assert(difference<1e-8,name+' preempts previous help pose on first frame');
  if(mounts)assert(mounts.every((m,index)=>m.parent&&m.parent===mountParents[index]),'mounted weapon attachment unchanged');
  priorities.push({sex,scenario:name,maxWorldBoneMatrixDifference:difference});
  pair.forEach(a=>a.dispose());gun?.traverse(o=>{o.geometry?.dispose();o.material?.dispose()});
 }
 // Phone is deliberately not part of this proposal. Match current release
 // matrices so this prototype cannot silently change the other author's work.
 const pair=createPair();for(let frame=0;frame<45;frame++)for(const actor of pair)tick(actor,1+frame/60,{phoneCalling:true});
 pair.forEach(a=>tick(a,1.75));assert(maxDifference(...pair)<1e-8,'phone release remains production-identical');pair.forEach(a=>a.dispose());
 // Social activity owns its own animation; a skipped generic talking gesture
 // must not suddenly appear as an outgoing pose when the activity disappears.
 const socialPair=createPair();for(let frame=0;frame<45;frame++)for(const actor of socialPair)tick(actor,1+frame/60,{talking:true,activity:{kind:'talk',phase:'active',since:1000,until:5000}});
 socialPair.forEach(a=>tick(a,1.75));assert(maxDifference(...socialPair)<1e-8,'no phantom generic-talk exit after social-owned animation');socialPair.forEach(a=>a.dispose());
 // A reappearing actor may receive a small integration dt despite an absolute
 // timestamp jump. Never resurrect a completed gesture from before that gap.
 for(const gap of [1,5])for(const gesture of ['help','talk']){
  const gapPair=createPair(),life=gesture==='help'?{helping:true}:{talking:true};
  for(let frame=0;frame<45;frame++)for(const actor of gapPair)tick(actor,1+frame/60,life);
  gapPair.forEach(a=>tick(a,1+44/60+gap,{}, {},1/60));assert(maxDifference(...gapPair)<1e-8,'absolute '+gap+'s observation gap must not replay '+gesture+' exit');
  gapPair.forEach(a=>a.dispose());
 }
}
const stats=a=>{a.sort((x,y)=>x-y);return{samples:a.length,p50:a[Math.floor(a.length*.5)],p95:a[Math.floor(a.length*.95)]}};
console.log(JSON.stringify({integrated:true,pass:true,rows,priorities,observationGapCases:8,cpuMs:{before:stats(performanceMs.before),after:stats(performanceMs.after)},limits:'Actual male/female GLB production regression; baseline reversed only in memory. No LIVE/GPU or full-scene FPS claim. CPU samples include the intended extra exit IK.'},null,2));
