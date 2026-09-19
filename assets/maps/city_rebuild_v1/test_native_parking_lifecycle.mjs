import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createLaneRouteJobs} from './city_lane_route_jobs.mjs';
import {nodeLaneWorker} from './test_lane_worker_adapter.mjs';
import {setTimeout as delay} from 'node:timers/promises';
import {createNpcVehicleNavigation} from './npc_vehicle_navigation.mjs';
import {createCarWorld,carFits} from './car_drive.mjs';
import {createNpcLogicalVehicleBinding} from './npc_logical_vehicle_binding.mjs';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';

const longTrip=process.argv.includes('--long'),asyncLane=process.argv.includes('--async'),laneJobs=asyncLane?createLaneRouteJobs({createWorker:nodeLaneWorker}):null;
const f=await createCivilianNativeFixture({laneJobs}),{box,car,npcs,M}=f;
box.window.__npcTripDiagnostics=true;
if(laneJobs)laneJobs.initialize({topology:f.top,bodies:f.bodies,roadPlan:f.snapshot.roadPlan,parkingPlan:f.snapshot.parkingPlan,instances:f.snapshot.buildings,metresPerCell:M});
const doors=box._residentBuildingDoors();assert.equal(doors.length,1);assert(doors[0].native);
const door=doors[0],npc={id:'resident_actual_lifecycle',r:0,c:0,hp:100,max_hp:100,speed:1,walkPhase:0,alive:true,_arcKey:'worker',_npcRoutine:'errands'};
box._npcAgendaWantsDrive=()=>true;
// Use successive actual 50 ms walking increments. A long planning query's
// sparse .14-tile samples can straddle the thin pair of closed door leaves.
const doorLength=Math.hypot(door.inside.r-door.r,door.inside.c-door.c),doorSteps=Math.ceil(doorLength/(.05*.4));
let closedDoorBlocks=false;
for(let i=1;i<=doorSteps;i++){
 const point=t=>({r:door.r+(door.inside.r-door.r)*t,c:door.c+(door.inside.c-door.c)*t}),a=point((i-1)/doorSteps),b=point(i/doorSteps);
 if(!box._npcPathPassable(a.r,a.c,b.r,b.c,box._residentNativePassable)){closedDoorBlocks=true;break;}
}
npcs.push(npc);
let start=null;
f.lanes.prepare();
const slots=f.lanes.query({mode:'parking-anchors'}).slots.sort((a,b)=>Math.hypot(a.r-door.r,a.c-door.c)-Math.hypot(b.r-door.r,b.c-door.c));
if(longTrip){
 const lotBuilding=f.snapshot.buildings.find(b=>b.id==='REBUILD-VISUAL-pine_ridge_cottage_v1-002');
 const home={...lotBuilding.entry.anchorRC,id:'native:'+lotBuilding.id,instanceId:lotBuilding.id,districtId:lotBuilding.districtId,native:true,residentEligible:true};
 box._residentBuildingDoors=()=>[door,home];
 slots.sort((a,b)=>(a.lotId==='parking:'+lotBuilding.id?0:1)-(b.lotId==='parking:'+lotBuilding.id?0:1));
 for(let i=0;i<100;i++){const id='long_resident_'+i;if(box._civilianJourneyHash(id+':1')%5===0){npc.id=id;break;}}
}
const originalQuery=box.nativeTrafficQuery;
let presentationLoaded=false;f.actor.object.removeFromParent();const logical=createNpcLogicalVehicleBinding({bridge:{getWalkNpcVehicleBinding:q=>box._getWalkNpcVehicleBinding(q),getWalkNpcVehicleTraffic:()=>box._getWalkNpcVehicleTraffic()},worldScale:M,groundHeight:f.floor,getTemplate:id=>id==='compact_sedan'?f.actor:null,getVisibleVehicle:()=>presentationLoaded?f.actor:null,getVisibleNpc:()=>null});
const longCarWorld=longTrip?createCarWorld(f.top,f.bodies,M):null;const longNav=longTrip?createNpcVehicleNavigation({worldScale:M,poseAllowed:(x,z,yaw,shape)=>carFits(x,z,yaw,longCarWorld,shape),waterAt:f.waterAt,groundHeight:f.floor,getVehicle:logical.getActor,getVehicles:logical.getVehicles}):null;
const laneQueryCosts=[];box.nativeTrafficQuery=q=>{const started=performance.now();const result=q.mode==='driver'?logical.driver(q):q.mode==='parking-exit'?f.lanes.query(q):q.mode==='parking-anchors'?{ready:true,slots}:q.mode==='initial-vehicle-shape'?{ready:true,halfLength:f.actor.profile.halfLength/M,halfWidth:f.actor.profile.halfWidth/M}:longNav&&!q.mode?longNav.query(q):originalQuery(q);if(q.mode==='lane-route')laneQueryCosts.push(performance.now()-started);return result;};
box.logicalAccess=logical.access;vm.runInContext('_walkTrafficNavigationResolver=nativeTrafficQuery;_walkNpcVehicleAccessResolver=logicalAccess;',box);
box._nativeParkingPrepare(car);
const admissionCosts=[];
for(let i=0;i<500&&car._nativeParkingPending;i++){f.nextFrame(.05);const begin=performance.now();box._nativeParkingAdmissionTick(f.now);admissionCosts.push(performance.now()-begin);}
assert(!car._nativeParkingPending,'new parked source car must be admitted to an actual authored bay');
assert(car._nativeParkingAnchor,'initial position must have exact bay identity');
f.syncCar();f.pedestrian.beginFrame();
box.player={r:car.r+100,c:car.c+100};logical.beginFrame();
const parkingAccess=logical.access({carId:car.id});
assert(!box.trip(),'geometry query must not create a trip');assert(!logical.driver({carId:car.id,npcId:npc.id}).ready,'geometry query must not authorize driving');
assert.equal(logical.access({carId:car.id,npcId:npc.id,phase:'board'}),null,'unassigned NPC cannot board');
assert(parkingAccess,'actual model door exists');
for(const [dr,dc]of [[1,0],[-1,0],[0,1],[0,-1]]){
 const point={r:parkingAccess.outside.r+dr,c:parkingAccess.outside.c+dc};
 if(box._npcPathPassable(point.r,point.c,parkingAccess.outside.r,parkingAccess.outside.c,box.npcPassableForSnitch)){start={car:{r:car.r,c:car.c,angle:car.ang},npc:point};break;}
}
assert(start,'authored parking bay must have physical pedestrian approach');
Object.assign(npc,start.npc);box.player={r:start.car.r+100,c:start.car.c+100};
const traces=[],costs=[],counts={frames:0,carDistanceM:0,footDistanceM:0,boardFrames:0,rideFrames:0,exitFrames:0,doorWaitFrames:0,insideFrames:0},seen=new Set();
let blocker=null,blockedAt=0,blockedFrames=0,blockerRemoved=false;
let gearStopFrames=0,previous='',maxStep=0,done=false,carMovedWithoutDriver=false,error=null;
const limit=Number(process.argv.find(a=>a.startsWith('--frames='))?.split('=')[1])||(longTrip?30000:8000);
try{
 for(let frame=0;frame<limit;frame++){
  if(laneJobs&&(!box.trip()||box.trip()?.phase==='planning'))await delay(5);
  f.nextFrame(.05);logical.beginFrame();longNav?.beginFrame();if(box.trip()?.phase==='drive'&&presentationLoaded){presentationLoaded=false;f.actor.object.removeFromParent();}const old={r:npc.r,c:npc.c,carR:car.r,carC:car.c,angle:car.ang},before=box.trip()?.phase,t0=performance.now();
  if(!box.trip()&&!npc._civilianPlan?.tripDestination&&!npc._residentNativeVisit&&!seen.has('drive'))box._civilianTripSchedule(f.now);
  const activeTrip=box.trip();if(longTrip&&!blocker&&!blockerRemoved&&activeTrip?.travelledM>100&&activeTrip.plan.points[activeTrip.index+80]){const point=activeTrip.plan.points[activeTrip.index+80];blocker={id:'actual-longtrip-blocker',r:point.r,c:point.c,ang:point.angle,parked:true,model:{name:'sedan'}};f.cars.push(blocker);logical.beginFrame();}
  if(blocker&&car._civilianBlockReason==='vehicle'){blockedAt||=f.now;blockedFrames++;}
  if(blocker&&blockedAt&&f.now-blockedAt>6000){f.cars.splice(f.cars.indexOf(blocker),1);blocker=null;blockerRemoved=true;logical.beginFrame();}
  const occupied=box._civilianTripTickNpc(npc,.05,f.now);
  box._civilianTripTickCar(car,.05);f.syncCar();
  if(!occupied){
   if(!box._residentNativeVisitTick(npc,.05,f.now)&&npc._civilianPlan?.tripDestination){
    if(!npc._route?.length)box._maybePlanResidentBuildingVisit(npc);
    if(!npc._routeSearchPending)box.actualFootTick(npc,.05,f.now);
   }
  }
  costs.push(performance.now()-t0);counts.frames++;
  const t=box.trip();if(longTrip&&t?.journey){assert.equal(t.journey.goalId,door.id);assert.equal(t.journey.range,'interdistrict');assert.notEqual(t.journey.originDistrict,t.journey.destinationDistrict);}
  const phase=t?.phase||npc._residentNativeVisit?.phase||npc._civilianPlan?.phase||'idle';seen.add(phase);
  if(phase!==previous){traces.push({frame,timeMs:f.now,phase,npc:{r:npc.r,c:npc.c},car:{r:car.r,c:car.c},visitStatus:npc._residentVisitStatus,routePending:!!npc._routeSearchPending,planStatus:car._civilianNativePlan?.status,planReason:car._civilianNativePlan?.reason});previous=phase;}
  const carStep=Math.hypot(car.r-old.carR,car.c-old.carC),npcStep=Math.hypot(npc.r-old.r,npc.c-old.c);maxStep=Math.max(maxStep,npcStep*M);counts.carDistanceM+=carStep*M;
  if(t?.nextGear){gearStopFrames++;assert.equal(carStep,0,'gear change stops the actual vehicle before reverse/forward');}
  if(!npc._civilianTripRiding)counts.footDistanceM+=npcStep*M;
  if(carStep>1e-9&&(!npc._civilianTripRiding||npc.hp<=0||npc.dead))carMovedWithoutDriver=true;
  if(carStep>0)assert((longNav||f.nav).query({carId:car.id,from:{r:old.carR,c:old.carC,angle:old.angle},to:{r:car.r,c:car.c,angle:car.ang},roadsOnly:false}).clear,'every actual moved car edge remains swept-clear');
  assert(npcStep<.23,'no pedestrian/seat teleport between frames');
  assert(carStep<=1.35*.05+1e-7,'car translation respects actual source speed');
  assert.equal(npcs.length,1,'source identity cannot disappear or duplicate');assert.equal(npcs[0],npc);
  assert(!npc._residentIndoors,'native visit never removes actor behind a timer');
  if(phase==='board')counts.boardFrames++;if(npc._civilianTripRiding)counts.rideFrames++;if(phase==='exit')counts.exitFrames++;if(npc._residentVisitStatus==='waiting-for-door')counts.doorWaitFrames++;if(npc._residentVisitStatus==='visiting')counts.insideFrames++;
  if(npc._residentVisitStatus==='visit-complete'){done=true;break;}
 }
}catch(e){error={message:e.message,stack:e.stack};}
costs.sort((a,b)=>a-b);
const report={longTrip,asyncLane,laneJobs:laneJobs?.diagnostics(),blockedFrames,blockerRemoved,farPresentationUnloaded:!presentationLoaded,farBeforeScheduling:true,parkingAnchor:car._nativeParkingAnchor,admissionCosts,gearStopFrames,scenario:'Actual native source civilian → authored car door → live seated drive → authored building entry → visible visit → physical exit',done,error,start,door,counts,phases:[...seen],trace:traces,maxNpcStepM:maxStep,carMovedWithoutDriver,cost:{p50Ms:costs[Math.floor(costs.length*.5)],p95Ms:costs[Math.floor(costs.length*.95)],maxMs:costs.at(-1)},final:{npc:{r:npc.r,c:npc.c,status:npc._residentVisitStatus,plan:npc._civilianPlan,routePending:npc._routeSearchPending,routeGoal:[npc._routeGoalR,npc._routeGoalC]},car:{r:car.r,c:car.c,nativePlan:car._civilianNativePlan},tripPhase:box.trip()?.phase},diagnostic:box.document.documentElement.dataset.civilianTrip,bodies:f.bodies.length,nav:f.nav.diagnostics(),limits:f.limits};
laneQueryCosts.sort((a,b)=>a-b);report.laneQuery={count:laneQueryCosts.length,p50Ms:laneQueryCosts[Math.floor(laneQueryCosts.length*.5)],p95Ms:laneQueryCosts[Math.floor(laneQueryCosts.length*.95)],maxMs:laneQueryCosts.at(-1)};report.callsOver1Ms=f.callCosts;report.lanes=f.lanes.diagnostics();
report.closedDoorBlocks=closedDoorBlocks;
if(process.argv.includes('--measure-lane')){
 report.warmLane=[];
 for(let i=0;i<3;i++){
  const begin=performance.now(),result=f.lanes.query({mode:'lane-route',from:start.car,to:{r:door.r,c:door.c,buildingId:door.sourceId},maxSnapDistance:12});
  report.warmLane.push({elapsedMs:performance.now()-begin,status:result.status,reason:result.reason});
 }
}
fs.writeFileSync(new URL('../../../outputs/'+(longTrip?(asyncLane?'npc_interdistrict_async_lifecycle_20260919.json':'npc_interdistrict_lifecycle_20260919.json'):'npc_native_parking_lifecycle_20260919.json'),import.meta.url),JSON.stringify(report,null,2));
console.log(JSON.stringify({done,error,counts,phases:[...seen],cost:report.cost,final:report.final},null,2));
laneJobs?.dispose();
assert(!error,error?.message);assert(done,'actual source lifecycle must finish within bounded frames');
for(const p of ['approach','board','drive','exit','entering','browsing','exiting'])assert(seen.has(p),'required physical phase '+p);
assert(counts.carDistanceM>(longTrip?400:8));if(longTrip){assert(blockerRemoved);assert(blockedFrames>100,'actual parked car blocks the long journey for six seconds before same driver resumes');}assert(counts.boardFrames>3&&counts.exitFrames>3&&counts.insideFrames>10);assert(!carMovedWithoutDriver);
assert(closedDoorBlocks,'closed door must separate actual outside/inside targets; visible state transition alone is insufficient');
console.log('PASS actual native civilian lifecycle with unchanged identity, physical boarding, swept drive, real door and visible visit/exit');
