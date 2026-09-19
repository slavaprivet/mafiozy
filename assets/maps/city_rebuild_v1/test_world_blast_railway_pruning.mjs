import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';
import {createExplorationRailway} from './exploration_railway.mjs';
import {applyWorldBlast} from './world_blast.mjs';

const vendor=process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor',threeURL=pathToFileURL(path.join(vendor,'build/three.module.js')).href;
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?threeURL:specifier,context)}});
const THREE=await import(threeURL),{GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')).href),topology=JSON.parse(fs.readFileSync(new URL('./topology_for_placement.json',import.meta.url))),plan=createExplorationRailwayPlan({topology}),bytes=fs.readFileSync(new URL('../../rail/city_v3/v1/regional_train_and_track_tiles_v1.glb',import.meta.url));
const railway=await createExplorationRailway({THREE,plan,loader:{loadAsync:async()=>new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')}}),scene=new THREE.Scene();scene.add(railway.object);scene.updateMatrixWorld(true);
const ranged=[];railway.object.traverse(mesh=>{if(mesh.userData.worldBlastInstanceRanges)ranged.push(mesh)});assert.ok(ranged.length>=3,'rails, sleepers and static station parts expose conservative ranges');
for(const mesh of ranged){let next=0;for(const range of mesh.userData.worldBlastInstanceRanges){assert.equal(range.start,next);assert.ok(range.count>0&&range.count<=64);assert.ok(range.bounds.isBox3&&!range.bounds.isEmpty());next+=range.count}assert.equal(next,mesh.count);assert.equal(mesh.userData.worldBlastRangeCount,mesh.count)}
const sample=plan.sample(plan.length*.37),options={point:new THREE.Vector3(sample.x,sample.y,sample.z),radius:11,power:80,roots:[railway.object],maxMeshes:96,maxPanels:96,maxSurfaceHits:0},reference=applyWorldBlast(THREE,{...options,spatialPrune:false}),pruned=applyWorldBlast(THREE,options);
assert.ok(reference.candidates>0,'actual railway geometry is reached');assert.equal(pruned.candidates,reference.candidates);assert.equal(pruned.broken,reference.broken);assert.equal(pruned.surfaceHits,reference.surfaceHits);assert.ok(pruned.prunedInstanceRanges>40);assert.ok(pruned.prunedInstances>3000);assert.ok(pruned.instancesTested<reference.instancesTested*.2,'range pruning skips most distant rail instances without changing effects');
railway.dispose();
console.log(JSON.stringify({status:'PASS',candidates:pruned.candidates,referenceInstances:reference.instancesTested,prunedInstances:pruned.instancesTested,prunedRanges:pruned.prunedInstanceRanges,skippedInstances:pruned.prunedInstances}));
