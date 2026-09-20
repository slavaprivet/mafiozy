import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance as clock} from 'node:perf_hooks';

const source=fs.readFileSync(new URL('./civilian_parking_trip_source.js',import.meta.url),'utf8');
let now=0,signalOpen=false,lastRuleRequest=null;
const car={id:'route-progress-car',r:10,c:10,ang:0,dirDx:1,dirDy:0,parked:false,model:{L:1.8,W:.88}},driver={id:'route-progress-driver',r:10,c:10,hp:100,alive:true,_civilianTripRiding:true},pedestrian={id:'crossing-pedestrian',r:100,c:100,hp:100},otherCar={id:'conflicting-car',r:100,c:100,ang:0,parked:false,model:{L:1.8,W:.88}};
const CARS=[car,otherCar],NPCS=[driver,pedestrian],player={r:100,c:100};
const context={console,Math,Number,Array,Map,Set,CARS,NPCS,player,myDrivingCarId:null,prevT:0,performance:{now:()=>now},document:{documentElement:{dataset:{}}},window:{},MAP:Array.from({length:120},()=>Array(120).fill(9)),_parkingNpcs:[],
 _walkRendererActive:()=>true,_threeVehicleEntityId:c=>c.id,_threeNpcEntityId:n=>n.id,_npcVehicleOccupants:new WeakMap(),_clearNpcRoute:()=>{},
 _walkTrafficNavigationResolver(request){
  if(request.mode==='driver')return {ready:true};
  if(request.mode==='road-rules'){
   lastRuleRequest=request;
   const control=request.control;
   if(control.kind==='pedestrian_crossing')return {control:{allowed:!(request.occupiedCrosswalkIds||[]).includes('zebra'),reason:'pedestrian_crossing'}};
   if(control.rule==='signal')return {control:{allowed:signalOpen,reason:'traffic_signal'}};
   if(control.rule==='yield')return {control:{allowed:!(request.occupiedTurnIds||[]).includes('conflicting-turn'),reason:'yield_to_traffic'}};
   return {control:{allowed:true}};
  }
  if(request.mode==='lane-route-touch')return {ready:true,status:'ready'};
  if(request.mode==='lane-route-cancel')return {ready:false,status:'blocked',reason:'route_cancelled'};
  return {clear:true};
 }
};
vm.createContext(context);
vm.runInContext(source+`;globalThis.api={register:_civilianTripRegister,tickCar:_civilianTripTickCar,permission:_civilianTripRoadPermission,tripForCar:_civilianTripForCar,release:_civilianTripRelease};`,context);
const api=context.api;

const goal={id:'destination-door',r:10,c:12};
const makeTrip=(points,controls=[])=>({car,carId:car.id,npc:driver,phase:'drive',index:0,since:now,travelledM:0,plan:{native:true,points,controls,goal:{door:goal,lot:null},lots:[]}});
const reset=(trip)=>{
 const old=api.tripForCar(car);if(old)api.release(old,'test-reset');
 Object.assign(car,{r:10,c:10,ang:0,dirDx:1,dirDy:0,vr:0,vc:0,parked:false,braking:false});
 Object.assign(driver,{r:10,c:10,hp:100,alive:true,_civilianTripRiding:true});
 delete car._civilianNativePlan;delete car._civilianTripRetryAt;delete driver._civilianTrip;
 assert(api.register(trip));
};
const tick=(dt=.05)=>{now+=dt*1000;context.prevT=now;api.tickCar(car,dt);};

// The first canonical lane point may equal the parked pose. It must be consumed
// without fabricating distance, then the following points must advance normally.
let trip=makeTrip([{r:10,c:10,angle:0},{r:10,c:10.6,angle:0},{r:10,c:11.2,angle:0}]);reset(trip);
tick();assert.equal(trip.index,1);assert.equal(trip.travelledM,0);
const indices=[trip.index],distances=[trip.travelledM];
for(let i=0;i<100&&trip.phase==='drive';i++){tick();if(indices.at(-1)!==trip.index)indices.push(trip.index);distances.push(trip.travelledM);}
assert.deepEqual(indices,[1,2,3]);assert(distances.some((d,i)=>i&&d>distances[i-1]));tick();assert.equal(trip.phase,'parked');assert(car.parked);

const stopPoint={r:10,c:10.25};
trip=makeTrip([{r:10,c:10,angle:0},{r:10,c:11,angle:0}],[{id:'signal-control',rule:'signal',distanceM:.5,approachId:'approach',turnId:'turn',stopPoint}]);reset(trip);tick();
const redDistance=trip.travelledM;for(let i=0;i<8;i++)tick();assert.equal(trip.travelledM,redDistance);assert.equal(trip.roadWaitReason,'traffic_signal');signalOpen=true;tick();tick();assert(trip.travelledM>redDistance);assert.equal(trip.roadWaitReason,null);

const crossingPoint={r:stopPoint.r,c:stopPoint.c+4.3/4.1};
trip=makeTrip([{r:10,c:10,angle:0},{r:10,c:11,angle:0}],[{id:'zebra-control',kind:'pedestrian_crossing',distanceM:.5,crosswalkIds:['zebra'],stopPoint}]);reset(trip);Object.assign(pedestrian,crossingPoint);tick();tick();assert.equal(trip.travelledM,0);assert(lastRuleRequest.occupiedCrosswalkIds.includes('zebra'));assert.equal(trip.roadWaitReason,'pedestrian_crossing');pedestrian.r=pedestrian.c=100;tick();tick();assert(trip.travelledM>0);

trip=makeTrip([{r:10,c:10,angle:0},{r:10,c:11,angle:0}],[{id:'yield-control',rule:'yield',distanceM:.5,approachId:'approach',turnId:'turn',yieldTo:['conflicting-turn'],stopPoint}]);reset(trip);Object.assign(otherCar,{r:stopPoint.r,c:stopPoint.c});tick();tick();assert.equal(trip.travelledM,0);assert(lastRuleRequest.occupiedTurnIds.includes('conflicting-turn'));assert.equal(trip.roadWaitReason,'yield_to_traffic');otherCar.r=otherCar.c=100;tick();tick();assert(trip.travelledM>0);

trip=makeTrip([{r:10,c:10,angle:0},{r:10,c:11,angle:0}]);reset(trip);Object.assign(pedestrian,{r:10,c:10.95});tick();tick();assert.equal(trip.travelledM,0,'full car sweep yields to a person in its path');assert.equal(car._civilianBlockReason,'pedestrian');assert.equal(car._civilianBlockerId,pedestrian.id,'pedestrian yield exposes the exact source actor');pedestrian.r=pedestrian.c=100;tick();tick();assert(trip.travelledM>0,'the same trip resumes after the person clears the lane');

const benchTrip=makeTrip([{r:10,c:10,angle:0},{r:10,c:11,angle:0}],Array.from({length:64},(_,i)=>({id:'clear-'+i,distanceM:i*.5,rule:'clear',stopPoint})));
reset(benchTrip);tick();const samples=[];for(let batch=0;batch<20;batch++){const start=clock.now();for(let i=0;i<1000;i++)api.permission(benchTrip,{r:10,c:10},{r:10,c:10.01});samples.push((clock.now()-start)/1000);}samples.sort((a,b)=>a-b);
const report={passed:true,initialWaypointConsumedWithoutDistance:true,indexSequence:indices,travelledM:distances.at(-1),arrivalPhase:'parked',trafficSignalWaitAndResume:true,pedestrianCrossingWaitAndResume:true,physicalPedestrianYieldAndResume:true,pedestrianBlockerId:pedestrian.id,yieldWaitAndResume:true,permissionCost:{p50Ms:samples[10],p95Ms:samples[19]},limits:'Actual civilian source TickCar/RoadPermission with controlled canonical road-rule replies; full authored parking, async lane worker, 895.97 m trip and physical building arrival are covered by test_native_parking_lifecycle --long --async.'};
fs.writeFileSync(new URL('../../../outputs/civilian_route_progress_controls_20260919.json',import.meta.url),JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
