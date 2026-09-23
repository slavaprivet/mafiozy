// Real Three r180 regression: render batches must not steal blast ownership
// from the exact source geometry, and finish coordinates must include both
// BatchedMesh and InstancedMesh transforms in renderer order.
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createStaticRenderBatches} from './static_render_batches.mjs';
import {applyWorldBlast} from './world_blast.mjs';
import {createBlastResponse} from './blast_response.mjs';
import {createInteriorFinish} from './interior_finishes.mjs';

const vendor=process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
assert.equal(T.REVISION,'180');

const scene=new T.Scene(),root=new T.Group(),instances=[];scene.add(root);
const geometry=new T.BoxGeometry(1.5,2,1),material=new T.MeshStandardMaterial({name:'blast wall',color:'#76513b'}),sources=[];
for(const x of [-4,0,4]){const group=new T.Group(),mesh=new T.Mesh(geometry,material);group.position.set(x,1,6);group.add(mesh);root.add(group);instances.push(group);sources.push(mesh);}
root.updateMatrixWorld(true);
function blast(options={}){
 const hits=[];
 const stats=applyWorldBlast(T,{point:new T.Vector3(0,1,0),radius:12,power:100,roots:[root],maxSurfaceHits:8,onSurfaceHit:payload=>hits.push({object:payload.hit.object,point:payload.point.toArray(),normal:payload.normal.toArray(),distance:payload.hit.distance}),...options});
 return {stats,hits};
}
const before=blast();assert.equal(before.hits.length,3,'baseline reaches all three authored walls');
const batches=createStaticRenderBatches({THREE:T,root,instances,minInstances:3,maxDistance:50,multiDraw:true});
assert.equal(batches.stats().members,3);assert.equal(root.children.filter(node=>node.userData.staticRenderBatch).length,1);
assert(sources.every(mesh=>mesh.material.visible===false&&mesh.material.userData.staticRenderSource===true));
const legacy=blast();assert.equal(legacy.hits.length,0,'negative control reproduces the hidden-source regression');
const fixed=blast({staticBatchSurfaceFix:true});assert.equal(fixed.hits.length,3);
assert.deepEqual(fixed.hits.map(hit=>hit.object),before.hits.map(hit=>hit.object),'callbacks stay on exact source meshes');
for(let i=0;i<fixed.hits.length;i++){
 assert.deepEqual(fixed.hits[i].point,before.hits[i].point);assert.deepEqual(fixed.hits[i].normal,before.hits[i].normal);assert.equal(fixed.hits[i].distance,before.hits[i].distance);
}
const response=createBlastResponse(T,scene,{getHero:()=>null,getVehicles:()=>[],getRoots:()=>[root],getGlass:()=>({}),groundHeight:()=>0,onHeroLaunch:()=>{},staticBatchSurfaceFix:true});
response.enqueue({point:new T.Vector3(0,1,0),radius:12,power:1});response.update();
assert.equal(response.stats().last.world.surfaceHits,3);assert.equal(response.stats().scorch.total,3,'blast response projects scorch on hidden source surfaces');response.dispose();
batches.dispose();assert(sources.every(mesh=>mesh.material===material));

const finish=createInteriorFinish(T,{finish:'tile'}),shader={vertexShader:'#include <project_vertex>',fragmentShader:'#include <color_fragment>'};finish.onBeforeCompile(shader);
const batchingAt=shader.vertexShader.indexOf('interiorMetric=batchingMatrix*interiorMetric'),instanceAt=shader.vertexShader.indexOf('interiorMetric=instanceMatrix*interiorMetric');
assert(batchingAt>0&&instanceAt>batchingAt,'renderer order is batchingMatrix then instanceMatrix');
assert.match(finish.customProgramCacheKey(),/^interior-finish-v2-/);

finish.dispose();geometry.dispose();material.dispose();
console.log('PASS static batching preserves exact blast surface callbacks and interior finish transform order');
