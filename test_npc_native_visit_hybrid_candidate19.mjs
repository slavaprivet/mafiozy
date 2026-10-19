import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
import {nativeVisitHybridCandidate19} from './npc_native_visit_hybrid_candidate19.mjs';
const source=fs.readFileSync('assets/maps/city_rebuild_v1/npc_native_directed_route_source.js','utf8'),world=fs.readFileSync('world.html','utf8'),candidate=nativeVisitHybridCandidate19(source,world);new vm.Script(candidate);
const f=await createCivilianNativeFixture({assetId:'garden_lane_house_v1'}),b=f.box,start={r:7.6767766953,c:129.6767766953},goal={r:9.794878025752743,c:135.79771782019736};
vm.runInContext('_npcRouteWorkExpired=()=>false',b);
const reports=[];let first;
for(let trial=0;trial<12;trial++)for(const [label,code] of trial%2?[['hybrid',candidate],['fine',source]]:[['fine',source],['hybrid',candidate]]){
 vm.runInContext(code,b);f.nextFrame(.125);const npc={...start};let calls=0;const pass=(r,c)=>{calls++;return b._npcBodyPassable(r,c,b.npcPassableForSnitch);},at=performance.now();
 const ready=b._npcPlanNativeVisitRoute(npc,goal.r,goal.c,pass,.8,1200,'building_entry'),ms=performance.now()-at;assert(ready,label);assert.equal(npc.r,start.r);assert.equal(npc.c,start.c);
 let from=start,length=0;for(const p of npc._route){assert(b._npcPathPassable(from.r,from.c,p.r,p.c,b.npcPassableForSnitch),label+' physical edge');length+=Math.hypot(p.r-from.r,p.c-from.c)*4.1;from=p;}assert.deepEqual(JSON.parse(JSON.stringify(npc._route.at(-1))),goal);
 if(label==='hybrid')first=JSON.parse(JSON.stringify(npc._route));reports.push({trial,label,ms,calls,expanded:npc._routeSearchExpanded,visited:npc._routeSearchVisited,length});
}
const stats={};for(const label of ['fine','hybrid']){const rows=reports.filter(r=>r.label===label&&r.trial>=2),times=rows.map(r=>r.ms).sort((a,b)=>a-b);stats[label]={...rows.at(-1),p50:times[5],p95:times[9]};delete stats[label].ms;}
console.log(JSON.stringify({passed:true,stats,prefix:first.slice(0,6)}));
// Narrow corridor: no coarse terminal anchor exists, original fine fallback must survive.
function simple(code){const box={MAP_COLS:200,_walkNpcNavigationResolver:()=>({swept:false}),_npcRouteWorkExpired:()=>false,_setNpcRoute:(n,p)=>{n._route=p;return true;}};vm.createContext(box);vm.runInContext(code,box);return box;}
const narrowPass=(r,c)=>Math.abs(r-10.2)<.11&&c>=10.1&&c<=21.3;
let narrowExpected;for(const code of [source,candidate]){const q=simple(code),n={r:10.2,c:10.2};assert(q._npcPlanNativeVisitRoute(n,10.2,21.2,narrowPass,.1,1200,'building_entry'));const value=JSON.parse(JSON.stringify({path:n._route,visited:n._routeSearchVisited,expanded:n._routeSearchExpanded}));if(narrowExpected)assert.deepEqual(value,narrowExpected);else narrowExpected=value;}
// Bounded local escape and coarse continuation failures both return to original fine search.
for(const phase of ['exit','coarse']){
 vm.runInContext(candidate,b);vm.runInContext('_npcRouteWorkExpired=()=>false',b);f.nextFrame(.125);
 if(phase==='exit')b._npcFindVisitGridExit19=()=>({status:'failed',nodes:96,expanded:96});
 else {const actual=b._npcPlanNativeVisitRoute;b._npcPlanNativeVisitRoute=(n,...args)=>{if(n._npcVisitHybridDisabled){n._routeSearchVisited=192;return false;}return actual(n,...args);};}
 const n={...start},pass=(r,c)=>b._npcBodyPassable(r,c,b.npcPassableForSnitch);assert(b._npcPlanNativeVisitRoute(n,goal.r,goal.c,pass,.8,1200,'building_entry'),phase+' fallback');assert(n._routeSearchVisited<=1203);assert.equal(n.r,start.r);assert.equal(n.c,start.c);
 let from=start;for(const p of n._route){assert(b._npcPathPassable(from.r,from.c,p.r,p.c,b.npcPassableForSnitch));from=p;}
}
// A moved obstacle after coarse planning invalidates the cached physical prefix.
vm.runInContext(candidate,b);f.nextFrame(.125);let yieldNow=false,blocked=false,blockedCalls=0,coarsePublished=0;
const originalSet=b._setNpcRoute,obstacle=first[1];b._setNpcRoute=(n,path,kind)=>{const result=originalSet(n,path,kind);if(n._npcVisitHybridDisabled){coarsePublished++;yieldNow=true;}return result;};
b._npcRouteWorkExpired=()=>yieldNow;
const dynamicPass=(r,c)=>{if(blocked&&Math.hypot(r-obstacle.r,c-obstacle.c)<.17){blockedCalls++;return false;}return b._npcBodyPassable(r,c,b.npcPassableForSnitch);};
const n={...start};assert.equal(b._npcPlanNativeVisitRoute(n,goal.r,goal.c,dynamicPass,.8,1200,'building_entry'),false);assert.equal(coarsePublished,1);assert(n._routeSearchPending);assert.equal(n._npcDirectedSearch.pass,dynamicPass);assert.equal(n._npcDirectedSearch.hybrid.phase,'verify');assert.equal(n.r,start.r);assert.equal(n.c,start.c);
blocked=true;yieldNow=false;n._routeSearchPending=false;f.nextFrame(.125);assert(b._npcPlanNativeVisitRoute(n,goal.r,goal.c,dynamicPass,.8,1200,'building_entry'));assert(blockedCalls>0);assert(!n._routeSearchRestarts);assert.equal(n.r,start.r);assert.equal(n.c,start.c);assert(n._routeSearchVisited<=1203);
let from=start;for(const p of n._route){for(let i=1,count=Math.max(1,Math.ceil(Math.hypot(p.r-from.r,p.c-from.c)/.14));i<=count;i++)assert(dynamicPass(from.r+(p.r-from.r)*i/count,from.c+(p.c-from.c)*i/count));from=p;}
b._setNpcRoute=originalSet;
// Same original callback identity across normal time slices; no stale closure in search.
vm.runInContext(candidate,b);let checks=0;b._npcRouteWorkExpired=()=>++checks>20;const sliced={...start},stablePass=(r,c)=>b._npcBodyPassable(r,c,b.npcPassableForSnitch);let complete=false,slices=0;
for(;slices<100;slices++){checks=0;f.nextFrame(.125);sliced._routeSearchPending=false;complete=b._npcPlanNativeVisitRoute(sliced,goal.r,goal.c,stablePass,.8,1200,'building_entry');assert.equal(sliced.r,start.r);assert.equal(sliced.c,start.c);if(complete)break;assert(sliced._routeSearchPending);assert.equal(sliced._npcDirectedSearch.pass,stablePass);if(sliced._npcDirectedSearch.hybrid?.proxy?._npcDirectedSearch)assert.equal(sliced._npcDirectedSearch.hybrid.proxy._npcDirectedSearch.pass,stablePass);}
assert(complete&&slices>0);assert(!sliced._routeSearchRestarts);
const error=new Error('predicate identity');assert.throws(()=>simple(candidate)._npcPlanNativeVisitRoute({r:10.5,c:10.5},10.5,10.6,()=>{throw error;},.8,1200,'building_entry'),value=>value===error);
console.log(JSON.stringify({regressions:true,slices,checks:['narrow corridor without coarse goal exact parity','forced exit and coarse failure recover with original fine search','moving obstacle prefix revalidation','actor never moved','original callback identity','callback exceptions escape','visited shared cap']}));

// 48 existing hospital origins: exact parity unless bounded hybrid is actually selected.
const hospital=await createCivilianNativeFixture(),hb=hospital.box,door=hb._residentBuildingDoors()[0],starts=[];vm.runInContext('_npcRouteWorkExpired=()=>false',hb);
for(let radius=8;radius<=32&&starts.length<48;radius+=3)for(let i=0;i<16&&starts.length<48;i++){const a=i*Math.PI/8,p={r:Math.floor(door.r+Math.sin(a)*radius)+.5,c:Math.floor(door.c+Math.cos(a)*radius)+.5};if(hb._npcBodyPassable(p.r,p.c,hb.npcPassableForSnitch))starts.push(p);}assert.equal(starts.length,48);
const hospitalPaths=[];for(const [label,code]of [['fine',source],['hybrid',candidate]]){vm.runInContext(code,hb);let changed=0;for(const [index,origin]of starts.entries()){hospital.nextFrame(.125);const actor={...origin};assert(hb._npcPlanNativeVisitRoute(actor,door.r,door.c,(r,c)=>hb._npcBodyPassable(r,c,hb.npcPassableForSnitch),.8,1200,'building_entry'));const path=JSON.parse(JSON.stringify(actor._route));if(label==='fine')hospitalPaths.push(path);else{if(JSON.stringify(path)!==JSON.stringify(hospitalPaths[index]))changed++;let from=origin;for(const to of path){assert(hb._npcPathPassable(from.r,from.c,to.r,to.c,hb.npcPassableForSnitch));from=to;}assert.equal(from.r,door.r);assert.equal(from.c,door.c);}}if(label==='hybrid')console.log(JSON.stringify({hospitalRoutes:48,changed,allEdgesClear:true}));}
// Natural narrow corridors, including a tempting coarse dead-end chamber.
for(const deadEnd of [false,true]){const q=simple(candidate),origin={r:10.2,c:10.2},target={r:10.5,c:22.5};let exitReady=0,exitFailed=0;const exit=q._npcFindVisitGridExit19;q._npcFindVisitGridExit19=(...args)=>{const v=exit(...args);if(v.status==='ready')exitReady++;if(v.status==='failed')exitFailed++;return v;};const pass=(r,c)=>(Math.abs(r-10.2)<.11&&c>=10.1&&c<=22.7)||(r>=9.9&&r<=10.8&&c>=21.2&&c<=23.2)||(deadEnd&&r>=9.9&&r<=10.8&&c>=11.2&&c<=12.8);const actor={...origin};assert(q._npcPlanNativeVisitRoute(actor,target.r,target.c,pass,.1,1200,'building_entry'));assert.equal(actor.r,origin.r);assert.equal(actor.c,origin.c);assert(actor._routeSearchVisited<=1203);assert(deadEnd?exitReady>0:exitFailed>0);let from=origin;for(const to of actor._route){for(let i=1,count=Math.ceil(Math.hypot(to.r-from.r,to.c-from.c)/.07);i<=count;i++)assert(pass(from.r+(to.r-from.r)*i/count,from.c+(to.c-from.c)*i/count));from=to;}console.log(JSON.stringify({naturalFallback:deadEnd?'coarse dead end':'no nearby coarse exit',visited:actor._routeSearchVisited,exitReady,exitFailed}));}
