import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';

const f=await createCivilianNativeFixture({assetId:'print_shop'}),b=f.box;
for(const name of ['_npcLifeEligible','_isRespawnableResident'])vm.runInContext(sourceFunction(f.source,name),b);
const realDoor=b._residentBuildingDoors()[0],report=[];
b.Math=Object.create(Math);
for(const arc of ['worker','bandit']){
 const n={id:'resident_'+arc,r:4.990913843951179,c:97.94314630350254,alive:true,hp:60,_arcKey:arc,_npcRoutine:'errands'};
 // This case checks a committed planned visit, separately from offer scheduling.
 if(arc==='worker')n._civilianPlan={phase:'walk_to_shop',cycle:0,doorId:realDoor.id};
 let calls=0,done=false;
 b.Math.random=()=>calls<2?0:.999;
 while(!done&&calls<180){
  f.nextFrame();let checks=0;b._npcRouteWorkExpired=()=>++checks>6;
  // Once selected, random visit rolls and registry order must not replace it.
  b._residentBuildingDoors=()=>calls<2?[realDoor]:[{...realDoor,id:'different-entry',r:realDoor.r+.25},realDoor];
  done=b._maybePlanResidentBuildingVisit(n);calls++;
  if(n._routeSearchPending&&arc==='bandit')assert.equal(n._residentVisitTargetId,realDoor.id);
 }
 assert(done,arc+' reaches a route despite many sliced updates');
 assert(calls>1);assert.equal(n._routeSearchRestarts||0,0);
 assert.equal(n._residentDoor.id,realDoor.id);assert.equal(n._residentVisitTargetId,null);
 assert(Math.hypot(n._route.at(-1).r-realDoor.r,n._route.at(-1).c-realDoor.c)<.35);
 let from={r:n.r,c:n.c};
 for(const to of n._route){assert(b._npcPathPassable(from.r,from.c,to.r,to.c,arc==='worker'?b.npcPassableForSnitch:(r,c)=>b.npcWaypointOk(n,r,c)));from=to;}
 if(arc==='bandit'){
  assert(n._residentVisitPass.pass(realDoor.r,realDoor.c));n._beach=true;
  assert.equal(n._residentVisitPass.pass(realDoor.r,realDoor.c),false,'live actor policy stays dynamic');
 }
 report.push({arc,calls,restarts:n._routeSearchRestarts||0,pathPoints:n._route.length});b._cancelNpcDirectedSearch(n);
}
console.log(JSON.stringify({report,limits:'Actual print-shop geometry/source route; the second registry entry tests target retention, not a second physical building. CPU only.'},null,2));
