import fs from 'node:fs';import assert from 'node:assert/strict';import {registerHooks} from 'node:module';import {pathToFileURL} from 'node:url';import {performance} from 'node:perf_hooks';
import {clone} from './test_npc_death_offline_setup.mjs';import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';import {createHeroWalker} from './hero_walk.mjs';import {createNpcLocomotionPose} from './npc_locomotion_pose.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const templates={};const report={rigs:[],limits:'CPU actual male/female rigs, constant straight trajectories and warm overlay cost. No LIVE visual/FPS acceptance.'};
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;templates[sex]=source;
 for(const speed of [1.5,2.6,7.8]){
  const running=speed>2.3,a=createNpcActor({THREE:T,scene:new T.Scene(),source,cloneSkeleton:clone,id:sex+speed,sex}),c=a.walker.artistContext(),baseline=createHeroWalker({THREE:T,scene:clone(source)}),bc=baseline.artistContext();
  a.update(0,{moving:true,running,motionSpeed:speed,gaitDistance:0,life:{}});
  const {stride,stance}=a.diagnostics().locomotion;
  const lengths=['l','r'].map(s=>[c.worldPosition('thigh_'+s).distanceTo(c.worldPosition('shin_'+s)),c.worldPosition('shin_'+s).distanceTo(c.worldPosition('foot_'+s))]);
  let previous=null,slip=0,oldSlip=0,count=0,maxSlip=0,maxBoneError=0;const dt=1/120;
  for(let i=0;i<720;i++){
   const position={x:0,y:0,z:i*dt*speed},snapshot={time:i*dt,position,yaw:0,moving:true,running,gaitDistance:dt*speed,motionSpeed:speed,posture:{target:'stand',value:0},life:{}};
   a.update(dt,snapshot);baseline.object.position.set(0,0,position.z);baseline.update(dt,true,running,null,{},snapshot);baseline.object.updateMatrixWorld(true);
   const phase=a.walker.diagnostics().phase,u=((phase/(2*Math.PI)+.25)%1+1)%1,foot=c.worldPosition('foot_l'),oldFoot=bc.worldPosition('foot_l');
   if(i>240&&previous&&u>.07*stance&&u<.93*stance&&previous.u<u){const velocity=foot.distanceTo(previous.foot)/dt;slip+=velocity;maxSlip=Math.max(maxSlip,velocity);oldSlip+=oldFoot.distanceTo(previous.oldFoot)/dt;count++;}
   for(let side=0;side<2;side++){const s=['l','r'][side],now=[c.worldPosition('thigh_'+s).distanceTo(c.worldPosition('shin_'+s)),c.worldPosition('shin_'+s).distanceTo(c.worldPosition('foot_'+s))];for(let j=0;j<2;j++)maxBoneError=Math.max(maxBoneError,Math.abs(now[j]-lengths[side][j]));}
   assert.equal(a.object.position.z,position.z,'pose never moves authoritative root');previous={u,foot,oldFoot};
  }
  const result={sex,speed,running,stride,stepsPerSecond:2*speed/stride,stance,oldMeanFootSpeed:oldSlip/count,meanStanceFootSpeed:slip/count,maxStanceFootSpeed:maxSlip,maxBoneError,stanceSamples:count};report.rigs.push(result);
  assert(count>10);assert(result.meanStanceFootSpeed<.025,JSON.stringify(result));assert(maxBoneError<1e-6,'no bone stretch');
  a.dispose();baseline.dispose();
 }
 const a=createNpcActor({THREE:T,scene:new T.Scene(),source,cloneSkeleton:clone,id:sex+'_priority',sex}),c=a.walker.artistContext();
 // Profession/crouch/death updates must not retain the locomotion pelvis offset.
 for(let i=0;i<120;i++)a.update(1/60,{moving:true,gaitDistance:.025,motionSpeed:1.5,position:{x:0,y:0,z:i*.025},life:{}});
 a.update(1/60,{moving:false,life:{professionAction:{type:'inspect'}}});assert.equal(c.scaled.position.y>=0,true,'profession resets leg overlay');
 a.dispose();
 const w=createHeroWalker({THREE:T,scene:clone(source)}),pose=createNpcLocomotionPose({THREE:T,walker:w}),out={phase:0,gait:0},input={motionSpeed:1.5,gaitDistance:.025,gaitOutput:out};input.gaitRadiansPerMetre=pose.configure({speed:1.5}).radiansPerMetre;const costs=[];
 for(let i=0;i<400;i++){w.update(1/60,true,false,null,{},input);const t=performance.now();pose.apply(1/60,true,out.phase,out.gait);const elapsed=performance.now()-t;if(i>=100)costs.push(elapsed);}
 costs.sort((x,y)=>x-y);report.rigs.push({sex,overlayP50Ms:costs[150],overlayP95Ms:costs[285],estimated50ActorsP95Ms:costs[285]*50});w.dispose();
}
let constructions=0;const counted={...T};for(const key of ['Vector3','Quaternion','Euler'])counted[key]=new Proxy(T[key],{construct(target,args){constructions++;return Reflect.construct(target,args);}});
const batch=Array.from({length:50},(_,i)=>{const w=createHeroWalker({THREE:T,scene:clone(templates[i%2?'female':'male'])}),pose=createNpcLocomotionPose({THREE:counted,walker:w}),out={phase:0,gait:0},input={motionSpeed:1.5,gaitDistance:.025,gaitOutput:out,gaitRadiansPerMetre:pose.configure({speed:1.5}).radiansPerMetre};return{w,pose,out,input};});
const warmConstructions=constructions,baseCosts=[],overlayCosts=[];
for(let i=0;i<130;i++){let t=performance.now();for(const r of batch)r.w.update(1/60,true,false,null,{},r.input);const before=performance.now()-t;t=performance.now();for(const r of batch)r.pose.apply(1/60,true,r.out.phase,r.out.gait);const after=performance.now()-t;if(i>=30){baseCosts.push(before);overlayCosts.push(after);}}
assert.equal(constructions,warmConstructions,'no warmed THREE scratch allocations');
const stats=arr=>{arr.sort((a,b)=>a-b);return{p50Ms:arr[50],p95Ms:arr[95]};};report.batch50={basePose:stats(baseCosts),addedFootPlant:stats(overlayCosts),warmThreeConstructions:constructions-warmConstructions};
for(const r of batch)r.w.dispose();
console.log(JSON.stringify(report,null,2));fs.writeFileSync(new URL('../../../outputs/npc_locomotion_pose_20260919.json',import.meta.url),JSON.stringify(report,null,2));console.log('PASS actual NPC gait: distance phase, planted stance, no limb stretch, preserved roots and profession priority');


