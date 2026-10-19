/** Original Three180 procedural buffers. Output-only; no Godot resource mutation. */
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const dependencies=new Set([fileURLToPath(import.meta.url)]);
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:specifier,context)},load(url,context,next){if(url.startsWith('file:'))dependencies.add(fileURLToPath(url));return next(url,context)}});
const T=await import('three');assert.equal(T.REVISION,'180');
const {RoundedBoxGeometry}=await import('../vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const {createExplorationDecor}=await import('../../assets/maps/city_rebuild_v1/exploration_decor.mjs');
const {createCityRoadDressing}=await import('../../assets/maps/city_rebuild_v1/city_road_dressing.mjs');
const SOURCE='assets/maps/city_rebuild_v1/';
const input=path.join(ROOT,'godot/mafiozi_walk/data/map_editor/catalog.json');dependencies.add(input);
const catalog=JSON.parse(fs.readFileSync(input,'utf8'));
let output=path.join(ROOT,'outputs/map_editor_procedural_source');
for(let i=2;i<process.argv.length;i++){assert.equal(process.argv[i],'--output');output=path.resolve(process.argv[++i]);}
assert(output.startsWith(path.join(ROOT,'outputs')+path.sep),'Output must remain outside Godot project');
fs.mkdirSync(path.join(output,'buffers'),{recursive:true});
const buffers=new Map(),geometries=[],geometryIds=new Map(),materials=[],materialIds=new Map();
function bytesOf(array){assert(ArrayBuffer.isView(array)&&!(array instanceof DataView));return Buffer.from(array.buffer,array.byteOffset,array.byteLength);}
function buffer(array,itemSize=1,normalized=false){const raw=bytesOf(array),hash=sha(raw),file=`buffers/${hash}.bin`;if(!buffers.has(hash)){fs.writeFileSync(path.join(output,file),raw);buffers.set(hash,{sha256:hash,file,bytes:raw.length});}return {buffer:hash,arrayType:array.constructor.name,itemSize,normalized,count:array.length/itemSize};}
function material(m){
 if(materialIds.has(m))return materialIds.get(m);
 assert(m.isMeshStandardMaterial||m.isMeshBasicMaterial);assert.equal(m.onBeforeCompile,T.Material.prototype.onBeforeCompile);
 for(const value of Object.values(m))assert(!value?.isTexture,'Textures require separate admission');
 const id='material-'+materials.length;materialIds.set(m,id);
 materials.push({id,type:m.type,name:m.name,colorLinear:m.color.toArray(),roughness:m.roughness??null,metalness:m.metalness??null,emissiveLinear:m.emissive?.toArray()??[0,0,0],emissiveIntensity:m.emissiveIntensity??0,opacity:m.opacity,transparent:m.transparent,side:m.side,vertexColors:m.vertexColors,flatShading:m.flatShading,depthWrite:m.depthWrite,depthTest:m.depthTest,polygonOffset:m.polygonOffset,polygonOffsetFactor:m.polygonOffsetFactor,polygonOffsetUnits:m.polygonOffsetUnits,blending:m.blending,toneMapped:m.toneMapped,premultipliedAlpha:m.premultipliedAlpha,alphaTest:m.alphaTest,forceSinglePass:m.forceSinglePass,sourceUserData:m.userData});return id;
}
function geometry(g,label){
 if(geometryIds.has(g))return geometryIds.get(g);
 const id='geometry-'+geometries.length;geometryIds.set(g,id);const attributes={};
 for(const [name,attr]of Object.entries(g.attributes)){assert(!attr.isInterleavedBufferAttribute);attributes[name]=buffer(attr.array,attr.itemSize,attr.normalized);}
 geometries.push({id,label,type:g.type,parameters:g.parameters,attributes,index:g.index?buffer(g.index.array,1,g.index.normalized):null,groups:structuredClone(g.groups),drawRange:{start:g.drawRange.start,count:Number.isFinite(g.drawRange.count)?g.drawRange.count:null},bounds:g.boundingBox?{min:g.boundingBox.min.toArray(),max:g.boundingBox.max.toArray()}:null});return id;
}
const captured=[];
const capture=(Class)=>class extends Class{constructor(...args){super(...args);captured.push(this)}};
const wrapped={...T,BoxGeometry:capture(T.BoxGeometry),CylinderGeometry:capture(T.CylinderGeometry),SphereGeometry:capture(T.SphereGeometry),TorusGeometry:capture(T.TorusGeometry),LatheGeometry:capture(T.LatheGeometry)};
const exploration=createExplorationDecor({THREE:wrapped,RoundedBoxGeometry:capture(RoundedBoxGeometry),plan:catalog.generatedPlans.explorationDecor});
assert.equal(captured.length,21,'All7original shapes at3LODs captured');
const shapes=['box','cylinder','taper','leaf','sphere','ring','pine'];
const explorationPrototypes=[];
for(let lod=0;lod<3;lod++)for(let index=0;index<7;index++){const source=captured[lod*7+index];explorationPrototypes.push({shape:shapes[index],lod,geometry:geometry(source,`exploration:${shapes[index]}:lod${lod}`)});}
const explorationBatches=[],objectIndex={};
function indexPart(id,reference){(objectIndex[id]??=[]).push(reference);}
exploration.object.traverse(mesh=>{if(!mesh.isInstancedMesh)return;const key=mesh.name,ids=mesh.userData.objectIds;assert.equal(ids.length,mesh.count);const batch={key,shape:mesh.userData.explorationShape,geometry:geometry(mesh.geometry,key),material:material(mesh.material),count:mesh.count,instanceMatrices:buffer(mesh.instanceMatrix.array,16),instanceColors:buffer(mesh.instanceColor.array,3),objectIds:ids,castShadow:mesh.castShadow,receiveShadow:mesh.receiveShadow,chunk:mesh.parent.name,chunkBounds:mesh.parent.userData.bounds,sourceWorldMatrix:mesh.matrixWorld.toArray()};explorationBatches.push(batch);ids.forEach((id,index)=>indexPart(id,{dataset:'exploration-decor',batch:key,instance:index}));});
assert.equal(new Set(explorationBatches.flatMap(v=>v.objectIds)).size,2440);
// Preserve true BatchedMesh path. Build per-source-ID oracle using the same
// untouched factory rather than assigning parts to a guessed nearby object.
const roadPlan=catalog.generatedPlans.roadDressing;
const road=createCityRoadDressing({THREE:T,plan:roadPlan});
const matrix=new T.Matrix4(),color=new T.Color();
function matrixColorKey(shape,m,c){return shape+':'+sha(Buffer.from(new Float32Array([...m.elements,...c.toArray()]).buffer));}
const roadOracle=new Map();
for(const record of [...roadPlan.signs,...roadPlan.signals]){
 const signal=record.kind==='traffic_signal';const single=createCityRoadDressing({THREE:T,plan:{markings:[],signs:signal?[]:[record],signals:signal?[record]:[]}});
 single.object.traverse(mesh=>{if(!mesh.isBatchedMesh)return;const shape=mesh.name.split(':').at(-1);for(let i=0;i<mesh.userData.roadEquipmentInstances;i++){mesh.getMatrixAt(i,matrix);mesh.getColorAt(i,color);const key=matrixColorKey(shape,matrix,color);if(!roadOracle.has(key))roadOracle.set(key,[]);roadOracle.get(key).push(record.id);}});
 single.dispose();
}
const markingBuckets=new Map();
for(const record of roadPlan.markings){const key=`${Math.floor(record.x/128)},${Math.floor(record.z/128)}:${record.color}`;if(!markingBuckets.has(key))markingBuckets.set(key,[]);markingBuckets.get(key).push(record.id);}
const roadBatches=[],equipmentChunks=[];
const roadRecords=new Map([...roadPlan.signs,...roadPlan.signals].map(v=>[v.id,v]));
road.object.traverse(mesh=>{
 if(!mesh.isMesh)return;const key=mesh.name;
 const batch={key,geometry:geometry(mesh.geometry,key),material:material(mesh.material),castShadow:mesh.castShadow,receiveShadow:mesh.receiveShadow,sourceWorldMatrix:mesh.matrixWorld.toArray(),sourceVisible:mesh.visible};
 if(mesh.isBatchedMesh){const shape=key.split(':').at(-1),count=mesh.userData.roadEquipmentInstances,matrices=new Float32Array(count*16),colors=new Float32Array(count*3),ids=[];
  for(let i=0;i<count;i++){mesh.getMatrixAt(i,matrix);mesh.getColorAt(i,color);matrices.set(matrix.elements,i*16);colors.set(color.toArray(),i*3);const lookup=matrixColorKey(shape,matrix,color),queue=roadOracle.get(lookup);assert(queue?.length,`Unattributed exact road part ${key}:${i}`);const id=queue.shift();ids.push(id);indexPart(id,{dataset:'road-equipment',batch:key,instance:i});}
  Object.assign(batch,{kind:'original-batched-equipment',count,instanceMatrices:buffer(matrices,16),instanceColors:buffer(colors,3),objectIds:ids});
  const chunkGroups=new Map();for(let index=0;index<ids.length;index++){const record=roadRecords.get(ids[index]),chunkKey=`${Math.floor(record.x/128)},${Math.floor(record.z/128)}:${shape}`;if(!chunkGroups.has(chunkKey))chunkGroups.set(chunkKey,[]);chunkGroups.get(chunkKey).push(index);}
  for(const [chunkKey,indices]of chunkGroups){const probe=new T.InstancedMesh(mesh.geometry,mesh.material,indices.length);indices.forEach((index,n)=>probe.setMatrixAt(n,matrix.fromArray(matrices,index*16)));probe.computeBoundingSphere();equipmentChunks.push({key:chunkKey,batch:key,instanceIndices:indices,sourceBoundingSphere:{center:probe.boundingSphere.center.toArray(),radius:probe.boundingSphere.radius}});probe.dispose();}
 }else if(mesh.isInstancedMesh){const ids=roadPlan.signals.map(v=>v.id);Object.assign(batch,{kind:'dynamic-traffic-bulb',count:mesh.count,instanceMatrices:buffer(mesh.instanceMatrix.array,16),objectIds:ids,phase:key.split(':').at(-1)});ids.forEach((id,index)=>indexPart(id,{dataset:'road-signal-phase',batch:key,instance:index}));
 }else{const ids=markingBuckets.get(key.slice('RoadPaint:'.length));assert(ids);assert.equal(mesh.geometry.attributes.position.count,ids.length*6);Object.assign(batch,{kind:'merged-original-paint',count:ids.length,objectIds:ids,verticesPerObject:6});ids.forEach((id,index)=>indexPart(id,{dataset:'road-markings',batch:key,firstVertex:index*6,vertexCount:6}));}
 roadBatches.push(batch);
});
assert([...roadOracle.values()].every(queue=>queue.length===0));
assert.equal(roadPlan.signs.length+roadPlan.signals.length,505);
assert.equal(roadPlan.markings.length,6449);
const receipts=[...dependencies].sort().map(file=>({path:path.relative(ROOT,file).replaceAll('\\','/'),sha256:sha(fs.readFileSync(file)),bytes:fs.statSync(file).size}));
const manifest={schema:'mafiozi.godot.map-editor-procedural-source/v1',status:'SOURCE_BUFFER_PROOF_ONLY_NATIVE_RUNTIME_PENDING',threeRevision:T.REVISION,coordinateContract:{system:'RH Y-up source metres',originM:catalog.originM,metresPerCell:4.1,matrixStorage:'original source-world Float32 column-major4x4; native parent translates by -origin once, do not multiply by4.1 or rewrite/quantize buffers',attributeStorage:'original Float32/Uint index bytes; no normal normalization, tessellation changes or primitive substitution'},dependencies:receipts,buffers:[...buffers.values()].sort((a,b)=>a.sha256.localeCompare(b.sha256)),geometries,materials,exploration:{objects:2440,prototypes:explorationPrototypes,batches:explorationBatches,lodPolicy:{near:64,far:180,hysteresis:8,maxDistance:360,chunkSize:128,rule:'nearest point of original expanded chunk bounds; unchanged sourceupdate hysteresis'},sourceStats:exploration.stats},roads:{signs:445,signals:60,markings:6449,batches:roadBatches,equipmentChunks,cullingPolicy:{chunkSize:128,maxDistance:360,rule:'source bucket sphere distance <360+radius'},dynamicPhaseSource:SOURCE+'city_road_dressing_plan.mjs',sourceStats:road.stats},objectIndex,limitations:['Only original rendering buffers exported. Native shader/material parity, LOD/chunk culling/phase runtime, picking and dependency rebuild remain pending.','No native generated-world colliders/nav/traffic authority activated. ObjectId part indices are exact edit-routing proof, not a completed native editor.','Source depth/polygonOffset/emission/vertex/instance-color behavior must be replicated and LIVE checked; no GPU/FPS claims.']};
const raw=Buffer.from(JSON.stringify(manifest)+'\n');fs.writeFileSync(path.join(output,'manifest.json'),raw);
console.log(JSON.stringify({output,status:manifest.status,geometryCount:geometries.length,bufferCount:buffers.size,bufferBytes:[...buffers.values()].reduce((n,v)=>n+v.bytes,0),manifestBytes:raw.length,materials:materials.length,explorationBatches:explorationBatches.length,roadBatches:roadBatches.length,objects:Object.keys(objectIndex).length,manifestSHA:sha(raw)}));
exploration.dispose();road.dispose();
