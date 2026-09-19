import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
import {stageStableNonplanPass} from './test_npc_native_fast_path18_nonplan_candidate.mjs';
const f=await createCivilianNativeFixture({assetId:'print_shop'}),b=f.box,original=sourceFunction(f.source,'_maybePlanResidentBuildingVisit'),patched=sourceFunction(stageStableNonplanPass(f.source),'_maybePlanResidentBuildingVisit'),reports=[];
for(const name of ['_npcLifeEligible','_isRespawnableResident'])vm.runInContext(sourceFunction(f.source,name),b);
b.Math=Object.create(Math);b.Math.random=()=>0;
for(const [label,code]of [['before',original],['after',patched]])for(const arc of ['worker','bandit']){
 vm.runInContext(code,b);const n={id:'resident_'+arc,r:4.990913843951179,c:97.94314630350254,alive:true,hp:60,_arcKey:arc,_npcRoutine:'errands'},initial={r:n.r,c:n.c};
 let done=false,calls=0,cpu=0;
 while(!done&&calls<180){f.nextFrame();let checks=0;b._npcRouteWorkExpired=()=>++checks>6;const start=performance.now();done=b._maybePlanResidentBuildingVisit(n);cpu+=performance.now()-start;calls++;}
 const door=b._residentBuildingDoors()[0];reports.push({label,arc,done,calls,cpuMs:cpu,restarts:n._routeSearchRestarts||0,frontierExpanded:n._npcDirectedSearch?.qi,routeLength:n._route?.length,goalDistance:n._route?.length?Math.hypot(n._route.at(-1).r-door.r,n._route.at(-1).c-door.c):null});
 assert.equal(done,label==='after'||arc==='worker');if(done){assert(calls>1,'test requires actual sliced continuation');assert.equal(n._routeSearchRestarts||0,0);let from=initial;for(const to of n._route){assert(b._npcPathPassable(from.r,from.c,to.r,to.c,arc==='worker'?b.npcPassableForSnitch:(r,c)=>b.npcWaypointOk(n,r,c)),'same dynamic movement rules stay valid');from=to;}assert(Math.hypot(from.r-door.r,from.c-door.c)<.35);}
 if(label==='after'&&arc==='bandit'){
  const stable=n._residentVisitPass.pass;assert(stable(door.r,door.c));n._beach=true;assert.equal(stable(door.r,door.c),false,'cached callback observes changed actor policy');n._beach=false;
 }
 b._cancelNpcDirectedSearch(n);
}
console.log(JSON.stringify({reports,limits:'CPU actual source one real shop/one deterministic chosen door; budget uses six checks to force resumability; no LIVE or FPS.'},null,2));
fs.writeFileSync('outputs/npc_nonplan_pass_candidate18.json',JSON.stringify(reports,null,2));
