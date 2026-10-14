import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {performance} from 'node:perf_hooks';
import {createHeroWalker} from './hero_walk.mjs';
import {createHeroMotionPoseOrchestrator,createHeroMotionPoseApplicator,createBuildingVerticalNavigationPoseAdapter,createSurfaceMotionAirbornePoseAdapter} from './hero_motion_pose_orchestrator.mjs';
import {sampleHeroLadderMotion} from './hero_ladder_motion_pose.mjs';

const here=path.dirname(fileURLToPath(import.meta.url)),vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c)}});
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js'))),{GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
const rates=[3,5,7,10,15,30,60,144],models=['player_male.8130dfb1f7eb.glb','player_female.298d50e6244a.glb'];
const ladderYaw=.31,ladderNormal={x:-Math.sin(ladderYaw),z:-Math.cos(ladderYaw)};
const ladder={lower:{x:7,y:0,z:-5},upper:{x:7,y:5,z:-5},normal:ladderNormal,right:{x:ladderNormal.z,z:-ladderNormal.x},rungSpacing:.28,width:.8,yaw:ladderYaw};

function maxDistance(a,b){let max=0;for(let i=0;i<a.length;i+=3)max=Math.max(max,Math.hypot(a[i]-b[i],a[i+1]-b[i+1],a[i+2]-b[i+2]));return max}
function advance(orchestrator,hz,duration,inputAt,onFrame=()=>{}){let time=0;while(time<duration-1e-12){const dt=Math.min(1/hz,duration-time),frame=orchestrator.update(dt,inputAt(time,dt));time+=dt;onFrame(frame,dt,time)}return orchestrator.state}

// Pure state contracts first, including cancellation and weapon restoration.
{
 const o=createHeroMotionPoseOrchestrator(),weapon={armed:true,visible:true};
 let f=o.update(1/60,{weapon,traversal:{active:true,kind:'vault',progress:.2,actionId:1,handL:{x:1,y:1,z:1},contacts:{handLVerified:false}}});
 assert.equal(f.mode,'traversal');assert.equal(f.layers.find(x=>x.mode==='traversal').data.handL,null,'unverified hand is stripped');assert.equal(f.weapon.policy,'holster');
 const weight=f.layers[0].weight;f=o.update(0,{weapon,traversal:{active:true,kind:'vault',progress:.2,actionId:1}});assert.equal(f.layers[0].weight,weight,'dt0 keeps transition weight');
 let restored=false;for(let i=0;i<90;i++){f=o.update(1/60,{weapon:{armed:true,visible:false}});if(f.weapon.policy==='restore'){restored=true;assert.equal(f.weapon.restoreVisible,true)}}assert.ok(restored,'ordinary exit restores prior weapon visibility');
 o.update(1/60,{weapon,traversal:{active:true,kind:'mantle',progress:.4,actionId:2}});f=o.update(1/60,{weapon:{armed:true,visible:false},blocked:{vehicle:true}});assert.equal(f.weapon.policy,'external');assert.equal(f.weapon.restoreVisible,null,'vehicle owner controls weapon after cancel');assert.equal(f.layers.length,0);
 o.update(1/60,{weapon,traversal:{active:true,kind:'mantle',progress:.4,actionId:3}});f=o.update(1/60,{weapon:{armed:true,visible:false},blocked:{cover:true}});assert.equal(f.weapon.policy,'restore','cover cancellation restores held weapon for cover owner');
 for(const reason of ['death','blast','water']){o.update(1/60,{traversal:{active:true,kind:'vault',progress:.3,actionId:reason}});f=o.update(1/60,{blocked:{[reason]:true}});assert.equal(f.reason,reason);assert.equal(f.layers.length,0)}
 const ladderInput={active:true,sample:{phaseName:'climb-up',phase:.3,direction:1,blend:1,handL:{x:0,y:1,z:0},handR:{x:0,y:1,z:0},footL:{x:0,y:0,z:0},footR:{x:0,y:0,z:0}},contacts:{handLVerified:true,handRVerified:true}};
 f=o.update(1/60,{ladder:ladderInput,blocked:{water:true,cover:true}});assert.equal(f.mode,'ladder','ladder owns pose over water and cover');
 const staleSurface={active:true,source:'surface',verticalVelocity:-5,airborneAge:1.2,fallDistance:3};
 f=o.update(1/60,{ladder:ladderInput,airborne:staleSurface});assert.equal(f.mode,'ladder','ladder owns pose over stale free-edge observer');
 f=o.update(1/60,{airborne:staleSurface,blocked:{water:true}});assert.equal(f.reason,'water','water owns pose over free-edge observer');
 f=o.update(1/60,{airborne:staleSurface,blocked:{cover:true}});assert.equal(f.reason,'cover','cover owns pose over free-edge observer');
 f=o.update(1/60,{ladder:ladderInput,jump:{active:true}});assert.equal(f.reason,'jump','jump owns pose over ladder');assert.equal(f.layers.length,0);
 f=o.update(1/60,{ladder:ladderInput,airborne:{active:true,verticalVelocity:-4},blocked:{custody:true}});assert.equal(f.reason,'custody');assert.equal(f.layers.length,0);
 f=o.update(1/60,{ladder:ladderInput,blocked:{interaction:true}});assert.equal(f.reason,'interaction');
 const sameFrame=o.update(1/60,{});assert.strictEqual(o.update(0,{}),sameFrame,'update reuses its output frame');
 const dt0=createHeroMotionPoseOrchestrator(),landingInput={airborne:{active:true,landingAge:.3,landingDuration:.34,impactSpeed:8,fallDistance:2}};f=dt0.update(1/60,landingInput);const landingAge=f.layers[0].data.landingAge;dt0.update(0,landingInput);assert.equal(f.layers[0].data.landingAge,landingAge,'landing pose is exact dt0 no-op');
 const ladderDt0={active:true,sample:{phaseName:'climb-up',phase:.2,direction:1,blend:.4,handL:{x:0,y:1,z:0,blend:.4},handR:{x:0,y:1,z:0,blend:.4},footL:{x:0,y:0,z:0},footR:{x:0,y:0,z:0}},contacts:{handLVerified:true,handRVerified:true}};f=dt0.update(1/60,{ladder:ladderDt0});const handBlend=f.layers.find(x=>x.mode==='ladder').data.handL.blend,handY=f.layers.find(x=>x.mode==='ladder').data.handL.y;ladderDt0.sample.handL.blend=1;ladderDt0.sample.handL.y=3;dt0.update(0,{ladder:ladderDt0});assert.equal(f.layers.find(x=>x.mode==='ladder').data.handL.blend,handBlend,'ladder contact blend is exact dt0 no-op');assert.equal(f.layers.find(x=>x.mode==='ladder').data.handL.y,handY,'ladder target is exact dt0 no-op');
 for(const owner of ['death','vehicle','custody']){const gate=createHeroMotionPoseOrchestrator();gate.update(1/60,{traversal:{active:true,kind:'vault',progress:.3}});f=gate.update(0,{blocked:{[owner]:true}});assert.equal(f.reason,owner,owner+' cancels immediately at dt0');assert.equal(f.layers.length,0)}
 {const gate=createHeroMotionPoseOrchestrator();gate.update(1/60,{traversal:{active:true,kind:'vault',progress:.3}});f=gate.update(0,{jump:{active:true}});assert.equal(f.reason,'jump');}
 {const gate=createHeroMotionPoseOrchestrator();gate.update(1/60,{traversal:{active:true,kind:'vault',progress:.3}});f=gate.update(0,{ladder:ladderInput});assert.equal(f.mode,'ladder');assert.equal(f.layers.length,0,'dt0 owner swap never applies stale traversal pose');}
 const adapt=createBuildingVerticalNavigationPoseAdapter(),legacy={active:true,sliding:false,pose:{phase:.4,direction:-1,handBlend:.7,handL:{x:1,y:2,z:3},handR:{x:2,y:2,z:3},footL:{x:1,y:1,z:3},footR:{x:2,y:1,z:3}}},adapted=adapt(legacy,{contactsVerified:true});assert.equal(adapted.sample.phaseName,'climb-down');assert.equal(adapted.sample.handL.blend,.7);assert.ok(adapted.contacts.handLVerified);assert.strictEqual(adapt(legacy),adapted,'vertical navigation adapter reuses output');
}

// Terminal samples and transition weights converge at the same elapsed time,
// including sparse 3/5/7 Hz rendering.
{
 const landingEnds=[],ladderEnds=[];
 for(const hz of rates){let t=0,o=createHeroMotionPoseOrchestrator(),frame;while(t<.34-1e-12){const dt=Math.min(1/hz,.34-t);t+=dt;frame=o.update(dt,{airborne:{active:true,landingAge:t,landingDuration:.34,impactSpeed:8,fallDistance:2}})}const air=frame.layers.find(x=>x.mode==='airborne');landingEnds.push([air.data.progress,air.weight]);
  t=0;o=createHeroMotionPoseOrchestrator();while(t<.5-1e-12){const dt=Math.min(1/hz,.5-t);t+=dt;const sample=sampleHeroLadderMotion(ladder,{x:7,y:2,z:-5},{travelled:t*1.7,direction:-1});frame=o.update(dt,{ladder:{active:true,sample,contacts:{handLVerified:true,handRVerified:true}}})}const layer=frame.layers.find(x=>x.mode==='ladder');ladderEnds.push([layer.data.phase,layer.data.handL.y,layer.weight]);}
 for(const end of landingEnds){assert.equal(end[0],1,'landing reaches terminal pose');assert.ok(Math.abs(end[1]-landingEnds[0][1])<1e-10,'landing weight elapsed-time parity')}
 for(const end of ladderEnds)for(let i=0;i<3;i++)assert.ok(Math.abs(end[i]-ladderEnds[0][i])<1e-10,'ladder terminal parity '+JSON.stringify(ladderEnds));
}

// A surfaceMotion ledge fall has no jump object. The observer must still drive
// fall/long-fall/landing and keep dt=0 stable without owning physics.
for(const armed of [false,true])for(const hz of [3,144]){
 const adapter=createSurfaceMotionAirbornePoseAdapter(),o=createHeroMotionPoseOrchestrator();let y=4.8,velocityY=0,seen=new Set(),last;
 adapter.reset({grounded:true,y});for(let t=0;t<1.15-1e-12;){const dt=Math.min(1/hz,1.15-t);velocityY-=18*dt;y+=velocityY*dt;const airborne=adapter.update(dt,{grounded:false,y,velocityY},{armed}),frame=o.update(dt,{weapon:{armed,visible:true},airborne});seen.add(frame.layers.find(x=>x.mode==='airborne')?.data.phase);t+=dt;last=airborne}
 assert.ok(seen.has('long-fall'),'walk-off ledge reaches long fall at '+hz+'Hz');const before=adapter.state;assert.strictEqual(adapter.update(0,{grounded:false,y,velocityY},{armed}),last);assert.deepEqual(adapter.state,before,'freefall dt0 repeat');
 const landed=adapter.update(1/hz,{grounded:true,y:0,velocityY:0},{armed}),frame=o.update(1/hz,{weapon:{armed,visible:true},airborne:landed});assert.equal(frame.layers.find(x=>x.mode==='airborne').data.phase,'landing');assert.equal(frame.weapon.policy,armed?'holster':'none');
}

const results=[],applyBenchmarks=[];
for(const model of models){
 const bytes=fs.readFileSync(path.join(here,'hero_models',model)),scene=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const hero=createHeroWalker({THREE,scene}),ctx=hero.artistContext(),applicator=createHeroMotionPoseApplicator(THREE,ctx),meshes=[];scene.traverse(node=>{if(node.isSkinnedMesh)meshes.push(node)});
 hero.object.position.set(7,2,-5);hero.object.rotation.y=.31;const root=[7,2,-5],point=new THREE.Vector3(),rest=new Map(Object.entries(ctx.bones).map(([name,bone])=>{const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);return[name,{p,s}]}));
 function snapshot(){hero.object.updateMatrixWorld(true);const inverse=hero.object.matrixWorld.clone().invert(),values=[];for(const mesh of meshes){mesh.skeleton.update();const positions=mesh.geometry.attributes.position;for(let i=0;i<positions.count;i++){point.fromBufferAttribute(positions,i);mesh.applyBoneTransform(i,point);point.applyMatrix4(mesh.matrixWorld).applyMatrix4(inverse);values.push(point.x,point.y,point.z)}}return values}
 function invariants(){assert.deepEqual(hero.object.position.toArray(),root);assert.equal(hero.object.rotation.y,.31);for(const [name,bone]of Object.entries(ctx.bones)){const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);assert.ok(p.distanceTo(rest.get(name).p)<1e-7,name+' translation');assert.ok(s.distanceTo(rest.get(name).s)<1e-6,name+' scale')}}

 // Mixed-owner gates execute against each real GLB. They must select one owner
 // before application, so the legacy ladder solver can never be applied twice.
 {
  const mixed=createHeroMotionPoseOrchestrator(),ladderSample=sampleHeroLadderMotion(ladder,{x:7,y:2,z:-5},{travelled:.3,direction:1}),ladderInput={active:true,sample:ladderSample,contacts:{handLVerified:true,handRVerified:true}};
  hero.update(1/60,true,false,null,{},{});let frame=mixed.update(1/60,{ladder:ladderInput,blocked:{water:true,cover:true}});assert.equal(frame.mode,'ladder');assert.equal(applicator.apply(frame).layerCount,1);invariants();assert.ok(snapshot().every(Number.isFinite));
  hero.update(1/60,true,false,null,{},{});frame=mixed.update(1/60,{ladder:ladderInput,jump:{active:true}});assert.equal(frame.reason,'jump');assert.equal(applicator.apply(frame).layerCount,0);invariants();
  frame=mixed.update(1/60,{ladder:ladderInput,airborne:{active:true,verticalVelocity:-5},blocked:{custody:true}});assert.equal(frame.reason,'custody');assert.equal(applicator.apply(frame).layerCount,0);invariants();
 }

 // Actual male/female skin exercise for ordinary walk-off freefall, with no
 // jump object at either a low or high presentation rate.
 for(const armed of [false,true])for(const hz of [3,144]){
  const observer=createSurfaceMotionAirbornePoseAdapter(),fall=createHeroMotionPoseOrchestrator();let y=4.8,vy=0,previous=null,maxSkinStep=0,sawLong=false;
  observer.reset({grounded:true,y});for(let t=0;t<1.15-1e-12;){const dt=Math.min(1/hz,1.15-t);vy-=18*dt;y+=vy*dt;const airborne=observer.update(dt,{grounded:false,y,velocityY:vy},{armed});hero.update(dt,true,false,armed?{id:'tt_pistol'}:null,{},{});const frame=fall.update(dt,{weapon:{armed,visible:true},airborne});applicator.apply(frame);const skin=snapshot();if(previous)maxSkinStep=Math.max(maxSkinStep,maxDistance(previous,skin));previous=skin;sawLong ||= frame.layers.some(x=>x.mode==='airborne'&&x.data.phase==='long-fall');invariants();t+=dt}
  const airborne=observer.update(1/hz,{grounded:true,y:0,velocityY:0},{armed});hero.update(1/hz,true,false,armed?{id:'tt_pistol'}:null,{},{});const frame=fall.update(1/hz,{weapon:{armed,visible:true},airborne});applicator.apply(frame);const skin=snapshot();maxSkinStep=Math.max(maxSkinStep,maxDistance(previous,skin));assert.ok(sawLong);assert.equal(frame.layers.find(x=>x.mode==='airborne').data.phase,'landing');assert.ok(maxSkinStep<.25+7/hz,`${model} freefall skin delta ${maxSkinStep} at ${hz}Hz`);invariants();
 }
 const fpsEnds=[],fpsMaxSteps=[];
 for(const hz of rates){
  const o=createHeroMotionPoseOrchestrator();let phase=0,previous=null,maxStep=0,maxMode=null,seen=new Set(),lead=null;
  const run=(duration,builder)=>advance(o,hz,duration,(time,dt)=>builder(time,dt,phase),(frame,dt)=>{phase+=dt*6;hero.update(dt,true,false,null,{},{});applicator.apply(frame);invariants();const skin=snapshot();if(previous){const step=maxDistance(previous,skin);if(step>maxStep){maxStep=step;maxMode={mode:frame.mode,layers:frame.layers.map(x=>[x.mode,x.weight,x.data?.phase,x.data?.progress]),phase}}}previous=skin;seen.add(frame.mode)});
  run(.2,()=>({slope:{grade:0,gaitPhase:phase,gaitWeight:1}}));
  run(.4,()=>({slope:{grade:.9,gaitPhase:phase,gaitWeight:1}}));
  run(.2,time=>({slope:{grade:.9,gaitPhase:phase,gaitWeight:1},autoStep:{active:true,progress:time/.2,obstacleHeight:.25,actionId:'curb'}}));lead=o.state.leadFoot;
  run(.35,time=>({traversal:{active:true,kind:'vault',progress:time/.35,obstacleHeight:.62,direction:{x:0,z:1},edge:{x:7,y:2.62,z:-4.6},start:{x:7,y:2,z:-5},actionId:'hood',contacts:{handLVerified:false,handRVerified:false}}}));
  run(.25,time=>({airborne:{active:true,verticalVelocity:-3-time*8,airborneAge:.55+time,fallDistance:.5+time*2.5}}));
  run(.34,time=>({airborne:{active:true,verticalVelocity:0,airborneAge:.8,fallDistance:1.3,landingAge:time,landingDuration:.34,impactSpeed:7}}));
  run(.3,()=>({slope:{grade:.86,gaitPhase:phase,gaitWeight:1}}));
  run(.5,time=>{const sample=sampleHeroLadderMotion(ladder,{x:7,y:2,z:-5},{travelled:time*1.7,direction:-1,sliding:false,mountProgress:Math.min(1,time/.2),dismountProgress:Math.max(0,(time-.25)/.25)});return {ladder:{active:true,sample,contacts:{handLVerified:true,handRVerified:true}}}});
  run(.4,()=>({slope:{grade:-.86,gaitPhase:phase,gaitWeight:1}}));
  assert.ok(['l','r'].includes(lead));assert.ok(seen.has('slope')&&seen.has('auto-step')&&seen.has('traversal')&&seen.has('airborne')&&seen.has('ladder'));
  fpsEnds.push(o.state);fpsMaxSteps.push({maxStep,maxMode});
 }
 const reference=fpsEnds[0];for(const state of fpsEnds.slice(1)){assert.equal(state.mode,reference.mode);assert.ok(Math.abs(state.filteredSlopeGrade-reference.filteredSlopeGrade)<1e-10,'fps slope state parity');const referenceSlope=reference.layers.find(x=>x.mode==='slope'),otherSlope=state.layers.find(x=>x.mode==='slope');assert.ok(otherSlope&&Math.abs(otherSlope.weight-referenceSlope.weight)<1e-10,'active slope layer fps parity');for(const layer of state.layers)if(layer.mode!=='slope')assert.ok(layer.weight<.04,'bounded residual '+layer.mode+' '+layer.weight)}
 for(let i=0;i<rates.length;i++)assert.ok(fpsMaxSteps[i].maxStep<.75,`bounded cross-mode skin step at ${rates[i]}Hz `+JSON.stringify(fpsMaxSteps[i]));

 // Rapid alternating slopes keep one slope layer and smooth its signed grade.
 const alternating=[];for(const hz of rates){const o=createHeroMotionPoseOrchestrator();for(let segment=0;segment<12;segment++)advance(o,hz,.08,()=>({slope:{grade:segment%2?.92:-.92,gaitPhase:segment,gaitWeight:1}}));alternating.push(o.state.filteredSlopeGrade);assert.equal(o.state.layers.filter(x=>x.mode==='slope').length,1)}
 assert.ok(Math.max(...alternating)-Math.min(...alternating)<1e-10,'rapid slope fps parity '+alternating);

 // Lead foot is stable through one action and alternates only after exit.
 const leadTest=createHeroMotionPoseOrchestrator();let frame=leadTest.update(.05,{autoStep:{active:true,progress:.1,actionId:'a',leadSide:'r'}});const first=frame.leadFoot;frame=leadTest.update(.05,{autoStep:{active:true,progress:.8,actionId:'a',leadSide:'l'}});assert.equal(frame.leadFoot,first);leadTest.update(.2,{});frame=leadTest.update(.05,{autoStep:{active:true,progress:.1,actionId:'b'}});assert.notEqual(frame.leadFoot,first);
 // Warmed actual artistContext loop. Heap delta includes the existing
 // hero.update/artistContext implementation; our applicator and state outputs
 // are identity-stable, so this exposes the remaining host-side allocation.
 const benchOrchestrator=createHeroMotionPoseOrchestrator(),benchSample=sampleHeroLadderMotion(ladder,{x:7,y:2,z:-5},{travelled:.84,direction:1}),benchInput={ladder:{active:true,sample:benchSample,contacts:{handLVerified:true,handRVerified:true}}};let applyIdentity=null;
 for(let i=0;i<250;i++){hero.update(1/60,true,false,null,{},{});const applied=applicator.apply(benchOrchestrator.update(1/60,benchInput));if(!applyIdentity)applyIdentity=applied;else assert.strictEqual(applied,applyIdentity,'applicator reuses result object')}
 const heapBefore=process.memoryUsage().heapUsed,applyStart=performance.now(),applyIterations=1000;for(let i=0;i<applyIterations;i++){hero.update(1/60,true,false,null,{},{});applicator.apply(benchOrchestrator.update(1/60,benchInput))}const applyMs=performance.now()-applyStart,heapDelta=process.memoryUsage().heapUsed-heapBefore;assert.ok(Number.isFinite(applyMs)&&Math.abs(heapDelta)<32*1024*1024,'bounded warmed apply heap');applyBenchmarks.push({model,applyIterations,applyMs,heapDelta});
 hero.dispose();results.push({model,fpsMaxSteps,finalFilteredGrades:fpsEnds.map(x=>x.filteredSlopeGrade),alternating});
}

let sink=0;const iterations=100000,o=createHeroMotionPoseOrchestrator(),start=performance.now();for(let i=0;i<iterations;i++){const frame=o.update(1/60,i%19<3?{traversal:{active:true,kind:i%2?'vault':'mantle',progress:(i%19)/3,actionId:i}}:{slope:{grade:(i%200-100)/100,gaitPhase:i*.1,gaitWeight:1}});sink+=frame.layers.length+frame.filteredSlopeGrade}const stateMs=performance.now()-start;assert.ok(Number.isFinite(sink));
console.log(JSON.stringify({passed:true,rates,models:results,stateMs,iterations,applyBenchmarks,priority:['death','blast','vehicle','custody','interaction','jump','traversal','explicit-airborne','ladder','water','cover','surface-airborne','auto-step','slope','walk'],checks:['crossfade_actual_skin_under_0.75m','rapid_alternating_slope','abort_traversal_to_airborne','ladder_exit_to_slope','fall_landing_to_incline','freeedge_fall_without_jump','mixed_ladder_water_cover','jump_ladder_and_custody','lead_foot_continuity','verified_hands_only','weapon_restore_and_external_cancel','3_5_7_10_15_30_60_144fps','elapsed_time_terminal_parity','dt0_state_freeze_and_owner_cancel','root_yaw_bone_invariants','pooled_orchestrator_applicator_outputs','warmed_actual_apply_cpu_heap','state_cpu']}));
