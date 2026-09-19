import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createHeroWalker} from './hero_walk.mjs';
import {createWeaponModel} from './hero_arsenal.mjs';
import {applyCoverPose} from './hero_cover_pose.mjs';
import {weaponHeadClearance} from './hero_weapon_clearance.mjs';
const vendor=process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));const{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
let cases=0,minimum=Infinity,maxFootError=0,minSkinY=Infinity,minGunY=Infinity,dynamicFrames=0;const rows=[];
for(const model of ['player_male.8130dfb1f7eb.glb','player_female.298d50e6244a.glb']){
 const b=fs.readFileSync(new URL('./hero_models/'+model,import.meta.url)),scene=(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene,hero=createHeroWalker({THREE,scene}),c=hero.artistContext();
 for(const id of [null,'tt_pistol','uzi','shotgun']){
  const weapon=id?createWeaponModel(THREE,id):null;hero.mountWeapon(weapon);
  for(const height of [.9,1.08,1.25,1.5,2.2])for(const mode of ['hidden','blocked']){
   hero.reset();const low=height<=1.5;hero.object.position.set(0,0,0);hero.update(0,false,false,weapon,{aimYaw:0,aimPitch:0},{posture:{target:low?'crouch':'stand',value:low?1:0}});
   const feet=['l','r'].map(s=>c.worldPosition('foot_'+s)),root=hero.object.position.clone(),lengths=['l','r'].flatMap(side=>[['thigh_'+side,'shin_'+side],['shin_'+side,'foot_'+side]]).map(([a,b])=>({a,b,length:c.worldPosition(a).distanceTo(c.worldPosition(b))}));
   const out=applyCoverPose(THREE,c,{mode,low,normal:{x:0,z:1},coverHeight:height,blend:1,weapon,carrySide:1});
   for(const [i,s]of ['l','r'].entries()){const error=c.worldPosition('foot_'+s).distanceTo(feet[i]);maxFootError=Math.max(maxFootError,error);assert.ok(error<.003,`ground contact ${model} ${height} ${error}`);}
   assert.ok(hero.object.position.distanceTo(root)<1e-10);for(const {a,b,length}of lengths)assert.ok(Math.abs(c.worldPosition(a).distanceTo(c.worldPosition(b))-length)<1e-7,'leg bones retain authored lengths');
   let actual=-Infinity;
   c.object.traverse(mesh=>{if(!mesh.isSkinnedMesh){if(!mesh.isMesh||!mesh.geometry?.attributes?.position)return;let parent=mesh.parent;while(parent&&parent!==c.object&&!['head','neck'].includes(parent.name))parent=parent.parent;if(!['head','neck'].includes(parent?.name))return;const a=mesh.geometry.attributes.position;for(let i=0;i<a.count;i++)actual=Math.max(actual,new THREE.Vector3().fromBufferAttribute(a,i).applyMatrix4(mesh.matrixWorld).y);return;}mesh.skeleton.update();const a=mesh.geometry.attributes;for(let i=0;i<a.position.count;i++){const p=new THREE.Vector3().fromBufferAttribute(a.position,i);mesh.applyBoneTransform(i,p);p.applyMatrix4(mesh.matrixWorld);minSkinY=Math.min(minSkinY,p.y);let head=0;for(let j=0;j<4;j++)if(['head','neck'].includes(mesh.skeleton.bones[a.skinIndex.getComponent(i,j)]?.name))head+=a.skinWeight.getComponent(i,j);if(head>.35)actual=Math.max(actual,p.y);}});
   assert.ok(actual<=out.actualHeadTop+.025,`diagnostic bounds actual geometry ${actual} ${out.actualHeadTop}`);
   assert.equal(out.fullyConcealed,true,`requested concealment ${model} ${id} ${height}: ${JSON.stringify(out)}`);if(out.fullyConcealed)assert.ok(actual<=height-.04,`head concealed ${model} ${id} ${height}: ${actual}`);
   if(weapon){const floor=new THREE.Box3().setFromObject(weapon).min.y;minGunY=Math.min(minGunY,floor);assert.ok(floor>-.012,`weapon above floor ${id} ${height} ${floor}`);}if(weapon)assert.equal(out.selfClear,true,`safe carry ${model} ${id} ${height} ${JSON.stringify(out)}`);if(weapon&&out.selfClear)assert.ok(weaponHeadClearance(THREE,c,weapon,{origin:weapon.getWorldPosition(new THREE.Vector3()),quaternion:weapon.getWorldQuaternion(new THREE.Quaternion()),checkMuzzle:false}).clear);
   minimum=Math.min(minimum,out.minimumHeadTop);if(!id&&mode==='hidden')rows.push({model,height,actual,bound:out.actualHeadTop,minimum:out.minimumHeadTop,concealed:out.fullyConcealed});cases++;
  }
 }
 hero.mountWeapon(null);hero.reset();hero.update(0,false,false,null,{aimYaw:0,aimPitch:0},{posture:{target:'crouch',value:1}});
 const impossible=applyCoverPose(THREE,c,{mode:'hidden',low:true,normal:{x:0,z:1},coverHeight:.7,blend:1});
 assert.equal(impossible.fullyConcealed,false,'anatomically insufficient cover is reported honestly');assert.ok(impossible.minimumHeadTop>.7-.04);
 for(const id of [null,'tt_pistol','uzi','shotgun']){
  const weapon=id?createWeaponModel(THREE,id):null;hero.mountWeapon(weapon);hero.reset();const posture={target:'crouch',value:1};let previousTop=null;
  for(const height of [1.5,1.08,.9,1.25,2.2])for(let frame=0;frame<54;frame++){
   const dt=1/60;hero.object.position.x+=.01;hero.object.rotation.y+=.008;posture.target=height<=1.5?'crouch':'stand';posture.value+=Math.max(-2.1*dt,Math.min(2.1*dt,(posture.target==='crouch'?1:0)-posture.value));
   hero.update(0,false,false,weapon,{aimYaw:hero.object.rotation.y,aimPitch:0},{posture});const feet=['l','r'].map(side=>c.worldPosition('foot_'+side));
   const out=applyCoverPose(THREE,c,{mode:'hidden',low:height<=1.5,normal:{x:Math.sin(hero.object.rotation.y),z:Math.cos(hero.object.rotation.y)},coverHeight:height,blend:1,weapon,carrySide:1,dt,attachmentId:'dynamic:'+id});
   for(const [i,side]of ['l','r'].entries())assert.ok(c.worldPosition('foot_'+side).distanceTo(feet[i])<.003,'adaptive feet stay planted');
   if(previousTop!==null)assert.ok(Math.abs(out.actualHeadTop-previousTop)<.12,'height adapts without a vertical teleport');previousTop=out.actualHeadTop;
   if(frame>=45){assert.ok(out.fullyConcealed,`dynamic hidden ${model} ${id} ${height} ${JSON.stringify(out)}`);if(weapon)assert.ok(out.selfClear,`dynamic safe carry ${model} ${id} ${height} ${JSON.stringify(out)}`);}
   hero.update(0,false,false,weapon,{aimYaw:hero.object.rotation.y,aimPitch:0},{posture});const repeated=applyCoverPose(THREE,c,{mode:'hidden',low:height<=1.5,normal:{x:Math.sin(hero.object.rotation.y),z:Math.cos(hero.object.rotation.y)},coverHeight:height,blend:1,weapon,carrySide:1,dt:0,attachmentId:'dynamic:'+id});
   assert.ok(Math.abs(repeated.actualHeadTop-out.actualHeadTop)<1e-7,'second render pass cannot deepen crouch');dynamicFrames++;
  }
 }
}
assert.ok(minSkinY>-.012,`skin below ground ${minSkinY}`);
console.log(JSON.stringify({passed:true,cases,dynamicFrames,minimum,maxFootError,minSkinY,minGunY,rows}));
