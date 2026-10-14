export const WALK_MAP_EDITOR_ATOMIC_REBUILD_SCHEMA='mafiozi.walk-map-editor.atomic-rebuild/v1';

const asPromise=value=>Promise.resolve(value);
const required=(value,label)=>{if(typeof value!=='function')throw new Error(`Atomic editor rebuild requires ${label}`);return value};
const abortError=()=>Object.assign(new Error('Atomic editor rebuild was cancelled'),{name:'AbortError',code:'EDITOR_REBUILD_CANCELLED'});
const plain=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);

/**
 * Serializes editor rebuilds. buildStage must create a detached generation;
 * installStage is the only allowed live swap. A failed/partial swap is restored
 * from the exact opaque snapshot captured immediately before that request.
 */
export function createWalkMapEditorAtomicRebuild({
 snapshotLive,
 buildStage,
 validateStage,
 installStage,
 verifyLive=()=>true,
 restoreLive,
 disposeStage=()=>{},
 releaseSnapshot=()=>{},
 onState=()=>{}
}={}){
 for(const [name,value] of Object.entries({snapshotLive,buildStage,validateStage,installStage,verifyLive,restoreLive,disposeStage,releaseSnapshot}))required(value,name);
 let disposed=false,activeController=null,sequence=0,queue=Promise.resolve(),last=Object.freeze({phase:'idle',requestId:null,completed:0,failed:0});
 function publish(phase,detail={}){last=Object.freeze({phase,requestId:detail.requestId??last.requestId,completed:detail.completed??last.completed,failed:detail.failed??last.failed,error:detail.error??null});try{onState(last)}catch{}return last}
 async function run(meta,requestId){
  if(disposed)throw abortError();const controller=new AbortController();activeController=controller;let snapshot=null,stage=null,installAttempted=false,restored=false;
  try{
   publish('snapshot',{requestId});snapshot=await asPromise(snapshotLive({requestId,meta,signal:controller.signal}));if(snapshot===undefined||snapshot===null)throw new Error('Atomic editor rebuild snapshot is missing');if(controller.signal.aborted)throw abortError();
   publish('building',{requestId});stage=await asPromise(buildStage({requestId,meta,signal:controller.signal,snapshot}));if(stage===undefined||stage===null)throw new Error('Atomic editor rebuild stage is missing');if(controller.signal.aborted)throw abortError();
   publish('validating',{requestId});const validation=await asPromise(validateStage(stage,{requestId,meta,signal:controller.signal,snapshot}));if(validation!==true&&validation?.ok!==true)throw new Error(validation?.message||validation?.reason||'Atomic editor rebuild validation failed');if(controller.signal.aborted)throw abortError();
   publish('installing',{requestId});installAttempted=true;const result=await asPromise(installStage(stage,{requestId,meta,signal:controller.signal,snapshot,validation}));if(controller.signal.aborted)throw abortError();
   publish('verifying',{requestId});const verification=await asPromise(verifyLive({requestId,meta,stage,result,snapshot,validation,signal:controller.signal}));if(verification!==true&&verification?.ok!==true)throw new Error(verification?.message||verification?.reason||'Atomic editor rebuild live verification failed');
   await asPromise(releaseSnapshot(snapshot,{requestId,meta,result,verification}));snapshot=null;publish('idle',{requestId,completed:last.completed+1});const output=plain(result)?{...result}:{value:result};return Object.freeze({...output,ok:true,atomicRebuild:Object.freeze({schema:WALK_MAP_EDITOR_ATOMIC_REBUILD_SCHEMA,requestId,verification})});
  }catch(error){
   const failures=[error];if(installAttempted&&snapshot!==null){publish('restoring',{requestId,error:String(error?.message||error)});try{await asPromise(restoreLive(snapshot,{requestId,meta,error,stage}));restored=true}catch(restoreError){failures.push(restoreError)}}
   if(stage!==null)try{await asPromise(disposeStage(stage,{requestId,meta,error,installed:installAttempted,restored}))}catch(disposeError){failures.push(disposeError)}
   if(snapshot!==null&&!installAttempted)try{await asPromise(releaseSnapshot(snapshot,{requestId,meta,error}))}catch(releaseError){failures.push(releaseError)}
   publish(disposed?'disposed':'idle',{requestId,failed:last.failed+1,error:String(error?.message||error)});if(failures.length>1)throw new AggregateError(failures,'Atomic editor rebuild and recovery failed');throw error;
  }finally{if(activeController===controller)activeController=null}
 }
 function requestRebuild(meta={}){if(disposed)return Promise.reject(abortError());const requestId=++sequence,task=queue.then(()=>run(meta,requestId));queue=task.catch(()=>{});return task}
 return Object.freeze({
  schema:WALK_MAP_EDITOR_ATOMIC_REBUILD_SCHEMA,get state(){return last},get disposed(){return disposed},requestRebuild,
  whenIdle(){return queue},
  async dispose(){if(disposed)return queue;disposed=true;activeController?.abort();try{await queue}finally{publish('disposed',{requestId:last.requestId})}}
 });
}
