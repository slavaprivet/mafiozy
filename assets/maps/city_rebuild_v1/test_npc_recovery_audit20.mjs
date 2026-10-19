// Read-only regression audit of actual male/female GLBs. No production edits.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c);}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const sources={};
for(const sex of ['male','female']){
 const b=fs.readFileSync(new URL(NPC_ASSETS[sex].url));
 sources[sex]=(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene;
}
function fixture(sex){
 const actor=createNpcActor({THREE,scene:new THREE.Scene(),source:sources[sex],cloneSkeleton:clone,id:'audit20:'+sex,sex});
 const position={x:4,y:0,z:-3},yaw=.4;actor.update(0,{time:1,position,yaw});
 actor.mountWeapon(new THREE.Group());const weapon=actor.weapon,context=actor.walker.artistContext(),bones=[];
 actor.object.traverse(o=>{if(o.isBone)bones.push({bone:o,length:o.position.length(),scale:o.scale.clone()});});
 const invariant=()=>{
  assert.deepEqual(actor.object.position.toArray(),[4,0,-3]);assert(Math.abs(actor.object.rotation.y-yaw)<1e-9);
  assert.equal(actor.weapon,weapon,'same mounted weapon object');
  for(const {bone,length,scale} of bones){assert(Math.abs(bone.position.length()-length)<1e-6,'unchanged bone length '+bone.name);assert(bone.scale.distanceTo(scale)<1e-9,'unchanged bone scale');}
 };
 const pose=()=>({q:context.visualPivot.quaternion.clone(),head:context.bones.head.getWorldPosition(new THREE.Vector3()).y});
 return {actor,pose,invariant};
}
for(const sex of ['male','female']){
 test(sex+' short source stun releases continuously and returns to walking',()=>{
  const {actor,pose,invariant}=fixture(sex);try{
   const point=actor.walker.artistContext().bones.head.getWorldPosition(new THREE.Vector3());
   assert(actor.receive({id:'confirmed-injury',confirmed:true,point,zone:'head',knockdown:false}));
   const bruises=actor.saveSurfaceState().surface.bruises;
   actor.update(.1,{time:2,stun:{active:true,age:.2}});const before=pose();
   actor.update(.001,{time:2.001,stun:{active:false,endedAge:0}});
   assert(before.q.angleTo(pose().q)<.02,'short stun release preserves tilt');
   actor.update(.1,{time:4,moving:true,motionSpeed:1,gaitDistance:.1,stun:{active:false,endedAge:1.999}});
   assert(!actor.diagnostics().sourceRecovering&&!actor.diagnostics().sourceDown);assert(pose().head>1);invariant();
   assert.deepEqual(actor.saveSurfaceState().surface.bruises,bruises,'confirmed injury persists through recovery');
   assert(!actor.receive({id:'confirmed-injury',confirmed:true,point,zone:'head'}),'injury receipt is not replayed');
  }finally{actor.dispose();}
 });
 test(sex+' long skipped time does not replay expired recovery after restore',()=>{
  const {actor,pose,invariant}=fixture(sex);try{
   actor.update(.1,{time:10,stun:{active:true,age:1}});
   actor.update(.01,{time:10.01,stun:{active:false,endedAge:0}});
   actor.update(.15,{time:10.16,stun:{active:false}});
   const saved=actor.saveSurfaceState();actor.restoreSurfaceState(saved,{time:40.16,elapsedSeconds:30});
   actor.update(.01,{time:40.17,moving:true,motionSpeed:1,gaitDistance:.01,stun:{active:false,endedAge:30.16}});
   assert(!actor.diagnostics().sourceRecovering&&!actor.diagnostics().sourceDown);assert(pose().head>1);invariant();
  }finally{actor.dispose();}
 });
 for(const trigger of ['repeat-stun','death'])test(sex+' recovery interrupted by '+trigger+' keeps visual continuity',()=>{
  const {actor,pose,invariant}=fixture(sex);try{
   actor.update(0,{time:10,stun:{active:true,age:1}});
   actor.update(.01,{time:10.01,stun:{active:false,endedAge:0}});
   actor.update(.15,{time:10.16,stun:{active:false}});const before=pose();
   actor.update(.001,{time:10.161,...(trigger==='repeat-stun'?{stun:{active:true,age:0}}:{lifecycle:{dead:true,key:'fatal-now',age:0}})});
   const after=pose(),angle=before.q.angleTo(after.q);invariant();
   console.log(JSON.stringify({sex,trigger,elapsedMs:1,angleRadians:angle,headBefore:before.head,headAfter:after.head,rootUnchanged:true}));
   assert(angle<.1&&Math.abs(after.head-before.head)<.1,'1 ms interruption must not snap a recovering actor upright');
  }finally{actor.dispose();}
 });
}
