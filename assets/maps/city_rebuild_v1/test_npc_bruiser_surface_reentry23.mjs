import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createNpcPopulation} from './npc_population.mjs';
import {performance} from 'node:perf_hooks';
import {resolveSurfaceMesh} from './npc_surface_state.mjs';
const deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(deps+'/build/three.module.js').href:s,c);}});
const THREE=await import(pathToFileURL(deps+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(deps+'/addons/loaders/GLTFLoader.js'));
const {clone}=await import('./vendor/three_skeleton_utils.mjs');
const originalFetch=globalThis.fetch;
globalThis.fetch=async(url,options)=>String(url).startsWith('file:')?{ok:true,arrayBuffer:async()=>{const bytes=fs.readFileSync(new URL(url));return bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength);}}:originalFetch(url,options);
const scene=new THREE.Scene(),population=await createNpcPopulation({THREE,scene,loader:new GLTFLoader(),cloneSkeleton:clone,maxActors:4,cacheSeconds:0,waterAt:()=>({level:.3,depth:.3})});
globalThis.fetch=originalFetch;
const rows=[];let clock=1,atomicCases=0,visibleWetChecks=0;
function assertVisibleWet(actor){
 const saved=actor.saveSurfaceState(),root=actor.walker.artistContext().scene;
 for(const record of saved.surface.wet.entries){
  const wet=resolveSurfaceMesh(root,record.path).geometry.attributes.aClothingWetness,bytes=atob(record.data);
  assert(wet&&wet.count===record.count);
  for(let i=0;i<wet.count;i++)assert.equal(Math.round(Math.max(0,Math.min(1,wet.array[i]))*255),bytes.charCodeAt(i),'snapshot and actual render attribute match');
  visibleWetChecks++;
 }
}
for(const gender of [0,1])for(const bruiser of [false,true]){
 const row={id:`npc_surface_shape23_${gender}_${bruiser}`,r:10,c:10,ang:Math.PI/2,role:'gang',look:{gender,body:gender?0:2,suit:gender?'#654877':'#345657'},mercenary:{profession:bruiser?'bruiser':'gunman',status:'hired'}};
 population.sync([row],clock);population.update(.1,clock+.1);
 const before=population.getActor(row.id),context=before.walker.artistContext();before.object.updateMatrixWorld(true);
 const meshes=[];context.scene.traverse(o=>{if(o.isSkinnedMesh){o.skeleton.update();o.computeBoundingSphere();meshes.push(o);}});
 const direction=new THREE.Vector3(0,0,-1).applyQuaternion(context.offset.getWorldQuaternion(new THREE.Quaternion()));
 const hit=new THREE.Raycaster(context.offset.localToWorld(new THREE.Vector3(0,2.8,2)),direction,0,4).intersectObjects(meshes,false)[0];assert(hit);
 assert(before.receive({id:'wound-'+row.id,confirmed:true,kind:'bullet',point:hit.point,normal:direction.clone().negate(),clothing:true}));
 assert(before.receive({id:'bruise-'+row.id,confirmed:true,zone:'head',point:context.bones.head.getWorldPosition(new THREE.Vector3())}));
 const saved=JSON.parse(JSON.stringify(before.saveSurfaceState()));assert.equal(saved.bodyShape.bruiser,bruiser);
 assert(saved.surface.wet.entries.some(e=>[...atob(e.data)].some(v=>v.charCodeAt(0)>0)));assert.equal(saved.surface.wounds.marks.length,1);
 population.sync([],clock+1);assert.equal(population.getActor(row.id),undefined);
 // The cached identity wins over a contradictory subsequent look packet.
 const changed={...row,r:20,c:22,look:{gender:1-gender,body:1,suit:'#ff0000'}};
 const at=performance.now();population.sync([changed],clock+2);const recreateMs=performance.now()-at;
 const after=population.getActor(row.id);assert(after&&after!==before);assert.equal(after.sex,gender?'female':'male');
 const restored=after.saveSurfaceState();
 assertVisibleWet(after);
 assert.equal(restored.bodyShape.bruiser,bruiser);
 assert.deepEqual(restored.surface.wet.entries.map(e=>e.signature),saved.surface.wet.entries.map(e=>e.signature));
 assert.deepEqual(restored.surface.wounds,saved.surface.wounds,'local wound anchors, mesh identities and receipts preserved');
 assert.deepEqual(restored.surface.bruises,saved.surface.bruises);assert.deepEqual(restored.surface.receipts,saved.surface.receipts);
 for(let j=0;j<saved.surface.wet.entries.length;j++){
  const old=atob(saved.surface.wet.entries[j].data),now=atob(restored.surface.wet.entries[j].data);
  for(let i=0;i<old.length;i++)assert(Math.abs(now.charCodeAt(i)-Math.max(0,old.charCodeAt(i)-1.9/90*255))<=1,'only actual offscreen dry aging');
 }
 assert.equal(after.receive({id:'wound-'+row.id,confirmed:true,kind:'bullet',point:hit.point,normal:direction.clone().negate()}),false,'receipt dedup survives recreation');
 assert.equal(after.surface.particles.count,0,'restore never replays contact particles');
 // Bad shape/identity/garment payload must leave current geometry AND effects intact.
 const stable=JSON.stringify(after.saveSurfaceState());
 for(const mutate of [s=>s.bodyShape.version=2,s=>s.bodyShape.bruiser='true',s=>s.bodyShape.bruiser=!s.bodyShape.bruiser,s=>s.id='other',s=>s.sex=s.sex==='male'?'female':'male',s=>s.surface.wet.entries[0].signature='wrong-garment',s=>{s.bodyShape.bruiser=!s.bodyShape.bruiser;s.surface.wounds.marks[0].anchors[0].a=999999;}]){
  const bad=structuredClone(saved);mutate(bad);assert.throws(()=>after.restoreSurfaceState(bad));assert.equal(JSON.stringify(after.saveSurfaceState()),stable,'transactional shape + surface rollback');atomicCases++;
 }
 const legacy=structuredClone(restored);delete legacy.bodyShape;
 if(bruiser){assert.throws(()=>after.restoreSurfaceState(legacy));assert.equal(JSON.stringify(after.saveSurfaceState()),stable,'ambiguous legacy shaped state stays rejected');}
 else{assert(after.restoreSurfaceState(legacy,{time:restored.surface.time,elapsedSeconds:0}));assert.deepEqual(after.saveSurfaceState().surface.wounds,restored.surface.wounds);}
 // Same cached actor leaves/reenters snapshot without eviction too.
 const current=after.saveSurfaceState();after.restoreSurfaceState(current,{time:clock+2,elapsedSeconds:0});
 assert.deepEqual(after.saveSurfaceState().surface.wounds,current.surface.wounds);
 const root=after.walker.artistContext().scene,attributes=current.surface.wet.entries.map(e=>resolveSurfaceMesh(root,e.path).geometry.attributes.aClothingWetness);
 for(const enabled of [!bruiser,bruiser]){
  after.update(.1,{time:clock+2.1,position:{x:22*4.1,y:0,z:20*4.1},life:{...row,mercenary:{profession:enabled?'bruiser':'gunman',status:'hired'}},inWater:true,waterLevel:.5});
  assertVisibleWet(after);
  current.surface.wet.entries.forEach((e,i)=>assert.equal(resolveSurfaceMesh(root,e.path).geometry.attributes.aClothingWetness,attributes[i],'shape toggle retains attached live wet attribute'));
 }
 // Valid shape restore changes an already-live actor back as a single operation.
 const state=after.saveSurfaceState();after.update(0,{time:clock+2.1,life:{mercenary:{profession:bruiser?'gunman':'bruiser',status:'hired'}}});
 assert(after.restoreSurfaceState(state,{time:state.surface.time,elapsedSeconds:0}));assert.equal(after.saveSurfaceState().bodyShape.bruiser,bruiser);assertVisibleWet(after);
 rows.push({sex:after.sex,bruiser,recreateMs,wounds:restored.surface.wounds.marks.length,wetMeshes:restored.surface.wet.entries.length});
 population.sync([],clock+3);clock+=10;
}
population.dispose();assert.equal(scene.children.length,0);
console.log(JSON.stringify({passed:true,actualRecreations:rows.length,atomicCases,visibleWetChecks,rows,limits:'Actual male/female GLB and population eviction/restore. No GPU/FPS. Creation timings include entire model and surface creation, not isolated patch cost.'},null,2));
