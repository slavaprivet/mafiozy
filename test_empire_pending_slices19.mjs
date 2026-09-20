import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const source=fs.readFileSync('world.html','utf8').replace(/\r\n/g,'\n');
const fn=name=>{const a=source.indexOf('function '+name+'(');assert(a>=0);return source.slice(a,source.indexOf('\n}',a)+2)};
const declarations=source.slice(source.indexOf('const _empireRoutePlanQueue=[];'),source.indexOf('function _empireCrewOrigin('));
const production=fn('_processEmpireRoutePlanQueue');
const pendingStart=production.indexOf('    if(!accepted&&npc._routeSearchPending){'),pendingEnd=production.indexOf('    _countEmpireRoutePlan(accepted?',pendingStart);
assert(pendingStart>0&&pendingEnd>pendingStart);const old=production.slice(0,pendingStart)+production.slice(pendingEnd);
function setup(pump=production,oldLease=false){
 let now=1000,calls=0;const b={Math,Number,Map,Set,Array,Uint32Array,MAP_COLS:60,performance:{now:()=>now},prevT:0,document:{documentElement:{dataset:{}}},_walkNpcNavigationResolver:()=>({surface:'land'}),npcPassable:(r,c)=>r>1&&r<45&&c>1&&c<45};
 b._empireBossWaypointPassable=(r,c)=>{calls++;now+=.1;return b.npcPassable(r,c)};
 vm.createContext(b);let scheduler=source.slice(source.indexOf('let _npcRouteWorkFrame='),source.indexOf('function _planNpcRouteTo('));if(oldLease)scheduler=scheduler.replace('&&!(actor._empireRouteQueued&&actor._empirePendingRoute)','');vm.runInContext(scheduler,b);
 for(const name of ['_clearNpcRoute','_setNpcRoute','_planNpcRouteTo'])vm.runInContext(fn(name),b);
 vm.runInContext(declarations+fn('_planEmpireRouteTo')+pump,b);
 return {b,frame(){now+=50;b.prevT++;return now},get now(){return now},get calls(){return calls},queue(){return vm.runInContext('_empireRoutePlanQueue',b)},counters(){return vm.runInContext('Array.from(_empireRoutePlanTotals)',b)}};
}
const actor=id=>({id,r:10.5,c:10.5,hp:100,_empireActionKey:'inspect:shop:1',_empireRouteGeneration:1});
function request(f,n,r=20.5,c=20.5){f.b._planEmpireRouteTo(n,r,c,.8,6000,'empire_action',4000,2,n._empireActionKey);}
function run(pump){const f=setup(pump),n=actor('boss'),started=f.now;request(f,n);let frames=0,firstFrontier=null,slices=0;
 for(;frames<600&&!n._route?.length;frames++){
  f.frame();if(!n._empireRouteQueued&&f.now>=(n._empireRouteRetryAt||0))request(f,n);
  f.b._processEmpireRoutePlanQueue(f.now);
  if(n._npcDirectedSearch){slices++;if(firstFrontier)assert.equal(n._npcDirectedSearch,firstFrontier,'same physical frontier retained');else firstFrontier=n._npcDirectedSearch;}
 }
 return {f,n,frames,slices,elapsed:f.now-started};
}
const before=run(old),after=run(production);
assert(after.n._route?.length,'real native planner completes through queue');assert(after.elapsed<before.elapsed/3,'pending slices do not wait four seconds');assert(after.slices>1);assert.equal(after.f.counters()[5],0,'normal yields are not unreachable EMPTY results');
// Coalescing and same-frame protection, with the actual native planner.
const f=setup(),a=actor('first'),b=actor('second');request(f,a);request(f,a,22.5,22.5);request(f,b);assert.equal(f.queue().length,2);
f.frame();f.b._processEmpireRoutePlanQueue(f.now);assert(a._routeSearchPending);const retained=a._empirePendingRoute;assert.equal(retained.goalR,22.5);assert.equal(f.queue().filter(n=>n===a).length,1);
f.b._processEmpireRoutePlanQueue(f.now);const calls=f.calls;f.b._processEmpireRoutePlanQueue(f.now);assert.equal(f.calls,calls,'same source frame cannot execute another slice for first boss');assert.equal(f.queue().length,2);
f.frame();f.b._processEmpireRoutePlanQueue(f.now);assert.equal(b._empirePendingRoute?.generation,1);
// New generation/action and explicit cancellation cannot revive old jobs.
for(const mode of ['generation','action','cancel','dead','hidden','hp0']){
 const g=setup(),n=actor(mode);request(g,n);g.frame();g.b._processEmpireRoutePlanQueue(g.now);assert(n._routeSearchPending);const calls=g.calls;
 if(mode==='generation')n._empireRouteGeneration++;if(mode==='action')n._empireActionKey='inspect:different:2';if(mode==='cancel')n._empirePendingRoute=null;if(mode==='dead')n.dead=true;if(mode==='hidden')n._hiddenByEmpire=true;if(mode==='hp0')n.hp=0;
 g.frame();g.b._processEmpireRoutePlanQueue(g.now);assert.equal(g.calls,calls,mode+' never resumes stale work');assert.equal(g.queue().length,0);assert(!n._route?.length);
}
const empty=setup(),z=actor('unreachable');empty.b._empireBossWaypointPassable=()=>false;request(empty,z);empty.frame();const stamp=empty.now;empty.b._processEmpireRoutePlanQueue(stamp);assert.equal(z._empireRouteRetryAt,stamp+4000,'genuinely empty route retains failure backoff');assert.equal(empty.counters()[5],1);
// Bosses are pumped once per frame, while residents request every frame.
// A denied boss must not consume that entire pump and lose its shared queue
// lease before the next round-robin turn through the other bosses.
function mixedOwners(pump,long=false,oldLease=false){
 const f=setup(pump,oldLease),bosses=Array.from({length:19},(_,i)=>actor('boss_'+i));
 const residents=Array.from({length:180},(_,i)=>({id:'resident_'+i,grants:0}));
 for(const n of bosses)request(f,n,long?20.5:11.5,long?20.5:10.5);
 f.b.residents=residents;
 vm.runInContext('for(const n of residents)_npcRouteWorkQueue.set(n,0)',f.b);
 for(let frame=0;frame<900&&bosses.some(n=>!n._route?.length);frame++){
  f.frame();f.b._processEmpireRoutePlanQueue(f.now);
  for(const n of residents)if(f.b._npcReserveRouteWork(f.now,n)){n.grants++;f.b._npcFinishRouteWork();}
 }
 return {completed:bosses.filter(n=>n._route?.length).length,minResidentGrants:Math.min(...residents.map(n=>n.grants))};
}
const deniedStopsPump=production.replace("if(typeof _walkNpcNavigationResolver==='function'&&!_npcRouteWorkServed.has(npc))continue;",'');
const starved=mixedOwners(deniedStopsPump,false,true),fair=mixedOwners(production);
assert.equal(starved.completed,0,'reproduce boss starvation with busy residents');
assert.equal(fair.completed,19,'every boss completes under resident contention');
assert(fair.minResidentGrants>0,'residents retain service');
console.log({mixedOwners:{before:starved,after:fair}});
console.log(JSON.stringify({pass:true,realNativeQueue:{before:{frames:before.frames,pendingFrames:before.slices,elapsedMs:before.elapsed,completed:!!before.n._route?.length},after:{frames:after.frames,pendingFrames:after.slices,elapsedMs:after.elapsed,completed:true}},contracts:['coalesced newest request','same request/frontier across slices','no duplicate queue entry','one slice per actor/source frame','generation/action cancellation','dead/hidden/HP0 cancellation','real failure backoff'],limits:'Actual source queue and native BFS with controlled .1ms predicate cost, not actual geometry or scene FPS.'},null,2));

const longBefore=mixedOwners(production,true,true),longAfter=mixedOwners(production,true);assert.equal(longBefore.completed,0);assert.equal(longAfter.completed,19);assert(longAfter.minResidentGrants>0);console.log({longJobs:{before:longBefore,after:longAfter}});
