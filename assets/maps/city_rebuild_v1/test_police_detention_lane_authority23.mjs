import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {performance as hostPerformance} from 'node:perf_hooks';

// The actual city geometry proof runs first. This source test then exercises
// the exact production movement helpers, including lease and cancellation.
const {actualDetentionRoutes}=await import('./test_service_lane_authority23.mjs');
const candidate=process.argv.includes('--candidate');
const path=candidate?'../../../outputs/world_police_detention_lane23_candidate.html':'../../../world.html';
const world=fs.readFileSync(new URL(path,import.meta.url),'utf8').replaceAll('\r','');
const section=(start,end)=>{const a=world.indexOf(start),b=world.indexOf(end,a);assert(a>=0&&b>a,start);return world.slice(a,b)};
const source=section('function _policeVehicleCancelLane(v){','\nfunction _groundPoliceCanDrive(v,now){');
let now=0,allowControl=false,driverReady=true,laneResult=null,routeResult=null;
const calls=[],sweeps=[],box={
 performance:{now:()=>now},player:{r:10,c:10.2},NPCS:[],CARS:[],serviceVehicles:[],
 _murderPoliceArrest:null,_walkRendererActive:()=>true,_vehicleStep:()=>{throw Error('native fallback not expected')},
 _groundPoliceCanDrive:()=>driverReady,
 _walkTrafficNavigationResolver:request=>{
  calls.push(structuredClone(request));
  if(request.mode==='lane-route')return structuredClone(laneResult);
  if(request.mode==='lane-route-touch')return {ready:true,status:'ready',routeJob:'detention-token'};
  if(request.mode==='lane-route-cancel')return {ready:false,status:'blocked',reason:'route_cancelled'};
  if(request.mode==='road-rules')return {ready:true,status:'ready',control:{allowed:allowControl,reason:allowControl?'clear':'traffic_signal'}};
  if(request.mode==='road-targets')return {status:'ready',points:[{r:20,c:22,angle:0}]};
  if(request.mode==='route')return structuredClone(routeResult);
  sweeps.push(structuredClone(request));return {clear:true};
 },
};
vm.createContext(box);vm.runInContext(source+';globalThis.step=_policeVehicleStep;globalThis.cancelLane=_policeVehicleCancelLane;',box);

const destination={id:'detention:test',instanceId:'REBUILD-DETENTION-southside',stop:{r:10,c:10.5,angle:0}};
const routePoints=[
 {r:10,c:10,angle:0,gear:'forward'},
 {r:10,c:11,angle:0,gear:'forward'},
 {r:10,c:10.5,angle:0,gear:'reverse'},
];
laneResult={status:'ready',points:routePoints,accessRouteIds:['service-access:test'],accessLotIds:[],
 routeJob:'detention-token',controls:[{id:'signal:test',kind:'pedestrian_crossing',edgeId:'edge:test',distanceM:.05,stopPoint:{r:10,c:10.2},routeJob:'detention-token'}]};
const vehicle={id:'convoy',kind:'police',_murderFleet:true,_policePrisonTransport:true,state:'returning',x:10,y:10,ang:0,speed:.1,payload:{}};
box.serviceVehicles=[vehicle];box._murderPoliceArrest={phase:'transport',destination,playerBoarded:true,playerAttachedVehicleId:vehicle.id};

assert.equal(box.step(vehicle,.1),false);
const request=calls.find(call=>call.mode==='lane-route');
assert(request,'detention transport requests the canonical lane planner');
assert.equal(request.to.buildingId,destination.instanceId);
assert.deepEqual({r:request.to.r,c:request.to.c,angle:request.to.angle},destination.stop);
assert.equal(vehicle.x,10,'red signal holds before the first movement');
assert(calls.some(call=>call.mode==='road-rules'&&call.control.id==='signal:test'));
assert.deepEqual(calls.find(call=>call.mode==='road-rules').occupiedCrosswalkIds,[],'the attached prisoner cannot occupy the convoy crossing');
allowControl=true;
let arrived=false,reverseObserved=false,previousX=vehicle.x;
for(let frame=0;frame<400&&!arrived;frame++){
 now+=100;arrived=box.step(vehicle,.1);
 if(vehicle.x<previousX-1e-8&&Math.abs(vehicle.ang)<.1)reverseObserved=true;
 assert(Math.abs(vehicle.x-previousX)<=.100001,'convoy movement stays paced');
 previousX=vehicle.x;
}
assert(arrived,'convoy reaches the exact detention stop');
assert(Math.hypot(vehicle.y-destination.stop.r,vehicle.x-destination.stop.c)<.001);
assert(Math.abs(Math.atan2(Math.sin(vehicle.ang-destination.stop.angle),Math.cos(vehicle.ang-destination.stop.angle)))<.035);
assert(reverseObserved,'southside-style route executes a physical reverse edge');
assert(calls.some(call=>call.mode==='lane-route-touch'),'long route renews its authority lease');
assert(calls.some(call=>call.mode==='lane-route-cancel'&&call.requestId===request.requestId),'arrival revokes the route authority');
assert(sweeps.length>0&&sweeps.every(call=>call.roadsOnly===false&&call.laneRouteToken==='detention-token'&&call.accessRouteIds?.[0]==='service-access:test'));
const touchCount=calls.filter(call=>call.mode==='lane-route-touch').length;

// A ready route that ends at an access tail other than the requested stop is
// rejected before the vehicle can move or start an arrival handoff.
calls.length=0;sweeps.length=0;now+=2000;
const mismatch={id:'convoy-mismatch',kind:'police',_murderFleet:true,_policePrisonTransport:true,state:'returning',x:10,y:10,ang:0,speed:1,payload:{}};
box.serviceVehicles=[mismatch];box._murderPoliceArrest={phase:'transport',destination};
laneResult={...laneResult,points:[routePoints[0],{r:10,c:10.2,angle:0}]};
assert.equal(box.step(mismatch,.1),false);
assert.equal(mismatch._nativePoliceReason,'route-endpoint-mismatch');
assert.equal(mismatch.x,10);assert.equal(sweeps.length,0);
assert(calls.some(call=>call.mode==='lane-route-cancel'));

// Losing the physical driver revokes an already-issued token immediately.
calls.length=0;driverReady=false;
const orphan={id:'convoy-orphan',kind:'police',_murderFleet:true,_policePrisonTransport:true,state:'returning',x:10,y:10,ang:0,speed:1,payload:{},
 _nativePoliceLaneRequestId:'orphan-token',_nativePoliceRoute:routePoints,_nativePoliceAuthority:{laneRouteToken:'orphan-proof'}};
box.serviceVehicles=[orphan];box._murderPoliceArrest={phase:'transport',destination};
assert.equal(box.step(orphan,.1),false);assert.equal(orphan._nativePoliceRoute,null);
assert(calls.some(call=>call.mode==='lane-route-cancel'&&call.requestId==='orphan-token'));
driverReady=true;

// Drive the exact source helper through every point of all three actual city
// detention routes. The physical full-hull validity was checked by the import.
const actualRows=[],stepCosts=[];
for(const actual of actualDetentionRoutes){
 calls.length=0;sweeps.length=0;now+=2000;allowControl=true;
 const {destination:actualDestination,result}=actual,points=result.points;
 laneResult={...result,routeJob:'actual-token:'+actualDestination.id};
 const first=points[0],car={id:'actual-'+actualDestination.id,kind:'police',_murderFleet:true,_policePrisonTransport:true,
  state:'returning',y:first.r,x:first.c,ang:first.angle,speed:.1,payload:{}};
 box.serviceVehicles=[car];box._murderPoliceArrest={phase:'transport',destination:actualDestination};
 let actualArrived=false,actualReverse=false,previous={r:car.y,c:car.x};
 for(let frame=0;frame<5000&&!actualArrived;frame++){
  now+=100;const started=hostPerformance.now();actualArrived=box.step(car,.1);stepCosts.push(hostPerformance.now()-started);
  const dr=car.y-previous.r,dc=car.x-previous.c,d=Math.hypot(dr,dc);
  if(d>.000001&&(dr*Math.sin(car.ang)+dc*Math.cos(car.ang))/d<-.5)actualReverse=true;
  previous={r:car.y,c:car.x};
 }
 assert(actualArrived,actualDestination.id+' source step reaches its route end');
 assert(Math.hypot(car.y-actualDestination.stop.r,car.x-actualDestination.stop.c)<.001);
 if(result.gearChanges.length)assert(actualReverse,actualDestination.id+' executes its authored reverse section');
 assert(calls.some(call=>call.mode==='lane-route-touch'),actualDestination.id+' renews the actual route lease');
 assert(calls.some(call=>call.mode==='lane-route-cancel'),actualDestination.id+' cancels authority on arrival');
 actualRows.push({id:actualDestination.id,points:points.length,reverse:actualReverse,endpoint:{r:car.y,c:car.x}});
}

// Ordinary police scene/home routing keeps its existing road-only planner.
calls.length=0;sweeps.length=0;now+=2000;
const ordinary={id:'ordinary',kind:'police',state:'go_to_scene',x:20,y:20,ang:0,speed:1,payload:{murderIncident:{r:20,c:22}}};
box.serviceVehicles=[ordinary];box._murderPoliceArrest=null;
routeResult={status:'ready',points:[{r:20,c:20,angle:0},{r:20,c:22,angle:0}]};
box.step(ordinary,.1);
assert(calls.some(call=>call.mode==='road-targets'));
assert(calls.some(call=>call.mode==='route'&&call.roadsOnly===true));
assert(sweeps.some(call=>call.roadsOnly===true&&!call.laneRouteToken));
stepCosts.sort((a,b)=>a-b);

console.log(JSON.stringify({passed:true,candidate,detention:{requestId:request.requestId,endpoint:destination.stop,reverseObserved,
 touches:touchCount,actual:actualRows},cpu:{steps:stepCosts.length,p50Ms:stepCosts[Math.floor(stepCosts.length*.5)],p95Ms:stepCosts[Math.floor(stepCosts.length*.95)]},limits:'Actual source helper in VM plus actual-city full-hull route proof; CPU only, no renderer/GPU/FPS.'},null,2));
console.log('PASS police detention exact lane authority, control wait, reverse, lease and arrival cancellation');
