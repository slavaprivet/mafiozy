import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroWalker,HERO_ASSET} from './hero_walk.mjs';
import {NPC_ASSETS} from './npc_actor.mjs';
import {ARSENAL,createWeaponModel} from './hero_arsenal.mjs';
import {createHeroFollowGesture} from './hero_follow_gesture.mjs';
const vendor=process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor',threeUrl=pathToFileURL(path.join(vendor,'build/three.module.js')).href;
registerHooks({resolve(s,c,n){return n(s==='three'?threeUrl:s,c)}});
const THREE=await import(threeUrl),{GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));

for(const [gender,asset] of [['male',HERO_ASSET],['female',NPC_ASSETS.female]]){
 const bytes=fs.readFileSync(new URL(asset.url)),gltf=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
 const hero=createHeroWalker({THREE,scene:gltf.scene}),ctx=hero.artistContext();hero.object.position.set(30,2,17);hero.object.rotation.y=.8;
 const point=name=>ctx.bones[name].getWorldPosition(new THREE.Vector3());
 const state=()=>Object.fromEntries(Object.entries(ctx.bones).map(([name,b])=>[name,b.matrix.elements.slice()]));
 for(const id of ['none','tt_pistol','ak74'])test(`${gender} ${id}: left follow gesture preserves locomotion, muzzle and primary grip`,()=>{
  const spec=ARSENAL.find(r=>r.id===id),model=id==='none'?null:createWeaponModel({THREE,id}),gesture=createHeroFollowGesture({THREE});hero.mountWeapon(model);
  const reset=()=>{hero.update(0,false,false,spec,{aimYaw:.8,aimPitch:0});hero.object.updateMatrixWorld(true);};reset();
  const baseline=state(),left=point('socket_hand_l'),root=hero.object.matrixWorld.elements.slice(),weaponMatrix=model?.matrixWorld.elements.slice(),right=point('socket_hand_r');
  const muzzle=model?model.localToWorld(new THREE.Vector3(...model.userData.muzzle)):null;
  assert(gesture.trigger({hero,weapon:spec,now:10}));const duration=gesture.duration;let maxTravel=0,maxHeight=-Infinity,minHeadDistance=Infinity,previousPalm=left.clone(),maxStep=0;
  const weaponBounds=model?new THREE.Box3().setFromObject(model):null;
  const trajectory=[];
  for(let i=0;i<=60;i++){
   reset();const before=state();gesture.apply({hero,weapon:spec,now:10+duration*i/60});hero.object.updateMatrixWorld(true);
   const after=state();for(const name of Object.keys(before))if(!['upperarm_l','forearm_l','hand_l'].includes(name))assert.deepEqual(after[name],before[name],`${name} local transform must stay host-owned`);
   assert.deepEqual(hero.object.matrixWorld.elements,root);assert(point('socket_hand_r').distanceTo(right)<1e-9);
   if(model){assert.deepEqual(model.matrixWorld.elements,weaponMatrix);assert(model.localToWorld(new THREE.Vector3(...model.userData.muzzle)).distanceTo(muzzle)<1e-9);}
   const palm=point('socket_hand_l');maxTravel=Math.max(maxTravel,palm.distanceTo(left));maxHeight=Math.max(maxHeight,palm.y-hero.object.position.y);minHeadDistance=Math.min(minHeadDistance,palm.distanceTo(point('head')));maxStep=Math.max(maxStep,palm.distanceTo(previousPalm));previousPalm.copy(palm);
   if(i>=15&&i<=38){const local=hero.object.worldToLocal(palm.clone());assert(local.x<-.15,'beckon stays on the left, clear of face and weapon');assert(local.y>=1.35,'palm is raised alongside head rather than swept across chest');assert(palm.distanceTo(point('head'))>.25,'palm clears head volume');if(weaponBounds)assert(weaponBounds.distanceToPoint(palm)>.12,'raised palm clears held weapon');}
   if([0,15,30,45,60].includes(i))trajectory.push(hero.object.worldToLocal(palm.clone()).toArray().map(v=>+v.toFixed(3)));
  }
  reset();gesture.apply({hero,weapon:spec,now:10+duration+1e-6});hero.object.updateMatrixWorld(true);
  assert(maxTravel>.25,'clear hand motion instead of imperceptible wrist rotation');assert(maxStep<.12,'blend has no sudden palm jump');assert.deepEqual(state(),baseline,'fresh host grip restored exactly after blend');assert.equal(gesture.active,false);
  if(model?.userData.twoHanded)assert(point('socket_hand_l').distanceTo(model.localToWorld(new THREE.Vector3(...model.userData.supportGrip)))<.01,'support palm returns to rifle');
  console.log(JSON.stringify({gender,id,maxTravel:+maxTravel.toFixed(3),maxHeight:+maxHeight.toFixed(3),minHeadDistance:+minHeadDistance.toFixed(3),trajectory}));
  reset();assert(gesture.trigger({hero,weapon:spec,now:20}));
  assert(gesture.trigger({hero,weapon:spec,now:20.1}),'a second press must not be discarded');
  assert.equal(gesture.queued,true);
  gesture.apply({hero,weapon:spec,now:20+duration*.5});hero.object.updateMatrixWorld(true);
  assert(point('socket_hand_l').distanceTo(left)>.25,'repeated V did not reset the active sweep');
  for(let i=0;i<10;i++)assert(gesture.trigger({hero,weapon:spec,now:20+duration*.55}));
  reset();gesture.apply({hero,weapon:spec,now:20+duration+1e-6});assert(gesture.active);assert.equal(gesture.queued,false);
  reset();gesture.apply({hero,weapon:spec,now:20+duration*1.5});hero.object.updateMatrixWorld(true);
  assert(point('socket_hand_l').distanceTo(left)>.25,'queued gesture actually raises the arm again');
  reset();gesture.apply({hero,weapon:spec,now:20+duration*2+2e-6});assert.equal(gesture.active,false,'rapid presses queue at most one repeat');assert.deepEqual(state(),baseline);
  assert(gesture.trigger({hero,weapon:spec,now:23}));assert(gesture.trigger({hero,weapon:spec,now:23.1}));
  assert.equal(gesture.apply({hero,weapon:spec,now:23.2,allowed:false}),false);assert.equal(gesture.active,false);assert.equal(gesture.queued,false);assert.deepEqual(state(),baseline);
  assert(gesture.trigger({hero,weapon:spec,now:24}));assert.equal(gesture.apply({hero,weapon:{id:'different'},now:24.2}),false);assert.equal(gesture.active,false);
  assert(gesture.trigger({hero,weapon:spec,now:25}));assert(gesture.trigger({hero,weapon:spec,now:25.1}));gesture.apply({hero,weapon:spec,now:28});assert.equal(gesture.active,false,'no delayed wave after a long hidden-tab pause');
  let nodes=0;hero.object.traverse(()=>nodes++);const costs=[];for(let i=0;i<600;i++){reset();gesture.trigger({hero,weapon:spec,now:30+i});const start=performance.now();gesture.apply({hero,weapon:spec,now:30+i+duration*.4});costs.push(performance.now()-start);}let endNodes=0;hero.object.traverse(()=>endNodes++);assert.equal(endNodes,nodes);
  costs.sort((a,b)=>a-b);console.log(`${gender}/${id} gesture-only CPU p50=${costs[300].toFixed(4)}ms p95=${costs[570].toFixed(4)}ms (not scene FPS)`);
  hero.mountWeapon(null);if(model)model.traverse(o=>{o.geometry?.dispose();for(const m of Array.isArray(o.material)?o.material:[o.material])m?.dispose();});
 });
}
