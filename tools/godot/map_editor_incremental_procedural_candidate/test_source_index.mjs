import assert from 'node:assert/strict';
import {loadPinned,makeIndex,batchWindow,pins} from './source_index.mjs';

const original=loadPinned();
const index=makeIndex(original.manifest,original.catalog,original.bufferHashes);
let checks=0;
const check=(condition,label)=>{assert.ok(condition,label);checks++};
check(index.sourceIds.length===9394,'all original procedural IDs');
check(index.batches.length===531,'all original batches');
check(index.batches.filter(x=>x.family==='exploration').length===464,'exploration batches');
check(index.batches.filter(x=>x.family==='roads').length===67,'road batches');
check(Object.values(index.batchMultiplicity).reduce((a,b)=>a+b,0)===9394,'all source IDs mapped');
check(Math.max(...Object.keys(index.batchMultiplicity).map(Number))>1,'multi-batch IDs make per-ID build unsafe');
check(index.digest==='fc68958f48def5cd4d8f90795874cca94df145690549a5166b306a9a1da322d6','deterministic index digest');
let cursor=0,parts=0,windows=0;
while(cursor<index.batches.length){
 const result=batchWindow(index,cursor,2,1702);
 check(result.nextCursor>cursor&&result.batches.length<=2&&result.parts<=1702,'bounded nonempty batch window');
 check(result.renderedIds===0,'metadata cursor never claims rendering');
 for(let i=0;i<result.batches.length;i++)check(result.batches[i].ordinal===cursor+i,'preserved original batch order');
 cursor=result.nextCursor;parts+=result.parts;windows++;
}
check(cursor===531&&parts===38738,'all original batch parts covered');
check(batchWindow(index,531,2,1702).complete,'end cursor complete');
assert.throws(()=>batchWindow(index,0,1,1),/Indivisible batch exceeds budget/);checks++;
assert.throws(()=>batchWindow(index,-1,2,1702),/Invalid cursor/);checks++;
assert.throws(()=>batchWindow(index,0,0,1702),/Invalid cursor/);checks++;
const shallowBatch=(family,ordinal,change)=>{
 const manifest={...original.manifest,exploration:{...original.manifest.exploration,batches:[...original.manifest.exploration.batches]},roads:{...original.manifest.roads,batches:[...original.manifest.roads.batches]}};
 manifest[family].batches[ordinal]={...manifest[family].batches[ordinal],...change};
 return manifest;
};
assert.throws(()=>makeIndex(shallowBatch('exploration',0,{count:18}),original.catalog,original.bufferHashes),/Incomplete batch/);checks++;
assert.throws(()=>makeIndex(shallowBatch('exploration',0,{material:'material-missing'}),original.catalog,original.bufferHashes),/Incomplete batch/);checks++;
assert.throws(()=>makeIndex(shallowBatch('exploration',0,{objectIds:['foreign-id',...original.manifest.exploration.batches[0].objectIds.slice(1)]}),original.catalog,original.bufferHashes),/Unknown\/wrong-family/);checks++;
assert.throws(()=>makeIndex(shallowBatch('roads',1,{key:original.manifest.roads.batches[0].key}),original.catalog,original.bufferHashes),/Duplicate\/invalid batch key/);checks++;
assert.throws(()=>makeIndex(shallowBatch('exploration',0,{instanceMatrices:{...original.manifest.exploration.batches[0].instanceMatrices,buffer:'0'.repeat(64)}}),original.catalog,original.bufferHashes),/Invalid .* matrices/);checks++;
const shortBuffers=new Set(original.bufferHashes);shortBuffers.delete(original.manifest.exploration.batches[0].instanceMatrices.buffer);
assert.throws(()=>makeIndex(original.manifest,original.catalog,shortBuffers),/Invalid .* matrices/);checks++;
const wrongCatalog={...original.catalog,generatedPlans:{...original.catalog.generatedPlans,explorationDecor:{...original.catalog.generatedPlans.explorationDecor,objects:original.catalog.generatedPlans.explorationDecor.objects.slice(1)}}};
assert.throws(()=>makeIndex(original.manifest,wrongCatalog,original.bufferHashes),/census drift/);checks++;
check(pins.factory==='280880c927809d0d773c3175cdf43fc7534a772af286d77fbf0b50a85fe53628','exact factory source pin');
console.log(JSON.stringify({suite:'procedural-source-batch-index',checks,failures:[],windows,parts,batches:index.batches.length,sourceIds:index.sourceIds.length,indexSha256:index.digest,renderedIds:0,nativeExecuted:false}));
