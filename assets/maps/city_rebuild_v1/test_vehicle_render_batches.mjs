import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createVehicleRenderBatches} from './vehicle_render_batches.mjs';
import {ARTIST_VEHICLE_PROFILES,createArtistVehicle} from './vehicle_fleet_models.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const results=[],vector=new T.Vector3(),expected=new T.Vector3(),matrix=new T.Matrix4();let compared=0;
for(const profile of ARTIST_VEHICLE_PROFILES){
 const bytes=fs.readFileSync(new URL('./models/artist_vehicle_pack/'+profile.modelFile,import.meta.url));
 const gltf=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
 const car=createArtistVehicle(T,RoundedBoxGeometry,gltf.scene,profile),before=new Map(),anchors=JSON.stringify(car.anchors),seats=JSON.stringify(car.seats);
 car.object.traverse(n=>{if(n.isMesh)before.set(n,{material:n.material,geometry:n.geometry,raycast:n.raycast,visible:n.visible,parent:n.parent,layers:n.layers.mask})});
 const helper=createVehicleRenderBatches({THREE:T,root:car.object}),batches=[];car.object.traverse(n=>{if(n.userData.vehicleRenderBatch)batches.push(n)});
 assert.ok(helper.stats.members>=20,profile.id+' effective interior coverage '+JSON.stringify(helper.stats));assert.ok(helper.stats.batches<helper.stats.members/4);
 assert.equal(JSON.stringify(car.anchors),anchors);assert.equal(JSON.stringify(car.seats),seats);
 const sources=[...before].filter(([n,s])=>n.material!==s.material).map(([n])=>n);
 assert.equal(sources.length,helper.stats.members);
 for(const [mesh,snapshot]of before){assert.equal(mesh.geometry,snapshot.geometry);assert.equal(mesh.raycast,snapshot.raycast);assert.equal(mesh.parent,snapshot.parent);assert.equal(mesh.visible,snapshot.visible);assert.equal(mesh.layers.mask,snapshot.layers);if(/Steering|Door|Wheel|Engine|Hood|Trunk/i.test(mesh.name))assert.equal(mesh.material,snapshot.material,'dynamic part not batched '+mesh.name)}
 for(const pose of [{x:0,y:0,z:0,yaw:0},{x:84,y:2.4,z:-19,yaw:1.17}]){
  car.object.position.set(pose.x,pose.y,pose.z);car.object.rotation.set(.07,pose.yaw,-.025);car.update({distance:3,steer:.4});helper.update();car.object.updateMatrixWorld(true);
  // Every batch vertex is an unmodified source vertex transformed inside the
  // same cabin, with the car's current full 3D matrix applied once.
  const available=sources.map(mesh=>({mesh,used:false}));
  for(const batch of batches){
   assert.equal(batch.parent,car.interior.object);assert.equal(batch.raycast(),undefined);
   for(let i=0;i<batch.instanceCount;i++){
    batch.getMatrixAt(i,matrix);const geometryId=batch.getGeometryIdAt(i),range=batch.getGeometryRangeAt(geometryId),position=batch.geometry.attributes.position;
    const source=available.find(item=>!item.used&&before.get(item.mesh).material===batch.material&&item.mesh.geometry.attributes.position.count===range.vertexCount&&new T.Matrix4().copy(batch.matrixWorld).multiply(matrix).equals(item.mesh.matrixWorld));
    // Float texture matrices carry Float32 precision, so compare transforms with tolerance.
    const match=source||available.find(item=>!item.used&&before.get(item.mesh).material===batch.material&&item.mesh.geometry.attributes.position.count===range.vertexCount&&new T.Matrix4().copy(batch.matrixWorld).multiply(matrix).elements.every((v,k)=>Math.abs(v-item.mesh.matrixWorld.elements[k])<2e-5));
    assert.ok(match,profile.id+' exact source match for batch instance');match.used=true;
    const local=match.mesh.geometry.attributes.position;
    for(let v=0;v<range.vertexCount;v++){vector.fromBufferAttribute(position,range.vertexStart+v).applyMatrix4(matrix).applyMatrix4(batch.matrixWorld);expected.fromBufferAttribute(local,v).applyMatrix4(match.mesh.matrixWorld);assert.ok(vector.distanceTo(expected)<3e-5,profile.id+' vertex moved');compared++;}
   }
  }
 }
 const start=performance.now();for(let i=0;i<500;i++)helper.update();const updateMs=(performance.now()-start)/500;
 const target=sources[0],savedMaterial=before.get(target).material;
 // Hidden sources still produce canonical Mesh.raycast results.
 const bounds=new T.Box3().setFromObject(target),center=bounds.getCenter(new T.Vector3()),ray=new T.Raycaster(center.clone().add(new T.Vector3(0,10,0)),new T.Vector3(0,-1,0)),hits=ray.intersectObject(target,false);assert.ok(hits.length,profile.id+' raycast source retained');
 target.visible=false;helper.update();assert.equal(helper.stats.activeMembers,helper.stats.members-1);target.visible=true;helper.update();assert.equal(helper.stats.activeMembers,helper.stats.members);
 target.position.x+=.11;helper.update();car.object.updateMatrixWorld(true);assert.ok(batches.some(batch=>{for(let i=0;i<batch.instanceCount;i++){batch.getMatrixAt(i,matrix);if(new T.Matrix4().copy(batch.matrixWorld).multiply(matrix).elements.every((v,k)=>Math.abs(v-target.matrixWorld.elements[k])<2e-5))return true}return false}),'part transform updated');
 const newMaterial=savedMaterial.clone();target.material=newMaterial;helper.update();assert.equal(helper.stats.fallbackMembers,1);assert.equal(target.material,newMaterial);
 const geometryTarget=sources.find(mesh=>mesh!==target);geometryTarget.geometry.attributes.position.needsUpdate=true;helper.update();assert.equal(helper.stats.fallbackMembers,2);assert.equal(geometryTarget.material,before.get(geometryTarget).material);
 const external=sources.find(mesh=>mesh!==target&&mesh!==geometryTarget);before.get(external).material.color?.set('#341122');helper.update();assert.equal(helper.stats.fallbackMembers,2,'canonical material changes stay live in batch');
 const hiddenMutation=sources.find(mesh=>mesh!==target&&mesh!==geometryTarget&&mesh.material.visible===false);const changed=hiddenMutation.material;changed.color?.set('#7b2631');helper.update();assert.equal(hiddenMutation.material,changed);assert.equal(changed.visible,true,'mutated material returns to normal rendering');
 const sourceDisposals=[];for(const snapshot of before.values())snapshot.geometry.addEventListener('dispose',()=>sourceDisposals.push(snapshot.geometry));
 const batchDisposals=[];for(const b of batches)b.geometry.addEventListener('dispose',()=>batchDisposals.push(b));
 results.push({id:profile.id,members:helper.stats.members,batches:helper.stats.batches,savedCalls:helper.stats.members-helper.stats.batches,updateMs});
 helper.dispose();helper.dispose();assert.equal(sourceDisposals.length,0);assert.equal(batchDisposals.length,batches.length);
 for(const b of batches)assert.equal(b.parent,null);
 for(const [mesh,snapshot]of before)if(mesh!==target&&mesh.material!==changed)assert.equal(mesh.material,snapshot.material,'dispose restores source material ownership');
}
console.log('PASS 12 authored GLB interiors, source identity/raycast/anchors, exact vertices under full car motion, visibility, steering exclusions, transform updates, mutation fallback, idempotent owned disposal');
console.log(JSON.stringify({compared,results},null,2));
