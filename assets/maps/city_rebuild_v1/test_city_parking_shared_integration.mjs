import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createLandscapePlan} from './landscape_plan.mjs';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';
import {buildExplorationDecorPlan} from './exploration_decor_worker_core.mjs';
import {explorationKeepouts} from './exploration_scene_support.mjs';
import {buildEnvironmentVisualPlans} from './environment_planning_worker_core.mjs';
import {createExplorationVehicleWorld} from './exploration_vehicle_support.mjs';
import {carFits} from './car_drive.mjs';
import {cityParkingCarFits} from './city_parking_plan.mjs';
import {mapKind} from './exploration_minimap.mjs';

const read=name=>JSON.parse(fs.readFileSync(new URL(name,import.meta.url)));
const topology=read('topology_for_placement.json'),instances=[...read('buildings_placement.v1.json').instances,...read('decor_placement.v1.json').instances];
const terrain=createLandscapePlan(),railPlan=createExplorationRailwayPlan({landscape:terrain,topology}),keepouts=explorationKeepouts(instances);
const decorPlan=buildExplorationDecorPlan({topology,instances,keepouts});
const plans=buildEnvironmentVisualPlans({topology,instances,keepouts,decorPlan}),parking=plans.parkingPlan;
const bodies=[...instances.flatMap(i=>i.collision?.worldBodies||[]),...decorPlan.colliders,...plans.roadPlan.colliders,...parking.colliders];
const world=createExplorationVehicleWorld({topology,bodies,terrain});
const failures=[];let carPoses=0,footPoses=0;
for(const lot of parking.lots){
 for(const path of lot.entryPaths)for(const p of path){
  if(!cityParkingCarFits(parking,p.x,p.z,p.yaw)||!carFits(p.x,p.z,p.yaw,world))failures.push({lot:lot.id,kind:'car_entry',p});
  carPoses++;
 }
 const marker=parking.mapFeatures.find(p=>p.id===lot.id);
 assert.equal(mapKind(marker.kind),'parking');
 assert.ok(marker.x>=lot.rect.minX&&marker.x<=lot.rect.maxX&&marker.z>=lot.rect.minZ&&marker.z<=lot.rect.maxZ,'parking marker stays over the actual surface');
}
for(const bay of parking.bays){if(!carFits(bay.x,bay.z,bay.yaw,world))failures.push({lot:bay.lotId,kind:'bay',p:bay});carPoses++;}
for(const route of parking.walkingRoutes)for(let i=1;i<route.points.length;i++){
 const a=route.points[i-1],b=route.points[i],steps=Math.max(1,Math.ceil(Math.hypot(a.x-b.x,a.z-b.z)/.3));
 for(let k=0;k<=steps;k++){
  const p={x:a.x+(b.x-a.x)*k/steps,z:a.z+(b.z-a.z)*k/steps};
  if([[0,0],[.36,0],[-.36,0],[0,.36],[0,-.36]].some(([dx,dz])=>!world(p.x+dx,p.z+dz)))failures.push({building:route.buildingId,lot:route.lotId,kind:'pedestrian_link',p});
  footPoses++;
 }
}
assert.deepEqual(failures.slice(0,12),[],'the full scene must preserve access, including procedural trees and every road/parking post');
assert.equal(parking.stats.uncoveredBuildings,0,'all current target entrances need shared parking coverage');
const walk=fs.readFileSync(new URL('walk_preview.mjs',import.meta.url),'utf8');
assert.match(walk,/carBodies\.push\(\.\.\.environmentVisuals\.colliders\)/);
assert.match(walk,/environmentVisuals\?\.parkingPlan\?\.lots/);
assert.match(walk,/environmentVisuals\?\.mapFeatures/);
console.log(JSON.stringify({status:'PASS',...parking.stats,carPoses,footPoses,proceduralColliders:decorPlan.colliders.length,roadColliders:plans.roadPlan.colliders.length}));
