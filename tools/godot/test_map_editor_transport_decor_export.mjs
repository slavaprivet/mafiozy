import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..'),output=path.join(root,'outputs/map_editor_transport_decor_source');
const manifest=JSON.parse(fs.readFileSync(path.join(output,'manifest.json'),'utf8'));
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
let checks=0;const check=(condition,message)=>{checks++;assert(condition,message)};
const equal=(a,b,message)=>{checks++;assert.deepEqual(a,b,message)};
equal(manifest.counts,{parkingLots:39,parkingBays:59,parkingSurfaces:78,parkingSigns:57,railAlignment:1,railStations:2,railCrossings:12,railSignals:17},'Exact source semantic counts');
equal(manifest.semanticObjects.length,265);equal(Object.keys(manifest.objectIndex).length,265);
const buffers=new Map(manifest.buffers.map(b=>[b.sha256,b]));
for(const descriptor of manifest.buffers){const bytes=fs.readFileSync(path.join(output,descriptor.file));equal(bytes.length,descriptor.bytes,'Exact original raw byte length');equal(sha(bytes),descriptor.sha256,'Original buffer checksum');}
const typedNames={Float32Array:4,Float64Array:8,Uint32Array:4,Uint16Array:2,Uint8Array:1,Int32Array:4,Int16Array:2,Int8Array:1};
function validateAttribute(attribute){const descriptor=buffers.get(attribute.buffer);check(!!descriptor,'Every attr resolves existing buffer');equal(descriptor.bytes,attribute.count*attribute.itemSize*typedNames[attribute.arrayType],'Typed count/itemSize exact');const bytes=fs.readFileSync(path.join(output,descriptor.file));if(attribute.arrayType==='Float32Array'){for(let i=0;i<bytes.length;i+=4)check(Number.isFinite(bytes.readFloatLE(i)),'Finite original Float32');}return bytes;}
const geometry=new Map(manifest.geometries.map(g=>[g.id,g])),materials=new Map(manifest.materials.map(m=>[m.id,m]));
for(const item of manifest.geometries){for(const attribute of Object.values(item.attributes))validateAttribute(attribute);if(item.index)validateAttribute(item.index);for(const group of item.groups){check(group.start>=0&&group.count>=0,'Original geometry group valid');}}
const allBatches=[...manifest.parking.batches,...manifest.railway.batches],batches=new Map(allBatches.map(b=>[b.key,b]));
for(const batch of allBatches){check(geometry.has(batch.geometry)&&materials.has(batch.material),'Batch binds exact source geometry/material');equal(batch.sourceWorldMatrix.length,16);check(batch.sourceWorldMatrix.every(Number.isFinite),'Finite exact source parent transform');if(batch.instanceMatrices){check(batch.instanceMatrices.count>=batch.count,'Original matrix capacity retains active count');if(batch.instanceCapacity!==undefined)equal(batch.instanceMatrices.count,batch.instanceCapacity,'Raw full capacity preserved; native draws active batch.count only');validateAttribute(batch.instanceMatrices);}if(batch.instanceColors){equal(batch.instanceColors.count,batch.count);validateAttribute(batch.instanceColors);}equal(batch.objectKeys.length,batch.count);for(const key of batch.objectKeys)check(manifest.objectIndex[key]?.length>0,'Every part owns stable semantic key');}
for(const object of manifest.semanticObjects){check(object.key===`${object.dataset}:${object.id}`,'Stable source ID, no positional substitution');check(object.dependencies.length>0,'Gameplay dependency graph preserved');check(manifest.objectIndex[object.key].length>0,'Each of265 semantic objects has geometry');for(const part of manifest.objectIndex[object.key]){const batch=batches.get(part.batch);check(!!batch,'Part resolves exact original batch');equal(batch.objectKeys[part.mesh?0:part.instance],object.key,'Bidirectional exact part routing');}}
equal(manifest.parking.sourcePlan.lots.length,39);equal(manifest.parking.sourcePlan.bays.length,59);equal(manifest.parking.sourcePlan.surfaceRects.length,78);equal(manifest.parking.sourcePlan.signs.length,57);
for(const lot of manifest.parking.sourcePlan.lots){check(lot.entryPaths.length>0,'Original verified entry curves retained');equal(lot.exitRule,'yield_to_road_and_pedestrians','Exit priority retained');check(Array.isArray(lot.servedBuildingIds),'Ownership/building association retained');}
check(manifest.parking.sourcePlan.walkingRoutes.length>0,'Pedestrian/entrance walking links retained');check(manifest.parking.sourcePlan.colliders.length>0,'Parking source colliders retained, NOT autoactivated');
for(const bay of manifest.parking.sourcePlan.bays)equal(manifest.objectIndex[`parking-bays:${bay.id}`].length,4,'Original four painted P-mark components');
equal(manifest.railway.signalLamps.length,24);equal(manifest.railway.trainCars.length,3);equal(manifest.railway.sourceMotionSnapshot.cars.length,3);
equal(manifest.textures.length,2,'Both original station CanvasTextures retained as recipe');
const sourceStations=new Set(manifest.railway.sourcePlan.stations.map(s=>s.name));
for(const texture of manifest.textures){equal(texture.image.width,1024);equal(texture.image.height,192);equal(texture.image.rasterPixelsStatus,'NOT_CAPTURED_REQUIRES_EXACT_BROWSER_ARIAL_CANVAS_PARITY');const text=texture.image.recipe.find(r=>r.operation==='fillText');check(sourceStations.has(text.args[0]),'Original Cyrillic station label text');equal(text.state.font,'600 66px Arial','Exact source font');equal(text.args.slice(1),[512,96,950]);}
check(manifest.materials.every(m=>m.type==='MeshStandardMaterial'||m.type==='MeshBasicMaterial'),'Original material type');
for(const receipt of manifest.dependencies){const bytes=fs.readFileSync(path.resolve(root,receipt.path));equal(bytes.length,receipt.bytes,'Source dependency unchanged since capture');equal(sha(bytes),receipt.sha256,'Source SHA still current');}
equal(manifest.oracleChecks.rawBufferReadback,manifest.buffers.length);equal(manifest.oracleChecks.parkingParts,manifest.parking.batches.reduce((n,b)=>n+b.count,0));
check(manifest.limitations.some(s=>s.includes('NOT_CAPTURED')),'Incomplete pixel parity explicitly reported');check(manifest.limitations.some(s=>s.includes('No native')),'No false native runtime/FPS claim');
// Independent unwrapped original factory run: exact bytes, not analytic proxies.
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c)}});
const T=await import('three'),{GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')).href);
const {createCityParking}=await import(pathToFileURL(path.join(root,'assets/maps/city_rebuild_v1/city_parking.mjs')).href);
const {createExplorationRailway}=await import(pathToFileURL(path.join(root,'assets/maps/city_rebuild_v1/exploration_railway.mjs')).href);
const {createExplorationRailwayPlan}=await import(pathToFileURL(path.join(root,'assets/maps/city_rebuild_v1/exploration_railway_plan.mjs')).href);
const topology=JSON.parse(fs.readFileSync(path.join(root,'assets/maps/city_rebuild_v1/topology_for_placement.json'),'utf8'));
const railPlan=createExplorationRailwayPlan({topology});
const directParking=createCityParking({THREE:T,plan:manifest.parking.sourcePlan});
const oldDocument=globalThis.document;
globalThis.document={createElement(tag){equal(tag,'canvas');return {width:0,height:0,getContext(){return {fillRect(){},strokeRect(){},fillText(){}}}}}};
const trainBytes=fs.readFileSync(path.join(root,manifest.railway.trainAsset.path));
let directRail;
try{directRail=await createExplorationRailway({THREE:T,plan:railPlan,loader:{loadAsync:async()=>new GLTFLoader().parseAsync(trainBytes.buffer.slice(trainBytes.byteOffset,trainBytes.byteOffset+trainBytes.byteLength),'')}});}finally{if(oldDocument===undefined)delete globalThis.document;else globalThis.document=oldDocument;}
function rawArray(array){return Buffer.from(array.buffer,array.byteOffset,array.byteLength)}
function exactGeometry(source,reference){const expected=geometry.get(reference.geometry);equal(Object.keys(source.attributes),Object.keys(expected.attributes),'Unwrapped original attribute names');for(const [key,attribute]of Object.entries(source.attributes))equal(sha(rawArray(attribute.array)),expected.attributes[key].buffer,'Unwrapped original attribute bytes');equal(source.index?sha(rawArray(source.index.array)):null,expected.index?.buffer??null,'Unwrapped original index bytes');equal(source.groups,expected.groups,'Unwrapped source primitive groups');}
function exactMaterial(source,reference){const expected=materials.get(reference.material);equal(source.color.toArray(),expected.colorLinear,'Unwrapped source linear color');equal(source.roughness??null,expected.roughness);equal(source.metalness??null,expected.metalness);equal(source.opacity,expected.opacity);equal(source.transparent,expected.transparent);equal(source.side,expected.side);equal(source.emissive?.toArray()??[0,0,0],expected.emissiveLinear);equal(source.emissiveIntensity??0,expected.emissiveIntensity);}
directParking.object.updateMatrixWorld(true);
const parkingActual=[];directParking.object.traverse(mesh=>{if(mesh.isMesh)parkingActual.push(mesh)});
equal(parkingActual.length,manifest.parking.batches.length);
parkingActual.forEach((mesh,index)=>{const expected=manifest.parking.batches[index];equal(mesh.name,expected.key);exactGeometry(mesh.geometry,expected);exactMaterial(mesh.material,expected);equal(mesh.count,expected.count);equal(sha(rawArray(mesh.instanceMatrix.array)),expected.instanceMatrices.buffer,'Direct original parking instance bytes');equal(sha(rawArray(mesh.instanceColor.array)),expected.instanceColors.buffer,'Direct original parking color bytes');equal(mesh.matrixWorld.toArray(),expected.sourceWorldMatrix);});
directRail.object.updateMatrixWorld(true);
const railActual=[];directRail.object.traverse(mesh=>{if(mesh.isMesh)railActual.push(mesh)});
equal(railActual.length,manifest.railway.batches.length);
railActual.forEach((mesh,index)=>{const expected=manifest.railway.batches[index];equal(mesh.name,expected.name);exactGeometry(mesh.geometry,expected);exactMaterial(mesh.material,expected);equal(mesh.matrixWorld.toArray(),expected.sourceWorldMatrix,'Direct original rail transform');if(mesh.isInstancedMesh){equal(mesh.count,expected.count);equal(sha(rawArray(mesh.instanceMatrix.array)),expected.instanceMatrices.buffer,'Direct original railway instance bytes');}});
directParking.dispose();directRail.dispose();
console.log(JSON.stringify({status:'PASS',checks,objects:265,buffers:manifest.buffers.length,parkingParts:manifest.oracleChecks.parkingParts,railStaticParts:manifest.oracleChecks.railStaticParts,railBatches:manifest.railway.batches.length,manifestSHA:sha(fs.readFileSync(path.join(output,'manifest.json')))}));

