import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {gunzipSync} from 'node:zlib';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture,sourceFunction} from './test_civilian_native_fixture.mjs';

// A checked-in physical snapshot: no unpublished outputs/ report dependency.
const snapshot=JSON.parse(gunzipSync(fs.readFileSync(new URL('test_fixtures/native_static_collision19.json.gz',import.meta.url))));
const f=await createCivilianNativeFixture({snapshot}),b=f.box;
for(const name of ['_inEmpireRecruitmentYard','_empireBossPassable','_empireBossWaypointPassable','_nearestEmpireWalkPoint'])vm.runInContext(sourceFunction(f.source,name),b);
const planner=sourceFunction(f.source,'_planNpcRouteTo'),advance=sourceFunction(f.source,'_npcAdvanceRoute');
const oldPlanner=planner.replace("||kind==='empire_action'||kind==='empire_escort'",'').replace('npc._npcDirectedSearch=null;goal=goal||search.best;','npc._compareExpanded=search.qi;npc._npcDirectedSearch=null;goal=goal||search.best;');
const oldAdvance=advance.replace(/const nativeEmpire=[^;]+;/,'const nativeEmpire=false;');
assert.notEqual(planner,oldPlanner);assert.notEqual(advance,oldAdvance);
const pairs=[];
for(const [r,c] of [[24.5,22],[25,22.5],[75,34.54],[50.5,115.5],[15.5,55.5],[5.5,110.5],[60.5,20.5],[80.5,80.5]]){
 const start=b._nearestEmpireWalkPoint(r,c);assert(start);
 for(const distance of [4.33,24]){
  let found=0;
  for(let i=0;i<64&&found<4;i++){
   const angle=(i*17%64)*Math.PI/32,goal={r:start.r+Math.sin(angle)*distance,c:start.c+Math.cos(angle)*distance};
   if(!b._empireBossWaypointPassable(goal.r,goal.c))continue;
   pairs.push({start,goal,distance});found++;
  }
  assert.equal(found,4);
 }
}
assert.equal(pairs.length,64);
const results={};
for(const [variant,plan,move] of [['coarse',oldPlanner,oldAdvance],['native',planner,advance]]){
 vm.runInContext(plan+'\n'+move,b);
 const rows=[],sliceTimes=[];
 for(const [index,pair] of pairs.entries()){
  const n={id:variant+index,...pair.start,walkPhase:0},kind=index%2?'empire_escort':'empire_action';
  let cpuMs=0,frames=0;
  vm.runInContext('_npcRouteWorkQueue.clear();_npcRouteWorkBatch.clear();_npcRouteWorkBatchCount=0;',b);
  for(;frames<160;frames++){
   f.nextFrame();const start=performance.now();
   const ready=b._planNpcRouteTo(n,pair.goal.r,pair.goal.c,b._empireBossWaypointPassable,.8,18000,kind);
   const elapsed=performance.now()-start;cpuMs+=elapsed;sliceTimes.push(elapsed);
   if(ready||!n._routeSearchPending)break;
  }
  assert(!n._routeSearchPending,variant+' route must finish within bounded slices');
  let unsafe=0,from=pair.start;
  for(const target of n._route||[]){
   if(!b._npcPathPassable(from.r,from.c,target.r,target.c,b._empireBossPassable)||f.pedestrian.query({mode:'sweep',from,to:target,radius:.18}).blocked)unsafe++;
   from=target;
  }
  const expanded=n._compareExpanded??n._routeSearchExpanded??0;
  let status='empty',sweptSteps=0;
  for(let frame=0;n._route?.length&&frame<20000;frame++){
   f.nextFrame();const from={r:n.r,c:n.c};status=b._npcAdvanceRoute(n,.05,.6,b._empireBossPassable);
   if(status!==true)break;
   if(f.pedestrian.query({mode:'sweep',from,to:n,radius:.18}).blocked)sweptSteps++;
  }
  const remaining=Math.hypot(n.r-pair.goal.r,n.c-pair.goal.c);
  if(variant==='native'){
   assert.equal(unsafe,0,'published edge '+index);assert.equal(sweptSteps,0,'movement sweep '+index);
   assert.equal(status,'arrived','actual advance '+index);assert(remaining<=1.05,'boss final arrival '+index);
  }
  rows.push({index,distance:pair.distance,cpuMs,expanded,unsafe,status,sweptSteps,remaining});
 }
 const sorted=rows.map(r=>r.cpuMs).sort((a,b)=>a-b);sliceTimes.sort((a,b)=>a-b);
 results[variant]={count:rows.length,blocked:rows.filter(r=>r.status==='blocked').length,unsafePaths:rows.filter(r=>r.unsafe).length,arrived:rows.filter(r=>r.status==='arrived').length,cpuTotalMs:rows.reduce((s,r)=>s+r.cpuMs,0),cpuMedianMs:sorted[32],cpuP95Ms:sorted[60],sliceP95Ms:sliceTimes[Math.floor(sliceTimes.length*.95)],expanded:rows.reduce((s,r)=>s+r.expanded,0)};
}
assert(results.coarse.unsafePaths>0,'fixture reproduces old unsafe published edges');
// Run the actual empire pump with the native A* helper and real geometry.
// Account 0.12 ms per body predicate to deterministically suspend a frontier;
// measured CPU results above use the real clock, unaffected by this contract test.
const declarations=f.source.slice(f.source.indexOf('const _empireRoutePlanQueue=[];'),f.source.indexOf('function _empireCrewOrigin('));
vm.runInContext(declarations+sourceFunction(f.source,'_planEmpireRouteTo')+sourceFunction(f.source,'_processEmpireRoutePlanQueue'),b);
const realClock=b.performance.now,realPass=b._empireBossWaypointPassable;
let accounted=0,calls=0;b.performance.now=()=>f.now+accounted;
b._empireBossWaypointPassable=(r,c)=>{calls++;accounted+=.12;return realPass(r,c);};
for(const mode of ['generation','action','cancel','dead','hidden','hp0']){
 vm.runInContext('_empireRoutePlanQueue.length=0;_npcRouteWorkQueue.clear();_npcRouteWorkBatch.clear();_npcRouteWorkBatchCount=0;',b);
 const n={id:mode,r:15.5,c:55.5,hp:100,_empireRouteGeneration:1,_empireActionKey:'inspect:first'};
 b._planEmpireRouteTo(n,36.66611034436052,44.18647831617606,.8,18000,'empire_action',1200,2,n._empireActionKey);
 f.nextFrame();b._processEmpireRoutePlanQueue(b.performance.now());
 assert(n._routeSearchPending&&n._npcDirectedSearch?.algorithm==='astar-visit','native pending frontier '+mode);
 const beforeCalls=calls;
 if(mode==='generation')n._empireRouteGeneration++;
 if(mode==='action')n._empireActionKey='inspect:second';
 if(mode==='cancel')n._empirePendingRoute=null;
 if(mode==='dead')n.dead=true;
 if(mode==='hidden')n._hiddenByEmpire=true;
 if(mode==='hp0')n.hp=0;
 f.nextFrame();b._processEmpireRoutePlanQueue(b.performance.now());
 assert.equal(calls,beforeCalls,'cancelled native search never resumes: '+mode);
 assert(!n._route?.length,'no stale publication: '+mode);
}
b.performance.now=realClock;b._empireBossWaypointPassable=realPass;
const nativeHelper=b._npcPlanNativeVisitRoute;b._npcPlanNativeVisitRoute=undefined;
vm.runInContext('_npcRouteWorkQueue.clear();_npcRouteWorkBatch.clear();_npcRouteWorkBatchCount=0;',b);
f.nextFrame();const fallback={id:'helper-absent',r:10.5,c:10.5};
assert(b._planNpcRouteTo(fallback,11.5,10.5,()=>true,.8,100,'empire_action'),'optional helper absence retains coarse fallback');
b._npcPlanNativeVisitRoute=nativeHelper;
// Final arrival tolerance, legacy empire and unrelated native routes keep their
// prior semantics; only intermediate native empire waypoints require precision.
const actualPath=b._npcPathPassable;b._npcPathPassable=()=>true;
for(const [native,kind,expectedIndex] of [[true,'empire_action',0],[true,'empire_escort',0],[true,'directed',1],[false,'empire_action',1]]){
 vm.runInContext('_walkNpcNavigationResolver='+(native?'nativePedestrianQuery':'null')+';',b);
 const n={r:10,c:10.25,walkPhase:0,_routeKind:kind,_route:[{r:10,c:10.5},{r:11,c:10.5}],_routeIndex:0};
 b._npcAdvanceRoute(n,.05,.6,b._empireBossPassable);assert.equal(n._routeIndex,expectedIndex);
 n._routeIndex=1;n.r=11;n.c=10.25;assert.equal(b._npcAdvanceRoute(n,.05,.6,b._empireBossPassable),'arrived');
}
b._npcPathPassable=actualPath;
console.log(JSON.stringify({pass:true,results,limits:f.limits},null,2));
