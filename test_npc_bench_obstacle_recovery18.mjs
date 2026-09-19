// Actual native car obstruction after an accepted bench route; no route-success stub.
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
import {stageNpcBenchApproach} from './test_npc_bench_candidate18.mjs';
const f=await createCivilianNativeFixture(),b=f.box;
const applied=sourceFunction(f.source,'_civilianRouteTo').includes('_civilianBenchPointPass');
const source=applied?f.source:stageNpcBenchApproach(f.source.replaceAll('\r\n','\n'));
vm.runInContext(source.slice(source.indexOf('// CIVILIAN_PURPOSEFUL_PLANS_START'),source.indexOf('// CIVILIAN_PURPOSEFUL_PLANS_END')),b);
vm.runInContext(sourceFunction(source,'_planNpcRouteTo'),b);
const p=f.snapshot.decorPlan.objects.find(p=>p.id==='explore-bench-2'),bench={id:p.id,r:p.z/f.M,c:p.x/f.M,yaw:p.yaw,seatWorldY:.61};
b._setWalkCivilianPlaces({benches:[bench]});
const n={id:'resident_bench_obstacle',r:163.5,c:41.5,tr:163.5,tc:41.5,hp:100,max_hp:100,speed:1,walkPhase:0,idleUntil:0,alive:true,_civilianPlan:{phase:'walk_to_bench',cycle:0}};f.npcs.push(n);
let accepted=false;
for(let i=0;i<50;i++){f.nextFrame(.1);if(b._civilianPlanNext(n,f.now)){accepted=true;break;}}
assert(accepted,'real bench route initially reachable');
const goal={r:n._civilianPlan.targetR,c:n._civilianPlan.targetC};
Object.assign(f.car,{r:goal.r,c:goal.c,ang:0});f.syncCar();f.pedestrian.beginFrame();
assert(!b._npcBodyPassable(goal.r,goal.c,b.npcPassable),'actual streamed car now occupies bench approach');
const begin=f.now;let blocks=0,repicks=0;
const step=b._npcRoutineStep;b._npcRoutineStep=(...args)=>{const ok=step(...args);if(!ok)blocks++;return ok;};
b.pickNpcWaypoint=n=>{repicks++;return b._civilianPlanNext(n,f.now);};
for(let i=0;i<1000&&!n._civilianPlan._failedBenches?.[bench.id];i++){f.nextFrame(.1);b.actualFootTick(n,.1,f.now);}
assert(n._civilianPlan._failedBenches?.[bench.id]>f.now,'new obstruction creates temporary blacklist rather than retrying same bench forever');
assert.equal(n._civilianPlan.benchId,null);
assert(blocks>0&&repicks>0,'ordinary movement encounters obstruction and owns recovery');
console.log(JSON.stringify({applied,accepted,blockedUpdates:blocks,repicks,blacklistAfterMs:f.now-begin,blacklistDurationMs:n._civilianPlan._failedBenches[bench.id]-f.now,final:{r:n.r,c:n.c},limit:'Actual source plan/movement/replan and actual compact-sedan collision. Only fallback after failure is omitted. No production modification or GPU.'}));
