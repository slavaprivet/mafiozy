import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createWindowedBuildingEntry} from './building_window_integration.mjs';
import {createStaticRenderBatches} from './static_render_batches.mjs';
import {WINDOW_PROFILES,residentialWindowCacheStats} from './residential_windows.mjs';
import {interiorFinishCacheStats} from './interior_finishes.mjs';
import {buildingStoreyResourceCacheStats} from './building_storeys.mjs';
import {createGlassBreakage} from './glass_breakage.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const placement=JSON.parse(fs.readFileSync(new URL('buildings_placement.v1.json',import.meta.url))),scene=new T.Scene(),glass=createGlassBreakage(T,scene),active=[];let count=0,interiorDoors=0,interiorDoorDraws=0,interiorFurniture=0,interiorFurnitureDraws=0;
for(const id of Object.keys(WINDOW_PROFILES)){
 const items=placement.instances.filter(i=>i.assetId===id),bytes=fs.readFileSync(new URL('../../..'+items[0].binding.url,import.meta.url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 for(const item of items){
  const group=new T.Group(),visual=source.clone(true),t=item.transform;group.position.fromArray(t.positionM);group.rotation.y=t.yawDegrees*Math.PI/180;group.scale.setScalar(t.uniformScale);visual.position.fromArray(t.modelLocalOffsetM);group.add(visual);scene.add(group);group.updateMatrixWorld(true);
  const before=new Map();visual.traverse(n=>{if(n.isMesh)before.set(n,n.geometry)});
  const applied=createWindowedBuildingEntry({THREE:T,visual,instance:item});assert.ok(applied.windows&&applied.entry);assert.equal(applied.windows.group.visible,true);assert.equal(applied.entry.contentRoot.children.length,0);const interior=applied.entry.interiorDesign.report;interiorDoors+=interior.doors;interiorDoorDraws+=interior.doorDraws;interiorFurniture+=interior.parts;interiorFurnitureDraws+=interior.draws;assert.ok(interior.draws<=6,'static room furniture remains instanced by its three shapes and two material classes');count+=applied.windows.report.windows;glass.prepare(visual);
  const mesh=applied.windows.glass,originalMatrix=mesh.instanceMatrix,transform=new T.Matrix4();mesh.getMatrixAt(0,transform);mesh.updateWorldMatrix(true,false);const point=new T.Vector3(.1,.1,.5).applyMatrix4(transform).applyMatrix4(mesh.matrixWorld);assert.equal(glass.hit({object:mesh,instanceId:0,faceIndex:0,point,face:{normal:new T.Vector3(0,0,1)}}).broken,true);glass.update(.1);assert.notEqual(mesh.instanceMatrix,originalMatrix);
  active.push({...applied,visual,before,group});
 }
}
assert.equal(active.length,43);assert.equal(count,675,'room integration must retain every planned window');assert.ok(interiorDoorDraws<=interiorDoors*2,'open public portals add no leaf; private leaves remain grouped by material');const finishCache=interiorFinishCacheStats(),storeyResources=buildingStoreyResourceCacheStats();assert.equal(finishCache.refs,active.length*2,'every room keeps wall and floor finish leases until teardown');assert.ok(finishCache.entries<finishCache.refs&&finishCache.hits>0,'repeated palettes share immutable interior finish materials');assert.equal(storeyResources.refs,active.length,'every multi-storey entry leases the same immutable storey resources');assert.equal(storeyResources.entries,1,'all storeys share one material and unit-box resource bundle');const furnishingSources=[];for(const a of active)a.visual.traverse(node=>{if(/^Interior_Furnishings_/.test(node.name))furnishingSources.push(node)});assert.equal(furnishingSources.length,interiorFurnitureDraws);const staticBatches=createStaticRenderBatches({THREE:T,root:scene,instances:active.map(a=>a.group),minInstances:3,multiDraw:true}),staticStats=staticBatches.stats(),batchedFurnishingSources=furnishingSources.filter(mesh=>mesh.material.visible===false).length;assert.ok(staticStats.members>=interiorFurniture,'global batch includes every static furnishing instance');assert.equal(batchedFurnishingSources,furnishingSources.length,'every real furnishing source is rendered exactly once through the global batch');for(const mesh of furnishingSources)assert.equal(mesh.material.visible,false,'batched furnishing source stays raycastable but is not drawn twice');staticBatches.dispose();for(const mesh of furnishingSources)assert.equal(mesh.material.visible,true,'batch disposal restores original furnishing material');const cache=residentialWindowCacheStats();assert.ok(cache.refs>0&&cache.hits>0,'shared source windows must reuse cache');
glass.dispose();for(const a of active){a.roomReveals.dispose();a.entry.dispose();a.windows.dispose();for(const[n,g]of a.before)assert.equal(n.geometry,g);a.group.removeFromParent()}
assert.equal(residentialWindowCacheStats().refs,0);assert.equal(residentialWindowCacheStats().entries,0);
assert.equal(interiorFinishCacheStats().refs,0);assert.equal(interiorFinishCacheStats().entries,0);
assert.equal(buildingStoreyResourceCacheStats().refs,0);assert.equal(buildingStoreyResourceCacheStats().entries,0);
console.log('PASS 43 full rooms + 675 panes; '+interiorDoors+' interior doors in '+interiorDoorDraws+' dynamic draws; '+interiorFurniture+' furnishing parts in '+interiorFurnitureDraws+' instanced draws; individual glass hit, shared cache reuse, ordered restoration/refcount zero',cache);
