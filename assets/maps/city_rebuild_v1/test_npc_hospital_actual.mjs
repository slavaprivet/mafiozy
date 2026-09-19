import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createWindowedBuildingEntry} from './building_window_integration.mjs';
import {applyBuildingDoorsGlass} from './building_doors_glass.mjs';
import {createWalkCollisionIndex} from './walk_collision_index.mjs';
import {createNpcNativeNavigation} from './npc_native_navigation.mjs';
import {createNpcVehicleNavigation} from './npc_vehicle_navigation.mjs';
import {createNpcServiceDestinations} from './npc_service_destinations.mjs';
import {createLandscapePlan} from './landscape_plan.mjs';
import {nativePedestrianLand} from './native_pedestrian_surface.mjs';
import {createCarWorld,carFits,pointInPolygon} from './car_drive.mjs';
import {createArtistVehicle} from './vehicle_fleet_models.mjs';
const M=4.1,read=n=>JSON.parse(fs.readFileSync(new URL(n,import.meta.url))),top=read('topology_for_placement.json');
const buildings=read('buildings_placement.v1.json').instances,decor=read('decor_placement.v1.json').instances,detention=read('detention_native_sites.v1.json').instances;
const item=buildings.find(i=>i.assetId==='hospital');assert(item);
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c);}});
const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const glb=async path=>{const b=fs.readFileSync(path);return(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene;};
const world=new T.Scene(),visual=await glb(new URL('../../..'+item.binding.url,import.meta.url)),group=new T.Group(),t=item.transform;
visual.traverse(n=>{if(item.hideNodeNames?.includes(n.name))n.visible=false;});visual.position.fromArray(t.modelLocalOffsetM);
group.add(visual);group.position.fromArray(t.positionM);group.rotation.y=t.yawDegrees*Math.PI/180;group.scale.setScalar(t.uniformScale);world.add(group);world.updateMatrixWorld(true);
applyBuildingDoorsGlass(visual,item);
const building=createWindowedBuildingEntry({THREE:T,visual,instance:item,metresPerCell:M}),entry=building.entry;assert(entry);
world.updateMatrixWorld(true);const doorPoint=entry.object.localToWorld(new T.Vector3(0,0,1)),door={r:doorPoint.z/M,c:doorPoint.x/M};
const solids=[...buildings.filter(b=>b!==item),...decor,...detention].flatMap(b=>b.collision?.worldBodies||[]),entryBodies=entry.getCollisionBodies();
const index=createWalkCollisionIndex([solids,entryBodies]),carWorld=createCarWorld(top,[...solids,...entryBodies],M),landscape=createLandscapePlan();
const waterAt=(x,z)=>{
 if(landscape.contains(x,z))return landscape.waterAt(x,z);
 const r=Math.floor(z/M),c=Math.floor(x/M);if(top.grid?.[r]?.[c]!==16||top.protectedMask?.[r]?.[c])return null;
 let shore=3.5;for(let rr=r-1;rr<=r+1;rr++)for(let cc=c-1;cc<=c+1;cc++){if(top.grid?.[rr]?.[cc]===16)continue;shore=Math.min(shore,Math.hypot(Math.max(cc*M-x,0,x-(cc+1)*M),Math.max(rr*M-z,0,z-(rr+1)*M)));}
 const floor=-Math.min(2.4,shore*.9);return {level:-.18,depth:Math.max(0,-.18-floor),floor};
};
const floor=(x,z)=>entry.floorHeight(x,z,0)??waterAt(x,z)?.floor??landscape.groundHeight(x,z);
const pedestrian=createNpcNativeNavigation({worldScale:M,waterAt,groundHeight:floor,bodiesAt:(c,r)=>index(c,r),containsBody:(body,r,c)=>pointInPolygon(c,r,body.polygonCR),terrainAllows:(x,z)=>landscape.contains(x,z)?landscape.canWalk(x,z):nativePedestrianLand(top,z/M,x/M)||!!waterAt(x,z)});
class Box extends T.BoxGeometry{constructor(w,h,d){super(w,h,d);}}
const ambulance=createArtistVehicle(T,Box,await glb(new URL('models/artist_vehicle_pack/city_ambulance.glb',import.meta.url)),'city_ambulance');
const isRoad=(x,z)=>!!top.roadMask?.[Math.floor(z/M)]?.[Math.floor(x/M)];
const nav=createNpcVehicleNavigation({worldScale:M,poseAllowed:(x,z,yaw,shape)=>carFits(x,z,yaw,carWorld,shape),isRoad,waterAt,groundHeight:floor,getVehicle:()=>ambulance});
let loaded=false;
const destinations=createNpcServiceDestinations({getHospitals:()=>loaded?[{hospitalId:item.id,door}]:[],vehicleQuery:nav.query,pedestrianQuery:pedestrian.query,isRoad,worldScale:M});
assert.equal(destinations.query({mode:'hospital'}),null);loaded=true;
const costs=[];let result=null,frames=0;
for(;frames<1200&&!result;frames++){nav.beginFrame();pedestrian.beginFrame();destinations.beginFrame();const start=performance.now();result=destinations.query({mode:'hospital',carId:'service_actual',from:{r:20,c:160}});costs.push(performance.now()-start);}
assert(result,'actual hospital must resolve a native road bay and physical door corridor');
assert.equal(result.hospitalId,item.id);assert(isRoad(result.bay.c*M,result.bay.r*M));
assert(nav.query({carId:'service_actual',from:result.bay,to:result.bay,roadsOnly:true}).clear);
let footSamples=0;
for(let j=1;j<result.footRoute.length;j++){
 const a=result.footRoute[j-1],b=result.footRoute[j],count=Math.max(1,Math.ceil(Math.hypot(b.r-a.r,b.c-a.c)/.06));
 for(let i=0;i<=count;i++)for(const [dr,dc]of [[0,0],[.18,0],[-.18,0],[0,.18],[0,-.18]]){
  const p={r:a.r+(b.r-a.r)*i/count+dr,c:a.c+(b.c-a.c)*i/count+dc},hit=pedestrian.query(p);footSamples++;
  assert(!hit.blocked&&hit.depth<=.025,'actual route capsule is dry and walkable');
 }
}
// The actual source fleet uses the same live resolvers, not a permissive fixture.
const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
const fn=name=>{const a=source.indexOf('function '+name+'(');assert(a>=0);return source.slice(a,source.indexOf('\nfunction ',a+10));};
const context={performance,Math,Number,Map,Set,Array,NPCS:[],serviceVehicles:[],_svcVehId:0,_walkTrafficNavigationResolver:null,
 HOSPITAL_R:80,HOSPITAL_C:80,HOSPITAL_EAST_R:90,HOSPITAL_EAST_C:90,AMBULANCE_FLEET_SIZE:6,AMBULANCES_PER_HOSPITAL:3,
 _walkRendererActive:()=>true,prevT:0,_hospitalAmbulanceBaysCache:null,_npcPacedSpeed:n=>n,_UP:new Set(['renderer=walk']),window:{},document:{documentElement:{dataset:{}}}};
vm.createContext(context);vm.runInContext(fs.readFileSync(new URL('ambulance_transport.js',import.meta.url),'utf8'),context);
for(const n of ['_hospitalAmbulanceBays','_ensureAmbulanceFleet'])vm.runInContext(fn(n),context);
context._ensureAmbulanceFleet();assert.equal(context.serviceVehicles.length,0,'native startup waits for actual hospital');assert.equal(context.NPCS.length,0);
context._walkTrafficNavigationResolver=q=>q.mode==='hospital'?destinations.query(q):nav.query(q);
for(let i=0;i<30;i++){context.prevT=i*16.667;nav.beginFrame();pedestrian.beginFrame();destinations.beginFrame();context._ensureAmbulanceFleet();}
const fleet=context.serviceVehicles;
assert(fleet.length>0&&fleet.length<=6,'fleet appears only in real native bays');
assert.equal(context.NPCS.length,fleet.length*3);
for(const v of fleet){
 assert.equal(v.hospitalId,item.id);assert(v.x>150,'no old MAP hospital coordinates');
 assert(nav.query({carId:'service_'+v.id,from:{r:v.y,c:v.x,angle:v.ang},to:{r:v.y,c:v.x,angle:v.ang},roadsOnly:true,halfLength:1.04,halfWidth:.5}).clear);
 assert(Math.hypot(v.y-result.bay.r,v.x-result.bay.c)>=2.3,'discharge bay remains free of parked depot cars');
}
for(let i=0;i<fleet.length;i++)for(let j=i+1;j<fleet.length;j++)assert(Math.hypot(fleet[i].y-fleet[j].y,fleet[i].x-fleet[j].x)>=2.3);
const initialFleet=fleet.map(v=>({id:v.id,r:v.y,c:v.x}));
const ids=context.NPCS.map(n=>n.id);context._ensureAmbulanceFleet();assert.deepEqual(context.NPCS.map(n=>n.id),ids);
// Real source handoff follows this exact geometry route, never the depot slot.
Object.assign(context,{AMBULANCE_RESPONSE_SPEED:2,AMBULANCE_ROUTE_RETRY_MS:900,
 _ambulanceDeliveryCount:0,_ambulanceHospitalRecoveryCount:0,_ambientTrafficServiceKind:()=>false,_groundPoliceCanDrive:()=>true,
 _completePlayerAmbulanceRecovery:()=>assert.fail('resident fixture'),_hospitalizeEmpireBoss:()=>assert.fail('resident fixture')});
for(const name of ['_completeAmbulanceHospitalDelivery','_sendAmbulanceToHospital','updateServiceVehicles'])vm.runInContext(fn(name),context);
let barrier=false;
context._walkNpcNavigationResolver=q=>barrier&&q.r>8?{blocked:true,depth:0}:pedestrian.query(q);
const v=fleet[0],patient={id:'actual_patient',hp:1,max_hp:60,_medicalDowned:true,_ambulanceInTransit:true,_carriedByAmbulance:true};
v.payload={npc:patient};v._ambulanceReturnMoveObserved=true;
assert.equal(context._completeAmbulanceHospitalDelivery(v,0),false,'depot is not delivery');assert.equal(patient.hp,1);
v.y=result.bay.r;v.x=result.bay.c;v.ang=result.bay.angle;
assert.equal(context._completeAmbulanceHospitalDelivery(v,0),false,'arrival starts physical discharge instead of healing');
assert.equal(v.state,'hospital_discharge');barrier=true;
let simTime=0,maxBeforeDoorHP=1;const dischargeCosts=[];context.performance={now:()=>simTime};
for(let i=0;i<400;i++){
 simTime+=50;pedestrian.beginFrame();const start=performance.now();context.updateServiceVehicles(.05);dischargeCosts.push(performance.now()-start);
 maxBeforeDoorHP=Math.max(maxBeforeDoorHP,patient.hp);
}
assert.equal(maxBeforeDoorHP,1,'blocked hospital path cannot complete by timer');assert(v._medicalScene.centerR<8);
barrier=false;
for(let i=0;i<600&&v.state==='hospital_discharge';i++){
 simTime+=50;pedestrian.beginFrame();nav.beginFrame();destinations.beginFrame();const start=performance.now();context.updateServiceVehicles(.05);dischargeCosts.push(performance.now()-start);
}
assert.equal(patient.hp,35);assert.equal(patient._medicalDowned,false);assert.equal(patient.r,door.r);assert.equal(patient.c,door.c);
assert.equal(v.state,'returning');assert(v._medicalCrew.every(n=>n._inVehicle));
assert.equal(v._ambulanceRouteGoal.r,v.homeR);assert.equal(v._ambulanceRouteGoal.c,v.homeC);
const injury={id:'driver_interrupted_patient',hp:1,max_hp:60,_medicalDowned:true,_ambulanceInTransit:true,_carriedByAmbulance:true};
const interrupted=fleet[1];interrupted.y=result.bay.r;interrupted.x=result.bay.c;interrupted.payload={npc:injury};interrupted._ambulanceReturnMoveObserved=true;
context._completeAmbulanceHospitalDelivery(interrupted,simTime);context._ambulanceUpdateDischarge(interrupted,.05,simTime+800);
interrupted._ambulanceDriver.hp=0;interrupted._ambulanceDriver.dead=true;
context._ambulanceUpdateDischarge(interrupted,.05,simTime+850);
assert.equal(interrupted.state,'ambulance_disabled');assert.equal(injury.hp,1);assert.equal(injury._ambulanceInTransit,false);
const deadPatient={id:'actual_corpse',hp:0,dead:true,_ambulanceInTransit:true,_carriedByAmbulance:true};
const corpseVan=fleet[2];corpseVan.y=result.bay.r;corpseVan.x=result.bay.c;corpseVan.ang=result.bay.angle;
corpseVan.payload={npc:deadPatient};corpseVan._ambulanceReturnMoveObserved=true;
context._completeAmbulanceHospitalDelivery(corpseVan,simTime);
for(let i=0;i<400&&corpseVan.state==='hospital_discharge';i++){simTime+=50;pedestrian.beginFrame();context._ambulanceUpdateDischarge(corpseVan,.05,simTime);}
assert.equal(deadPatient.hp,0);assert.equal(deadPatient.dead,true);assert.equal(deadPatient._ambulanceInTransit,false);
assert.equal(deadPatient.r,door.r);assert.equal(deadPatient.c,door.c);
dischargeCosts.sort((a,b)=>a-b);

costs.sort((a,b)=>a-b);
const report={hospital:item.id,door,result,frames,footSamples,fleet:initialFleet,crew:context.NPCS.length,
 dischargeCost:{p50:dischargeCosts[Math.floor(dischargeCosts.length*.5)],p95:dischargeCosts[Math.floor(dischargeCosts.length*.95)]},cost:{p50:costs[Math.floor(costs.length*.5)],p95:costs[Math.floor(costs.length*.95)],max:costs.at(-1)},
 limits:'CPU actual hospital GLB + entry collision + current placement/decor/detention + terrain/water. No generated forest/fences/moving rail or GPU.'};
console.log(JSON.stringify(report));
fs.writeFileSync(new URL('../../../outputs/npc_actual_hospital_access_20260912.json',import.meta.url),JSON.stringify(report,null,2));
