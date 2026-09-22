import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createNpcTrafficVehicleBinding} from './npc_vehicle_pose.mjs';

const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
class Box extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
const glb=async url=>{const bytes=fs.readFileSync(url);return(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene};
const models=['family_wagon','city_suv','police_interceptor'],sexes=['male','female'],heights=[1.65,2.05],watched=['head','chest','hand_l','hand_r','socket_hand_l','socket_hand_r','foot_l','foot_r'];
const smooth=x=>{x=Math.max(0,Math.min(1,x));return x*x*(3-2*x)},doorGripWeight=p=>.55*smooth(p/.55)*(1-smooth((p-.45)/.55));
const npcSources=Object.fromEntries(await Promise.all(sexes.map(async sex=>[sex,await glb(new URL(NPC_ASSETS[sex].url))]))),vehicleSources=Object.fromEntries(await Promise.all(models.map(async id=>[id,await glb(new URL('./models/artist_vehicle_pack/'+id+'.glb',import.meta.url))])));
const rows=[],times=[];
for(const model of models)for(const sex of sexes)for(const height of heights){
 const scene=new THREE.Scene(),vehicle=createArtistVehicle(THREE,Box,vehicleSources[model],model);scene.add(vehicle.object);vehicle.object.position.set(18,.2,14);vehicle.object.rotation.y=.65;vehicle.object.updateMatrixWorld(true);
 const bridge=createNpcTrafficVehicleBinding({THREE,actor:vehicle});
 for(const seat of vehicle.seats){
  const actor=createNpcActor({THREE,scene,source:npcSources[sex],cloneSkeleton:clone,id:['door20',model,sex,height,seat.id].join('_'),sex,height,getVehicle:()=>bridge}),context=actor.walker.artistContext();
  const doorSpec=vehicle.anchors.doors.find(door=>door.id===seat.id),outside=vehicle.object.localToWorld(new THREE.Vector3(Math.sign(seat.anchor.side)*seat.doorDistance,0,seat.doorFront)),seatRoot=bridge.getSeatRootWorld(seat.id).clone(),approachYaw=.65+Math.sign(seat.anchor.side)*Math.PI/2;
  let previous=null,maxStepM=0,maxStep=null,closestHandleM=Infinity,handleAt=null,threshold=null,seated=null;
  for(let i=0;i<=40;i++){
   const p=i/40,position=outside.clone().lerp(seatRoot,p);position.y=outside.y;vehicle.setDoorById(Math.min(1,p/.14,(1-p)/.14),seat.id);vehicle.object.updateMatrixWorld(true);const life={civilianTripRiding:false,civilianTripCarId:'car',civilianTripPhase:'board',civilianTripProgress:p,vehicleSeatId:seat.id};
   const started=performance.now();actor.update(.05,{time:1+i*.05,position,yaw:approachYaw,moving:false,running:false,gaitDistance:0,motionSpeed:0,posture:{target:'stand',value:0,blocked:false},aim:{},life});times.push(performance.now()-started);
   const pose=Object.fromEntries(watched.map(name=>[name,context.worldPosition(name).clone()]));
   if(previous)for(const name of watched){const distance=previous[name].distanceTo(pose[name]);if(distance>maxStepM){maxStepM=distance;maxStep={p,name,distance}}}
   const doorHand=pose[seat.side>0?'socket_hand_l':'socket_hand_r'],handle=bridge.getDoorHandleWorld(seat.id),handleDistance=doorHand.distanceTo(handle);if(doorGripWeight(p)>.47&&handleDistance<closestHandleM){closestHandleM=handleDistance;handleAt={p,doorGrip:doorGripWeight(p)}}
   if(i===20)threshold={left:vehicle.object.worldToLocal(pose.foot_l.clone()).toArray(),right:vehicle.object.worldToLocal(pose.foot_r.clone()).toArray()};
   previous=pose;
  }
  vehicle.setDoorById(0,seat.id);const drive={civilianTripRiding:true,civilianTripCarId:'car',civilianTripPhase:'drive',civilianTripProgress:1,vehicleSeatId:seat.id},driveRoot=new THREE.Vector3(seatRoot.x,outside.y,seatRoot.z);actor.update(.05,{time:3.1,position:driveRoot,yaw:.65,moving:false,running:false,gaitDistance:0,motionSpeed:0,posture:{target:'stand',value:0,blocked:false},aim:{},life:drive});
  const pose=Object.fromEntries(watched.map(name=>[name,context.worldPosition(name).clone()])),local=Object.fromEntries(Object.entries(pose).map(([name,v])=>[name,vehicle.object.worldToLocal(v.clone()).toArray()]));
  for(const name of watched){const distance=previous[name].distanceTo(pose[name]);if(distance>maxStepM){maxStepM=distance;maxStep={p:1.001,phase:'drive',name,distance}}}previous=pose;
  const grips=vehicle.getSteeringGrips(),gripError=seat.canDrive?Math.min(pose.socket_hand_l.distanceTo(grips.left)+pose.socket_hand_r.distanceTo(grips.right),pose.socket_hand_l.distanceTo(grips.right)+pose.socket_hand_r.distanceTo(grips.left)):null;
  seated={local,gripError,headRoofClearance:vehicle.anchors.roofBottom-local.head[1],lowestFootAboveFloor:Math.min(local.foot_l[1],local.foot_r[1])-vehicle.anchors.floorTop};
  assert(actor.object.position.distanceTo(driveRoot)<1e-9,'source root '+model+' '+seat.id);
  for(let i=0;i<=40;i++){
   const p=i/40,position=seatRoot.clone().lerp(outside,p);position.y=outside.y;vehicle.setDoorById(Math.min(1,p/.14,(1-p)/.14),seat.id);vehicle.object.updateMatrixWorld(true);actor.update(.05,{time:3.15+i*.05,position,yaw:.65,moving:false,running:false,gaitDistance:0,motionSpeed:0,posture:{target:'stand',value:0,blocked:false},aim:{},life:{civilianTripRiding:false,civilianTripCarId:'car',civilianTripPhase:'exit',civilianTripProgress:p,vehicleSeatId:seat.id}});const current=Object.fromEntries(watched.map(name=>[name,context.worldPosition(name).clone()]));for(const name of watched){const distance=previous[name].distanceTo(current[name]);if(distance>maxStepM){maxStepM=distance;maxStep={p,phase:'exit',name,distance}}}previous=current;
  }
  vehicle.setDoorById(0,seat.id);actor.update(.05,{time:5.2,position:outside,yaw:.65,moving:false,running:false,gaitDistance:0,motionSpeed:0,posture:{target:'stand',value:0,blocked:false},aim:{},life:{}});const released=Object.fromEntries(watched.map(name=>[name,context.worldPosition(name).clone()]));for(const name of watched){const distance=previous[name].distanceTo(released[name]);if(distance>maxStepM){maxStepM=distance;maxStep={p:1.001,phase:'released',name,distance}}}
  const thresholdInDoor=Object.values(threshold).some(([x,y,z])=>x>=doorSpec.opening.min[0]-.12&&x<=doorSpec.opening.max[0]+.12&&y>=vehicle.anchors.floorTop-.15&&z>=doorSpec.opening.min[2]-.12&&z<=doorSpec.opening.max[2]+.12);
  rows.push({model,sex,height,seat:seat.id,maxStepM,maxStep,closestHandleM,handleAt,threshold,thresholdInDoor,seated});actor.dispose();
 }
}
times.sort((a,b)=>a-b);
const report={rows,cpuMs:{samples:times.length,p50:times[Math.floor(times.length*.5)],p95:times[Math.floor(times.length*.95)]}};
if(process.argv.includes('--audit'))console.log(JSON.stringify(report,null,2));
else{
 for(const row of rows){assert(row.maxStepM<.12,JSON.stringify(row));assert(row.closestHandleM<.70,JSON.stringify(row));assert(row.thresholdInDoor,JSON.stringify(row));assert(row.seated.headRoofClearance>-.03,JSON.stringify(row));assert(row.seated.lowestFootAboveFloor>-.08,JSON.stringify(row));if(row.seated.gripError!==null)assert(row.seated.gripError<.12,JSON.stringify(row));}
 console.log(JSON.stringify({pass:true,cases:rows.length,worstStepM:Math.max(...rows.map(r=>r.maxStepM)),worstHandleM:Math.max(...rows.map(r=>r.closestHandleM)),minimumHeadRoofClearanceM:Math.min(...rows.map(r=>r.seated.headRoofClearance)),minimumFootFloorClearanceM:Math.min(...rows.map(r=>r.seated.lowestFootAboveFloor)),cpuMs:report.cpuMs,limits:'CPU actual GLBs; no renderer/GPU/full-scene FPS/LIVE acceptance.'},null,2));
}
