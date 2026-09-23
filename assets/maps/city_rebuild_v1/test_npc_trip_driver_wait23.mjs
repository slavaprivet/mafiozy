// Actual production source/geometry regression for bounded driver readiness.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';
import {createNpcLogicalVehicleBinding} from './npc_logical_vehicle_binding.mjs';

async function run({resumeAtMs=Infinity,missingAt='first-point'}={}){
 const f=await createCivilianNativeFixture(),{box,car,npcs,M}=f;
 const destination=box._residentBuildingDoors()[0];
 const slots=f.lanes.query({mode:'parking-anchors'}).slots.sort((a,b)=>Math.hypot(a.r-destination.r,a.c-destination.c)-Math.hypot(b.r-destination.r,b.c-destination.c));
 const npcObject=new f.THREE.Object3D();f.scene.add(npcObject);
 const logical=createNpcLogicalVehicleBinding({bridge:{getWalkNpcVehicleBinding:q=>box._getWalkNpcVehicleBinding(q),getWalkNpcVehicleTraffic:()=>box._getWalkNpcVehicleTraffic()},worldScale:M,groundHeight:f.floor,getTemplate:()=>f.actor,getVisibleVehicle:()=>f.actor,getVisibleNpc:()=>npcObject.parent?{object:npcObject}:null});
 const nav=box.nativeTrafficQuery;
 box.nativeTrafficQuery=q=>q.mode==='driver'?logical.driver(q):q.mode==='parking-anchors'?{ready:true,slots}:q.mode==='parking-exit'?f.lanes.query(q):q.mode==='initial-vehicle-shape'?{ready:true,halfLength:f.actor.profile.halfLength/M,halfWidth:f.actor.profile.halfWidth/M}:nav(q);
 vm.runInContext('_walkTrafficNavigationResolver=nativeTrafficQuery;',box);
 box._nativeParkingPrepare(car);
 for(let i=0;i<500&&car._nativeParkingPending;i++){f.nextFrame(.05);box._nativeParkingAdmissionTick(f.now);}
 assert(!car._nativeParkingPending);f.syncCar();f.pedestrian.beginFrame();
 const access=f.access({carId:car.id});assert(access);
 const npc={id:'driver_wait_resident23',r:access.outside.r,c:access.outside.c,hp:100,max_hp:100,alive:true,_arcKey:'worker',_npcRoutine:'errands',walkPhase:0};npcs.push(npc);box.player={r:car.r+10,c:car.c+10};
 box._npcAgendaAdopt(npc,'drive');assert(box._npcAgendaTryDrive(npc,f.now));
 let started=null,readyAt=null,releasedAt=null,missingBinding=null,distanceM=0,distanceAtLoss=null,maxNpcStepM=0,last={r:car.r,c:car.c};const phases=['planning'],costs=[];
 for(let frame=0;frame<6500;frame++){
  f.nextFrame(.05);
  const npcBefore={r:npc.r,c:npc.c},tickStart=performance.now();
  box._civilianTripTickNpc(npc,.05,f.now);
  const t=box.trip();
  if(t?.phase==='drive'&&started===null&&(missingAt==='first-point'||t.index>=t.plan.points.length)){started=f.now;distanceAtLoss=distanceM;npcObject.removeFromParent();missingBinding=logical.driver({carId:car.id,npcId:npc.id});assert.deepEqual(missingBinding,{ready:false,mode:'visible'});if(missingAt==='first-point')assert(Math.hypot(t.plan.points[t.index].r-car.r,t.plan.points[t.index].c-car.c)<.03,'actual route starts at current car pose');}
  if(started!==null&&f.now-started>=resumeAtMs&&readyAt===null){readyAt=f.now;f.scene.add(npcObject);}
  box._civilianTripTickCar(car,.05);costs.push(performance.now()-tickStart);f.syncCar();
  const npcStep=Math.hypot(npc.r-npcBefore.r,npc.c-npcBefore.c)*M;maxNpcStepM=Math.max(maxNpcStepM,npcStep);assert(npcStep<.23*M,'no body/seat teleport');
  distanceM+=Math.hypot(car.r-last.r,car.c-last.c)*M;last={r:car.r,c:car.c};
  const phase=box.trip()?.phase||'released';if(phases.at(-1)!==phase)phases.push(phase);
  if(started!==null&&!box.trip()){releasedAt=f.now;break;}
  if(started!==null&&resumeAtMs===Infinity&&f.now-started>110000)break;
 }
 assert.notEqual(started,null,'actual agenda→reserve→plan→board must reach drive');
 costs.sort((a,b)=>a-b);
 const result={missingAt,resumeAtMs:Number.isFinite(resumeAtMs)?resumeAtMs:null,started,readyAt,releasedAt,missingBinding,phases,distanceM,distanceAtLoss,maxNpcStepM,cpu:{p50Ms:costs[Math.floor(costs.length*.5)],p95Ms:costs[Math.floor(costs.length*.95)]},active:!!box.trip(),phase:box.trip()?.phase||null,driverNotReady:!!car._civilianDriverNotReady,noProgressMs:box.trip()?.physicalProgress?f.now-box.trip().physicalProgress.at:null,agenda:structuredClone(npc._npcAgenda),position:{r:npc.r,c:npc.c},carPosition:{r:car.r,c:car.c},limits:f.limits+' Actual logical binding evaluates missing near NPC scene object; stand-in Object3D models presentation availability only, not NPC skinning. CPU tick timing is not scene FPS.'};
 if(resumeAtMs===Infinity){assert(!result.active);assert.equal(result.distanceM,distanceAtLoss);assert.equal(result.agenda.lastResult.reason,'interrupted-exited');assert(result.phases.includes('exit'));assert.equal(result.agenda.current,'walk');}
 else{assert(!result.active);assert(result.distanceM>8);assert(result.phases.includes('exit'));assert.equal(result.agenda.lastResult.reason,'arrived');}
 return result;
}
const results=[];
for(const scenario of [{},{resumeAtMs:10000},{missingAt:'last-point'}]){results.push(await run(scenario));console.log(JSON.stringify(results.at(-1),null,2));}
fs.writeFileSync(new URL('../../../outputs/npc_trip_driver_wait23.json',import.meta.url),JSON.stringify({results,productionEdited:true},null,2));
console.log('PASS actual source driver readiness timeout, transient recovery and final-waypoint release');
