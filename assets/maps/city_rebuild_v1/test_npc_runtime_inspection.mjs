import assert from 'node:assert/strict';
import {createNpcRuntimeInspection,isInspectionCivilian} from './npc_runtime_inspection.mjs';
for(const role of ['worker','pensioner','student','housewife','businessman','drunk','homeless'])assert(isInspectionCivilian({id:'native_'+role,role,source:{}}));
assert(isInspectionCivilian({id:'npc_resident_71',role:'unknown',source:{}}));
assert(isInspectionCivilian({id:'native_72',role:'other',source:{_arcKey:'worker'}}));
for(const source of [{empireBoss:true,_arcKey:'businessman'},{_specialistId:'said',_arcKey:'businessman'},{_arcKey:'bandit'},{police:true,_arcKey:'worker'}])assert(!isInspectionCivilian({id:'npc_resident_7',role:'worker',source}));
assert(!isInspectionCivilian({id:'npc_resident_8',role:'gang_fighter',source:{_arcKey:'worker'}}));
class Element{
 constructor(){this.children=[];this.style={};this.handlers={};this.hidden=false;this.value=''}
 setAttribute(k,v){this[k]=v}append(...nodes){for(const n of nodes){this.children.push(n);n.parent=this}}replaceChildren(){this.children=[]}addEventListener(k,f){this.handlers[k]=f}remove(){this.parent.children=this.parent.children.filter(n=>n!==this)}click(){this.handlers.click?.()}change(value){this.value=value;this.handlers.change?.()}
}
const doc={body:new Element(),createElement:()=>new Element()};let calls=0,actors=[];
const off=createNpcRuntimeInspection({document:doc,getActors(){throw Error('Off mode accessed runtime')}});assert.equal(off.enabled,false);assert.equal(doc.body.children.length,0);
actors=Array.from({length:55},(_,i)=>({id:'real_'+i,role:i===1?'police':'civilian',object:{position:{x:i,z:0}},source:Object.freeze({routinePlan:Object.freeze({phase:'walk_to_shop'})})}));
const ui=createNpcRuntimeInspection({document:doc,search:'?npcqa=1',getActors:()=>actors,getFocus:()=>({x:0,z:0}),focusActor:row=>{calls++;assert(actors.includes(row))}});
const [toggle,body]=ui.panel.children,[select,civil,police,follow,status]=body.children;
assert.equal(select.children.length,51);assert.equal(calls,0);civil.click();assert.equal(ui.getSelection().id,'real_0');police.click();assert.equal(ui.getSelection().id,'real_1');assert.equal(calls,2);
select.change('real_2');ui.update(1);actors[2].object.position.x+=2;ui.update(2);assert.match(status.textContent,/2.00 м\/с/);assert.match(status.textContent,/walk_to_shop/);
assert(ui.isFollowing());follow.click();assert(!ui.isFollowing());follow.click();assert(ui.isFollowing());const previous=calls;ui.update(2.1);assert(calls>previous);
toggle.click();assert(body.hidden);toggle.click();assert(!body.hidden);
actors=[];ui.update(3);assert.equal(ui.getSelection(),null);assert(civil.disabled&&police.disabled);
ui.dispose();ui.dispose();assert.equal(doc.body.children.length,0);
console.log('PASS: off by default; only existing nearest50 IDs; civilian/police camera selection; measured speed; read-only source; collapse/follow/dispose');
