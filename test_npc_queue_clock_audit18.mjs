// Admission-clock regression; historical baseline is recreated inside VM only.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source=fs.readFileSync('world.html','utf8').replace(/\r\n/g,'\n');
const fn=name=>{const start=source.indexOf('function '+name+'(');assert(start>=0);return source.slice(start,source.indexOf('\n}',start)+2);};
const queue=source.slice(source.indexOf('let _npcRouteWorkFrame='),source.indexOf('function _planNpcRouteTo('));
assert(queue.includes('  now=performance.now();'),'production admission uses a fresh clock');
const staleQueue=queue.replace('  now=performance.now();','');
const native=fs.readFileSync('assets/maps/city_rebuild_v1/npc_native_directed_route_source.js','utf8');
function fixture({freshClock=false,prepareMs=0}={}){
 let now=1000,checks=0;
 const box={Math,Number,Map,Set,Array,NPCS:[],MAP_COLS:200,performance:{now:()=>now},prevT:1,
  _walkNpcNavigationResolver:()=>({swept:true,blocked:false}),
  _civilianPlanNext:()=>false,_maybePlanResidentBuildingVisit:()=>{now+=prepareMs;return false;}};
 box.npcPassable=box.npcWaypointOk=()=>{checks++;now+=.02;return true;};
 box._npcPathPassable=(fr,fc,r,c,pass)=>pass(r,c);
 vm.createContext(box);
 vm.runInContext(freshClock?queue:staleQueue,box);
 for(const name of ['_clearNpcRoute','_setNpcRoute','_planNpcRouteTo','pickNpcWaypoint'])vm.runInContext(fn(name),box);
 vm.runInContext(native,box);
 return {box,advance:ms=>now+=ms,frame:i=>{now=1000+i*200;box.prevT=i;},get now(){return now},get checks(){return checks}};
}
function initialWander(freshClock){
 const f=fixture({freshClock,prepareMs:6}),n={id:'resident_clock',r:10.5,c:10.5,hp:60};f.box.NPCS.push(n);
 const before=f.now;f.box.pickNpcWaypoint(n);
 return{expanded:n._npcWanderSearch?.qi||0,admittedAt:n._routeQueueAdmittedAt,actualPreparationDoneAt:before+6,queryChecks:f.checks,elapsedMs:f.now-before};
}
const stale=initialWander(false),fresh=initialWander(true);
assert.equal(stale.expanded,0,'stale pre-plan timestamp admits an already-expired wander slice');
assert(fresh.expanded>0,'fresh reservation timestamp gives the real search its unchanged 4 ms window');
assert(fresh.elapsedMs<10.3,'6 ms pre-planning plus existing 4 ms slice and bounded atomic edge overrun');

// A caller which omits its completion still consumes the interval conservatively.
// Real production callers now close their slice: test_npc_route_cpu_budget18.mjs.
const gap=fixture({freshClock:true}),a={id:'first'},b={id:'second'};
assert(gap.box._npcReserveRouteWork(gap.now,a));gap.advance(.25);const actualSearchCpu=.25;gap.advance(5);
const secondAdmitted=gap.box._npcReserveRouteWork(gap.now,b);
assert.equal(secondAdmitted,false);

// Actual current native planner and FIFO with deterministic query cost. This
// isolates queue throughput from geometry and rendering, not a LIVE benchmark.
function throughput(fps){
 const f=fixture({freshClock:true}),actors=Array.from({length:233},(_,i)=>({id:'resident_'+i,r:10.5,c:10.5}));
 let completed=0,frames=0,firstFinished=null;const finish=[];
 for(;frames<15000&&completed<actors.length;frames++){
  f.frame(frames); // Budget clock is monotonic per simulation frame.
  for(const n of actors){if(n.done)continue;n.done=f.box._planNpcRouteTo(n,20.5,20.5,f.box.npcPassable,.1,1200,'building_entry');if(n.done){completed++;finish.push((frames+1)/fps);firstFinished??=(frames+1)/fps;}}
 }
 assert.equal(completed,233);assert(actors.every(n=>n._route?.at(-1).r===20.5&&n._route.at(-1).c===20.5));
 return{fps,frames,completed,firstFinishedSeconds:firstFinished,p95Seconds:finish[Math.floor(finish.length*.95)],lastSeconds:finish.at(-1),checks:f.checks};
}
const rates=[60,20,5].map(throughput);
assert(rates.every(r=>r.frames===rates[0].frames),'render cadence does not increase route throughput per source frame');
console.log(JSON.stringify({staleWander:stale,freshClockProduction:fresh,wallClockGap:{actualSearchCpu,nonRouteGapMs:5,secondAdmitted},rates,limits:'Current queue and planner source versus historical stale-clock VM baseline; open synthetic land, 0.02 ms query cost. This tests admission and throughput, not actual geometry or LIVE FPS.'},null,2));
