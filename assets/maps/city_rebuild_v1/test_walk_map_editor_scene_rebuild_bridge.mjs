import assert from 'node:assert/strict';
import test from 'node:test';
import {createWalkMapEditorDocument,walkMapEditorCanonicalDigest} from './walk_map_editor_document.mjs';
import {walkMapEditorArtifactSha256} from './walk_map_editor_compile.mjs';
import {createWalkMapEditorSceneRebuildBridge,WALK_MAP_EDITOR_SCENE_BUILD_PROOF_SCHEMA,WALK_MAP_EDITOR_SCENE_REBUILD_SCHEMA} from './walk_map_editor_scene_rebuild_bridge.mjs';

const names=['topology','buildings','decor','custom'],planNames=['roadDressing','parking','explorationDecor','railway'];
const sources={topology:'1'.repeat(64),buildings:'2'.repeat(64),decor:'3'.repeat(64),custom:'4'.repeat(64)};
const ids=Array.from({length:78},(_,index)=>`building-${String(index).padStart(2,'0')}`);
const stable=value=>Array.isArray(value)?value.map(stable):value&&typeof value==='object'?Object.fromEntries(Object.keys(value).sort().map(key=>[key,stable(value[key])])):value;
const json=value=>JSON.stringify(stable(value));
const artifact=value=>{const text=json(value);return {value:structuredClone(value),json:text,sha256:walkMapEditorArtifactSha256(text)}};
const documentFor=label=>createWalkMapEditorDocument({documentId:`scene-${label}`,createdAt:'2026-09-23T20:00:00.000Z',metadata:{label},base:{topology:{sha256:sources.topology,revision:'top-v1'},buildings:{sha256:sources.buildings,revision:'build-v1'},decor:{sha256:sources.decor,revision:'decor-v1'},extensions:{custom:{sha256:sources.custom,revision:'custom-v1'}}}});
const plansFor=label=>Object.fromEntries(planNames.map(name=>[name,{schema:`${name}/v1`,label,items:[]}]))
function compile(document){const artifacts={topology:artifact({grid:[[8]],label:document.metadata.label}),buildings:artifact({instances:ids.map(id=>({id}))}),decor:artifact({instances:[]}),custom:artifact({instances:[]})};return {document:structuredClone(document),artifacts,compileReceipt:{documentDigest:walkMapEditorCanonicalDigest(document),sourceDigests:{topology:sources.topology,buildings:sources.buildings,decor:sources.decor},outputDigests:Object.fromEntries(names.map(name=>[name,artifacts[name].sha256]))}}}
const evidence=label=>({ok:true,sampleId:`sample:${label}`,digest:walkMapEditorArtifactSha256(label)});
const visual=label=>{const digest=walkMapEditorArtifactSha256(label);return {ok:true,sampleId:`visual:${label}`,beforeDigest:digest,afterDigest:digest}}
function proof(expected,overrides={}){return {schema:WALK_MAP_EDITOR_SCENE_BUILD_PROOF_SCHEMA,signature:expected.signature,documentDigest:expected.documentDigest,sourceDigests:{...expected.sourceDigests},artifactDigests:{...expected.artifactDigests},planDigests:{...expected.planDigests},buildingGroupIds:[...expected.buildingIds],readiness:{collision:evidence('collision'),entry:evidence('entry'),minimap:evidence('minimap')},visual:{parity:visual('parity'),lod:visual('lod'),materials:visual('materials')},...overrides}}
function makeGroups(){return [...ids.map(id=>({userData:{instance:{id}}})),{userData:{instance:{id:'decor-extra'}}}]}

function harness({compileMutate,buildMutate,installOverride,verifyOverride,buildWait=null}={}){
 let live={id:'prior',released:false},compileCalls=0,buildCalls=0,snapshots=0,installs=0,restores=0,releases=0,disposals=0;const installMetas=[],events=[];
 const bridge=createWalkMapEditorSceneRebuildBridge({
  compileArtifacts:async({document,meta,signal})=>{compileCalls++;events.push(`compile:${meta.id||document.metadata.label}`);const result=compile(document);return compileMutate?compileMutate(result,{document,meta,signal}):result},isCompileResult:()=>true,
  resolveBuildingIds:()=>ids,
  buildGeneration:async context=>{buildCalls++;events.push(`build:${context.meta.id||context.meta.document.metadata.label}`);if(buildWait)await buildWait(context);const stage={generation:{id:`generation:${context.meta.document.metadata.label}`,disposed:false},groups:makeGroups(),proof:proof(context.expected)};return buildMutate?buildMutate(stage,context):stage},
  snapshotGeneration:()=>{snapshots++;return live},
  installGeneration:async(stage,context)=>{installs++;installMetas.push(context.meta);live=stage.generation;if(installOverride)return installOverride(stage,context,{get live(){return live},set live(value){live=value}});return {groups:stage.groups}},
  verifyInstalled:context=>verifyOverride?verifyOverride(context):({ok:true,signature:context.expected.signature,sampleId:`installed:${context.expected.signature}`,groups:context.stage.groups}),
  restoreGeneration:snapshot=>{restores++;live=snapshot},disposeGeneration:stage=>{disposals++;stage.generation.disposed=true},releaseGeneration:snapshot=>{releases++;snapshot.released=true},onState:value=>events.push(value.phase)
 });
 return {bridge,events,installMetas,get live(){return live},get compileCalls(){return compileCalls},get buildCalls(){return buildCalls},get snapshots(){return snapshots},get installs(){return installs},get restores(){return restores},get releases(){return releases},get disposals(){return disposals}};
}

test('success validates exact artifacts, plans, 78 building roots and releases prior only after live verification',async()=>{
 const h=harness(),document=documentFor('success'),result=await h.bridge.requestRebuild({document,generatedPlans:plansFor('success'),id:'success'});assert.equal(result.ok,true);assert.equal(result.sceneRebuild.schema,WALK_MAP_EDITOR_SCENE_REBUILD_SCHEMA);assert.equal(result.groups.length,79);assert.equal(result.groups.filter(root=>ids.includes(root.userData.instance.id)).length,78);assert.equal(h.live.id,'generation:success');assert.equal(h.releases,1);assert.equal(h.restores,0);assert.equal(h.disposals,0);assert.equal(h.installs,1);assert.equal(h.bridge.signature,result.signature);await h.bridge.dispose();
});

test('stale document and artifact receipts fail before any scene snapshot or build',async()=>{
 for(const mode of ['document','artifact']){const h=harness({compileMutate:result=>{if(mode==='document')result.compileReceipt.documentDigest='f'.repeat(64);else result.artifacts.decor.sha256='e'.repeat(64);return result}});await assert.rejects(()=>h.bridge.requestRebuild({document:documentFor(mode),generatedPlans:plansFor(mode)}),error=>['SCENE_REBUILD_DOCUMENT_STALE','SCENE_REBUILD_ARTIFACT_STALE'].includes(error.code));assert.equal(h.snapshots,0);assert.equal(h.buildCalls,0);assert.equal(h.live.id,'prior');assert.equal(h.releases,0);await h.bridge.dispose()}
});

test('detached build failure leaves the exact prior scene retained and untouched',async()=>{
 const h=harness({buildMutate:()=>{throw new Error('detached generation failed')}}),prior=h.live;await assert.rejects(()=>h.bridge.requestRebuild({document:documentFor('build-fail'),generatedPlans:plansFor('build-fail')}),/detached generation failed/);assert.equal(h.live,prior);assert.equal(prior.released,false);assert.equal(h.snapshots,1);assert.equal(h.installs,0);assert.equal(h.restores,0);assert.equal(h.releases,0);assert.equal(h.disposals,0);await h.bridge.dispose();
});

test('stale generated-plan proof, missing building groups and visual downgrade never install',async()=>{
 const cases=[
  ['plan',stage=>{stage.proof.planDigests.roadDressing='f'.repeat(64);return stage},'SCENE_REBUILD_PROOF_STALE'],
  ['groups',stage=>{stage.groups=stage.groups.filter(root=>root.userData.instance.id!=='building-77');return stage},'SCENE_REBUILD_GROUPS_MISSING'],
  ['visual',stage=>{stage.proof.visual.materials.afterDigest='e'.repeat(64);return stage},'SCENE_REBUILD_VISUAL_DOWNGRADE']
 ];
 for(const [label,mutate,code] of cases){const h=harness({buildMutate:mutate});await assert.rejects(()=>h.bridge.requestRebuild({document:documentFor(label),generatedPlans:plansFor(label)}),error=>error.code===code);assert.equal(h.installs,0);assert.equal(h.live.id,'prior');assert.equal(h.live.released,false,'prior live scene must not be released on preinstall failure');assert.equal(h.disposals,1);await h.bridge.dispose()}
});

test('partial install failure restores the exact prior scene and disposes only detached generation',async()=>{
 const h=harness({installOverride:()=>{throw new Error('partial scene swap failed')}}),prior=h.live;await assert.rejects(()=>h.bridge.requestRebuild({document:documentFor('partial'),generatedPlans:plansFor('partial')}),/partial scene swap failed/);assert.equal(h.live,prior);assert.equal(prior.released,false);assert.equal(h.restores,1);assert.equal(h.disposals,1);assert.equal(h.releases,0);await h.bridge.dispose();
});

test('failed installed verification restores prior and never publishes groups',async()=>{
 const h=harness({verifyOverride:context=>({ok:false,signature:context.expected.signature,sampleId:'bad-live'})}),prior=h.live;await assert.rejects(()=>h.bridge.requestRebuild({document:documentFor('verify'),generatedPlans:plansFor('verify')}),error=>error.code==='SCENE_REBUILD_LIVE_VERIFY');assert.equal(h.live,prior);assert.equal(h.restores,1);assert.equal(h.disposals,1);assert.equal(h.bridge.signature,null);await h.bridge.dispose();
});

test('rollback meta builds its exact target and unchanged signatures are no-op without snapshot/build/install',async()=>{
 const h=harness(),forward=await h.bridge.requestRebuild({document:documentFor('forward'),generatedPlans:plansFor('forward'),id:'forward',committed:true}),rollback=await h.bridge.requestRebuild({document:documentFor('rollback'),generatedPlans:plansFor('rollback'),id:'rollback',rollback:true}),before={build:h.buildCalls,snapshot:h.snapshots,install:h.installs},noop=await h.bridge.requestRebuild({document:documentFor('rollback'),id:'rollback-again',rollback:true});assert.notEqual(forward.signature,rollback.signature);assert.equal(h.installMetas[1].rollback,true);assert.equal(rollback.sceneRebuild.rollback,true);assert.equal(noop.noop,true,'omitted generatedPlans must retain the last verified plan signature');assert.deepEqual({build:h.buildCalls,snapshot:h.snapshots,install:h.installs},before);assert.equal(noop.groups,rollback.groups);assert.equal(h.compileCalls,3,'no-op still recompiles and verifies the exact input signature');await h.bridge.dispose();
});

test('concurrent requests are serialized before compile/build/install',async()=>{
 let releaseFirst,markFirst;const firstStarted=new Promise(resolve=>{markFirst=resolve}),waitFirst=new Promise(resolve=>{releaseFirst=resolve}),h=harness({buildWait:async({meta})=>{if(meta.id==='one'){markFirst();await waitFirst}}}),secondDocument=documentFor('two'),one=h.bridge.requestRebuild({document:documentFor('one'),generatedPlans:plansFor('one'),id:'one'}),two=h.bridge.requestRebuild({document:secondDocument,generatedPlans:plansFor('two'),id:'two'});secondDocument.metadata.label='mutated-after-request';await firstStarted;assert.deepEqual(h.events.filter(value=>value.startsWith('compile:')||value.startsWith('build:')),['compile:one','build:one']);releaseFirst();await Promise.all([one,two]);assert.deepEqual(h.events.filter(value=>value.startsWith('compile:')||value.startsWith('build:')),['compile:one','build:one','compile:two','build:two']);assert.equal(h.live.id,'generation:two','queued request must own an immutable input snapshot');assert.equal(h.installs,2);await h.bridge.dispose();
});

test('dispose aborts detached staging, restores nothing uninstalled and rejects later requests',async()=>{
 let release,mark;const started=new Promise(resolve=>{mark=resolve}),wait=new Promise(resolve=>{release=resolve}),h=harness({buildWait:async({signal})=>{mark();await wait;if(signal.aborted)return}}),pending=h.bridge.requestRebuild({document:documentFor('dispose'),generatedPlans:plansFor('dispose')});await started;const disposing=h.bridge.dispose();release();await assert.rejects(()=>pending,error=>error?.name==='AbortError');await disposing;assert.equal(h.installs,0);assert.equal(h.restores,0);assert.equal(h.releases,0);assert.equal(h.disposals,1);assert.equal(h.live.id,'prior');await assert.rejects(()=>h.bridge.requestRebuild({document:documentFor('late')}),error=>error?.code==='EDITOR_SCENE_REBUILD_CANCELLED');
});
