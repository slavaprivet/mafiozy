import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../../..');
export const pins=Object.freeze({
 manifest:'82e6ef82a824e002d0f315972ffd3d967102b7c36256371699992bcfb76220dd',
 catalog:'ae089d73eb61131bc6a38ccc6a2b9b18639f7bd8b65079f7c15c1e1cda9cde6e',
 factory:'280880c927809d0d773c3175cdf43fc7534a772af286d77fbf0b50a85fe53628',
 registry:'34d880d1d79b5b58f28c10fb2b797e2a1ab2b9c6a86f6927d4cd9c06e7595073'
});
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const source=path.join(root,'outputs','map_editor_procedural_source');
const catalogPath=path.join(root,'godot','mafiozi_walk','data','map_editor','catalog.json');
const factoryPath=path.join(root,'tools','godot','map_editor_procedural_native_v3','scripts','procedural_factory.gd');
const registryPath=path.join(root,'tools','godot','map_editor_procedural_native_v3','scripts','procedural_registry.gd');
function requirePin(location,digest){
 const bytes=fs.readFileSync(location);
 if(sha(bytes)!==digest)throw Error(`Pinned source drift: ${location}`);
 return bytes;
}
function safeBufferPath(entry){
 if(!/^[0-9a-f]{64}$/.test(entry.sha256)||entry.file!==`buffers/${entry.sha256}.bin`||!Number.isSafeInteger(entry.bytes)||entry.bytes<0)throw Error('Unsafe buffer receipt');
 const location=path.join(source,entry.file);
 if(!location.startsWith(source+path.sep))throw Error('Unsafe buffer path');
 for(let cursor=location;cursor!==path.dirname(source);cursor=path.dirname(cursor))if(fs.lstatSync(cursor).isSymbolicLink())throw Error('Symlinked source buffer path');
 return location;
}
export function loadPinned(){
 const manifest=JSON.parse(requirePin(path.join(source,'manifest.json'),pins.manifest));
 const catalog=JSON.parse(requirePin(catalogPath,pins.catalog));
 requirePin(factoryPath,pins.factory);requirePin(registryPath,pins.registry);
 if(manifest.schema!=='mafiozi.godot.map-editor-procedural-source/v1'||String(manifest.threeRevision)!=='180')throw Error('Unsupported source manifest');
 const catalogReceipt=manifest.dependencies.find(x=>x.path==='godot/mafiozi_walk/data/map_editor/catalog.json');
 if(!catalogReceipt||catalogReceipt.sha256!==pins.catalog||catalogReceipt.bytes!==fs.statSync(catalogPath).size)throw Error('Catalog dependency drift');
 const seen=new Set();
 for(const entry of manifest.buffers){
  const location=safeBufferPath(entry);
  if(seen.has(entry.sha256))throw Error('Duplicate buffer SHA');
  seen.add(entry.sha256);
  const bytes=fs.readFileSync(location);
  if(bytes.length!==entry.bytes||sha(bytes)!==entry.sha256)throw Error(`Buffer changed: ${entry.sha256}`);
 }
 if(seen.size!==982)throw Error(`Buffer closure incomplete: ${seen.size}`);
 return {manifest,catalog,bufferHashes:seen};
}
function ids(rows,label){
 if(!Array.isArray(rows))throw Error(`Missing catalog ${label}`);
 const result=new Set();
 for(const row of rows){
  if(typeof row.id!=='string'||!row.id||result.has(row.id))throw Error(`Duplicate/invalid ${label} source ID`);
  result.add(row.id);
 }
 return result;
}
function descriptor(value,count,size,buffers,label){
 if(!value||value.arrayType!=='Float32Array'||value.itemSize!==size||value.count!==count||value.normalized!==false||!buffers.has(value.buffer))throw Error(`Invalid ${label} buffer descriptor`);
}
export function makeIndex(manifest,catalog,bufferHashes){
 if(!manifest?.exploration?.batches||!manifest?.roads?.batches||!catalog?.generatedPlans)throw Error('Missing source batch/catalog plans');
 const families={
  exploration:ids(catalog.generatedPlans.explorationDecor.objects,'exploration'),
  signs:ids(catalog.generatedPlans.roadDressing.signs,'road signs'),
  signals:ids(catalog.generatedPlans.roadDressing.signals,'road signals'),
  markings:ids(catalog.generatedPlans.roadDressing.markings,'road markings')
 };
 const all=new Set([...families.exploration,...families.signs,...families.signals,...families.markings]);
 if(all.size!==9394||families.exploration.size!==2440||families.signs.size!==445||families.signals.size!==60||families.markings.size!==6449)throw Error('Catalog source ID census drift');
 const meshes=new Set(manifest.geometries.map(x=>x.id));
 const materials=new Set(manifest.materials.map(x=>x.id));
 const roadControls=new Set([...families.signs,...families.signals]);
 if(meshes.size!==manifest.geometries.length||materials.size!==manifest.materials.length)throw Error('Duplicate geometry/material');
 const batches=[];const references=new Map([...all].map(id=>[id,[]]));const batchKeys=new Set();
 for(const [family,rows] of [['exploration',manifest.exploration.batches],['roads',manifest.roads.batches]]){
  for(const batch of rows){
   if(typeof batch.key!=='string'||!batch.key||batchKeys.has(batch.key))throw Error('Duplicate/invalid batch key');
   batchKeys.add(batch.key);
   if(!meshes.has(batch.geometry)||!materials.has(batch.material)||!Array.isArray(batch.objectIds)||!Number.isSafeInteger(batch.count)||batch.count!==batch.objectIds.length||batch.count<1)throw Error(`Incomplete batch ${batch.key}`);
   const paint=batch.kind==='merged-original-paint';
   if(family==='roads'&&!['merged-original-paint','original-batched-equipment','dynamic-traffic-bulb'].includes(batch.kind))throw Error(`Unknown road batch kind ${batch.kind}`);
   if(paint){
    if(batch.verticesPerObject!==6)throw Error(`Paint vertex contract drift: ${batch.key}`);
   }else{
    descriptor(batch.instanceMatrices,batch.count,16,bufferHashes,`${batch.key} matrices`);
    if(family==='exploration'||batch.instanceColors)descriptor(batch.instanceColors,batch.count,3,bufferHashes,`${batch.key} colors`);
   }
   const unique=new Set();
   for(let slot=0;slot<batch.objectIds.length;slot++){
    const id=batch.objectIds[slot];
    const allowed=family==='exploration'?families.exploration:paint?families.markings:roadControls;
    if(!allowed.has(id))throw Error(`Unknown/wrong-family source ID ${id}`);
    references.get(id).push([batches.length,slot]);unique.add(id);
   }
   batches.push({ordinal:batches.length,family,key:batch.key,kind:batch.kind??'exploration',chunk:batch.chunk??null,geometry:batch.geometry,material:batch.material,castShadow:batch.castShadow,receiveShadow:batch.receiveShadow,count:batch.count,uniqueIds:unique.size});
  }
 }
 if(batches.length!==531||manifest.exploration.batches.length!==464||manifest.roads.batches.length!==67)throw Error('Batch family count drift');
 for(const [id,spans] of references)if(spans.length===0)throw Error(`Unbuilt source ID ${id}`);
 const orderedIds=[...all].sort();
 const digest=sha(Buffer.from(JSON.stringify({pins,batches,refs:orderedIds.map(id=>[id,references.get(id)])})));
 const slotMultiplicity={},batchMultiplicity={};
 for(const spans of references.values()){
  slotMultiplicity[spans.length]=(slotMultiplicity[spans.length]??0)+1;
  const distinct=new Set(spans.map(([batch])=>batch)).size;
  batchMultiplicity[distinct]=(batchMultiplicity[distinct]??0)+1;
 }
 return Object.freeze({batches:Object.freeze(batches),references,sourceIds:Object.freeze(orderedIds),digest,slotMultiplicity,batchMultiplicity});
}
export function batchWindow(index,cursor,maxBatches,maxParts){
 if(!Number.isSafeInteger(cursor)||cursor<0||cursor>index.batches.length||!Number.isSafeInteger(maxBatches)||maxBatches<1||!Number.isSafeInteger(maxParts)||maxParts<1)throw Error('Invalid cursor/budget');
 const selected=[];let parts=0;
 while(cursor+selected.length<index.batches.length&&selected.length<maxBatches){
  const batch=index.batches[cursor+selected.length];
  if(parts+batch.count>maxParts){
   if(selected.length===0)throw Error(`Indivisible batch exceeds budget: ${batch.key} ${batch.count}>${maxParts}`);
   break;
  }
  selected.push(batch);parts+=batch.count;
 }
 return {batches:selected,nextCursor:cursor+selected.length,parts,complete:cursor+selected.length===index.batches.length,renderedIds:0};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const {manifest,catalog,bufferHashes}=loadPinned();
 const index=makeIndex(manifest,catalog,bufferHashes);
 const maxParts=Math.max(...index.batches.map(x=>x.count));
 console.log(JSON.stringify({scope:'source-only batch dependency index; not native renderer',manifestSha256:pins.manifest,catalogSha256:pins.catalog,factorySha256:pins.factory,buffers:bufferHashes.size,batches:index.batches.length,sourceIds:index.sourceIds.length,maxIndivisibleBatchParts:maxParts,batchMultiplicity:index.batchMultiplicity,slotMultiplicity:index.slotMultiplicity,indexSha256:index.digest,renderedIds:0}));
}
