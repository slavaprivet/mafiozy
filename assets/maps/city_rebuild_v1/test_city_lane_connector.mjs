import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {createHash} from 'node:crypto';
import {createLaneConnector,makeLaneConnector} from './city_lane_connector.mjs';
import {CAR,createCarWorld,carFits} from './car_drive.mjs';
import {isExistingTrafficBridge} from './city_road_traffic_plan.mjs';

const free={isRoad:()=>true,poseAllowed:()=>true},angle=n=>Math.atan2(Math.sin(n),Math.cos(n)),hypot=(a,b)=>Math.hypot(b.x-a.x,b.z-a.z),origin={x:0,z:0,yaw:0};
function verify(result,from,to,minRadius=4.3){
 assert(result,'a physical curve exists');assert.deepEqual(result.points[0],from);assert.deepEqual(result.points.at(-1),to);assert(result.minRadiusM>=minRadius);assert.equal(result.lengthM,result.length);
 let length=0,minMeasuredRadius=Infinity;
 for(let i=1;i<result.points.length;i++){
  const a=result.points[i-1],b=result.points[i],d=hypot(a,b),yawDelta=angle(b.yaw-a.yaw),yaw=a.yaw+yawDelta/2;length+=d;assert(d>0&&d<=.15000001,'bounded positional steps');assert(Math.abs(yawDelta)<=Math.PI/180+1e-8,'no instantaneous heading jump');assert(((b.x-a.x)*Math.sin(yaw)+(b.z-a.z)*Math.cos(yaw))/d>.999,'movement follows the nose');
  if(i>1){const p=result.points[i-2],cross=Math.abs((a.x-p.x)*(b.z-p.z)-(a.z-p.z)*(b.x-p.x)),radius=cross>1e-12?hypot(p,a)*hypot(a,b)*hypot(p,b)/(2*cross):Infinity;minMeasuredRadius=Math.min(minMeasuredRadius,radius);}
 }
 assert(Math.abs(length-result.lengthM)<1e-6);assert(minMeasuredRadius>=minRadius-.005,'independent circumcircle curvature check');return minMeasuredRadius;
}

test('forward straight, lane change, quarter turn and U-turn preserve endpoints and radius',()=>{
 assert.strictEqual(makeLaneConnector,createLaneConnector);
 for(const to of [{x:0,z:12,yaw:0},{x:2,z:12,yaw:0},{x:8,z:8,yaw:Math.PI/2},{x:10,z:0,yaw:Math.PI}]){
  const before=structuredClone(to),result=createLaneConnector({...free,from:origin,to,sampleStep:.3});verify(result,origin,to);assert.deepEqual(to,before);
 }
 for(const yaw of [-Math.PI,Math.PI/2,2*Math.PI-.12]){
  const map=p=>({x:30+p.x*Math.cos(yaw)+p.z*Math.sin(yaw),z:-10-p.x*Math.sin(yaw)+p.z*Math.cos(yaw),yaw:p.yaw+yaw}),from=map(origin),to=map({x:2,z:12,yaw:0});verify(createLaneConnector({...free,from,to}),from,to);
 }
});

test('sideways, backwards, zero-distance rotation and excessive curvature fail closed',()=>{
 for(const to of [{x:2,z:0,yaw:0},{x:0,z:-4,yaw:0},{x:0,z:0,yaw:Math.PI/2},{x:1e-9,z:0,yaw:.01},{x:1,z:1,yaw:Math.PI/2}])assert.equal(createLaneConnector({...free,from:origin,to}),null);
 const exact=createLaneConnector({...free,from:origin,to:{...origin}});assert.equal(exact.points.length,1);assert.equal(exact.lengthM,0);
 assert.equal(createLaneConnector({...free,from:origin,to:{x:0,z:37,yaw:0}}),null);
 for(const invalid of [{minRadius:0},{sampleStep:0},{maxDistance:NaN},{poseAllowed:null},{isRoad:null},{from:{x:NaN,z:0,yaw:0}}])assert.equal(createLaneConnector({...free,from:origin,to:{x:0,z:12,yaw:0},...invalid}),null);
});

test('the complete hull and road surface reject a crossing blocker between clear endpoints',()=>{
 const topology={grid:Array.from({length:10},()=>Array(10).fill(0))},body={polygonCR:[[3,4.8],[3.1,4.8],[3.1,5.2],[3,5.2]],minYM:0,maxYM:2},world=createCarWorld(topology,[body],1),from={x:2,z:1,yaw:0},to={x:2,z:9,yaw:0};
 // Its centre line misses the post. The 2.56m-wide full CAR hits it.
 assert.equal(createLaneConnector({from,to,isRoad:()=>true,poseAllowed:(x,z,yaw)=>carFits(x,z,yaw,world,CAR)}),null);
 assert.equal(createLaneConnector({...free,from:origin,to:{x:0,z:12,yaw:0},isRoad:(x,z)=>z<5||z>6}),null);
 const result=createLaneConnector({...free,from:origin,to:{x:2,z:12,yaw:0},poseAllowed:(x,z,yaw)=>Number.isFinite(yaw)&&z>=0&&z<=12});verify(result,origin,{x:2,z:12,yaw:0});
 assert.equal(createLaneConnector({...free,from:origin,to:{x:2,z:12,yaw:0},poseAllowed:(x,z)=>z<5||z>7}),null,'cached geometry must not cache yesterday\'s collision clearance');
 verify(createLaneConnector({...free,from:origin,to:{x:2,z:12,yaw:0}}),origin,{x:2,z:12,yaw:0});
});

test('an actual residential lane joins its preserved parking entry through a forward full-hull curve',()=>{
 const root=new URL('../../../',import.meta.url),snapshotFile=new URL('outputs/roads_logical_20260912/integration_candidate_snapshot.json',root),bytes=fs.readFileSync(snapshotFile),s=JSON.parse(bytes),topology=JSON.parse(fs.readFileSync(new URL('topology_for_placement.json',import.meta.url))),before=JSON.parse(fs.readFileSync(new URL('outputs/roads_logical_20260912/ready_route_full_hull_pre_connector.json',root)));
 const record=before.rows.find(r=>r.id==='REBUILD-VISUAL-old_town_narrow_townhouse_v1-001'),bad=record.gearFailures[0];assert(bad&&bad.signed<0,'saved audit reproduces the original unmarked sideways/backward connector');
 const bodies=[...s.buildings,...s.authoredDecor].flatMap(i=>i.collision?.worldBodies||[]).concat(s.decorPlan.colliders,s.roadPlan.colliders,s.parkingPlan.colliders),world=createCarWorld(topology,bodies,4.1),isRoad=(x,z)=>!!topology.roadMask[Math.floor(z/4.1)]?.[Math.floor(x/4.1)]||isExistingTrafficBridge(topology,x,z,4.1),poseAllowed=(x,z,yaw)=>carFits(x,z,yaw,world,CAR);
 const graph=s.roadPlan.preparedLaneGraph.plan,edge=[...graph.connections,...graph.turns].find(e=>e.id===record.edgeIds.at(-1));assert(edge);
 let nearest=0;for(let i=1;i<edge.points.length;i++)if(hypot(edge.points[i],bad.a)<hypot(edge.points[nearest],bad.a))nearest=i;
 const attempts=[];let accepted;
 for(const upstream of [4,6,8,10,12,16]){
  let index=nearest,length=0;while(index>0&&length<upstream){length+=hypot(edge.points[index],edge.points[index-1]);index--;}
  const from=edge.points[index],start=performance.now(),result=createLaneConnector({from,to:bad.b,isRoad,poseAllowed});attempts.push({upstream,from,accepted:!!result,ms:performance.now()-start,lengthM:result?.lengthM,minRadiusM:result?.minRadiusM});if(result){accepted={from,result};break;}
 }
 assert(accepted,'upstream attachment admits a real forward curve on this actual frontage');verify(accepted.result,accepted.from,bad.b);
 let sweptSamples=0;for(let i=1;i<accepted.result.points.length;i++){const a=accepted.result.points[i-1],b=accepted.result.points[i],dyaw=angle(b.yaw-a.yaw),n=Math.max(1,Math.ceil(hypot(a,b)/.02));for(let j=0;j<=n;j++){const t=j/n,x=a.x+(b.x-a.x)*t,z=a.z+(b.z-a.z)*t,yaw=a.yaw+dyaw*t;assert(isRoad(x,z));assert(carFits(x,z,yaw,world,CAR),'independent dense interpolation remains clear');sweptSamples++;}}
 for(let i=0;i<40;i++)createLaneConnector({from:accepted.from,to:bad.b,isRoad,poseAllowed});const timings=[];for(let i=0;i<51;i++){const start=performance.now();createLaneConnector({from:accepted.from,to:bad.b,isRoad,poseAllowed});timings.push(performance.now()-start);}timings.sort((a,b)=>a-b);
 const hash=b=>createHash('sha256').update(b).digest('hex'),report={createdAt:new Date().toISOString(),snapshotSHA256:hash(bytes),snapshotStable:hash(fs.readFileSync(snapshotFile))===hash(bytes),previousSidewaysConnector:bad,attempts,accepted:{from:accepted.from,to:bad.b,lengthM:accepted.result.lengthM,minRadiusM:accepted.result.minRadiusM,points:accepted.result.points.length,sweptSamples},fullFinalBodies:bodies.length,cpu:{p50Ms:timings[25],p95Ms:timings[48]},limits:'CPU bounded endpoint connector only, no graph/follower integration or GPU acceptance.'};fs.writeFileSync(new URL('outputs/roads_logical_20260912/lane_connector_actual_audit.json',root),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
});
