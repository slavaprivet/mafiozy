import assert from 'node:assert/strict';
import test from 'node:test';
import {readFile} from 'node:fs/promises';
import {WALK_MAP_EDITOR_SCENE_BUILD_PROOF_SCHEMA} from './walk_map_editor_scene_rebuild_bridge.mjs';
import {auditWalkPreviewDetachedGenerationSourceContract,createWalkMapEditorWalkGenerationContract,WALK_MAP_EDITOR_WALK_GENERATION_COMPONENTS} from './walk_map_editor_walk_generation_contract.mjs';

const root=id=>({userData:{instance:{id}},position:{fromArray(value){this.value=[...value]}},rotation:{},scale:{set(...value){this.value=value}},updateWorldMatrix(){}}),buildingRoots=Array.from({length:78},(_,index)=>root(`building-${index}`)),decorRoots=Array.from({length:164},(_,index)=>root(`decor-${index}`));
const proof=()=>({schema:WALK_MAP_EDITOR_SCENE_BUILD_PROOF_SCHEMA,readiness:{collision:{ok:true},entry:{ok:true},minimap:{ok:true}},visual:{parity:{ok:true},lod:{ok:true},materials:{ok:true}}});
const generatedPlans=()=>({roadDressing:{isRoad(){return true}},parking:{lots:[]},explorationDecor:{objects:[]},railway:{blocksPlacement(){return false},landscape:{groundHeight(){return 0},waterAt(){return null}}}});
function harness({mutateLive=false,invalidStage=null,installFailure=false}={}){
 let liveDigest='live-v1',live={id:'prior'},disposed=0,restored=0,released=0,installed=0,scale=null;const events=[];
 const hooks={
  captureLiveSnapshot(){events.push('snapshot');return {token:'generation-1',digest:liveDigest,generation:live}},captureLiveDigest({phase}){events.push(phase);return liveDigest},
  async buildDetached({productionScale,applyAuthoredRootTransform}){events.push('build');scale=productionScale({uniformScale:2,horizontalScale:[3,.5]});const sample=root('sample');applyAuthoredRootTransform(sample,{transform:{positionM:[1,2,3],uniformScale:2,horizontalScale:[3,.5]}});assert.deepEqual(sample.scale.value,[6,2,1]);if(mutateLive)liveDigest='mutated';const buildings=[...buildingRoots],decor=[...decorRoots],stage={generation:{id:'next',attached:false},groups:[...buildings,...decor,{name:'environment'}],authoredRoots:{buildings,decor},ownership:{detached:true,components:Object.fromEntries(WALK_MAP_EDITOR_WALK_GENERATION_COMPONENTS.map(name=>[name,true]))},proof:proof()};invalidStage?.(stage);return stage},
  installDetached(stage){events.push('install');if(installFailure)throw new Error('install failed');installed++;live=stage.generation;return {installed:true,generation:stage.generation,receipt:'swap-1'}},verifyInstalled(){return {ok:true}},restoreLiveSnapshot(snapshot){events.push('restore');restored++;live=snapshot.generation},disposeDetached(){events.push('dispose-stage');disposed++},releaseLiveSnapshot(){events.push('release');released++}
 };
 const contract=createWalkMapEditorWalkGenerationContract({hooks});return {contract,hooks,events,get live(){return live},get disposed(){return disposed},get restored(){return restored},get released(){return released},get installed(){return installed},get scale(){return scale}};
}

test('actual refresh inventory is complete but current production source fails closed for detached atomic rebuild',async()=>{
 const source=await readFile(new URL('walk_preview.mjs',import.meta.url),'utf8'),audit=auditWalkPreviewDetachedGenerationSourceContract({walkPreviewSource:source});assert.equal(audit.ready,false);for(const [name,item] of Object.entries(audit.inventory))assert.equal(item.present,true,name);assert.equal(Object.keys(audit.inventory).length,WALK_MAP_EDITOR_WALK_GENERATION_COMPONENTS.length);assert.equal(audit.checks.templatesStagedBeforeClear,true);assert.equal(audit.checks.destructiveClearBeforeAssembly,true);assert.equal(audit.checks.assemblyWritesLiveContent,true);assert.equal(audit.checks.oldResourcesDisposedBeforeSuccess,true);assert.equal(audit.checks.detachedBuilderExported,false);assert.equal(audit.checks.atomicInstallerExported,false);assert.equal(audit.checks.liveSnapshotRestoreExported,false);assert.equal(audit.checks.horizontalScaleStillUniformOnly,true);assert.ok(audit.gaps.some(value=>value.startsWith('detached-build:')));assert.ok(audit.gaps.some(value=>value.startsWith('rollback:')));assert.ok(audit.gaps.some(value=>value.startsWith('transform:')));assert.ok(audit.gaps.some(value=>value.startsWith('verification:')));
});

test('incomplete live host fails before snapshot or detached work',()=>{
 let work=0;assert.throws(()=>createWalkMapEditorWalkGenerationContract({hooks:{captureLiveSnapshot(){work++}}}),/captureLiveDigest/);assert.equal(work,0);
});

test('complete contract builds off-scene with exact 78/164 split, capabilities, parity and one install',async()=>{
 const h=harness(),snapshot=h.contract.snapshotGeneration({id:'qa'}),stage=await h.contract.buildGeneration({generatedPlans:generatedPlans(),meta:{id:'qa'}});assert.equal(stage.authoredRoots.buildings.length,78);assert.equal(stage.authoredRoots.decor.length,164);assert.equal(stage.capabilities.roadDressing,true);assert.equal(stage.capabilities.railway,true);assert.equal(stage.capabilities.groundHeight,true);assert.equal(stage.capabilities.waterAt,true);assert.deepEqual(h.scale,[6,2,1]);assert.deepEqual(h.events.slice(0,4),['snapshot','before-build','build','after-build']);assert.equal(h.live.id,'prior','detached build must retain live scene');const result=await h.contract.installGeneration(stage,{snapshot});assert.equal(result.generation.id,'next');assert.equal(result.groups,stage.groups);assert.equal(h.live.id,'next');assert.equal(h.installed,1);assert.deepEqual(h.contract.verifyInstalled({stage}),{ok:true});h.contract.restoreGeneration(snapshot,{reason:'qa'});assert.equal(h.live.id,'prior');assert.equal(h.restored,1);h.contract.releaseGeneration(snapshot,{});assert.equal(h.released,1);h.contract.dispose();assert.equal(h.contract.disposed,true);
});

test('live mutation during detached build disposes the stage and cannot install it',async()=>{
 const h=harness({mutateLive:true});await assert.rejects(()=>h.contract.buildGeneration({generatedPlans:generatedPlans()}),error=>error.code==='WALK_GENERATION_LIVE_MUTATED');assert.equal(h.disposed,1);assert.equal(h.installed,0);assert.deepEqual(h.events,['before-build','build','after-build','dispose-stage']);
});

test('missing roots, ownership, capabilities and parity are rejected before install',async()=>{
 const cases=[
  [stage=>stage.authoredRoots.buildings.pop(),'WALK_GENERATION_ROOT_INVENTORY'],
  [stage=>{stage.ownership.components.minimap=false},'WALK_GENERATION_OWNERSHIP_INCOMPLETE'],
  [stage=>{stage.proof.visual.materials.ok=false},'WALK_GENERATION_PROOF_INCOMPLETE']
 ];
 for(const [invalidStage,code] of cases){const h=harness({invalidStage});await assert.rejects(()=>h.contract.buildGeneration({generatedPlans:generatedPlans()}),error=>error.code===code);assert.equal(h.disposed,1);assert.equal(h.installed,0)}
 const h=harness(),plans=generatedPlans();delete plans.railway.blocksPlacement;await assert.rejects(()=>h.contract.buildGeneration({generatedPlans:plans}),error=>error.code==='WALK_GENERATION_PLAN_CAPABILITY');assert.equal(h.disposed,0);assert.equal(h.installed,0);
});

test('install errors stay explicit for the atomic bridge to restore from its prior snapshot',async()=>{
 const h=harness({installFailure:true}),snapshot=h.contract.snapshotGeneration({}),stage=await h.contract.buildGeneration({generatedPlans:generatedPlans()});await assert.rejects(()=>h.contract.installGeneration(stage,{snapshot}),/install failed/);assert.equal(h.live.id,'prior');assert.equal(h.installed,0);assert.equal(h.restored,0,'the surrounding atomic bridge owns restore ordering');await h.contract.disposeGeneration(stage,{error:new Error('install failed')});assert.equal(h.disposed,1);
});
