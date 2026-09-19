import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import {performance} from 'node:perf_hooks';
const source=fs.readFileSync('world.html','utf8').replace(/\r\n/g,'\n');
function fn(name,text=source){const a=text.indexOf(`function ${name}(`);assert.ok(a>=0,name);return text.slice(a,text.indexOf('\n}',a)+2);}
let now=10000,wall=false,rays=0,sent=0;
const npc=(extra={})=>({id:'resident_test',r:0,c:0,ang:0,speed:.4,_arc:{panicMult:2},...extra});
const e={Math,Number,String,performance:{now:()=>now},NPCS:[],player:{r:0,c:4},myDead:false,_buildingInt:null,_bankInt:null,myDrivingCarId:null,
 _isArmed:()=>true,_npcLifeEligible:n=>!!n&&!n._guard,_policeWorldLineClear:()=>{rays++;return !wall;},
 _npcCancelHelping:()=>{},_npcCancelSocial:()=>{},_npcSpeechSlots:()=>1,_npcSetLifeState:()=>{},_npcRememberEvent:()=>{},
 _npcPanicStyle:()=> 'flee',_npcStableUnit:()=>0,_clearNpcRoute:()=>{},NPC_LIFE_STATES:{PANIC:'panic',ALERT:'alert'},NPC_LIFE_EVENT_PRIORITY:{bullet:60,fight:20},
 _lastSnitchReportAt:0,ws:{readyState:1,send:()=>sent++},showToast:()=>{},currentWeapon:'pistol'};
vm.createContext(e);
for(const name of ['_npcPerceptionHeight','_npcPerceptionTargetHeight','_npcCanSeePoint','_npcCanHearPoint','_npcWitnessAble','_npcCanWitnessEvent','_npcBeginPanic','markNpcSnitch','_npcQueueWitnessCall','_npcAdvanceWitnessRetreat','_npcSensePlayerWeapon','_snitchReport','_npcCancelInterruptedWitness','_npcFinishWitnessCall'])vm.runInContext(fn(name),e);
assert.equal(e._npcCanSeePoint(npc(),0,7,8),true);
assert.equal(e._npcCanSeePoint(npc(),0,-2,8),false,'Back-facing actor cannot identify a visible crime');
assert.equal(e._npcCanSeePoint(npc(),7,0,8),false,'Outside 140-degree FOV');
assert.equal(e._npcCanSeePoint(npc(),0,8.01,8),false);
wall=true;assert.equal(e._npcCanSeePoint(npc(),0,.2,8),false,'Even point blank wall blocks visual');
assert.equal(e._npcCanHearPoint(npc(),0,-3,9),true,'Close shot heard through wall and behind');
assert.equal(e._npcCanHearPoint(npc(),0,5,9),false,'Muffled distant shot not heard');wall=false;
assert.equal(e._npcCanHearPoint(npc(),0,-8,9),true,'Hearing is not FOV');
e._walkNpcPerceptionResolver=()=>({blocked:true});assert.equal(e._npcCanSeePoint(npc(),0,2,8),false,'Native geometry blocks tile-clear space');assert.equal(e._npcCanHearPoint(npc(),0,6,9),false,'Native facade muffles distant shot');assert.equal(e._npcCanHearPoint(npc(),0,3,9),true,'Close muffled shot remains audible');e._walkNpcPerceptionResolver=null;
assert.equal(e._npcCanSeePoint(npc({_residentIndoors:true}),0,2),false,'Local interior coordinates not outdoor witnesses');
for(const role of ['police','cop','guard','gang','boss'])assert.equal(e._npcCanWitnessEvent(npc({role}),now),false,role);
let n=npc();e.NPCS=[n];e._npcSensePlayerWeapon(n,now);assert.equal(!!n.snitching,false,'Observe weapon before calling');
now+=1700;wall=true;e._npcSensePlayerWeapon(n,now);assert.equal(n._weaponSeenSince,0,'Loss of sight resets exposure');wall=false;
e._npcSensePlayerWeapon(n,now);now+=1700;e._npcSensePlayerWeapon(n,now);assert.equal(n._witnessStage,'escaping');assert.equal(n._witnessReportKind,'weapon_display');
e._npcAdvanceWitnessRetreat(n,now+1000);assert.equal(n._witnessStage,'escaping','Must actually retreat, no timer-only early safety');
n.c=-.8;e._npcAdvanceWitnessRetreat(n,now+1000);assert.equal(n._witnessStage,'calling');assert.equal(n.panicUntil,0);
now=n._witnessCallUntil;e._npcFinishWitnessCall(n,now);assert.equal(sent,0,'Weapon display is not fabricated open_fire');assert.equal(n.snitching,true,'No adapter/ACK must not claim a successful report');
let suspicion=0;e._npcReportSuspicion=w=>{assert.equal(w._witnessReportKind,'weapon_display');suspicion++;return true;};now+=300;e._npcFinishWitnessCall(n,now);assert.equal(suspicion,1);assert.equal(n._witnessStage,'reported');
now+=1000;e._npcSensePlayerWeapon(n,now);assert.equal(n.snitching,false,'No repeated report in same armed encounter');
assert.equal(e._npcQueueWitnessCall(n,now,0,4),false,'Crime report cooldown prevents per-shot call loop');
const blocked=npc({id:'resident_blocked'});e.NPCS=[blocked];e._npcQueueWitnessCall(blocked,now,0,1);e._npcAdvanceWitnessRetreat(blocked,now+3501);assert.equal(blocked._witnessStage,'calling','Blocked retreat ends safely in place');assert.equal(blocked.r,0);assert.equal(blocked.c,0);
const a=npc({id:'a'}),b=npc({id:'b'}),c=npc({id:'c'});e.NPCS=[a,b,c];assert.equal(e._npcQueueWitnessCall(a,now,0,4),true);assert.equal(e._npcQueueWitnessCall(b,now,0,4),true);assert.equal(e._npcQueueWitnessCall(c,now,0,4),false,'Bounded two active callers');
a.dead=true;e._npcFinishWitnessCall(a,now);assert.equal(a._witnessStage,'interrupted');
const samples=[];e.NPCS=Array.from({length:72},(_,i)=>npc({id:`resident_${i}`,r:i%9,c:Math.floor(i/9),ang:(i%4)*Math.PI/2}));
// Comparable visual scan baseline: previous radius+LOS vs FOV+radius+LOS, 72 residents/one event.
function bench(visual){const values=[];rays=0;for(let warm=0;warm<100;warm++)for(const n of e.NPCS)visual(n);rays=0;for(let i=0;i<2000;i++){const t=performance.now();for(const n of e.NPCS)visual(n);values.push(performance.now()-t);}values.sort((a,b)=>a-b);return {p50ms:+values[1000].toFixed(4),p95ms:+values[1900].toFixed(4),losPerEvent:rays/2000};}
vm.runInContext('function baselineVisual(n){return Math.hypot(n.r-4,n.c-4)<=8&&_policeWorldLineClear(n.r,n.c,4,4);}',e);
const before=bench(n=>e.baselineVisual(n));
const after=bench(n=>e._npcCanSeePoint(n,4,4,8));
console.log(JSON.stringify({result:'PASS',checks:'FOV, LOS, acoustic attenuation, cop exclusion, weapon exposure, no fake shots, retreat/contact, interrupted call, bounded callers/cooldowns',cpu:{scenario:'72 residents, one visual event, 2000 samples; stub LOS (CPU microbenchmark, not game FPS)',before,after}},null,2));
