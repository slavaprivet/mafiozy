import fs from 'node:fs';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {applyNpcAppearance,describeNpcAppearance} from './npc_appearance.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor',threeURL=pathToFileURL(vendor+'/build/three.module.js').href;
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?threeURL:specifier,context);}});
const THREE=await import(threeURL),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const bytes=fs.readFileSync(new URL(NPC_ASSETS.male.url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
function skeletonClone(root){
 const clone=root.clone(true),sourceNodes=[],cloneNodes=[];root.traverse(node=>sourceNodes.push(node));clone.traverse(node=>cloneNodes.push(node));const map=new Map(sourceNodes.map((node,index)=>[node,cloneNodes[index]]));
 root.traverse(node=>{if(!node.isSkinnedMesh)return;const target=map.get(node);target.skeleton=node.skeleton.clone();target.skeleton.bones=node.skeleton.bones.map(bone=>map.get(bone));target.bindMatrix.copy(node.bindMatrix);target.bind(target.skeleton,target.bindMatrix);});
 return clone;
}
let sourceMesh;source.traverse(node=>{if(!sourceMesh&&node.isMesh)sourceMesh=node});assert(sourceMesh);
const sourceTexture=new THREE.DataTexture(new Uint8Array([255,192,128,255]),1,1);sourceTexture.needsUpdate=true;sourceMesh.material=sourceMesh.material.clone();sourceMesh.material.map=sourceTexture;
let geometryDisposed=0,materialDisposed=0,textureDisposed=0;sourceMesh.geometry.addEventListener('dispose',()=>geometryDisposed++);sourceMesh.material.addEventListener('dispose',()=>materialDisposed++);sourceTexture.addEventListener('dispose',()=>textureDisposed++);
const world=new THREE.Scene(),make=id=>{const descriptor=describeNpcAppearance(id,{sex:'male'});return createNpcActor({THREE,scene:world,source,cloneSkeleton:skeletonClone,id,sex:'male',height:descriptor.height,appearanceOwnsResources:true,applyAppearance:scene=>applyNpcAppearance({THREE,scene,descriptor,cloneTextures:true})});};
const first=make('npc-resource-a'),second=make('npc-resource-b'),firstMesh=first.walker.artistContext().scene.getObjectByName(sourceMesh.name),secondMesh=second.walker.artistContext().scene.getObjectByName(sourceMesh.name);
assert.notEqual(firstMesh.geometry,sourceMesh.geometry);assert.notEqual(firstMesh.material,sourceMesh.material);assert.notEqual(firstMesh.material.map,sourceTexture);assert.notEqual(firstMesh.geometry,secondMesh.geometry);assert.notEqual(firstMesh.material,secondMesh.material);
first.dispose();assert.equal(geometryDisposed,0);assert.equal(materialDisposed,0);assert.equal(textureDisposed,0,'disposing one actor must not touch template resources');second.update(.1,{position:{x:2,y:0,z:1},moving:true});assert.equal(second.object.parent,world);second.dispose();assert.equal(world.children.length,0);
sourceMesh.material.dispose();sourceTexture.dispose();
console.log('PASS actor appearance skips temporary private resources while preserving per-NPC isolation and template ownership');
