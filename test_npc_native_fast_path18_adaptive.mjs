import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import {performance} from 'node:perf_hooks';
import {candidateSource} from './test_npc_native_fast_path18_candidate.mjs';
import {createCivilianNativeFixture} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
const served=fs.readFileSync('assets/maps/city_rebuild_v1/npc_native_directed_route_source.js','utf8'),fineGate="if(!goal&&!search.fine&&search.qi===1&&nodes.size===1&&maxVisited>2){";
const baseline=served.replace(fineGate,'if(false){'),after=served.includes(fineGate)?served:candidateSource;
const cases=[{assetId:'print_shop',r:4.990913843951179,c:97.94314630350254},{assetId:'hospital',r:6.469984627970292,c:165.137}];
const report=[];
for(const info of cases){
 const f=await createCivilianNativeFixture({assetId:info.assetId}),b=f.box,door=b._residentBuildingDoors()[0],record={assetId:info.assetId,start:{r:info.r,c:info.c},door:{r:door.r,c:door.c}};
 for(const [label,code]of [['before',baseline],['after',after]]){
  vm.runInContext(code,b);const n={r:info.r,c:info.c},pass=(r,c)=>b._npcBodyPassable(r,c,b.npcPassableForSnitch),costs=[];let ok=false,slices=0,firstSearch;
  do{
   f.nextFrame();const start=performance.now();b._npcRouteWorkExpired=()=>performance.now()-start>=1;
   n._routeSearchPending=false;ok=b._npcPlanNativeVisitRoute(n,door.r,door.c,pass,.8,1200,'building_entry');costs.push(performance.now()-start);slices++;
   if(n._routeSearchPending){firstSearch??=n._npcDirectedSearch;assert.equal(n._npcDirectedSearch,firstSearch,'frontier resumes without restart');}
  }while(n._routeSearchPending&&slices<100);
  assert.equal(!!n._routeSearchPending,false);assert.equal(ok,label==='after');assert.equal(n._routeSearchRestarts,undefined);
  if(ok){let from={r:info.r,c:info.c};for(const to of n._route){assert(b._npcPathPassable(from.r,from.c,to.r,to.c,b.npcPassableForSnitch),'actual body/sweep clear');from=to;}assert.deepEqual({...from},{r:door.r,c:door.c},'physical final door connection');}
  record[label]={ok,slices,totalCpuMs:costs.reduce((s,x)=>s+x,0),maxSliceMs:Math.max(...costs),expanded:n._routeSearchExpanded,visited:n._routeSearchVisited,path:n._route||[]};
  if(ok){
   Object.assign(n,{id:'resident_grid_'+info.assetId,hp:60,max_hp:60,speed:1,alive:true,walkPhase:0,_arcKey:'worker',_npcRoutine:'errands',_civilianPlan:{phase:'walk_to_shop',doorId:door.id,cycle:0}});
   let steps=0,distanceM=0,maxStepM=0;
   while(Math.hypot(n.r-door.r,n.c-door.c)>.08&&steps<1400){
    f.nextFrame(.05);const old={r:n.r,c:n.c};b.actualFootTick(n,.05,f.now);const delta=Math.hypot(n.r-old.r,n.c-old.c)*f.M;
    assert(delta<=.083,'production footsteps cannot teleport');assert(b._npcPathPassable(old.r,old.c,n.r,n.c,b.npcPassableForSnitch),'movement preserves collisions');distanceM+=delta;maxStepM=Math.max(maxStepM,delta);steps++;
   }
   assert(steps<1400,'actual foot update reaches entrance');record[label].movement={steps,distanceM,maxStepM,doorDistanceM:Math.hypot(n.r-door.r,n.c-door.c)*f.M};
  }
 }
 report.push(record);
}
// A fine fallback cannot cross a surrounding thin wall, water or a forbidden
// goal connector merely because the last grid node lies within goalRadius.
for(const reason of ['wall','water','goal-wall']){
 let expired=false;const pass=(r,c)=>reason==='wall'?r>0&&c>0&&r<10&&c<10:r>1.9&&r<2.4&&c>1.9&&c<(reason==='water'?2.4:4);
 const sweep=q=>({swept:true,blocked:reason==='water'?false:reason==='wall'?(Math.hypot(q.to.r-2.1,q.to.c-2.1)>.3):((q.from.c<2.75)!==(q.to.c<2.75))});
 const b={MAP_COLS:100,Math,Map,_walkNpcNavigationResolver:sweep,_npcRouteWorkExpired:()=>expired,_setNpcRoute:(n,p)=>{n._route=p;return p.length>0;}};vm.createContext(b);vm.runInContext(candidateSource,b);
 const n={r:2.1,c:2.1};
 const ok=b._npcPlanNativeVisitRoute(n,2.1,3.4,pass,.8,1200,'building_entry');
 assert.equal(ok,false,'fine fallback cannot cross '+reason);
 assert(n._routeSearchVisited>1,'negative case exercises actual fine fallback');
 assert((n._routeSearchVisited||0)<=1203,'bounded total node work');
}
for(const changed of ['pass','resolver','origin','goal']){
 const makePass=()=>(r,c)=>r>1.9&&r<2.4&&c>1.9&&c<4,makeSweep=()=>q=>({swept:true,blocked:Math.hypot(q.to.r-q.from.r,q.to.c-q.from.c)>1});
 let calls=0,pass=makePass(),goalC=3.4;const n={r:2.1,c:2.1};
 const b={MAP_COLS:100,Math,Map,_walkNpcNavigationResolver:makeSweep(),_npcRouteWorkExpired:()=>++calls>2,_setNpcRoute:(n,p)=>{n._route=p;return p.length>0;}};vm.createContext(b);vm.runInContext(candidateSource,b);
 assert.equal(b._npcPlanNativeVisitRoute(n,2.1,goalC,pass,.8,1200,'building_entry'),false);assert(n._npcDirectedSearch?.fine,'resumable fine state exists before invalidation');
 if(changed==='pass')pass=makePass();if(changed==='resolver')b._walkNpcNavigationResolver=makeSweep();if(changed==='origin')n.r+=.02;if(changed==='goal')goalC+=.02;
 b._npcRouteWorkExpired=()=>false;n._routeSearchPending=false;
 assert(b._npcPlanNativeVisitRoute(n,2.1,goalC,pass,.8,1200,'building_entry'));assert.equal(n._routeSearchRestarts,1,'changed '+changed+' invalidates frontier');
 assert.equal(n._route.at(-1).c,goalC);
}
console.log(JSON.stringify({pass:true,report,limit:'CPU candidate VM only; 1 ms slices exercise continuation, total production budget unchanged. No LIVE or GPU.'},null,2));
fs.writeFileSync('outputs/npc_adaptive_grid_candidate18.json',JSON.stringify(report,null,2));
