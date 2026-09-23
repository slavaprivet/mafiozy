import assert from 'node:assert/strict';
import vm from 'node:vm';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture,sourceFunction} from './test_civilian_native_fixture.mjs';

const f=await createCivilianNativeFixture(),b=f.box;
b.BEACH_R0=145;
for(const name of ['_inEmpireRecruitmentYard','_empireBossPassable','_empireBossWaypointPassable','_empireTargetFootprintPassable23','_nearestEmpireWalkPoint','_uniqueNpcCityPassable','_uniqueNpcSafeCityPoint','_uniqueNpcPlacementRecoveryAllowed'])vm.runInContext(sourceFunction(f.source,name),b);
const start=f.source.indexOf('    if((n?._uniqueNpc||n?._said)&&'),end=f.source.indexOf('    if (n.dead)',start);
assert(start>0&&end>start);
vm.runInContext('globalThis.placementTick=(n,now)=>{'+f.source.slice(start,end)+'};',b);
const leila=()=>({id:'leila',_uniqueNpc:true,_empireBoss:true,r:24.95,c:23.49,tr:28,tc:24,_empireAction:{kind:'patrol'},_empireTarget:{r:28,c:24},_route:[{r:25.5,c:23.5}],_routeKind:'empire_action'});
assert(b._empireBossPassable(24.95,23.49),'reported center is dry');
assert(!b._empireBossWaypointPassable(24.95,23.49),'body overlaps native water');
const n=leila(),order=n._empireAction,target=n._empireTarget;
const before={r:n.r,c:n.c},t0=performance.now();b.placementTick(n,1000);const recoveryMs=performance.now()-t0;
assert(b._empireBossWaypointPassable(n.r,n.c));
assert(Math.hypot(n.r-before.r,n.c-before.c)<=2);
assert.equal(n.r,25.5);assert.equal(n.c,23.5);
assert.equal(n._empireAction,order);assert.equal(n._empireTarget,target);assert.equal(n.id,'leila');
assert(!n._route?.length,'stale path discarded, order retained');
const recovered={r:n.r,c:n.c};
for(let i=1;i<=200;i++){f.nextFrame();b.placementTick(n,1000+i*50);}
assert.deepEqual({r:n.r,c:n.c},recovered,'no repeated displacement');
const marat={...leila(),id:'marat',r:75,c:34.54};const maratRoute=marat._route;
assert(b._empireBossWaypointPassable(marat.r,marat.c));b.placementTick(marat,20000);
assert.equal(marat.r,75);assert.equal(marat.c,34.54);assert.equal(marat._route,maratRoute,'valid body keeps current route');
const guards={_residentIndoors:true,_interiorId:'room',interior_id:'room',_insideBuilding:true,_residentNativeVisit:{},_civilianTrip:{},_civilianTripRiding:true,_responseVehicleId:'car',vehicleId:'car',vehicle_id:'car',_inVehicle:true,_inCar:true,_vehicleHijackControlled:true,_carriedByAmbulance:true,_evacuated:true,_policeCuffed:true,_medicalDowned:true,_fighting:true,_fightingMelee:true,_hostile:true,_empireCombatTarget:{},_empirePlayerWar:true,_empireEnemyLeaderId:'enemy',_empireFieldEncounterStatus:'active',_empireStreetNegotiation:{},_playerConversationOpen:true,_knockedUntil:50000,_meleeStunnedUntil:50000,_empireDownUntil:50000,_empireHospitalUntil:Date.now()+60000};
for(const [key,value] of Object.entries(guards)){
 const actor={...leila(),[key]:value},route=actor._route;b.placementTick(actor,20000);
 assert.equal(actor.r,24.95,key);assert.equal(actor.c,23.49,key);assert.equal(actor._route,route,key);
}
// An unavailable local repair cannot relocate the actor across the city;
// retries are throttled before the expensive nearest-safe search.
const actualNearest=b._nearestEmpireWalkPoint;let calls=0;
b._nearestEmpireWalkPoint=()=>{calls++;return {r:40,c:40};};
const stranded=leila();b.placementTick(stranded,30000);
assert.equal(stranded.r,24.95);assert.equal(calls,1);
b.placementTick(stranded,30001);assert.equal(calls,1);
b.placementTick(stranded,32000);assert.equal(calls,2);
b._nearestEmpireWalkPoint=actualNearest;
console.log(JSON.stringify({pass:true,actualLeilaRecovery:recovered,recoveryMs,maratUnchanged:true,protectedStates:Object.keys(guards).length,limits:f.limits}));
