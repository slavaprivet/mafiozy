import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source=fs.readFileSync(process.argv[2]||new URL('./world.html',import.meta.url),'utf8').replace(/\r\n/g,'\n');
function fn(name){const start=source.indexOf(`function ${name}(`);assert.ok(start>=0,name);return source.slice(start,source.indexOf('\n}',start)+2);}
let now=10000,reports=[],toasts=[],rep=0,clear=true,social=0;
const sandbox={performance:{now:()=>now},Math:Object.assign(Object.create(Math),{random:()=>0}),NPCS:[],
  _characterSkills:{stealth:0},_districtWitnessChance:x=>x,_lastDistrictCrimeRepAt:0,
  _districtRepAdd:()=>rep++,_recoverNpcFromCollision:()=>{},_npcLifeEligible:n=>!!n,
  _policeWorldLineClear:()=>clear,_npcCancelHelping:()=>{},_npcCancelSocial:()=>social++,
  _npcSpeechSlots:()=>2,_npcPanicStyle:()=> 'cower',_npcStableUnit:()=>0,
  NPC_LIFE_EVENT_PRIORITY:{bullet:60,fight:20},NPC_LIFE_STATES:{COWER:'cower',PANIC:'panic'},
  _npcRememberEvent:()=>{},_npcSetLifeState:()=>{},_clearNpcRoute:()=>{},
  _lastSnitchReportAt:0,ws:{readyState:1,send:s=>reports.push(JSON.parse(s))},
  player:{r:1,c:2},currentWeapon:'fists',showToast:s=>toasts.push(s)};
vm.createContext(sandbox);
const names=['_npcPerceptionHeight','_npcPerceptionTargetHeight','_npcCanSeePoint','_npcQueueWitnessCall','_npcAdvanceWitnessRetreat','markNpcSnitch','triggerWitnessChain','_snitchReport','_npcWitnessAble','_npcCancelInterruptedWitness','_npcFinishWitnessCall','_npcCanWitnessEvent','_npcBeginPanic'];
for(const name of names)if(source.includes(`function ${name}(`))vm.runInContext(fn(name),sandbox);
const npc=()=>({id:'resident_1',r:1,c:1,_arc:{panicMult:2}});
let n=npc();sandbox.NPCS=[n];clear=false;
sandbox.triggerWitnessChain(1,2,10,{snitchChance:1});
assert.equal(!!n.snitching,false,'A wall must prevent identifying the perpetrator');
assert.equal(rep,0,'No witness means no witnessed-crime reputation change');
clear=true;n.r=50;sandbox.triggerWitnessChain(1,2,10,{snitchChance:1});assert.equal(!!n.snitching,false,'Outside hearing/vision radius');
n.r=1;sandbox.NPCS=[{...npc(),dead:true,snitching:true,snitchUntil:99999},{...npc(),_medicalDowned:true,snitching:true,snitchUntil:99999},n];
sandbox.triggerWitnessChain(1,2,10,{snitchChance:1});assert.equal(n.snitching,true,'Incapacitated callers must not consume slots');
assert.equal(reports.length,0,'Beginning a call cannot report');
assert.equal(n._witnessStage,'escaping');n.c-=1;now=n._witnessRetreatUntil;sandbox._npcAdvanceWitnessRetreat(n,now);assert.equal(n._witnessStage,'calling');
now=n._witnessCallUntil-1;sandbox._npcFinishWitnessCall(n,now);assert.equal(reports.length,0);
now++;sandbox._npcFinishWitnessCall(n,now);assert.equal(reports.length,1);assert.equal(n._witnessStage,'reported');
sandbox._npcFinishWitnessCall(n,now);assert.equal(reports.length,1,'Completed call reports once');
assert.ok(!toasts.some(s=>s.includes('wanted +1')),'No fabricated server wanted acknowledgement');
for(const status of [{dead:true},{_medicalDowned:true},{_meleeStunnedUntil:99999},{_policeCuffed:true},{_fightingMelee:true}]){
  const interrupted={...npc(),snitching:true,_witnessStage:'calling',_witnessCallUntil:now-1,...status};
  sandbox._npcFinishWitnessCall(interrupted,now);assert.equal(interrupted.snitching,false);assert.equal(reports.length,1);
}
const retry={...npc(),snitching:true,_witnessStage:'calling',_witnessCallUntil:now};
sandbox._npcFinishWitnessCall(retry,now);assert.equal(retry.snitching,true,'Throttle must retain pending call');
now+=2501;sandbox.ws.readyState=3;sandbox._npcFinishWitnessCall(retry,now);assert.equal(reports.length,1,'Disconnected socket is not a successful call');
now+=201;sandbox.ws.readyState=1;sandbox._npcFinishWitnessCall(retry,now);assert.equal(reports.length,2);
const scared=npc();sandbox._npcBeginPanic(scared,now,now+5000,1,2,'bullet');const deadline=scared._panicCowerUntil,started=scared._panicStartedAt;
now+=850;sandbox._npcBeginPanic(scared,now,now+5000,1,2,'bullet');assert.equal(scared._panicCowerUntil,deadline);assert.equal(scared._panicStartedAt,started);assert.ok(social>0);
assert.equal(sandbox._npcBeginPanic(scared,now,now+5000,1,2,'fight'),false,'Lower priority cannot replace shots');
const update=source.slice(source.indexOf('function updateNpcs('));
const cancelAt=update.indexOf('_npcCancelInterruptedWitness(n,now);'),deadAt=update.indexOf('    if (n.dead)');
assert.ok(cancelAt>=0&&deadAt>cancelAt,'Cancel before dead/downed update early exits');
assert.ok(source.includes('if(_npcFinishWitnessCall(n,now))continue;'),'Actual world update must finish phone calls');

// Production panic sampling: a gunshot makes 90% of ordinary civilians flee,
// while preserving a small stable non-flight minority and all protected-role
// exclusions. Non-shot fights keep their existing archetype diversity.
const styleSandbox={performance:{now:()=>10000},_npcStableUnit:n=>n.u};vm.createContext(styleSandbox);vm.runInContext(fn('_npcPanicStyle'),styleSandbox);
for(const arc of ['worker','student','businessman','housewife','homeless','drunk','pensioner']){
  const samples=Array.from({length:100},(_,i)=>styleSandbox._npcPanicStyle({_arcKey:arc,u:(i+.5)/100},'bullet'));
  assert.equal(samples.filter(style=>style==='flee').length,90,arc+' gunshot flight rate');
  assert(samples.slice(90).every(style=>style==='freeze'||style==='cower'||style==='call'),arc+' keeps a bounded non-flight minority');
}
assert.notEqual(styleSandbox._npcPanicStyle({_arcKey:'drunk',u:.3},'fight'),'flee','ordinary fights retain archetype behaviour');
assert.equal(styleSandbox._npcPanicStyle({_arcKey:'drunk',u:.3},'fire'),'freeze','non-shot fire keeps archetype behaviour');
for(const protectedNpc of [{police:true},{isPolice:true},{_empireBoss:true},{_empireCrew:true},{role:'guard'},{role:'gang'},{role:'boss'}])assert.equal(sandbox._npcCanWitnessEvent({...npc(),...protectedNpc},now),false,'protected combat role never enters civilian gunshot panic');

// A physical hit may happen outside the ambient sound radius. Execute the
// production hit function with the production civilian-role policy and prove
// that only a living ordinary victim gets direct bullet panic.
const hitSandbox={performance:{now:()=>20000},Math:Object.assign(Object.create(Math),{random:()=>.5}),QP:{uid:'qa'},player:{r:0,c:0},_LOCAL_PREVIEW:false,_UP:new Map(),
  _walkConfirmDamage(){},_markCombatBleeding(){},_npcPathPassable:()=>true,_npcRememberAggression(){},_npcSpreadRumor(){},_npcTrySurrenderAfterHit:()=>false,_npcTriggerFight(){},
  _npcBeginPanic(n,at,until,r,c,kind){n.directPanic={at,until,r,c,kind};return true;},spawnFloatText(){},_registerMurderIncident(){},_respawnResidentImmediately(){},_capArr(){},bloodSplats:[],impacts:[],_MAX_BLOOD:20,_MAX_IMPACTS:20};
vm.createContext(hitSandbox);vm.runInContext(fn('npcCivilianUnarmed')+'\n'+fn('hitNpc'),hitSandbox);
const hitVictim=role=>({id:'resident_hit',r:0,c:12,hp:100,max_hp:100,role,_arc:{panicMult:1}});
const ordinary=hitVictim('civilian');hitSandbox.hitNpc(ordinary,0,1,'pistol',5,{kind:'player'});assert.equal(ordinary.directPanic?.kind,'bullet','a distant direct-hit civilian flees without relying on radius panic');
for(const role of ['police','guard','gang','boss']){const protectedVictim=hitVictim(role);hitSandbox.hitNpc(protectedVictim,0,1,'pistol',5,{kind:'player'});assert.equal(protectedVictim.directPanic,undefined,role+' keeps protected combat behaviour');}
console.log('PASS: visibility/range, finite phone completion, interruption, throttle/offline retry, 90% civilian gunshot flight, direct-hit flight, protected roles, world hooks');
