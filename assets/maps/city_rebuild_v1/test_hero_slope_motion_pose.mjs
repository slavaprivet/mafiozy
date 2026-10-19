import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {performance} from 'node:perf_hooks';
import {createHeroWalker} from './hero_walk.mjs';
import {ARSENAL,createWeaponModel} from './hero_arsenal.mjs';
import {HERO_SLOPE_BLEND,stepHeroSlopeBlend,sampleHeroSlopeMotion,applyHeroSlopeMotionPose} from './hero_slope_motion_pose.mjs';

const here=path.dirname(fileURLToPath(import.meta.url)),vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c)}});
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js'))),{GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
const models=['player_male.8130dfb1f7eb.glb','player_female.298d50e6244a.glb'],rates=[10,30,60,144],poseSnapshots=[],results=[];

function maxDistance(a,b){let max=0;assert.equal(a.length,b.length);for(let i=0;i<a.length;i+=3)max=Math.max(max,Math.hypot(a[i]-b[i],a[i+1]-b[i+1],a[i+2]-b[i+2]));return max}

for(const model of models){
 const bytes=fs.readFileSync(path.join(here,'hero_models',model)),scene=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const hero=createHeroWalker({THREE,scene}),ctx=hero.artistContext(),meshes=[];scene.traverse(node=>{if(node.isSkinnedMesh)meshes.push(node)});assert.ok(meshes.length);
 hero.object.position.set(7,2,-5);hero.object.rotation.y=.43;const root=[7,2,-5],rest=new Map(Object.entries(ctx.bones).map(([name,bone])=>{const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);return[name,{p,s}]}));
 const point=new THREE.Vector3();let snapshotCount=0,maxGradeStep=0,maxTransitionStep=0;
 function snapshot(){hero.object.updateMatrixWorld(true);const inverse=hero.object.matrixWorld.clone().invert(),values=[];for(const mesh of meshes){mesh.skeleton.update();const positions=mesh.geometry.attributes.position;for(let i=0;i<positions.count;i++){point.fromBufferAttribute(positions,i);mesh.applyBoneTransform(i,point);point.applyMatrix4(mesh.matrixWorld).applyMatrix4(inverse);values.push(point.x,point.y,point.z)}}snapshotCount++;return values}
 function invariants(){assert.deepEqual(hero.object.position.toArray(),root);assert.equal(hero.object.rotation.y,.43);for(const [name,bone]of Object.entries(ctx.bones)){const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);assert.ok(p.distanceTo(rest.get(name).p)<1e-7,name+' translation');assert.ok(s.distanceTo(rest.get(name).s)<1e-6,name+' scale')}}
 function pose({grade,blend=null,phase=.7,armed=false,contacts=false}){
  hero.reset();hero.object.updateMatrixWorld(true);const feet={},hands={};
  for(const side of ['l','r']){const foot=ctx.worldPosition('foot_'+side),lift=side==='l'?Math.max(0,grade)*.08:Math.max(0,-grade)*.08;feet[side]={x:foot.x,y:foot.y+lift,z:foot.z};const shoulder=ctx.worldPosition('upperarm_'+side),hand=ctx.worldPosition('socket_hand_'+side).sub(shoulder).multiplyScalar(.9).add(shoulder);hands[side]={x:hand.x,y:hand.y+.02,z:hand.z}}
  const sample=sampleHeroSlopeMotion({slopeGrade:grade,blend,gaitPhase:phase,gaitWeight:1,armed,footL:feet.l,footR:feet.r,handL:contacts?hands.l:null,handR:contacts?hands.r:null});
  assert.equal(applyHeroSlopeMotionPose(THREE,ctx,sample),true);invariants();
  if(sample.blend>.99)for(const side of ['l','r']){const target=new THREE.Vector3(feet[side].x,feet[side].y,feet[side].z),distance=ctx.worldPosition('foot_'+side).distanceTo(target);assert.ok(distance<.012,`independent foot support ${model} ${side} ${grade} ${distance}`)}
  if(contacts&&sample.handBlend>.999)for(const side of ['l','r']){const target=new THREE.Vector3(hands[side].x,hands[side].y,hands[side].z),distance=ctx.worldPosition('socket_hand_'+side).distanceTo(target);assert.ok(distance<.04,`steep hand contact ${model} ${side} ${grade} ${distance}`)}
  return {sample,skin:snapshot()};
 }

 assert.equal(sampleHeroSlopeMotion({slopeGrade:.41}).targetBlend,0);assert.equal(sampleHeroSlopeMotion({slopeGrade:.79}).targetBlend,1);
 assert.equal(sampleHeroSlopeMotion({slopeGrade:-.29}).downhillBrake,0);assert.ok(sampleHeroSlopeMotion({slopeGrade:-.73}).downhillBrake>.93);
 let previous=pose({grade:.35}).skin;
 for(let grade=.36;grade<=.96;grade+=.01){const current=pose({grade,phase:1.1,contacts:grade>.72}).skin;maxGradeStep=Math.max(maxGradeStep,maxDistance(previous,current));previous=current}
 assert.ok(maxGradeStep<.09,'walk to scramble grade continuity '+maxGradeStep);
 previous=pose({grade:-.35}).skin;
 for(let grade=-.36;grade>=-.96;grade-=.01){const current=pose({grade,phase:2.2,contacts:grade<-.72}).skin;maxGradeStep=Math.max(maxGradeStep,maxDistance(previous,current));previous=current}
 assert.ok(maxGradeStep<.09,'downhill brake grade continuity '+maxGradeStep);

 for(const armed of [false,true])for(const grade of [-.95,-.78,-.55,.55,.78,.95])for(const phase of [0,Math.PI/2,Math.PI,Math.PI*1.5]){
  const {sample}=pose({grade,phase,armed,contacts:Math.abs(grade)>.91});
  assert.equal(sample.weaponPolicy,armed?(sample.blend>.55?'holster':'carry-safe'):'none');
 }
 const pistolSpec=ARSENAL.find(spec=>spec.id==='tt_pistol'),weapon=createWeaponModel({THREE,id:pistolSpec.id});hero.mountWeapon(weapon);hero.update(0,true,false,pistolSpec,{aimYaw:.43,aimPitch:-.1},{gaitOutput:{}});
 const carried=sampleHeroSlopeMotion({slopeGrade:.53,blend:.45,gaitPhase:.7,gaitWeight:1,armed:true});applyHeroSlopeMotionPose(THREE,ctx,carried);hero.object.updateMatrixWorld(true);
 const grip=new THREE.Vector3(0,-.13,-.02).applyMatrix4(weapon.matrixWorld);assert.ok(grip.distanceTo(ctx.worldPosition('socket_hand_r'))<.012,'moderate armed slope keeps pistol grip');hero.mountWeapon(null);

 const fpsEnds=[];
 for(const hz of rates){let blend=0,previousSkin=null;const dt=1/hz;assert.equal(stepHeroSlopeBlend(.37,1,0),.37,'dt0 exact');
  for(let t=0;t<1-1e-10;t+=dt){blend=stepHeroSlopeBlend(blend,1,Math.min(dt,1-t));const skin=pose({grade:.9,blend,phase:t*7}).skin;if(previousSkin)maxTransitionStep=Math.max(maxTransitionStep,maxDistance(previousSkin,skin));previousSkin=skin}
  for(let t=0;t<1-1e-10;t+=dt)blend=stepHeroSlopeBlend(blend,0,Math.min(dt,1-t));fpsEnds.push(blend);
 }
 assert.ok(Math.max(...fpsEnds)-Math.min(...fpsEnds)<1e-10,'transition fps parity '+fpsEnds);assert.ok(maxTransitionStep<.43,'10Hz transition bounded '+maxTransitionStep);

 for(const [label,grade,phase]of[['walk-edge',.42,0],['scramble-up',.92,1.1],['scramble-down',-.92,2.4]]){
  const {sample}=pose({grade,phase,contacts:Math.abs(grade)>.9});const joints={};for(const name of ['chest','head','hand_l','hand_r','foot_l','foot_r'])joints[name]=ctx.worldPosition(name).toArray().map(value=>+value.toFixed(5));poseSnapshots.push({model,label,grade,blend:+sample.blend.toFixed(5),downhillBrake:+sample.downhillBrake.toFixed(5),joints});
 }
 hero.dispose();results.push({model,snapshotCount,maxGradeStep,maxTransitionStep,fpsEnds});
}

let sink=0;const iterations=200000,start=performance.now();for(let i=0;i<iterations;i++){const s=sampleHeroSlopeMotion({slopeGrade:(i%231-115)/100,blend:(i%101)/100,gaitPhase:i*.01,gaitWeight:(i%17)/16,armed:i%2===0});sink+=s.blend+s.downhillBrake}const sampleMs=performance.now()-start;
assert.ok(Number.isFinite(sink));const output={passed:true,blendRanges:HERO_SLOPE_BLEND,rates,models:results,sampleMs,iterations,checks:['uphill_scramble','downhill_braking','walk_scramble_continuity','independent_foot_support','optional_steep_hand_contacts','armed_carry_and_holster','actual_male_female_glb','10_30_60_144fps','dt0','root_yaw_bone_invariants']};
const outputDir=path.resolve(here,'../../..','outputs','hero_pose_astra15');fs.mkdirSync(outputDir,{recursive:true});fs.writeFileSync(path.join(outputDir,'slope_pose_snapshots.json'),JSON.stringify({generatedBy:'test_hero_slope_motion_pose.mjs',poseSnapshots,output},null,2));
console.log(JSON.stringify(output));
