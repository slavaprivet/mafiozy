import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createVehicleRenderBatches,setVehicleRenderDetailOptimization,getVehicleRenderSourceMaterial} from './vehicle_render_batches.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import('three');
function fixture(enabled=true,available=true){
 const root=new T.Group(),interior=new T.Group();interior.name='Interior_Test';root.add(interior);
 const pairMaterial=new T.MeshStandardMaterial(),legacyMaterial=new T.MeshStandardMaterial(),paint=new T.MeshStandardMaterial();
 const make=(name,material,parent=interior)=>{const mesh=new T.Mesh(new T.BoxGeometry(),material);mesh.name=name;mesh.castShadow=mesh.receiveShadow=true;parent.add(mesh);return mesh;};
 const pair=[make('fixed_a',pairMaterial),make('fixed_b',pairMaterial)],legacy=[0,1,2].map(i=>make('legacy_'+i,legacyMaterial)),arches=[];
 for(const id of ['front_left','front_right','rear_left','rear_right']){const group=new T.Group();group.name='Wheel_arch_'+id;root.add(group);const lip=make('Wheel_arch_lip_'+id,paint,group);lip.userData.wheelArchFor=id;arches.push(lip);}
 const fake=make('Wheel_arch_lip_front_left',paint,root);fake.userData.wheelArchFor='front_left';
 root.updateMatrixWorld(true);const original=new Map();root.traverse(n=>{if(n.isMesh)original.set(n,n.material)});
 const api=createVehicleRenderBatches({THREE:T,root,includeBody:true,detailOptimization:available});if(!enabled)api.setDetailOptimizationEnabled(false);
 return {root,interior,pair,legacy,arches,fake,api,original};
}
for(const initiallyEnabled of [true,false]){
 const f=fixture(initiallyEnabled),{root,api,pair,legacy,arches,original}=f;
 assert.equal(api.stats.detailBatches,2);assert.equal(api.stats.detailMembers,6);assert.equal(api.stats.archMembers,4);assert.equal(f.fake.material,original.get(f.fake),'name alone cannot admit a moving/unowned arch');
 const legacyHidden=legacy.map(n=>n.material);
 for(const enabled of [false,true,false,true]){
  assert.equal(setVehicleRenderDetailOptimization(root,enabled),enabled);
  for(const n of [...pair,...arches]){assert.equal(n.material===original.get(n),!enabled);assert.equal(getVehicleRenderSourceMaterial(n),original.get(n));}
  legacy.forEach((n,i)=>assert.equal(n.material,legacyHidden[i],'old batches never change during A/B'));
  const detail=[];root.traverse(n=>{if(n.userData.vehicleDetailRenderBatch)detail.push(n)});assert(detail.every(n=>n.visible===enabled));
 }
 api.setDetailOptimizationEnabled(false);api.dispose();api.dispose();assert.equal(setVehicleRenderDetailOptimization(root,true),null);
 for(const[n,material]of original)assert.equal(n.material,material);
}
{
 const f=fixture(false,false);assert.equal(f.api.stats.detailOptimizationAvailable,false);assert.equal(f.api.stats.detailBatches,0);assert.equal(f.api.stats.detailMembers,0);assert.equal(f.api.stats.batches,1);assert.equal(f.api.stats.members,3);
 for(const n of [...f.pair,...f.arches])assert.equal(n.material,f.original.get(n));
 assert.equal(setVehicleRenderDetailOptimization(f.root,true),false,'unsupported constructor cannot allocate or enable detail batches at runtime');f.api.dispose();
}
for(const enabled of [true,false])for(const [label,mutate]of [
 ['geometry version',n=>{n.geometry.attributes.position.needsUpdate=true}],
 ['geometry replacement',n=>{n.geometry=new T.BoxGeometry(2,1,1)}],
 ['material replacement',n=>{n.material=new T.MeshStandardMaterial({color:'red'})}],
 ['detached',n=>{n.userData.detached=true}],
 ['reparented',n=>{n.parent.parent.add(n)}],
 ['cast shadow',n=>{n.castShadow=false}],
 ['layers',n=>{n.layers.set(2)}],
 ['children ownership',n=>{n.parent.name='Wheel_attachment_front_left'}],
 ]){
 const f=fixture(enabled),n=f.arches[0];mutate(n);const expectedMaterial=label==='material replacement'?n.material:f.original.get(n);
 f.api.update();assert.equal(f.api.stats.fallbackMembers,1,label+' falls back even while detail disabled');assert.equal(n.material,expectedMaterial);
 f.api.setDetailOptimizationEnabled(!enabled);f.api.setDetailOptimizationEnabled(enabled);assert.equal(n.material,expectedMaterial,label+' never resurrects after A/B');f.api.dispose();
}
{
 const f=fixture(false),n=f.arches[0];n.position.set(.2,.1,-.3);n.scale.set(.85,1.1,.92);f.root.updateMatrixWorld(true);const expected=n.matrixWorld.clone();
 f.api.setDetailOptimizationEnabled(true);f.root.updateMatrixWorld(true);const matrix=new T.Matrix4();let matched=false;
 f.root.traverse(batch=>{if(!batch.userData.vehicleDetailRenderBatch)return;for(let i=0;i<batch.instanceCount;i++){batch.getMatrixAt(i,matrix);matrix.premultiply(batch.matrixWorld);if(matrix.elements.every((v,k)=>Math.abs(v-expected.elements[k])<1e-6))matched=true;}});
 assert(matched,'transform changes while disabled transfer exactly on re-enable');n.visible=false;f.api.update();f.api.setDetailOptimizationEnabled(false);f.api.setDetailOptimizationEnabled(true);assert.equal(n.visible,false,'authored hidden sources stay hidden');f.api.dispose();
}
{
 const f=fixture(false),canonical=f.pair[0].material;canonical.color.set('#c84933');f.api.setDetailOptimizationEnabled(true);
 let reflected=false;f.root.traverse(n=>{if(n.userData.vehicleDetailRenderBatch&&n.material===canonical)reflected=true;});assert(reflected,'canonical material edits made while disabled remain live');f.api.dispose();
}
{
 const f=fixture(),replacement=f.pair[0].material;replacement.color.set('#abc123');f.api.update();
 assert.equal(f.api.stats.fallbackMembers,2,'editing the hidden replacement exits both pair members');assert.equal(replacement.visible,true);
 f.api.setDetailOptimizationEnabled(false);f.api.setDetailOptimizationEnabled(true);assert.equal(f.pair[0].material,replacement);assert.equal(f.pair[1].material,replacement);f.api.dispose();assert.equal(f.pair[0].material,replacement,'fallback material ownership survives dispose');
}
console.log('PASS detail pairs/strict fixed arches, exact legacy A/B preservation, exported lifecycle, geometry/material/deformation/detachment fallback while enabled and disabled, changed transforms and authored visibility');
