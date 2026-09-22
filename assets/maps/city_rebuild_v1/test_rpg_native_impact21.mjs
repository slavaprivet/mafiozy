// Execute the production bridge, RPG resolver and HP callback. The fixture
// controls map/transport/FX only; damage and one-flight admission are real.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
function actual(name){const a=source.indexOf('function '+name+'(');assert(a>=0,name);return source.slice(a,source.indexOf('\n}',a)+2);}
const fireBridgeStart=source.indexOf('  fireWalkShot(request={}){');
const fireBridge=source.slice(fireBridgeStart,source.indexOf('\n  fire(angle, muzzleR, muzzleC)',fireBridgeStart));
function fixture(){
 let now=5000;const timers=[],bullets=[],sent=[],noop=()=>{},c={performance:{now:()=>now},Math:Object.create(Math),QP:{uid:'local'},player:{r:0,c:0},myDead:true,myDrivingCarId:null,CARS:[],cityCops:[],_bankInt:null,_buildingInt:null,beachgoers:new Map(),currentWeapon:'rpg',
  _walkShotContext:null,_walkMeleeDamageContext:null,_walkPendingShots:new Map(),_authoritativeShotId:'rocket1',_authoritativeTargetClaims:new Set(),_pendingBallisticFxTimers:0,_serverAuthoritativeAmmo:false,ws:{readyState:1,send:message=>sent.push(JSON.parse(message))},
  resolveWeapon:w=>w,_walkRendererActive:()=>true,_isArmed:()=>true,weaponsForPick:()=>[{id:c.currentWeapon}],
  weaponProfile:()=>({dmg:160,bulletSpeed:15}),isBlocked:()=>false,_usesPooled3DFx:()=>true,_explosionSound:noop,_capArr:noop,explosionBursts:[],impacts:[],_MAX_IMPACTS:100,bloodSplats:[],_MAX_BLOOD:100,
  _damageCasinoPropsInRadius:()=>0,_currentShotDamage:x=>x,spawnImpact:noop,_showCurrentShotCritical:noop,addShake:noop,hapticHit:noop,
  _markCombatBleeding:noop,_walkConfirmDamage:noop,_npcPathPassable:()=>true,_npcRememberAggression:noop,_npcSpreadRumor:noop,npcCivilianUnarmed:()=>false,_npcTrySurrenderAfterHit:()=>false,_registerMurderIncident:noop,_respawnResidentImmediately:noop,spawnFloatText:noop,
  setTimeout:(fn,delay)=>{timers.push({fn,delay});},spawnBullet:(...args)=>bullets.push(args)};
 c.Math.random=()=>.99;const npc={id:'near-impact',r:1,c:1,hp:1000};c.NPCS=[npc];
 vm.createContext(c);vm.runInContext(['_walkShotAllows','_walkShotPhysicalContact','_weaponWallDistance','_projectTargetOnRay','_localBallisticTargets','_scheduleBallisticFx','_fireRpgRound','_spawnRpgExplosion','hitNpc','_walkImpactRpg','_sendWorldWeaponFire','_reserveAuthoritativeTargetClaim','_sendRemoteWeaponHit'].map(actual).join('\n'),c);
 vm.runInContext('globalThis.bridge={getPlayerState(){return {magazine:1};},'+fireBridge+'};',c);
 function launch({pitch=0,angle=0,range=15,remote=null,request={}}={}){
  const ctx={request:{nativeRpgImpact:true,muzzleR:0,muzzleC:0,muzzleY:1.5,pitch,...request},at:now,angle,pitch,range,ref:null,contact:null,shotId:c._authoritativeShotId,confirmed:false};
  c._walkShotContext=ctx;c._walkPendingShots.set(ctx.shotId,ctx);c._fireRpgRound(0,0,Math.sin(angle),Math.cos(angle),range,remote);c._walkShotContext=null;return ctx;
 }
 return {c,npc,timers,bullets,sent,launch,advance:ms=>{now+=ms;},impact:point=>c.bridge.impactWalkRpg({shotId:'rocket1',point})};
}
test('native no-contact ground impact damages nearby local NPC once at actual 3D endpoint, without a legacy timer',()=>{
 const f=fixture(),pitch=-Math.atan2(1.5,4.1),ctx=f.launch({pitch});
 assert(Object.isFrozen(ctx.rpgFlight));assert(Object.isFrozen(ctx.rpgFlight.origin));assert(Object.isFrozen(ctx.rpgFlight.direction));
 assert.equal(f.timers.length,0);assert.equal(f.bullets.length,0);assert.equal(f.npc.hp,1000);
 const retained={ref:null,request:{resolveContact:()=>null}};f.c._walkShotContext=retained;f.c._authoritativeShotId='another-weapon-shot';
 assert.equal(f.impact({x:4.1,y:0,z:0}).accepted,true);assert(f.npc.hp<1000);assert.equal(f.c.explosionBursts[0].c,1);
 assert.equal(f.c._walkShotContext,retained);assert.equal(f.c._authoritativeShotId,'another-weapon-shot');
 const hp=f.npc.hp;assert.equal(f.impact({x:4.1,y:0,z:0}).reason,'duplicate');assert.equal(f.npc.hp,hp);assert.equal(f.c.explosionBursts.length,1);
});
test('direct-contact launch does not restrict area victims at impact',()=>{
 const f=fixture(),other={id:'splash',r:1.2,c:1,hp:1000};f.c.NPCS.push(other);const ctx=f.launch({angle:Math.PI/4});
 ctx.ref=f.npc;ctx.contact={point:{x:4.1,y:1.5,z:4.1}};ctx.request.resolveContact=()=>ctx.contact;
 f.c._walkShotContext=ctx;assert.equal(f.c._localBallisticTargets('rpg').length,1);
 assert.equal(f.impact({x:4.1,y:1.5,z:4.1}).accepted,true);assert(f.npc.hp<1000);assert(other.hp<1000);assert.equal(f.c._walkShotContext,ctx);
});
test('invalid, behind, off-axis, out-of-range, expired and foreign-scene endpoints never damage',()=>{
 for(const [label,point,setup,reason] of [
  ['nonfinite',{x:NaN,y:1.5,z:0},null,'point'],['missing',null,null,'point'],
  ['backwards',{x:-1,y:1.5,z:0},null,'trajectory'],['sideways',{x:4.1,y:1.5,z:1},null,'trajectory'],['height',{x:4.1,y:5,z:0},null,'trajectory'],
  ['too far',{x:61.61,y:1.5,z:0},null,'trajectory'],['expired',{x:4.1,y:1.5,z:0},f=>f.advance(15001),'expired'],
  ['clock reversal',{x:4.1,y:1.5,z:0},f=>f.advance(-1),'expired'],['scene changed',{x:4.1,y:1.5,z:0},f=>{f.c._bankInt={npcs:[]};},'scene']
 ]){const f=fixture();f.launch();setup?.(f);assert.equal(f.impact(point).reason,reason,label);assert.equal(f.npc.hp,1000,label);assert.equal(f.c.explosionBursts.length,0,label);}
 const f=fixture();assert.equal(f.impact({x:0,y:0,z:0}).reason,'unknown-flight');f.c._walkPendingShots.set('rocket1',{weapon:'pistol',at:5000});assert.equal(f.impact({x:0,y:0,z:0}).reason,'unknown-flight');
});
test('accepted range endpoint and 15-second boundary are supported; mutable caller damage/radius are ignored',()=>{
 const f=fixture();f.npc.r=0;f.npc.c=15;const ctx=f.launch();ctx.request.muzzleY=900;ctx.request.pitch=1;ctx.request.damage=99999;ctx.request.range=99999;
 f.advance(15000);assert.equal(f.c.bridge.impactWalkRpg({shotId:'rocket1',point:{x:61.5,y:1.5,z:0},damage:99999,radius:999}).accepted,true);
 assert.equal(f.npc.hp,840);assert.equal(ctx.rpgFlight.origin.y,1.5);assert.equal(ctx.rpgFlight.range,15);
});
test('resolver exception consumes flight and restores context and shot identity atomically',()=>{
 const f=fixture(),ctx=f.launch(),retained={unrelated:true};f.c._walkShotContext=retained;f.c._authoritativeShotId='later';f.c._spawnRpgExplosion=()=>{throw Error('fixture damage failure');};
 assert.throws(()=>f.impact({x:4.1,y:1.5,z:0}),/fixture damage failure/);assert.equal(ctx.rpgImpactConsumed,true);assert.equal(f.c._walkShotContext,retained);assert.equal(f.c._authoritativeShotId,'later');assert.equal(f.impact({x:4.1,y:1.5,z:0}).reason,'duplicate');
});
test('authenticated accounting stays at one existing impact claim, with no new launch claim or replay',()=>{
 const f=fixture();f.c._serverAuthoritativeAmmo=true;f.launch();assert.equal(f.sent.length,0);f.impact({x:4.1,y:1.5,z:0});assert.equal(f.sent.length,1);assert.equal(f.sent[0].t,'weapon_fire');assert.equal(f.sent[0].d.shot_id,'rocket1');f.impact({x:4.1,y:1.5,z:0});assert.equal(f.sent.length,1);
 const g=fixture();g.c._serverAuthoritativeAmmo=true;const remote={kind:'cop',id:'server-cop',r:0,c:1};const ctx=g.launch({remote});remote.id='mutated';assert(Object.isFrozen(ctx.rpgFlight.remote));g.impact({x:4.1,y:1.5,z:0});assert.equal(g.sent.length,1);assert.equal(g.sent[0].t,'cop_shoot');assert.equal(g.sent[0].d.target,'server-cop');assert.equal(g.sent[0].d.shot_id,'rocket1');
});
test('native bridge rejects malformed launch before ammo admission, and bounds retained receipts',()=>{
 const f=fixture();let admitted=0;f.c._threeBridgeFireAccepted=()=>{admitted++;return false;};
 const valid={nativeRpgImpact:true,angle:0,pitch:0,muzzleR:0,muzzleC:0,muzzleY:1.5};
 for(const bad of [{muzzleY:undefined},{muzzleY:Infinity},{pitch:NaN},{pitch:Math.PI},{muzzleR:NaN},{muzzleC:5}])assert.equal(f.c.bridge.fireWalkShot({...valid,...bad}).accepted,false);
 assert.equal(admitted,0);f.c.currentWeapon='pistol';assert.equal(f.c.bridge.fireWalkShot(valid).accepted,false);assert.equal(admitted,0);f.c.currentWeapon='rpg';
 for(let i=0;i<600;i++)f.c._walkPendingShots.set('old'+i,{at:5000});
 assert.equal(f.c.bridge.fireWalkShot(valid).accepted,false);assert.equal(admitted,1);assert(f.c._walkPendingShots.size<512);
 f.c._threeBridgeFireAccepted=()=>{const ctx=f.c._walkShotContext;ctx.shotId='rocket1';ctx.angle=.25;ctx.pitch=-.2;ctx.range=15;f.c._walkPendingShots.set(ctx.shotId,ctx);f.c._fireRpgRound(0,0,Math.sin(.25),Math.cos(.25),15,null);return true;};
 const receipt=f.c.bridge.fireWalkShot(valid);assert.equal(receipt.accepted,true);assert.equal(receipt.nativeRpgImpact,true);assert.equal(receipt.range,15);assert.equal(receipt.angle,.25);assert.equal(receipt.pitch,-.2);assert(f.c._walkPendingShots.size<=512);
});
test('production fire blocks bypass both legacy walls and pump/car direct returns only for opted-in RPG',()=>{
 const start=source.indexOf('  const nativeRpgShot=resolvedShotWeapon'),end=source.indexOf('\n  // В тюрьме NPC-цели',start),rangeBlock=source.slice(start,end);
 const dispatchStart=source.indexOf('  const range = shotRange;',end),dispatchEnd=source.indexOf('\n  const propRange=',dispatchStart),dispatchBlock=source.slice(dispatchStart,dispatchEnd);
 for(const native of [true,false]){
  const calls=[],noop=()=>{},c={_walkShotContext:{request:{nativeRpgImpact:native,resolveContact:noop}},resolvedShotWeapon:'rpg',shotRange:15,player:{r:0,c:0},dirY:0,dirX:1,currentWeapon:'rpg',_weaponWallDistance:()=>{calls.push('wall');return .3;},_walkResolveShotContact:(a,r)=>calls.push(['contact',r]),_walkShotPhysicalContact:()=>null,
   resolveWeapon:w=>w,_remoteBallisticTarget:()=>null,chosenConvoy:null,chosenCop:null,chosenAggro:null,chosenMg:null,pvpTarget:null,sR:0,sC:0,
   hitGasPump:{point:{r:0,c:.2}},hitDamageableCar:{point:{r:0,c:.1},dist:.1},_fireRpgRound:()=>calls.push('rpg'),spawnBullet:noop,_hitGasPump:()=>calls.push('gas'),triggerHitStop:noop,addShake:noop,hapticHit:noop,_sendWorldWeaponFire:noop};
  vm.createContext(c);vm.runInContext('(function(){'+rangeBlock+dispatchBlock+'})()',c);
  assert.equal(c.shotRange,native?15:.3);assert.equal(calls.includes('rpg'),native);assert.equal(calls.includes('gas'),!native);assert.equal(calls.includes('wall'),!native);
 }
});
if(process.env.RPG_IMPACT_COST==='1')test('CPU before/after: same 64 local recipients, direct resolver versus validated native impact',()=>{
 const f=fixture(),samples={direct:[],native:[]};f.c.NPCS=Array.from({length:64},(_,i)=>({id:'cost-'+i,r:i%8*.1,c:1+Math.floor(i/8)*.1,hp:1e7}));
 const reset=()=>{for(let i=0;i<64;i++)Object.assign(f.c.NPCS[i],{r:i%8*.1,c:1+Math.floor(i/8)*.1,hp:1e7});f.c.explosionBursts.length=0;f.c.impacts.length=0;};
 for(let i=0;i<160;i++)for(const kind of i%2?['native','direct']:['direct','native']){
  reset();if(kind==='native')f.launch();const start=performance.now();
  if(kind==='native')assert.equal(f.impact({x:4.1,y:1.5,z:0}).accepted,true);else f.c._spawnRpgExplosion(0,1,null,'rpg','rocket1');
  const elapsed=performance.now()-start;if(i>=30)samples[kind].push(elapsed);
  assert(f.c.NPCS.every(n=>n.hp<1e7));
 }
 const summary={};for(const [kind,values]of Object.entries(samples)){values.sort((a,b)=>a-b);summary[kind]={p50:values[Math.floor(values.length*.5)],p95:values[Math.floor(values.length*.95)],samples:values.length};}
 console.log('RPG source CPU 64 recipients, milliseconds:',JSON.stringify(summary));
});
