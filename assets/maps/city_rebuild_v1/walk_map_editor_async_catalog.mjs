export class WalkMapEditorAsyncCatalogError extends Error{constructor(message){super(message);this.name='WalkMapEditorAsyncCatalogError';}}

function plain(value){return value!==null&&typeof value==='object'&&!Array.isArray(value);}
function abortError(){return Object.assign(new Error('catalog load cancelled'),{name:'AbortError'});}
function aborted(error){return error?.name==='AbortError'||error?.code==='ABORT_ERR';}
function defaultSchedule(){return new Promise(resolve=>setTimeout(resolve,0));}
function loaderDescriptor(raw,index){
 const value=typeof raw==='function'?{load:raw}:raw,id=String(value?.id??`generated-${index+1}`),load=value?.load??value?.batches;
 if(!plain(value)||!id||id.length>160||typeof load!=='function')throw new WalkMapEditorAsyncCatalogError(`Invalid generated catalog loader at index ${index}`);
 const categories=Array.isArray(value.categories)?[...new Set(value.categories.map(String).filter(Boolean))]:[];
 const total=value.total===undefined||value.total===null?null:value.total;if(total!==null&&(!Number.isSafeInteger(total)||total<0))throw new WalkMapEditorAsyncCatalogError(`Invalid total for loader ${id}`);
 return Object.freeze({id,label:String(value.label??id),categories:Object.freeze(categories),total,load});
}
function normalizeChunk(value){if(Array.isArray(value))return {items:value,total:null};if(plain(value)&&Array.isArray(value.items))return {items:value.items,total:value.total??null};throw new WalkMapEditorAsyncCatalogError('Generated catalog loader returned an invalid batch');}
async function* chunksFrom(value){const source=await value;if(source?.[Symbol.asyncIterator]){for await(const chunk of source)yield normalizeChunk(chunk);return}if(source?.[Symbol.iterator]&&!Array.isArray(source)&&typeof source!=='string'){for(const chunk of source)yield normalizeChunk(chunk);return}yield normalizeChunk(source);}
function freezeState(value){return Object.freeze({...value,failed:Object.freeze(value.failed.map(item=>Object.freeze({...item})))});}

export function createWalkMapEditorAsyncCatalog({loaders=[],onBatch=()=>{},onStatus=()=>{},batchSize=160,scheduleTask=defaultSchedule,keyOf=item=>item?.key??item?.id}={}){
 if(!Array.isArray(loaders)||typeof onBatch!=='function'||typeof onStatus!=='function'||typeof scheduleTask!=='function'||typeof keyOf!=='function'||!Number.isSafeInteger(batchSize)||batchSize<1||batchSize>1000)throw new WalkMapEditorAsyncCatalogError('Invalid async catalog configuration');
 let descriptors=loaders.map(loaderDescriptor),disposed=false,active=false,generation=0,attempt=0,priority=null,running=null,controller=null;
 const completed=new Set(),failed=new Map(),items=new Map(),loaderTotals=new Map(descriptors.filter(item=>item.total!==null).map(item=>[item.id,item.total]));
 let state=freezeState({status:'idle',active:false,loaded:0,total:descriptors.every(item=>item.total!==null)?descriptors.reduce((sum,item)=>sum+item.total,0):null,completedSources:0,totalSources:descriptors.length,failed:[],message:'Каталог дополнительных объектов ещё не загружался.'});
 const emit=()=>{try{onStatus(state)}catch{}return state;};
 function assertAlive(){if(disposed)throw new WalkMapEditorAsyncCatalogError('Async catalog controller is disposed');}
 function totalValue(){if(descriptors.every(item=>loaderTotals.has(item.id)))return [...loaderTotals.values()].reduce((sum,value)=>sum+value,0);return null;}
 function update(status,message){state=freezeState({status,active,loaded:items.size,total:totalValue(),completedSources:completed.size,totalSources:descriptors.length,failed:[...failed].map(([id,error])=>({id,message:String(error?.message||error||'Ошибка загрузки')})),message});return emit();}
 function progressMessage(){const total=totalValue(),loaded=items.size;return total===null?`Загружено объектов: ${loaded}…`:`Загружено объектов: ${loaded} из ${total}…`;}
 function stillCurrent(token){return !disposed&&active&&token===generation&&!controller?.signal.aborted;}
 async function deliver(rawItems,meta,token){
  for(let offset=0;offset<rawItems.length;offset+=batchSize){
   if(!stillCurrent(token))throw abortError();const accepted=[];
   for(const raw of rawItems.slice(offset,offset+batchSize)){if(!plain(raw))continue;const key=String(keyOf(raw)??'');if(!key||items.has(key))continue;const item=Object.freeze({...raw,key});items.set(key,item);accepted.push(item)}
   if(accepted.length){await onBatch(Object.freeze(accepted),Object.freeze({...meta,loaded:items.size,total:totalValue()}));if(!stillCurrent(token))throw abortError();update('loading',progressMessage())}
   if(offset+batchSize<rawItems.length){await scheduleTask({signal:controller.signal,sourceId:meta.sourceId});if(!stillCurrent(token))throw abortError()}
  }
 }
 function nextQueue(onlyFailed=false){const pending=descriptors.filter(item=>!completed.has(item.id)&&(!onlyFailed||failed.has(item.id)));return pending.sort((a,b)=>Number(!(priority&&a.categories.includes(priority)))-Number(!(priority&&b.categories.includes(priority))));}
 async function run({onlyFailed=false,replay=false}={}){
  assertAlive();if(running)return running;active=true;const token=++generation,runController=new AbortController();controller=runController;attempt++;
  const task=(async()=>{
   await Promise.resolve();
   try{
    update('loading',progressMessage());
    if(replay&&items.size){const cached=[...items.values()];for(let offset=0;offset<cached.length;offset+=batchSize){if(!stillCurrent(token))throw abortError();await onBatch(Object.freeze(cached.slice(offset,offset+batchSize)),Object.freeze({sourceId:'cache',replay:true,loaded:Math.min(cached.length,offset+batchSize),total:totalValue()}));if(offset+batchSize<cached.length)await scheduleTask({signal:runController.signal,sourceId:'cache'})}}
    const queue=nextQueue(onlyFailed);for(const descriptor of queue){
     if(!stillCurrent(token))throw abortError();failed.delete(descriptor.id);let sourceLoaded=0;
     try{
      const produced=descriptor.load({signal:runController.signal,categories:descriptor.categories,priorityCategory:priority,attempt});
      for await(const chunk of chunksFrom(produced)){if(chunk.total!==null&&chunk.total!==undefined){if(!Number.isSafeInteger(chunk.total)||chunk.total<0)throw new WalkMapEditorAsyncCatalogError(`Invalid batch total for ${descriptor.id}`);loaderTotals.set(descriptor.id,chunk.total)}sourceLoaded+=chunk.items.length;await deliver(chunk.items,{sourceId:descriptor.id,replay:false},token)}
      if(!loaderTotals.has(descriptor.id))loaderTotals.set(descriptor.id,sourceLoaded);completed.add(descriptor.id);
     }catch(error){if(aborted(error)||!stillCurrent(token))throw abortError();failed.set(descriptor.id,error);}
     if(stillCurrent(token))update('loading',progressMessage());await scheduleTask({signal:runController.signal,sourceId:descriptor.id});
    }
    if(!stillCurrent(token))return false;
    if(failed.size)update('error',`Загружено объектов: ${items.size}. Не удалось загрузить источников: ${failed.size}. Можно повторить.`);
    else update('ready',`Дополнительные объекты загружены: ${items.size}.`);return failed.size===0;
   }catch(error){if(!aborted(error)&&stillCurrent(token)){update('error',`Не удалось загрузить каталог. Можно повторить.`);return false}return false;
   }finally{if(running===task){running=null;controller=null}}
  })();running=task;return task;
 }
 emit();
 return Object.freeze({
  get state(){return state},get items(){return Object.freeze([...items.values()])},get active(){return active},get disposed(){return disposed},
  open({category=null}={}){assertAlive();if(category)priority=String(category);if(active&&running)return running;if(active&&completed.size===descriptors.length&&!failed.size){update('ready',`Дополнительные объекты загружены: ${items.size}.`);return Promise.resolve(true)}return run({replay:!active&&items.size>0});},
  start(options){return this.open(options)},
  setPriority(category){assertAlive();priority=category?String(category):null;return priority},
  retry(){assertAlive();if(!failed.size)return Promise.resolve(false);if(!active)active=true;return run({onlyFailed:true,replay:false})},
  cancel(reason='close'){assertAlive();if(!active&&!running)return false;active=false;generation++;controller?.abort();controller=null;running=null;update('cancelled',reason==='close'?'Фоновая загрузка остановлена.':'Загрузка отменена.');return true},
  close(){return this.cancel('close')},
  dispose(){if(disposed)return;active=false;disposed=true;generation++;controller?.abort();controller=null;running=null;descriptors=[];completed.clear();failed.clear();items.clear();loaderTotals.clear();state=freezeState({...state,status:'disposed',active:false,message:'Загрузчик каталога закрыт.',failed:[]});emit();}
 });
}
