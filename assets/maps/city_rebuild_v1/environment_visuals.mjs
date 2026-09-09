import {createEnvironmentSurfaceMaterials} from './environment_surface_materials.mjs';
import {createEnvironmentGrass} from './environment_grass.mjs';
import {createCityRoadDressing} from './city_road_dressing.mjs';
import {buildEnvironmentVisualPlans} from './environment_planning_worker_core.mjs';
import {createCityParking} from './city_parking.mjs';
import {isCityParkingSurface,cityParkingGroundHeight} from './city_parking_plan.mjs';

/** Visual detail shares the existing terrain and collision units; it never changes the map. */
export function createEnvironmentVisuals({THREE,topology,landscape,railPlan,instances,decorPlan,keepouts,nativeMeshes=[],depthAt,preparedPlans}={}){
 const surfaces=createEnvironmentSurfaceMaterials({THREE});
 for(const mesh of nativeMeshes){const previous=mesh.material;surfaces.prepareMesh(mesh,{kind:mesh.userData.nativeTerrainKind,depthAt});if(previous!==mesh.material)for(const material of Array.isArray(previous)?previous:[previous])material?.dispose()}
 for(const mesh of landscape.object.children){
  if(mesh.userData.landscapeGround)surfaces.prepareMesh(mesh,{kind:'ground',vertexColors:true});
  else if(mesh.userData.landscapeWater)surfaces.prepareMesh(mesh,{kind:'water',depthAt});
  else if(mesh.userData.landscapeTrail)surfaces.prepareMesh(mesh,{kind:'trail',vertexColors:true});
 }
 const {roadPlan,grassPlan,parkingPlan}=preparedPlans||buildEnvironmentVisualPlans({topology,instances,keepouts,decorPlan});
 const roads=createCityRoadDressing({THREE,plan:roadPlan});
 const grass=createEnvironmentGrass({THREE,plan:grassPlan});
 const parking=createCityParking({THREE,plan:parkingPlan});
 const object=new THREE.Group();object.name='Город · покрытия, трава и дорожное оформление';object.add(roads.object,grass.object,parking.object);
 let disposed=false,lastCpuMs=0,maxCpuMs=0;
 return {
  object,roadPlan,grassPlan,parkingPlan,colliders:[...(roads.colliders||roadPlan.colliders||[]),...parkingPlan.colliders],mapFeatures:[...(roads.mapFeatures||roadPlan.mapFeatures||[]),...parkingPlan.mapFeatures],
  isParkingSurface:(x,z)=>isCityParkingSurface(parkingPlan,x,z),parkingGroundHeight:(x,z)=>cityParkingGroundHeight(parkingPlan,x,z),
  setWaterRipples(events){if(!disposed)return surfaces.setWaterRipples?.(events)??0;return 0},
  update({dt=0,time=0,focus,camera,actorPosition,actorRadius=.65,actorGround,actorFeet}={}){
   if(disposed)return;const started=performance.now();
   surfaces.update(time);grass.update({time,focus,camera,actorPosition,actorRadius,actorGround,actorFeet});roads.update(dt,{time,focus});parking.update({focus});
   lastCpuMs=performance.now()-started;maxCpuMs=Math.max(maxCpuMs,lastCpuMs);
  },
  get stats(){return {surfaces:surfaces.stats,grass:grass.stats,roads:roads.stats,parking:parking.stats,updateMs:+lastCpuMs.toFixed(3),maxUpdateMs:+maxCpuMs.toFixed(3)}},
  dispose(){if(disposed)return;disposed=true;roads.dispose();grass.dispose();parking.dispose();surfaces.dispose();object.removeFromParent()},
 };
}
