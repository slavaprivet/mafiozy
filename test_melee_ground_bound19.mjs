import fs from 'node:fs';import assert from 'node:assert/strict';import {registerHooks} from 'node:module';import {pathToFileURL} from 'node:url';
import {clone} from './assets/maps/city_rebuild_v1/test_npc_death_offline_setup.mjs';
import {createHeroWalker} from './assets/maps/city_rebuild_v1/hero_walk.mjs';
import {NPC_ASSETS} from './assets/maps/city_rebuild_v1/npc_actor.mjs';
import {createContactGroundBound} from './assets/maps/city_rebuild_v1/hero_contact_ground_bound.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
let checks=0,fast=0,fallback=0,maxError=0;
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),model=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const hero=createHeroWalker({THREE,scene:clone(model),targetHeight:1.9}),meshes=[];hero.object.traverse(x=>{if(x.isMesh)meshes.push(x);});const bound=createContactGroundBound({THREE,meshes,root:hero.object});
 const sample=new THREE.Vector3(),inverse=new THREE.Matrix4();
 for(const scale of [[1,1,1],[.8,1.2,1.3],[-1,1.1,.9]])for(const side of [-1,1])for(let ms=0;ms<=1248;ms+=16){
  hero.object.position.set(3,.4,-8);hero.object.rotation.y=.7;hero.object.scale.fromArray(scale);const action={type:'dropkick',side,progress:ms/1250};hero.update(.016,false,false,null,{}, {action});
  const context=hero.artistContext(),samples=['foot_l','foot_r'].map(name=>({name,current:new THREE.Vector3()})),expected=samples.map(({name})=>context.bones[name].getWorldPosition(new THREE.Vector3()));
  hero.sampleMeleeContactPose(action,hero.object.position,hero.object.quaternion,samples);
  samples.forEach((s,i)=>{maxError=Math.max(maxError,s.current.distanceTo(expected[i]));assert(s.current.distanceTo(expected[i])<1e-8,'contact-only floor optimization preserves exact authored pose');});
  const above=bound();if(above)fast++;else fallback++;
  inverse.copy(hero.object.matrixWorld).invert();let min=Infinity;
  for(const mesh of meshes){if(mesh.isSkinnedMesh)mesh.skeleton.update();for(let i=0;i<mesh.geometry.attributes.position.count;i++){sample.fromBufferAttribute(mesh.geometry.attributes.position,i);if(mesh.isSkinnedMesh)mesh.applyBoneTransform(i,sample);sample.applyMatrix4(mesh.matrixWorld).applyMatrix4(inverse);min=Math.min(min,sample.y);}}
  if(above)assert(min>=-1e-8,'conservative bound may only skip full scan above floor');checks++;
 }
 // Genuine below-floor and unknown-weight inputs must use original groundPose.
 hero.artistContext().visualPivot.position.y-=4;hero.object.updateMatrixWorld(true);assert(!bound());
 const mesh=meshes.find(x=>x.isSkinnedMesh),weights=mesh.geometry.attributes.skinWeight,old=weights.getX(0);weights.setX(0,-.1);assert(!createContactGroundBound({THREE,meshes:[mesh],root:hero.object})());weights.setX(0,old);
 hero.dispose();
}
assert(fast>0&&fallback>0);console.log(JSON.stringify({pass:true,checks,fast,fallback,maxError,scope:'real male/female full dropkick timeline; ±side; nonuniform and mirrored scale; exact visible-pose parity; every vertex lower-bound proof; invalid/negative fallback'}));
