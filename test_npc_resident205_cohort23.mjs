import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {gunzipSync} from 'node:zlib';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';

const snapshot=JSON.parse(gunzipSync(fs.readFileSync('assets/maps/city_rebuild_v1/test_fixtures/native_static_collision19.json.gz')));
const captured=JSON.parse(fs.readFileSync('assets/maps/city_rebuild_v1/test_fixtures/resident_walk_requests23.json'));
const rows=captured.rows;
assert(rows.some(n=>n.id==='resident_205'));
const refill='  if(!_npcRouteWorkBatch.size)_npcRouteWorkBatchCount=0; // Reopen a drained cohort in this frame.';
const percentile=(xs,p)=>[...xs].sort((a,b)=>a-b)[Math.min(xs.length-1,Math.floor(xs.length*p))]||0;
async function run(fixed,{drainedOnly=false}={}){
 const f=await createCivilianNativeFixture({snapshot}),b=f.box;
 let reserve=sourceFunction(f.source,'_npcReserveRouteWork');
 reserve=reserve.replace(refill,'');
 if(fixed)reserve=reserve.replace('  let head=_npcRouteWorkQueue.keys().next().value;',refill+'\n  let head=_npcRouteWorkQueue.keys().next().value;');
 vm.runInContext(reserve+'\n'+sourceFunction(f.source,'pickNpcWaypoint'),b);
 // Isolate the captured walking request, not later shop/bench/drive offers.
 // Search frontiers are intentionally rebuilt: the UI export has scalar counts only.
 b._npcAgendaPick=()=> 'walk';
 if(drainedOnly){
  const row=rows.find(n=>n.id==='resident_205'),n={id:row.id,r:row.r,c:row.c,hp:60,_routeStartR:row.startR,_routeStartC:row.startC,_civilianPlan:{phase:row.phase}};
  b.NPCS.push(n);f.nextFrame(1/7);
  // Valid post-drain scheduler state from the deterministic regression:
  // seven previous members ran last frame; the eighth used .25 ms this frame.
  vm.runInContext('_npcRouteWorkFrame=prevT;_npcRouteWorkEpoch=1;_npcRouteWorkBatchCount=8;_npcRouteWorkCount=1;_npcRouteWorkUsedMs=.25;',b);
  const ready=b.pickNpcWaypoint(n);
  const result={fixed,ready,expanded:n._npcWanderSearch?.qi||0,grants:vm.runInContext('_npcRouteWorkCount',b)};
  if(fixed){assert(result.grants===2);assert(ready||result.expanded>0,'actual resident search resumes in the same frame');}
  else{assert.equal(result.grants,1);assert.equal(result.expanded,0);assert.equal(ready,false);}
  return result;
 }
 let seed=77;const math=Object.create(Math);math.random=()=>((seed=Math.imul(seed,1664525)+1013904223>>>0)/4294967296);b.Math=math;
 for(const row of rows)b.NPCS.push({id:row.id,r:row.r,c:row.c,tr:row.r,tc:row.c,hp:60,speed:row.speed,_routeStartR:row.startR,_routeStartC:row.startC,_allowBeach:row.allowBeach,_beach:row.beach,_civilianPlan:row.phase?{phase:row.phase}:null});
 b.ordered=rows.filter(n=>n.queuePosition>=0).sort((a,z)=>a.queuePosition-z.queuePosition).map(n=>b.NPCS.find(a=>a.id===n.id));
 vm.runInContext('for(const n of ordered)_npcRouteWorkQueue.set(n,0)',b);
 const costs=[],waits=[];let ready205=null,unsafe=0,maxGrants=0;
 for(let frame=0;frame<420;frame++){
  f.nextFrame(1/7);const started=performance.now();
  for(const n of b.NPCS){
   if(n.done)continue;
   const ready=b.pickNpcWaypoint(n);
   if(ready&&n._route?.length){
    n.done=true;waits.push(f.now);if(n.id==='resident_205')ready205={waitMs:f.now,path:n._route.map(p=>({r:p.r,c:p.c}))};
    let previous=n;
    for(const next of n._route){if(!b._npcPathPassable(previous.r,previous.c,next.r,next.c,(r,c)=>b.npcWaypointOk(n,r,c)))unsafe++;previous=next;}
   }
  }
  costs.push(performance.now()-started);maxGrants=Math.max(maxGrants,vm.runInContext('_npcRouteWorkCount',b));
  if(b.NPCS.every(n=>n.done))break;
 }
 assert(ready205,'captured resident205 obtains an actual collision-checked outing');
 assert.equal(unsafe,0,'no route traverses a blocked body segment');assert(maxGrants<=8);
 const report={fixed,actors:rows.length,completed:waits.length,resident205:ready205,waitMs:{p50:percentile(waits,.5),p95:percentile(waits,.95)},cpuMs:{p50:percentile(costs,.5),p95:percentile(costs,.95)},maxGrants,unsafe,limits:f.limits};
 return report;
}
const drained={baseline:await run(false,{drainedOnly:true}),candidate:await run(true,{drainedOnly:true})};
const baseline=await run(false),candidate=await run(true);
const report={capturedAt:captured.capturedAt,drained,baseline,candidate,limits:'Actual captured positions and available queue order; actual source planner and native static geometry. Rebuilt frontiers, later activities disabled, wall-clock CPU timing is variable. The post-drain state is a constructed valid scheduler state, not captured internal LIVE state. Not an exact LIVE replay, controlled full-world perf comparison or FPS result.'};
fs.writeFileSync('outputs/npc_resident205_cohort23.json',JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
