import assert from 'node:assert/strict';
import {normalizeWalkHudState, createWalkHudDispatcher, createWorldWalkHudBridge, getWalkHudOpenPanels, WALK_HUD_ACTIONS} from './world_walk_hud_data.mjs';

const unavailable = normalizeWalkHudState({player: {cash: 9000}});
assert.equal(unavailable.available, false);
assert.equal(unavailable.player.cash, null);
assert.equal(unavailable.player.hp, null);
assert.deepEqual(unavailable.bosses, []);
assert.ok(Object.values(unavailable.actions).every(enabled => !enabled));
const raw = {available: true, player: {id:'7', name:'Ира', hp:83, maxHp:125, cash:0, diamonds:3, level:12, look:{gender:1, skin:3, hair:4, suit:'#903443', extra:{color:'red'}}}, gang:{playerMax:3, npcMax:0, npcs:[]}, bosses:[{id:'leila', name:'Лейла', look:{hair:2}}], actions:{profile:true}};
const first = normalizeWalkHudState(raw);
assert.equal(first.player.cash, 0);
const largeCash='9007199254740993123456789';
const preciseCash=normalizeWalkHudState({available:true,player:{cash:largeCash}});
assert.equal(preciseCash.player.cash,largeCash);
assert.equal(normalizeWalkHudState(preciseCash).player.cash,largeCash);
assert.equal(normalizeWalkHudState({available:true,player:{cash:BigInt(largeCash)}}).player.cash,largeCash);
assert.equal(first.player.hpRatio, 83/125);
assert.equal(first.gang.npcMax, 0);
assert.equal(first.actions.profile, true);
assert.equal(first.actions.inventory, false);
first.player.look.extra.color='blue';
assert.equal(raw.player.look.extra.color, 'red');
raw.player.look.suit='#abcabc';
raw.player.look.hair=7;
const second=normalizeWalkHudState(raw);
assert.equal(second.player.look.suit, '#abcabc');
assert.equal(second.player.look.hair, 7);
assert.equal(normalizeWalkHudState({available:true,player:{hp:200,maxHp:100,cash:NaN}}).player.hpRatio,1);
assert.equal(normalizeWalkHudState({available:true,player:{cash:NaN}}).player.cash,null);

let active=false, calls=[];
const dispatcher=createWalkHudDispatcher({isActive:()=>active,getBossIds:()=>['leila'],actions:{
  profile:payload=>calls.push(['profile',payload]), boss:payload=>calls.push(['boss',payload]),
  inventory:()=>({accepted:false,reason:'auth-required'}), menu:()=>{throw Error('private');},
}});
assert.equal((await dispatcher('profile')).reason,'source-unavailable');
active=true;
for(const action of ['eval','constructor','__proto__','transferCash'])assert.equal((await dispatcher(action)).reason,'unknown-action');
assert.equal((await dispatcher('mode')).reason,'action-unavailable');
assert.equal((await dispatcher('boss',{id:'fake'})).reason,'unknown-boss');
assert.equal((await dispatcher('profile',{tab:'inv',uid:'other'})).accepted,true);
assert.deepEqual(calls.pop(),['profile',undefined]);
assert.equal((await dispatcher('boss',{id:'leila',allowAssault:true,uid:'other'})).accepted,true);
assert.deepEqual(calls.pop(),['boss',{id:'leila'}]);
assert.equal((await dispatcher('inventory')).reason,'auth-required');
assert.equal((await dispatcher('menu')).reason,'source-action-failed');
assert.equal(WALK_HUD_ACTIONS.length,16);
const roleState=normalizeWalkHudState({available:true,status:{kind:'gang',role:'Лидер'},gang:{kind:'permanent',isLeader:true,canManage:true,players:[{id:'7',isSelf:true,canKick:false}],npcs:[{id:'7',canKick:true}]},actions:{gang_manage:true}});
assert.equal(roleState.status.role,'Лидер');assert.equal(roleState.gang.isLeader,true);assert.equal(roleState.gang.players[0].kind,'player');assert.equal(roleState.gang.npcs[0].kind,'npc');assert.equal(roleState.gang.players[0].isSelf,true);assert.equal(roleState.gang.npcs[0].canKick,true);
const limited=createWorldWalkHudBridge({isActive:()=>true,readSnapshot:()=>({actions:{police:false,gang_manage:false}}),actions:{police(){},gang_manage(){},role_help(){}}}).getWalkHudState();
assert.equal(limited.actions.police,false);assert.equal(limited.actions.gang_manage,false);assert.equal(limited.actions.role_help,true);

const visible={id:'profileModal',getClientRects:()=>[{}],getAttribute:()=>null};
const hidden={id:'newspaperModal',getClientRects:()=>[],getAttribute:()=>null};
const ariaHidden={id:'modeModal',getClientRects:()=>[{}],getAttribute:k=>k==='aria-hidden'?'true':null};
const doc={getElementById:id=>[visible,hidden,ariaHidden].find(el=>el.id===id),querySelectorAll:()=>[visible],defaultView:{getComputedStyle:()=>({display:'flex',visibility:'visible'})}};
assert.deepEqual(getWalkHudOpenPanels(doc),['profileModal']);
assert.deepEqual(getWalkHudOpenPanels(null),[]);
const facade=createWorldWalkHudBridge({readSnapshot:()=>raw,isActive:()=>active,document:doc,actions:{profile:()=>{}}});
assert.equal(facade.getWalkHudState().available,true);
assert.equal(facade.getWalkHudState().ui.blocked,true);
assert.equal(facade.getWalkHudState().ui.reason,'source-dialog');
assert.equal(facade.getWalkHudState().actions.profile,true);
active=false;
assert.equal(facade.getWalkHudState().player.cash,null);
assert.equal((await facade.performWalkHudAction('profile')).accepted,false);
assert.equal(createWorldWalkHudBridge({isActive:()=>true,readSnapshot:()=>{throw Error('not initialized');}}).getWalkHudState().available,false);
console.log('PASS world HUD: source-only values, live copied look, explicit actions, boss allowlist, native modal locks');
