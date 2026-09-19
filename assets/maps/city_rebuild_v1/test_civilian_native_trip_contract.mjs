import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

// Contract regressions, not the actual-map lifecycle acceptance harness.
const source=fs.readFileSync(new URL('./civilian_parking_trip_source.js',import.meta.url),'utf8');
let now=0,laneReady=false,pedestrianReady=false,driverReady=true,routeRequests=0,laneTarget=null,parkingDestinationRequests=0,noParking=false;
const car={id:'civilian-car',r:10,c:10,ang:0,dirDx:1,dirDy:0,parked:true,model:{L:1.8,W:.88}},npc={id:'resident',r:9,c:10,hp:100},goal={id:'native:shop',buildingId:'shop',r:10,c:15};
const destinationSlot={id:'native:shop:slot',lotId:'native:shop:lot',r:10,c:14.7,angle:0,widthM:5,lengthM:10};
const CARS=[car],NPCS=[npc],context={CARS,NPCS,player:{r:35,c:35},_parkingNpcs:[],_npcVehicleOccupants:new WeakMap(),_npcRouteWorkBatch:new Set(),myDrivingCarId:null,MAP:Array.from({length:40},()=>Array(40).fill(1)),document:{documentElement:{dataset:{}}},performance:{now:()=>now},
 _walkRendererActive:()=>true,_threeVehicleEntityId:c=>c.id,_threeNpcEntityId:n=>n.id,_residentBuildingDoors:()=>[goal],_civilianPlanEligible:n=>!n.dead,_civilianPlanInterrupted:n=>n.dead,
 _npcBodyPassable:(r,c,fn)=>fn(r,c),npcPassableForSnitch:()=>true,npcWaypointOk:()=>false,_npcPathPassable:()=>true,_clearNpcRoute:n=>{n._route=null;},_setNpcRoute:(n,p)=>{n._route=p;return true;},_npcEffectiveSpeed:()=>1,
 _planNpcRouteTo(n,r,c){n._routeSearchPending=!pedestrianReady;if(!pedestrianReady)return false;n._route=[{r,c}];return true;},_npcAdvanceRoute:()=> 'walking',_civilianRouteTo:()=>false,
 _walkNpcNavigationResolver:()=>({blocked:false,depth:0,surface:'road'}),
 _walkTrafficNavigationResolver(request){if(request.mode==='parking-destination'){parkingDestinationRequests++;return {ready:true,status:'ready',lotIds:noParking?[]:[destinationSlot.lotId]};}if(request.mode==='lane-route'){routeRequests++;laneTarget=request.to;return laneReady?{status:'ready',points:[{r:10,c:14,angle:0}],controls:[],destination:{lotId:destinationSlot.lotId}}:{status:'pending'};}if(request.mode==='parking-anchors')return {ready:true,slots:[destinationSlot]};if(request.mode==='driver')return {ready:driverReady};return {clear:true};}
};
vm.createContext(context);vm.runInContext(source+`;globalThis.api={schedule:_civilianTripSchedule,npcTick:_civilianTripTickNpc,carTick:_civilianTripTickCar,trip:()=>_civilianTrip,setTrip(t){_civilianTrip=t;t.car._civilianTrip=true;t.npc._civilianTrip=true;},setAccess(fn){_walkNpcVehicleAccessResolver=fn;},release:_civilianTripRelease};`,context);
const api=context.api;api.setAccess(()=>({outside:{r:9,c:10},seat:{r:10,c:10}}));
api.schedule(now);const trip=api.trip();assert(trip);assert.equal(trip.phase,'planning');assert(!car._onParking,'native vehicle did not need legacy parking membership');
for(let i=0;i<160;i++){now+=100;api.schedule(now);api.npcTick(npc,.05,now);assert.equal(api.trip(),trip);assert.equal(trip.npc,npc);assert.equal(trip.car,car);}
assert.equal(car.c,10);assert(routeRequests>100,'same pending job is polled across old twelve-second reset');
assert.equal(parkingDestinationRequests,1,'parking suitability is resolved once before the heavy lane job');assert.deepEqual(laneTarget.lotIds,[destinationSlot.lotId]);
laneReady=true;now+=100;api.npcTick(npc,.05,now);assert.equal(trip.phase,'approach');
npc.r=7; // Outside the directly reachable short door corridor: this phase exercises pending routing.
for(let i=0;i<160;i++){now+=100;api.npcTick(npc,.05,now);assert.equal(api.trip(),trip);assert(npc._routeSearchPending);}
pedestrianReady=true;npc.r=9;now+=100;api.npcTick(npc,.05,now);assert.equal(trip.phase,'board');
for(let i=0;i<60&&trip.phase==='board';i++){now+=50;api.npcTick(npc,.05,now);}
assert.equal(trip.phase,'drive');assert(npc._civilianTripRiding);
driverReady=false;const before=car.c;api.carTick(car,.05);assert.equal(car.c,before,'missing renderer driver cannot move car');
driverReady=true;api.carTick(car,.05);assert(car.c>before);
context._npcVehicleOccupants.set(car,{npc});
trip.phase='exit';trip.exit={r:npc.r,c:npc.c};trip.doorLength=1;api.npcTick(npc,.05,now);
assert(!context._npcVehicleOccupants.has(car),'a physically exited living citizen is no longer hijackable inside the empty car');
assert.equal(api.trip(),null);assert.equal(npc._residentDoor,goal);assert.equal(npc._civilianPlan.doorId,goal.id);assert.equal(npc._civilianPlan.phase,'walk_to_shop');assert(npc._civilianPlan.tripDestination,'pending building route keeps exact trip destination');
// A building without verified parking is rejected before any lane worker job.
noParking=true;npc._civilianPlan=null;car.parked=true;delete car._civilianTripRetryAt;vm.runInContext('_civilianTripNextAt=0;',context);const beforeNoParkingRoutes=routeRequests;now+=100;api.schedule(now);assert(api.trip());for(let i=0;i<3&&api.trip();i++){now+=100;api.npcTick(npc,.05,now);}assert.equal(api.trip(),null);assert.equal(routeRequests,beforeNoParkingRoutes,'no lane route is requested for a destination without parking');noParking=false;delete car._civilianTripRetryAt;
for(const phase of ['board','drive','exit'])for(const kind of ['dead','zero-hp']){
 npc.dead=kind==='dead';npc.hp=kind==='zero-hp'?0:100;npc._civilianPlan={phase:'drive_to_shop'};npc._civilianTripRiding=phase==='drive';trip.phase=phase;trip.exit={r:npc.r+1,c:npc.c+1};trip.since=now-1000;car.vr=1;car.vc=1;api.setTrip(trip);const anchor={r:npc.r,c:npc.c,carR:car.r,carC:car.c};
 api.npcTick(npc,.1,now);assert.equal(api.trip(),null);assert.equal(npc._civilianPlan,null,'dead resident gets no walking task');assert.equal(npc.r,anchor.r);assert.equal(npc.c,anchor.c);assert.equal(car.r,anchor.carR);assert.equal(car.c,anchor.carC);assert.equal(car.vr,0);assert.equal(car.vc,0);assert.equal(npc.hp,kind==='zero-hp'?0:100);
}
// Source-owned intent cancellation: execute the actual current world methods.
{
 const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');for(const name of ['_cancelNpcDirectedSearch','_civilianPlanCancel']){const a=world.indexOf('function '+name+'('),b=world.indexOf('\n}',a)+2;assert(a>=0&&b>a);vm.runInContext(world.slice(a,b),context);}
 context._civilianBenchReservations=new Map();context._npcRouteWorkQueue=new Map();npc.dead=false;npc.hp=100;car.parked=true;delete car._civilianTrip;delete npc._civilianTrip;delete car._civilianTripRetryAt;
 npc._civilianPlan={phase:'sitting',benchId:'bench-owned',cycle:3};npc._civilianSeat={benchId:'bench-owned'};npc._routeKind='civilian_bench';npc._routeSearchKind='building_entry';npc._routeSearchPending=true;npc._npcDirectedSearch={kind:'building_entry'};npc._routeRequestAt=1;context._npcRouteWorkQueue.set(npc,1);context._civilianBenchReservations.set('bench-owned',npc);
 vm.runInContext('_civilianTrip=null;_civilianTripNextAt=0;',context);now+=1000;api.schedule(now);const fresh=api.trip();assert(fresh);assert.equal(npc._civilianPlan.phase,'walk_to_car');assert.equal(npc._civilianSeat,null);assert(!context._civilianBenchReservations.has('bench-owned'));assert(!npc._routeSearchPending);assert(!context._npcRouteWorkQueue.has(npc));assert.equal(npc._npcDirectedSearch,null);
 npc._routeSearchKind='civilian_car';npc._routeSearchPending=true;context._npcRouteWorkQueue.set(npc,2);api.release(fresh,'test-release');assert.equal(npc._routeSearchPending,false);assert(!context._npcRouteWorkQueue.has(npc));
 api.setTrip(fresh);npc._routeSearchKind='medical_rescue';npc._routeSearchPending=true;const rescue={kind:'medical_rescue'};npc._npcDirectedSearch=rescue;context._npcRouteWorkQueue.set(npc,3);api.release(fresh,'test-foreign-intent');assert(npc._routeSearchPending);assert.equal(npc._npcDirectedSearch,rescue);assert(context._npcRouteWorkQueue.has(npc),'trip release does not cancel a new rescue owner');
}
// Actual renderer IDs may be absent on source cars: fairness must use the stable
// source-to-presentation WeakMap identity, never String(car.id).
{
 const ids=new WeakMap(),idless=Array.from({length:5},(_,i)=>({r:30,c:30+i,ang:0,parked:true,model:{}}));idless.forEach((car,i)=>ids.set(car,'local_vehicle_'+i));CARS.splice(0,CARS.length,...idless);NPCS.splice(0);context._threeVehicleEntityId=car=>ids.get(car);context.window={__npcTripDiagnostics:true};
 vm.runInContext('_civilianTrip=null;_civilianTripAdmissionAfter=null;_civilianTripNextAt=0;',context);
 const seen=[];for(let i=0;i<3;i++){now+=1100;api.schedule(now);const report=JSON.parse(context.document.documentElement.dataset.civilianTrip);seen.push(report.admission.map(a=>a.carId));}
 // Distance sort: source player35,35 visits columns34,33,32,31,30.
 assert.deepEqual(seen,[['local_vehicle_4','local_vehicle_3'],['local_vehicle_2','local_vehicle_1'],['local_vehicle_0','local_vehicle_4']]);
 assert(JSON.parse(context.document.documentElement.dataset.civilianTrip).history,'opt-in admission retains history');
 npc.dead=false;npc.hp=100;trip.npc=npc;trip.car=car;trip.carId='diagnostic-car';trip.phase='approach';trip.door={r:9,c:10};npc._route=[{r:9,c:10}];npc._routeIndex=0;
 for(let i=0;i<10;i++){trip.phase='phase-'+i;now+=600;api.setTrip(trip);api.release(trip,'release-'+i);}
 const report=JSON.parse(context.document.documentElement.dataset.civilianTrip);assert.equal(report.history.length,8);assert.equal(report.history[0].phase,'release-2');assert.equal(report.history.at(-1).phase,'release-9');assert(report.approach);assert(report.door);assert(!report.history[0].history,'rolling history never recursively embeds itself');
}
console.log('PASS native trip contracts: stable native/pedestrian pending, exact door, live driver admission, retained visit, corpse/zero-HP no exit during board/drive/exit');
