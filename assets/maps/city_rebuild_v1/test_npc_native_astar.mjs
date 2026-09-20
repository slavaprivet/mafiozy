import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8').replace(/\r\n/g,'\n');
const planner=world.slice(world.indexOf('function _planNpcRouteTo('),world.indexOf('function _planNpcEscapeRoute('));
const scheduler=world.slice(world.indexOf('let _npcRouteWorkFrame='),world.indexOf('function _planNpcRouteTo('));
assert(scheduler.includes('function _npcReserveRouteWork(')&&scheduler.includes('function _npcFinishRouteWork('));
let allowance=4,sweeps=0;const pass=(r,c)=>r>0&&r<18&&c>0&&c<18&&!(c>5.8&&c<7.2&&r<8);
const resolver=()=>{sweeps++;return {swept:true,blocked:false};};
const box=vm.createContext({MAP_COLS:30,prevT:0,performance:{now:()=>0},_walkNpcNavigationResolver:resolver,_setNpcRoute:(n,path)=>{n._route=path;return !!path.length},npcPassable:pass});
vm.runInContext(fs.readFileSync(new URL('./npc_native_directed_route_source.js',import.meta.url),'utf8'),box);vm.runInContext(scheduler+planner,box);
// Real scheduler state/admission/finish/cancellation stay together. This CPU
// test controls only slice expiration; it does not measure wall-clock latency.
box._npcRouteWorkExpired=()=>--allowance<0;
vm.runInContext('globalThis.schedulerQueue=_npcRouteWorkQueue;',box);
const resident=()=>({id:'persistent-frontier',r:2.2,c:2.2});
const route=(n,p=pass,cap=1000)=>{box.prevT++;return box._planNpcRouteTo(n,2.5,10.5,p,.1,cap,'building_entry');};
const n=resident();assert(!route(n));assert(n._routeSearchPending);const first=n._npcDirectedSearch;assert.equal(first.algorithm,'astar-visit');assert(first.heap.length&&(first.qi>0||first.goalDiscovery?.index>0),'slice advances anchor discovery or frontier');
allowance=4;route(n);assert.equal(n._npcDirectedSearch,first,'retains heap, nodes, callback between slices');assert(!n._routeSearchRestarts);
allowance=Infinity;assert(route(n));assert(!n._routeSearchPending);assert.equal(n._npcDirectedSearch,null);assert(n._route.some(p=>p.r>8));assert(n._route.every(p=>pass(p.r,p.c)));assert(sweeps>0);
assert.deepEqual([n.r,n.c],[2.2,2.2]);
for(const mode of ['callback','resolver','origin']){
 const n=resident();allowance=2;route(n);const old=n._npcDirectedSearch;
 let p=pass;if(mode==='callback')p=(r,c)=>pass(r,c);if(mode==='resolver')box._walkNpcNavigationResolver=()=>({swept:true,blocked:false});if(mode==='origin')n.r+=.05;
 allowance=2;route(n,p);assert.notEqual(n._npcDirectedSearch,old,mode+' invalidates stale frontier');assert.equal(n._routeSearchRestarts,1);box._walkNpcNavigationResolver=resolver;
}
const interrupted=resident();allowance=2;route(interrupted);box.schedulerQueue.set(interrupted,0);box._cancelNpcDirectedSearch(interrupted);assert.equal(interrupted._npcDirectedSearch,null);assert.equal(interrupted._routeSearchPending,false);assert(!box.schedulerQueue.has(interrupted));
const limited=resident();allowance=Infinity;route(limited,pass,12);assert(!limited._routeSearchPending);assert(limited._routeSearchVisited<=15,'same maxVisited boundary (one last cardinal expansion)');
// Exact sweep result is mandatory even where point samples allow the edge.
box._walkNpcNavigationResolver=()=>({swept:true,blocked:true});const blocked=resident();assert(!route(blocked));assert.equal(blocked._routeSearchVisited,2,'isolated start tries one coarse and one fine node; neither crosses a blocked sweep');assert(!blocked._route?.length);
// Legacy and non-visit directed paths still execute the original BFS.
box._walkNpcNavigationResolver=null;const legacy=resident();box._planNpcRouteTo(legacy,2.5,4.5,pass,.1,100,'directed');assert(legacy._route?.length);assert.equal(legacy._routeSearchExpanded,undefined);
console.log('PASS native visit A*: actual scheduler state, persistent heap, resolver/callback/origin identity, exact sweep, maxVisited, cancellation, immutable coordinates, legacy fallback. CPU controlled-expiration fixture; not LIVE latency/FPS.');
