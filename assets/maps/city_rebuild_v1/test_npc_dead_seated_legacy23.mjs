// Production legacy-envelope regression using actual male/female posed bones.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {registerHooks} from 'node:module';
const dir=fileURLToPath(new URL('.',import.meta.url)),url=n=>pathToFileURL(path.join(dir,n));
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c);}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {createNpcActor,NPC_ASSETS}=await import(url('npc_actor.mjs'));
const {clone}=await import(url('vendor/three_skeleton_utils.mjs')),{createArtistVehicle}=await import(url('vehicle_fleet_models.mjs')),{createNpcTrafficVehicleBinding}=await import(url('npc_vehicle_pose.mjs'));
const glb=async location=>{const b=fs.readFileSync(location);return(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene;};
const vehicleSource=await glb(url('models/artist_vehicle_pack/compact_sedan.glb'));class Box extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d);}}
const copy=v=>JSON.parse(JSON.stringify(v)),signature=a=>Object.values(a.walker.artistContext().bones).flatMap(b=>b.matrixWorld.elements);let checks=0;
for(const sex of ['male','female']){
 const source=await glb(new URL(NPC_ASSETS[sex].url)),scene=new THREE.Scene(),car=createArtistVehicle(THREE,Box,vehicleSource,'compact_sedan');scene.add(car.object);const binding=createNpcTrafficVehicleBinding({THREE,actor:car});
 for(const origin of ['vehicle','prone']){
  const id='legacy_v1_'+sex+'_'+origin,options={THREE,scene,source,cloneSkeleton:clone,id,sex,getVehicle:()=>binding},stock=createNpcActor(options),restored=createNpcActor(options),base={position:{x:0,y:0,z:0},yaw:.2,moving:false,posture:{target:'stand',value:0}};
  stock.update(.016,{...base,time:10,...(origin==='vehicle'?{life:{civilianTripRiding:true,civilianTripCarId:'car',civilianTripPhase:'drive',civilianTripProgress:1,vehicleSeatId:'front_left'}}:{moving:true,posture:{target:'prone',value:2},life:{downed:true,lifeState:'downed'}})});
  stock.update(.016,{...base,time:10.016,lifecycle:{dead:true,key:'legacy-epoch',age:0}});const saved=copy(stock.saveSurfaceState());assert.equal(saved.deathEntry20.version,2);saved.deathEntry20.version=1;for(const key of ['vehicleBound','vehicleReleaseAt','lastRawAge'])delete saved.deathEntry20[key];
  for(const missingOrigin of [false,true]){
   const legacy=copy(saved);if(missingOrigin)delete legacy.deathEntry20.origin;
   if(origin==='prone'&&missingOrigin){const before=copy(restored.saveSurfaceState());assert.throws(()=>restored.restoreSurfaceState(legacy),/Invalid death entry pose/);assert.deepEqual(restored.saveSurfaceState(),before);checks++;continue;}
   const unchanged=JSON.stringify(legacy);restored.restoreSurfaceState(legacy,{time:10.016});assert.equal(JSON.stringify(legacy),unchanged,'normalization never mutates caller save');
   const normalized=restored.saveSurfaceState().deathEntry20;assert.equal(normalized.version,2);assert.equal(normalized.origin,origin);assert.equal(normalized.vehicleBound,false);assert.equal(normalized.vehicleReleaseAt,null);assert.equal(normalized.lastRawAge,0);
   restored.update(0,{...base,time:10.016});const expected=signature(stock),actual=signature(restored);assert(Math.max(...actual.map((v,i)=>Math.abs(v-expected[i])))<1e-7,'v1 visual restored unchanged');checks++;
  }
  const before=copy(restored.saveSurfaceState());for(const mutate of [d=>d.bones.pelvis[0]+=.1,d=>d.bones.head[7]*=2,d=>d.pivotQ=[NaN,0,0,1],d=>d.version=3]){const bad=copy(saved);mutate(bad.deathEntry20);assert.throws(()=>restored.restoreSurfaceState(bad),/Invalid death entry pose/);assert.deepEqual(restored.saveSurfaceState(),before);checks++;}
  stock.dispose();restored.dispose();
 }
 car.object.removeFromParent();
}
const report={pass:true,checks,scope:'Legacy v1 envelope from actual production poses restored into production v2, male/female vehicle/prone, missing origin, normalized metadata, strict shape and atomic invalid restore.'};console.log(JSON.stringify(report));
