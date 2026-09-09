import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createStaticRenderBatches} from './static_render_batches.mjs';
import {createWindowedBuildingEntry} from './building_window_integration.mjs';
import {applyBuildingDoorsGlass} from './building_doors_glass.mjs';
import {isBreakableGlass} from './glass_breakage.mjs';

const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import('three'),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const items=JSON.parse(readFileSync(new URL('buildings_placement.v1.json',import.meta.url))).instances.filter(item=>item.assetId==='glass_pavilion_small_v1');
assert.equal(items.length,4);
const bytes=readFileSync(new URL('../../..'+items[0].binding.url,import.meta.url));
// Node does not decode the embedded AO image. Geometry and all authored GLTF
// material settings are real; this test only replaces its browser image upload.
const loader=new GLTFLoader().register(()=>({name:'Test_Image_Upload',loadTexture(){return Promise.resolve(new T.Texture())}}));
const template=(await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
template.traverse(node=>{if(/(^|[_\s])(collision|collider|clearance|socket|anchor|keepout|nav|proxy|datum)([_\s]|$)/i.test(node.name)||/^(COLLISION|SOCKET|CLEARANCE|NAV_|COL_)/i.test(node.name))node.visible=false;if(node.isMesh)node.castShadow=node.receiveShadow=true});
const scene=new T.Scene(),root=new T.Group(),instances=[],resources=[],originals=[];scene.add(root);
for(const item of items){
 const group=new T.Group(),visual=template.clone(true),t=item.transform;
 visual.position.fromArray(t.modelLocalOffsetM);group.position.fromArray(t.positionM);group.rotation.y=t.yawDegrees*Math.PI/180;group.scale.setScalar(t.uniformScale);group.add(visual);root.add(group);
 const doors=applyBuildingDoorsGlass(visual,item),building=createWindowedBuildingEntry({THREE:T,visual,instance:item});
 resources.push({doors,...building});instances.push(group);
}
root.updateWorldMatrix(true,true);
for(const group of instances)group.traverse(mesh=>{if(mesh.isMesh)originals.push({mesh,material:mesh.material,geometry:mesh.geometry,matrix:mesh.matrixWorld.clone(),parent:mesh.parent})});
const batches=createStaticRenderBatches({THREE:T,root,instances}),stats=batches.stats(),sources=originals.filter(({mesh,material})=>mesh.material!==material);
assert(sources.length>100,'the four real pavilion shells must enter static batches');
assert(stats.batches<sources.length/2,'shared opaque surfaces reduce draw submissions');
const matrix=new T.Matrix4();let copied=0,panes=0,doors=0;
for(const source of originals){
 assert.equal(source.mesh.geometry,source.geometry,'source collision/raycast geometry is untouched');
 assert.equal(source.mesh.parent,source.parent,'door and scene hierarchy ownership is unchanged');
 const mats=Array.isArray(source.material)?source.material:[source.material];
 if(mats.some(material=>isBreakableGlass(source.mesh,material))){panes++;assert.equal(source.mesh.material,source.material,'breakable panes are not frozen into static copies')}
 for(let node=source.mesh;node;node=node.parent)if(/Door|Hinge/i.test(node.name)){doors++;assert.equal(source.mesh.material,source.material,'door descendants retain their moving runtime');break}
}
for(const batch of root.children.filter(node=>node.isBatchedMesh))for(let id=0;id<batch.instanceCount;id++){
 batch.getMatrixAt(id,matrix);
 assert(sources.some(source=>source.matrix.elements.every((value,k)=>Math.abs(value-matrix.elements[k])<1e-4)),'every static transform matches an original opaque source');copied++;
}
assert(copied>0);assert(panes>0);assert(doors>0);
for(const group of instances){const point=group.position.clone();const state=batches.update({focus:point,maxDistance:35});assert(state.visible>0,'near pavilion remains visible')}
assert.equal(batches.update({focus:new T.Vector3(100000,0,100000),maxDistance:220}).visible,0,'original distance threshold still hides distant pavilions');
batches.dispose();for(const source of originals)assert.equal(source.mesh.material,source.material,'batch disposal restores exact source materials');
for(const resource of resources){resource.roomReveals?.dispose();resource.entry?.dispose();resource.windows?.dispose();resource.doors.dispose()}
console.log('PASS real four GALLERIA GLBs: opaque batching, source matrices/raycast geometry, moving doors, breakable panes, culling and disposal',JSON.stringify({opaqueSources:sources.length,batches:stats.batches,members:stats.members,panes,doors}));
