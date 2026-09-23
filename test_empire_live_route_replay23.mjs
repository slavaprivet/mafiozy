// Bounded CPU reproduction from the standard in-game inspection JSON export.
// Requires real pending-request fields; never substitutes guessed destinations.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {gunzipSync} from 'node:zlib';
import {registerHooks} from 'node:module';
import {sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
import {pointInPolygon} from './assets/maps/city_rebuild_v1/car_drive.mjs';
import {empireTargetFootprintCandidate23} from './npc_empire_target_footprint23_candidate.mjs';
import {refreshEmpireCachedTargets23,cachedTargetRegistration23} from './npc_cached_target23_candidate.mjs';

const input=process.argv[2];assert(input,'Pass a standard inspection JSON export path.');
const exported=JSON.parse(fs.readFileSync(input,'utf8').replace(/^\uFEFF/,''));
const useCurrentTarget=process.argv.includes('--current-target'),retargetEscorts=process.argv.includes('--retarget-escort'),ids=process.argv.slice(3).filter(x=>!x.startsWith('--'));if(!ids.length)ids.push('unique_niko','empire_crew_sofia_25');
const rows=ids.map(id=>exported.routeReplay?.actors?.find(n=>n.id===id));
for(const [i,row]of rows.entries()){
 assert(row,'Missing captured actor '+ids[i]);
 if(!row.empireRequest&&useCurrentTarget&&row.kind==='empire_action'&&Number.isFinite(row.empire?.targetR)&&Number.isFinite(row.empire?.targetC)){
  const world=fs.readFileSync('world.html','utf8');assert(world.includes("_planEmpireRouteTo(n,target.r,target.c,.8,42000,'empire_action',4000"),'verify current boss request contract');
  row.empireRequest={goalR:row.empire.targetR,goalC:row.empire.targetC,goalRadius:.8,maxVisited:42000,kind:'empire_action',generation:row.empire.generation,targetKey:row.empire.actionKey,provenance:'Captured current boss target during failure backoff; scheduling constants verified against actual boss branch. Not an active request.'};
 }
 assert(row.empireRequest&&Number.isFinite(row.empireRequest.goalR)&&Number.isFinite(row.empireRequest.goalC),'Missing real pending goal for '+ids[i]+'; reload with QA scalar additions and export again.');
}
const snapshot=JSON.parse(gunzipSync(fs.readFileSync('assets/maps/city_rebuild_v1/test_fixtures/native_static_collision19.json.gz')));
const results=[];
for(const row of rows){
 const q=row.empireRequest,n={id:row.id,r:row.r,c:row.c,hp:60,walkPhase:0},times=[],progress=[];let targetChoiceCost=null,targetMatrix=null,registration=null;
 // Replace the target's broad static box with its actual GLB entry geometry,
 // just as Walk does. Otherwise an interior/door goal falsely looks solid.
 const targetBuilding=snapshot.buildings.find(building=>building.collision?.worldBodies?.some(body=>pointInPolygon(q.goalC,q.goalR,body.polygonCR)))||snapshot.buildings.find(building=>building.assetId==='hospital');
 const url=new URL('./assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs?empire23='+encodeURIComponent(targetBuilding.id),import.meta.url);
 const hook=registerHooks({load(urlString,context,next){const result=next(urlString,context);if(urlString!==url.href)return result;const s=String(result.source),needle='buildings.find(b=>b.assetId===assetId)';assert(s.includes(needle));return {...result,source:s.replace(needle,'buildings.find(b=>b.id==='+JSON.stringify(targetBuilding.id)+')').replace('new GLTFLoader().parseAsync','new GLTFLoader().register(()=>({name:"cpu-no-textures",loadTexture:()=>Promise.resolve(null)})).parseAsync')};}});
 let createFixture;try{createFixture=(await import(url.href)).createCivilianNativeFixture;}finally{hook.deregister();}
 const f=await createFixture({snapshot}),b=f.box;
 for(const name of ['_inEmpireRecruitmentYard','_empireBossPassable','_empireBossWaypointPassable'])vm.runInContext(sourceFunction(f.source,name),b);
 if(process.argv.includes('--refresh-candidate')){
  assert(!process.argv.includes('--solid-goal-candidate')&&!process.argv.includes('--reselect-current'),'registration candidate owns target reselection');
  const requireFixed=process.argv.includes('--require-fixed');
  if(requireFixed){assert(f.source.includes('function refreshEmpireCachedTargets23()'),'production refresh installed');vm.runInContext(sourceFunction(f.source,'_empireTargetFootprintPassable23')+'\n'+sourceFunction(f.source,'_nearestEmpireWalkPoint'),b);}
  else vm.runInContext(empireTargetFootprintCandidate23(sourceFunction(f.source,'_nearestEmpireWalkPoint')),b);
  vm.runInContext(sourceFunction(f.source,'_pauseEmpireMovementWatch'),b);
  const target={r:q.goalR,c:q.goalC};
  Object.assign(n,{_specialistId:row.empire.leaderId,_empireBoss:true,_empireAction:{kind:'patrol',target_id:'offline:'+row.empire.leaderId,target_r:target.r,target_c:target.c},_empireActionKey:row.empire.actionKey,_empireRouteGeneration:row.empire.generation,_empireTarget:target,_empireActivityBaseTarget:target,_routeKind:'empire_action',_empirePendingRoute:q.queued?{...q}:null,_empireRouteQueued:!!q.queued,walking:row.walking});
  // Capture lacks the original activity/base point. Using the cached target for
  // those two setup fields is explicit; assertions still preserve action identity.
  b.SPECIALIST_NPCS=[n];b._npcInitialSafePlacement=()=>{};
  const actualRegistration=f.source.split('\n').find(line=>line.trimStart().startsWith('registerWalkNpcNavigationResolver(resolver){')).trim().replace(/,$/,'');
  if(requireFixed)assert(actualRegistration.includes('if(changed)refreshEmpireCachedTargets23();'),'production hook installed');
  vm.runInContext((requireFixed?sourceFunction(f.source,'refreshEmpireCachedTargets23'):refreshEmpireCachedTargets23.toString())+'\nglobalThis.registration23={'+(requireFixed?actualRegistration:cachedTargetRegistration23(f.source))+'};',b);
  const originalQuery=b.nativePedestrianQuery;let queries=0;
  const counted=query=>{queries++;return originalQuery(query);};
  const invalid=!b._empireTargetFootprintPassable23(target.r,target.c),before=JSON.stringify(n),action=n._empireAction;
  const originalRegistration=actualRegistration.replace('const changed=resolver!==_walkNpcNavigationResolver;_walkNpcNavigationResolver=resolver;if(resolver){_npcInitialSafePlacement();if(changed)refreshEmpireCachedTargets23();}','_walkNpcNavigationResolver=resolver;if(resolver)_npcInitialSafePlacement();');
  vm.runInContext('globalThis.baselineRegistration23={'+originalRegistration+'};_walkNpcNavigationResolver=null;',b);
  assert.equal(b.baselineRegistration23.registerWalkNpcNavigationResolver(counted),true);
  assert.equal(JSON.stringify(n),before,'RED: current registration leaves even invalid cached targets untouched');
  assert.equal(!b._empireTargetFootprintPassable23(n._empireTarget.r,n._empireTarget.c),invalid,'baseline retains the invalid target');
  queries=0;
  vm.runInContext('_walkNpcNavigationResolver=null;',b);f.nextFrame(1/7);
  const at=performance.now();assert.equal(b.registration23.registerWalkNpcNavigationResolver(counted),true);const cpuMs=performance.now()-at;
  const after=JSON.stringify(n),beforeRepeat=queries;
  assert.equal(b.registration23.registerWalkNpcNavigationResolver(counted),true);
  assert.equal(queries,beforeRepeat,'same resolver performs no second target scan');
  assert.equal(JSON.stringify(n),after,'same resolver leaves actor unchanged');
  assert.equal(n._empireAction,action);assert.equal(n._empireActionKey,row.empire.actionKey);assert.equal(n._empireRouteGeneration,row.empire.generation);
  assert.equal(n.r,row.r);assert.equal(n.c,row.c);
  if(!invalid)assert.equal(after,before,'valid actor is completely unchanged');
  else {assert.notDeepEqual(n._empireTarget,target);assert(b._empireTargetFootprintPassable23(n._empireTarget.r,n._empireTarget.c));}
  registration={actualDeployedSource:requireFixed,waterAdapterAbsent:vm.runInContext('_walkNpcWaterResolver===null',b),baselineInvalid:invalid,baselineUnchanged:true,changed:invalid,validUnchanged:!invalid,cpuMs,queries:beforeRepeat,actionOwnershipPreserved:true,repeatNoQueries:true,baseFixture:'Original base/activity coordinates absent; initialized to captured current target.'};
  assert(registration.waterAdapterAbsent,'native query rejects water without a secondary water adapter');
  if(process.argv.includes('--registration-cost')){
   const originalLine=originalRegistration;
   vm.runInContext('globalThis.baselineRegistration23={'+originalLine+'};',b);
   const samples={before:[],after:[]};
   for(let trial=0;trial<120;trial++)for(const label of trial%2?['after','before']:['before','after']){
    b.SPECIALIST_NPCS=[JSON.parse(before)];vm.runInContext('_walkNpcNavigationResolver=null;',b);f.nextFrame(1/7);
    const at=performance.now();(label==='before'?b.baselineRegistration23:b.registration23).registerWalkNpcNavigationResolver(counted);const elapsed=performance.now()-at;
    if(trial>=20)samples[label].push(elapsed);
   }
   b.SPECIALIST_NPCS=[n];registration.costSamples=samples;
   registration.costMs=Object.fromEntries(Object.entries(samples).map(([key,values])=>{const sorted=values.slice().sort((a,z)=>a-z);return[key,{p50:sorted[50],p95:sorted[95]}]}));
  }
  q.previousGoal={r:q.goalR,c:q.goalC};q.goalR=n._empireTarget.r;q.goalC=n._empireTarget.c;
  q.provenance=requireFixed?'Actual deployed registration, cached-target repair and full-footprint nearest, read verbatim from world. CPU replay, not LIVE.':'Isolated actual registration hook plus cached-target repair and full-footprint nearest candidate. No production edit.';
 }
 if(process.argv.includes('--solid-goal-candidate')||process.argv.includes('--reselect-current')){
  const originalNearest=sourceFunction(f.source,'_nearestEmpireWalkPoint'),nearest=process.argv.includes('--solid-goal-candidate')?empireTargetFootprintCandidate23(originalNearest):originalNearest;
  vm.runInContext(originalNearest,b);const beforeNearest=b._nearestEmpireWalkPoint;vm.runInContext(nearest,b);const afterNearest=b._nearestEmpireWalkPoint;
  if(process.argv.includes('--target-matrix')){
   vm.runInContext(empireTargetFootprintCandidate23(originalNearest,{ordered:false}),b);const bruteNearest=b._nearestEmpireWalkPoint;let count=0,rejectedBefore=0,changed=0,missing=0;const costs=[];
   for(let dr=-6;dr<=6;dr++)for(let dc=-6;dc<=6;dc++){
    const r=q.goalR+dr*.25,c=q.goalC+dc*.25;f.nextFrame(1/7);const old=beforeNearest(r,c);f.nextFrame(1/7);const at=performance.now(),fixed=afterNearest(r,c);costs.push(performance.now()-at);f.nextFrame(1/7);const brute=bruteNearest(r,c);
    assert.equal(JSON.stringify(fixed),JSON.stringify(brute),'actual geometry nearest parity');count++;
    if(old&&f.pedestrian.query({mode:'sweep',from:old,to:old,radius:.18}).blocked)rejectedBefore++;
    if(JSON.stringify(old)!==JSON.stringify(fixed))changed++;
    if(fixed)assert.equal(f.pedestrian.query({mode:'sweep',from:fixed,to:fixed,radius:.18}).blocked,false,'every candidate target has a clear full footprint');else missing++;
   }
   costs.sort((a,z)=>a-z);targetMatrix={count,rejectedBefore,changed,missing,orderedBruteParity:true,candidateMs:{p50:costs[Math.floor(costs.length*.5)],p95:costs[Math.floor(costs.length*.95)]}};
   b._nearestEmpireWalkPoint=afterNearest;
  }
  if(process.argv.includes('--target-cost')){
   const samples={before:[],after:[]};
   for(let trial=0;trial<120;trial++)for(const label of trial%2?['after','before']:['before','after']){
    f.nextFrame(1/7);const at=performance.now();(label==='before'?beforeNearest:afterNearest)(q.goalR,q.goalC);const cost=performance.now()-at;if(trial>=20)samples[label].push(cost);
   }
   targetChoiceCost=Object.fromEntries(Object.entries(samples).map(([label,values])=>{values.sort((a,z)=>a-z);return[label,{p50:values[50],p95:values[95]}]}));
  }
  const fixed=afterNearest(q.goalR,q.goalC);assert(fixed,'a nearby reselected target exists');q.previousGoal={r:q.goalR,c:q.goalC};q.goalR=fixed.r;q.goalC=fixed.c;q.provenance=process.argv.includes('--solid-goal-candidate')?'Isolated candidate: source nearest target with full static footprint check; no production edit.':'Isolated current source nearest-target reselection after geometry is ready. No new target-footprint filter; no production invalidation hook.';
 }
 if(retargetEscorts&&q.kind==='empire_escort'&&Number.isFinite(row.empire?.targetR)&&Number.isFinite(row.empire?.targetC)&&Math.hypot(q.goalR-row.empire.targetR,q.goalC-row.empire.targetC)>5.2){q.previousGoal={r:q.goalR,c:q.goalC};q.goalR=row.empire.targetR;q.goalC=row.empire.targetC;q.provenance='Candidate: replace stale pending escort goal with captured current formation target after >5.2-cell drift. Same actual building geometry as baseline.';}
 vm.runInContext('_npcRouteWorkFrame=null;_npcRouteWorkQueue.clear();_npcRouteWorkBatch.clear();_npcRouteWorkBatchCount=0;',b);
 let ready=false,slices=0;
 if(!process.argv.includes('--inspect-target'))do{
  f.nextFrame(1/7);const at=performance.now();ready=b._planNpcRouteTo(n,q.goalR,q.goalC,b._empireBossWaypointPassable,q.goalRadius,q.maxVisited,q.kind);times.push(performance.now()-at);slices++;
  if(slices%25===0||!n._routeSearchPending)progress.push({slices,expanded:n._npcDirectedSearch?.qi??n._routeSearchExpanded,visited:n._npcDirectedSearch?.nodes.size??n._routeSearchVisited,fine:!!n._npcDirectedSearch?.fine,anchors:n._npcDirectedSearch?.goalAnchors?.size??null,bestDistance:n._npcDirectedSearch?.bestD??null});
 }while(n._routeSearchPending&&slices<900);
 let from=n,pathM=0,blockedSegments=0;
 for(const to of n._route||[]){if(!b._npcPathPassable(from.r,from.c,to.r,to.c,b._empireBossPassable))blockedSegments++;pathM+=Math.hypot(to.r-from.r,to.c-from.c)*4.1;from=to;}
 times.sort((a,z)=>a-z);
 const geometry={startPoint:b._empireBossPassable(row.r,row.c),startBody:b._empireBossWaypointPassable(row.r,row.c),goalPoint:b._empireBossPassable(q.goalR,q.goalC),goalBody:b._empireBossWaypointPassable(q.goalR,q.goalC),startSample:f.pedestrian.query({r:row.r,c:row.c}),goalSample:f.pedestrian.query({r:q.goalR,c:q.goalC})};
 geometry.goalFloor=f.floor(q.goalC*4.1,q.goalR*4.1);geometry.goalBodies=f.bodies.filter(body=>pointInPolygon(q.goalC,q.goalR,body.polygonCR)).map(({id,kind,minYM,maxYM,instanceId,source,name})=>({id,kind,minYM,maxYM,instanceId,source,name}));
 geometry.goalFootprint=f.pedestrian.query({mode:'sweep',from:{r:q.goalR,c:q.goalC},to:{r:q.goalR,c:q.goalC},radius:.18});
 if(process.argv.includes('--probe-nearby')){
  geometry.nearby=[];
  for(let dr=-4;dr<=4;dr++)for(let dc=-4;dc<=4;dc++){
   const r=q.goalR+dr*.25,c=q.goalC+dc*.25,distance=Math.hypot(r-q.goalR,c-q.goalC);if(distance>1.05||!b._empireBossWaypointPassable(r,c))continue;
   const direct=b._npcPathPassable(row.r,row.c,r,c,b._empireBossPassable)&&!f.pedestrian.query({mode:'sweep',from:{r:row.r,c:row.c},to:{r,c},radius:.18}).blocked;
   geometry.nearby.push({r,c,distance,direct});
  }
 }
 if(!ready&&process.argv.includes('--reverse-goal-probe')){
  const endpoint={id:row.id+':goal-probe',r:q.goalR,c:q.goalC},scratch={},occupiedGoals=new Set();let exit,slices=0;
  const edgeClear=(from,to)=>b._npcPathPassable(from.r,from.c,to.r,to.c,b._empireBossPassable)&&!f.pedestrian.query({mode:'sweep',from,to,radius:.18}).blocked;
  do{
   f.nextFrame(1/7);b._npcReserveRouteWork(f.now,endpoint);
   try{exit=b._npcFindWanderGridExit(endpoint,scratch,{pointClear:b._empireBossWaypointPassable,edgeClear,expired:b._npcRouteWorkExpired,occupiedGoals});}finally{b._npcFinishRouteWork();}
   slices++;
  }while(exit.status==='pending'&&slices<100);
  geometry.reverseGoal={status:exit.status,slices,expanded:exit.expanded,visited:exit.nodes};
  if(exit.status==='ready'){
   const connection=exit.path.at(-1),proxy={id:row.id+':connection',r:row.r,c:row.c,walkPhase:0};let connected=false,connectionSlices=0;
   do{f.nextFrame(1/7);connected=b._planNpcRouteTo(proxy,connection.r,connection.c,b._empireBossWaypointPassable,.1,Math.max(2,q.maxVisited-(exit.nodes||0)),q.kind);connectionSlices++;}while(proxy._routeSearchPending&&connectionSlices<900);
   Object.assign(geometry.reverseGoal,{connection,connected,connectionSlices});
   if(connected){
    const joined=[...proxy._route,...exit.path.slice(0,-1).reverse(),{r:q.goalR,c:q.goalC}];let previous={r:row.r,c:row.c},lengthM=0;
    for(const next of joined){assert(edgeClear(previous,next),'reverse connector and full forward route remain physically clear');lengthM+=Math.hypot(next.r-previous.r,next.c-previous.c)*4.1;previous=next;}
    Object.assign(geometry.reverseGoal,{path:joined,pathM:lengthM});
   }
  }
 }
 results.push({id:row.id,planningSkipped:process.argv.includes('--inspect-target'),actualBuilding:targetBuilding.id,start:{r:row.r,c:row.c},request:q,geometry,targetChoiceCost,targetMatrix,registration,capturedPendingMs:row.ageMs,ready,pending:!!n._routeSearchPending,slices,noCompetitionSeconds:slices/7,cpuTotalMs:times.reduce((a,z)=>a+z,0),sliceMs:{p50:times[Math.floor(times.length*.5)],p95:times[Math.floor(times.length*.95)]},progress,pathM,blockedSegments,path:n._route||[]});
 assert.equal(blockedSegments,0,'all returned route segments remain physically passable');
 assert.equal(n.r,row.r);assert.equal(n.c,row.c,'planner never teleports actor');
 if(ready&&process.argv.includes('--walk-result')){
  let state=false,frames=0,maxStep=0,blockedMovementSweeps=0;
  for(;frames<4000&&state!=='arrived';frames++){
   f.nextFrame(1/7);const previous={r:n.r,c:n.c};state=b._npcAdvanceRoute(n,1/7,1.18,b._empireBossPassable);
   maxStep=Math.max(maxStep,Math.hypot(n.r-previous.r,n.c-previous.c));assert.notEqual(state,'blocked','actual movement follows every returned corner');
   if(Math.hypot(n.r-previous.r,n.c-previous.c)>0&&f.pedestrian.query({mode:'sweep',from:previous,to:n,radius:.18}).blocked)blockedMovementSweeps++;
   assert(maxStep<=1.18/7+1e-8,'movement has no teleport');
  }
  assert.equal(state,'arrived');assert(Math.hypot(n.r-q.goalR,n.c-q.goalC)<.8);assert.equal(blockedMovementSweeps,0,'full body movement sweeps remain clear');
  results.at(-1).movement={state,seconds:frames/7,maxStepCells:maxStep,blockedMovementSweeps,final:{r:n.r,c:n.c},distanceToGoal:Math.hypot(n.r-q.goalR,n.c-q.goalC)};
 }
}
const report={capturedAt:exported.capturedAt,results,limits:'Actual target building GLB/entry geometry and source native planner; other buildings remain static snapshot boxes. Rebuilds searches from real start and goal, without original frontier, queue competitors, moving targets, other runtime vehicles/railway or GPU. Simulated wait is a no-competition reference, not actual LIVE wait or FPS.'};
const reportTag=process.argv.find(arg=>arg.startsWith('--report='))?.slice('--report='.length);if(reportTag)assert(/^[a-z0-9_]{1,48}$/.test(reportTag),'safe bounded report tag');
fs.writeFileSync('outputs/empire_live_route_replay23'+(reportTag?'_'+reportTag:retargetEscorts?'_retarget_candidate':process.argv.includes('--solid-goal-candidate')?'_solid_goal_candidate':process.argv.includes('--reverse-goal-probe')?'_goal_probe':'')+'.json',JSON.stringify(report,null,2));console.log(JSON.stringify(process.argv.includes('--summary')?{capturedAt:report.capturedAt,results:results.map(({id,planningSkipped,ready,slices,pathM,movement,registration})=>({id,planningSkipped,ready,slices,pathM,movement,registration:registration?{...registration,costSamples:undefined}:null})),limits:report.limits}:report,null,2));
