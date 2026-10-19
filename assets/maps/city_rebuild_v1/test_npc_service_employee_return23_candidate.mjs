import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {gunzipSync} from 'node:zlib';
import {createCivilianNativeFixture,sourceFunction} from './test_civilian_native_fixture.mjs';
import {createPrintShopServiceStation} from './native_print_shop_service_station.mjs';
import {createServiceEmployeeReturn23} from '../../../npc_service_employee_return23_candidate.mjs';
import {employeeReturnControllerCandidate,employeeReturnWorldCandidate,employeeReturnSourceHost23} from '../../../npc_service_employee_return23_patch_candidate.mjs';
const controllerText=employeeReturnControllerCandidate(fs.readFileSync(new URL('../../../npc_stationary_service_source23_candidate.mjs',import.meta.url),'utf8')).replaceAll("from './","from '"+new URL('../../../',import.meta.url).href);
const {createStationaryServiceSource23}=await import('data:text/javascript;base64,'+Buffer.from(controllerText).toString('base64'));
import {stationaryServiceWorldCandidate} from '../../../npc_stationary_service_world23_patch_candidate.mjs';
import {serviceCustomerWorldCandidate,customerServiceHelpers23} from '../../../npc_service_customer_world23_patch_candidate.mjs';
const snapshot=JSON.parse(gunzipSync(fs.readFileSync(new URL('test_fixtures/native_static_collision19.json.gz',import.meta.url))));
const f=await createCivilianNativeFixture({assetId:'print_shop',snapshot}),box=f.box,world=employeeReturnWorldCandidate(serviceCustomerWorldCandidate(stationaryServiceWorldCandidate(f.source)));
new vm.Script(sourceFunction(world,'updateNpcs'));
const start=world.indexOf('const NPC_ARCHETYPES ='),end=world.indexOf('// Взвешенная выборка архетипа',start);
box.getGameHour=()=>12;vm.runInContext(world.slice(start,end)+'\nlet _residentSerial=0;let _stationaryServicePilot23=null,_stationaryServiceExitMove23=null;',box);
vm.runInContext(employeeReturnSourceHost23,box);
for(const name of ['spawnNpc','_initNpcEmotions','_pickArchetype','_installStationaryServicePilot23'])vm.runInContext(sourceFunction(world,name),box);
vm.runInContext(customerServiceHelpers23+'\n'+sourceFunction(world,'_residentNativeVisitTick'),box);
const rc=p=>({r:p.z/f.M,c:p.x/f.M}),clear=p=>!f.pedestrian.query({mode:'sweep',from:rc(p),to:rc(p),radius:.18}).blocked;
const station=createPrintShopServiceStation({THREE:f.THREE,entry:f.entry,siteRevision:'customer-world23',validateLayout:({layout})=>['spawn','doorInside','doorOutside','work','customer','customerVia'].every(k=>clear(layout[k]))}),layout=station.layout;
let movingBodies=[];const originalBodies=f.entry.getCollisionBodies.bind(f.entry);f.entry.getCollisionBodies=()=>originalBodies().concat(station.getCollisionBodies(),movingBodies);f.refreshBodies();
const actorPoint=n=>({x:n.c*f.M,y:f.floor(n.c*f.M,n.r*f.M),z:n.r*f.M});
const canSweep=(a,b)=>box._residentNativeSegmentPassable(a.r,a.c,b.r,b.c),isFloor=(p,y)=>Math.abs(f.floor(p.c*f.M,p.r*f.M)-y)<.05;
const plannerStats={ready:0,pending:0,blocked:0};let capturedHost,capturedReturnHost;
const sourceHost={createEmployeeReturn:input=>{capturedReturnHost=input.host;const plan=input.host.planRoute;input.host.planRoute=(...args)=>{const result=plan(...args);plannerStats[result.status]++;return result;};return createServiceEmployeeReturn23(input);},employeeReturnGeometry:{validateLayout:l=>l===layout,isCurrentSite:l=>l===layout,canSweep,isWorkFloor:isFloor,groundHeight:p=>f.floor(p.c*f.M,p.r*f.M),hasGround:p=>Number.isFinite(f.floor(p.c*f.M,p.r*f.M))&&!(f.waterAt(p.c*f.M,p.r*f.M)?.depth>.6)},validateLayout:l=>l===layout,isCurrentSite:l=>l.revision===layout.revision,groundHeight:n=>actorPoint(n).y,
 canSpawnHidden:()=>true,canOccupySpawn:clear,canSweep,isStationFloor:isFloor,
 occupants:()=>f.npcs.map(n=>({position:actorPoint(n),radius:.18*f.M,height:n.dead?.45:1.9})),ownsServiceSlot:()=>false};
const employeeRegistration=box._installStationaryServicePilot23(input=>{capturedHost=input.host;return createStationaryServiceSource23(input);},station,sourceHost),controller=employeeRegistration.controller;
for(let i=0;i<600&&controller.lifecycle.phase!=='working';i++){f.nextFrame(.05);controller.tick(f.now,.05);f.refreshBodies();}
assert.equal(controller.lifecycle.phase,'working');
const door=box.nativeTrafficQuery({mode:'resident-access',action:'list'}).doors.find(d=>d.instanceId===layout.buildingId),n=controller.actor,cases=[];
const outside={r:door.r,c:door.c};
// Test placement supplies the externally owned panic endpoint only. Every return step is executed by source movement.
for(const hz of [15,3])for(const path of ['direct','planned']){
 const start=path==='direct'?{r:outside.r,c:outside.c+3}:{r:outside.r-4,c:outside.c-4};assert(canSweep(start,start),'remote source endpoint is walkable');
 Object.assign(n,start);n.tr=n.r;n.tc=n.c;n.panicUntil=f.now+500;
 const before={r:n.r,c:n.c};controller.tick(f.now,1/hz);assert.deepEqual({r:n.r,c:n.c},before);assert.equal(controller.lifecycle.available,false);
 let frames=0,opened=false,crossed=false,paused=false,last=null,trace=[],obstructed=false,barrierUntil=0;
 do{
  f.nextFrame(1/hz);f.refreshBodies();const before={r:n.r,c:n.c};
  if(!paused&&Math.hypot(n.r-outside.r,n.c-outside.c)<1.2){n.panicUntil=f.now+500;paused=true;}
  if(last==='door'&&!obstructed){
   const c=door.c-.4,r=door.r;movingBodies=[{polygonCR:[[c-.03,r-.8],[c+.03,r-.8],[c+.03,r+.8],[c-.03,r+.8]],minYM:-1,maxYM:3}];barrierUntil=f.now+800;obstructed=true;f.refreshBodies();f.pedestrian.beginFrame();
  }
  if(barrierUntil&&f.now>=barrierUntil){movingBodies=[];barrierUntil=0;f.refreshBodies();f.pedestrian.beginFrame();}
  const result=controller.tick(f.now,1/hz),delta=Math.hypot(n.r-before.r,n.c-before.c)*f.M;
  assert(delta<=1.25/hz+1e-7,'bounded physical return, no teleport');
  if(n.panicUntil>f.now)assert.equal(delta,0,'panic owns source body');
  if(barrierUntil)assert.equal(delta,0,'actual temporary doorway collider blocks entry');
  if(result.movement?.returnStage!==last){last=result.movement?.returnStage;trace.push({stage:last,status:result.movement?.status,reason:result.movement?.reason,r:n.r,c:n.c});}
  opened||=last==='door';crossed||=Math.hypot(n.r-door.inside.r,n.c-door.inside.c)<.12;
  assert(++frames<1600,JSON.stringify({hz,result,trace,r:n.r,c:n.c,floor:actorPoint(n).y}));
 }while(!controller.lifecycle.available||controller.lifecycle.phase!=='working');
 assert(opened&&crossed&&paused&&obstructed);assert.equal(controller.lifecycle.available,true);assert(Math.hypot(n.r-layout.work.z/f.M,n.c-layout.work.x/f.M)*f.M<.12);
 cases.push({hz,path,frames,opened,crossed,secondPanicPaused:paused,temporaryDoorwayCollider:obstructed});
}
const denied=[];
Object.assign(n,{r:outside.r,c:outside.c+3});n.panicUntil=0;
function noMove(label,dt=1/7){const before={r:n.r,c:n.c};controller.tick(f.now,dt);assert.deepEqual({r:n.r,c:n.c},before,label);assert.equal(controller.lifecycle.available,false);denied.push(label);}
noMove('elapsed gap does not consume stale time',2);
noMove('freshness tick0 cannot move',0);
const currentSite=capturedReturnHost.isCurrentSite;capturedReturnHost.isCurrentSite=()=>false;noMove('return addon rejects stale site');capturedReturnHost.isCurrentSite=currentSite;
const ground=capturedReturnHost.hasGround;capturedReturnHost.hasGround=()=>false;noMove('unsupported ground blocks return');capturedReturnHost.hasGround=ground;
const index=f.npcs.indexOf(n);f.npcs.splice(index,1);noMove('removed source body cannot move');f.npcs.splice(index,0,n);
const marker=n._stationaryService;n._stationaryService={...marker,generation:marker.generation+1};noMove('mutated generation cannot move');n._stationaryService=marker;
const swept=capturedReturnHost.canSweep;capturedReturnHost.canSweep=(...args)=>{const result=swept(...args);n.panicUntil=f.now+1000;return result;};noMove('ownership lost during geometry query prevents source write');capturedReturnHost.canSweep=swept;
n.panicUntil=0;
for(let i=0;!controller.lifecycle.available&&i<500;i++){f.nextFrame(1/7);controller.tick(f.now,1/7);}
assert(controller.lifecycle.available,'same live body returns after gates restored');
assert(plannerStats.ready>0&&plannerStats.pending>0,'actual native budget continuation was consumed');
const addon=capturedHost.advanceEmployeeReturn,baseCosts=[],addonCosts=[];
for(let i=0;i<300;i++)for(const enabled of [false,true]){capturedHost.advanceEmployeeReturn=enabled?addon:null;const before=performance.now();controller.tick(f.now,0);const cost=performance.now()-before;if(i>=50)(enabled?addonCosts:baseCosts).push(cost);}
capturedHost.advanceEmployeeReturn=addon;
const stats=values=>{values.sort((a,b)=>a-b);return{p50ms:values[Math.floor(values.length*.5)],p95ms:values[Math.floor(values.length*.95)]};};
const cpu={scenario:'one working source employee, same station/camera-free geometry, alternating idle tick0 with return hook off/on, 50 warm+250 samples',withoutReturnHook:stats(baseCosts),withReturnHook:stats(addonCosts)};
employeeRegistration.unregister();station.dispose();f.entry.getCollisionBodies=originalBodies;f.entry.dispose();
const report={pass:true,cases,denied,plannerStats,cpu,limits:'Actual source body and source-owned public access/entryLane, actual GLB/capsule/floors. Panic endpoints staged by fixture; no full-world panic simulation, camera/renderer/FPS or activation.'};
fs.writeFileSync(new URL('../../../outputs/npc_service_employee_return23_candidate.json',import.meta.url),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));

