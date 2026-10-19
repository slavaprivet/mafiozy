import assert from 'node:assert/strict';
import {createWalkMapEditorAsyncCatalog,WalkMapEditorAsyncCatalogError} from './walk_map_editor_async_catalog.mjs';

function deferred(){let resolve,reject;const promise=new Promise((yes,no)=>{resolve=yes;reject=no});return {promise,resolve,reject}}
const generated=(prefix,count)=>Array.from({length:count},(_,index)=>({key:`${prefix}:${index}`,id:`${prefix}-${index}`,label:`Объект ${index}`,category:prefix}));

const batches=[],statuses=[],order=[];let yields=0;
const controller=createWalkMapEditorAsyncCatalog({batchSize:160,loaders:[
 {id:'other',categories:['decor'],total:9359,load:async()=>{order.push('other');return generated('decor',9359)}},
 {id:'signs',categories:['signs'],total:300,load:async()=>{order.push('signs');return generated('signs',300)}}
],onBatch:(items,meta)=>batches.push({items,meta}),onStatus:value=>statuses.push(value),scheduleTask:async()=>{yields++}});
const started=controller.open({category:'signs'});assert.equal(batches.length,0,'opening the editor must not synchronously build the generated inventory');
assert.equal(await started,true);assert.deepEqual(order,['signs','other'],'selected category source should be loaded first');
assert.equal(controller.state.status,'ready');assert.equal(controller.state.loaded,9659);assert.equal(controller.state.total,9659);assert.equal(controller.items.length,9659);
assert.ok(batches.length>60);assert.ok(batches.every(batch=>batch.items.length<=160),'each UI delivery must respect the batch limit');assert.equal(batches[0].meta.sourceId,'signs');assert.ok(Object.isFrozen(batches[0].items));assert.ok(Object.isFrozen(batches[0].items[0]));assert.ok(yields>0);assert.ok(statuses.some(value=>value.status==='loading'&&/Загружено объектов/.test(value.message)));assert.match(controller.state.message,/9659/);

let attempts=0;const retryBatches=[];const retryController=createWalkMapEditorAsyncCatalog({loaders:[{id:'retry',total:2,load(){attempts++;if(attempts===1)throw new Error('temporary');return generated('retry',2)}}],onBatch:items=>retryBatches.push(...items),scheduleTask:async()=>{}});
assert.equal(await retryController.open(),false);assert.equal(retryController.state.status,'error');assert.equal(retryController.state.failed.length,1);assert.match(retryController.state.message,/повторить/i);
assert.equal(await retryController.retry(),true);assert.equal(retryController.state.status,'ready');assert.equal(retryBatches.length,2);assert.equal(attempts,2);

const wait=deferred(),staleBatches=[];let staleStatuses=[];const staleController=createWalkMapEditorAsyncCatalog({loaders:[{id:'slow',load:()=>wait.promise}],onBatch:items=>staleBatches.push(...items),onStatus:value=>staleStatuses.push(value)});
const staleRun=staleController.open();await Promise.resolve();assert.equal(staleController.close(),true);wait.resolve(generated('slow',3));assert.equal(await staleRun,false);assert.equal(staleBatches.length,0,'a loader resolving after close must not update the catalog');assert.equal(staleController.state.status,'cancelled');
const beforeDisposeStatuses=staleStatuses.length;staleController.dispose();staleController.dispose();assert.equal(staleController.state.status,'disposed');assert.equal(staleController.items.length,0);assert.equal(staleStatuses.length,beforeDisposeStatuses+1);assert.throws(()=>staleController.open(),WalkMapEditorAsyncCatalogError);

const streamBatches=[];const streamController=createWalkMapEditorAsyncCatalog({batchSize:2,loaders:[{id:'stream',batches:async function*(){yield {items:generated('stream-a',3),total:5};yield generated('stream-b',2)}}],onBatch:items=>streamBatches.push(items),scheduleTask:async()=>{}});assert.equal(await streamController.start(),true);assert.deepEqual(streamBatches.map(items=>items.length),[2,1,2]);assert.equal(streamController.state.total,5);

assert.throws(()=>createWalkMapEditorAsyncCatalog({loaders:[{}]}),WalkMapEditorAsyncCatalogError);assert.throws(()=>createWalkMapEditorAsyncCatalog({batchSize:0}),WalkMapEditorAsyncCatalogError);
controller.dispose();retryController.dispose();streamController.dispose();
console.log('walk map editor async catalog: PASS');
