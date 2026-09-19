import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createNpcTrafficVehicleBinding} from './npc_vehicle_pose.mjs';
import {createVehicleHijackPose} from './vehicle_hijack_pose.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const load=async url=>{const b=fs.readFileSync(url);return(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene};
class Box extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
const scene=new THREE.Scene(),car=createArtistVehicle(THREE,Box,await load(new URL('models/artist_vehicle_pack/compact_sedan.glb',import.meta.url)),'compact_sedan');
scene.add(car.object);car.object.position.set(12,0,9);car.object.rotation.y=.71;car.object.updateMatrixWorld(true);
const binding=createNpcTrafficVehicleBinding({THREE,actor:car}),seat=binding.getDriverRootWorld().clone(),outside=car.object.localToWorld(new THREE.Vector3(-car.seats[0].doorDistance,0,car.seats[0].doorFront));
const times=[],results=[];
for(const sex of ['male','female']){
 const source=await load(new URL(NPC_ASSETS[sex].url));
 for(const dead of [false,true]){
  const actor=createNpcActor({THREE,scene,source,cloneSkeleton:clone,id:sex+':'+dead,sex,getVehicle:()=>binding}),c=actor.walker.artistContext();
  let previous=null,maxBoneStep=0,maxAt=null;
  const bonePositions=()=>Object.values(c.bones).map(b=>b.getWorldPosition(new THREE.Vector3()));
  if(dead){
   actor.update(1/60,{time:9.9,position:{x:seat.x,y:0,z:seat.z},yaw:.71,life:{dead:true,hp:0,vehicleHijack:{phase:'seated',carId:'actual-car',seatId:'front_left',eventId:'stable'}}});
   previous=bonePositions();assert.equal(actor.surface.state.kind,'dead','seated corpse remains dead');
  }
  for(let i=0;i<=60;i++){
   const p=i/60,root=seat.clone().lerp(outside,p);root.y=0;
   const life={vehicleHijack:{phase:'pulled',progress:p,carId:'actual-car',seatId:'front_left',side:-1,eventId:'stable'},...(dead?{dead:true,hp:0}:{hp:100})};
   const begin=performance.now();actor.update(1/60,{time:10+p,position:root,yaw:.71,life});times.push(performance.now()-begin);
   assert(actor.object.position.distanceTo(root)<1e-10,'source position preserved');assert(Math.abs(actor.object.rotation.y-.71)<1e-10,'source yaw preserved');
   const current=bonePositions();for(const point of current)assert(point.toArray().every(Number.isFinite));
   if(previous)for(let j=0;j<current.length;j++){const d=current[j].distanceTo(previous[j]);if(d>maxBoneStep){maxBoneStep=d;maxAt={p,bone:Object.keys(c.bones)[j]}}}previous=current;
   for(const [name,bone]of Object.entries(c.bones)){
    const pos=new THREE.Vector3(),q=new THREE.Quaternion(),scale=new THREE.Vector3();bone.matrix.decompose(pos,q,scale);
    assert(pos.distanceTo(c.rest[name].p)<1e-7,'bone length stable '+name);assert(scale.distanceTo(c.rest[name].s)<1e-6,'bone scale stable '+name);
   }
   assert.equal(actor.surface.state.kind==='dead',dead,'extraction cannot create or erase death');
  }
  assert(maxBoneStep<.35,sex+' '+dead+' no extraction pose discontinuity: '+maxBoneStep+' '+JSON.stringify(maxAt));
  const final=bonePositions();actor.update(1/60,{time:12,position:{x:outside.x,y:0,z:outside.z},yaw:.71,life:dead?{dead:true,hp:0}:{hp:100}});
  if(dead){const normal=bonePositions(),d=normal.map((v,i)=>({name:Object.keys(c.bones)[i],d:v.distanceTo(final[i])})).sort((a,b)=>b.d-a.d);assert(d[0].d<.08,'extraction settles into existing corpse pose '+JSON.stringify(d.slice(0,4)));assert.equal(actor.surface.state.kind,'dead');}
  const pose=createVehicleHijackPose({THREE,walker:actor.walker,getVehicle:()=>car});
  actor.walker.reset();const rootBefore=actor.object.position.clone();
  assert.equal(pose.applyPuller({phase:'other',progress:.5}),false);
  assert(pose.applyPuller({phase:'pull_driver',progress:.45,carId:'actual-car',gripWorld:{x:outside.x,y:1.2,z:outside.z+.5}}));
  assert(actor.object.position.distanceTo(rootBefore)<1e-10,'puller pose preserves authoritative root');
  for(const [name,bone]of Object.entries(c.bones)){const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);assert(p.distanceTo(c.rest[name].p)<1e-7,'puller cannot stretch '+name);assert(s.distanceTo(c.rest[name].s)<1e-6)}
  actor.walker.reset();assert.equal(pose.applyReaction({phase:'protest',since:1000,until:2200},{time:1.5,blocked:true}),false);
  assert(pose.applyReaction({phase:'protest',since:1000,until:2200},{time:1.5}));
  results.push({sex,dead,maxBoneStep});actor.dispose();
 }
}
times.sort((a,b)=>a-b);const report={results,cpuActorUpdate:{p50Ms:times[Math.floor(times.length*.5)],p95Ms:times[Math.floor(times.length*.95)]},limits:'CPU actual male/female/compact sedan rigs. No renderer, source-carjacking success, physical contact or full scene FPS claim.'};
fs.writeFileSync(new URL('../../../outputs/vehicle_hijack_animation_20260913.json',import.meta.url),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
console.log('PASS hijack presentation preserves source roots, bone proportions, lifecycle death and protected reaction priority');
