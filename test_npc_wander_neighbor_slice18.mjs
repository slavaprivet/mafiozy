import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {neighborSliceCandidate18,historicalWholeNode18} from './npc_wander_neighbor_slice_candidate18.mjs';
import {historicalEagerWander19} from './npc_wander_lazy_compare19.mjs';
const world=fs.readFileSync('world.html','utf8').replace(/\r\n/g,'\n');
const fn=name=>{const start=world.indexOf('function '+name+'(');assert(start>=0);return world.slice(start,world.indexOf('\n}',start)+2)};
const queue=world.slice(world.indexOf('let _npcRouteWorkFrame='),world.indexOf('function _planNpcRouteTo('));
const production=fn('pickNpcWaypoint'),lazy=production.includes('search.lazyStack');
// Keep the historical whole-node regression, then exercise the actual lazy
// planner's per-edge yielding and backtracking in its current contract suite.
const actual=lazy?historicalEagerWander19(production):production,applied=actual.includes('let neighborYield=false;');
const current=applied?historicalWholeNode18(actual):actual,candidate=applied?actual:neighborSliceCandidate18(actual);
assert.equal(neighborSliceCandidate18(current),candidate,'applied production equals exactly one scoped neighbor transform');
new vm.Script(candidate);
function fixture(pick,cost=.02,blocked=false){
 let now=1000,checks=0;
 const b={Math,Number,Array,Map,Set,NPCS:[],MAP_COLS:200,MAP_ROWS:200,performance:{now:()=>now},prevT:1,_walkNpcNavigationResolver:()=>({swept:true,blocked:false}),_civilianPlanNext:()=>false,_maybePlanResidentBuildingVisit:()=>false};
 b.npcWaypointOk=(n,r,c)=>{checks++;now+=cost;return !blocked||!(c>10.6&&c<10.7)};
 b._npcPathPassable=(fr,fc,r,c,pass)=>pass(r,c);
 vm.createContext(b);vm.runInContext(queue,b);
 for(const name of ['_clearNpcRoute','_setNpcRoute'])vm.runInContext(fn(name),b);
 vm.runInContext(pick,b);
 return{b,get now(){return now},get checks(){return checks},advance:ms=>now+=ms,frame:i=>{now=1000+i*50;b.prevT=i;}};
}
function firstSlice(pick){
 const f=fixture(pick),n={id:'resident_clock',r:10.5,c:10.5,hp:60};f.b.NPCS.push(n);
 f.b._maybePlanResidentBuildingVisit=()=>{f.advance(6);return false};
 const started=f.now;f.b.pickNpcWaypoint(n);
 return{elapsedMs:f.now-started,checks:f.checks,qi:n._npcWanderSearch?.qi,nextDirection:n._npcWanderSearch?.nextDirection};
}
const before=firstSlice(current),after=firstSlice(candidate);
assert(after.elapsedMs<10.3,'existing clock regression bound remains unchanged');
assert(after.elapsedMs<before.elapsedMs);
// With a cheap clock, both implementations complete the identical DFS route.
// Costly slices must retain the same route, parent order and candidate count.
function complete(pick,cost,blocked,oneNeighbor=false){
 const f=fixture(pick,cost,blocked),n={id:'resident_clock',r:10.5,c:10.5,hp:60};f.b.NPCS.push(n);let previous=null,resumed=0,peak=0;
 for(let i=1;i<=150&&!n._route?.length;i++){
  f.frame(i);if(oneNeighbor){let deadlineChecks=0;f.b._npcRouteWorkExpired=()=>++deadlineChecks>2;}
  const start=f.now;f.b.pickNpcWaypoint(n);peak=Math.max(peak,f.now-start);
  const s=n._npcWanderSearch;
  if(s){assert.equal(new Set(s.candidates.map(p=>p.key)).size,s.candidates.length,'candidate published once per node');
   if(previous&&previous.node===s.expandingNodeKey&&s.qi===previous.qi){assert(s.nextDirection>=previous.direction,'resume does not restart directions');resumed++;}
   previous={node:s.expandingNodeKey,qi:s.qi,direction:s.nextDirection};
  }
 }
 assert(n._route?.length>=8,'long route eventually completes');
 const path=Array.from(n._route,p=>({r:p.r,c:p.c}));assert.equal(new Set(path.map(p=>p.r+'|'+p.c)).size,path.length,'no repeated path nodes');
 return{path,resumed,peak,checks:f.checks};
}
const cases=[];for(const blocked of [false,true]){
 const reference=complete(current,0,blocked),cheap=complete(candidate,0,blocked),sliced=complete(candidate,.02,blocked),everyNeighbor=complete(candidate,.02,blocked,true);
 assert.deepEqual(cheap.path,reference.path,'candidate preserves original DFS neighbor ordering');assert.deepEqual(sliced.path,reference.path,'time slicing preserves original full route');
 assert(sliced.peak<=4+41*.02+1e-8,'at most one edge worth of atomic overrun');
 assert.deepEqual(everyNeighbor.path,reference.path,'forced yield after each neighbor retains every parent/direction');
 assert(everyNeighbor.resumed>0,'forced test actually resumes the same node multiple times');
 assert(everyNeighbor.peak<=41*.02+1e-8,'forced slice contains at most one complete edge');
 cases.push({blocked,...sliced,everyNeighbor:{resumed:everyNeighbor.resumed,peak:everyNeighbor.peak,checks:everyNeighbor.checks}});
}
fs.writeFileSync('outputs/pickNpcWaypoint_neighbor_slice_staged18.js',candidate+'\n');
console.log(JSON.stringify({applied,before,after,cases,limits:'Actual source versus reconstructed historical whole-node baseline; deterministic point-query cost and controlled static obstacles; no production edit by test or GPU/FPS claim.'},null,2));
if(lazy)await import('./test_npc_wander_lazy19.mjs');
