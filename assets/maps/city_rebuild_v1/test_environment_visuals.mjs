import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createLandscapeTerrain} from './landscape_terrain.mjs';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';
import {buildExplorationDecorPlan} from './exploration_decor_worker_core.mjs';
import {explorationKeepouts} from './exploration_scene_support.mjs';
import {createEnvironmentVisuals} from './environment_visuals.mjs';
import {buildEnvironmentVisualPlans} from './environment_planning_worker_core.mjs';

const vendor=process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js')).href);
const read=name=>JSON.parse(fs.readFileSync(new URL('./'+name,import.meta.url)));
const topology=read('topology_for_placement.json');
const instances=[...read('buildings_placement.v1.json').instances,...read('decor_placement.v1.json').instances];
const originalInstances=JSON.stringify(instances),originalGrid=JSON.stringify(topology.grid);
const landscape=createLandscapeTerrain({THREE}),railPlan=createExplorationRailwayPlan({landscape,topology});
const keepouts=explorationKeepouts(instances);
const decorPlan=buildExplorationDecorPlan({topology,instances,keepouts});
const nativeMeshes=['asphalt','grass','paving','sand','water'].map((kind,i)=>{
 const geometry=new THREE.PlaneGeometry(8,8);geometry.rotateX(-Math.PI/2);geometry.translate(100+i*12,kind==='water'?-.18:0,50);geometry.deleteAttribute('uv');
 const mesh=new THREE.Mesh(geometry,new THREE.MeshStandardMaterial());mesh.userData.nativeTerrainKind=kind;return mesh;
});
const positions=nativeMeshes.map(m=>m.geometry.attributes.position.array.slice());
const preparedPlans=structuredClone(buildEnvironmentVisualPlans({topology,instances,keepouts,decorPlan}));
const started=performance.now();
const visuals=createEnvironmentVisuals({preparedPlans,THREE,topology,landscape,railPlan,instances,decorPlan,keepouts,nativeMeshes,depthAt:()=>2.4});
const buildMs=performance.now()-started;
assert.equal(visuals.roadPlan,preparedPlans.roadPlan);assert.equal(visuals.grassPlan,preparedPlans.grassPlan);
assert.equal(visuals.parkingPlan,preparedPlans.parkingPlan);
assert.ok(visuals.parkingPlan.lots.some(l=>l.kind==='hospital'),'hospital parking survives actual scene keepouts');
for(const lot of visuals.parkingPlan.lots){assert.ok(visuals.isParkingSurface(lot.tour.x,lot.tour.z));assert.equal(visuals.parkingGroundHeight(lot.tour.x,lot.tour.z),0);assert.ok(visuals.mapFeatures.some(p=>p.id===lot.id));}
for(const tuft of visuals.grassPlan.tufts)for(const rect of visuals.parkingPlan.keepouts){assert.ok(Math.hypot(Math.max(rect.minX-tuft.x,0,tuft.x-rect.maxX),Math.max(rect.minZ-tuft.z,0,tuft.z-rect.maxZ))>tuft.radius,'grass bend stays outside parking');}
nativeMeshes.forEach((mesh,i)=>{assert.equal(mesh.material.userData.environmentSurface,true);assert.deepEqual(mesh.geometry.attributes.position.array,positions[i],'materials preserve physics geometry')});
assert.equal(JSON.stringify(instances),originalInstances,'native placements unchanged');
assert.equal(JSON.stringify(topology.grid),originalGrid,'road/water masks unchanged');
let lights=0;visuals.object.traverse(n=>{if(n.isLight)lights++});assert.equal(lights,0,'detail adds no shader light slots');
const observations=[];
for(const focus of[{x:69,z:373},{x:280,z:-66},{x:459,z:-326},{x:610,z:62}]){
 visuals.update({dt:1/60,time:10+observations.length,focus});const report=visuals.stats;
 assert.ok(report.grass.visibleBatches<=24);assert.ok(report.grass.visibleTufts<=1200);assert.ok(report.grass.visibleTriangles<=90000);
 assert.ok(report.roads.totalDraws<200);assert.equal(report.surfaces.passesPerMesh,1);assert.equal(report.surfaces.extraLights,0);
 assert.equal(report.parking.pointLights,0);assert.ok(report.parking.totalDraws<100);
 observations.push({focus,grass:report.grass.visibleTriangles,grassBatches:report.grass.visibleBatches,roadBatches:report.roads.visibleDraws,updateMs:report.updateMs});
}
assert.equal(visuals.stats.surfaces.time,3,'all animated surfaces share advancing time');
assert.equal(visuals.setWaterRipples([{x:817,z:425,age:.5,strength:1}]),1);
assert.equal(visuals.stats.surfaces.waterRipples,1,'actual contact events reach the water material');
visuals.setWaterRipples([]);assert.equal(visuals.stats.surfaces.waterRipples,0);
const materials=new Set();for(const mesh of [...nativeMeshes,...landscape.object.children])if(mesh.material?.userData.environmentSurface)materials.add(mesh.material);
let disposals=0;for(const m of materials)m.addEventListener('dispose',()=>disposals++);
visuals.dispose();visuals.dispose();assert.equal(disposals,materials.size,'shared surface materials disposed exactly once');
landscape.dispose();for(const m of nativeMeshes)m.geometry.dispose();
console.log(JSON.stringify({status:'PASS',buildMs:+buildMs.toFixed(1),nativeObjects:instances.length,sharedMaterials:materials.size,observations}));
