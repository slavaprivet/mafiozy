import fs from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import {performance} from 'node:perf_hooks';
import {createHash} from 'node:crypto';
import {augmentCityParkingLaneEntries} from './city_parking_access.mjs';
import {createCarWorld,carFits,CAR} from './car_drive.mjs';
import {cityParkingCarFits} from './city_parking_plan.mjs';
import {createDirectedLaneRouter} from './city_directed_lane_router.mjs';
import {isExistingTrafficBridge} from './city_road_traffic_plan.mjs';
const root=new URL('../../../',import.meta.url),snapshotFile=new URL('outputs/roads_logical_20260912/integration_candidate_snapshot.json',root),bytes=fs.readFileSync(snapshotFile),snapshot=JSON.parse(bytes),topology=JSON.parse(fs.readFileSync(new URL('topology_for_placement.json',import.meta.url))),plan=snapshot.parkingPlan,access=plan.access;
const instances=[...snapshot.buildings,...snapshot.authoredDecor],extraBodies=[...snapshot.decorPlan.colliders,...snapshot.roadPlan.colliders],bodies=instances.flatMap(i=>i.collision?.worldBodies||[]).concat(plan.colliders,extraBodies),world=createCarWorld(topology,bodies,4.1),isRoad=(x,z)=>!!topology.roadMask[Math.floor(z/4.1)]?.[Math.floor(x/4.1)]||isExistingTrafficBridge(topology,x,z,4.1),poseAllowed=(x,z,yaw)=>carFits(x,z,yaw,world,CAR),router=createDirectedLaneRouter({preparedPlan:snapshot.roadPlan.preparedLaneGraph,isRoad,poseAllowed}),trafficPlan=snapshot.roadPlan.preparedLaneGraph.plan,from={x:80.155,z:200.409,yaw:0},angle=n=>Math.atan2(Math.sin(n),Math.cos(n));
const connected=new Map(),connection=(point,{routeId})=>{const key=routeId;if(!connected.has(key))connected.set(key,router.snap(point,{arrival:true,maxDistance:8}).length>0);return connected.get(key);},initial=JSON.stringify(access),start=performance.now(),augmented=augmentCityParkingLaneEntries({plan,access,topology,instances,extraBodies,trafficPlan,arrivalIsConnected:connection}),augmentationMs=performance.now()-start;
const additions=augmented.routes.slice(access.routes.length),issues=[],summaries=[];let poses=0;
for(const route of additions){const lot=plan.lots.find(l=>l.id===route.lotId),source=router.edgeById.get(route.laneAnchor.edgeId),support={surfaceRects:[lot.rect,lot.driveway],roadSupportRects:plan.roadSupportRects};
 assert(source);assert.deepEqual(route.points[0],source.points[route.laneAnchor.pointIndex]);assert.deepEqual(route.laneAnchor.point,route.points[0]);assert(Math.abs(route.laneAnchor.progressM-source.cumulative[route.laneAnchor.pointIndex])<1e-6);assert(isRoad(route.points[0].x,route.points[0].z));
 for(let i=1;i<route.points.length;i++){const a=route.points[i-1],b=route.points[i],dyaw=angle(b.yaw-a.yaw),d=Math.hypot(b.x-a.x,b.z-a.z),steps=Math.max(1,Math.ceil(d/.05),Math.ceil(Math.abs(dyaw)/(Math.PI/360))),yaw=a.yaw+dyaw/2;
  if(d>1e-7)assert(((b.x-a.x)*Math.sin(yaw)+(b.z-a.z)*Math.cos(yaw))/d>.999);if(Math.abs(dyaw)>1e-9)assert(d/Math.abs(dyaw)>=4.3-.001);
  for(let j=0;j<=steps;j++){const t=j/steps,p={x:a.x+(b.x-a.x)*t,z:a.z+(b.z-a.z)*t,yaw:a.yaw+dyaw*t};poses++;if(!poseAllowed(p.x,p.z,p.yaw)||!cityParkingCarFits(support,p.x,p.z,p.yaw))issues.push({id:route.id,i,t,p});}
 }
 const result=router.route({from,to:route.points[0],maxDistance:8});summaries.push({id:route.id,lotId:route.lotId,side:route.side,anchor:route.laneAnchor,pointCount:route.points.length,minRadiusM:route.minRadiusM,distance:route.distance,reachable:result.status==='ready',reason:result.reason});
}
const hash=b=>createHash('sha256').update(b).digest('hex'),report={createdAt:new Date().toISOString(),source:'additive pass over current actual final prepared graph; existing parking objects and source IDs preserved',snapshotSHA256:hash(bytes),snapshotStable:hash(fs.readFileSync(snapshotFile))===hash(bytes),augmentationMs,stats:augmented.stats,details:augmented.laneEntries,added:additions.length,poses,fullFinalBodies:bodies.length,issues,entries:summaries,limits:'CPU local entry geometry and fixed-origin graph reachability only; no GPU, full worker regeneration or runtime NPC controller.'};
fs.writeFileSync(new URL('outputs/roads_logical_20260912/parking_lane_entry_audit.json',root),JSON.stringify(report,null,2));console.log(JSON.stringify({...report,entries:summaries.map(r=>({id:r.id,reachable:r.reachable,reason:r.reason,radius:r.minRadiusM})),issues:issues.slice(0,5)},null,2));

test('the additive pass preserves all old route identities, physical marks and source data',()=>{
 assert.equal(JSON.stringify(access),initial);for(let i=0;i<access.routes.length;i++)assert.strictEqual(augmented.routes[i],access.routes[i]);assert.strictEqual(augmented.markings,access.markings);assert.strictEqual(augmented.issues,access.issues);assert.equal(new Set(augmented.routes.map(r=>r.id)).size,augmented.routes.length);
 assert.equal(augmented.stats.verifiedEntryLots,39);assert.equal(augmented.stats.verifiedExitLots,39);assert(additions.length>0,'fixture should exercise actual disconnected parking arrivals');
 for(const lot of plan.lots){const rows=augmented.routes.filter(r=>r.lotId===lot.id&&r.laneAnchor);assert(rows.length<=4);for(const side of [1,-1])assert(rows.filter(r=>r.side===side).length<=2);}
});
test('new entries start exactly on the source lane and satisfy forward radius and full own-paving sweeps',()=>{assert.deepEqual(issues,[]);assert(poses>0);assert(summaries.some(r=>r.reachable),'at least one disconnected arrival gains a real reachable lane anchor');});
test('connected arrivals skip augmentation without touching the original access object',()=>{
 assert.strictEqual(augmentCityParkingLaneEntries({plan,access,topology,instances,extraBodies,trafficPlan,arrivalIsConnected:()=>true}),access);
});
