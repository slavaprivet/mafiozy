import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const source=fs.readFileSync('world.html','utf8'),fn=name=>{const start=source.indexOf('function '+name+'(');let p=source.indexOf('{',start),d=1;for(p++;d;p++){if(source[p]==='{')d++;if(source[p]==='}')d--;}return source.slice(start,p);};
const planner=source.slice(source.indexOf('let _npcRouteWorkFrame='),source.indexOf('function _planNpcEscapeRoute('));
function fixture(legacy=false){
 let clock=1000;const c={Math,Number,Map,Set,performance:{now:()=>clock},prevT:1,MAP_ROWS:80,MAP_COLS:80,_residentBuildingRouteBudget:1,_walkNpcNavigationResolver:()=>({surface:'land'}),_beachDecor:[],_civilianPlanEligible:()=>true,_civilianPlanInterrupted:()=>false,_civilianPlanUnit:()=>0};
 c.npcWaypointOk=(n,r,col)=>{clock+=.6;return r>0&&col>0&&r<79&&col<79;};c._npcBodyPassable=(r,col,pass)=>pass(r,col);c._npcPathPassable=(r,col,rr,cc,pass)=>pass(rr,cc);c.npcPassableForSnitch=(r,col)=>c.npcWaypointOk(null,r,col);
 vm.createContext(c);vm.runInContext(planner+';const _civilianBenchReservations=new Map();const _civilianPlaces={benches:[{id:"bench",r:40.5,c:40.5,yaw:0,seatWorldY:.6}]};',c);
 for(const name of ['_clearNpcRoute','_setNpcRoute','_civilianRouteTo','_civilianPlanCancel'])vm.runInContext(fn(name),c);
 let next=fn('_civilianPlanNext');if(legacy)next=next.replace("const nativeRouting=typeof _walkNpcNavigationResolver==='function';","const nativeRouting=false;");vm.runInContext(next,c);
 return {c,actor:id=>({id,r:30.5,c:30.5,tr:30.5,tc:30.5,hp:100,_civilianPlan:{phase:'walk_to_bench',cycle:0}}),frame(){clock+=20;c.prevT++;c._residentBuildingRouteBudget=1;},clock:()=>clock};
}
function contention(legacy){
 const f=fixture(legacy),a=f.actor('first'),b=f.actor('fifo-head');f.c.a=a;f.c.b=b;
 // Both slots are occupied when B originally requests its bench: this is a real
 // deferred planner request with no frontier, exactly the zero/zero LIVE case.
 vm.runInContext('_npcRouteWorkFrame=prevT;_npcRouteWorkCount=2;',f.c);f.c._civilianPlanNext(b);assert(b._routeSearchPending);assert(!b._npcDirectedSearch);
 for(let i=0;i<12;i++){f.frame();f.c._civilianPlanNext(a);f.c._civilianPlanNext(b);assert(vm.runInContext('_npcRouteWorkCount<=2',f.c));}
 return b._npcDirectedSearch?.qi||0;
}
assert.equal(contention(true),0,'old local bench slot is consumed before the FIFO head can request work');assert(contention(false)>0,'the FIFO head now reaches the shared planner without a second conflicting admission gate');
const f=fixture(),n=f.actor('cancelled');f.c.n=n;vm.runInContext('_npcRouteWorkFrame=prevT;_npcRouteWorkCount=2;',f.c);f.c._civilianRouteTo(n,40.5,40.5,'building_entry');assert(n._routeSearchPending);assert(!n._npcDirectedSearch);assert(vm.runInContext('_npcRouteWorkQueue.has(n)',f.c));
n._civilianPlan.phase='seek_shop';f.c._civilianPlanCancel(n);assert.equal(n._routeSearchPending,false,'even a never-admitted seek-shop request is cancelled');assert.equal(n._npcDirectedSearch,null);assert.equal(n._routeRequestAt,null);assert(!vm.runInContext('_npcRouteWorkQueue.has(n)',f.c),'cancelled civilian no longer occupies the FIFO');
f.frame();f.c._planNpcRouteTo(n,50.5,50.5,f.c.npcPassableForSnitch,.8,1200,'help');assert(n._routeSearchPending);const helping=n._npcDirectedSearch;f.c._civilianPlanCancel(n);assert.equal(n._npcDirectedSearch,helping,'cancelling old civilian intent must preserve the current helper route');assert(n._routeSearchPending);
console.log('PASS actual source: old native bench/FIFO double-gate starves 0-frontier head; unchanged shared budget now expands it; abandoned pending intent cancels without clearing a newer helper route');
