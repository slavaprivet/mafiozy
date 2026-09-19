import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createStaticRenderBatches} from './static_render_batches.mjs';
import {createWindowedBuildingEntry} from './building_window_integration.mjs';
import {applyBuildingDoorsGlass} from './building_doors_glass.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c);}});
const T=await import('three'),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const items=JSON.parse(readFileSync(new URL('buildings_placement.v1.json',import.meta.url))).instances.filter(i=>i.assetId==='woodland_crosswing_house_v1');
assert.equal(items.length,2);
const bytes=readFileSync(new URL('../../..'+items[0].binding.url,import.meta.url));
const loader=new GLTFLoader().register(()=>({name:'Test_No_Image_Upload',loadTexture(){return Promise.resolve(new T.Texture());}}));
const template=(await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
template.traverse(n=>{if(/(^|[_\s])(collision|collider|clearance|socket|anchor|keepout|nav|proxy|datum)([_\s]|$)/i.test(n.name)||/^(COLLISION|SOCKET|CLEARANCE|NAV_|COL_)/i.test(n.name))n.visible=false;if(n.isMesh)n.castShadow=n.receiveShadow=true;});
const root=new T.Group(),instances=[],resources=[];
const materialKey=material=>{const description=material.toJSON();delete description.metadata;delete description.uuid;description.defines=Object.fromEntries(Object.entries(material.defines||{}).sort(([a],[b])=>a.localeCompare(b)));return JSON.stringify(description)};
for(const item of items){
 const group=new T.Group(),visual=template.clone(true),t=item.transform;
 visual.position.fromArray(t.modelLocalOffsetM);group.position.fromArray(t.positionM);group.rotation.y=t.yawDegrees*Math.PI/180;group.scale.setScalar(t.uniformScale);group.add(visual);group.userData.instance=item;root.add(group);instances.push(group);
 resources.push({doors:applyBuildingDoorsGlass(visual,item),...createWindowedBuildingEntry({THREE:T,visual,instance:item})});
}
// Negative fixtures use the same audited name/material as a real static trim.
const trim=instances[0].getObjectByName('FrontWindow1Sill'),trimMaterial=trim.material,exclusions=[];
for(const mode of ['hidden-self','hidden-parent','moving-parent']){
 const group=new T.Group(),mesh=new T.Mesh(trim.geometry,trim.material);mesh.name=trim.name;
 if(mode==='hidden-self')mesh.visible=false;if(mode==='hidden-parent')group.visible=false;if(mode==='moving-parent')group.name='Entry_Hinge_Test';
 group.add(mesh);instances[0].add(group);exclusions.push(mesh);
}
root.updateWorldMatrix(true,true);
const originals=[],cloneSources=new WeakMap(),materials=new Set();
root.traverse(mesh=>{if(mesh.isMesh){originals.push({mesh,material:mesh.material,geometry:mesh.geometry,parent:mesh.parent,matrix:mesh.matrixWorld.clone(),colors:mesh.instanceColor?.array.slice()});if(!Array.isArray(mesh.material))materials.add(mesh.material);}});
for(const material of materials){const clone=material.clone;material.clone=function(){const result=clone.call(this);cloneSources.set(result,this);return result;};}
const ray=new T.Raycaster(),center=new T.Vector3(),size=new T.Vector3(),rays=[];
for(const s of originals){
 const box=new T.Box3().setFromObject(s.mesh);if(box.isEmpty())continue;box.getCenter(center);box.getSize(size);
 const origin=center.clone().add(new T.Vector3(0,0,size.length()+3)),direction=new T.Vector3(0,0,-1);ray.set(origin,direction);
 const hits=ray.intersectObject(s.mesh,false).map(h=>({distance:h.distance,instanceId:h.instanceId}));if(hits.length)rays.push({mesh:s.mesh,origin,direction,hits});
}
assert(rays.length>10,'real original collision/raycast geometry is exercised');
// Observe addGeometry without changing submitted geometry or production batching.
class ObservedBatch extends T.BatchedMesh{
 addGeometry(geometry,...args){const id=super.addGeometry(geometry,...args);(this.sourceGeometry??=new Map()).set(id,geometry);return id;}
}
const batches=createStaticRenderBatches({THREE:{...T,BatchedMesh:ObservedBatch},root,instances}),stats=batches.stats();
const allBatches=root.children.filter(n=>n.isBatchedMesh),allSources=originals.filter(s=>s.mesh.material!==s.material);
batches.setOptimizationEnabled(false);
const sources=allSources.filter(s=>s.mesh.material===s.material),architectureBatches=allBatches.filter(b=>!b.visible);
assert(sources.length>40,'actual woodland architecture must enter audited batches');
assert.equal(architectureBatches.length,stats.optimizationBatches);assert(allSources.some(s=>s.mesh.material!==s.material),'pre-existing ordinary batches remain enabled');
batches.setOptimizationEnabled(true);
const flattened=[];
for(const s of sources){
 const count=s.mesh.isInstancedMesh?s.mesh.count:1;
 for(let i=0;i<count;i++){const local=new T.Matrix4();if(s.mesh.isInstancedMesh)s.mesh.getMatrixAt(i,local);const color=s.mesh.instanceColor?new T.Color():null;if(color)s.mesh.getColorAt(i,color);flattened.push({...s,world:s.matrix.clone().multiply(local),color});}
}
assert.equal(flattened.length,stats.optimizationMembers);
let vertices=0,maximumVertexError=0;
const packed=new T.Vector3(),expected=new T.Vector3(),matrix=new T.Matrix4(),color=new T.Color();
for(const batch of architectureBatches)for(let i=0;i<batch.instanceCount;i++){
 batch.getMatrixAt(i,matrix);matrix.premultiply(batch.matrixWorld);
 const sourceMaterial=cloneSources.get(batch.material),id=batch.getGeometryIdAt(i),geometry=batch.sourceGeometry.get(id),range=batch.getGeometryRangeAt(id),renderKey=materialKey(sourceMaterial);
 const match=flattened.find(s=>materialKey(s.material)===renderKey&&s.geometry===geometry&&s.world.elements.every((v,k)=>Math.abs(v-matrix.elements[k])<.001));
 assert(match,'each batch member retains exact render material, geometry identity and world matrix');
 assert.equal(batch.castShadow,match.mesh.castShadow);assert.equal(batch.receiveShadow,match.mesh.receiveShadow);assert.equal(batch.renderOrder,match.mesh.renderOrder);
 if(match.color){batch.getColorAt(i,color);assert(color.distanceTo?color.distanceTo(match.color)<1e-5:['r','g','b'].every(k=>Math.abs(color[k]-match.color[k])<1e-5));}
 const src=geometry.attributes.position,dst=batch.geometry.attributes.position;
 for(let j=0;j<src.count;j++){
  assert.equal(dst.getX(range.vertexStart+j),src.getX(j));assert.equal(dst.getY(range.vertexStart+j),src.getY(j));assert.equal(dst.getZ(range.vertexStart+j),src.getZ(j));
  packed.fromBufferAttribute(dst,range.vertexStart+j).applyMatrix4(matrix);expected.fromBufferAttribute(src,j).applyMatrix4(match.world);
  const error=packed.distanceTo(expected);maximumVertexError=Math.max(maximumVertexError,error);assert(error<.001,'world vertex differs only by Float32 batch matrix precision');vertices++;
 }
 if(geometry.index)for(let j=0;j<geometry.index.count;j++)assert.equal(batch.geometry.index.getX(range.indexStart+j)-range.vertexStart,geometry.index.getX(j),'identical triangle indices');
}
for(const s of originals){
 assert.equal(s.mesh.geometry,s.geometry);assert.equal(s.mesh.parent,s.parent);assert.deepEqual(s.mesh.matrixWorld.elements,s.matrix.elements);if(s.colors)assert.deepEqual(s.mesh.instanceColor.array,s.colors);
 let hidden=false,moving=false;for(let n=s.mesh;n;n=n.parent){hidden ||=!n.visible;moving ||= /Hinge/.test(n.name);}
 if(hidden||moving||s.mesh.userData.breakableGlass||/^ResidentialWindow|^(?:PublicDoor|ServiceDoor|DoorHeader|DoorCanopy|Entry_Brass|Entry_Handle|Entry_Leaf|InteriorDoor)/.test(s.mesh.name))assert.equal(s.mesh.material,s.material,'excluded source '+s.mesh.name);
}
for(const mesh of exclusions)assert.equal(mesh.material,trimMaterial,'hidden and moving ancestor exclusions');
for(const r of rays){ray.set(r.origin,r.direction);assert.deepEqual(ray.intersectObject(r.mesh,false).map(h=>({distance:h.distance,instanceId:h.instanceId})),r.hits,'original collision hits remain exact');}
batches.update({focus:new T.Vector3(1e6,0,1e6)});batches.setOptimizationEnabled(false);batches.setOptimizationEnabled(true);assert.equal(batches.stats().visible,0);for(const b of allBatches)assert.equal(b.visible,false);
batches.update();for(const b of allBatches)assert.equal(b.visible,true);batches.setOptimizationEnabled(false);for(const s of sources)assert.equal(s.mesh.material,s.material);batches.setOptimizationEnabled(true);
batches.dispose();for(const s of originals)assert.equal(s.mesh.material,s.material);assert.equal(root.children.filter(n=>n.isBatchedMesh).length,0);
for(const r of resources){r.roomReveals?.dispose();r.entry?.dispose();r.windows?.dispose();r.doors.dispose();}
console.log(JSON.stringify({status:'PASS',placements:items.length,architectureSourceMeshes:sources.length,architectureMembers:stats.optimizationMembers,architectureBatches:stats.optimizationBatches,totalBatches:stats.batches,vertices,maximumVertexError,sourceRayChecks:rays.length,checks:'actual GLB vertices/indices, UUID grouping, source instance colors, hidden/moving/door/glass exclusions, original collision rays, A/B cull/dispose'}));
