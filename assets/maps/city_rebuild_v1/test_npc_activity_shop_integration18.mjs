import vm from 'node:vm';
import assert from 'node:assert/strict';
import {createCivilianNativeFixture,sourceFunction} from './test_civilian_native_fixture.mjs';

const f=await createCivilianNativeFixture({assetId:'print_shop'}),b=f.box,door=b._residentBuildingDoors()[0];
vm.runInContext(f.source.slice(f.source.indexOf('// CIVILIAN_PURPOSEFUL_PLANS_START'),f.source.indexOf('// CIVILIAN_PURPOSEFUL_PLANS_END')),b);
vm.runInContext(sourceFunction(f.source,'pickNpcWaypoint'),b);
assert.equal(typeof b._npcActivityClaimDoor,'function','actual canonical-door adapter loaded');
assert.equal(typeof b._npcAgendaPick,'function');
assert(door.native&&door.inside&&door.assetId==='print_shop');
const dr=door.r-door.inside.r,dc=door.c-door.inside.c,len=Math.hypot(dr,dc),start={r:door.r+dr/len*.65,c:door.c+dc/len*.65};
assert(b._npcPathPassable(start.r,start.c,door.r,door.c,b.npcPassableForSnitch));
assert(!b._residentNativeSegmentPassable(door.r,door.c,door.inside.r,door.inside.c),'closed authored door blocks initial entry');
const make=i=>({id:'resident_slot_shop_'+i,...start,tr:start.r,tc:start.c,hp:60,max_hp:60,speed:1,alive:true,walkPhase:0,idleUntil:0,_arcKey:'worker',_npcRoutine:'errands',_civilianPlan:{phase:'seek_shop',cycle:0,doorId:door.id},_npcAgenda:{queue:['shop','walk','bench','walk'],index:0,current:'shop',started:true,completed:0,lastResult:null}});
const visitors=Array.from({length:15},(_,i)=>make(i)),extra=make(15);f.npcs.push(...visitors,extra);
const key=b._npcActivityDoorKey(door);assert(key);
const balances=new Map(visitors.map(n=>[n,b._residentCommerceAccount(n).balance]));
f.nextFrame(.05);
for(const n of visitors){b._maybePlanResidentBuildingVisit(n);assert(b._npcActivityBuildingReservation(n),'actual planner claims its destination before pending/ready route');}
assert.equal(b._npcActivityBuildingCount(key,{now:f.now}),15);
assert.equal(b._maybePlanResidentBuildingVisit(extra),false,'sixteenth visit refused by actual destination selection');
assert.equal(b._npcActivityBuildingReservation(extra),null);
assert.equal(extra._route?.length||0,0,'full interior does not publish an entry route');
assert.equal(b._npcAgendaPick(extra,f.now),'walk','finite agenda immediately chooses alternate walk after full destination');
assert.equal(extra._npcAgenda.current,'walk');
const finished=new Set(),paid=new Set(),inside=new Set(),phases=new Set();let movedExtra=0,maxStep=0,maxOwners=15,routeReadyAt=null;
for(let frame=0;frame<1800&&finished.size<15;frame++){
 f.nextFrame(.05);b._npcActivitySlotsTick(f.now);
 for(const n of f.npcs){
  if(finished.has(n))continue;
  const previous={r:n.r,c:n.c};
  if(!b._residentNativeVisitTick(n,.05,f.now))b.actualFootTick(n,.05,f.now);
  const step=Math.hypot(n.r-previous.r,n.c-previous.c)*f.M;maxStep=Math.max(maxStep,step);
  assert(step<=.083,'all movement is an actual source step, no visit teleport');
  if(n===extra){movedExtra+=step;if(n._route?.length&&routeReadyAt===null)routeReadyAt=f.now;assert(!n._residentNativeVisit);assert(!b._npcActivityBuildingReservation(n));continue;}
  const record=b._npcActivityBuildingReservation(n),visit=n._residentNativeVisit,wallet=b._residentCommerceAccount(n);
  if(visit){inside.add(n);assert.equal(record?.phase,'inside','entering/browsing/exiting all retain capacity');phases.add(visit.phase);}
  if(visit?.commerce)phases.add(visit.commerce.phase);
  if(wallet.receipts.length){
   assert.equal(wallet.receipts.length,1,'one purchase per visit');
   if(!paid.has(n)){assert(f.entry.containsInterior(new f.THREE.Vector3(n.c*f.M,f.floor(n.c*f.M,n.r*f.M),n.r*f.M)),'first payment physically inside authored GLB');paid.add(n);}
   assert.equal(balances.get(n)-wallet.balance,3);assert.equal(wallet.inventory.newspaper.quantity,1);
  }
  if(n._residentVisitStatus==='visit-complete'){assert.equal(record,null,'actual physical exit releases slot');assert.equal(n._npcAgenda.current,'walk','shopping completion advances agenda');finished.add(n);}
 }
 const count=b._npcActivityBuildingCount(key,{now:f.now});maxOwners=Math.max(maxOwners,count);assert(count<=15,'capacity never exceeded');
}
assert.equal(finished.size,15,'all real native visits finish');assert.equal(inside.size,15);assert.equal(paid.size,15);
assert.equal(b._npcActivityBuildingCount(key,{now:f.now}),0);
assert(movedExtra>1,'refused sixteenth visitor physically follows a real alternate route');assert(routeReadyAt!==null);
for(const phase of ['entering','browsing','browse','pay','complete','exiting'])assert(phases.has(phase),phase);
console.log(JSON.stringify({status:'PASS',door:door.id,visitors:15,finished:finished.size,paid:paid.size,maxOwners,remaining:0,maxStepM:maxStep,extraWalkMetres:movedExtra,extraRouteReadyAtMs:routeReadyAt,elapsedMs:f.now,phases:[...phases],limits:f.limits+' Capacity stress stages simultaneous visitors at the same clear approach; inter-NPC personal-space behavior is outside this test. No route-success/geometry stubs; existing authored door opens through real native access.'},null,2));
