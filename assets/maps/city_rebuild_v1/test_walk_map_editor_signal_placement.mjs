import assert from 'node:assert/strict';
import test from 'node:test';
import {readFile} from 'node:fs/promises';
import {createLandscapePlan} from './landscape_plan.mjs';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';
import {createCityRoadDressingPlan} from './city_road_dressing_plan.mjs';
import {createCityParkingPlan} from './city_parking_plan.mjs';
import {createWalkMapEditorPalette} from './walk_map_editor_palette.mjs';
import {createWalkMapAssetPlacement} from './walk_map_editor_asset_placement.mjs';
import {createWalkMapEditorWalkHost} from './walk_map_editor_walk_host.mjs';
import {createWalkMapSignalCommandPreparer,createWalkMapSignalDeleteCommand,createWalkMapSignalPlacement,createWalkMapSignalTransformCommand,WALK_MAP_ROAD_SIGN_ASSETS,WALK_MAP_ROAD_SIGN_DEPENDENCIES,WALK_MAP_SIGNAL_ADAPTER_ID,WALK_MAP_SIGNAL_ASSETS,WALK_MAP_SIGNAL_DEPENDENCIES,WALK_MAP_SIGNAL_SCHEMA} from './walk_map_editor_signal_placement.mjs';

const here=new URL('.',import.meta.url),read=async name=>JSON.parse(await readFile(new URL(name,here),'utf8')),M=4.1,HASH='a'.repeat(64);
const [topology,buildingPlacement,decorPlacement,decorCatalog,buildingCatalog]=await Promise.all([read('topology_for_placement.json'),read('buildings_placement.v1.json'),read('decor_placement.v1.json'),read('decor_catalog.v1.json'),read('buildings_catalog.v1.json')]);
const assetById=new Map(decorCatalog.entries.map(entry=>[entry.assetId,{...entry,binding:entry.lods?.find(lod=>lod.lod===0)}]));
let actualPromise=null;
async function actual(){return actualPromise??=(async()=>{const buildings=buildingPlacement.instances,instances=[...buildings,...decorPlacement.instances],landscape=createLandscapePlan(),railPlan=createExplorationRailwayPlan({topology,landscape}),roadPlan=createCityRoadDressingPlan({topology,landscape,railPlan,instances}),parking=createCityParkingPlan({topology,instances,railPlan}),inventory={complete:{buildings:true,parking:true,controls:true},buildings,parkingKeepouts:[...parking.keepouts,...parking.accessKeepouts],controls:[]};return {roadPlan,inventory,placement:createWalkMapSignalPlacement({topology,roadPlan,inventory})}})()}
function compileNearAny(placement,roadPlan,asset){let last;for(const junction of roadPlan.junctionRules)try{return placement.compileAssetRecord({asset,transform:{positionM:[junction.x,0,junction.z],yawDegrees:0}})}catch(error){last=error}throw last}

test('all six proven models snap against the real topology and road dressing plan',async()=>{
 const {placement,roadPlan}=await actual(),results=new Map();
 for(const assetId of [...WALK_MAP_SIGNAL_ASSETS,...WALK_MAP_ROAD_SIGN_ASSETS]){const result=compileNearAny(placement,roadPlan,assetById.get(assetId));assert.equal(result.ok,true,assetId);assert.equal(result.dataset,'custom');assert.equal(result.record.schema,WALK_MAP_SIGNAL_SCHEMA);assert.equal(result.record.assetId,assetId);assert.match(result.record.id,/^road-control:/);assert.equal(result.record.protection.validated,true);assert.deepEqual(result.dependencies,WALK_MAP_SIGNAL_ASSETS.includes(assetId)?WALK_MAP_SIGNAL_DEPENDENCIES:WALK_MAP_ROAD_SIGN_DEPENDENCIES);results.set(assetId,result)}
 assert.ok(results.get('traffic_signal_4way_v1').record.trafficControl.approachIds.length>=4);assert.equal(results.get('traffic_signal_t_junction_v1').record.trafficControl.approachIds.length,3);
 const arm=results.get('traffic_signal_arm_v1').record;assert.equal(arm.trafficControl.paired,true);assert.equal(arm.trafficControl.approachIds.length,2);assert.equal(arm.render.modelMode,'paired-instances');assert.equal(arm.render.instances.length,2);
 for(const id of WALK_MAP_ROAD_SIGN_ASSETS){const record=results.get(id).record;assert.equal(record.snap.mode,'road-edge');assert.ok(['left','right'].includes(record.snap.side));assert.ok(Number.isFinite(record.transform.yawDegrees))}
 const first=results.get('sign_wayfinding'),repeat=placement.compileAssetRecord({asset:assetById.get('sign_wayfinding'),transform:{positionM:first.record.snap.requestedPositionM,yawDegrees:73}});assert.equal(repeat.record.id,first.record.id);assert.equal(repeat.record.semanticKey,first.record.semanticKey);assert.notEqual(repeat.record.transform.yawDegrees,73,'road edge owns sign yaw');
});

function matrices(value,rows=24,cols=24){return Array.from({length:rows},()=>Array(cols).fill(value))}
function approaches(id,cx,cz,count=4){const dirs=[{x:1,z:0},{x:-1,z:0},{x:0,z:1},{x:0,z:-1}];return dirs.slice(0,count).map((outward,index)=>({id:`${id}:A${index}`,roadId:`${id}:R${index}`,controlCenter:{x:cx+outward.x*3,z:cz+outward.z*3},outward,width:5,axis:index<2?0:1,allowedTurnIds:[`${id}:T${index}`],crosswalkId:`${id}:X${index}`}))}
function fixture({grid=matrices(8),protectedMask=matrices(0),policeMask=matrices(0),bridgeDeckMask=matrices(0),buildings=[],parkingKeepouts=[],controls=[]}={}){const roadMask=matrices(0),topology={map:{rows:24,cols:24,worldUnitsPerCell:M},grid,roadMask,protectedMask,policeMask,bridgeDeckMask},junctionRules=[{id:'J1',x:41,z:41,approaches:approaches('J1',41,41)},{id:'J2',x:65.6,z:41,approaches:approaches('J2',65.6,41)}],roadPlan={junctionRules,signals:[],safeSign:()=>true},inventory={complete:{buildings:true,parking:true,controls:true},buildings,parkingKeepouts,controls};return {topology,roadPlan,inventory,placement:createWalkMapSignalPlacement({topology,roadPlan,inventory})}}
function asset(assetId){return {assetId,binding:{url:`/${assetId}.glb`,sha256:HASH}}}

test('stable semantic slots reject duplicates while move/delete use current trusted snapshots',async()=>{
 const base=fixture(),added=base.placement.compileAssetRecord({asset:asset('sign_wayfinding'),transform:{positionM:[41,0,41]}}).record,occupied=fixture({controls:[added]});assert.throws(()=>occupied.placement.compileAssetRecord({asset:asset('sign_wayfinding'),transform:{positionM:[41,0,41]}}),error=>error.code==='ROAD_CONTROL_SLOT_OCCUPIED');
 const moved=base.placement.compileTransform({currentRecord:added,nextTransform:{...added.transform,positionM:[65.6,0,41]}}).record;assert.equal(moved.id,added.id);assert.notEqual(moved.semanticKey,added.semanticKey);assert.deepEqual(createWalkMapSignalTransformCommand({before:added,after:moved}).patch.metadata.dependencies,WALK_MAP_ROAD_SIGN_DEPENDENCIES);assert.deepEqual(createWalkMapSignalDeleteCommand({record:moved}).patch.before,moved);
 let current=added;const prepare=createWalkMapSignalCommandPreparer({resolveCurrentEntity:()=>current,placement:base.placement}),raw=createWalkMapSignalTransformCommand({before:added,after:{...added,transform:{...added.transform,positionM:[65.6,0,41]}}}),prepared=await prepare(raw);assert.equal(prepared.command.patch.after.id,added.id);assert.deepEqual(prepared.dependencies,WALK_MAP_ROAD_SIGN_DEPENDENCIES);current=prepared.command.patch.after;await assert.rejects(()=>prepare(raw),error=>error.code==='STALE_ROAD_CONTROL_PREVIEW');
 const deletePrepared=await prepare(createWalkMapSignalDeleteCommand({record:current}));assert.deepEqual(deletePrepared.command.patch.before,current);assert.equal(deletePrepared.command.patch.metadata.adapter,WALK_MAP_SIGNAL_ADAPTER_ID);
});

test('water, protection, buildings, parking and carriageway clearance fail closed without mutation',()=>{
 const desired={positionM:[41,0,41]},entry=asset('sign_no_parking'),cases=[
  [fixture({grid:matrices(16)}),'ROAD_CONTROL_ON_WATER'],
  [fixture({protectedMask:matrices(1)}),'ROAD_CONTROL_ON_PROTECTED'],
  [fixture({buildings:[{id:'BLOCK',clearance:{minR:0,minC:0,maxR:24,maxC:24}}]}),'ROAD_CONTROL_BUILDING_OVERLAP'],
  [fixture({parkingKeepouts:[{id:'PARK',minR:0,minC:0,maxR:24,maxC:24}]}),'ROAD_CONTROL_PARKING_OVERLAP']
 ];
 for(const [value,code] of cases){const before=structuredClone(value.inventory);assert.throws(()=>value.placement.compileAssetRecord({asset:entry,transform:desired}),error=>error.code===code,code);assert.deepEqual(value.inventory,before)}
 const road=matrices(1),blocked=fixture();blocked.topology.roadMask=road;const api=createWalkMapSignalPlacement({topology:blocked.topology,roadPlan:blocked.roadPlan,inventory:blocked.inventory});assert.throws(()=>api.compileAssetRecord({asset:entry,transform:desired}),error=>error.code==='ROAD_CONTROL_ON_CARRIAGEWAY');
});

test('palette unlocks only the six proven controls when the adapter is available',()=>{
 const currentRecords=[...buildingPlacement.instances,...decorPlacement.instances],locked=createWalkMapEditorPalette({buildingCatalog,decorCatalog,currentRecords}),enabled=createWalkMapEditorPalette({buildingCatalog,decorCatalog,currentRecords,roadControlAdapterAvailable:true});
 for(const assetId of [...WALK_MAP_SIGNAL_ASSETS,...WALK_MAP_ROAD_SIGN_ASSETS]){assert.equal(locked.find(item=>item.assetId===assetId)?.available,false,assetId);const item=enabled.find(value=>value.assetId===assetId);assert.equal(item.available,true,assetId);assert.equal(item.placementMode,'road-control')}
 const unknownEntry={...structuredClone(decorCatalog.entries.find(entry=>entry.assetId==='traffic_signal_arm_v1')),assetId:'traffic_signal_unknown_v9',lods:[{lod:0,url:'/unknown.glb',sha256:HASH}]},unknown=createWalkMapEditorPalette({buildingCatalog,decorCatalog:{...decorCatalog,entries:[...decorCatalog.entries,unknownEntry]},currentRecords,roadControlAdapterAvailable:true}).find(item=>item.assetId===unknownEntry.assetId);assert.ok(unknown);assert.equal(unknown.available,false);assert.match(unknown.reason,/неизвестная|непроверенная/i);
});

test('a rejected traffic rebuild rolls an add back through the real editor host contract',async()=>{
 const value=fixture(),compiledAsset={key:'asset:decor:sign_wayfinding',available:true,...asset('sign_wayfinding')},stage={children:[],add(root){this.children.push(root)},remove(root){this.children=this.children.filter(value=>value!==root)}},vector=()=>({x:0,y:0,z:0,fromArray(values){[this.x,this.y,this.z]=values},set(x,y,z){this.x=x;this.y=y;this.z=z}}),model=()=>({position:vector(),rotation:{y:0},scale:vector(),userData:{},clone(){return model()},updateMatrixWorld(){}}),placement=createWalkMapAssetPlacement({scene:stage,loadTemplate:async()=>model(),compileRecord:input=>value.placement.compileAssetRecord(input),idExists:()=>false,groundHeight:()=>0});
 class V2{set(){return this}}class V3{constructor(x=0,y=0,z=0){this.x=x;this.y=y;this.z=z}clone(){return new V3(this.x,this.y,this.z)}}class Plane{}class Raycaster{constructor(){this.ray={intersectPlane:(_plane,out)=>out}}setFromCamera(){}intersectObjects(){return []}}
 let hooks,state=[],before=[],fail=true;const rebuilds=[],runtime={active:true,selection:null,refreshCatalog(){},dispose:async()=>{}},host=createWalkMapEditorWalkHost({THREE:{Vector2:V2,Vector3:V3,Plane,Raycaster},renderer:{domElement:{getBoundingClientRect:()=>({left:0,top:0,width:100,height:100})}},scene:stage,camera:{},controls:{},adapter:{enumerate:()=>[],resolveIntersection:()=>null,cancelAllPreviews(){},dispose(){}},placement,getPickRoots:()=>[],prepareCommands:async commands=>({commands,dependencies:WALK_MAP_ROAD_SIGN_DEPENDENCIES}),commitCommands:async commands=>{before=state;state=[...commands];return true},requestRebuild:async meta=>{rebuilds.push(meta);if(meta.rollback){state=before;return}if(meta.committed&&fail){fail=false;throw new Error('traffic rebuild failed')}},createRuntime:options=>{hooks=options.hooks;return runtime},createCamera:()=>({enter(){},restore(){return true},setMode(){return true},handleAction(){return false},update(){},dispose(){}})});
 await placement.begin(compiledAsset,{positionM:[41,0,41]});await assert.rejects(()=>hooks.commit(),/traffic rebuild failed/);assert.deepEqual(state,[]);assert.equal(stage.children.length,0);assert.ok(rebuilds.some(meta=>meta.committed));assert.ok(rebuilds.some(meta=>meta.rollback));await host.dispose();
});
