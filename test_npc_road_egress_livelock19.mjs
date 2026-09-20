import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';

const f=await createCivilianNativeFixture(),b=f.box;
const code=fs.readFileSync('assets/maps/city_rebuild_v1/npc_road_egress_source.js','utf8');
const current=code.slice(code.indexOf('function _npcPlanRoadExit('));
const before=current.replace('if(state.index>=_npcRoadExitOffsets.length)state.index=0;','state.index=0;');
assert.notEqual(before,current,'comparison reconstructs only the previous retry behavior');
const positions=[{r:5.5,c:110.5},{r:15.5,c:55.5},{r:50.5,c:115.5},{r:60.5,c:20.5}];
const quantile=(values,q)=>[...values].sort((a,b)=>a-b)[Math.min(values.length-1,Math.floor(values.length*q))]||0;
function reset(source){
 vm.runInContext(source,b);
 vm.runInContext('_npcRouteWorkQueue.clear();_npcRouteWorkBatch.clear();_npcRouteWorkBatchCount=0;',b);
}
function resident(p){return{id:'resident_egress19',...p,tr:p.r,tc:p.c,hp:100,_civilianPlan:{phase:'seek_shop',cycle:3}};}
function run(p,source){
 reset(source);const n=resident(p),intent=n._civilianPlan,started=f.now,costs=[],retryIndexes=[];
 let ready=false,lastRetry=0;
 for(let frame=0;frame<500;frame++){
  f.nextFrame(.05);const start=performance.now();ready=b._npcPlanRoadExit(n,f.now);costs.push(performance.now()-start);
  assert.equal(n.r,p.r,'planning never moves the resident');assert.equal(n.c,p.c);assert.equal(n._civilianPlan,intent);
  if(n._npcRoadExit?.retryAt&&n._npcRoadExit.retryAt!==lastRetry){lastRetry=n._npcRoadExit.retryAt;retryIndexes.push(n._npcRoadExit.index);}
  if(ready)break;
 }
 if(ready){
  let from={...p};for(const to of n._route){assert(b._npcPathPassable(from.r,from.c,to.r,to.c,b.npcPassableForSnitch),'every published segment has a real swept body clearance');from=to;}
  const goal=n._route.at(-1);assert(b._npcBodyPassable(goal.r,goal.c,(r,c)=>f.pedestrian.query({r,c}).surface==='land'&&b.npcWaypointOk(n,r,c)),'destination footprint is wholly safe land');
 }
 return{ready,elapsedMs:f.now-started,retryIndexes,route:n._route,planningCallCpuMs:{p50:quantile(costs,.5),p95:quantile(costs,.95)}};
}
const rows=[];
for(const position of positions){
 const old=run(position,before),after=run(position,current);
 assert(!old.ready,'original repeats inaccessible nearby landings');assert(old.retryIndexes.length>=3);assert.equal(new Set(old.retryIndexes).size,1,'same exhausted batch is retried');
 assert(after.ready,'later reachable landing is eventually considered');assert(after.elapsedMs<5000);assert(after.retryIndexes.length>=1,'same bounded four-attempt backoff remains');
 rows.push({position,before:old,after});
}

// An interrupted batch never takes over combat or a new building journey.
reset(current);const interrupted=resident(positions[0]);f.nextFrame();b._npcPlanRoadExit(interrupted,f.now);const state=interrupted._npcRoadExit,index=state.index;
for(const field of ['dead','_fighting','_civilianTrip','_residentNativeVisit','_civilianActivity','_civilianSeat']){
 interrupted[field]=true;f.nextFrame();assert.equal(b._npcPlanRoadExit(interrupted,f.now),null,field+' retains authority');assert.equal(state.index,index);interrupted[field]=false;
}
interrupted._civilianPlan.doorId='real-shop';interrupted._routeSearchPending=true;interrupted._routeSearchKind='building_entry';
f.nextFrame();assert.equal(b._npcPlanRoadExit(interrupted,f.now),null,'a retained physical shop journey wins');assert.equal(state.index,index);

// Complete exhaustion may restart after the same one-second backoff. Use the
// actual geometry with a temporary closed-land policy, keeping resolver identity.
reset(current);let closeLand=true;b.egressLandPolicy=q=>{const hit=f.pedestrian.query(q);return closeLand&&q.mode!=='sweep'&&hit?.surface==='land'?{...hit,blocked:true}:hit;};
vm.runInContext('_walkNpcNavigationResolver=egressLandPolicy;',b);
const retry=resident(positions[0]);let exhausted=false;
for(let frame=0;frame<300;frame++){f.nextFrame(.05);b._npcPlanRoadExit(retry,f.now);if(retry._roadExitStatus==='no-clear-land'){exhausted=true;break;}}
assert(exhausted);const endIndex=retry._npcRoadExit.index;assert.equal(endIndex,vm.runInContext('_npcRoadExitOffsets.length',b));
const backoff=retry._npcRoadExit.retryAt;closeLand=false;f.nextFrame(.1);assert(f.now<backoff);assert.equal(b._npcPlanRoadExit(retry,f.now),false);assert.equal(retry._npcRoadExit.index,endIndex);
let recovered=false;for(let frame=0;frame<100;frame++){f.nextFrame(.05);if(b._npcPlanRoadExit(retry,f.now)){recovered=true;break;}}
assert(recovered,'changed land becomes reachable after full-list reset');
console.log(JSON.stringify({pass:true,rows,checks:'four actual geometry livelocks, swept paths, preserved position/intent, interruption priority, full-list retry and backoff',limits:f.limits+' Isolated planning timings only; no relation to resident12 inferred without its live coordinates.'},null,2));
