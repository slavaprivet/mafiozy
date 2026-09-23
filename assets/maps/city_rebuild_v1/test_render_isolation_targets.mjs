// CPU-only: actual furniture/static factories and the current walk target callback.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {createInteriorMeshPool} from './interior_mesh_pool.mjs';
import {createStaticRenderBatches} from './static_render_batches.mjs';

const vendor=process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
const walk=readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
const callback=walk.match(/getTargets:(mode=>\{[\s\S]*?\n\})\}\);/);
assert(callback,'walk isolation target callback remains testable');

let cases=0;
for(const mode of ['batched','threshold-fallback','no-BatchedMesh']){
 const root=new T.Group(),instances=[],pools=[],sources=[],exterior=[],architecture=[];
 const geometry=new T.BoxGeometry(),exteriorMaterial=new T.MeshStandardMaterial({roughness:.76});
 for(let building=0;building<3;building++){
  const group=new T.Group();group.userData.instance={assetId:'hillstep_chalet_v1'};group.position.x=building*8;root.add(group);instances.push(group);
  const furniture=new T.Group();furniture.name='Themed_Building_Interior';group.add(furniture);
  const pool=createInteriorMeshPool(T,furniture);pools.push(pool);
  for(const shape of ['box','cylinder','sphere'])for(const metalness of [0,.65])pool.add({shape,metalness,position:[metalness,1,0],size:[1,1,1]});
  pool.flush();sources.push(...furniture.children);
  const wall=new T.Mesh(geometry,exteriorMaterial);wall.name='Exterior_Wall';group.add(wall);exterior.push(wall);
  const floor=new T.Mesh(geometry,exteriorMaterial);floor.name='Entry_Interior_Floor';floor.userData.staticRenderMaterialImmutable=true;group.add(floor);architecture.push(floor);
 }
 const api=createStaticRenderBatches({THREE:mode==='no-BatchedMesh'?{...T,BatchedMesh:undefined}:T,root,instances,minInstances:mode==='threshold-fallback'?999:3,multiDraw:true});
 api.update({focus:new T.Vector3(),maxDistance:220});
 const getTargets=Function('scene','npcPopulation','fleet','worldTrafficPresentation',`return (${callback[1]});`)(root,null,null,null);
 const targets=getTargets('interiors'),furnitureBatches=root.children.filter(n=>n.userData.renderIsolationInteriorFurnishings===true),otherBatches=root.children.filter(n=>n.userData.staticRenderBatch&&!n.userData.renderIsolationInteriorFurnishings);
 assert.equal(sources.length,18,'all three shapes and both material roles across three actual factories');
 for(const source of sources)assert(targets.includes(source),'both batched hidden sources and unbatched pools are targeted');
 for(const batch of furnitureBatches)assert(targets.includes(batch),'global furniture render copies are targeted');
 assert.equal(targets.length,sources.length+furnitureBatches.length,'no unrelated mesh or root is included');
 for(const mesh of [...exterior,...architecture,...otherBatches])assert(!targets.includes(mesh),'exterior and audited floor lane must not be furniture');
 if(mode==='batched'){
  assert(furnitureBatches.length>0&&otherBatches.length>0);
  assert(sources.every(source=>source.material.visible===false),'canonical hidden source materials are present');
 }
 const materials=sources.map(source=>source.material),saved=targets.map(node=>node.visible);
 try{
  for(const node of targets)node.visible=false;
  assert(targets.every(node=>!node.visible));
  assert(otherBatches.every(node=>node.visible),'unrelated global geometry survives isolation');
  assert(exterior.every(node=>node.visible)&&architecture.every(node=>node.visible));
 }finally{targets.forEach((node,i)=>{node.visible=saved[i]});}
 for(let i=0;i<sources.length;i++)assert.equal(sources[i].material,materials[i],'isolation must not rewrite canonical materials');
 api.dispose();for(const pool of pools)pool.dispose();geometry.dispose();exteriorMaterial.dispose();cases++;
}
console.log(JSON.stringify({passed:cases,scope:'actual furniture/static factories; live walk target callback; CPU only, no GPU'}));
