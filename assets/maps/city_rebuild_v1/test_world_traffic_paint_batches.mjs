// Source paint must target authored materials, not the batching invisibility
// proxy. Real traffic factory and all twelve authored GLBs, CPU only.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createWorldTrafficPresentation} from './world_traffic_presentation.mjs';
import {ARTIST_VEHICLE_PROFILES} from './vehicle_fleet_models.mjs';
import {createVehicleRenderBatches,getVehicleRenderSourceMaterial} from './vehicle_render_batches.mjs';
const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const gltfLoader=new GLTFLoader(),loaded=[],helpers=new Map(),initial=new Map();let batchUpdates=0;
const loader={async loadAsync(url){const bytes=fs.readFileSync(new URL(url)),gltf=await gltfLoader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');loaded.push(gltf.scene);return gltf}};
const scene=new THREE.Scene(),fleet=createWorldTrafficPresentation({THREE,RoundedBox:RoundedBoxGeometry,loader,scene,renderBatchFactory(options){const helper=createVehicleRenderBatches(options),id=options.root.userData.sourceVehicleId,update=helper.update;helpers.set(id,helper);initial.set(id,{...helper.stats});helper.update=(...args)=>{batchUpdates++;return update(...args)};return helper}});
const rows=ARTIST_VEHICLE_PROFILES.map((p,i)=>({id:'paint_'+p.id,model:p.id,r:0,c:i*20/4.1,ang:0,paint:'#235a87'}));
// A second instance of the same model must own independent canonical paint.
rows.push({...rows[0],id:'paint_independent',c:400/4.1,paint:'#bd4721'});
const inputCopy=JSON.stringify(rows);fleet.sync(rows);await fleet.whenIdle();
for(let i=0;i<rows.length;i++)fleet.update(1/60);
function submissions(root){let count=0;root.traverse(n=>{if(!n.isMesh)return;for(let p=n;p;p=p.parent)if(!p.visible)return;const materials=Array.isArray(n.material)?n.material:[n.material];count+=materials.filter(m=>m?.visible).length});return count;}
const report=[];
for(const row of rows){
 const car=fleet.getActor(row.id),helper=helpers.get(row.id),before=initial.get(row.id),stats=helper.stats;
 report.push({id:row.id,members:stats.members,activeMembers:stats.activeMembers,fallbackMembers:stats.fallbackMembers,initialActiveBatches:before.activeBatches,activeBatches:stats.activeBatches,meshSubmissions:submissions(car.object)});
}
console.log(JSON.stringify({initialPaintCensus:report},null,2));
assert.equal(fleet.diagnostics().renderBatches.fallbackMembers,0,'source paint must not mutate hidden replacement and force mass fallback');
function paintedMeshes(car){const result=[];car.object.traverse(m=>{if(m.name?.endsWith('_LowerBody'))result.push(m)});return result;}
function assertPaint(car,paint){const color=new THREE.Color(paint);for(const mesh of paintedMeshes(car)){const value=getVehicleRenderSourceMaterial(mesh);for(const mat of Array.isArray(value)?value:[value])assert(mat.color.equals(color),'canonical LowerBody paint matches source');}}
for(const row of rows)assertPaint(fleet.getActor(row.id),row.paint);
const car=fleet.getActor(rows[0].id),other=fleet.getActor('paint_independent'),target=paintedMeshes(car)[0],canonical=getVehicleRenderSourceMaterial(target),hidden=target.material,helper=helpers.get(rows[0].id);
assert.notEqual(hidden,canonical,'actual source part is batched');const hiddenColor=hidden.color.clone(),geometry=target.geometry,owner=target.parent;
const changedRows=rows.map(row=>row.id===rows[0].id?{...row,paint:'#7f3'}:row);
const updatesBefore=batchUpdates;fleet.sync(changedRows);fleet.update(1/60);
assert.equal(batchUpdates,updatesBefore,'stationary paint change updates uniforms without rescanning batch geometry');
assertPaint(car,'#7f3');assertPaint(other,'#bd4721');assert(hidden.color.equals(hiddenColor),'presentation proxy remains untouched');assert.equal(target.geometry,geometry);assert.equal(target.parent,owner);
const paintedBatch=[];car.object.traverse(n=>{if(n.isBatchedMesh&&n.material===canonical)paintedBatch.push(n)});assert(paintedBatch.length>0);assert(paintedBatch.every(n=>n.material.color.equals(new THREE.Color('#7f3'))),'batch immediately uses updated canonical color');
helper.setDetailOptimizationEnabled(false);fleet.sync(changedRows.map(row=>row.id===rows[0].id?{...row,paint:'#693ab4'}:row));fleet.update(1/60);helper.setDetailOptimizationEnabled(true);assertPaint(car,'#693ab4');assert.equal(helper.stats.fallbackMembers,0,'runtime paint works with detail A/B off and on');
fleet.sync(changedRows.map(row=>row.id===rows[0].id?{...row,paint:'invalid'}:row));fleet.update(1/60);assertPaint(car,'#693ab4');
fleet.sync(changedRows.map(row=>({...row,c:row.c+.1,steer:.12,braking:true})));fleet.update(1/60);assert.equal(fleet.diagnostics().renderBatches.fallbackMembers,0,'moving/brake/steer update retains paint batching');
fleet.setNpcAccess(rows[0].id,'board',.5);assert.equal(helper.stats.fallbackMembers,0,'actual animated door still batches in its own owner');
// Legitimate per-part material replacement must remain authoritative and cause
// its normal local fallback, not be overwritten by cached canonical ownership.
const replacement=canonical.clone();target.material=replacement;fleet.sync(changedRows.map(row=>row.id===rows[0].id?{...row,paint:'#fb3a16'}:row));fleet.update(1/60);helper.update();
assert.equal(target.material,replacement);assert(replacement.color.equals(new THREE.Color('#fb3a16')));assert.equal(target.geometry,geometry);assert.equal(target.parent,owner);assert.equal(helper.stats.fallbackMembers,1,'only genuinely replaced material falls back');
assert.equal(JSON.stringify(rows),inputCopy,'source rows never rewritten');
const retained=report.map(r=>({id:r.id,retainedMembers:r.activeMembers,retainedBatches:r.activeBatches,structuralSavedCalls:r.activeMembers-r.activeBatches}));
fleet.dispose();fleet.dispose();assert.equal(scene.children.length,0);console.log(JSON.stringify({passed:true,models:12,actors:13,retained,scope:'CPU actual GLB hierarchy/material batching; submissions are structural one-pass counts, not GPU/FPS'},null,2));
