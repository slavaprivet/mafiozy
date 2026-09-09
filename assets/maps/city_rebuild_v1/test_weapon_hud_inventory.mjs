import assert from 'node:assert/strict';
import {ARSENAL} from './hero_arsenal.mjs';
import {createWeaponHud,weaponHudOwnedIds,WEAPON_HUD_CSS} from './weapon_hud.mjs';

class Element{
 constructor(tag,doc){this.tagName=tag.toUpperCase();this.doc=doc;this.children=[];this.dataset={};this.attributes={};this.listeners={};this.classList={add(){},remove(){}};this.hidden=false;this.disabled=false;this.textContent=''}
 append(...elements){for(const element of elements){element.parent=this;this.children.push(element)}}
 replaceChildren(...elements){this.children=[];this.append(...elements)}
 setAttribute(name,value){this.attributes[name]=String(value)}
 getAttribute(name){return this.attributes[name]}
 addEventListener(name,callback){this.listeners[name]=callback}
 removeEventListener(name,callback){if(this.listeners[name]===callback)delete this.listeners[name]}
 focus(){this.doc.activeElement=this}
 remove(){if(this.parent)this.parent.children=this.parent.children.filter(child=>child!==this)}
 click(){this.listeners.click?.({target:this})}
}
function fixture(){
 const queue=new Map();let next=0;const doc={createElement(tag){return new Element(tag,this)},getElementById(id){return this.head.children.find(child=>child.id===id)},addEventListener(){},removeEventListener(){},defaultView:{requestAnimationFrame(callback){const id=++next;queue.set(id,callback);return id},cancelAnimationFrame(id){queue.delete(id)}}};
 doc.head=doc.createElement('head');doc.body=doc.createElement('body');const host=doc.createElement('div');doc.body.append(host);
 return {doc,host,queue,flush(){while(queue.size){const [id,callback]=queue.entries().next().value;queue.delete(id);callback()}}};
}
assert.deepEqual(weaponHudOwnedIds(ARSENAL,[]),['none']);
assert.deepEqual(weaponHudOwnedIds(ARSENAL,['ak74','ak74','invented']),['none','ak74']);
assert.equal(weaponHudOwnedIds(ARSENAL).length,ARSENAL.length);
const {doc,host,queue,flush}=fixture(),selected=[],rendered=[];let disposed=false;
const hud=createWeaponHud({document:doc,host,arsenal:ARSENAL,onSelect:id=>selected.push(id),thumbnailRenderer:{render(id){rendered.push(id);return 'data:image/png;base64,'+id},dispose(){disposed=true}}});
const choices=()=>hud.grid.children.filter(child=>child.className==='mfz-weapon-choice'),choice=id=>choices().find(child=>child.dataset.weapon===id),visible=()=>choices().filter(child=>!child.hidden).map(child=>child.dataset.weapon);
hud.setState({weaponId:'ak74',magazine:17,reserveAmmo:45,ownedWeaponIds:['ak74','tt_pistol'],ammoByWeaponId:{ak74:{magazine:17,reserveAmmo:45}}});
assert.deepEqual(visible(),['none','tt_pistol','ak74']);
hud.setOpen(true);flush();assert.deepEqual(rendered.sort(),['ak74','none','tt_pistol']);assert.equal(doc.activeElement,choice('ak74'));assert.equal(choice('none').children[0].children[0].tagName,'IMG','unarmed card must display the 3D fist thumbnail');
assert.equal(choice('ak74').children[2].textContent,'В РУКАХ · 17 / 45');
assert.equal(choice('ak74').children[0].children[0].tagName,'IMG','cards must display generated model photograph');
choice('tt_pistol').click();assert.deepEqual(selected,['tt_pistol']);choice('m16').click();assert.equal(selected.length,1,'hidden non-owned choices cannot dispatch equip even by scripted click');
hud.setState({weaponId:'ak74',ownedWeaponIds:['tt_pistol']});assert.equal(host.dataset.weapon,'none','stale equipped dropped id must not remain presented');assert(choice('ak74').hidden&&choice('ak74').disabled);choice('ak74').click();assert.equal(selected.length,1);
hud.setState({weaponId:'tt_pistol',magazine:2,reserveAmmo:3});assert.deepEqual(visible(),['none','tt_pistol'],'omitted ownership retains inventory');
hud.setState({weaponId:'sniper',ownedWeaponIds:['sniper']});assert(hud.setScopeVisible(true));hud.setState({weaponId:'sniper',ownedWeaponIds:[]});assert.equal(hud.scope.dataset.visible,'false');assert.deepEqual(visible(),['none']);
hud.setState({weaponId:'none',disabled:true});assert.equal(hud.isOpen(),false);assert.equal(hud.setOpen(true),false);choice('none').click();assert.equal(selected.length,1);
hud.setState({weaponId:'none',disabled:false,ownedWeaponIds:['tt_pistol']});let prevented=0;const key={code:'KeyQ',preventDefault(){prevented++}};
assert.equal(hud.handleKeydown({...key,target:{tagName:'INPUT'}}),false);assert.equal(hud.handleKeydown({...key,repeat:true}),false);assert(hud.handleKeydown(key));assert.equal(prevented,1);assert(hud.isOpen());assert(hud.handleKeydown(key));assert.equal(hud.isOpen(),false);
hud.setState({weaponId:'tt_pistol',ownedWeaponIds:['tt_pistol']});hud.setOpen(true);flush();assert.equal(rendered.filter(id=>id==='tt_pistol').length,1,'cached thumbnail renders only once');
hud.dispose();assert(disposed);assert.equal(queue.size,0);assert.equal(host.children.length,0);assert.equal(hud.handleKeydown(key),false);
assert(WEAPON_HUD_CSS.includes('[hidden]{display:none!important}'),'hidden attribute must override display:grid');
console.log(JSON.stringify({passed:true,checks:['owned_only','stale_equipped_drop','hidden_click_guard','ownership_retention','empty_inventory','scope_drop','disabled_gate','single_Q','text_input_guard','actual_model_images','thumbnail_cache','dispose','hidden_css']}));
