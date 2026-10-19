import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {gunzipSync} from 'node:zlib';
import {createCivilianNativeFixture,sourceFunction} from './test_civilian_native_fixture.mjs';
import {createPrintShopServiceStation} from './native_print_shop_service_station.mjs';
import {createStationaryServiceAdapter} from './npc_stationary_service_adapter.mjs';
import {createStationaryServiceSource23} from '../../../npc_stationary_service_source23_candidate.mjs';
import {stationaryServiceWorldCandidate} from '../../../npc_stationary_service_world23_patch_candidate.mjs';
import {serviceCustomerWorldCandidate,customerServiceHelpers23} from '../../../npc_service_customer_world23_patch_candidate.mjs';
import {createServiceVisitLease23,createServiceExitMovement23} from '../../../npc_service_visit_lease23_candidate.mjs';
const snapshot=JSON.parse(gunzipSync(fs.readFileSync(new URL('test_fixtures/native_static_collision19.json.gz',import.meta.url))));
const f=await createCivilianNativeFixture({assetId:'print_shop',snapshot}),box=f.box,world=serviceCustomerWorldCandidate(stationaryServiceWorldCandidate(f.source));
new vm.Script(sourceFunction(world,'updateNpcs'));
const start=world.indexOf('const NPC_ARCHETYPES ='),end=world.indexOf('// Взвешенная выборка архетипа',start);
box.getGameHour=()=>12;vm.runInContext(world.slice(start,end)+'\nlet _residentSerial=0;let _stationaryServicePilot23=null,_stationaryServiceExitMove23=null;',box);
for(const name of ['spawnNpc','_initNpcEmotions','_pickArchetype','_installStationaryServicePilot23'])vm.runInContext(sourceFunction(world,name),box);
vm.runInContext(customerServiceHelpers23+'\n'+sourceFunction(world,'_residentNativeVisitTick'),box);
const rc=p=>({r:p.z/f.M,c:p.x/f.M}),clear=p=>!f.pedestrian.query({mode:'sweep',from:rc(p),to:rc(p),radius:.18}).blocked;
const station=createPrintShopServiceStation({THREE:f.THREE,entry:f.entry,siteRevision:'customer-world23',validateLayout:({layout})=>['spawn','doorInside','doorOutside','work','customer','customerVia'].every(k=>clear(layout[k]))}),layout=station.layout;
const originalBodies=f.entry.getCollisionBodies.bind(f.entry);f.entry.getCollisionBodies=()=>originalBodies().concat(station.getCollisionBodies());f.refreshBodies();
const actorPoint=n=>({x:n.c*f.M,y:f.floor(n.c*f.M,n.r*f.M),z:n.r*f.M});
const canSweep=(a,b)=>box._residentNativeSegmentPassable(a.r,a.c,b.r,b.c),isFloor=(p,y)=>Math.abs(f.floor(p.c*f.M,p.r*f.M)-y)<.05;
let lease;
const customerHost={validateLayout:l=>l===layout,isCurrentSite:l=>l.revision===layout.revision,now:()=>f.now,
 identity:n=>({id:n.id,generation:1}),currentVisit:n=>n._residentNativeVisit,isPresent:n=>f.npcs.includes(n),
 entranceInside:()=>door.inside,validateRoute:points=>points.slice(1).every((p,i)=>canSweep(points[i],p)&&canSweep(p,points[i])),
 employeeReady:now=>controller.lifecycle.available&&controller.lifecycle.lastNow===now,
 canControl:(n,v,now)=>f.npcs.includes(n)&&n._residentNativeVisit===v&&!n.dead&&!n._medicalDowned&&!n._policeCuffed&&!n._vehicleHijackControlled&&(!box._civilianPlanInterrupted(n,now)||v.phase==='exiting'),canSweep,isStationFloor:isFloor};
const sourceHost={validateLayout:l=>l===layout,isCurrentSite:l=>l.revision===layout.revision,groundHeight:n=>actorPoint(n).y,
 advanceServiceExit:createServiceExitMovement23({layout,host:customerHost}),
 canSpawnHidden:()=>true,canOccupySpawn:clear,canSweep,isStationFloor:isFloor,
 occupants:()=>f.npcs.map(n=>({position:actorPoint(n),radius:.18*f.M,height:n.dead?.45:1.9})),ownsServiceSlot:q=>lease?.ownsServiceSlot(q)===true};
const employeeRegistration=box._installStationaryServicePilot23(createStationaryServiceSource23,station,sourceHost),controller=employeeRegistration.controller;
for(let i=0;i<600&&controller.lifecycle.phase!=='working';i++){f.nextFrame(.05);controller.tick(f.now,.05);f.refreshBodies();}
assert.equal(controller.lifecycle.phase,'working');
lease=createServiceVisitLease23({layout,host:customerHost});
const adapter=createStationaryServiceAdapter({buildingId:layout.buildingId,getServiceAccess:({npc,visit,now})=>controller.serviceAccess({customer:{...npc,generation:1,position:actorPoint(npc)},visitId:visit.id,now})});Object.assign(adapter,lease);
const commerce=vm.runInContext('({register:_residentCommerceRegisterService,reservation:_npcActivityBuildingReservation})',box);let remove=commerce.register(layout.buildingId,adapter);
const door=box.nativeTrafficQuery({mode:'resident-access',action:'list'}).doors.find(d=>d.instanceId===layout.buildingId),doorBefore=JSON.stringify(door),cases=[];
for(const hz of [15,3])for(const cancel of [false,true]){
 const n=box.spawnNpc(300000+hz,{cityOnly:true});assert(n);
 Object.assign(n,{r:door.r,c:door.c,tr:door.r,tc:door.c,_civilianPlan:{phase:'walk_to_shop',cycle:1},_residentWallet:{balance:80,serial:0,inventory:{},receipts:[]}});f.npcs.push(n);
 assert(box._residentEnterBuilding(n,f.now,door));
 const visit=n._residentNativeVisit,originalReturn={...visit.returnPoint},trace=[];let frames=0,cancelled=false,reverse=false,sawCounter=false,lastTrace='';
 do{
  f.nextFrame(1/hz);f.refreshBodies();controller.tick(f.now,0);
  const before={r:n.r,c:n.c},route=visit._serviceRoute23;
  if(cancel&&!cancelled&&route?.index===2&&route.stage==='approach'&&Math.hypot(n.r-route.points[1].r,n.c-route.points[1].c)*f.M>.12){visit.phase='exiting';cancelled=true;}
  box._residentNativeVisitTick(n,1/hz,f.now);
  controller.tick(f.now,1/hz);
  const traceKey=[visit.phase,n._residentVisitStatus,visit._serviceRoute23?.stage,visit._serviceRoute23?.index,lease.snapshot()?.customerId].join(':');if(traceKey!==lastTrace){trace.push({at:f.now,key:traceKey,employee:controller.lifecycle.phase,employeeAvailable:controller.lifecycle.available,r:n.r,c:n.c,commerce:visit.commerce?.phase});lastTrace=traceKey;}
  assert(Math.hypot(n.r-before.r,n.c-before.c)*f.M<=Math.max(box._npcEffectiveSpeed(n)*f.M,1.25)/hz+1e-7,'no source root teleport');
  reverse||=visit._serviceRoute23?.stage==='reverse';
  if(visit.phase==='browsing'){sawCounter=true;assert(Math.hypot(n.r-layout.customer.z/f.M,n.c-layout.customer.x/f.M)*f.M<.12,'real source browsing is at counter');}
  assert(++frames<1800,JSON.stringify({hz,cancel,phase:visit.phase,status:n._residentVisitStatus,route:visit._serviceRoute23}));
 }while(n._residentNativeVisit);
 assert(reverse,'service completion/cancel physically reverses route '+JSON.stringify({hz,cancel,trace}));assert.equal(cancelled,cancel);assert.equal(sawCounter,!cancel);
 assert.equal(n._residentWallet.balance,cancel?80:77);assert.equal(n._residentWallet.receipts.length,cancel?0:1);
 assert(Math.hypot(n.r-originalReturn.r,n.c-originalReturn.c)<.026,'returns through original exit');
 assert.equal(lease.snapshot(),null);assert.equal(commerce.reservation(n),null);assert.equal(JSON.stringify(door),doorBefore);assert.deepEqual({...visit.returnPoint},originalReturn);
 cases.push({hz,cancel,frames,balance:n._residentWallet.balance,reverse});f.npcs.splice(f.npcs.indexOf(n),1);
}
{
 const buyers=[0,1].map(i=>{const n=box.spawnNpc(400000+i,{cityOnly:true});assert(n);Object.assign(n,{r:door.r,c:door.c,tr:door.r,tc:door.c,_civilianPlan:{phase:'walk_to_shop',cycle:1},_residentWallet:{balance:80,serial:0,inventory:{},receipts:[]}});f.npcs.push(n);assert(box._residentEnterBuilding(n,f.now,door));return n;});
 let frames=0,contended=false;
 while(buyers.some(n=>n._residentNativeVisit)){
  f.nextFrame(1/7);f.refreshBodies();controller.tick(f.now,0);
  for(const n of buyers)if(n._residentNativeVisit)box._residentNativeVisitTick(n,1/7,f.now);
  controller.tick(f.now,1/7);
  contended||=buyers.some(n=>n._residentNativeVisit?._serviceRoute23?.stage==='await')&&!!lease.snapshot();
  assert(buyers.filter(n=>n._residentNativeVisit?.phase==='browsing').length<=1,'one physical checkout owner');
  assert(++frames<400,'two customers finish or time out through original exit');
 }
 assert(contended);assert.deepEqual(buyers.map(n=>n._residentWallet.balance).sort((a,b)=>a-b),[77,80]);
 for(const n of buyers){assert.equal(commerce.reservation(n),null);f.npcs.splice(f.npcs.indexOf(n),1);}assert.equal(lease.snapshot(),null);
 cases.push({hz:7,concurrentCustomers:2,contended,frames});
}
for(const change of ['visit-id','ownership-counter']){
 const n=box.spawnNpc(450000,{cityOnly:true});assert(n);Object.assign(n,{r:door.r,c:door.c,tr:door.r,tc:door.c,_civilianPlan:{phase:'walk_to_shop',cycle:1},_residentWallet:{balance:80,serial:0,inventory:{},receipts:[]}});f.npcs.push(n);assert(box._residentEnterBuilding(n,f.now,door));
 const visit=n._residentNativeVisit,originalReturn={...visit.returnPoint},control=customerHost.canControl;let frames=0,changed=false,lostAt=0,reversed=false;
 while(n._residentNativeVisit){
  f.nextFrame(1/7);f.refreshBodies();controller.tick(f.now,0);
  if(!changed&&(change==='visit-id'?visit._serviceRoute23?.index===2:visit.phase==='browsing')){
   const originalId=visit.id;
   if(change==='visit-id')visit.id='replacement-visit';
   else{lostAt=f.now;customerHost.canControl=(actor,...args)=>actor!==n&&control(actor,...args);}
   changed=true;
   assert.equal(lease.ownsServiceSlot({customerId:n.id,generation:1,visitId:originalId}),false);
   assert.equal(lease.ownsServiceSlot({customerId:n.id,generation:1,visitId:visit.id}),false);
  }
  if(lostAt&&f.now-lostAt>800)customerHost.canControl=control;
  box._residentNativeVisitTick(n,1/7,f.now);controller.tick(f.now,1/7);reversed||=visit._serviceRoute23?.stage==='reverse';
  assert.equal(n._residentWallet.balance,80);assert(++frames<500,'invalid authority still physically exits');
 }
 customerHost.canControl=control;assert(changed&&reversed);assert.equal(n._residentWallet.receipts.length,0);assert.equal(lease.snapshot(),null);assert.equal(commerce.reservation(n),null);assert(Math.hypot(n.r-originalReturn.r,n.c-originalReturn.c)<.026);
 f.npcs.splice(f.npcs.indexOf(n),1);cases.push({hz:7,change,reversed,frames,balance:80});
}
{
 const n=box.spawnNpc(500000,{cityOnly:true});assert(n);Object.assign(n,{r:door.r,c:door.c,tr:door.r,tc:door.c,_civilianPlan:{phase:'walk_to_shop',cycle:1},_residentWallet:{balance:80,serial:0,inventory:{},receipts:[]}});f.npcs.push(n);assert(box._residentEnterBuilding(n,f.now,door));
 let frames=0,removed=false,recovery=false,reversed=false;
 while(n._residentNativeVisit){
  f.nextFrame(1/7);f.refreshBodies();controller.tick(f.now,0);
  if(!removed&&n._residentNativeVisit.phase==='browsing'){remove();lease.disposeServiceVisits();removed=true;}
  box._residentNativeVisitTick(n,1/7,f.now);controller.tick(f.now,1/7);recovery||=!!n._residentNativeVisit?.recovering;reversed||=n._residentNativeVisit?._serviceRoute23?.stage==='reverse';
  assert(++frames<450,JSON.stringify({removed,status:n._residentVisitStatus,r:n.r,c:n.c}));
 }
 assert(removed&&reversed&&!recovery);assert.equal(n._residentWallet.balance,80);assert.equal(commerce.reservation(n),null);assert.equal(lease.snapshot(),null);f.npcs.splice(f.npcs.indexOf(n),1);
 cases.push({hz:7,providerRemoved:true,reversed,recovery,frames});
}
remove();employeeRegistration.unregister();station.dispose();f.entry.getCollisionBodies=originalBodies;f.entry.dispose();
const report={pass:true,cases,limits:'Actual source factory/entryAlignment/native visit tick/checkout/reservation release with proposed route hooks, actual GLB/floor/public+service doors/capsule sweeps. Source employee ordinary body. Camera hidden proof and full-city dynamic body coverage remain host boundaries. No world/Walk activation/renderer/LIVE/FPS.'};
fs.writeFileSync(new URL('../../../outputs/npc_service_customer_world23_candidate.json',import.meta.url),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
