import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createStaticRenderBatches} from './static_render_batches.mjs';
import {createWindowedBuildingEntry} from './building_window_integration.mjs';
import {applyBuildingDoorsGlass} from './building_doors_glass.mjs';

const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(specifier,context,nextResolve){return nextResolve(specifier==='three'?pathToFileURL(vendor+'build/three.module.js').href:specifier,context)}});
const T=await import('three');
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const multiDraw=process.argv.includes('--multi-draw');
const all=JSON.parse(readFileSync(new URL('buildings_placement.v1.json',import.meta.url))).instances;
const items=all.filter(item=>item.assetId==='garden_lane_house_v1');
assert.equal(items.length,3);
const bytes=readFileSync(new URL('../../..'+items[0].binding.url,import.meta.url));
const loader=new GLTFLoader().register(()=>({name:'Audit_No_Image_Upload',loadTexture(){return Promise.resolve(new T.Texture())}}));
const template=(await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
template.traverse(node=>{
 if(/(^|[_\s])(collision|collider|clearance|socket|anchor|keepout|nav|proxy|datum)([_\s]|$)/i.test(node.name)||/^(COLLISION|SOCKET|CLEARANCE|NAV_|COL_)/i.test(node.name))node.visible=false;
 if(node.isMesh){node.castShadow=node.receiveShadow=true;for(const material of Array.isArray(node.material)?node.material:[node.material])if(material.transparent){material.depthWrite=false;material.side=T.FrontSide;material.forceSinglePass=true;material.envMapIntensity=.35;}}
});

const root=new T.Group(),instances=[],resources=[];
for(const item of items){
 const group=new T.Group(),visual=template.clone(true),transform=item.transform;
 visual.position.fromArray(transform.modelLocalOffsetM);group.position.fromArray(transform.positionM);group.rotation.y=transform.yawDegrees*Math.PI/180;group.scale.setScalar(transform.uniformScale);group.add(visual);group.userData.instance=item;root.add(group);
 const doors=applyBuildingDoorsGlass(visual,item),building=createWindowedBuildingEntry({THREE:T,visual,instance:item});resources.push({doors,...building});instances.push(group);
}
root.updateWorldMatrix(true,true);
const visibleInHierarchy=node=>{for(let cursor=node;cursor;cursor=cursor.parent)if(cursor.visible===false)return false;return true};
const drawNodes=()=>{const nodes=[];root.traverse(node=>{if(node.isMesh&&visibleInHierarchy(node)&&node.material&&(Array.isArray(node.material)?node.material.some(m=>m.visible!==false):node.material.visible!==false))nodes.push(node)});return nodes};
const summarize=nodes=>{
 const rows=new Map();let main=0,shadow=0;
 for(const node of nodes){const key=node.name||'(unnamed)',row=rows.get(key)||{objects:0,instances:0,main:0,shadow:0};row.objects++;row.instances+=node.isInstancedMesh?node.count:1;row.main++;if(node.castShadow)row.shadow++;rows.set(key,row);main++;if(node.castShadow)shadow++;}
 return {main,shadow,total:main+shadow,topNames:[...rows].map(([name,row])=>({name,...row})).sort((a,b)=>b.main+b.shadow-a.main-a.shadow).slice(0,12)};
};
const beforeNodes=drawNodes(),sourceMaterials=new Map(beforeNodes.map(node=>[node,node.material])),before=summarize(beforeNodes),batches=createStaticRenderBatches({THREE:T,root,instances,minInstances:3,multiDraw}),afterNodes=drawNodes(),after=summarize(afterNodes);
const hidden=beforeNodes.filter(node=>node.material?.visible===false),batchNodes=afterNodes.filter(node=>node.userData.staticRenderBatch);
const dynamicSources=beforeNodes.filter(node=>node.userData?.breakableGlass||/ResidentialWindow|^(?:PublicDoor|ServiceDoor|DoorLeaf|Entry_Brass|Entry_Handle|Entry_Leaf|InteriorDoor)/.test(node.name));
assert(dynamicSources.every(node=>node.material===sourceMaterials.get(node)));
batches.setOptimizationEnabled(false);const optimizationSources=hidden.filter(node=>node.material===sourceMaterials.get(node));
const sourceComposition=new Map();for(const node of optimizationSources){const row=sourceComposition.get(node.name)||{sourceMeshes:0,copiedMembers:0};row.sourceMeshes++;row.copiedMembers+=node.isInstancedMesh?node.count:1;sourceComposition.set(node.name,row)}
batches.setOptimizationEnabled(true);assert(optimizationSources.every(node=>node.material?.visible===false));
assert.deepEqual([before.main,before.shadow,before.total],[318,303,621]);
assert.deepEqual([after.main,after.shadow,after.total],multiDraw?[105,92,197]:[308,293,601]);
const stats=batches.stats();assert.deepEqual([stats.optimizationBatches,stats.optimizationMembers],multiDraw?[14,339]:[0,0]);assert.equal(hidden.length,multiDraw?243:15);
const existingBaseline=multiDraw?{main:217,shadow:202,total:419}:{main:308,shadow:293,total:601};
const report={scope:'actual Three r180 lod0 plus production entry/storey/window/furnishing builders; potential visible draw objects, no GPU',assetId:'garden_lane_house_v1',multiDraw,placements:items.length,template:{meshes:[...template.children].length},beforeAllBatching:before,existingBaseline,afterCandidate:after,candidateReduction:{main:existingBaseline.main-after.main,shadow:existingBaseline.shadow-after.shadow,total:existingBaseline.total-after.total,percent:Number(((existingBaseline.total-after.total)/existingBaseline.total*100).toFixed(1))},newStaticArchitecture:{sourceMeshes:optimizationSources.length,copiedMembers:optimizationSources.reduce((sum,node)=>sum+(node.isInstancedMesh?node.count:1),0),materialBatchGroups:stats.optimizationBatches,composition:Object.fromEntries([...sourceComposition].sort(([a],[b])=>a.localeCompare(b)))},batching:stats,hiddenSources:hidden.length,batchObjects:batchNodes.length,dynamicExcluded:dynamicSources.length,limits:['main/shadow counts are asset-local draw-bearing objects, not a full-scene GPU measurement','multiDraw=true matches the current GTX path; fallback preserves authored pools and receives no garden-specific gain']};
console.log(JSON.stringify(report,null,2));
batches.dispose();
for(const resource of resources){resource.roomReveals?.dispose();resource.entry?.dispose();resource.windows?.dispose();resource.doors.dispose()}
