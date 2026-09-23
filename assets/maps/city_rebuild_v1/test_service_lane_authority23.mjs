import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createCityRoadNavigation} from './city_road_navigation.mjs';
import {createCarWorld,carFits} from './car_drive.mjs';
import {isExistingTrafficBridge} from './city_road_traffic_plan.mjs';
import {createNpcVehicleNavigation} from './npc_vehicle_navigation.mjs';
import {createNpcVehicleSurfaceAccess} from './npc_vehicle_surface_access.mjs';
import {createCurrentNativeSnapshot} from './test_civilian_native_fixture.mjs';

const read=path=>JSON.parse(fs.readFileSync(new URL(path,import.meta.url),'utf8'));
const scene=createCurrentNativeSnapshot();
const topology=read('./topology_for_placement.json');
const detentions=read('./detention_destinations.v1.json').destinations;
const placement=read('./buildings_placement.v1.json');
const M=4.1,instances=[...scene.buildings,...scene.authoredDecor];
const bodies=instances.flatMap(instance=>instance.collision?.worldBodies||[])
 .concat(scene.decorPlan.colliders,scene.roadPlan.colliders,scene.parkingPlan.colliders);
const world=createCarWorld(topology,bodies,M);
const isRoad=(x,z)=>!!topology.roadMask[Math.floor(z/M)]?.[Math.floor(x/M)]||isExistingTrafficBridge(topology,x,z,M);
// The detention stop contract accepts the full 6.4 by 2.3 metre convoy hull.
const profile={halfLength:3.2,halfWidth:1.15};
const navigation=createCityRoadNavigation({
 getRoadPlan:()=>scene.roadPlan,getParkingPlan:()=>scene.parkingPlan,getInstances:()=>instances,
 isRoad,poseAllowed:(x,z,yaw,shape)=>carFits(x,z,yaw,world,shape),metresPerCell:M,
});
navigation.prepare();
const access=createNpcVehicleSurfaceAccess({getParkingPlan:()=>scene.parkingPlan,getRoadPlan:()=>scene.roadPlan,worldScale:M});
const physical=createNpcVehicleNavigation({
 worldScale:M,isRoad,vehicleAccess:access.query,getVehicles:()=>[],
 poseAllowed:(x,z,yaw,shape)=>carFits(x,z,yaw,world,shape),
});

const rows=[];
export const actualDetentionRoutes=[];
for(const destination of detentions){
 const route=scene.roadPlan.serviceAccess.routes.find(row=>row.buildingId===destination.instanceId);
 assert(route?.points?.length>1,destination.id+' has an authored vehicle access route');
 const first=route.points[0],from={r:first.z/M,c:first.x/M,angle:Math.PI/2-first.yaw};
 const to={...destination.stop,buildingId:destination.instanceId};
 const result=navigation.query({mode:'route',from,to,vehicleProfile:profile,maxSnapDistance:12});
 assert.equal(result.status,'ready',destination.id+': '+result.reason);
 assert.equal(result.destination.kind,'service_stop');
 assert.deepEqual(result.accessRouteIds,[route.id]);
 const endpoint=result.points.at(-1),endpointErrorTiles=Math.hypot(endpoint.r-to.r,endpoint.c-to.c);
 assert(endpointErrorTiles<1e-6,destination.id+' route must reach the exact registry stop');
 let accessSegments=0;
 for(let i=1;i<result.points.length;i++){
  const fromPoint=result.points[i-1],toPoint=result.points[i];
  const sweep=physical.query({carId:'service-convoy-proof',from:fromPoint,to:toPoint,roadsOnly:false,
   accessRouteIds:result.accessRouteIds,accessLotIds:result.accessLotIds,
   halfLength:profile.halfLength/M,halfWidth:profile.halfWidth/M});
  assert.equal(sweep?.clear,true,destination.id+' segment '+i+': '+sweep?.reason);
  if(!isRoad(toPoint.c*M,toPoint.r*M))accessSegments++;
 }
 rows.push({id:destination.id,instanceId:destination.instanceId,accessRouteId:route.id,
  points:result.points.length,endpointErrorTiles,accessSegments,gearChanges:result.gearChanges.length});
 actualDetentionRoutes.push({destination,from,result});
}

// These POIs are still unresolved in the accepted placement. Do not let a
// mock road point masquerade as a real fire/tow depot in this acceptance test.
const acceptedAssets=new Set(placement.instances.map(instance=>instance.assetId));
const unresolvedFireTow=placement.unresolved.filter(row=>row.id==='poi:firestation'||row.id==='poi:junkyard');
assert(!acceptedAssets.has('fire_station'));
assert.equal(unresolvedFireTow.length,2);

const report={passed:true,detention:rows,fireTowDepotReady:false,
 fireTowBlocker:'fire station and junkyard are unresolved placement POIs; native depot/home/scene remains HOLD',
 limits:'CPU current production plans rebuilt from the tracked exact static fixture and full convoy hull; no renderer/GPU/FPS. Ambulance physical hospital bay/corridor remains covered by test_npc_hospital_actual.mjs.'};
console.log(JSON.stringify(report,null,2));
console.log('PASS exact detention service routes and semantic full-hull access; fire/tow native depots remain HOLD');
