import vm from 'node:vm';import assert from 'node:assert/strict';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
import {prefetchPlanner18,makePrefetchJob18,stepPrefetch18,adoptPrefetch18} from './npc_wander_prefetch_prototype18.mjs';
const f=await createCivilianNativeFixture(),b=f.box;
vm.runInContext(prefetchPlanner18(sourceFunction(f.source,'pickNpcWaypoint').replace(/\r\n/g,'\n')),b);
// A real short continuation on the hospital pavement, verified geometrically.
const door=b._residentBuildingDoors()[0];let start,end;
for(let r=door.r-8;r<door.r+8&&!end;r+=.5)for(let c=door.c-8;c<door.c+8&&!end;c+=.5){
 const n={r,c,_arcKey:'worker'};if(b.npcWaypointOk(n,r,c)&&b.npcWaypointOk(n,r+1,c)&&b._npcPathPassable(r,c,r+1,c,b.npcPassable)){start={r,c};end={r:r+1,c};}
}
assert(end);const n={...start,id:'resident_prefetch18',hp:100,speed:1,walkPhase:0,walking:true,_arcKey:'worker',_civilianPlan:{phase:'seek_shop',cycle:0,retryAt:999999},_routeStartR:start.r-4,_routeStartC:start.c-4};
f.npcs.push(n);b._setNpcRoute(n,[end],'walk');
const job=makePrefetchJob18(n,b,f.now);assert(job);const originalRoute=n._route,original={r:n.r,c:n.c,tr:n.tr,tc:n.tc};
// An actual urgent owner waits at the FIFO head: prefetch gets no slice.
vm.runInContext('_npcRouteWorkQueue.set({id:"urgent_real_resident"},_npcRouteWorkEpoch);',b);
stepPrefetch18(job,b,f.now);assert.equal(job.actor._npcWanderSearch.qi,0);assert.equal(job.actor._routeQueueAdmittedAt,undefined);
vm.runInContext('_npcRouteWorkQueue.clear();',b);
let slices=0;for(;slices<200&&job.status==='pending';slices++){f.nextFrame(.05);stepPrefetch18(job,b,f.now);assert.deepEqual({r:n.r,c:n.c,tr:n.tr,tc:n.tc},original);assert.equal(n._route,originalRoute);assert(n.walking);}
assert.equal(job.status,'ready');assert(!adoptPrefetch18(job,b,f.now),'future route cannot be adopted before physical endpoint');
// Test placement is only fixture setup, never prototype motion or production.
Object.assign(n,end);assert(adoptPrefetch18(job,b,f.now,()=>false));assert.equal(job.status,'adopted');assert.notEqual(n._route,originalRoute);
const second=makePrefetchJob18(n,b,f.now);assert(second);n.panicUntil=f.now+1000;assert(!stepPrefetch18(second,b,f.now));assert.equal(second.status,'cancelled');n.panicUntil=0;
// A prepared path loses to an ordinary meaningful task chosen at arrival.
const prepared={...job,status:'ready',route:n._route,endpoint:{r:n.r,c:n.c},path:n._route};assert(!adoptPrefetch18(prepared,b,f.now,actor=>{actor._routeSearchPending=true;return true;}));assert.equal(prepared.status,'superseded');n._routeSearchPending=false;
console.log(JSON.stringify({pass:true,slices,pathPoints:job.path.length,contracts:['old route and coordinates unchanged during preparation','same FIFO/CPU reserve with null low-priority owner','urgent queue suppresses prefetch','no early adoption','fresh first edge footprint and sweep','panic cancellation','purpose decision priority'],limits:'Isolated actual-geometry contract prototype only. No production pump/integration, no population throughput claim, no GPU.'},null,2));
