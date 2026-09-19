import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const samples=[];
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const actor=createNpcActor({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:'shop_'+sex,sex}),c=actor.walker.artistContext(),position={x:4.1,y:0,z:8.2};
 const tick=(time,life={},extra={})=>actor.update(.05,{time,position,yaw:.2,life,...extra});
 tick(1);const neutral=c.worldPosition('socket_hand_r');let maxMotion=0,previous=null;
 for(let i=0;i<31;i++){
  const time=1+i*.05,activity={kind:'shop',phase:i<15?'browse':'pay',since:1000,payAt:1750,until:2550};
  const t=performance.now();tick(time,{activity});samples.push(performance.now()-t);
  const hand=c.worldPosition('socket_hand_r');maxMotion=Math.max(maxMotion,hand.distanceTo(neutral));
  if(previous)assert(hand.distanceTo(previous)<.18,'bounded motion across browse/pay');previous=hand;
  assert.deepEqual(actor.object.position.toArray(),[position.x,position.y,position.z]);
  for(const [name,bone]of Object.entries(c.bones)){const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);assert(p.distanceTo(c.rest[name].p)<1e-7,'rest length '+name);assert(s.distanceTo(c.rest[name].s)<1e-6);assert(bone.matrix.elements.every(Number.isFinite));}
 }
 assert(maxMotion>.10,'visible reach to inspect/pay '+sex);
 tick(3);const released=c.worldPosition('socket_hand_r');tick(3,{activity:{kind:'shop',phase:'pay',since:1000,until:2000}});assert(c.worldPosition('socket_hand_r').distanceTo(released)<.001,'expired checkout clears arm');
 tick(3,{activity:{kind:'shop',phase:'pay',since:1000,until:10000},panic:true});assert(!actor.object.getObjectByName('NPC_Phone').visible);
 actor.dispose();
}
samples.sort((a,b)=>a-b);console.log(JSON.stringify({pass:true,rigs:['male','female'],cpuActorP50:samples[Math.floor(samples.length*.5)],cpuActorP95:samples[Math.floor(samples.length*.95)],limits:'real GLB CPU bones; no GPU visual acceptance, no added props/draw calls'}));
