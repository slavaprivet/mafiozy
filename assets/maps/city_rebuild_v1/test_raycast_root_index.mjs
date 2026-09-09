import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createRaycastRootIndex} from './raycast_root_index.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/')+'build/three.module.js'));
const scene=new THREE.Scene(),roots=[];
for(let i=0;i<80;i++){
 const root=new THREE.Group();root.position.set((i%10-5)*18,0,(Math.floor(i/10)-4)*20);root.name='world-root-'+i;
 const mesh=new THREE.Mesh(new THREE.BoxGeometry(5,5,5),new THREE.MeshBasicMaterial());root.add(mesh);scene.add(root);roots.push(root);
}
// Parent visibility must not remove an authoritative hit candidate.
roots[7].visible=false;
const instanced=new THREE.InstancedMesh(new THREE.BoxGeometry(2,2,2),new THREE.MeshBasicMaterial(),4);for(let i=0;i<4;i++)instanced.setMatrixAt(i,new THREE.Matrix4().makeTranslation(60+i*7,0,35));instanced.instanceMatrix.needsUpdate=true;instanced.computeBoundingBox();const instancedRoot=new THREE.Group();instancedRoot.add(instanced);scene.add(instancedRoot);roots.push(instancedRoot);
scene.updateMatrixWorld(true);const index=createRaycastRootIndex({THREE,roots,padding:3}),ray=new THREE.Raycaster(),origin=new THREE.Vector3(),direction=new THREE.Vector3();let checks=0,candidateTotal=0,baselineTotal=0;
for(let i=0;i<2400;i++){
 origin.set(-120+(i*37%241),-3+(i%7),-120+(i*71%241));direction.set(Math.sin(i*1.7),((i%9)-4)*.035,Math.cos(i*2.3)).normalize();const far=20+(i%11)*22;
 ray.set(origin,direction);ray.near=.001;ray.far=far;
 const baseline=ray.intersectObjects(roots,true).find(result=>result.object.visible!==false&&result.distance>.001)||null;
 const candidates=index.query(origin,direction,far);const indexed=ray.intersectObjects(candidates,true).find(result=>result.object.visible!==false&&result.distance>.001)||null;
 assert.equal(indexed?.object||null,baseline?.object||null,'same exact mesh '+i);assert.equal(indexed?.instanceId??null,baseline?.instanceId??null,'same exact instance '+i);if(baseline)assert.ok(Math.abs(indexed.distance-baseline.distance)<1e-8,'same triangle distance '+i);
 candidateTotal+=candidates.length;baselineTotal+=roots.length;checks++;
}
// The legacy hit filter checks the mesh's own flag, not an ancestor's. The
// broadphase must therefore retain hidden-parent roots as candidates too.
const hiddenOrigin=roots[7].getWorldPosition(new THREE.Vector3()).add(new THREE.Vector3(0,0,-40));direction.set(0,0,1);ray.set(hiddenOrigin,direction);ray.near=.001;ray.far=80;const hiddenBaseline=ray.intersectObjects([roots[7]],true).find(result=>result.object.visible!==false&&result.distance>.001);assert.ok(hiddenBaseline);const hiddenCandidates=index.query(hiddenOrigin,direction,80);assert.ok(hiddenCandidates.includes(roots[7]));const hiddenIndexed=ray.intersectObjects(hiddenCandidates,true).find(result=>result.object.visible!==false&&result.distance>.001);assert.equal(hiddenIndexed?.object,hiddenBaseline.object);checks++;
assert.ok(candidateTotal<baselineTotal*.2,'broadphase must materially prune roots');index.dispose();
console.log(JSON.stringify({status:'PASS',checks,roots:roots.length,averageCandidates:candidateTotal/checks,baselineRoots:baselineTotal/checks}));
