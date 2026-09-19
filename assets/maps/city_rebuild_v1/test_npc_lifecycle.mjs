import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {normalizeNpcSnapshot} from './npc_population.mjs';
import {createWeaponModel} from './hero_arsenal.mjs';
const deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(deps+'/build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(deps+'/build/three.module.js'));const {GLTFLoader}=await import(pathToFileURL(deps+'/addons/loaders/GLTFLoader.js'));
const skeleton=await(await fetch('https://cdn.jsdelivr.net/npm/three@0.180.0/examples/jsm/utils/SkeletonUtils.js')).text();const {clone}=await import('data:text/javascript;base64,'+Buffer.from(skeleton.replace("from 'three'","from '"+pathToFileURL(deps+'/build/three.module.js').href+"'")).toString('base64'));
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene,world=new THREE.Scene();
 const a=createNpcActor({THREE,scene:world,source,cloneSkeleton:clone,id:'stun-'+sex,sex}),ctx=a.walker.artistContext();let time=0;
 const tick=(s={})=>{time+=.1;return a.update(.1,{time,...s});};tick();
 const meshes=[];ctx.scene.traverse(o=>{if(o.isSkinnedMesh){o.skeleton.update();o.computeBoundingSphere();meshes.push(o);}});const hit=new THREE.Raycaster(ctx.offset.localToWorld(new THREE.Vector3(0,2.8,2)),new THREE.Vector3(0,0,-1),0,4).intersectObjects(meshes,false)[0];assert(hit);
 a.receive({id:'tear',confirmed:true,kind:'bullet',point:hit.point,normal:{x:0,y:0,z:1},clothing:true});a.receive({id:'eye',confirmed:true,zone:'head',point:ctx.bones.head.getWorldPosition(new THREE.Vector3())});for(let i=0;i<8;i++)tick();const injuries=a.saveSurfaceState().surface;
 const sourceRow={id:a.id,r:0,c:0,dead:true,meleeStunned:true,meleeStunnedAt:1000,meleeStunnedUntil:3000};
 for(let i=0;i<10;i++){const snap=normalizeNpcSnapshot(sourceRow,{time:time+.1,sourceNowMs:1100+i*100});tick(snap);}
 assert(a.diagnostics().sourceDown);assert.notEqual(a.surface.state.kind,'dead');assert(ctx.bones.head.getWorldPosition(new THREE.Vector3()).y<.65,sex+' nonfatal source stun lies down');
 const saved=a.saveSurfaceState();assert(saved.sourceDown.active);
 for(let i=0;i<14;i++){const snap=normalizeNpcSnapshot({...sourceRow,meleeStunned:false,dead:false},{time:time+.1,sourceNowMs:3100+i*100});tick(snap);}
 assert(!a.diagnostics().sourceDown&&!a.diagnostics().sourceRecovering);assert(ctx.bones.head.getWorldPosition(new THREE.Vector3()).y>1.2,sex+' recovered stands');const after=a.saveSurfaceState().surface;assert.deepEqual(after.bruises,injuries.bruises);assert.deepEqual(after.wounds.marks,injuries.wounds.marks,'getting up never heals wounds');
 for(let i=0;i<8;i++)tick({life:{cuffed:true}});assert.equal(a.diagnostics().lifeGesture,'cuffed');for(const side of ['l','r'])assert(ctx.offset.worldToLocal(ctx.worldPosition('socket_hand_'+side)).z<-.15,'cuffed palms behind torso');
 const gun=createWeaponModel({THREE,id:'tt_pistol'});a.mountWeapon(gun);tick({life:{cuffed:true}});const armed=ctx.bones.hand_r.matrix.toArray();tick();assert(armed.every((v,i)=>Math.abs(v-ctx.bones.hand_r.matrix.elements[i])<1e-8),'armed cuffs do not overwrite weapon IK');assert.equal(a.diagnostics().lifeGesture,null);a.mountWeapon(null);
 // Actual medical source snapshot carries both downed and forcedCrawl.
 // Its base prone tilt must not cancel the authored nonfatal fall rotation.
 for(let i=0;i<10;i++)tick(normalizeNpcSnapshot({id:a.id,r:0,c:0,hp:1,dead:false,deathConfirmed:false,downed:true,downedAt:1000,downedUntil:0,forcedCrawl:true,panic:true,walking:true},{time:time+.1,sourceNowMs:5000+i*100}));
 assert(a.diagnostics().sourceDown);assert.notEqual(a.surface.state.kind,'dead','medical HP1 remains alive');
 assert(ctx.bones.head.getWorldPosition(new THREE.Vector3()).y<.65,sex+' medical downed cannot stand from double prone/fall rotation');
 for(let i=0;i<8;i++)tick({stun:{active:true,age:1}});a.receive({id:'real-death',confirmed:true,dead:true});for(let i=0;i<10;i++)tick({stun:{active:true,age:2}});assert.equal(a.surface.state.kind,'dead');assert(ctx.visualPivot.quaternion.angleTo(new THREE.Quaternion())<1.8,'death not composed with second source fall');
 a.dispose();gun.traverse(o=>{o.geometry?.dispose();o.material?.dispose();});assert.equal(world.children.length,0);
}
console.log('PASS both GLB source stun->recover preserves wounds/bruises, cuffed hands behind, armed IK, explicit source timing, serialized down state, death priority');
