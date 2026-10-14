import assert from 'node:assert/strict';
import test from 'node:test';
import {readFile} from 'node:fs/promises';
import {performance} from 'node:perf_hooks';
import {buildWalkMapGeneratedCollections,createWalkMapGeneratedSources,summarizeWalkMapGeneratedCollections,WALK_MAP_GENERATED_OVERRIDE_SCHEMA} from './walk_map_editor_generated_sources.mjs';
import {createLandscapePlan} from './landscape_plan.mjs';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';
import {createCityRoadDressingPlan} from './city_road_dressing_plan.mjs';
import {createCityParkingPlan} from './city_parking_plan.mjs';
import {planExplorationDecor} from './exploration_decor_plan.mjs';

const here=new URL('.',import.meta.url),read=async file=>JSON.parse(await readFile(new URL(file,here),'utf8'));
const [expected,topology,buildingPlacement,decorPlacement]=await Promise.all([read('test_fixtures/walk_map_editor_generated_source_counts.json'),read('topology_for_placement.json'),read('buildings_placement.v1.json'),read('decor_placement.v1.json')]);
let actualPlansPromise=null;
async function actualPlans(){return actualPlansPromise??=(async()=>{const landscape=createLandscapePlan(),railway=createExplorationRailwayPlan({landscape,topology}),instances=[...buildingPlacement.instances,...decorPlacement.instances],roadDressing=createCityRoadDressingPlan({topology,landscape,railPlan:railway,instances}),parking=createCityParkingPlan({topology,instances,railPlan:railway}),explorationDecor=planExplorationDecor({terrain:landscape,topology,buildings:buildingPlacement.instances,existingDecor:decorPlacement.instances,railPlan:railway});return {roadDressing,parking,explorationDecor,railway}})()}

test('actual plan bridge has exact deterministic counts per generated source',async()=>{
 const plans=await actualPlans(),collections=buildWalkMapGeneratedCollections(plans),counts=summarizeWalkMapGeneratedCollections(collections);assert.deepEqual(counts,expected);assert.equal(Object.values(counts).reduce((sum,value)=>sum+value,0),9659);
 assert.equal(plans.roadDressing.markings.length,6449);assert.equal(plans.parking.lots.length,39);assert.equal(plans.explorationDecor.stats.objects,2440);assert.equal(plans.railway.points.length,1021);
});

test('all semantic ids, Russian labels, categories and proxy metadata are stable',async()=>{
 const collections=buildWalkMapGeneratedCollections(await actualPlans()),keys=new Set();
 for(const collection of collections)for(const record of collection.records){const key=`${collection.dataset}:${record.id}`;assert.equal(keys.has(key),false,key);keys.add(key);assert.ok(record.target?.sourceFile);assert.equal(record.target.dataset,collection.dataset);assert.ok(record.proxy&&Number.isFinite(record.proxy.x)&&Number.isFinite(record.proxy.z),key)}
 const bridge=createWalkMapGeneratedSources({loadPlans:actualPlans}),adapter=await bridge.load(),items=adapter.enumerate();assert.equal(items.length,9659);assert.equal(new Set(items.map(item=>item.key)).size,items.length);assert.ok(items.every(item=>item.label&&!/^[a-z_]+$/i.test(item.label)),items.find(item=>/^[a-z_]+$/i.test(item.label))?.label);assert.ok(new Set(items.map(item=>item.category)).isSupersetOf(new Set(['roads','signs','parking','ground','nature','monuments','decor','railway'])));bridge.dispose();
});

test('unsupported grouped objects stay visible and locked with exact Russian reasons',async()=>{
 const bridge=createWalkMapGeneratedSources({loadPlans:actualPlans}),adapter=await bridge.load(),items=adapter.enumerate(),byDataset=dataset=>items.filter(item=>item.source.dataset===dataset);
 for(const dataset of ['road-signals','parking-bays','parking-surfaces','railway-alignment','railway-stations','railway-crossings','railway-signals'])for(const item of byDataset(dataset)){assert.equal(item.locked,true,item.key);assert.deepEqual(item.capabilities,{move:false,rotate:false,delete:false,paint:false});assert.match(item.subtitle,/привязан|связан|частью|создаются|трасса|сплайн|пересечения|переезд|фазами|групп/i,item.subtitle)}
 const markings=byDataset('road-markings');assert.ok(markings.some(item=>item.capabilities.delete));assert.ok(markings.some(item=>item.locked));for(const item of markings.filter(item=>!item.locked)){assert.equal(item.capabilities.delete,true);assert.equal(item.capabilities.move,false)}for(const item of byDataset('parking-signs')){assert.equal(item.locked,false,item.key);assert.equal(item.capabilities.delete,true);assert.equal(item.capabilities.move,false)}
 assert.equal(byDataset('parking-lots').every(item=>item.capabilities.delete&&!item.capabilities.move),true);bridge.dispose();
});

test('delete and transform compile to custom overrides with exact dependencies',async()=>{
 const existing=new Map(),bridge=createWalkMapGeneratedSources({loadPlans:actualPlans,resolveOverride:source=>existing.get(source.id)||null,validateGeneratedTransform:async({transform})=>transform.positionM[0]>=0||{ok:false,reason:'За пределами карты'}}),adapter=await bridge.load(),tree=adapter.enumerate({category:'nature'})[0],sign=adapter.enumerate({category:'signs'}).find(item=>item.source.dataset==='road-signs');
 const remove=adapter.deleteCommand(tree.key);assert.equal(remove.patch.source.dataset,'custom');assert.equal(remove.patch.action,'add');assert.equal(remove.patch.after.schema,WALK_MAP_GENERATED_OVERRIDE_SCHEMA);assert.equal(remove.patch.after.operation,'suppress');assert.deepEqual(remove.patch.metadata.dependencies,adapter.dependenciesFor(tree.key));assert.deepEqual(remove.patch.after.target,adapter.recordFor(tree.key).target);
 existing.set(remove.patch.source.id,remove.patch.after);const replace=adapter.deleteCommand(tree.key);assert.equal(replace.patch.action,'modify');assert.deepEqual(replace.patch.before,remove.patch.after);
 const move=await adapter.transformCommand(sign.key,{positionM:[20,0,20],yawDegrees:90,uniformScale:1});assert.equal(move.patch.source.dataset,'custom');assert.equal(move.patch.after.operation,'transform');assert.deepEqual(move.patch.after.transform,{positionM:[20,0,20],yawDegrees:90,uniformScale:1});assert.ok(move.patch.metadata.dependencies.includes('traffic-rules'));
 await assert.rejects(adapter.transformCommand(sign.key,{positionM:[-1,0,20]}),/За пределами карты/);bridge.dispose();
});

test('bridge construction is O(1) lazy, concurrent load occurs once and no Mesh is created',async()=>{
 let calls=0,release;const wait=new Promise(resolve=>{release=resolve}),start=performance.now(),bridge=createWalkMapGeneratedSources({loadPlans:async()=>{calls++;return wait}}),constructionMs=performance.now()-start;
 assert.equal(calls,0);assert.equal(bridge.state,'idle');assert.equal(bridge.loaded,false);assert.throws(()=>bridge.getAdapter(),/not loaded/);assert.ok(constructionMs<20,`lazy construction ${constructionMs.toFixed(2)} ms`);
 const a=bridge.load(),b=bridge.load();await Promise.resolve();assert.equal(calls,1);release(await actualPlans());const [first,second]=await Promise.all([a,b]);assert.equal(first,second);assert.equal(bridge.loadCount,1);assert.equal(bridge.loaded,true);
 const records=first.enumerate();assert.equal(records.length,9659);assert.ok(records.every(item=>!('object' in item)&&!('mesh' in item)&&!('isMesh' in item)));for(let i=0;i<10000;i++)assert.equal(first.hasKey(records[i%records.length].key),true);bridge.dispose();
});

test('lazy adapter build time and memory stay bounded for the real 9,659 objects',async()=>{
 const heapBefore=process.memoryUsage().heapUsed,start=performance.now(),bridge=createWalkMapGeneratedSources({loadPlans:actualPlans}),adapter=await bridge.load(),elapsed=performance.now()-start,heapGrowth=process.memoryUsage().heapUsed-heapBefore;
 assert.equal(adapter.enumerate().length,9659);assert.ok(elapsed<5000,`bridge build ${elapsed.toFixed(1)} ms`);assert.ok(heapGrowth<250*1024*1024,`bridge heap ${(heapGrowth/1024/1024).toFixed(1)} MiB`);console.log(`generated sources bridge: 9659 objects, ${elapsed.toFixed(1)} ms, ${(heapGrowth/1024/1024).toFixed(1)} MiB`);bridge.dispose();
});
