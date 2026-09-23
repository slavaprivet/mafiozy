import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createHeroWalker,HERO_ASSET} from './hero_walk.mjs';
import {createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createDemoCar} from './car_drive.mjs';
import {VEHICLE_SEATS} from './vehicle_seats.mjs';
import * as pose from './npc_vehicle_pose.mjs';

// Actual production functions, tracked character/vehicle GLBs, real Three.
// This test has no source substitution or dependency on isolated candidates.
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const load=async u=>{const b=fs.readFileSync(new URL(u));return(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene};
const sources={male:await load(HERO_ASSET.url),female:await load(new URL('./hero_models/player_female.298d50e6244a.glb',import.meta.url))};
let checks=0,maxError=0;
const check=(v,m)=>{assert(v,m);checks++};
const delta=(a,b)=>Math.max(...a.elements.map((x,i)=>Math.abs(x-b.elements[i])));
const world=(o,p,q)=>{o.position.copy(p);o.quaternion.copy(q);if(o.parent){o.parent.worldToLocal(o.position);o.quaternion.premultiply(o.parent.getWorldQuaternion(new T.Quaternion()).invert())}o.updateMatrixWorld(true)};
const sample=(w,car)=>{const c=w.artistContext(),inv=car.object.matrixWorld.clone().invert();return Object.fromEntries(Object.entries(c.bones).map(([k,b])=>[k,b.getWorldPosition(new T.Vector3()).applyMatrix4(inv)]))};
const err=(a,b)=>Math.max(...Object.keys(a).map(k=>a[k].distanceTo(b[k])));

for(const id of ['kingswell','sport_coupe','city_bus','police_interceptor']){
 const car=id==='kingswell'?createDemoCar(T,RoundedBoxGeometry):createArtistVehicle(T,RoundedBoxGeometry,await load(new URL('./models/artist_vehicle_pack/'+id+'.glb',import.meta.url)),id);
 if(id==='kingswell')car.seats=VEHICLE_SEATS;
 const scene=new T.Scene(),vehicleParent=new T.Group();scene.add(vehicleParent);vehicleParent.add(car.object);
 const vehicle=pose.createNpcTrafficVehicleBinding({THREE:T,actor:car});
 for(const sex of ['male','female'])for(const parented of [false,true]){
  const parent=new T.Group();scene.add(parent);
  if(parented){parent.position.set(-4,2,7);parent.rotation.set(.13,-.4,-.09);parent.updateMatrixWorld(true)}
  const w=createHeroWalker({THREE:T,scene:clone(sources[sex]),targetHeight:1.9});parent.add(w.object);
  for(const seat of car.seats){
   let flat;
   for(const [i,rot]of [[0,[0,0,0]],[1,[.24,-2.89,-.19]],[2,[-.21,3.09,.18]]]){
    vehicleParent.position.set(11,-.3,29);vehicleParent.rotation.set(parented?.08:0,parented?.31:0,parented?-.11:0);vehicleParent.updateMatrixWorld(true);
    // Flat reference is world-flat even when the vehicle parent is tilted.
    world(car.object,new T.Vector3(31+i*7,.7+i*.6,-13+i*2),new T.Quaternion().setFromEuler(new T.Euler(...rot)));
    const life={civilianTripRiding:true,civilianTripPhase:'drive',civilianTripCarId:id,vehicleSeatId:seat.id};
    const binding=pose.resolveNpcVehicleBinding(life,()=>vehicle),point=car.object.localToWorld(new T.Vector3(.2,-.1,.3));
    w.reset();world(w.object,point,new T.Quaternion().setFromEuler(new T.Euler(.02,.9,-.04)));
    const authority=w.object.matrixWorld.clone(),snapshot=JSON.stringify(life);
    pose.applyNpcVehicleBinding({THREE:T,walker:w,binding,dt:.03});
    check(delta(w.object.matrixWorld,authority)<1e-11,id+' source root unchanged');
    check(JSON.stringify(life)===snapshot,id+' source identity/seat unchanged');
    // A seated body must move rigidly with the actual car: each car-local bone
    // stays at its flat authored location, independently of the implementation.
    const posed=sample(w,car);if(!flat)flat=posed;
    const distance=err(flat,posed);maxError=Math.max(maxError,distance);
    check(distance<1e-5,`${id}/${sex}/${parented}/${seat.id}/${i} car-local all-bone covariance ${distance}`);
   }
   // The transition midpoint splits the shortest world-space arc. Source X/Z
   // is the authoritative door-crossing path and must never snap to the seat.
   const target=vehicle.getSeatRootWorld(seat.id).clone(),source=target.clone().add(new T.Vector3(.8,-.25,-.3));
   const sourceQ=new T.Quaternion().setFromEuler(new T.Euler(-.05,-Math.PI+.04,.03)),carQ=car.object.getWorldQuaternion(new T.Quaternion());
   for(const phase of ['board','exit'])for(const progress of [0,.5,1]){
    w.reset();world(w.object,source,sourceQ);const before=w.object.matrixWorld.clone();let posed;
    const wrapped={...vehicle,poseOccupant(actor,seatId,options){posed={point:actor.object.getWorldPosition(new T.Vector3()),q:actor.object.getWorldQuaternion(new T.Quaternion()),fold:options.fold};return vehicle.poseOccupant(actor,seatId,options)}};
    const binding=pose.resolveNpcVehicleBinding({civilianTripCarId:id,vehicleSeatId:seat.id,civilianTripPhase:phase,civilianTripProgress:progress},()=>wrapped);
    pose.applyNpcVehicleBinding({THREE:T,walker:w,binding,dt:.03});
    check(delta(w.object.matrixWorld,before)<1e-11,'transition does not move authority');
    check(Math.abs(posed.point.x-source.x)+Math.abs(posed.point.z-source.z)<1e-10,'source door crossing retained');
    check(Math.abs(posed.point.y-(source.y+(target.y-source.y)*posed.fold))<1e-10,'world vertical interpolation');
    if(posed.fold===0)check(posed.q.angleTo(sourceQ)<1e-7,'zero-fold source orientation');
    else if(posed.fold===1)check(posed.q.angleTo(carQ)<1e-7,'full-fold car orientation');
    else{const a=sourceQ.angleTo(posed.q),b=posed.q.angleTo(carQ),full=sourceQ.angleTo(carQ);check(Math.abs(a-b)<1e-7&&Math.abs(a+b-full)<1e-7,'midpoint splits shortest world arc');}
   }
  }
  // Old seat-center providers intentionally use the legacy branch. Its public
  // contract is a seated hip center at the supplied point, without root motion.
  const legacySeat=new T.Vector3(5,1,3),legacyVehicle={object:car.object,yaw:.35,getDriverSeatWorld:()=>legacySeat};
  const binding=pose.resolveNpcVehicleBinding({civilianTripRiding:true,civilianTripCarId:id},()=>legacyVehicle);
  check(binding&&!binding.rootSeat,'legacy seat-center branch selected');
  w.reset();world(w.object,new T.Vector3(2,.4,-1),new T.Quaternion().setFromEuler(new T.Euler(0,.8,0)));
  const before=w.object.matrixWorld.clone();pose.applyNpcVehicleBinding({THREE:T,walker:w,binding,dt:.03});
  const c=w.artistContext(),hips=c.worldPosition('thigh_l').add(c.worldPosition('thigh_r')).multiplyScalar(.5);
  check(hips.distanceTo(legacySeat)<1e-9,'legacy hip center reaches world seat');
  check(delta(w.object.matrixWorld,before)<1e-11,'legacy source root unchanged');
  w.dispose();parent.removeFromParent();
 }
 vehicleParent.visible=false;
 check(pose.resolveNpcVehicleBinding({civilianTripRiding:true,civilianTripCarId:id},()=>vehicle)===null,'hidden ancestor rejected');
 vehicleParent.visible=true;car.object.removeFromParent();
 check(pose.resolveNpcVehicleBinding({civilianTripRiding:true,civilianTripCarId:id},()=>vehicle)===null,'detached car rejected');
}
console.log(JSON.stringify({status:'PASS actual production fleet/GLB covariance, transition, authority, legacy and visibility',checks,maxCarLocalBoneErrorM:maxError}));
