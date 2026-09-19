import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const source=readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
function setup(){
 const listeners=new Map(),canvasListeners=new Map();let blocked=false,releases=0,locks=0;
 const document={addEventListener(type,fn,capture){assert.equal(capture,true);listeners.set(type,fn);}};
 const canvas={addEventListener(type,fn){canvasListeners.set(type,fn);},requestPointerLock(){locks++;}};
 const state={document,renderer:{domElement:canvas},hudInputBlocked:()=>blocked,releaseControls(){releases++;state.triggerHeld=false;state.triggerPressed=false;},currentWeapon:{id:'pistol'},combatAllowed:()=>true,artistAllowed:()=>true,heroPosture:{value:0},artistInput:{press(){state.punches++;},block(){}},artistMeleeContext:()=>({}),setFreeMouse(){},triggerHeld:false,triggerPressed:false,punches:0};
 vm.createContext(state);
 vm.runInContext(source.slice(source.indexOf('let walkUiPointerGesture=false;'),source.indexOf("renderer.domElement.addEventListener('contextmenu'")),state);
 const down=source.split('\n').find(s=>s.startsWith("renderer.domElement.addEventListener('mousedown',e=>{if(e.defaultPrevented"));
 const click=source.split('\n').find(s=>s.startsWith("renderer.domElement.addEventListener('click',e=>"));
 assert(down&&click);vm.runInContext(down+'\n'+click,state);
 const emit=(type,path=[canvas],extra={})=>{const e={type,target:path.at(-1),composedPath:()=>path,button:0,preventDefault(){this.defaultPrevented=true;},...extra};listeners.get(type)?.(e);if(path.includes(canvas))canvasListeners.get(type)?.(e);return e;};
 return{state,emit,canvas,block:value=>blocked=value,get releases(){return releases;},get locks(){return locks;}};
}
test('Hire press in shadow DOM stays consumed after dialog closes before mouse/click',()=>{
 const f=setup(),button={tagName:'BUTTON'},shadowHost={tagName:'DIV'},dialog={dataset:{walkHud:'recruit-dialog'}};
 f.emit('pointerdown',[button,dialog,shadowHost]);f.emit('mousedown');f.emit('click');
 assert.equal(f.state.triggerPressed,false);assert.equal(f.state.triggerHeld,false);assert.equal(f.locks,0);assert(f.releases>0);
 f.emit('pointerdown');f.emit('mousedown');assert.equal(f.state.triggerPressed,true,'next intentional scene press shoots normally');f.emit('click');assert.equal(f.locks,1);
});
test('all interactive controls and modal presses suppress firing, including disabled or nested labels',()=>{
 for(const node of [{tagName:'BUTTON',disabled:true},{tagName:'SELECT'},{tagName:'LABEL'},{tagName:'A'},{isContentEditable:true},{getAttribute:key=>key==='role'?'dialog':null},{dataset:{walkHud:'any-panel'}}]){
  const f=setup();f.state.triggerHeld=true;f.emit('pointerdown',[{tagName:'SPAN'},node]);f.emit('mousedown');assert.equal(f.state.triggerHeld,false);assert.equal(f.state.triggerPressed,false);
 }
});
test('blocked scene press remains consumed after modal close and does not punch either',()=>{
 const f=setup();f.block(true);f.emit('pointerdown');f.block(false);f.state.currentWeapon.id='none';f.emit('mousedown');f.emit('click');assert.equal(f.state.punches,0);assert.equal(f.locks,0);
 f.emit('pointerdown');f.emit('mousedown');assert.equal(f.state.punches,1);
});
test('mouse RMB+LMB chord retains normal aiming and firing for scene gestures',()=>{
 const f=setup();f.emit('pointerdown',undefined,{button:2});f.emit('mousedown',undefined,{button:2});f.emit('mousedown');assert.equal(f.state.aiming,true);assert.equal(f.state.triggerHeld,true);
});
