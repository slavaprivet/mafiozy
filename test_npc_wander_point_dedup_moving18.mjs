import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
const source=fs.readFileSync('world.html','utf8').replace(/\r\n/g,'\n'),pick=sourceFunction(source,'pickNpcWaypoint');
const before=pick.replace('!wanderEdgePassable(fr,fc,r+.5,c+.5)','!_npcPathPassable(fr,fc,r+.5,c+.5,edgePass)');
assert.notEqual(before,pick);
const percentile=(a,p)=>[...a].sort((x,y)=>x-y)[Math.min(a.length-1,Math.floor(a.length*p))]||0;
const random=()=>{let s=77;const math=Object.create(Math);math.random=()=>((s=Math.imul(s,1664525)+1013904223>>>0)/4294967296);return math;};
const f=await createCivilianNativeFixture(),b=f.box,origins=[];
b._civilianPlanNext=()=>false;b._maybePlanResidentBuildingVisit=()=>false;
for(let r=3;r<b.MAP_ROWS-4&&origins.length<288;r+=2)for(let c=3;c<b.MAP_COLS-4&&origins.length<288;c+=2){
 const n={r:r+.5,c:c+.5};if(origins.length%10===0)n.c+=.11;
 if(b.npcWaypointOk(n,n.r,n.c)&&b._npcBodyPassable(n.r,n.c,b.npcPassable))origins.push(n);
}
assert.equal(origins.length,288);

function moving(code){
 b.Math=random();b.NPCS.length=0;for(let i=0;i<origins.length;i++)b.NPCS.push({id:'moving-'+i,...origins[i],hp:60});
 vm.runInContext('_npcRouteWorkFrame=null;_npcRouteWorkQueue.clear();_npcRouteWorkServed.clear();',b);vm.runInContext(code,b);
 let issues=0,arrivals=0,blocked=0,distance=0,movingSamples=0,pendingSamples=0,plannerCpu=0,motionCpu=0;const latency=[],costs=[];
 for(let frame=0;frame<1200;frame++){
  f.nextFrame(.05);let frameRouteCpu=0;
  for(const n of b.NPCS){
   if(!n._route?.length&&!(n.idleUntil>f.now)){
    n.testRequestAt??=f.now;const t=performance.now();
    if(b.pickNpcWaypoint(n)){issues++;latency.push(f.now-n.testRequestAt);n.testRequestAt=null;}
    frameRouteCpu+=performance.now()-t;
   }
   if(!n._route?.length){if(n._npcWanderSearch)pendingSamples++;continue;}
   const t=performance.now(),to=n._route[n._routeIndex||0],dr=to.r-n.r,dc=to.c-n.c,d=Math.hypot(dr,dc),step=Math.min(d,1.8/4.1*.05);
   const r=n.r+dr/Math.max(d,.0000001)*step,c=n.c+dc/Math.max(d,.0000001)*step;
   if(!b._npcPathPassable(n.r,n.c,r,c,b.npcPassable)){blocked++;b._clearNpcRoute(n);n.idleUntil=f.now+900;}
   else {n.r=r;n.c=c;distance+=step*4.1;if(step>0)movingSamples++;
    if(d-step<.000001){n._routeIndex=(n._routeIndex||0)+1;if(n._routeIndex>=n._route.length){arrivals++;b._clearNpcRoute(n);n.idleUntil=0;}}
   }
   motionCpu+=performance.now()-t;
  }
  plannerCpu+=frameRouteCpu;costs.push(frameRouteCpu);
 }
 return{issues,arrivals,blocked,distanceM:distance,movingShare:movingSamples/(1200*288),pendingShare:pendingSamples/(1200*288),plannerCpuMs:plannerCpu,plannerMsPerIssue:plannerCpu/issues,motionCpuMs:motionCpu,routeCpuP95:percentile(costs,.95),latencyMs:{p50:percentile(latency,.5),p95:percentile(latency,.95)}};
}
const baseline=moving(before),after=moving(pick);
const report={scenario:'288 actual city NPC origins, 60 simulated seconds at 20Hz, speed 1.8m/s, exact intermediate waypoint following and actual body/sweep collision at every movement; repeat wander immediately after arrival. Both have same source FIFO and 4ms budget.',baseline,after,limits:f.limits+' Purpose/commerce/social/combat and GPU are outside this planner comparison.'};
fs.writeFileSync('outputs/npc_wander_point_dedup_moving18.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
assert.equal(after.blocked,0);assert(after.issues>=baseline.issues,'sustained outing throughput does not fall');assert(after.movingShare>=baseline.movingShare,'moving fraction does not fall');assert(after.plannerMsPerIssue<baseline.plannerMsPerIssue,'CPU per published outing falls');assert(after.plannerCpuMs<baseline.plannerCpuMs,'total sustained route CPU falls');
