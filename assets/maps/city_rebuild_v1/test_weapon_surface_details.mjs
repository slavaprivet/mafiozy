import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {ARSENAL,createWeaponModel} from './hero_arsenal.mjs';

const vendor=process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const THREE=await import(pathToFileURL(`${vendor}/build/three.module.js`));
const canonical={
  nagan:[.14,.82],tt_pistol:[.15,.62],revolver:[.14,.92],deagle:[.15,.82],golden_colt:[.15,.68],
  sawn_off:[.2,.88],shotgun:[.2,1.42],uzi:[.22,.96],golden_uzi:[.22,.96],ak74:[.23,1.4],
  m16:[.23,1.4],tommy_gun:[.22,1.38],sniper:[.23,1.88],rpg:[.23,1.73],
};
const report=[];
for(const spec of ARSENAL.filter(x=>x.id!=='none')){
  const model=createWeaponModel(THREE,spec.id),data=model.userData;
  assert.equal(data.artRevision,'artist14-weapons-v2-ground-arsenal');
  assert(data.surfaceDetails.length>=20,`${spec.id}: individually authored surface details`);
  assert(data.surfaceDetailBatches<=6,`${spec.id}: detail draw calls must stay bounded`);
  assert.deepEqual(data.gripOrigin,[0,0,0]);
  assert.deepEqual(data.mountOffset,spec.twoHanded?[.15,1.1,spec.id==='rpg'?.24:.18]:[.24,1.07,.26]);
  canonical[spec.id].forEach((value,i)=>assert(Math.abs(data.muzzle[i+1]-value)<1e-12,`${spec.id}: muzzle anchor unchanged`));
  const support=({uzi:[0,-.01,.5],golden_uzi:[0,-.01,.5],tommy_gun:[0,-.1,.62],sawn_off:[0,.1,.42],rpg:[0,.09,.46],m16:[0,.1,.57]}[spec.id])??[0,.1,.62];
  assert.deepEqual(data.supportGrip,spec.twoHanded?support:null);
  const ejection=['nagan','revolver','rpg'].includes(spec.id)?null:!spec.twoHanded?[.105,.255,.34]:['shotgun','sawn_off'].includes(spec.id)?[.14,.3,.29]:[.13,.3,.37];
  assert.deepEqual(data.ejectionPort,ejection);
  const fullBounds=new THREE.Box3().setFromObject(model),batches=model.children.filter(x=>x.name==='batched_surface_detail');
  assert.equal(batches.length,data.surfaceDetailBatches);
  let triangles=0;
  for(const mesh of model.children){
    if(!mesh.isMesh)continue;
    const p=mesh.geometry.attributes.position;
    assert([...p.array].every(Number.isFinite));
    assert.equal(mesh.geometry.attributes.normal.count,p.count);
    assert.equal(mesh.geometry.attributes.uv.count,p.count);
    triangles+=(mesh.geometry.index?.count??p.count)/3;
  }
  assert(triangles<2500,`${spec.id}: maintain lightweight runtime model`);
  for(const mesh of batches)model.remove(mesh);
  const originalBounds=new THREE.Box3().setFromObject(model);
  for(const axis of ['x','y','z']){
    assert(fullBounds.min[axis]>=originalBounds.min[axis]-1e-7,`${spec.id}: no rear/side/underside silhouette expansion on ${axis}`);
    assert(fullBounds.max[axis]<=originalBounds.max[axis]+1e-7,`${spec.id}: no front/side/top silhouette expansion on ${axis}`);
  }
  report.push({id:spec.id,details:data.surfaceDetails.length,extraDrawCalls:batches.length,triangles});
  for(const mesh of batches)model.add(mesh);
  const materials=new Set();model.traverse(mesh=>{if(mesh.isMesh){mesh.geometry.dispose();materials.add(mesh.material)}});
  for(const material of materials)material.dispose();
}
assert.equal(report.length,14);
console.log(JSON.stringify({passed:true,checks:['all_14_detailed','anchors_unchanged','surface_batches_bounded','no_silhouette_expansion','finite_geometry','triangle_budget'],weapons:report}));
