import {createWalkMapEditorUi} from './walk_map_editor_ui.mjs';
import {createWalkMapEditorInput} from './walk_map_editor_input.mjs';

function asPromise(value){return Promise.resolve(value);}

/**
 * Connects the editor UI/input to the live world through narrow host callbacks.
 * The host remains responsible for authoritative document transactions and for
 * rebuilding derived gameplay data after a committed edit.
 */
export function createWalkMapEditorRuntime({
 document:doc=globalThis.document,
 parent=doc?.body,
 target=globalThis.window,
 canvas,
 adapter,
 createUi=createWalkMapEditorUi,
 createInput=createWalkMapEditorInput,
 hooks={}
}={}){
 if(!adapter?.enumerate)throw new Error('Map editor runtime requires an authored object adapter');
 let active=false,disposed=false,disposing=false,transition=0,closingUi=false,selection=null;
 let openingPromise=null,closingPromise=null,disposePromise=null,pickRevision=0,modeRevision=0,toolRevision=0,catalogRevision=0;
 let mutationTail=Promise.resolve();
 const pendingHostTasks=new Set();
 let currentMode='top',currentTool='select';
 const hasHook=name=>typeof hooks[name]==='function';
 const call=(name,...args)=>(hasHook(name)?hooks[name](...args):undefined);
 function report(error,stage){try{const result=call('error',error,stage);result?.catch?.(()=>{})}catch{}}
 function signal(name,...args){try{const result=call(name,...args);result?.catch?.(error=>report(error,name));return result}catch(error){if(name!=='error')report(error,name);return undefined}}
 function requireHook(name){if(!hasHook(name))throw new Error(`Map editor host callback is missing: ${name}`);return hooks[name]}
 async function trackHost(value){const promise=asPromise(value);pendingHostTasks.add(promise);try{return await promise}finally{pendingHostTasks.delete(promise)}}
 function serializeMutation(run){const next=mutationTail.then(run,run);mutationTail=next.catch(()=>{});return next}
 function catalog(){const value=adapter.enumerate();return Array.isArray(value)?value:[]}
 const itemByKey=(key,items=catalog())=>items.find(item=>item?.key===key)||null;

 let ui,input;

 function refreshCatalog(){
  const items=catalog(),previous=selection;
  ui.setCatalog(items);
  if(ui.setPalette)try{const value=call('palette');ui.setPalette(Array.isArray(value)?value:[])}catch(error){report(error,'palette');ui.setPalette([])}
  selection=selection?.key?itemByKey(selection.key,items):null;ui.setSelection(selection);
  if(previous&&!selection)signal('selectionChanged',null);
  return items;
 }
 function setSelection(item){selection=item||null;ui.setSelection(selection);signal('selectionChanged',selection)}
 function setHistory(value){
  let state=value;
  if(!state)try{state=call('historyState')}catch(error){report(error,'historyState');state=null}
  ui.setHistory(state||{});
 }
 function setSaveState(value){let state=value;if(!state)try{state=call('saveState')}catch(error){report(error,'saveState');state=null}ui.setSaveState?.(state||{});return state;}
 function setCatalogStatus(value,ticket=catalogRevision){if(disposed||ticket!==catalogRevision)return false;ui.setCatalogStatus?.(value||{});return true;}
 function appendCatalog(items,ticket=catalogRevision){if(disposed||disposing||!active||ticket!==catalogRevision)return 0;return ui.appendCatalog?.(items)||0;}
 function catalogContext(ticket){return Object.freeze({category:ui.category||'all',onBatch:items=>appendCatalog(items,ticket),onStatus:value=>setCatalogStatus(value,ticket)});}
 function startCatalog(){if(!hasHook('catalogOpen'))return;const ticket=++catalogRevision,result=signal('catalogOpen',catalogContext(ticket));result?.catch?.(error=>{if(ticket===catalogRevision&&!disposed){report(error,'catalogOpen');setCatalogStatus({status:'error',message:'Не удалось загрузить дополнительные объекты.'},ticket)}});}
 function stopCatalog(reason){catalogRevision++;ui.setCatalogStatus?.({status:'cancelled',message:'Фоновая загрузка остановлена.'});signal('catalogClose',{reason});}
 function hideUi(){closingUi=true;try{ui.setOpen(false)}finally{closingUi=false}}
 function showUi(){closingUi=true;try{ui.setOpen(true)}finally{closingUi=false}}
 function resetModePresentation(){ui.setMode(currentMode);input.setPhase(currentMode==='fly'?'fly':'top')}

 async function open(){
  if(disposed||disposing)return false;
  if(openingPromise)return openingPromise;
  if(closingPromise)await closingPromise;
  if(disposed||disposing)return false;
  if(active)return true;
  const ticket=++transition;input.setPhase('entering');
  const task=(async()=>{
   try{
    await asPromise(call('enter',{mode:currentMode,tool:currentTool}));
    if(disposed||disposing||ticket!==transition)return false;
    active=true;refreshCatalog();showUi();input.setPhase(currentMode==='fly'?'fly':'top');setHistory();setSaveState();startCatalog();signal('opened');return true;
   }catch(error){
    report(error,'enter');
    if(ticket===transition){
     try{await asPromise(adapter.disposePreview?.())}catch(cleanupError){report(cleanupError,'disposePreview')}
     signal('cancelPreview');
     try{await asPromise(call('leave',{reason:'enter-error',selection}))}catch(cleanupError){report(cleanupError,'leave')}
     stopCatalog('enter-error');active=false;setSelection(null);ui.setActiveAsset?.(null);hideUi();input.setPhase('game');signal('closed','enter-error');
    }
    return false;
   }
  })();
  openingPromise=task;
  try{return await task}finally{if(openingPromise===task)openingPromise=null}
 }

 async function close(reason='close'){
  if(disposed)return true;
  if(closingPromise)return closingPromise;
  if(!active&&!openingPromise){setSelection(null);ui.setActiveAsset?.(null);hideUi();input.setPhase('game');return true}
  const pendingOpen=openingPromise,ticket=++transition;input.setPhase('leaving');stopCatalog(reason);
  const task=(async()=>{
   if(pendingOpen)try{await pendingOpen}catch(error){report(error,'enter')}
   if(pendingHostTasks.size)await Promise.allSettled([...pendingHostTasks]);
   try{await asPromise(adapter.disposePreview?.())}catch(error){report(error,'disposePreview')}
   signal('cancelPreview');
   try{await asPromise(call('leave',{reason,selection}))}catch(error){report(error,'leave')}
   if(ticket!==transition)return false;
   active=false;setSelection(null);ui.setActiveAsset?.(null);hideUi();input.setPhase('game');signal('closed',reason);return true;
  })();
  closingPromise=task;
  try{return await task}finally{if(closingPromise===task)closingPromise=null}
 }

 async function deleteItem(item,confirmed=false,event=null){
  try{
   const canonical=item?.key?itemByKey(item.key):null;
   if(!canonical)return false;
   if(canonical.locked&&!confirmed){ui.confirmDelete(canonical);return false}
   const lifecycleTicket=transition,key=canonical.key;
   const changed=await trackHost(serializeMutation(()=>requireHook('deleteObject')({item:canonical,confirmed,event})));
   if(changed===false)return false;
   if(disposed||disposing||lifecycleTicket!==transition||!active)return true;
   if(selection?.key===key)setSelection(null);
   refreshCatalog();setHistory();ui.notify('Объект удалён · Ctrl+Z — вернуть');return true;
  }catch(error){report(error,'delete');ui.notify('Не удалось удалить объект безопасно');return false}
 }

 async function selectAtPointer(event){
  const revision=++pickRevision,lifecycleTicket=transition;
  const result=await trackHost(call('pick',{event,canvas,mode:currentMode,tool:currentTool}));
  const key=result?.key||result?.item?.key,item=key?itemByKey(key):null;
  if(revision!==pickRevision||lifecycleTicket!==transition||!active)return {item:null,result,stale:true};
  setSelection(item);return {item,result,stale:false};
 }

 async function handleAction(action,event=null){
  if(disposed||disposing||!action?.action)return;
  const name=action.action;
  if(name==='toggle')return active||openingPromise||closingPromise?close('toggle'):open();
  if(name==='close')return close('panel');
  if(name==='clear-input'){signal('clearInput',action.reason);return}
  if(!active||openingPromise||closingPromise)return;
  try{
   if(name==='mode'){
    if(!['top','fly'].includes(action.mode))return false;
    const revision=++modeRevision,lifecycleTicket=transition;
    const accepted=await trackHost(call('setMode',action.mode,{previous:currentMode}));
    if(revision!==modeRevision||lifecycleTicket!==transition||!active)return false;
    if(accepted===false){resetModePresentation();return false}
    currentMode=action.mode;ui.setMode(currentMode);input.setPhase(currentMode==='fly'?'fly':'top');return true;
   }
   if(name==='tool'){
    if(!['select','move','rotate','place','paint'].includes(action.tool))return false;
    const revision=++toolRevision,lifecycleTicket=transition;
    const accepted=await trackHost(call('setTool',action.tool,{previous:currentTool}));
    if(revision!==toolRevision||lifecycleTicket!==transition||!active)return false;
    if(accepted===false){ui.setTool(currentTool);return false}
    currentTool=action.tool;ui.setTool(currentTool);return true;
   }
   if(name==='catalog-category'){signal('catalogCategory',action.category);return true}
   if(name==='retry-catalog'){const ticket=catalogRevision,result=signal('catalogRetry',catalogContext(ticket));result?.catch?.(error=>{report(error,'catalogRetry');setCatalogStatus({status:'error',message:'Повторная загрузка не удалась.'},ticket)});return result}
   if(name==='select'){const item=action.item?.key?itemByKey(action.item.key):null;setSelection(item);return item}
   if(name==='place-asset'){
    const assets=hasHook('palette')?call('palette'):[],asset=Array.isArray(assets)?assets.find(item=>(item?.key||item?.id||item?.assetId)===(action.asset?.key||action.asset?.id||action.asset?.assetId)):null;
    if(!asset){ui.setActiveAsset?.(null);ui.setTool(currentTool);ui.setSelection(selection);return false}
    const lifecycleTicket=transition,result=await trackHost(requireHook('placeAsset')(asset,{mode:currentMode,tool:'place',previousTool:currentTool,selection}));
    if(result===false){ui.setActiveAsset?.(null);ui.setTool(currentTool);ui.setSelection(selection);return false}
    if(lifecycleTicket!==transition||!active)return false;
    currentTool=result?.tool==='paint'?'paint':'place';ui.setTool(currentTool);setSelection(null);return result;
   }
   if(name==='primary-end'&&currentTool==='select'){await selectAtPointer(event);return}
   if(name==='delete-at-pointer'){const {item}=await selectAtPointer(event);return deleteItem(item,false,event)}
   if(name==='delete')return deleteItem(action.item||selection,!!action.confirmed,event);
   if(name==='undo'||name==='redo'){
    if(!hasHook(name))return false;
    const lifecycleTicket=transition,changed=await trackHost(serializeMutation(()=>call(name)));
    if(changed===false||lifecycleTicket!==transition||!active)return false;
    refreshCatalog();setHistory();ui.notify(name==='undo'?'Изменение отменено':'Изменение возвращено');return true;
   }
   if(name==='save'){
    const lifecycleTicket=transition,result=await trackHost(serializeMutation(()=>requireHook('save')()));
    if(lifecycleTicket!==transition||!active)return result;
    if(result!==false){setHistory();setSaveState();ui.notify(result?.message||'Карта сохранена')}
    return result;
   }
   if(name==='files')return await trackHost(call('files',{selection,mode:currentMode,tool:currentTool}));
   if(name==='focus-search'){ui.root?.querySelector?.('.wme-search')?.focus?.({preventScroll:true});return true}
   if(name==='text-escape'){doc?.activeElement?.blur?.();ui.root?.querySelector?.('.wme-panel')?.focus?.({preventScroll:true});return true}
   if(name==='cancel-place'){
    await trackHost(call('cancel',action.reason||'cancel-place'));
    currentTool='select';ui.setActiveAsset?.(null);ui.setTool(currentTool);return true;
   }
   if(name==='cancel'){
    try{await trackHost(adapter.cancelPreview?.(selection?.key))}catch(error){report(error,'cancelPreview')}
    if(ui.activeAsset){ui.setActiveAsset?.(null);currentTool='select';ui.setTool(currentTool)}
    signal('cancel',{selection});return true;
   }
   if(name==='commit'){
    const lifecycleTicket=transition,result=await trackHost(serializeMutation(()=>requireHook('commit')({selection})));
    if(lifecycleTicket!==transition||!active)return result;
    setHistory();if(result!==false)ui.notify('Изменение применено');return result;
   }
   return await trackHost(call('sceneAction',action,event,{selection,mode:currentMode,tool:currentTool,activeAsset:ui.activeAsset||null}));
  }catch(error){
   if(name==='mode')resetModePresentation();
   if(name==='tool')ui.setTool(currentTool);
   if(name==='place-asset'){ui.setActiveAsset?.(null);ui.setTool(currentTool);ui.setSelection(selection)}
   report(error,name);ui.notify('Действие отменено: карта осталась без изменений');return false;
  }
 }

 ui=createUi({document:doc,parent,onAction:(name,payload={})=>handleAction({action:name,...payload}),onOpenChange:openValue=>{if(!openValue&&active&&!closingUi)void close('panel')}});
 currentMode=ui.mode==='fly'?'fly':'top';currentTool=['select','move','rotate','place','paint'].includes(ui.tool)?ui.tool:'select';
 input=createInput({target,document:doc,canvas,isActive:()=>active,getMode:()=>currentMode,getTool:()=>currentTool,isModalOpen:()=>!!ui.root?.querySelector?.('dialog[open]'),onAction:handleAction});
 refreshCatalog();setHistory();setSaveState();

 return {
  ui,input,
  get active(){return active},get selection(){return selection},
  open,close,handleAction,refreshCatalog,setSelection,setHistory,setSaveState,setCatalogStatus,appendCatalog,
  dispose(){
   if(disposePromise)return disposePromise;
   disposing=true;
   disposePromise=(async()=>{
    try{await close('dispose')}finally{
     disposed=true;active=false;
     try{input.dispose()}catch(error){report(error,'input.dispose')}
     try{ui.dispose()}catch(error){report(error,'ui.dispose')}
     signal('catalogDispose');signal('disposed');
    }
   })();
   return disposePromise;
  }
 };
}
