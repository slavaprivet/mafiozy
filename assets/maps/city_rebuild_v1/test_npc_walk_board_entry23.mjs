import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createNpcTrafficVehicleBinding} from './npc_vehicle_pose.mjs';

const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(vendor+'/build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const glb=async url=>{const bytes=fs.readFileSync(url);return(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;};
class Box extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d);}}
const vehicleSource=await glb(new URL('./models/artist_vehicle_pack/compact_sedan.glb',import.meta.url));
const watched=['head','chest','hand_l','hand_r','foot_l','foot_r'];

const reports=[];
for(const sex of ['male','female']){
 const source=await glb(new URL(NPC_ASSETS[sex].url));
 for(const seatId of ['front_left','front_right'])for(const earlyCancel of [false,true])for(let phase=0;phase<8;phase++){
  const scene=new THREE.Scene(),vehicle=createArtistVehicle(THREE,Box,vehicleSource,'compact_sedan');scene.add(vehicle.object);vehicle.object.rotation.y=.65;vehicle.object.updateMatrixWorld(true);
  const bridge=createNpcTrafficVehicleBinding({THREE,actor:vehicle}),seat=vehicle.seats.find(s=>s.id===seatId),outside=vehicle.object.localToWorld(new THREE.Vector3(Math.sign(seat.anchor.side)*1.55,0,seat.anchor.front));
  const actor=createNpcActor({THREE,scene,source,cloneSkeleton:clone,id:`entry_${sex}_${seatId}_${phase}_${earlyCancel}`,sex,getVehicle:()=>bridge}),context=actor.walker.artistContext();
  const snapshot={time:0,position:outside,yaw:.65+Math.sign(seat.anchor.side)*Math.PI/2,moving:true,running:false,motionSpeed:1.5,gaitDistance:.025,posture:{target:'stand',value:0},life:{}};
  for(let i=0;i<100+phase*7;i++){snapshot.time+=1/60;actor.update(1/60,snapshot);}
  const positions=()=>Object.fromEntries(watched.map(name=>[name,context.worldPosition(name).clone()]));let previous=positions(),maxStep=0,firstJump=0;
  const costs=[];
  for(let i=0;i<=9;i++){
   const progress=i*.025,tripPhase=earlyCancel&&i>=2?'exit':'board',tripProgress=tripPhase==='exit'?Math.min(1,.975+(i-2)*.005):progress;
   snapshot.time+=.05;snapshot.moving=false;snapshot.motionSpeed=0;snapshot.gaitDistance=0;snapshot.life={civilianTripCarId:'car',civilianTripPhase:tripPhase,civilianTripProgress:tripProgress,vehicleSeatId:seatId};
   const at=performance.now();actor.update(.05,snapshot);costs.push(performance.now()-at);const current=positions();
   for(const name of watched){const distance=current[name].distanceTo(previous[name]);if(i===0)firstJump=Math.max(firstJump,distance);else maxStep=Math.max(maxStep,distance);}
   assert(actor.object.position.distanceTo(outside)<1e-9,'blend cannot displace authority root');previous=current;
  }
  assert(firstJump<1e-6,JSON.stringify({sex,seatId,phase,earlyCancel,firstJump}));
  assert(maxStep<.1,JSON.stringify({sex,seatId,phase,earlyCancel,maxStep}));
  // Release and a new car must not inherit an old outgoing entry pose.
  snapshot.life={};actor.update(.05,snapshot);snapshot.life={civilianTripCarId:'car',civilianTripPhase:'drive',civilianTripRiding:true,civilianTripProgress:1,vehicleSeatId:seatId};actor.update(.05,snapshot);
  const reference=createNpcActor({THREE,scene,source,cloneSkeleton:clone,id:'fresh_'+phase,sex,getVehicle:()=>bridge});reference.update(.05,snapshot);for(const name of watched)assert(context.worldPosition(name).distanceTo(reference.walker.artistContext().worldPosition(name))<1e-6,'no entry residue while seated');reference.dispose();
  reports.push({sex,seatId,phase,earlyCancel,firstJump,maxStep,costs});actor.dispose();
 }
}
const report={cases:reports.length,maxFirstJump:Math.max(...reports.map(r=>r.firstJump)),maxStep:Math.max(...reports.map(r=>r.maxStep)),reports,limits:'Actual warm GLB poses, 50ms presentation updates. Whole-scene LIVE/FPS pending.'};fs.writeFileSync(new URL('../../../outputs/npc_walk_board_entry23.json',import.meta.url),JSON.stringify(report,null,2));console.log(JSON.stringify({cases:report.cases,maxFirstJump:report.maxFirstJump,maxStep:report.maxStep}));
