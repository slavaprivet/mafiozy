import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {createLandscapePlan} from './landscape_plan.mjs';
import {planExplorationDecor} from './exploration_decor_plan.mjs';
import {createExplorationDecor} from './exploration_decor.mjs';
import {applyWorldBlast} from './world_blast.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/')+'build/three.module.js'));
class RoundedBoxGeometry extends THREE.BoxGeometry { constructor(w,h,d){super(w,h,d)} }
const topology=JSON.parse(fs.readFileSync(new URL('./topology_for_placement.json',import.meta.url),'utf8')),plan=planExplorationDecor({terrain:createLandscapePlan(),topology}),decor=createExplorationDecor({THREE,RoundedBoxGeometry,plan}),scene=new THREE.Scene();scene.add(decor.object);scene.updateMatrixWorld(true);
const tree=plan.objects.find(object=>object.zone==='western-pines'&&object.sizeClass),point=new THREE.Vector3(tree.x,tree.y+2,tree.z),options={point,radius:12,power:80,roots:[decor.object],maxMeshes:96,maxPanels:96,maxSurfaceHits:0},reference=applyWorldBlast(THREE,{...options,spatialPrune:false}),pruned=applyWorldBlast(THREE,options);
assert.ok(reference.candidates>0,'test blast reaches actual forest geometry');assert.equal(pruned.candidates,reference.candidates,'conservative chunk pruning preserves every in-radius candidate');assert.equal(pruned.broken,reference.broken);assert.ok(pruned.prunedChunks>0,'distant forest chunks are skipped');assert.ok(pruned.instancesTested<reference.instancesTested*.2,'forest instance inspection is materially reduced');assert.ok(pruned.sphereRejectedInstances>0,'near chunks reject distant instances before expensive AABB expansion');decor.dispose();
console.log(JSON.stringify({status:'PASS',candidates:pruned.candidates,referenceInstances:reference.instancesTested,prunedInstances:pruned.instancesTested,prunedChunks:pruned.prunedChunks,prunedMeshes:pruned.prunedInstancedMeshes}));
