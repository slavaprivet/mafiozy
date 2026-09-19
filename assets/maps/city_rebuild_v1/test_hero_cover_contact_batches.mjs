import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroWalker} from './hero_walk.mjs';
import {createDemoCar,CAR} from './car_drive.mjs';
import {createArtistVehicle,ARTIST_VEHICLE_PROFILES} from './vehicle_fleet_models.mjs';
import {createVehicleRenderBatches} from './vehicle_render_batches.mjs';
import {vehicleCoverContact} from './hero_cover_contact.mjs';
const baselineContact=process.env.COVER_CONTACT_BASELINE?(await import(pathToFileURL(process.env.COVER_CONTACT_BASELINE))).vehicleCoverContact:null;
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c);}});
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
async function glb(relative){const b=fs.readFileSync(new URL(relative,import.meta.url));return new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'');}
const hero=createHeroWalker({THREE:T,scene:(await glb('./hero_models/player_male.8130dfb1f7eb.glb')).scene}),c=hero.artistContext();
function pose(position,normal){hero.reset();hero.object.position.copy(position);hero.object.rotation.y=Math.atan2(normal.x,normal.z);hero.update(0,false,false,null,{aimYaw:hero.object.rotation.y},{posture:{target:'crouch',value:1}});}
function equal(a,b,label){assert.ok(a.gap===b.gap||Math.abs(a.gap-b.gap)<1e-8,label+' gap');assert.ok(Math.abs(a.distance-b.distance)<1e-8,label+' shift');assert.equal(a.rays,b.rays,label+' rays');}
let cases=0,batchMembers=0;
const cars=[{id:'kingswell',car:createDemoCar(T,RoundedBoxGeometry),profile:CAR}];
for(const profile of ARTIST_VEHICLE_PROFILES){const car=createArtistVehicle(T,RoundedBoxGeometry,await glb('./models/artist_vehicle_pack/'+profile.modelFile),profile);cars.push({id:profile.id,car,profile:car.profile});}
for(const {id,car,profile}of cars){
  const states=[];for(const open of [0,.8])for(const side of [-1,1])for(const yaw of [0,.71])states.push({open,side,yaw});
  function query(state,batches){
    car.object.position.set(29,2,-31);car.object.rotation.set(.025,state.yaw,-.03);
    car.setDoorById(state.open,'front_left');batches?.update();car.object.updateMatrixWorld(true);
    const normal=new T.Vector3(state.side,0,0).applyAxisAngle(new T.Vector3(0,1,0),state.yaw);
    pose(new T.Vector3(state.side*(profile.halfWidth+.37),0,-.25).applyMatrix4(car.object.matrixWorld),normal);
    const result=vehicleCoverContact(T,c,car.object,normal);if(baselineContact)equal(result,baselineContact(T,c,car.object,normal),id+' original triangle raycast');return result;
  }
  const before=states.map(s=>query(s));
  const batches=createVehicleRenderBatches({THREE:T,root:car.object,includeBody:true,includeDoors:true});batchMembers+=batches.stats.members;
  states.forEach((state,i)=>{equal(query(state,batches),before[i],id+' batched '+JSON.stringify(state));cases++;});
  batches.dispose();
}
// An instanced mesh whose prototype remains at the origin while the visible
// instances are translated/rotated must match equivalent ordinary meshes.
const root=new T.Group();root.position.set(20,0,-30);root.rotation.y=.63;
const geometry=new T.BoxGeometry(2,1.7,.3),material=new T.MeshBasicMaterial(),instanced=new T.InstancedMesh(geometry,material,2),ordinary=new T.Group();
root.add(instanced,ordinary);const local=new T.Matrix4(),rotation=new T.Quaternion(),scale=new T.Vector3(1,1,1);
const copies=[0,1].map(()=>{const mesh=new T.Mesh(geometry,material);mesh.matrixAutoUpdate=false;ordinary.add(mesh);return mesh;});
for(const offset of [0,2]){
  for(let i=0;i<2;i++){local.compose(new T.Vector3(10+i*5+offset,.85,5),rotation.setFromAxisAngle(new T.Vector3(0,1,0),i*.4),scale);instanced.setMatrixAt(i,local);copies[i].matrix.copy(local);}
  // Intentionally no needsUpdate flag: CPU instance transforms have changed.
  root.updateMatrixWorld(true);for(const index of [0,1]){const normal=new T.Vector3(0,0,-1).applyAxisAngle(new T.Vector3(0,1,0),root.rotation.y+index*.4);
  pose(new T.Vector3(0,-.85,-.67).applyMatrix4(root.matrixWorld.clone().multiply(copies[index].matrix)),normal);
  instanced.visible=false;ordinary.visible=true;const expected=vehicleCoverContact(T,c,root,normal);assert.ok(expected.gap!==null&&expected.distance>0);
  instanced.visible=true;ordinary.visible=false;equal(vehicleCoverContact(T,c,root,normal),expected,'translated instance '+offset);cases++;
  material.visible=false;assert.equal(vehicleCoverContact(T,c,root,normal).gap,null,'genuinely hidden material cannot provide cover');material.visible=true;
  material.transparent=true;material.opacity=.1;assert.equal(vehicleCoverContact(T,c,root,normal).gap,null,'transparent instance cannot provide cover');material.transparent=false;material.opacity=1;
  }
}
console.log(JSON.stringify({passed:true,cases,batchMembers,checks:['13_actual_cars','body_and_door_batches','open_closed_door','world_position_rotation_tilt','canonical_hidden_source_material','translated_rotated_instances','changed_instance_matrices_before_GPU_upload','genuine_material_visibility','opaque_surfaces']}));

if(baselineContact){
 const perf=[],quantiles=a=>{const b=a.toSorted((a,b)=>a-b);return {p50Ms:b[Math.floor(b.length*.5)],p95Ms:b[Math.floor(b.length*.95)]};};
 for(const {id,car,profile}of cars.filter(v=>['kingswell','city_bus'].includes(v.id))){
  car.object.position.set(0,0,0);car.object.rotation.set(0,.71,0);car.setDoorById(0,'front_left');
  const batches=createVehicleRenderBatches({THREE:T,root:car.object,includeBody:true,includeDoors:true});batches.update();car.object.updateMatrixWorld(true);
  const normal=new T.Vector3(1,0,0).applyAxisAngle(new T.Vector3(0,1,0),.71);pose(new T.Vector3(profile.halfWidth+.37,0,0).applyMatrix4(car.object.matrixWorld),normal);
  const values=[[],[]],functions=[baselineContact,vehicleCoverContact];
  for(let i=0;i<100;i++)for(const n of (i%2?[1,0]:[0,1])){const start=performance.now();const result=functions[n](T,c,car.object,normal);if(i>=30)values[n].push(performance.now()-start);assert.ok(result.gap!==null);}
  perf.push({id,warmup:30,samples:70,before:quantiles(values[0]),after:quantiles(values[1])});batches.dispose();
 }
 console.log(JSON.stringify({scope:'CPU contact query only, paired same actual batched car/hero state; no GPU/general-game FPS',perf}));
}
