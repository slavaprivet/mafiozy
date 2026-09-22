import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {createArtist14Pose} from './hero_artist14_pose.mjs';
import {createNpcDeathPose20} from './npc_death_pose20.mjs';
const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {clone}=await import('./vendor/three_skeleton_utils.mjs');
const report=[],cost={base:[],profile:[]};
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url));
 const source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const actor=createNpcActor({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:'death_pose20_'+sex,sex});
 const c=actor.walker.artistContext(),base=createArtist14Pose(THREE),pose=createNpcDeathPose20({THREE,basePose:base});
 actor.object.position.set(4,0,8);actor.object.rotation.y=.2;
 const reset=()=>{actor.walker.reset();c.object.updateMatrixWorld(true)};
 const signature=()=>Object.values(c.bones).flatMap(bone=>bone.matrixWorld.elements);
 const delta=(a,b)=>Math.max(...a.map((value,i)=>Math.abs(value-b[i])));
 for(const age of [0,.05,.2,.5,1,10]){
  reset();base.reaction({kind:'dead',age,side:-1},c);const before=signature();
  reset();pose.reaction({kind:'dead',age,side:-1},c,{known:false,cause:'unknown'});assert(delta(before,signature())<1e-10,'unknown preserves authored pose');
 }
 const shapes=[];
 for(const cause of ['bullet','melee','super','kick','dropkick','blast']){
  const profile={known:true,cause,directionLocal:{x:.6,y:0,z:.8}};
  // At a fatal transition out of recovery, weight/side can already be partial.
  reset();base.reaction({kind:'dead',age:.48,side:.4},c);const inherited=signature();
  reset();pose.reaction({kind:'dead',age:.48,rawAge:0,side:.4},c,profile);assert(delta(inherited,signature())<1e-8,'no cause switch at initial recovery weight');
  let minSkinY=Infinity,maxHandStep=0,last=null;
  for(let frame=0;frame<=60;frame++){
   reset();pose.reaction({kind:'dead',age:frame/60,rawAge:frame/60,side:1},c,profile);
   const hand=c.worldPosition('socket_hand_r');if(last)maxHandStep=Math.max(maxHandStep,last.distanceTo(hand));last=hand;
   assert.deepEqual(actor.object.position.toArray(),[4,0,8]);assert.equal(actor.object.rotation.y,.2);
   for(const [name,bone]of Object.entries(c.bones)){const p=new THREE.Vector3(),q=new THREE.Quaternion(),scale=new THREE.Vector3();bone.matrix.decompose(p,q,scale);assert(p.distanceTo(c.rest[name].p)<1e-7);assert(scale.distanceTo(c.rest[name].s)<1e-6);assert(bone.matrix.elements.every(Number.isFinite));}
   if(frame%10===0){const p=new THREE.Vector3();actor.object.traverse(mesh=>{if(!mesh.isSkinnedMesh)return;mesh.skeleton.update();for(let i=0;i<mesh.geometry.attributes.position.count;i++){mesh.getVertexPosition(i,p).applyMatrix4(mesh.matrixWorld);minSkinY=Math.min(minSkinY,p.y)}});}
  }
  assert(minSkinY>-.025,'bounded actual skin-ground penetration '+sex+' '+cause+' '+minSkinY);
  assert(maxHandStep<.22,'continuous 60FPS fall '+cause+' '+maxHandStep);
  shapes.push(signature());report.push({sex,cause,minSkinY,maxHandStep});
 }
 for(let i=0;i<shapes.length;i++)for(let j=i+1;j<shapes.length;j++)assert(delta(shapes[i],shapes[j])>.015,'distinct cause poses');
 for(let frame=0;frame<65;frame++)for(const variant of frame%2?['profile','base']:['base','profile']){
  reset();const s={kind:'dead',age:.5,rawAge:.5,side:1},profile={known:true,cause:'bullet',directionLocal:{x:.6,y:0,z:.8}};
  const start=performance.now();if(variant==='base')base.reaction(s,c);else pose.reaction(s,c,profile);const elapsed=performance.now()-start;if(frame>10)cost[variant].push(elapsed);
 }
 actor.dispose();
}
const stats=a=>{a.sort((x,y)=>x-y);return {samples:a.length,p50:a[Math.floor(a.length*.5)],p95:a[Math.floor(a.length*.95)]}};
console.log(JSON.stringify({pass:true,report,cpuMs:{base:stats(cost.base),profile:stats(cost.profile)},limits:'Actual GLB isolated pose; no source cause integration, body-part effect, GPU or LIVE/FPS acceptance.'},null,2));
