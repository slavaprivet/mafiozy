import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {gunzipSync} from 'node:zlib';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
const variant=process.argv[2]||'baseline',seconds=Number(process.argv[3])||180;
const snapshot=JSON.parse(gunzipSync(fs.readFileSync('assets/maps/city_rebuild_v1/test_fixtures/native_static_collision19.json.gz')));
const f=await createCivilianNativeFixture({snapshot}),b=f.box,s=f.source;
b._civilianPlanNext=()=>false;b._maybePlanResidentBuildingVisit=()=>false;b._npcAgendaPick=()=>null;
vm.runInContext(sourceFunction(s,'pickNpcWaypoint'),b);
const original=sourceFunction(s,'_npcReserveRouteWork');
if(variant==='cohort32')vm.runInContext(original.replace('let head=_npcRouteWorkQueue.keys().next().value;', 'if(!_npcRouteWorkBatch.size)_npcRouteWorkBatchCount=0;\n  let head=_npcRouteWorkQueue.keys().next().value;').replace('_npcRouteWorkCount>=8','_npcRouteWorkCount>=32').replace('_npcRouteWorkBatchCount>=8','_npcRouteWorkBatchCount>=32'),b);
let seed=77;const math=Object.create(Math);math.random=()=>((seed=Math.imul(seed,1664525)+1013904223>>>0)/4294967296);b.Math=math;
const all=[];
for(let r=3;r<b.MAP_ROWS-4;r+=2)for(let c=3;c<b.MAP_COLS-4;c+=2){const n={r:r+.5,c:c+.5};if(b.npcWaypointOk(n,n.r,n.c)&&b._npcBodyPassable(n.r,n.c,b.npcPassable))all.push(n);}
const live=process.argv[4]?JSON.parse(fs.readFileSync(process.argv[4],'utf8').replace(/^\uFEFF/,'')):null;
const liveActors=Array.isArray(live)?live:live?.actors||live?.rows?.map(row=>Object.fromEntries(live.columns.map((key,i)=>[key,row[i]])));
for(let i=0;i<288;i++){const captured=liveActors?.find(n=>n.id==='resident_'+i),o=captured||all[Math.floor(i*all.length/288)];b.NPCS.push({id:captured?.id||'resident_'+i,...o,tr:o.r,tc:o.c,hp:100,max_hp:100,speed:captured?.speed||1,walkPhase:0,idleUntil:0,alive:true,_routeStartR:captured?.startR??undefined,_routeStartC:captured?.startC??undefined,_allowBeach:!!captured?.allowBeach,_beach:!!captured?.beach});}
const p=(a,q)=>[...a].sort((a,b)=>a-b)[Math.min(a.length-1,Math.floor(a.length*q))]||0;
const costs=[],waits=[],admissions=[],used=[],samples=[];let moving=0,pending=0,total=0,blocked=0,routes=0,maxPendingAge=0;
const originalSet=b._setNpcRoute;b._setNpcRoute=(n,path,...args)=>{if(path?.length){routes++;n.completed=(n.completed||0)+1;if(n.requestAt!=null){waits.push(f.now-n.requestAt);n.requestAt=null;}}return originalSet(n,path,...args);};
for(let frame=0;frame<seconds*7;frame++){
 f.nextFrame(1/7);const at=performance.now();let fm=0,fp=0;
 for(const n of b.NPCS){
  if(!n._route?.length&&!(n.idleUntil>f.now))n.requestAt??=f.now;
  const r=n.r,c=n.c;b.actualFootTick(n,1/7,f.now);const d=Math.hypot(n.r-r,n.c-c);
  assert(d<=.18,'actual source walking speed: '+n.id+' moved '+d+' from '+r+','+c+' to '+n.r+','+n.c);
  if(d&&!b._npcPathPassable(r,c,n.r,n.c,b.npcPassableForSnitch))blocked++;
  fm+=d>1e-9;fp+=!!(n._npcWanderSearch||n._routeSearchPending);
  if(n._npcWanderSearch)maxPendingAge=Math.max(maxPendingAge,f.now-n._npcWanderSearch.since);
 }
 costs.push(performance.now()-at);const stats=vm.runInContext('({count:_npcRouteWorkCount,used:_npcRouteWorkUsedMs,queued:_npcRouteWorkQueue.size,expired:_npcRouteWorkStats.expired})',b);admissions.push(stats.count);used.push(stats.used);
 if(frame>=seconds*7-140){moving+=fm;pending+=fp;total+=288;}
 if(frame%70===69)samples.push({second:Math.round(f.now/1000),moving:fm,pending:fp,...stats});
}
const completed=b.NPCS.map(n=>n.completed||0);
const capturedOutcomes=b.NPCS.filter(n=>liveActors?.some(a=>a.id===n.id)).map(n=>({id:n.id,r:n.r,c:n.c,completed:n.completed||0,pending:!!(n._npcWanderSearch||n._routeSearchPending),nodes:n._npcWanderSearch?.nodes.size||0,expanded:n._npcWanderSearch?.qi||0,gridExit:n._npcWanderSearch?.gridExit?.expanded||0,road:n._roadExitStatus||null}));
const report={variant,scenario:'288 ordinary residents, actual native geometry and source walking loop, 7Hz; activity offers disabled to isolate 144 LIVE wander jobs. '+seconds+' simulated seconds.',routes,neverCompleted:completed.filter(x=>!x).length,minCompleted:Math.min(...completed),movingFractionLast20s:moving/total,pendingFractionLast20s:pending/total,routeWaitMs:{p50:p(waits,.5),p95:p(waits,.95),max:p(waits,1)},maxPendingAge,cpuMs:{p50:p(costs,.5),p95:p(costs,.95)},admissionsMean:admissions.reduce((a,v)=>a+v,0)/admissions.length,budgetUsedMean:used.reduce((a,v)=>a+v,0)/used.length,blocked,samples,limits:f.limits+' This isolates ordinary walking, not full activities scheduling or GPU FPS.'};
report.capturedOutcomes=capturedOutcomes;fs.writeFileSync('outputs/npc_wander_7fps19_'+variant+(liveActors?'_actual':'')+'.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));assert.equal(blocked,0);



