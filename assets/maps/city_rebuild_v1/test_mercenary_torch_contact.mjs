import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroWalker,HERO_ASSET} from './hero_walk.mjs';
import {NPC_ASSETS} from './npc_actor.mjs';
import {createMercenaryPose} from './mercenary_pose.mjs';
const vendor=process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor',threeUrl=pathToFileURL(vendor+'/build/three.module.js').href;
registerHooks({resolve(s,c,n){return n(s==='three'?threeUrl:s,c)}});
const THREE=await import(threeUrl),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
for(const [name,asset]of[['male',HERO_ASSET],['female',NPC_ASSETS.female]])for(const reach of[.5,.92,1.09])test(name+' '+reach+'m torch reaches real surface; draws/stows and has no effect while too far away',async()=>{
 const bytes=fs.readFileSync(new URL(asset.url)),gltf=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),''),walker=createHeroWalker({THREE,scene:gltf.scene}),pose=createMercenaryPose({THREE,walker});
 try{walker.object.position.set(30,2,17);walker.object.rotation.y=.8;walker.object.updateMatrixWorld(true);const point=walker.object.localToWorld(new THREE.Vector3(0,.65,reach)),normal=new THREE.Vector3(0,0,-1).applyQuaternion(walker.object.quaternion),root=walker.object.position.toArray(),action={kind:'cut_fence',phase:'working',progress:.45,workPoint:point,workNormal:normal};
  const apply=(p,time=2)=>{walker.update(.016);pose.apply({...action,progress:p},time);};apply(.45);assert.equal(pose.stats().contactActive,true,JSON.stringify(pose.stats()));assert(pose.stats().contactError<.065);assert.deepEqual(walker.object.position.toArray(),root);
  const tools=walker.object.getObjectByName('Mercenary_Tools'),flame=tools.getObjectByName('Torch_Contact_Flame'),sparks=tools.getObjectByName('Torch_Contact_Sparks');assert(flame.visible);assert.equal(sparks.count,6);assert.equal(sparks.visible,true);assert(tools.getObjectByName('Torch_Small_Fuel_Cylinder'));const scale=tools.getWorldScale(new THREE.Vector3());assert(Math.abs(scale.x-1)<1e-5,'tool dimensions use metres');
  for(const progress of[.26,.32,.38,.44,.50,.56,.62,.68,.74,.80,.84]){apply(progress);assert.equal(pose.stats().contactActive,true,'sweep '+progress+' '+JSON.stringify(pose.stats()));}
  apply(.12);assert.equal(pose.stats().stage,'draw');assert.equal(flame.visible,false);apply(.93);assert.equal(pose.stats().stage,'stow');assert.equal(flame.visible,false);
  action.workPoint=point.clone().addScaledVector(normal,-4);apply(.45);assert.equal(pose.stats().contactActive,false);assert(pose.stats().contactError>1);assert.equal(flame.visible,false);assert.equal(sparks.visible,false);assert.deepEqual(walker.object.position.toArray(),root,'no fake root teleport to remote target');
  action.workPoint=point;let count=0;walker.object.traverse(o=>{count++;assert(!o.isLight,'no per-specialist lights');});const costs=[];for(let i=0;i<240;i++){walker.update(.016);const start=performance.now();pose.apply(action,i/60);if(i>=40)costs.push(performance.now()-start);}costs.sort((a,b)=>a-b);console.log(name+' real contact IK CPU only p50='+costs[100].toFixed(3)+'ms p95='+costs[190].toFixed(3)+'ms');let after=0;walker.object.traverse(()=>after++);assert.equal(after,count);assert(pose.stats().sparks<=6);
  walker.update(.016);pose.apply({...action,phase:'approach'},4);assert.equal(tools.visible,false);assert.equal(flame.visible,false);
 }finally{pose.dispose();walker.dispose()}
});
