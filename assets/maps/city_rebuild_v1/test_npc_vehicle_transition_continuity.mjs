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
 const scene=new THREE.Scene(),vehicle=createArtistVehicle(THREE,Box,vehicleSource,'compact_sedan');scene.add(vehicle.object);vehicle.object.position.set(18,.2,14);vehicle.object.rotation.y=.65;vehicle.object.updateMatrixWorld(true);
 const bridge=createNpcTrafficVehicleBinding({THREE,actor:vehicle}),seat=vehicle.seats.find(s=>s.id==='front_left'),outside=vehicle.object.localToWorld(new THREE.Vector3(Math.sign(seat.anchor.side)*1.55,0,seat.anchor.front)),seatRoot=bridge.getSeatRootWorld('front_left').clone();
 const npcSource=await glb(new URL(NPC_ASSETS[sex].url)),actor=createNpcActor({THREE,scene,source:npcSource,cloneSkeleton:clone,id:'transition_'+sex,sex,getVehicle:()=>bridge}),positions=()=>Object.fromEntries(watched.map(name=>[name,actor.walker.artistContext().worldPosition(name).clone()])),approachYaw=.65+Math.sign(seat.anchor.side)*Math.PI/2,steps=[];
 actor.update(.05,{time:1,position:outside,yaw:approachYaw,moving:true,running:false,gaitDistance:1.15,motionSpeed:1.1,posture:{target:'stand',value:0,blocked:false},aim:{}});const approach=positions();
 actor.update(.05,{time:1.05,position:outside,yaw:approachYaw,moving:false,running:false,gaitDistance:1.15,motionSpeed:0,posture:{target:'stand',value:0,blocked:false},aim:{},life:{civilianTripRiding:false,civilianTripCarId:'car',civilianTripPhase:'board',civilianTripProgress:0,vehicleSeatId:'front_left'}});const board0=positions();
 const jumps=Object.fromEntries(watched.map(name=>[name,approach[name].distanceTo(board0[name])]));
 let previous=board0,maxStepM=0,maxStep=null;
 const sample=(label,position,yaw,life,time)=>{actor.update(.05,{time,position,yaw,moving:false,running:false,gaitDistance:1.15,motionSpeed:0,posture:{target:'stand',value:0,blocked:false},aim:{},life});const current=positions();for(const name of watched){const distance=previous[name].distanceTo(current[name]);steps.push({label,name,distance,grip:actor.walker.diagnostics().vehicleGripAssignment});if(distance>maxStepM){maxStepM=distance;maxStep={label,name,distance,grip:actor.walker.diagnostics().vehicleGripAssignment};}}assert(actor.object.position.distanceTo(position)<1e-9,label+' preserves authority root');previous=current;};
 for(let i=1;i<=40;i++){const p=i/40,position=outside.clone().lerp(seatRoot,p);position.y=outside.y;sample('board-'+i,position,approachYaw,{civilianTripRiding:false,civilianTripCarId:'car',civilianTripPhase:'board',civilianTripProgress:p,vehicleSeatId:'front_left'},1.05+i*.05);}
 sample('drive',new THREE.Vector3(seatRoot.x,outside.y,seatRoot.z),.65,{civilianTripRiding:true,civilianTripCarId:'car',civilianTripPhase:'drive',civilianTripProgress:1,vehicleSeatId:'front_left'},3.1);
 for(let i=0;i<=40;i++){const p=i/40,position=seatRoot.clone().lerp(outside,p);position.y=outside.y;sample('exit-'+i,position,.65,{civilianTripRiding:false,civilianTripCarId:'car',civilianTripPhase:'exit',civilianTripProgress:p,vehicleSeatId:'front_left'},3.15+i*.05);}
 sample('released',outside,.65,{},5.2);
 const maxInitialJumpM=Math.max(...Object.values(jumps));
 assert(maxInitialJumpM<.1,sex+' first board frame must not snap limbs');
 if(maxStepM>=.1)console.log(JSON.stringify({sex,worst:steps.sort((a,b)=>b.distance-a.distance).slice(0,12)},null,2));
 assert(maxStepM<.1,sex+' board/drive/exit sequence must remain continuous: '+JSON.stringify(maxStep));
 // A threat can cancel entry before the driver reaches the seat. The source
 // reverses through exit progress 1-fold..1, preserving the exact first pose.
 const cutoff=.55,cancelSteps=[];let cancelPrevious;
 const cancelSample=(label,position,phase,progress,time)=>{actor.update(.05,{time,position,yaw:approachYaw,moving:false,running:false,gaitDistance:1.15,motionSpeed:0,posture:{target:'stand',value:0,blocked:false},aim:{},life:phase?{civilianTripRiding:false,civilianTripCarId:'car',civilianTripPhase:phase,civilianTripProgress:progress,vehicleSeatId:'front_left'}:{}});const current=positions();if(cancelPrevious)for(const name of watched)cancelSteps.push({label,name,distance:cancelPrevious[name].distanceTo(current[name])});cancelPrevious=current;};
 cancelSample('cancel-approach',outside,null,0,6);
 cancelSample('cancel-board-0',outside,'board',0,6.05);
 for(let i=1;i<=20;i++){const p=cutoff*i/20,position=outside.clone().lerp(seatRoot,p);position.y=outside.y;cancelSample('cancel-board-'+i,position,'board',p,6.05+i*.05);}
 const middle=outside.clone().lerp(seatRoot,cutoff);middle.y=outside.y;
 cancelSample('cancel-exit-0',middle,'exit',1-cutoff,7.1);
 for(let i=1;i<=20;i++){const q=i/20,p=1-cutoff+cutoff*q,position=middle.clone().lerp(outside,q);position.y=outside.y;cancelSample('cancel-exit-'+i,position,'exit',p,7.1+i*.05);}
 cancelSample('cancel-released',outside,null,0,8.15);
 const cancelWorst=cancelSteps.sort((a,b)=>b.distance-a.distance)[0];assert(cancelWorst.distance<.1,sex+' cancelled boarding must reverse continuously: '+JSON.stringify(cancelWorst));
 // A nearby cull may destroy and recreate the presentation actor while the
 // source-owned exit keeps running. Rehydrating the same seat/progress must
 // reconstruct the same side and bone pose without advancing the transition.
 let reentryMaxDifferenceM=0;
 for(const seatId of ['front_left','front_right']){
  const transitionSeat=vehicle.seats.find(s=>s.id===seatId),transitionOutside=vehicle.object.localToWorld(new THREE.Vector3(Math.sign(transitionSeat.anchor.side)*1.55,0,transitionSeat.anchor.front)),transitionRoot=bridge.getSeatRootWorld(seatId).clone(),position=transitionRoot.clone().lerp(transitionOutside,.4);position.y=transitionOutside.y;
  const snapshot={time:9,position,yaw:approachYaw,moving:false,running:false,gaitDistance:1.15,motionSpeed:0,posture:{target:'stand',value:0,blocked:false},aim:{},life:{civilianTripRiding:false,civilianTripCarId:'car',civilianTripPhase:'exit',civilianTripProgress:.4,vehicleSeatId:seatId}};
  const beforeCull=createNpcActor({THREE,scene,source:npcSource,cloneSkeleton:clone,id:'cull_'+sex+'_'+seatId,sex,getVehicle:()=>bridge});beforeCull.update(.05,snapshot);const beforePose=Object.fromEntries(watched.map(name=>[name,beforeCull.walker.artistContext().worldPosition(name).clone()]));beforeCull.dispose();
  const returned=createNpcActor({THREE,scene,source:npcSource,cloneSkeleton:clone,id:'cull_'+sex+'_'+seatId,sex,getVehicle:()=>bridge});returned.update(0,snapshot);for(const name of watched)reentryMaxDifferenceM=Math.max(reentryMaxDifferenceM,beforePose[name].distanceTo(returned.walker.artistContext().worldPosition(name)));assert(returned.object.position.distanceTo(position)<1e-9,seatId+' reentry preserves source root');returned.dispose();
 }
 assert(reentryMaxDifferenceM<1e-6,sex+' cull/return must reconstruct the same exit pose and side');
 const baselineActor=createNpcActor({THREE,scene,source:npcSource,cloneSkeleton:clone,id:'baseline_'+sex,sex}),blendedActor=createNpcActor({THREE,scene,source:npcSource,cloneSkeleton:clone,id:'blended_'+sex,sex}),times={before:[],after:[]};
 baselineActor.object.position.copy(seatRoot);baselineActor.object.rotation.y=.65;blendedActor.object.position.copy(seatRoot);blendedActor.object.rotation.y=.65;
 for(let i=0;i<140;i++)for(const mode of i%2?['before','after']:['after','before']){const p=(i%41)/40,fold=p,gripUnit=Math.max(0,Math.min(1,(fold-.62)/.38)),gripBlend=gripUnit*gripUnit*(3-2*gripUnit),walker=mode==='before'?baselineActor.walker:blendedActor.walker,at=performance.now();vehicle.poseOccupant(walker,'front_left',{fold,...(mode==='after'?{gripBlend}:{}),reach:Math.sin(p*Math.PI)*.65,dt:.05});if(i>=20)times[mode].push(performance.now()-at);}
 for(const values of Object.values(times))values.sort((a,b)=>a-b);const cpuMs=Object.fromEntries(Object.entries(times).map(([mode,values])=>[mode,{samples:values.length,p50:values[Math.floor(values.length*.5)],p95:values[Math.floor(values.length*.95)]}]));
 reports.push({sex,jumps,maxInitialJumpM,maxStepM,maxStep,cancelMaxStepM:cancelWorst.distance,cancelWorst,reentryMaxDifferenceM,cpuMs});
 assert(actor.object.position.distanceTo(outside)<1e-9,'authority root remains at the door');
 actor.dispose();baselineActor.dispose();blendedActor.dispose();
}
console.log(JSON.stringify(reports,null,2));
