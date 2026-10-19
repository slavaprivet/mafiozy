import assert from 'node:assert/strict';
import test from 'node:test';
import {createWalkMapEditorLiveBootstrap} from './walk_map_editor_live_bootstrap.mjs';
import {WALK_MAP_DECOR_DEPENDENCIES,WALK_MAP_DECOR_PREPARE_ADAPTER_ID} from './walk_map_editor_decor_prepare.mjs';

const rows=10,cols=10,M=4.1,matrix=value=>Array.from({length:rows},()=>Array(cols).fill(value));
function vector(x=0,y=0,z=0){return {x,y,z,fromArray(value){[this.x,this.y,this.z]=value;return this},set(a,b,c){this.x=a;this.y=b;this.z=c;return this}}}
function rootFor(record){const root={userData:{instance:record},position:vector(...record.transform.positionM),rotation:{y:record.transform.yawDegrees*Math.PI/180},scale:vector(1,1,1),visible:true,updateMatrixWorld(){}};return root}
function sourcesFor(record){
 const protectedMask=matrix(0);protectedMask[3][7]=1;
 const topology={schema:'mafiozy.city-rebuild-placement-topology/v1',map:{rows,cols,worldUnitsPerCell:M},grid:matrix(8),roadMask:matrix(0),walkableMask:matrix(1),protectedMask,policeMask:matrix(0),bridgeDeckMask:matrix(0)};
 const buildings={schema:'mafiozi.city-rebuild.buildings-placement/v1',counts:{instances:0,assetTypesPlaced:0,residences:0},instances:[]};
 const detention={version:1,instances:[]};
 const decor={schema:'mafiozi.city-rebuild.decor-plan/v1',counts:{instances:1,lamps:1,fountains:0},instances:[record]};
 const custom={schema:'mafiozi.walk-map-editor.custom/v1',status:'empty',counts:{instances:0},instances:[]};
 return Object.fromEntries(Object.entries({topology,buildings,detention,decor,custom}).map(([name,value])=>[name,{text:JSON.stringify(value),revision:`${name}-decor-integration-v1`}]))
}
function harness(){
 const record={id:'DECOR-LAMP-1',assetId:'lamp_civic_double_v1',binding:{kind:'authored',source:'fixture'},hideNodeNames:['Bulb.Day'],unknownTop:{keep:'exact'},transform:{positionM:[12.3,0,12.3],yawDegrees:0,uniformScale:1,horizontalScale:[1,1],modelLocalOffsetM:[.2,0,-.1]},r:3,c:3,clearancePolygonCR:[[2.8,2.8],[3.2,2.8],[3.2,3.2],[2.8,3.2]],collision:{scaleApplied:1,worldBodies:[{id:'lamp-body',polygonCR:[[2.8,2.8],[3.2,2.8],[3.2,3.2],[2.8,3.2]],minYM:0,maxYM:3,unknownBody:true}]}};
 const root=rootFor(record),groups=[root],memory=new Map(),rebuilds=[];let hooks,failCommitted=false;
 const target={addEventListener(){},removeEventListener(){}};
 class V2{set(){return this}}class V3{constructor(x=0,y=0,z=0){this.x=x;this.y=y;this.z=z}clone(){return new V3(this.x,this.y,this.z)}}class Plane{}class Raycaster{constructor(){this.ray={intersectPlane:(_plane,out)=>out}}setFromCamera(){}intersectObjects(){return []}}
 const runtime={active:true,selection:null,refreshCatalog(){},setSaveState(){},dispose:async()=>{}};
 const live={THREE:{Vector2:V2,Vector3:V3,Plane,Raycaster},renderer:{domElement:{getBoundingClientRect:()=>({left:0,top:0,width:100,height:100})}},scene:{add(){},remove(){}},camera:{},controls:{},getPickRoots:()=>groups,groundHeight:()=>0,selectionVisual:false,target};
 const services={storage:{getItem:key=>memory.get(key)??null,setItem:(key,value)=>memory.set(key,value),removeItem:key=>memory.delete(key)},loadTemplate:async()=>({}),compileAssetRecord:()=>({ok:false}),parkingKeepouts:()=>[],requestRebuild:async meta=>{rebuilds.push(structuredClone(meta));if(failCommitted&&meta.committed&&!meta.rollback){failCommitted=false;throw new Error('fixture rebuild rejected')}return {groups}},releaseControls(){},enterGameEditor(){},leaveGameEditor(){},createRuntime:options=>{hooks=options.hooks;return runtime},createCamera:()=>({enter(){},restore(){return true},setMode(){return true},handleAction(){return false},update(){},dispose(){}}),now:()=> '2026-09-23T18:00:00.000Z',pickImportText:async()=>null,download:async()=>{},createBlob:()=>({}),createFilesDialog:()=>({open(){},dispose(){}})};
 const bootstrap=createWalkMapEditorLiveBootstrap({rawSources:sourcesFor(record),live,services,groups,documentId:'decor-live-integration',createdAt:'2026-09-23T17:59:00.000Z'});
 return {record,root,runtime,rebuilds,bootstrap,hooks,failNext(){failCommitted=true}};
}

test('authored decor commits derived record with exact dependencies and survives delete/undo lifecycle',async()=>{
 const h=harness(),item=h.bootstrap.adapter.enumerate().find(value=>value.id===h.record.id);assert.ok(item);assert.equal(item.locked,false);
 h.runtime.selection={key:item.key};h.bootstrap.adapter.beginPreview(item.key);h.bootstrap.adapter.updatePreview(item.key,{positionM:[16.4,0,12.3]});
 assert.equal(await h.hooks.commit(),true);assert.equal(h.bootstrap.session.revision,1);
 const patch=h.bootstrap.document.objectPatches.find(value=>value.source.id===h.record.id);assert.equal(patch.metadata.adapter,WALK_MAP_DECOR_PREPARE_ADAPTER_ID);assert.deepEqual(patch.metadata.dependencies,WALK_MAP_DECOR_DEPENDENCIES);assert.equal(patch.after.unknownTop.keep,'exact');assert.deepEqual(patch.after.binding,h.record.binding);assert.deepEqual(patch.after.hideNodeNames,h.record.hideNodeNames);assert.deepEqual(patch.after.transform.modelLocalOffsetM,h.record.transform.modelLocalOffsetM);assert.deepEqual(patch.after.clearancePolygonCR,[[3.8,2.8],[4.2,2.8],[4.2,3.2],[3.8,3.2]]);
 assert.deepEqual([h.root.position.x,h.root.position.y,h.root.position.z],[16.4,0,12.3]);assert.deepEqual([h.root.scale.x,h.root.scale.y,h.root.scale.z],[1,1,1]);
 assert.equal(await h.hooks.deleteObject({item,confirmed:true}),true);assert.equal(h.bootstrap.session.revision,2);assert.equal(h.root.visible,false);assert.equal(h.bootstrap.adapter.enumerate().some(value=>value.key===item.key),false);
 assert.equal(await h.hooks.undo(),true);assert.equal(h.bootstrap.session.revision,3);assert.equal(h.root.visible,true);assert.equal(h.bootstrap.adapter.enumerate().some(value=>value.key===item.key),true);assert.deepEqual([h.root.position.x,h.root.position.z],[16.4,12.3]);
 await h.bootstrap.dispose();
});

test('protected rejection and failed rebuild roll document and root back to authoritative decor',async()=>{
 const h=harness(),item=h.bootstrap.adapter.enumerate().find(value=>value.id===h.record.id);h.runtime.selection={key:item.key};
 h.bootstrap.adapter.beginPreview(item.key);h.bootstrap.adapter.updatePreview(item.key,{positionM:[16.4,0,12.3]});await h.hooks.commit();const revision=h.bootstrap.session.revision;
 h.bootstrap.adapter.beginPreview(item.key);h.bootstrap.adapter.updatePreview(item.key,{positionM:[28.7,0,12.3]});await assert.rejects(()=>h.hooks.commit(),error=>error?.code==='DECOR_ON_PROTECTED');assert.equal(h.bootstrap.session.revision,revision);assert.deepEqual([h.root.position.x,h.root.position.z],[16.4,12.3]);assert.equal(h.root.visible,true);
 h.bootstrap.adapter.beginPreview(item.key);h.bootstrap.adapter.updatePreview(item.key,{positionM:[20.5,0,12.3],yawDegrees:45,uniformScale:1.2,horizontalScale:[1.3,.7]});h.failNext();await assert.rejects(()=>h.hooks.commit(),/fixture rebuild rejected/);assert.equal(h.bootstrap.session.revision,revision);assert.deepEqual([h.root.position.x,h.root.position.y,h.root.position.z],[16.4,0,12.3]);assert.equal(h.root.rotation.y,0);assert.deepEqual([h.root.scale.x,h.root.scale.y,h.root.scale.z],[1,1,1]);assert.equal(h.root.visible,true);assert.ok(h.rebuilds.some(meta=>meta.rollback===true));
 await h.bootstrap.dispose();
});
