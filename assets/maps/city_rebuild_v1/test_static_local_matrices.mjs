import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createStaticRenderBatches} from './static_render_batches.mjs';
import {createWindowedBuildingEntry} from './building_window_integration.mjs';
import {applyBuildingDoorsGlass} from './building_doors_glass.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import('three'),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));

// Cheap negative fixtures: being accepted for draw batching alone must not
// override custom transform/render behavior or a flag owned by another system.
for(const fallback of [false,true]){
 const root=new T.Group(),geometry=new T.BoxGeometry(),material=new T.MeshStandardMaterial(),sources=[];
 for(const kind of ['ordinary','owned-false','children','custom-update','custom-world','custom-world-parents','custom-before','custom-after','custom-shadow-before','custom-shadow-after','animation']){
  const mesh=new T.Mesh(geometry,material);mesh.name=kind;mesh.position.x=sources.length*2;
  if(kind==='owned-false'){mesh.updateMatrix();mesh.matrixAutoUpdate=false;}
  if(kind==='children')mesh.add(new T.Object3D());
  if(kind==='custom-update')mesh.updateMatrix=function(){return T.Object3D.prototype.updateMatrix.call(this)};
  if(kind==='custom-world')mesh.updateMatrixWorld=function(...args){return T.Object3D.prototype.updateMatrixWorld.apply(this,args)};
  if(kind==='custom-world-parents')mesh.updateWorldMatrix=function(...args){return T.Object3D.prototype.updateWorldMatrix.apply(this,args)};
  if(kind==='custom-before')mesh.onBeforeRender=()=>{};
  if(kind==='custom-after')mesh.onAfterRender=()=>{};
  if(kind==='custom-shadow-before')mesh.onBeforeShadow=()=>{};
  if(kind==='custom-shadow-after')mesh.onAfterShadow=()=>{};
  if(kind==='animation')mesh.animations=[{}];root.add(mesh);sources.push(mesh);
 }
 const api=createStaticRenderBatches({THREE:fallback?{...T,BatchedMesh:undefined}:T,root,instances:[root],localMatrixOptimization:true,multiDraw:true});
 assert.equal(api.stats().localMatrixOptimizationEnabled,true);assert.equal(api.stats().frozenLocalSources,1);
 assert.equal(sources[0].matrixAutoUpdate,false);assert.equal(sources[1].matrixAutoUpdate,false);
 for(const n of sources.slice(2))assert.equal(n.matrixAutoUpdate,true);
 api.setLocalMatrixOptimizationEnabled(false);assert.equal(sources[0].matrixAutoUpdate,true);assert.equal(sources[1].matrixAutoUpdate,false);
 sources[0].position.y=7;sources[0].updateMatrix();const matrix=sources[0].matrix.clone();
 api.setLocalMatrixOptimizationEnabled(true);api.setLocalMatrixOptimizationEnabled(true);assert.equal(api.stats().frozenLocalSources,1);
 api.dispose();api.dispose();assert.equal(api.stats().frozenLocalSources,0);assert.equal(api.stats().localMatrixOptimizationEnabled,false);
 assert.deepEqual(sources[0].matrix,matrix);assert.equal(sources[0].matrixAutoUpdate,true);assert.equal(sources[1].matrixAutoUpdate,false);
 assert.equal(api.setLocalMatrixOptimizationEnabled(true),undefined);geometry.dispose();material.dispose();
}

const all=JSON.parse(fs.readFileSync(new URL('./buildings_placement.v1.json',import.meta.url),'utf8')).instances;
const items=[...all.filter(i=>i.assetId==='woodland_crosswing_house_v1'),all.find(i=>i.assetId==='glass_pavilion_small_v1')];
const scene=new T.Scene(),root=new T.Group(),templates=new Map(),instances=[],resources=[];scene.add(root);
for(const item of items){
 let template=templates.get(item.binding.sha256);
 if(!template){const bytes=fs.readFileSync(new URL('../../..'+item.binding.url,import.meta.url));const loader=new GLTFLoader().register(()=>({name:'Test_No_Image_Upload',loadTexture(){return Promise.resolve(new T.Texture())}}));template=(await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;template.traverse(n=>{if(/(^|[_\s])(collision|collider|clearance|socket|anchor|keepout|nav|proxy|datum)([_\s]|$)/i.test(n.name)||/^(COLLISION|SOCKET|CLEARANCE|NAV_|COL_)/i.test(n.name))n.visible=false;if(n.isMesh)n.castShadow=n.receiveShadow=true});templates.set(item.binding.sha256,template);}
 const group=new T.Group(),visual=template.clone(true),transform=item.transform;visual.position.fromArray(transform.modelLocalOffsetM);group.position.fromArray(transform.positionM);group.rotation.y=transform.yawDegrees*Math.PI/180;group.scale.setScalar(transform.uniformScale);group.userData.instance=item;group.add(visual);root.add(group);instances.push(group);
 resources.push({doors:applyBuildingDoorsGlass(visual,item),...createWindowedBuildingEntry({THREE:T,visual,instance:item})});
}
scene.updateMatrixWorld(true);
const originals=[];root.traverse(mesh=>{if(mesh.isMesh)originals.push({mesh,material:mesh.material,geometry:mesh.geometry,parent:mesh.parent,local:mesh.matrix.clone(),world:mesh.matrixWorld.clone(),auto:mesh.matrixAutoUpdate,worldAuto:mesh.matrixWorldAutoUpdate,instances:mesh.instanceMatrix?.array.slice(),colors:mesh.instanceColor?.array.slice(),id:mesh.id,uuid:mesh.uuid})});
const api=createStaticRenderBatches({THREE:T,root,instances,multiDraw:true});
assert.equal(api.stats().frozenLocalSources,0);assert.equal(api.stats().localMatrixOptimizationEnabled,false,'Production default stays OFF');
for(const s of originals)assert.equal(s.mesh.matrixAutoUpdate,s.auto);
const batchState=root.children.filter(n=>n.userData.staticRenderBatch).map(mesh=>({mesh,material:mesh.material,geometry:mesh.geometry,ids:Array.from({length:mesh.instanceCount},(_,i)=>mesh.getGeometryIdAt(i)),matrices:Array.from({length:mesh.instanceCount},(_,i)=>{const m=new T.Matrix4();mesh.getMatrixAt(i,m);return m.elements})}));
const accepted=originals.filter(s=>s.mesh.material!==s.material),enabledMaterials=new Map(accepted.map(s=>[s.mesh,s.mesh.material]));
api.setLocalMatrixOptimizationEnabled(true);const frozen=originals.filter(s=>s.auto&&!s.mesh.matrixAutoUpdate);assert(frozen.length>100);assert.equal(api.stats().frozenLocalSources,frozen.length);assert(frozen.every(s=>accepted.includes(s)));
const selected=new Set(frozen.map(s=>s.mesh));
function frameComposes(){let compose=0,selectedCompose=0;const original=T.Object3D.prototype.updateMatrix;T.Object3D.prototype.updateMatrix=function(...args){compose++;if(selected.has(this))selectedCompose++;return original.apply(this,args)};try{scene.updateMatrixWorld();return {compose,selectedCompose}}finally{T.Object3D.prototype.updateMatrix=original}}
const optimized=frameComposes();assert.equal(optimized.selectedCompose,0);api.setLocalMatrixOptimizationEnabled(false);const baseline=frameComposes();assert.equal(baseline.selectedCompose,frozen.length);assert.equal(baseline.compose-optimized.compose,frozen.length);api.setLocalMatrixOptimizationEnabled(true);
function verifySources(){for(const s of originals){assert.equal(s.mesh.geometry,s.geometry);assert.equal(s.mesh.parent,s.parent);assert.equal(s.mesh.id,s.id);assert.equal(s.mesh.uuid,s.uuid);assert.equal(s.mesh.matrixWorldAutoUpdate,s.worldAuto);if(s.instances)assert.deepEqual(s.mesh.instanceMatrix.array,s.instances);if(s.colors)assert.deepEqual(s.mesh.instanceColor.array,s.colors);}for(const s of frozen){assert.deepEqual(s.mesh.matrix,s.local);assert.deepEqual(s.mesh.matrixWorld,new T.Matrix4().multiplyMatrices(s.mesh.parent.matrixWorld,s.mesh.matrix));}}
verifySources();
for(const enabled of [false,true]){api.setOptimizationEnabled(enabled);scene.updateMatrixWorld(true);verifySources();}
for(const state of batchState){assert.equal(state.mesh.material,state.material);assert.equal(state.mesh.geometry,state.geometry);for(let i=0;i<state.matrices.length;i++){const matrix=new T.Matrix4();state.mesh.getMatrixAt(i,matrix);assert.deepEqual(matrix.elements,state.matrices[i]);assert.equal(state.mesh.getGeometryIdAt(i),state.ids[i]);}}
api.update({focus:new T.Vector3(1e6,0,1e6)});api.update();verifySources();
// The original entry API still animates its hinges and updates physical colliders.
let animated=0;
for(const resource of resources){const entry=resource.entry;if(!entry?.approachPoint)continue;const point=entry.approachPoint(),before=entry.report.openFraction;const result=entry.interact(point);if(!result.accepted)continue;for(let i=0;i<8;i++)entry.update(.1);assert(entry.report.openFraction>before);assert(entry.getCollisionBodies().some(b=>b.movingDoor));animated++;}
assert(animated>0,'Actual GLB entry door animation must be exercised');scene.updateMatrixWorld(true);verifySources();
// Root transform changes continue to propagate; no world-freeze guard required.
root.position.set(17,2,-9);root.rotation.y=.43;root.scale.set(1.2,.9,1.1);scene.updateMatrixWorld(true);verifySources();
// Actual source raycasts still hit at the same distances on both toggle states.
const rays=[];for(const s of frozen.slice(0,80)){const bounds=new T.Box3().setFromObject(s.mesh);if(bounds.isEmpty())continue;const point=bounds.getCenter(new T.Vector3()),extent=bounds.getSize(new T.Vector3()).length()+3,ray=new T.Raycaster(point.clone().add(new T.Vector3(0,0,extent)),new T.Vector3(0,0,-1));const hits=ray.intersectObject(s.mesh,false).map(h=>({distance:h.distance,point:h.point.toArray(),instanceId:h.instanceId}));if(hits.length)rays.push({mesh:s.mesh,ray,hits});}
assert(rays.length>0);api.setLocalMatrixOptimizationEnabled(false);scene.updateMatrixWorld(true);for(const r of rays)assert.deepEqual(r.ray.intersectObject(r.mesh,false).map(h=>({distance:h.distance,point:h.point.toArray(),instanceId:h.instanceId})),r.hits);api.setLocalMatrixOptimizationEnabled(true);
api.dispose();for(const s of originals){assert.equal(s.mesh.material,s.material);assert.equal(s.mesh.matrixAutoUpdate,s.auto);assert.equal(s.mesh.matrixWorldAutoUpdate,s.worldAuto);}for(const s of frozen)assert.deepEqual(s.mesh.matrix,s.local);
for(const r of resources){r.roomReveals?.dispose();r.entry?.dispose();r.windows?.dispose();r.doors.dispose();}
console.log('PASS static local matrices default OFF, opt-in and fallback; excluded custom/animated/nonleaf/owned flags; actual woodland+pavilion geometry/materials/IDs/instances, world transforms, moving entry doors, nonempty ray hits, culling, toggle and disposal.');
console.log(JSON.stringify({placements:items.length,acceptedSources:accepted.length,frozenLocalSources:frozen.length,baseline,optimized,animatedEntries:animated,sourceRaycasts:rays.length}));
