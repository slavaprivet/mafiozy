import {createLandscapePlan} from './landscape_plan.mjs';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';
import {planExplorationDecor} from './exploration_decor_plan.mjs';
import {createCityParkingPlan} from './city_parking_plan.mjs';

// Pure, structured-cloneable planning phase. Rendering still happens on the
// main thread; this only moves deterministic arithmetic out of first paint.
export function buildExplorationDecorPlan({topology,instances=[],keepouts=[],metresPerCell=4.1}={}){
 const terrain=createLandscapePlan(),railPlan=createExplorationRailwayPlan({landscape:terrain,topology});
 const parking=instances.length?createCityParkingPlan({topology,instances,keepouts,railPlan,metresPerCell}):null;
 return planExplorationDecor({terrain,topology,metresPerCell,keepouts:[...keepouts,...(parking?.keepouts||[]),...(parking?.accessKeepouts||[])],railPlan});
}
