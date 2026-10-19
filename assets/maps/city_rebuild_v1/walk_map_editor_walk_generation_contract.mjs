import {applyWalkMapEditorProductionRootTransform,walkMapEditorProductionScale} from './walk_map_editor_production_adapter.mjs';
import {WALK_MAP_EDITOR_SCENE_BUILD_PROOF_SCHEMA} from './walk_map_editor_scene_rebuild_bridge.mjs';

export const WALK_MAP_EDITOR_WALK_GENERATION_CONTRACT_SCHEMA='mafiozi.walk-map-editor.walk-generation-contract/v1';
export const WALK_MAP_EDITOR_WALK_GENERATION_COMPONENTS=Object.freeze([
 'content-root','topology-terrain','authored-buildings','authored-decor','building-entry','collision-world','railway','exploration-decor','environment-visuals','water-effects','street-lighting-glass','static-render-batches','raycast-indexes','road-navigation','minimap','npc-bridges','mercenary-local-effects','ui-diagnostics'
]);

const REQUIRED_HOOKS=Object.freeze(['captureLiveSnapshot','captureLiveDigest','buildDetached','installDetached','verifyInstalled','restoreLiveSnapshot','disposeDetached','releaseLiveSnapshot']);
const plain=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
const required=(value,label)=>{if(typeof value!=='function')throw new Error(`Walk generation contract requires ${label}`);return value};
const fail=(code,message=code,details={})=>{const error=new Error(message);error.name='WalkMapEditorWalkGenerationContractError';error.code=code;error.details=details;throw error};
const rootId=root=>String(root?.userData?.instance?.id??'').trim();
function exactRoots(value,count,label){if(!Array.isArray(value)||value.length!==count)fail('WALK_GENERATION_ROOT_INVENTORY',`${label} requires exactly ${count} roots`);const ids=value.map(rootId);if(ids.some(id=>!id)||new Set(ids).size!==count)fail('WALK_GENERATION_ROOT_INVENTORY',`${label} roots require unique authored ids`);return {roots:value,ids}}
function sameRefs(groups,roots){const set=new Set(groups);return roots.every(root=>set.has(root))}
function capabilityProof(plans){return Object.freeze({roadDressing:typeof plans?.roadDressing?.isRoad==='function',railway:typeof plans?.railway?.blocksPlacement==='function',groundHeight:typeof plans?.railway?.landscape?.groundHeight==='function',waterAt:typeof plans?.railway?.landscape?.waterAt==='function'})}
function visualProof(proof){return ['parity','lod','materials'].every(name=>proof?.visual?.[name]?.ok===true)&&['collision','entry','minimap'].every(name=>proof?.readiness?.[name]?.ok===true)}

const SOURCE_INVENTORY=Object.freeze([
 ['content-root',['while(content.children.length)','content.add(group)','content.add(landscape.object)']],
 ['topology-terrain',['topology=top','terrain(top.grid','createLandscapeTerrain']],
 ['authored-buildings',['const buildings=[...records(bld),...records(det)]','buildingItems.has(item)']],
 ['authored-decor',['decorItems=records(dec)','records(dec).length']],
 ['building-entry',['createWindowedBuildingEntry','buildingEntries.push(entry)','stableEntryLights=createStableEntryLights']],
 ['collision-world',['bodies.push','carBodies.push','walkCollisionIndex','buildingSampleIndex=createWalkCollisionIndex']],
 ['railway',['createExplorationRailwayPlan','createExplorationRailway','explorationRailway.object']],
 ['exploration-decor',['planExplorationDecorAsync','createExplorationDecor','explorationDecor.colliders']],
 ['environment-visuals',['planEnvironmentVisualsAsync','createEnvironmentVisuals','environmentVisuals.colliders']],
 ['water-effects',['createWaterInteractionEffects','createVehicleWaterVapor']],
 ['street-lighting-glass',['streetLighting.prepare','glass.prepare','glass.dispose()']],
 ['static-render-batches',['createStaticRenderBatches','staticRenderBatches?.dispose()']],
 ['raycast-indexes',['installBuildingCameraTriangleIndex','installNativeTerrainRaycastIndex','createRaycastRootIndex']],
 ['road-navigation',['createCarWorld','createLaneRouteJobs','createCityRoadNavigation']],
 ['minimap',['configureExplorationMap(all,explorationPlan)','explorationMap.setWorld','explorationPlaces=']],
 ['npc-bridges',['npcVehicleNavigation?.invalidate()','npcServiceDestinations?.invalidate()','setWalkCivilianPlaces']],
 ['mercenary-local-effects',['createMercenaryFences','createMercenaryPowerPanel']],
 ['ui-diagnostics',["$('district')","document.body.dataset.rebuildProof","document.body.dataset.walkLoadTiming"]]
]);

/** Audits text only. It never executes or imports walk_preview. */
export function auditWalkPreviewDetachedGenerationSourceContract({walkPreviewSource=''}={}){
 const inventory=Object.freeze(Object.fromEntries(SOURCE_INVENTORY.map(([name,anchors])=>[name,Object.freeze({present:anchors.every(anchor=>walkPreviewSource.includes(anchor)),anchors:Object.freeze([...anchors])})]))),clearAt=walkPreviewSource.indexOf('clearContent();topology=top'),firstAssemblyAt=walkPreviewSource.indexOf('landscape=createLandscapeTerrain'),checks=Object.freeze({
  refreshExists:walkPreviewSource.includes('async function refresh()'),templatesStagedBeforeClear:walkPreviewSource.indexOf('const templatesReadyAt=performance.now()')>=0&&walkPreviewSource.indexOf('const templatesReadyAt=performance.now()')<clearAt,
  destructiveClearBeforeAssembly:clearAt>=0&&firstAssemblyAt>clearAt,assemblyWritesLiveContent:walkPreviewSource.includes('content.add(group)')&&walkPreviewSource.includes('content.add(environmentVisuals.object)'),globalCollisionMutation:walkPreviewSource.includes('bodies.push(...explorationDecor.colliders)')&&walkPreviewSource.includes('carBodies.push(...environmentVisuals.colliders)'),directMinimapMutation:walkPreviewSource.includes('explorationMap.setWorld'),directNavigationMutation:walkPreviewSource.includes('cityRoadNavigation=createCityRoadNavigation'),oldResourcesDisposedBeforeSuccess:walkPreviewSource.includes('environmentVisuals?.dispose();environmentVisuals=null')&&walkPreviewSource.includes('explorationRailway?.dispose();explorationRailway=null'),catchClaimsPreservation:walkPreviewSource.includes('Последняя сцена сохранена'),horizontalScaleStillUniformOnly:walkPreviewSource.includes('group.scale.setScalar(t.uniformScale??1)'),authoredSplit78And164:walkPreviewSource.includes('const buildings=[...records(bld),...records(det)],decorItems=records(dec)'),planCapabilitiesBuilt:walkPreviewSource.includes('createExplorationRailwayPlan')&&walkPreviewSource.includes('planEnvironmentVisualsAsync'),detachedBuilderExported:/export\s+(async\s+)?function\s+buildWalkGenerationDetached\b/.test(walkPreviewSource),atomicInstallerExported:/export\s+(async\s+)?function\s+installWalkGeneration\b/.test(walkPreviewSource),liveSnapshotRestoreExported:/export\s+(async\s+)?function\s+restoreWalkGeneration\b/.test(walkPreviewSource),visualParityReceipt:walkPreviewSource.includes(WALK_MAP_EDITOR_SCENE_BUILD_PROOF_SCHEMA)
 });
 const gaps=Object.freeze([
  ...(!checks.detachedBuilderExported?['detached-build: refresh assembles directly into live globals/content']:[]),...(!checks.atomicInstallerExported?['single-install: no exported one-swap installer']:[]),...(!checks.liveSnapshotRestoreExported?['rollback: no exact generation snapshot restore hook']:[]),...(checks.oldResourcesDisposedBeforeSuccess?['ownership: prior resources are disposed before the replacement is verified']:[]),...(checks.directMinimapMutation?['minimap: setWorld mutates the live controller during assembly']:[]),...(checks.directNavigationMutation?['navigation: live lane/navigation state is replaced during assembly']:[]),...(checks.horizontalScaleStillUniformOnly?['transform: refresh ignores authored horizontalScale']:[]),...(!checks.visualParityReceipt?['verification: no collision/entry/minimap/LOD/material parity receipt']:[])
 ]);
 return Object.freeze({schema:WALK_MAP_EDITOR_WALK_GENERATION_CONTRACT_SCHEMA,ready:gaps.length===0,inventory,checks,gaps,requiredHooks:REQUIRED_HOOKS});
}

/**
 * Produces callbacks accepted by createWalkMapEditorSceneRebuildBridge. Every
 * live operation stays injected; an incomplete host fails before capture/build.
 */
export function createWalkMapEditorWalkGenerationContract({hooks}={}){
 if(!plain(hooks))throw new Error('Walk generation contract requires hooks');for(const name of REQUIRED_HOOKS)required(hooks[name],`hooks.${name}`);let disposed=false;
 const assertActive=()=>{if(disposed)fail('WALK_GENERATION_DISPOSED','Walk generation contract is disposed')};
 async function disposeStage(stage,context){try{await hooks.disposeDetached(stage,context)}catch(error){throw error}}
 const api={
  schema:WALK_MAP_EDITOR_WALK_GENERATION_CONTRACT_SCHEMA,
  snapshotGeneration(context){assertActive();const snapshot=hooks.captureLiveSnapshot(context);if(!plain(snapshot)||typeof snapshot.token!=='string'||!snapshot.token||typeof snapshot.digest!=='string'||!snapshot.digest)fail('WALK_GENERATION_SNAPSHOT_INVALID','Live generation snapshot is incomplete');return snapshot},
  async buildGeneration(context){assertActive();const before=await hooks.captureLiveDigest({phase:'before-build',context}),capabilities=capabilityProof(context.generatedPlans);if(!Object.values(capabilities).every(Boolean))fail('WALK_GENERATION_PLAN_CAPABILITY','Generated runtime plan capabilities are incomplete',capabilities);let stage=null;try{stage=await hooks.buildDetached({...context,applyAuthoredRootTransform:applyWalkMapEditorProductionRootTransform,productionScale:walkMapEditorProductionScale});const after=await hooks.captureLiveDigest({phase:'after-build',context});if(before!==after)fail('WALK_GENERATION_LIVE_MUTATED','Detached build mutated the live generation',{before,after});if(!plain(stage)||!plain(stage.generation)||stage.generation.attached===true||stage.ownership?.detached!==true||!Array.isArray(stage.groups)||!plain(stage.proof)||stage.proof.schema!==WALK_MAP_EDITOR_SCENE_BUILD_PROOF_SCHEMA)fail('WALK_GENERATION_STAGE_INVALID','Detached generation result is incomplete');const buildings=exactRoots(stage.authoredRoots?.buildings,78,'buildings'),decor=exactRoots(stage.authoredRoots?.decor,164,'decor');if(!sameRefs(stage.groups,buildings.roots)||!sameRefs(stage.groups,decor.roots))fail('WALK_GENERATION_ROOT_INVENTORY','Top-level generation groups do not retain the exact authored root split');if(buildings.ids.some(id=>new Set(decor.ids).has(id)))fail('WALK_GENERATION_ROOT_INVENTORY','Building and decor ids overlap');for(const name of WALK_MAP_EDITOR_WALK_GENERATION_COMPONENTS)if(stage.ownership.components?.[name]!==true)fail('WALK_GENERATION_OWNERSHIP_INCOMPLETE',`Detached generation does not own ${name}`);if(!visualProof(stage.proof))fail('WALK_GENERATION_PROOF_INCOMPLETE','Detached generation lacks readiness or visual parity proof');return {...stage,authoredRoots:Object.freeze({buildings:Object.freeze([...buildings.roots]),decor:Object.freeze([...decor.roots])}),capabilities};}catch(error){if(stage)try{await disposeStage(stage,{...context,error,phase:'build-validation'})}catch(disposeError){throw new AggregateError([error,disposeError],'Detached walk generation validation and disposal failed')}throw error}},
  async installGeneration(stage,context){assertActive();const result=await hooks.installDetached(stage,context);if(!plain(result)||result.installed!==true||result.generation!==stage.generation)fail('WALK_GENERATION_INSTALL_INVALID','Walk generation install did not publish the exact staged generation');return {groups:stage.groups,generation:stage.generation,receipt:result.receipt??null}},
  verifyInstalled(context){assertActive();return hooks.verifyInstalled(context)},restoreGeneration(snapshot,context){return hooks.restoreLiveSnapshot(snapshot,context)},disposeGeneration:disposeStage,releaseGeneration(snapshot,context){return hooks.releaseLiveSnapshot(snapshot,context)},
  get disposed(){return disposed},dispose(){disposed=true}
 };
 return Object.freeze(api);
}
