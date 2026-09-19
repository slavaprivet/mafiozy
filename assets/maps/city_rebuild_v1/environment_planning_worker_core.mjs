import {createLandscapePlan} from './landscape_plan.mjs';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';
import {planEnvironmentGrass} from './environment_grass_plan.mjs';
import {createCityRoadDressingPlan} from './city_road_dressing_plan.mjs';
import {explorationKeepouts} from './exploration_scene_support.mjs';
import {createCityParkingPlan,replanCityParkingWalks} from './city_parking_plan.mjs';
import {planCityParkingAccess,augmentCityParkingLaneEntries} from './city_parking_access.mjs';
import {resolveCityParkingPedestrianAccess} from './city_parking_pedestrian_routes.mjs';
import {prepareDirectedLanePlan,createDirectedLaneRouter} from './city_directed_lane_router.mjs';
import {isExistingTrafficBridge} from './city_road_traffic_plan.mjs';
import {createCarWorld,carFits} from './car_drive.mjs';
import {cityRoadArrivalPoses} from './city_road_destinations.mjs';
import {planCityServiceAccess} from './city_service_access_plan.mjs';

/** Identical deterministic arithmetic to the host wrapper; all returned fields clone safely. */
export function buildEnvironmentVisualPlans({topology,instances=[],keepouts=[],decorPlan={colliders:[]}}={}){
  const landscape=createLandscapePlan(),railPlan=createExplorationRailwayPlan({landscape,topology});
  const roadKeepouts=[...keepouts,...explorationKeepouts([{collision:{worldBodies:decorPlan.colliders||[]}}])];
  let parkingPlan=createCityParkingPlan({topology,instances,keepouts:roadKeepouts,railPlan});
  const {isRoad,paintSafe,safeSign,...initialRoadPlan}=createCityRoadDressingPlan({topology,landscape,railPlan,keepouts:[...roadKeepouts,...parkingPlan.keepouts],accessKeepouts:parkingPlan.accessKeepouts,instances,pedestrianBodies:[...decorPlan.colliders,...parkingPlan.colliders]});
  let roadPlan=initialRoadPlan;
  parkingPlan=replanCityParkingWalks(parkingPlan,{topology,instances,keepouts:roadKeepouts,railPlan,extraBodies:[...roadPlan.colliders,...decorPlan.colliders]});
  ({parkingPlan,roadPlan}=resolveCityParkingPedestrianAccess({parkingPlan,roadPlan,topology,instances,extraBodies:decorPlan.colliders,railPlan,metresPerCell:4.1}));
  parkingPlan.access=planCityParkingAccess({plan:parkingPlan,topology,instances,extraBodies:[...roadPlan.colliders,...decorPlan.colliders]});
  const staticRoadWorld=createCarWorld(topology,[...instances.flatMap(i=>(i.userData?.instance||i).collision?.worldBodies||[]),...roadPlan.colliders,...parkingPlan.colliders,...decorPlan.colliders],4.1);
  const laneRoad=(x,z)=>!!topology.roadMask?.[Math.floor(z/4.1)]?.[Math.floor(x/4.1)]||isExistingTrafficBridge(topology,x,z,4.1);
  const laneOptions={plan:roadPlan.trafficPlan,isRoad:laneRoad,poseAllowed:(x,z,yaw)=>carFits(x,z,yaw,staticRoadWorld)};
  roadPlan.preparedLaneGraph=prepareDirectedLanePlan({...laneOptions,arrivalPoses:cityRoadArrivalPoses({parkingPlan,instances,isRoad:laneRoad}),arrivalMaxDistance:8});
  const laneRouter=createDirectedLaneRouter({...laneOptions,preparedPlan:roadPlan.preparedLaneGraph});
  parkingPlan.access=augmentCityParkingLaneEntries({plan:parkingPlan,topology,instances,extraBodies:[...roadPlan.colliders,...decorPlan.colliders],trafficPlan:roadPlan.preparedLaneGraph.plan,arrivalIsConnected:point=>laneRouter.snap(point,{arrival:true,maxDistance:8}).length>0});
  roadPlan.serviceAccess=planCityServiceAccess({trafficPlan:roadPlan.preparedLaneGraph.plan,instances,topology,extraBodies:[...roadPlan.colliders,...parkingPlan.colliders,...decorPlan.colliders],roadSupportRects:parkingPlan.roadSupportRects});
  // Source NPCs request a 12 m arrival radius. Warm exactly those driveway
  // goals here as well as the 8 m map goals, instead of doing thousands of
  // connector hull checks in the first driving frame. Exact anchors need none.
  for(const entry of parkingPlan.access.routes)if(entry.kind==='entry'&&!entry.laneAnchor)laneRouter.snap(entry.points[0],{arrival:true,maxDistance:12});
  // Additional entries begin at exact prepared anchors, so they need no new
  // snap search or second graph compilation. Retain the worker's warm cache.
  roadPlan.preparedLaneGraph.arrivalSnapData=laneRouter.exportArrivalCache();
  const grassPlan=planEnvironmentGrass({topology,landscape,railPlan,keepouts:[...keepouts,...parkingPlan.keepouts],decorPlan});
  return {grassPlan,roadPlan,parkingPlan};
}
