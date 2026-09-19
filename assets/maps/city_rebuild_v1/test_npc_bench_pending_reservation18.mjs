import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8').replace(/\r\n/g,'\n');
const agenda=fs.readFileSync(new URL('npc_activity_agenda_source.js',import.meta.url),'utf8');
const reservations=fs.readFileSync(new URL('npc_activity_reservations_source.js',import.meta.url),'utf8');
function sourceFunction(name){
  const start=world.indexOf('function '+name+'(');assert(start>=0,name);
  const lineEnd=world.indexOf('\n',start),line=world.slice(start,lineEnd);
  return line.trimEnd().endsWith('}')?line:world.slice(start,world.indexOf('\n}',start)+2);
}
const actualFunctions=['_civilianPlanUnit','_civilianPlanInterrupted','_civilianPlanCancel','_civilianPlanNext','_civilianPlanArrive'].map(sourceFunction).join('\n');
const lifeGuard=world.split('\n').find(line=>line.includes("if(n._civilianPlan?.phase==='rest'")&&line.includes('_npcAgenda.current'));
assert(lifeGuard,'actual lifeTick agenda guard must exist');
const make=id=>({id:'resident_'+id,hp:100,r:10,c:10,_civilianPlan:{phase:'walk_to_bench',cycle:0}});
function setup(){
  let now=1000,mode='pending',calls=0,cancels=0;
  const bench={id:'physical-bench',r:11,c:10,yaw:0,seatWorldY:.61};
  const b={Math,Number,Object,performance:{now:()=>now},_civilianPlanEligible:()=>true,
    _isRespawnableResident:()=>true,_walkRendererActive:()=>true,_walkNpcNavigationResolver:()=>({}),
    _civilianBenchReservations:new Map(),_civilianPlaces:{benches:[bench]},
    _clearNpcRoute(n){n._route=null;n._routeKind=null;},
    _cancelNpcDirectedSearch(n){cancels++;n._routeSearchPending=false;n._routeSearchKind=null;},
    _civilianRouteTo(n,r,c,kind){
      calls++;assert.equal(b._civilianBenchReservations.get(bench.id)?.id,n.id,'claim exists before resumable route starts');
      assert.equal(kind,'civilian_bench');assert.equal(r,bench.r+1.8/4.1);
      n._routeSearchPending=mode==='pending';n._routeSearchKind=n._routeSearchPending?kind:null;
      if(mode==='ready'){n._route=[{r,c}];n._routeKind=kind;return true;}return false;
    }};
  vm.createContext(b);vm.runInContext(agenda+'\n'+actualFunctions,b);
  return {b,bench,get calls(){return calls;},get cancels(){return cancels;},time(t){now=t;},mode(m){mode=m;}};
}

{
  const f=setup(),{b}=f,a=make('first'),other=make('second');
  assert.equal(b._civilianPlanNext(a,1000),false);assert(a._routeSearchPending);assert.equal(f.calls,1);
  assert.equal(b._civilianPlanNext(other,1000),false);assert.equal(f.calls,1,'second NPC cannot queue the same seat');
  assert.equal(b._civilianBenchReservations.size,1);assert.equal(a._civilianPlan.benchAttemptAt,1000);
  f.mode('failed');assert.equal(b._civilianPlanNext(a,1200),false);
  assert.equal(b._civilianBenchReservations.size,0,'definitive route failure releases claim');
  assert.equal(a._civilianPlan.benchId,null);assert(a._civilianPlan._failedBenches['physical-bench']>1200);
  f.mode('pending');assert.equal(b._civilianPlanNext(other,6001),false);assert(other._routeSearchPending);
  other.panicUntil=9000;assert(b._civilianPlanInterrupted(other,6001));b._civilianPlanCancel(other);
  assert.equal(b._civilianBenchReservations.size,0,'interruption releases pending claim');assert(!other._routeSearchPending);assert.equal(f.cancels,1);
}
{
  const f=setup(),{b}=f,n=make('timeout');b._civilianPlanNext(n,1000);
  b._civilianPlanNext(n,30000);assert.equal(n._civilianPlan.benchAttemptAt,1000,'retry cannot renew attempt age');
  const calls=f.calls;b._civilianPlanNext(n,46000);
  assert.equal(f.calls,calls,'exhausted pending route is not retried');assert.equal(b._civilianBenchReservations.size,0);
  assert(!n._routeSearchPending);assert.equal(n._civilianPlan.benchId,null);assert(n._civilianPlan._failedBenches['physical-bench']>46000);
}
{
  const f=setup(),{b}=f,n=make('walker');f.mode('ready');assert(b._civilianPlanNext(n,1000));
  const path=n._route;assert(b._civilianPlanNext(n,90000));assert.equal(n._route,path,'long actual walking is not pending-search timeout');
  const a=b._npcAgendaEnsure(n);a.index=a.queue.indexOf('bench');a.current='bench';a.started=true;
  n.r=n._civilianPlan.targetR;n.c=n._civilianPlan.targetC;assert(b._civilianPlanArrive(n,90000));
  assert.equal(n._civilianPlan.phase,'rest');assert(n._civilianSeat);
  b._civilianPlanNext(n,n._civilianPlan.until+1);
  assert.equal(n._npcAgenda.current,'walk','real rest completion advances agenda');assert.equal(n._civilianSeat,null);assert.equal(b._civilianBenchReservations.size,0);
  // Execute the actual production lifeTick guard, including legacy compatibility.
  let calls=0;b._civilianPlanNext=()=>calls++;b.n=n;b.now=100000;
  n._civilianPlan.phase='walk_to_bench';vm.runInContext(lifeGuard,b);assert.equal(calls,0,'stale phase must not steal the next walk');
  n._npcAgenda.current='bench';vm.runInContext(lifeGuard,b);assert.equal(calls,1);
  n._routeKind='civilian_bench';vm.runInContext(lifeGuard,b);assert.equal(calls,1,'ready bench route must not be replanned');
  n._routeKind=null;delete n._npcAgenda;vm.runInContext(lifeGuard,b);assert.equal(calls,2,'legacy actors retain bench lifecycle');
  n._npcAgenda={current:'walk'};n._civilianPlan.phase='rest';vm.runInContext(lifeGuard,b);assert.equal(calls,3,'existing rest still receives cleanup');
}
{
  const {b}=setup();vm.runInContext(reservations,b);
  const pending=make('pending-shop');pending._civilianPlan.phase='seek_shop';
  assert(b._npcActivityReserveBuilding(pending,'native:shop',{now:1000}));
  const plan=pending._civilianPlan;b._civilianPlanCancel(pending);
  assert.equal(pending._civilianPlan,plan,'exercise actual early-return seek_shop branch');
  assert.equal(b._npcActivityBuildingReservation(pending),null,'pending building reservation releases before early return');
  const inside=make('inside-shop');inside._civilianPlan.phase='seek_shop';
  const visit=inside._residentNativeVisit={doorId:'native:shop',phase:'browsing'};
  assert(b._npcActivityEnterBuilding(inside,'native:shop',{now:1000}));
  b._civilianPlanCancel(inside);
  assert.equal(b._npcActivityBuildingReservation(inside)?.phase,'inside','occupied capacity survives pending-only cancellation');
  assert.equal(inside._residentNativeVisit,visit,'physical visit ownership is preserved');
}
console.log(JSON.stringify({pass:true,checks:['source claim before pending route','exclusive seat while pending','definitive failure release','interruption release','45-second pending exhaustion','ready route survives timeout','actual bench completion advances agenda','actual lifeTick stale-phase guard','seek_shop early-return releases reserved slot','inside visit preserves occupied slot'],limits:'CPU source lifecycle regression; route boundary is stubbed. Whole-city frame rate and visual animation are not measured.'}));
