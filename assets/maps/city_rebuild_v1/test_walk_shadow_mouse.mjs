import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';
import assert from 'node:assert/strict';
const source=readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
const helper=source.match(/^function sceneHasPointerLock\(\).*$/m)?.[0];
const mouse=source.match(/^document\.addEventListener\('mousemove'.*$/m)?.[0];
const lock=source.match(/^document\.addEventListener\('pointerlockchange'.*$/m)?.[0];
assert.ok(helper&&mouse&&lock);
const listeners={},turns=[],host={},root={pointerLockElement:null};
const canvas={getRootNode:()=>root,getBoundingClientRect:()=>({left:0,right:800})};
const context={renderer:{domElement:canvas},document:{pointerLockElement:null,addEventListener:(name,fn)=>listeners[name]=fn},
 freeMouseLook:true,edgeTurn:0,orbitActive:false,followCarCamera:false,blocked:false,
 hudInputBlocked:()=>context.blocked,turnCamera:(x,y)=>turns.push([x,y]),
 setFreeMouse:value=>{context.freeMouseLook=value},releaseControls:()=>{},THREE:{MathUtils:{clamp:(x,a,b)=>Math.max(a,Math.min(b,x))}}};
runInNewContext(helper+'\n'+mouse+'\n'+lock,context);
const event={target:host,composedPath:()=>[canvas,root,host],movementX:10,movementY:5,clientX:400};
listeners.mousemove(event); assert.deepEqual(turns.pop(),[.04,.015],'shadow canvas must rotate without pointer lock');
listeners.mousemove({...event,composedPath:()=>[{},host]});assert.equal(turns.length,0,'HUD must not rotate camera');
context.blocked=true;listeners.mousemove(event);assert.equal(turns.length,0,'modal keeps input lock');context.blocked=false;
context.document.pointerLockElement=host;root.pointerLockElement=canvas;listeners.pointerlockchange();
assert.equal(context.freeMouseLook,true,'shadow pointer lock must remain enabled');
listeners.mousemove({...event,composedPath:()=>[host]});assert.deepEqual(turns.pop(),[.04,.015]);
context.document.pointerLockElement=null;root.pointerLockElement=null;listeners.pointerlockchange();assert.equal(context.freeMouseLook,false);
context.freeMouseLook=true;listeners.mousemove({...event,target:canvas,composedPath:undefined});assert.deepEqual(turns.pop(),[.04,.015],'standalone still works');
console.log('PASS: integrated free mouse, HUD exclusion, modal, shadow lock/unlock, standalone');
