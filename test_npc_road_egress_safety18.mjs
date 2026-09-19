import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
import {stageNpcRoadEgress} from './test_npc_road_egress_candidate18.mjs';
import {sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
const world=stageNpcRoadEgress(fs.readFileSync('world.html','utf8')),helper=fs.readFileSync('assets/maps/city_rebuild_v1/npc_road_egress_source.js','utf8');
function fixture(mode='open',position={r:10.1,c:10.1}){
 let clock=1000,frame=0,blocked=false,calls=0;
 const query=q=>{clock+=.03;calls++;if(q.mode==='sweep')return{swept:true,blocked:blocked};const land=q.c>=10.8;return{surface:land?'land':'road',blocked:q.r<1||q.c<1||q.r>30||q.c>30||blocked&&land,depth:mode==='water'&&land?1:0};};
 const b={Math,Number,Map,Set,MAP_COLS:100,performance:{now:()=>clock},prevT:0,_walkNpcNavigationResolver:query};
 b.npcPassableForSnitch=(r,c)=>{const hit=b._walkNpcNavigationResolver({r,c});return !hit.blocked&&hit.depth<=.025;};b.npcPassable=b.npcPassableForSnitch;
 b.npcWaypointOk=(n,r,c)=>{const hit=b._walkNpcNavigationResolver({r,c});return hit.surface==='land'&&!hit.blocked&&hit.depth<=.025;};
 b._npcRouteWalkBlocked=(r,c)=>!b.npcPassableForSnitch(r,c);
 vm.createContext(b);vm.runInContext(world.slice(world.indexOf('let _npcRouteWorkFrame='),world.indexOf('function _planNpcRouteTo(')),b);
 for(const name of ['_clearNpcRoute','_setNpcRoute','_npcBodyPassable','_npcPathPassable','_planNpcRouteTo','_civilianPlanInterrupted','_isRespawnableResident'])vm.runInContext(sourceFunction(world,name),b);
 vm.runInContext(fs.readFileSync('assets/maps/city_rebuild_v1/npc_native_directed_route_source.js','utf8')+'\n'+helper,b);
 const plan={phase:'seek_shop',cycle:3,retryAt:5000},n={id:'resident_egress_test',...position,tr:position.r,tc:position.c,hp:100,_civilianPlan:plan},costs=[];
 return{b,n,plan,costs,block(v){blocked=v;},get calls(){return calls;},tick(){clock=1000+(++frame)*50;b.prevT=clock;const start=clock,result=b._npcPlanRoadExit(n,clock);costs.push(clock-start);assert.equal(n.r,position.r);assert.equal(n.c,position.c);assert.equal(n._civilianPlan,plan,'egress never replaces civilian intent');return result;}};
}
const report={};
for(const mode of ['open','water','blocked-land']){
 const f=fixture(mode);if(mode==='blocked-land')f.block(true);let ready=false,slices=0,retained;
 do{ready=f.tick();retained??=f.n._npcRoadExit;assert.equal(f.n._npcRoadExit,retained);slices++;}while(f.n._routeSearchPending&&slices<200);
 if(mode==='open'){assert(ready);assert.equal(f.n._routeKind,'civilian_road_exit');assert(f.b._npcBodyPassable(f.n._route.at(-1).r,f.n._route.at(-1).c,(r,c)=>f.b.npcWaypointOk(f.n,r,c)));}
 else{assert(!ready);assert(!f.n._route?.length);assert.equal(f.n._roadExitStatus,'no-clear-land');}
 assert(slices<200);assert(Math.max(...f.costs)<6,'shared4ms plus one atomic body/edge probe is bounded');report[mode]={slices,queryCalls:f.calls,maxSliceMs:Math.max(...f.costs),ready};
}
{
 const f=fixture(),original=f.b._planNpcRouteTo;let changed=false;
 f.b._planNpcRouteTo=(...args)=>{const ready=original(...args);if(ready){changed=true;f.block(true);}return ready;};let slices=0,ready=false;
 do{ready=f.tick();slices++;}while(!changed&&f.n._routeSearchPending&&slices<100);
 assert(changed,'dynamic obstacle is injected after a real complete path');assert(!ready);assert(!f.n._route?.length,'new car at landing cannot leave a published route');assert.equal(f.n._npcRoadExit.goal,null);report.dynamicLanding={slices,rejected:true};
}
for(const kind of ['ready-building','pending-building']){
 const f=fixture();f.plan.doorId='native:shop';f.plan.phase='walk_to_shop';
 if(kind==='ready-building'){f.n._route=[{r:15,c:15}];f.n._routeKind='building_entry';}else{f.n._routeSearchPending=true;f.n._routeSearchKind='building_entry';f.n._npcDirectedSearch={key:'retained'};}
 const before=JSON.stringify(f.n);assert.equal(f.tick(),null);assert.equal(JSON.stringify(f.n),before,'existing journey wins '+kind);
}
{
 const f=fixture('open',{r:10.1,c:10.9});assert.equal(f.b._walkNpcNavigationResolver(f.n).surface,'land');assert.equal(f.b._walkNpcNavigationResolver({r:f.n.r,c:f.n.c-.18}).surface,'road');
 let ready=false;for(let i=0;i<100&&!ready;i++)ready=f.tick();assert(ready,'a land centre with road under body corners still requires egress');assert.equal(f.n._routeKind,'civilian_road_exit');report.footprintStraddle=true;
}
for(const id of ['merc_resident_dismissed','world_person_42']){const f=fixture();f.n.id=id;assert.notEqual(f.tick(),null,'existing civilian identity can exit road '+id);}
for(const field of ['_guard','_empireBoss','_empireCrew','_uniqueNpc','_medicalCrewVehicleId','police','_ambientTrafficDriver','_npcInitialPlacementPending']){const f=fixture();f.n[field]=true;assert.equal(f.tick(),null,'special owner preserved '+field);assert(!f.n._npcRoadExit);}
// Ready road exit is the only ordinary route that gains road traversal. The
// stage does not relax the default civilian pass or the physical sweep.
assert(world.includes("n._routeKind==='civilian_road_exit'||n._residentDoor?.native&&n._routeKind==='building_entry'"));
assert(world.includes("if(n._routeKind==='civilian_road_exit')return .001"));
console.log(JSON.stringify({pass:true,report,scope:'CPU actual shared queue/native planner/body/path with controlled native surface and dynamic occupancy; no GPU or full-scene FPS'},null,2));
