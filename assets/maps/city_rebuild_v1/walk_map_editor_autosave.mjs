export class WalkMapEditorAutosaveError extends Error{constructor(message){super(message);this.name='WalkMapEditorAutosaveError';}}

function isObject(value){return value!==null&&typeof value==='object'&&!Array.isArray(value);}
function validSession(session){return isObject(session)&&isObject(session.document)&&Number.isSafeInteger(session.revision)&&session.revision>=0&&session.document.revision===session.revision;}
function russianSaveError(error){const message=String(error?.message||''),name=String(error?.name||'');if(/quota|storage full|disk full/i.test(`${name} ${message}`))return 'Не удалось сохранить копию: хранилище браузера заполнено. Освободите место или скачайте проект JSON.';if(error?.name==='AbortError')return 'Сохранение отменено.';return 'Не удалось сохранить копию восстановления. Проект остаётся открыт; попробуйте ещё раз или скачайте JSON.';}
function defaultIdle(callback){if(typeof globalThis.requestIdleCallback==='function')return globalThis.requestIdleCallback(callback,{timeout:1000});return setTimeout(callback,0);}
function defaultCancelIdle(handle){if(typeof globalThis.cancelIdleCallback==='function')globalThis.cancelIdleCallback(handle);else clearTimeout(handle);}
function statusMessage(status,lastError){if(status==='dirty')return 'Есть несохранённые изменения.';if(status==='saving')return 'Сохраняю копию для восстановления…';if(status==='error')return lastError||'Не удалось сохранить копию восстановления.';if(status==='disposed')return 'Автосохранение остановлено.';return 'Все изменения сохранены.';}

export function createWalkMapEditorAutosave({getSession,saveRecovery,clearRecovery=()=>{},onStatus=()=>{},debounceMs=700,scheduleDelay=(callback,delay)=>setTimeout(callback,delay),cancelDelay=handle=>clearTimeout(handle),scheduleIdle=defaultIdle,cancelIdle=defaultCancelIdle}={}){
 if(typeof getSession!=='function'||typeof saveRecovery!=='function'||typeof clearRecovery!=='function'||typeof onStatus!=='function'||typeof scheduleDelay!=='function'||typeof cancelDelay!=='function'||typeof scheduleIdle!=='function'||typeof cancelIdle!=='function'||!Number.isFinite(debounceMs)||debounceMs<0||debounceMs>60000)throw new WalkMapEditorAutosaveError('Invalid autosave configuration');
 const initial=getSession();if(!validSession(initial))throw new WalkMapEditorAutosaveError('Autosave requires a valid editor session');
 let latestRevision=initial.revision,savedRevision=initial.revision,delayHandle=null,idleHandle=null,inFlight=null,inFlightRevision=null,inFlightController=null,clearController=null,disposed=false,lastError=null,status='saved',generation=0,flushSerial=0;
 function snapshot(){const dirty=latestRevision>savedRevision;return Object.freeze({status,message:statusMessage(status,lastError),dirty,saving:status==='saving'||!!inFlight,latestRevision,savedRevision,inFlightRevision,lastError,shouldWarnBeforeUnload:dirty});}
 function emit(){const value=snapshot();try{onStatus(value);}catch{}return value;}
 function setStatus(next,error=null){status=next;lastError=error;return emit();}
 function active(){if(disposed)throw new WalkMapEditorAutosaveError('Autosave controller is disposed');}
 function cancelScheduled(){if(delayHandle!==null){cancelDelay(delayHandle);delayHandle=null;}if(idleHandle!==null){cancelIdle(idleHandle);idleHandle=null;}}
 function schedule(){
  if(disposed||latestRevision<=savedRevision)return false;cancelScheduled();delayHandle=scheduleDelay(()=>{delayHandle=null;if(disposed)return;idleHandle=scheduleIdle(()=>{idleHandle=null;void flush('idle');});},debounceMs);return true;
 }
 async function performSave(reason){
  if(disposed||latestRevision<=savedRevision)return true;const session=getSession();if(!validSession(session)||session.revision!==latestRevision){setStatus('error','Текущая версия карты не совпадает с последним подтверждённым commit. Сохранение отложено.');return false;}
  const revision=latestRevision,controller=new AbortController(),saveGeneration=generation;inFlightRevision=revision;inFlightController=controller;setStatus('saving');
  let finish;const operation=new Promise(resolve=>{finish=resolve});inFlight=operation;
  void(async()=>{let outcome=false;try{await saveRecovery(session,{revision,reason,signal:controller.signal});if(!disposed&&saveGeneration===generation&&!controller.signal.aborted){savedRevision=Math.max(savedRevision,revision);setStatus(latestRevision>savedRevision?'dirty':'saved');outcome=true;}}catch(error){if(!disposed&&saveGeneration===generation)setStatus('error',russianSaveError(error));}finally{if(inFlight===operation){inFlight=null;inFlightRevision=null;inFlightController=null;}finish(outcome);}})();return operation;
 }
 async function flush(reason='manual'){
  active();const serial=++flushSerial;cancelScheduled();if(inFlight){await inFlight;if(disposed)return false;if(latestRevision<=savedRevision)return true;if(['close','pagehide','manual'].includes(reason))return flush(reason);if(serial===flushSerial)schedule();return false;}
  const success=await performSave(reason);if(disposed)return false;if(success&&latestRevision>savedRevision){if(['close','pagehide','manual'].includes(reason))return flush(reason);if(serial===flushSerial)schedule();}return success&&latestRevision<=savedRevision;
 }
 function notifyCommitted(session=getSession()){
  active();if(!validSession(session))throw new WalkMapEditorAutosaveError('Committed session is invalid');const current=getSession();if(!validSession(current)||current.revision!==session.revision||current.document!==session.document)throw new WalkMapEditorAutosaveError('Committed session is not the active editor session');if(session.revision<=latestRevision)return false;latestRevision=session.revision;setStatus(inFlight?'saving':'dirty');schedule();return true;
 }
 async function clearStoredRecovery(){
  active();cancelScheduled();
  if(inFlight){inFlightController?.abort();await inFlight;active();}
  const controller=new AbortController(),clearGeneration=generation,clearedThroughRevision=latestRevision;clearController=controller;
  try{await clearRecovery({signal:controller.signal});if(disposed||clearGeneration!==generation||controller.signal.aborted)return false;savedRevision=Math.max(savedRevision,clearedThroughRevision);setStatus(latestRevision>savedRevision?'dirty':'saved');return true;}
  catch(error){if(disposed||clearGeneration!==generation)return false;setStatus('error',russianSaveError(error));return false;}
  finally{if(clearController===controller)clearController=null;}
 }
 emit();
 return Object.freeze({
  get state(){return snapshot();},
  notifyCommitted,
  notifyPreview(){active();return false;},
  flush,
  onEditorClose(){return flush('close');},
  onPageHide(){return flush('pagehide');},
  clearRecovery:clearStoredRecovery,
  shouldWarnBeforeUnload(){return !disposed&&latestRevision>savedRevision;},
  dispose(){if(disposed)return;disposed=true;generation++;flushSerial++;cancelScheduled();inFlightController?.abort();clearController?.abort();inFlight=null;inFlightRevision=null;inFlightController=null;clearController=null;status='disposed';lastError=null;emit();}
 });
}
