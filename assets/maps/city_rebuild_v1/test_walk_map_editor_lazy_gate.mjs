import assert from 'node:assert/strict';
import test from 'node:test';
import {createWalkMapEditorLazyGate,walkMapEditorLazyGateAcceptsKey} from './walk_map_editor_lazy_gate.mjs';

class FakeTarget{
 constructor(){this.listeners=new Map()}
 addEventListener(type,handler,options=false){const capture=options===true||!!options?.capture,list=this.listeners.get(type)||[];list.push({handler,capture});this.listeners.set(type,list)}
 removeEventListener(type,handler,options=false){const capture=options===true||!!options?.capture,list=this.listeners.get(type)||[];this.listeners.set(type,list.filter(listener=>listener.handler!==handler||listener.capture!==capture))}
 emit(type,init={}){const target=init.target??{tagName:'CANVAS'},path=init.path??[target,this],event={type,target,code:'',repeat:false,isComposing:false,keyCode:0,defaultPrevented:false,altKey:false,ctrlKey:false,metaKey:false,prevented:0,stopped:0,immediate:0,preventDefault(){this.defaultPrevented=true;this.prevented++},stopPropagation(){this.stopped++},stopImmediatePropagation(){this.immediate++;this.stopped++},composedPath(){return path},...init};for(const listener of [...(this.listeners.get(type)||[])]){listener.handler(event);if(event.immediate)break}return event}
 count(type){return (this.listeners.get(type)||[]).length}
}
const key=(extra={})=>({type:'keydown',code:'KeyK',target:{tagName:'CANVAS'},repeat:false,isComposing:false,keyCode:0,defaultPrevented:false,altKey:false,ctrlKey:false,metaKey:false,...extra});
const deferred=()=>{let resolve,reject;const promise=new Promise((yes,no)=>{resolve=yes;reject=no});return {promise,resolve,reject}};
const controller=()=>{const value={toggles:0,disposals:0,toggle(){value.toggles++},dispose(){value.disposals++}};return value};
const settle=async gate=>{await gate.whenSettled();await Promise.resolve()};

test('gate predicate ignores text input, IME, prevented, repeat and modified K',()=>{
 const input={tagName:'INPUT'},editable={tagName:'DIV',isContentEditable:true},role={tagName:'DIV',getAttribute:name=>name==='role'?'textbox':null};
 assert.equal(walkMapEditorLazyGateAcceptsKey(key()),true);
 for(const event of [key({target:input}),key({composedPath:()=>[role]}),key({isComposing:true}),key({keyCode:229}),key({defaultPrevented:true}),key({repeat:true}),key({ctrlKey:true}),key({metaKey:true}),key({altKey:true}),key({code:'KeyJ'}),{...key(),type:'keyup'}])assert.equal(walkMapEditorLazyGateAcceptsKey(event),false);
 assert.equal(walkMapEditorLazyGateAcceptsKey(key(),{activeElement:editable}),false);
});

test('capture K is consumed before gameplay and concurrent loading happens once',async()=>{
 const target=new FakeTarget(),wait=deferred();let loads=0,gameplay=0;
 const gate=createWalkMapEditorLazyGate({target,document:{activeElement:null},loadEditor:()=>{loads++;return wait.promise}});
 target.addEventListener('keydown',()=>gameplay++,true);
 const first=target.emit('keydown',{code:'KeyK'}),second=target.emit('keydown',{code:'KeyK'}),third=target.emit('keydown',{code:'KeyK'});
 assert.equal(loads,0);await Promise.resolve();assert.equal(loads,1);assert.equal(gameplay,0);assert.equal(gate.state,'loading');assert.equal(gate.pendingToggleParity,1);
 for(const event of [first,second,third]){assert.equal(event.defaultPrevented,true);assert.equal(event.immediate,1)}
 const installed=controller();wait.resolve(installed);await settle(gate);assert.equal(installed.toggles,1);assert.equal(gate.state,'installed');gate.dispose();
});

test('two K presses during load cancel by parity and future K belongs to editor input',async()=>{
 const target=new FakeTarget(),wait=deferred();let editorKeys=0;
 const gate=createWalkMapEditorLazyGate({target,loadEditor:()=>wait.promise,createEditor:loaded=>{target.addEventListener('keydown',event=>{if(event.code==='KeyK')editorKeys++},true);return loaded}}),installed=controller();
 target.emit('keydown',{code:'KeyK'});target.emit('keydown',{code:'KeyK'});assert.equal(gate.pendingToggleParity,0);wait.resolve(installed);await settle(gate);
 assert.equal(installed.toggles,0);assert.equal(gate.installed,true);assert.equal(target.count('keydown'),1);
 const event=target.emit('keydown',{code:'KeyK'});assert.equal(editorKeys,1);assert.equal(event.defaultPrevented,false);gate.dispose();
});

test('load failure leaves the gate installed and next K retries cleanly',async()=>{
 const target=new FakeTarget(),first=deferred(),second=deferred(),errors=[];let attempts=0;
 const gate=createWalkMapEditorLazyGate({target,loadEditor:()=>++attempts===1?first.promise:second.promise,onError:error=>errors.push(error.message)});
 target.emit('keydown',{code:'KeyK'});await Promise.resolve();first.reject(new Error('network failed'));await settle(gate);
 assert.equal(gate.state,'idle');assert.equal(gate.pendingToggleParity,0);assert.deepEqual(errors,['network failed']);assert.equal(target.count('keydown'),1);
 target.emit('keydown',{code:'KeyK'});await Promise.resolve();const installed=controller();second.resolve(installed);await settle(gate);
 assert.equal(attempts,2);assert.equal(installed.toggles,1);assert.equal(gate.state,'installed');gate.dispose();
});

test('dispose during pending load never opens and disposes the late controller',async()=>{
 const target=new FakeTarget(),wait=deferred(),gate=createWalkMapEditorLazyGate({target,loadEditor:()=>wait.promise}),late=controller();
 target.emit('keydown',{code:'KeyK'});await Promise.resolve();gate.dispose();assert.equal(gate.state,'disposed');assert.equal(target.count('keydown'),0);
 wait.resolve(late);await settle(gate);assert.equal(late.toggles,0);assert.equal(late.disposals,1);assert.equal(gate.state,'disposed');
});

test('invalid or asynchronous controller toggle fails closed and remains retryable',async()=>{
 const target=new FakeTarget(),errors=[];let attempt=0;
 const asyncController={disposals:0,toggle(){return Promise.resolve()},dispose(){this.disposals++}};
 const gate=createWalkMapEditorLazyGate({target,loadEditor:()=>++attempt===1?asyncController:controller(),onError:error=>errors.push(error.message)});
 target.emit('keydown',{code:'KeyK'});await settle(gate);assert.equal(gate.state,'idle');assert.equal(asyncController.disposals,1);assert.match(errors[0],/synchronous/);assert.equal(target.count('keydown'),1);
 target.emit('keydown',{code:'KeyK'});await settle(gate);assert.equal(gate.state,'installed');gate.dispose();gate.dispose();
});

test('dispose after installation owns the controller exactly once',async()=>{
 const target=new FakeTarget(),installed=controller(),gate=createWalkMapEditorLazyGate({target,loadEditor:()=>installed});target.emit('keydown',{code:'KeyK'});await settle(gate);gate.dispose();gate.dispose();assert.equal(installed.toggles,1);assert.equal(installed.disposals,1);
});
