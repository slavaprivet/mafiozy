import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {WINDOW_PROFILES,applyResidentialWindows,componentBounds,createResidentialWindowQueue,residentialWindowCacheStats} from './residential_windows.mjs';

const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..'),placement=JSON.parse(fs.readFileSync(path.join(here,'buildings_placement.v1.json'))),results=[];
assert.equal(Object.keys(WINDOW_PROFILES).length,9);
for(const assetId of Object.keys(WINDOW_PROFILES)){
 const item=placement.instances.find(row=>row.assetId===assetId);assert(item,`${assetId} must be placed`);assert.equal(item.binding.sha256,WINDOW_PROFILES[assetId]);
 const bytes=fs.readFileSync(path.join(root,item.binding.url.slice(1))),loader=new GLTFLoader().register(()=>({name:'WINDOW_TEST_TEXTURE_ONLY',loadTexture:()=>Promise.resolve(new T.Texture())})),source=(await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene,visual=source.clone(true),visual2=source.clone(true),world=new T.Scene();world.add(visual,visual2);visual2.position.x=30;world.updateMatrixWorld(true);
 const originalGeometry=new Map(),porch=[];visual.traverse(node=>{if(node.isMesh)originalGeometry.set(node.name,node.geometry);if(/PorchLamp/i.test(node.name))porch.push({node,visible:node.visible,material:node.material,geometry:node.geometry})});
 const before=residentialWindowCacheStats(),started=performance.now(),api=applyResidentialWindows({THREE:T,visual,instance:item}),elapsed=performance.now()-started;assert(api&&api.report.windows>0,assetId);assert.equal(api.report.status,'applied-needs-live-review');assert.equal(api.report.porchLamps,porch.length);assert(porch.every(entry=>entry.node.visible===entry.visible&&entry.node.material===entry.material&&entry.node.geometry===entry.geometry),'porch lamps must remain untouched');
 const glass=api.glass;assert(glass?.isInstancedMesh);assert.equal(glass.count,api.report.windows);assert.equal(glass.userData.breakableGlass,true);assert.equal(glass.material.userData.breakableGlass,true);assert(/DeepGlass/.test(glass.name));assert.equal(glass.material.depthWrite,false);assert(glass.material.opacity<.5&&glass.material.transmission>=0);
 let emissivePanels=0;api.group.traverse(node=>{const materials=Array.isArray(node.material)?node.material:[node.material];for(const material of materials)if(material?.emissiveIntensity>0&&material.emissive?.getHex?.()!==0)emissivePanels++});assert.equal(emissivePanels,0,'runtime windows cannot reintroduce flat orange emissive inserts');
 assert(api.panes.every(pane=>pane.width>.25&&pane.height>.35));
 const api2=applyResidentialWindows({THREE:T,visual:visual2,instance:item});assert(api2);assert.equal(api2.report.cacheMisses,0,'second clone must reuse cached template clipping');assert(api2.report.cacheHits>0);assert(residentialWindowCacheStats().hits>before.hits);
 const changed=[...originalGeometry].filter(([name,geometry])=>visual.getObjectByName(name)?.geometry!==geometry);assert.equal(changed.length,api.report.clippedMeshes);api2.dispose();api.dispose();for(const [name,geometry]of originalGeometry)assert.equal(visual.getObjectByName(name)?.geometry,geometry);results.push({assetId,windows:api.report.windows,preserved:api.report.preservedComponents,clipped:api.report.clippedMeshes,firstMs:+elapsed.toFixed(1)});
}
assert.equal(residentialWindowCacheStats().entries,0,'last dispose releases cached geometry');let fakeNow=0;const queue=createResidentialWindowQueue({budgetMs:5,now:()=>fakeNow});const bad=queue.enqueue({THREE:T,visual:new T.Group(),instance:{}});fakeNow=6;assert.equal(queue.update(),1);assert.equal(bad.done,true);assert.equal(queue.pending,0);
console.log(JSON.stringify({passed:true,checks:['nine_hash_pinned_profiles','real_glb_connected_components','porch_lamps_preserved','no_orange_emissive_panels','deep_physical_breakable_glass','geometric_recess_and_frames','template_geometry_cache','refcount_dispose','optional_frame_queue'],results}));
