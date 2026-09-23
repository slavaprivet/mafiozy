import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {ARTIST_VEHICLE_PROFILES,createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createVehicleRenderBatches,getVehicleRenderSourceMaterial} from './vehicle_render_batches.mjs';
import {batchedShadowBoundsCurrent} from './shadow_bounds_stamp.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import('three'),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js')),{RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const loader=new GLTFLoader(),matrix=new T.Matrix4(),inverse=new T.Matrix4(),point=new T.Vector3(),rows=[];let comparedVertices=0;
const visible=mesh=>{for(let n=mesh;n;n=n.parent)if(!n.visible)return false;return true};
function census(root){const result={main:0,shadow:0};root.traverse(mesh=>{if(!mesh.isMesh||!visible(mesh))return;for(const m of Array.isArray(mesh.material)?mesh.material:[mesh.material])if(m?.visible){result.main+=m.transparent&&m.side===T.DoubleSide&&!m.forceSinglePass?2:1;if(mesh.castShadow)result.shadow++;}});return result;}
function rootDoorSources(car,saved){return [...saved].filter(([mesh])=>{for(let n=mesh.parent;n&&n!==car.object;n=n.parent)if(n.userData.vehicleDoorId)return true;return false;}).map(([mesh])=>mesh);}
function verifyBatches(car,batches,saved){
 car.object.updateMatrixWorld(true);const available=rootDoorSources(car,saved).map(mesh=>({mesh,used:false}));
 for(const batch of batches){assert.equal(batch.parent,car.object);assert.equal(batch.userData.vehicleRootDoorRenderBatch,true);assert.equal(batch.raycast(),undefined);assert(batchedShadowBoundsCurrent(batch));inverse.copy(batch.matrixWorld).invert();
  for(let i=0;i<batch.instanceCount;i++){batch.getMatrixAt(i,matrix);const range=batch.getGeometryRangeAt(batch.getGeometryIdAt(i)),world=matrix.clone().premultiply(batch.matrixWorld),match=available.find(item=>!item.used&&saved.get(item.mesh).material===batch.material&&item.mesh.geometry.attributes.position.count===range.vertexCount&&world.elements.every((v,k)=>Math.abs(v-item.mesh.matrixWorld.elements[k])<2e-5));assert(match,'every root-door instance has one exact source');match.used=true;assert.equal(batch.castShadow,match.mesh.castShadow);assert.equal(batch.receiveShadow,match.mesh.receiveShadow);assert.equal(batch.layers.mask,match.mesh.layers.mask);assert.equal(batch.renderOrder,match.mesh.renderOrder);
   const source=match.mesh.geometry.attributes.position,packed=batch.geometry.attributes.position;for(let v=0;v<range.vertexCount;v++){point.fromBufferAttribute(packed,range.vertexStart+v).applyMatrix4(matrix);assert(batch.boundingBox.containsPoint(point)||batch.boundingBox.distanceToPoint(point)<3e-5,'current aggregate bounds contain moved door vertex');const expected=new T.Vector3().fromBufferAttribute(source,v).applyMatrix4(match.mesh.matrixWorld),actual=new T.Vector3().fromBufferAttribute(packed,range.vertexStart+v).applyMatrix4(world);assert(actual.distanceTo(expected)<3e-5);comparedVertices++;}
  }
 }
}
for(const profile of ARTIST_VEHICLE_PROFILES){
 const bytes=readFileSync(new URL('./models/artist_vehicle_pack/'+profile.modelFile,import.meta.url)),gltf=await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
 const oldCar=createArtistVehicle(T,RoundedBoxGeometry,gltf.scene,profile),newCar=createArtistVehicle(T,RoundedBoxGeometry,gltf.scene,profile),saved=new Map();newCar.object.traverse(mesh=>{if(mesh.isMesh)saved.set(mesh,{material:mesh.material,geometry:mesh.geometry,parent:mesh.parent,raycast:mesh.raycast,layers:mesh.layers.mask})});
 const oldApi=createVehicleRenderBatches({THREE:T,root:oldCar.object,includeDoors:true,includeBody:true}),api=createVehicleRenderBatches({THREE:T,root:newCar.object,includeDoors:true,includeBody:true,rootDoorBatches:true}),batches=[];newCar.object.traverse(n=>{if(n.userData.vehicleRootDoorRenderBatch)batches.push(n)});
 assert.equal(oldApi.stats.rootDoorBatching,false);assert.equal(api.stats.rootDoorBatching,true);assert(api.stats.rootDoorMembers>oldApi.stats.doorMembers);assert(api.stats.rootDoorBatches<api.stats.rootDoorMembers);
 const before=census(oldCar.object),after=census(newCar.object),handles={};for(const id of newCar.doors.keys())handles[id]=newCar.getDoorHandleWorld(id,new T.Vector3()).clone();
 const amounts=[.19,.43,.67,.91];let index=0;for(const id of newCar.doors.keys()){newCar.setDoorById(amounts[index],id);oldCar.setDoorById(amounts[index],id);index++;}api.update();
 for(const id of newCar.doors.keys())assert(newCar.getDoorHandleWorld(id,new T.Vector3()).distanceTo(oldCar.getDoorHandleWorld(id,new T.Vector3()))<1e-9,'source handle follows independent door pivot');verifyBatches(newCar,batches,saved);
 // Closing all four doors and updating in the same turn restores exact closed matrices.
 for(const id of newCar.doors.keys())newCar.setDoorById(0,id);api.update();verifyBatches(newCar,batches,saved);for(const id of newCar.doors.keys())assert(newCar.getDoorHandleWorld(id,new T.Vector3()).distanceTo(handles[id])<1e-9);
 for(const [mesh,snapshot]of saved){assert.equal(mesh.geometry,snapshot.geometry);assert.equal(mesh.parent,snapshot.parent);assert.equal(mesh.raycast,snapshot.raycast);assert.equal(mesh.layers.mask,snapshot.layers);}
 rows.push({id:profile.id,before,after,rootDoorMembers:api.stats.rootDoorMembers,rootDoorBatches:api.stats.rootDoorBatches,savedMain:before.main-after.main,savedShadow:before.shadow-after.shadow});
 oldApi.dispose();api.dispose();const rebuilt=createVehicleRenderBatches({THREE:T,root:newCar.object,includeDoors:true,includeBody:true,rootDoorBatches:true});assert.equal(rebuilt.stats.rootDoorMembers,rows.at(-1).rootDoorMembers,'dispose permits exact rebuild');rebuilt.dispose();for(const [mesh,snapshot]of saved)assert.equal(mesh.material,snapshot.material);
}
const total=rows.reduce((sum,row)=>{for(const key of ['savedMain','savedShadow'])sum[key]+=row[key];return sum;},{savedMain:0,savedShadow:0});assert.deepEqual(total,{savedMain:197,savedShadow:197});
assert.equal(rows.reduce((n,r)=>n+r.before.main,0),1314);assert.equal(rows.reduce((n,r)=>n+r.after.main,0),1117);assert.equal(rows.reduce((n,r)=>n+r.before.shadow,0),1216);assert.equal(rows.reduce((n,r)=>n+r.after.shadow,0),1019);
const sumScenario=list=>list.reduce((sum,row)=>{for(const phase of ['before','after'])for(const pass of ['main','shadow'])sum[phase][pass]+=row[phase][pass];return sum;},{before:{main:0,shadow:0},after:{main:0,shadow:0}}),representative18=sumScenario([...rows,...rows.slice(0,6)]),ceiling96=sumScenario(Array.from({length:8},()=>rows).flat());
assert.deepEqual(representative18,{before:{main:1976,shadow:1832},after:{main:1653,shadow:1509}});assert.deepEqual(ceiling96,{before:{main:10512,shadow:9728},after:{main:8936,shadow:8152}});

function synthetic({detailOptimization=true}={}){
 const root=new T.Group(),material=new T.MeshStandardMaterial({color:'#537a91'}),doors=[];root.name='Vehicle_test';
 for(const [i,id]of ['front_left','front_right','rear_left','rear_right'].entries()){const door=new T.Group();door.name='Door_'+id;door.userData.vehicleDoorId=id;door.position.set(i-1.5,.4,i*.2);root.add(door);doors.push(door);for(let j=0;j<2;j++){const mesh=new T.Mesh(new T.BoxGeometry(.2,.3,.1),material);mesh.name='Door_handle_'+i+'_'+j;mesh.position.x=j*.3;mesh.castShadow=mesh.receiveShadow=true;door.add(mesh);}}
 const light=new T.Mesh(new T.BoxGeometry(),material);light.name='Door_Light';doors[0].add(light);const damage=new T.Mesh(new T.BoxGeometry(),material);damage.name='Door_trim';damage.userData.damagePart=true;doors[1].add(damage);
 const api=createVehicleRenderBatches({THREE:T,root,includeDoors:true,includeBody:true,rootDoorBatches:true,detailOptimization});return {root,material,doors,light,damage,api,members:doors.flatMap(door=>door.children.filter(n=>n!==light&&n!==damage))};
}
{
 const f=synthetic();assert.equal(f.api.stats.rootDoorMembers,8);assert.equal(f.api.stats.rootDoorBatches,1);assert.equal(f.light.material,f.material);assert.equal(f.damage.material,f.material,'lights and damage stay outside traffic door batching');const batch=f.root.children.find(n=>n.userData.vehicleRootDoorRenderBatch);assert.equal(batch.material,f.material);f.material.color.set('#a34d6f');f.api.update();assert.equal(batch.material.color.getHexString(),'a34d6f','canonical color stays live without instance colour overrides');assert.equal(f.api.stats.fallbackMembers,0);
 f.api.setDetailOptimizationEnabled(false);assert(f.members.every(mesh=>mesh.material===f.material));assert.equal(batch.visible,false);f.members[0].layers.set(3);f.api.setDetailOptimizationEnabled(true);assert.equal(f.members[0].material,f.material);assert.equal(f.api.stats.fallbackMembers,1,'mutation while disabled fails open');f.api.dispose();
}
for(const [label,mutate]of [
 ['material',(mesh,f)=>{mesh.material=f.material.clone()}],['geometry',mesh=>{mesh.geometry=mesh.geometry.clone()}],['layers',mesh=>mesh.layers.set(2)],['renderOrder',mesh=>mesh.renderOrder++],
 ['detach and reattach',(mesh,f)=>{const parent=mesh.parent;mesh.removeFromParent();f.api.update();parent.add(mesh)}],['move to another door',(mesh,f)=>f.doors[1].add(mesh)],['detach whole door',(mesh,f)=>{const door=mesh.parent;door.removeFromParent();f.api.update();f.root.add(door)}]
]){
 const f=synthetic(),mesh=f.members[0];mutate(mesh,f);f.api.update();assert.equal(mesh.material.visible,true,label+' restores source rendering');assert(f.api.stats.fallbackMembers>=1);const fallen=f.api.stats.fallbackMembers;f.api.update();assert.equal(f.api.stats.fallbackMembers,fallen,label+' is permanently fail-open after reattach');f.api.dispose();
}
{
 const f=synthetic({detailOptimization:false});assert.equal(f.api.stats.rootDoorBatching,false);assert.equal(f.api.stats.rootDoorBatches,0);assert.equal(f.root.children.some(n=>n.userData.vehicleRootDoorRenderBatch),false,'no-multiDraw capability path allocates no new root-door batches');f.api.dispose();
}
console.log(JSON.stringify({passed:true,base:'f8f1a6e87341e468087fa7dd2e36939d188fbe2f',models:rows.length,rows,total,representative18,ceiling96,comparedVertices,limits:['CPU/structural actual Three and GLB verification; no browser/GPU/FPS claim','18 is one actual instance of every profile plus a second instance of the first six, not the unknown LIVE profile mix','96 is eight actual instances of every profile before view/shadow culling','root-door path is traffic-only and multi-draw capability gated']},null,2));
