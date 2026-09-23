import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {createVehicleEntryHoldClock} from './vehicle_entry_hold_clock.mjs';
import {HOLD_SECONDS,EXIT_HOLD_SECONDS} from './car_entry.mjs';

const read=n=>readFileSync(new URL(n,import.meta.url),'utf8');
const walk=read('./walk_preview.mjs'),merc=read('./mercenary_walk.mjs');
const priority=walk.slice(walk.indexOf('function hasPriorityInteraction('),walk.indexOf('function nearestInteraction('));
const capture=merc.slice(merc.indexOf(' function keydown(e){'),merc.indexOf(" document.addEventListener('keydown',keydown,true);"));
const mainE=walk.slice(walk.indexOf(" if(e.code==='KeyE'){",walk.indexOf('const keys=new Set()')),walk.indexOf(" if(e.code==='Space'){e.preventDefault();if(sourceVehicleActive())"));
function setup(){
 const calls=[],s={occupiedSeat:null,sourceActive:false,transition:null,verticalNavigation:{active:false,cancel:()=>calls.push('ladder-cancel')},
  npcHoldUp:null,window:{},ground:null,current:null,stale:null,blocked:false,buildingKeyConsumed:false,entryHeld:0,pointerHeld:false,jump:null,busy:false,keys:new Set(),
  sourceVehicleActive:()=>s.sourceActive,nearbyGroundWeapon:()=>s.ground,
  nearestInteraction:({fresh=false}={})=>{calls.push(fresh?'fresh':'cached');return fresh?s.current:s.stale;},
  isBlocked:()=>s.blocked,isCommandBlocked:()=>false,ui:{isOpen:false,showNotice:()=>{}},dialogue:{isOpen:false,openMember:()=>{calls.push('dialogue');return true;},open:()=>{calls.push('recruit-dialogue');return true;}},actionMenu:{isOpen:false},
  collectNearbyLoot:()=>{calls.push('loot-query');return false;},nearestOwnMember:()=>({id:'merc33'}),host:{beginConversation:()=>{calls.push('conversation');return {ok:true};}},talkId:null,conversationId:null,
  heroCover:{leave:()=>{}},$:()=>({hidden:true}),takeNpcCash:()=>!!s.npcHoldUp?.canTake,pickupNearbyWeapon:()=>!!s.ground,
  interactWithVehiclePanel:()=>{if(!['hood','trunk'].includes(s.current?.kind))return false;calls.push(s.current.kind);return true;},
  interactWithBuilding:()=>{if(!['building','ladder'].includes(s.current?.kind))return false;calls.push(s.current.kind);return true;}};
 vm.createContext(s);vm.runInContext(priority+'\n'+capture+'\nfunction walkKey(e){'+mainE+'}',s);
 const press=(extra={})=>{const e={code:'KeyE',repeat:false,target:{tagName:'CANVAS'},preventDefault(){this.defaultPrevented=true;},stopImmediatePropagation(){this.stopped=true;},...extra};s.keydown(e);if(!e.defaultPrevented&&!e.stopped&&!s.blocked&&!/INPUT|SELECT|TEXTAREA/.test(e.target.tagName||'')&&!e.target.isContentEditable)s.walkKey(e);return e;};
 return {s,calls,press};
}
test('actual Walk wires object priority into the conversation capture handler',()=>{
 assert.match(walk,/createMercenaryWalk\(\{[^\n]*groundHeight,hasPriorityInteraction,isBlocked:/);
});
for(const kind of ['car','building','hood','trunk','ladder'])test(`fresh ${kind} wins over nearby crew conversation`,()=>{
 const {s,calls,press}=setup();s.current={kind,ladder:{end:'lower'}};s.stale=null;const e=press();
 assert(!calls.includes('conversation'));assert(calls.includes('fresh'));assert.equal(e.defaultPrevented,true);
 if(kind==='car')assert(s.keys.has('KeyE'),'normal hold input must start');else assert(calls.includes(kind));
});
for(const property of ['occupiedSeat','sourceActive','transition'])test(`${property} keeps E for exit/transition`,()=>{
 const {s,calls,press}=setup();s[property]=true;press();assert(s.keys.has('KeyE'));assert(!calls.includes('conversation'));
});
for(const action of ['cash','weapon','rescue','active-ladder'])test(`${action} wins over conversation`,()=>{
 const {s,calls,press}=setup();
 if(action==='cash')s.npcHoldUp={canTake:true};
 if(action==='weapon')s.ground={id:'drop'};
 if(action==='rescue')s.window.MafioziPoliceConvoyRescue={getPrompt:()=>({canInteract:true}),begin:()=>calls.push('rescue')};
 if(action==='active-ladder')s.verticalNavigation.active=true;
 press();assert(!calls.includes('conversation'));
});
test('expired cached object does not prevent conversation when fresh query is empty',()=>{
 const {s,calls,press}=setup();s.stale={kind:'car'};press();assert(calls.includes('conversation'));assert(calls.includes('dialogue'));assert(!s.keys.has('KeyE'));
});
test('upper ladder uses E and wins over conversation',()=>{
 const {s,calls,press}=setup();s.current={kind:'ladder',ladder:{end:'upper'}};const e=press();assert(!calls.includes('conversation'));assert(calls.includes('ladder'));assert.equal(e.defaultPrevented,true);
});
test('repeat/consumed/editable/menu events never open conversation',()=>{
 for(const extra of [{repeat:true},{defaultPrevented:true},{target:{tagName:'INPUT'}},{target:{tagName:'SELECT'}},{target:{isContentEditable:true}}]){
  const {calls,press}=setup();press(extra);assert(!calls.includes('conversation'));
 }
 const {s,calls,press}=setup();s.blocked=true;press();assert(!calls.includes('conversation'));
});
test('car QA entry uses the actual capture/bubble E path instead of bypassing it with pointer hold',()=>{
 const callback=walk.match(/onEntryHold\(pressed\)\{document\.body\.dispatchEvent\(new KeyboardEvent[^\n]+?\},/)[0].slice(0,-1);
 const events=[],s={document:{body:{dispatchEvent:e=>events.push(e)}},KeyboardEvent:class{constructor(type,options){Object.assign(this,{type},options);}}};vm.createContext(s);
 vm.runInContext('const qa={'+callback+'};qa.onEntryHold(true);qa.onEntryHold(false);',s);
 assert.deepEqual(events.map(e=>[e.type,e.code,e.bubbles,e.cancelable]),[['keydown','KeyE',true,true],['keyup','KeyE',true,true]]);
});

function registeredInput(){
 const f=setup(),{s,calls}=f,listeners=new Map();let now=0;
 Object.assign(s,{hudInputBlocked:()=>s.blocked,arsenalOpen:()=>false,walking:true,entryArmed:true,entryHoldClock:createVehicleEntryHoldClock(),performance:{now:()=>now*1000},addEventListener(type,fn){const list=listeners.get(type)||[];list.push(fn);listeners.set(type,list);}});
 const start=walk.indexOf('const keys=new Set();');
 vm.runInContext(walk.slice(start,walk.indexOf('function beginJump(',start))+'\nglobalThis.eHeld=()=>keys.has("KeyE");',s);
 const event=(type,extra={})=>({type,code:'KeyE',repeat:false,target:{tagName:'BODY',isContentEditable:false},preventDefault(){this.defaultPrevented=true;},stopImmediatePropagation(){this.stopped=true;},...extra});
 const dispatch=e=>{if(e.type==='keydown')s.keydown(e);if(!e.stopped)for(const fn of listeners.get(e.type)||[]){fn(e);if(e.stopped)break;}return e;};
 return {...f,event,dispatch,sample(t){now=t;return s.entryHoldClock.advance(s.eHeld()&&s.entryArmed&&!s.buildingKeyConsumed,true,t,s.occupiedSeat?EXIT_HOLD_SECONDS:HOLD_SECONDS);}};
}

test('actual registered capture/window input and keyup preserve short/held/repeated E without double entry',()=>{
 const {s,calls,event,dispatch,sample}=registeredInput();s.current={kind:'car'};
 dispatch(event('keydown'));assert(s.eHeld());assert(!sample(0).ready);dispatch(event('keydown',{repeat:true}));assert(!sample(.2).ready);
 dispatch(event('keyup'));assert(!s.eHeld());dispatch(event('keydown'));assert(!sample(.21).ready,'release removes prior hold credit');assert(sample(.21+HOLD_SECONDS).ready);
 dispatch(event('keydown',{repeat:true}));assert(!sample(.21+HOLD_SECONDS+.05).ready,'auto-repeat cannot authorize a second transition');
 dispatch(event('keyup'));s.occupiedSeat='front_left';s.npcHoldUp={canTake:true};s.ground={id:'nearby-gun'};dispatch(event('keydown'));
 assert(s.eHeld());assert(!sample(1).ready);assert(sample(1+EXIT_HOLD_SECONDS).ready);assert(!calls.includes('conversation'));assert(!calls.includes('loot-query'));
});

const world=read('../../../world.html');
function sourceFunction(source,name){const start=source.indexOf('function '+name+'(');assert(start>=0,name);const end=source.indexOf('\n',start),line=source.slice(start,end);return line.trimEnd().endsWith('}')?line:source.slice(start,source.indexOf('\n}',start)+2);}
function sourceRescueCapture(walkActive){
 const sent=[],handlers=[],s={walkActive,_LOCAL_PREVIEW:false,performance:{now:()=>1000},player:{r:10,c:10},QP:{uid:'player'},questCars:new Map([['custody',{id:'custody',x:10,y:10,custody_id:'case',custody_owner_uid:'ally',custody_driver_id:'dead-cop',vx:0,vy:0}]]),worldCops:[{id:'dead-cop',alive:false,hp:0}],ws:{readyState:1,send:message=>sent.push(JSON.parse(message))},window:{addEventListener:(type,fn,capture)=>handlers.push({type,fn,capture})}};
 s._walkRendererActive=()=>s.walkActive;vm.createContext(s);
 const listener=world.split(/\r?\n/).find(line=>line.startsWith("window.addEventListener('keydown',")&&line.includes('_policeConvoyRescueInput(true)'));assert(listener);
 vm.runInContext('let _policeRescueHold=null,_policeRescueCandidateCache=null,_policeRescueCandidateAt=-Infinity;\n'+['_walkOwnsGameKey','_policeConvoyRescueCandidate','_policeConvoyRescueInput'].map(name=>sourceFunction(world,name)).join('\n')+'\n'+listener,s);
 assert.equal(handlers.length,1);assert.equal(handlers[0].capture,true);
 return {s,sent,keydown:handlers[0].fn};
}

test('source rescue capture preserves legacy 2D but yields Walk E before occupied exit',()=>{
 const legacy=sourceRescueCapture(false),plain={code:'KeyE',repeat:false,preventDefault(){this.defaultPrevented=true;},stopImmediatePropagation(){this.stopped=true;}};
 legacy.keydown(plain);assert(plain.defaultPrevented&&plain.stopped);assert.equal(legacy.sent.length,1);assert.equal(legacy.sent[0].d.action,'rescue_begin');
 const source=sourceRescueCapture(true),{s,calls,event,dispatch}=registeredInput();s.occupiedSeat='front_left';s.window.MafioziPoliceConvoyRescue={getPrompt:()=>({canInteract:true}),begin:()=>source.s._policeConvoyRescueInput(true)};
 const e=event('keydown');source.keydown(e);assert(!e.stopped&&!e.defaultPrevented);dispatch(e);assert(s.eHeld());assert.equal(source.sent.length,0);assert(!calls.includes('conversation'));
});

test('Walk foot rescue reaches real source begin once, while editable or blocked input does not send it',()=>{
 for(const mode of ['foot','blocked','editable']){
  const source=sourceRescueCapture(true),{s,calls,event,dispatch}=registeredInput();s.current=null;s.blocked=mode==='blocked';
  s.window.MafioziPoliceConvoyRescue={getPrompt:()=>({canInteract:true}),begin:()=>source.s._policeConvoyRescueInput(true),end:()=>source.s._policeConvoyRescueInput(false)};
  const e=event('keydown',mode==='editable'?{target:{tagName:'INPUT',isContentEditable:false}}:{});source.keydown(e);dispatch(e);
  if(mode==='foot'){assert.equal(source.sent.length,1);assert(e.defaultPrevented);assert(!s.eHeld());const repeated=event('keydown',{repeat:true});source.keydown(repeated);dispatch(repeated);assert.equal(source.sent.length,1,'held rescue cannot send duplicate begin');dispatch(event('keyup'));assert.equal(vm.runInContext('_policeRescueHold',source.s),null,'actual Walk keyup releases source rescue');}
  else assert.equal(source.sent.length,0,mode+' cannot trigger source rescue');
  assert(!calls.includes('conversation'));
 }
});
