import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {createNpcContactRay} from './npc_contact_ray.mjs';
const deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(deps+'/build/three.module.js').href:s,c);}});
const THREE=await import(pathToFileURL(deps+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(deps+'/addons/loaders/GLTFLoader.js'));
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url));
 const source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const scene=new THREE.Scene(),actor=createNpcActor({THREE,scene,source,cloneSkeleton:clone,id:'contact-'+sex,sex}),context=actor.walker.artistContext();
 actor.update(.1,{time:1});
 const ray=createNpcContactRay({THREE,getActors:()=>[actor]}),normal=new THREE.Vector3(0,0,1);
 const shoot=y=>ray({origin:new THREE.Vector3(0,y,5),direction:new THREE.Vector3(0,0,-1),range:10});
 const head=shoot(context.bones.head.getWorldPosition(new THREE.Vector3()).y+.32);
 const chest=shoot(context.bones.chest.getWorldPosition(new THREE.Vector3()).y);
 assert(head&&chest,sex+' actual skin contacts');
 for(const [index,hit] of [head,chest].entries()){
  actor.surface.reset();
  assert(actor.receive({...hit,id:'bullet-'+index,confirmed:true,kind:'bullet',targetId:actor.id}));
  const marks=context.scene.getObjectByName('PersistentBulletWounds').children;
  assert(marks.length>0,sex+' accepted contact creates wound');
  assert.equal(marks[0].name,index===0?'BulletSkinWound':'RaggedBulletTear',sex+' actual contact material distinguishes skin and clothing');
  actor.update(0,{time:1});
  const matrix=new THREE.Matrix4();actor.surface.particles.getMatrixAt(0,matrix);
  assert(new THREE.Vector3().setFromMatrixPosition(matrix).distanceTo(new THREE.Vector3(hit.point.x,hit.point.y,hit.point.z))<1e-6,'blood originates at actual impact, not nose');
  assert.equal(actor.receive({...hit,id:'bullet-'+index,confirmed:true,kind:'bullet'}),false,'receipt does not replay blood');
 }
 actor.surface.reset();
 actor.receive({id:'no-fall',confirmed:true,kind:'dropkick',heavy:true,knockdown:false,point:chest.point,normal});
 assert.equal(actor.surface.state.kind,'hit','explicit source refusal to knock down beats attack presentation');
 actor.surface.reset();
 actor.receive({id:'fall',confirmed:true,kind:'melee',knockdown:true,point:chest.point,normal});
 assert.equal(actor.surface.state.kind,'fall');
 actor.surface.reset();
 actor.receive({id:'block',confirmed:true,kind:'dropkick',heavy:true,knockdown:true,blocked:true,point:chest.point,normal});
 assert.equal(actor.surface.state.kind,'block');assert.equal(actor.surface.snapshot().wounds.marks.length,0);
 actor.surface.reset();
 actor.receive({id:'death-no-contact',confirmed:true,dead:true,zone:'head'});
 assert.equal(actor.surface.state.kind,'dead');assert.deepEqual(actor.surface.snapshot().bruises,[0,0],'death lifecycle cannot invent an eye contact');
 actor.dispose();
}
console.log('PASS actual male/female hit surfaces: skin/clothing, blood origin, receipt dedupe, explicit knockdown authority, block, no-contact death');
