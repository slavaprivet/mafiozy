import {captureWalkMapEditorVisualParity,compareWalkMapEditorVisualParity} from './walk_map_editor_visual_parity.mjs';

export const WALK_MAP_EDITOR_LIVE_QA_SCHEMA='mafiozi.walk-map-editor.live-qa/v1';

export const WALK_MAP_EDITOR_LIVE_QA_DEFAULT_THRESHOLDS=Object.freeze({
 openLatencyMs:1500,
 minFrameSamples:60,
 frameP95Ms:33.4,
 longFrameMs:50,
 maxLongFrameRate:.05,
 idleP95RegressionRatio:1.2,
 dragP95RegressionRatio:1.5,
 idleDrawCallRatio:1.25,
 dragDrawCallRatio:1.4,
 idleTriangleRatio:1.15,
 dragTriangleRatio:1.3,
 minCatalogBatches:1,
 catalogBatchMs:50,
 catalogTotalMs:1500,
 relocationToleranceM:.05,
});

const SCENARIO_IDS=Object.freeze(['k-open-close','top-fly','select-move-cancel-commit','rmb-delete-vs-drag','save-reload','relocation','visual-parity','catalog-buildings']);
const PERF_IDS=Object.freeze(['openLatency','frames','renderer','catalog']);
const finite=value=>Number.isFinite(value);
const plain=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
const clone=value=>value===undefined?undefined:structuredClone(value);
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
const errorText=error=>String(error?.message||error||'Unknown QA error');
const aggregate=values=>values.includes('fail')?'fail':values.includes('unverified')?'unverified':values.length&&values.every(value=>value==='pass')?'pass':'unverified';
const ratio=(value,baseline)=>baseline===0?(value===0?1:Infinity):value/baseline;
const pointDistance=(a,b)=>Array.isArray(a)&&Array.isArray(b)&&a.length===b.length?Math.hypot(...a.map((value,index)=>value-b[index])):Infinity;
const addPoint=(point,delta)=>point.map((value,index)=>value+(delta[index]||0));

function bindingDescriptor(value){return plain(value)&&Number.isInteger(value.rootIndex)&&typeof value.key==='string'&&value.key&&typeof value.assetId==='string'&&value.assetId&&['string','number'].includes(typeof value.lod)&&value.lod!==''&&plain(value.materialQuality)?{rootIndex:value.rootIndex,key:value.key,assetId:value.assetId,lod:value.lod,materialQuality:value.materialQuality}:null}
function compareVisualBindings(before,after){
 const issues=[];if(!Array.isArray(before?.bindings)||!Array.isArray(after?.bindings)||!Array.isArray(before?.roots)||!Array.isArray(after?.roots))return {ok:false,issues:[{code:'VISUAL_BINDINGS_MISSING'}]};const normalize=(sample,label)=>{const map=new Map();for(const raw of sample.bindings){const item=bindingDescriptor(raw);if(!item){issues.push({code:'VISUAL_BINDING_INVALID',phase:label});continue}if(item.rootIndex<0||item.rootIndex>=sample.roots.length||map.has(item.key)){issues.push({code:'VISUAL_BINDING_ROOT_INVALID',phase:label,key:item.key});continue}map.set(item.key,item)}if(map.size!==sample.roots.length)issues.push({code:'VISUAL_BINDING_COVERAGE',phase:label,roots:sample.roots.length,bindings:map.size});return map},expected=normalize(before,'before'),actual=normalize(after,'after');for(const [key,item] of expected){const next=actual.get(key);if(!next)issues.push({code:'VISUAL_BINDING_REMOVED',key});else if(!same(item,next))issues.push({code:'VISUAL_BINDING_CHANGED',key})}for(const key of actual.keys())if(!expected.has(key))issues.push({code:'VISUAL_BINDING_ADDED',key});return {ok:issues.length===0,issues};
}
function containsNode(root,target){if(root===target)return true;const queue=[...(root?.children||[])],seen=new Set();for(let index=0;index<queue.length;index++){const node=queue[index];if(node===target)return true;if(!plain(node)||seen.has(node))continue;seen.add(node);queue.push(...(node.children||[]))}return false}
function validateBuildingCatalog(sample,visual){
 const issues=[];if(!Array.isArray(sample?.buildings))return {ok:false,issues:[{code:'BUILDING_CATALOG_MISSING'}],rootIndexByKey:new Map()};const keys=new Set(),rootIndexByKey=new Map(),protectedEntries=[],visualRoots=Array.isArray(visual?.roots)?visual.roots:null;if(sample.buildings.length!==78)issues.push({code:'BUILDING_COUNT',expected:78,actual:sample.buildings.length});for(const entry of sample.buildings){if(!plain(entry)||typeof entry.key!=='string'||!entry.key||keys.has(entry.key)){issues.push({code:'BUILDING_KEY_INVALID',key:entry?.key??null});continue}keys.add(entry.key);if(!visualRoots||!Number.isInteger(entry.rootIndex)||entry.rootIndex<0||entry.rootIndex>=visualRoots.length||entry.root!==visualRoots[entry.rootIndex]||entry.selectRoot!==entry.root||!plain(entry.pickRoot)||!containsNode(entry.root,entry.pickRoot)){issues.push({code:'BUILDING_PICK_ROOT_MISSING',key:entry.key});continue}rootIndexByKey.set(entry.key,entry.rootIndex);if(entry.protected===true){protectedEntries.push(entry);const reason=String(entry.lockReason||'').trim();if(entry.visible!==true||entry.root.visible===false)issues.push({code:'PROTECTED_BUILDING_HIDDEN',key:entry.key});if(reason.length<6||/unknown|неизвест/i.test(reason))issues.push({code:'PROTECTED_REASON_MISSING',key:entry.key})}}
 if(keys.size!==78)issues.push({code:'BUILDING_UNIQUE_COUNT',expected:78,actual:keys.size});if(rootIndexByKey.size!==78)issues.push({code:'BUILDING_SELECTABLE_COUNT',expected:78,actual:rootIndexByKey.size});if(protectedEntries.length!==8)issues.push({code:'PROTECTED_BUILDING_COUNT',expected:8,actual:protectedEntries.length});return {ok:issues.length===0,issues,rootIndexByKey};
}

function validateThresholds(input={}){
 const value={...WALK_MAP_EDITOR_LIVE_QA_DEFAULT_THRESHOLDS,...input};
 for(const [key,number] of Object.entries(value))if(!finite(number)||number<0)throw new TypeError(`Invalid LIVE QA threshold: ${key}`);
 if(!Number.isInteger(value.minFrameSamples)||value.minFrameSamples<1||!Number.isInteger(value.minCatalogBatches)||value.minCatalogBatches<0)throw new TypeError('LIVE QA sample thresholds must be integers');
 return Object.freeze(value);
}

function isProof(sample){
 return plain(sample)&&typeof sample.source==='string'&&sample.source.trim()&&typeof sample.sampleId==='string'&&sample.sampleId.trim()&&typeof sample.transactionId==='string'&&sample.transactionId.trim()&&finite(sample.capturedAtMs);
}

function evidence(proofs){return proofs.filter(isProof).map(sample=>({source:sample.source,sampleId:sample.sampleId,transactionId:sample.transactionId,capturedAtMs:sample.capturedAtMs}))}
function scenario(id){return {id,status:'unverified',checks:[]}}
function check(target,id,condition,proofs=[],detail=null){
 const valid=proofs.length>0&&proofs.every(isProof)&&new Set(proofs.map(sample=>sample.sampleId)).size===proofs.length,status=valid?(condition?'pass':'fail'):'unverified';
 target.checks.push({id,status,detail:detail??null,evidence:evidence(proofs)});target.status=aggregate(target.checks.map(item=>item.status));return status;
}
function failure(target,id,error){target.checks.push({id,status:'fail',detail:errorText(error),evidence:[]});target.status='fail'}
function unverifiedMetric(reason){return {status:'unverified',reason,source:null,sampleId:null}}
function metricProof(sample,body){return {status:'pass',source:sample.source,sampleId:sample.sampleId,capturedAtMs:sample.capturedAtMs,...body}}

function percentile(sorted,fraction){if(!sorted.length)return null;const index=(sorted.length-1)*fraction,low=Math.floor(index),high=Math.ceil(index),weight=index-low;return sorted[low]*(1-weight)+sorted[high]*weight}
function frameMetric(sample,thresholds){
 const values=sample?.frameTimesMs;
 if(!isProof(sample)||!Array.isArray(values)||values.length<thresholds.minFrameSamples||values.some(value=>!finite(value)||value<0))return unverifiedMetric('real-frame-samples-missing');
 const sorted=[...values].sort((a,b)=>a-b),longFrames=values.filter(value=>value>=thresholds.longFrameMs).length;
 return metricProof(sample,{samples:values.length,p50Ms:percentile(sorted,.5),p95Ms:percentile(sorted,.95),longFrames,longFrameRate:longFrames/values.length});
}
function rendererMetric(sample){
 if(!isProof(sample)||!finite(sample.drawCalls)||sample.drawCalls<0||!finite(sample.triangles)||sample.triangles<0)return unverifiedMetric('renderer-sample-missing');
 return metricProof(sample,{drawCalls:sample.drawCalls,triangles:sample.triangles});
}
function catalogMetric(sample,thresholds){
 if(!isProof(sample)||!Array.isArray(sample.batches)||sample.batches.length<thresholds.minCatalogBatches||sample.batches.some(batch=>!plain(batch)||!finite(batch.durationMs)||batch.durationMs<0||!Number.isInteger(batch.count)||batch.count<0))return unverifiedMetric('catalog-batch-samples-missing');
 const totalMs=sample.batches.reduce((sum,batch)=>sum+batch.durationMs,0),maxBatchMs=Math.max(0,...sample.batches.map(batch=>batch.durationMs)),items=sample.batches.reduce((sum,batch)=>sum+batch.count,0);
 const result=metricProof(sample,{batches:sample.batches.length,items,totalMs,maxBatchMs,batchDurationsMs:sample.batches.map(batch=>batch.durationMs)});
 result.status=maxBatchMs<=thresholds.catalogBatchMs&&totalMs<=thresholds.catalogTotalMs?'pass':'fail';return result;
}
function position(sample,kind){const value=kind==='scene'?sample?.scenePositionM:sample?.documentPositionM;return Array.isArray(value)&&value.length===3&&value.every(finite)?value:null}
function objectEqual(a,b,tolerance=1e-6){
 if(!isProof(a)||!isProof(b)||a.exists!==b.exists)return false;
 if(!a.exists)return true;
 return pointDistance(position(a,'scene'),position(b,'scene'))<=tolerance&&pointDistance(position(a,'document'),position(b,'document'))<=tolerance;
}
function anchorEqual(a,b,tolerance){return isProof(a)&&isProof(b)&&pointDistance(a.pointXZ,b.pointXZ)<=tolerance}
function movedBy(a,b,delta,tolerance){return isProof(a)&&isProof(b)&&Array.isArray(a.pointXZ)&&Array.isArray(b.pointXZ)&&pointDistance(b.pointXZ,addPoint(a.pointXZ,delta))<=tolerance}

/**
 * Runs only against injected live input/state/performance probes. The harness
 * never imports the game or editor runtime and will not dispatch any action
 * unless a rollback-capable test transaction has been acquired.
 *
 * Driver: key(event), pointer(event), waitFor(expectation), setTool(tool),
 * reloadSaved(), dispose(), and optional abort(). Fixtures provide screen-space
 * `movable` and `deletable` targets. State proofs must have a unique sampleId,
 * source, capturedAtMs and the acquired transactionId. editorState reports open/mode/tool/selectionKey;
 * objectState reports exists, scenePositionM and documentPositionM; anchor
 * probes report pointXZ. Frame, renderer and catalog probes use their raw sample
 * arrays/counters rather than precomputed pass booleans.
 */
export function createWalkMapEditorLiveQa({
 driver,
 probes={},
 fixtures={},
 beginTransaction,
 thresholds:thresholdOverrides={},
 clock=()=>globalThis.performance?.now?.()??Date.now(),
 now=()=>Date.now(),
}={}){
 if(!plain(driver)||typeof driver.dispose!=='function')throw new TypeError('LIVE QA requires an injected disposable driver');
 const thresholds=validateThresholds(thresholdOverrides);let running=false,finished=false;

 async function run(){
  if(running||finished)throw new Error('LIVE QA harness is single-use');running=true;
  const report={schema:WALK_MAP_EDITOR_LIVE_QA_SCHEMA,startedAtMs:now(),completedAtMs:null,status:'unverified',thresholds:clone(thresholds),transaction:{status:'unverified',id:null,rollback:'pending',verification:'unverified'},cleanup:{rollback:'pending',dispose:'pending',abort:'not-provided'},scenarios:Object.fromEntries(SCENARIO_IDS.map(id=>[id,scenario(id)])),performance:Object.fromEntries(PERF_IDS.map(id=>[id,unverifiedMetric('not-sampled')])),errors:[]};
  let transaction=null;
  const call=async(name,...args)=>{const fn=driver[name];if(typeof fn!=='function')throw new Error(`LIVE QA driver callback is missing: ${name}`);return await fn(...args)};
  const probe=async(name,...args)=>{const fn=probes[name];if(typeof fn!=='function')return null;try{const value=await fn(...args);if(transaction&&plain(value)&&String(value.transactionId||'')!==String(transaction.id||'')){report.errors.push({stage:`probe:${name}`,message:'sample-transaction-mismatch'});return null}return value}catch(error){report.errors.push({stage:`probe:${name}`,message:errorText(error)});return null}};
  const visualSampleIds=new Set();
  const visual=async phase=>{const sample=await probe('visualState',{phase});if(!isProof(sample))return {phase,sample:null,roots:null,capture:null,reason:'visual-proof-missing'};if(sample.phase!==phase||visualSampleIds.has(sample.sampleId))return {phase,sample,roots:null,capture:null,reason:sample.phase!==phase?'visual-phase-stale':'visual-proof-reused'};visualSampleIds.add(sample.sampleId);if(!Array.isArray(sample.roots)||!sample.roots.length||sample.roots.some(root=>!plain(root)))return {phase,sample,roots:null,capture:null,reason:'visual-roots-missing'};try{return {phase,sample,roots:sample.roots,capture:captureWalkMapEditorVisualParity(sample.roots,{label:`live:${phase}`}),reason:null}}catch(error){return {phase,sample,roots:null,capture:null,reason:errorText(error)}}};
  const visualCompare=(before,after,options={})=>{if(!before?.capture||!after?.roots)return {ok:false,issues:[{code:before?.reason||after?.reason||'VISUAL_CAPTURE_MISSING'}]};try{return compareWalkMapEditorVisualParity(before.capture,after.roots,options)}catch(error){return {ok:false,issues:[{code:'VISUAL_COMPARE_ERROR',message:errorText(error)}]}}};
  const visualCheck=(id,result,...states)=>check(report.scenarios['visual-parity'],id,result?.ok===true,states.map(item=>item?.sample).filter(Boolean),result?.issues||states.find(item=>item?.reason)?.reason||null);
  const key=async(code,options={})=>{await call('key',{code,...options});await call('waitFor',{kind:'key-settled',code,...options})};
  const pointer=async(type,point,{button=0,pointerId=1}={})=>{await call('pointer',{type,button,pointerId,clientX:point.x,clientY:point.y});await call('waitFor',{kind:'pointer-settled',type,button,pointerId})};
  const state=()=>probe('editorState');
  const object=key=>probe('objectState',key);
  const anchors=async(key,checkpoint)=>({door:await probe('doorAnchor',key,checkpoint),collision:await probe('collisionAnchor',key,checkpoint),minimap:await probe('minimapAnchor',key,checkpoint)});
  const compareAnchors=(target,prefix,before,after,condition)=>{for(const channel of ['door','collision','minimap'])check(target,`${prefix}:${channel}`,condition(before[channel],after[channel]),[before[channel],after[channel]])};
  try{
   if(typeof beginTransaction!=='function'){
    report.transaction.status='unverified';report.transaction.reason='transaction-callback-missing';
    return report;
   }
   transaction=await beginTransaction({label:'walk-map-editor-live-qa',rollbackOnly:true,includeStorage:true,includeGameplay:true});
   if(!plain(transaction)||typeof transaction.id!=='string'||!transaction.id.trim()||typeof transaction.rollback!=='function'||!transaction.rollbackCapable){
    report.transaction.status='unverified';report.transaction.reason='rollback-capable-transaction-unavailable';return report;
   }
   report.transaction={status:'pass',id:String(transaction.id||''),rollback:'pending',verification:'unverified'};

   const movable=fixtures.movable,deletable=fixtures.deletable;
   if(!plain(movable)||typeof movable.key!=='string'||!plain(movable.selectPoint)||!plain(movable.dragTo)||!plain(deletable)||typeof deletable.key!=='string'||!plain(deletable.point)||!plain(deletable.dragTo))throw new Error('LIVE QA fixtures require movable and deletable screen-space targets');

   const beforeVisual=await visual('before-open');visualCheck('before-open-snapshot',{ok:!!beforeVisual.capture,issues:beforeVisual.reason?[{code:beforeVisual.reason}]:[]},beforeVisual);
   const initialEditor=await state();
   check(report.scenarios['k-open-close'],'starts-in-game',initialEditor?.open===false,[initialEditor]);
   report.performance.frames={before:frameMetric(await probe('sampleFrames',{phase:'game-before',minimum:thresholds.minFrameSamples}),thresholds),idleEditor:unverifiedMetric('not-sampled'),drag:unverifiedMetric('not-sampled'),status:'unverified'};
   report.performance.renderer={before:rendererMetric(await probe('rendererStats',{phase:'game-before'})),idleEditor:unverifiedMetric('not-sampled'),drag:unverifiedMetric('not-sampled'),status:'unverified'};

   const openStarted=clock();await key('KeyK');const opened=await state(),openElapsed=clock()-openStarted;
   check(report.scenarios['k-open-close'],'k-opens-editor',opened?.open===true,[initialEditor,opened]);
   report.performance.openLatency=isProof(opened)&&finite(openElapsed)&&openElapsed>=0?{status:openElapsed<=thresholds.openLatencyMs?'pass':'fail',valueMs:openElapsed,limitMs:thresholds.openLatencyMs,source:opened.source,sampleId:opened.sampleId,capturedAtMs:opened.capturedAtMs}:unverifiedMetric('open-state-or-clock-sample-missing');

   report.performance.frames.idleEditor=frameMetric(await probe('sampleFrames',{phase:'editor-idle',minimum:thresholds.minFrameSamples}),thresholds);
   report.performance.renderer.idleEditor=rendererMetric(await probe('rendererStats',{phase:'editor-idle'}));
   report.performance.catalog=catalogMetric(await probe('catalogBatches'),thresholds);

   const idleVisual=await visual('editor-idle'),idleParity=visualCompare(beforeVisual,idleVisual);visualCheck('idle-exact-graph-resources-transforms',idleParity,beforeVisual,idleVisual);visualCheck('idle-asset-binding-lod-quality',compareVisualBindings(beforeVisual.sample,idleVisual.sample),beforeVisual,idleVisual);
   const catalogSample=await probe('buildingCatalogProof'),catalogValidation=isProof(catalogSample)?validateBuildingCatalog(catalogSample,idleVisual):{ok:false,issues:[{code:'BUILDING_CATALOG_PROOF_MISSING'}],rootIndexByKey:new Map()};check(report.scenarios['catalog-buildings'],'exactly-78-unique-pickable-buildings',catalogValidation.ok,[catalogSample].filter(Boolean),catalogValidation.issues);check(report.scenarios['catalog-buildings'],'eight-protected-visible-with-reason',catalogValidation.ok,[catalogSample].filter(Boolean),catalogValidation.issues);

   await key('Digit2');const fly=await state();check(report.scenarios['top-fly'],'digit2-enters-fly',fly?.open===true&&fly?.mode==='fly',[opened,fly]);
   await key('Digit1');const top=await state();check(report.scenarios['top-fly'],'digit1-restores-top',top?.open===true&&top?.mode==='top',[fly,top]);

   const moveBefore=await object(movable.key),anchorsBefore=await anchors(movable.key,'before');
   await pointer('pointerdown',movable.selectPoint,{button:0,pointerId:11});await pointer('pointerup',movable.selectPoint,{button:0,pointerId:11});const selected=await state();
   check(report.scenarios['select-move-cancel-commit'],'selects-target',selected?.selectionKey===movable.key,[selected,moveBefore]);
   await call('setTool','move');await call('waitFor',{kind:'tool',tool:'move'});const moveTool=await state();check(report.scenarios['select-move-cancel-commit'],'move-tool-live',moveTool?.tool==='move',[moveTool]);
   await pointer('pointerdown',movable.selectPoint,{button:0,pointerId:12});await pointer('pointermove',movable.dragTo,{button:0,pointerId:12});
   report.performance.frames.drag=frameMetric(await probe('sampleFrames',{phase:'editor-drag',minimum:thresholds.minFrameSamples}),thresholds);
   report.performance.renderer.drag=rendererMetric(await probe('rendererStats',{phase:'editor-drag'}));
   await pointer('pointerup',movable.dragTo,{button:0,pointerId:12});const previewOne=await object(movable.key),previewVisual=await visual('move-preview'),movableRootIndex=catalogValidation.rootIndexByKey.get(movable.key);
   check(report.scenarios['select-move-cancel-commit'],'preview-moves-scene-only',pointDistance(position(moveBefore,'scene'),position(previewOne,'scene'))>1e-6&&pointDistance(position(moveBefore,'document'),position(previewOne,'document'))<=1e-6,[moveBefore,previewOne]);
   visualCheck('preview-only-selected-root-transform',visualCompare(beforeVisual,previewVisual,{allowRootTransform:true,allowRootIndices:Number.isInteger(movableRootIndex)?[movableRootIndex]:[]}),beforeVisual,previewVisual);visualCheck('preview-preserves-binding-lod-quality',compareVisualBindings(beforeVisual.sample,previewVisual.sample),beforeVisual,previewVisual);
   await key('Escape');const cancelled=await object(movable.key),anchorsCancelled=await anchors(movable.key,'cancelled'),cancelVisual=await visual('move-cancelled');
   check(report.scenarios['select-move-cancel-commit'],'escape-restores-object',objectEqual(moveBefore,cancelled),[moveBefore,cancelled]);
   compareAnchors(report.scenarios.relocation,'cancel-restores',anchorsBefore,anchorsCancelled,(before,after)=>anchorEqual(before,after,thresholds.relocationToleranceM));
   visualCheck('cancel-restores-exact-graph-resources-transforms',visualCompare(beforeVisual,cancelVisual),beforeVisual,cancelVisual);visualCheck('cancel-restores-binding-lod-quality',compareVisualBindings(beforeVisual.sample,cancelVisual.sample),beforeVisual,cancelVisual);

   await pointer('pointerdown',movable.selectPoint,{button:0,pointerId:13});await pointer('pointermove',movable.dragTo,{button:0,pointerId:13});await pointer('pointerup',movable.dragTo,{button:0,pointerId:13});const previewTwo=await object(movable.key);
   await key('Enter');const committed=await object(movable.key),anchorsCommitted=await anchors(movable.key,'committed'),commitVisual=await visual('move-committed');
   const beforeDocument=position(moveBefore,'document'),committedDocument=position(committed,'document'),previewScene=position(previewTwo,'scene');
   check(report.scenarios['select-move-cancel-commit'],'enter-commits-preview',pointDistance(beforeDocument,committedDocument)>1e-6&&pointDistance(previewScene,committedDocument)<=1e-6&&position(committed,'scene')&&pointDistance(position(committed,'scene'),committedDocument)<=1e-6,[moveBefore,previewTwo,committed]);
   const moveDelta=beforeDocument&&committedDocument?[committedDocument[0]-beforeDocument[0],committedDocument[2]-beforeDocument[2]]:null;
   compareAnchors(report.scenarios.relocation,'commit-relocates',anchorsBefore,anchorsCommitted,(before,after)=>moveDelta&&movedBy(before,after,moveDelta,thresholds.relocationToleranceM));
   visualCheck('commit-preserves-visual-descriptors',visualCompare(beforeVisual,commitVisual,{allowRootTransform:true,allowRootIndices:Number.isInteger(movableRootIndex)?[movableRootIndex]:[]}),beforeVisual,commitVisual);visualCheck('commit-preserves-binding-lod-quality',compareVisualBindings(beforeVisual.sample,commitVisual.sample),beforeVisual,commitVisual);

   const deleteBefore=await object(deletable.key);
   await pointer('pointerdown',deletable.point,{button:2,pointerId:21});await pointer('pointermove',deletable.dragTo,{button:2,pointerId:21});await pointer('pointerup',deletable.dragTo,{button:2,pointerId:21});const afterRightDrag=await object(deletable.key);
   check(report.scenarios['rmb-delete-vs-drag'],'rmb-drag-does-not-delete',deleteBefore?.exists===true&&objectEqual(deleteBefore,afterRightDrag),[deleteBefore,afterRightDrag]);
   await pointer('pointerdown',deletable.point,{button:2,pointerId:22});await pointer('pointerup',deletable.point,{button:2,pointerId:22});await call('waitFor',{kind:'object-exists',key:deletable.key,exists:false});const afterShortRight=await object(deletable.key);
   check(report.scenarios['rmb-delete-vs-drag'],'short-rmb-deletes',deleteBefore?.exists===true&&afterShortRight?.exists===false,[deleteBefore,afterShortRight]);

   const dirty=await probe('saveState');check(report.scenarios['save-reload'],'mutations-are-dirty',dirty?.dirty===true,[dirty]);
   await key('KeyS',{ctrlKey:true});const saved=await probe('saveState');check(report.scenarios['save-reload'],'ctrl-s-saves',saved?.dirty===false&&saved?.status==='saved',[dirty,saved]);
   await call('reloadSaved');await call('waitFor',{kind:'saved-map-reloaded'});const reloadedMove=await object(movable.key),reloadedDelete=await object(deletable.key),anchorsReloaded=await anchors(movable.key,'reloaded'),reloadVisual=await visual('saved-reloaded');
   check(report.scenarios['save-reload'],'reload-preserves-move',objectEqual(committed,reloadedMove,thresholds.relocationToleranceM),[committed,reloadedMove]);
   check(report.scenarios['save-reload'],'reload-preserves-delete',afterShortRight?.exists===false&&reloadedDelete?.exists===false,[afterShortRight,reloadedDelete]);
   compareAnchors(report.scenarios.relocation,'reload-preserves',anchorsCommitted,anchorsReloaded,(before,after)=>anchorEqual(before,after,thresholds.relocationToleranceM));
   visualCheck('reload-preserves-visual-descriptors',visualCompare(commitVisual,reloadVisual,{allowResourceReplacement:true}),commitVisual,reloadVisual);visualCheck('reload-preserves-binding-lod-quality',compareVisualBindings(commitVisual.sample,reloadVisual.sample),commitVisual,reloadVisual);

   await key('KeyK');const closed=await state();check(report.scenarios['k-open-close'],'k-closes-editor',closed?.open===false,[opened,closed]);

   const frames=report.performance.frames,beforeFrames=frames.before;
   if(beforeFrames.status==='pass')for(const [phase,limit] of [['idleEditor',thresholds.idleP95RegressionRatio],['drag',thresholds.dragP95RegressionRatio]]){const metric=frames[phase];if(metric.status==='pass')metric.status=metric.p95Ms<=thresholds.frameP95Ms&&metric.longFrameRate<=thresholds.maxLongFrameRate&&ratio(metric.p95Ms,beforeFrames.p95Ms)<=limit?'pass':'fail'}
   else for(const phase of ['idleEditor','drag'])if(frames[phase].status==='pass')frames[phase].status='unverified',frames[phase].reason='baseline-frame-samples-missing';
   frames.status=aggregate(['before','idleEditor','drag'].map(key=>frames[key].status));

   const renderer=report.performance.renderer,beforeRenderer=renderer.before;
   if(beforeRenderer.status==='pass')for(const [phase,drawLimit,triangleLimit] of [['idleEditor',thresholds.idleDrawCallRatio,thresholds.idleTriangleRatio],['drag',thresholds.dragDrawCallRatio,thresholds.dragTriangleRatio]]){const metric=renderer[phase];if(metric.status==='pass'){metric.drawCallRatio=ratio(metric.drawCalls,beforeRenderer.drawCalls);metric.triangleRatio=ratio(metric.triangles,beforeRenderer.triangles);metric.status=metric.drawCallRatio<=drawLimit&&metric.triangleRatio<=triangleLimit?'pass':'fail'}}
   else for(const phase of ['idleEditor','drag'])if(renderer[phase].status==='pass')renderer[phase].status='unverified',renderer[phase].reason='baseline-renderer-sample-missing';
   renderer.status=aggregate(['before','idleEditor','drag'].map(key=>renderer[key].status));
  }catch(error){
   report.errors.push({stage:'run',message:errorText(error)});const pending=SCENARIO_IDS.map(id=>report.scenarios[id]).find(item=>item.status==='unverified'&&!item.checks.length);failure(pending||report.scenarios['k-open-close'],'run-error',error);
  }finally{
   if(transaction){
    if(typeof driver.abort==='function')try{await driver.abort({reason:'live-qa-finalize'});report.cleanup.abort='pass'}catch(error){report.cleanup.abort='fail';report.errors.push({stage:'abort',message:errorText(error)})}
    try{await transaction.rollback({reason:'live-qa-finalize'});report.cleanup.rollback='pass';report.transaction.rollback='pass'}catch(error){report.cleanup.rollback='fail';report.transaction.rollback='fail';report.errors.push({stage:'rollback',message:errorText(error)})}
    if(typeof transaction.verify==='function')try{const proof=await transaction.verify(),bound=isProof(proof)&&proof.transactionId===transaction.id;report.transaction.verification=bound&&proof.restored===true?'pass':bound?'fail':'unverified';report.transaction.verificationEvidence=bound?evidence([proof]):[]}catch(error){report.transaction.verification='fail';report.errors.push({stage:'rollback-verify',message:errorText(error)})}
   }else report.cleanup.rollback='not-started';
   try{await driver.dispose();report.cleanup.dispose='pass'}catch(error){report.cleanup.dispose='fail';report.errors.push({stage:'dispose',message:errorText(error)})}
   report.completedAtMs=now();
   const scenarioStatus=aggregate(Object.values(report.scenarios).map(item=>item.status)),performanceStatus=aggregate(Object.values(report.performance).map(item=>item.status)),cleanupStatus=aggregate([report.cleanup.rollback==='pass'||report.cleanup.rollback==='not-started'?'pass':'fail',report.cleanup.dispose==='pass'?'pass':'fail',transaction?report.transaction.verification:'unverified']);
   report.status=aggregate([scenarioStatus,performanceStatus,cleanupStatus]);running=false;finished=true;
  }
  return clone(report);
 }

 return {run,get running(){return running},get finished(){return finished},thresholds};
}
