import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
const source=fs.readFileSync('world.html','utf8').replace(/\r\n/g,'\n');
const queue=source.slice(source.indexOf('let _npcRouteWorkFrame='),source.indexOf('function _planNpcRouteTo('));
const reserve=sourceFunction(source,'_npcReserveRouteWork');
assert(reserve.includes('_npcRouteWorkCount>=8'),'production uses applied eight-admission cap');
const statsCode='globalThis.queueStats=()=>({used:_npcRouteWorkUsedMs,count:_npcRouteWorkCount,queued:_npcRouteWorkQueue.size,head:_npcRouteWorkQueue.keys().next().value?.id});';
const percentile=(a,p)=>[...a].sort((x,y)=>x-y)[Math.min(a.length-1,Math.floor(a.length*p))]||0;
function deterministic(cap,workKind){
 let clock=1000;const b={performance:{now:()=>clock},prevT:0,_walkNpcNavigationResolver:()=>({}),Map,Set,Math,Number};vm.createContext(b);
 vm.runInContext(queue.replace('_npcRouteWorkCount>=8','_npcRouteWorkCount>='+cap),b);vm.runInContext(statsCode,b);
 const actors=Array.from({length:288},(_,i)=>({id:i,remaining:workKind==='short'?5:workKind==='heavy'?120:i%4===0?5:i%4===1?20:120,admissions:0}));
 b.existing=actors.slice(55);vm.runInContext('for(const n of existing)_npcRouteWorkQueue.set(n,0);',b);
 const completed=[],frames=[];let admissions=0,totalQuanta=0;
 for(let frame=0;frame<5000&&completed.length<actors.length;frame++){
  b.prevT=frame+1;clock+=50;
  for(const n of actors){if(n.remaining<=0)continue;if(!b._npcReserveRouteWork(clock,n))continue;admissions++;n.admissions++;
   while(n.remaining>0&&!b._npcRouteWorkExpired()){n.remaining--;totalQuanta++;clock+=.05;}
   b._npcFinishRouteWork();if(n.remaining===0)completed.push((frame+1)*50);
  }
  const s=b.queueStats(),backlog=actors.filter(n=>n.remaining>0).length,unused=backlog?Math.max(0,4-s.used):0;
  frames.push({...s,backlog,unused,capUnused:s.count>=cap?unused:0,orderUnused:s.count<cap?unused:0});
  assert(s.used<=4.0500001,'same 4ms budget with at most one .05ms atomic quantum');assert(s.count<=cap);
 }
 assert.equal(completed.length,288);assert(actors.some(n=>n.admissions>1)||workKind==='short','retained work exercised');
 return{cap,workKind,frames:frames.length,admissions,totalWorkMs:totalQuanta*.05,multiSliceActors:actors.filter(n=>n.admissions>1).length,completionMs:{p50:percentile(completed,.5),p95:percentile(completed,.95),last:completed.at(-1)},usedMs:frames.reduce((a,f)=>a+f.used,0),unusedWithBacklogMs:frames.reduce((a,f)=>a+f.unused,0),capLimitedUnusedMs:frames.reduce((a,f)=>a+f.capUnused,0),orderLimitedUnusedMs:frames.reduce((a,f)=>a+f.orderUnused,0),peakWorkMs:Math.max(...frames.map(f=>f.used)),firstFrames:frames.slice(0,4)};
}
const synthetic=[];for(const kind of ['short','mixed','heavy'])synthetic.push({baseline:deterministic(2,kind),candidate:deterministic(8,kind)});
console.log('PASS applied max8 versus historical max2 FIFO: 233 older requests, 288 fixed-order actors, short/mixed/heavy retained work, unchanged 4 ms budget.');
if(process.argv.includes('--contracts-only')){console.log(JSON.stringify({appliedCap:8,synthetic},null,2));process.exit(0);}
const f=await createCivilianNativeFixture(),b=f.box,origins=[];
b._civilianPlanNext=()=>false;b._maybePlanResidentBuildingVisit=()=>false;vm.runInContext(sourceFunction(source,'pickNpcWaypoint'),b);vm.runInContext(statsCode,b);
for(let r=3;r<b.MAP_ROWS-4&&origins.length<288;r+=2)for(let c=3;c<b.MAP_COLS-4&&origins.length<288;c+=2){const n={r:r+.5,c:c+.5};if(origins.length%10===0)n.c+=.11;if(b.npcWaypointOk(n,n.r,n.c)&&b._npcBodyPassable(n.r,n.c,b.npcPassable))origins.push(n);}
assert.equal(origins.length,288);
const random=()=>{let s=77;const math=Object.create(Math);math.random=()=>((s=Math.imul(s,1664525)+1013904223>>>0)/4294967296);return math;};
function actual(cap){
 b.Math=random();b.NPCS.length=0;for(let i=0;i<origins.length;i++)b.NPCS.push({id:'cap-'+i,...origins[i],hp:60});
 vm.runInContext('_npcRouteWorkFrame=null;_npcRouteWorkQueue.clear();_npcRouteWorkServed.clear();',b);vm.runInContext(reserve.replace('_npcRouteWorkCount>=8','_npcRouteWorkCount>='+cap),b);
 let issues=0,arrivals=0,blocked=0,movingSamples=0,pendingSamples=0,plannerCpu=0,motionCpu=0,capUnused=0,orderUnused=0,admissions=0;const latency=[],frameCosts=[],workUsed=[],counts=[];
 for(let frame=0;frame<600;frame++){
  f.nextFrame(.05);let cost=0,anyRequest=false;
  for(const n of b.NPCS){
   if(!n._route?.length&&!(n.idleUntil>f.now)){anyRequest=true;n.testRequestAt??=f.now;const t=performance.now();if(b.pickNpcWaypoint(n)){issues++;latency.push(f.now-n.testRequestAt);n.testRequestAt=null;}cost+=performance.now()-t;}
   if(!n._route?.length){if(n._npcWanderSearch)pendingSamples++;continue;}
   const t=performance.now(),to=n._route[n._routeIndex||0],dr=to.r-n.r,dc=to.c-n.c,d=Math.hypot(dr,dc),step=Math.min(d,1.8/4.1*.05),r=n.r+dr/Math.max(d,.0000001)*step,c=n.c+dc/Math.max(d,.0000001)*step;
   if(!b._npcPathPassable(n.r,n.c,r,c,b.npcPassable)){blocked++;b._clearNpcRoute(n);n.idleUntil=f.now+900;}
   else{n.r=r;n.c=c;if(step>0)movingSamples++;if(d-step<.000001){n._routeIndex=(n._routeIndex||0)+1;if(n._routeIndex>=n._route.length){arrivals++;b._clearNpcRoute(n);n.idleUntil=0;}}}
   motionCpu+=performance.now()-t;
  }
  const s=b.queueStats(),pending=b.NPCS.filter(n=>n._npcWanderSearch).length,unused=anyRequest&&pending?Math.max(0,4-s.used):0;
  if(s.count>=cap)capUnused+=unused;else orderUnused+=unused;
  if(anyRequest){admissions+=s.count;workUsed.push(s.used);counts.push(s.count);}plannerCpu+=cost;frameCosts.push(cost);
 }
 return{cap,issues,arrivals,blocked,movingShare:movingSamples/(600*288),pendingShare:pendingSamples/(600*288),plannerCpuMs:plannerCpu,plannerMsPerIssue:plannerCpu/issues,motionCpuMs:motionCpu,routeUpdateP50:percentile(frameCosts,.5),routeUpdateP95:percentile(frameCosts,.95),accountedWorkP95:percentile(workUsed,.95),accountedWorkMax:Math.max(...workUsed),admissions,peakAdmissions:Math.max(...counts),capLimitedUnusedMs:capUnused,orderLimitedUnusedMs:orderUnused,latencyMs:{p50:percentile(latency,.5),p95:percentile(latency,.95)}};
}
const baseline=actual(2),candidate=actual(8);assert.equal(baseline.blocked,0);assert.equal(candidate.blocked,0);
const reverseCandidate=actual(8),reverseBaseline=actual(2);assert.equal(reverseBaseline.blocked,0);assert.equal(reverseCandidate.blocked,0);
const report={appliedCap:8,synthetic,actual:{baseline,candidate},reverseOrder:{candidate:reverseCandidate,baseline:reverseBaseline},limits:f.limits+' Applied max8 compared with reconstructed historical max2 in VM; unchanged actual 4ms CPU budget and fixed NPC iteration. 30 simulated seconds at20Hz/1.8m/s per run with physical waypoint following. Reverse-order repeat guards warm-up ordering. Not FPS or whole update measurement.'};
fs.writeFileSync('outputs/npc_route_admission_cap_audit18.json',JSON.stringify(report,null,2));console.log(JSON.stringify({actual:report.actual,reverseOrder:report.reverseOrder,limits:report.limits},null,2));
