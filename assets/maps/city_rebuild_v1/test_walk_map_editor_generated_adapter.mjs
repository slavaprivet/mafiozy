import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createWalkMapGeneratedAdapter,createWalkMapCompositeAdapter} from './walk_map_editor_generated_adapter.mjs';

const records=[{id:'sign-1',kind:'stop-sign',x:10,z:20,label:'Знак STOP',nested:{value:1}},{id:'sign-2',kind:'direction-sign',x:30,z:40,label:'Указатель'}],suppressed=[];
const generated=createWalkMapGeneratedAdapter({collections:[{dataset:'road-dressing',label:'Дорожный знак',category:'signs',categoryLabel:'Дорожные знаки',records,movable:true,deletable:true,dependencies:['road-dressing','minimap'],proxyOf:record=>({type:'circle',x:record.x,z:record.z,radius:.8,key:'forged',dataset:'forged',id:'forged'})}],onSuppress:value=>suppressed.push(value),compileTransform:async({before,transform})=>({ok:true,after:{...before,transform},dependencies:['road-dressing']})});
records[0].nested.value=99;
const items=generated.enumerate();assert.equal(items.length,2);assert.equal(items[0].category,'signs');assert.equal(generated.enumerate({query:'указ'}).length,1);assert.equal(generated.enumerate({offset:1,limit:1}).length,1);assert.equal(generated.recordFor(items[0].key).nested?.value??1,1);
assert.equal('raw' in items[0],false);
assert.equal(Object.isFrozen(items[0]),true);assert.equal(Object.isFrozen(items[0].capabilities),true);assert.throws(()=>{items[0].capabilities.delete=false},TypeError);
const key=items.find(item=>item.id==='sign-1').key;assert.equal(generated.resolveSemanticHit({dataset:'road-dressing',id:'sign-1'}).key,key);assert.equal(generated.resolveIntersection({object:{userData:{editorGeneratedKey:key}}}).key,key);
assert.equal(generated.resolvePoint({x:10.2,z:20.1},{toleranceM:.1}).key,key);assert.equal(generated.resolvePoint({x:15,z:25},{toleranceM:.5}),null);assert.throws(()=>generated.resolvePoint({x:NaN,z:0}),/finite/);
const deletion=generated.deleteCommand(key);assert.equal(deletion.patch.action,'delete');assert.deepEqual(deletion.patch.before.nested,{value:1});assert.equal(Object.isFrozen(deletion.patch.before),true);assert.throws(()=>{deletion.patch.before.id='changed'},TypeError);
const movement=await generated.transformCommand(key,{positionM:[1,0,2],yawDegrees:90});assert.equal(movement.patch.action,'modify');assert.deepEqual(movement.patch.after.transform.positionM,[1,0,2]);assert.equal(Object.isFrozen(movement),true);
const edgeProxy=generated.proxyDescriptors({bounds:{minX:10.5,minZ:20,maxX:11,maxZ:21}});assert.equal(edgeProxy.length,1);assert.equal(edgeProxy[0].key,key);assert.equal(edgeProxy[0].dataset,'road-dressing');assert.equal(edgeProxy[0].id,'sign-1');
assert.throws(()=>generated.proxyDescriptors({bounds:{minX:2,minZ:0,maxX:1,maxZ:1}}),/Invalid proxy bounds/);
generated.suppress(key,true);assert.equal(suppressed.at(-1).suppressed,true);assert.equal(Object.isFrozen(suppressed.at(-1)),true);assert.throws(()=>{suppressed.at(-1).record.id='bad'},TypeError);

const locked=createWalkMapGeneratedAdapter({collections:[{dataset:'locked',records:[{id:'x'}],movable:true,deletable:true,locked:true}]});const lockedItem=locked.enumerate()[0];assert.equal(lockedItem.locked,true);assert.deepEqual(lockedItem.capabilities,{move:false,rotate:false,delete:false,paint:false});assert.throws(()=>locked.deleteCommand(lockedItem.key),/cannot be deleted/);assert.rejects(locked.transformCommand(lockedItem.key,{}),/cannot be moved/);assert.throws(()=>locked.suppress(lockedItem.key,true),/cannot be suppressed/);locked.dispose();

assert.throws(()=>createWalkMapGeneratedAdapter({collections:[{dataset:'same',records:[]},{dataset:'same',records:[]}]}),/Duplicate generated dataset/);
assert.throws(()=>createWalkMapGeneratedAdapter({collections:[{dataset:'dup',records:[{id:'x'},{id:'x'}]}]}),/Duplicate generated id/);
assert.throws(()=>createWalkMapGeneratedAdapter({collections:[{dataset:'bad-id',records:[{id:{value:1}}]}]}),/stable id/);

let releaseTransform,receivedSignal;
const cancellable=createWalkMapGeneratedAdapter({collections:[{dataset:'async',records:[{id:'one'}],movable:true}],compileTransform:request=>{receivedSignal=request.signal;return new Promise(resolve=>{releaseTransform=resolve;});}}),asyncKey=cancellable.enumerate()[0].key,pending=cancellable.transformCommand(asyncKey,{positionM:[1,0,1]});
assert.equal(cancellable.cancelPreview(asyncKey),true);assert.equal(receivedSignal.aborted,true);await assert.rejects(pending,error=>error?.name==='AbortError'&&error?.code==='EDITOR_TRANSFORM_CANCELLED');releaseTransform({ok:true,after:{id:'one'}});assert.equal(cancellable.cancelPreview(asyncKey),false);
const cancellationComposite=createWalkMapCompositeAdapter([cancellable]),compositePending=cancellationComposite.transformCommand(asyncKey,{positionM:[2,0,2]});assert.equal(cancellationComposite.cancelPreview(asyncKey),true);await assert.rejects(compositePending,error=>error?.name==='AbortError');releaseTransform({ok:true,after:{id:'one'}});cancellationComposite.dispose();

let authoredEnumerations=0;
const authored={datasets:Object.freeze(['buildings']),enumerate:()=>{authoredEnumerations++;return [{key:'buildings:house',id:'house',label:'Дом',category:'buildings'}]},deleteCommand:()=>({type:'authored-delete'}),recordFor:()=>({id:'house'}),dependenciesFor:()=>['building'],disposePreview:()=>0};
const composite=createWalkMapCompositeAdapter([authored,generated]);assert.equal(authoredEnumerations,1);assert.equal(composite.enumerate().length,3);for(let i=0;i<1000;i++)assert.equal(composite.deleteCommand('buildings:house').type,'authored-delete');assert.equal(authoredEnumerations,1);assert.equal(composite.deleteCommand(key).patch.action,'delete');assert.deepEqual(composite.dependenciesFor(key),['road-dressing','minimap']);assert.equal(Object.isFrozen(composite.recordFor(key)),true);
assert.throws(()=>createWalkMapCompositeAdapter([{datasets:['same'],enumerate:()=>[]},{datasets:['same'],enumerate:()=>[]}]),/Duplicate composite dataset/);
assert.throws(()=>createWalkMapCompositeAdapter([{enumerate:()=>[{key:'collision'}]},{enumerate:()=>[{key:'collision'}]}]),/Duplicate composite editor key/);

const heapBefore=process.memoryUsage().heapUsed,start=performance.now(),largeRecords=Array.from({length:8000},(_,index)=>({id:`object-${index}`,kind:index%2?'lamp':'sign',x:index%200,z:Math.floor(index/200),label:`Объект ${index}`})),large=createWalkMapGeneratedAdapter({collections:[{dataset:'large-generated',records:largeRecords,movable:false,proxyOf:record=>({x:record.x,z:record.z,radius:.25})}]}),largeComposite=createWalkMapCompositeAdapter([large]);
const largeItems=largeComposite.enumerate();assert.equal(largeItems.length,8000);for(let i=0;i<2000;i++){const item=largeItems[(i*37)%largeItems.length];assert.equal(largeComposite.hasKey(item.key),true);assert.equal(largeComposite.recordFor(item.key).id,item.id);}const pickStarted=performance.now();for(let i=0;i<200;i++)assert.ok(largeComposite.resolvePoint({x:i%200,z:Math.floor(i/10)},{toleranceM:.25}));const pickElapsed=performance.now()-pickStarted,elapsed=performance.now()-start,heapGrowth=process.memoryUsage().heapUsed-heapBefore;assert.ok(pickElapsed<1500,`200 explicit 8k proxy picks took ${pickElapsed.toFixed(1)} ms`);assert.ok(elapsed<5000,`8k generated inventory took ${elapsed.toFixed(1)} ms`);assert.ok(heapGrowth<200*1024*1024,`8k generated inventory used ${(heapGrowth/1024/1024).toFixed(1)} MiB`);largeComposite.dispose();assert.throws(()=>largeComposite.enumerate(),/disposed/);assert.throws(()=>large.enumerate(),/disposed/);

let releaseDispose;
const disposable=createWalkMapGeneratedAdapter({collections:[{dataset:'dispose',records:[{id:'pending'}],movable:true}],compileTransform:()=>new Promise(resolve=>{releaseDispose=resolve;})}),disposeKey=disposable.enumerate()[0].key,disposePending=disposable.transformCommand(disposeKey,{});disposable.dispose();disposable.dispose();await assert.rejects(disposePending,error=>error?.name==='AbortError');releaseDispose({ok:true,after:{id:'pending'}});assert.throws(()=>disposable.enumerate(),/disposed/);

composite.dispose();composite.dispose();assert.throws(()=>composite.enumerate(),/disposed/);assert.throws(()=>generated.enumerate(),/disposed/);
console.log(`walk map editor generated adapter: PASS (8k ${elapsed.toFixed(1)} ms, 200 picks ${pickElapsed.toFixed(1)} ms, ${(heapGrowth/1024/1024).toFixed(1)} MiB)`);
