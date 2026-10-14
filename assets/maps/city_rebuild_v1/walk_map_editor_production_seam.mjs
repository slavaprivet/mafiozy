import {createWalkMapEditorLazyGate} from './walk_map_editor_lazy_gate.mjs';

export const WALK_MAP_EDITOR_PRODUCTION_SEAM_SCHEMA='mafiozi.walk-map-editor.production-seam/v1';
export const WALK_MAP_EDITOR_PRODUCTION_SOURCE_ANCHORS=Object.freeze({
 legacyPanel:"panel.id='mfzEditor20'",
 legacyInit:'init();',
 walkBranch:'rendererSelection.get("render")==="3d"&&rendererSelection.get("renderer")==="walk"',
 mercenaryGuard:'const mercenaryInputBlocked=',
 hudGuard:'const hudInputBlocked=',
 heldKeys:'const keys=new Set()',
 rmbWaypoint:"addEventListener('mousedown'",
 pointerLock:"addEventListener('pointerlockchange'",
});

const plain=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
const asPromise=value=>Promise.resolve(value);
const reason=error=>String(error?.message||error||'Unknown editor integration error');
function rendererValue(selection,key){return typeof selection?.get==='function'?selection.get(key):selection?.[key]??null}
function blocker(base){try{return typeof base==='function'?!!base():!!base}catch{return true}}
function required(value,label){if(typeof value!=='function')throw new Error(`Walk map editor production seam requires ${label}`);return value}

export function walkMapEditorLegacyInitDecision(selection,{enabled=true}={}){
 const productionWalk=enabled===true&&rendererValue(selection,'render')==='3d'&&rendererValue(selection,'renderer')==='walk';
 return Object.freeze({schema:WALK_MAP_EDITOR_PRODUCTION_SEAM_SCHEMA,productionWalk,installProductionGate:productionWalk,suppressLegacyInit:productionWalk,action:productionWalk?'suppress-legacy-init':'no-op'});
}

/** Read-only evidence for the future world/walk wiring patch. */
export function auditWalkMapEditorProductionSourceContract({worldSource='',walkPreviewSource=''}={}){
 const legacyPanels=worldSource.split(WALK_MAP_EDITOR_PRODUCTION_SOURCE_ANCHORS.legacyPanel).length-1,legacyInitCalls=(worldSource.match(/\binit\(\);/g)||[]).length;
 const checks=Object.freeze({
  walkRendererBranch:worldSource.includes(WALK_MAP_EDITOR_PRODUCTION_SOURCE_ANCHORS.walkBranch),
  legacyEditorDefinitions:legacyPanels>=1,
  oneLegacyRuntimeInit:legacyInitCalls===1,
  mercenaryInputGuard:walkPreviewSource.includes(WALK_MAP_EDITOR_PRODUCTION_SOURCE_ANCHORS.mercenaryGuard),
  hudInputGuard:walkPreviewSource.includes(WALK_MAP_EDITOR_PRODUCTION_SOURCE_ANCHORS.hudGuard),
  heldKeySet:walkPreviewSource.includes(WALK_MAP_EDITOR_PRODUCTION_SOURCE_ANCHORS.heldKeys)&&walkPreviewSource.includes("addEventListener('blur',()=>keys.clear())"),
  rmbWaypointCapture:walkPreviewSource.includes(WALK_MAP_EDITOR_PRODUCTION_SOURCE_ANCHORS.rmbWaypoint)&&walkPreviewSource.includes('waypointVisual?.visible'),
  pointerLockChange:walkPreviewSource.includes(WALK_MAP_EDITOR_PRODUCTION_SOURCE_ANCHORS.pointerLock)&&walkPreviewSource.includes('releaseControls()'),
 });
 return Object.freeze({complete:Object.values(checks).every(Boolean),checks,inventory:Object.freeze({legacyPanels,legacyInitCalls})});
}

function createGuard(onChange=()=>{}){
 let phase='game',gateState=()=>({state:'idle',pendingToggleParity:0}),revision=0;
 const owns=()=>phase==='entering'||phase==='editor'||phase==='leaving'||gateState()?.state==='loading'&&gateState()?.pendingToggleParity===1;
 const snapshot=()=>Object.freeze({phase,ownsInput:owns(),revision,gateState:gateState()?.state||'idle',pendingToggleParity:gateState()?.pendingToggleParity||0});
 function publish(next,detail=null){if(phase===next)return snapshot();phase=next;revision++;const value=snapshot();try{onChange(value,detail)}catch{}return value}
 const api=Object.freeze({
  get phase(){return phase},get ownsInput(){return owns()},snapshot,
  mercenaryInputBlocked:base=>owns()||blocker(base),
  hudInputBlocked:base=>owns()||blocker(base),
  rmbWaypointBlocked:()=>owns(),
  pointerLockChangeBlocked:()=>owns(),
  refreshBlocked:()=>owns(),
  blocks:channel=>['mercenary','hud','rmb-waypoint','pointerlockchange','refresh'].includes(channel)?owns():false,
 });
 return {api,publish,setGateState:getter=>{gateState=getter}};
}

function createOwnership({guard,inputHost,services,onError}){
 const capture=required(inputHost.captureGameplayState,'inputHost.captureGameplayState'),restore=required(inputHost.restoreGameplayState,'inputHost.restoreGameplayState'),clearHeld=required(inputHost.clearHeldKeys,'inputHost.clearHeldKeys'),closeMenus=required(inputHost.closeConflictingMenus,'inputHost.closeConflictingMenus'),releasePointerLock=required(inputHost.releasePointerLock,'inputHost.releasePointerLock');
 const refresh=typeof inputHost.refreshInput==='function'?inputHost.refreshInput:()=>{};
 const releaseControls=required(services.releaseControls,'services.releaseControls'),enterGameEditor=required(services.enterGameEditor,'services.enterGameEditor'),leaveGameEditor=required(services.leaveGameEditor,'services.leaveGameEditor');
 let lease=null,capturePromise=null,restorePromise=null,sequence=0;
 async function acquire(){
  if(lease)return lease;if(capturePromise)return capturePromise;const id=++sequence;guard.publish('entering',{id});
  capturePromise=(async()=>{const snapshot=await asPromise(capture());if(snapshot===undefined)throw new Error('captureGameplayState returned no snapshot');lease={id,snapshot,restored:false};await asPromise(clearHeld({reason:'editor-enter',id}));await asPromise(closeMenus({reason:'editor-enter',id}));await asPromise(releasePointerLock({reason:'editor-enter',id}));await asPromise(releaseControls());return lease})().catch(async error=>{const failures=[error],current=lease;let restored=!current;if(current&&!current.restored)try{await asPromise(restore(current.snapshot,{reason:'editor-enter-failed',id:current.id}));current.restored=true;restored=true}catch(restoreError){failures.push(restoreError)}if(restored)lease=null;try{await asPromise(refresh({reason:'editor-enter-failed',phase:restored?'game':'leaving'}))}catch(refreshError){failures.push(refreshError)}guard.publish(restored?'game':'leaving',{id,error:reason(error)});if(failures.length>1)throw new AggregateError(failures,'Map editor ownership acquisition failed');throw error}).finally(()=>{capturePromise=null});
  return capturePromise;
 }
 async function entered(...args){await asPromise(enterGameEditor(...args));guard.publish('editor',{id:lease?.id??null});return true}
 async function release(reasonValue='editor-leave',args=[],{skipLeave=false}={}){
  if(restorePromise)return restorePromise;const current=lease;guard.publish('leaving',{id:current?.id??null,reason:reasonValue});
  restorePromise=(async()=>{const failures=[];if(!skipLeave)try{await asPromise(leaveGameEditor(...args))}catch(error){failures.push(error)}
   try{await asPromise(clearHeld({reason:'editor-leave',id:current?.id??null}))}catch(error){failures.push(error)}
   let restored=!current||current.restored;if(current&&!current.restored)try{await asPromise(restore(current.snapshot,{reason:reasonValue,id:current.id}));current.restored=true;restored=true}catch(error){failures.push(error)}
   if(restored)lease=null;try{await asPromise(refresh({reason:reasonValue,phase:restored?'game':'leaving'}))}catch(error){failures.push(error)}guard.publish(restored?'game':'leaving',{reason:reasonValue});
   if(failures.length===1)throw failures[0];if(failures.length>1)throw new AggregateError(failures,'Map editor gameplay restoration failed');return true;
  })().finally(()=>{restorePromise=null});return restorePromise;
 }
 async function forceRestore(reasonValue='editor-force-restore'){
  if(capturePromise)try{await capturePromise}catch{}
  if(!lease){if(guard.api.phase!=='disposed')guard.publish('game',{reason:reasonValue});return true}
  try{return await release(reasonValue,[],{skipLeave:true})}catch(error){try{onError(error,'restore')}catch{}throw error}
 }
 return {acquire,entered,release,forceRestore,get lease(){return lease},services:{...services,releaseControls:acquire,enterGameEditor:(...args)=>entered(...args),leaveGameEditor:(...args)=>release(args?.[0]?.reason||'editor-leave',args)}};
}

function createSynchronousController({bootstrap,guard,ownership,onError}){
 const runtime=bootstrap?.host?.runtime;if(!runtime||typeof runtime.open!=='function'||typeof runtime.close!=='function'||typeof bootstrap.dispose!=='function')throw new Error('Live bootstrap returned no compatible host runtime');
 let desired=!!runtime.active,running=false,disposed=false,pumpPromise=Promise.resolve(),disposePromise=null;
 function startPump(){
  if(running||disposed)return;running=true;
  pumpPromise=(async()=>{while(!disposed&&!!runtime.active!==desired){const opening=desired;guard.publish(opening?'entering':'leaving',{reason:'controller-toggle'});let result;try{result=opening?await runtime.open():await runtime.close('production-toggle')}catch(error){try{onError(error,opening?'open':'close')}catch{}result=false}if(!opening&&!runtime.active)try{await ownership.forceRestore('post-close')}catch(error){try{onError(error,'restore')}catch{}}if(result===false){desired=!!runtime.active;if(!runtime.active)await ownership.forceRestore('toggle-rejected').catch(error=>{try{onError(error,'restore')}catch{}});break}}})().finally(()=>{running=false;if(!disposed&&!!runtime.active!==desired)startPump()});
 }
 const controller={
  get active(){return !!runtime.active},get desiredOpen(){return desired},get bootstrap(){return bootstrap},
  toggle(){if(disposed)return false;desired=running?!desired:!runtime.active;guard.publish(desired?'entering':'leaving',{reason:'controller-toggle-request'});startPump();return true},
  whenSettled(){return pumpPromise},
  dispose(){if(disposePromise)return disposePromise;disposed=true;desired=false;disposePromise=(async()=>{await pumpPromise;await bootstrap.dispose();await ownership.forceRestore('controller-dispose')})();return disposePromise;}
 };
 return controller;
}

/**
 * Side-effect-free except for installing the tiny KeyK lazy-gate listener.
 * The dynamic module, source snapshots, plans, GLBs and catalogs are untouched
 * until that gate accepts its first clean capture-phase KeyK.
 */
export function createWalkMapEditorProductionSeam({
 target=globalThis.window,
 document:doc=globalThis.document,
 rendererSelection,
 enabled=true,
 loadBootstrapModule,
 createBootstrapOptions,
 inputHost,
 onGuardChange=()=>{},
 onReady=()=>{},
 onError=()=>{},
 createGate=createWalkMapEditorLazyGate,
}={}){
 const decision=walkMapEditorLegacyInitDecision(rendererSelection,{enabled}),guardState=createGuard(onGuardChange);
 if(!decision.installProductionGate){let disposed=false;return Object.freeze({schema:WALK_MAP_EDITOR_PRODUCTION_SEAM_SCHEMA,active:false,decision,guard:guardState.api,get controller(){return null},get gate(){return null},dispose(){disposed=true;guardState.publish('disposed',{reason:'inactive-dispose'});return Promise.resolve()},get disposed(){return disposed}})}
 required(loadBootstrapModule,'loadBootstrapModule');required(createBootstrapOptions,'createBootstrapOptions');if(!plain(inputHost))throw new Error('Walk map editor production seam requires inputHost');
 let controller=null,ownership=null,disposed=false,disposePromise=null,attempt=0;
 const gate=createGate({target,document:doc,
  loadEditor:async()=>{const currentAttempt=++attempt,module=await loadBootstrapModule({attempt:currentAttempt});if(disposed)throw new Error('Map editor production seam disposed during module load');const factory=required(module?.createWalkMapEditorLiveBootstrap,'module.createWalkMapEditorLiveBootstrap'),options=await createBootstrapOptions({attempt:currentAttempt,guard:guardState.api});if(!plain(options)||!plain(options.services))throw new Error('Map editor bootstrap options must include services');ownership=createOwnership({guard:guardState,inputHost,services:options.services,onError});const bootstrap=await factory({...options,services:ownership.services});if(disposed){await bootstrap?.dispose?.();throw new Error('Map editor production seam disposed during bootstrap creation')}return {bootstrap,ownership};},
  createEditor:({bootstrap,ownership:currentOwnership})=>{controller=createSynchronousController({bootstrap,guard:guardState,ownership:currentOwnership,onError});return controller},
  onReady:value=>{try{onReady(value)}catch{}},onError:error=>{guardState.publish('game',{reason:'load-error',error:reason(error)});try{onError(error,'load')}catch{}}
 });
 guardState.setGateState(()=>gate);
 const seam={schema:WALK_MAP_EDITOR_PRODUCTION_SEAM_SCHEMA,active:true,decision,guard:guardState.api,get controller(){return controller},get gate(){return gate},get disposed(){return disposed},dispose(){if(disposePromise)return disposePromise;disposed=true;gate.dispose();disposePromise=(async()=>{await gate.whenSettled();if(controller)await controller.dispose();else if(ownership)await ownership.forceRestore('seam-dispose');guardState.publish('disposed',{reason:'seam-dispose'})})();return disposePromise;}};
 return Object.freeze(seam);
}
