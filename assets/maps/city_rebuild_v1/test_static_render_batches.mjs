import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {readFileSync} from 'node:fs';
import {createStaticRenderBatches} from './static_render_batches.mjs';

const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import('three');

const scene=new T.Scene(),root=new T.Group();scene.add(root);
const geometry=new T.BoxGeometry(1,1,1),material=new T.MeshStandardMaterial({name:'shared brick',color:0x884422});
const glass=new T.MeshStandardMaterial({name:'Glass',transparent:true,opacity:.5});
const instances=[];
for(let i=0;i<4;i++){
 const group=new T.Group(),mesh=new T.Mesh(geometry,material);group.position.set(i*2,0,0);group.add(mesh);root.add(group);instances.push(group);
}
const hiddenSources=[];
for(let i=0;i<4;i++){
 const proxy=new T.Mesh(geometry,material);proxy.name='COLLISION_BIN_CIVIC';proxy.visible=false;instances[i].add(proxy);hiddenSources.push(proxy);
 const hiddenParent=new T.Group(),hiddenChild=new T.Mesh(geometry,material);hiddenParent.visible=false;hiddenParent.add(hiddenChild);instances[i].add(hiddenParent);hiddenSources.push(hiddenChild);
}
const glassGroup=new T.Group(),glassMesh=new T.Mesh(geometry,glass);glassMesh.name='WindowPane';glassGroup.add(glassMesh);root.add(glassGroup);instances.push(glassGroup);
root.updateMatrixWorld(true);
const batches=createStaticRenderBatches({THREE:T,root,instances,minInstances:3,maxDistance:5});
assert.equal(batches.stats().batches,1);
assert.equal(batches.stats().members,4);
assert.equal(batches.stats().sourceMaterials,1,'one hidden clone serves all meshes with the same authored material');
for(const mesh of hiddenSources)assert.equal(mesh.material,material,'hidden sources and hidden-parent meshes must never enter render batches');
assert.equal(material.visible,true,'shared source material remains usable for unbatched meshes');
for(let i=0;i<4;i++)assert.equal(instances[i].children[0].material.visible,false);
assert.equal(instances[0].children[0].material,instances[3].children[0].material,'shared hidden material preserves every source mesh while avoiding duplicate clones');
assert.equal(glassMesh.material,glass,'transparent and window meshes are never batched');
const hit=new T.Raycaster(new T.Vector3(0,0,3),new T.Vector3(0,0,-1),0,10).intersectObject(instances[0],true);
assert(hit.length>0,'hidden render source must remain raycastable');
const near=batches.update({focus:new T.Vector3(0,0,0),maxDistance:5});
assert.equal(near.visible,3);
const far=batches.update({focus:new T.Vector3(100,0,0),maxDistance:5});
assert.equal(far.visible,0);
batches.dispose();
for(let i=0;i<4;i++)assert.equal(instances[i].children[0].material,material);
// Real GLBs have deliberately magenta collision geometry. The loader hides
// those objects, and batching must keep them hidden while batching the art.
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const catalog=JSON.parse(readFileSync(new URL('decor_catalog.v1.json',import.meta.url)));
let testedProxies=0;
for(const id of ['bin_civic','fountain_central','fountain_district','fountain_park','plaza_edge_straight_4m']){
 const asset=catalog.entries.find(e=>e.assetId===id),url=new URL('../../../'+asset.lods[0].relativePath,import.meta.url),bytes=readFileSync(url);
 const visual=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 visual.traverse(n=>{if(/(^|[_\s])(collision|collider|clearance|socket|anchor|keepout|nav|proxy|datum)([_\s]|$)/i.test(n.name)||/^(COLLISION|SOCKET|CLEARANCE|NAV_|COL_)/i.test(n.name))n.visible=false});
 const batchRoot=new T.Group(),copies=[],proxyMaterials=[];scene.add(batchRoot);
 for(let i=0;i<3;i++){
  const copy=visual.clone(true);copy.position.x=i*20;batchRoot.add(copy);copies.push(copy);
  copy.traverse(n=>{if(n.isMesh&&!n.visible){proxyMaterials.push([n,n.material]);testedProxies++}});
 }
 const batched=createStaticRenderBatches({THREE:T,root:batchRoot,instances:copies,minInstances:3});
 assert(batched.stats().members>0,'visible artwork still batches');
 for(const [mesh,sourceMaterial]of proxyMaterials){assert.equal(mesh.visible,false);assert.equal(mesh.material,sourceMaterial,'real collision proxy was not copied into a batch')}
 for(const child of batchRoot.children.filter(n=>n.userData.staticRenderBatch))assert(!/PROXY|COLLISION/.test(child.material.name),'magenta collision material cannot enter render batches');
 batched.dispose();batchRoot.removeFromParent();
}
assert(testedProxies>0);
// Interior furnishing pools are InstancedMesh already. Flatten their static
// instances into the global BatchedMesh while retaining hidden raycast sources
// and the authored per-instance colours.
const furnitureScene=new T.Scene(),furnitureRoot=new T.Group(),furnitureGroups=[],furnitureSources=[];furnitureScene.add(furnitureRoot);
for(let i=0;i<4;i++){
 const group=new T.Group(),geometry=new T.BoxGeometry(1,1,1),sourceMaterial=new T.MeshStandardMaterial({roughness:.76}),mesh=new T.InstancedMesh(geometry,sourceMaterial,3);group.position.x=i*4;mesh.name='Interior_Furnishings_box0';
 for(let j=0;j<3;j++){mesh.setMatrixAt(j,new T.Matrix4().makeTranslation(0,j,0));mesh.setColorAt(j,new T.Color(j===1?'#7a4d31':'#d6c29a'))}group.add(mesh);furnitureRoot.add(group);furnitureGroups.push(group);furnitureSources.push({mesh,geometry,sourceMaterial});
}
furnitureRoot.updateMatrixWorld(true);const furnitureBatches=createStaticRenderBatches({THREE:T,root:furnitureRoot,instances:furnitureGroups,minInstances:3,maxDistance:20});
assert.equal(furnitureBatches.stats().members,12);assert.equal(furnitureBatches.stats().batches,1,'four local pools become one global static furniture batch');for(const source of furnitureSources)assert.equal(source.mesh.material.visible,false,'hidden source stays raycastable while the batch draws its exact copy');const furnitureBatch=furnitureRoot.children.find(node=>node.userData.staticRenderBatch),furnitureColor=new T.Color();assert.equal(furnitureBatch._geometryCount,1,'identical local pool shapes occupy one shared batch geometry');furnitureBatch.getColorAt(1,furnitureColor);const expectedFurnitureColor=new T.Color('#7a4d31');assert.ok(Math.abs(furnitureColor.r-expectedFurnitureColor.r)<1e-5&&Math.abs(furnitureColor.g-expectedFurnitureColor.g)<1e-5&&Math.abs(furnitureColor.b-expectedFurnitureColor.b)<1e-5,'batched furnishing preserves the authored instance colour');furnitureBatches.dispose();for(const source of furnitureSources){assert.equal(source.mesh.material,source.sourceMaterial);source.geometry.dispose();source.sourceMaterial.dispose()}furnitureRoot.removeFromParent();
console.log(`PASS ${testedProxies} hidden proxy meshes across real bin, fountains and plaza GLBs stay excluded`);
console.log('PASS static render batching keeps original raycasts, excludes glass, mirrors distance culling, flattens interior furnishing pools and restores materials');
