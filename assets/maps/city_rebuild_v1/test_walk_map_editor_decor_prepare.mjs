import assert from 'node:assert/strict';
import test from 'node:test';
import {readFile} from 'node:fs/promises';
import {makeWalkMapObjectDeleteCommand,makeWalkMapObjectTransformCommand} from './walk_map_editor_document.mjs';
import {createWalkMapDecorCommandPreparer,deriveMovedDecor,WalkMapDecorPrepareError,WALK_MAP_DECOR_DEPENDENCIES} from './walk_map_editor_decor_prepare.mjs';

const here=new URL('.',import.meta.url),read=async file=>JSON.parse(await readFile(new URL(file,here),'utf8')),[placement,realTopology]=await Promise.all([read('decor_placement.v1.json'),read('topology_for_placement.json')]),M=4.1;
const zero=(rows,cols)=>Array.from({length:rows},()=>Array(cols).fill(0)),fixtureTopology=()=>{const rows=12,cols=12;return {grid:Array.from({length:rows},()=>Array(cols).fill(8)),roadMask:zero(rows,cols),protectedMask:zero(rows,cols),policeMask:zero(rows,cols),bridgeDeckMask:zero(rows,cols)}};
const base={id:'DECOR-FIXTURE',assetId:'lamp_pine_v1',role:'roadside_lamp',r:2.5,c:2.5,transform:{positionM:[10.25,0,10.25],yawDegrees:0,uniformScale:1,horizontalScale:[1.1,.9],modelLocalOffsetM:[0,.2,0],unknownScale:'keep'},binding:{url:'/lamp.glb',sha256:'a'.repeat(64)},hideNodeNames:['helper'],clearancePolygonCR:[[2.25,2.25],[2.75,2.25],[2.75,2.75],[2.25,2.75]],collision:{policy:'fixture',worldBodies:[{node:'base',polygonCR:[[2.35,2.35],[2.65,2.35],[2.65,2.65],[2.35,2.65]],minYM:0,maxYM:1}],scaleApplied:1},unknownFuture:{nested:true},lightBudget:{emissive:true}};
const inventory=(decor=[base],buildings=[],parkingKeepouts=[])=>({complete:{decor:true,buildings:true,parking:true},decor,buildings,parkingKeepouts});
const expectCode=(fn,code)=>assert.throws(fn,error=>error instanceof WalkMapDecorPrepareError&&error.code===code);

test('all 164 actual authored records are accepted losslessly at their trusted placement',()=>{
 assert.equal(placement.instances.length,164);for(const record of placement.instances){const result=deriveMovedDecor({trustedBase:record,nextTransform:record.transform,topology:realTopology,inventory:inventory(placement.instances),metresPerCell:M});assert.equal(result.ok,true,record.id);assert.deepEqual(result.record,record,record.id)}
 assert.equal(placement.instances.filter(record=>/^lamp_/.test(record.assetId)).length,128);assert.equal(placement.instances.filter(record=>/^fountain_/.test(record.assetId)).length,8);
});

test('transform preserves binding, hide list, unknown fields, horizontal scale and local offset',()=>{
 const before=structuredClone(base),result=deriveMovedDecor({trustedBase:base,nextTransform:{...base.transform,positionM:[14.35,1,10.25],yawDegrees:90,uniformScale:1.5,horizontalScale:[1.3,.8]},topology:fixtureTopology(),inventory:inventory(),metresPerCell:M});
 assert.deepEqual(base,before);assert.deepEqual(result.record.binding,base.binding);assert.deepEqual(result.record.hideNodeNames,base.hideNodeNames);assert.deepEqual(result.record.unknownFuture,base.unknownFuture);assert.equal(result.record.transform.unknownScale,'keep');assert.deepEqual(result.record.transform.horizontalScale,[1.3,.8]);assert.deepEqual(result.record.transform.modelLocalOffsetM,[0,.2,0]);assert.deepEqual([result.record.c,result.record.r],[3.5,2.5]);assert.equal(result.record.collision.worldBodies[0].minYM,1);assert.equal(result.record.collision.worldBodies[0].maxYM,2.5);assert.deepEqual(result.dirty,WALK_MAP_DECOR_DEPENDENCIES);
});

test('lamps, fountains and monument-shaped future authored records use the same compiler',()=>{
 const samples=[placement.instances.find(record=>/^lamp_/.test(record.assetId)),placement.instances.find(record=>/^fountain_/.test(record.assetId)),{...structuredClone(base),id:'MONUMENT-FIXTURE',assetId:'monument_founders'}];
 for(const record of samples){const topology=record===samples[2]?fixtureTopology():realTopology,decor=record===samples[2]?[record]:placement.instances,result=deriveMovedDecor({trustedBase:record,nextTransform:record.transform,topology,inventory:inventory(decor),metresPerCell:M});assert.equal(result.ok,true);assert.equal(result.record.assetId,record.assetId)}
});

test('bounds, protected, water, road, building, decor and parking overlap fail closed',()=>{
 const run=(topology=fixtureTopology(),next={...base.transform,positionM:[14.35,0,10.25]},items=inventory())=>deriveMovedDecor({trustedBase:base,nextTransform:next,topology,inventory:items,metresPerCell:M});
 expectCode(()=>run(fixtureTopology(),{...base.transform,positionM:[100,0,100]}),'DECOR_OUT_OF_BOUNDS');
 for(const [mask,code] of [['protectedMask','DECOR_ON_PROTECTED'],['policeMask','DECOR_ON_PROTECTED'],['bridgeDeckMask','DECOR_ON_PROTECTED']]){const topology=fixtureTopology();topology[mask][2][3]=1;expectCode(()=>run(topology),code)}
 {const topology=fixtureTopology();topology.grid[2][3]=16;expectCode(()=>run(topology),'DECOR_ON_WATER')}{const topology=fixtureTopology();topology.roadMask[2][3]=1;expectCode(()=>run(topology),'DECOR_ON_ROAD')}
 expectCode(()=>run(fixtureTopology(),undefined,inventory([base],[{id:'house',clearance:{minC:3,minR:2,maxC:4,maxR:3}}])),'DECOR_BUILDING_OVERLAP');
 expectCode(()=>run(fixtureTopology(),undefined,inventory([base,{id:'other',clearancePolygonCR:[[3,2],[4,2],[4,3],[3,3]]}])),'DECOR_OVERLAP');
 expectCode(()=>run(fixtureTopology(),undefined,inventory([base],[],[{id:'lot',rectCR:{minC:3,minR:2,maxC:4,maxR:3}}])),'DECOR_PARKING_OVERLAP');
 expectCode(()=>deriveMovedDecor({trustedBase:base,nextTransform:base.transform,topology:fixtureTopology(),inventory:{decor:[base],buildings:[],parkingKeepouts:[],complete:{decor:true,buildings:true,parking:false}}}),'DECOR_INVENTORY_INCOMPLETE');
});

test('local offset cannot silently detach render from derived collision',()=>{expectCode(()=>deriveMovedDecor({trustedBase:base,nextTransform:{...base.transform,modelLocalOffsetM:[1,.2,0]},topology:fixtureTopology(),inventory:inventory()}),'DECOR_LOCAL_OFFSET_CHANGE_UNSUPPORTED')});

test('preparer has stale-current guard and authoritative transform/delete snapshots',async()=>{
 const source={dataset:'decor',id:base.id},after={...structuredClone(base),transform:{...base.transform,positionM:[14.35,0,10.25]}},transform=makeWalkMapObjectTransformCommand({source,before:base,after}),remove=makeWalkMapObjectDeleteCommand({source,before:base}),prepare=createWalkMapDecorCommandPreparer({resolveCurrentEntity:()=>structuredClone(base),topology:fixtureTopology(),inventory:inventory(),metresPerCell:M});
 const moved=await prepare(transform);assert.equal(moved.command.patch.action,'modify');assert.equal(moved.command.patch.metadata.adapter,'authored-decor-derived-v1');assert.deepEqual(moved.dependencies,WALK_MAP_DECOR_DEPENDENCIES);assert.deepEqual(moved.command.patch.metadata.dependencies,WALK_MAP_DECOR_DEPENDENCIES);
 const deleted=await prepare(remove);assert.equal(deleted.command.patch.action,'delete');assert.deepEqual(deleted.command.patch.before,base);
 const stale=createWalkMapDecorCommandPreparer({resolveCurrentEntity:()=>({...structuredClone(base),unknownFuture:{changed:true}}),topology:fixtureTopology(),inventory:inventory()});await assert.rejects(stale(transform),error=>error.code==='STALE_DECOR_PREVIEW');
});
