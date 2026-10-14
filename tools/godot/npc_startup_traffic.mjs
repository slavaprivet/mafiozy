// Actual source initCars continuation. Caller must first run exact named stage.
// Import has no world execution or output side effects.
import {sourceFunction,sourceDeclaration,hash} from './npc_startup_source_vm.mjs';
const completed=new WeakSet();
export function installTrafficAndRun(s){
 if(!s?.run||!s.installed)throw Error('Actual shared source VM required');
 if(completed.has(s))throw Error('Traffic continuation already executed');
 if(!s.run("NPCS.includes(SAID_NPC)&&SPECIALIST_NPCS.every(n=>NPCS.includes(n))"))throw Error('Exact named startup must precede traffic');
 if(s.run('_walkTrafficNavigationResolver === null')!==true)throw Error('Approved actual null-resolver declaration phase required');
 const beforeRng=s.rng(),beforeMap=s.run('JSON.stringify(MAP)'),beforeNpc=s.run('JSON.stringify(NPCS)'),queryStart=s.queries.length;
 const buildingCacheBefore=s.run('JSON.stringify([..._threeBuildingBlockCache])');
 const declarations=['CAR_MODELS','CARS','GANG_CAR_MODELS','POLICE_MODELS','EMERGENCY_AMBIENT_MODELS','_TRAFFIC_DENSITY','_trafficRoadGraph','_trafficPathCache','PARKING_LOTS','_nativeParkingAdmission','_convoyNextAt'];
 const functions=['initCars','spawnCar','spawnParkedCar','spawnGangLair','_getTrafficTarget','_assignCarGoal','_spawnParkingLotCars','_clearParkingTiles','_civilianTripNative','_nativeParkingPrepare','_pickTrafficEdgePortal','_trafficEdgePortalInvisible','_parkedCarOverlapsBank','_trafficCarFootprintClear'];
 for(const receipt of [...declarations.map(sourceDeclaration),...functions.map(sourceFunction)].sort((a,b)=>a.start-b.start))s.installReceipt(receipt);
 s.context.__trafficCalls=[];
 s.context.__trafficRngSnapshot=()=>s.rng();
 const observerCode="const __trafficSourceSpawnCar=spawnCar;spawnCar=function(...args){const before=__trafficRngSnapshot();const car=__trafficSourceSpawnCar(...args);__trafficCalls.push({function:'spawnCar',args,before,after:__trafficRngSnapshot(),car});return car;};const __trafficSourceParked=spawnParkedCar;spawnParkedCar=function(...args){const before=__trafficRngSnapshot();const car=__trafficSourceParked(...args);__trafficCalls.push({function:'spawnParkedCar',args,before,after:__trafficRngSnapshot(),car});return car;};";
 s.run(observerCode,'unchanged source call-through trace');
 (s.instrumentationReceipts??=[]).push({name:'traffic_observational_birth_call_trace',code:observerCode,sha256:hash(observerCode),source_policy_modified:false});
 s.run('initCars();','actual complete initCars');
 const afterMap=s.run('JSON.stringify(MAP)'),mapBefore=JSON.parse(beforeMap),mapAfter=JSON.parse(afterMap),mapChanges=[];
 for(let r=0;r<mapBefore.length;r++)for(let c=0;c<mapBefore[r].length;c++)if(mapBefore[r][c]!==mapAfter[r][c])mapChanges.push({r,c,before:mapBefore[r][c],after:mapAfter[r][c]});
 const state=JSON.parse(s.run('JSON.stringify({cars:CARS,parking_lots:PARKING_LOTS,parking_admission:{queue:_nativeParkingAdmission.queue.map(row=>({car_index:CARS.indexOf(row.car),index:row.index,retryAt:row.retryAt})),cursor:_nativeParkingAdmission.cursor,refreshAt:_nativeParkingAdmission.refreshAt,reservations_size:_nativeParkingAdmission.reservations.size},traffic:{target:_getTrafficTarget(),road_graph:_trafficRoadGraph,path_cache_size:_trafficPathCache.size},convoy_next_at:_convoyNextAt})'));
 if(s.run('JSON.stringify(NPCS)')!==beforeNpc)throw Error('Traffic altered NPC source rows unexpectedly');
 const buildingCacheAfter=s.run('JSON.stringify([..._threeBuildingBlockCache])');
 if(state.parking_admission.queue.some(row=>row.car_index<0))throw Error('Source parking queue lost CARS object alias');
 const birth_calls=JSON.parse(s.run('JSON.stringify(__trafficCalls.map(row=>({...row,car_index:row.car?CARS.indexOf(row.car):null,car:undefined})))'));
 const model_aliases=JSON.parse(s.run("JSON.stringify(CARS.map((car,car_index)=>{for(const [catalogue,models] of [['CAR_MODELS',CAR_MODELS],['GANG_CAR_MODELS',GANG_CAR_MODELS],['EMERGENCY_AMBIENT_MODELS',EMERGENCY_AMBIENT_MODELS]]){const model_index=models.indexOf(car.model);if(model_index>=0)return{car_index,catalogue,model_index};}for(const [model_key,model]of Object.entries(POLICE_MODELS))if(model===car.model)return{car_index,catalogue:'POLICE_MODELS',model_key};return{car_index,catalogue:null};}))"));
 if(model_aliases.some(row=>row.catalogue===null))throw Error('Unknown source car model identity');
 completed.add(s);
 return {schema:'mafiozi.npc-startup-traffic-stage/v1',phase:'AFTER_INITCARS_BEFORE_INITCITYCOPS_BEFORE_NATIVE_RESOLVER',approved_boundary:s.boundary,before_rng:beforeRng,after_rng:s.rng(),map_before_sha256:hash(beforeMap+'\n'),map_after_sha256:hash(afterMap+'\n'),map_changes:mapChanges,building_collision_cache:{before_sha256:hash(buildingCacheBefore),after_sha256:hash(buildingCacheAfter),unchanged:buildingCacheBefore===buildingCacheAfter,entries:JSON.parse(buildingCacheAfter)},state,birth_calls,model_aliases,source_passability_queries:s.queries.slice(queryStart),limits:['Offline source initCars, not physical/native parking or authenticated transport','Native resolver absent by actual declaration; spawnCar source early returns null','Parking queue retains original CARS references; serialized car_index preserves aliases','No source/model overrides, mock clear query or synthetic vehicle birth']};
}
