import {createWalkMapEditorProductionAdapter,WALK_MAP_EDITOR_PRODUCTION_CONTEXT_SCHEMA} from './walk_map_editor_production_adapter.mjs';
import {createWalkMapEditorWalkGenerationBuilder,WALK_MAP_EDITOR_WALK_GENERATION_REQUIRED_FACTORIES} from './walk_map_editor_walk_generation_builder.mjs';
import {auditWalkPreviewDetachedGenerationSourceContract,WALK_MAP_EDITOR_WALK_GENERATION_COMPONENTS} from './walk_map_editor_walk_generation_contract.mjs';
import {auditWalkPreviewGenerationInstallSourceContract,createWalkMapEditorWalkGenerationInstall,WALK_MAP_EDITOR_WALK_INSTALL_STATE_KEYS} from './walk_map_editor_walk_generation_install.mjs';

export const WALK_MAP_EDITOR_WALK_RUNTIME_BINDINGS_SCHEMA='mafiozi.walk-map-editor.walk-runtime-bindings/v1';
export const WALK_MAP_EDITOR_WALK_RUNTIME_SOURCE_NAMES=Object.freeze(['topology','buildings','decor','detention','custom']);
export const WALK_MAP_EDITOR_WALK_RUNTIME_PLAN_NAMES=Object.freeze(['roadDressing','parking','explorationDecor','railway']);
export const WALK_MAP_EDITOR_WALK_RUNTIME_BINDING_LAYOUT=Object.freeze({
 'content-root':Object.freeze({state:Object.freeze(['contentRoot']),factories:Object.freeze(['createDetachedRoot'])}),
 'topology-terrain':Object.freeze({state:Object.freeze(['topology','terrain','landscape']),factories:Object.freeze(['captureLiveDigest','createTerrain','createLandscape'])}),
 'authored-buildings':Object.freeze({state:Object.freeze(['instances']),factories:Object.freeze(['createAuthoredRoot','loadTemplate','applyDoorsGlass'])}),
 'authored-decor':Object.freeze({state:Object.freeze([]),factories:Object.freeze(['cloneTemplate','disposeAuthoredRoot'])}),
 'building-entry':Object.freeze({state:Object.freeze(['entries']),factories:Object.freeze(['createBuildingEntry'])}),
 'collision-world':Object.freeze({state:Object.freeze(['bodies','carBodies']),factories:Object.freeze(['createCollisionWorld'])}),
 'railway':Object.freeze({state:Object.freeze(['railway']),factories:Object.freeze(['createRailway'])}),
 'exploration-decor':Object.freeze({state:Object.freeze(['explorationDecor']),factories:Object.freeze(['createExplorationDecor'])}),
 'environment-visuals':Object.freeze({state:Object.freeze(['environmentVisuals']),factories:Object.freeze(['createEnvironmentVisuals'])}),
 'water-effects':Object.freeze({state:Object.freeze(['waterEffects']),factories:Object.freeze(['createWaterEffects'])}),
 'street-lighting-glass':Object.freeze({state:Object.freeze(['streetLighting','glass','stableEntryLights']),factories:Object.freeze(['createStreetLighting','createGlass','createStableEntryLights'])}),
 'static-render-batches':Object.freeze({state:Object.freeze(['staticRenderBatches']),factories:Object.freeze(['createStaticRenderBatches'])}),
 'raycast-indexes':Object.freeze({state:Object.freeze(['raycastIndexes']),factories:Object.freeze(['createRaycastIndexes'])}),
 'road-navigation':Object.freeze({state:Object.freeze(['roadNavigation']),factories:Object.freeze(['createRoadNavigation'])}),
 'minimap':Object.freeze({state:Object.freeze(['minimap']),factories:Object.freeze(['createMinimapSnapshot'])}),
 'npc-bridges':Object.freeze({state:Object.freeze(['npcBridge']),factories:Object.freeze(['createNpcBridgeSnapshot'])}),
 'mercenary-local-effects':Object.freeze({state:Object.freeze(['mercenaryEffects']),factories:Object.freeze(['createMercenaryEffects'])}),
 'ui-diagnostics':Object.freeze({state:Object.freeze(['diagnostics','listeners']),factories:Object.freeze(['createUiDiagnostics','createGenerationListeners','verifyReadiness','verifyVisualParity','verifyLodParity','verifyMaterialParity','releasePriorGeneration'])})
});

const ARRAY_STATE_KEYS=new Set(['instances','bodies','carBodies','entries']);
const plain=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
const required=(value,label)=>{if(typeof value!=='function')throw new Error(`Walk runtime bindings require ${label}`);return value};
const fail=(code,message=code,details={})=>{const error=new Error(message);error.name='WalkMapEditorWalkRuntimeBindingsError';error.code=code;error.details=details;throw error};
const sameKeys=(value,expected)=>plain(value)&&JSON.stringify(Object.keys(value).sort())===JSON.stringify([...expected].sort());
const sameState=(a,b)=>WALK_MAP_EDITOR_WALK_INSTALL_STATE_KEYS.every(key=>a?.[key]===b?.[key]);
const rootId=root=>String(root?.userData?.instance?.id??'').trim();

function collectSubsystems(subsystems){
 if(!sameKeys(subsystems,WALK_MAP_EDITOR_WALK_GENERATION_COMPONENTS))fail('WALK_RUNTIME_SUBSYSTEMS_INCOMPLETE','Runtime subsystem table must contain the exact 18 generation subsystems');
 const getters={},setters={},factories={};
 for(const name of WALK_MAP_EDITOR_WALK_GENERATION_COMPONENTS){
  const binding=subsystems[name];if(!plain(binding)||!plain(binding.getters)||!plain(binding.setters)||!plain(binding.factories))fail('WALK_RUNTIME_SUBSYSTEM_INVALID',`Subsystem binding is incomplete: ${name}`);
  const layout=WALK_MAP_EDITOR_WALK_RUNTIME_BINDING_LAYOUT[name];if(!sameKeys(binding.getters,layout.state)||!sameKeys(binding.setters,layout.state)||!sameKeys(binding.factories,layout.factories))fail('WALK_RUNTIME_SUBSYSTEM_LAYOUT',`Subsystem binding does not match the explicit ownership layout: ${name}`);
  for(const [key,getter] of Object.entries(binding.getters)){if(!WALK_MAP_EDITOR_WALK_INSTALL_STATE_KEYS.includes(key))fail('WALK_RUNTIME_STATE_KEY_UNKNOWN',`Unknown state getter: ${key}`);if(getters[key])fail('WALK_RUNTIME_STATE_KEY_DUPLICATE',`State getter has multiple owners: ${key}`);getters[key]=required(getter,`subsystems.${name}.getters.${key}`)}
  for(const [key,setter] of Object.entries(binding.setters)){if(!WALK_MAP_EDITOR_WALK_INSTALL_STATE_KEYS.includes(key))fail('WALK_RUNTIME_STATE_KEY_UNKNOWN',`Unknown state setter: ${key}`);if(setters[key])fail('WALK_RUNTIME_STATE_KEY_DUPLICATE',`State setter has multiple owners: ${key}`);setters[key]=required(setter,`subsystems.${name}.setters.${key}`)}
  for(const [key,factory] of Object.entries(binding.factories)){if(!WALK_MAP_EDITOR_WALK_GENERATION_REQUIRED_FACTORIES.includes(key))fail('WALK_RUNTIME_FACTORY_UNKNOWN',`Unknown generation factory: ${key}`);if(factories[key])fail('WALK_RUNTIME_FACTORY_DUPLICATE',`Generation factory has multiple owners: ${key}`);factories[key]=required(factory,`subsystems.${name}.factories.${key}`)}
 }
 for(const key of WALK_MAP_EDITOR_WALK_INSTALL_STATE_KEYS){if(!getters[key]||!setters[key])fail('WALK_RUNTIME_STATE_INCOMPLETE',`Runtime state binding is missing ${key}`)}
 for(const key of WALK_MAP_EDITOR_WALK_GENERATION_REQUIRED_FACTORIES)if(!factories[key])fail('WALK_RUNTIME_FACTORY_INCOMPLETE',`Runtime factory binding is missing ${key}`);
 return Object.freeze({getters:Object.freeze(getters),setters:Object.freeze(setters),factories:Object.freeze(factories)});
}

function captureState(table){
 const state={};for(const key of WALK_MAP_EDITOR_WALK_INSTALL_STATE_KEYS){const value=table.getters[key]();if(value===undefined||value===null)fail('WALK_RUNTIME_STATE_INVALID',`Live state is missing ${key}`);if(ARRAY_STATE_KEYS.has(key)&&!Array.isArray(value))fail('WALK_RUNTIME_STATE_INVALID',`Live state ${key} must be an array`);state[key]=value}return Object.freeze(state);
}
async function setState(table,state,context){for(const key of WALK_MAP_EDITOR_WALK_INSTALL_STATE_KEYS)await table.setters[key](state[key],{...context,key})}

function validateSources(snapshot){
 if(!plain(snapshot)||typeof snapshot.token!=='string'||!snapshot.token.trim()||!sameKeys(snapshot.rawSources,WALK_MAP_EDITOR_WALK_RUNTIME_SOURCE_NAMES))fail('WALK_RUNTIME_SOURCE_SNAPSHOT_INVALID','Source snapshot requires an exact revision token and five raw sources');
 const rawSources={},parsed={},revisions={};for(const name of WALK_MAP_EDITOR_WALK_RUNTIME_SOURCE_NAMES){const value=snapshot.rawSources[name];if(!plain(value)||typeof value.text!=='string'||!value.text.trim()||typeof value.revision!=='string'||!value.revision.trim())fail('WALK_RUNTIME_SOURCE_SNAPSHOT_INVALID',`Raw source is incomplete: ${name}`);try{parsed[name]=JSON.parse(value.text)}catch{fail('WALK_RUNTIME_SOURCE_JSON_INVALID',`Raw source JSON is invalid: ${name}`)}rawSources[name]=Object.freeze({text:value.text,revision:value.revision});revisions[name]=value.revision}
 if(!Array.isArray(parsed.buildings?.instances)||parsed.buildings.instances.length!==75||!Array.isArray(parsed.detention?.instances)||parsed.detention.instances.length!==3)fail('WALK_RUNTIME_BUILDING_INVENTORY','Source snapshot must contain exactly 75 buildings and 3 detention sites');
 if(!Array.isArray(parsed.decor?.instances)||parsed.decor.instances.length!==164)fail('WALK_RUNTIME_DECOR_INVENTORY','Source snapshot must contain exactly 164 decor records');
 return Object.freeze({token:snapshot.token,rawSources:Object.freeze(rawSources),parsed:Object.freeze(parsed),revisions:Object.freeze(revisions)});
}
function plans(value){
 if(!sameKeys(value,WALK_MAP_EDITOR_WALK_RUNTIME_PLAN_NAMES))fail('WALK_RUNTIME_PLANS_INCOMPLETE','Generated plan snapshot must contain exactly four plans');
 const capability=Object.freeze({roadDressing:typeof value.roadDressing?.isRoad==='function',parking:Array.isArray(value.parking?.lots)&&Array.isArray(value.parking?.surfaceRects),explorationDecor:Array.isArray(value.explorationDecor?.objects)&&Array.isArray(value.explorationDecor?.colliders),railway:typeof value.railway?.blocksPlacement==='function'&&typeof value.railway?.landscape?.groundHeight==='function'&&typeof value.railway?.landscape?.waterAt==='function'});
 if(!Object.values(capability).every(Boolean))fail('WALK_RUNTIME_PLAN_CAPABILITY','Generated plan capabilities are incomplete',capability);return Object.freeze({snapshot:Object.freeze(Object.fromEntries(WALK_MAP_EDITOR_WALK_RUNTIME_PLAN_NAMES.map(name=>[name,value[name]]))),capability});
}
function exactRoots(state,source){
 const instances=state.instances;if(instances.length!==242)fail('WALK_RUNTIME_ROOT_INVENTORY','Live instances must contain exactly 242 authored roots');const byId=new Map();for(const root of instances){const id=rootId(root);if(!id||byId.has(id))fail('WALK_RUNTIME_ROOT_INVENTORY','Live authored roots require unique source ids');byId.set(id,root)}
 const buildingRecords=[...source.parsed.buildings.instances,...source.parsed.detention.instances],decorRecords=source.parsed.decor.instances,resolve=(records,label)=>records.map(record=>{const root=byId.get(String(record.id));if(!root)fail('WALK_RUNTIME_ROOT_INVENTORY',`Live root is missing for ${label}: ${record.id}`);return root}),buildings=resolve(buildingRecords,'building'),decor=resolve(decorRecords,'decor');if(new Set([...buildings,...decor]).size!==242)fail('WALK_RUNTIME_ROOT_INVENTORY','Building and decor root inventories overlap');return Object.freeze({buildings:Object.freeze(buildings),decor:Object.freeze(decor)});
}
function equalRevisions(a,b){return WALK_MAP_EDITOR_WALK_RUNTIME_SOURCE_NAMES.every(name=>a?.[name]===b?.[name])}

/** Text-only audit. Importing this module never executes walk_preview. */
export function auditWalkPreviewRuntimeBindingsSourceContract({walkPreviewSource=''}={}){
 const detached=auditWalkPreviewDetachedGenerationSourceContract({walkPreviewSource}),install=auditWalkPreviewGenerationInstallSourceContract({walkPreviewSource}),exports=Object.freeze({sourceSnapshot:/export\s+(async\s+)?function\s+captureWalkMapEditorSourceSnapshot\b/.test(walkPreviewSource),subsystemBindings:/export\s+(async\s+)?function\s+createWalkMapEditorRuntimeSubsystemBindings\b/.test(walkPreviewSource),frameSubscription:/export\s+(async\s+)?function\s+subscribeWalkMapEditorFrame\b/.test(walkPreviewSource)}),missingExports=Object.freeze([...(exports.sourceSnapshot?[]:['captureWalkMapEditorSourceSnapshot: raw texts/revisions plus one atomic revision token']),...(exports.subsystemBindings?[]:['createWalkMapEditorRuntimeSubsystemBindings: exact 18-owner getters/setters/factories and install lifecycle']),...(exports.frameSubscription?[]:['subscribeWalkMapEditorFrame: one editor frame subscriber with unsubscribe'])]);
 return Object.freeze({schema:WALK_MAP_EDITOR_WALK_RUNTIME_BINDINGS_SCHEMA,ready:missingExports.length===0&&detached.ready&&install.ready,exports,missingExports,anchors:Object.freeze({detached,install})});
}

/**
 * Isolated production composition. All reads/builds remain dormant until the
 * production adapter's existing clean-KeyK gate calls captureEditorContext.
 */
export function createWalkMapEditorWalkRuntimeBindings({THREE,subsystems,sourceSnapshots,generatedPlans,editorContext,lifecycle,compileArtifacts,createBuilder=createWalkMapEditorWalkGenerationBuilder,createInstaller=createWalkMapEditorWalkGenerationInstall,createProductionAdapter=createWalkMapEditorProductionAdapter}={}){
 if(!THREE||!plain(sourceSnapshots)||!plain(generatedPlans)||!plain(editorContext)||!plain(lifecycle))throw new Error('Walk runtime bindings require THREE, subsystem, source, plan, editor and lifecycle injections');
 const table=collectSubsystems(subsystems);for(const [name,value] of Object.entries({captureSourceSnapshot:sourceSnapshots.captureSnapshot,currentSourceToken:sourceSnapshots.currentToken,captureGeneratedPlans:generatedPlans.captureSnapshot,captureLive:editorContext.captureLive,captureServices:editorContext.captureServices,captureInput:editorContext.captureInput,subscribeFrame:editorContext.subscribeFrame,enterCriticalSection:lifecycle.enterCriticalSection,verifyInstalledState:lifecycle.verifyInstalledState,disposeState:lifecycle.disposeState,compileArtifacts}))required(value,name);
 const builder=createBuilder({THREE,factories:table.factories});let disposed=false,frameActive=null,revision=0;const adapters=new Set();
 const install=createInstaller({bindings:{captureState:()=>captureState(table),enterCriticalSection:lifecycle.enterCriticalSection,swapState:(next,context)=>setState(table,next,{...context,mode:'install'}),verifyState:lifecycle.verifyInstalledState,restoreState:(prior,context)=>setState(table,prior,{...context,mode:'restore'}),disposeState:lifecycle.disposeState}});
 const rebuild=Object.freeze({compileArtifacts,buildGeneration:builder.buildGeneration,snapshotGeneration:install.snapshotGeneration,installGeneration:install.installGeneration,verifyInstalled:install.verifyInstalled,restoreGeneration:install.restoreGeneration,disposeGeneration:builder.disposeGeneration,releaseGeneration:install.releaseGeneration});
 function assertActive(){if(disposed)fail('WALK_RUNTIME_DISPOSED','Walk runtime bindings are disposed')}
 async function captureEditorContext(){
  assertActive();const beforeState=captureState(table),source=validateSources(await sourceSnapshots.captureSnapshot()),tokenNow=await sourceSnapshots.currentToken();if(tokenNow!==source.token)fail('WALK_RUNTIME_SOURCE_STALE','Raw sources changed during capture');const plan=plans(await generatedPlans.captureSnapshot()),roots=exactRoots(beforeState,source),live=await editorContext.captureLive(),services=await editorContext.captureServices(),input=await editorContext.captureInput(),afterState=captureState(table);if(!sameState(beforeState,afterState))fail('WALK_RUNTIME_CAPTURE_MUTATED','Live generation references changed during editor capture');if(await sourceSnapshots.currentToken()!==source.token)fail('WALK_RUNTIME_SOURCE_STALE','Raw sources changed during editor capture');const token=`walk-runtime:${source.token}:${++revision}`;
  return Object.freeze({schema:WALK_MAP_EDITOR_PRODUCTION_CONTEXT_SCHEMA,token,rawSources:source.rawSources,roots,generatedPlans:plan.snapshot,live,services,input,rebuild,bootstrapOptions:typeof editorContext.captureBootstrapOptions==='function'?await editorContext.captureBootstrapOptions():undefined,__runtime:Object.freeze({sourceToken:source.token,state:beforeState,revisions:source.revisions,planCapabilities:plan.capability})});
 }
 async function verifyEditorContext({token,sourceRevisions}){assertActive();const source=validateSources(await sourceSnapshots.captureSnapshot()),activeToken=String(token||''),sourceToken=activeToken.split(':').slice(2,-1).join(':');const ok=source.token===sourceToken&&await sourceSnapshots.currentToken()===source.token&&equalRevisions(source.revisions,sourceRevisions);return Object.freeze({ok,token:activeToken,sourceRevisions:source.revisions})}
 function subscribeFrame(callback){assertActive();required(callback,'frame callback');if(frameActive)fail('WALK_RUNTIME_FRAME_SUBSCRIBER','Only one editor frame subscriber is allowed');const unsubscribe=editorContext.subscribeFrame(callback);if(typeof unsubscribe!=='function')fail('WALK_RUNTIME_FRAME_SUBSCRIBER','Frame subscription must return an unsubscribe callback');let active=true;frameActive=()=>{if(!active)return;active=false;try{unsubscribe()}finally{frameActive=null}};return frameActive}
 const runtimeContext=Object.freeze({captureEditorContext,verifyEditorContext,subscribeFrame});
 function attachProductionAdapter(options={}){assertActive();const adapter=createProductionAdapter({...options,runtimeContext});adapters.add(adapter);return adapter}
 return Object.freeze({schema:WALK_MAP_EDITOR_WALK_RUNTIME_BINDINGS_SCHEMA,runtimeContext,rebuild,builder,installer:install,attachProductionAdapter,get disposed(){return disposed},async dispose(){if(disposed)return;disposed=true;const current=[...adapters];adapters.clear();await Promise.allSettled(current.map(adapter=>adapter.dispose()));frameActive?.();await install.dispose();builder.dispose();}});
}
