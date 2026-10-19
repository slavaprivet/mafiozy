import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {gunzipSync} from 'node:zlib';
import {createCivilianNativeFixture,sourceFunction} from './test_civilian_native_fixture.mjs';
import {createIncrementalWalkCollisionIndex} from './incremental_walk_collision_index.mjs';
import {createNpcNativeNavigation} from './npc_native_navigation.mjs';
import {pointInPolygon} from './car_drive.mjs';
import {stationaryServiceWorldCandidate} from '../../../npc_stationary_service_world23_patch_candidate.mjs';
import {serviceCustomerWorldCandidate,customerServiceHelpers23} from '../../../npc_service_customer_world23_patch_candidate.mjs';
import {employeeReturnControllerCandidate,employeeReturnWorldCandidate,employeeReturnSourceHost23} from '../../../npc_service_employee_return23_patch_candidate.mjs';
import {serviceMerchantWorldCandidate,serviceMerchantSource23,serviceMerchantControllerCandidate,serviceMerchantWalkCandidate} from '../../../npc_stationary_service_activation23_patch_candidate.mjs';
import {servicePhysicalRosterWorldCandidate} from '../../../npc_service_physical_roster23_patch_candidate.mjs';
import {createStationaryServiceWalk23} from './service_pilot23_candidate/walk_host.mjs';
import {createStationaryServiceSource23} from './service_pilot23_candidate/source.mjs';
const snapshot=JSON.parse(gunzipSync(fs.readFileSync(new URL('test_fixtures/native_static_collision19.json.gz',import.meta.url))));
const f=await createCivilianNativeFixture({assetId:'print_shop',snapshot}),box=f.box,T=f.THREE;
const world=servicePhysicalRosterWorldCandidate(serviceMerchantWorldCandidate(employeeReturnWorldCandidate(serviceCustomerWorldCandidate(stationaryServiceWorldCandidate(f.source)))));
new vm.Script(sourceFunction(world,'updateNpcs'));
const walk=serviceMerchantWalkCandidate(fs.readFileSync(new URL('walk_preview.mjs',import.meta.url),'utf8'));
new vm.Script(sourceFunction(walk,'ensureStationaryServiceWalk23'));
assert(walk.includes('stationaryServiceWalk23?.syncCollision();'));
const start=world.indexOf('const NPC_ARCHETYPES ='),end=world.indexOf('// Взвешенная выборка архетипа',start);
Object.assign(box,{getGameHour:()=>12,_buildingInt:null,_bankInt:null,_customGang:null,_murderPoliceArrest:null,CORPSE_AUTO_REMOVE_MS:300000});
vm.runInContext(world.slice(start,end)+'\nlet _residentSerial=0;let _stationaryServicePilot23=null,_stationaryServiceExitMove23=null;const _threeNpcIds=new WeakMap();let _threeNpcIdSeq=0;',box);
vm.runInContext(employeeReturnSourceHost23+'\n'+serviceMerchantSource23+'\n'+customerServiceHelpers23,box);
for(const name of ['spawnNpc','_initNpcEmotions','_pickArchetype','_installStationaryServicePilot23','_residentNativeVisitTick','_residentServiceYield23','_getWalkServicePhysicalBodies23','_threeNpcEntityId','_corpseRemovalDue','_npcLogicalVehicleRow','_getWalkNpcVehicleTraffic'])vm.runInContext(sourceFunction(world,name),box);
const bridge={installStationaryServiceMerchant23:(...args)=>box._installStationaryServiceMerchant23(...args),getWalkServicePhysicalBodies23:q=>box._getWalkServicePhysicalBodies23(q),getWalkNpcVehicleTraffic:()=>box._getWalkNpcVehicleTraffic()};
const index=createIncrementalWalkCollisionIndex();index.replaceGroup('fixture-world',f.bodies);
const nav=createNpcNativeNavigation({worldScale:f.M,groundHeight:f.floor,waterAt:f.waterAt,bodiesAt:(c,r)=>index(c,r),bodiesInBounds:(...args)=>index.queryBounds(...args),containsBody:(b,r,c)=>pointInPolygon(c,r,b.polygonCR),terrainAllows:(x,z)=>f.pedestrian.query({r:z/f.M,c:x/f.M}).blocked===false});
const door=box.nativeTrafficQuery({mode:'resident-access',action:'list'}).doors.find(d=>d.instanceId===f.item.id),hero={object:new T.Group()},camera=new T.PerspectiveCamera(55,1.6,.05,1500),actors=new Map();
f.scene.add(hero.object);hero.object.position.set(door.c*f.M+20,2,door.r*f.M);camera.position.copy(hero.object.position).add(new T.Vector3(0,2,0));camera.lookAt(hero.object.position.x+30,2,hero.object.position.z);camera.updateMatrixWorld(true);
let pilot,fleetRows=[];const baseBodies=f.entry.getCollisionBodies.bind(f.entry);f.entry.getCollisionBodies=()=>baseBodies().concat(pilot?.station.getCollisionBodies()||[]);
const host={getEntries:()=>[f.entry],ready:()=>true,getCollisionIndex:()=>index,invalidateNavigation:()=>nav.beginFrame(),nativeQuery:nav.query,groundHeight:f.floor,ceilingHeight:(x,z,y)=>f.entry.ceilingHeight({x,y,z})??Infinity,waterAt:f.waterAt,getCamera:()=>camera,getHero:()=>hero,heroBody:()=>({radius:.738,height:1.9}),getNpcActors:()=>[...actors].map(([id,object])=>({id,object,source:{id}})),getNpcActor:id=>actors.has(id)?{object:actors.get(id)}:null,getFleet:()=>fleetRows,getTrafficActors:()=>[]};
pilot=createStationaryServiceWalk23({THREE:T,bridge,host,siteRevision:'walk-host23',sourceFactory:createStationaryServiceSource23});assert(pilot);
function frame(dt=.05,{render=true}={}){
 f.nextFrame(dt);f.refreshBodies();index.replaceGroup('fixture-world',f.bodies);nav.beginFrame();pilot.syncCollision();
 if(render)for(const n of f.npcs){const id=box._threeNpcEntityId(n);if(!actors.has(id)){const object=new T.Group();f.scene.add(object);actors.set(id,object);}actors.get(id).position.set(n.c*f.M,f.floor(n.c*f.M,n.r*f.M),n.r*f.M);}
 return pilot.controller.tick(f.now,dt);
}
for(let i=0;i<10&&!pilot.controller.actor;i++)frame(.1,{render:false});assert(pilot.controller.actor,'real source birth in hidden backroom');
const employee=pilot.controller.actor,atBirth={r:employee.r,c:employee.c};
for(let i=0;i<5;i++)frame(.05,{render:false});assert.deepEqual({r:employee.r,c:employee.c},atBirth,'nearby source waits for actual model admission');
for(let i=0;i<700&&!pilot.controller.lifecycle.available;i++)frame(.05);
assert(pilot.controller.lifecycle.available,JSON.stringify({stats:pilot.controller.stats,position:{r:employee.r,c:employee.c},result:frame(.05)}));
let cpu=null;
if(process.env.SERVICE_HOST_PERF23==='1'){
 const population=Array.from({length:384},(_,i)=>({id:'perf_body_'+i,r:100+i*.02,c:100,hp:60}));f.npcs.push(...population);
 const at={r:pilot.station.layout.spawn.z/f.M,c:pilot.station.layout.spawn.x/f.M};
 const measure=fn=>{for(let i=0;i<30;i++)fn();const samples=[];for(let i=0;i<120;i++){const start=performance.now();fn();samples.push(performance.now()-start);}samples.sort((a,b)=>a-b);return{p50:samples[60],p95:samples[114]};};
 cpu={units:'ms',population:384,scenario:'warmed identical point at storeroom, all far source bodies still enumerated',nativePoint:measure(()=>host.nativeQuery({mode:'sweep',from:at,to:at,radius:.18})),composedPoint:measure(()=>pilot.canSweep(at,at,null)),idleController:measure(()=>pilot.controller.tick(f.now,0)),limits:'CPU fixture only; no renderer or whole-scene frame time'};
 for(const body of population)f.npcs.splice(f.npcs.indexOf(body),1);
}
const n=box.spawnNpc(777777,{cityOnly:true});Object.assign(n,{r:door.r,c:door.c,tr:door.r,tc:door.c,_civilianPlan:{phase:'walk_to_shop',cycle:1},_residentWallet:{balance:80,serial:0,inventory:{},receipts:[]}});f.npcs.push(n);assert(box._residentEnterBuilding(n,f.now,door));
let frames=0;while(n._residentNativeVisit){frame(1/7);pilot.controller.tick(f.now,0);box._residentNativeVisitTick(n,1/7,f.now);assert(++frames<600,JSON.stringify({status:n._residentVisitStatus,visit:n._residentNativeVisit,employee:pilot.controller.stats}));}
assert.equal(n._residentWallet.balance,77);assert.equal(n._residentWallet.receipts.length,1);
const spawn=pilot.station.layout.spawn,rc={r:spawn.z/f.M,c:spawn.x/f.M};
const overflow=[];for(let i=0;i<100;i++){const body={id:'unrendered_'+i,r:rc.r,c:rc.c,hp:60};overflow.push(body);f.npcs.push(body);}
assert.equal(pilot.canSweep(rc,rc,null),false,'body outside 72 renderer quota still blocks spawn');
for(const body of overflow)f.npcs.splice(f.npcs.indexOf(body),1);
const unrendered={id:'fresh-blocker',r:rc.r,c:rc.c,hp:60};f.npcs.push(unrendered);assert.equal(pilot.canSweep(rc,rc,null),false);unrendered.c+=10;assert.equal(pilot.canSweep(rc,rc,null),true,'source change between Walk frames is read fresh');f.npcs.splice(f.npcs.indexOf(unrendered),1);
hero.object.position.set(spawn.x,spawn.y,spawn.z);assert.equal(pilot.canSweep(rc,rc,null),false,'current player body blocks');hero.object.position.y+=8;assert.equal(pilot.canSweep(rc,rc,null),true,'actual player Y avoids false floor collision');
const originalCar={r:f.car.r,c:f.car.c};f.car.r=rc.r;f.car.c=rc.c;assert.equal(pilot.canSweep(rc,rc,null),false,'fresh unstreamed source traffic blocks between Walk frames');Object.assign(f.car,originalCar);
fleetRows=[{id:'hidden-fleet',car:f.actor}];f.actor.object.position.set(spawn.x,spawn.y,spawn.z);f.actor.object.visible=false;assert.equal(pilot.canSweep(rc,rc,null),false,'render-hidden physical fleet vehicle still blocks');f.actor.object.visible=true;fleetRows=[];f.syncCar();
const corpse={id:'retained-corpse',r:rc.r,c:rc.c,hp:0,dead:true,deadAt:f.now-61000,_deathR:rc.r,_deathC:rc.c};f.npcs.push(corpse);assert.equal(pilot.canSweep(rc,rc,null),false,'corpse retained after minute still occupies room');f.npcs.splice(f.npcs.indexOf(corpse),1);
const closePoint=pilot.station.layout.doorOutside,nearDoor=[];for(let i=0;i<65;i++){const body={id:'door_crowd_'+i,r:closePoint.z/f.M,c:closePoint.x/f.M,hp:60};f.npcs.push(body);nearDoor.push(body);}
assert.equal(pilot.station.sweptClear(0,1,pilot.physicalBodies(closePoint,pilot.station.layout.doorInside)),false,'complete door crowd over64 holds, no truncation');for(const body of nearDoor)f.npcs.splice(f.npcs.indexOf(body),1);
// Confirmed-death boundary is injected here; actual hit/downing/bleedout is covered by the accepted source-body suite.
employee.dead=true;employee.hp=0;employee.deadAt=f.now;employee._deathRecord20={confirmed:true,fatal:true,targetId:box._threeNpcEntityId(employee),deathKey:String(f.now)};frame(.05);assert.equal(pilot.controller.lifecycle.available,false);
const shopper=box.spawnNpc(888888,{cityOnly:true});Object.assign(shopper,{r:door.r,c:door.c,tr:door.r,tc:door.c,_civilianPlan:{phase:'walk_to_shop',cycle:1},_residentWallet:{balance:80,serial:0,inventory:{},receipts:[]}});f.npcs.push(shopper);assert(box._residentEnterBuilding(shopper,f.now,door));let deniedFrames=0;
while(shopper._residentNativeVisit){frame(1/7);pilot.controller.tick(f.now,0);box._residentNativeVisitTick(shopper,1/7,f.now);assert(++deniedFrames<300);}
assert.equal(shopper._residentWallet.balance,80);assert.equal(shopper._residentWallet.receipts.length,0,'dead seller cannot sell');
const corpseBefore=JSON.stringify(employee);frame((employee.deadAt+59000-f.now)/1000);assert.equal(pilot.controller.stats.births,1);frame(1.1);assert.equal(pilot.controller.stats.births,2);assert.notEqual(pilot.controller.actor.id,employee.id);assert.equal(JSON.stringify(employee),corpseBefore);
assert(Math.hypot(pilot.controller.actor.c*f.M-spawn.x,pilot.controller.actor.r*f.M-spawn.z)<.01,'replacement born in same hidden storeroom');
const replacement=pilot.controller.actor;
const countBefore=index.stats.bodyReferences;pilot.dispose();assert(index.stats.bodyReferences<countBefore,'service collision group removed');assert.equal(replacement._stationaryService,undefined);assert(employee._stationaryService,'corpse marker retained to prevent ambient duplicate');assert.equal(vm.runInContext('_residentCommerceServiceProviders.size',box),0);
for(const object of actors.values())object.removeFromParent();hero.object.removeFromParent();f.entry.getCollisionBodies=baseBodies;f.entry.dispose();
const report={pass:true,purchase:{frames,balance:77,receipts:1},uncappedBodies:100,actualCameraFrustum:true,sourceFreshBetweenFrames:true,sourceTraffic:true,hiddenFleet:true,retainedCorpse:true,doorCrowd65:true,deadSellerPurchaseDenied:true,hiddenReplacementAfter60s:true,cpu,limits:'Composed actual source/commerce/native geometry/camera/uncapped roster. Presentation ready is tested with source-following Object3D stand-ins, not actual skeletal renderer. No activation/GPU/LIVE/FPS.'};
fs.writeFileSync(new URL('../../../outputs/service_walk23_candidate_results.json',import.meta.url),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
