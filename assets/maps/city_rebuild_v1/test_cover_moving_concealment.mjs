import assert from 'node:assert/strict';
import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createHeroWalker} from './hero_walk.mjs';
import {createWeaponModel} from './hero_arsenal.mjs';
import {weaponHeadClearance} from './hero_weapon_clearance.mjs';
const {applyCoverPose}=await import(process.env.COVER_POSE_MODULE||'./hero_cover_pose.mjs');
const vendor=process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));const{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const bench=process.env.COVER_MOVING_BENCH==='1',costs=[];let frames=0,failures=0,firstFailure=null,maxExcess=-Infinity,maxFootError=0,minSkinY=Infinity,maxFloorRegression=0;
function check(ok,message){if(ok)return;failures++;firstFailure??=message;if(!bench)assert.ok(ok,message);}
for(const model of ['player_male.8130dfb1f7eb.glb','player_female.298d50e6244a.glb']){
 const bytes=fs.readFileSync(new URL('./hero_models/'+model,import.meta.url)),scene=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene,hero=createHeroWalker({THREE,scene}),c=hero.artistContext(),headMeshes=[];
 scene.traverse(mesh=>{if(!mesh.isSkinnedMesh)return;const a=mesh.geometry.attributes,indices=[];for(let i=0;i<a.position.count;i++){let head=0;for(let j=0;j<4;j++)if(['head','neck'].includes(mesh.skeleton.bones[a.skinIndex.getComponent(i,j)]?.name))head+=a.skinWeight.getComponent(i,j);if(head>.35)indices.push(i);}headMeshes.push({mesh,indices:new Set(indices)});});
 for(const id of [null,'uzi'])for(const baseHeight of [1.08,.9,1.25]){
  hero.reset();hero.object.position.set(0,0,0);hero.object.rotation.y=Math.PI;const weapon=id?createWeaponModel(THREE,id):null;hero.mountWeapon(weapon);const posture={target:'crouch',value:1},attachmentId=model+id+baseHeight;
  for(let frame=0;frame<240;frame++){
   const dt=1/60,time=frame*dt,moving=frame>=48,height=baseHeight===1.25?1.25+.12*Math.sin(time*1.3):baseHeight,direction=Math.floor(frame/48)%2?-1:1;
   if(moving)hero.object.position.x+=direction*2.35*dt;
   hero.update(dt,moving,false,weapon,{aimYaw:hero.object.rotation.y,aimPitch:0},{posture,motionSpeed:2.35});
   const feet=['l','r'].map(side=>c.worldPosition('foot_'+side)),lengths=['l','r'].flatMap(side=>[['thigh_'+side,'shin_'+side],['shin_'+side,'foot_'+side]]).map(([a,b])=>({a,b,d:c.worldPosition(a).distanceTo(c.worldPosition(b))}));
   let beforeFloor=Infinity;if(frame%12===0&&frame>=60)for(const {mesh}of headMeshes){mesh.skeleton.update();for(let i=0;i<mesh.geometry.attributes.position.count;i++){const v=new THREE.Vector3().fromBufferAttribute(mesh.geometry.attributes.position,i);mesh.applyBoneTransform(i,v);v.applyMatrix4(mesh.matrixWorld);beforeFloor=Math.min(beforeFloor,v.y);}}
   const sample={mode:'hidden',low:true,normal:{x:0,z:-1},coverHeight:height,blend:1,weapon,carrySide:direction>0?-1:1,moveAlong:moving?direction*2.35*dt:0,dt,attachmentId};
   const started=performance.now(),out=applyCoverPose(THREE,c,sample);if(frame>=60)costs.push(performance.now()-started);
   for(const {a,b,d}of lengths)check(Math.abs(c.worldPosition(a).distanceTo(c.worldPosition(b))-d)<1e-7,'leg lengths preserved');
   for(const [i,side]of ['l','r'].entries()){const error=c.worldPosition('foot_'+side).distanceTo(feet[i]);maxFootError=Math.max(maxFootError,error);check(error<.003,`gait foot target ${model} ${id} ${height} ${frame} ${error}`);}
   if(frame>=60){maxExcess=Math.max(maxExcess,out.actualHeadTop-height+.04);check(out.fullyConcealed,`moving concealment ${model} ${id} ${height.toFixed(3)} frame${frame} phase${hero.diagnostics().phase}: ${JSON.stringify(out)}`);if(weapon)check(out.selfClear,`moving weapon clearance ${model} ${height} frame${frame}`);}
   if(frame%12===0&&frame>=60){let actual=-Infinity;let afterFloor=Infinity,lowestBone='';for(const {mesh,indices}of headMeshes){mesh.skeleton.update();for(let i=0;i<mesh.geometry.attributes.position.count;i++){const v=new THREE.Vector3().fromBufferAttribute(mesh.geometry.attributes.position,i);mesh.applyBoneTransform(i,v);v.applyMatrix4(mesh.matrixWorld);if(indices.has(i))actual=Math.max(actual,v.y);minSkinY=Math.min(minSkinY,v.y);if(v.y<afterFloor){afterFloor=v.y;const a=mesh.geometry.attributes;let influence=-1;for(let j=0;j<4;j++)if(a.skinWeight.getComponent(i,j)>influence){influence=a.skinWeight.getComponent(i,j);lowestBone=mesh.skeleton.bones[a.skinIndex.getComponent(i,j)]?.name;}}}}maxFloorRegression=Math.max(maxFloorRegression,beforeFloor-afterFloor);check(afterFloor>=Math.min(-.012,beforeFloor-.003),`moving floor regression ${model} ${id} ${height} ${beforeFloor} -> ${afterFloor} ${lowestBone}`);check(actual<=height-.04,`actual moving head ${model} ${id} ${height} frame${frame} top${actual}`);}
   if(weapon&&frame>=60&&frame%12===0)check(weaponHeadClearance(THREE,c,weapon,{origin:weapon.getWorldPosition(new THREE.Vector3()),quaternion:weapon.getWorldQuaternion(new THREE.Quaternion()),checkMuzzle:false}).clear,'physical moving weapon/head clearance');
   hero.update(0,moving,false,weapon,{aimYaw:hero.object.rotation.y,aimPitch:0},{posture,motionSpeed:2.35});const repeated=applyCoverPose(THREE,c,{...sample,dt:0});check(Math.abs(repeated.actualHeadTop-out.actualHeadTop)<1e-7,'moving second pass idempotent');frames++;
  }
 }
}
costs.sort((a,b)=>a-b);console.log(JSON.stringify({passed:!failures,frames,failures,firstFailure,maxExcess,maxFootError,minSkinY,maxFloorRegression,samples:costs.length,p50:costs[Math.floor(costs.length*.5)],p95:costs[Math.floor(costs.length*.95)]}));
