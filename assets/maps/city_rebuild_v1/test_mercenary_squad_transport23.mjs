import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
import {performance} from 'node:perf_hooks';
import {createMercenaryVehicleBridge} from './mercenary_vehicle_bridge.mjs';
import {advanceMercenarySafeDrop} from './mercenary_catchup.mjs';
import {createNpcNativeNavigation} from './npc_native_navigation.mjs';

const source=fs.readFileSync(new URL('./mercenary_world.js',import.meta.url),'utf8');
const baseline=execFileSync('git',['show','272d12c25ed0843e0ec525288f06af7556f2d990:assets/maps/city_rebuild_v1/mercenary_world.js'],{encoding:'utf8',maxBuffer:2e6});
const extract=s=>s.slice(s.indexOf(' const squadPassengerSeats='),s.indexOf(' function getMember(id)'));
function setup({old=false,sourceCar=false,count=4}={}){
 const seats=['front_left','front_right','rear_left','rear_right'].map((id,i)=>({id,canDrive:!i,side:i%2?-1:1,doorDistance:2,doorFront:i>1?-1:0,anchor:{side:i%2?-.5:.5,front:i>1?-1:0,y:.7}}));
 const actor={object:{parent:{},visible:true,position:{x:41,y:0,z:41},rotation:{y:0},scale:{x:1,y:1,z:1}},seats,profile:{halfWidth:1},setDoorById(){}};
 const other={...actor,object:{...actor.object,position:{x:90,y:0,z:80}}};
 const fleet={records:[{id:'a',car:actor,state:{speed:0}},{id:'b',car:other,state:{speed:0}}]};
 let player={id:sourceCar?'quest_1':'fleet:a',seatId:'front_left',ready:true};
 const bridge=createMercenaryVehicleBridge({canCross:()=>true,getFleet:()=>fleet,getTraffic:()=>({getActor:id=>id==='quest_1'?actor:null,setNpcAccess(){}}),getPlayer:()=>player});
 const members=Array.from({length:count},(_,i)=>({id:'m'+i,r:10,c:15,hp:100,ang:0}));
 const roster=members.map(m=>({id:m.id,status:'active'}));
 const car={id:1,x:10,y:10,ang:Math.PI/2,vx:0,vy:0,passenger_uids:[]};
 const ctx={testTime:0,members,targets:{squadTransport:bridge,canMove:()=>false},raw:id=>members.find(m=>m.id===id),core:{getAction:()=>null},scale:()=>4.1,toWorld:m=>({x:m.c*4.1,z:m.r*4.1,y:0}),now:()=>ctx.testTime,
  myDrivingCarId:sourceCar?'1':null,myIsPassenger:false,questCars:new Map([['1',car]]),QP:{uid:'hero'},player:{r:0,c:0},document:{documentElement:{dataset:{}}},
  _npcBodyPassable:()=>false,_civilianTripDoorPath:()=>true,canMoveMember:()=>true,findSquadSafeDrop:()=>null,validateSquadSafeDrop:(m,p)=>p};
 vm.createContext(ctx);vm.runInContext(extract(old?baseline:source)+';globalThis.api={tick:squadVehicleTick,clear:clearSquadVehicle,vehicle:playerSquadVehicle'+(old?'':',door:squadDoorPath')+'};',ctx);
 return {ctx,bridge,members,roster,actor,other,fleet,car,setPlayer:p=>{player=p;ctx.myDrivingCarId=p?.id==='quest_1'?'1':null;},tick:(dt=.25)=>{ctx.testTime+=dt;return ctx.api.tick(roster,dt);},atDoor(m){const a=bridge.access({carId:m._mercenaryVehicleReservedId,seatId:m._mercenaryVehicleReservedSeat});m.r=a.outside.r;m.c=a.outside.c;}};
}
const checks=[];const check=(name,fn)=>{fn();checks.push(name);};
check('actual baseline clears seat into forbidden origin',()=>{
 const h=setup({old:true,sourceCar:true,count:1}),m=h.members[0];Object.assign(m,{_mercenaryVehicleSeat:'rear_left',_mercenaryVehicleId:'quest_1'});h.setPlayer(null);h.tick();assert.equal(m._mercenaryVehicleSeat,undefined);assert.equal(m.r,0);assert.equal(m.c,0);
});
check('authored local fleet seats reserved once; full fourth member waits',()=>{
 const h=setup();h.tick();assert.deepEqual(h.bridge.reservedSeats('fleet:a').sort(),['front_right','rear_left','rear_right']);assert.equal(h.members[3]._mercenaryVehicleReservedSeat,undefined);assert.ok(h.members.every(m=>!m._mercenaryVehicleSeat));
 const before=h.members.map(m=>m._mercenaryVehicleReservedSeat);h.roster.reverse();h.tick();assert.deepEqual(h.members.map(m=>m._mercenaryVehicleReservedSeat),before);
});
function board(h){h.tick();for(const m of h.members.filter(m=>m._mercenaryVehicleReservedSeat))h.atDoor(m);h.tick();for(let i=0;i<4;i++)h.tick();}
check('real board phases then moving ride keep distinct seat coordinates',()=>{
 const h=setup();h.tick();h.atDoor(h.members[0]);h.tick();assert.equal(h.members[0]._mercenaryVehiclePhase,'board');assert.equal(h.members[0]._mercenaryVehicleProgress,0);board(h);
 assert.equal(h.members.filter(m=>m._mercenaryVehiclePhase==='drive').length,3);h.actor.object.position.x+=5;h.tick();assert.equal(new Set(h.members.slice(0,3).map(m=>m.r+','+m.c)).size,3);
});
check('moving car and blocked door do not board',()=>{
 const h=setup({count:1});h.tick();h.atDoor(h.members[0]);h.fleet.records[0].state.speed=2;h.tick();assert.equal(h.members[0]._mercenaryVehicleSeat,undefined);h.fleet.records[0].state.speed=0;h.ctx._civilianTripDoorPath=()=>false;h.tick();assert.equal(h.members[0]._mercenaryVehicleSeat,undefined);
});
check('car departing during board never advances seated progress or drags NPC, then resumes bounded approach',()=>{
 const h=setup({count:1}),m=h.members[0];h.tick();h.atDoor(m);h.tick();h.tick(.15);assert.ok(m._mercenaryVehicleProgress>0&&m._mercenaryVehicleProgress<1);
 const before={r:m.r,c:m.c,progress:m._mercenaryVehicleProgress};h.actor.object.position.x+=4;h.fleet.records[0].state.speed=2;h.tick(.1);
 assert.equal(m.r,before.r);assert.equal(m.c,before.c);assert.ok(!m._mercenaryVehicleSeat||m._mercenaryVehicleProgress===before.progress);assert.equal(h.bridge.reservedSeats('fleet:a').length,1);
 h.fleet.records[0].state.speed=0;let previous={r:m.r,c:m.c};for(let i=0;i<30&&m._mercenaryVehicleSeat;i++){h.tick(.1);assert.ok(Math.hypot(m.r-previous.r,m.c-previous.c)*4.1<=.300001);previous={r:m.r,c:m.c};}
 if(!m._mercenaryVehicleSeat){assert.ok(m._mercenaryVehicleChase);h.atDoor(m);h.tick();for(let i=0;i<15;i++)h.tick(.1);}assert.equal(m._mercenaryVehiclePhase,'drive');
});
check('seated focus does not eject and death does not call safe relocation',()=>{
 const h=setup({count:1});board(h);const m=h.members[0],seat=m._mercenaryVehicleSeat;m._mercenaryDefending=true;h.tick();assert.equal(m._mercenaryVehicleSeat,seat);m.hp=0;m.dead=true;h.setPlayer(null);h.ctx.findSquadSafeDrop=()=>{throw Error('must not move dead member');};h.tick();assert.equal(m._mercenaryVehicleSeat,seat);
});
check('blocked exit retains original car seat; switch does not use new-car origin',()=>{
 const h=setup({count:1});board(h);const m=h.members[0],seat=m._mercenaryVehicleSeat;h.setPlayer({id:'fleet:b',seatId:'front_left',ready:true});let origin;
 h.ctx.findSquadSafeDrop=(member,index,p)=>{origin=p;return null;};h.tick();assert.equal(m._mercenaryVehicleId,'fleet:a');assert.equal(m._mercenaryVehicleSeat,seat);assert.equal(m._mercenaryVehicleExitPending,true);assert.ok(origin.x<60);
 h.ctx.findSquadSafeDrop=()=>({x:35,y:0,z:40});h.tick();assert.equal(m._mercenaryVehiclePhase,'exit');for(let i=0;i<30&&m._mercenaryVehicleSeat;i++)h.tick();assert.equal(m._mercenaryVehicleSeat,undefined);assert.equal(m.c,35/4.1);assert.equal(h.bridge.reservedSeats('fleet:a').length,0);
});
check('invalid safe drop and blocked door-to-ground sweep retain pending seat',()=>{
 const h=setup({count:1});board(h);h.setPlayer(null);const m=h.members[0];h.ctx.findSquadSafeDrop=()=>({x:NaN,z:0});h.tick();assert.ok(m._mercenaryVehicleSeat);h.ctx.findSquadSafeDrop=()=>({x:35,y:0,z:40});h.ctx.canMoveMember=()=>false;h.tick();assert.ok(m._mercenaryVehicleSeat);
});
check('existing source passenger blocks actual front seat; malformed occupancy fails closed',()=>{
 const h=setup({sourceCar:true});h.car.passenger_uids=['guest'];h.tick();assert.deepEqual(h.bridge.reservedSeats('quest_1').sort(),['rear_left','rear_right']);const j=setup({sourceCar:true});j.car.passenger_uids=['a','b'];j.tick();assert.equal(j.bridge.reservedSeats('quest_1').length,0);
});
check('player passenger seat reserved and source/local ids never alias',()=>{
 const h=setup();h.setPlayer({id:'fleet:a',seatId:'rear_left',ready:true});h.tick();assert.ok(!h.bridge.reservedSeats('fleet:a').includes('rear_left'));assert.equal(h.bridge.getVehicle('a'),null);assert.equal(h.bridge.getVehicle('quest_a'),null);
});
check('missing rendered actor blocks new seats and retains seated ownership',()=>{
 const h=setup({count:1});board(h);h.actor.object.parent=null;h.tick();assert.ok(h.members[0]._mercenaryVehicleSeat);const j=setup();j.actor.object.parent=null;j.tick();assert.equal(j.bridge.reservedSeats('fleet:a').length,0);
});
check('numeric and string quest keys both preserve authoritative car identity',()=>{
 for(const key of ['1',1]){const h=setup({sourceCar:true});h.ctx.questCars=new Map([[key,h.car]]);h.tick();assert.equal(h.bridge.reservedSeats('quest_1').length,3);}
 const h=setup({sourceCar:true});h.ctx.questCars=new Map([[2,h.car]]);h.tick();assert.equal(h.bridge.reservedSeats('quest_1').length,0);
});
check('physical exit advances at 3m/s and final fresh validation retains reservation until clear',()=>{
 const h=setup({count:1});board(h);const m=h.members[0];h.setPlayer(null);h.ctx.findSquadSafeDrop=()=>({x:35,y:0,z:40});h.ctx.validateSquadSafeDrop=()=>null;
 for(let i=0;i<40;i++){const before={r:m.r,c:m.c};h.tick(.1);assert.ok(Math.hypot(m.r-before.r,m.c-before.c)*4.1<=.300001);assert.ok(m._mercenaryVehicleSeat);}
 assert.equal(m._mercenaryVehiclePhase,'exit');assert.equal(h.bridge.reservedSeats('fleet:a').length,1);h.ctx.validateSquadSafeDrop=(m,p)=>p;h.tick(.1);assert.equal(m._mercenaryVehicleSeat,undefined);
});
check('moving vehicle pauses existing exit and blocked corridor never releases seat',()=>{
 const h=setup({count:1});board(h);const m=h.members[0];h.setPlayer(null);h.ctx.findSquadSafeDrop=()=>({x:35,y:0,z:40});h.tick(.1);const position={r:m.r,c:m.c};h.fleet.records[0].state.speed=3;h.tick(.1);assert.equal(m.r,position.r);assert.equal(m.c,position.c);h.fleet.records[0].state.speed=0;h.ctx._civilianTripDoorPath=()=>false;h.tick(.1);assert.ok(m._mercenaryVehicleSeat);assert.equal(m.r,position.r);
});
check('far reserved follower uses bounded checked outside drop then physical door boarding',()=>{
 const h=setup({count:1}),m=h.members[0];m.c=35;let checks=0;
 h.ctx.findSquadSafeDrop=(member,index,origin,yaw,state)=>advanceMercenarySafeDrop(state,{origin,yaw,memberId:member.id,slot:index,now:h.ctx.testTime*1000,maxChecks:4,validate:p=>{checks++;return {ok:true,point:{...p,y:0}};}}).point;
 for(let i=0;i<25;i++)h.tick(.25);assert.equal(m.c,35);h.tick(.25);assert.notEqual(m.c,35);assert.equal(checks,2);assert.equal(m._mercenaryVehicleSeat,undefined);assert.ok(m._mercenaryVehicleChase);assert.ok(Math.hypot(m.c*4.1-41,m.r*4.1-41)>=2.5);
 h.atDoor(m);h.tick();assert.equal(m._mercenaryVehiclePhase,'board');for(let i=0;i<4;i++)h.tick();assert.equal(m._mercenaryVehiclePhase,'drive');
});
check('stuck reserved follower waits 10s; moving car, full car and no free ground never teleport',()=>{
 const h=setup({count:1}),m=h.members[0];let attempts=0;h.ctx.findSquadSafeDrop=()=>{attempts++;return null;};for(let i=0;i<40;i++)h.tick(.25);assert.equal(attempts,0);h.tick(.25);assert.equal(attempts,1);assert.equal(m.c,15);h.fleet.records[0].state.speed=1;h.tick(.25);assert.equal(attempts,1);
 const j=setup({count:4});for(const m of j.members)m.c=35;const calls=[];j.ctx.findSquadSafeDrop=m=>{calls.push(m.id);return null;};for(let i=0;i<45;i++)j.tick(.25);assert.ok(calls.length>0);assert.ok(!calls.includes('m3'));assert.ok(j.members.every(m=>m.c===35));
});
check('vehicle catchup cooldown and interrupted/conversation state do not cause repeated relocation',()=>{
 const h=setup({count:1}),m=h.members[0];m.c=35;let attempts=0;h.ctx.findSquadSafeDrop=()=>{attempts++;return {x:37,y:0,z:42};};for(let i=0;i<26;i++)h.tick(.25);assert.equal(attempts,1);m.c=35;for(let i=0;i<30;i++)h.tick(.25);assert.equal(attempts,1);
 const j=setup({count:1});j.members[0].c=35;j.members[0]._mercenaryConversation=true;j.ctx.findSquadSafeDrop=()=>{throw Error('conversation relocation');};for(let i=0;i<45;i++)j.tick(.25);assert.equal(j.members[0].c,35);
});
check('protected source car refuses boarding and authoritative old-car velocity pauses exit',()=>{
 for(const flag of ['_hidden','_towed','_wrecked','_walkWrecked']){const h=setup({sourceCar:true});h.car[flag]=true;h.tick();assert.equal(h.bridge.reservedSeats('quest_1').length,0);}
 const h=setup({sourceCar:true,count:1});board(h);h.car.vx=1;h.setPlayer(null);h.ctx.findSquadSafeDrop=()=>{throw Error('moving old source car cannot begin exit');};h.tick();assert.ok(h.members[0]._mercenaryVehicleSeat);
});
check('bridge reports entering and exiting local vehicle despite not-ready boarding descriptor',()=>{
 const h=setup();for(const exiting of [false,true]){h.setPlayer({id:'fleet:a',seatId:'front_left',ready:false,exiting});assert.equal(h.bridge.getPlayerVehicle(),null);assert.equal(h.bridge.isPlayerInVehicle(),true);}h.setPlayer(null);assert.equal(h.bridge.isPlayerInVehicle(),false);
});
check('actual source five-probe door helper misses narrow pillar; supplemental native sweep rejects it',()=>{
 const wall={polygonCR:[[10.08,10.06],[10.12,10.06],[10.12,10.10],[10.08,10.10]],minYM:0,maxYM:3};
 const nav=createNpcNativeNavigation({groundHeight:()=>0,bodiesAt:()=>[wall],bodiesInBounds:()=>[wall],containsBody:(b,r,c)=>c>=10.08&&c<=10.12&&r>=10.06&&r<=10.10,surfaceAt:()=> 'land'});
 const h=setup({count:1}),m=h.members[0],from={r:10,c:9.7},to={r:10,c:10.3};
 const src=fs.readFileSync(new URL('./civilian_parking_trip_source.js',import.meta.url),'utf8'),fn=src.slice(src.indexOf('function _civilianTripDoorPath('),src.indexOf('function _civilianTripDoorStep('));
 Object.assign(h.ctx,{MAP:Array.from({length:25},()=>Array(25).fill(0)),_walkNpcNavigationResolver:nav.query,_civilianTripDebugEnabled:()=>false,_civilianDoorBody:[[0,0],[-.18,-.18],[-.18,.18],[.18,-.18],[.18,.18]]});vm.runInContext(fn,h.ctx);
 assert.equal(h.ctx._civilianTripDoorPath({npc:m,carId:'fleet:a'},from.r,from.c,to.r,to.c),true);
 assert.equal(nav.query({mode:'sweep',from,to,radius:.18}).blocked,true);
 h.bridge.canCross=(id,a,b)=>nav.query({mode:'sweep',from:a,to:b,radius:.18}).blocked===false;assert.equal(h.ctx.api.door(m,'fleet:a',from,to),false);
});
check('board admission and door exit both require swept-body clearance',()=>{
 const h=setup({count:1});h.tick();h.atDoor(h.members[0]);h.bridge.canCross=()=>false;h.tick();assert.equal(h.members[0]._mercenaryVehicleSeat,undefined);
 h.bridge.canCross=()=>true;board(h);h.setPlayer(null);h.ctx.findSquadSafeDrop=()=>({x:35,y:0,z:40});h.bridge.canCross=()=>false;const m=h.members[0],from={r:m.r,c:m.c};h.tick();assert.ok(m._mercenaryVehicleSeat);assert.equal(m._mercenaryVehicleExitPlan,undefined);assert.equal(m.r,from.r);assert.equal(m.c,from.c);
});
for(const failure of ['corridor','landing'])check('newly blocked '+failure+' invalidates drop and selects an alternative under shared four-check budget',()=>{
 const h=setup({count:1});board(h);h.setPlayer(null);const m=h.members[0];let searches=0,blocked=null,maxChecks=0;
 h.ctx.squadDropChecksRemaining=4;
 const bad=p=>blocked&&Math.hypot(p.x-blocked.c*4.1,p.z-blocked.r*4.1)<.1;
 h.ctx.findSquadSafeDrop=(member,index,origin,yaw,state)=>{searches++;const result=advanceMercenarySafeDrop(state,{origin,yaw,memberId:member.id,slot:index,now:h.ctx.testTime*1000,maxChecks:h.ctx.squadDropChecksRemaining,validate:p=>bad(p)?{ok:false}:{ok:true,point:{...p,y:0}}});h.ctx.squadDropChecksRemaining-=result.checks;return result.point;};
 h.ctx.canMoveMember=(id,from,to)=>failure==='landing'||!blocked||!bad({x:to.c*4.1,z:to.r*4.1})&&!(m._mercenaryVehicleExitPlan?.drop===blocked);
 h.ctx.validateSquadSafeDrop=(member,p)=>{if(h.ctx.squadDropChecksRemaining<=0)return null;h.ctx.squadDropChecksRemaining--;return bad(p)?null:p;};
 let invalidated=false,previous={r:m.r,c:m.c};for(let i=0;i<150&&m._mercenaryVehicleSeat;i++){
  if(!blocked&&m._mercenaryVehicleExitPlan?.stage==='body')blocked=m._mercenaryVehicleExitPlan.drop;
  h.ctx.squadDropChecksRemaining=4;h.tick(.1);maxChecks=Math.max(maxChecks,4-h.ctx.squadDropChecksRemaining);assert.ok(Math.hypot(m.r-previous.r,m.c-previous.c)*4.1<=.300001);previous={r:m.r,c:m.c};
  if(blocked&&m._mercenaryVehicleExitPlan&&!m._mercenaryVehicleExitPlan.drop)invalidated=true;
 }
 assert.ok(invalidated);assert.ok(searches>2);assert.ok(maxChecks<=4);assert.equal(m._mercenaryVehicleSeat,undefined);
});
function bench(old){const h=setup({old,sourceCar:true,count:3});if(old){for(const [i,m]of h.members.entries())Object.assign(m,{_mercenaryVehicleSeat:['front_right','rear_left','rear_right'][i],_mercenaryVehicleId:'quest_1'});}else board(h);for(let i=0;i<200;i++)h.tick();const times=[];for(let i=0;i<1200;i++){const start=performance.now();h.tick();times.push(performance.now()-start);}times.sort((a,b)=>a-b);return {p50ms:times[600],p95ms:times[1140]};}
const result={pass:true,checks,baseline:bench(true),current:bench(false),limitations:['CPU fixture only; no loaded-scene FPS or LIVE claim','door movement and safe placement providers are injected; host transport code is actual runtime source','seated fire mechanics tested by fire owner']};
fs.writeFileSync(new URL('../../../outputs/mercenary_squad_transport23_results.json',import.meta.url),JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));
