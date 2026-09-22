import fs from 'node:fs';
import {applyNpcAppearance,describeNpcAppearance} from './npc_appearance.mjs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {normalizeNpcSnapshot} from './npc_population.mjs';
import {createNpcTrafficVehicleBinding} from './npc_vehicle_pose.mjs';
import {createWeaponModel} from './hero_arsenal.mjs';
const deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(deps+'/build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(deps+'/build/three.module.js'));const {GLTFLoader}=await import(pathToFileURL(deps+'/addons/loaders/GLTFLoader.js'));
const skeleton=await(await fetch('https://cdn.jsdelivr.net/npm/three@0.180.0/examples/jsm/utils/SkeletonUtils.js')).text();const {clone}=await import('data:text/javascript;base64,'+Buffer.from(skeleton.replace("from 'three'","from '"+pathToFileURL(deps+'/build/three.module.js').href+"'")).toString('base64'));
import {createArtistVehicle} from './vehicle_fleet_models.mjs';
class TestBox extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
const carBytes=fs.readFileSync(new URL('./models/artist_vehicle_pack/compact_sedan.glb',import.meta.url)),carSource=(await new GLTFLoader().parseAsync(carBytes.buffer.slice(carBytes.byteOffset,carBytes.byteOffset+carBytes.byteLength),'')).scene;
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene,world=new THREE.Scene(),vehicle=createArtistVehicle(THREE,TestBox,carSource,'compact_sedan');world.add(vehicle.object);vehicle.object.position.set(12,.3,9);vehicle.object.rotation.y=1.1;vehicle.object.updateMatrixWorld(true);
 const binding=createNpcTrafficVehicleBinding({THREE,actor:vehicle});assert(binding);
 const expectedRoot=vehicle.object.localToWorld(new THREE.Vector3(vehicle.seats[0].anchor.side,vehicle.seats[0].anchor.y,vehicle.seats[0].anchor.front));assert(binding.getDriverRootWorld().distanceTo(expectedRoot)<1e-9,'cached bridge root remains exact under vehicle world transform');
 const a=createNpcActor({THREE,scene:world,source,cloneSkeleton:clone,id:'bound',sex,getVehicle:()=>binding}),reference=createNpcActor({THREE,scene:world,source,cloneSkeleton:clone,id:'reference',sex});
 a.update(.05,{time:1,position:{x:11,y:0,z:8},yaw:.4,life:{civilianTripRiding:true,civilianTripCarId:'actual-car'}});
 const anchor=binding.getDriverRootWorld();reference.update(.05,{time:1,position:anchor,yaw:1.1});vehicle.poseOccupant(reference.walker,'front_left',{fold:1,reach:0,dt:.05});reference.object.updateMatrixWorld(true);
 const ac=a.walker.artistContext(),rc=reference.walker.artistContext();for(const name of Object.keys(ac.bones)){const actual=ac.bones[name].getWorldPosition(new THREE.Vector3()),expected=rc.bones[name].getWorldPosition(new THREE.Vector3());assert(actual.distanceTo(expected)<1e-5,sex+' exact native vehicle pose '+name);}
 assert.deepEqual(a.object.position.toArray(),[11,0,8],'NPC authority root restored');assert(Math.abs(a.object.rotation.y-.4)<1e-9);
 for(const seat of vehicle.seats.filter(s=>s.id!=='front_left')){
  const root=binding.getSeatRootWorld(seat.id).clone();
  a.update(.05,{time:1.4,position:{x:11,y:0,z:8},yaw:.4,life:{civilianTripRiding:true,civilianTripCarId:'actual-car',vehicleSeatId:seat.id}});
  reference.update(.05,{time:1.4,position:root,yaw:1.1});vehicle.poseOccupant(reference.walker,seat.id,{fold:1,reach:0,dt:.05});reference.object.updateMatrixWorld(true);
  for(const name of Object.keys(ac.bones))assert(ac.bones[name].getWorldPosition(new THREE.Vector3()).distanceTo(rc.bones[name].getWorldPosition(new THREE.Vector3()))<1e-5,sex+' actual passenger seat '+seat.id+' '+name);
  assert.deepEqual(a.object.position.toArray(),[11,0,8],'passenger preserves authority root');
 }
 binding.getDriverRootWorld(); // restore the shared scratch anchor for driver transition checks
 for(const phase of ['board','exit'])for(const progress of [0,.25,.5,.75,1]){
 const fold=phase==='board'?progress:1-progress,root={x:11+fold*(anchor.x-11),y:0,z:8+fold*(anchor.z-8)};
  a.update(.05,{time:2+progress,position:root,yaw:.4,life:{civilianTripRiding:false,civilianTripCarId:'actual-car',civilianTripPhase:phase,civilianTripProgress:progress}});
  const yaw=.4+Math.atan2(Math.sin(1.1-.4),Math.cos(1.1-.4))*fold,gripUnit=Math.max(0,Math.min(1,(fold-.62)/.38)),gripBlend=gripUnit*gripUnit*(3-2*gripUnit),doorUnit=Math.max(0,Math.min(1,progress/.55)),doorRelease=Math.max(0,Math.min(1,(progress-.45)/.55)),doorGripBlend=.55*doorUnit*doorUnit*(3-2*doorUnit)*(1-doorRelease*doorRelease*(3-2*doorRelease));
  reference.update(.05,{time:2+progress,position:{x:root.x,y:anchor.y*fold,z:root.z},yaw});vehicle.poseOccupant(reference.walker,'front_left',{fold,gripBlend,doorGrip:vehicle.getDoorHandleWorld('front_left'),doorGripBlend,side:1,driver:true,reach:Math.sin(progress*Math.PI)*.65,dt:.05});reference.object.updateMatrixWorld(true);
  for(const name of Object.keys(ac.bones))assert(ac.bones[name].getWorldPosition(new THREE.Vector3()).distanceTo(rc.bones[name].getWorldPosition(new THREE.Vector3()))<1e-5,sex+' animated '+phase+' '+progress+' '+name);
  assert.deepEqual(a.object.position.toArray(),[root.x,0,root.z],'transition retains source root, no visual seat snap');
 }
 a.dispose();reference.dispose();
}
console.log('PASS actual compact_sedan + both hero GLBs: native poseOccupant world bones match exactly; seat root semantics and source root preserved');
let bridgeVectorAllocations=0;class CountedVector3 extends THREE.Vector3{constructor(...args){super(...args);bridgeVectorAllocations++;}}
const measuredBinding=createNpcTrafficVehicleBinding({THREE:{...THREE,Vector3:CountedVector3},actor:createArtistVehicle(THREE,TestBox,carSource,'compact_sedan')});bridgeVectorAllocations=0;for(let i=0;i<120;i++)measuredBinding.getDriverRootWorld();assert.equal(bridgeVectorAllocations,0,'120 stable traffic bridge samples reuse the one seat-root vector');
console.log('PASS traffic seat bridge: stable root sampling allocates 0 vectors after setup');
import {createNpcPopulation} from './npc_population.mjs';
const originalFetch=globalThis.fetch;globalThis.fetch=async(url,options)=>String(url).startsWith('file:')?new Response(fs.readFileSync(new URL(url))):originalFetch(url,options);
let reads=0,snapshots=0,poses=0,updates=0;const shared={cars:[{id:'shared-car'}],npcs:[{id:'shared-npc',r:0,c:0,ang:0,weapon:'fists'}]},scene=new THREE.Scene();
const population=await createNpcPopulation({THREE,scene,loader:new GLTFLoader(),cloneSkeleton:clone,bridge:{getWorldClock:()=>({now:1000}),getDynamicEntities:()=>{reads++;return shared;}},onSnapshot:payload=>{assert.equal(payload,shared);snapshots++;},onBeforePose:()=>{poses++;}});
population.update(.05,1);const actor=population.getActor('shared-npc'),update=actor.update;actor.update=(...args)=>{updates++;assert(poses>=updates+1,'traffic frame update precedes NPC pose');return update(...args);};population.update(.05,1.05);population.update(.1,1.2);assert.equal(reads,2);assert.equal(snapshots,2);assert.equal(poses,3);assert.equal(updates,2);population.dispose();globalThis.fetch=originalFetch;
console.log('PASS shared source snapshot: two reads, two car callbacks, every traffic update before NPC pose; no second entity read');
