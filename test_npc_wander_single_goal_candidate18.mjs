import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
import {singleGoalWanderCandidate18} from './npc_wander_single_goal_candidate18.mjs';
const source=fs.readFileSync('world.html','utf8'),realPick=sourceFunction(source,'pickNpcWaypoint');
const applied=realPick.includes('const wanderChoiceTarget=1;')&&realPick.includes('search.wanderDirs');
let baselinePick=realPick;
if(applied){
 const start=realPick.indexOf('  const {queue,nodes,candidates}=search;'),end=realPick.indexOf('  const occupiedGoals=new Set();',start);
 assert(start>=0&&end>start&&realPick.slice(start,end).includes('search.wanderDirs'),'locate only applied per-search direction block');
 baselinePick=(realPick.slice(0,start)+'  const {queue,nodes,candidates}=search,dirs=[[1,0],[-1,0],[0,1],[0,-1]];\n'+realPick.slice(end)).replace('const wanderChoiceTarget=1;','const wanderChoiceTarget=8;');
}
const candidatePick=applied?realPick:singleGoalWanderCandidate18(realPick);
assert.notEqual(candidatePick,baselinePick,'A/B uses distinct one-goal and original eight-goal implementations');
new vm.Script(baselinePick);new vm.Script(candidatePick);
if(process.argv.includes('--source-only')){console.log('PASS applied-source A/B reconstruction: current one-goal function versus eight goals/original directions; no double injection');process.exit(0);}
const percentile=(a,p)=>[...a].sort((x,y)=>x-y)[Math.min(a.length-1,Math.floor(a.length*p))]||0;
const seeded=()=>{let s=77;const math=Object.create(Math);math.random=()=>((s=Math.imul(s,1664525)+1013904223>>>0)/4294967296);return math;};
const f=await createCivilianNativeFixture(),b=f.box,all=[];
b._civilianPlanNext=()=>false;b._maybePlanResidentBuildingVisit=()=>false;
for(let r=3;r<b.MAP_ROWS-4;r+=2)for(let c=3;c<b.MAP_COLS-4;c+=2){const n={r:r+.5,c:c+.5};if(all.length%10===0)n.c+=.11;if(b.npcWaypointOk(n,n.r,n.c)&&b._npcBodyPassable(n.r,n.c,b.npcPassable))all.push(n);}
assert(all.length>=288);const origins=Array.from({length:288},(_,i)=>all[Math.floor(i*all.length/288)]);
const setRoute=b._setNpcRoute,gridExit=b._npcFindWanderGridExit;
b._npcFindWanderGridExit=(n,...args)=>{const result=gridExit(n,...args);if(result.status==='ready')n.testGridExit=true;return result;};
function run(code,hz){
 const dt=1/hz,frames=60*hz;b.Math=seeded();b.NPCS.length=0;for(let i=0;i<origins.length;i++)b.NPCS.push({id:'resident_'+i,...origins[i],hp:60});
 vm.runInContext('_npcRouteWorkFrame=null;_npcRouteWorkQueue.clear();_npcRouteWorkServed.clear();',b);vm.runInContext(code,b);
 let issues=0,arrivals=0,blocked=0,moving=0,pending=0,plannerCpu=0,motionCpu=0,shortFallback=0,gridExits=0,minimumLongPoints=Infinity,minimumLongDistance=Infinity;const waits=[],costs=[],lengths=[],longLengths=[],directions={north:0,south:0,east:0,west:0},goals=new Set();
 b._setNpcRoute=(n,path,...args)=>{
  if(path?.length){const end=path.at(-1),dr=end.r-n.r,dc=end.c-n.c,net=Math.hypot(dr,dc);let distance=0,from=n;for(const to of path){distance+=Math.hypot(to.r-from.r,to.c-from.c)*4.1;from=to;}lengths.push(distance);
   if(n.testGridExit){gridExits++;delete n.testGridExit;}
   else if(path.length>=8&&net>=6){minimumLongPoints=Math.min(minimumLongPoints,path.length);minimumLongDistance=Math.min(minimumLongDistance,net*4.1);longLengths.push(distance);}
   else shortFallback++;
   directions[Math.abs(dr)>=Math.abs(dc)?dr<0?'north':'south':dc<0?'west':'east']++;goals.add(Math.floor(end.r)+','+Math.floor(end.c));
  }
  return setRoute(n,path,...args);
 };
 for(let frame=0;frame<frames;frame++){
  f.nextFrame(dt);let cpu=0;
  for(const n of b.NPCS){
   if(!n._route?.length&&!(n.idleUntil>f.now)){n.testRequestAt??=f.now;const t=performance.now();if(b.pickNpcWaypoint(n)){issues++;waits.push(f.now-n.testRequestAt);n.testRequestAt=null;}cpu+=performance.now()-t;}
   if(!n._route?.length){if(n._npcWanderSearch)pending++;continue;}
   const t=performance.now();let target=n._route[n._routeIndex||0],dr=target.r-n.r,dc=target.c-n.c,d=Math.hypot(dr,dc);
   if(d<b._civilianArrivalRadius(n)){
    if((n._routeIndex||0)+1>=n._route.length){arrivals++;b._clearNpcRoute(n);n.idleUntil=0;motionCpu+=performance.now()-t;continue;}
    n._routeIndex=(n._routeIndex||0)+1;target=n._route[n._routeIndex];dr=target.r-n.r;dc=target.c-n.c;d=Math.hypot(dr,dc);
   }
   const step=Math.min(d,1.8/4.1*dt),r=n.r+dr/Math.max(d,.0000001)*step,c=n.c+dc/Math.max(d,.0000001)*step;
   if(!b._npcPathPassable(n.r,n.c,r,c,b.npcPassable)){blocked++;b._clearNpcRoute(n);n.idleUntil=f.now+900;}
   else{n.r=r;n.c=c;if(step>0)moving++;}
   motionCpu+=performance.now()-t;
  }
  plannerCpu+=cpu;costs.push(cpu);
 }
 b._setNpcRoute=setRoute;
 return{hz,issues,arrivals,blocked,movingShare:moving/(frames*288),pendingShare:pending/(frames*288),plannerCpuMs:plannerCpu,plannerMsPerIssue:plannerCpu/issues,motionCpuMs:motionCpu,updateP95:percentile(costs,.95),requestMs:{p50:percentile(waits,.5),p95:percentile(waits,.95)},routeMetres:{p50:percentile(lengths,.5),p95:percentile(lengths,.95),longP50:percentile(longLengths,.5),longP95:percentile(longLengths,.95)},longOutings:longLengths.length,minimumLongPoints,minimumLongNetMetres:minimumLongDistance,shortFallback,gridExits,directions,uniqueGoalCells:goals.size};
}
const results=[];
const reverseOrder=process.argv.includes('--reverse');
for(const hz of [20,10]){
 const first=run(reverseOrder?candidatePick:baselinePick,hz),second=run(reverseOrder?baselinePick:candidatePick,hz),baseline=reverseOrder?second:first,candidate=reverseOrder?first:second;assert.equal(baseline.blocked,0);assert.equal(candidate.blocked,0);assert(candidate.minimumLongPoints>=8);assert(candidate.minimumLongNetMetres>=24.6-1e-8);assert(Object.values(candidate.directions).every(v=>v>0));
 results.push({hz,baseline,candidate});console.log(JSON.stringify(results.at(-1),null,2));
}
const report={scenario:'Current eight choices versus one long choice with stable per-actor/outing shuffled cardinal expansion. 288 physically valid origins spread across all source map; 60simsec at20Hz and10Hz; unchanged actual route queue/4ms/collision/arrival/speed.',reverseOrder,results,limits:f.limits+' CPU candidate only. Movement uses actual source arrival radius and full execution footprint/sweep; no LIVE or FPS claim.'};
fs.writeFileSync('outputs/npc_wander_single_goal_candidate18'+(reverseOrder?'_reverse':'')+'.json',JSON.stringify(report,null,2));
fs.writeFileSync('outputs/pickNpcWaypoint_single_goal_staged18.js',candidatePick+'\n');
