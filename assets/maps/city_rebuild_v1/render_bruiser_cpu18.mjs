import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import {pathToFileURL} from 'node:url';import {registerHooks} from 'node:module';import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';import {createMercenaryPose} from './mercenary_pose.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor',threeUrl=pathToFileURL(vendor+'/build/three.module.js').href;
registerHooks({resolve(s,c,n){return n(s==='three'?threeUrl:s,c)}});const THREE=await import(threeUrl),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
function clone(root){
 const clone=root.clone(true),sourceNodes=[],cloneNodes=[];root.traverse(node=>sourceNodes.push(node));clone.traverse(node=>cloneNodes.push(node));const map=new Map(sourceNodes.map((node,index)=>[node,cloneNodes[index]]));
 root.traverse(node=>{if(!node.isSkinnedMesh)return;const target=map.get(node);target.skeleton=node.skeleton.clone();target.skeleton.bones=node.skeleton.bones.map(bone=>map.get(bone));target.bindMatrix.copy(node.bindMatrix);target.bind(target.skeleton,target.bindMatrix);});
 return clone;
}


import {applyNpcAppearance,describeNpcAppearance} from './npc_appearance.mjs';
const output=[];
for(const[sex,asset]of Object.entries(NPC_ASSETS)){
 const bytes=fs.readFileSync(new URL(asset.url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 for(const bulky of[false,true]){
 const descriptor=describeNpcAppearance('bruiser-visual-'+sex,{sex,height:1.9,build:1,hairstyle:'short',outfit:'#334851'}),actor=createNpcActor({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:'crew_'+sex,sex,appearanceOwnsResources:true,applyAppearance:scene=>applyNpcAppearance({THREE,scene,descriptor})});
 actor.update(0,{life:bulky?{mercenary:{profession:'bruiser',status:'active'}}:{}});actor.object.updateMatrixWorld(true);const triangles=[];
 actor.object.traverse(mesh=>{if(!mesh.isMesh||!mesh.visible)return;mesh.skeleton?.update();const g=mesh.geometry,p=g.attributes.position,index=g.index,color=g.attributes.color,material=Array.isArray(mesh.material)?mesh.material[0]:mesh.material;
 const vertices=Array.from({length:p.count},(_,i)=>{const v=mesh.isSkinnedMesh?mesh.getVertexPosition(i,new THREE.Vector3()):new THREE.Vector3().fromBufferAttribute(p,i);mesh.localToWorld(v);return v.toArray();});
 for(let i=0;i<(index?index.count:p.count);i+=3){const ids=[0,1,2].map(j=>index?index.getX(i+j):i+j),rgb=new THREE.Color(0,0,0);for(const vi of ids){const c=color?new THREE.Color().fromBufferAttribute(color,vi):new THREE.Color(1,1,1);if(material.color)c.multiply(material.color);rgb.add(c);}rgb.multiplyScalar(1/3).convertLinearToSRGB();triangles.push({p:ids.map(i=>vertices[i]),c:rgb.toArray()});}
 });output.push({name:sex+(bulky?' bruiser':' normal'),triangles});actor.dispose();
 }}fs.writeFileSync('docs/ai/bruiser_visual18_geometry.json',JSON.stringify(output));
