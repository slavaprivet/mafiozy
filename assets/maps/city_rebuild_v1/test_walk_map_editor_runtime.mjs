import assert from 'node:assert/strict';
import {createWalkMapEditorRuntime} from './walk_map_editor_runtime.mjs';

const log=[];
const items=[{key:'buildings:house-1',label:'Дом',locked:false},{key:'buildings:bank-1',label:'Банк',locked:true}];
const adapter={enumerate:()=>items.map(item=>({...item})),cancelPreview:key=>log.push(['cancelPreview',key])};
let uiAction,openChange,inputAction;
const ui={mode:'top',tool:'select',activeAsset:null,root:{querySelector:()=>null},setOpen(value){this.open=value;openChange(value)},setCatalog(value){this.catalog=value},setPalette(value){this.palette=value},setSelection(value){this.selection=value},setActiveAsset(value){this.activeAsset=value},setHistory(value){this.history=value},setMode(value){this.mode=value},setTool(value){this.tool=value},notify(value){log.push(['notify',value])},confirmDelete(value){log.push(['confirmDelete',value.key])},dispose(){log.push(['ui.dispose'])}};
const input={phase:'game',setPhase(value){this.phase=value},dispose(){log.push(['input.dispose'])}};
const runtime=createWalkMapEditorRuntime({adapter,createUi:options=>{uiAction=options.onAction;openChange=options.onOpenChange;return ui},createInput:options=>{inputAction=options.onAction;return input},hooks:{
 enter:()=>log.push(['enter']),leave:value=>log.push(['leave',value.reason]),setMode:value=>log.push(['mode',value]),
 pick:()=>({key:'buildings:house-1'}),deleteObject:({item})=>{log.push(['delete',item.key]);return true},
 undo:()=>true,redo:()=>true,save:()=>({message:'Сохранено безопасно'}),historyState:()=>({canUndo:true,canRedo:false}),palette:()=>[{key:'lamp',label:'Фонарь'}],placeAsset:asset=>log.push(['placeAsset',asset.key]),
 cancel:reason=>log.push(['cancel',reason]),
 sceneAction:action=>log.push(['scene',action.action]),error:error=>{throw error}
}});

assert.equal(runtime.active,false);assert.equal(input.phase,'game');assert.equal(ui.catalog.length,2);
await inputAction({action:'toggle'});assert.equal(runtime.active,true);assert.equal(input.phase,'top');assert.equal(ui.open,true);
await uiAction('place-asset',{asset:ui.palette[0]});assert.deepEqual(log.at(-1),['placeAsset','lamp']);assert.equal(ui.tool,'place');
ui.activeAsset=ui.palette[0];await uiAction('cancel-place',{reason:'scope-change'});assert.deepEqual(log.at(-1),['cancel','scope-change']);assert.equal(ui.activeAsset,null);assert.equal(ui.tool,'select');
await uiAction('place-asset',{asset:ui.palette[0]});assert.equal(ui.tool,'place');
ui.activeAsset={key:'missing'};assert.equal(await uiAction('place-asset',{asset:ui.activeAsset}),false);assert.equal(ui.activeAsset,null);
await inputAction({action:'mode',mode:'fly'});assert.equal(ui.mode,'fly');assert.equal(input.phase,'fly');
await inputAction({action:'mode',mode:'top'});await inputAction({action:'tool',tool:'select'});await inputAction({action:'primary-end'},{clientX:10,clientY:20});assert.equal(runtime.selection.key,'buildings:house-1');
await inputAction({action:'delete'});assert.equal(runtime.selection,null);assert.ok(log.some(row=>row[0]==='delete'));
runtime.setSelection(items[1]);await inputAction({action:'delete'});assert.deepEqual(log.at(-1),['confirmDelete','buildings:bank-1']);
await uiAction('delete',{item:items[1],confirmed:true});assert.ok(log.some(row=>row[0]==='delete'&&row[1]==='buildings:bank-1'));
await inputAction({action:'undo'});await inputAction({action:'redo'});await inputAction({action:'save'});assert.ok(log.some(row=>row[0]==='notify'&&row[1]==='Сохранено безопасно'));
await inputAction({action:'toggle'});assert.equal(runtime.active,false);assert.equal(input.phase,'game');assert.equal(ui.open,false);
assert.equal(ui.selection,null);
await runtime.dispose();assert.ok(log.some(row=>row[0]==='input.dispose'));assert.ok(log.some(row=>row[0]==='ui.dispose'));
assert.equal(log.filter(row=>row[0]==='leave').length,1,'dispose after close must not leave twice');

const deferred=()=>{let resolve,reject;const promise=new Promise((yes,no)=>{resolve=yes;reject=no});return {promise,resolve,reject}};
function harness({source=[{key:'a',label:'A'},{key:'b',label:'B',locked:true}],adapter:adapterOverride={},hooks:hookOverride={}}={}){
 const events=[];let uiActionLocal=()=>{},inputActionLocal=()=>{},openChangeLocal=()=>{};
 const localUi={mode:'top',tool:'select',activeAsset:null,root:{querySelector:()=>null},
  setOpen(value){this.open=value;openChangeLocal(value)},setCatalog(value){this.catalog=value},setPalette(value){this.palette=value},
  appendCatalog(value){this.catalog.push(...value);return value.length},setCatalogStatus(value){this.catalogStatus=value},
  setSelection(value){this.selection=value},setActiveAsset(value){this.activeAsset=value},setHistory(value){this.history=value},setMode(value){this.mode=value},setTool(value){this.tool=value},
  notify(value){events.push(['notify',value])},confirmDelete(value){events.push(['confirm',value.key])},dispose(){events.push(['ui.dispose'])}};
 const localInput={phase:'game',setPhase(value){this.phase=value},dispose(){events.push(['input.dispose'])}};
 const localAdapter={enumerate:()=>source.map(item=>({...item})),...adapterOverride};
 const localHooks={error:(error,stage)=>events.push(['error',stage,error.message]),...hookOverride};
 const localRuntime=createWalkMapEditorRuntime({adapter:localAdapter,
  createUi:options=>{uiActionLocal=options.onAction;openChangeLocal=options.onOpenChange;return localUi},
  createInput:options=>{inputActionLocal=options.onAction;return localInput},hooks:localHooks});
 return {events,ui:localUi,input:localInput,runtime:localRuntime,uiAction:(...args)=>uiActionLocal(...args),inputAction:(...args)=>inputActionLocal(...args)};
}

// Closing while enter is pending invalidates the open ticket, waits for enter,
// then performs cleanup exactly once. Cleanup failures cannot skip host leave.
const enterGate=deferred(),race=harness({
 adapter:{disposePreview:()=>{throw new Error('preview cleanup failed')}},
 hooks:{enter:()=>enterGate.promise,leave:({reason})=>race.events.push(['leave',reason]),closed:()=>{throw new Error('observer failed')}}
});
const pendingOpen=race.runtime.open();assert.equal(race.input.phase,'entering');
const pendingClose=race.runtime.close('race');assert.equal(race.input.phase,'leaving');
enterGate.resolve();assert.equal(await pendingOpen,false);assert.equal(await pendingClose,true);
assert.equal(race.runtime.active,false);assert.equal(race.input.phase,'game');assert.equal(race.ui.open,false);
assert.equal(race.events.filter(row=>row[0]==='leave').length,1);
assert.ok(race.events.some(row=>row[0]==='error'&&row[1]==='disposePreview'));
assert.ok(race.events.some(row=>row[0]==='error'&&row[1]==='closed'));
await race.runtime.dispose();assert.equal(race.events.filter(row=>row[0]==='leave').length,1);

// Missing destructive host callbacks never report a fake success or clear the
// live selection. Stale/unknown objects cannot bypass canonical lookup.
const missing=harness();await missing.runtime.open();missing.runtime.setSelection({key:'a',label:'stale'});
assert.equal(await missing.inputAction({action:'delete'}),false);assert.equal(missing.runtime.selection.key,'a');
assert.ok(missing.events.some(row=>row[0]==='error'&&row[1]==='delete'));
assert.ok(!missing.events.some(row=>row[0]==='notify'&&row[1].startsWith('Объект удалён')));
assert.equal(await missing.inputAction({action:'delete',item:{key:'unknown'},confirmed:true}),false);
await missing.runtime.dispose();

// The latest async pick wins even when an older raycast resolves afterwards.
const pickFirst=deferred(),pickSecond=deferred(),pickQueue=[pickFirst,pickSecond];
const picking=harness({hooks:{pick:()=>pickQueue.shift().promise}});await picking.runtime.open();
const firstPick=picking.inputAction({action:'primary-end'},{clientX:1});
const secondPick=picking.inputAction({action:'primary-end'},{clientX:2});
pickSecond.resolve({key:'b'});await secondPick;pickFirst.resolve({key:'a'});await firstPick;
assert.equal(picking.runtime.selection.key,'b');await picking.runtime.dispose();

// Async mode callbacks cannot let a stale, slower request overwrite the last
// requested mode or its input phase.
const flyGate=deferred(),topGate=deferred();
const modes=harness({hooks:{setMode:value=>value==='fly'?flyGate.promise:topGate.promise}});await modes.runtime.open();
const flyRequest=modes.inputAction({action:'mode',mode:'fly'}),topRequest=modes.inputAction({action:'mode',mode:'top'});
topGate.resolve(true);assert.equal(await topRequest,true);flyGate.resolve(true);assert.equal(await flyRequest,false);
assert.equal(modes.ui.mode,'top');assert.equal(modes.input.phase,'top');await modes.runtime.dispose();

// A partially completed enter that rejects still receives preview cleanup and
// one balancing leave; it cannot leave host state alive behind a closed panel.
const failedEnter=harness({
 adapter:{disposePreview:()=>failedEnter.events.push(['disposePreview'])},
 hooks:{enter:()=>Promise.reject(new Error('enter failed')),leave:({reason})=>failedEnter.events.push(['leave',reason])}
});
assert.equal(await failedEnter.runtime.open(),false);assert.equal(failedEnter.runtime.active,false);assert.equal(failedEnter.input.phase,'game');
assert.ok(failedEnter.events.some(row=>row[0]==='disposePreview'));
assert.deepEqual(failedEnter.events.filter(row=>row[0]==='leave'),[['leave','enter-error']]);
await failedEnter.runtime.dispose();assert.equal(failedEnter.events.filter(row=>row[0]==='leave').length,1);

// Close waits for an already-started host placement before disposing preview,
// so a late async callback cannot recreate preview after cleanup.
const placementGate=deferred(),placementOrder=[];
const placement=harness({
 adapter:{disposePreview:()=>placementOrder.push('disposePreview')},
 hooks:{palette:()=>[{key:'lamp',label:'Lamp'}],placeAsset:()=>placementGate.promise,leave:()=>placementOrder.push('leave')}
});
await placement.runtime.open();
const placing=placement.uiAction('place-asset',{asset:{key:'lamp'}}),closingPlacement=placement.runtime.close('placement-race');
await Promise.resolve();assert.deepEqual(placementOrder,[]);
placementGate.resolve(true);assert.equal(await placing,false);assert.equal(await closingPlacement,true);
assert.deepEqual(placementOrder,['disposePreview','leave']);await placement.runtime.dispose();

// Document mutations are serialized: save cannot overtake an unfinished undo
// and capture a revision that is still changing.
const undoGate=deferred(),mutationOrder=[];
const mutations=harness({hooks:{undo:()=>{mutationOrder.push('undo-start');return undoGate.promise},save:()=>{mutationOrder.push('save');return {message:'saved'}}}});await mutations.runtime.open();
const undoing=mutations.inputAction({action:'undo'}),saving=mutations.inputAction({action:'save'});await Promise.resolve();assert.deepEqual(mutationOrder,['undo-start']);undoGate.resolve(true);await undoing;await saving;assert.deepEqual(mutationOrder,['undo-start','save']);await mutations.runtime.dispose();

// Authored records render immediately; generated batches are accepted only
// while the matching editor-open ticket remains current.
let catalogContext,catalogRetries=0,catalogCloses=0,catalogDisposes=0,catalogCategory=null;
const asyncCatalog=harness({hooks:{catalogOpen:context=>{catalogContext=context},catalogRetry:()=>{catalogRetries++},catalogClose:()=>{catalogCloses++},catalogDispose:()=>{catalogDisposes++},catalogCategory:value=>{catalogCategory=value}}});
await asyncCatalog.runtime.open();assert.equal(asyncCatalog.ui.catalog.length,2,'authored catalog must be available synchronously on open');
assert.equal(catalogContext.onBatch([{key:'generated:1',label:'Generated'}]),1);assert.equal(asyncCatalog.ui.catalog.length,3);catalogContext.onStatus({status:'loading',loaded:1,total:9659,message:'Загружено объектов: 1 из 9659…'});assert.equal(asyncCatalog.ui.catalogStatus.status,'loading');
await asyncCatalog.uiAction('catalog-category',{category:'signs'});assert.equal(catalogCategory,'signs');await asyncCatalog.uiAction('retry-catalog',{});assert.equal(catalogRetries,1);
await asyncCatalog.runtime.close('catalog-test');assert.equal(catalogCloses,1);assert.equal(catalogContext.onBatch([{key:'generated:late'}]),0,'stale batch after close must be ignored');
await asyncCatalog.runtime.dispose();assert.equal(catalogDisposes,1);

console.log('walk map editor runtime: PASS');
