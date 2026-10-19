// Production continuity regression; before version is reconstructed only in memory.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const actorUrl=new URL('./npc_actor.mjs',import.meta.url),candidate=fs.readFileSync(actorUrl,'utf8').replaceAll('\r\n','\n');
const replaceOnce=(source,from,to)=>{assert.equal(source.split(to).length,2,'regression anchor changed; review required: '+to.slice(0,80));return source.replace(to,from)};
let original=replaceOnce(candidate,' function receive(event,presentationAt=time){',` let sourceDownVisualBias=0,deathVisualBias=0,deathVisualSide=1;
 function fallingAgeForWeight(weight){
  if(weight<=0)return 0;if(weight>=1)return .62;
  let lo=.03,hi=.62;for(let i=0;i<24;i++){const mid=(lo+hi)/2;if(THREE.MathUtils.smoothstep(mid,.03,.62)<weight)lo=mid;else hi=mid;}return (lo+hi)/2;
 }
 function continuityAt(atTime){
  const state=surface.state,ease=THREE.MathUtils.smoothstep;
  if(state.kind==='fall'){const age=Math.max(0,atTime-state.at);return {weight:ease(age,.03,.62)*(1-ease(age,1.55,2.7)),side:state.side};}
  if(sourceDown.active)return {weight:ease(Math.max(0,atTime-sourceDown.at+sourceDownVisualBias),.03,.62),side:1};
  if(sourceDown.releaseAt!==null)return {weight:1-ease(Math.max(0,atTime-sourceDown.releaseAt),0,1.15),side:1};
  return {weight:0,side:1};
 }
 const reactionPresentation={kind:'idle',age:0,rawAge:0,visualWeight:0,side:1,unit:undefined,zone:undefined};
 function presentReaction(s,sourceHeld=false){
  if(s.kind!=='fall'&&s.kind!=='dead')return s;
  const rawAge=s.kind==='dead'&&sourceDeathAt!==null?Math.max(0,time-sourceDeathAt):s.age;
  const age=s.kind==='dead'?rawAge+deathVisualBias:sourceHeld?Math.min(.75,rawAge+sourceDownVisualBias):rawAge;
  reactionPresentation.kind=s.kind;reactionPresentation.rawAge=rawAge;reactionPresentation.age=age;
  reactionPresentation.visualWeight=THREE.MathUtils.smoothstep(age,.03,.62)*(s.kind==='dead'?1:1-THREE.MathUtils.smoothstep(age,1.55,2.7));
  reactionPresentation.side=s.kind==='dead'?deathVisualSide+(s.side-deathVisualSide)*THREE.MathUtils.smoothstep(rawAge,0,.3):s.side;
  reactionPresentation.unit=s.unit;reactionPresentation.zone=s.zone;return reactionPresentation;
 }
 function receive(event,presentationAt=time){`);
original=replaceOnce(original,"  const wasDead=surface.state.kind==='dead',accepted=surface.receive(event);\n  if(accepted&&!wasDead&&surface.state.kind==='dead')deathEntry20.begin(presentationAt);", "  const inherited=continuityAt(presentationAt),wasDead=surface.state.kind==='dead',accepted=surface.receive(event);\n  if(accepted&&!wasDead&&surface.state.kind==='dead'){deathEntry20.begin(presentationAt);deathVisualBias=fallingAgeForWeight(inherited.weight);deathVisualSide=inherited.weight>0?inherited.side:surface.state.side;}");
original=replaceOnce(original,'targetId:persistentId,dead:true,side:lifecycle.side});','targetId:persistentId,dead:true,side:lifecycle.side},atTime);');
original=replaceOnce(original,"sourceDown={active:false,at:atTime,releaseAt:null};sourceFall=null;}","sourceDown={active:false,at:atTime,releaseAt:null};sourceFall=null;sourceDownVisualBias=0;deathVisualBias=0;deathVisualSide=1;}");
original=replaceOnce(original,"  if(sourceActive){if(!sourceDown.active)sourceDown.at=time-(Number.isFinite(stun.age)?Math.max(0,stun.age):0);sourceDown.active=true;sourceDown.releaseAt=null;}","  if(sourceActive){if(!sourceDown.active){const age=Number.isFinite(stun.age)?Math.max(0,stun.age):0;sourceDownVisualBias=Math.max(0,fallingAgeForWeight(continuityAt(time).weight)-age);sourceDown.at=time-age;}sourceDown.active=true;sourceDown.releaseAt=null;}");
original=replaceOnce(original,'Math.max(0,endTime-sourceDown.at),.03,.62)','Math.max(0,endTime-sourceDown.at+sourceDownVisualBias),.03,.62)');
original=replaceOnce(original,'if(sourceFall)pose.reaction(sourceFall,c);','if(sourceFall)pose.reaction(presentReaction(sourceFall,sourceDown.active),c);');
original=replaceOnce(original,"const presented=s.kind==='dead'&&sourceDeathAt!==null?{...s,age:Math.max(0,time-sourceDeathAt),rawAge:Math.max(0,time-sourceDeathAt)}:s;",'const presented=presentReaction(s);');
original=replaceOnce(original,'surface:saved};}','reactionVisual:{sourceDownBias:sourceDownVisualBias,deathBias:deathVisualBias,deathSide:deathVisualSide},surface:saved};}');
original=replaceOnce(original,"const down=data.sourceDown;if(down",`const visual=data.reactionVisual;if(visual&&(!Number.isFinite(visual.sourceDownBias)||visual.sourceDownBias<0||visual.sourceDownBias>.62||!Number.isFinite(visual.deathBias)||visual.deathBias<0||visual.deathBias>.62||!Number.isFinite(visual.deathSide)||Math.abs(visual.deathSide)>1))throw Error('Invalid reaction visual continuity');const down=data.sourceDown;if(down`);
original=replaceOnce(original,'', 'sourceDownVisualBias=visual?.sourceDownBias||0;deathVisualBias=visual?.deathBias||0;deathVisualSide=visual?.deathSide??data.surface.reaction.side;');
const beforeUrl=actorUrl.href+'?recovery20-before',afterUrl=actorUrl.href+'?recovery20-after';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)},load(u,c,next){const result=next(u,c);return u===beforeUrl?{...result,source:original}:u===afterUrl?{...result,source:candidate}:result}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {clone}=await import('./vendor/three_skeleton_utils.mjs');
const {createNpcActor:createBefore,NPC_ASSETS}=await import(beforeUrl),{createNpcActor:createAfter}=await import(afterUrl);
const results=[],position={x:4,y:0,z:-3},yaw=.4,cpu={before:[],after:[]};
function skinFloor(actor){let min=Infinity;const point=new THREE.Vector3();actor.object.traverse(mesh=>{if(!mesh.isSkinnedMesh)return;mesh.skeleton.update();for(let i=0;i<mesh.geometry.attributes.position.count;i++){mesh.getVertexPosition(i,point).applyMatrix4(mesh.matrixWorld);min=Math.min(min,point.y)}});return min}
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const fixture=create=>{const a=create({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:'recovery_proto20_'+sex,sex});a.update(0,{time:1,position,yaw});a.mountWeapon(new THREE.Group());return a};
 const tick=(a,time,snapshot={},dt=.001)=>{const weapon=a.weapon;a.update(dt,{time,...snapshot});assert.deepEqual(a.object.position.toArray(),[4,0,-3]);assert.equal(a.object.rotation.y,yaw);assert.equal(a.weapon,weapon);for(const [name,bone]of Object.entries(a.walker.artistContext().bones)){const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);assert(p.distanceTo(a.walker.artistContext().rest[name].p)<1e-7);assert(s.distanceTo(a.walker.artistContext().rest[name].s)<1e-6)}};
 const pose=a=>({q:a.walker.artistContext().visualPivot.quaternion.clone(),head:a.walker.artistContext().worldPosition('head').y});
 const delta=(a,b)=>({angle:a.q.angleTo(b.q),head:Math.abs(a.head-b.head)});
 for(const trigger of ['repeat-stun','source-death','receipt-death'])for(const mode of ['before','after']){
  const a=fixture(mode==='before'?createBefore:createAfter);
  tick(a,10,{stun:{active:true,age:1}});tick(a,10.01,{stun:{active:false,endedAge:0}});tick(a,10.16,{stun:{active:false}});const start=pose(a);
  const event=trigger==='repeat-stun'?{stun:{active:true,age:0}}:trigger==='source-death'?{lifecycle:{dead:true,key:'fatal20',age:0}}:{hit:{id:'fatal-receipt20',confirmed:true,dead:true,side:-1}};
  tick(a,10.161,event);const jump=delta(start,pose(a));
  if(mode==='after'){assert(jump.angle<.02&&jump.head<.02,trigger+' starts at authored recovery pose');assert(trigger==='repeat-stun'?a.diagnostics().sourceDown:a.surface.state.kind==='dead','state changes immediately');assert(Math.abs(skinFloor(a))<.002,'actual skinned floor contact preserved');}
  else assert(jump.angle>1,'baseline must demonstrate audited snap');
  results.push({sex,trigger,mode,...jump});
  if(mode==='after'){
   const saved=a.saveSurfaceState();if(trigger==='repeat-stun')assert(saved.sourceDown.age<1e-8,'raw source stun age has no presentation bias');else{assert(saved.surface.reaction.age<=.0011,'source death clock has no presentation bias');const receipts=saved.surface.receipts;assert(!a.receive({id:trigger==='source-death'?'world-death:'+a.id+':fatal20':'fatal-receipt20',confirmed:true,dead:true}));assert.deepEqual(a.saveSurfaceState().surface.receipts,receipts)}
   const restored=fixture(createAfter);restored.restoreSurfaceState(saved,{time:10.161});tick(restored,10.161,trigger==='repeat-stun'?{stun:{active:true,age:0}}:{});const restoredJump=delta(pose(a),pose(restored));assert(restoredJump.angle<1e-6&&restoredJump.head<1e-6,'zero-gap save/restore preserves presentation');
   const beforeInvalid=restored.saveSurfaceState();assert.throws(()=>restored.restoreSurfaceState({...saved,reactionVisual:{...saved.reactionVisual,deathBias:Infinity}}),/Invalid reaction visual/);assert.deepEqual(restored.saveSurfaceState(),beforeInvalid,'invalid optional presentation payload is atomic');
   restored.restoreSurfaceState(saved,{time:40.161,elapsedSeconds:30});tick(restored,40.162,trigger==='repeat-stun'?{stun:{active:false,endedAge:29}}:{});
   assert(trigger==='repeat-stun'?pose(restored).head>1:restored.surface.state.kind==='dead','long gap does not replay recovery');restored.dispose();
  }
  a.dispose();
 }
 // Normal standing death must remain exactly the same authored animation.
 for(const side of [-1,1]){
  const pair=[fixture(createBefore),fixture(createAfter)];
  for(const time of [2,2.1,2.3,2.7,4]){pair.forEach(a=>tick(a,time,time===2?{lifecycle:{dead:true,key:'normal20',age:0,side}}:{}));const d=delta(pose(pair[0]),pose(pair[1]));assert(d.angle<1e-7&&d.head<1e-8,'standing death unchanged for side '+side)}pair.forEach(a=>a.dispose());
  const legacy=fixture(createBefore),restored=fixture(createAfter);tick(legacy,2,{lifecycle:{dead:true,key:'legacy20',age:0,side}});tick(legacy,2.15);restored.restoreSurfaceState(legacy.saveSurfaceState(),{time:2.15});tick(restored,2.15);const d=delta(pose(legacy),pose(restored));assert(d.angle<1e-7&&d.head<1e-8,'legacy payload without reactionVisual remains canonical');legacy.dispose();restored.dispose();
 }
 // Death can interrupt the original fall, including opposite source side.
 for(const age of [.1,.3,.55,1]){
  const a=fixture(createAfter);tick(a,5,{stun:{active:true,age}});const before=pose(a);tick(a,5.001,{lifecycle:{dead:true,key:'midfall20',age:0,side:-1}});const d=delta(before,pose(a));assert(d.angle<.02&&d.head<.02,'death during fall continuity');a.dispose();
 }
 // Existing authored surface knockdown (not source stun) can also die mid-fall.
 for(const age of [.3,1,1.8]){
  const a=fixture(createAfter);tick(a,5);a.receive({id:'surfacefall20',confirmed:true,point:a.walker.artistContext().worldPosition('head'),knockdown:true,side:-1});tick(a,5+age);const before=pose(a);tick(a,5+age+.001,{lifecycle:{dead:true,key:'surfacefall-death20',age:0,side:1}});const d=delta(before,pose(a));assert(d.angle<.02&&d.head<.02,'surface fall/recovery to death remains continuous');a.dispose();
 }
 const hidden=fixture(createAfter);tick(hidden,10,{stun:{active:true,age:1}});tick(hidden,10.01,{stun:{active:false,endedAge:0}});tick(hidden,10.16,{stun:{active:false}});tick(hidden,15.16,{lifecycle:{dead:true,key:'afterhidden20',age:0}},1/60);assert(pose(hidden).head>1,'direct new death after 5s recovery gap cannot resurrect old down pose');hidden.dispose();
 for(const gap of [.001,5]){
  const external=fixture(createAfter);tick(external,10,{stun:{active:true,age:1}});tick(external,10.01,{stun:{active:false,endedAge:0}});tick(external,10.16,{stun:{active:false}});const before=pose(external),atTime=10.16+gap;
  external.syncSourceLifecycle({dead:true,key:'external-gap20',age:0},atTime);assert.equal(external.surface.state.kind,'dead','external lifecycle changes state immediately');tick(external,atTime);
  if(gap>1)assert(pose(external).head>1,'external sync lifecycle uses atTime rather than stale private presentation time');else assert(delta(before,pose(external)).head<.02,'external close death retains current continuity');
  assert(external.saveSurfaceState().surface.reaction.age<1e-8,'external source death age remains authoritative');external.dispose();
 }
 // Repeated interrupt/release cycles must not accumulate a fake age or revive.
 const a=fixture(createAfter);tick(a,10,{stun:{active:true,age:1}});let time=10;
 for(let cycle=0;cycle<5;cycle++){time+=.05;tick(a,time,{stun:{active:false,endedAge:0}});time+=.15;tick(a,time,{stun:{active:false}});const before=pose(a);time+=.001;tick(a,time,{stun:{active:true,age:0}});const d=delta(before,pose(a));assert(d.angle<.02&&d.head<.02,'repeat cycle '+cycle)}
 tick(a,time+5,{stun:{active:false,endedAge:4}});assert(pose(a).head>1,'old release is neutral after observation gap');
 // A new death after that gap must not inherit a stale prone pose.
 tick(a,time+5.001,{lifecycle:{dead:true,key:'aftergap20',age:0}});assert(pose(a).head>1,'no stale continuity resurrection');a.dispose();
 const perfPair=[fixture(createBefore),fixture(createAfter)];
 for(let frame=0;frame<48;frame++)for(const index of frame%2?[1,0]:[0,1]){const actor=perfPair[index],now=20+frame/60,start=performance.now();actor.update(1/60,{time:now,stun:{active:true,age:frame/60}});if(frame>=8)cpu[index?'after':'before'].push(performance.now()-start)}perfPair.forEach(actor=>actor.dispose());
}
const stats=a=>{a.sort((x,y)=>x-y);return{samples:a.length,p50:a[Math.floor(a.length*.5)],p95:a[Math.floor(a.length*.95)]}};
console.log(JSON.stringify({integrated:true,pass:true,results,cpuMs:{before:stats(cpu.before),after:stats(cpu.after)},limits:'Actual male/female production regression; before rollback in memory only. No LIVE, GPU or full-scene performance claim. CPU comparison covers same held source-fall poses.'},null,2));
if(process.argv.includes('--audit'))await import('./test_npc_recovery_audit20.mjs');
