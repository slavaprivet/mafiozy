import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createWalkMapEditorLiveBootstrap} from './walk_map_editor_live_bootstrap.mjs';

const base=new URL('./',import.meta.url);
async function source(name){return {text:await readFile(new URL(name,base),'utf8'),revision:`inventory:${name}`}}
const rawSources={
 topology:await source('topology_for_placement.json'),
 buildings:await source('buildings_placement.v1.json'),
 detention:await source('detention_native_sites.v1.json'),
 decor:await source('decor_placement.v1.json'),
 custom:{text:JSON.stringify({schema:'mafiozi.walk-map-editor.custom/v1',status:'empty',counts:{instances:0},instances:[]}),revision:'inventory:empty-custom'}
};
const buildingSource=JSON.parse(rawSources.buildings.text),detentionSource=JSON.parse(rawSources.detention.text);
assert.equal(buildingSource.instances.length,75);assert.equal(detentionSource.instances.length,3);

function vector(){return {x:0,y:0,z:0,fromArray(values){[this.x,this.y,this.z]=values},set(x,y,z){this.x=x;this.y=y;this.z=z}}}
function group(instance){return {userData:{instance},position:vector(),rotation:{y:0},scale:vector(),visible:true,updateWorldMatrix(){}}}
const groups=[...buildingSource.instances,...detentionSource.instances].map(group);
class V2{set(){return this}}class V3{constructor(x=0,y=0,z=0){this.x=x;this.y=y;this.z=z}clone(){return new V3(this.x,this.y,this.z)}}class Plane{}class Raycaster{constructor(){this.ray={intersectPlane:(_plane,out)=>out}}setFromCamera(){}intersectObjects(){return []}}
const THREE={Vector2:V2,Vector3:V3,Plane,Raycaster},scene={add(){},remove(){}},canvas={getBoundingClientRect:()=>({left:0,top:0,width:100,height:100})};
let hooks;const runtime={active:true,selection:null,refreshCatalog(){},setSaveState(){},dispose:async()=>{}},camera={enter(){},restore(){return true},setMode(){return true},handleAction(){return false},update(){},dispose(){}};
const storageData=new Map(),storage={getItem:key=>storageData.get(key)??null,setItem:(key,value)=>storageData.set(key,value),removeItem:key=>storageData.delete(key)};
const services={
 storage,loadTemplate:async()=>({clone:()=>group({})}),compileAssetRecord:()=>({ok:false}),releaseControls(){},enterGameEditor(){},leaveGameEditor(){},pickImportText:async()=>null,download:async()=>{},
 requestRebuild:async meta=>{const deleted=new Set((meta.document?.objectPatches||[]).filter(patch=>patch.action==='delete').map(patch=>String(patch.source.id)));return {groups:groups.filter(root=>!deleted.has(String(root.userData.instance.id)))}} ,
 createRuntime:options=>{hooks=options.hooks;return runtime},createCamera:()=>camera,createFilesDialog:({workflow})=>({open(){},dispose(){workflow.dispose()}}),now:()=> '2026-09-23T13:00:00.000Z'
};
const live={THREE,renderer:{domElement:canvas},scene,camera:{},controls:{},getPickRoots:()=>groups,groundHeight:()=>0,selectionVisual:false};
const bootstrap=createWalkMapEditorLiveBootstrap({rawSources,live,services,groups,createdAt:'2026-09-23T12:59:00.000Z'});
const authored=bootstrap.adapter.enumerate().filter(item=>item.source.dataset==='buildings');
assert.equal(authored.length,78,'catalog must expose 75 authored buildings plus 3 detention sites');
const detentionIds=new Set(detentionSource.instances.map(record=>String(record.id))),detentionItems=authored.filter(item=>detentionIds.has(String(item.id)));
assert.equal(detentionItems.length,3);assert.ok(detentionItems.every(item=>item.locked&&!item.capabilities.move&&!item.capabilities.delete));assert.ok(detentionItems.every(item=>/full|\u043fолная/i.test(item.derivedWarning)));
const locked=authored.filter(item=>item.locked);assert.equal(locked.length,8,'exact inventory is five special buildings plus three detention sites');
const nightclub=authored.find(item=>item.assetId==='nightclub');assert.ok(nightclub,'nightclub must remain in the authored catalog');assert.equal(nightclub.locked,false);assert.equal(nightclub.capabilities.move,true);
const compiled=bootstrap.compile({compiledAt:'2026-09-23T13:00:01.000Z'});assert.equal(compiled.artifacts.buildings.value.instances.length,75,'detention remains a separate trusted source policy');assert.ok(!compiled.artifacts.buildings.value.instances.some(record=>detentionIds.has(String(record.id))));
assert.ok(bootstrap.document.base.extensions.detention,'document must retain the separate detention source reference');

const topology=JSON.parse(rawSources.topology.text),safe=authored.find(item=>!item.locked&&(()=>{const box=item.raw?.footprint;if(!box)return false;for(let r=Math.max(0,Math.floor(box.minR));r<Math.min(topology.map.rows,Math.ceil(box.maxR));r++)for(let c=Math.max(0,Math.floor(box.minC));c<Math.min(topology.map.cols,Math.ceil(box.maxC));c++)if(topology.protectedMask?.[r]?.[c]||topology.policeMask?.[r]?.[c]||topology.bridgeDeckMask?.[r]?.[c])return false;return true})());
assert.ok(safe,'fixture needs one unprotected ordinary building');const safeRoot=groups.find(root=>String(root.userData.instance.id)===String(safe.id));runtime.selection={key:safe.key};
assert.equal(await hooks.deleteObject({item:safe,confirmed:true}),true);assert.equal(bootstrap.adapter.hasKey(safe.key),false);assert.equal(bootstrap.adapter.enumerate().some(item=>item.key===safe.key),false);assert.equal(safeRoot.visible,false,'deleted authored root is tombstoned after rebuild');
assert.equal(await hooks.undo(),true);assert.equal(bootstrap.adapter.hasKey(safe.key),true);assert.equal(bootstrap.adapter.enumerate().some(item=>item.key===safe.key),true);assert.equal(safeRoot.visible,true,'undo rebinds and restores the authored root');

await bootstrap.dispose();
console.log(`walk map editor live inventory: PASS (75 + 3, ${locked.length} protected)`);
