import assert from 'node:assert/strict';
import test from 'node:test';
import {createWalkMapGroundOverlayPreview,WALK_MAP_GROUND_OVERLAY_PREVIEW_STYLE} from './walk_map_editor_ground_overlay_preview.mjs';
import {WALK_MAP_GROUND_OVERLAY_DEPENDENCIES,WALK_MAP_GROUND_OVERLAY_MATERIALS} from './walk_map_editor_ground_overlay.mjs';
import {createWalkMapSurfacePalette} from './walk_map_editor_palette.mjs';

class BufferAttribute{constructor(array,itemSize){this.array=array;this.itemSize=itemSize}}
class BufferGeometry{static made=[];constructor(){this.attributes={};this.disposals=0;BufferGeometry.made.push(this)}setAttribute(name,value){this.attributes[name]=value}setIndex(value){this.index=value}computeVertexNormals(){this.normals=true}computeBoundingBox(){this.box=true}computeBoundingSphere(){this.sphere=true}dispose(){this.disposals++}}
class MeshStandardMaterial{static made=[];constructor(options){Object.assign(this,options);this.disposals=0;MeshStandardMaterial.made.push(this)}dispose(){this.disposals++}}
class Mesh{constructor(geometry,material){this.geometry=geometry;this.material=material;this.userData={}}}
const THREE={BufferAttribute,BufferGeometry,MeshStandardMaterial,Mesh},rows=6,cols=6,zeros=()=>Array.from({length:rows},()=>Array(cols).fill(0)),map={rows,cols},masks=()=>({protectedMask:zeros(),policeMask:zeros(),bridgeDeckMask:zeros()});
function scene(){return {children:[],adds:0,removes:0,add(value){this.adds++;this.children.push(value)},remove(value){this.removes++;this.children=this.children.filter(item=>item!==value)}}}
function setup(options={}){BufferGeometry.made=[];MeshStandardMaterial.made=[];const stage=scene(),api=createWalkMapGroundOverlayPreview({THREE,scene:stage,map,protectionMasks:options.protectionMasks??masks(),idFactory:()=>options.id||'overlay-test',maxCachedGeometries:options.maxCachedGeometries??8,materials:options.materials,surfaceMaterialFor:options.surfaceMaterialFor});return {stage,api}}

test('cell preview reuses geometry, has an anti-z-fighting offset and does no per-frame work',()=>{
 const {stage,api}=setup(),shape={type:'cells',cells:[[1,1],[1,2]]},mesh=api.begin({materialId:'earth',shape});assert.equal(stage.children[0],mesh);assert.equal(mesh.renderOrder,3);assert.equal(mesh.userData.walkMapEditorPreview,true);assert.equal(mesh.geometry.attributes.position.array.length,24);assert.ok([...mesh.geometry.attributes.position.array].filter((_value,index)=>index%3===1).every(value=>Math.abs(value-.025)<1e-7));assert.equal(mesh.material.color,WALK_MAP_GROUND_OVERLAY_PREVIEW_STYLE.earth.color);assert.equal(mesh.material.polygonOffset,true);
 const geometry=mesh.geometry;for(let index=0;index<500;index++)assert.equal(api.update(1/60),false);assert.equal(api.diagnostics().geometryBuilds,1);api.updateShape(structuredClone(shape));assert.equal(api.preview.mesh.geometry,geometry);assert.equal(api.diagnostics().geometryBuilds,1);
 api.setMaterial('dirt-road');assert.equal(api.preview.mesh.geometry,geometry);assert.equal(api.preview.mesh.material.color,WALK_MAP_GROUND_OVERLAY_PREVIEW_STYLE['dirt-road'].color);assert.equal(api.diagnostics().materialBuilds,2);assert.equal(api.cancel('escape'),true);assert.equal(stage.children.length,0);
 api.begin({materialId:'earth',shape});assert.equal(api.preview.mesh.geometry,geometry,'same deterministic plan reuses cached geometry across previews');assert.equal(api.diagnostics().geometryBuilds,1);api.dispose();assert.equal(geometry.disposals,1);assert.equal(MeshStandardMaterial.made.every(material=>material.disposals===1),true);assert.equal(api.diagnostics().disposed,true);assert.throws(()=>api.begin({materialId:'earth',shape}),/disposed/);
});

test('polygon preview commits a lossless custom overlay with exact rebuild dependencies',()=>{
 const {stage,api}=setup(),shape={type:'polygon',points:[[1,1],[1,3],[3,3],[3,1]]};api.begin({id:'earth-polygon',materialId:'earth',shape,groundHeightM:.4,zOffsetM:.03,metadata:{unknown:'kept'}});const preview=api.preview;assert.equal(preview.record.geometry.type,'polygon');assert.deepEqual(preview.record.geometry.points,shape.points);assert.equal(preview.record.render.groundHeightM,.4);assert.equal(preview.record.render.zOffsetM,.03);assert.equal(preview.meshPlan.primitives[0].triangles.length,2);
 const result=api.commit({metadata:{source:'preview-test'}});assert.equal(stage.children.length,0);assert.equal(result.command.patch.action,'add');assert.equal(result.command.patch.source.dataset,'custom');assert.equal(result.command.patch.after.metadata.unknown,'kept');assert.deepEqual(result.dependencies,WALK_MAP_GROUND_OVERLAY_DEPENDENCIES);assert.deepEqual(result.command.patch.metadata.dependencies,WALK_MAP_GROUND_OVERLAY_DEPENDENCIES);for(const dependency of ['ground-overlay-render','road-navigation','walk-navigation','vehicle-surface','grass','minimap'])assert.ok(result.dependencies.includes(dependency));
 const deletion=api.deleteCommand(result.record);assert.equal(deletion.patch.action,'delete');assert.deepEqual(deletion.patch.before,result.record);api.dispose();
});

test('invalid/protected shapes never leak a mesh; rollback and dispose are idempotent',()=>{
 const protection=masks();protection.protectedMask[2][2]=1;const {stage,api}=setup({protectionMasks:protection});assert.throws(()=>api.begin({materialId:'earth',shape:{type:'cells',cells:[[2,2]]}}),error=>error.code==='PROTECTED_GROUND_OVERLAY_CELL');assert.equal(stage.children.length,0);assert.equal(api.diagnostics().geometryBuilds,0);
 api.begin({materialId:'dirt-road',shape:{type:'cells',cells:[[1,1]]}});assert.equal(api.rollback(),true);assert.equal(stage.children.length,0);assert.equal(api.rollback(),false);api.dispose();api.dispose();assert.equal(stage.children.length,0);
});

test('geometry cache is bounded and shared world materials remain caller-owned',()=>{
 const shared=new MeshStandardMaterial({name:'shared-trail'}),{api}=setup({maxCachedGeometries:2,materials:{[WALK_MAP_GROUND_OVERLAY_MATERIALS['dirt-road'].renderMaterialId]:shared}});for(const cell of [[0,0],[1,1],[2,2],[3,3]]){api.begin({materialId:'dirt-road',shape:{type:'cells',cells:[cell]}});api.cancel()}assert.equal(api.diagnostics().cachedGeometries,2);assert.equal(BufferGeometry.made.length,4);assert.equal(BufferGeometry.made.filter(geometry=>geometry.disposals===1).length,2);api.dispose();assert.equal(BufferGeometry.made.every(geometry=>geometry.disposals===1),true);assert.equal(shared.disposals,0,'injected world-style material is not owned by the editor preview');
});

test('earth and dirt-road palette entries unlock only with the installed preview adapter',()=>{
 const locked=createWalkMapSurfacePalette(),enabled=createWalkMapSurfacePalette({groundOverlayAdapterAvailable:true});for(const materialId of ['earth','dirt-road']){const before=locked.find(item=>item.materialId===materialId),after=enabled.find(item=>item.materialId===materialId);assert.equal(before.available,false);assert.equal(after.available,true);assert.equal(after.placementMode,'overlay');assert.match(after.reason,/без подмены tile 9\/14/i)}assert.deepEqual(enabled.filter(item=>item.available).map(item=>item.materialId),['asphalt','dirt-road','earth','grass']);
});
