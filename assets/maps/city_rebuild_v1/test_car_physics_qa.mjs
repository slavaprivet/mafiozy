import assert from 'node:assert/strict';
import {initCarPhysicsQa} from './car_physics_qa.mjs';
class Element extends EventTarget{
 constructor(){super();this.style={};this.attributes={};this.children=[];this.textContent=''}
 setAttribute(name,value){this.attributes[name]=value}
 append(...children){for(const child of children){child.parent=this;this.children.push(child)}}
 remove(){if(this.parent)this.parent.children=this.parent.children.filter(child=>child!==this)}
 click(){this.dispatchEvent(new Event('click'))}
}
const document=new Element(),view=new Element(),pending=new Map();let id=0;
view.setTimeout=(callback,delay)=>{pending.set(++id,{callback,delay});return id};view.clearTimeout=timer=>pending.delete(timer);
document.defaultView=view;document.body=new Element();document.createElement=()=>new Element();
let input={},held=false,resets=0,releases=0;
const qa=initCarPhysicsQa({document,onInput:value=>input=value,onRelease:()=>{input={};releases++},onReset:()=>resets++,onEntryHold:value=>held=value});
assert.equal(document.body.children.length,1);
assert(Object.values(qa.buttons).every(button=>button.attributes['aria-label']));
qa.buttons.accelerate.click();assert.deepEqual(input,{forward:true});assert.equal([...pending.values()][0].delay,3000);
qa.buttons.handbrake.click();assert.deepEqual(input,{left:true,handbrake:true});assert.equal(pending.size,1,'new action replaces previous timer');
assert.equal([...pending.values()][0].delay,1000);
view.dispatchEvent(new Event('blur'));assert.deepEqual(input,{});assert.equal(pending.size,0);assert.equal(held,false);
qa.buttons.shortEntry.click();assert.equal(held,true);assert.equal([...pending.values()][0].delay,200);
const [[timer,task]]=pending;pending.delete(timer);task.callback();assert.equal(held,false);assert.equal(pending.size,0);
qa.buttons.entryExit.click();assert(held);assert.equal([...pending.values()][0].delay,700);
document.hidden=true;document.dispatchEvent(new Event('visibilitychange'));assert(!held);assert.equal(pending.size,0);
qa.buttons.brake.click();assert.deepEqual(input,{reverse:true});
qa.buttons.reset.click();assert.equal(resets,1);assert.deepEqual(input,{});assert.equal(pending.size,0);
qa.buttons.accelerate.click();qa.dispose();assert.deepEqual(input,{});assert.equal(pending.size,0);assert.equal(document.body.children.length,0);
const released=releases;qa.buttons.accelerate.click();view.dispatchEvent(new Event('blur'));qa.dispose();assert.equal(releases,released,'dispose removes handlers and is idempotent');
console.log('PASS car QA: real input callbacks, timed hold/release, replacing action, blur/hidden cleanup, reset and disposal');
