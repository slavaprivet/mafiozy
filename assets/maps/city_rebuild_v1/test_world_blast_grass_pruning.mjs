import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createEnvironmentGrass} from './environment_grass.mjs';
import {applyWorldBlast} from './world_blast.mjs';

const THREE=await import(pathToFileURL((process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/')+'build/three.module.js'));
const tufts=[];
for(const [cluster,x] of [-80,-40,0,40,80].entries())for(let index=0;index<120;index++)tufts.push({
 id:`grass-${cluster}-${index}`,x:x+(index%12)*.45,z:Math.floor(index/12)*.45-2,y:0,height:.8,width:.7,yaw:index*.13,style:'grass',color:index%2?0x70824c:0x849259,radius:.7,slopeX:0,slopeZ:0,
});
const grass=createEnvironmentGrass({THREE,plan:{stats:{tufts:tufts.length},tufts},limits:{chunkSize:32,viewDistance:130,maxVisibleTufts:1000,maxVisibleTriangles:90000,maxVisibleBatches:24}});
grass.update({time:0,focus:{x:0,z:0},force:true});
const scene=new THREE.Scene();scene.add(grass.object);scene.updateMatrixWorld(true);
const ignored=new THREE.Mesh(new THREE.BoxGeometry(2,2,2),new THREE.MeshStandardMaterial());ignored.userData.worldBlastIgnore=true;scene.add(ignored);scene.updateMatrixWorld(true);
const options={point:new THREE.Vector3(1,0,0),radius:7,power:80,roots:[grass.object],maxMeshes:96,maxPanels:96,maxSurfaceHits:0};
const reference=applyWorldBlast(THREE,{...options,spatialPrune:false}),pruned=applyWorldBlast(THREE,options);
assert.ok(reference.candidates>0,'blast reaches actual visible grass geometry');
assert.equal(pruned.candidates,reference.candidates,'aggregate grass bounds preserve every in-radius candidate');
assert.equal(pruned.broken,reference.broken);
assert.equal(pruned.surfaceHits,reference.surfaceHits);
assert.ok(pruned.prunedInstancedMeshes>=4,'distant visible grass batches are skipped whole');
assert.ok(pruned.instancesTested<reference.instancesTested*.35,'grass instance inspection is materially reduced');
const ignoredOnly=applyWorldBlast(THREE,{point:new THREE.Vector3(),radius:7,power:80,roots:[ignored],maxSurfaceHits:1});assert.equal(ignoredOnly.candidates,0,'render-only lawn details never enter blast work');
grass.dispose();
console.log(JSON.stringify({status:'PASS',candidates:pruned.candidates,referenceInstances:reference.instancesTested,prunedInstances:pruned.instancesTested,prunedMeshes:pruned.prunedInstancedMeshes}));
