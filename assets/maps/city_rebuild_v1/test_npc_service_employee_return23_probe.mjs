import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {gunzipSync} from 'node:zlib';
import {createCivilianNativeFixture,sourceFunction} from './test_civilian_native_fixture.mjs';
import {createPrintShopServiceStation} from './native_print_shop_service_station.mjs';
import {createStationaryServiceAdapter} from './npc_stationary_service_adapter.mjs';
import {createServiceEmployeeReturn23} from '../../../npc_service_employee_return23_candidate.mjs';
import {employeeReturnControllerCandidate,employeeReturnWorldCandidate,employeeReturnSourceHost23} from '../../../npc_service_employee_return23_patch_candidate.mjs';
const controllerText=employeeReturnControllerCandidate(fs.readFileSync(new URL('../../../npc_stationary_service_source23_candidate.mjs',import.meta.url),'utf8')).replaceAll("from './","from '"+new URL('../../../',import.meta.url).href);
const {createStationaryServiceSource23}=await import('data:text/javascript;base64,'+Buffer.from(controllerText).toString('base64'));
import {stationaryServiceWorldCandidate} from '../../../npc_stationary_service_world23_patch_candidate.mjs';
import {serviceCustomerWorldCandidate,customerServiceHelpers23} from '../../../npc_service_customer_world23_patch_candidate.mjs';
import {createServiceVisitLease23,createServiceExitMovement23} from '../../../npc_service_visit_lease23_candidate.mjs';
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
const originalBodies=f.entry.getCollisionBodies.bind(f.entry);f.entry.getCollisionBodies=()=>originalBodies().concat(station.getCollisionBodies());f.refreshBodies();
const actorPoint=n=>({x:n.c*f.M,y:f.floor(n.c*f.M,n.r*f.M),z:n.r*f.M});
const canSweep=(a,b)=>box._residentNativeSegmentPassable(a.r,a.c,b.r,b.c),isFloor=(p,y)=>Math.abs(f.floor(p.c*f.M,p.r*f.M)-y)<.05;
let lease;
const customerHost={validateLayout:l=>l===layout,isCurrentSite:l=>l.revision===layout.revision,now:()=>f.now,
 identity:n=>({id:n.id,generation:1}),currentVisit:n=>n._residentNativeVisit,isPresent:n=>f.npcs.includes(n),
 entranceInside:()=>door.inside,validateRoute:points=>points.slice(1).every((p,i)=>canSweep(points[i],p)&&canSweep(p,points[i])),
 employeeReady:now=>controller.lifecycle.available&&controller.lifecycle.lastNow===now,
 canControl:(n,v,now)=>f.npcs.includes(n)&&n._residentNativeVisit===v&&!n.dead&&!n._medicalDowned&&!n._policeCuffed&&!n._vehicleHijackControlled&&(!box._civilianPlanInterrupted(n,now)||v.phase==='exiting'),canSweep,isStationFloor:isFloor};
const sourceHost={createEmployeeReturn:createServiceEmployeeReturn23,employeeReturnGeometry:{validateLayout:l=>l===layout,isCurrentSite:l=>l===layout,canSweep,isWorkFloor:isFloor,groundHeight:p=>f.floor(p.c*f.M,p.r*f.M),hasGround:p=>Number.isFinite(f.floor(p.c*f.M,p.r*f.M))&&!(f.waterAt(p.c*f.M,p.r*f.M)?.depth>.6)},validateLayout:l=>l===layout,isCurrentSite:l=>l.revision===layout.revision,groundHeight:n=>actorPoint(n).y,
 advanceServiceExit:createServiceExitMovement23({layout,host:customerHost}),
 canSpawnHidden:()=>true,canOccupySpawn:clear,canSweep,isStationFloor:isFloor,
 occupants:()=>f.npcs.map(n=>({position:actorPoint(n),radius:.18*f.M,height:n.dead?.45:1.9})),ownsServiceSlot:q=>lease?.ownsServiceSlot(q)===true};
const employeeRegistration=box._installStationaryServicePilot23(createStationaryServiceSource23,station,sourceHost),controller=employeeRegistration.controller;
for(let i=0;i<600&&controller.lifecycle.phase!=='working';i++){f.nextFrame(.05);controller.tick(f.now,.05);f.refreshBodies();}
assert.equal(controller.lifecycle.phase,'working');
const door=box.nativeTrafficQuery({mode:'resident-access',action:'list'}).doors.find(d=>d.instanceId===layout.buildingId),n=controller.actor,cases=[];
const outside={r:door.r,c:door.c};
const host=box._stationaryServiceReturnHost23(),reports=[];
for(const [dr,dc] of [[4,-4],[-4,-4],[5,0],[-5,0],[5,-7],[-5,-7],[8,-8],[-8,-8]]){
 const at={r:outside.r+dr,c:outside.c+dc};if(!canSweep(at,at)){reports.push({dr,dc,occupied:true});continue;}
 Object.assign(n,at);host.cancelRoute(n);let route,frames=0;do{f.nextFrame(.05);route=host.planRoute(n,outside);}while(route.status==='pending'&&++frames<100);
 reports.push({dr,dc,direct:canSweep(at,outside),status:route.status,points:route.points?.length,frames});
}
console.log(JSON.stringify(reports));employeeRegistration.unregister();station.dispose();f.entry.dispose();
