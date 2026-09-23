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
const batches=createStaticRenderBatches({THREE:T,root,instances,minInstances:3,maxDistance:5,multiDraw:true});
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
const detachedMesh=instances[0].children[0];instances[0].remove(detachedMesh);assert.equal(batches.update({focus:new T.Vector3(0,0,0),maxDistance:5}).visible,2,'detached source is removed from copied members on the next update');assert.equal(detachedMesh.material,material,'detached source regains its render material');instances[0].add(detachedMesh);assert.equal(batches.update({focus:new T.Vector3(0,0,0),maxDistance:5}).visible,3,'reattach below the registered placement restores the copied member');assert.equal(detachedMesh.material.visible,false,'reattached source is hidden by the owner again');
root.remove(instances[1]);assert.equal(batches.update({focus:new T.Vector3(0,0,0),maxDistance:5}).visible,2,'detached placement cannot leave a copied member visible');root.add(instances[1]);assert.equal(batches.update({focus:new T.Vector3(0,0,0),maxDistance:5}).visible,3,'reattached placement resumes without rebuilding the batch');
instances[0].remove(detachedMesh);assert.equal(batches.update({focus:new T.Vector3(0,0,0),maxDistance:5}).visible,2);const movedParent=new T.Group();movedParent.position.x=5;instances[0].add(movedParent);movedParent.add(detachedMesh);assert.equal(batches.update({focus:new T.Vector3(0,0,0),maxDistance:5}).visible,2,'changed reparent transform permanently fails open instead of reusing a stale batch matrix');assert.equal(detachedMesh.material,material,'changed source transform renders through the exact source');movedParent.remove(detachedMesh);instances[0].add(detachedMesh);assert.equal(batches.update({focus:new T.Vector3(0,0,0),maxDistance:5}).visible,2,'retired stale slot is never reclaimed without a batch rebuild');assert.equal(detachedMesh.material,material);
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
  const batched=createStaticRenderBatches({THREE:T,root:batchRoot,instances:copies,minInstances:3,multiDraw:true});
 assert(batched.stats().members>0,'visible artwork still batches');
 for(const [mesh,sourceMaterial]of proxyMaterials){assert.equal(mesh.visible,false);assert.equal(mesh.material,sourceMaterial,'real collision proxy was not copied into a batch')}
 for(const child of batchRoot.children.filter(n=>n.userData.staticRenderBatch))assert(!/PROXY|COLLISION/.test(child.material.name),'magenta collision material cannot enter render batches');
 batched.dispose();batchRoot.removeFromParent();
}
assert(testedProxies>0);
// Interior furnishing pools are InstancedMesh already. Flatten their static
// instances into the global BatchedMesh while retaining hidden raycast sources
// and the authored per-instance colours.
const furnitureScene=new T.Scene(),furnitureRoot=new T.Group(),furnitureGroups=[],furnitureSources=[];furnitureScene.add(furnitureRoot);furnitureRoot.position.set(17,2,-9);furnitureRoot.rotation.y=.43;furnitureRoot.scale.set(1.2,.9,1.1);
for(let i=0;i<4;i++){
 const group=new T.Group(),geometry=new T.BoxGeometry(1,1,1),sourceMaterial=new T.MeshStandardMaterial({roughness:.76}),mesh=new T.InstancedMesh(geometry,sourceMaterial,3);group.position.x=i*4;mesh.name='Interior_Furnishings_box0';
 for(let j=0;j<3;j++){mesh.setMatrixAt(j,new T.Matrix4().makeTranslation(0,j,0));mesh.setColorAt(j,new T.Color(j===1?'#7a4d31':'#d6c29a'))}group.add(mesh);furnitureRoot.add(group);furnitureGroups.push(group);furnitureSources.push({mesh,geometry,sourceMaterial});
}
furnitureRoot.updateMatrixWorld(true);const furnitureBatches=createStaticRenderBatches({THREE:T,root:furnitureRoot,instances:furnitureGroups,minInstances:3,maxDistance:20,multiDraw:true});
assert.equal(furnitureBatches.stats().members,12);assert.equal(furnitureBatches.stats().batches,1,'four local pools become one global static furniture batch');for(const source of furnitureSources)assert.equal(source.mesh.material.visible,false,'hidden source stays raycastable while the batch draws its exact copy');const furnitureBatch=furnitureRoot.children.find(node=>node.userData.staticRenderBatch),furnitureColor=new T.Color();assert.equal(furnitureBatch._geometryCount,1,'identical local pool shapes occupy one shared batch geometry');furnitureBatch.getColorAt(1,furnitureColor);const expectedFurnitureColor=new T.Color('#7a4d31');assert.ok(Math.abs(furnitureColor.r-expectedFurnitureColor.r)<1e-5&&Math.abs(furnitureColor.g-expectedFurnitureColor.g)<1e-5&&Math.abs(furnitureColor.b-expectedFurnitureColor.b)<1e-5,'batched furnishing preserves the authored instance colour');const expectedFurnitureMatrix=new T.Matrix4(),sourceFurnitureMatrix=new T.Matrix4(),actualFurnitureMatrix=new T.Matrix4();furnitureSources[2].mesh.getMatrixAt(1,sourceFurnitureMatrix);expectedFurnitureMatrix.copy(furnitureRoot.matrixWorld).invert().multiply(furnitureSources[2].mesh.matrixWorld).multiply(sourceFurnitureMatrix);furnitureBatch.getMatrixAt(7,actualFurnitureMatrix);for(let i=0;i<16;i++)assert.ok(Math.abs(actualFurnitureMatrix.elements[i]-expectedFurnitureMatrix.elements[i])<1e-7,'global batch retains exact transformed furnishing matrix');const changedPool=furnitureSources[0];furnitureGroups[0].remove(changedPool.mesh);assert.equal(furnitureBatches.update().visible,9);changedPool.mesh.setMatrixAt(0,new T.Matrix4().makeTranslation(9,0,0));furnitureGroups[0].add(changedPool.mesh);assert.equal(furnitureBatches.update().visible,9,'changed instance matrix retires all stale copied members for that source pool');assert.equal(changedPool.mesh.material,changedPool.sourceMaterial);furnitureBatches.dispose();for(const source of furnitureSources){assert.equal(source.mesh.material,source.sourceMaterial);source.geometry.dispose();source.sourceMaterial.dispose()}furnitureRoot.removeFromParent();

// Cross-material architecture batching is opt-in and preserves render layers.
const layerRoot=new T.Group(),layerGroups=[],layerGeometry=new T.BoxGeometry(1,1,1),layerMaterials=[];scene.add(layerRoot);
for(let i=0;i<6;i++){
 const group=new T.Group(),sourceMaterial=new T.MeshStandardMaterial({color:'#795842',roughness:.71}),mesh=new T.Mesh(layerGeometry,sourceMaterial);group.userData.instance={assetId:'hillstep_chalet_v1'};mesh.name='Entry_Interior_Floor';mesh.userData.staticRenderMaterialImmutable=true;mesh.layers.mask=i<3?1:2;group.add(mesh);layerRoot.add(group);layerGroups.push(group);layerMaterials.push(sourceMaterial);
}
layerRoot.updateMatrixWorld(true);const layerBatches=createStaticRenderBatches({THREE:T,root:layerRoot,instances:layerGroups,minInstances:3,multiDraw:true}),layerMeshes=layerRoot.children.filter(node=>node.userData.staticRenderBatch);
assert.equal(layerBatches.stats().members,6);assert.equal(layerMeshes.length,2,'different source layer masks stay in separate batches');assert.deepEqual(layerMeshes.map(mesh=>mesh.layers.mask).sort(),[1,2]);layerBatches.setOptimizationEnabled(false);layerBatches.update();assert.equal(layerBatches.stats().visible,6,'disabled optimization retains the current visibility census');assert.ok(layerMeshes.every(mesh=>!mesh.visible),'disabled optimization hides architecture batches');for(let i=0;i<layerGroups.length;i++)assert.equal(layerGroups[i].children[0].material,layerMaterials[i],'disabled optimization restores source materials');layerBatches.setOptimizationEnabled(true);assert.equal(layerBatches.stats().visible,6,'re-enabled optimization immediately retains visible members');assert.ok(layerMeshes.every(mesh=>mesh.visible),'re-enabled optimization immediately reveals architecture batches');for(const group of layerGroups)assert.equal(group.children[0].material.visible,false,'re-enabled optimization immediately hides source materials');layerBatches.dispose();for(const material of layerMaterials)material.dispose();layerGeometry.dispose();layerRoot.removeFromParent();

// Equivalent but unowned materials and mesh-specific render hooks fail open.
for(const mode of ['untagged','callback','depth']){
 const safetyRoot=new T.Group(),safetyGroups=[],safetyGeometry=new T.BoxGeometry(1,1,1),safetyMaterials=[];scene.add(safetyRoot);
 for(let i=0;i<3;i++){
  const group=new T.Group(),sourceMaterial=new T.MeshStandardMaterial({color:'#684b37'}),mesh=new T.Mesh(safetyGeometry,sourceMaterial);group.userData.instance={assetId:'old_town_narrow_townhouse_v1'};mesh.name='Entry_Corridor_Floor';if(mode!=='untagged')mesh.userData.staticRenderMaterialImmutable=true;if(mode==='callback')mesh.onBeforeRender=()=>{};if(mode==='depth')mesh.customDepthMaterial=new T.MeshDepthMaterial();group.add(mesh);safetyRoot.add(group);safetyGroups.push(group);safetyMaterials.push(sourceMaterial);
 }
  safetyRoot.updateMatrixWorld(true);const safetyBatches=createStaticRenderBatches({THREE:T,root:safetyRoot,instances:safetyGroups,minInstances:3,multiDraw:true});assert.equal(safetyBatches.stats().members,0,mode+' sources must remain unbatched');for(const group of safetyGroups)assert.equal(group.children[0].material.visible,true);safetyBatches.dispose();for(const group of safetyGroups)group.children[0].customDepthMaterial?.dispose();for(const material of safetyMaterials)material.dispose();safetyGeometry.dispose();safetyRoot.removeFromParent();
}

// Cloned batch materials retain custom shader hooks, and a late source
// material replacement immediately fails open without being overwritten.
const hookRoot=new T.Group(),hookGroups=[],hookGeometry=new T.BoxGeometry(1,1,1),hookMaterial=new T.MeshStandardMaterial({color:'#526879'}),hookCompile=()=>{},hookKey=()=> 'static-hook';hookMaterial.onBeforeCompile=hookCompile;hookMaterial.customProgramCacheKey=hookKey;scene.add(hookRoot);
for(let i=0;i<3;i++){const group=new T.Group(),mesh=new T.Mesh(hookGeometry,hookMaterial);group.add(mesh);hookRoot.add(group);hookGroups.push(group)}
hookRoot.updateMatrixWorld(true);const hookBatches=createStaticRenderBatches({THREE:T,root:hookRoot,instances:hookGroups,minInstances:3,multiDraw:true}),hookBatch=hookRoot.children.find(node=>node.userData.staticRenderBatch);assert.equal(hookBatch.material.onBeforeCompile,hookCompile);assert.equal(hookBatch.material.customProgramCacheKey,hookKey);assert.equal(hookBatches.stats().visible,3);
const replacement=new T.MeshStandardMaterial({color:'#cc4422'}),replacedMesh=hookGroups[0].children[0];replacedMesh.material=replacement;assert.equal(hookBatches.update().visible,2,'late material replacement removes only that source from its batch');hookBatches.dispose();assert.equal(replacedMesh.material,replacement,'dispose preserves a later owner material replacement');replacement.dispose();hookMaterial.dispose();hookGeometry.dispose();hookRoot.removeFromParent();

// BatchedMesh without WEBGL_multi_draw expands a source InstancedMesh into one
// native draw per copied member. Preserve the authored pool in that backend.
const fallbackRoot=new T.Group(),fallbackGroups=[],fallbackSources=[];scene.add(fallbackRoot);for(let i=0;i<4;i++){const group=new T.Group(),g=new T.BoxGeometry(1,1,1),m=new T.MeshStandardMaterial(),mesh=new T.InstancedMesh(g,m,3);mesh.name='Interior_Furnishings_box0';group.add(mesh);fallbackRoot.add(group);fallbackGroups.push(group);fallbackSources.push({mesh,g,m})}fallbackRoot.updateMatrixWorld(true);const fallback=createStaticRenderBatches({THREE:T,root:fallbackRoot,instances:fallbackGroups,minInstances:3,multiDraw:false});assert.equal(fallback.stats().members,0,'no-multi-draw backend keeps authored InstancedMesh pools intact');assert.equal(fallback.stats().batches,0);assert.equal(fallback.stats().mode,'StaticRenderBatch_Zero');for(const source of fallbackSources)assert.equal(source.mesh.material,source.m);fallback.dispose();for(const source of fallbackSources){source.g.dispose();source.m.dispose()}fallbackRoot.removeFromParent();
console.log(`PASS ${testedProxies} hidden proxy meshes across real bin, fountains and plaza GLBs stay excluded`);
console.log('PASS static render batching keeps original raycasts, excludes glass, mirrors distance culling, flattens interior furnishing pools and restores materials');
