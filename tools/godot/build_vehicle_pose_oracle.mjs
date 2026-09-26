import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const source=path.join(root,'assets/maps/city_rebuild_v1');
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c)}});
const T=await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
const {GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
const {RoundedBoxGeometry}=await import('../vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const {createHeroWalker}=await import(pathToFileURL(path.join(source,'hero_walk.mjs')));
const {ARTIST_VEHICLE_PROFILES,createArtistVehicle}=await import(pathToFileURL(path.join(source,'vehicle_fleet_models.mjs')));
const {entryPose}=await import(pathToFileURL(path.join(source,'car_entry.mjs')));
const parse=async name=>{const b=fs.readFileSync(path.join(source,name));return(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene};
const profile=ARTIST_VEHICLE_PROFILES.find(p=>p.id==='compact_sedan');
const car=createArtistVehicle(T,RoundedBoxGeometry,await parse('models/artist_vehicle_pack/'+profile.modelFile),profile);
const traces=[];
for(const seat of car.seats){
 const series=[];
 for(const p of [0,.12,.3,.42,.6,.78,.9,1]){const pose=entryPose(p);series.push({label:'entry:'+p,fold:pose.fold,reach:pose.reach,pose,side:seat.side,reclineBlend:pose.seat,dt:1/60});}
 series.push({label:'neutral',fold:0,reach:0,dt:0});
 series.push({label:'seated',fold:1,reach:0,dt:1/60});
 for(const blend of [.25,.5,1])series.push({label:'wheel:'+blend,fold:1,gripBlend:blend,steer:.8,dt:.1});
 series.push({label:'door-reach',fold:.72,side:seat.side,doorGripBlend:.75,doorGrip:car.getDoorHandleWorld(seat.id),gripBlend:0,dt:1/60});
 const hero=createHeroWalker({THREE:T,scene:await parse('hero_models/player_male.8130dfb1f7eb.glb'),targetHeight:1.9});
 hero.object.position.set(seat.anchor.side,seat.anchor.y,seat.anchor.front);hero.object.updateMatrixWorld(true);
 const frames=[];
 for(const options of series){
  car.update({steer:options.steer??0,distance:0});
  car.poseOccupant(hero,seat.id,options);
  const context=hero.artistContext(),rotations={},positions={},scales={};
  for(const [name,bone] of Object.entries(context.bones)){
   const p=new T.Vector3(),q=new T.Quaternion(),s=new T.Vector3();bone.matrix.decompose(p,q,s);
   rotations[name]=q.toArray();positions[name]=p.toArray();scales[name]=s.toArray();
  }
  const grips=car.getSteeringGrips();
  const input={...options,steering_left:hero.object.worldToLocal(grips.left.clone()).toArray(),steering_right:hero.object.worldToLocal(grips.right.clone()).toArray()};
  if(options.doorGrip)input.doorGrip=hero.object.worldToLocal(options.doorGrip.clone()).toArray();
  frames.push({input,rotations,positions,scales,visual_offset:context.visualPivot.position.toArray(),visual_rotation:context.visualPivot.quaternion.toArray(),head_yaw:hero.diagnostics().vehicleHeadYaw});
 }
 traces.push({seat:{id:seat.id,can_drive:seat.canDrive,side:seat.side,recline:car.profile.seatRecline},source_seat:seat,source_scale:hero.scale,frames});
 hero.dispose();
}
const receipts={};for(const name of ['hero_walk.mjs','vehicle_fleet_models.mjs','car_entry.mjs','hero_models/player_male.8130dfb1f7eb.glb','models/artist_vehicle_pack/'+profile.modelFile]){const b=fs.readFileSync(path.join(source,name));receipts[name]={sha256:crypto.createHash('sha256').update(b).digest('hex'),bytes:b.length};}
const out=path.join(root,'godot/mafiozi_walk/scripts/tests/fixtures/vehicle_occupant_pose_oracle.json');
fs.writeFileSync(out,JSON.stringify({source:'Unmodified actual createHeroWalker + createArtistVehicle + entryPose; compact_sedan actual GLBs',receipts,traces}));
console.log(JSON.stringify({output:out,traces:traces.length,frames:traces.reduce((n,t)=>n+t.frames.length,0),recline:car.profile.seatRecline,receipts}));
