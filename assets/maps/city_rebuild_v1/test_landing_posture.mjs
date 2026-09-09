// Verify a grounded dive changes directly into Ctrl/Z posture on the actual
// authored skin, with no hidden standing frame and preserved weapon contacts.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroWalker} from './hero_walk.mjs';
import {createHeroPosture} from './hero_posture.mjs';
import {LANDING_POSTURE_SECONDS} from './hero_pose_transition.mjs';
import {ARSENAL,createWeaponModel} from './hero_arsenal.mjs';
const here=path.dirname(fileURLToPath(import.meta.url)),vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c)}});
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js'))),{GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
const bytes=fs.readFileSync(path.join(here,'hero_models/player_male.8130dfb1f7eb.glb')),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
const bones={},meshes=[];source.traverse(n=>{if(n.isBone)bones[n.name]=n;if(n.isMesh)meshes.push(n)});
const hero=createHeroWalker({THREE,scene:source}),rest=new Map();assert.equal(typeof hero.blendIntoPosture,'function');
for(const[name,bone]of Object.entries(bones)){const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);rest.set(name,{p,s})}
hero.object.position.set(14,.6,-9);hero.object.rotation.y=-.4;
function skin(){
 hero.object.updateMatrixWorld(true);const inverse=hero.object.matrixWorld.clone().invert(),v=new THREE.Vector3(),vertices=[],bounds=new THREE.Box3(),center=new THREE.Vector3();
 for(const mesh of meshes){if(mesh.isSkinnedMesh)mesh.skeleton.update();const p=mesh.geometry.attributes.position;for(let i=0;i<p.count;i++){v.fromBufferAttribute(p,i);if(mesh.isSkinnedMesh)mesh.applyBoneTransform(i,v);v.applyMatrix4(mesh.matrixWorld).applyMatrix4(inverse);vertices.push(v.x,v.y,v.z);bounds.expandByPoint(v);center.add(v)}}center.multiplyScalar(3/vertices.length);return {vertices,bounds,center};
}
function distance(a,b){let max=0;for(let i=0;i<a.vertices.length;i+=3)max=Math.max(max,Math.hypot(a.vertices[i]-b.vertices[i],a.vertices[i+1]-b.vertices[i+1],a.vertices[i+2]-b.vertices[i+2]));return max}
let maxStep=0,maxCenterStep=0,maxZeroStep=0,cases=0;
const casesWithWeapon=[null,...ARSENAL.filter(s=>s.id!=='none')];
for(const spec of casesWithWeapon){
 const weapon=spec?createWeaponModel({THREE,id:spec.id}):null;hero.mountWeapon(weapon);
 for(const target of ['crouch','prone'])for(const side of [-1,1]){
  const aim={aimYaw:.73,aimPitch:-.2,travelYaw:.73+side*Math.PI/2,diveBlend:1},posture=createHeroPosture(target);
  hero.reset();hero.jumpPose(.63,true,spec,aim);const from=skin();hero.blendIntoPosture();hero.update(0,false,false,spec,aim,{posture});const zero=skin(),zeroStep=distance(from,zero);maxZeroStep=Math.max(maxZeroStep,zeroStep);
  // Unarmed source must be reproduced exactly at t=0; weapon IK may correct
  // palms after the blend but may not insert a visible whole-arm jump.
  assert.ok(zeroStep<(spec?.06:1e-5),`${spec?.id??'unarmed'} ${target}: zero-time landing pose pops ${zeroStep}m`);
  let prior=zero;
  for(let frame=1;frame<=96;frame++){
   hero.update(LANDING_POSTURE_SECONDS/96,false,false,spec,aim,{posture});const next=skin(),delta=distance(prior,next),centerDelta=next.center.distanceTo(prior.center);maxStep=Math.max(maxStep,delta);maxCenterStep=Math.max(maxCenterStep,centerDelta);
   // Fine samples distinguish steep continuous weapon IK from discontinuities;
   // exact zero/end matching separately catches entry and release snaps.
   assert.ok(delta<.13,`${spec?.id??'unarmed'} ${target}: adjacent skin frame pops ${delta}m`);assert.ok(centerDelta<.04,`${spec?.id??'unarmed'} ${target} side${side} frame${frame}: body center moves ${centerDelta}m`);assert.ok(next.bounds.min.y>=-.012,`${target}: actual skin below support floor ${next.bounds.min.y}`);assert.ok(next.bounds.max.y<2.12,'transition cannot insert a standing-height spike');
   assert.deepEqual(hero.object.position.toArray(),[14,.6,-9],'pose blend must not teleport the world root');assert.equal(hero.object.rotation.y,-.4,'pose blend must not steer physics');
   for(const[name,bone]of Object.entries(bones)){const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);assert.ok(s.distanceTo(rest.get(name).s)<1e-6,'no bone scale/stretch '+name);if(name!=='pelvis')assert.ok(p.distanceTo(rest.get(name).p)<1e-6,'no limb translation '+name)}
   if(weapon){const right=new THREE.Vector3(0,-.13,-.02).applyMatrix4(weapon.matrixWorld);assert.ok(right.distanceTo(bones.socket_hand_r.getWorldPosition(new THREE.Vector3()))<.01,spec.id+' right grip during landing');if(spec.twoHanded){const left=new THREE.Vector3(...weapon.userData.supportGrip).applyMatrix4(weapon.matrixWorld);assert.ok(left.distanceTo(bones.socket_hand_l.getWorldPosition(new THREE.Vector3()))<.01,spec.id+' support grip during landing')}}prior=next;
  }
  hero.update(0,false,false,spec,aim,{posture});const final=skin();assert.ok(distance(prior,final)<1e-5,`${spec?.id??'unarmed'} ${target}: completed blend release pop ${distance(prior,final)}m; floors ${prior.bounds.min.y} -> ${final.bounds.min.y}`);
  // Compare against a clean target pose, avoiding a test that merely checks
  // a blend's own interpolation formula or accepts a permanently stuck dive.
  hero.reset();hero.update(0,false,false,spec,aim,{posture});const targetSkin=skin();assert.ok(distance(final,targetSkin)<1e-5,`${target} must fully settle after ${LANDING_POSTURE_SECONDS}s`);cases++;
 }
 hero.mountWeapon(null);
}
hero.reset();hero.dispose();console.log(JSON.stringify({passed:true,cases,maxStep,maxCenterStep,maxZeroStep,checks:['real_glb_dive_to_crouch_prone','no_zero_frame_standing_pop','continuous_skin_and_center','grounded_skin','fixed_world_root','no_bone_stretch','all_weapon_grips','settles_to_exact_target_in_280ms']}));
