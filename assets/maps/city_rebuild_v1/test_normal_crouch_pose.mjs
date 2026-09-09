import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroWalker} from './hero_walk.mjs';
import {ARSENAL,createWeaponModel} from './hero_arsenal.mjs';
const here=path.dirname(fileURLToPath(import.meta.url)),vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c);}});
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
const {GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
let frames=0,minFloor=Infinity,minWeaponFloor=Infinity,maxHeight=0,maxTorsoPitch=0,maxGripError=0,maxBoneError=0,minKneeBend=Infinity,maxFootShift=0;
for(const model of ['player_male.8130dfb1f7eb.glb','player_female.298d50e6244a.glb']){
 const bytes=fs.readFileSync(path.join(here,'hero_models',model));
 const source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const hero=createHeroWalker({THREE,scene:source}),c=hero.artistContext(),meshes=[];source.traverse(n=>{if(n.isSkinnedMesh)meshes.push(n)});
 const restLengths=[['thigh_l','shin_l'],['shin_l','foot_l'],['thigh_r','shin_r'],['shin_r','foot_r'],['upperarm_l','forearm_l'],['forearm_l','hand_l'],['upperarm_r','forearm_r'],['forearm_r','hand_r']].map(([a,b])=>[a,b,c.worldPosition(a).distanceTo(c.worldPosition(b))]);
 const standingFeet=['foot_l','foot_r'].map(n=>c.worldPosition(n));
 for(const {id} of ARSENAL){
 const weapon=id==='none'?null:createWeaponModel(THREE,id);hero.mountWeapon(weapon);
 for(const moving of [false,true])for(const pitch of [-.65,0,.65]){
 hero.reset();hero.object.rotation.y=0;hero.object.position.set(0,0,0);
 for(let frame=0;frame<36;frame++){
 const value=Math.min(1,frame/15);
 hero.update(1/60,moving,false,weapon,{aimYaw:0,aimPitch:pitch,recoil:frame===29?.65:0},{posture:{target:'crouch',value}});c.object.updateMatrixWorld(true);
 const cp=new THREE.Vector3(),cq=new THREE.Quaternion(),cs=new THREE.Vector3();c.bones.chest.matrix.decompose(cp,cq,cs);cq.premultiply(c.rest.chest.q.clone().invert());const torso=new THREE.Euler().setFromQuaternion(cq);
 maxTorsoPitch=Math.max(maxTorsoPitch,Math.abs(torso.x));assert.ok(Math.abs(torso.x)<.40,`${model} ${id}: chest must remain moderately inclined`);
 for(const [a,b,length]of restLengths){const error=Math.abs(c.worldPosition(a).distanceTo(c.worldPosition(b))-length);maxBoneError=Math.max(maxBoneError,error);assert.ok(error<1e-6,'crouching cannot stretch a limb');}
 for(const mesh of meshes){mesh.skeleton.update();const v=new THREE.Vector3();for(let i=0;i<mesh.geometry.attributes.position.count;i++){
 v.fromBufferAttribute(mesh.geometry.attributes.position,i);mesh.applyBoneTransform(i,v);v.applyMatrix4(mesh.matrixWorld);assert.ok([v.x,v.y,v.z].every(Number.isFinite));minFloor=Math.min(minFloor,v.y);if(value===1)maxHeight=Math.max(maxHeight,v.y);
 }}
 if(value===1&&!moving){for(const [i,n]of ['foot_l','foot_r'].entries()){const shift=c.worldPosition(n).distanceTo(standingFeet[i]);maxFootShift=Math.max(maxFootShift,shift);assert.ok(shift<1e-6,'stationary crouch must pin both feet');}
 for(const side of ['l','r']){const hip=c.worldPosition('thigh_'+side),knee=c.worldPosition('shin_'+side),foot=c.worldPosition('foot_'+side);const bend=Math.PI-hip.sub(knee).angleTo(foot.sub(knee));minKneeBend=Math.min(minKneeBend,bend);assert.ok(bend>.8&&bend<2.5,'crouch bends the knees, not just the waist');}}
 if(weapon){const grips=[['r',[0,-.13,-.02]],...(weapon.userData.twoHanded?[['l',weapon.userData.supportGrip]]:[])];for(const [side,point]of grips){const error=c.worldPosition('socket_hand_'+side).distanceTo(weapon.localToWorld(new THREE.Vector3(...point)));maxGripError=Math.max(maxGripError,error);assert.ok(error<.003,`${id} ${pitch} ${side} hand retains weapon grip`);}
 const bounds=new THREE.Box3().setFromObject(weapon);minWeaponFloor=Math.min(minWeaponFloor,bounds.min.y);assert.ok(bounds.min.y>-.01,`${id} weapon above ground`);
 }
 frames++;
 }
 }
 }
}
assert.ok(minFloor>-.01,`skin floor penetration ${minFloor}`);assert.ok(maxHeight<1.69,`ordinary crouch needs a truthful 1.69 m capsule: ${maxHeight}`);assert.ok(minKneeBend>1,'visibly flexed legs');
console.log(JSON.stringify({passed:true,frames,minFloor,minWeaponFloor,maxHeight,maxTorsoPitch,maxGripError,maxBoneError,minKneeBend,maxFootShift,checks:['male_female_actual_GLB','all_14_weapons_and_unarmed','moderate_torso_pitch','bent_knees','no_limb_stretch','pinned_stationary_feet','moving_transition_skin_floor','weapon_floor','authored_hand_grips','three_aim_pitches','recoil']}));
