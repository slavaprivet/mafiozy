const HELD_CODES=new Set(['KeyW','KeyA','KeyS','KeyD','ShiftLeft','ShiftRight','ControlLeft','ControlRight','Space']);
const EDITOR_CAPTURE_CODES=new Set([
 'KeyK','Digit1','Digit2','Numpad1','Numpad2','KeyW','KeyA','KeyS','KeyD','KeyQ','KeyE','KeyR','KeyM','KeyC','KeyZ','KeyY',
 'ShiftLeft','ShiftRight','ControlLeft','ControlRight','Space','Enter','Escape','Delete','BracketLeft','BracketRight','Slash','F8'
]);

function eventPath(event){return event.composedPath?.()||[event.target];}

export function walkMapEditorTextInput(target,path=[],activeElement=null){
 return [target,...path,activeElement].some(node=>!!node&&(node.isContentEditable||/^(INPUT|TEXTAREA|SELECT)$/.test(node.tagName||'')||['textbox','searchbox'].includes(node.getAttribute?.('role'))));
}

function interactiveControl(target,path=[],activeElement=null){
 return [target,...path,activeElement].some(node=>!!node&&(/^(BUTTON|A|SUMMARY)$/.test(node.tagName||'')||['button','link','menuitem'].includes(node.getAttribute?.('role'))));
}

export function walkMapEditorKeyAction(event,{active=false,mode='top',tool='select',modal=false,textInput,activeElement=null,tracked=false}={}){
 const code=event.code,type=event.type||'keydown',down=type==='keydown',up=type==='keyup',ctrl=event.ctrlKey||event.metaKey;
 const path=eventPath(event),text=textInput??walkMapEditorTextInput(event.target,path,activeElement),interactive=interactiveControl(event.target,path,activeElement);
 if(up){
  if(!tracked){if(text||modal||!active||interactive&&(code==='Space'||code==='Enter'))return null;return EDITOR_CAPTURE_CODES.has(code)?{action:'consume',consume:true}:null;}
  if(['KeyW','KeyA','KeyS','KeyD'].includes(code))return {action:'navigate',code,pressed:false,boost:false,mode,consume:active};
  if(code==='Space')return {action:'navigate-vertical',direction:1,pressed:false,consume:active};
  if(code==='ControlLeft'||code==='ControlRight')return {action:'navigate-vertical',direction:-1,pressed:false,consume:active};
  if(code==='ShiftLeft'||code==='ShiftRight')return {action:'modifier',name:'precision-or-boost',pressed:false,consume:active};
  return active&&EDITOR_CAPTURE_CODES.has(code)?{action:'consume',consume:true}:null;
 }
 if(event.defaultPrevented||event.isComposing||event.keyCode===229)return null;
 if(!down)return null;
 if(event.repeat&&EDITOR_CAPTURE_CODES.has(code))return active||code==='KeyK'?{action:'consume',consume:true}:null;
 if(code==='KeyK'&&!text&&!modal&&!event.altKey&&!ctrl)return {action:'toggle',consume:true};
 if(!active)return null;
 if(modal)return null;
 if(text)return code==='Escape'?{action:'text-escape',consume:true}:null;
 if(interactive&&(code==='Space'||code==='Enter'))return null;
 if(ctrl&&!event.altKey&&code==='KeyS')return {action:'save',consume:true};
 if(ctrl&&!event.altKey&&code==='KeyZ')return {action:event.shiftKey?'redo':'undo',consume:true};
 if(ctrl&&!event.altKey&&code==='KeyY')return {action:'redo',consume:true};
 if(ctrl||event.altKey)return {action:'consume',consume:true};
 if(code==='Digit1'||code==='Numpad1')return {action:'mode',mode:'top',consume:true};
 if(code==='Digit2'||code==='Numpad2')return {action:'mode',mode:'fly',consume:true};
 if(code==='Escape')return {action:'cancel',consume:true};
 if(code==='Enter')return {action:'commit',consume:true};
 if(code==='Delete')return {action:'delete',consume:true};
 if(code==='Slash')return {action:'focus-search',consume:true};
 if(code==='BracketLeft')return {action:tool==='paint'?'brush-smaller':'scale-smaller',consume:true};
 if(code==='BracketRight')return {action:tool==='paint'?'brush-larger':'scale-larger',consume:true};
 if(code==='KeyQ'&&['rotate','place'].includes(tool))return {action:'rotate-step',degrees:-15,consume:true};
 if(code==='KeyE'&&['rotate','place'].includes(tool)||code==='KeyR'&&tool==='place')return {action:'rotate-step',degrees:15,consume:true};
 if(['KeyW','KeyA','KeyS','KeyD'].includes(code))return {action:'navigate',code,pressed:true,boost:event.shiftKey,mode,consume:true};
 if(code==='Space')return mode==='fly'?{action:'navigate-vertical',direction:1,pressed:true,consume:true}:{action:'consume',consume:true};
 if(code==='ControlLeft'||code==='ControlRight')return mode==='fly'?{action:'navigate-vertical',direction:-1,pressed:true,consume:true}:{action:'consume',consume:true};
 if(code==='ShiftLeft'||code==='ShiftRight')return {action:'modifier',name:'precision-or-boost',pressed:true,consume:true};
 if(EDITOR_CAPTURE_CODES.has(code))return {action:'consume',consume:true};
 return null;
}

export function walkMapEditorPointerAction(event,{active=false,tool='select',mode='top',overUi=false,gesture=null,now=performance.now()}={}){
 if(!active||overUi)return null;
 if(event.type==='contextmenu'||['mousedown','mouseup','click','dblclick','auxclick'].includes(event.type))return {action:'consume',consume:true};
 if(event.type==='wheel')return {action:mode==='fly'?'fly-speed':'zoom',delta:event.deltaY,consume:true};
 if(event.type==='pointerdown'){
  if(event.button===1)return {action:mode==='fly'?'camera-look-start':'camera-pan-start',consume:true};
  if(event.button===0)return {action:tool==='paint'?'paint-start':'primary-start',consume:true};
  if(event.button===2)return {action:tool==='paint'?'erase-start':'right-press',consume:true};
 }
 if(event.type==='pointermove')return {action:gesture?.button===2&&tool==='paint'?'erase-move':gesture?.button===1?(mode==='fly'?'camera-look-move':'camera-pan-move'):gesture?.button===0&&tool==='paint'?'paint-move':'pointer-move',consume:!!gesture};
 if(event.type==='pointerup'){
  if(event.button===1)return {action:mode==='fly'?'camera-look-end':'camera-pan-end',consume:true};
  if(event.button===0)return {action:tool==='paint'?'paint-end':'primary-end',consume:true};
  if(event.button===2){
   if(tool==='paint')return {action:'erase-end',consume:true};
   const distance=gesture?Math.hypot((event.clientX??0)-gesture.x,(event.clientY??0)-gesture.y):Infinity,duration=gesture?now-gesture.at:Infinity;
   return {action:distance<=4&&duration<=500?'delete-at-pointer':'right-cancel',consume:true};
  }
 }
 if(event.type==='pointercancel'||event.type==='lostpointercapture')return {action:'cancel-pointer',consume:true};
 return null;
}

function consume(event){event.preventDefault?.();event.stopImmediatePropagation?.();event.stopPropagation?.();}

export function createWalkMapEditorInput({target=globalThis.window,document:doc=globalThis.document,canvas,isActive=()=>false,getMode=()=> 'top',getTool=()=> 'select',isModalOpen=()=>false,isOverUi=event=>eventPath(event).some(node=>node?.id==='walk-map-editor'||node?.closest?.('#walk-map-editor')),now=()=>performance.now(),onAction=()=>{}}={}){
 if(!target?.addEventListener)throw new Error('Map editor input requires an event target');
 const listeners=[],held=new Set();let phase=isActive()?(getMode()==='fly'?'fly':'top'):'game',gesture=null;
 const owns=()=>phase!=='game';
 function listen(node,type,handler,options){node.addEventListener(type,handler,options);listeners.push(()=>node.removeEventListener(type,handler,options));}
 function emit(result,event){if(!result)return;if(result.consume)consume(event);if(result.action!=='consume'&&(!event.repeat||['navigate','navigate-vertical','modifier'].includes(result.action)))onAction(result,event);}
 function keyboard(event){
  const tracked=held.has(event.code);if(event.type==='keyup')held.delete(event.code);
  const result=walkMapEditorKeyAction(event,{active:owns(),mode:getMode(),tool:getTool(),modal:isModalOpen(),activeElement:doc?.activeElement,tracked});
  if(event.type==='keydown'&&result?.pressed===true&&HELD_CODES.has(event.code))held.add(event.code);
  if(result?.action==='toggle'&&!event.repeat)phase=owns()?'leaving':'entering';
  emit(result,event);
 }
 function sceneEvent(event){return !!canvas&&eventPath(event).includes(canvas)&&!isOverUi(event)}
 function pointer(event){
  if(!owns()||!sceneEvent(event))return;
  if(event.type==='pointerdown'){
   if(gesture&&gesture.pointerId!==event.pointerId){consume(event);return}
   gesture={pointerId:event.pointerId,button:event.button,x:event.clientX??0,y:event.clientY??0,at:now(),moved:false,tool:getTool(),mode:getMode()};try{canvas.setPointerCapture?.(event.pointerId)}catch{}
  }else if(gesture&&event.pointerId!==gesture.pointerId){consume(event);return}
  else if(event.type==='pointermove'&&gesture&&Math.hypot((event.clientX??0)-gesture.x,(event.clientY??0)-gesture.y)>4)gesture.moved=true;
  if(['pointerup','pointercancel','lostpointercapture'].includes(event.type)&&!gesture){consume(event);return}
  const result=walkMapEditorPointerAction(event,{active:true,tool:gesture?.tool??getTool(),mode:gesture?.mode??getMode(),gesture,now:now()});
  if(result?.action==='delete-at-pointer'&&gesture?.moved)result.action='right-cancel';emit(result,event);
  if(['pointerup','pointercancel','lostpointercapture'].includes(event.type)){try{canvas.releasePointerCapture?.(event.pointerId)}catch{}gesture=null}
 }
 function compatibility(event){if(owns()&&sceneEvent(event))consume(event)}
 function clear(reason){if(!held.size&&!gesture)return;const pointerId=gesture?.pointerId;held.clear();gesture=null;try{if(pointerId!==undefined)canvas?.releasePointerCapture?.(pointerId)}catch{}onAction({action:'clear-input',reason,consume:false});}
 listen(target,'keydown',keyboard,true);listen(target,'keyup',keyboard,true);
 for(const type of ['pointerdown','pointerup','pointermove','pointercancel','lostpointercapture','contextmenu','wheel'])listen(target,type,pointer,{capture:true,passive:false});
 for(const type of ['mousedown','mouseup','click','dblclick','auxclick'])listen(target,type,compatibility,{capture:true,passive:false});
 listen(target,'blur',()=>clear('blur'),true);if(doc?.addEventListener)listen(doc,'visibilitychange',()=>{if(doc.hidden)clear('hidden')},true);
 return {
  get phase(){return phase},get ownsInput(){return owns()},
  setPhase(value){if(!['game','entering','top','fly','leaving'].includes(value))throw new Error(`Unknown editor input phase: ${value}`);phase=value;if(value==='game')clear('leave')},
  clear,dispose(){clear('dispose');for(const remove of listeners.splice(0))remove();},handleKeyEvent:keyboard,handlePointerEvent:pointer
 };
}
