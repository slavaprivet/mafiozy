import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createNpcTrafficVehicleBinding} from './npc_vehicle_pose.mjs';

// Production regression. --require-fixed remains accepted explicitly;
// --baseline is only for an isolated rollback of the entry patch.
const requireFixed=!process.argv.includes('--baseline');
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(vendor+'/build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const glb=async url=>{const bytes=fs.readFileSync(url);return(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;};
class Box extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d);}}
const vehicleSource=await glb(new URL('./models/artist_vehicle_pack/compact_sedan.glb',import.meta.url)),watched=['head','chest','hand_l','hand_r','foot_l','foot_r'],report=[];

for(const sex of ['male','female']){
 const npcSource=await glb(new URL(NPC_ASSETS[sex].url));
 for(const scenario of [{name:'board',phase:'board',progress:.55,riding:false},{name:'seated',phase:'drive',progress:1,riding:true},{name:'exit',phase:'exit',progress:.4,riding:false}]){
  const scene=new THREE.Scene(),vehicle=createArtistVehicle(THREE,Box,vehicleSource,'compact_sedan');scene.add(vehicle.object);vehicle.object.position.set(18,.2,14);vehicle.object.rotation.y=.65;vehicle.object.updateMatrixWorld(true);
  const bridge=createNpcTrafficVehicleBinding({THREE,actor:vehicle}),seat=vehicle.seats.find(s=>s.id==='front_left'),outside=vehicle.object.localToWorld(new THREE.Vector3(Math.sign(seat.anchor.side)*1.55,0,seat.anchor.front)),seatRoot=bridge.getSeatRootWorld('front_left').clone(),fold=scenario.phase==='exit'?1-scenario.progress:scenario.progress;
  const position=outside.clone().lerp(seatRoot,fold);position.y=outside.y;const yaw=scenario.phase==='drive'?.65:.65+Math.sign(seat.anchor.side)*Math.PI/2,id=`vehicle_death20_${sex}_${scenario.name}`;
  const actor=createNpcActor({THREE,scene,source:npcSource,cloneSkeleton:clone,id,sex,getVehicle:()=>bridge}),pose=()=>Object.fromEntries(watched.map(name=>[name,actor.walker.artistContext().worldPosition(name).clone()]));
  const life={civilianTripRiding:scenario.riding,civilianTripCarId:'car',civilianTripPhase:scenario.phase,civilianTripProgress:scenario.progress,vehicleSeatId:'front_left'};
  actor.update(.05,{time:10,position,yaw,moving:false,posture:{target:'stand',value:0,blocked:false},aim:{},life});const before=pose();
  actor.update(.05,{time:10.05,position,yaw,moving:false,posture:{target:'stand',value:0,blocked:false},aim:{},lifecycle:{dead:true,key:'vehicle-death',age:0,side:1},life:{dead:true,deathConfirmed:true}});const after=pose(),jumps=Object.fromEntries(watched.map(name=>[name,before[name].distanceTo(after[name])])),maxBoneStepM=Math.max(...Object.values(jumps));
  assert(actor.object.position.distanceTo(position)<1e-9,scenario.name+' death keeps source root');assert(Math.abs(Math.atan2(Math.sin(actor.object.rotation.y-yaw),Math.cos(actor.object.rotation.y-yaw)))<1e-9,scenario.name+' death keeps source yaw');
  const saved=actor.saveSurfaceState(),savedPose=pose();actor.dispose();
  const returned=createNpcActor({THREE,scene,source:npcSource,cloneSkeleton:clone,id,sex,getVehicle:()=>bridge});returned.restoreSurfaceState(saved,{time:10.05,elapsedSeconds:0});returned.update(0,{time:10.05,position,yaw,moving:false,posture:{target:'stand',value:0,blocked:false},aim:{},lifecycle:{dead:true,key:'vehicle-death',age:0,side:1},life:{dead:true,deathConfirmed:true}});let reentryDifferenceM=0;for(const name of watched)reentryDifferenceM=Math.max(reentryDifferenceM,savedPose[name].distanceTo(returned.walker.artistContext().worldPosition(name)));assert(reentryDifferenceM<1e-6,scenario.name+' death cull/return must be deterministic');returned.dispose();vehicle.object.removeFromParent();
  report.push({sex,scenario:scenario.name,maxBoneStepM,jumps,reentryDifferenceM,rootPreserved:true,yawPreserved:true});
 }
}
const worst=Math.max(...report.map(row=>row.maxBoneStepM)),knownDefect=worst>=.1;
if(requireFixed)assert(!knownDefect,'vehicle pose -> death first frame still jumps: '+worst.toFixed(4)+' m');
else assert(knownDefect,'baseline no longer reproduces; run --require-fixed and convert this fixture to a regression');
console.log(JSON.stringify({mode:requireFixed?'require-fixed':'baseline',knownDefect,worstBoneStepM:worst,limitM:.1,report},null,2));
