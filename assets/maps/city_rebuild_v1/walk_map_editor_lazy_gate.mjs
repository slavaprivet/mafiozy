function eventPath(event){return event.composedPath?.()||[event.target]}
function textInputNode(node){return !!node&&(node.isContentEditable||/^(INPUT|TEXTAREA|SELECT)$/.test(node.tagName||'')||['textbox','searchbox'].includes(node.getAttribute?.('role')))}

export function walkMapEditorLazyGateAcceptsKey(event,{activeElement=null}={}){
 if(event?.type!=='keydown'||event.code!=='KeyK'||event.defaultPrevented||event.repeat||event.isComposing||event.keyCode===229||event.altKey||event.ctrlKey||event.metaKey)return false;
 return ![event.target,...eventPath(event),activeElement].some(textInputNode);
}

function consume(event){event.preventDefault?.();event.stopImmediatePropagation?.();event.stopPropagation?.()}
function validController(controller){return controller!==null&&typeof controller==='object'&&typeof controller.toggle==='function'&&typeof controller.dispose==='function'}
function safeDispose(controller){try{controller?.dispose?.()}catch{}}

export function createWalkMapEditorLazyGate({
 target=globalThis.window,
 document:doc=globalThis.document,
 loadEditor,
 createEditor=loaded=>loaded,
 onReady=()=>{},
 onError=()=>{}
}={}){
 if(!target?.addEventListener||!target?.removeEventListener)throw new Error('Map editor lazy gate requires an event target');
 if(typeof loadEditor!=='function'||typeof createEditor!=='function')throw new Error('Map editor lazy gate requires loadEditor and createEditor functions');
 let state='idle',pending=null,pendingToken=null,controller=null,pendingParity=0,lastError=null,listening=true;

 function removeListener(){if(!listening)return;target.removeEventListener('keydown',handleKey,true);listening=false}
 function reportError(error){lastError=error;try{onError(error)}catch{}}
 function beginLoad(){
  if(state==='loading'||state==='installed'||state==='disposed')return pending;
  state='loading';lastError=null;const token={};pendingToken=token;
  const loaded=Promise.resolve().then(loadEditor).then(createEditor);
  pending=loaded.then(resolved=>{
   if(!validController(resolved)){safeDispose(resolved);throw new Error('Loaded map editor must provide synchronous toggle() and dispose()')}
   if(state==='disposed'||pendingToken!==token){safeDispose(resolved);return}
   const shouldOpen=pendingParity===1;pendingParity=0;
   try{
    if(shouldOpen){const result=resolved.toggle();if(result&&typeof result.then==='function')throw new Error('Loaded map editor toggle() must be synchronous')}
   }catch(error){safeDispose(resolved);throw error}
   controller=resolved;state='installed';pendingToken=null;removeListener();try{onReady(resolved)}catch{}
  },error=>{throw error}).catch(error=>{
   if(pendingToken!==token)return;
   pendingToken=null;pendingParity=0;
   if(state!=='disposed'){state='idle';reportError(error)}
  }).then(()=>{if(pendingToken!==token)pending=null});
  return pending;
 }
 function handleKey(event){
  if(state==='disposed'||!walkMapEditorLazyGateAcceptsKey(event,{activeElement:doc?.activeElement}))return;
  consume(event);pendingParity^=1;if(state==='idle')beginLoad();
 }
 target.addEventListener('keydown',handleKey,true);
 return {
  get state(){return state},get loading(){return state==='loading'},get installed(){return state==='installed'},get pendingToggleParity(){return pendingParity},get lastError(){return lastError},
  whenSettled(){return pending??Promise.resolve()},
  dispose(){
   if(state==='disposed')return;state='disposed';pendingParity=0;pendingToken=null;removeListener();const installed=controller;controller=null;safeDispose(installed);
  }
 };
}
