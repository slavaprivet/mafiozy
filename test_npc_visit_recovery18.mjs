import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
import {stageResidentVisitRecovery,residentVisitRecoveryHelpers} from './test_npc_visit_recovery_candidate18.mjs';
const reports=[];
const applied=fs.readFileSync('world.html','utf8').includes('function _residentNativeRecoveryTick(');
for(const candidate of [false,true]){
 const f=await createCivilianNativeFixture(),b=f.box,source=candidate&&!applied?stageResidentVisitRecovery(f.source):f.source;
 if(candidate&&!applied)vm.runInContext(residentVisitRecoveryHelpers,b);
 let tick=sourceFunction(source,'_residentNativeVisitTick');
 if(!candidate&&applied){
  const start=tick.indexOf('  if(!access?.ready){'),end=tick.indexOf('}else visit.accessWaitAt=null;',start);
  assert(start>=0&&end>start,'recover historical unavailable-door baseline without changing production');
  tick=tick.slice(0,start)+"  if(!access?.ready){n._residentVisitStatus='waiting-for-door';n.walking=false;return true;}"+tick.slice(end+'}else visit.accessWaitAt=null;'.length);
 }
 vm.runInContext(tick,b);
 const door=b._residentBuildingDoors()[0],n={id:'resident_visit_wait18',r:door.r,c:door.c,tr:door.r,tc:door.c,hp:100,speed:1,walkPhase:0,idleUntil:0,_civilianPlan:{phase:'entering',cycle:0},_residentNativeVisit:{phase:'entering',door,since:0,blockedAt:0}};
 f.npcs.push(n);const raw=b.nativeTrafficQuery;
 b.nativeTrafficQuery=q=>q.mode==='resident-access'&&q.action==='open'?{ready:false,reason:'entry-not-loaded'}:raw(q);
 vm.runInContext('_walkTrafficNavigationResolver=nativeTrafficQuery;',b);
 for(let i=0;i<120;i++){f.nextFrame(.05);b._residentNativeVisitTick(n,.05,f.now);}
 assert.equal(n.r,door.r);assert.equal(n.c,door.c);assert.equal(!!n._residentNativeVisit,!candidate);
 reports.push({candidate,case:'unloaded-door-at-outside',afterMs:f.now,owned:!!n._residentNativeVisit,status:n._residentVisitStatus});
}
// Current production planner with an analytical rectangular dynamic blocker.
// This fixture isolates recovery geometry; it does not claim whole city LIVE.
{
 const f=await createCivilianNativeFixture(),b=f.box,source=applied?f.source:stageResidentVisitRecovery(f.source);
 if(!applied)vm.runInContext(residentVisitRecoveryHelpers,b);vm.runInContext(sourceFunction(source,'_residentNativeVisitTick'),b);
 let blocked=true,allBlocked=false;
 const inside=(r,c)=>allBlocked||blocked&&r>10.05&&r<10.95&&c>10.05&&c<10.95;
 b.recoveryQuery=q=>{
  if(q.mode==='sweep'){
   const count=Math.ceil(Math.hypot(q.to.r-q.from.r,q.to.c-q.from.c)/.015)||1;
   for(let i=0;i<=count;i++){const t=i/count,r=q.from.r+(q.to.r-q.from.r)*t,c=q.from.c+(q.to.c-q.from.c)*t;if(inside(r,c)||inside(r-.18,c-.18)||inside(r-.18,c+.18)||inside(r+.18,c-.18)||inside(r+.18,c+.18))return {swept:true,blocked:true};}
   return {swept:true,blocked:false};
  }
  return {blocked:inside(q.r,q.c),depth:0,surface:'land'};
 };
 b.nativeTrafficQuery=q=>({ready:true});vm.runInContext('_walkNpcNavigationResolver=recoveryQuery;_walkTrafficNavigationResolver=nativeTrafficQuery;',b);
 const door={id:'recovery-room',r:10.5,c:8.5,inside:{r:10.5,c:12.5}};
 const make=()=>({id:'resident_exit18',r:10.5,c:12.5,tr:10.5,tc:12.5,hp:100,speed:1,walkPhase:0,idleUntil:0,_civilianPlan:{phase:'browsing',cycle:0},_residentNativeVisit:{phase:'exiting',door,since:0,blockedAt:0,returnPoint:{r:door.r,c:door.c}}});
 const n=make();f.npcs.push(n);let distance=0,maxStep=0;
 for(let i=0;i<1200&&n._residentNativeVisit;i++){
  f.nextFrame(.05);const r=n.r,c=n.c;b._residentNativeVisitTick(n,.05,f.now);const step=Math.hypot(n.r-r,n.c-c);distance+=step;maxStep=Math.max(step,maxStep);
  assert(step<=.4391*.05+1e-6,'bounded walking speed, no teleport');if(step)assert(b._residentNativeSegmentPassable(r,c,n.r,n.c),'every recovery segment respects body and sweep');
 }
 assert(!n._residentNativeVisit,'physically routes around a blocking object');assert(distance>4.2,'detour was used');reports.push({candidate:true,case:'blocked-direct-exit',distance,maxStep,status:n._residentVisitStatus});
 // A fully blocked volume cannot produce movement; reopening resumes recovery.
 blocked=false;allBlocked=true;const trapped=make();f.npcs.push(trapped);
 for(let i=0;i<100;i++){f.nextFrame(.05);b._residentNativeVisitTick(trapped,.05,f.now);}
 assert.equal(trapped.r,10.5);assert.equal(trapped.c,12.5);assert(trapped._residentNativeVisit);
 allBlocked=false;
 for(let i=0;i<600&&trapped._residentNativeVisit;i++){f.nextFrame(.05);b._residentNativeVisitTick(trapped,.05,f.now);}
 assert(!trapped._residentNativeVisit,'dynamic obstruction removed: recovery completes');
 // Losing the streamed adapter while physically inside must not permanently
 // block an otherwise collision-clear route back out of the same building.
 const unloaded=make();f.npcs.push(unloaded);b.nativeTrafficQuery=()=>({ready:false,reason:'entry-not-loaded'});vm.runInContext('_walkTrafficNavigationResolver=nativeTrafficQuery;',b);
 for(let i=0;i<600&&unloaded._residentNativeVisit;i++){f.nextFrame(.05);b._residentNativeVisitTick(unloaded,.05,f.now);}
 assert(!unloaded._residentNativeVisit);assert(Math.hypot(unloaded.r-door.r,unloaded.c-door.c)<=.10);assert.equal(unloaded._residentVisitStatus,'visit-unavailable');
 b.nativeTrafficQuery=()=>({ready:true});vm.runInContext('_walkTrafficNavigationResolver=nativeTrafficQuery;',b);
 // Pending recovery cannot steal a dead or downed actor from its owner.
 const dead=make();dead.dead=true;dead._residentNativeVisit.recovering=true;dead._routeSearchPending=true;f.nextFrame(.05);
 assert.equal(b._residentNativeVisitTick(dead,.05,f.now),false);assert(!dead._residentNativeVisit&&!dead._routeSearchPending);assert.equal(dead.c,12.5);
 const stunned=make();stunned._knockedUntil=f.now+1000;f.nextFrame(.05);assert.equal(b._residentNativeVisitTick(stunned,.05,f.now),false);assert.equal(stunned.c,12.5);
 // Invalid indoor target exits from the real outside point, not a guessed origin.
 const invalid=make();invalid.r=door.r;invalid.c=door.c;invalid._residentNativeVisit.phase='entering';invalid._residentNativeVisit.entryLaneChecked=true;invalid._residentNativeVisit.door={...door,inside:{r:NaN,c:2}};
 for(let i=0;i<4&&invalid._residentNativeVisit;i++){f.nextFrame(.05);b._residentNativeVisitTick(invalid,.05,f.now);}
 assert(!invalid._residentNativeVisit);assert.equal(invalid.r,door.r);assert.equal(invalid.c,door.c);
 const invalidExit=make();invalidExit._residentNativeVisit.recovering=true;invalidExit._residentNativeVisit.returnPoint={r:NaN,c:Infinity};
 f.nextFrame(.05);assert.equal(b._residentNativeVisitTick(invalidExit,.05,f.now),true);assert.equal(invalidExit._residentVisitStatus,'invalid-exit');assert.equal(invalidExit.r,10.5);assert.equal(invalidExit.c,12.5);
 reports.push({candidate:true,case:'dynamic-block-release/unloaded-inside/death/stun/invalid-target',pass:true});
}
console.log(JSON.stringify({applied,reports,limits:'Outside timeout uses current hospital fixture; detour/dynamic blocker cases use actual production planner with analytical obstacle geometry. Historical unavailable-door baseline is restored only inside VM. No GPU, LIVE or FPS measurement.'},null,2));
