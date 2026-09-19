import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const world=fs.readFileSync('world.html','utf8');
const fn=name=>{const start=world.indexOf('function '+name+'(');assert(start>=0,name);let p=world.indexOf('{',start),d=1;for(p++;d;p++){if(world[p]==='{')d++;if(world[p]==='}')d--;}return world.slice(start,p);};
function run(fullCadence,oldFirstSlice=false){
 let now=1000;const NPCS=[],n={id:'distant-first-wander',r:80.5,c:80.5,tr:80.5,tc:80.5,walkPhase:0,idleUntil:0};NPCS.push(n);
 const b={Math,Number,Map,Set,NPCS,MAP_ROWS:180,MAP_COLS:180,player:{r:1,c:1},performance:{now:()=>now},prevT:0,_walkRendererActive:()=>true,_walkNpcNavigationResolver:()=>({blocked:false,depth:0}),npcWaypointOk:()=>true,_civilianPlanNext:()=>false,_maybePlanResidentBuildingVisit:()=>false};
 vm.createContext(b);vm.runInContext(world.slice(world.indexOf('let _npcRouteWorkFrame='),world.indexOf('function _planNpcRouteTo(')),b);vm.runInContext('const _npcSimulationStats={full:0,distant:0,deferred:0};',b);
 for(const name of ['_npcSimulationDelta','_clearNpcRoute','_setNpcRoute','pickNpcWaypoint']){
  let code=fn(name);
  if(oldFirstSlice&&name==='pickNpcWaypoint'){
   assert(code.includes('if(resolver)npc._npcWanderSearch=search;'));
   code=code.replace('if(resolver)npc._npcWanderSearch=search;','');
  }
  vm.runInContext(code,b);
 }
 // One admitted search slice stops immediately; we test acquiring the first
 // persistent frontier, not planner speed or a synthetic no-collision route.
 b._npcRouteWorkExpired=()=>true;
 const busy=Array.from({length:200},(_,i)=>({id:'already-pending-'+i,_routeSearchPending:true}));let attempted=0,admittedFrame=null,maxAdmissions=0,maxWorkMs=0;
 for(let frame=1;frame<=1200;frame++){
  now=1000+frame*1000/60;b.prevT=frame;
  for(const owner of busy)if(b._npcReserveRouteWork(now,owner)){now+=.5;b._npcFinishRouteWork();}
  const stats=vm.runInContext('({count:_npcRouteWorkCount,used:_npcRouteWorkUsedMs})',b);
  maxAdmissions=Math.max(maxAdmissions,stats.count);maxWorkMs=Math.max(maxWorkMs,stats.used);
  assert(stats.count<=8&&stats.used<=4+1e-9,'background work respects max 8 admissions and actual 4 ms budget');
  const dt=fullCadence?1/60:b._npcSimulationDelta(n,1/60,now);
  if(dt){attempted++;b.pickNpcWaypoint(n);}
  if(Number.isFinite(n._routeQueueAdmittedAt)){admittedFrame=frame;break;}
 }
 return{attempted,admittedFrame,maxAdmissions,maxWorkMs,simulatedSeconds:(admittedFrame||1200)/60,pending:!!n._routeSearchPending,frontier:!!n._npcWanderSearch,queueContains:vm.runInContext('_npcRouteWorkQueue.has(NPCS[0])',b)};
}
const before=run(false,true),actual=run(false),fullCadenceControl=run(true);console.log(JSON.stringify({before,actual,fullCadenceControl,scenario:'200 existing persistent jobs; first distant wander admission using actual queue, cadence and pickNpcWaypoint'},null,2));
assert.equal(before.admittedFrame,null,'reproduce perpetual eviction before the first admitted slice');
assert(fullCadenceControl.admittedFrame,'control same queue admits continuously polled owner');
assert(actual.admittedFrame,'first distant wander request must not expire before its next 250ms cadence');
assert(actual.admittedFrame<=fullCadenceControl.admittedFrame+15,'initial far cadence adds at most one 250ms wait, not repeated queue expiry');
