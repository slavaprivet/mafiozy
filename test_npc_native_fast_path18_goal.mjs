import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import {registerHooks} from 'node:module';import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
import {stageNativeGoalAnchors} from './test_npc_native_fast_path18_goal_candidate.mjs';
const baseline=fs.readFileSync('assets/maps/city_rebuild_v1/npc_native_directed_route_source.js','utf8'),applied=baseline.includes('search.goalDiscovery={candidates,index:0,anchors:new Map()}'),candidate=applied?baseline:stageNativeGoalAnchors(baseline);
const fixtureURL=new URL('./assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs?goal-coastal002',import.meta.url),wanted='REBUILD-VISUAL-coastal_orchard_house_v1-002';
const hook=registerHooks({load(url,context,next){const result=next(url,context);if(url!==fixtureURL.href)return result;const source=String(result.source),before='buildings.find(b=>b.assetId===assetId)';assert(source.includes(before));return {...result,source:source.replace(before,'buildings.find(b=>b.id==='+JSON.stringify(wanted)+')')};}});
const special=await import(fixtureURL.href);hook.deregister();
const cases=[{assetId:'coastal_orchard_house_v1',factory:special.createCivilianNativeFixture,r:139.111932568,c:173.181051759},{assetId:'print_shop',factory:createCivilianNativeFixture,r:4.990913843951179,c:97.94314630350254},{assetId:'hospital',factory:createCivilianNativeFixture,r:6.469984627970292,c:165.137}];
const results=[];
for(const spec of cases){
 const f=await spec.factory({assetId:spec.assetId}),b=f.box,door=b._residentBuildingDoors()[0],row={assetId:spec.assetId,instance:f.item.id};
 for(const [label,code]of (applied?[['after',candidate]]:[['before',baseline],['after',candidate]])){
  vm.runInContext(code,b);const n={id:'resident_goal_'+label,r:spec.r,c:spec.c,hp:60,alive:true,_civilianPlan:{phase:'walk_to_shop',doorId:door.id}},costs=[];let ok=false,slices=0;
  do{f.nextFrame(.2);const t=performance.now();ok=b._civilianRouteTo(n,door.r,door.c,'building_entry');costs.push(performance.now()-t);slices++;}while(n._routeSearchPending&&slices<300);
  assert(!n._routeSearchPending);assert.equal(ok,label==='after'||spec.assetId!=='coastal_orchard_house_v1');
  if(ok){let from={r:spec.r,c:spec.c};for(const to of n._route){assert(b._npcPathPassable(from.r,from.c,to.r,to.c,b.npcPassableForSnitch),'full-body returned edge');from=to;}assert(Math.hypot(from.r-door.r,from.c-door.c)<1e-9);}
  row[label]={ok,slices,totalCpuMs:costs.reduce((a,x)=>a+x,0),maxSliceMs:Math.max(...costs),expanded:n._routeSearchExpanded,visited:n._routeSearchVisited,route:n._route||[]};
  if(ok&&spec.assetId==='coastal_orchard_house_v1'){
   Object.assign(n,{speed:1,max_hp:60,walkPhase:0,_arcKey:'worker',_npcRoutine:'errands',_residentDoor:door});let frames=0,distanceM=0,maxStepM=0;
   while(Math.hypot(n.r-door.r,n.c-door.c)>.08&&frames<2400){f.nextFrame(.05);const from={r:n.r,c:n.c};b.actualFootTick(n,.05,f.now);const d=Math.hypot(n.r-from.r,n.c-from.c)*f.M;assert(d<=.083);assert(b._npcPathPassable(from.r,from.c,n.r,n.c,b.npcPassableForSnitch));frames++;distanceM+=d;maxStepM=Math.max(maxStepM,d);}
   assert(frames<2400,JSON.stringify({position:{r:n.r,c:n.c},target:{r:n.tr,c:n.tc},routeIndex:n._routeIndex,routeKind:n._routeKind,phase:n._civilianPlan,blocked:n._routeBlockedAt,distanceM}));row[label].movement={frames,distanceM,maxStepM,doorDistanceM:Math.hypot(n.r-door.r,n.c-door.c)*f.M};
  }
 }
 results.push(row);
}
// Bounded goal discovery resumes in the same search; no safe anchor never
// expands the city. Revalidate a once-safe connector after a dynamic change.
for(const mode of ['sealed','water','dynamic','dynamic-car']){
 let block=false,checks=0;const n={r:2.2,c:2.2},goal={r:12.2,c:12.2},pass=(r,c)=>r>0&&c>0&&r<30&&c<30&&(!(mode==='water'||mode==='dynamic-car'&&block)||Math.hypot(r-goal.r,c-goal.c)>.2);
 const resolver=q=>({swept:true,blocked:(mode==='sealed'||mode==='dynamic'&&block)&&Math.hypot(q.to.r-goal.r,q.to.c-goal.c)<.01});
 const b={MAP_COLS:100,Math,Map,_walkNpcNavigationResolver:resolver,_npcRouteWorkExpired:()=>++checks>2,_setNpcRoute:(n,p)=>{n._route=p;return p.length>0;}};vm.createContext(b);vm.runInContext(candidate,b);
 let ok=false,slices=0,first;
 do{checks=0;n._routeSearchPending=false;ok=b._npcPlanNativeVisitRoute(n,goal.r,goal.c,pass,.8,1200,'building_entry');slices++;if(n._npcDirectedSearch){first??=n._npcDirectedSearch;assert.equal(first,n._npcDirectedSearch);if(mode.startsWith('dynamic')&&n._npcDirectedSearch.goalAnchors?.size)block=true;}}while(n._routeSearchPending&&slices<1000);
 assert(!ok,'cannot publish '+mode+' corridor');assert(!n._routeSearchPending);assert.equal(n._routeSearchRestarts||0,0);
 if(!mode.startsWith('dynamic'))assert.equal(n._routeSearchExpanded,0,'no valid terminal anchor prevents pointless city expansion');
}
{
 const n={r:10.1,c:2.1},pass=(r,c)=>Math.abs(r-10.1)<.12&&c>=2&&c<=12.3;let checks=0,ok=false,slices=0;
 const b={MAP_COLS:100,Math,Map,_walkNpcNavigationResolver:()=>({swept:true,blocked:false}),_npcRouteWorkExpired:()=>++checks>3,_setNpcRoute:(n,p)=>{n._route=p;return p.length>0;}};vm.createContext(b);vm.runInContext(candidate,b);
 do{checks=0;n._routeSearchPending=false;ok=b._npcPlanNativeVisitRoute(n,10.1,12.1,pass,.8,1200,'building_entry');slices++;}while(n._routeSearchPending&&slices<100);
 assert(ok,'retain fine-only corridor even without coarse goal anchors');assert.equal(n._routeSearchRestarts||0,0);assert.equal(n._route.at(-1).c,12.1);
}
console.log(JSON.stringify({pass:true,applied,results,limits:'CPU actual source shared4ms queue, no other queue owners; not LIVE/FPS.'},null,2));
fs.writeFileSync(applied?'outputs/npc_goal_anchor_applied18.json':'outputs/npc_goal_anchor_candidate18.json',JSON.stringify(results,null,2));
