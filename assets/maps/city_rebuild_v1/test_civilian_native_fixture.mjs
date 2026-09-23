// CPU-only actual-geometry fixture. No renderer, route-success stubs or GPU.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {gunzipSync} from 'node:zlib';
import {createWindowedBuildingEntry} from './building_window_integration.mjs';
import {applyBuildingDoorsGlass} from './building_doors_glass.mjs';
import {createWalkCollisionIndex} from './walk_collision_index.mjs';
import {createNpcNativeNavigation} from './npc_native_navigation.mjs';
import {createNpcVehicleNavigation} from './npc_vehicle_navigation.mjs';
import {createNpcVehicleSurfaceAccess} from './npc_vehicle_surface_access.mjs';
import {createNpcVehicleAccessResolver} from './npc_vehicle_access.mjs';
import {createCityRoadNavigation} from './city_road_navigation.mjs';
import {createLandscapePlan} from './landscape_plan.mjs';
import {nativePedestrianLand} from './native_pedestrian_surface.mjs';
import {createCarWorld,carFits,pointInPolygon} from './car_drive.mjs';
import {createArtistVehicle} from './vehicle_fleet_models.mjs';
import {npcVehicleBlocks} from './world_traffic_presentation.mjs';
import {createNpcResidentBuildingAccess} from './npc_resident_building_access.mjs';
import {buildEnvironmentVisualPlans} from './environment_planning_worker_core.mjs';
import {explorationKeepouts} from './exploration_scene_support.mjs';

export const read=n=>JSON.parse(fs.readFileSync(new URL(n,import.meta.url)));
let currentNativeSnapshot=null;
export function createCurrentNativeSnapshot(){
 if(currentNativeSnapshot)return currentNativeSnapshot;
 const staticSnapshot=JSON.parse(gunzipSync(fs.readFileSync(new URL('test_fixtures/native_static_collision19.json.gz',import.meta.url))));
 const buildings=[...read('buildings_placement.v1.json').instances,...read('detention_native_sites.v1.json').instances];
 const authoredDecor=read('decor_placement.v1.json').instances;
 assert.deepEqual(staticSnapshot.buildings,buildings,'tracked static fixture must match current building and detention records');
 assert.equal(staticSnapshot.authoredDecor.length,authoredDecor.length);
 for(let i=0;i<authoredDecor.length;i++)assert.deepEqual(staticSnapshot.authoredDecor[i],{collision:authoredDecor[i].collision},'tracked decor collision '+i);
 const instances=[...buildings,...authoredDecor],decorPlan={colliders:staticSnapshot.decorPlan.colliders};
 const plans=buildEnvironmentVisualPlans({topology:read('topology_for_placement.json'),instances,keepouts:explorationKeepouts(instances),decorPlan});
 currentNativeSnapshot={description:'current production plans rebuilt from tracked source placements and exact compressed static collision fixture',buildings,authoredDecor,decorPlan,roadPlan:plans.roadPlan,parkingPlan:plans.parkingPlan};
 return currentNativeSnapshot;
}
export function sourceFunction(source,name){
 const start=source.indexOf('function '+name+'(');assert(start>=0,'source function '+name);
 const lineEnd=source.indexOf('\n',start),line=source.slice(start,lineEnd);
 // Existing source functions use a column-zero closing brace; short functions
 // are wholly on their declaration line. Preserve their actual implementation.
 return line.trimEnd().endsWith('}')?line:source.slice(start,source.indexOf('\n}',start)+2);
}
export async function createCivilianNativeFixture({assetId='hospital',tripLimit=null,laneJobs=null,snapshot:providedSnapshot=null,candidateTripSource=false}={}){
 const M=4.1,top=read('topology_for_placement.json');
 const snapshot=providedSnapshot||createCurrentNativeSnapshot();
 const buildings=snapshot.buildings,item=buildings.find(b=>b.assetId===assetId);assert(item);
 const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
 registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
 const THREE=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
 const glb=async path=>{const b=fs.readFileSync(path);return(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene};
 const scene=new THREE.Scene(),visual=await glb(new URL('../../..'+item.binding.url,import.meta.url)),group=new THREE.Group(),t=item.transform;
 visual.traverse(n=>{if(item.hideNodeNames?.includes(n.name))n.visible=false});visual.position.fromArray(t.modelLocalOffsetM);
 group.add(visual);group.position.fromArray(t.positionM);group.rotation.y=t.yawDegrees*Math.PI/180;group.scale.setScalar(t.uniformScale);scene.add(group);scene.updateMatrixWorld(true);
 applyBuildingDoorsGlass(visual,item);
 const {entry}=createWindowedBuildingEntry({THREE,visual,instance:item,metresPerCell:M});assert(entry);scene.updateMatrixWorld(true);
 const fixed=[...buildings.filter(b=>b!==item),...snapshot.authoredDecor].flatMap(b=>b.collision?.worldBodies||[])
  .concat(snapshot.decorPlan.colliders,snapshot.roadPlan.colliders,snapshot.parkingPlan.colliders);
 let bodies,carWorld,index;
 function refreshBodies(){bodies=[...fixed,...entry.getCollisionBodies()];index=createWalkCollisionIndex([bodies]);carWorld=createCarWorld(top,bodies,M)}refreshBodies();
 const landscape=createLandscapePlan();
 const waterAt=(x,z)=>{
  if(landscape.contains(x,z))return landscape.waterAt(x,z);
  const r=Math.floor(z/M),c=Math.floor(x/M);if(top.grid?.[r]?.[c]!==16||top.protectedMask?.[r]?.[c])return null;
  let shore=3.5;for(let rr=r-1;rr<=r+1;rr++)for(let cc=c-1;cc<=c+1;cc++)if(top.grid?.[rr]?.[cc]!==16)shore=Math.min(shore,Math.hypot(Math.max(cc*M-x,0,x-(cc+1)*M),Math.max(rr*M-z,0,z-(rr+1)*M)));
  const floor=-Math.min(2.4,shore*.9);return{level:-.18,depth:Math.max(0,-.18-floor),floor};
 };
 const floor=(x,z)=>entry.floorHeight(x,z,0)??waterAt(x,z)?.floor??landscape.groundHeight(x,z);
 class Box extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
 const actor=createArtistVehicle(THREE,Box,await glb(new URL('models/artist_vehicle_pack/compact_sedan.glb',import.meta.url)),'compact_sedan');scene.add(actor.object);
 const car={id:'actual-civilian-car',r:0,c:0,ang:0,parked:true,model:{L:1.8,W:.88}},cars=[car],npcs=[];
 const syncCar=()=>{actor.object.position.set(car.c*M,floor(car.c*M,car.r*M),car.r*M);actor.object.rotation.y=Math.PI/2-car.ang;actor.object.updateMatrixWorld(true)};
 const isRoad=(x,z)=>!!top.roadMask?.[Math.floor(z/M)]?.[Math.floor(x/M)];
 const pedestrian=createNpcNativeNavigation({worldScale:M,waterAt,groundHeight:floor,bodiesAt:(c,r)=>index(c,r),bodiesInBounds:(...bounds)=>index.queryBounds(...bounds),containsBody:(body,r,c)=>pointInPolygon(c,r,body.polygonCR),terrainAllows:(x,z)=>landscape.contains(x,z)?landscape.canWalk(x,z):nativePedestrianLand(top,z/M,x/M)||!!waterAt(x,z),surfaceAt:(x,z)=>isRoad(x,z)?'road':'land',blocksDynamic:(x,z,body)=>body.ignoreId===car.id?false:npcVehicleBlocks(actor,x,z,0,body)});
 let lanes;const vehicleSurface=createNpcVehicleSurfaceAccess({getParkingPlan:()=>snapshot.parkingPlan,getRoadPlan:()=>snapshot.roadPlan,verifyLaneSegment:request=>lanes?.verifyLaneSegment(request)||{allowed:false,reason:'route_expired'},worldScale:M});
 const nav=createNpcVehicleNavigation({worldScale:M,frameBudgetMs:3,poseAllowed:(x,z,yaw,shape)=>carFits(x,z,yaw,carWorld,shape),isRoad,vehicleAccess:vehicleSurface.query,waterAt,groundHeight:floor,getVehicle:()=>actor});
 lanes=createCityRoadNavigation({routeJobs:laneJobs,getRoadPlan:()=>snapshot.roadPlan,getParkingPlan:()=>snapshot.parkingPlan,getInstances:()=>buildings,isRoad,poseAllowed:(x,z,yaw)=>carFits(x,z,yaw,carWorld,actor.profile),metresPerCell:M});
 const access=createNpcVehicleAccessResolver({traffic:{getActor:id=>id===car.id?actor:null,setNpcAccess:()=>{}},worldScale:M});
 let now=0,frameClock=performance.now();const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
 const box={console,Math,Number,Array,Map,Set,performance:{now:()=>now+performance.now()%1},prevT:0,MAP:top.grid,MAP_ROWS:top.grid.length,MAP_COLS:top.grid[0].length,CARS:cars,NPCS:npcs,PARKING_LOTS:[],_parkingNpcs:[],player:{r:20,c:155},myDrivingCarId:null,document:{documentElement:{dataset:{}}},window:{},_inPrisonIslandRestrictedZone:()=>false,inArena:()=>false,inLair:()=>false,_inPitCorridor:()=>false,isBlockedPed:(r,c)=>top.grid[Math.floor(r)]?.[Math.floor(c)]===1,_cityV3NextSurfaceAt:()=>false,_threeVehicleEntityId:c=>c.id,_threeNpcEntityId:n=>n.id,_trafficRoadTile:(r,c)=>isRoad(c*M,r*M),_trafficHardTileAt:(r,c)=>top.grid[Math.floor(r)]?.[Math.floor(c)]===1,_npcEffectiveSpeed:()=>.4,_npcLifeEligible:n=>!n.dead,_isRespawnableResident:n=>!n.dead,_getTrafficRoadGraph:()=>({nodes:[]})};
 box.performance.now=()=>now+performance.now()-frameClock;box._walkRendererActive=()=>true;
 box._getTrafficRoadGraph=()=>assert.fail('native cycle must not consult legacy graph');
 box._residentBuildingRouteBudget=1;box._residentBuildingRouteDeferred=0;box._npcRememberEvent=()=>{};
 box.pickNpcWaypoint=()=>{}; // End-of-visit handoff is outside this bounded cycle.
 box.NPC_HERO_PACE={walk:4.6/M,run:7.8/M};
 vm.createContext(box);
 // Load the same finite agenda and capacity authority as production. Explicit
 // manual/trip plans keep their real helper semantics; no route success stub.
 vm.runInContext(fs.readFileSync(new URL('npc_activity_reservations_source.js',import.meta.url),'utf8'),box);
 vm.runInContext(fs.readFileSync(new URL('npc_activity_agenda_source.js',import.meta.url),'utf8'),box);
 vm.runInContext(fs.readFileSync(new URL('npc_resident_commerce_source.js',import.meta.url),'utf8'),box);
 vm.runInContext(fs.readFileSync(new URL('npc_native_directed_route_source.js',import.meta.url),'utf8'),box);
 vm.runInContext(fs.readFileSync(new URL('npc_road_egress_source.js',import.meta.url),'utf8'),box);
 vm.runInContext(fs.readFileSync(new URL('npc_city_population_source.js',import.meta.url),'utf8'),box);
 vm.runInContext(fs.readFileSync(new URL('npc_civilian_elapsed_source.js',import.meta.url),'utf8'),box);
 vm.runInContext(`const _npcNavigationStats={queries:0,solidRefusals:0,waterRefusals:0};let _walkNpcNavigationResolver=null,_walkNpcWaterResolver=null,_npcWaterBypass=0,_walkTrafficNavigationResolver=null;`,box);
 vm.runInContext(source.slice(source.indexOf('let _npcRouteWorkFrame='),source.indexOf('function _planNpcRouteTo(')),box);
 for(const name of ['_npcNavigationAt','_npcRouteWaterDepth','_npcRouteWalkBlocked','npcPassable','npcPassableForSnitch','npcWaypointOk','_npcBodyPassable','_npcPathPassable','_clearNpcRoute','_setNpcRoute','_planNpcRouteTo','_npcFindWanderGridExit','_npcAdvanceRoute','_civilianRouteTo','_civilianPlanInterrupted','_civilianPlanEligible'])vm.runInContext(sourceFunction(source,name),box);
 for(const name of ['_npcPacedSpeed','_npcEffectiveSpeed','_civilianPlanUnit','_civilianVisitOfferReady','_civilianArrivalRadius','_residentBuildingDoors','_residentDoorById','_residentCanVisitBuilding','_maybePlanResidentBuildingVisit','_residentNativePassable','_residentNativeVisitTick','_residentEnterBuilding'])vm.runInContext(sourceFunction(source,name),box);
 for(const name of ['_residentNativeRecoveryPass','_residentNativeVisitReleaseUnavailable','_residentNativeRecoveryTick'])if(source.includes('function '+name+'('))vm.runInContext(sourceFunction(source,name),box);
 const footEnd=source.indexOf('  // Entries are collected after iteration'),footStart=source.lastIndexOf('    if (now < n.idleUntil)',footEnd),footCode=source.slice(footStart,footEnd).replace(/\s*}\s*$/,'');
 assert(footStart>0&&footEnd>footStart,'actual updateNpc foot branch');
 vm.runInContext('globalThis.actualFootTick=(npc,dt,now)=>{for(const n of [npc]){const civilianRoutineDt=_npcConsumeCivilianElapsed(n,dt,now);'+footCode+'}};',box);
 const markerStart='// CIVILIAN_PARKING_TRIP_START',markerEnd='// CIVILIAN_PARKING_TRIP_END',tripStart=source.indexOf(markerStart),tripEnd=source.indexOf(markerEnd,tripStart);assert(tripStart>=0&&tripEnd>tripStart,'actual world civilian parking trip markers');
 const worldHelper=source.slice(tripStart,tripEnd+markerEnd.length),candidateHelper=fs.readFileSync(new URL('civilian_parking_trip_source.js',import.meta.url),'utf8'),canonical=value=>value.replace(/\r\n/g,'\n').trim();
 assert.equal(canonical(candidateHelper),canonical(worldHelper),'candidate civilian parking source must exactly mirror the actual world marker region');
 const rawHelper=candidateTripSource?candidateHelper:worldHelper,helper=tripLimit?rawHelper.replace(/const CIVILIAN_TRIP_LIMIT=\d+;/,'const CIVILIAN_TRIP_LIMIT='+tripLimit+';'):rawHelper;vm.runInContext(helper,box);
 const residentAccess=createNpcResidentBuildingAccess({getEntries:()=>[entry],worldScale:M});
 const callCosts=[];let driverPresentationReady=true;
 box.nativePedestrianQuery=pedestrian.query;box.nativeAccess=access;box.nativeTrafficQuery=q=>{
  const t0=performance.now();
  const result=q.mode==='resident-access'?residentAccess(q):q.mode==='driver'?{ready:driverPresentationReady&&!!actor.object.parent&&npcs.some(n=>String(n.id)===String(q.npcId)&&n.hp>0&&!n.dead)}:q.mode==='lane-route-touch'?(laneJobs?lanes.query(q):{ready:true,status:'ready'}):q.mode==='lane-route-cancel'?(laneJobs?lanes.query(q):{ready:false,status:'blocked',reason:'route_cancelled'}):q.mode==='lane-route'||q.mode==='road-rules'||q.mode==='parking-destination'?lanes.query(laneJobs&&q.mode==='lane-route'?q:{...q,requestId:undefined}):nav.query(q);
  const elapsed=performance.now()-t0;if(elapsed>1)callCosts.push({timeMs:now,mode:q.mode||'sweep',elapsedMs:elapsed,status:result?.status,reason:result?.reason});return result;
 };
 vm.runInContext('_walkNpcNavigationResolver=nativePedestrianQuery;_walkNpcVehicleAccessResolver=nativeAccess;_walkTrafficNavigationResolver=nativeTrafficQuery;globalThis.trip=()=>_civilianTrip;',box);
 let entryBodies=entry.getCollisionBodies();
 const nextFrame=(dt=.05)=>{now+=dt*1000;frameClock=performance.now();box.prevT=now;box._residentBuildingRouteBudget=1;entry.update(dt,new THREE.Vector3(-100,0,-100));if(entryBodies!==entry.getCollisionBodies()){entryBodies=entry.getCollisionBodies();refreshBodies()}syncCar();pedestrian.beginFrame();nav.beginFrame()};
 return{M,THREE,scene,entry,item,top,snapshot,actor,car,cars,npcs,box,source,helper,nav,lanes,pedestrian,access,floor,waterAt,refreshBodies,syncCar,nextFrame,callCosts,setDriverPresentationReady:v=>{driverPresentationReady=v},get now(){return now},get bodies(){return bodies},limits:'CPU actual compact sedan and one actual building GLB, static snapshot buildings/authored/generated decor/road/parking, native water and physical source pathfinding. No runtime railway, other streamed cars, GPU, whole world update or FPS. Driver model readiness supplied at adapter boundary; NPC pose skinning is covered separately, not instantiated here.'};
}
