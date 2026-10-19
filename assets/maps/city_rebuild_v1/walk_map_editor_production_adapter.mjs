import {createWalkMapEditorProductionSeam,auditWalkMapEditorProductionSourceContract} from './walk_map_editor_production_seam.mjs';
import {createWalkMapEditorSceneRebuildBridge} from './walk_map_editor_scene_rebuild_bridge.mjs';
import {walkMapEditorArtifactSha256} from './walk_map_editor_compile.mjs';

export const WALK_MAP_EDITOR_PRODUCTION_ADAPTER_SCHEMA='mafiozi.walk-map-editor.production-adapter/v1';
export const WALK_MAP_EDITOR_PRODUCTION_CONTEXT_SCHEMA='mafiozi.walk-map-editor.production-context/v1';

const SOURCE_NAMES=Object.freeze(['topology','buildings','decor','detention','custom']);
const PLAN_NAMES=Object.freeze(['roadDressing','parking','explorationDecor','railway']);
const BOOTSTRAP_SERVICE_NAMES=Object.freeze(['loadTemplate','compileAssetRecord','releaseControls','enterGameEditor','leaveGameEditor','pickImportText','download']);
const INPUT_NAMES=Object.freeze(['captureGameplayState','restoreGameplayState','clearHeldKeys','closeConflictingMenus','releasePointerLock','refreshInput']);
const REBUILD_NAMES=Object.freeze(['compileArtifacts','buildGeneration','snapshotGeneration','installGeneration','verifyInstalled','restoreGeneration']);
const plain=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
const required=(value,label)=>{if(typeof value!=='function')throw new Error(`Walk map editor production adapter requires ${label}`);return value};
const fail=(code,message=code)=>{const error=new Error(message);error.name='WalkMapEditorProductionAdapterError';error.code=code;throw error};
const stable=value=>Array.isArray(value)?value.map(stable):plain(value)?Object.fromEntries(Object.keys(value).sort().map(key=>[key,stable(value[key])])):value;
const same=(a,b)=>JSON.stringify(stable(a))===JSON.stringify(stable(b));

function finite(value,label){const number=Number(value);if(!Number.isFinite(number))fail('PRODUCTION_TRANSFORM_INVALID',`${label} must be finite`);return number}

/** The production transform contract. Horizontal scale never changes world Y. */
export function walkMapEditorProductionScale(transform={}){
 const uniform=finite(transform.uniformScale??1,'uniformScale'),horizontal=transform.horizontalScale??[1,1];
 if(!Array.isArray(horizontal)||horizontal.length!==2)fail('PRODUCTION_TRANSFORM_INVALID','horizontalScale must be [x,z]');
 return Object.freeze([uniform*finite(horizontal[0],'horizontalScale[0]'),uniform,uniform*finite(horizontal[1],'horizontalScale[1]')]);
}

/** Applies an authored record to a detached or preview root without touching materials. */
export function applyWalkMapEditorProductionRootTransform(root,record,{metresPerCell=4.1}={}){
 if(!root||!plain(record))fail('PRODUCTION_TRANSFORM_INVALID','A root and authored record are required');
 const transform=record.transform||{},position=transform.positionM??[finite(record.c,'record.c')*metresPerCell,0,finite(record.r,'record.r')*metresPerCell],scale=walkMapEditorProductionScale(transform),yaw=finite(transform.yawDegrees??0,'yawDegrees')*Math.PI/180;
 if(!Array.isArray(position)||position.length!==3||!position.every(Number.isFinite))fail('PRODUCTION_TRANSFORM_INVALID','positionM must contain three finite numbers');
 root.position?.fromArray?.(position);if(root.position&&!root.position.fromArray)[root.position.x,root.position.y,root.position.z]=position;
 if(root.rotation)root.rotation.y=yaw;
 root.scale?.set?.(...scale);if(root.scale&&!root.scale.set)[root.scale.x,root.scale.y,root.scale.z]=scale;
 if(root.updateWorldMatrix)root.updateWorldMatrix(true,false);else root.updateMatrixWorld?.(true);
 return root;
}

function sourceInventory(rawSources){
 if(!plain(rawSources))fail('PRODUCTION_SOURCES_INCOMPLETE','Raw source inventory is missing');
 const parsed={},revisions={};
 for(const name of SOURCE_NAMES){const source=rawSources[name];if(!plain(source)||typeof source.text!=='string'||!source.text.trim()||typeof source.revision!=='string'||!source.revision.trim())fail('PRODUCTION_SOURCES_INCOMPLETE',`Raw source is incomplete: ${name}`);try{parsed[name]=JSON.parse(source.text)}catch{fail('PRODUCTION_SOURCE_JSON_INVALID',`Raw source JSON is invalid: ${name}`)}revisions[name]=source.revision}
 if(!Array.isArray(parsed.topology.grid)||!plain(parsed.topology.map))fail('PRODUCTION_TOPOLOGY_INVALID','Topology source is incomplete');
 for(const name of ['buildings','decor','detention','custom'])if(!Array.isArray(parsed[name].instances))fail('PRODUCTION_SOURCES_INCOMPLETE',`${name} source has no instances`);
 if(parsed.buildings.instances.length!==75||parsed.detention.instances.length!==3)fail('PRODUCTION_BUILDING_INVENTORY','Authored source inventory must contain exactly 75 buildings and 3 detention sites');
 if(parsed.decor.instances.length!==164)fail('PRODUCTION_DECOR_INVENTORY','Authored source inventory must contain exactly 164 decor records');
 return Object.freeze({parsed:Object.freeze(parsed),revisions:Object.freeze(revisions)});
}
function rootId(root){return String(root?.userData?.instance?.id??'').trim()}
function exactRoots(value,count,label,expectedIds){
 if(!Array.isArray(value)||value.length!==count)fail(`PRODUCTION_${label.toUpperCase()}_ROOTS`,`${label} roots must contain exactly ${count} entries`);
 const ids=value.map(rootId);if(ids.some(id=>!id)||new Set(ids).size!==count)fail(`PRODUCTION_${label.toUpperCase()}_ROOTS`,`${label} roots must have unique authored ids`);
 if(expectedIds&& !same([...ids].sort(),[...expectedIds].map(String).sort()))fail(`PRODUCTION_${label.toUpperCase()}_ROOTS`,`${label} roots do not match the source inventory`);
 return Object.freeze({roots:Object.freeze([...value]),ids:Object.freeze(ids)});
}
export function walkMapEditorProductionPlanSnapshot(value){
 if(!plain(value)||!same(Object.keys(value).sort(),[...PLAN_NAMES].sort()))fail('PRODUCTION_PLANS_INCOMPLETE','Generated plan snapshot must contain the exact four supported plans');
 for(const name of PLAN_NAMES)if(!plain(value[name]))fail('PRODUCTION_PLANS_INCOMPLETE',`Generated plan is missing: ${name}`);
 return Object.freeze(Object.fromEntries(PLAN_NAMES.map(name=>[name,value[name]])));
}
function semanticValue(value,stack){
 if(value===null||typeof value==='string'||typeof value==='boolean')return value;if(typeof value==='number'){if(!Number.isFinite(value))fail('PRODUCTION_PLAN_SEMANTIC_INVALID','Generated plan contains a non-finite number');return value}if(typeof value==='bigint')return String(value);if(value===undefined||typeof value==='function'||typeof value==='symbol')return undefined;
 if(stack.has(value))fail('PRODUCTION_PLAN_SEMANTIC_CYCLE','Generated plan contains an unsupported cyclic data branch');stack.add(value);let result;
 if(Array.isArray(value))result=value.map(item=>semanticValue(item,stack)??null);
 else if(value instanceof Date)result=value.toISOString();
 else if(ArrayBuffer.isView(value))result=Array.from(value,value=>semanticValue(value,stack));
 else if(value instanceof Set)result=[...value].map(item=>semanticValue(item,stack)).sort((a,b)=>JSON.stringify(a).localeCompare(JSON.stringify(b)));
 else if(value instanceof Map)result=[...value.entries()].map(([key,item])=>[semanticValue(key,stack),semanticValue(item,stack)]).sort((a,b)=>JSON.stringify(a[0]).localeCompare(JSON.stringify(b[0])));
 else{result={};for(const key of Object.keys(value).sort()){const item=semanticValue(value[key],stack);if(item!==undefined)result[key]=item}}
 stack.delete(value);return result;
}
/** Serializable semantic projection used only for plan identity; runtime capabilities stay outside it. */
export function walkMapEditorProductionPlanSemantic(plan){if(!plain(plan))fail('PRODUCTION_PLAN_SEMANTIC_INVALID','Generated plan must be an object');return semanticValue(plan,new WeakSet())}
export function walkMapEditorProductionPlanDigest(plan){return walkMapEditorArtifactSha256(JSON.stringify(walkMapEditorProductionPlanSemantic(plan)))}
function validateLive(live){
 if(!plain(live))fail('PRODUCTION_LIVE_CONTEXT_INCOMPLETE','Live context is missing');for(const name of ['THREE','renderer','scene','camera','controls'])if(!live[name])fail('PRODUCTION_LIVE_CONTEXT_INCOMPLETE',`Live context is missing ${name}`);
 if(!live.renderer.domElement||typeof live.scene.add!=='function'||typeof live.scene.remove!=='function'||typeof live.getPickRoots!=='function'||typeof live.groundHeight!=='function')fail('PRODUCTION_LIVE_CONTEXT_INCOMPLETE','Live scene contract is incomplete');return live;
}
function validateServices(services){if(!plain(services))fail('PRODUCTION_SERVICES_INCOMPLETE','Bootstrap services are missing');for(const name of BOOTSTRAP_SERVICE_NAMES)required(services[name],`services.${name}`);if(!services.storage?.getItem||!services.storage?.setItem||!services.storage?.removeItem)fail('PRODUCTION_SERVICES_INCOMPLETE','Bootstrap storage service is incomplete');return services}
function validateInput(input){if(!plain(input))fail('PRODUCTION_INPUT_INCOMPLETE','Input ownership contract is missing');for(const name of INPUT_NAMES)required(input[name],`input.${name}`);return input}
function validateRebuild(rebuild){if(!plain(rebuild))fail('PRODUCTION_REBUILD_INCOMPLETE','Scene rebuild contract is missing');for(const name of REBUILD_NAMES)required(rebuild[name],`rebuild.${name}`);return rebuild}
function verifyFresh(verification,snapshot,revisions){
 if(!plain(verification)||verification.ok!==true||verification.token!==snapshot.token||!same(verification.sourceRevisions,revisions))fail('PRODUCTION_CONTEXT_STALE','Runtime context changed while the editor was preparing');
}
function frameDelta(value){if(Number.isFinite(value))return value;if(Number.isFinite(value?.dt))return value.dt;if(Number.isFinite(value?.deltaSeconds))return value.deltaSeconds;return 0}

/** Source-only evidence: no production source is executed by this audit. */
export function auditWalkMapEditorProductionAdapterSourceContract({walkPreviewSource='',worldSource='',bootstrapSource='',authoredAdapterSource='',adapterSource=''}={}){
 const seam=auditWalkMapEditorProductionSourceContract({walkPreviewSource,worldSource}),checks=Object.freeze({
  seamAnchors:seam.complete,
  exactSourceFetch:walkPreviewSource.includes("getJsonBytes('topology_for_placement.json')")&&walkPreviewSource.includes("getJsonBytes('buildings_placement.v1.json',true)")&&walkPreviewSource.includes("getJsonBytes('decor_placement.v1.json',true)")&&walkPreviewSource.includes("getJsonBytes('detention_native_sites.v1.json',true)"),
  sourceRevisionDigest:walkPreviewSource.includes("crypto.subtle.digest('SHA-256',bytes)"),
  authoredSplit:walkPreviewSource.includes('const buildings=[...records(bld),...records(det)],decorItems=records(dec)'),
  rootIdentity:walkPreviewSource.includes('group.userData.instance=item')&&walkPreviewSource.includes('instances.push(group)'),
  generatedPlans:walkPreviewSource.includes('const explorationPlan=decorPlanResult.plan')&&walkPreviewSource.includes('environmentVisuals.parkingPlan')&&walkPreviewSource.includes('environmentVisuals?.roadPlan')&&walkPreviewSource.includes('explorationRailPlan'),
  frameAnchor:walkPreviewSource.includes('function frame(){requestAnimationFrame(frame);'),
  legacyUniformOnlyDetected:walkPreviewSource.includes('group.scale.setScalar(t.uniformScale??1)'),
  bootstrapHorizontalScale:bootstrapSource.includes('uniform*(horizontal[0]??1),uniform,uniform*(horizontal[1]??1)'),
  authoredHorizontalScale:authoredAdapterSource.includes('x=transform.uniformScale*(horizontal[0]??1),y=transform.uniformScale,z=transform.uniformScale*(horizontal[1]??1)'),
  productionHorizontalScale:adapterSource.includes('uniform*finite(horizontal[0]')&&adapterSource.includes('uniform*finite(horizontal[1]'),
 });
 return Object.freeze({complete:Object.values(checks).every(Boolean),checks,seam});
}

/**
 * Installs only the existing KeyK lazy gate. runtimeContext.captureEditorContext
 * and every source/root/plan/GLB operation remain untouched until that gate fires.
 */
export function createWalkMapEditorProductionAdapter({
 target=globalThis.window,document:doc=globalThis.document,rendererSelection,enabled=true,runtimeContext,loadBootstrapModule,
 createSeam=createWalkMapEditorProductionSeam,createRebuildBridge=createWalkMapEditorSceneRebuildBridge,onGuardChange=()=>{},onReady=()=>{},onError=()=>{}
}={}){
 if(!plain(runtimeContext))throw new Error('Walk map editor production adapter requires runtimeContext');required(loadBootstrapModule,'loadBootstrapModule');required(createSeam,'createSeam');required(createRebuildBridge,'createRebuildBridge');
 let activeSnapshot=null,frameUnsubscribe=null,disposed=false,disposePromise=null;const bridges=new Set();
 const inputHost=Object.fromEntries(INPUT_NAMES.map(name=>[name,(...args)=>{const input=activeSnapshot?.input;if(!input)throw new Error('Walk map editor input used before a validated runtime snapshot');return input[name](...args)}]));
 async function createBootstrapOptions({attempt,guard}){
  if(disposed)fail('PRODUCTION_ADAPTER_DISPOSED','Production adapter is disposed');
  const capture=required(runtimeContext.captureEditorContext,'runtimeContext.captureEditorContext'),verify=required(runtimeContext.verifyEditorContext,'runtimeContext.verifyEditorContext'),subscribeFrame=required(runtimeContext.subscribeFrame,'runtimeContext.subscribeFrame');void subscribeFrame;
  const snapshot=await capture({attempt,guard});if(!plain(snapshot)||snapshot.schema!==WALK_MAP_EDITOR_PRODUCTION_CONTEXT_SCHEMA||typeof snapshot.token!=='string'||!snapshot.token.trim())fail('PRODUCTION_CONTEXT_INCOMPLETE','Runtime context snapshot is invalid');
  const inventory=sourceInventory(snapshot.rawSources),buildingRecords=[...inventory.parsed.buildings.instances,...inventory.parsed.detention.instances],buildingRoots=exactRoots(snapshot.roots?.buildings,78,'building',buildingRecords.map(record=>record.id)),decorRoots=exactRoots(snapshot.roots?.decor,164,'decor',inventory.parsed.decor.instances.map(record=>record.id));
  const overlap=buildingRoots.ids.filter(id=>new Set(decorRoots.ids).has(id));if(overlap.length)fail('PRODUCTION_ROOT_ID_COLLISION','Building and decor root inventories overlap');
  const generatedPlans=walkMapEditorProductionPlanSnapshot(snapshot.generatedPlans),live=validateLive(snapshot.live),services=validateServices(snapshot.services),input=validateInput(snapshot.input),rebuild=validateRebuild(snapshot.rebuild);
  const verification=await verify({token:snapshot.token,sourceRevisions:inventory.revisions,attempt});verifyFresh(verification,snapshot,inventory.revisions);if(disposed)fail('PRODUCTION_ADAPTER_DISPOSED','Production adapter was disposed while capturing the runtime');
  const groups=Object.freeze([...buildingRoots.roots,...decorRoots.roots]);
  const bridge=createRebuildBridge({
   compileArtifacts:rebuild.compileArtifacts,
   buildGeneration:args=>rebuild.buildGeneration({...args,applyAuthoredRootTransform:applyWalkMapEditorProductionRootTransform,productionScale:walkMapEditorProductionScale}),
   resolveBuildingIds:()=>[...buildingRoots.ids],snapshotGeneration:rebuild.snapshotGeneration,installGeneration:rebuild.installGeneration,verifyInstalled:rebuild.verifyInstalled,restoreGeneration:rebuild.restoreGeneration,
   disposeGeneration:rebuild.disposeGeneration,releaseGeneration:rebuild.releaseGeneration,onState:rebuild.onState,initialSignature:rebuild.initialSignature??null,initialGroups:groups,initialGeneratedPlans:generatedPlans,
   cloneGeneratedPlans:walkMapEditorProductionPlanSnapshot,digestGeneratedPlan:walkMapEditorProductionPlanDigest,
   ...(rebuild.isCompileResult?{isCompileResult:rebuild.isCompileResult}:{}),...(rebuild.createAtomicRebuild?{createAtomicRebuild:rebuild.createAtomicRebuild}:{})
  });bridges.add(bridge);activeSnapshot={...snapshot,input,buildingRoots,decorRoots,generatedPlans,bridge};
  const additions=plain(snapshot.bootstrapOptions)?snapshot.bootstrapOptions:{};
  return {...additions,rawSources:Object.fromEntries(SOURCE_NAMES.map(name=>[name,{text:snapshot.rawSources[name].text,revision:snapshot.rawSources[name].revision}])),live,groups,services:{...services,requestRebuild:bridge.requestRebuild},generatedPlanLoader:async()=>walkMapEditorProductionPlanSnapshot(generatedPlans)};
 }
 const loadModuleWithFrame=async input=>{const module=await loadBootstrapModule(input),factory=required(module?.createWalkMapEditorLiveBootstrap,'module.createWalkMapEditorLiveBootstrap');return {...module,createWalkMapEditorLiveBootstrap:async options=>{const bootstrap=await factory(options);if(!bootstrap?.host||typeof bootstrap.host.update!=='function'){await bootstrap?.dispose?.();fail('PRODUCTION_FRAME_HOOK_INCOMPLETE','Live bootstrap has no frame update hook')}const subscribe=required(runtimeContext.subscribeFrame,'runtimeContext.subscribeFrame');let unsubscribe;try{unsubscribe=subscribe(value=>bootstrap.host.update(frameDelta(value)));if(typeof unsubscribe!=='function')fail('PRODUCTION_FRAME_HOOK_INCOMPLETE','runtimeContext.subscribeFrame must return an unsubscribe function')}catch(error){try{unsubscribe?.()}catch{}await bootstrap.dispose?.();throw error}frameUnsubscribe=()=>{try{unsubscribe()}finally{if(frameUnsubscribe)frameUnsubscribe=null}};return bootstrap}}};
 const seam=createSeam({target,document:doc,rendererSelection,enabled,loadBootstrapModule:loadModuleWithFrame,createBootstrapOptions,inputHost,onGuardChange,
  onReady:controller=>{if(disposed)return;try{onReady(controller,{snapshot:activeSnapshot})}catch{}},
  onError:(error,stage)=>{for(const bridge of bridges)if(bridge!==activeSnapshot?.bridge||stage==='load')void bridge.dispose().catch(()=>{});try{onError(error,stage)}catch{}}
 });
 return Object.freeze({schema:WALK_MAP_EDITOR_PRODUCTION_ADAPTER_SCHEMA,seam,get guard(){return seam.guard},get controller(){return seam.controller},get snapshot(){return activeSnapshot},get disposed(){return disposed},dispose(){if(disposePromise)return disposePromise;disposed=true;disposePromise=(async()=>{try{frameUnsubscribe?.();frameUnsubscribe=null;await seam.dispose()}finally{await Promise.allSettled([...bridges].map(bridge=>bridge.dispose()));bridges.clear();activeSnapshot=null}})();return disposePromise;}});
}
