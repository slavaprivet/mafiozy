// Production regression. Only the historical baseline is reconstructed in memory.
// Source-adapter scenarios execute the actual mercenary_world.js in a bounded VM.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import * as production from './assets/maps/city_rebuild_v1/mercenary_core.mjs';

const root=new URL('./assets/maps/city_rebuild_v1/',import.meta.url);
const coreUrl=new URL('mercenary_core.mjs',root),coreBytes=fs.readFileSync(coreUrl),source=coreBytes.toString('utf8').replaceAll('\r\n','\n');
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const anchor=`      if(a.phase==='approach'){a.phase='working';a.phaseStartedAt=time;moveMember(a.memberId,null,{phase:'stop',stopDistance:0});}
      a.progress=Math.min(1,(time-a.phaseStartedAt)/a.duration);
      if(a.progress<1){publish(a);continue;}
      if(a.kind==='plant_bomb'){a.armed=true;a.armedAt=time;a.detonateAt=time+balance.bombFuse;a.phaseStartedAt=time;a.phase='retreat';a.progress=0;publish(a);continue;}
      const ok=apply(a,t);if(ok!==null)finish(a,ok?'completed':'effect_rejected',ok);`;
const replacement=`      if(a.phase==='approach'){a.phase='working';a.phaseStartedAt=time;if(a.kind!=='intimidate')moveMember(a.memberId,null,{phase:'stop',stopDistance:0});}
      // Intimidation keeps ordinary physical locomotion while its target walks.
      // Work still requires the existing full 3D range check on every update.
      if(a.kind==='intimidate'){
        const heightDelta=(m.position.y||0)-(t.position.y||0),horizontalRange=Math.sqrt(Math.max(0,a.range*a.range-heightDelta*heightDelta));
        moveMember(a.memberId,t,{phase:'approach',stopDistance:horizontalRange*.6});
      }
      a.progress=Math.min(1,(time-a.phaseStartedAt)/a.duration);
      if(a.progress<1){publish(a);continue;}
      if(a.kind==='plant_bomb'){a.armed=true;a.armedAt=time;a.detonateAt=time+balance.bombFuse;a.phaseStartedAt=time;a.phase='retreat';a.progress=0;publish(a);continue;}
      if(a.kind==='intimidate')moveMember(a.memberId,null,{phase:'stop',stopDistance:0});
      const ok=apply(a,t);if(ok!==null)finish(a,ok?'completed':'effect_rejected',ok);`;
assert.equal(source.split(replacement).length,2,'Production moving-contact fix missing or changed; review baseline reconstruction');
const moduleText=source.replace(replacement,anchor).replace(/from '(\.\/[^']+)'/g,(_,path)=>`from '${new URL(path,root).href}'`);
const baseline=await import('data:text/javascript;base64,'+Buffer.from(moduleText).toString('base64'));
const reports=[];
const distance=(m,t)=>Math.hypot(m.position.x-t.position.x,m.position.y-t.position.y,m.position.z-t.position.z);

function fixture(module,{fps=60,kind='intimidate',blocked=false,effect=true,initialDistance=1.8}={}){
 let time=0,goal=null,targetAvailable=true,memberAvailable=true;
 const m={id:'operator',hp:100,available:true,position:{x:0,y:0,z:0}},target={id:'target',kind:kind==='plant_bomb'?'vehicle':'npc',valid:true,hp:100,position:{x:initialDistance,y:0,z:0}};
 const calls=[],moves=[],phases=[],trajectory=[],allowed=()=>typeof blocked==='function'?blocked(time):blocked;
 const squad=module.createMercenarySquad({now:()=>time,getMember:()=>memberAvailable?m:null,getTarget:()=>targetAvailable?target:null,
  moveMember(id,t,options){goal=t?{position:{...t.position},options:{...options}}:null;moves.push({time,target:goal?.position||null,...options});},
  performEffect(event){if(event.kind!==kind)return false;calls.push({time,kind:event.kind,distance:distance(m,target),id:event.actionId,targetPosition:{...target.position}});return typeof effect==='function'?effect(event):effect;},
  onAction(id,a){phases.push({time,...a});}
 });
 assert(squad.recruit({id:m.id,profession:kind==='plant_bomb'?'demolitions':'bruiser'}).ok);
 assert(squad.command(m.id,kind,target.id).ok);
 function tick(velocity=0,dt=1/fps){
  time+=dt;target.position.x+=velocity*dt;if(kind==='plant_bomb')target.speed=velocity;
  const targetBefore=JSON.stringify(target),memberBefore={...m.position};
  squad.update();assert.equal(JSON.stringify(target),targetBefore,'core must not freeze, teleport or mutate target');
  m.approachMoving=false;
  if(goal&&!allowed()){
   const dx=goal.position.x-m.position.x,dz=goal.position.z-m.position.z,d=Math.hypot(dx,dz),step=Math.min(Math.max(0,d-goal.options.stopDistance),3*dt);
   if(step>0){m.position.x+=dx/d*step;m.position.z+=dz/d*step;m.approachMoving=true;}
  }
  assert(Math.hypot(m.position.x-memberBefore.x,m.position.z-memberBefore.z)<=3*dt+1e-9,'movement must obey physical speed');
  trajectory.push({time,phase:squad.getAction(m.id)?.phase||null,position:{...m.position},progress:squad.getAction(m.id)?.progress??null,armed:squad.getAction(m.id)?.armed??false,goal:goal&&{position:goal.position,options:goal.options}});
 }
 function run(seconds,velocity=0){for(let i=0;i<Math.ceil(seconds*fps);i++)tick(velocity);}
 return {m,target,squad,calls,moves,phases,trajectory,tick,run,get time(){return time},get goal(){return goal},setTargetAvailable:v=>targetAvailable=v,setMemberAvailable:v=>memberAvailable=v};
}

for(const fps of [7,15,60]){
 test(`historical actual core reproduces walking target reset and timeout at ${fps} FPS`,()=>{
  const f=fixture(baseline,{fps});f.run(42,1.2);
  const work=f.phases.filter(p=>p.phase==='working'),resets=f.phases.filter((p,i)=>p.phase==='approach'&&f.phases[i-1]?.phase==='working');
  assert.equal(f.calls.length,0);assert(work.length>5);assert(resets.length>5);
  assert.equal(f.phases.at(-1).reason,'path_timeout');assert.equal(f.squad.getAction(f.m.id),null);
  reports.push({mode:'actual-core-before',fps,effects:0,resets:resets.length,maxProgress:Math.max(...work.map(p=>p.progress)),end:f.phases.at(-1).time});
 });
 test(`production completes stationary and walking contact once at ${fps} FPS`,()=>{
  for(const speed of [0,1.2,2.1]){
   const f=fixture(production,{fps});f.run(4,speed);
   assert.equal(f.calls.length,1,`speed ${speed}`);assert(f.calls[0].distance<=2+1e-9);assert(f.calls[0].time>=2.5);
   assert.equal(f.squad.getRecord(f.m.id).xp,25);assert.equal(f.squad.getAction(f.m.id),null);assert.equal(f.goal,null);
   assert.equal(f.phases.filter(p=>p.phase==='cancelled').length,0);
   reports.push({mode:'production-core',fps,speed,effects:1,at:f.calls[0].time,distance:f.calls[0].distance});
  }
 });
 test(`faster fleeing target cannot receive remote intimidation at ${fps} FPS`,()=>{
  const f=fixture(production,{fps});f.run(42,4.4);
  assert.equal(f.calls.length,0);assert.equal(f.phases.at(-1).reason,'path_timeout');assert.equal(f.squad.getAction(f.m.id),null);
 });
 test(`lost range and vertical separation restart continuous work at ${fps} FPS`,()=>{
  for(const axis of ['x','y']){
   const f=fixture(production,{fps});f.run(.8,0);assert(f.squad.getAction(f.m.id).progress>0);
   f.target.position[axis]+=20;f.tick();assert.equal(f.squad.getAction(f.m.id).phase,'approach');assert.equal(f.squad.getAction(f.m.id).progress,0);assert.equal(f.calls.length,0);
   f.target.position={x:f.m.position.x+1.4,y:0,z:f.m.position.z};f.tick();const restart=f.time;
   f.run(2);assert.equal(f.calls.length,0);f.run(1);assert.equal(f.calls.length,1);assert(f.calls[0].time-restart>=2.5-1e-9);
  }
 });
 test(`cancel, injury, death and invalidation prevent later effects at ${fps} FPS`,()=>{
  const cases=[['cancelled',f=>f.squad.cancel(f.m.id)],['damaged',f=>f.m.hp--],['member_unavailable',f=>f.m.dead=true],['member_unavailable',f=>f.m.downed=true],['member_unavailable',f=>f.m.available=false],['member_unavailable',f=>f.setMemberAvailable(false)],['target_invalid',f=>f.target.dead=true],['target_invalid',f=>f.target.valid=false],['target_invalid',f=>f.target.intimidatable=false],['target_invalid',f=>f.setTargetAvailable(false)]];
  for(const [reason,mutate]of cases){const f=fixture(production,{fps});f.run(.8,1.2);mutate(f);f.run(5,1.2);assert.equal(f.calls.length,0,reason);assert.equal(f.phases.at(-1).reason,reason);assert.equal(f.goal,null);}
 });
 test(`blocked pursuit cannot grant an effect or wait forever at ${fps} FPS`,()=>{
  const f=fixture(production,{fps,blocked:true,initialDistance:2.5});f.run(12);
  assert.equal(f.calls.length,0);assert.equal(f.phases.at(-1).reason,'path_timeout');assert(f.phases.at(-1).time<11);
  const lost=fixture(production,{fps,blocked:t=>t>.4});lost.run(12,1.2);assert.equal(lost.calls.length,0);assert.equal(lost.phases.at(-1).reason,'path_timeout');
 });
 test(`moving vehicle planting trace is unchanged at ${fps} FPS`,()=>{
  const traces=[];
  for(const module of [baseline,production]){
   const f=fixture(module,{fps,kind:'plant_bomb'});f.run(8,2);assert.equal(f.calls.length,0);assert(!f.squad.getAction(f.m.id).armed);
   f.run(4);assert.equal(f.calls.length,0);assert(!f.squad.getAction(f.m.id).armed,'must complete a full stationary work interval');
   f.run(9);assert.equal(f.calls.length,1);assert(f.calls[0].distance>=8);f.run(5);assert.equal(f.calls.length,1);
   traces.push({moves:f.moves,phases:f.phases,trajectory:f.trajectory,calls:f.calls,snapshot:f.squad.snapshot()});
  }
  assert.deepEqual(traces[1],traces[0],'production fix must not alter moving C4 approach/arming/retreat/once-only effect');
 });
}

test('effect rejection and pending authority keep once-only behavior and release physical movement',async()=>{
 const rejected=fixture(production,{effect:false});rejected.run(4,1.2);assert.equal(rejected.calls.length,1);assert.equal(rejected.phases.at(-1).reason,'effect_rejected');assert.equal(rejected.squad.getRecord(rejected.m.id).xp,0);assert.equal(rejected.goal,null);
 let resolve;const pending=fixture(production,{effect:()=>new Promise(r=>resolve=r)});pending.run(3,1.2);
 assert.equal(pending.calls.length,1);assert.equal(pending.squad.getAction(pending.m.id).phase,'awaiting');assert.equal(pending.goal,null);assert.equal(pending.squad.cancel(pending.m.id).reason,'effect_pending');
 pending.target.position.x+=50;pending.run(5,5);assert.equal(pending.calls.length,1);resolve({ok:true});await Promise.resolve();await Promise.resolve();
 assert.equal(pending.squad.getAction(pending.m.id),null);assert.equal(pending.squad.getRecord(pending.m.id).xp,25);
});

// Reuse the existing bounded source fixture, not a handwritten movement adapter.
const worldSource=fs.readFileSync(new URL('mercenary_world.js',root),'utf8'),fixtureSource=fs.readFileSync(new URL('test_mercenary_rally_actions.mjs',root),'utf8');
const fixtureStart=fixtureSource.indexOf('async function fixture('),fixtureEnd=fixtureSource.indexOf('\nfor(const [profession',fixtureStart);
assert(fixtureStart>=0&&fixtureEnd>fixtureStart);
const importAnchor="import(new URL('./mercenary_core.mjs',scriptUrl).href)";
assert.equal(worldSource.split(importAnchor).length,2);
async function actualWorld(module,fps){
 const script=worldSource.replace(importAnchor,'Promise.resolve(module)');
 const make=Function('vm','module','script','assert',fixtureSource.slice(fixtureStart,fixtureEnd)+';return fixture;')(vm,module,script,assert);
 const f=await make(),m=f.recruit('bruiser'),target=f.ctx.NPCS.find(n=>n.hp>0&&!n.dead),hits=[];
 assert(target);target.r=m.r;target.c=m.c+1.8/4.1;target.speed=1.2/4.1;
 f.api.bindTargets({canMove:()=>true});
 f.ctx._npcApplyIntimidation=(n,r,c,t)=>{hits.push({r,c,t,distance:Math.hypot(n.r-r,n.c-c)*4.1});return true;};
 assert(f.api.command('intimidate',f.api.getTarget(target.id)).ok);
 const observations=[];
 for(let i=0;i<Math.ceil(5*fps);i++){
  target.c+=1.2/fps/4.1;const original={r:target.r,c:target.c,speed:target.speed};f.tick(1/fps);
  assert.deepEqual({r:target.r,c:target.c,speed:target.speed},original,'actual source adapter cannot freeze or teleport target');
  observations.push({phase:f.api.getAction(m.id)?.phase,progress:f.api.getAction(m.id)?.progress,memberX:m.c*4.1,reason:m._mercenaryMoveReason});
 }
 return {hits,observations,action:f.api.getAction(m.id)};
}
for(const fps of [7,15,60])test(`actual mercenary_world movement adapter sustains walking contact at ${fps} FPS`,async()=>{
 const before=await actualWorld(baseline,fps),after=await actualWorld(production,fps);
 assert.equal(before.hits.length,0);assert.equal(after.hits.length,1);assert(after.hits[0].distance<=2);assert.equal(after.action,null);
 assert(after.observations.some(o=>o.phase==='working'&&['moving','route_moving'].includes(o.reason)),'working phase uses ordinary route movement');
 reports.push({mode:'actual-world-adapter',fps,beforeEffects:0,afterEffects:1,contactDistance:after.hits[0].distance});
});

test('actual male/female intimidation preserves moving thighs and stationary authored pose',async()=>{
 const vendor=process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor',threeUrl=pathToFileURL(vendor+'/build/three.module.js').href;
 registerHooks({resolve(s,c,next){return next(s==='three'?threeUrl:s,c)}});
 const THREE=await import(threeUrl),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
 const {clone}=await import('./assets/maps/city_rebuild_v1/test_npc_death_offline_setup.mjs');
 const {createHeroWalker}=await import('./assets/maps/city_rebuild_v1/hero_walk.mjs');
 const {createNpcActor,NPC_ASSETS}=await import('./assets/maps/city_rebuild_v1/npc_actor.mjs');
 const {createMercenaryPose}=await import('./assets/maps/city_rebuild_v1/mercenary_pose.mjs');
 const poseText=fs.readFileSync(new URL('mercenary_pose.mjs',root),'utf8').replaceAll('\r\n','\n');
 const fixedThigh=`   if(moving){spreadWalkingThigh('thigh_l',-.12*weight);spreadWalkingThigh('thigh_r',.12*weight);}
   else{r('thigh_l',0,0,-.12);r('thigh_r',0,0,.12);}
   r('chest',-.06,Math.sin(t*2)*.04);`;
 assert.equal(poseText.split(fixedThigh).length,2,'Production gait fix absent; historical baseline cannot be reconstructed');
 const {createMercenaryPose:createHistoricalPose}=await import('data:text/javascript;base64,'+Buffer.from(poseText.replace(fixedThigh,"   r('thigh_l',0,0,-.12);r('thigh_r',0,0,.12);r('chest',-.06,Math.sin(t*2)*.04);")).toString('base64'));
 const signature=w=>Object.values(w.artistContext().bones).flatMap(b=>b.matrix.elements);
 const span=rows=>Math.max(...Array.from({length:16},(_,i)=>Math.max(...rows.map(r=>r[i]))-Math.min(...rows.map(r=>r[i]))));
 for(const sex of ['male','female']){
  const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),model=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
  const a=createHeroWalker({THREE,scene:clone(model)}),b=createHeroWalker({THREE,scene:clone(model)}),ca=a.artistContext(),cb=b.artistContext(),after=createMercenaryPose({THREE,walker:a}),before=createHistoricalPose({THREE,walker:b});
  const action={kind:'intimidate',phase:'working',progress:.4};
  for(const progress of [.02,.4,.97]){
   a.update(.05,false);b.update(.05,false);after.apply({...action,progress},1,false);before.apply({...action,progress},1,false);
   assert.deepEqual(signature(a),signature(b),'stationary silhouette must remain exact');assert.deepEqual(ca.visualPivot.position.toArray(),cb.visualPivot.position.toArray());
  }
  const oldThigh=[],newThigh=[],untouchedThigh=[],expectedP=new THREE.Vector3(),expectedQ=new THREE.Quaternion(),expectedS=new THREE.Vector3(),spreadQ=new THREE.Quaternion(),axis=new THREE.Vector3(0,0,1),expectedMatrix=new THREE.Matrix4();
  for(let i=0;i<80;i++){
   const p={gaitDistance:.06,motionSpeed:1.2};a.update(.05,true,false,null,{},p);b.update(.05,true,false,null,{},p);
   const beforeMatrices=Object.fromEntries(['thigh_l','thigh_r','shin_l','shin_r','foot_l','foot_r'].map(n=>[n,ca.bones[n].matrix.clone()]));untouchedThigh.push(beforeMatrices.thigh_l.elements.slice());
   after.apply(action,i*.05,true);before.apply(action,i*.05,true);
   for(const [name,sign]of [['thigh_l',-1],['thigh_r',1]]){
    beforeMatrices[name].decompose(expectedP,expectedQ,expectedS);expectedQ.multiply(spreadQ.setFromAxisAngle(axis,sign*.12));expectedMatrix.compose(expectedP,expectedQ,expectedS);
    assert(Math.max(...expectedMatrix.elements.map((v,j)=>Math.abs(v-ca.bones[name].matrix.elements[j])))<1e-12,'walking thigh keeps authored gait plus relative spread');
   }
   for(const name of ['shin_l','shin_r','foot_l','foot_r'])assert.deepEqual(ca.bones[name].matrix.elements,beforeMatrices[name].elements,'lower gait joint untouched');
   oldThigh.push(cb.bones.thigh_l.matrix.elements.slice());newThigh.push(ca.bones.thigh_l.matrix.elements.slice());
  }
  assert(span(untouchedThigh)>.5);assert.equal(span(oldThigh),0,'historical gesture erased thigh motion');assert(span(newThigh)>.5);
  for(const kind of ['revive','unlock_safe','unlock_door','cut_fence','plant_bomb','disable_power','breach_door']){
   a.update(.05,true);b.update(.05,true);const other={kind,phase:'working',progress:.4};after.apply(other,3,true);before.apply(other,3,true);assert.deepEqual(signature(a),signature(b),kind+' unaffected');
  }
  // Actual actor proves the moving argument reaches the real overlay call.
  const actor=createNpcActor({THREE,scene:new THREE.Scene(),source:model,cloneSkeleton:clone,id:'moving-intimidation-'+sex,sex}),actorThigh=[];
  for(let i=0;i<80;i++){
   actor.update(.05,{time:i*.05,position:{x:i*.06,y:0,z:0},yaw:0,moving:true,motionSpeed:1.2,gaitDistance:.06,posture:{target:'stand',value:0},life:{mercenary:{profession:'bruiser',status:'active'},mercenaryAction:action}});
   actorThigh.push(actor.walker.artistContext().bones.thigh_l.matrix.elements.slice());
  }
  assert(span(actorThigh)>.5,'actual npc_actor must forward movement instead of freezing thighs');
  const costs={before:[],after:[]};for(let i=0;i<400;i++)for(const key of i%2?['after','before']:['before','after']){const w=key==='after'?a:b,pose=key==='after'?after:before;w.update(.016,true);const t=performance.now();pose.apply(action,i/60,true);if(i>=100)costs[key].push(performance.now()-t);}for(const list of Object.values(costs))list.sort((x,y)=>x-y);
  const percentiles=list=>({p50Ms:list[Math.floor(list.length*.5)],p95Ms:list[Math.floor(list.length*.95)]});
  reports.push({mode:'actual-gait',sex,frames:80,authoredThighSpan:span(untouchedThigh),historicalThighSpan:span(oldThigh),productionThighSpan:span(newThigh),actorThighSpan:span(actorThigh),stationaryExact:true,poseOnlyCost:{before:percentiles(costs.before),after:percentiles(costs.after)}});
  actor.dispose();after.dispose();before.dispose();a.dispose();b.dispose();
 }
});

test('regression did not edit production and prints bounded evidence',()=>{
 assert.equal(sha(fs.readFileSync(coreUrl)),sha(coreBytes));
 console.log(JSON.stringify({scope:'production core and actual source adapter; inverse historical baseline only; no browser or loaded FPS proof',coreSha256:sha(coreBytes),reports},null,2));
});
