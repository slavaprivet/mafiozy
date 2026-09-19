import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {createHash} from 'node:crypto';
import {planCityServiceAccess} from './city_service_access_plan.mjs';
import {getDetentionRoadStopPose} from './detention_road_stop_pose.mjs';
import {CAR,createCarWorld,carFits} from './car_drive.mjs';
import {cityParkingCarFits} from './city_parking_plan.mjs';
import {createLandscapePlan} from './landscape_plan.mjs';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';
import {createCityRoadDressingPlan} from './city_road_dressing_plan.mjs';
import {explorationKeepouts} from './exploration_scene_support.mjs';
import {prepareDirectedLanePlan,createDirectedLaneRouter} from './city_directed_lane_router.mjs';
import {isExistingTrafficBridge} from './city_road_traffic_plan.mjs';

// Rebuild roads and their controls from current source, including the narrow
// passage and waterfront lane inset. The stored snapshot supplies existing
// placement, parking and decor only; it cannot conceal an outdated road graph.
const root=new URL('../../../',import.meta.url),file=new URL('outputs/roads_logical_20260912/integration_candidate_snapshot.json',root),bytes=fs.readFileSync(file),s=JSON.parse(bytes),topology=JSON.parse(fs.readFileSync(new URL('topology_for_placement.json',import.meta.url))),instances=[...s.buildings,...s.authoredDecor];
const landscape=createLandscapePlan(),railPlan=createExplorationRailwayPlan({landscape,topology}),roadPlan=createCityRoadDressingPlan({topology,landscape,railPlan,instances,keepouts:[...explorationKeepouts(instances),...explorationKeepouts([{collision:{worldBodies:s.decorPlan.colliders}}]),...s.parkingPlan.keepouts],accessKeepouts:s.parkingPlan.accessKeepouts,pedestrianBodies:[...s.decorPlan.colliders,...s.parkingPlan.colliders]});
const extraBodies=[...s.decorPlan.colliders,...roadPlan.colliders,...s.parkingPlan.colliders],bodyList=instances.flatMap(i=>i.collision?.worldBodies||[]).concat(extraBodies),world=createCarWorld(topology,bodyList,4.1),isRoad=(x,z)=>!!topology.roadMask[Math.floor(z/4.1)]?.[Math.floor(x/4.1)]||isExistingTrafficBridge(topology,x,z),poseAllowed=(x,z,yaw)=>carFits(x,z,yaw,world),prepared=prepareDirectedLanePlan({plan:roadPlan.trafficPlan,isRoad,poseAllowed}),trafficPlan=prepared.plan,router=createDirectedLaneRouter({preparedPlan:prepared,isRoad,poseAllowed});
const options={trafficPlan,instances,topology,extraBodies,roadSupportRects:s.parkingPlan.roadSupportRects},support={surfaceRects:[],roadSupportRects:options.roadSupportRects},angle=n=>Math.atan2(Math.sin(n),Math.cos(n)),dist=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z),sha=b=>createHash('sha256').update(b).digest('hex'),begun=performance.now(),actual=planCityServiceAccess(options),constructionMs=performance.now()-begun,ids=['REBUILD-DETENTION-southside','REBUILD-DETENTION-iron_harbor','REBUILD-DETENTION-chinatown'];

test('current prepared frontage entries preserve exact source poses, corrected stops and physical gear',()=>{
 assert.deepEqual(actual.issues,[]);assert.deepEqual(actual.routes.map(r=>r.buildingId).sort(),[...ids].sort());let samples=0;
 for(const route of actual.routes){
  const building=instances.find(i=>i.id===route.buildingId),source=[...trafficPlan.turns,...trafficPlan.connections].find(e=>e.id===route.laneAnchor.edgeId),first=route.points[0],last=route.points.at(-1),gear=route.buildingId.endsWith('southside')?-1:1;
  assert(source);assert.deepEqual(route.laneAnchor.point,{x:first.x,z:first.z,yaw:first.yaw});assert.deepEqual(route.laneAnchor.point,source.points[route.laneAnchor.pointIndex]);assert(Math.abs(route.laneAnchor.progressM-source.cumulative[route.laneAnchor.pointIndex])<1e-8);
  assert.deepEqual({x:last.x,z:last.z,yaw:last.yaw},getDetentionRoadStopPose(building));assert.equal(route.gear,gear);assert.equal(route.requiresStopBeforeReverse,gear<0);assert(route.minRadiusM>=4.3);assert(route.speedLimitKmh<=6);assert(route.points.every(p=>p.gear===gear));
  if(route.retainedTurnId){assert.equal(route.retainedTurnId,source.id);assert.equal(route.retainedApproachId,source.fromApproachId);assert(route.actualConflictTurnIds.every(id=>route.retainedConflictTurnIds.includes(id)));}
  let length=0,minCircumradius=Infinity;
  for(let i=1;i<route.points.length;i++){
   const a=route.points[i-1],b=route.points[i],gap=dist(a,b),dyaw=angle(b.yaw-a.yaw),yaw=a.yaw+dyaw/2;length+=gap;assert(gap>0&&gap<=.150001);assert(Math.abs(dyaw)<=Math.PI/180+1e-8);assert(((b.x-a.x)*Math.sin(yaw)+(b.z-a.z)*Math.cos(yaw))*gear/gap>.999);
   if(i>1){const p=route.points[i-2],cross=Math.abs((a.x-p.x)*(b.z-p.z)-(a.z-p.z)*(b.x-p.x));if(cross>1e-12)minCircumradius=Math.min(minCircumradius,dist(p,a)*dist(a,b)*dist(p,b)/(2*cross));}
   const count=Math.max(1,Math.ceil(gap/.025),Math.ceil(Math.abs(dyaw)/(Math.PI/360)));for(let n=0;n<=count;n++){const t=n/count,x=a.x+(b.x-a.x)*t,z=a.z+(b.z-a.z)*t,yaw=a.yaw+dyaw*t;samples++;assert(topology.roadMask[Math.floor(z/4.1)]?.[Math.floor(x/4.1)]);assert(carFits(x,z,yaw,world,CAR));assert(cityParkingCarFits(support,x,z,yaw),'complete rectangle remains on real asphalt');}
  }
  assert(Math.abs(length-route.lengthM)<1e-8);assert(minCircumradius>=4.3-.005);
 }
 assert(samples>1200);
 fs.writeFileSync(new URL('outputs/roads_logical_20260912/service_access_plan_audit.json',root),JSON.stringify({createdAt:new Date().toISOString(),snapshotSHA256:sha(bytes),snapshotStable:sha(bytes)===sha(fs.readFileSync(file)),constructionMs,fullFinalBodies:bodyList.length,samples,issues:actual.issues,routes:actual.routes.map(r=>({...r,points:undefined})),limits:'Fresh road dressing and prepared graph; existing placement/parking/decor snapshot. Construction-time CPU and static geometry only. No full worker build, GPU scene or authoritative actor execution.'},null,2));
});

test('actual city routes retain the signal and right-priority control before service entry',()=>{
 for(const route of actual.routes){
  const prefix=router.route({from:{x:80.155,z:200.409,yaw:0},to:route.points[0],toAnchor:route.laneAnchor});
  assert.equal(prefix.status,'ready');
  if(!route.retainedTurnId)continue;
  const control=prefix.controls.find(c=>c.turnId===route.retainedTurnId);assert(control,'source TURN control remains in the actual route');
  assert.equal(control.approachId,route.retainedApproachId);assert(control.distanceM<prefix.distanceM);assert(control.stopPoint);
  assert(route.actualConflictTurnIds.every(id=>control.conflictingTurnIds.includes(id)));
  if(route.buildingId.endsWith('iron_harbor')){assert.equal(control.rule,'signal');assert.equal(control.signalId,'road-traffic_signal-21');}
  else assert.equal(control.rule,'priority_right');
 }
});

test('renumbering every TURN keeps semantic selections and resolves new exact IDs',()=>{
 const renamed={...trafficPlan,turns:trafficPlan.turns.map(t=>({...t,id:'renumbered:'+t.id}))},result=planCityServiceAccess({...options,trafficPlan:renamed});assert.deepEqual(result.issues,[]);assert.equal(result.routes.length,3);
 for(const r of result.routes){const old=actual.routes.find(o=>o.buildingId===r.buildingId);assert.deepEqual(r.points,old.points);assert.deepEqual(r.laneAnchor.point,old.laneAnchor.point);if(r.retainedTurnId){assert.equal(r.retainedTurnId,'renumbered:'+old.retainedTurnId);assert(r.retainedConflictTurnIds.every(id=>id.startsWith('renumbered:')));}}
});

test('a missing semantic edge or road-support source fails closed without a neighbouring-street snap',()=>{
 const south=actual.routes.find(r=>r.buildingId.endsWith('southside')),without={...trafficPlan,turns:trafficPlan.turns.filter(t=>t.fromLaneId!==south.laneAnchor.fromLaneId||t.toLaneId!==south.laneAnchor.toLaneId)},missing=planCityServiceAccess({...options,trafficPlan:without});assert.equal(missing.routes.length,2);assert.deepEqual(missing.issues,[{buildingId:south.buildingId,reason:'missing_prepared_service_edge'}]);
 const unsupported=planCityServiceAccess({...options,roadSupportRects:[]});assert.equal(unsupported.routes.length,0);assert.equal(unsupported.issues.length,3);assert(unsupported.issues.every(i=>i.reason==='missing_road_support'));assert.throws(()=>planCityServiceAccess({...options,metresPerCell:3}),RangeError);
});

test('new final-world obstacles and asphalt loss cannot reuse old clearance',()=>{
 const china=actual.routes.find(r=>r.buildingId.endsWith('chinatown')),p=china.points.at(-1),post={polygonCR:[[p.x-.1,p.z-.1],[p.x+.1,p.z-.1],[p.x+.1,p.z+.1],[p.x-.1,p.z+.1]].map(([x,z])=>[x/4.1,z/4.1]),minYM:0,maxYM:2},blocked=planCityServiceAccess({...options,extraBodies:[...extraBodies,post]});assert(!blocked.routes.some(r=>r.buildingId===china.buildingId));assert(blocked.issues.some(i=>i.buildingId===china.buildingId&&i.reason==='blocked_service_stop'));
 const gap={...topology,roadMask:topology.roadMask.map(r=>[...r])};gap.roadMask[Math.floor(p.z/4.1)][Math.floor(p.x/4.1)]=0;assert(!planCityServiceAccess({...options,topology:gap}).routes.some(r=>r.buildingId===china.buildingId));assert.equal(planCityServiceAccess(options).routes.length,3,'cached curve geometry must not cache obstacle clearance');
});

test('new traffic stop lines and crossing turns cannot silently enter a service suffix',()=>{
 const china=actual.routes.find(r=>r.buildingId.endsWith('chinatown')),stop=china.points.at(-1),line={id:'test-service-new-stop-line',x:stop.x,z:stop.z+2,approaches:[{id:'test-service-new-approach',outward:{x:0,z:1},width:8,stopPoint:{x:stop.x,z:stop.z+2},rule:'signal',signalId:'test-signal'}]},withLine={...trafficPlan,junctionRules:[...(trafficPlan.junctionRules||trafficPlan.junctions),line]},blockedLine=planCityServiceAccess({...options,trafficPlan:withLine});assert(!blockedLine.routes.some(r=>r.buildingId===china.buildingId));assert(blockedLine.issues.some(i=>i.buildingId===china.buildingId&&i.reason==='unretained_service_stop_line'));
 const crossing={id:'test-crossing-service-stop',fromApproachId:'test-other-approach',fromLaneId:'test-other-in',toLaneId:'test-other-out',points:[{x:stop.x-4,z:stop.z,yaw:Math.PI/2},{x:stop.x+4,z:stop.z,yaw:Math.PI/2}]},withCrossing={...trafficPlan,turns:[...trafficPlan.turns,crossing]},blockedTurn=planCityServiceAccess({...options,trafficPlan:withCrossing});assert(!blockedTurn.routes.some(r=>r.buildingId===china.buildingId));assert(blockedTurn.issues.some(i=>i.buildingId===china.buildingId&&i.reason==='new_service_turn_conflict'));
});
