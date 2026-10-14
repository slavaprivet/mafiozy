import assert from 'node:assert/strict';
import test from 'node:test';
import {readFile} from 'node:fs/promises';
import {auditWalkMapEditorProductionSourceContract,createWalkMapEditorProductionSeam,walkMapEditorLegacyInitDecision} from './walk_map_editor_production_seam.mjs';

class FakeTarget{
 constructor(){this.listeners=new Map()}
 addEventListener(type,handler,options=false){const capture=options===true||!!options?.capture,list=this.listeners.get(type)||[];list.push({handler,capture});this.listeners.set(type,list)}
 removeEventListener(type,handler,options=false){const capture=options===true||!!options?.capture,list=this.listeners.get(type)||[];this.listeners.set(type,list.filter(item=>item.handler!==handler||item.capture!==capture))}
 emit(type,init={}){const target=init.target??{tagName:'CANVAS'},event={type,target,code:'',repeat:false,isComposing:false,keyCode:0,defaultPrevented:false,altKey:false,ctrlKey:false,metaKey:false,preventDefault(){this.defaultPrevented=true},stopPropagation(){},stopImmediatePropagation(){this.immediate=true},composedPath(){return [target]},...init};for(const item of [...(this.listeners.get(type)||[])]){item.handler(event);if(event.immediate)break}return event}
 count(type){return (this.listeners.get(type)||[]).length}
}
const deferred=()=>{let resolve,reject;const promise=new Promise((yes,no)=>{resolve=yes;reject=no});return {promise,resolve,reject}};
const pressK=target=>target.emit('keydown',{code:'KeyK'});
const settle=async seam=>{await seam.gate.whenSettled();await seam.controller?.whenSettled();await Promise.resolve()};

function integrationFixture({moduleWait=null,bootstrapWait=null,failFirstLoad=false,enterWait=null,enterFailure=false}={}){
 const target=new FakeTarget(),stats={module:0,options:0,bootstrap:0,plans:0,glb:0,catalog:0,bootstrapDispose:0,captures:0,restores:0,clearEnter:0,clearLeave:0,menus:0,pointer:0,release:0,enter:0,leave:0,refresh:0},errors=[],order=[];
 const initial={phase:'walking',camera:{position:[1,2,3],target:[4,5,6]},controls:{enabled:true,minDistance:2},held:true,menu:'inventory',pointerLocked:true},gameplay=structuredClone(initial);
 const replace=value=>{for(const key of Object.keys(gameplay))delete gameplay[key];Object.assign(gameplay,structuredClone(value))};
 const inputHost={
  captureGameplayState(){stats.captures++;order.push('capture');return structuredClone(gameplay)},
  restoreGameplayState(snapshot){stats.restores++;order.push('restore');replace(snapshot)},
  clearHeldKeys({reason}){if(reason==='editor-enter')stats.clearEnter++;else stats.clearLeave++;order.push(`clear:${reason}`);gameplay.held=false},
  closeConflictingMenus(){stats.menus++;order.push('menus');gameplay.menu=null},
  releasePointerLock(){stats.pointer++;order.push('pointer');gameplay.pointerLocked=false},
  refreshInput(){stats.refresh++;order.push('refresh')},
 };
 const services={
  releaseControls(){stats.release++;order.push('release');gameplay.controls.enabled=false},
  async enterGameEditor(){stats.enter++;order.push('enter');if(enterWait)await enterWait.promise;if(enterFailure)throw new Error('enter failed');gameplay.phase='editor'},
  leaveGameEditor(){stats.leave++;order.push('leave');gameplay.phase='leaving'},
 };
 const makeBootstrap=options=>{stats.bootstrap++;stats.plans++;let opening=null,closing=null,disposed=false;
  const runtime={active:false,async open(){if(opening)return opening;opening=(async()=>{try{await options.services.releaseControls();await options.services.enterGameEditor({mode:'top'});runtime.active=true;stats.catalog++;return true}catch{try{await options.services.leaveGameEditor({reason:'enter-error'})}catch{}return false}})();try{return await opening}finally{opening=null}},async close(reason='close'){if(closing)return closing;closing=(async()=>{if(opening)await opening;if(!runtime.active)return true;await options.services.leaveGameEditor({reason});runtime.active=false;return true})();try{return await closing}finally{closing=null}}};
  return {host:{runtime},async dispose(){if(disposed)return;disposed=true;await runtime.close('dispose');stats.bootstrapDispose++}};
 };
 const module={createWalkMapEditorLiveBootstrap:async options=>{if(bootstrapWait)await bootstrapWait.promise;return makeBootstrap(options)}};
 let loadAttempt=0;
 const loadBootstrapModule=async()=>{stats.module++;loadAttempt++;if(moduleWait)await moduleWait.promise;if(failFirstLoad&&loadAttempt===1)throw new Error('dynamic import failed');return module};
 const createBootstrapOptions=async()=>{stats.options++;return {services}};
 const seam=createWalkMapEditorProductionSeam({target,document:{activeElement:null},rendererSelection:{render:'3d',renderer:'walk'},loadBootstrapModule,createBootstrapOptions,inputHost,onError:(error,stage)=>errors.push(`${stage}:${error.message}`)});
 return {target,seam,stats,errors,order,gameplay,initial};
}

test('actual world/walk source exposes every future integration anchor',async()=>{
 const here=new URL('.',import.meta.url),root=new URL('../../../',import.meta.url),[worldSource,walkPreviewSource]=await Promise.all([readFile(new URL('world.html',root),'utf8'),readFile(new URL('walk_preview.mjs',here),'utf8')]),audit=auditWalkMapEditorProductionSourceContract({worldSource,walkPreviewSource});
 assert.equal(audit.complete,true);assert.equal(audit.inventory.legacyPanels,5);assert.equal(audit.inventory.legacyInitCalls,1);for(const [id,value] of Object.entries(audit.checks))assert.equal(value,true,id);
});

test('legacy init is suppressed only for production walk and other renderers are true no-ops',async()=>{
 const walk=walkMapEditorLegacyInitDecision(new URLSearchParams('render=3d&renderer=walk'));assert.equal(walk.suppressLegacyInit,true);assert.equal(walk.installProductionGate,true);assert.equal(walk.action,'suppress-legacy-init');
 for(const selection of [{render:'3d',renderer:'legacy'},{render:'2d',renderer:'walk'},{render:'3d',renderer:'walk',enabled:false}]){const decision=walkMapEditorLegacyInitDecision(selection,{enabled:selection.enabled??true});assert.equal(decision.suppressLegacyInit,false);assert.equal(decision.installProductionGate,false);assert.equal(decision.action,'no-op')}
 const target=new FakeTarget(),seam=createWalkMapEditorProductionSeam({target,rendererSelection:{render:'3d',renderer:'legacy'}});assert.equal(seam.active,false);assert.equal(target.count('keydown'),0);assert.equal(seam.guard.ownsInput,false);await seam.dispose();assert.equal(seam.disposed,true);
});

test('first clean K is the first bootstrap work and ownership restores exact gameplay state',async()=>{
 const fixture=integrationFixture(),{seam,target,stats,gameplay,initial,order}=fixture;
 assert.deepEqual(stats,{module:0,options:0,bootstrap:0,plans:0,glb:0,catalog:0,bootstrapDispose:0,captures:0,restores:0,clearEnter:0,clearLeave:0,menus:0,pointer:0,release:0,enter:0,leave:0,refresh:0});assert.equal(target.count('keydown'),1);assert.equal(seam.guard.ownsInput,false);
 const event=pressK(target);assert.equal(event.defaultPrevented,true);assert.equal(seam.guard.ownsInput,true);await settle(seam);
 assert.equal(stats.module,1);assert.equal(stats.options,1);assert.equal(stats.bootstrap,1);assert.equal(stats.plans,1);assert.equal(stats.glb,0);assert.equal(stats.catalog,1);assert.equal(seam.controller.active,true);assert.equal(seam.guard.phase,'editor');
 for(const value of [seam.guard.mercenaryInputBlocked(false),seam.guard.hudInputBlocked(false),seam.guard.rmbWaypointBlocked(),seam.guard.pointerLockChangeBlocked(),seam.guard.refreshBlocked()])assert.equal(value,true);
 assert.deepEqual(order.slice(0,6),['capture','clear:editor-enter','menus','pointer','release','enter']);assert.equal(stats.captures,1);assert.equal(stats.clearEnter,1);
 seam.controller.toggle();await seam.controller.whenSettled();assert.equal(seam.controller.active,false);assert.equal(seam.guard.ownsInput,false);assert.equal(seam.guard.mercenaryInputBlocked(true),true);assert.deepEqual(gameplay,initial);assert.equal(stats.restores,1);assert.equal(stats.clearLeave,1);assert.deepEqual(order.slice(-4),['leave','clear:editor-leave','restore','refresh']);
 await seam.dispose();assert.equal(stats.bootstrapDispose,1);assert.equal(target.count('keydown'),0);assert.equal(seam.guard.phase,'disposed');assert.equal(stats.restores,1,'dispose after a clean close must not restore twice');
});

test('repeated K parity during async load installs closed on even and opens on odd',async()=>{
 const evenWait=deferred(),even=integrationFixture({moduleWait:evenWait});pressK(even.target);pressK(even.target);assert.equal(even.seam.gate.pendingToggleParity,0);assert.equal(even.seam.guard.ownsInput,false);evenWait.resolve();await settle(even.seam);assert.equal(even.seam.controller.active,false);assert.equal(even.stats.captures,0);assert.equal(even.stats.catalog,0);await even.seam.dispose();
 const oddWait=deferred(),odd=integrationFixture({moduleWait:oddWait});pressK(odd.target);pressK(odd.target);pressK(odd.target);assert.equal(odd.seam.gate.pendingToggleParity,1);assert.equal(odd.seam.guard.ownsInput,true);oddWait.resolve();await settle(odd.seam);assert.equal(odd.seam.controller.active,true);assert.equal(odd.stats.captures,1);assert.equal(odd.stats.catalog,1);await odd.seam.dispose();assert.deepEqual(odd.gameplay,odd.initial);
});

test('async bootstrap construction completes before controller installation and keeps K parity',async()=>{
 const wait=deferred(),fixture=integrationFixture({bootstrapWait:wait});pressK(fixture.target);await Promise.resolve();await Promise.resolve();assert.equal(fixture.seam.gate.state,'loading');assert.equal(fixture.seam.controller,null);assert.equal(fixture.stats.module,1);assert.equal(fixture.stats.options,1);pressK(fixture.target);assert.equal(fixture.seam.gate.pendingToggleParity,0);assert.equal(fixture.seam.guard.ownsInput,false);
 wait.resolve();await settle(fixture.seam);assert.equal(fixture.seam.gate.state,'installed');assert.ok(fixture.seam.controller);assert.equal(fixture.seam.controller.active,false);assert.equal(fixture.stats.catalog,0);await fixture.seam.dispose();assert.equal(fixture.stats.bootstrapDispose,1);
});

test('synchronous controller toggle preserves parity while async entry is pending',async()=>{
 const enterWait=deferred(),fixture=integrationFixture({enterWait});pressK(fixture.target);await fixture.seam.gate.whenSettled();assert.equal(fixture.seam.controller.desiredOpen,true);assert.equal(fixture.seam.guard.ownsInput,true);
 fixture.seam.controller.toggle();fixture.seam.controller.toggle();assert.equal(fixture.seam.controller.desiredOpen,true);enterWait.resolve();await fixture.seam.controller.whenSettled();assert.equal(fixture.seam.controller.active,true);assert.equal(fixture.stats.captures,1);fixture.seam.controller.toggle();await fixture.seam.controller.whenSettled();assert.deepEqual(fixture.gameplay,fixture.initial);await fixture.seam.dispose();
});

test('dynamic load errors retry and leave gameplay ownership neutral',async()=>{
 const fixture=integrationFixture({failFirstLoad:true});pressK(fixture.target);await settle(fixture.seam);assert.equal(fixture.seam.gate.state,'idle');assert.equal(fixture.seam.guard.ownsInput,false);assert.deepEqual(fixture.errors,['load:dynamic import failed']);assert.equal(fixture.stats.options,0);assert.equal(fixture.stats.captures,0);
 pressK(fixture.target);await settle(fixture.seam);assert.equal(fixture.seam.gate.state,'installed');assert.equal(fixture.seam.controller.active,true);assert.equal(fixture.stats.module,2);await fixture.seam.dispose();assert.deepEqual(fixture.gameplay,fixture.initial);
});

test('dispose during module load never creates or opens bootstrap and removes capture listener',async()=>{
 const wait=deferred(),fixture=integrationFixture({moduleWait:wait});pressK(fixture.target);assert.equal(fixture.seam.guard.ownsInput,true);const disposal=fixture.seam.dispose();assert.equal(fixture.target.count('keydown'),0);wait.resolve();await disposal;
 assert.equal(fixture.stats.module,1);assert.equal(fixture.stats.options,0);assert.equal(fixture.stats.bootstrap,0);assert.equal(fixture.stats.captures,0);assert.equal(fixture.stats.catalog,0);assert.equal(fixture.seam.guard.phase,'disposed');assert.deepEqual(fixture.gameplay,fixture.initial);
});

test('dispose during async bootstrap creation disposes the late bootstrap without opening it',async()=>{
 const wait=deferred(),fixture=integrationFixture({bootstrapWait:wait});pressK(fixture.target);await Promise.resolve();await Promise.resolve();assert.equal(fixture.stats.options,1);const disposal=fixture.seam.dispose();wait.resolve();await disposal;
 assert.equal(fixture.stats.bootstrap,1);assert.equal(fixture.stats.bootstrapDispose,1);assert.equal(fixture.stats.captures,0);assert.equal(fixture.stats.catalog,0);assert.equal(fixture.seam.controller,null);assert.equal(fixture.seam.guard.phase,'disposed');assert.deepEqual(fixture.gameplay,fixture.initial);
});

test('entry rejection restores the captured camera/controls once with no stuck input',async()=>{
 const fixture=integrationFixture({enterFailure:true});pressK(fixture.target);await settle(fixture.seam);assert.equal(fixture.seam.controller.active,false);assert.equal(fixture.seam.guard.ownsInput,false);assert.deepEqual(fixture.gameplay,fixture.initial);assert.equal(fixture.stats.captures,1);assert.equal(fixture.stats.restores,1);assert.equal(fixture.stats.leave,1);assert.equal(fixture.stats.clearLeave,1);await fixture.seam.dispose();assert.equal(fixture.stats.restores,1);assert.equal(fixture.stats.bootstrapDispose,1);
});
