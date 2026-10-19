import assert from 'node:assert/strict';
import test from 'node:test';
import {createWalkMapEditorLiveQa,WALK_MAP_EDITOR_LIVE_QA_SCHEMA} from './walk_map_editor_live_qa.mjs';

const fixtures={
 movable:{key:'buildings:movable',selectPoint:{x:10,y:10},dragTo:{x:35,y:24}},
 deletable:{key:'decor:deletable',point:{x:70,y:30},dragTo:{x:82,y:44}},
};
const thresholds={minFrameSamples:6,openLatencyMs:100,frameP95Ms:30,longFrameMs:40,maxLongFrameRate:0,idleP95RegressionRatio:1.2,dragP95RegressionRatio:1.5,idleDrawCallRatio:1.2,dragDrawCallRatio:1.3,idleTriangleRatio:1.1,dragTriangleRatio:1.2,minCatalogBatches:1,catalogBatchMs:30,catalogTotalMs:100,relocationToleranceM:.001};

const vec=(x=0,y=0,z=0)=>({x,y,z}),quat=()=>({x:0,y:0,z:0,w:1});
function visualRoot(key){const geometry={index:{count:36},drawRange:{start:0,count:36},groups:[],attributes:{position:{count:24,itemSize:3,normalized:false,usage:35044}}},material={type:'MeshStandardMaterial',name:'building-wall',side:0,transparent:false,opacity:1,alphaTest:0,depthTest:true,depthWrite:true,blending:1,vertexColors:false,toneMapped:true,color:{getHex:()=>0x886644},emissive:{getHex:()=>0},roughness:.72,metalness:.08},mesh={visible:true,layers:{mask:1},castShadow:true,receiveShadow:true,renderOrder:0,frustumCulled:true,matrixAutoUpdate:true,position:vec(),rotation:vec(),quaternion:quat(),scale:vec(1,1,1),geometry,material,children:[]};return {visible:true,layers:{mask:1},castShadow:false,receiveShadow:false,renderOrder:0,frustumCulled:true,matrixAutoUpdate:true,position:vec(),rotation:vec(),quaternion:quat(),scale:vec(1,1,1),children:[mesh],userData:{key}}}

function liveFixture({regression=false,throwOnMove=false,withTransaction=true,transactionCapable=true,omitFrameProbe=false,omitVisualProbe=false,visualRegression=false,missingCatalogRoot=false,reuseVisualProof=false,proofTransactionId='live-test-transaction'}={}){
 let serial=0,clockValue=0,disposed=0,aborted=0,rollbacks=0,verifications=0,actions=0,revision=1,dirty=false;
 const original={
  'buildings:movable':{exists:true,scene:[0,0,0],document:[0,0,0]},
 'decor:deletable':{exists:true,scene:[5,0,5],document:[5,0,5]},
 };
 const buildingRoots=Array.from({length:78},(_,index)=>visualRoot(index===0?'buildings:movable':`buildings:catalog-${index}`)),buildingEntries=buildingRoots.map((root,index)=>({key:index===0?'buildings:movable':`buildings:catalog-${index}`,assetId:`building_asset_${index%22}`,rootIndex:index,root,pickRoot:missingCatalogRoot&&index===10?null:root.children[0],selectRoot:root,protected:index>=1&&index<=8,visible:true,lockReason:index>=1&&index<=8?'Защищено игровым сценарием':null}));
 let objects=structuredClone(original),saved=structuredClone(original),editor={open:false,mode:'top',tool:'select',selectionKey:null},gesture=null;
 const proof=(source,body={})=>({source,sampleId:`sample-${++serial}`,transactionId:proofTransactionId,capturedAtMs:clockValue,...body});
 const snapshot=key=>{const object=objects[key];return proof('live-editor-document',{key,exists:!!object?.exists,scenePositionM:object?.scene?[...object.scene]:null,documentPositionM:object?.document?[...object.document]:null,revision:`rev-${revision}`})};
 const anchor=(key,offset,source)=>{const object=objects[key];return proof(source,{key,pointXZ:object?.exists?[object.scene[0]+offset,object.scene[2]+offset]:null})};
 const driver={
  async key(event){actions++;clockValue+=event.code==='KeyK'?25:2;
   if(event.code==='KeyK')editor.open=!editor.open;
   else if(event.code==='Digit2'&&editor.open)editor.mode='fly';
   else if(event.code==='Digit1'&&editor.open)editor.mode='top';
   else if(event.code==='Escape'&&editor.open){for(const object of Object.values(objects))if(object.exists)object.scene=[...object.document];buildingRoots[0].position.x=objects['buildings:movable'].scene[0];buildingRoots[0].position.z=objects['buildings:movable'].scene[2]}
   else if(event.code==='Enter'&&editor.open){for(const object of Object.values(objects))if(object.exists)object.document=[...object.scene];revision++;dirty=true}
   else if(event.code==='KeyS'&&event.ctrlKey&&editor.open){saved=structuredClone(objects);dirty=false}
  },
  async pointer(event){actions++;clockValue+=1;
   if(event.type==='pointerdown'){gesture={...event,startX:event.clientX,startY:event.clientY,moved:false};if(event.button===0&&editor.tool==='select')editor.selectionKey=event.clientX<50?'buildings:movable':'decor:deletable';return}
   if(event.type==='pointermove'&&gesture){if(throwOnMove)throw new Error('injected pointer failure');gesture.moved ||= Math.hypot(event.clientX-gesture.startX,event.clientY-gesture.startY)>4;if(gesture.button===0&&editor.tool==='move'&&editor.selectionKey==='buildings:movable'){objects['buildings:movable'].scene=[10,0,5];buildingRoots[0].position.x=10;buildingRoots[0].position.z=5}return}
   if(event.type==='pointerup'&&gesture){if(gesture.button===2&&!gesture.moved&&event.clientX===gesture.startX&&event.clientY===gesture.startY){objects['decor:deletable'].exists=false;revision++;dirty=true}gesture=null}
  },
  async setTool(tool){actions++;editor.tool=tool},
  async reloadSaved(){actions++;objects=structuredClone(saved);buildingRoots[0].position.x=objects['buildings:movable'].scene[0];buildingRoots[0].position.z=objects['buildings:movable'].scene[2];revision++},
  async waitFor(){clockValue+=1},
  async abort(){aborted++;editor.open=false;gesture=null;for(const object of Object.values(objects))if(object.exists)object.scene=[...object.document]},
  async dispose(){disposed++},
 };
 const probes={
  editorState:async()=>proof('live-editor-state',structuredClone(editor)),
  objectState:async key=>snapshot(key),
  saveState:async()=>proof('live-storage-state',{dirty,status:dirty?'dirty':'saved'}),
  doorAnchor:async key=>anchor(key,1,'live-door-registry'),
  collisionAnchor:async key=>anchor(key,2,'live-collision-registry'),
  minimapAnchor:async key=>anchor(key,3,'live-minimap-registry'),
  rendererStats:async({phase})=>proof('renderer.info',{drawCalls:phase==='game-before'?100:phase==='editor-idle'?(regression?150:110):(regression?180:120),triangles:phase==='game-before'?100000:phase==='editor-idle'?(regression?140000:105000):(regression?170000:110000)}),
 catalogBatches:async()=>proof('live-catalog-loader',{batches:[{count:500,durationMs:12},{count:700,durationMs:18}]})
 };
 const visualBindings=()=>buildingEntries.map(entry=>({rootIndex:entry.rootIndex,key:entry.key,assetId:entry.assetId,lod:'lod0',materialQuality:{shader:'MeshStandardMaterial',textures:'source',shadows:true}}));
 if(!omitVisualProbe)probes.visualState=async({phase})=>{if(visualRegression&&phase==='editor-idle')buildingRoots[20].children[0].material.roughness=.1;const sample=proof('live-visual-parity',{phase,roots:buildingRoots,bindings:visualBindings()});if(reuseVisualProof)sample.sampleId='reused-visual-proof';return sample};
 probes.buildingCatalogProof=async()=>proof('live-building-catalog',{buildings:buildingEntries});
 if(!omitFrameProbe)probes.sampleFrames=async({phase})=>proof('requestAnimationFrame',{frameTimesMs:Array.from({length:8},()=>phase==='game-before'?16:phase==='editor-idle'?(regression?35:17):(regression?48:20))});
 const beginTransaction=withTransaction?async request=>({id:'live-test-transaction',rollbackCapable:transactionCapable&&request.rollbackOnly&&request.includeStorage&&request.includeGameplay,async rollback(){rollbacks++;objects=structuredClone(original);saved=structuredClone(original);buildingRoots[0].position.x=0;buildingRoots[0].position.z=0;dirty=false;editor.open=false},async verify(){verifications++;return proof('live-transaction-verifier',{restored:sameObjects(objects,original)&&sameObjects(saved,original)&&dirty===false})}}):undefined;
 return {driver,probes,beginTransaction,clock:()=>clockValue,stats:()=>({disposed,aborted,rollbacks,verifications,actions}),objects:()=>objects};
}

function sameObjects(a,b){return JSON.stringify(a)===JSON.stringify(b)}

test('complete injected LIVE evidence passes acceptance/performance and always rolls back',async()=>{
 const live=liveFixture(),qa=createWalkMapEditorLiveQa({driver:live.driver,probes:live.probes,fixtures,beginTransaction:live.beginTransaction,thresholds,clock:live.clock,now:()=>1234});
 const report=await qa.run();assert.equal(report.schema,WALK_MAP_EDITOR_LIVE_QA_SCHEMA);assert.equal(report.status,'pass');assert.equal(report.scenarios['k-open-close'].status,'pass');assert.equal(report.scenarios['top-fly'].status,'pass');assert.equal(report.scenarios['select-move-cancel-commit'].status,'pass');assert.equal(report.scenarios['rmb-delete-vs-drag'].status,'pass');assert.equal(report.scenarios['save-reload'].status,'pass');assert.equal(report.scenarios.relocation.status,'pass');
 assert.equal(report.scenarios['visual-parity'].status,'pass');assert.equal(report.scenarios['catalog-buildings'].status,'pass');assert.equal(report.scenarios['visual-parity'].checks.length,11);assert.ok(report.scenarios['visual-parity'].checks.every(item=>item.evidence.length>=1));
 assert.equal(report.performance.openLatency.status,'pass');assert.equal(report.performance.openLatency.valueMs,26);assert.equal(report.performance.frames.status,'pass');assert.equal(report.performance.renderer.status,'pass');assert.equal(report.performance.catalog.status,'pass');
 assert.deepEqual(live.stats(),{disposed:1,aborted:1,rollbacks:1,verifications:1,actions:22});assert.ok(sameObjects(live.objects(),{'buildings:movable':{exists:true,scene:[0,0,0],document:[0,0,0]},'decor:deletable':{exists:true,scene:[5,0,5],document:[5,0,5]}}));
 await assert.rejects(()=>qa.run(),/single-use/);
});

test('missing transaction dispatches no editor action and cannot report PASS',async()=>{
 const live=liveFixture({withTransaction:false}),qa=createWalkMapEditorLiveQa({driver:live.driver,probes:live.probes,fixtures,thresholds,clock:live.clock});const report=await qa.run();
 assert.equal(report.status,'unverified');assert.equal(report.transaction.reason,'transaction-callback-missing');assert.equal(live.stats().actions,0);assert.equal(live.stats().disposed,1);for(const scenario of Object.values(report.scenarios))assert.equal(scenario.status,'unverified');
});

test('rejected transaction still rolls back its acquired scope without dispatching actions',async()=>{
 const live=liveFixture({transactionCapable:false}),qa=createWalkMapEditorLiveQa({driver:live.driver,probes:live.probes,fixtures,beginTransaction:live.beginTransaction,thresholds,clock:live.clock});const report=await qa.run();
 assert.equal(report.status,'unverified');assert.equal(report.transaction.reason,'rollback-capable-transaction-unavailable');assert.equal(live.stats().actions,0);assert.equal(live.stats().rollbacks,1);assert.equal(live.stats().disposed,1);
});

test('missing real frame samples remain unverified instead of becoming synthetic PASS',async()=>{
 const live=liveFixture({omitFrameProbe:true}),qa=createWalkMapEditorLiveQa({driver:live.driver,probes:live.probes,fixtures,beginTransaction:live.beginTransaction,thresholds,clock:live.clock});const report=await qa.run();
 assert.equal(report.performance.frames.status,'unverified');assert.equal(report.performance.frames.before.reason,'real-frame-samples-missing');assert.equal(report.status,'unverified');assert.equal(live.stats().rollbacks,1);assert.equal(live.stats().disposed,1);
});

test('stale samples from another transaction are rejected as unverified',async()=>{
 const live=liveFixture({proofTransactionId:'stale-transaction'}),qa=createWalkMapEditorLiveQa({driver:live.driver,probes:live.probes,fixtures,beginTransaction:live.beginTransaction,thresholds,clock:live.clock});const report=await qa.run();
 assert.equal(report.status,'unverified');assert.ok(report.errors.some(item=>item.message==='sample-transaction-mismatch'));assert.notEqual(report.performance.openLatency.status,'pass');assert.equal(live.stats().rollbacks,1);assert.equal(live.stats().disposed,1);
});

test('measured regressions fail configurable frame and renderer thresholds',async()=>{
 const live=liveFixture({regression:true}),qa=createWalkMapEditorLiveQa({driver:live.driver,probes:live.probes,fixtures,beginTransaction:live.beginTransaction,thresholds,clock:live.clock});const report=await qa.run();
 assert.equal(report.performance.frames.status,'fail');assert.equal(report.performance.frames.idleEditor.status,'fail');assert.equal(report.performance.renderer.status,'fail');assert.equal(report.status,'fail');assert.equal(live.stats().rollbacks,1);assert.equal(live.stats().disposed,1);
});

test('driver failure still aborts, rolls back, verifies and disposes exactly once',async()=>{
 const live=liveFixture({throwOnMove:true}),qa=createWalkMapEditorLiveQa({driver:live.driver,probes:live.probes,fixtures,beginTransaction:live.beginTransaction,thresholds,clock:live.clock});const report=await qa.run();
 assert.equal(report.status,'fail');assert.ok(report.errors.some(item=>item.message==='injected pointer failure'));assert.deepEqual(live.stats(),{disposed:1,aborted:1,rollbacks:1,verifications:1,actions:8});assert.equal(report.cleanup.rollback,'pass');assert.equal(report.cleanup.dispose,'pass');assert.equal(report.transaction.verification,'pass');
});

test('missing visual snapshot or selectable catalog root can never report PASS',async()=>{
 const missingVisual=liveFixture({omitVisualProbe:true}),visualQa=createWalkMapEditorLiveQa({driver:missingVisual.driver,probes:missingVisual.probes,fixtures,beginTransaction:missingVisual.beginTransaction,thresholds,clock:missingVisual.clock}),visualReport=await visualQa.run();assert.notEqual(visualReport.status,'pass');assert.equal(visualReport.scenarios['visual-parity'].status,'unverified');assert.equal(missingVisual.stats().rollbacks,1);assert.equal(missingVisual.stats().disposed,1);
 const missingRoot=liveFixture({missingCatalogRoot:true}),rootQa=createWalkMapEditorLiveQa({driver:missingRoot.driver,probes:missingRoot.probes,fixtures,beginTransaction:missingRoot.beginTransaction,thresholds,clock:missingRoot.clock}),rootReport=await rootQa.run();assert.equal(rootReport.scenarios['catalog-buildings'].status,'fail');assert.ok(rootReport.scenarios['catalog-buildings'].checks.some(item=>item.detail.some(issue=>issue.code==='BUILDING_PICK_ROOT_MISSING')));assert.equal(missingRoot.stats().rollbacks,1);assert.equal(missingRoot.stats().disposed,1);
});

test('visual quality regression and reused proof are rejected with cleanup',async()=>{
 const degraded=liveFixture({visualRegression:true}),degradedQa=createWalkMapEditorLiveQa({driver:degraded.driver,probes:degraded.probes,fixtures,beginTransaction:degraded.beginTransaction,thresholds,clock:degraded.clock}),degradedReport=await degradedQa.run();assert.equal(degradedReport.scenarios['visual-parity'].status,'fail');assert.ok(degradedReport.scenarios['visual-parity'].checks.some(item=>item.detail?.some?.(issue=>issue.code==='MATERIAL_CHANGED')));assert.equal(degraded.stats().rollbacks,1);assert.equal(degraded.stats().disposed,1);
 const reused=liveFixture({reuseVisualProof:true}),reusedQa=createWalkMapEditorLiveQa({driver:reused.driver,probes:reused.probes,fixtures,beginTransaction:reused.beginTransaction,thresholds,clock:reused.clock}),reusedReport=await reusedQa.run();assert.notEqual(reusedReport.status,'pass');assert.equal(reusedReport.scenarios['visual-parity'].status,'unverified');assert.equal(reused.stats().rollbacks,1);assert.equal(reused.stats().disposed,1);
});
