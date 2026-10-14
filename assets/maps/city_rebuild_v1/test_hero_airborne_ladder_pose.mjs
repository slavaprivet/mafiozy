import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {performance} from 'node:perf_hooks';
import {sampleHeroAirborneMotion,applyHeroAirborneMotionPose} from './hero_airborne_motion_pose.mjs';
import {sampleHeroLadderMotion,applyHeroLadderMotionPose} from './hero_ladder_motion_pose.mjs';
import {sampleHeroObstacleMotion,applyHeroObstacleMotionPose} from './hero_obstacle_motion_pose.mjs';
import {createHeroWalker} from './hero_walk.mjs';
import {ARSENAL,createWeaponModel} from './hero_arsenal.mjs';

const here=path.dirname(fileURLToPath(import.meta.url));
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c)}});
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
const {GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));

const models=['player_male.8130dfb1f7eb.glb','player_female.298d50e6244a.glb'];
const rates=[10,30,60,144],results=[];
const ladder=Object.freeze({
  id:'pose-test',lower:{x:4,y:0,z:-2},upper:{x:4,y:5,z:-2},normal:{x:0,z:1},right:{x:1,z:0},
  rungSpacing:.28,width:.8,yaw:Math.PI,
});

function maxDistance(a,b){let max=0;assert.equal(a.length,b.length);for(let i=0;i<a.length;i+=3)max=Math.max(max,Math.hypot(a[i]-b[i],a[i+1]-b[i+1],a[i+2]-b[i+2]));return max}

for(const model of models){
  const bytes=fs.readFileSync(path.join(here,'hero_models',model));
  const scene=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
  const hero=createHeroWalker({THREE,scene}),context=hero.artistContext(),meshes=[];
  scene.traverse(node=>{if(node.isSkinnedMesh)meshes.push(node)});assert.ok(meshes.length,model+' actual skinned GLB');
  hero.object.position.set(4,3,-2);hero.object.rotation.y=Math.PI;
  const rest=new Map(Object.entries(context.bones).map(([name,bone])=>{const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);return [name,{p,s}]}));
  const point=new THREE.Vector3();let snapshots=0,maxStep=0,minLandingY=Infinity;
  function snapshot(){
    hero.object.updateMatrixWorld(true);const inverse=hero.object.matrixWorld.clone().invert(),values=[];
    for(const mesh of meshes){mesh.skeleton.update();const positions=mesh.geometry.attributes.position;for(let i=0;i<positions.count;i++){point.fromBufferAttribute(positions,i);mesh.applyBoneTransform(i,point);point.applyMatrix4(mesh.matrixWorld).applyMatrix4(inverse);values.push(point.x,point.y,point.z)}}
    snapshots++;return values;
  }
  function invariants(root=[4,3,-2]){
    assert.deepEqual(hero.object.position.toArray(),root,model+' presentation preserves root');assert.equal(hero.object.rotation.y,Math.PI,model+' presentation preserves yaw');
    for(const [name,bone]of Object.entries(context.bones)){const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);assert.ok(p.distanceTo(rest.get(name).p)<1e-7,name+' local translation');assert.ok(s.distanceTo(rest.get(name).s)<1e-6,name+' local scale')}
  }

  const direct=[
    {verticalVelocity:6,airborneAge:.05,fallDistance:0},
    {verticalVelocity:0,airborneAge:.6,fallDistance:0},
    {verticalVelocity:-4,airborneAge:.65,fallDistance:1.1},
    {verticalVelocity:-10,airborneAge:1.2,fallDistance:4},
    {verticalVelocity:0,airborneAge:1.25,fallDistance:4,landingAge:.12,impactSpeed:10},
  ];
  assert.deepEqual(direct.map(sampleHeroAirborneMotion).map(s=>s.phase),['ascent','apex','fall','long-fall','landing']);
  for(const armed of [false,true])for(const input of direct){
    const sample=sampleHeroAirborneMotion({...input,armed});hero.reset();assert.equal(applyHeroAirborneMotionPose(THREE,context,sample),true);invariants();
    const first=snapshot();hero.reset();applyHeroAirborneMotionPose(THREE,context,sample);const repeat=snapshot();assert.ok(maxDistance(first,repeat)<1e-9,'dt=0 repeat is deterministic');
    assert.equal(sample.weaponPolicy,armed?'holster':'none');
  }

  const obstacleRest=(()=>{hero.reset();return snapshot()})();
  for(const kind of ['auto-step','vault','mantle'])for(const armed of [false,true]){
    let peak=0,previous=obstacleRest;
    for(let i=0;i<=60;i++){
      const progress=i/60,direction={x:0,z:-1},edge={x:4,y:3+(kind==='auto-step'?.22:kind==='vault'?.62:1.08),z:-2.42};
      const sample=sampleHeroObstacleMotion({kind,progress,obstacleHeight:edge.y-3,direction,edge,start:{x:4,y:3,z:-2},leadSide:'r',armed});
      hero.reset();applyHeroObstacleMotionPose(THREE,context,sample);const skin=snapshot();invariants();peak=Math.max(peak,maxDistance(obstacleRest,skin));
      assert.ok(maxDistance(previous,skin)<.19,kind+' pose continuity');previous=skin;
      assert.equal(sample.weaponPolicy,kind==='auto-step'?'carry-safe':'holster');
    }
    assert.ok(peak>(kind==='auto-step'?.08:.2),kind+' visibly articulates '+model);
  }
  const pistolSpec=ARSENAL.find(spec=>spec.id==='tt_pistol'),pistol=createWeaponModel({THREE,id:pistolSpec.id});hero.mountWeapon(pistol);
  hero.update(0,false,false,pistolSpec,{aimYaw:Math.PI,aimPitch:-.1});
  const stepArmed=sampleHeroObstacleMotion({kind:'auto-step',progress:.42,obstacleHeight:.24,leadSide:'r',armed:true});
  applyHeroObstacleMotionPose(THREE,context,stepArmed);hero.object.updateMatrixWorld(true);
  const grip=new THREE.Vector3(0,-.13,-.02).applyMatrix4(pistol.matrixWorld);
  assert.ok(grip.distanceTo(context.worldPosition('socket_hand_r'))<.012,'armed auto-step preserves pistol grip');hero.mountWeapon(null);

  // Host-style hidden hand prop validates the explicit holster policy without
  // changing weapon inventory or introducing a second weapon pose solver.
  const weapon=createWeaponModel({THREE,id:'tommy_gun'});hero.mountWeapon(weapon);
  const armedFall=sampleHeroAirborneMotion({verticalVelocity:-9,airborneAge:1,fallDistance:3,armed:true});
  weapon.visible=armedFall.weaponPolicy!=='holster';hero.reset();applyHeroAirborneMotionPose(THREE,context,armedFall);assert.equal(weapon.visible,false,'held weapon is stowed during fall pose');invariants();hero.mountWeapon(null);

  const fpsEnd=[];
  for(const hz of rates){
    const dt=1/hz;let previous=null,seen=new Set();
    for(let time=0;time<=1.6+1e-8;time+=dt){
      const flight=Math.min(time,1.22),velocity=6-9.8*flight,peak=6*6/(2*9.8),height=Math.max(0,6*flight-4.9*flight*flight),fallDistance=Math.max(0,peak-height);
      const landed=time>=1.22,sample=sampleHeroAirborneMotion({verticalVelocity:landed?0:velocity,airborneAge:flight,fallDistance,landingAge:landed?time-1.22:null,impactSpeed:6});seen.add(sample.phase);
      hero.reset();applyHeroAirborneMotionPose(THREE,context,sample);const skin=snapshot();invariants();if(previous)maxStep=Math.max(maxStep,maxDistance(previous,skin));previous=skin;
    }
    assert.ok(seen.has('ascent')&&seen.has('apex')&&seen.has('fall')&&seen.has('long-fall')&&seen.has('landing'),hz+'Hz phase coverage');
    fpsEnd.push(previous);
  }
  for(const end of fpsEnd.slice(1))assert.ok(maxDistance(fpsEnd[0],end)<1e-6,'airborne terminal pose is fps independent');

  const ladderEnds=[];
  for(const hz of rates){
    const dt=1/hz;let previous=null,last=null;
    for(let time=0;time<=2+1e-8;time+=dt){
      const travelled=Math.min(3.4,time*1.7),position={x:4,y:travelled,z:-2};
      const sample=sampleHeroLadderMotion(ladder,position,{travelled,direction:1,mountProgress:Math.min(1,time/.2),dismountProgress:Math.max(0,(time-1.75)/.25)});
      hero.object.position.set(position.x,position.y,position.z);hero.reset();applyHeroLadderMotionPose(THREE,context,sample);const skin=snapshot();invariants([position.x,position.y,position.z]);
      if(previous&&time>.2&&time<1.75)maxStep=Math.max(maxStep,maxDistance(previous,skin));previous=skin;last=skin;
      for(const [side,target]of[['l',sample.handL],['r',sample.handR]])if(target.blend>.97&&sample.blend>.97){const contact=new THREE.Vector3(target.x,target.y,target.z),distance=context.worldPosition('socket_hand_'+side).distanceTo(contact);assert.ok(distance<.04,`hand planted on rung: ${model} ${side} ${distance}`)}
      for(const [side,target]of[['l',sample.footL],['r',sample.footR]])if(target.blend>.97&&sample.blend>.97){const contact=new THREE.Vector3(target.x,target.y,target.z),distance=context.worldPosition('foot_'+side).distanceTo(contact);assert.ok(distance<.04,`foot planted on rung: ${model} ${side} ${distance}`)}
    }
    ladderEnds.push(last);
  }
  for(const end of ladderEnds.slice(1))assert.ok(maxDistance(ladderEnds[0],end)<1e-6,'ladder terminal pose is fps independent');

  for(const direction of [1,-1])for(const sliding of [false,true]){
    const position={x:4,y:2.4,z:-2},sample=sampleHeroLadderMotion(ladder,position,{travelled:2.4,direction,sliding});
    assert.equal(sample.phaseName,sliding?'slide':direction>0?'climb-up':'climb-down');assert.equal(sample.weaponPolicy,'holster');
    hero.object.position.set(position.x,position.y,position.z);hero.reset();applyHeroLadderMotionPose(THREE,context,sample);invariants([4,2.4,-2]);
    if(sliding){assert.ok(Math.abs(sample.handL.x-sample.handR.x)>.7,'slide hands follow both rails');assert.ok(Math.abs(sample.footL.x-sample.footR.x)<.15,'slide feet stay together')}
  }
  const landing=sampleHeroAirborneMotion({landingAge:.16,landingDuration:.34,fallDistance:4,impactSpeed:10});hero.object.position.set(4,0,-2);hero.reset();applyHeroAirborneMotionPose(THREE,context,landing);
  const landedSkin=snapshot();for(let i=1;i<landedSkin.length;i+=3)minLandingY=Math.min(minLandingY,landedSkin[i]);assert.ok(minLandingY>=-.012,'landing skin remains above support');
  hero.dispose();results.push({model,snapshots,maxStep,minLandingY});
}

let sink=0;const benchStart=performance.now();
for(let i=0;i<200000;i++){const s=sampleHeroAirborneMotion({verticalVelocity:(i%30)-15,airborneAge:(i%120)/60,fallDistance:(i%70)/10,landingAge:i%11===0?(i%20)/60:null,armed:i%2===0});sink+=s.progress}
const airborneSampleMs=performance.now()-benchStart,ladderStart=performance.now();
for(let i=0;i<200000;i++){const s=sampleHeroLadderMotion(ladder,{x:4,y:(i%500)/100,z:-2},{travelled:(i%500)/100,direction:i%2?1:-1,sliding:i%7===0});sink+=s.blend}
const ladderSampleMs=performance.now()-ladderStart;
assert.ok(Number.isFinite(sink));
console.log(JSON.stringify({passed:true,models:results,rates,airborneSampleMs,ladderSampleMs,samplesPerBench:200000,checks:['ascent_apex_fall_long_fall_landing','auto_step_vault_mantle','climb_up_climb_down_ctrl_slide','actual_male_female_glb','weapon_holster_and_armed_step_grip','root_yaw_bone_length_preserved','ledge_and_rung_contacts','enter_exit','10_30_60_144fps','dt0_repeat','landing_floor','sample_cpu_cost']}));
