import assert from 'node:assert/strict';
import test from 'node:test';
import {readFile} from 'node:fs/promises';
import {createWalkMapEditorDocument,walkMapEditorCanonicalDigest} from './walk_map_editor_document.mjs';
import {walkMapEditorArtifactSha256} from './walk_map_editor_compile.mjs';
import {WALK_MAP_EDITOR_SCENE_BUILD_PROOF_SCHEMA} from './walk_map_editor_scene_rebuild_bridge.mjs';
import {createLandscapePlan} from './landscape_plan.mjs';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';
import {createCityParkingPlan} from './city_parking_plan.mjs';
import {createCityRoadDressingPlan} from './city_road_dressing_plan.mjs';
import {planExplorationDecor} from './exploration_decor_plan.mjs';
import {applyWalkMapEditorProductionRootTransform,auditWalkMapEditorProductionAdapterSourceContract,createWalkMapEditorProductionAdapter,WALK_MAP_EDITOR_PRODUCTION_CONTEXT_SCHEMA,walkMapEditorProductionPlanDigest,walkMapEditorProductionPlanSemantic,walkMapEditorProductionPlanSnapshot,walkMapEditorProductionScale} from './walk_map_editor_production_adapter.mjs';

class FakeTarget{
 constructor(){this.listeners=new Map()}
 addEventListener(type,handler,options=false){const list=this.listeners.get(type)||[];list.push({handler,capture:options===true||!!options?.capture});this.listeners.set(type,list)}
 removeEventListener(type,handler,options=false){const capture=options===true||!!options?.capture;this.listeners.set(type,(this.listeners.get(type)||[]).filter(item=>item.handler!==handler||item.capture!==capture))}
 emit(type,init={}){const target=init.target||{tagName:'CANVAS'},event={type,target,code:'',repeat:false,isComposing:false,keyCode:0,defaultPrevented:false,altKey:false,ctrlKey:false,metaKey:false,preventDefault(){this.defaultPrevented=true},stopPropagation(){},stopImmediatePropagation(){this.immediate=true},composedPath(){return [target]},...init};for(const item of [...(this.listeners.get(type)||[])]){item.handler(event);if(event.immediate)break}return event}
 count(type){return (this.listeners.get(type)||[]).length}
}
const deferred=()=>{let resolve,reject;const promise=new Promise((yes,no)=>{resolve=yes;reject=no});return {promise,resolve,reject}};
const pressK=target=>target.emit('keydown',{code:'KeyK'});
const settle=async adapter=>{await adapter.seam.gate.whenSettled();await adapter.controller?.whenSettled();await Promise.resolve()};
const buildingRecords=Array.from({length:75},(_,index)=>({id:`building-${index}`,r:index,c:index,transform:{uniformScale:1,horizontalScale:[1,1]}}));
const detentionRecords=Array.from({length:3},(_,index)=>({id:`detention-${index}`,role:'district_detention',r:index,c:index,transform:{uniformScale:1,horizontalScale:[1,1]}}));
const decorRecords=Array.from({length:164},(_,index)=>({id:`decor-${index}`,r:index,c:index}));
const allBuildingRecords=[...buildingRecords,...detentionRecords],buildingIds=allBuildingRecords.map(record=>record.id);
const root=id=>({userData:{instance:{id}},position:{fromArray(value){this.value=[...value]}},rotation:{y:0},scale:{set(...value){this.value=value}},updateWorldMatrix(){this.updated=true}});
const raw=(value,revision)=>({text:JSON.stringify(value),revision});
const revisions={topology:'top-r1',buildings:'build-r1',decor:'decor-r1',detention:'det-r1',custom:'custom-r1'};
const rawSources={topology:raw({map:{rows:200,cols:180,worldUnitsPerCell:4.1},grid:Array.from({length:200},()=>[])},revisions.topology),buildings:raw({instances:buildingRecords},revisions.buildings),decor:raw({instances:decorRecords},revisions.decor),detention:raw({instances:detentionRecords},revisions.detention),custom:raw({instances:[]},revisions.custom)};
const plans=label=>({roadDressing:{label,items:[]},parking:{label,lots:[]},explorationDecor:{label,objects:[]},railway:{label,tracks:[]}});

function fixture({verifyMutate=null,captureWait=null,moduleWait=null,bridgeFactory=null,sourceMutate=null,subscribeMode='ok'}={}){
 const target=new FakeTarget(),stats={capture:0,verify:0,module:0,bootstrap:0,bridge:0,subscribe:0,unsubscribe:0,updates:[],inputCapture:0,inputRestore:0,clear:0,menus:0,pointer:0,refresh:0,enter:0,leave:0,dispose:0},frame={callback:null},gameplay={camera:[1,2,3],controls:true,pointer:true},saved=structuredClone(gameplay);
 const roots={buildings:allBuildingRecords.map(record=>root(record.id)),decor:decorRecords.map(record=>root(record.id))};
 const input={captureGameplayState(){stats.inputCapture++;return structuredClone(gameplay)},restoreGameplayState(value){stats.inputRestore++;Object.assign(gameplay,structuredClone(value))},clearHeldKeys(){stats.clear++},closeConflictingMenus(){stats.menus++},releasePointerLock(){stats.pointer++;gameplay.pointer=false},refreshInput(){stats.refresh++}};
 const services={loadTemplate(){},compileAssetRecord(){},releaseControls(){gameplay.controls=false},enterGameEditor(){stats.enter++},leaveGameEditor(){stats.leave++},pickImportText(){},download(){},storage:{getItem(){},setItem(){},removeItem(){}}};
 const live={THREE:{},renderer:{domElement:{}},scene:{add(){},remove(){}},camera:{},controls:{},getPickRoots(){return []},groundHeight(){return 0}};
 const baseRebuild={compileArtifacts(){throw new Error('unused compile')},buildGeneration(){throw new Error('unused build')},snapshotGeneration(){},installGeneration(){},verifyInstalled(){},restoreGeneration(){}};
 const contextSnapshot={schema:WALK_MAP_EDITOR_PRODUCTION_CONTEXT_SCHEMA,token:'world-token-1',rawSources:structuredClone(rawSources),roots,generatedPlans:plans('initial'),live,services,input,rebuild:baseRebuild};sourceMutate?.(contextSnapshot);
 const runtimeContext={
  async captureEditorContext(){stats.capture++;if(captureWait)await captureWait.promise;return contextSnapshot},
  async verifyEditorContext(){stats.verify++;const value={ok:true,token:contextSnapshot.token,sourceRevisions:{...revisions}};return verifyMutate?verifyMutate(value,contextSnapshot):value},
  subscribeFrame(callback){stats.subscribe++;if(subscribeMode==='throw')throw new Error('frame subscribe failed');if(subscribeMode==='invalid')return null;frame.callback=callback;return()=>{stats.unsubscribe++;frame.callback=null}}
 };
 const seenOptions={value:null},module={createWalkMapEditorLiveBootstrap:async options=>{stats.bootstrap++;seenOptions.value=options;const runtime={active:false,async open(){await options.services.releaseControls();await options.services.enterGameEditor();runtime.active=true;return true},async close(){if(!runtime.active)return true;await options.services.leaveGameEditor();runtime.active=false;return true}};return {host:{runtime,update(dt){stats.updates.push(dt)}},async dispose(){stats.dispose++;await runtime.close()}}}};
 const loadBootstrapModule=async()=>{stats.module++;if(moduleWait)await moduleWait.promise;return module};
 const createRebuildBridge=bridgeFactory||((options)=>{stats.bridge++;return {requestRebuild(){},dispose(){return Promise.resolve()},options}}),errors=[],adapterOptions={target,document:{activeElement:null},rendererSelection:{render:'3d',renderer:'walk'},runtimeContext,loadBootstrapModule,onError:(error,stage)=>errors.push({error,stage})};
 if(bridgeFactory!=='real')adapterOptions.createRebuildBridge=createRebuildBridge;
 const adapter=createWalkMapEditorProductionAdapter(adapterOptions);
 return {adapter,target,stats,frame,gameplay,saved,contextSnapshot,roots,errors,seenOptions};
}

test('horizontalScale is exactly [uniform*hx, uniform, uniform*hz] and does not touch materials',()=>{
 assert.deepEqual(walkMapEditorProductionScale({uniformScale:2,horizontalScale:[3,.5]}),[6,2,1]);const material={name:'untouched'},node=root('scaled');node.material=material;applyWalkMapEditorProductionRootTransform(node,{r:4,c:5,transform:{positionM:[10,2,20],yawDegrees:90,uniformScale:2,horizontalScale:[3,.5]}},{metresPerCell:4.1});assert.deepEqual(node.position.value,[10,2,20]);assert.deepEqual(node.scale.value,[6,2,1]);assert.ok(Math.abs(node.rotation.y-Math.PI/2)<1e-12);assert.equal(node.material,material);assert.equal(node.updated,true);
 assert.throws(()=>walkMapEditorProductionScale({uniformScale:1,horizontalScale:[1]}),error=>error.code==='PRODUCTION_TRANSFORM_INVALID');
});

test('no runtime, source, plan, root, GLB or frame work occurs before the first clean K',async()=>{
 const f=fixture();assert.deepEqual(f.stats,{capture:0,verify:0,module:0,bootstrap:0,bridge:0,subscribe:0,unsubscribe:0,updates:[],inputCapture:0,inputRestore:0,clear:0,menus:0,pointer:0,refresh:0,enter:0,leave:0,dispose:0});assert.equal(f.target.count('keydown'),1);
 pressK(f.target);await settle(f.adapter);assert.equal(f.stats.module,1);assert.equal(f.stats.capture,1);assert.equal(f.stats.verify,1);assert.equal(f.stats.bridge,1);assert.equal(f.stats.bootstrap,1);assert.equal(f.stats.subscribe,1);assert.equal(f.adapter.snapshot.buildingRoots.roots.length,78);assert.equal(f.adapter.snapshot.decorRoots.roots.length,164);assert.equal(f.adapter.controller.active,true);f.frame.callback({dt:.016});assert.deepEqual(f.stats.updates,[.016]);
 f.adapter.controller.toggle();await f.adapter.controller.whenSettled();assert.deepEqual(f.gameplay,f.saved);await f.adapter.dispose();assert.equal(f.stats.unsubscribe,1);assert.equal(f.stats.dispose,1);assert.equal(f.target.count('keydown'),0);
});

test('repeated K parity is preserved while module/context creation is asynchronous',async()=>{
 const moduleWait=deferred(),even=fixture({moduleWait});pressK(even.target);pressK(even.target);moduleWait.resolve();await settle(even.adapter);assert.equal(even.adapter.controller.active,false);assert.equal(even.stats.capture,1);assert.equal(even.stats.inputCapture,0);await even.adapter.dispose();
 const captureWait=deferred(),odd=fixture({captureWait});pressK(odd.target);await Promise.resolve();pressK(odd.target);pressK(odd.target);captureWait.resolve();await settle(odd.adapter);assert.equal(odd.adapter.controller.active,true);assert.equal(odd.stats.inputCapture,1);await odd.adapter.dispose();assert.deepEqual(odd.gameplay,odd.saved);
});

test('stale revisions and incomplete inventories fail closed before bridge/bootstrap/input ownership',async()=>{
 const stale=fixture({verifyMutate:value=>({...value,sourceRevisions:{...value.sourceRevisions,decor:'decor-r2'}})});pressK(stale.target);await settle(stale.adapter);assert.equal(stale.adapter.seam.gate.state,'idle');assert.equal(stale.stats.bridge,0);assert.equal(stale.stats.bootstrap,0);assert.equal(stale.stats.inputCapture,0);assert.equal(stale.errors[0].error.code,'PRODUCTION_CONTEXT_STALE');await stale.adapter.dispose();
 for(const mutate of [snapshot=>snapshot.roots.buildings.pop(),snapshot=>snapshot.roots.decor.pop(),snapshot=>delete snapshot.generatedPlans.railway,snapshot=>delete snapshot.rawSources.detention]){const f=fixture({sourceMutate:mutate});pressK(f.target);await settle(f.adapter);assert.equal(f.stats.bridge,0);assert.equal(f.stats.bootstrap,0);assert.ok(f.errors[0].error.code.startsWith('PRODUCTION_'));await f.adapter.dispose()}
});

test('dispose during capture prevents late bootstrap, frame subscription and ownership',async()=>{
 const wait=deferred(),f=fixture({captureWait:wait});pressK(f.target);for(let i=0;i<8&&!f.stats.capture;i++)await Promise.resolve();assert.equal(f.stats.capture,1);const disposal=f.adapter.dispose();wait.resolve();await disposal;assert.equal(f.stats.bootstrap,0);assert.equal(f.stats.subscribe,0);assert.equal(f.stats.inputCapture,0);assert.equal(f.adapter.disposed,true);assert.equal(f.adapter.snapshot,null);
});

test('frame subscription failure rejects ready state and disposes bootstrap before gameplay ownership',async()=>{
 for(const subscribeMode of ['throw','invalid']){const f=fixture({subscribeMode});pressK(f.target);await settle(f.adapter);assert.equal(f.adapter.seam.gate.state,'idle');assert.equal(f.adapter.controller,null);assert.equal(f.stats.bootstrap,1);assert.equal(f.stats.dispose,1);assert.equal(f.stats.inputCapture,0);assert.equal(f.stats.enter,0);assert.equal(f.stats.subscribe,1);assert.equal(f.errors.length,1);assert.match(f.errors[0].error.message,/frame subscribe|unsubscribe function/);await f.adapter.dispose();assert.deepEqual(f.gameplay,f.saved)}
});

test('actual generated plans retain runtime capabilities while semantic snapshots remain stable and unmodified',async()=>{
 const here=new URL('.',import.meta.url),[topology,buildings,decor]=await Promise.all(['topology_for_placement.json','buildings_placement.v1.json','decor_placement.v1.json'].map(async name=>JSON.parse(await readFile(new URL(name,here),'utf8')))),landscape=createLandscapePlan(),railway=createExplorationRailwayPlan({landscape,topology}),instances=[...buildings.instances,...decor.instances],actual={roadDressing:createCityRoadDressingPlan({topology,landscape,railPlan:railway,instances}),parking:createCityParkingPlan({topology,instances,railPlan:railway}),explorationDecor:planExplorationDecor({terrain:landscape,topology,buildings:buildings.instances,existingDecor:decor.instances,railPlan:railway}),railway};
 const functions={isRoad:actual.roadDressing.isRoad,blocksPlacement:actual.railway.blocksPlacement,groundHeight:actual.railway.landscape.groundHeight,waterAt:actual.railway.landscape.waterAt},counts={markings:actual.roadDressing.markings.length,lots:actual.parking.lots.length,objects:actual.explorationDecor.objects.length,points:actual.railway.points.length},digests=Object.fromEntries(Object.entries(actual).map(([name,plan])=>[name,walkMapEditorProductionPlanDigest(plan)])),snapshot=walkMapEditorProductionPlanSnapshot(actual);
 assert.equal(Object.isFrozen(snapshot),true);for(const name of Object.keys(actual))assert.equal(snapshot[name],actual[name]);assert.equal(snapshot.roadDressing.isRoad,functions.isRoad);assert.equal(snapshot.railway.blocksPlacement,functions.blocksPlacement);assert.equal(snapshot.railway.landscape.groundHeight,functions.groundHeight);assert.equal(snapshot.railway.landscape.waterAt,functions.waterAt);assert.ok(Object.keys(walkMapEditorProductionPlanSemantic(actual.railway)).length>0);
 const f=fixture({bridgeFactory:'real',sourceMutate:value=>{value.generatedPlans=actual}});pressK(f.target);await settle(f.adapter);const loaded=await f.seenOptions.value.generatedPlanLoader();for(const name of Object.keys(actual))assert.equal(loaded[name],actual[name]);assert.deepEqual(Object.fromEntries(Object.entries(actual).map(([name,plan])=>[name,walkMapEditorProductionPlanDigest(plan)])),digests);assert.deepEqual({markings:actual.roadDressing.markings.length,lots:actual.parking.lots.length,objects:actual.explorationDecor.objects.length,points:actual.railway.points.length},counts);assert.deepEqual(functions,{isRoad:actual.roadDressing.isRoad,blocksPlacement:actual.railway.blocksPlacement,groundHeight:actual.railway.landscape.groundHeight,waterAt:actual.railway.landscape.waterAt});await f.adapter.dispose();
});

const stable=value=>Array.isArray(value)?value.map(stable):value&&typeof value==='object'?Object.fromEntries(Object.keys(value).sort().map(key=>[key,stable(value[key])])):value;
const json=value=>JSON.stringify(stable(value));
const artifact=value=>{const text=json(value);return {value:structuredClone(value),json:text,sha256:walkMapEditorArtifactSha256(text)}};
const sourceSha={topology:'1'.repeat(64),buildings:'2'.repeat(64),decor:'3'.repeat(64),custom:'4'.repeat(64)};
const editorDocument=label=>createWalkMapEditorDocument({documentId:`prod-${label}`,createdAt:'2026-09-23T20:00:00.000Z',metadata:{label},base:{topology:{sha256:sourceSha.topology,revision:'t'},buildings:{sha256:sourceSha.buildings,revision:'b'},decor:{sha256:sourceSha.decor,revision:'d'},extensions:{custom:{sha256:sourceSha.custom,revision:'c'}}}});
const evidence=label=>({ok:true,sampleId:label,digest:walkMapEditorArtifactSha256(label)});
const visual=label=>{const digest=walkMapEditorArtifactSha256(label);return {ok:true,sampleId:label,beforeDigest:digest,afterDigest:digest}};

test('real rebuild bridge receives scale helper, preserves visual parity and restores on failed rollback verification',async()=>{
 let current={id:'prior'},restores=0,releases=0,rollbackSeen=false,damageVisual=false,failVerify=false,helperProof=null;
 const f=fixture({bridgeFactory:'real'});
 const rebuild=f.contextSnapshot.rebuild;rebuild.isCompileResult=()=>true;rebuild.compileArtifacts=({document})=>{const artifacts={topology:artifact({grid:[[1]],label:document.metadata.label}),buildings:artifact({instances:buildingIds.map(id=>({id}))}),decor:artifact({instances:decorRecords}),custom:artifact({instances:[]})};return {document:structuredClone(document),artifacts,compileReceipt:{documentDigest:walkMapEditorCanonicalDigest(document),sourceDigests:{topology:sourceSha.topology,buildings:sourceSha.buildings,decor:sourceSha.decor},outputDigests:Object.fromEntries(Object.entries(artifacts).map(([name,value])=>[name,value.sha256]))}}};
 rebuild.snapshotGeneration=()=>current;rebuild.buildGeneration=context=>{rollbackSeen ||= context.meta.rollback===true;helperProof=context.productionScale({uniformScale:2,horizontalScale:[3,.5]});const digests=context.expected,makeVisual=name=>damageVisual&&name==='materials'?{...visual(name),afterDigest:'e'.repeat(64)}:visual(name);return {generation:{id:`generation:${context.meta.document.metadata.label}`},groups:[...f.roots.buildings,...f.roots.decor],proof:{schema:WALK_MAP_EDITOR_SCENE_BUILD_PROOF_SCHEMA,signature:digests.signature,documentDigest:digests.documentDigest,sourceDigests:{...digests.sourceDigests},artifactDigests:{...digests.artifactDigests},planDigests:{...digests.planDigests},buildingGroupIds:[...digests.buildingIds],readiness:{collision:evidence('collision'),entry:evidence('entry'),minimap:evidence('minimap')},visual:{parity:makeVisual('parity'),lod:makeVisual('lod'),materials:makeVisual('materials')}}}};
 rebuild.installGeneration=(stage)=>{current=stage.generation;return {groups:stage.groups}};rebuild.verifyInstalled=context=>failVerify?({ok:false,signature:context.expected.signature,sampleId:'failed'}):({ok:true,signature:context.expected.signature,sampleId:'installed',groups:context.stage.groups});rebuild.restoreGeneration=snapshot=>{restores++;current=snapshot};rebuild.releaseGeneration=()=>{releases++};rebuild.disposeGeneration=()=>{};
 pressK(f.target);await settle(f.adapter);const bridge=f.adapter.snapshot.bridge,success=await bridge.requestRebuild({document:editorDocument('success'),generatedPlans:plans('success')});assert.equal(success.ok,true);assert.deepEqual(helperProof,[6,2,1]);assert.equal(releases,1);const prior=current;damageVisual=true;await assert.rejects(()=>bridge.requestRebuild({document:editorDocument('visual'),generatedPlans:plans('visual')}),error=>error.code==='SCENE_REBUILD_VISUAL_DOWNGRADE');assert.equal(current,prior);assert.equal(restores,0,'visual proof fails before install, so prior scene never needs restoration');damageVisual=false;failVerify=true;await assert.rejects(()=>bridge.requestRebuild({document:editorDocument('rollback'),generatedPlans:plans('rollback'),rollback:true}),error=>error.code==='SCENE_REBUILD_LIVE_VERIFY');assert.equal(current,prior);assert.equal(restores,1);assert.equal(rollbackSeen,true);await f.adapter.dispose();
});

test('actual walk/world sources expose exact production adapter anchors including the legacy scale correction seam',async()=>{
 const here=new URL('.',import.meta.url),root=new URL('../../../',import.meta.url),[walkPreviewSource,worldSource,bootstrapSource,authoredAdapterSource,adapterSource]=await Promise.all([readFile(new URL('walk_preview.mjs',here),'utf8'),readFile(new URL('world.html',root),'utf8'),readFile(new URL('walk_map_editor_live_bootstrap.mjs',here),'utf8'),readFile(new URL('walk_map_editor_authored_adapter.mjs',here),'utf8'),readFile(new URL('walk_map_editor_production_adapter.mjs',here),'utf8')]),audit=auditWalkMapEditorProductionAdapterSourceContract({walkPreviewSource,worldSource,bootstrapSource,authoredAdapterSource,adapterSource});assert.equal(audit.complete,true);for(const [name,value] of Object.entries(audit.checks))assert.equal(value,true,name);
});
