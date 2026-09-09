import fs from 'node:fs';
import {applyNpcAppearance,describeNpcAppearance} from './npc_appearance.mjs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {normalizeNpcSnapshot} from './npc_population.mjs';
import {createWeaponModel} from './hero_arsenal.mjs';
const deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(deps+'/build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(deps+'/build/three.module.js'));const {GLTFLoader}=await import(pathToFileURL(deps+'/addons/loaders/GLTFLoader.js'));
const skeleton=await(await fetch('https://cdn.jsdelivr.net/npm/three@0.180.0/examples/jsm/utils/SkeletonUtils.js')).text();const {clone}=await import('data:text/javascript;base64,'+Buffer.from(skeleton.replace("from 'three'","from '"+pathToFileURL(deps+'/build/three.module.js').href+"'")).toString('base64'));
import {HERO_POSTURES} from './hero_posture.mjs';
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const make=id=>createNpcActor({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id,sex});
 for(const [running,slowWalking,speed]of [[false,false,4.6],[true,false,7.8],[false,true,1.65]]){
  const original=make('original'),explicit=make('explicit'),half=make('half');
  for(let i=0;i<24;i++){const options={time:(i+1)/60,moving:true,running,slowWalking};original.update(1/60,options);explicit.update(1/60,{...options,motionSpeed:speed});half.update(1/60,{...options,motionSpeed:speed/2});}
  const a=original.walker.artistContext(),b=explicit.walker.artistContext(),h=half.walker.artistContext();
  for(const name of Object.keys(a.bones))assert(a.bones[name].matrix.elements.every((v,i)=>Math.abs(v-b.bones[name].matrix.elements[i])<1e-10),'default hero equals canonical explicit speed');
  const gait=1-Math.exp(-4),angle=Math.sin(.4*speed*2.3)*gait*.56,q=a.rest.thigh_l.q.clone().multiply(new THREE.Quaternion().setFromEuler(new THREE.Euler(angle,0,0))),actual=new THREE.Quaternion();a.bones.thigh_l.matrix.decompose(new THREE.Vector3(),actual,new THREE.Vector3());assert(q.angleTo(actual)<1e-6,'default original phase formula preserved');
  assert(a.bones.thigh_l.matrix.elements.some((v,i)=>Math.abs(v-h.bones.thigh_l.matrix.elements[i])>1e-4),'measured slower motion changes cadence');
  original.dispose();explicit.dispose();half.dispose();
 }
}
console.log('PASS both GLB: unchanged default hero walk/run/slow phase and all bone matrices; measured half speed adjusts cadence only');
