import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
import {depthFirstWanderCandidate18} from './npc_wander_depth_first_candidate18.mjs';
const source=fs.readFileSync('world.html','utf8'),realPick=sourceFunction(source,'pickNpcWaypoint');
const dfsInsertion='if(resolver)queue.splice(search.qi+1,0,node);else queue.push(node);',applied=realPick.includes(dfsInsertion);
const baselinePick=applied?realPick.replace(dfsInsertion,'queue.push(node);'):realPick,candidatePick=applied?realPick:depthFirstWanderCandidate18(realPick);
assert.notEqual(baselinePick,candidatePick);new vm.Script(candidatePick);
if(process.argv.includes('--source-only')){new vm.Script(baselinePick);console.log('PASS applied DFS/current source versus reconstructed FIFO frontier; no double transformation');process.exit(0);}
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
 vm.runInContext('_npcRouteWorkFrame=null;_npcRouteWorkQueue.clear();_npcRouteWorkServed.clear();',b);vm.runInContext(code.replace('  npc._npcWanderSearch=null;\n  let pool=','  npc.testExpanded=search.qi+1;npc.testVisited=nodes.size;\n  npc._npcWanderSearch=null;\n  let pool='),b);
 let issues=0,arrivals=0,blocked=0,moving=0,pending=0,last20Moving=0,last20Pending=0,plannerCpu=0,motionCpu=0,shortFallback=0,gridExits=0,minimumLongPoints=Infinity,minimumLongDistance=Infinity;const waits=[],costs=[],lengths=[],longLengths=[],expanded=[],visited=[],directions={north:0,south:0,east:0,west:0},goals=new Set();
 b._setNpcRoute=(n,path,...args)=>{
  if(path?.length){assert.equal(new Set(path.map(p=>p.r+','+p.c)).size,path.length,'published route contains no repeated waypoint loop');const end=path.at(-1),dr=end.r-n.r,dc=end.c-n.c,net=Math.hypot(dr,dc);let distance=0,from=n;for(const to of path){distance+=Math.hypot(to.r-from.r,to.c-from.c)*4.1;from=to;}lengths.push(distance);
   if(Number.isFinite(n.testExpanded))expanded.push(n.testExpanded);if(Number.isFinite(n.testVisited))visited.push(n.testVisited);
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
   if(!n._route?.length){if(n._npcWanderSearch){pending++;if(frame>=frames-20*hz)last20Pending++;}continue;}
   const t=performance.now();let target=n._route[n._routeIndex||0],dr=target.r-n.r,dc=target.c-n.c,d=Math.hypot(dr,dc);
   if(d<b._civilianArrivalRadius(n)){
    if((n._routeIndex||0)+1>=n._route.length){arrivals++;b._clearNpcRoute(n);n.idleUntil=0;motionCpu+=performance.now()-t;continue;}
    n._routeIndex=(n._routeIndex||0)+1;target=n._route[n._routeIndex];dr=target.r-n.r;dc=target.c-n.c;d=Math.hypot(dr,dc);
   }
   const step=Math.min(d,1.8/4.1*dt),r=n.r+dr/Math.max(d,.0000001)*step,c=n.c+dc/Math.max(d,.0000001)*step;
   if(!b._npcPathPassable(n.r,n.c,r,c,b.npcPassable)){blocked++;b._clearNpcRoute(n);n.idleUntil=f.now+900;}
   else{n.r=r;n.c=c;if(step>0){moving++;if(frame>=frames-20*hz)last20Moving++;}}
   motionCpu+=performance.now()-t;
  }
  plannerCpu+=cpu;costs.push(cpu);
 }
 b._setNpcRoute=setRoute;
 return{hz,issues,arrivals,blocked,movingShare:moving/(frames*288),pendingShare:pending/(frames*288),last20Seconds:{movingShare:last20Moving/(20*hz*288),pendingShare:last20Pending/(20*hz*288)},plannerCpuMs:plannerCpu,plannerMsPerIssue:plannerCpu/issues,motionCpuMs:motionCpu,updateP95:percentile(costs,.95),requestMs:{p50:percentile(waits,.5),p95:percentile(waits,.95)},expandedNodes:{p50:percentile(expanded,.5),p95:percentile(expanded,.95)},visitedNodes:{p50:percentile(visited,.5),p95:percentile(visited,.95)},routeMetres:{p50:percentile(lengths,.5),p95:percentile(lengths,.95),longP50:percentile(longLengths,.5),longP95:percentile(longLengths,.95),under4: lengths.filter(v=>v<4).length,under8:lengths.filter(v=>v<8).length,under16:lengths.filter(v=>v<16).length},longOutings:longLengths.length,minimumLongPoints,minimumLongNetMetres:minimumLongDistance,shortFallback,gridExits,directions,uniqueGoalCells:goals.size};
}
const results=[];
const reverseOrder=process.argv.includes('--reverse');
for(const hz of process.argv.includes('--20hz')?[20]:[10]){
 const first=run(reverseOrder?candidatePick:baselinePick,hz),second=run(reverseOrder?baselinePick:candidatePick,hz),baseline=reverseOrder?second:first,candidate=reverseOrder?first:second;assert.equal(baseline.blocked,0);assert.equal(candidate.blocked,0);assert(candidate.minimumLongPoints>=8);assert(candidate.minimumLongNetMetres>=24.6-1e-8);assert(Object.values(candidate.directions).every(v=>v>0));
 results.push({hz,baseline,candidate});console.log(JSON.stringify(results.at(-1),null,2));
}
const report={scenario:'Current one-goal breadth-first frontier versus retained depth-first frontier; identical visited/parent/minDepth8/net6/maxDepth18/520-node/shuffled-direction constraints. 288 physically valid origins spread across all source map; 60simsec at20Hz and10Hz; unchanged actual route queue/4ms/collision/arrival/speed.',reverseOrder,results,limits:f.limits+' CPU candidate only. Movement uses actual source arrival radius and full execution footprint/sweep; no LIVE or FPS claim.'};
fs.writeFileSync('outputs/npc_wander_depth_first_candidate18'+(process.argv.includes('--20hz')?'_20hz':'_10hz')+(reverseOrder?'_reverse':'')+'.json',JSON.stringify(report,null,2));
fs.writeFileSync('outputs/pickNpcWaypoint_depth_first_staged18.js',candidatePick+'\n');
