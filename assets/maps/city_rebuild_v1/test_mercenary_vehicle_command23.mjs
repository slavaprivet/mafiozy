import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const source=readFileSync(new URL('./mercenary_walk.mjs',import.meta.url),'utf8');
const line=name=>source.split('\n').find(s=>s.includes(`function ${name}(`));
function setup(){
 const calls=[],notices=[];
 const state={generalBlocked:true,commandBlocked:false,inVehicle:true,contextPending:false,disposed:false,
  squadTransport:{isPlayerInVehicle:()=>state.inVehicle},
  isBlocked:()=>state.generalBlocked,isCommandBlocked:()=>state.commandBlocked,
  actionPriority:['revive','unlock_safe','eliminate','intimidate'],
  host:{getActions:()=>[{id:'revive'},{id:'eliminate'},{id:'intimidate'}],command:(...args)=>{calls.push(args);return {ok:true};},rally:()=>{calls.push(['rally']);return {ok:true};},toggleVehicleDefenseFire:()=>{calls.push(['defense']);return {ok:true,message:'Ответный огонь'};}},
  ui:{isOpen:false,showNotice:s=>notices.push(s)},dialogue:{isOpen:false},actionMenu:{isOpen:false,open:()=>calls.push(['menu'])},
  selection:{setRally:()=>{}},targets:{pickGround:()=>{calls.push(['ground']);return {x:1,z:2};}},
  pick:()=>state.aimed,updateAimSelection:()=>{},aimed:{id:'enemy',valid:true},
  collectNearbyLoot:()=>{calls.push(['loot']);return false;},nearestOwnMember:()=>null};
 vm.createContext(state);
 vm.runInContext([line('vehicleCommandContext'),line('issueCommand'),line('contextActions'),line('dispatchAction'),source.slice(source.indexOf(' async function commandAtAim(){'),source.indexOf(" document.addEventListener('keydown',keydown,true);"))].join('\n'),state);
 return {state,calls,notices};
}

test('seated X has no aimed actions; ordinary foot actions remain',()=>{
 const {state:s}=setup();assert.equal(s.contextActions(s.aimed).length,0);
 s.generalBlocked=false;s.inVehicle=false;assert.deepEqual(Array.from(s.contextActions(s.aimed),a=>a.id),['revive','eliminate','intimidate']);
 s.commandBlocked=true;assert.equal(s.contextActions(s.aimed).length,0);
});
test('seat command does not bypass host availability or invalid target',()=>{
 const {state:s}=setup();s.host.getActions=()=>[{id:'eliminate',disabledReason:'no seat'},{id:'intimidate'}];assert.equal(s.contextActions(s.aimed).length,0);
 assert.equal(s.contextActions({valid:false}).length,0);
});
test('dispatch rechecks command permission after menu or seat state changes',async()=>{
 const {state:s,calls}=setup();assert.equal((await s.issueCommand('revive',s.aimed)).ok,false);assert.equal(calls.length,0);
 s.commandBlocked=true;assert.equal((await s.issueCommand('eliminate',s.aimed)).ok,false);assert.equal(calls.length,0);
 s.commandBlocked=false;assert.equal((await s.issueCommand('eliminate',s.aimed)).ok,false);assert.equal(calls.length,0);
 s.generalBlocked=false;s.inVehicle=false;assert.equal((await s.issueCommand('eliminate',s.aimed)).ok,true);assert.equal(calls.length,1);
});
test('vehicle X toggles defense without picking a civilian or sending eliminate',async()=>{
 const {state:s,calls}=setup();s.pick=()=>{throw Error('vehicle must never pick a target');};await s.commandAtAim();
 assert.deepEqual(calls,[['defense']]);assert.equal(s.contextPending,false);
});
test('empty vehicle aim still toggles defense and never issues rally',async()=>{
 const {state:s,calls,notices}=setup();s.aimed=null;await s.commandAtAim();assert.deepEqual(calls,[['defense']]);assert.match(notices[0],/огонь/);
 calls.length=0;s.generalBlocked=false;s.inVehicle=false;await s.commandAtAim();assert.deepEqual(calls.map(a=>a[0]),['ground','rally']);
});
test('transition/menu authority blocks before picking or dispatch',async()=>{
 const {state:s,calls}=setup();s.commandBlocked=true;s.pick=()=>{throw Error('must not pick');};await s.commandAtAim();assert.equal(calls.length,0);
});
test('X command allowance preserves E and editable/modal input guards',()=>{
 const {state:s,calls}=setup();let commands=0;s.commandAtAim=()=>commands++;
 const event=(code,extra={})=>({code,target:{tagName:'CANVAS'},preventDefault(){this.defaultPrevented=true;},stopImmediatePropagation(){},...extra});
 s.keydown(event('KeyX'));assert.equal(commands,1);s.keydown(event('KeyE'));assert.equal(calls.length,0);
 for(const extra of [{repeat:true},{defaultPrevented:true},{target:{tagName:'INPUT'}},{target:{isContentEditable:true}}])s.keydown(event('KeyX',extra));
 for(const modal of [s.ui,s.dialogue,s.actionMenu]){modal.isOpen=true;s.keydown(event('KeyX'));modal.isOpen=false;}
 s.commandBlocked=true;s.keydown(event('KeyX'));assert.equal(commands,1);
});

test('defense rejection and unavailable host never fall back to foot orders',async()=>{
 const {state:s,calls,notices}=setup();s.host.toggleVehicleDefenseFire=()=>({ok:false,reason:'Нет вооружённых пассажиров'});
 await s.commandAtAim();assert.equal(calls.length,0);assert.match(notices[0],/пассажиров/);
 delete s.host.toggleVehicleDefenseFire;await s.commandAtAim();assert.equal(calls.length,0);assert.equal(s.contextPending,false);
});
test('vehicle without a current ready record still cannot dispatch foot actions',async()=>{
 const {state:s,calls}=setup();s.generalBlocked=false;s.squadTransport={isPlayerInVehicle:()=>true,getPlayerVehicle:()=>null};
 assert.equal((await s.issueCommand('eliminate',s.aimed)).ok,false);assert.equal(calls.length,0);
 s.squadTransport={getPlayerVehicle:()=>({id:'quest_car'})};assert.equal(s.vehicleCommandContext(),true);
 s.squadTransport=null;assert.equal(s.vehicleCommandContext(),false);
});
test('actual Walk guard allows a seated rejection notice but keeps gameplay blocks',()=>{
 const walk=readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
 const expression=walk.match(/isCommandBlocked:\(\)=>(.*?),onOpenChange:open=>/)[1];
 const s={window:{MafioziMercenaries:{canIssueVehicleFireCommand:()=>false}},occupiedSeat:'front_left',transition:null,busy:false,menuHidden:true,blocked:false,arsenal:false,sourceVehicleActive:()=>false};
 s.mercenaryInputBlocked=()=>s.blocked;s.arsenalOpen=()=>s.arsenal;s.$=()=>({hidden:s.menuHidden});vm.createContext(s);
 const check=()=>vm.runInContext(expression,s);assert.equal(check(),false,'unavailable weapon still reaches host reason');
 for(const key of ['transition','busy','blocked','arsenal']){s[key]=true;assert.equal(check(),true,key);s[key]=false;}
 s.menuHidden=false;assert.equal(check(),true);s.menuHidden=true;
 s.window.MafioziMercenaries=null;assert.equal(check(),true,'missing source never dispatches via stale host');
});
