import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import {pathToFileURL} from 'node:url';import {registerHooks} from 'node:module';import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';import {createMercenaryPose} from './mercenary_pose.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor',threeUrl=pathToFileURL(vendor+'/build/three.module.js').href;
registerHooks({resolve(s,c,n){return n(s==='three'?threeUrl:s,c)}});const THREE=await import(threeUrl),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
function clone(root){
 const clone=root.clone(true),sourceNodes=[],cloneNodes=[];root.traverse(node=>sourceNodes.push(node));clone.traverse(node=>cloneNodes.push(node));const map=new Map(sourceNodes.map((node,index)=>[node,cloneNodes[index]]));
 root.traverse(node=>{if(!node.isSkinnedMesh)return;const target=map.get(node);target.skeleton=node.skeleton.clone();target.skeleton.bones=node.skeleton.bones.map(bone=>map.get(bone));target.bindMatrix.copy(node.bindMatrix);target.bind(target.skeleton,target.bindMatrix);});
 return clone;
}

for(const[sex,asset]of Object.entries(NPC_ASSETS))test(sex+' hired bruiser shape preserves canonical bones and door kick reaches source contact',async()=>{
 const bytes=fs.readFileSync(new URL(asset.url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const actor=createNpcActor({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:'crew_test',sex}),c=actor.walker.artistContext();
 const meshes=[];c.scene.traverse(o=>{if(o.isSkinnedMesh)meshes.push(o)});const initial=meshes.map(m=>Float32Array.from(m.geometry.attributes.position.array));
 actor.update(0,{life:{mercenaryCandidate:true,mercenary:{profession:'bruiser'}}});assert(meshes.every((m,i)=>m.geometry.attributes.position.array.every((v,j)=>v===initial[i][j])),'candidate unchanged');
 actor.update(0,{});const headY=c.bones.head.getWorldPosition(new THREE.Vector3()).y;const anchors=Object.fromEntries(['foot_l','foot_r','socket_hand_l','socket_hand_r','socket_weapon'].map(k=>[k,c.bones[k].matrixWorld.toArray()]));
 actor.update(0,{life:{mercenary:{profession:'bruiser',status:'active'}}});assert(meshes.some((m,i)=>m.geometry.attributes.position.array.some((v,j)=>v!==initial[i][j])),'hired body expanded');
 for(const[k,m]of Object.entries(anchors))assert.deepEqual(c.bones[k].matrixWorld.toArray(),m,k+' anchor unchanged');assert.deepEqual(actor.object.scale.toArray(),[1,1,1]);assert(c.bones.head.getWorldPosition(new THREE.Vector3()).y<headY-.025,'visibly shorter neck without moving feet or hands');
 actor.update(0,{});assert(meshes.every((m,i)=>m.geometry.attributes.position.array.every((v,j)=>v===initial[i][j])),'ordinary shape restored exactly');
 actor.update(0,{position:{x:170,y:2,z:180},yaw:1.2,life:{mercenary:{profession:'bruiser',status:'active'}}});
 const farActor=createNpcActor({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:'crew_far',sex});
 farActor.update(0,{position:{x:170,y:2,z:180},yaw:1.2,life:{mercenary:{profession:'bruiser',status:'active'}}});
 const farMeshes=[];farActor.walker.artistContext().scene.traverse(o=>{if(o.isSkinnedMesh)farMeshes.push(o)});
 assert(meshes.every((m,i)=>m.geometry.attributes.position.array.every((v,j)=>Math.abs(v-farMeshes[i].geometry.attributes.position.array[j])<1e-6)),'shape independent of first world position and yaw');farActor.dispose();
 actor.update(0,{position:{x:0,y:0,z:0},yaw:0,life:{}});
 const pose=createMercenaryPose({THREE,walker:actor.walker}),point=new THREE.Vector3(0,.85,1),action={kind:'breach_door',phase:'working',workPoint:point,workNormal:{x:0,y:0,z:-1}};
 actor.walker.update(0);const foot=c.bones.foot_l.getWorldPosition(new THREE.Vector3()),root=actor.object.position.toArray(),base=c.bones.foot_r.getWorldPosition(new THREE.Vector3());
 const legRest=Object.fromEntries(['shin_r','foot_r'].map(n=>[n,{p:c.rest[n].p.toArray(),matrix:c.rest[n].matrix.toArray()}]));
 for(const progress of[.1,.6,.8,.9,.95,.975,.99]){actor.walker.update(0);assert(pose.apply({...action,progress},progress*2.5));assert.deepEqual(actor.object.position.toArray(),root);for(const[n,r]of Object.entries(legRest)){assert.deepEqual(c.rest[n].p.toArray(),r.p);assert.deepEqual(c.rest[n].matrix.toArray(),r.matrix);}if(progress===.9)assert.equal(pose.stats().kickExtension,1);if(progress===.975)assert.equal(pose.stats().kickExtension,1.4);assert(c.bones.foot_l.getWorldPosition(new THREE.Vector3()).distanceTo(foot)<.015,'support foot planted '+progress);if(progress===.975){let front=-Infinity;for(const mesh of meshes){mesh.skeleton.update();const si=mesh.geometry.attributes.skinIndex,sw=mesh.geometry.attributes.skinWeight;for(let vi=0;vi<si.count;vi++){let weight=0;for(let j=0;j<4;j++)if(mesh.skeleton.bones[si.getComponent(vi,j)].name==='foot_r')weight+=sw.getComponent(vi,j);if(weight<.5)continue;const v=mesh.getVertexPosition(vi,new THREE.Vector3());mesh.localToWorld(v);front=Math.max(front,v.z);}}console.log(sex,pose.stats(),'shoe front',front);assert(Math.abs(front-point.z)<.025,'actual shoe reaches door plane within 2.5cm');assert(pose.stats().contactError<.16,'heel reaches source door');}}
 actor.walker.update(0);pose.apply(null,3);assert(c.bones.foot_r.getWorldPosition(new THREE.Vector3()).distanceTo(base)<1e-6);pose.dispose();actor.dispose();
});
