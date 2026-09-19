import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
import {findWanderGridExit18,injectWanderGridExit18} from './npc_wander_grid_exit_candidate18.mjs';
import {depthFirstWanderCandidate18} from './npc_wander_depth_first_candidate18.mjs';
const source=fs.readFileSync('world.html','utf8'),pick=sourceFunction(source,'pickNpcWaypoint');
const applied=pick.includes('_npcFindWanderGridExit'),basePick=applied?pick:injectWanderGridExit18(pick);
const depthFirstApplied=basePick.includes('if(resolver)queue.splice(search.qi+1,0,node);else queue.push(node);');
const testedPick=process.argv.includes('--depth-first')&&!depthFirstApplied?depthFirstWanderCandidate18(basePick):basePick;
const testedHelper=applied?vm.runInNewContext('('+sourceFunction(source,'_npcFindWanderGridExit')+')'):findWanderGridExit18;
const scan=JSON.parse(fs.readFileSync('outputs/npc_grid_resolution_scan18.json','utf8'));
const results=[];
for(const row of scan.results.filter(r=>r.fine?.found)){
 const f=await createCivilianNativeFixture({assetId:row.assetId}),b=f.box;
 b._civilianPlanNext=()=>false;b._maybePlanResidentBuildingVisit=()=>false;
 let calls=0;b.findWanderGridExit18=(...args)=>{calls++;return testedHelper(...args)};b._npcFindWanderGridExit=b.findWanderGridExit18;
 vm.runInContext(testedPick,b);
 const n={id:'candidate-'+row.assetId,...row.start,hp:60};b.NPCS.push(n);let slices=0,cpu=0,peakNodes=0;
 const plan=()=>{for(let i=0;i<240;i++){f.nextFrame(.05);const t=performance.now(),ready=b.pickNpcWaypoint(n);cpu+=performance.now()-t;slices++;peakNodes=Math.max(peakNodes,n._npcWanderSearch?.gridExit?.nodes.size||0);if(ready)return true;assert(n.idleUntil===0,'reachable origin never schedules idle while connector pending');}return false;};
 assert(plan(),'actual trapped origin receives physical connector');const escapePath=n._route.map(p=>({...p}));
 let from=n;for(const to of escapePath){assert(b._npcPathPassable(from.r,from.c,to.r,to.c,b.npcPassable),'whole published connector execution footprint clear');from=to;}
 let movementFrames=0,distanceM=0;
 for(;movementFrames<1600&&n._route?.length;movementFrames++){
  f.nextFrame(.05);let to=n._route[n._routeIndex||0],dr=to.r-n.r,dc=to.c-n.c,d=Math.hypot(dr,dc);
  const radius=b._civilianArrivalRadius(n);
  if(d<radius){if((n._routeIndex||0)+1>=n._route.length){b._clearNpcRoute(n);break;}n._routeIndex=(n._routeIndex||0)+1;to=n._route[n._routeIndex];dr=to.r-n.r;dc=to.c-n.c;d=Math.hypot(dr,dc);}
  const step=Math.min(1.8/4.1*.05,d),r=n.r+dr/Math.max(.000001,d)*step,c=n.c+dc/Math.max(.000001,d)*step;
  assert(b._npcPathPassable(n.r,n.c,r,c,b.npcPassable),'actual body/sweep movement clear');distanceM+=step*4.1;n.r=r;n.c=c;
 }
 assert(!n._route?.length,'connector physically completed');const exit={r:n.r,c:n.c},escapeCalls=calls;
 assert(plan(),'normal outing is available after physical escape');assert.equal(calls,escapeCalls,'next ordinary wander uses original coarse BFS');
 assert(n._route.length>=6,'next route is a normal long outing');
 results.push({assetId:row.assetId,start:row.start,escapePath,exit,physicalDistanceM:distanceM,movementFrames,normalRoutePoints:n._route.length,plannerSlices:slices,plannerCpuMs:cpu,peakFineNodes:peakNodes});
}
// Bounded closed cage and water callbacks use the same actual production
// admission/cancellation machinery with an explicit always-blocked sweep.
for(const surface of ['land','water']){
 let clock=1000;const b={Math,Number,Map,Set,performance:{now:()=>clock},prevT:0,MAP_COLS:80,NPCS:[],_civilianPlanNext:()=>false,_maybePlanResidentBuildingVisit:()=>false};
 b._walkNpcNavigationResolver=q=>({surface,swept:q.mode==='sweep',blocked:true});b.npcWaypointOk=()=>{clock+=.2;return surface==='land'};b._npcPathPassable=()=>false;b.findWanderGridExit18=testedHelper;b._npcFindWanderGridExit=testedHelper;
 vm.createContext(b);vm.runInContext(source.slice(source.indexOf('let _npcRouteWorkFrame='),source.indexOf('function _planNpcRouteTo(')),b);for(const name of ['_clearNpcRoute','_setNpcRoute'])vm.runInContext(sourceFunction(source,name),b);vm.runInContext(testedPick,b);
 const n={id:surface,r:30.5,c:30.5,hp:60};b.NPCS.push(n);b.prevT=1;assert.equal(b.pickNpcWaypoint(n),false);assert(!n._route?.length);assert(n.idleUntil>clock,'true '+surface+' isolation keeps failure cooldown');assert.deepEqual({r:n.r,c:n.c},{r:30.5,c:30.5});
}
{
 const row=scan.results.find(r=>r.assetId==='print_shop'&&r.fine?.found),f=await createCivilianNativeFixture({assetId:row.assetId}),b=f.box;
 b._civilianPlanNext=()=>false;b._maybePlanResidentBuildingVisit=()=>false;b.findWanderGridExit18=testedHelper;b._npcFindWanderGridExit=testedHelper;
 vm.runInContext(testedPick,b);
 const n={id:'retained',...row.start,hp:60};b.NPCS.push(n);
 const baseClock=b.performance.now,basePoint=b.npcWaypointOk;let queryCpu=0;
 b.performance.now=()=>baseClock()+queryCpu;b.npcWaypointOk=(...args)=>{queryCpu+=.12;return basePoint(...args)};
 const pending=()=>{for(let i=0;i<80;i++){f.nextFrame(.05);b.pickNpcWaypoint(n);if(n._npcWanderSearch?.gridExit)return n._npcWanderSearch;}assert.fail('bounded fine search is pending');};
 let state=pending(),fine=state.gridExit;assert(!n._route?.length);assert.equal(n.idleUntil,0);
 f.nextFrame(.05);b.pickNpcWaypoint(n);assert.equal(n._npcWanderSearch,state);assert.equal(n._npcWanderSearch.gridExit,fine,'fine frontier survives admitted slices');assert.deepEqual({r:n.r,c:n.c},row.start);
 const coarseCell={r:Math.floor(n.r),c:Math.floor(n.c)};n.c+=.02;const shifted={r:n.r,c:n.c};
 assert.deepEqual({r:Math.floor(n.r),c:Math.floor(n.c)},coarseCell,'external displacement stays in the same coarse cell');
 assert(b._npcBodyPassable(n.r,n.c,b.npcPassable),'shifted exact origin is physically valid');
 state=pending();assert.notEqual(state.gridExit,fine,'exact-origin displacement invalidates fine nodes despite unchanged outer coarse key');
 assert.equal(state.gridExit.originR,n.r);assert.equal(state.gridExit.originC,n.c);assert.equal(state.gridExit.queue[0].c,n.c);
 let shiftedReady=false;for(let i=0;i<240&&!shiftedReady;i++){f.nextFrame(.05);shiftedReady=b.pickNpcWaypoint(n);}assert(shiftedReady,'restarted fine search publishes from the shifted position');
 let from=shifted;for(const to of n._route){assert(b._npcPathPassable(from.r,from.c,to.r,to.c,b.npcPassable),'all shifted-origin edges are physically clear');from=to;}assert.deepEqual({r:n.r,c:n.c},shifted,'search never restores or teleports to the old origin');
 b._clearNpcRoute(n);state=pending();fine=state.gridExit;
 b.changedResolver=q=>b.nativePedestrianQuery(q);vm.runInContext('_walkNpcNavigationResolver=changedResolver',b);state=pending();assert.notEqual(state.gridExit,fine,'resolver change invalidates old fine frontier');fine=state.gridExit;
 n._allowBeach=true;state=pending();assert.notEqual(state.gridExit,fine,'permitted surface change invalidates old fine frontier');
 b._clearNpcRoute(n);assert.equal(n._npcWanderSearch,null);pending();n.panicUntil=b.performance.now()+10000;f.nextFrame(.05);b.pickNpcWaypoint(n);assert.equal(n._npcWanderSearch,null,'panic cancels fine connector');
 n.panicUntil=0;pending();n.dead=true;f.nextFrame(.05);b.pickNpcWaypoint(n);assert.equal(n._npcWanderSearch,null,'death cancels fine connector');
}
{
 const row=scan.results.find(r=>r.assetId==='print_shop'&&r.fine?.found),f=await createCivilianNativeFixture({assetId:row.assetId}),b=f.box;
 b._civilianPlanNext=()=>false;b._maybePlanResidentBuildingVisit=()=>false;b.findWanderGridExit18=testedHelper;b._npcFindWanderGridExit=testedHelper;vm.runInContext(testedPick,b);
 const n={id:'occupied-goal',...row.start,hp:60};b.NPCS.push(n,{id:'reserved',r:6.5,c:98.5,hp:60,_routeGoalR:7.5,_routeGoalC:98.5});
 let ready=false;for(let i=0;i<160&&!ready;i++){f.nextFrame(.05);ready=b.pickNpcWaypoint(n);}assert(ready,'another reachable exit is found without taking the occupied goal');
 const end=n._route.at(-1),key=Math.floor(end.r)+','+Math.floor(end.c);assert(!['6,98','7,98'].includes(key),'actor location and reserved goal both remain exclusive');
 results.push({scenario:'occupied coarse exit',chosenEnd:end,pathPoints:n._route.length});
}
const depthFirstCandidate=process.argv.includes('--depth-first')&&!depthFirstApplied;
const report={appliedProduction:applied,depthFirstApplied,depthFirstCandidate,results,limits:(depthFirstCandidate?'Actual grid-exit helper with CANDIDATE depth-first override of pickNpcWaypoint. ':applied?'Actual production helper and pickNpcWaypoint, without candidate reinjection. ':'CANDIDATE ONLY, injected into CPU test. ')+'Actual GLB and native collision CPU, original final .4/intermediate .001 arrival handling. No GPU/LIVE/FPS claim.'};
fs.writeFileSync('outputs/npc_wander_grid_exit_candidate18'+(depthFirstCandidate?'_depth_first':'')+'.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
