import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {loadPinned,makeIndex,pins} from '../map_editor_incremental_procedural_candidate/source_index.mjs';

const here=path.dirname(fileURLToPath(import.meta.url));
const script=fs.readFileSync(path.join(here,'frame_budget_factory.gd'),'utf8');
const source=fs.readFileSync(path.join(here,'../map_editor_incremental_procedural_candidate/incremental_factory.gd'),'utf8');
const {manifest,catalog,bufferHashes}=loadPinned();
const index=makeIndex(manifest,catalog,bufferHashes);
let checks=0;
function check(ok,label){assert.ok(ok,label);checks++;}

for(const token of [
 'extends "res://scripts/incremental_factory.gd"',
 'func step_exploration_parts(max_parts: int = 64)',
 'func step_road_parts(max_parts: int = 64)',
 'max_parts > 64',
 'if not _slice.is_empty() and _slice.cursor == _slice.count and not _finish_slice()',
 'mm.buffer = _slice.buffer',
 'node.material_override = _materials[source.material]',
 'node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if source.castShadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF',
 'node.transform = _transform_array(source.sourceWorldMatrix)',
 '_paint_ids[id] = {"batch":source.key,"first":index * 6,"count":6}',
 '_completed_batch_counts[id] = int(_completed_batch_counts.get(id, 0)) + 1',
 'if not _slice.is_empty():',
 'return super.finish_all()',
 'return super.finish_exploration()',
 'return {"ok":false,"error":"use-step-exploration-parts"}',
 'return {"ok":false,"error":"use-step-road-parts"}',
])check(script.includes(token),`source guard: ${token}`);
for(const token of ['_parts[id].append({"batch":', '_recompute_road_bounds(source.key)', 'initial_upload_calls += 1', 'road_upload_calls += 1'])check(script.includes(token),`source mapping: ${token}`);
check(source.includes('func finish_all() -> Dictionary:'),'source full closure retained');
check(source.includes('func source_stage_complete(id: String) -> bool:'),'source ID closure retained');

const batches=[...manifest.exploration.batches,...manifest.roads.batches];
let maxSlots=0, sliced=0, encodedBatches=0, paintSlots=0, roadIds=new Set(), paintIds=new Set();
for(const [batchIndex,batch] of batches.entries()){
 const paint=batch.kind==='merged-original-paint';
 const count=paint?batch.objectIds.length:batch.count;
 maxSlots=Math.max(maxSlots,count);
 check(Number.isSafeInteger(count)&&count>0,`valid count ${batch.key}`);
 if(!paint){
  check(batch.objectIds.length===count,`ID/instance alignment ${batch.key}`);
  if(batchIndex<464)check(!!batch.instanceColors,`exploration color stride ${batch.key}`);
  const matrixReceipt=manifest.buffers.find(x=>x.sha256===batch.instanceMatrices.buffer);
  check(!!matrixReceipt&&matrixReceipt.bytes===count*16*4,`original Float32 matrices ${batch.key}`);
  if(batch.instanceColors){
   const colorReceipt=manifest.buffers.find(x=>x.sha256===batch.instanceColors.buffer);
   check(!!colorReceipt&&colorReceipt.bytes===count*3*4,`original Float32 colors ${batch.key}`);
  }
  encodedBatches++;
 }else{
  paintSlots+=count;
  for(const id of batch.objectIds)paintIds.add(id);
 }
 if(batchIndex>=464&&!paint)for(const id of batch.objectIds)roadIds.add(id);
 // Exact original order and membership are invariant under contiguous 64-part slices.
 const flat=[];
 for(let cursor=0;cursor<count;cursor+=64){
  const next=batch.objectIds.slice(cursor,Math.min(cursor+64,count));
  check(next.length>0&&next.length<=64,`bounded slice ${batch.key}:${cursor}`);
  flat.push(...next);
  sliced++;
 }
 check(flat.length===batch.objectIds.length&&flat.every((id,i)=>id===batch.objectIds[i]),`lossless ordered slices ${batch.key}`);
}
check(maxSlots===1702,'largest original batch not reduced or split at publication');
check(batches.length===531&&encodedBatches===472,'original 531 batch/472 MultiMesh identity');
check(paintSlots===6449&&paintIds.size===6449,'all original six-vertex paint slots');
check(roadIds.size===505,'original road equipment IDs');
check(index.sourceIds.length===9394,'full procedural source ID count');
console.log(JSON.stringify({suite:'frame-budget-source-parity',checks,sourceManifestSha256:pins.manifest,indexSha256:index.digest,batches:batches.length,multiMeshBatches:encodedBatches,slicesAt64:sliced,maxPartsPerStep:64,maxAtomicBatchSlots:maxSlots,paintSlots,roadIds:roadIds.size,nativeExecuted:false,gpu:false,renderedIds:0}));
