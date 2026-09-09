import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
function extract(name){const start=source.indexOf(`function ${name}(`);assert(start>=0,name);return source.slice(start,source.indexOf('\n}',start)+2);}
const helpers=extract('_walkHudGangInfo')+'\n'+extract('_walkHudCurrentStatus');
const context={_customGang:null,_onlineGang:null,_mafiaState:{employed:false},_policeState:{employed:false},QP:{uid:'1',name:'Я',lvl:4},others:new Map(),myHp:80,PVP:{max_hp:100},_livePlayerLook:()=>({hair:3}),_effectivePrisonJailSeconds:()=>0,_policeProgress:()=>({rank:'Сержант',level:2,xp:500}),_mafiaProgress:()=>({rank:'Капо',level:3,xp:900}),_mafiaFamily:()=>({name:'Беллини'}),_mafiaTraitorLeft:()=>0,_mafiaTraitorText:()=>'10:00'};
vm.createContext(context);vm.runInContext(helpers,context);
const gang=()=>vm.runInContext('_walkHudGangInfo(true)',context),status=()=>vm.runInContext('_walkHudCurrentStatus(_walkHudGangInfo(true))',context);
assert.equal(status().kind,'civilian');
context._customGang={id:7,name:'Волки',role:'leader',member_count:3,max_members:12,hq_r:4,hq_c:8,members:[{telegram_id:'1',name:'Я',role:'leader'},{telegram_id:'2',name:'Офлайн',role:'member'},{telegram_id:'3',name:'Онлайн',role:'member'}]};
context._onlineGang={crew_id:'cg:7',members:[{uid:'1'},{uid:'3'}],max_players:12};
assert.equal(gang().players.length,3);assert.equal(gang().playerCount,3);assert.equal(gang().players[1].online,false);assert.equal(gang().players[2].online,true);assert.equal(gang().players[0].canKick,false);assert.equal(gang().players[1].canKick,true);assert.equal(status().label,'Волки');assert.equal(status().role,'Лидер');
// Authoritative member role wins over a stale per-recipient role field.
context._customGang.members[0].role='member';context._customGang.members[1].role='leader';assert.equal(gang().canManage,false);assert(gang().players.every(m=>!m.canKick));assert.equal(status().role,'Участник');
context._mafiaState.employed=true;assert.equal(status().kind,'gang');
context._policeState.employed=true;assert.equal(status().label,'Полиция · Сержант');
context._effectivePrisonJailSeconds=()=>65;assert.equal(status().kind,'prison');assert.equal(status().badge,'1:05');
context._effectivePrisonJailSeconds=()=>0;context._policeState.employed=false;context._mafiaState.employed=false;context._mafiaTraitorLeft=()=>600;assert.equal(status().kind,'traitor');
context._mafiaTraitorLeft=()=>0;context._customGang=null;context._onlineGang={crew_id:'1',max_players:4,members:[{uid:'1',name:'Я'},{uid:'2',name:'Друг'}]};assert.equal(gang().kind,'party');assert.equal(gang().playerMax,4);assert.equal(gang().players[1].canKick,true);
context.QP.uid='2';assert.equal(gang().isLeader,false);assert(gang().players.every(m=>!m.canKick));
// Regression: the native roster is called before this lexical binding initializes.
const boot={_customGang:null,_onlineGang:null,QP:{uid:'1'},others:new Map()};vm.createContext(boot);vm.runInContext(extract('_walkHudGangInfo')+'\nresult=_walkHudGangInfo(); let _mafiaState={employed:false};',boot);assert.equal(boot.result.kind,'none');
// Extract the real kick helper; authorization is checked again at click time.
vm.runInContext(extract('_kickCustomGangMember').replace(/^function /,'async function '),context);
let requests=0;Object.assign(context,{_customGangBusy:false,confirm:()=>true,_apiRequest:async()=>{requests++;return{json:async()=>({ok:true,gang:null})};},_refreshMafiaPerks:()=>{},renderJobStatus:()=>{},_refreshCustomGangViews:()=>{},showToast:()=>{},loadCustomGangState:()=>{}});context.QP.api='https://example.invalid';
assert.equal(await vm.runInContext("_kickCustomGangMember('1')",context),false);assert.equal(requests,0);
context.QP.uid='1';context._customGang={id:7,role:'leader',members:[{telegram_id:'1',role:'leader'},{telegram_id:'2',role:'member'}]};
assert.equal(await vm.runInContext("_kickCustomGangMember('1')",context),false);assert.equal(requests,0);
assert.equal(await vm.runInContext("_kickCustomGangMember('2')",context),true);assert.equal(requests,1);
console.log('PASS: live status priority, full offline roster, role changes, leader-only controls, early boot TDZ, safe source kick');
