// Isolated AB: no world mutation, no authenticated gameplay claim.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {gunzipSync} from 'node:zlib';
import {registerHooks} from 'node:module';
const fixtureUrl = new URL('./assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs', import.meta.url);
const hook = registerHooks({load(url, context, next) {
  const result = next(url, context);
  return url === fixtureUrl.href ? {...result, source: String(result.source).replace('new GLTFLoader().parseAsync', 'new GLTFLoader().register(()=>({name:"cpu-no-textures",loadTexture:()=>Promise.resolve(null)})).parseAsync')} : result;
}});
const {createCivilianNativeFixture, sourceFunction} = await import(fixtureUrl.href);
hook.deregister();
const snapshot = JSON.parse(gunzipSync(fs.readFileSync('assets/maps/city_rebuild_v1/test_fixtures/native_static_collision19.json.gz')));
const f = await createCivilianNativeFixture({snapshot}), b = f.box;
for (const name of ['_inEmpireRecruitmentYard', '_empireBossPassable', '_empireBossWaypointPassable']) vm.runInContext(sourceFunction(f.source,name), b);
// Deliberately include four previously problematic paths and two controls.
let pairs = JSON.parse(fs.readFileSync('assets/maps/city_rebuild_v1/test_fixtures/empire_other_kinds23.json','utf8')).pairs;
assert.equal(pairs.length,6, 'six recorded geometry inputs');
const guardPosts=process.argv.includes('--guard-posts');
if(guardPosts){
  for(const name of ['_empireTargetFootprintPassable23','_nearestEmpireWalkPoint','_empireHoldingGuardPost'])vm.runInContext(sourceFunction(f.source,name),b);
  const anchor={r:f.item.transform.positionM[2]/4.1,c:f.item.transform.positionM[0]/4.1};
  pairs=[];
  for(let slot=0;slot<3;slot++)for(let step=0;step<4;step++){
    f.nextFrame();const start=b._empireHoldingGuardPost(anchor,slot,step),goal=b._empireHoldingGuardPost(anchor,slot,step+1);
    if(Math.hypot(start.r-goal.r,start.c-goal.c)>.8)pairs.push({index:slot*4+step,start,goal,anchor,slot,step});
  }
  assert(pairs.length>0,'actual guard posts around existing hospital produce routes');
}
const planner = sourceFunction(f.source,'_planNpcRouteTo'), advance = sourceFunction(f.source,'_npcAdvanceRoute');
const suffix = guardPosts?"||kind==='empire_holding_guard'":"||kind==='empire_holding_guard'||kind==='empire_recruit'||kind==='empire_street_recruit'||kind==='empire_retreat'";
const candidatePlanner = planner.replace("||kind==='empire_escort'", "||kind==='empire_escort'"+suffix);
const candidateAdvance = advance.replace("||npc._routeKind==='empire_escort'", "||npc._routeKind==='empire_escort'"+suffix.replaceAll('kind===','npc._routeKind==='));
assert.notEqual(planner,candidatePlanner); assert.notEqual(advance,candidateAdvance);
const kinds = guardPosts?[['empire_holding_guard',.7,9000]]:[['empire_holding_guard',.7,9000], ['empire_recruit',.45,12000], ['empire_street_recruit',1.05,9000], ['empire_retreat',.8,42000]];
const rows=[];
const originalPass=b._empireBossWaypointPassable;
let passCalls=0;b._empireBossWaypointPassable=(r,c)=>{passCalls++;return originalPass(r,c);};
for (const [pairIndex,pair] of pairs.entries()) for (const [kind,radius,limit] of kinds) {
  for (const variant of pairIndex%2 ? ['both','planner-only','production'] : ['production','planner-only','both']) {
    vm.runInContext((variant==='production'?planner:candidatePlanner)+'\n'+(variant==='both'?candidateAdvance:advance),b);
    vm.runInContext('_npcRouteWorkQueue.clear();_npcRouteWorkBatch.clear();_npcRouteWorkBatchCount=0;',b);
    const n={id:`${variant}:${kind}:${pairIndex}`,...pair.start,walkPhase:0};
    let ready=false,slices=0,cpuMs=0;const callsBefore=passCalls;
    do {
      f.nextFrame(1/7); const at=performance.now();
      ready=b._planNpcRouteTo(n,pair.goal.r,pair.goal.c,b._empireBossWaypointPassable,radius,limit,kind);
      cpuMs+=performance.now()-at; slices++;
    } while(n._routeSearchPending&&slices<300);
    let from={...pair.start},unsafe=0,steps=0,blockedSteps=0,status='empty',maxStep=0;
    for (const to of n._route||[]) {
      if (!b._npcPathPassable(from.r,from.c,to.r,to.c,b._empireBossPassable)||f.pedestrian.query({mode:'sweep',from,to,radius:.18}).blocked) unsafe++;
      from=to;
    }
    if(ready) for(;steps<4000;steps++) {
      f.nextFrame(1/7); const from={r:n.r,c:n.c};
      status=b._npcAdvanceRoute(n,1/7,1.18,b._empireBossPassable);
      const distance=Math.hypot(n.r-from.r,n.c-from.c);maxStep=Math.max(maxStep,distance);
      if(distance>0&&f.pedestrian.query({mode:'sweep',from,to:n,radius:.18}).blocked)blockedSteps++;
      if(status!==true)break;
    }
    assert(maxStep<=1.18/7+1e-8,'no teleport');
    rows.push({pairIndex,sourceIndex:pair.index,kind,variant,start:pair.start,goal:pair.goal,radius,limit,ready,pending:!!n._routeSearchPending,slices,cpuMs,passCalls:passCalls-callsBefore,unsafe,blockedSteps,status,remaining:Math.hypot(n.r-pair.goal.r,n.c-pair.goal.c),steps});
  }
}
const stats={};
for(const variant of ['production','planner-only','both']) {
  const items=rows.filter(r=>r.variant===variant),cost=items.map(r=>r.cpuMs).sort((a,b)=>a-b);
  stats[variant]={count:items.length,arrived:items.filter(r=>r.status==='arrived').length,reachedGoal:items.filter(r=>r.status==='arrived'&&r.remaining<(guardPosts?.75:r.radius+.01)).length,blocked:items.filter(r=>r.status==='blocked').length,unsafePaths:items.filter(r=>r.unsafe).length,blockedMovement:items.filter(r=>r.blockedSteps).length,pending:items.filter(r=>r.pending).length,passCalls:items.reduce((s,r)=>s+r.passCalls,0),cpuTotalMs:items.reduce((s,r)=>s+r.cpuMs,0),cpuRouteMs:{p50:cost[Math.floor(cost.length*.5)],p95:cost[Math.floor(cost.length*.95)]}};
}
assert.equal(stats.both.unsafePaths,0);assert.equal(stats.both.blockedMovement,0);
const allCandidateRoutesArrived=stats.both.reachedGoal===pairs.length*kinds.length;
assert.equal(stats.both.pending,0);
if(!guardPosts)assert(stats.production.unsafePaths>0,'reproduces coarse path failure');
// Actual queue/pump on the candidate planner: suspend, deny a second same-frame
// slice, then cancel without more collision queries. Accounting cost is separate
// from all real CPU measurements above.
vm.runInContext(candidatePlanner+'\n'+candidateAdvance,b);
const declarations=f.source.slice(f.source.indexOf('const _empireRoutePlanQueue=[];'),f.source.indexOf('function _empireCrewOrigin('));
vm.runInContext(declarations+sourceFunction(f.source,'_planEmpireRouteTo')+sourceFunction(f.source,'_processEmpireRoutePlanQueue'),b);
const savedClock=b.performance.now;let accounted=0;
b.performance.now=()=>f.now+accounted;
b._empireBossWaypointPassable=(r,c)=>{passCalls++;accounted+=.25;return originalPass(r,c);};
let cancellationCases=0;
for(const [kind,radius,limit] of kinds) for(const mode of ['generation','cancel','dead','hidden','hp0']) {
  vm.runInContext('_empireRoutePlanQueue.length=0;_npcRouteWorkQueue.clear();_npcRouteWorkBatch.clear();_npcRouteWorkBatchCount=0;',b);
  const n={id:kind+mode,...pairs[2].start,hp:100,_empireRouteGeneration:1,_empireActionKey:'fixture'};
  b._planEmpireRouteTo(n,pairs[2].goal.r,pairs[2].goal.c,radius,limit,kind,1000,2,'fixture');
  f.nextFrame();b._processEmpireRoutePlanQueue(b.performance.now());
  assert(n._routeSearchPending&&n._npcDirectedSearch?.algorithm==='astar-visit',kind+' pending native frontier');
  const before=passCalls;b._processEmpireRoutePlanQueue(b.performance.now());
  assert.equal(passCalls,before,'one expensive slice per actor/frame');
  if(mode==='generation')n._empireRouteGeneration++;
  if(mode==='cancel')n._empirePendingRoute=null;
  if(mode==='dead')n.dead=true;
  if(mode==='hidden')n._hiddenByEmpire=true;
  if(mode==='hp0')n.hp=0;
  f.nextFrame();b._processEmpireRoutePlanQueue(b.performance.now());
  assert.equal(passCalls,before,'cancelled native search does not resume');
  assert(!n._route?.length,'no stale route publication');cancellationCases++;
}
b.performance.now=savedClock;b._empireBossWaypointPassable=originalPass;
const report={candidateOnly:true,allCandidateRoutesArrived,selection:guardPosts?'Actual source holding-guard posts at existing hospital transform anchor, three slots and four quarter-turns. Synthetic ownership/anchor, not LIVE guard jobs.':'Four historically unsafe routes plus two controls, synthetic guard/recruit/retreat kinds. Not a representative city/FPS sample or captured live jobs.',stats,cancellationCases,rows,limits:f.limits};
fs.writeFileSync(guardPosts?'outputs/empire_guard_posts23_candidate.json':'outputs/empire_other_kinds23_candidate.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({stats,cancellationCases,limits:report.selection},null,2));
assert(allCandidateRoutesArrived,'candidate must physically arrive at every generated guard post before readiness');
