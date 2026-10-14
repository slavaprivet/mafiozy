import assert from 'node:assert/strict';
import {createWalkMapEditorInput,walkMapEditorKeyAction,walkMapEditorPointerAction} from './walk_map_editor_input.mjs';

const key=(code,extra={})=>({type:'keydown',code,target:{tagName:'CANVAS'},ctrlKey:false,metaKey:false,shiftKey:false,altKey:false,...extra});
assert.deepEqual(walkMapEditorKeyAction(key('KeyK'),{active:false}),{action:'toggle',consume:true});
assert.equal(walkMapEditorKeyAction(key('KeyK',{target:{tagName:'INPUT'}}),{active:true}),null);
assert.deepEqual(walkMapEditorKeyAction(key('Digit1'),{active:true}),{action:'mode',mode:'top',consume:true});
assert.deepEqual(walkMapEditorKeyAction(key('Digit2'),{active:true}),{action:'mode',mode:'fly',consume:true});
assert.deepEqual(walkMapEditorKeyAction(key('KeyZ',{ctrlKey:true}),{active:true}),{action:'undo',consume:true});
assert.deepEqual(walkMapEditorKeyAction(key('KeyZ',{ctrlKey:true,shiftKey:true}),{active:true}),{action:'redo',consume:true});
assert.deepEqual(walkMapEditorKeyAction(key('KeyQ'),{active:true,tool:'rotate'}),{action:'rotate-step',degrees:-15,consume:true});
assert.deepEqual(walkMapEditorKeyAction(key('KeyE'),{active:true,tool:'rotate'}),{action:'rotate-step',degrees:15,consume:true});
assert.deepEqual(walkMapEditorKeyAction({...key('KeyK'),type:'keyup'},{active:true}),{action:'consume',consume:true});
assert.deepEqual(walkMapEditorKeyAction(key('KeyK',{repeat:true}),{active:true}),{action:'consume',consume:true});
assert.deepEqual(walkMapEditorKeyAction({...key('KeyW'),type:'keyup',isComposing:true},{active:true,tracked:true}),{action:'navigate',code:'KeyW',pressed:false,boost:false,mode:'top',consume:true});
assert.equal(walkMapEditorKeyAction({...key('Space'),type:'keyup',target:{tagName:'BUTTON'}},{active:true,mode:'fly',modal:true,tracked:false}),null);
assert.deepEqual(walkMapEditorKeyAction(key('Delete',{ctrlKey:true}),{active:true}),{action:'consume',consume:true});
assert.deepEqual(walkMapEditorKeyAction(key('KeyQ',{ctrlKey:true}),{active:true,tool:'rotate'}),{action:'consume',consume:true});
assert.equal(walkMapEditorKeyAction(key('Space',{target:{tagName:'BUTTON'}}),{active:true}),null);
assert.equal(walkMapEditorKeyAction(key('Enter',{target:{tagName:'A'}}),{active:true}),null);
assert.deepEqual(walkMapEditorKeyAction(key('BracketRight'),{active:true,tool:'paint'}),{action:'brush-larger',consume:true});
assert.deepEqual(walkMapEditorKeyAction({...key('Space'),type:'keyup'},{active:true,mode:'fly',tracked:true}),{action:'navigate-vertical',direction:1,pressed:false,consume:true});
assert.deepEqual(walkMapEditorKeyAction({...key('Space'),type:'keyup'},{active:true,mode:'top',tracked:true}),{action:'navigate-vertical',direction:1,pressed:false,consume:true});
assert.deepEqual(walkMapEditorKeyAction({...key('ControlLeft'),type:'keyup'},{active:true,mode:'top',tracked:true}),{action:'navigate-vertical',direction:-1,pressed:false,consume:true});
assert.equal(walkMapEditorKeyAction(key('KeyW'),{active:false}),null);

assert.deepEqual(walkMapEditorPointerAction({type:'contextmenu'},{active:true,tool:'select'}),{action:'consume',consume:true});
assert.deepEqual(walkMapEditorPointerAction({type:'contextmenu'},{active:true,tool:'paint'}),{action:'consume',consume:true});
assert.deepEqual(walkMapEditorPointerAction({type:'pointerdown',button:1},{active:true}),{action:'camera-pan-start',consume:true});
assert.deepEqual(walkMapEditorPointerAction({type:'pointerup',button:2,clientX:2,clientY:2},{active:true,tool:'select',gesture:{button:2,x:0,y:0,at:100},now:200}),{action:'delete-at-pointer',consume:true});
assert.deepEqual(walkMapEditorPointerAction({type:'pointerup',button:2,clientX:20,clientY:2},{active:true,tool:'select',gesture:{button:2,x:0,y:0,at:100},now:200}),{action:'right-cancel',consume:true});
assert.equal(walkMapEditorPointerAction({type:'contextmenu'},{active:true,overUi:true}),null);

class FakeTarget{
 constructor(name='target'){this.name=name;this.listeners=new Map()}
 addEventListener(type,handler,options=false){
  const capture=options===true||!!options?.capture,list=this.listeners.get(type)||[];
  list.push({handler,capture,options});this.listeners.set(type,list);
 }
 removeEventListener(type,handler,options=false){
  const capture=options===true||!!options?.capture,list=this.listeners.get(type)||[];
  this.listeners.set(type,list.filter(listener=>listener.handler!==handler||listener.capture!==capture));
 }
 emit(type,init={}){
  const target=init.target??this,path=init.path??[target],event={
   type,target,code:'',button:0,pointerId:1,clientX:0,clientY:0,deltaY:0,
   repeat:false,ctrlKey:false,metaKey:false,shiftKey:false,altKey:false,
   isComposing:false,keyCode:0,defaultPrevented:!!init.defaultPrevented,
   propagationStopped:false,immediateStopped:false,
   preventDefault(){this.defaultPrevented=true},
   stopPropagation(){this.propagationStopped=true},
   stopImmediatePropagation(){this.immediateStopped=true;this.propagationStopped=true},
   composedPath(){return path}
  };
  Object.assign(event,init);event.target=target;event.composedPath=()=>path;
  for(const {handler} of [...(this.listeners.get(type)||[])]){handler(event);if(event.immediateStopped)break}
  return event;
 }
 count(type){return (this.listeners.get(type)||[]).length}
}

const domNode=(tagName='DIV',{id='',role=null,parent=null}={})=>({
 tagName,id,parent,isContentEditable:false,
 getAttribute(name){return name==='role'?role:null},
 closest(selector){for(let node=this;node;node=node.parent)if(selector==='#walk-map-editor'&&node.id==='walk-map-editor')return node;return null}
});

const fakeWindow=new FakeTarget('window'),fakeDocument=new FakeTarget('document');
fakeDocument.hidden=false;fakeDocument.activeElement=null;
const canvas=domNode('CANVAS');canvas.captures=new Set();
canvas.setPointerCapture=id=>canvas.captures.add(id);
canvas.releasePointerCapture=id=>canvas.captures.delete(id);
let mode='top',tool='select',modal=false,clock=100;const actions=[];
const input=createWalkMapEditorInput({
 target:fakeWindow,document:fakeDocument,canvas,getMode:()=>mode,getTool:()=>tool,
 isModalOpen:()=>modal,now:()=>clock,onAction:action=>actions.push(action)
});
const sceneEvent=(type,extra={})=>fakeWindow.emit(type,{target:canvas,path:[canvas,fakeWindow],...extra});
const take=()=>actions.splice(0);

assert.equal(input.phase,'game');assert.equal(input.ownsInput,false);
let event=fakeWindow.emit('keydown',{code:'KeyK'});
assert.equal(input.phase,'entering');assert.equal(input.ownsInput,true);
assert.equal(event.defaultPrevented,true);assert.equal(event.immediateStopped,true);
assert.deepEqual(take(),[{action:'toggle',consume:true}]);
event=fakeWindow.emit('keydown',{code:'KeyK',repeat:true});
assert.equal(input.phase,'entering');assert.equal(event.defaultPrevented,true);assert.deepEqual(take(),[]);
input.setPhase('fly');mode='fly';

event=fakeWindow.emit('keydown',{code:'KeyW'});assert.equal(event.defaultPrevented,true);
assert.deepEqual(take(),[{action:'navigate',code:'KeyW',pressed:true,boost:false,mode:'fly',consume:true}]);
event=fakeWindow.emit('keyup',{code:'KeyW',isComposing:true,defaultPrevented:true});
assert.equal(event.immediateStopped,true);
assert.deepEqual(take(),[{action:'navigate',code:'KeyW',pressed:false,boost:false,mode:'fly',consume:true}]);

fakeWindow.emit('keydown',{code:'Space'});take();mode='top';
fakeWindow.emit('keyup',{code:'Space'});
assert.deepEqual(take(),[{action:'navigate-vertical',direction:1,pressed:false,consume:true}]);

mode='fly';fakeWindow.emit('keydown',{code:'ControlLeft'});take();
input.setPhase('leaving');assert.equal(input.ownsInput,true);
input.setPhase('game');assert.equal(input.ownsInput,false);
assert.deepEqual(take(),[{action:'clear-input',reason:'leave',consume:false}]);
event=sceneEvent('pointerdown',{button:0,pointerId:2});assert.equal(event.defaultPrevented,false);

input.setPhase('top');mode='top';tool='select';clock=100;
event=sceneEvent('pointerdown',{button:2,pointerId:7,clientX:0,clientY:0});
assert.equal(event.defaultPrevented,true);assert.equal(canvas.captures.has(7),true);
assert.deepEqual(take(),[{action:'right-press',consume:true}]);
clock=150;sceneEvent('pointermove',{pointerId:7,clientX:10,clientY:0});take();
clock=200;sceneEvent('pointermove',{pointerId:7,clientX:0,clientY:0});take();
clock=250;sceneEvent('pointerup',{button:2,pointerId:7,clientX:0,clientY:0});
assert.equal(canvas.captures.has(7),false);
assert.deepEqual(take(),[{action:'right-cancel',consume:true}]);

sceneEvent('pointerdown',{button:1,pointerId:8});take();
event=sceneEvent('pointerup',{button:1,pointerId:9});assert.equal(event.defaultPrevented,true);
assert.equal(canvas.captures.has(8),true);assert.deepEqual(take(),[]);
sceneEvent('pointerup',{button:1,pointerId:8});assert.equal(canvas.captures.has(8),false);take();

tool='paint';mode='top';sceneEvent('pointerdown',{button:0,pointerId:10});take();
tool='select';mode='fly';sceneEvent('pointermove',{pointerId:10,clientX:3});
assert.deepEqual(take(),[{action:'paint-move',consume:true}]);
sceneEvent('pointerup',{button:0,pointerId:10});
assert.deepEqual(take(),[{action:'paint-end',consume:true}]);

sceneEvent('pointerdown',{button:1,pointerId:11});take();
fakeWindow.emit('blur');assert.equal(canvas.captures.has(11),false);
assert.deepEqual(take(),[{action:'clear-input',reason:'blur',consume:false}]);

sceneEvent('pointerdown',{button:0,pointerId:12});take();fakeDocument.hidden=true;
fakeDocument.emit('visibilitychange');assert.equal(canvas.captures.has(12),false);
assert.deepEqual(take(),[{action:'clear-input',reason:'hidden',consume:false}]);
fakeDocument.hidden=false;

assert.equal(fakeWindow.count('keydown'),1);
input.dispose();assert.equal(fakeWindow.count('keydown'),0);assert.equal(fakeWindow.count('pointerdown'),0);
const actionCount=actions.length;fakeWindow.emit('keydown',{code:'KeyK'});assert.equal(actions.length,actionCount);

const accessibilityWindow=new FakeTarget('window'),accessibilityDocument=new FakeTarget('document');
accessibilityDocument.hidden=false;
const accessibilityCanvas=domNode('CANVAS'),editorRoot=domNode('SECTION',{id:'walk-map-editor'});
const editorButton=domNode('BUTTON',{parent:editorRoot}),buttonLabel=domNode('SPAN',{parent:editorButton}),accessibilityActions=[];
const accessibilityInput=createWalkMapEditorInput({
 target:accessibilityWindow,document:accessibilityDocument,canvas:accessibilityCanvas,
 isActive:()=>true,onAction:action=>accessibilityActions.push(action)
});
accessibilityInput.setPhase('top');accessibilityDocument.activeElement=editorButton;
for(const code of ['Space','Enter']){
 const down=accessibilityWindow.emit('keydown',{code,target:buttonLabel,path:[buttonLabel,editorButton,editorRoot,accessibilityWindow]});
 assert.equal(down.defaultPrevented,false,`${code} must preserve native button activation`);
 assert.equal(down.immediateStopped,false);assert.deepEqual(accessibilityActions,[]);
 const up=accessibilityWindow.emit('keyup',{code,target:buttonLabel,path:[buttonLabel,editorButton,editorRoot,accessibilityWindow]});
 assert.equal(up.defaultPrevented,false,`${code} keyup must preserve native button activation`);
 assert.equal(up.immediateStopped,false);assert.deepEqual(accessibilityActions,[]);
}
accessibilityDocument.activeElement=null;
const enter=accessibilityWindow.emit('keydown',{code:'Enter',target:accessibilityCanvas,path:[accessibilityCanvas,accessibilityWindow]});
assert.equal(enter.defaultPrevented,true);assert.deepEqual(accessibilityActions.splice(0),[{action:'commit',consume:true}]);
accessibilityInput.dispose();

console.log('walk map editor input: PASS');
