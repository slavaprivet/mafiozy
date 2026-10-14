import {createWalkMapEditorAtomicRebuild} from './walk_map_editor_atomic_rebuild.mjs';
import {walkMapEditorCanonicalDigest} from './walk_map_editor_document.mjs';
import {isWalkMapEditorCompileResult,walkMapEditorArtifactSha256} from './walk_map_editor_compile.mjs';

export const WALK_MAP_EDITOR_SCENE_REBUILD_SCHEMA='mafiozi.walk-map-editor.scene-rebuild/v1';
export const WALK_MAP_EDITOR_SCENE_BUILD_PROOF_SCHEMA='mafiozi.walk-map-editor.scene-build-proof/v1';

const ARTIFACT_NAMES=Object.freeze(['topology','buildings','decor','custom']);
const PLAN_NAMES=Object.freeze(['roadDressing','parking','explorationDecor','railway']);
const REQUIRED_BUILDING_GROUPS=78;
const shaPattern=/^[a-f0-9]{64}$/i;
const plain=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
const required=(value,label)=>{if(typeof value!=='function')throw new Error(`Scene rebuild bridge requires ${label}`);return value};
const abortError=()=>Object.assign(new Error('Scene rebuild bridge was cancelled'),{name:'AbortError',code:'EDITOR_SCENE_REBUILD_CANCELLED'});
function fail(code,message=code){const error=new Error(message);error.name='WalkMapEditorSceneRebuildError';error.code=code;throw error}
function stable(value){if(Array.isArray(value))return value.map(stable);if(plain(value))return Object.fromEntries(Object.keys(value).sort().map(key=>[key,stable(value[key])]));return value}
function canonical(value){return JSON.stringify(stable(value))}
function digestValue(value){return walkMapEditorArtifactSha256(canonical(value))}
function sha(value,label){if(typeof value!=='string'||!shaPattern.test(value))fail('SCENE_REBUILD_DIGEST_INVALID',`${label} digest is invalid`);return value.toLowerCase()}
function exactDigests(actual,expected,label){if(!plain(actual))fail('SCENE_REBUILD_PROOF_INVALID',`${label} proof is missing`);const a=Object.keys(actual).sort(),e=Object.keys(expected).sort();if(canonical(a)!==canonical(e))fail('SCENE_REBUILD_PROOF_STALE',`${label} proof keys are stale`);for(const key of e)if(sha(actual[key],`${label}.${key}`)!==expected[key])fail('SCENE_REBUILD_PROOF_STALE',`${label}.${key} proof is stale`)}
function sourceReference(document,name){return name==='custom'?document?.base?.extensions?.custom:document?.base?.[name]}
function sourceDigests(document){const result={};for(const name of ARTIFACT_NAMES){const value=sourceReference(document,name)?.sha256;result[name]=sha(value,`source.${name}`)}return Object.freeze(result)}
function normalizePlans(value,digestPlan=digestValue){
 if(value===undefined||value===null)return Object.freeze({plans:null,digests:Object.freeze({})});if(!plain(value))fail('SCENE_REBUILD_PLANS_INVALID','Generated plans must be an object');
 const keys=Object.keys(value).sort(),expected=[...PLAN_NAMES].sort();if(canonical(keys)!==canonical(expected))fail('SCENE_REBUILD_PLANS_INCOMPLETE','Generated plans must contain the exact four supported plans');
 const digests={};for(const name of PLAN_NAMES){if(!plain(value[name]))fail('SCENE_REBUILD_PLANS_INVALID',`Generated plan is invalid: ${name}`);digests[name]=sha(digestPlan(value[name],name),`plan.${name}`)}return Object.freeze({plans:value,digests:Object.freeze(digests)});
}
function validateCompileResult(result,document,isCompileResult){
 if(!isCompileResult(result))fail('SCENE_REBUILD_COMPILE_UNTRUSTED','compileArtifacts returned an untrusted result');const documentDigest=walkMapEditorCanonicalDigest(document);
 if(walkMapEditorCanonicalDigest(result.document)!==documentDigest||result.compileReceipt?.documentDigest!==documentDigest)fail('SCENE_REBUILD_DOCUMENT_STALE','Compiled document digest is stale');
 const sources=sourceDigests(document),receiptSources=result.compileReceipt?.sourceDigests||{};for(const name of ['topology','buildings','decor'])if(sha(receiptSources[name],`receipt.source.${name}`)!==sources[name])fail('SCENE_REBUILD_SOURCE_STALE',`Compiled source is stale: ${name}`);
 const artifactDigests={};for(const name of ARTIFACT_NAMES){const artifact=result.artifacts?.[name];if(!plain(artifact)||typeof artifact.json!=='string')fail('SCENE_REBUILD_ARTIFACT_MISSING',`Compiled artifact is missing: ${name}`);let parsed;try{parsed=JSON.parse(artifact.json)}catch{fail('SCENE_REBUILD_ARTIFACT_INVALID',`Compiled artifact JSON is invalid: ${name}`)}const digest=walkMapEditorArtifactSha256(artifact.json);if(canonical(parsed)!==artifact.json||canonical(artifact.value)!==artifact.json||sha(artifact.sha256,`artifact.${name}`)!==digest||sha(result.compileReceipt?.outputDigests?.[name],`receipt.output.${name}`)!==digest)fail('SCENE_REBUILD_ARTIFACT_STALE',`Compiled artifact digest is stale: ${name}`);artifactDigests[name]=digest}
 return Object.freeze({compileResult:result,documentDigest,sourceDigests:sources,artifactDigests:Object.freeze(artifactDigests)});
}
function expectedBuildingIds(resolveBuildingIds,context){const values=resolveBuildingIds(context);if(!Array.isArray(values)||values.length!==REQUIRED_BUILDING_GROUPS)fail('SCENE_REBUILD_BUILDING_INVENTORY',`Scene rebuild requires exactly ${REQUIRED_BUILDING_GROUPS} building ids`);const ids=values.map(value=>String(value??'').trim());if(ids.some(value=>!value)||new Set(ids).size!==REQUIRED_BUILDING_GROUPS)fail('SCENE_REBUILD_BUILDING_INVENTORY','Building ids must be non-empty and unique');return Object.freeze(ids.sort())}
function validateEvidence(value,label){if(!plain(value)||value.ok!==true||typeof value.sampleId!=='string'||!value.sampleId.trim()||!shaPattern.test(value.digest||''))fail('SCENE_REBUILD_READINESS_FAILED',`${label} readiness proof failed`)}
function validateVisualEvidence(value,label){if(!plain(value)||value.ok!==true||typeof value.sampleId!=='string'||!value.sampleId.trim())fail('SCENE_REBUILD_VISUAL_DOWNGRADE',`${label} visual proof failed`);const before=sha(value.beforeDigest,`${label}.before`),after=sha(value.afterDigest,`${label}.after`);if(before!==after)fail('SCENE_REBUILD_VISUAL_DOWNGRADE',`${label} visual proof reports a downgrade`)}
function validateGroupMapping(groups,expectedIds,proofIds){
 if(!Array.isArray(groups))fail('SCENE_REBUILD_GROUPS_MISSING','Detached generation has no top-level groups');const expected=new Set(expectedIds),found=[];
 for(const root of groups){const id=String(root?.userData?.instance?.id??'');if(expected.has(id))found.push(id)}
 if(found.length!==REQUIRED_BUILDING_GROUPS||new Set(found).size!==REQUIRED_BUILDING_GROUPS||canonical([...new Set(found)].sort())!==canonical(expectedIds))fail('SCENE_REBUILD_GROUPS_MISSING','Detached generation does not map all 78 buildings exactly once');
 if(!Array.isArray(proofIds)||canonical([...proofIds].map(String).sort())!==canonical(expectedIds))fail('SCENE_REBUILD_PROOF_STALE','Building group proof is stale');
}
function sameRoots(a,b){return Array.isArray(a)&&Array.isArray(b)&&a.length===b.length&&a.every((root,index)=>root===b[index])}

export function createWalkMapEditorSceneRebuildBridge({
 compileArtifacts,buildGeneration,resolveBuildingIds,snapshotGeneration,installGeneration,verifyInstalled,restoreGeneration,
 disposeGeneration=()=>{},releaseGeneration=()=>{},onState=()=>{},initialSignature=null,initialGroups=[],initialGeneratedPlans=null,
 isCompileResult=isWalkMapEditorCompileResult,createAtomicRebuild=createWalkMapEditorAtomicRebuild,cloneGeneratedPlans=structuredClone,digestGeneratedPlan=digestValue
}={}){
 for(const [name,value] of Object.entries({compileArtifacts,buildGeneration,resolveBuildingIds,snapshotGeneration,installGeneration,verifyInstalled,restoreGeneration,disposeGeneration,releaseGeneration,isCompileResult,createAtomicRebuild,cloneGeneratedPlans,digestGeneratedPlan}))required(value,name);
 if(initialSignature!==null)sha(initialSignature,'initial signature');if(!Array.isArray(initialGroups))throw new Error('Scene rebuild initialGroups must be an array');
 const initialPlans=normalizePlans(initialGeneratedPlans===null?null:cloneGeneratedPlans(initialGeneratedPlans),digestGeneratedPlan);let disposed=false,preparing=null,queue=Promise.resolve(),installedSignature=initialSignature?.toLowerCase()??null,installedGroups=Object.freeze([...initialGroups]),installedGeneratedPlans=initialPlans.plans;
 const atomic=createAtomicRebuild({
  snapshotLive:context=>snapshotGeneration({...context,meta:context.meta.__sceneRebuildPrepared.publicMeta}),
  async buildStage({meta,signal,snapshot}){const prepared=meta.__sceneRebuildPrepared;if(!prepared)fail('SCENE_REBUILD_PREPARED_MISSING');const built=await buildGeneration({artifacts:prepared.compileResult.artifacts,compileResult:prepared.compileResult,generatedPlans:prepared.generatedPlans,topologySnapshot:meta.topologySnapshot??null,expected:prepared.expected,meta:prepared.publicMeta,signal,snapshot});if(!plain(built)||!built.generation||!Array.isArray(built.groups)||!plain(built.proof))fail('SCENE_REBUILD_STAGE_INVALID','buildGeneration returned an invalid detached generation');return {...built,prepared};},
  validateStage(stage){const {expected}=stage.prepared,proof=stage.proof;if(proof.schema!==WALK_MAP_EDITOR_SCENE_BUILD_PROOF_SCHEMA||proof.signature!==expected.signature||proof.documentDigest!==expected.documentDigest)fail('SCENE_REBUILD_PROOF_STALE','Detached generation identity proof is stale');exactDigests(proof.sourceDigests,expected.sourceDigests,'source');exactDigests(proof.artifactDigests,expected.artifactDigests,'artifact');exactDigests(proof.planDigests,expected.planDigests,'plan');validateGroupMapping(stage.groups,expected.buildingIds,proof.buildingGroupIds);for(const name of ['collision','entry','minimap'])validateEvidence(proof.readiness?.[name],name);for(const name of ['parity','lod','materials'])validateVisualEvidence(proof.visual?.[name],name);return {ok:true,signature:expected.signature};},
  async installStage(stage,context){const result=await installGeneration(stage,{...context,meta:stage.prepared.publicMeta});if(!plain(result)||!sameRoots(result.groups,stage.groups))fail('SCENE_REBUILD_INSTALL_GROUPS','Installed top-level groups do not match the detached generation');return {...result,groups:stage.groups,signature:stage.prepared.expected.signature};},
  async verifyLive(context){const expected=context.stage.prepared.expected,verification=await verifyInstalled({...context,meta:context.stage.prepared.publicMeta,expected});if(!plain(verification)||verification.ok!==true||verification.signature!==expected.signature||typeof verification.sampleId!=='string'||!verification.sampleId.trim())fail('SCENE_REBUILD_LIVE_VERIFY','Installed generation verification failed');if(verification.groups!==undefined&&!sameRoots(verification.groups,context.stage.groups))fail('SCENE_REBUILD_LIVE_VERIFY','Installed group verification is stale');return verification;},
  restoreLive:(snapshot,context)=>restoreGeneration(snapshot,{...context,meta:context.stage?.prepared?.publicMeta??context.meta}),
  disposeStage:(stage,context)=>disposeGeneration(stage,{...context,meta:stage?.prepared?.publicMeta??context.meta}),
  releaseSnapshot:(snapshot,context)=>context.error?undefined:releaseGeneration(snapshot,{...context,meta:context.meta.__sceneRebuildPrepared.publicMeta}),onState
 });
 async function prepare(meta,signal){
  if(!plain(meta)||!plain(meta.document))fail('SCENE_REBUILD_DOCUMENT_MISSING','requestRebuild requires the current editor document');const compileResult=await compileArtifacts({document:meta.document,topologySnapshot:meta.topologySnapshot??null,meta,signal});if(signal.aborted)throw abortError();const compiled=validateCompileResult(compileResult,meta.document,isCompileResult);
  if(meta.topologySnapshot!==undefined&&digestValue(meta.topologySnapshot)!==compiled.artifactDigests.topology)fail('SCENE_REBUILD_TOPOLOGY_STALE','Effective topology snapshot does not match the compiled artifact');const inheritedPlans=meta.generatedPlans===undefined&&installedGeneratedPlans!==null?cloneGeneratedPlans(installedGeneratedPlans):meta.generatedPlans,plans=normalizePlans(inheritedPlans,digestGeneratedPlan),buildingIds=expectedBuildingIds(resolveBuildingIds,{compileResult,artifacts:compileResult.artifacts,generatedPlans:plans.plans,meta});
  const signature=digestValue({documentDigest:compiled.documentDigest,sourceDigests:compiled.sourceDigests,artifactDigests:compiled.artifactDigests,planDigests:plans.digests,buildingIds});
  const expected=Object.freeze({...compiled,generatedPlans:plans.plans,planDigests:plans.digests,buildingIds,signature});return Object.freeze({compileResult,generatedPlans:plans.plans,expected,publicMeta:meta});
 }
 function requestRebuild(meta={}){
  if(disposed)return Promise.reject(abortError());let requestMeta;try{requestMeta={...meta,...(meta.document===undefined?{}:{document:structuredClone(meta.document)}),...(meta.topologySnapshot===undefined?{}:{topologySnapshot:structuredClone(meta.topologySnapshot)}),...(meta.generatedPlans===undefined?{}:{generatedPlans:cloneGeneratedPlans(meta.generatedPlans)})}}catch(error){return Promise.reject(error)}
  const task=queue.then(async()=>{if(disposed)throw abortError();const controller=new AbortController();preparing=controller;let prepared;try{prepared=await prepare(requestMeta,controller.signal)}finally{if(preparing===controller)preparing=null}if(disposed||controller.signal.aborted)throw abortError();if(prepared.expected.signature===installedSignature){validateGroupMapping(installedGroups,prepared.expected.buildingIds,prepared.expected.buildingIds);installedGeneratedPlans=prepared.generatedPlans===null?null:cloneGeneratedPlans(prepared.generatedPlans);return Object.freeze({ok:true,noop:true,groups:installedGroups,signature:installedSignature,sceneRebuild:Object.freeze({schema:WALK_MAP_EDITOR_SCENE_REBUILD_SCHEMA,signature:installedSignature,rollback:requestMeta.rollback===true})})}const result=await atomic.requestRebuild({...requestMeta,__sceneRebuildPrepared:prepared});installedSignature=prepared.expected.signature;installedGroups=Object.freeze([...result.groups]);installedGeneratedPlans=prepared.generatedPlans===null?null:cloneGeneratedPlans(prepared.generatedPlans);return Object.freeze({...result,groups:installedGroups,signature:installedSignature,sceneRebuild:Object.freeze({schema:WALK_MAP_EDITOR_SCENE_REBUILD_SCHEMA,signature:installedSignature,rollback:requestMeta.rollback===true})});});queue=task.catch(()=>{});return task;
 }
 return Object.freeze({schema:WALK_MAP_EDITOR_SCENE_REBUILD_SCHEMA,requestRebuild,get signature(){return installedSignature},get groups(){return installedGroups},get state(){return atomic.state},get disposed(){return disposed},whenIdle:()=>queue,async dispose(){if(disposed)return queue;disposed=true;preparing?.abort();await atomic.dispose();await queue;}});
}
