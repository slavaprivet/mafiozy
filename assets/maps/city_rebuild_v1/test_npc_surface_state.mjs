import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
const deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(deps+'/build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(deps+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(deps+'/addons/loaders/GLTFLoader.js'));
const skeletonCode=await(await fetch('https://cdn.jsdelivr.net/npm/three@0.180.0/examples/jsm/utils/SkeletonUtils.js')).text();
const {clone}=await import('data:text/javascript;base64,'+Buffer.from(skeletonCode.replace("from 'three'","from '"+pathToFileURL(deps+'/build/three.module.js').href+"'")).toString('base64'));
const bytes=fs.readFileSync(new URL(NPC_ASSETS.male.url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene,scene=new THREE.Scene();
const make=()=>createNpcActor({THREE,scene,source,cloneSkeleton:clone,id:'persistent-actor-1'});
const a=make();for(let i=0;i<3;i++)a.update(.1,{time:i*.1,inWater:true,waterLevel:.25});
const c=a.walker.artistContext(),surfaces=[];c.scene.traverse(o=>{if(o.isSkinnedMesh){o.skeleton.update();o.computeBoundingSphere();surfaces.push(o);}});
const hit=new THREE.Raycaster(c.offset.localToWorld(new THREE.Vector3(0,2.8,2)),new THREE.Vector3(0,0,-1),0,4).intersectObjects(surfaces,false)[0];assert(hit);
assert(a.receive({id:'hole-1',confirmed:true,kind:'bullet',point:hit.point,normal:{x:0,y:0,z:1},clothing:true}));
assert(a.receive({id:'eye-1',confirmed:true,zone:'head',point:c.bones.head.getWorldPosition(new THREE.Vector3())}));
const tear=c.scene.getObjectByName('PersistentBulletWounds').children[0],localBefore=[...tear.geometry.attributes.position.array];
const saved=JSON.parse(JSON.stringify(a.saveSurfaceState()));assert(saved.surface.wet.entries.some(e=>atob(e.data).split('').some(v=>v.charCodeAt(0)>0)));assert.equal(saved.surface.wounds.marks.length,1);
assert(a.receive({id:'fatal-1',confirmed:true,fatal:true}));const deathState=a.saveSurfaceState();a.dispose();
const b=make();b.object.position.set(10,0,-6);b.object.updateMatrixWorld(true);assert(b.restoreSurfaceState(saved,{time:500,elapsedSeconds:45}));
const bc=b.walker.artistContext(),restored=bc.scene.getObjectByName('PersistentBulletWounds').children[0];assert.equal(restored.geometry.attributes.position.count,tear.geometry.attributes.position.count);
assert(localBefore.every((v,i)=>Math.abs(v-restored.geometry.attributes.position.array[i])<1e-5),'anchors follow local mesh after teleport, never re-raycast old world hit');
assert.equal(b.surface.state.kind,'idle');assert.equal(b.surface.particles.count,0,'restore must not replay blood');
assert.equal(b.receive({id:'eye-1',confirmed:true,zone:'head',point:{x:10,y:1.7,z:-6}}),false,'receipts survive');
const bs=b.saveSurfaceState();assert.deepEqual(bs.surface.bruises,saved.surface.bruises);
for(let j=0;j<saved.surface.wet.entries.length;j++){const old=atob(saved.surface.wet.entries[j].data),now=atob(bs.surface.wet.entries[j].data);for(let i=0;i<old.length;i++)assert(Math.abs(now.charCodeAt(i)-Math.max(0,old.charCodeAt(i)-127.5))<=1,'45s dry aging');}
const stable=JSON.stringify(b.saveSurfaceState());
for(const mutate of [s=>s.id='wrong',s=>s.surface.wet.entries[0].signature='bad',s=>s.surface.wet.entries[0].count++,s=>s.surface.wounds.marks[0].anchors[0].a=999999,s=>s.surface.wounds.marks[0].anchors[0].weights=[1,1,1],s=>s.surface.reaction.age=NaN,s=>s.surface.bruises[0]=Infinity]){
 const bad=structuredClone(saved);mutate(bad);assert.throws(()=>b.restoreSurfaceState(bad));assert.equal(JSON.stringify(b.saveSurfaceState()),stable,'invalid payload must not partially clear valid state');
}
const d=make();d.restoreSurfaceState(deathState,{time:999,elapsedSeconds:300});d.update(.1,{time:999.1,position:{x:-8,y:0,z:2}});assert.equal(d.surface.state.kind,'dead');assert.equal(d.surface.particles.count,0);
assert.equal(b.surface.state.kind,'idle','materials/state independent');b.dispose();d.dispose();assert.equal(scene.children.length,0);
console.log('PASS surface serialization: JSON roundtrip, local wound anchors after teleport/recreation, dry aging, bruises/death/receipts, no replay particles, 7 atomic-invalid cases, independent disposal');
