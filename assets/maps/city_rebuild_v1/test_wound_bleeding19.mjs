import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {createNpcContactRay} from './npc_contact_ray.mjs';
import {resolveNpcContactAnchor} from './npc_contact_anchor.mjs';
import {validateSurfaceMesh} from './npc_surface_state.mjs';
import {createWoundBleeding} from './artist14/wound_bleeding.mjs';
const deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(deps+'/build/three.module.js').href:s,c);}});
const THREE=await import(pathToFileURL(deps+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(deps+'/addons/loaders/GLTFLoader.js'));
const positionAt=(mesh,index=0)=>{const matrix=new THREE.Matrix4();mesh.getMatrixAt(index,matrix);return new THREE.Vector3().setFromMatrixPosition(matrix);};
const skinPoint=(root,row)=>{const mesh=validateSurfaceMesh(root,row.mesh);mesh.updateMatrixWorld(true);const point=new THREE.Vector3();row.indices.forEach((index,i)=>point.addScaledVector(mesh.getVertexPosition(index,new THREE.Vector3()).applyMatrix4(mesh.matrixWorld),row.weights[i]));return point;};
const timing=[];
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const scene=new THREE.Scene(),make=()=>createNpcActor({THREE,scene,source,cloneSkeleton:clone,id:'bleed-'+sex,sex});
 const actor=make(),context=actor.walker.artistContext();actor.update(0,{time:0});
 const ray=createNpcContactRay({THREE,getActors:()=>[actor]}),y=context.bones.chest.getWorldPosition(new THREE.Vector3()).y;
 const hit=ray({origin:new THREE.Vector3(0,y,5),direction:new THREE.Vector3(0,0,-1),range:10});assert(hit?.anchor,sex+' actual triangle contact');
 for(const [heavy,count] of [[false,20],[true,32]]){
  actor.surface.reset();assert(actor.receive({...hit,id:'burst-'+heavy,confirmed:true,kind:'bullet',heavy}));
  actor.surface.update(0,{time:0,groundWorldY:-10});assert.equal(actor.surface.particles.count,count);
  assert(positionAt(actor.surface.particles).distanceTo(new THREE.Vector3(hit.point.x,hit.point.y,hit.point.z))<1e-6);
  assert.equal(actor.surface.bleedingStats().activeWounds,1);
  assert.equal(actor.receive({...hit,id:'burst-'+heavy,confirmed:true,kind:'bullet',heavy}),false);
 }
 for(const event of [{id:'block',confirmed:true,blocked:true,point:hit.point},{id:'no-contact-death',confirmed:true,dead:true},{id:'unconfirmed',point:hit.point},{id:'missing-contact',confirmed:true}]){
  actor.surface.reset();actor.receive(event);actor.surface.update(0,{time:0,groundWorldY:-10});assert.equal(actor.surface.bleedingStats().activeWounds,0);assert.equal(actor.surface.particles.count,0);
 }
 // Exact triangle follows blended skin under movement, rotation and bone pose;
 // only three vertices are evaluated, no skeleton-wide update in the helper.
 actor.surface.reset();actor.walker.reset();actor.object.updateMatrixWorld(true);
 const drips=createWoundBleeding(THREE,{root:actor.object,bones:context.bones,unit:actor.surface.scale,height:actor.height});
 assert(drips.add({...hit,id:'skin',confirmed:true},0));assert.equal(drips.snapshot(0).rows[0].kind,'skin');
 actor.object.position.set(1,.2,-.4);actor.object.rotation.y=.65;context.bones.chest.rotation.z+=.15;actor.object.updateMatrixWorld(true);
 const expected=resolveNpcContactAnchor({THREE,record:actor,anchor:hit.anchor});assert(expected);
 const emissions=[];const skeletons=new Set();context.scene.traverse(o=>{if(o.isSkinnedMesh)skeletons.add(o.skeleton);});
 const updates=[...skeletons].map(s=>[s,s.update]);for(const [s]of updates)s.update=()=>assert.fail('drip must not update the entire skeleton');
 drips.update(.2,p=>emissions.push(p.clone()));for(const [s,update]of updates)s.update=update;
 assert.equal(emissions.length,1);assert(emissions[0].distanceTo(expected.point)<1e-6,sex+' posed exact skin origin');
 // Bone fallback keeps the received off-centre contact; never emits at bone origin.
 drips.reset();const bone=context.bones.head,exact=bone.localToWorld(new THREE.Vector3(.12,.3,.09));
 assert(drips.add({id:'melee',confirmed:true,point:exact,boneName:'head'},1));
 const local=bone.worldToLocal(exact.clone());bone.rotation.y+=.5;actor.object.updateMatrixWorld(true);
 drips.update(1.2,p=>assert(p.distanceTo(bone.localToWorld(local.clone()))<1e-6));
 // Four wounds and aggregate rate bound, finite duration, hidden/no catch-up.
 drips.reset();for(let i=0;i<8;i++)assert(drips.add({id:'cap'+i,confirmed:true,point:bone.localToWorld(local.clone()),boneName:'head',heavy:true},2));
 assert.equal(drips.count,4);let emitted=0;
 const begin=performance.now();for(let frame=0;frame<600;frame++)drips.update(2+frame/120,()=>emitted++);timing.push({sex,update600Ms:performance.now()-begin});
 assert(emitted<=50&&emitted>=30,'aggregate drop rate is bounded');
 actor.object.visible=false;const previous=drips.emittedDrops;drips.update(8,()=>assert.fail('culled actor emission'));
 actor.object.visible=true;drips.update(8.01,()=>assert.fail('no cull catch-up'));assert.equal(drips.emittedDrops,previous);
 drips.update(14.01,()=>assert.fail('expired wound'));assert.equal(drips.count,0);
 // Surface snapshot restores the local skin anchor onto a new actor UUID.
 actor.object.position.set(0,0,0);actor.object.rotation.set(0,0,0);actor.walker.reset();actor.surface.reset();actor.update(0,{time:20});
 const contact=ray({origin:new THREE.Vector3(0,context.bones.chest.getWorldPosition(new THREE.Vector3()).y,5),direction:new THREE.Vector3(0,0,-1),range:10});assert(contact);
 actor.receive({...contact,id:'persist',confirmed:true,kind:'bullet'});const saved=JSON.parse(JSON.stringify(actor.saveSurfaceState()));
 assert.equal(saved.surface.bleed.rows[0].kind,'skin');
 const restored=make();restored.object.position.set(12,0,-4);restored.object.updateMatrixWorld(true);
 assert(restored.restoreSurfaceState(saved,{time:30,elapsedSeconds:1}));assert.equal(restored.surface.particles.count,0);assert.equal(restored.surface.bleedingStats().emittedDrops,0);
 restored.surface.update(0,{time:30,groundWorldY:-10});assert.equal(restored.surface.particles.count,0,'restore does not replay burst');
 restored.surface.update(0,{time:30.5,groundWorldY:-10});assert.equal(restored.surface.bleedingStats().emittedDrops,1);
 assert(positionAt(restored.surface.particles).distanceTo(skinPoint(restored.object,saved.surface.bleed.rows[0]))<1e-6,'restored drip uses new actor world transform');
 const wounds=restored.surface.bleedingStats().activeWounds;
 restored.receive({confirmed:true,id:'death',dead:true});restored.surface.update(0,{time:31,groundWorldY:-10});
 assert.equal(restored.surface.bleedingStats().activeWounds,wounds,'death receipt adds no wound');assert.equal(restored.surface.bleedingStats().emittedDrops,2,'existing wound can finish bleeding during death');
 restored.object.position.x+=100;restored.surface.update(0,{time:31.2,groundWorldY:-10});assert.equal(restored.surface.particles.count,0,'teleport clears old world particles');
 restored.surface.update(0,{time:31.7,groundWorldY:-10});assert.equal(restored.surface.particles.count,1);
 const teleportedError=positionAt(restored.surface.particles).distanceTo(skinPoint(restored.object,saved.surface.bleed.rows[0]));
 assert(teleportedError<1e-5,'teleported source stays on wound (Float32 instance): '+teleportedError);
 const stable=JSON.stringify(restored.saveSurfaceState());
 for(const mutate of [s=>s.surface.bleed.rows[0].remaining=Infinity,s=>s.surface.bleed.rows[0].indices[0]=999999,s=>s.surface.bleed.rows[0].weights=[1,1,1],s=>s.surface.bleed.rows[0].id='missing-receipt',s=>s.surface.bleed.rows.push(...Array(4).fill(s.surface.bleed.rows[0]))]){
  const invalid=structuredClone(saved);mutate(invalid);assert.throws(()=>restored.restoreSurfaceState(invalid));assert.equal(JSON.stringify(restored.saveSurfaceState()),stable,'invalid bleed restore is atomic');
 }
 const legacy=structuredClone(saved);delete legacy.surface.bleed;restored.restoreSurfaceState(legacy,{time:40,elapsedSeconds:0});assert.equal(restored.surface.bleedingStats().activeWounds,0,'old snapshots remain valid');
 restored.restoreSurfaceState(saved,{time:50,elapsedSeconds:30});assert.equal(restored.surface.bleedingStats().activeWounds,0,'time offscreen expires bleed');
 actor.surface.reset();assert.deepEqual(actor.surface.bleedingStats(),{activeWounds:0,emittedDrops:0});
 assert.equal(actor.surface.particles.instanceMatrix.count,112,'shared pool remains bounded');
 actor.dispose();restored.dispose();assert.equal(scene.children.length,0);
}
console.log(JSON.stringify({pass:true,actualModels:['male','female'],timing,contracts:['exact skin and bone-local origin','20/32 hit burst','four wounds / ten drops per second','atomic and backward-compatible restore','death/cull/teleport/expiry','pool112/reset/dispose']},null,2));
