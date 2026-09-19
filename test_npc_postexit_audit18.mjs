// Read-only post-exit audit: actual ordinary foot scheduling, no manual visit retry.
import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
import {stageCivilianExactTail} from './test_npc_postexit_candidate18.mjs';
import {stageNpcRoadEgress} from './test_npc_road_egress_candidate18.mjs';
const candidate=process.argv.includes('--dedupe');
const applied=fs.readFileSync('world.html','utf8').includes('const roadExit=_npcPlanRoadExit(npc,now);');
const egress=applied||process.argv.includes('--egress');
const reports=[];
for(const mode of ['normal','pending','recovery','recovery-stale-pending']){
 const f=await createCivilianNativeFixture(),b=f.box,door=b._residentBuildingDoors()[0];
 const source=egress?stageNpcRoadEgress(f.source):f.source;
 vm.runInContext(f.source.slice(f.source.indexOf('// CIVILIAN_PURPOSEFUL_PLANS_START'),f.source.indexOf('// CIVILIAN_PURPOSEFUL_PLANS_END')),b);
 if(candidate)vm.runInContext(stageCivilianExactTail(sourceFunction(f.source,'_civilianRouteTo')),b);
 for(const name of ['_civilianVisitOfferReady','pickNpcWaypoint'])vm.runInContext(sourceFunction(source,name),b);
 if(egress){
  if(typeof b._npcPlanRoadExit!=='function')vm.runInContext(fs.readFileSync('assets/maps/city_rebuild_v1/npc_road_egress_source.js','utf8'),b);
  for(const name of ['_planNpcRouteTo','_civilianArrivalRadius'])vm.runInContext(sourceFunction(source,name),b);
  const end=source.indexOf('  // Entries are collected after iteration'),start=source.lastIndexOf('    if (now < n.idleUntil)',end),foot=source.slice(start,end).replace(/\s*}\s*$/,'');
  vm.runInContext('globalThis.actualFootTick=(npc,dt,now)=>{for(const n of [npc]){const civilianRoutineDt=_npcConsumeCivilianElapsed(n,dt,now);'+foot+'}};',b);
 }
 b._npcRoutineFor=()=> 'errands';b.getGameHour=()=>12;
 const options=f.nav.query({mode:'road-targets',carId:f.car.id,from:{r:door.r,c:door.c,angle:0},minDistance:2,maxDistance:8})?.points||[];
 let access;
 for(const p of options){Object.assign(f.car,{r:p.r,c:p.c,ang:p.angle,dirDy:Math.sin(p.angle),dirDx:Math.cos(p.angle)});f.syncCar();f.pedestrian.beginFrame();const a=f.access({carId:f.car.id});if(a&&b._npcBodyPassable(a.outside.r,a.outside.c,b.npcPassableForSnitch)){access=a;break;}}
 assert(access,'actual car exit required');
 const n={id:'resident_postexit_'+mode,r:access.outside.r,c:access.outside.c,tr:access.outside.r,tc:access.outside.c,hp:100,max_hp:100,speed:1,walkPhase:0,idleUntil:0,alive:true,_npcRoutine:'errands',_civilianPlan:{phase:'seek_shop',cycle:0}};
 f.npcs.push(n);
 if(mode==='recovery-stale-pending'){n._routeSearchPending=true;n._routeSearchKind='building_entry';n._npcDirectedSearch={algorithm:'old-visit'};}
 const trip={npc:n,car:f.car,carId:f.car.id,phase:'exit',exit:{...access.outside},access,doorLength:1,since:f.now,plan:{native:true,points:[],goal:{door},lots:[]},interrupted:mode.startsWith('recovery'),recovery:mode.startsWith('recovery')?{reason:'drive-no-progress'}:null};
 assert(b._civilianTripRegister(trip));
 if(mode==='pending')b._npcReserveRouteWork=()=>false;
 f.nextFrame(.05);assert(b._civilianTripTickNpc(n,.05,f.now));assert(!b._civilianTripForNpc(n));
 if(mode==='pending')vm.runInContext(sourceFunction(f.source,'_npcReserveRouteWork'),b);
 const start={r:n.r,c:n.c},states=new Set(),trace=[],egressCosts=[];let moved=0,firstMove=null,entered=false;
 if(egress){const original=b._npcPlanRoadExit;b._npcPlanRoadExit=(...args)=>{const at=performance.now(),result=original(...args);egressCosts.push(performance.now()-at);return result;};}
 for(let frame=0;frame<1200;frame++){
  f.nextFrame(.05);const previous={r:n.r,c:n.c};
  if(!b._residentNativeVisitTick(n,.05,f.now))b.actualFootTick(n,.05,f.now);
  const step=Math.hypot(n.r-previous.r,n.c-previous.c)*f.M;moved+=step;if(step>1e-7&&firstMove===null)firstMove=f.now;
  assert(step<=.083,'each physical source step stays within actual walking speed');
  if(step>0)assert(b._npcPathPassable(previous.r,previous.c,n.r,n.c,b.npcPassableForSnitch),'actual exit/walk/visit retains body+continuous sweep');
  if(n._residentNativeVisit)entered=true;
  const state=[n._civilianPlan?.phase,n._residentVisitStatus,n._routeSearchPending,n._routeKind,!!n._npcWanderSearch].join('|');
  if(!states.has(state)){states.add(state);trace.push({at:f.now,state,r:n.r,c:n.c,tr:n.tr,tc:n.tc});}
  if(n._residentVisitStatus==='visit-complete'||mode.startsWith('recovery')&&moved>5&&(!egress||n._roadExitStatus==='complete'))break;
 }
 if((candidate||applied)&&!mode.startsWith('recovery'))assert(entered&&n._residentVisitStatus==='visit-complete',mode+': physical destination visit completes through ordinary foot branch');
 if(egress&&mode==='recovery')assert(moved>5&&n._roadExitStatus==='complete'&&n._routeKind==='walk','recovery physically exits road and resumes ordinary walk');
 reports.push({mode,start,surface:f.pedestrian.query(start)?.surface,doorDistanceM:Math.hypot(start.r-door.r,start.c-door.c)*f.M,moved,firstMove,entered,egressCpu:{calls:egressCosts.length,totalMs:egressCosts.reduce((a,b)=>a+b,0),maxMs:Math.max(0,...egressCosts)},final:{r:n.r,c:n.c,plan:n._civilianPlan,pending:n._routeSearchPending,kind:n._routeSearchKind,status:n._residentVisitStatus,roadExit:n._roadExitStatus},trace});
}
console.log(JSON.stringify({candidate,applied,egress,reports,limit:'CPU real native car exit placement/static/door/water and actual source trip release, ordinary foot and waypoint functions. Controlled pending case only alters first planner admission; no production world edits or GPU.'},null,2));
