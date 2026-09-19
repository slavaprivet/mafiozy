import vm from 'node:vm';
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
import {stageNpcBenchApproach} from './test_npc_bench_candidate18.mjs';
const f=await createCivilianNativeFixture(),b=f.box,reports=[];
const applied=sourceFunction(f.source,'_civilianRouteTo').includes('_civilianBenchPointPass');
const candidate=!applied&&process.argv.includes('--clearance'),fixed=applied||candidate,distance=fixed?1.8:.6,source=candidate?stageNpcBenchApproach(f.source.replaceAll('\r\n','\n')):f.source;
vm.runInContext(source.slice(source.indexOf('// CIVILIAN_PURPOSEFUL_PLANS_START'),source.indexOf('// CIVILIAN_PURPOSEFUL_PLANS_END')),b);
if(candidate)vm.runInContext(sourceFunction(source,'_planNpcRouteTo'),b);
const benches=f.snapshot.decorPlan.objects.filter(p=>p.kind==='bench').map(p=>({id:p.id,r:p.z/f.M,c:p.x/f.M,yaw:p.yaw||0,seatWorldY:p.y+.61*(p.scale||1)}));
for(const bench of benches){
 const target={r:bench.r+Math.cos(bench.yaw)*(distance/f.M),c:bench.c+Math.sin(bench.yaw)*(distance/f.M)};
 const n={id:'resident_bench_'+bench.id,hp:100,max_hp:100,speed:1,walkPhase:0,idleUntil:0,alive:true,_civilianPlan:{phase:'walk_to_bench',cycle:0}};
 let start=null;
 for(const [dr,dc]of [[-3,0],[3,0],[0,-3],[0,3],[-2,-2],[2,2]]){const p={r:Math.floor(target.r+dr)+.5,c:Math.floor(target.c+dc)+.5};if(b.npcWaypointOk(n,p.r,p.c)&&b._npcBodyPassable(p.r,p.c,(r,c)=>b.npcWaypointOk(n,r,c))){start=p;break;}}
 if(!start)continue;Object.assign(n,start,{tr:start.r,tc:start.c});f.npcs.push(n);b._setWalkCivilianPlaces({benches:[bench]});
 let ok=false,calls=0,cpuMs=0;
 for(;calls<80;calls++){f.nextFrame(.1);const at=performance.now();ok=b._civilianPlanNext(n,f.now);cpuMs+=performance.now()-at;if(ok||!n._routeSearchPending)break;}
 let blocked=null,from=start;
 for(const [i,p]of (n._route||[]).entries()){if(!b._npcPathPassable(from.r,from.c,p.r,p.c,b.npcPassable)){blocked={i,from,to:p};break;}from=p;}
 let sat=false,released=false;
 if(ok&&!blocked){
  for(let frame=0;frame<1200;frame++){
   f.nextFrame(.05);
   if(n._civilianPlan.phase==='rest'){sat=true;b._civilianPlanNext(n,f.now);if(!n._civilianSeat){released=true;break;}}
   b.actualFootTick(n,.05,f.now);
  }
 }
 reports.push({bench:bench.id,start,target,eligible:b._civilianPlanEligible(n),plan:n._civilianPlan,targetHit:f.pedestrian.query(target),targetBodyPass:b._npcBodyPassable(target.r,target.c,b.npcPassable),ok,calls: calls+1,cpuMs,blocked,routeLength:n._route?.length||0,pending:n._routeSearchPending,sat,released});f.npcs.splice(f.npcs.indexOf(n),1);
}
fs.writeFileSync('outputs/npc_bench_physical_audit18'+(applied?'_applied':candidate?'_clearance':'')+'.json',JSON.stringify(reports,null,2));
if(fixed){assert(reports.filter(r=>r.ok).length>=20,'actual benches remain reachable');assert(reports.every(r=>!r.ok||!r.blocked&&r.sat&&r.released),'accepted paths clear every edge and complete sit/release');assert(!reports.some(r=>r.pending),'bounded bench requests terminate');}
console.log(JSON.stringify({applied,candidate,benches:benches.length,tested:reports.length,blockedTarget:reports.filter(r=>!r.targetBodyPass).length,ready:reports.filter(r=>r.ok).length,invalidReady:reports.filter(r=>r.ok&&r.blocked),pending:reports.filter(r=>r.pending).length,sat:reports.filter(r=>r.sat).length,released:reports.filter(r=>r.released).length,routeCpuMs:reports.reduce((s,r)=>s+r.cpuMs,0),maxRouteCpuMs:Math.max(...reports.map(r=>r.cpuMs)),example:reports[0],limit:'CPU actual snapshot/native obstacles and ordinary source foot cycle; no other streamed vehicles/GPU or full-scene FPS. Fixed front approach plus existing interpolated visual seating needs LIVE review.'},null,2));
