import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createNpcVehicleNavigation} from './npc_vehicle_navigation.mjs';
import {createNpcVehicleSurfaceAccess} from './npc_vehicle_surface_access.mjs';
import {createLaneRouteJobs} from './city_lane_route_jobs.mjs';
import {createCurrentNativeSnapshot} from './test_civilian_native_fixture.mjs';

const parking={
 lots:[{id:'parking:test',rect:{minX:10,minZ:10,maxX:14,maxZ:14},driveway:{minX:8,minZ:11,maxX:10,maxZ:13}}],
 bays:[{id:'parking:test:bay:0',lotId:'parking:test',x:12,z:12,yaw:0}],
 access:{routes:[{id:'parking:test:entry',lotId:'parking:test',kind:'entry',points:[{x:8,z:12},{x:12,z:12}]}]}
};
const roadPlan={serviceAccess:{routes:[{id:'service:test:entry',buildingId:'service:test',kind:'service_entry',points:[{x:0,z:20},{x:4,z:20}]}]}};
let laneWorker;const laneJobs=createLaneRouteJobs({createWorker:()=>laneWorker={messages:[],postMessage(message){this.messages.push(structuredClone(message));},terminate(){this.terminated=true;},emit(data){this.onmessage?.({data});}},setTimer:()=>({unref(){}}),clearTimer:()=>{}});
laneJobs.initialize({fixture:true});laneWorker.emit({type:'initialized',generation:laneWorker.messages[0].generation});
const laneRequest={mode:'lane-route',requestId:'surface-lane',carId:'surface-car',from:{r:7,c:5},to:{r:7,c:7}};
laneJobs.query(laneRequest);const laneMessage=laneWorker.messages.at(-1);laneWorker.emit({type:'result',generation:laneMessage.generation,token:laneMessage.token,result:{status:'ready',points:[{r:7,c:5},{r:7,c:7}],controls:[]}});const canonicalLane=laneJobs.query(laneRequest);
const access=createNpcVehicleSurfaceAccess({getParkingPlan:()=>parking,getRoadPlan:()=>roadPlan,verifyLaneSegment:request=>laneJobs.evaluateSegment(request),worldScale:1,routeToleranceM:.7});
const isRoad=(x,z)=>z>=-2&&z<=2&&x>=-20&&x<=1.5;
const nav=createNpcVehicleNavigation({worldScale:1,frameBudgetMs:20,maxExpanded:300,poseAllowed:()=>true,isRoad,vehicleAccess:access.query});
const pose=(x,z,identity={})=>nav.query({carId:'surface-car',from:{r:z,c:x,angle:0},to:{r:z,c:x,angle:0},halfWidth:.3,halfLength:.6,roadsOnly:false,...identity});
const laneSweep=(from,to,identity={})=>nav.query({carId:'surface-car',from:{...from,angle:0},to:{...to,angle:0},halfWidth:.3,halfLength:.6,roadsOnly:false,...identity});

assert.equal(pose(40,40).reason,'vehicle_surface_forbidden','untagged mountain is forbidden even with physical clearance');
assert.equal(pose(6,7).reason,'vehicle_surface_forbidden','untagged grass is forbidden even with roadsOnly:false');
assert.equal(pose(6,7,{lotId:'parking:test'}).reason,'vehicle_surface_forbidden','a valid lot identity cannot authorize terrain outside that lot');
assert.equal(pose(40,40,{accessRouteId:'missing'}).reason,'vehicle_surface_forbidden','unknown authored identity is forbidden');
assert.equal(pose(12,12,{parkingSlotId:'parking:test:bay:0'}).clear,true,'identified parking bay is allowed');
assert.equal(pose(9,12,{lotId:'parking:test'}).clear,true,'identified driveway rectangle is allowed');
assert.equal(pose(8.2,12,{accessRouteId:'parking:test:entry',lotId:'parking:test'}).clear,true,'identified parking access route is allowed');
assert.equal(pose(2,20,{accessRouteId:'service:test:entry'}).clear,true,'identified service access route is allowed');
assert.equal(laneSweep({r:7,c:5.5},{r:7,c:6.5},{laneRouteToken:canonicalLane.routeJob}).clear,true,'active canonical lane segment bridges a coarse road-mask corner');
assert.equal(laneSweep({r:7,c:5.5},{r:7,c:6.5},{laneRouteToken:'never-issued'}).reason,'vehicle_surface_forbidden','a forged lane token is forbidden');
assert.equal(laneSweep({r:40,c:39},{r:40,c:41},{laneRouteToken:canonicalLane.routeJob}).reason,'vehicle_surface_forbidden','a real token cannot authorize unrelated terrain');
assert.equal(laneSweep({r:7,c:6.5},{r:7,c:5.5},{laneRouteToken:canonicalLane.routeJob,laneSegment:[{r:7,c:5},{r:7,c:7}]}).reason,'vehicle_surface_forbidden','a presented forward segment cannot authorize a reversed actual sweep');
assert.equal(laneSweep({r:7,c:5.5},{r:7,c:6.5},{carId:'different-car',laneRouteToken:canonicalLane.routeJob}).reason,'vehicle_surface_forbidden','a canonical lane token is bound to its car');
assert.equal(pose(0,0).clear,true,'canonical road remains allowed without non-road identity');
assert.equal(nav.queryPhysical({carId:'player-car',from:{r:40,c:40,angle:0},to:{r:40,c:40.2,angle:0},halfWidth:.3,halfLength:.6}).clear,true,'trusted player path preserves physical non-road clearance');
assert.equal(nav.query({mode:'player-physical',carId:'player-car',from:{r:40,c:40,angle:0},to:{r:40,c:40.2,angle:0},halfWidth:.3,halfLength:.6,roadsOnly:false}).reason,'vehicle_surface_forbidden','an arbitrary public mode cannot select the private physical path');
const physicalWater=createNpcVehicleNavigation({worldScale:1,poseAllowed:()=>true,isRoad:()=>false,waterAt:()=>({depth:.3})});
assert.equal(physicalWater.queryPhysical({from:{r:40,c:40,angle:0},to:{r:40,c:40.2,angle:0}}).reason,'water','trusted physical path still enforces water clearance');

const throwingNav=createNpcVehicleNavigation({worldScale:1,poseAllowed:()=>true,isRoad:()=>false,vehicleAccess:()=>{throw Error('not ready');}});
assert.equal(throwingNav.query({carId:'surface-car',from:{r:7,c:6,angle:0},to:{r:7,c:6,angle:0},roadsOnly:false,laneRouteToken:canonicalLane.routeJob}).reason,'vehicle_surface_forbidden','vehicle access failure denies instead of escaping the query');
laneJobs.cancel(laneRequest.requestId);
assert.equal(laneSweep({r:7,c:5.5},{r:7,c:6.5},{laneRouteToken:canonicalLane.routeJob}).reason,'vehicle_surface_forbidden','cancelled lane tokens expire immediately');

const actual=createCurrentNativeSnapshot(),actualParking=actual.parkingPlan,actualAccess=createNpcVehicleSurfaceAccess({getParkingPlan:()=>actualParking,getRoadPlan:()=>actual.roadPlan});
const actualBay=actualParking.bays[0],actualRoute=actualParking.access.routes.find(route=>route.lotId===actualBay.lotId&&route.points?.length>1),actualMid=actualRoute.points[Math.floor(actualRoute.points.length/2)];
assert.equal(actualAccess.query({x:actualBay.x,z:actualBay.z,request:{parkingSlotId:actualBay.id}}).allowed,true,'actual authored bay identity is accepted');
assert.equal(actualAccess.query({x:actualMid.x,z:actualMid.z,request:{accessRouteId:actualRoute.id,lotId:actualRoute.lotId}}).allowed,true,'actual authored driveway route identity is accepted');

async function finish(request){let result;for(let frame=0;frame<500;frame++){nav.beginFrame();result=nav.query(request);if(result.status!=='pending')break;}return result;}
const base={mode:'route',carId:'route-car',halfWidth:.3,halfLength:.6,roadsOnly:true};
let result=await finish({...base,requestId:'final-forbidden',from:{r:0,c:0,angle:0},to:{r:0,c:2,angle:0}});
assert.equal(result.status,'blocked','final sweep cannot leave road without an authored identity');
result=await finish({...base,requestId:'final-authored',from:{r:0,c:0,angle:0},to:{r:0,c:2,angle:0},accessRouteId:'parking:test:entry'});
assert.equal(result.status,'blocked','an unrelated authored route cannot authorize a different endpoint');

const connectorPlan={serviceAccess:{routes:[{id:'service:road-edge',kind:'service_entry',points:[{x:0,z:0},{x:2,z:0}]}]}};
const connectorAccess=createNpcVehicleSurfaceAccess({getRoadPlan:()=>connectorPlan,worldScale:1,routeToleranceM:.7});
const connectorNav=createNpcVehicleNavigation({worldScale:1,frameBudgetMs:20,maxExpanded:300,poseAllowed:()=>true,isRoad,vehicleAccess:connectorAccess.query});
async function finishConnector(request){let value;for(let frame=0;frame<500;frame++){connectorNav.beginFrame();value=connectorNav.query(request);if(value.status!=='pending')break;}return value;}
result=await finishConnector({...base,requestId:'final-allowed',from:{r:0,c:0,angle:0},to:{r:0,c:2,angle:0},accessRouteId:'service:road-edge'});
assert.equal(result.status,'ready','final sweep accepts the matching authored access route');
result=await finishConnector({...base,requestId:'start-forbidden',from:{r:0,c:2,angle:Math.PI},to:{r:0,c:0,angle:Math.PI}});
assert.equal(result.status,'blocked','near-start apron cannot leave untagged terrain');
result=await finishConnector({...base,requestId:'start-allowed',from:{r:0,c:2,angle:Math.PI},to:{r:0,c:0,angle:Math.PI},accessRouteId:'service:road-edge'});
assert.equal(result.status,'ready','near-start apron accepts the matching authored access route');

const timings=[];
for(let i=0;i<20000;i++){
 const start=performance.now();
 pose(i%2?12:40,i%2?12:40,i%2?{parkingSlotId:'parking:test:bay:0'}:{});
 timings.push(performance.now()-start);
}
timings.sort((a,b)=>a-b);
laneJobs.dispose();
const report={passed:true,forbidden:['mountain','grass','wrong-lot','unknown-route','forged-lane-token','unrelated-lane-segment','reversed-lane-segment','wrong-car','cancelled-lane-token','access-exception','public-physical-mode','physical-water','near-start','final-sweep'],allowed:['road','parking-bay','driveway','parking-access','service-access','canonical-lane-segment','trusted-player-physical','authored-near-start','authored-final','actual-city-bay','actual-city-driveway'],actual:{bayId:actualBay.id,lotId:actualBay.lotId,accessRouteId:actualRoute.id},cpu:{queries:timings.length,p50Ms:timings[Math.floor(timings.length*.5)],p95Ms:timings[Math.floor(timings.length*.95)]},limits:'CPU semantic gate plus current authored parking rebuilt from the tracked exact static fixture; trusted player physical entry is module-private until the Walk bridge verifies the active source driver. Full physical lifecycle is covered by test_native_parking_lifecycle, no renderer/GPU/FPS.'};
console.log(JSON.stringify(report,null,2));
console.log('PASS vehicle surface identity rejects terrain and preserves authored vehicle access');
