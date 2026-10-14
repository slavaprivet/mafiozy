import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..'),output=path.join(ROOT,'outputs/map_editor_procedural_source');
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:specifier,context)}});
const T=await import('three');assert.equal(T.REVISION,'180');
const {RoundedBoxGeometry}=await import('../vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const {createExplorationDecor}=await import('../../assets/maps/city_rebuild_v1/exploration_decor.mjs');
const {createCityRoadDressing}=await import('../../assets/maps/city_rebuild_v1/city_road_dressing.mjs');
const {markingPolygon}=await import('../../assets/maps/city_rebuild_v1/city_road_dressing_plan.mjs');
const catalog=JSON.parse(fs.readFileSync(path.join(ROOT,'godot/mafiozi_walk/data/map_editor/catalog.json'),'utf8'));
const manifest=JSON.parse(fs.readFileSync(path.join(output,'manifest.json'),'utf8'));
const hash=raw=>createHash('sha256').update(raw).digest('hex');
const bytes=array=>Buffer.from(array.buffer,array.byteOffset,array.byteLength);
function exact(descriptor,array){assert.equal(descriptor.arrayType,array.constructor.name);assert.equal(descriptor.buffer,hash(bytes(array)));assert.deepEqual(fs.readFileSync(path.join(output,'buffers',descriptor.buffer+'.bin')),bytes(array));}
function geometryExact(descriptor,g){for(const [name,attr]of Object.entries(g.attributes)){assert.equal(descriptor.attributes[name].itemSize,attr.itemSize);assert.equal(descriptor.attributes[name].normalized,attr.normalized);exact(descriptor.attributes[name],attr.array);}assert.deepEqual(Object.keys(descriptor.attributes).sort(),Object.keys(g.attributes).sort());if(g.index)exact(descriptor.index,g.index.array);else assert.equal(descriptor.index,null);assert.deepEqual(descriptor.groups,g.groups);}
const captured=[],capture=Class=>class extends Class{constructor(...args){super(...args);captured.push(this)}};
const exploration=createExplorationDecor({THREE:{...T,BoxGeometry:capture(T.BoxGeometry),CylinderGeometry:capture(T.CylinderGeometry),SphereGeometry:capture(T.SphereGeometry),TorusGeometry:capture(T.TorusGeometry),LatheGeometry:capture(T.LatheGeometry)},RoundedBoxGeometry:capture(RoundedBoxGeometry),plan:catalog.generatedPlans.explorationDecor});
const road=createCityRoadDressing({THREE:T,plan:catalog.generatedPlans.roadDressing});
test.after(()=>{exploration.dispose();road.dispose();});
test('every binary and source receipt is exact/current and output stays outside res',()=>{
 assert.equal(manifest.threeRevision,'180');assert.equal(manifest.status,'SOURCE_BUFFER_PROOF_ONLY_NATIVE_RUNTIME_PENDING');
 for(const receipt of manifest.buffers){const raw=fs.readFileSync(path.join(output,receipt.file));assert.equal(hash(raw),receipt.sha256);assert.equal(raw.length,receipt.bytes);}
 for(const receipt of manifest.dependencies){const raw=fs.readFileSync(path.resolve(ROOT,receipt.path));assert.equal(hash(raw),receipt.sha256,receipt.path);assert.equal(raw.length,receipt.bytes);}
 assert.equal(manifest.buffers.reduce((n,v)=>n+v.bytes,0),3472204);
});
test('all21 actual original exploration shape/LOD buffers preserve every attribute and index',()=>{
 assert.equal(captured.length,21);assert.equal(manifest.exploration.prototypes.length,21);
 manifest.exploration.prototypes.forEach((prototype,index)=>geometryExact(manifest.geometries.find(v=>v.id===prototype.geometry),captured[index]));
 const box=manifest.geometries.find(v=>v.label==='exploration:box:lod0'),leaf=manifest.geometries.find(v=>v.label==='exploration:leaf:lod0');
 assert.equal(box.type,'RoundedBoxGeometry');assert.equal(box.parameters.segments,2);assert.equal(box.parameters.radius,.08);assert.equal(leaf.parameters.widthSegments,10);assert.equal(leaf.parameters.heightSegments,7);
 assert.deepEqual({...manifest.exploration.lodPolicy,rule:''},{near:64,far:180,hysteresis:8,maxDistance:360,chunkSize:128,rule:''});
});
test('all464 exploration batches preserve exact28718 instance matrices/colors and2440 semantic IDs',()=>{
 let parts=0;const ids=new Set();
 exploration.object.traverse(mesh=>{if(!mesh.isInstancedMesh)return;const batch=manifest.exploration.batches.find(v=>v.key===mesh.name);assert(batch);assert.deepEqual(batch.objectIds,mesh.userData.objectIds);exact(batch.instanceMatrices,mesh.instanceMatrix.array);exact(batch.instanceColors,mesh.instanceColor.array);assert.equal(batch.castShadow,mesh.castShadow);assert.equal(batch.receiveShadow,mesh.receiveShadow);parts+=mesh.count;batch.objectIds.forEach(id=>ids.add(id));});
 assert.equal(parts,28718);assert.equal(ids.size,2440);assert.equal(manifest.exploration.batches.length,464);
});
test('all67 original road batches preserve actual geometry attributes and instance buffers',()=>{
 const matrix=new T.Matrix4(),color=new T.Color();let nodes=0;
 road.object.traverse(mesh=>{if(!mesh.isMesh)return;const batch=manifest.roads.batches.find(v=>v.key===mesh.name);assert(batch);geometryExact(manifest.geometries.find(v=>v.id===batch.geometry),mesh.geometry);if(mesh.isBatchedMesh){const matrices=new Float32Array(batch.count*16),colors=new Float32Array(batch.count*3);for(let i=0;i<batch.count;i++){mesh.getMatrixAt(i,matrix);mesh.getColorAt(i,color);matrices.set(matrix.elements,i*16);colors.set(color.toArray(),i*3);}exact(batch.instanceMatrices,matrices);exact(batch.instanceColors,colors);}else if(mesh.isInstancedMesh)exact(batch.instanceMatrices,mesh.instanceMatrix.array);nodes++;});
 assert.equal(nodes,67);assert.equal(manifest.roads.equipmentChunks.length,road.stats.equipmentSourceChunks);
 assert.equal(new Set(manifest.roads.batches.filter(v=>v.kind==='original-batched-equipment').flatMap(v=>v.objectIds)).size,505);
});
test('all6449 marking IDs route to their exact six original vertices without lookup guessing',()=>{
 const records=new Map(catalog.generatedPlans.roadDressing.markings.map(v=>[v.id,v]));let count=0;
 for(const batch of manifest.roads.batches.filter(v=>v.kind==='merged-original-paint')){const descriptor=manifest.geometries.find(v=>v.id===batch.geometry).attributes.position,raw=fs.readFileSync(path.join(output,'buffers',descriptor.buffer+'.bin'));batch.objectIds.forEach((id,index)=>{const record=records.get(id),polygon=markingPolygon(record),values=[];for(const corner of [0,1,2,0,2,3])values.push(polygon[corner][0],record.y,polygon[corner][1]);assert.deepEqual(raw.subarray(index*18*4,(index+1)*18*4),bytes(new Float32Array(values)));assert.ok(manifest.objectIndex[id].some(v=>v.firstVertex===index*6&&v.batch===batch.key));count++;});}
 assert.equal(count,6449);assert.equal(Object.keys(manifest.objectIndex).length,9394);
});
test('origin uses source metres once, materials preserve original scalar/linear colors',()=>{
 assert.equal(manifest.coordinateContract.metresPerCell,4.1);assert.deepEqual(manifest.coordinateContract.originM,catalog.originM);
 for(const batch of manifest.exploration.batches){const mesh=exploration.object.getObjectByName(batch.key),m=manifest.materials.find(v=>v.id===batch.material);assert.deepEqual(m.colorLinear,mesh.material.color.toArray());assert.equal(m.roughness,mesh.material.roughness);assert.equal(m.metalness,mesh.material.metalness);assert.equal(m.emissiveIntensity,mesh.material.emissiveIntensity);}
 assert.equal(manifest.materials.length,10);assert.ok(manifest.materials.some(v=>v.polygonOffset&&v.polygonOffsetFactor===-1&&v.polygonOffsetUnits===-1));
});
