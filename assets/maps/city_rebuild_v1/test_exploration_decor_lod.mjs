import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createExplorationDecor} from './exploration_decor.mjs';
import {buildExplorationDecorPlan} from './exploration_decor_worker_core.mjs';
const threeUrl=pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js').href;
registerHooks({resolve(s,c,next){return next(s==='three'?threeUrl:s,c);}});
const THREE=await import(threeUrl);
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const read=name=>JSON.parse(fs.readFileSync(new URL(name,import.meta.url),'utf8'));
const plan=buildExplorationDecorPlan({topology:read('./topology_for_placement.json'),instances:[...read('./buildings_placement.v1.json').instances,...read('./decor_placement.v1.json').instances]});
const before=JSON.stringify(plan),render=createExplorationDecor({THREE,RoundedBoxGeometry,plan});
const original=new Map();
for(const chunk of render.object.children)for(const mesh of chunk.children)original.set(mesh,{geometry:mesh.geometry,matrices:mesh.instanceMatrix.array.slice(),colors:mesh.instanceColor.array.slice(),ids:[...mesh.userData.objectIds],bounds:mesh.boundingBox.clone()});
assert.equal(render.colliders,plan.colliders);assert.equal(render.mapFeatures,plan.mapFeatures);
const triangleCount=mesh=>(mesh.geometry.index?.count??mesh.geometry.attributes.position.count)/3*mesh.count;
const report=[];
for(const focus of [{x:611,z:83},{x:370,z:410},{x:-130,z:330},{x:280,z:-66},{x:730,z:640}]){
  render.update({focus,maxDistance:420});
  let triangles=0,calls=0;
  for(const chunk of render.object.children)if(chunk.visible)for(const mesh of chunk.children){triangles+=triangleCount(mesh);calls++;}
  assert.equal(triangles,render.stats.visibleTriangles);assert.equal(calls,render.stats.visibleDrawCalls);
  assert.ok(triangles<render.stats.fullQualityVisibleTriangles*.8,'LOD must lower real tessellation in '+JSON.stringify(focus));
  report.push({...focus,calls,triangles,baseline:render.stats.fullQualityVisibleTriangles,savedPercent:+(100*(1-triangles/render.stats.fullQualityVisibleTriangles)).toFixed(1),detailChunks:[...render.stats.detailChunks]});
}
// A whole composition is protected by its closest bound, including giant crowns.
for(const chunk of render.object.children){
  const b=chunk.userData.bounds,focus={x:(b.minX+b.maxX)/2,z:b.minZ-64};
  render.update({focus,maxDistance:1e6});assert.equal(chunk.userData.detailLevel,0);
  for(const mesh of chunk.children)assert.equal(mesh.geometry,original.get(mesh).geometry,'near geometry identical');
  render.update({focus:{...focus,z:b.minZ-70},maxDistance:1e6});assert.equal(chunk.userData.detailLevel,0,'hysteresis holds near');
  render.update({focus:{...focus,z:b.minZ-73},maxDistance:1e6});assert.equal(chunk.userData.detailLevel,1);
  render.update({focus:{...focus,z:b.minZ-189},maxDistance:1e6});assert.equal(chunk.userData.detailLevel,2);
  for(const mesh of chunk.children){
    const snapshot=original.get(mesh);
    assert.deepEqual(mesh.instanceMatrix.array,snapshot.matrices);assert.deepEqual(mesh.instanceColor.array,snapshot.colors);assert.deepEqual(mesh.userData.objectIds,snapshot.ids);
    // Lower polygon counts must not invalidate the conservative instanced bounds.
    mesh.geometry.computeBoundingBox();const a=mesh.geometry.boundingBox,ref=snapshot.geometry.boundingBox;
    for(const axis of ['x','y','z']){assert.ok(Math.abs(a.min[axis]-ref.min[axis])<1e-6);assert.ok(Math.abs(a.max[axis]-ref.max[axis])<1e-6);}
    assert.deepEqual(mesh.boundingBox,snapshot.bounds);assert.equal(mesh.castShadow,false);
    assert.ok(triangleCount(mesh)<=((snapshot.geometry.index?.count??snapshot.geometry.attributes.position.count)/3*mesh.count));
  }
  render.update({focus:{...focus,z:b.minZ-182},maxDistance:1e6});assert.equal(chunk.userData.detailLevel,2,'hysteresis holds far');
  render.update({focus:{...focus,z:b.minZ-180},maxDistance:1e6});assert.equal(chunk.userData.detailLevel,1);
}
assert.equal(JSON.stringify(plan),before,'renderer must not edit physics, map features or placement');
render.update({focus:{x:1e6,z:1e6},maxDistance:420});assert.equal(render.stats.visibleDrawCalls,0);
const start=performance.now();for(let i=0;i<1000;i++)render.update({focus:{x:370+i*.01,z:410},maxDistance:420});
const updateMs=(performance.now()-start)/1000;
assert.ok(updateMs<5,'LOD update must not introduce material CPU overhead');
const ownedGeometry=new Set();
for(const {geometry}of original.values())ownedGeometry.add(geometry);
for(const focus of [{x:1e5,z:1e5},{x:370,z:410}]){render.update({focus,maxDistance:1e6});for(const chunk of render.object.children)for(const mesh of chunk.children)ownedGeometry.add(mesh.geometry);}
const disposal=new Map();for(const geometry of ownedGeometry){disposal.set(geometry,0);geometry.addEventListener('dispose',()=>disposal.set(geometry,disposal.get(geometry)+1));}
render.dispose();for(const count of disposal.values())assert.equal(count,1);
console.log('PASS real RoundedBox LOD, identical near geometry/transforms/IDs/colliders, bounds, hysteresis, culling, stats, disposal');
console.log(JSON.stringify({updateMs,report},null,2));
