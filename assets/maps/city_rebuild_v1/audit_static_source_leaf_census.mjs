// Read-only authored-stage census. Does not generate interiors, batches, city AI or GPU state.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {applyCloneVisibilityMask} from './template_visibility_mask.mjs';
import {applyBuildingDoorsGlass} from './building_doors_glass.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import('three'),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const stampImport="import {stampBatchedShadowBounds} from './shadow_bounds_stamp.mjs';",rawSource=fs.readFileSync(new URL('./static_render_batches.mjs',import.meta.url),'utf8');
assert(rawSource.includes(stampImport));
// The data-URL audit exits before batch allocation and never needs the runtime
// bounds stamp. Strip its relative import because data: modules have no base URL.
const source=rawSource.replace(stampImport,'');
const marker='const batches=[],instancedSourceMaterials=new Map();';
assert(source.includes(marker));
// Use actual admission/grouping code, return before any BatchedMesh geometry allocation.
const censusModule=await import('data:text/javascript;base64,'+Buffer.from(source.replace(marker,'return {groups:[...groups.values()]};\n '+marker)).toString('base64'));
const read=f=>JSON.parse(fs.readFileSync(new URL(f,import.meta.url),'utf8'));
const buildings=[...read('./buildings_placement.v1.json').instances,...read('./detention_native_sites.v1.json').instances];
const rows=[...buildings,...read('./decor_placement.v1.json').instances],buildingIds=new Set(buildings.map(r=>r.id));
const templates=new Map(),resources=[],originals=[],scene=new T.Scene(),root=new T.Group(),instances=[];scene.add(root);
let authoredAnimations=0;
for(const row of rows){
 const binding=row.binding;if(!binding)continue;
 let template=templates.get(binding.sha256);
 if(!template){
  const bytes=fs.readFileSync(new URL('../../..'+binding.url,import.meta.url));
  // Same image-only test shim as the existing pavilion test: preserves materials and geometry.
  const loader=new GLTFLoader().register(()=>({name:'Census_No_Image_Upload',loadTexture(){return Promise.resolve(new T.Texture())}}));
  const gltf=await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');authoredAnimations+=gltf.animations.length;template=gltf.scene;
  template.traverse(n=>{if(/(^|[_\s])(collision|collider|clearance|socket|anchor|keepout|nav|proxy|datum)([_\s]|$)/i.test(n.name)||/^(COLLISION|SOCKET|CLEARANCE|NAV_|COL_)/i.test(n.name))n.visible=false;if(n.isMesh){n.castShadow=n.receiveShadow=true;for(const m of Array.isArray(n.material)?n.material:[n.material])if(m.transparent){m.depthWrite=false;m.side=T.FrontSide;m.forceSinglePass=true;m.envMapIntensity=.35;}}});templates.set(binding.sha256,template);
 }
 const group=new T.Group(),visual=template.clone(true),transform=row.transform||{};
 applyCloneVisibilityMask(visual,row.hideNodeNames);resources.push(applyBuildingDoorsGlass(visual,row));
 visual.position.fromArray(transform.modelLocalOffsetM||[0,0,0]);group.add(visual);group.position.fromArray(transform.positionM||[row.c*4.1,0,row.r*4.1]);group.rotation.y=(transform.yawDegrees||0)*Math.PI/180;group.scale.setScalar(transform.uniformScale??1);group.userData.instance=row;root.add(group);instances.push(group);
 group.traverse(n=>{if(n.isMesh)originals.push(n)});
}
const groups=censusModule.createStaticRenderBatches({THREE:T,root,instances,minInstances:3}).groups;
const accepted=groups.filter(group=>group.members.length>=3).flatMap(group=>group.members);
const unique=[...new Set(accepted.map(member=>member.mesh))],leaves=unique.filter(n=>!n.children.length&&n.matrixAutoUpdate===true),byAsset={};
for(const member of accepted){const key=member.group.userData.instance.assetId;byAsset[key]??={sources:new Set(),placements:new Set()};byAsset[key].sources.add(member.mesh);byAsset[key].placements.add(member.group);}
let decorSources=0,buildingSources=0;for(const mesh of leaves){const member=accepted.find(m=>m.mesh===mesh);if(buildingIds.has(member.group.userData.instance.id))buildingSources++;else decorSources++;}
const prior=new Map(leaves.map(n=>[n,{local:n.matrixAutoUpdate,world:n.matrixWorldAutoUpdate,matrix:n.matrix.clone(),position:n.position.clone(),quaternion:n.quaternion.clone(),scale:n.scale.clone()}]));
const selected=new Set(leaves),compose=T.Object3D.prototype.updateMatrix,visit=T.Object3D.prototype.updateMatrixWorld;
function count(){const stats={localCompose:0,visits:0,selectedCompose:0};T.Object3D.prototype.updateMatrix=function(...a){stats.localCompose++;if(selected.has(this))stats.selectedCompose++;return compose.apply(this,a)};T.Object3D.prototype.updateMatrixWorld=function(...a){stats.visits++;return visit.apply(this,a)};try{scene.updateMatrixWorld();return stats}finally{T.Object3D.prototype.updateMatrix=compose;T.Object3D.prototype.updateMatrixWorld=visit;}}
const before=count();for(const n of leaves)n.matrixAutoUpdate=false;const after=count();
assert.equal(before.selectedCompose,leaves.length);assert.equal(after.selectedCompose,0);assert.equal(before.visits,after.visits);
root.position.set(17,2,-9);root.rotation.y=.43;root.scale.set(1.2,.9,1.1);scene.updateMatrixWorld(true);
for(const n of leaves){const state=prior.get(n);assert.deepEqual(n.matrix,state.matrix);assert.deepEqual(n.matrixWorld,new T.Matrix4().multiplyMatrices(n.parent.matrixWorld,n.matrix));assert.equal(n.matrixWorldAutoUpdate,state.world);n.matrixAutoUpdate=state.local;}
console.log(JSON.stringify({scope:'Authored GLB admission only: generated entry/storey/interior sources absent; not an exact LIVE restores count',placements:instances.length,assetTypes:templates.size,authoredAnimations,authoredMeshObjects:originals.length,acceptedGroups:groups.filter(g=>g.members.length>=3).length,acceptedUniqueSources:unique.length,acceptedAutoLocalLeafSources:leaves.length,decorLeafSources:decorSources,buildingAuthoredLeafSources:buildingSources,before,after,byAsset:Object.fromEntries(Object.entries(byAsset).map(([k,v])=>[k,{sources:v.sources.size,placements:v.placements.size}]))},null,2));
for(const resource of resources)resource.dispose();
