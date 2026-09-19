import fs from 'node:fs';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';

const f=await createCivilianNativeFixture(),{box,car,npcs,M}=f;
const doors=box._residentBuildingDoors();assert.equal(doors.length,1);assert(doors[0].native);
const door=doors[0],npc={id:'resident_actual_lifecycle',r:0,c:0,hp:100,max_hp:100,speed:1,walkPhase:0,alive:true,_arcKey:'worker',_npcRoutine:'errands'};
// Use successive actual 50 ms walking increments. A long planning query's
// sparse .14-tile samples can straddle the thin pair of closed door leaves.
const doorLength=Math.hypot(door.inside.r-door.r,door.inside.c-door.c),doorSteps=Math.ceil(doorLength/(.05*.4));
let closedDoorBlocks=false;
for(let i=1;i<=doorSteps;i++){
 const point=t=>({r:door.r+(door.inside.r-door.r)*t,c:door.c+(door.inside.c-door.c)*t}),a=point((i-1)/doorSteps),b=point(i/doorSteps);
 if(!box._npcPathPassable(a.r,a.c,b.r,b.c,box._residentNativePassable)){closedDoorBlocks=true;break;}
}
npcs.push(npc);
let start=null;
const options=f.nav.query({mode:'road-targets',carId:car.id,from:{r:door.r,c:door.c,angle:0},minDistance:6,maxDistance:12})?.points||[];
for(const p of options){
 Object.assign(car,{r:p.r,c:p.c,ang:p.angle,dirDy:Math.sin(p.angle),dirDx:Math.cos(p.angle)});f.syncCar();f.pedestrian.beginFrame();
 const access=f.access({carId:car.id});if(!access||!box._npcBodyPassable(access.outside.r,access.outside.c,box.npcPassableForSnitch))continue;
 for(const [dr,dc] of [[1,0],[-1,0],[0,1],[0,-1]]){
  const p2={r:access.outside.r+dr,c:access.outside.c+dc};
  if(box._npcPathPassable(p2.r,p2.c,access.outside.r,access.outside.c,box.npcPassableForSnitch)){start={car:{...p},npc:p2};break;}
 }if(start)break;
}
assert(start,'actual dry clear road has car door and full pedestrian approach');
Object.assign(npc,start.npc);box.player={r:start.car.r+20,c:start.car.c+20};
const traces=[],costs=[],counts={frames:0,carDistanceM:0,footDistanceM:0,boardFrames:0,rideFrames:0,exitFrames:0,doorWaitFrames:0,insideFrames:0},seen=new Set();
let previous='',maxStep=0,done=false,carMovedWithoutDriver=false,error=null;
const limit=Number(process.argv.find(a=>a.startsWith('--frames='))?.split('=')[1])||8000;
try{
 for(let frame=0;frame<limit;frame++){
  f.nextFrame(.05);const old={r:npc.r,c:npc.c,carR:car.r,carC:car.c,angle:car.ang},before=box.trip()?.phase,t0=performance.now();
  if(!box.trip()&&!npc._civilianPlan?.tripDestination&&!npc._residentNativeVisit&&!seen.has('drive'))box._civilianTripSchedule(f.now);
  const occupied=box._civilianTripTickNpc(npc,.05,f.now);
  box._civilianTripTickCar(car,.05);f.syncCar();
  if(!occupied){
   if(!box._residentNativeVisitTick(npc,.05,f.now)&&npc._civilianPlan?.tripDestination){
    if(!npc._route?.length)box._maybePlanResidentBuildingVisit(npc);
    if(!npc._routeSearchPending)box.actualFootTick(npc,.05,f.now);
   }
  }
  costs.push(performance.now()-t0);counts.frames++;
  const t=box.trip(),phase=t?.phase||npc._residentNativeVisit?.phase||npc._civilianPlan?.phase||'idle';seen.add(phase);
  if(phase!==previous){traces.push({frame,timeMs:f.now,phase,npc:{r:npc.r,c:npc.c},car:{r:car.r,c:car.c},visitStatus:npc._residentVisitStatus,routePending:!!npc._routeSearchPending,planStatus:car._civilianNativePlan?.status,planReason:car._civilianNativePlan?.reason});previous=phase;}
  const carStep=Math.hypot(car.r-old.carR,car.c-old.carC),npcStep=Math.hypot(npc.r-old.r,npc.c-old.c);maxStep=Math.max(maxStep,npcStep*M);counts.carDistanceM+=carStep*M;
  if(!npc._civilianTripRiding)counts.footDistanceM+=npcStep*M;
  if(carStep>1e-9&&(!npc._civilianTripRiding||npc.hp<=0||npc.dead))carMovedWithoutDriver=true;
  if(carStep>0)assert(f.nav.query({carId:car.id,from:{r:old.carR,c:old.carC,angle:old.angle},to:{r:car.r,c:car.c,angle:car.ang},roadsOnly:false}).clear,'every actual moved car edge remains swept-clear');
  assert(npcStep<.23,'no pedestrian/seat teleport between frames');
  assert(carStep<=1.35*.05+1e-7,'car translation respects actual source speed');
  assert.equal(npcs.length,1,'source identity cannot disappear or duplicate');assert.equal(npcs[0],npc);
  assert(!npc._residentIndoors,'native visit never removes actor behind a timer');
  if(phase==='board')counts.boardFrames++;if(npc._civilianTripRiding)counts.rideFrames++;if(phase==='exit')counts.exitFrames++;if(npc._residentVisitStatus==='waiting-for-door')counts.doorWaitFrames++;if(npc._residentVisitStatus==='visiting')counts.insideFrames++;
  if(npc._residentVisitStatus==='visit-complete'){done=true;break;}
 }
}catch(e){error={message:e.message,stack:e.stack};}
costs.sort((a,b)=>a-b);
const report={scenario:'Actual native source civilian → authored car door → live seated drive → authored building entry → visible visit → physical exit',done,error,start,door,counts,phases:[...seen],trace:traces,maxNpcStepM:maxStep,carMovedWithoutDriver,cost:{p50Ms:costs[Math.floor(costs.length*.5)],p95Ms:costs[Math.floor(costs.length*.95)],maxMs:costs.at(-1)},final:{npc:{r:npc.r,c:npc.c,status:npc._residentVisitStatus,plan:npc._civilianPlan,routePending:npc._routeSearchPending,routeGoal:[npc._routeGoalR,npc._routeGoalC]},car:{r:car.r,c:car.c,nativePlan:car._civilianNativePlan},tripPhase:box.trip()?.phase},bodies:f.bodies.length,nav:f.nav.diagnostics(),limits:f.limits};
report.callsOver1Ms=f.callCosts;report.lanes=f.lanes.diagnostics();
report.closedDoorBlocks=closedDoorBlocks;
if(process.argv.includes('--measure-lane')){
 report.warmLane=[];
 for(let i=0;i<3;i++){
  const begin=performance.now(),result=f.lanes.query({mode:'lane-route',from:start.car,to:{r:door.r,c:door.c,buildingId:door.sourceId},maxSnapDistance:12});
  report.warmLane.push({elapsedMs:performance.now()-begin,status:result.status,reason:result.reason});
 }
}
fs.writeFileSync(new URL('../../../outputs/npc_civilian_actual_lifecycle_20260913.json',import.meta.url),JSON.stringify(report,null,2));
console.log(JSON.stringify({done,error,counts,phases:[...seen],cost:report.cost,final:report.final},null,2));
assert(!error,error?.message);assert(done,'actual source lifecycle must finish within bounded frames');
for(const p of ['approach','board','drive','exit','entering','browsing','exiting'])assert(seen.has(p),'required physical phase '+p);
assert(counts.carDistanceM>8);assert(counts.boardFrames>3&&counts.exitFrames>3&&counts.insideFrames>10);assert(!carMovedWithoutDriver);
assert(closedDoorBlocks,'closed door must separate actual outside/inside targets; visible state transition alone is insufficient');
console.log('PASS actual native civilian lifecycle with unchanged identity, physical boarding, swept drive, real door and visible visit/exit');
