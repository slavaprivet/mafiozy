// Test-only actual source/worker/geometry lifecycle from the recorded trip17
// origin. Does not claim the unknown LIVE vehicle profile/history is recovered.
import fs from 'node:fs';
import vm from 'node:vm';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {setTimeout as delay} from 'node:timers/promises';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';
import {createLaneRouteJobs} from './city_lane_route_jobs.mjs';
import {nodeLaneWorker} from './test_lane_worker_adapter.mjs';
import {createCityRoadNavigation} from './city_road_navigation.mjs';
import {createNpcVehicleNavigation} from './npc_vehicle_navigation.mjs';
import {createNpcLogicalVehicleBinding} from './npc_logical_vehicle_binding.mjs';
import {createCarWorld,carFits} from './car_drive.mjs';

const hashFile=p=>crypto.createHash('sha256').update(fs.readFileSync(new URL(p,import.meta.url))).digest('hex');
const pins={snapshot:'7cc0043339615a3fecf74eb0c3c0ebc46b75a76c78cf82f133952f891bd8f8d9',topology:'11f256f20ea5f8f5387fa4829173e84cf688aa2ba554aa5b6aacdb85301d67b6'};
assert.equal(hashFile('../../../outputs/roads_logical_20260912/integration_candidate_snapshot.json'),pins.snapshot,'review geometry changes before refreshing this pin');
assert.equal(hashFile('topology_for_placement.json'),pins.topology);
const observed={carId:'local_vehicle_17',npcId:'resident_2',from:{r:35.34146341463414,c:42.109756097560975,angle:-Math.PI/2},npc:{r:32.85541513915751,c:38.5},goalId:'REBUILD-VISUAL-pine_ridge_cottage_v1-001'};
const jobs=createLaneRouteJobs({createWorker:nodeLaneWorker}),f=await createCivilianNativeFixture({assetId:'pine_ridge_cottage_v1'}),{box,car,npcs,M}=f;
assert.equal(f.item.id,observed.goalId);box.window.__npcTripDiagnostics=true;
const door=box._residentBuildingDoors()[0];assert(door);assert.equal(door.instanceId,observed.goalId);
const npc={id:observed.npcId,...observed.npc,hp:60,max_hp:60,alive:true,speed:.9286360584051568,walkPhase:0,_arcKey:'worker',_npcRoutine:'work'};npcs.push(npc);box._npcAgendaAdopt(npc,'drive');
const profile={halfLength:f.actor.profile.collisionHalfLength??f.actor.profile.halfLength,halfWidth:f.actor.profile.collisionHalfWidth??f.actor.profile.halfWidth};
const originBay=f.snapshot.parkingPlan.bays.find(b=>Math.hypot(b.x-observed.from.c*M,b.z-observed.from.r*M)<1e-7);assert(originBay);
Object.assign(car,{id:observed.carId,r:observed.from.r,c:observed.from.c,ang:observed.from.angle,dirDy:Math.sin(observed.from.angle),dirDx:Math.cos(observed.from.angle),_nativeParkingPresented:true,_nativeParkingShape:{halfLength:profile.halfLength/M,halfWidth:profile.halfWidth/M},_nativeParkingAnchor:{id:originBay.id,lotId:originBay.lotId,r:observed.from.r,c:observed.from.c}});
box.car=car;box.npc=npc;vm.runInContext('_nativeParkingAdmission.reservations.set(car._nativeParkingAnchor.id,car);globalThis.tripApi={forCar:_civilianTripForCar,forNpc:_civilianTripForNpc,reservations:_nativeParkingAdmission.reservations,count:_civilianTripCount,release:_civilianTripRelease};',box);
box.player={r:180,c:180};f.syncCar();
f.actor.object.removeFromParent();
const logical=createNpcLogicalVehicleBinding({bridge:{getWalkNpcVehicleBinding:q=>box._getWalkNpcVehicleBinding(q),getWalkNpcVehicleTraffic:()=>box._getWalkNpcVehicleTraffic()},worldScale:M,groundHeight:f.floor,getTemplate:id=>id==='compact_sedan'?f.actor:null,getVisibleVehicle:()=>null,getVisibleNpc:()=>null});
let world=createCarWorld(f.top,f.bodies,M);
const isRoad=(x,z)=>!!f.top.roadMask?.[Math.floor(z/M)]?.[Math.floor(x/M)];
const native=createNpcVehicleNavigation({worldScale:M,isRoad,poseAllowed:(x,z,yaw,p)=>carFits(x,z,yaw,world,p),waterAt:f.waterAt,groundHeight:f.floor,getVehicle:logical.getActor,getVehicles:logical.getVehicles,inspectRoutes:true});
const lanes=createCityRoadNavigation({routeJobs:jobs,getRoadPlan:()=>f.snapshot.roadPlan,getParkingPlan:()=>f.snapshot.parkingPlan,getInstances:()=>f.snapshot.buildings,isRoad,poseAllowed:(x,z,yaw,p)=>carFits(x,z,yaw,world,p),getVehicleProfile:()=>profile,metresPerCell:M});
jobs.initialize({topology:f.top,bodies:f.bodies,roadPlan:f.snapshot.roadPlan,parkingPlan:f.snapshot.parkingPlan,instances:f.snapshot.buildings,metresPerCell:M});
const original=box.nativeTrafficQuery,events=[],requests=new Set();let firstLaneRejection=null,firstFallback=null;
box.nativeTrafficQuery=q=>{
 const result=q.mode==='driver'?logical.driver(q):['lane-route','lane-route-cancel','lane-route-touch','parking-destination','parking-exit','parking-anchors','road-rules'].includes(q.mode)?lanes.query(q):q.mode==='resident-access'?original(q):native.query(q);
 if(q.mode==='lane-route'&&result?.status!=='pending'&&!requests.has(q.requestId)){requests.add(q.requestId);const e={atMs:f.now,mode:q.mode,request:structuredClone(q),result:{status:result?.status,reason:result?.reason,points:result?.points?.length||0}};events.push(e);if(result?.status==='blocked')firstLaneRejection||=e;}
 if(q.mode==='route'){const e={atMs:f.now,mode:q.mode,request:structuredClone(q),result:{status:result?.status,reason:result?.reason,expanded:result?.expanded,points:result?.points?.length||0}};firstFallback||=e;if(result?.status==='blocked'&&!requests.has(q.requestId)){requests.add(q.requestId);events.push(e);}}
 return result;
};
box.logicalAccess=logical.access;vm.runInContext('_walkTrafficNavigationResolver=nativeTrafficQuery;_walkNpcVehicleAccessResolver=logicalAccess;',box);
logical.beginFrame();f.pedestrian.beginFrame();assert.equal(logical.access({carId:car.id,npcId:npc.id,phase:'board'}),null);
assert(box._npcAgendaTryDrive(npc,f.now),'actual source agenda must reserve exact car17 from actual NPC2 position');
const trip=box.tripApi.forCar(car);assert.equal(trip.npc,npc);trip.destinationDoor=door;
const costs=[],phases=[],counts={frames:0,carDistanceM:0,footDistanceM:0,boardFrames:0,exitFrames:0},initial={car:[car.r,car.c,car.ang],npc:[npc.r,npc.c]},limit=Number(process.argv.find(a=>a.startsWith('--frames='))?.slice(9))||9000;
let done=false,error=null,bodyVersion=f.bodies;
try{
 for(let i=0;i<limit;i++){
  if(box.trip()?.phase==='planning')await delay(2);
  f.nextFrame(.05);logical.beginFrame();native.beginFrame();if(f.bodies!==bodyVersion){bodyVersion=f.bodies;world=createCarWorld(f.top,f.bodies,M);}
  const old={r:npc.r,c:npc.c,cr:car.r,cc:car.c,angle:car.ang},start=performance.now(),active=box._civilianTripTickNpc(npc,.05,f.now);box._civilianTripTickCar(car,.05);f.syncCar();
  if(!active){if(!box._residentNativeVisitTick(npc,.05,f.now)&&npc._civilianPlan?.tripDestination){if(!npc._route?.length)box._maybePlanResidentBuildingVisit(npc);if(!npc._routeSearchPending)box.actualFootTick(npc,.05,f.now);}}
  costs.push(performance.now()-start);counts.frames++;
  const t=box.tripApi.forCar(car),phase=t?.phase||npc._residentNativeVisit?.phase||npc._civilianPlan?.phase||'released';if(phases.at(-1)?.phase!==phase)phases.push({atMs:f.now,phase,reason:car._civilianNativePlan?.reason||trip.releaseReason||null});
  const carStep=Math.hypot(car.r-old.cr,car.c-old.cc),npcStep=Math.hypot(npc.r-old.r,npc.c-old.c);counts.carDistanceM+=carStep*M;if(!npc._civilianTripRiding)counts.footDistanceM+=npcStep*M;
  assert(carStep<=1.35*.05+1e-7,'no car teleport');assert(npcStep<.23,'no NPC/seat teleport');assert.equal(npcs.length,1);assert.equal(npcs[0],npc);
  if(carStep){assert(npc._civilianTripRiding);assert(native.query({carId:car.id,from:{r:old.cr,c:old.cc,angle:old.angle},to:{r:car.r,c:car.c,angle:car.ang},roadsOnly:false}).clear,'actual hull swept on every driven step');}
  if(t){assert.equal(t.npc,npc);assert.equal(box.tripApi.forNpc(npc),t);assert.equal(t.car,car);}if(phase==='board')counts.boardFrames++;if(phase==='exit')counts.exitFrames++;
  if(!t&&!npc._civilianPlan?.tripDestination&&!npc._residentNativeVisit){done=true;break;}
  if(npc._residentVisitStatus==='visit-complete'){done=true;break;}
 }
}catch(e){error={message:e.message,stack:e.stack};}finally{jobs.dispose();}
if(process.argv.includes('--approach-audit'))console.log(JSON.stringify({approachAudit:{door:trip.door,access:trip.access,approachStatus:trip.approachStatus,approachBlock:trip.approachBlock,doorTrace:trip.doorTrace,nativeStart:f.pedestrian.query({r:npc.r,c:npc.c}),sourceStartClear:box._npcBodyPassable(npc.r,npc.c),directed:npc._npcDirectedSearch}},null,2));
costs.sort((a,b)=>a-b);
const report={pass:done&&!error,pins,observed,profile:{...profile,provenance:'actual fixture compact sedan; LIVE car17 profile not supplied'},initial,done,error,firstLaneRejection,firstFallback,events,phases,counts,releaseReason:trip.releaseReason||null,final:{car:{r:car.r,c:car.c,angle:car.ang,parked:car.parked,anchor:car._nativeParkingAnchor||null},npc:{r:npc.r,c:npc.c,agenda:npc._npcAgenda,visitStatus:npc._residentVisitStatus||null},activeTrips:box.tripApi.count(),reservations:[...box.tripApi.reservations].map(([id,c])=>({id,carId:c.id}))},cpu:{p50Ms:costs[Math.floor(costs.length*.5)],p95Ms:costs[Math.floor(costs.length*.95)]},limits:'Pinned authored static geometry, actual worker/source/door/agenda. Recorded origin/NPC pose and one known goal, compact fixture profile. Missing actual LIVE profile, original allowed lot subset, other traffic, prior four door attempts and GPU/FPS.'};
fs.writeFileSync(new URL('../../../outputs/transport_trip17_lifecycle23.json',import.meta.url),JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));assert(!error,error?.message);assert(done,'bounded lifecycle must finish or release');
