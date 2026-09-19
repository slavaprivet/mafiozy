import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {resolveCityParkingPedestrianAccess} from '../../assets/maps/city_rebuild_v1/city_parking_pedestrian_routes.mjs';
import {createLandscapePlan} from '../../assets/maps/city_rebuild_v1/landscape_plan.mjs';
import {createExplorationRailwayPlan} from '../../assets/maps/city_rebuild_v1/exploration_railway_plan.mjs';
const input=process.argv[2]||'outputs/roads_logical_20260912/integration_candidate_snapshot.json',snapshot=JSON.parse(fs.readFileSync(input)),topology=JSON.parse(fs.readFileSync('assets/maps/city_rebuild_v1/topology_for_placement.json')),railPlan=createExplorationRailwayPlan({topology,landscape:createLandscapePlan()}),start=performance.now(),result=resolveCityParkingPedestrianAccess({parkingPlan:snapshot.parkingPlan,roadPlan:snapshot.roadPlan,topology,instances:[...snapshot.buildings,...snapshot.authoredDecor],extraBodies:snapshot.decorPlan.colliders,railPlan});
fs.writeFileSync('outputs/roads_logical_20260912/parking_pedestrian_production_probe.json',JSON.stringify({...result,elapsedMs:performance.now()-start},null,2));console.log(JSON.stringify({stats:result.stats,uncovered:result.parkingPlan.pedestrianAccess.uncovered,elapsedMs:performance.now()-start},null,2));
