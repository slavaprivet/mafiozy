import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';

const code=fs.readFileSync('assets/maps/city_rebuild_v1/npc_native_directed_route_source.js','utf8');
const before=code.replace(/  const directLength=[\s\S]*?search\.direct=[^\n]*\n/,'').replace(/ \/\/ BEGIN short direct approach[\s\S]*? \/\/ END short direct approach\r?\n/,'');
assert.notEqual(before,code);
function unit(resolver=()=>({swept:true,blocked:false})){
 const b={MAP_COLS:100,Math,Map,_walkNpcNavigationResolver:resolver,_npcRouteWorkExpired:()=>false,_setNpcRoute:(n,p)=>{n._route=p;return p.length>0;}};
 vm.createContext(b);vm.runInContext(code,b);return b;
}
{
 const b=unit(),n={r:2.5,c:2.5},pass=(r,c)=>r>0&&c>0&&r<20&&c<20;
 assert(b._npcPlanNativeVisitRoute(n,4.5,4.5,pass,.8,1200,'building_entry'));
 assert.equal(n._routeSearchExpanded,0);assert.equal(n._route.length,1);
 assert.deepEqual([n.r,n.c],[2.5,2.5],'planning never moves NPC');
 let checks=0;b._npcRouteWorkExpired=()=>++checks>4;const deferred={r:2.5,c:2.5};
 assert.equal(b._npcPlanNativeVisitRoute(deferred,6.5,4.5,pass,.8,1200,'building_entry'),false);
 const search=deferred._npcDirectedSearch;assert(deferred._routeSearchPending);assert(search.direct.sample>0);
 b._npcRouteWorkExpired=()=>false;deferred._routeSearchPending=false;
 assert(b._npcPlanNativeVisitRoute(deferred,6.5,4.5,pass,.8,1200,'building_entry'));
 assert.equal(deferred._routeSearchRestarts,undefined,'resume retains progress');
 let blocked=false;const changed=unit(q=>({swept:true,blocked:blocked&&Math.hypot(q.to.r-q.from.r,q.to.c-q.from.c)>2}));
 const waiting={r:2.5,c:2.5};checks=0;changed._npcRouteWorkExpired=()=>++checks>4;
 assert.equal(changed._npcPlanNativeVisitRoute(waiting,6.5,4.5,pass,.8,1200,'building_entry'),false);
 blocked=true;changed._npcRouteWorkExpired=()=>false;waiting._routeSearchPending=false;
 assert(changed._npcPlanNativeVisitRoute(waiting,6.5,4.5,pass,.8,1200,'building_entry'));
 assert(waiting._routeSearchExpanded>0,'door closing between slices invalidates direct corridor');
}
{
 let directSweeps=0;
 const b=unit(q=>{if(Math.hypot(q.to.r-q.from.r,q.to.c-q.from.c)>2){directSweeps++;return {swept:true,blocked:true};}return {swept:true,blocked:false};});
 const n={r:2.5,c:2.5},pass=(r,c)=>r>0&&c>0&&r<20&&c<20;
 assert(b._npcPlanNativeVisitRoute(n,6.5,4.5,pass,.8,1200,'building_entry'));assert.equal(directSweeps,1);assert(n._routeSearchExpanded>0,'thin solid sweep refusal falls back to A*');
 const water={r:2.5,c:2.5},b2=unit();
 const land=(r,c)=>pass(r,c)&&!(r>3.2&&r<3.8&&c>2.9&&c<4.1);
 assert(b2._npcPlanNativeVisitRoute(water,4.5,4.5,land,.8,1200,'building_entry'));assert(water._routeSearchExpanded>0,'body/water rejection falls back');
 let wide=0;const long=unit(q=>{if(Math.hypot(q.to.r-q.from.r,q.to.c-q.from.c)>2)wide++;return {swept:true,blocked:false};});
 assert(long._npcPlanNativeVisitRoute({r:2.5,c:2.5},15.5,2.5,pass,.8,1200,'building_entry'));assert.equal(wide,0,'long trips do not add an unbounded direct probe');
}

const results=[];
for(const assetId of ['hospital','print_shop','old_town_narrow_townhouse_v1']){
 const f=await createCivilianNativeFixture({assetId}),b=f.box,door=b._residentBuildingDoors()[0],starts=[];
 for(const radius of [1.5,3,5,7])for(let i=0;i<16;i++){
  const a=i*Math.PI/8,p={r:door.r+Math.sin(a)*radius,c:door.c+Math.cos(a)*radius};
  if(b._npcBodyPassable(p.r,p.c,b.npcPassableForSnitch))starts.push(p);
 }
 const row={assetId,starts:starts.length};
 for(const [label,version] of [['before',before],['after',code]]){
  vm.runInContext(version,b);const costs=[],records=[];let queries=0;
  // Repeat the same physical paths to reduce one-off module/JIT noise.
  for(let repeat=-1;repeat<3;repeat++)for(const start of starts){
   const n={...start},pass=(r,c)=>b._npcBodyPassable(r,c,b.npcPassableForSnitch);let ok=false,slices=0,cpuMs=0;
   const diagnosticsBefore=f.pedestrian.diagnostics();
   do{
    f.nextFrame();const began=performance.now();b._npcRouteWorkExpired=()=>performance.now()-began>=4;
    n._routeSearchPending=false;ok=b._npcPlanNativeVisitRoute(n,door.r,door.c,pass,.8,1200,'building_entry');
    const elapsed=performance.now()-began;cpuMs+=elapsed;if(repeat>=0)costs.push(elapsed);slices++;
   }while(n._routeSearchPending&&slices<300);
   const diagnosticsAfter=f.pedestrian.diagnostics();
   assert(!n._routeSearchPending,assetId+' route converges');
   const path=ok?n._route:[],tail=path.at(-1)||start;
   const reached=Math.hypot(tail.r-door.r,tail.c-door.c)<=.9&&b._npcPathPassable(tail.r,tail.c,door.r,door.c,b.npcPassableForSnitch);
   let from=start;for(const to of path){assert(b._npcPathPassable(from.r,from.c,to.r,to.c,b.npcPassableForSnitch),label+' returned full body swept edge');from=to;}
   if(repeat>=0)records.push({reached,slices,cpuMs,expanded:n._routeSearchExpanded,direct:n._routeSearchExpanded===0&&ok,queries:diagnosticsAfter.queries-diagnosticsBefore.queries,sweeps:diagnosticsAfter.sweepQueries-diagnosticsBefore.sweepQueries});
  }
  costs.sort((a,b)=>a-b);const sum=records.reduce((s,r)=>s+r.cpuMs,0);
  row[label]={reached:records.filter(r=>r.reached).length,direct:records.filter(r=>r.direct).length,slices:records.reduce((s,r)=>s+r.slices,0),expanded:records.reduce((s,r)=>s+(r.expanded||0),0),nativeQueries:records.reduce((s,r)=>s+r.queries,0),sweeps:records.reduce((s,r)=>s+r.sweeps,0),cpuMs:sum,sliceP50:costs[Math.floor(costs.length*.5)],sliceP95:costs[Math.floor(costs.length*.95)]};
 }
 assert(row.after.reached>=row.before.reached,assetId+' no reachability regression');
 assert(row.after.nativeQueries<row.before.nativeQueries,assetId+' strictly less native query work');results.push(row);
}
console.log(JSON.stringify({pass:true,results,limits:'CPU actual GLB/static city/water/car/body sweep, 4 ms planner slices; excludes whole-world frame cost, loaded game and FPS.'},null,2));
