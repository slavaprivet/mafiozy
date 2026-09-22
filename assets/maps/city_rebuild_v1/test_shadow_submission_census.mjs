import assert from 'node:assert/strict';
import {createShadowSubmissionCensus,shadowSubmissionCategory,tagShadowBatch,SHADOW_CATEGORIES} from './shadow_submission_census.mjs';

const node=(name='',userData={},parent=null)=>({name,userData,parent});
const scene=node('Scene'),building=node('Building',{shadowCensusCategory:'buildingsInteriors'},scene),npc=node('NPC_civilian',{},scene),car=node('car',{sourceVehicleId:'car-1'},scene),lampPlacement=node('',{instance:{assetId:'lamp_pine_v1'}},scene),lamp=node('Lamp_Base',{},lampPlacement),decor=node('ExplorationChunk_2',{explorationDecor:true},scene),water=node('Lake',{nativeTerrainKind:'water'},scene),unknown=node('Unknown',{},scene);
assert.deepEqual(SHADOW_CATEGORIES,['npc','transport','lamps','buildingsInteriors','decor','water','other']);
assert.equal(shadowSubmissionCategory(node('body',{},npc)),'npc');assert.equal(shadowSubmissionCategory(node('wheel',{},car)),'transport');assert.equal(shadowSubmissionCategory(lamp),'lamps');assert.equal(shadowSubmissionCategory(node('chair',{},building)),'buildingsInteriors');assert.equal(shadowSubmissionCategory(decor),'decor');assert.equal(shadowSubmissionCategory(water),'water');assert.equal(shadowSubmissionCategory(unknown),'other');

const sameBatch=node('Static_Render_Batch',{staticRenderBatch:true});tagShadowBatch(sameBatch,[{mesh:lamp},{mesh:lamp}]);assert.equal(sameBatch.userData.shadowCensusCategory,'lamps');assert.equal(sameBatch.userData.shadowCensusMixed,false);
const mixedBatch=node('Static_Render_Batch',{staticRenderBatch:true});tagShadowBatch(mixedBatch,[{mesh:lamp},{mesh:decor}]);assert.equal(mixedBatch.userData.shadowCensusCategory,'other');assert.equal(mixedBatch.userData.shadowCensusMixed,true);

const census=createShadowSubmissionCensus();census.add(npc,3,90);census.add(car,2,40);census.add(lamp,5,100);census.add(building,7,140);census.add(decor,11,220);census.add(water,1,20);census.add(unknown,4,80);census.add(mixedBatch,6,120);census.add(unknown,0,0);
let report=census.snapshot({frame:17,expectedCalls:39,expectedTriangles:810});assert.equal(report.status,'ok');assert.deepEqual(report.totals,{submissions:39,triangles:810});assert.deepEqual(report.mixed,{submissions:6,triangles:120});assert.equal(report.categories.other.submissions,10);assert.equal(JSON.stringify(report).length<4096,true);
assert.equal(census.snapshot({expectedCalls:38,expectedTriangles:810}).status,'invalid');assert.equal(census.snapshot({enabled:false}).status,'disabled');assert.equal(census.snapshot({ready:false}).status,'warming');
census.add(unknown,-1,0);assert.equal(census.snapshot().invalidDeltas,1);census.reset();report=census.snapshot({expectedCalls:0,expectedTriangles:0});assert.equal(report.status,'ok');assert.deepEqual(report.totals,{submissions:0,triangles:0});
console.log('PASS bounded shadow submission census categories, batch tags, exact totals, invalidation and reset');
