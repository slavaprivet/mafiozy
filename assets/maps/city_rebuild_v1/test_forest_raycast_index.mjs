import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {createLandscapePlan} from './landscape_plan.mjs';
import {createLandscapeTerrain} from './landscape_terrain.mjs';
import {planExplorationDecor} from './exploration_decor_plan.mjs';
import {createExplorationDecor} from './exploration_decor.mjs';
import {createRaycastRootIndex} from './raycast_root_index.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/')+'build/three.module.js'));
class RoundedBoxGeometry extends THREE.BoxGeometry { constructor(w,h,d){super(w,h,d)} }
const read=name=>JSON.parse(fs.readFileSync(new URL(name,import.meta.url),'utf8'));
const terrainPlan=createLandscapePlan(),terrain=createLandscapeTerrain({THREE,plan:terrainPlan}),decorPlan=planExplorationDecor({terrain:terrainPlan,topology:read('./topology_for_placement.json'),buildings:read('./buildings_placement.v1.json').instances,existingDecor:read('./decor_placement.v1.json').instances}),decor=createExplorationDecor({THREE,RoundedBoxGeometry,plan:decorPlan});
const scene=new THREE.Scene();scene.add(terrain.object,decor.object);scene.updateMatrixWorld(true);
const roots=[...terrain.object.children,...decor.object.children],index=createRaycastRootIndex({THREE,roots,padding:4}),ray=new THREE.Raycaster(),origin=new THREE.Vector3(),direction=new THREE.Vector3();let candidateTotal=0,baselineTotal=0,checks=0;
for(let i=0;i<300;i++){
 const angle=i*2.399963,side=i%2?-1:1;origin.set(370+Math.cos(angle)*330,2.2,410+Math.sin(angle)*360);direction.set(Math.sin(angle+side*Math.PI/2),-.025,Math.cos(angle+side*Math.PI/2)).normalize();ray.set(origin,direction);ray.near=.001;ray.far=180;
 const baseline=ray.intersectObjects(roots,true).find(hit=>hit.object.visible!==false&&hit.distance>.001)||null,candidates=index.query(origin,direction,180),indexed=ray.intersectObjects(candidates,true).find(hit=>hit.object.visible!==false&&hit.distance>.001)||null;
 assert.equal(indexed?.object||null,baseline?.object||null,'same forest/terrain mesh '+i);assert.equal(indexed?.instanceId??null,baseline?.instanceId??null,'same forest instance '+i);if(baseline)assert.ok(Math.abs(indexed.distance-baseline.distance)<1e-7,'same hit distance '+i);candidateTotal+=candidates.length;baselineTotal+=roots.length;checks++;
}
assert.ok(candidateTotal<baselineTotal*.35,'real forest broadphase must prune most chunk roots');index.dispose();decor.dispose();terrain.dispose();
console.log(JSON.stringify({status:'PASS',checks,roots:roots.length,averageCandidates:candidateTotal/checks,baselineRoots:baselineTotal/checks}));
