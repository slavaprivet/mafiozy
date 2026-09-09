import {createLandscapePlan} from './landscape_plan.mjs';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';
import {planEnvironmentGrass} from './environment_grass_plan.mjs';
import {createCityRoadDressingPlan} from './city_road_dressing_plan.mjs';
import {explorationKeepouts} from './exploration_scene_support.mjs';
import {createCityParkingPlan,replanCityParkingWalks} from './city_parking_plan.mjs';

/** Identical deterministic arithmetic to the host wrapper; all returned fields clone safely. */
export function buildEnvironmentVisualPlans({topology,instances=[],keepouts=[],decorPlan={colliders:[]}}={}){
  const landscape=createLandscapePlan(),railPlan=createExplorationRailwayPlan({landscape,topology});
  const roadKeepouts=[...keepouts,...explorationKeepouts([{collision:{worldBodies:decorPlan.colliders||[]}}])];
  let parkingPlan=createCityParkingPlan({topology,instances,keepouts:roadKeepouts,railPlan});
  const {isRoad,paintSafe,safeSign,...roadPlan}=createCityRoadDressingPlan({topology,landscape,railPlan,keepouts:[...roadKeepouts,...parkingPlan.keepouts],accessKeepouts:parkingPlan.accessKeepouts,instances});
  parkingPlan=replanCityParkingWalks(parkingPlan,{topology,instances,keepouts:roadKeepouts,railPlan,extraBodies:[...roadPlan.colliders,...decorPlan.colliders]});
  const grassPlan=planEnvironmentGrass({topology,landscape,railPlan,keepouts:[...keepouts,...parkingPlan.keepouts],decorPlan});
  return {grassPlan,roadPlan,parkingPlan};
}
