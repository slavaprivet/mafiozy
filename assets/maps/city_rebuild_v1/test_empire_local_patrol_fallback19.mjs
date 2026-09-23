import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {gunzipSync} from 'node:zlib';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture,sourceFunction} from './test_civilian_native_fixture.mjs';

const snapshot=JSON.parse(gunzipSync(fs.readFileSync(new URL('test_fixtures/native_static_collision19.json.gz',import.meta.url))));
const f=await createCivilianNativeFixture({snapshot}),b=f.box;
for(const name of ['_inEmpireRecruitmentYard','_empireBossPassable','_empireBossWaypointPassable','_empireTargetFootprintPassable23','_nearestEmpireWalkPoint','_empireBossWorkWaypoint','_empireActivityTarget','_empireBossReachedActivityTarget','_empireRecoverySide','_pauseEmpireMovementWatch','_empireMovementWatch','_empireLocalPatrolFallback'])vm.runInContext(sourceFunction(f.source,name),b);
b._npcEmpireById=new Map();b.SPECIALIST_NPCS=[];b._empireSpeak=()=>{};
const declarations=f.source.slice(f.source.indexOf('const _empireRoutePlanQueue=[];'),f.source.indexOf('function _empireCrewOrigin('));
vm.runInContext(declarations+sourceFunction(f.source,'_planEmpireRouteTo')+sourceFunction(f.source,'_processEmpireRoutePlanQueue'),b);
const start=f.source.indexOf('    if(n._empireBoss&&n._empireAction&&!n._fighting&&!n._hostile){'),end=f.source.indexOf('    // Сдающийся локальный бандит',start);
assert(start>0&&end>start);
vm.runInContext('globalThis.bossTick=(actor,dt,now)=>{for(const n of [actor]){'+f.source.slice(start,end)+'}};',b);
const actor=()=>({id:'local-patrol',r:7,c:164,walkPhase:0,speed:.8,hp:100,_empireBoss:true,_empireStyle:7,_empireWorkStep:7,_empireActivityBaseTarget:{r:7,c:164},_empireTarget:{r:7,c:164},_empireAction:{kind:'patrol',target_r:7,target_c:164},_empireActionKey:'patrol:local:1',_empireRouteGeneration:1,_empireArrivedGeneration:1,_empireActionArrived:true,_empireNextWorkMoveAt:f.now+1});
const reset=()=>vm.runInContext('_empireRoutePlanQueue.length=0;_npcRouteWorkQueue.clear();_npcRouteWorkBatch.clear();_npcRouteWorkBatchCount=0;_npcRouteWorkUsedMs=0;',b);
const fallback=b._empireLocalPatrolFallback;
const fallbackCpu=[];
function run(enabled,seedHistoricalGoal=true){
 reset();b._empireLocalPatrolFallback=enabled?((...args)=>{const start=performance.now();try{return fallback(...args);}finally{fallbackCpu.push(performance.now()-start);}}):undefined;
 const n=actor(),action=n._empireAction,base=n._empireActivityBaseTarget;let firstGoal=null,firstAlternative=null,arrivedAlternative=false,maxInstantMove=0;
 // The full-footprint nearest fix now avoids the old goal during new selection.
 // Retain the documented historical coordinates as an existing cached job to
 // exercise fallback itself; every route and movement still uses real geometry.
 if(seedHistoricalGoal){n._empireWorkStep=8;n._empireTarget={r:10.198526098792687,c:164.09711228213794};n._empireActionArrived=false;n._empireLocalPatrolTarget={generation:1,actionKey:n._empireActionKey,...n._empireTarget,baseR:7,baseC:164};}
 const oldEmpty=vm.runInContext('_empireRoutePlanTotals[5]',b);
 for(let frame=0;frame<3600;frame++){
  f.nextFrame();b.bossTick(n,.05,f.now);if(!firstGoal)firstGoal={...n._empireTarget};
  const before={r:n.r,c:n.c};b._processEmpireRoutePlanQueue(f.now);
  maxInstantMove=Math.max(maxInstantMove,Math.hypot(n.r-before.r,n.c-before.c));
  if(n._empirePatrolFallbacks&&!firstAlternative)firstAlternative={...n._empireTarget};
  if(firstAlternative&&Math.hypot(n.r-firstAlternative.r,n.c-firstAlternative.c)<1.05)arrivedAlternative=true;
 }
 assert.equal(n._empireAction,action);assert.equal(n._empireActivityBaseTarget,base);
 return {n,firstGoal,firstAlternative,arrivedAlternative,maxInstantMove,empty:vm.runInContext('_empireRoutePlanTotals[5]',b)-oldEmpty};
}
const before=run(false),after=run(true);
const prevention=run(false,false);
assert.equal(prevention.empty,0,'new production target selection avoids historical invalid endpoint');
assert(Math.hypot(prevention.n.r-7,prevention.n.c-164)>1,'new selection allows physical movement without fallback');
assert.equal(before.empty,45);assert.equal(before.n.r,7);assert.equal(before.n.c,164);assert.equal(before.n._empireWorkStep,8);
assert(b._empireBossWaypointPassable(before.firstGoal.r,before.firstGoal.c),'target endpoint alone is physically clear');
assert(f.pedestrian.query({mode:'sweep',from:{r:7,c:164},to:before.firstGoal,radius:.18}).blocked,'closed approach isolates endpoint');
assert(after.arrivedAlternative,'actual actor reaches a replacement local waypoint');
assert.equal(after.maxInstantMove,0,'planner and fallback never teleport actor');
assert(Math.hypot(after.firstAlternative.r-7,after.firstAlternative.c-164)<=3.200001);
assert(after.empty<before.empty);
b._empireLocalPatrolFallback=fallback;
function marked(){
 const n=actor();n._empireWorkStep=8;n._empireTarget={...before.firstGoal};n._empireActionArrived=false;
 n._empireLocalPatrolTarget={generation:1,actionKey:n._empireActionKey,...n._empireTarget,baseR:7,baseC:164};
 n._empireRouteRetryAt=f.now+4000;
 return n;
}
const request=n=>({kind:'empire_action',generation:1,targetKey:n._empireActionKey,goalR:n._empireTarget.r,goalC:n._empireTarget.c});
const protectedStates={_routeSearchPending:true,_empireActionArrived:true,dead:true,alive:false,_hiddenByEmpire:true,_fighting:true,_fightingMelee:true,_hostile:true,_empirePlayerWar:true,_empireEnemyLeaderId:'enemy',_empireCombatTarget:{},_empireFieldEncounterStatus:'active',_empireStreetNegotiation:{},_playerConversationOpen:true,_residentIndoors:true,_interiorId:'room',interior_id:'room',_insideBuilding:true,_residentNativeVisit:{},_civilianTrip:{},_civilianTripRiding:true,_responseVehicleId:'car',vehicleId:'car',vehicle_id:'car',_inVehicle:true,_inCar:true,_policeCuffed:true,_medicalDowned:true,_carriedByAmbulance:true,_evacuated:true,_knockedUntil:Infinity,_meleeStunnedUntil:Infinity,_empireDownUntil:Infinity,_empireHospitalUntil:Infinity};
for(const [key,value] of Object.entries(protectedStates)){
 const n=marked();n[key]=value;const target=n._empireTarget;reset();assert.equal(fallback(n,request(n),f.now),false,key);assert.equal(n._empireTarget,target,key);
}
for(const mode of ['initial','distant','raid','hq','business','escort','generation','action','goal','base']){
 const n=marked(),q=request(n),target=n._empireTarget;
 if(mode==='initial')delete n._empireLocalPatrolTarget;
 if(mode==='distant')n.r=100;
 if(mode==='raid')n._empireAction.kind='player_business_raid';
 if(mode==='hq')n._empireAction.kind='return_hq';
 if(mode==='business')n._empireAction.kind='inspect';
 if(mode==='escort')q.kind='empire_escort';
 if(mode==='generation')n._empireRouteGeneration++;
 if(mode==='action')n._empireActionKey='patrol:new';
 if(mode==='goal')q.goalR++;
 if(mode==='base')n._empireActivityBaseTarget.r++;
 reset();assert.equal(fallback(n,q,f.now),false,mode);assert.equal(n._empireTarget,target,mode);
}
const realPass=b._empireBossWaypointPassable;let candidateCalls=0;
b._empireBossWaypointPassable=()=>{candidateCalls++;return false;};
const unavailable=marked(),oldTarget=unavailable._empireTarget;reset();assert(!fallback(unavailable,request(unavailable),f.now));
assert(candidateCalls<=12);assert.equal(unavailable._empireTarget,oldTarget);assert.equal(unavailable._empireRouteRetryAt,f.now+4000);
b._empireBossWaypointPassable=realPass;
const blocked=marked(),blockedTarget=blocked._empireTarget;
b.patrolBlockedSweep=q=>q.mode==='sweep'?{swept:true,blocked:true}:f.pedestrian.query(q);
vm.runInContext('_walkNpcNavigationResolver=patrolBlockedSweep;',b);reset();assert(!fallback(blocked,request(blocked),f.now));assert.equal(blocked._empireTarget,blockedTarget,'solid sweep veto');
vm.runInContext('_walkNpcNavigationResolver=nativePedestrianQuery;',b);
reset();vm.runInContext('_npcRouteWorkUsedMs=4;',b);const exhausted=marked();assert(!fallback(exhausted,request(exhausted),f.now),'no extra work after frame budget');
console.log(JSON.stringify({pass:true,before:{seconds:180,empty:before.empty,position:{r:before.n.r,c:before.n.c},goal:before.firstGoal},after:{empty:after.empty,firstAlternative:after.firstAlternative,arrivedAlternative:after.arrivedAlternative,fallbacks:after.n._empirePatrolFallbacks},fallbackCpuMs:fallbackCpu,protectedStates:Object.keys(protectedStates).length,limits:f.limits},null,2));
