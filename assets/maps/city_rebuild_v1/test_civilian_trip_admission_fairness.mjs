// Source admission regression, not full-map navigation or renderer acceptance.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createNpcNativeNavigation} from './npc_native_navigation.mjs';

const source=fs.readFileSync(new URL('./civilian_parking_trip_source.js',import.meta.url),'utf8');
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
function sourceFunction(name){
 const start=world.indexOf('function '+name+'(');assert(start>=0,name);
 const line=world.slice(start,world.indexOf('\n',start));
 return line.trimEnd().endsWith('}')?line:world.slice(start,world.indexOf('\n}',start)+2);
}
const helpers=['_npcLifeEligible','_isRespawnableResident','_civilianPlanEligible','_civilianPlanInterrupted','_npcNavigationAt','_npcRouteWalkBlocked','npcPassableForSnitch','_npcBodyPassable'].map(sourceFunction).join('\n');
const car=(id,c)=>({id,r:20,c,ang:0,parked:true,model:{L:1.8,W:.88}});
const npc=(id,c,r=18)=>({id:'resident_'+id,r,c,hp:100,walking:false});

function fixture({cars=[car('c0',10),car('c1',14),car('c2',18),car('c3',22)],npcs=[npc('original',18)],missing=[],obstacles=[],water=[],native=true}={}){
 let now=0,accessQueries=[],laneQueries=[];
 const contains=(b,r,c)=>r>=b.r0&&r<=b.r1&&c>=b.c0&&c<=b.c1;
 const navigation=createNpcNativeNavigation({worldScale:4.1,groundHeight:()=>0,
  bodiesAt:()=>obstacles,containsBody:contains,surfaceAt:()=> 'road',
  waterAt:(x,z)=>water.some(b=>contains(b,z/4.1,x/4.1))?{level:1}:null});
 const box={CARS:cars,NPCS:npcs,player:{r:20,c:5},MAP:Array.from({length:200},()=>Array(180).fill(9)),MAP_ROWS:200,MAP_COLS:180,
  _parkingNpcs:[],myDrivingCarId:null,document:{documentElement:{dataset:{}}},performance:{now:()=>now},
  _walkRendererActive:()=>native,_threeVehicleEntityId:c=>c.id,_threeNpcEntityId:n=>n.id,
  _walkNpcNavigationResolver:navigation.query,_walkNpcWaterResolver:null,_npcWaterBypass:0,
  _npcNavigationStats:{queries:0,solidRefusals:0,waterRefusals:0},
  _inPrisonIslandRestrictedZone:()=>false,inArena:()=>false,inLair:()=>false,_inPitCorridor:()=>false,
  isBlockedPed:()=>false,_cityV3NextSurfaceAt:()=>false,npcPassable:()=>assert.fail('unexpected ordinary pass'),
  npcWaypointOk:()=>assert.fail('native admission must use native body'),
  _clearNpcRoute:n=>{n._route=null;},
  _residentBuildingDoors:()=>[{id:'native:shop',r:20,c:32}],
  _walkTrafficNavigationResolver:request=>{assert.equal(request.mode,'lane-route');laneQueries.push(request);return {status:'pending',reason:'fixture-no-route-completion'};},
 };
 vm.createContext(box);vm.runInContext(helpers+'\n'+source+`;globalThis.api={schedule:_civilianTripSchedule,tick:_civilianTripTickNpc,trip:()=>_civilianTrip,cursor:()=>_civilianTripAdmissionAfter,setAccess(fn){_walkNpcVehicleAccessResolver=fn;},body:_npcBodyPassable};`,box);
 box.api.setAccess(({carId})=>{accessQueries.push(carId);const c=cars.find(c=>c.id===carId);return missing.includes(carId)?null:{outside:{r:c.r-.85,c:c.c},seat:{r:c.r,c:c.c}};});
 return {box,cars,npcs,navigation,laneQueries,api:box.api,
  step(time){now=time;navigation.beginFrame();accessQueries=[];box.api.schedule(now);const d=box.document.documentElement.dataset.civilianTrip;return {access:[...accessQueries],status:d?JSON.parse(d):null};},
  tick(){box.api.tick(box.api.trip().npc,.05,now);},
 };
}

const report={scenario:'Actual source scheduler/native point+body predicates; synthetic static blockers/water; no forced route success; CPU only',cases:[]};
for(const reason of ['vehicle-model-pending','door-approach-blocked','water']){
 const obstacles=[10,14].map(c=>({r0:19.30,r1:19.34,c0:c+.15,c1:c+.20})); // Centre clear; the body corner collides.
 const f=fixture({missing:reason==='vehicle-model-pending'?['c0','c1']:[],obstacles:reason==='door-approach-blocked'?obstacles:[],water:reason==='water'?obstacles:[]});
 const original=f.npcs[0],beforeCars=JSON.stringify(f.cars),beforeAnchor={r:original.r,c:original.c};
 const first=f.step(0);assert.equal(f.api.trip(),null);assert.equal(first.status.phase,'waiting-admission');assert.equal(first.status.admission.length,2);assert.deepEqual(first.access,['c0','c1']);
 assert(first.status.admission.every(a=>a.reason===(reason==='water'?'door-approach-blocked':reason)));
 assert.deepEqual(f.step(749).access,[],'not more work before the next admission time');
 assert.equal(JSON.stringify(f.cars),beforeCars,'failed admission must not reserve or move a car');
 const second=f.step(750),trip=f.api.trip();assert(trip,'next pair must be admitted');assert.equal(trip.car,f.cars[2]);assert.equal(trip.npc,original);assert.equal(trip.phase,'planning');
 assert.deepEqual(second.access,['c2']);assert.equal(f.cars.length,4);assert.equal(f.npcs.length,1);assert.equal(original.r,beforeAnchor.r);assert.equal(original.c,beforeAnchor.c);
 assert(!f.cars[0]._civilianTrip&&!f.cars[1]._civilianTrip&&!f.cars[3]._civilianTrip);
 f.tick();assert.equal(f.api.trip(),trip);assert.equal(trip.phase,'planning','pending native planner must not be forced successful');assert.equal(f.laneQueries.length,1);
 report.cases.push({name:reason,first:first.status.admission,admitted:trip.car.id,atMs:750,originalNpc:trip.npc.id});
}
{
 const f=fixture({cars:[car('c0',10),car('c1',14),car('c2',40),car('c3',44)],npcs:[npc('near-next-pair',41)]});
 const first=f.step(0);assert.equal(first.access.length,0);assert.equal(first.status.admission.length,2);assert(first.status.admission.every(a=>a.reason==='no-available-resident'));
 f.step(750);assert.equal(f.api.trip().car.id,'c2');assert.equal(f.api.trip().npc,f.npcs[0]);assert(Math.hypot(f.npcs[0].r-f.cars[2].r,f.npcs[0].c-f.cars[2].c)<12);
 report.cases.push({name:'nearest-two-no-resident',admitted:'c2',originalNpc:f.npcs[0].id});
}
{
 const f=fixture({missing:['c0','c1','c2','c3']});
 for(const [at,ids] of [[0,['c0','c1']],[750,['c2','c3']],[1500,['c0','c1']]]){
  const result=f.step(at);assert.deepEqual(result.access,ids);assert.equal(result.status.admission.length,2);assert.equal(f.api.trip(),null);
 }
 report.cases.push({name:'all-blocked-cyclic-bound',carsPerAttempt:2});
}
{
 const flags=[{owner_uid:'player'},{driver_uid:'other'},{ownerId:'owner'},{driverId:'driver'},{_hijackPending:1},{_convoy:true},{_wrecked:true},{_ambientDriverNpcId:'driver'},{model:{police:true}},{model:{emergency:true}}];
 const cars=flags.map((flag,i)=>Object.assign(car('protected'+i,10+i*.1),flag));cars.push(car('free',20));
 const f=fixture({cars,npcs:[npc('eligible',20),{...npc('dead',20),dead:true},{...npc('panic',20),panicUntil:9999}]});
 const protectedBefore=JSON.stringify(cars.slice(0,-1));const result=f.step(0);assert.deepEqual(result.access,['free']);assert.equal(f.api.trip().car.id,'free');assert.equal(f.api.trip().npc,f.npcs[0]);assert.equal(JSON.stringify(cars.slice(0,-1)),protectedBefore);
 report.cases.push({name:'ownership-special-vehicles-and-original-eligible-resident',protectedCars:flags.length});
}
{
 const f=fixture({cars:[car('reserved',10),car('retry',12),car('free',20)]});f.box._parkingNpcs.push({car:f.cars[0]});f.cars[1]._civilianTripRetryAt=10000;
 assert.deepEqual(f.step(0).access,['free']);assert.equal(f.api.trip().car.id,'free');
 report.cases.push({name:'parking-reservation-and-retry-preserved'});
}
{
 const residents=[npc('farther',28),{...npc('dead-nearest',20,19.9),dead:true},npc('closest',20),npc('tie',20),{...npc('panic-nearest',20,19.8),panicUntil:9999}];
 const f=fixture({cars:[car('nearest-check',20)],npcs:residents});f.step(0);
 assert.equal(f.api.trip().npc,residents[2],'linear selection must retain nearest eligible original NPC and stable first tie');
 report.cases.push({name:'nearest-eligible-not-first-array-entry',originalNpc:residents[2].id});
}
// Isolate scheduler CPU cost: 32 candidates, 1000 existing residents, every
// access unavailable. No model load, no planner/route fake success, no renderer.
{
 const cars=Array.from({length:32},(_,i)=>car('bench'+i,10+i)),npcs=Array.from({length:1000},(_,i)=>npc('bench'+i,10+i%32,18+(i%3)*.1));
 const f=fixture({cars,npcs,missing:cars.map(c=>c.id)}),samples=[];
 for(let i=0;i<100;i++){const start=performance.now(),result=f.step(i*750),ms=performance.now()-start;assert.equal(result.access.length,2);assert.equal(result.status.admission.length,2);if(i>=20)samples.push(ms);}
 samples.sort((a,b)=>a-b);report.cpu={npcCount:1000,carCount:32,warmup:20,samples:samples.length,p50Ms:samples[Math.floor(samples.length*.5)],p95Ms:samples[Math.floor(samples.length*.95)],maxMs:samples.at(-1),limit:'Synthetic admission only, not scene FPS'};
}
fs.writeFileSync(new URL('../../../outputs/civilian_trip_admission_fairness_20260913.json',import.meta.url),JSON.stringify(report,null,2));
console.log('PASS civilian trip admission fairness',JSON.stringify(report));
