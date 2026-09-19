// Read-only production audit. Actual source visit gate + actual GLB/native
// access, without competing route searches or GPU rendering.
import assert from 'node:assert/strict';
import {createCivilianNativeFixture} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
const reports=[];
for(const assetId of ['hospital','print_shop','pawnshop','gun_shop','old_town_narrow_townhouse_v1','eastside_garden_walkup_v1']){
 const f=await createCivilianNativeFixture({assetId}),b=f.box,door=b._residentBuildingDoors()[0];
 const n={id:'resident_visit_audit_'+assetId,r:door.r,c:door.c,tr:door.r,tc:door.c,hp:100,max_hp:100,speed:1,alive:true,walkPhase:0,_civilianPlan:{phase:'walk_to_shop',cycle:0,doorId:door.id}};
 f.npcs.push(n);assert(b._residentEnterBuilding(n,f.now,door));
 const states={},phases=new Set();let moved=0,finished=false;
 for(let i=0;i<1200;i++){
  const old={r:n.r,c:n.c};f.nextFrame(.05);b._residentNativeVisitTick(n,.05,f.now);
  moved+=Math.hypot(n.r-old.r,n.c-old.c)*f.M;
  phases.add(n._residentNativeVisit?.phase||'finished');states[n._residentVisitStatus]=(states[n._residentVisitStatus]||0)+1;
  if(!n._residentNativeVisit){finished=true;break;}
 }
 assert(finished,`${assetId}: visit did not complete: ${n._residentVisitStatus}`);
 assert(phases.has('entering')&&phases.has('browsing')&&phases.has('exiting'),`${assetId}: physical visit phases were skipped`);
 assert(moved>1,`${assetId}: visit must involve physical displacement`);
 reports.push({assetId,finished,movedM:+moved.toFixed(3),status:n._residentVisitStatus,phases:[...phases],states});
}
console.log(JSON.stringify({reports,limit:'CPU actual six GLBs, source native visit and physical access. No route-queue competition, GPU or LIVE prevalence.'},null,2));
