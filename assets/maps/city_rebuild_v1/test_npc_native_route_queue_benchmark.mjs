import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';
const f=await createCivilianNativeFixture(),b=f.box,door=b._residentBuildingDoors()[0],starts=[];
for(let radius=3;radius<=16&&starts.length<96;radius++)for(let i=0;i<32&&starts.length<96;i++){
 const angle=i*Math.PI*2/32,r=Math.floor(door.r+Math.sin(angle)*radius)+.5,c=Math.floor(door.c+Math.cos(angle)*radius)+.5;
 if(starts.some(p=>p.r===r&&p.c===c)||!b._npcBodyPassable(r,c,b.npcPassableForSnitch))continue;starts.push({r,c});
}
assert(starts.length>=70,'actual geometry must provide a substantial simultaneous visit queue');
const original=b._planNpcRouteTo.toString().replace(/\s*if\(native&&kind==='building_entry'&&typeof _npcPlanNativeVisitRoute==='function'\)return _npcPlanNativeVisitRoute\(npc,goalR,goalC,passFn,goalRadius,maxVisited,kind\);/,''),route=b._civilianRouteTo.toString();
const stableRoute=route.replace("pass=native?(rr,cc)=>_npcBodyPassable(rr,cc,pointPass):pointPass","pass=native?(n._testNativePass??=(rr,cc)=>_npcBodyPassable(rr,cc,pointPass)):pointPass");
vm.runInContext(stableRoute,b);
vm.runInContext(fs.readFileSync(new URL('./npc_native_directed_route_source.js',import.meta.url),'utf8'),b);
const startGate="if(!_npcReserveRouteWork(performance.now(),npc)){npc._routeSearchPending=true;return false;}";
const candidate=original.replace(startGate,startGate+"if(native&&kind==='building_entry')return _npcPlanNativeVisitRoute(npc,goalR,goalC,passFn,goalRadius,maxVisited,kind);");assert.notEqual(original,candidate);
const results={};
for(const [label,code]of [['bfs',original],['astar',candidate]]){
 vm.runInContext(code,b);vm.runInContext('_npcRouteWorkFrame=null;_npcRouteWorkDeadline=0;_npcRouteWorkCount=0;_npcRouteWorkQueue.clear();_npcRouteWorkServed.clear();',b);
 const residents=starts.map((p,i)=>({...p,id:'resident_queue_'+i,_civilianPlan:{phase:'walk_to_shop'},_routeSearchPending:false})),remaining=new Set(residents),completion=[],costs=[],routes=[],started=f.now,counts={reached:0,blocked:0};
 const queriesBefore=f.pedestrian.diagnostics().queries;
 for(let frame=0;frame<1200&&remaining.size;frame++){
  f.nextFrame(.05);const t=performance.now();
  for(const n of remaining){const ok=b._civilianRouteTo(n,door.r,door.c,'building_entry');if(ok||!n._routeSearchPending){remaining.delete(n);completion.push(f.now-started);counts[ok?'reached':'blocked']++;if(ok)routes.push({id:n.id,start:starts[residents.indexOf(n)],path:n._route});}}
  costs.push(performance.now()-t);
 }
 // Every completed edge is rechecked by the same full production body/sweep
 // predicate; successful paths cannot improve by removing a collision check.
 for(const route of routes){let from=route.start;for(const to of route.path){assert(b._npcPathPassable(from.r,from.c,to.r,to.c,b.npcPassableForSnitch),label+' collision-safe returned edge');from=to;}}
 const pct=(x,p)=>x.slice().sort((a,b)=>a-b)[Math.min(x.length-1,Math.floor(x.length*p))];
 results[label]={residents:residents.length,...counts,pending:remaining.size,completionP50: pct(completion,.5),completionP95:pct(completion,.95),completionMax:Math.max(...completion),totalCpuMs:costs.reduce((a,b)=>a+b,0),frameCpuP50:pct(costs,.5),frameCpuP95:pct(costs,.95),nativeQueries:f.pedestrian.diagnostics().queries-queriesBefore};
}
console.log(JSON.stringify({scenario:'96 actual native starts, hospital target, 2 jobs/4ms existing queue',results,limits:'CPU real geometry, no residents rendered; 50ms simulated source frames'},null,2));
fs.writeFileSync(new URL('../../../outputs/npc_native_route_queue_20260919.json',import.meta.url),JSON.stringify(results,null,2));
assert.equal(results.astar.pending,0);assert(results.astar.reached>=results.bfs.reached,'at least equal route completion');
assert(results.astar.totalCpuMs<results.bfs.totalCpuMs*.75,'measured CPU improvement required');
assert(results.astar.completionP95<results.bfs.completionP95*.75,'measured queued wait improvement required');
