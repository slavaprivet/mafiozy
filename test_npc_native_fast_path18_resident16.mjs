// Read-only reproduction of the reported LIVE source start and actual house002.
import fs from 'node:fs';import assert from 'node:assert/strict';import {registerHooks} from 'node:module';import {performance} from 'node:perf_hooks';
import vm from 'node:vm';
const fixtureURL=new URL('./assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs?resident16-coastal002',import.meta.url);
const wanted='REBUILD-VISUAL-coastal_orchard_house_v1-002';
const hook=registerHooks({load(url,context,next){const result=next(url,context);if(url!==fixtureURL.href)return result;const source=String(result.source),before='buildings.find(b=>b.assetId===assetId)';assert(source.includes(before));return {...result,source:source.replace(before,'buildings.find(b=>b.id==='+JSON.stringify(wanted)+')')};}});
const {createCivilianNativeFixture}=await import(fixtureURL.href);hook.deregister();
const f=await createCivilianNativeFixture({assetId:'coastal_orchard_house_v1'}),b=f.box,door=b._residentBuildingDoors()[0];
assert.equal(f.item.id,wanted);
const live={r:139.111932568,c:173.181051759},liveDoor={r:150.893585368,c:165.747926883};
assert(Math.hypot(door.r-liveDoor.r,door.c-liveDoor.c)<1e-7,'fixture chooses the actual LIVE door, not house001');
const n={id:'resident_16',...live,alive:true,hp:60,_arcKey:'worker',_npcRoutine:'errands',_civilianPlan:{phase:'walk_to_shop',doorId:door.id,cycle:0}},startValid=b._npcBodyPassable(n.r,n.c,b.npcPassableForSnitch),goalValid=b._npcBodyPassable(door.r,door.c,b.npcPassableForSnitch),costs=[];
let ok=false,slices=0;const progress=[];
do{
 f.nextFrame(.2);const start=performance.now();ok=b._civilianRouteTo(n,door.r,door.c,'building_entry');costs.push(performance.now()-start);slices++;
 if(slices%5===0||!n._routeSearchPending)progress.push({slices,expanded:n._npcDirectedSearch?.qi??n._routeSearchExpanded,visited:n._npcDirectedSearch?.nodes.size??n._routeSearchVisited,pending:!!n._routeSearchPending});
}while(n._routeSearchPending&&slices<300);
let pathDistanceM=0,from=live;
if(ok)for(const to of n._route){assert(b._npcPathPassable(from.r,from.c,to.r,to.c,b.npcPassableForSnitch));pathDistanceM+=Math.hypot(to.r-from.r,to.c-from.c)*f.M;from=to;}
costs.sort((a,b)=>a-b);
const goalNodes=[];
for(let r=Math.floor(door.r)-1;r<=Math.floor(door.r)+1;r++)for(let c=Math.floor(door.c)-1;c<=Math.floor(door.c)+1;c++)if(Math.hypot(r+.5-door.r,c+.5-door.c)<=.8)goalNodes.push({r:r+.5,c:c+.5,body:b._npcBodyPassable(r+.5,c+.5,b.npcPassableForSnitch),connector:b._npcPathPassable(r+.5,c+.5,door.r,door.c,b.npcPassableForSnitch)});
const nearbyConnectors=[];for(let r=Math.floor(door.r)-2;r<=Math.floor(door.r)+2;r++)for(let c=Math.floor(door.c)-2;c<=Math.floor(door.c)+2;c++)if(b._npcBodyPassable(r+.5,c+.5,b.npcPassableForSnitch)&&b._npcPathPassable(r+.5,c+.5,door.r,door.c,b.npcPassableForSnitch))nearbyConnectors.push({r:r+.5,c:c+.5,distance:Math.hypot(r+.5-door.r,c+.5-door.c)});nearbyConnectors.sort((a,b)=>a.distance-b.distance);
const audit=fs.readFileSync('test_npc_native_fast_path18_grid_audit.mjs','utf8'),fineSource=audit.slice(audit.indexOf('function fineRoute('),audit.indexOf('const results=[];')).replace('nodes.size<8000','nodes.size<16000').replace(')>12',')>22');
vm.runInContext(fineSource,b);f.nextFrame();const fineStarted=performance.now(),fine=b.fineRoute(b,live,door);fine.cpuMs=performance.now()-fineStarted;
const report={instance:f.item.id,start:live,door:{r:door.r,c:door.c},startValid,goalValid,ok,pending:!!n._routeSearchPending,restarts:n._routeSearchRestarts||0,slices,noCompetitionSimulatedWaitSeconds:slices*.2,totalCpuMs:costs.reduce((s,x)=>s+x,0),sliceP50Ms:costs[Math.floor(costs.length*.5)],sliceP95Ms:costs[Math.floor(costs.length*.95)],expanded:n._routeSearchExpanded,visited:n._routeSearchVisited,pathDistanceM,progress,path:n._route||[],goalNodes,nearbyConnectors,fine,limits:'Actual house002/current city snapshot/source shared4ms budget; no other queue owners, runtime cars/railway, GPU or loaded LIVE state. Fine search is diagnostic-only, bounded16000 nodes/22source radius.'};
console.log(JSON.stringify(report,null,2));fs.writeFileSync('outputs/npc_resident16_coastal002_audit18.json',JSON.stringify(report,null,2));
