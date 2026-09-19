import assert from 'node:assert/strict';
import {createWalkPlayerHud} from './walk_player_hud.mjs';

// Count DOM calls, not elapsed time: this is a light deterministic regression
// test and does not stand in for populated-scene frame-time measurements.
let writes={};
const count=kind=>{writes[kind]=(writes[kind]||0)+1;};
class Element {
 constructor(tag,doc){
  this.tagName=tag.toUpperCase();this.doc=doc;this.children=[];this.attributes={};this.listeners={};this.classList={add(){},remove(){}};
  this.dataset=new Proxy({}, {set:(o,k,v)=>{count('dataset');o[k]=v;return true;}});
  this.style=new Proxy({}, {set:(o,k,v)=>{count('style');o[k]=v;return true;}});
  for(const [key,initial]of Object.entries({textContent:'',title:'',hidden:false,disabled:false})){
   let value=initial;Object.defineProperty(this,key,{get:()=>value,set:next=>{count(key);value=next;}});
  }
 }
 append(...nodes){for(const node of nodes){node.remove();node.parentNode=this;this.children.push(node);count('insert');}}
 insertBefore(node,reference){node.remove();const index=this.children.indexOf(reference);node.parentNode=this;this.children.splice(index<0?this.children.length:index,0,node);count('insert');}
 replaceChildren(...nodes){for(const child of this.children)child.parentNode=null;this.children=[];count('replace');this.append(...nodes);}
 setAttribute(name,value){count('attribute');this.attributes[name]=String(value);}
 getAttribute(name){return this.attributes[name]??null;}
 removeAttribute(name){count('removeAttribute');delete this.attributes[name];}
 addEventListener(name,callback){this.listeners[name]=callback;}
 remove(){if(this.parentNode){this.parentNode.children=this.parentNode.children.filter(child=>child!==this);this.parentNode=null;count('remove');}}
 click(){this.listeners.click?.({target:this});}
}
const doc={addEventListener(){},removeEventListener(){},querySelectorAll(){return [];},createElement(tag){return new Element(tag,this);},createElementNS(ns,tag){return this.createElement(tag);}};
doc.head=doc.createElement('head');const host=doc.createElement('aside'),actions=[];
const hud=createWalkPlayerHud({document:doc,host,onAction:(action,payload)=>actions.push({action,payload})});
const nodes=(node=host)=>[node,...node.children.flatMap(child=>nodes(child))];
const find=cls=>nodes().find(node=>node.className===cls);
const state={available:true,player:{name:'Елена',level:7,hp:73,maxHp:120,money:'123456789012345678901234567890',timeLabel:'12:40',mode:'PvE'},gang:{name:'Семья',role:'leader',countLabel:'1/3 ИГРОКА · 1/4 NPC',members:[{id:7,kind:'player',name:'Игрок',role:'leader',hp:80,maxHp:100},{id:7,kind:'npc',name:'Боец',role:'gang_fighter',hp:80,maxHp:100}]},status:{label:'Босс',detail:'Влияние района'},empires:{count:19,bosses:Array.from({length:19},(_,i)=>({id:i,name:'Босс '+i}))},actions:Object.fromEntries(['menu','newspaper','profile','inventory','missions','mode','empires','gang','status','boss'].map(id=>[id,true]))};
hud.setState(state);hud.setRosterPortrait('member:npc:7','blob:npc7');
const originalCards=nodes().filter(n=>n.className==='mfz-dossier-person');
const samples=[];
for(const collapsed of [true,false]){
 if(!collapsed)find('mfz-dossier-launcher').click();
 hud.setState(state);writes={};hud.setState(structuredClone(state));
 samples.push({collapsed,total:Object.values(writes).reduce((a,b)=>a+b,0),writes:{...writes}});
 assert.deepEqual(nodes().filter(n=>n.className==='mfz-dossier-person'),originalCards,'identical roster retains exact DOM nodes');
}
console.log(JSON.stringify({kind:'deterministic-dom-operations',samples}));
if(!process.argv.includes('--report'))for(const sample of samples)assert.equal(sample.total,0,'unchanged HUD snapshots must not write DOM');

// Changed values remain immediate, even when the left panel is collapsed.
find('mfz-dossier-toggle').click();
const changed=structuredClone(state);changed.player.hp=0;changed.player.money=0;changed.player.name='Новое имя';changed.actions.inventory=false;changed.gang.members[1].hp=31;
hud.setState(changed);
assert.equal(find('mfz-dossier-name').textContent,'Новое имя');
assert.equal(find('mfz-dossier-money').textContent,'0 $');
assert.equal(find('mfz-dossier-health').getAttribute('aria-valuenow'),'0');
assert.equal(nodes().find(n=>n.dataset.action==='inventory').disabled,true);
const npc=nodes().find(n=>n.dataset.memberKey==='member:npc:7');assert.match(npc.title,/31 \/ 100/);assert.equal(npc.children[0].children[0].src,'blob:npc7');npc.click();assert.deepEqual(actions.at(-1),{action:'gang',payload:{id:7}});
changed.player.hp=15;hud.setState(changed);assert.equal(find('mfz-dossier-health').getAttribute('aria-valuenow'),'15','mutating the same snapshot object still refreshes');
find('mfz-dossier-name').textContent='external edit';nodes().find(n=>n.dataset.action==='inventory').disabled=false;
hud.setState(changed);assert.equal(find('mfz-dossier-name').textContent,'Новое имя');assert.equal(nodes().find(n=>n.dataset.action==='inventory').disabled,true,'current DOM is repaired without trusting a stale snapshot cache');
hud.setState({available:false});assert.equal(find('mfz-dossier-health').getAttribute('aria-valuenow'),null);
writes={};hud.setState({available:false});assert.equal(Object.values(writes).reduce((a,b)=>a+b,0),0,'unknown HUD is also mutation-free on repeated refreshes');
hud.setState(state);assert.equal(nodes().find(n=>n.dataset.memberKey==='member:npc:7').children[0].children[0].src,'blob:npc7');
hud.dispose();
