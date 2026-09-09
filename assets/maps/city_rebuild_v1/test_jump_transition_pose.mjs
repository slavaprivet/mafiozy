// Actual authored skin: catch normal-to-dive pops, reversed lateral banking,
// camera/travel gaze confusion and grip/floor regressions in one isolated test.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroWalker} from './hero_walk.mjs';
import {ARSENAL,createWeaponModel} from './hero_arsenal.mjs';
import {jumpDirection} from './hero_jump.mjs';
const here=path.dirname(fileURLToPath(import.meta.url)),vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c)}});
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js'))),{GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
const bytes=fs.readFileSync(path.join(here,'hero_models/player_male.8130dfb1f7eb.glb')),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
const bones={},meshes=[];source.traverse(n=>{if(n.isBone)bones[n.name]=n;if(n.isMesh)meshes.push(n)});
assert.ok(meshes.some(m=>m.isSkinnedMesh),'test must exercise the actual skinned GLB');
const hero=createHeroWalker({THREE,scene:source}),headRest=bones.head.getWorldQuaternion(new THREE.Quaternion()),rest=new Map();
for(const [name,bone]of Object.entries(bones)){const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);rest.set(name,{p,s})}
hero.object.position.set(13,0,-7);hero.object.rotation.y=-.67;
const point=new THREE.Vector3();let snapshots=0,maxSkinStep=0,maxCenterStep=0,maxHeadStep=0,minSkinY=Infinity;
function snapshot(){
 hero.object.updateMatrixWorld(true);const inverse=hero.object.matrixWorld.clone().invert(),vertices=[],bounds=new THREE.Box3(),center=new THREE.Vector3();
 for(const mesh of meshes){if(mesh.isSkinnedMesh)mesh.skeleton.update();const p=mesh.geometry.attributes.position;for(let i=0;i<p.count;i++){point.fromBufferAttribute(p,i);if(mesh.isSkinnedMesh)mesh.applyBoneTransform(i,point);point.applyMatrix4(mesh.matrixWorld).applyMatrix4(inverse);vertices.push(point.x,point.y,point.z);bounds.expandByPoint(point);center.add(point)}}
 center.multiplyScalar(3/vertices.length);const head=bones.head.getWorldPosition(new THREE.Vector3()).applyMatrix4(inverse);snapshots++;minSkinY=Math.min(minSkinY,bounds.min.y);
 return {vertices,center,head,bounds};
}
function maxVertexDistance(a,b){assert.equal(a.vertices.length,b.vertices.length);let max=0;for(let i=0;i<a.vertices.length;i+=3)max=Math.max(max,Math.hypot(a.vertices[i]-b.vertices[i],a.vertices[i+1]-b.vertices[i+1],a.vertices[i+2]-b.vertices[i+2]));return max}
function pose(p,directional,weapon,aim){hero.jumpPose(p,directional,weapon,aim);assert.deepEqual(hero.object.position.toArray(),[13,0,-7],'presentation must not move ballistic root');assert.equal(hero.object.rotation.y,-.67,'presentation must not change physical heading');return snapshot()}
function gaze(aim){
 const actual=new THREE.Vector3(0,0,1).applyQuaternion(bones.head.getWorldQuaternion(new THREE.Quaternion()).multiply(headRest.clone().invert())).normalize();
 const expected=new THREE.Vector3(Math.sin(aim.aimYaw)*Math.cos(aim.aimPitch),Math.sin(aim.aimPitch),Math.cos(aim.aimYaw)*Math.cos(aim.aimPitch));
 assert.ok(actual.dot(expected)>.999,`head must follow crosshair, not travel: dot=${actual.dot(expected)}`);
}
function floor(s,label){assert.ok(s.bounds.min.y>=-.012,`${label}: actual skin below ballistic support plane ${s.bounds.min.y}`)}
for(const progress of [.1,.22,.4,.61,.8])for(const relativeTravel of [0,Math.PI/2,-Math.PI/2,Math.PI]){
 const aim={aimYaw:1.13,aimPitch:.24,travelYaw:1.13+relativeTravel},normal=pose(progress,false,null,aim),start=pose(progress,true,null,{...aim,diveBlend:0});
 assert.ok(maxVertexDistance(normal,start)<1e-6,`diveBlend=0 must equal current normal pose: progress=${progress}, travel=${relativeTravel}`);
 const near=pose(progress,true,null,{...aim,diveBlend:1e-6});assert.ok(maxVertexDistance(start,near)<1e-4,'first transition frame cannot snap skin');
 let previous=start;
 for(let i=1;i<=40;i++){
  const current=pose(progress,true,null,{...aim,diveBlend:i/40}),skinStep=maxVertexDistance(previous,current),centerStep=current.center.distanceTo(previous.center),headStep=current.head.distanceTo(previous.head);
  maxSkinStep=Math.max(maxSkinStep,skinStep);maxCenterStep=Math.max(maxCenterStep,centerStep);maxHeadStep=Math.max(maxHeadStep,headStep);
  assert.ok(skinStep<.15,`skin pop across blend ${i/40}: ${skinStep}m`);assert.ok(centerStep<.08,`skin center pops ${centerStep}m`);assert.ok(headStep<.1,`head position pops ${headStep}m`);gaze(aim);floor(current,'transition');previous=current;
 }
 const nearEnd=pose(progress,true,null,{...aim,diveBlend:1-1e-6}),end=pose(progress,true,null,{...aim,diveBlend:1});assert.ok(maxVertexDistance(nearEnd,end)<1e-4,'completion frame cannot snap skin');
}
for(const aimYaw of [0,.91,-2.2])for(const inputName of ['left','right']){
 const travel=jumpDirection({x:Math.sin(aimYaw),z:Math.cos(aimYaw)},{[inputName]:true}),aim={aimYaw,aimPitch:0,travelYaw:Math.atan2(travel.x,travel.z),diveBlend:1};
 pose(.32,false,null,aim);
 const leftBefore=bones.upperarm_l.getWorldPosition(new THREE.Vector3()),rightBefore=bones.upperarm_r.getWorldPosition(new THREE.Vector3()),span=rightBefore.clone().sub(leftBefore),rightLeads=span.x*travel.x+span.z*travel.z>0;
 pose(.32,true,null,aim);gaze(aim);
 const left=bones.upperarm_l.getWorldPosition(new THREE.Vector3()),right=bones.upperarm_r.getWorldPosition(new THREE.Vector3()),leadingY=rightLeads?right.y:left.y,trailingY=rightLeads?left.y:right.y;
 // Authored names are mirrored relative to camera-right when facing +Z:
 // actual D => travel X -1 => bone upperarm_l is the leading shoulder.
 assert.ok(trailingY-leadingY>.08,`${inputName==='right'?'D':'A'} dive must lower leading ${rightLeads?'upperarm_r':'upperarm_l'}: left=${left.y}, right=${right.y}`);
}
for(const travelYaw of [0,Math.PI/2,-Math.PI/2,Math.PI]){
 const aim={aimYaw:0,aimPitch:0,travelYaw,diveBlend:1};
 for(const p of [.64,.70,.72]){
  const landed=pose(p,true,null,aim),up=new THREE.Vector3(0,1,0).transformDirection(hero.artistContext().visualPivot.matrixWorld);
  assert.ok(Math.abs(up.y)<.06,'body must contact ground lying toward chosen travel before standing');
  assert.ok(Math.abs(landed.bounds.min.y)<1e-5);gaze(aim);
 }
 pose(1,true,null,aim);const up=new THREE.Vector3(0,1,0).transformDirection(hero.artistContext().visualPivot.matrixWorld);assert.ok(up.y>.999,'quick recovery ends upright');
}
const armed=ARSENAL.filter(s=>s.id!=='none');
for(const spec of armed){
 const model=createWeaponModel({THREE,id:spec.id});hero.mountWeapon(model);
 for(const progress of [.24,.55,.82])for(const blend of [0,.5,1])for(const relativeTravel of [-Math.PI/2,Math.PI/2]){
  const aim={aimYaw:.81,aimPitch:-.4,travelYaw:.81+relativeTravel,diveBlend:blend,recoil:.5};
  if(blend===0){const normal=pose(progress,false,spec,aim),start=pose(progress,true,spec,aim);assert.ok(maxVertexDistance(normal,start)<1e-6,`${spec.id} armed transition starts at normal pose`)}
  const skin=pose(progress,true,spec,aim);gaze(aim);floor(skin,spec.id);
  const right=new THREE.Vector3(0,-.13,-.02).applyMatrix4(model.matrixWorld);assert.ok(right.distanceTo(bones.socket_hand_r.getWorldPosition(new THREE.Vector3()))<.01,`${spec.id} transition right grip`);
  if(spec.twoHanded){const left=new THREE.Vector3(...model.userData.supportGrip).applyMatrix4(model.matrixWorld);assert.ok(left.distanceTo(bones.socket_hand_l.getWorldPosition(new THREE.Vector3()))<.01,`${spec.id} transition support grip`)}
  const muzzle=new THREE.Vector3(0,0,1).transformDirection(model.matrixWorld),yaw=Math.atan2(muzzle.x,muzzle.z),pitch=Math.atan2(muzzle.y,Math.hypot(muzzle.x,muzzle.z));assert.ok(Math.abs(Math.atan2(Math.sin(yaw-aim.aimYaw),Math.cos(yaw-aim.aimYaw)))<.04,`${spec.id} lateral dive muzzle yaw`);assert.ok(Math.abs(pitch-(aim.aimPitch+aim.recoil*(spec.twoHanded?.13:.105)))<.03,`${spec.id} lateral dive muzzle pitch`);
  for(const [name,bone]of Object.entries(bones)){const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);assert.ok(p.distanceTo(rest.get(name).p)<1e-6&&s.distanceTo(rest.get(name).s)<1e-6,'dive may rotate bones but not stretch/translate limbs: '+name)}
 }
 hero.mountWeapon(null);
}
hero.reset();hero.dispose();
console.log(JSON.stringify({passed:true,source:'actual player_male GLB skin',weapons:armed.length,snapshots,maxSkinStep,maxCenterStep,maxHeadStep,minSkinY,checks:['normal_to_dive_zero_and_endpoint_continuity','blend_skin_centroid_head_continuity','leading_right_left_shoulder','crosshair_gaze_independent_of_travel','all_weapon_grips_and_aim','skin_floor_clearance','no_bone_stretch_or_root_teleport']}));
