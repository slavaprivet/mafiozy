import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const s=fs.readFileSync('world.html','utf8');for(const m of s.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi))if(!/type=['"](?:module|importmap|application\/json)/.test(m[1])&&m[2].trim())new vm.Script(m[2]);
const block=s.slice(s.indexOf('const PUNCH_CD_MS'),s.indexOf('let _policeBatonAnim'));
const punch=s.slice(s.indexOf('function punch(force,'),s.indexOf('// ── Бандит/враждебный NPC'));
const methods=s.slice(s.indexOf('  setWalkMeleeCharge(active)'),s.indexOf('  getWalkWeaponOptions(){'));
const confirm=s.slice(s.indexOf('function _walkConfirmDamage('),s.indexOf('function _walkConfirmServerHit('));
let now=10000,hits=0,events=[],timers=[];const npc={r:0,c:1,hp:100},view={r:0,c:1};
const c={performance:{now:()=>now},Math:Object.create(Math),document:{documentElement:{dataset:{}}},window:{dispatchEvent:e=>events.push(e)},CustomEvent:class{constructor(type,data){this.type=type;Object.assign(this,data)}},_UP:new URLSearchParams(),_LOCAL_PREVIEW:false,myMode:'pvp',myDead:false,_meleeStunnedIn:0,_murderPoliceArrest:null,_onlinePoliceArrest:null,myDrivingCarId:null,myJetSkiId:null,_playerSwimmingDeep:false,_inBus:false,chatOpen:false,_gameMenuOpen:false,armed:false,player:{r:0,c:0,ang:0},lockedTargets:new Set(),ws:{readyState:1,send(){}},_walkRendererActive:()=>true,_effectivePlayerStance:()=> 'stand',_isArmed:()=>c.armed,_findLaserTarget:()=>{throw Error('2D fallback forbidden')},getActiveTarget:()=>{throw Error('2D fallback forbidden')},_findNearestMeleeTarget:()=>{throw Error('2D fallback forbidden')},_meleeTargetIsProne:()=>false,_meleeTargetNpcRef:t=>t?._ref||null,_npcConsiderMeleeBlock:()=>{},_meleeLineClear:()=>true,_fireBtn:{classList:{add(){},remove(){}}},addKick(){},_renewAllLocks(){},setTimeout:f=>timers.push(f),NPCS:[npc],cityCops:[],_bankInt:null,beachgoers:new Map(),_busRiders:[],_busWaiters:[],_parkingNpcs:[],_walkShotNativeRef:id=>id==='npc1'?npc:null,_threeNpcActionRefs:new Map([['npc1',{view}]]),_walkShotContext:null,_walkPendingShots:new Map(),hitNpc:(ref,y,x,weapon,dmg)=>{hits++;ref.hp-=dmg;c._walkConfirmDamage(ref,dmg)},spawnFloatText(){},triggerHitStop(){},addShake(){},hapticHit(){},_alertNearbyCops(){},_npcTriggerFight(){},triggerWitnessChain(){}};
vm.createContext(c);vm.runInContext(block+'\n'+punch+'\n'+confirm+'\nthis.bridge={'+methods+'};',c);c.Math.random=()=>.8;
const hit={npcId:'npc1',point:{x:4.1,y:1.2,z:0},normal:{x:-1,y:0,z:0}};
let a=c.bridge.beginWalkMelee({angle:0});assert(a.accepted&&a.type==='punch');assert.equal(hits,0);assert.equal(timers.length,1,'only UI cooldown timer; damage is deferred');assert.equal(c.bridge.resolveWalkMelee({seq:a.seq,contact:hit}).reason,'early');now+=70;assert(c.bridge.resolveWalkMelee({seq:a.seq,contact:null}).accepted);assert.equal(hits,0);assert.equal(c.bridge.resolveWalkMelee({seq:a.seq,contact:hit}).reason,'sequence');
now+=400;a=c.bridge.beginWalkMelee({angle:0});now+=70;assert(c.bridge.resolveWalkMelee({seq:a.seq,contact:hit}).confirmed);assert.equal(hits,1);assert.equal(events[0].detail.kind,'melee');assert.deepEqual({...events[0].detail.point},hit.point);
now+=400;c.armed=true;assert(!c.bridge.beginWalkMelee({angle:0}).accepted);c.armed=false;assert(!c.bridge.beginWalkMelee({angle:0,heavy:true}).accepted);c.bridge.setWalkMeleeCharge(true);now+=1100;assert(!c.bridge.beginWalkMelee({angle:0,heavy:true}).accepted);now+=110;a=c.bridge.beginWalkMelee({angle:0,heavy:true});assert(a.accepted&&a.type==='heavy');now+=600;assert(!c.bridge.beginWalkMelee({angle:0,heavy:true}).accepted,'one heavy per hold');
c.Math.random=()=>0;a=c.bridge.beginWalkMelee({angle:0});assert.equal(a.type,'kick');now+=400;a=c.bridge.beginWalkMelee({angle:0,airborne:true});assert.equal(a.type,'dropkick');npc._meleeBlockUntil=now+1000;now+=200;const result=c.bridge.resolveWalkMelee({seq:a.seq,contact:hit});assert(result.confirmed&&result.blocked);assert.equal(events.at(-1).detail.knockdown,false);assert(!npc._meleeStunnedUntil);
now+=400;a=c.bridge.beginWalkMelee({angle:0});now+=500;assert.equal(c.bridge.resolveWalkMelee({seq:a.seq,contact:hit}).reason,'expired-or-locked');
console.log('PASS world melee: all inline syntax, no 2D fallback, deferred physical contact, one-shot miss, charge1200, one heavy, source kick, blocked dropkick, expired contact');

// Remote NPCs are admitted by the server protocol, never the local HP path.
const remote={id:'cop42',x:1,y:0,hp:100,alive:true},sent=[];
Object.assign(c,{worldCops:[remote],michaelGuards:new Map(),worldEvent:null,aggroZones:{},gangNests:[],QP:{uid:'7'},sendInput(){},_newCombatEventId:()=>`nonce-${sent.length}`});
c._walkShotNativeRef=id=>id==='npc_world_cop_cop42'?remote:null;c._threeNpcActionRefs.set('npc_world_cop_cop42',{view:{r:0,c:1}});c.ws.send=value=>sent.push(JSON.parse(value));
vm.runInContext(s.slice(s.indexOf('function _walkConfirmServerHit('),s.indexOf('function _threeBridgeFireAccepted(')),c);
c.Math.random=()=>.8;now+=400;a=c.bridge.beginWalkMelee({angle:0});now+=70;
const remoteHit={...hit,npcId:'npc_world_cop_cop42'},eventCount=events.length,pending=c.bridge.resolveWalkMelee({seq:a.seq,contact:remoteHit});
assert(pending.accepted&&pending.pending&&!pending.confirmed);assert.equal(remote.hp,100);assert.equal(events.length,eventCount);
const request=sent.find(message=>message.t==='melee_hit');assert(request);assert.deepEqual(Object.keys(request.d).sort(),['attack_id','heavy','id','kind']);assert.equal(request.d.kind,'cop');
let ack={melee:true,kind:'cop_hit',attack_id:request.d.attack_id,shooter_uid:'7',cop_id:'cop42',dmg:12,blocked:false,heavy:false,stunned:false};
assert(!c._walkConfirmServerHit({...ack,shooter_uid:'other'}));assert(!c._walkConfirmServerHit({...ack,cop_id:'different'}));assert(!c._walkConfirmServerHit({...ack,replayed:true}));assert.equal(events.length,eventCount);
assert(c._walkConfirmServerHit(ack));assert.equal(events.at(-1).detail.shotId,`walk-melee:${a.seq}`);assert.equal(events.at(-1).detail.kind,'melee');assert(!c._walkConfirmServerHit(ack));
// Keep the server charge until the earned heavy reaches its physical contact.
now+=400;c.bridge.setWalkMeleeCharge(true);now+=1210;const startIndex=sent.length;a=c.bridge.beginWalkMelee({angle:0,heavy:true});assert(a.accepted);c.bridge.setWalkMeleeCharge(false);assert.equal(sent.length,startIndex,'input release cannot cancel accepted heavy before contact');now+=120;
assert(c.bridge.resolveWalkMelee({seq:a.seq,contact:remoteHit}).pending);const tail=sent.slice(startIndex);assert.equal(tail[0].t,'melee_hit');assert.equal(tail[0].d.heavy,true);assert.equal(tail[1].t,'melee_charge');assert.equal(tail[1].d.active,false);
// Airborne is a local visual until a server-owned jump window exists.
now+=400;a=c.bridge.beginWalkMelee({angle:0,airborne:true});now+=200;assert(c.bridge.resolveWalkMelee({seq:a.seq,contact:remoteHit}).pending);const airborne=sent.at(-1);assert.equal(airborne.t,'melee_hit');assert.equal(airborne.d.heavy,false);
ack={...ack,attack_id:airborne.d.attack_id};assert(c._walkConfirmServerHit(ack));assert.equal(events.at(-1).detail.knockdown,false);assert.equal(events.at(-1).detail.super,false);
console.log('PASS remote NPC melee: no optimistic HP/blood, own actor-target-attack ACK, replay dedupe, unique network identity/stable visual identity, deferred charge release, no client-airborne damage promotion');


