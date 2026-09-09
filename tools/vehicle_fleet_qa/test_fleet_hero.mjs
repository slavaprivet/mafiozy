// Real skinned GLB seat QA adapted from the architect's 2026-09-09 test_fleet_hero.
// Executes shared production factory and hero pose code; does not modify source assets.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
const game=new URL('../../assets/maps/city_rebuild_v1/',import.meta.url);
const vendor=process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import('./RoundedBoxGeometry.mjs');
const {ARTIST_VEHICLE_PROFILES,createArtistVehicle}=await import(new URL('vehicle_fleet_models.mjs',game));
const {createHeroWalker}=await import(new URL('hero_walk.mjs',game));
const hash=file=>createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const parse=async file=>{const b=fs.readFileSync(file);return(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene};
const heroFile=new URL('hero_models/player_male.8130dfb1f7eb.glb',game),heroHash=hash(heroFile);
const heroSource=await parse(heroFile),hero=createHeroWalker({THREE:T,scene:heroSource,targetHeight:1.9});
const bones={},sample=new T.Vector3(),scales=new Map(),matrixScales=new Map();
hero.object.traverse(n=>{scales.set(n,n.scale.clone());const scale=new T.Vector3();n.matrix.decompose(new T.Vector3(),new T.Quaternion(),scale);matrixScales.set(n,scale);if(n.isBone)bones[n.name]=n});
const lengths=new Map();hero.object.updateMatrixWorld(true);
for(const bone of Object.values(bones))if(bone.parent?.isBone)lengths.set(bone,bone.getWorldPosition(new T.Vector3()).distanceTo(bone.parent.getWorldPosition(new T.Vector3())));
function invariantRig(label){
 for(const [node,scale]of scales)assert(node.scale.distanceTo(scale)<1e-9,`${label}: node scale changed ${node.name}`);
 for(const [node,scale]of matrixScales){const actual=new T.Vector3();node.matrix.decompose(new T.Vector3(),new T.Quaternion(),actual);assert(actual.distanceTo(scale)<1e-5,`${label}: matrix scale changed ${node.name}`)}
 for(const [bone,length]of lengths)assert(Math.abs(bone.getWorldPosition(new T.Vector3()).distanceTo(bone.parent.getWorldPosition(new T.Vector3()))-length)<1e-5,`${label}: bone length changed ${bone.name}`);
}
function bounds(){
 const box=new T.Box3();hero.object.updateMatrixWorld(true);
 hero.object.traverse(mesh=>{if(!mesh.isMesh)return;if(mesh.isSkinnedMesh)mesh.skeleton.update();const pos=mesh.geometry.attributes.position;
  for(let i=0;i<pos.count;i++){sample.fromBufferAttribute(pos,i);if(mesh.isSkinnedMesh)mesh.applyBoneTransform(i,sample);sample.applyMatrix4(mesh.matrixWorld);box.expandByPoint(sample)}
 });return box;
}
const failures=[],results=[];
function check(label,fn){try{fn()}catch(error){failures.push({label,message:error.message});console.error('FAIL '+label+': '+error.message)}}
function place(car,seat){hero.reset();hero.object.position.set(seat.anchor.side,seat.anchor.y,seat.anchor.front);hero.object.rotation.set(0,0,0);car.object.updateMatrixWorld(true)}
for(const profile of ARTIST_VEHICLE_PROFILES){
 const car=createArtistVehicle(T,RoundedBoxGeometry,await parse(new URL('models/artist_vehicle_pack/'+profile.modelFile,game)),profile);
 const roofMeshes=[];car.object.traverse(mesh=>{if(mesh.isMesh&&(mesh.userData.vehicleRoof||/_(Cab|Cabin|PassengerBody)$/.test(mesh.name)))roofMeshes.push(mesh)});
 const row={id:profile.id,seats:[],steering:[]};results.push(row);
 for(const seat of car.seats){
  const label=profile.id+'/'+seat.id;place(car,seat);car.poseOccupant(hero,seat.id);const occupied=bounds(),voidBox=car.diagnostics().interiorVoid;
  const result={id:seat.id,anchor:seat.anchor,floorClearance:occupied.min.y-car.anchors.floorTop,roofClearance:car.anchors.roofBottom-occupied.max.y,bounds:{min:occupied.min.toArray(),max:occupied.max.toArray()},roofSamples:0,roofMisses:0};row.seats.push(result);
  check(label,()=>{
   assert(result.floorClearance>=.012,'feet above floor');assert(result.roofClearance>=.015,'head under roof');
   assert(occupied.min.z>=voidBox.min[2]-.01,'occupant behind cabin');assert(occupied.max.z<=voidBox.max[2]+.01,'occupant ahead of cabin');
   assert(occupied.min.x>=voidBox.min[0]-.01&&occupied.max.x<=voidBox.max[0]+.01,'arms within cabin sides');
  });
  check(label+' unchanged rig',()=>invariantRig(label));
  hero.object.traverse(mesh=>{if(!mesh.isMesh||!mesh.name.includes('headwear'))return;const pos=mesh.geometry.attributes.position;
   for(let j=0;j<pos.count;j+=9){sample.fromBufferAttribute(pos,j);if(mesh.isSkinnedMesh)mesh.applyBoneTransform(j,sample);sample.applyMatrix4(mesh.matrixWorld);
    const ray=new T.Raycaster(sample.clone().add(new T.Vector3(0,1.5,0)),new T.Vector3(0,-1,0),0,1.5);result.roofSamples++;if(!ray.intersectObjects(roofMeshes).length)result.roofMisses++;
   }
  });
  check(label+' actual roof',()=>{assert(result.roofSamples>0,'real headwear vertices sampled');assert.equal(result.roofMisses,0,'roof covers headwear')});
  console.log(JSON.stringify({type:'seat',vehicle:profile.id,...result}));
 }
 const driver=car.seats.find(seat=>seat.canDrive),passenger=car.seats.find(seat=>seat.id==='front_right');place(car,driver);
 check(profile.id+' steering location',()=>{
  const wheel=car.interior.steeringWheel.getWorldPosition(new T.Vector3());row.wheel=wheel.toArray();
  assert(driver.id==='front_left');assert(driver.anchor.side>0&&passenger.anchor.side<0,'+X is left when vehicle faces +Z');
  assert(Math.abs(wheel.x-driver.anchor.side)<.02,'steering wheel aligned with left driver');assert(wheel.z>driver.anchor.front,'steering wheel ahead of driver');
 });
 check(profile.id+' transition rig',()=>{
  for(let step=0;step<=20;step++){const fold=step/20;car.poseOccupant(hero,driver.id,{fold,reach:Math.sin(fold*Math.PI)*.3,reclineBlend:fold,pose:{innerLeg:fold,outerLeg:fold,duck:.2*(1-fold)}});hero.object.updateMatrixWorld(true);invariantRig(profile.id+' fold '+fold)}
 });
 for(const steer of [-.56,0,.56]){
  place(car,driver);car.update({steer,distance:0});for(let i=0;i<15;i++)car.poseOccupant(hero,driver.id,{steer,dt:1/60});
  const left=bones.socket_hand_l.getWorldPosition(new T.Vector3()),right=bones.socket_hand_r.getWorldPosition(new T.Vector3()),grips=car.getSteeringGrips();
  const palmError=Math.min(left.distanceTo(grips.left)+right.distanceTo(grips.right),left.distanceTo(grips.right)+right.distanceTo(grips.left)),driving=bounds();
  row.steering.push({steer,palmError});check(profile.id+' steer '+steer,()=>{assert(palmError<(steer===0?.018:.035),'palms on actual rotating rim: '+palmError);assert(driving.min.y>=car.anchors.floorTop+.012,'driving feet above floor');assert(driving.max.y<=car.anchors.roofBottom-.01,'driving head below roof');invariantRig(profile.id+' steer '+steer)});
 }
 console.log(JSON.stringify({type:'steering',vehicle:profile.id,wheel:row.wheel,checks:row.steering}));
}
check('source hero unchanged',()=>assert.equal(hash(heroFile),heroHash));
const seatCount=results.reduce((sum,row)=>sum+row.seats.length,0);
check('complete authored fleet',()=>{assert.equal(results.length,12);assert.equal(seatCount,36)});
const report={status:failures.length?'FAIL':'PASS',models:results.length,seats:seatCount,sourceHero:'player_male.8130dfb1f7eb.glb',sourceSha256:heroHash,targetHeight:1.9,geometry:'actual RoundedBoxGeometry',factorySha256:hash(new URL('vehicle_fleet_models.mjs',game)),bodySha256:hash(new URL('vehicle_fleet_body.mjs',game)),failures,results};
const output=new URL('../../outputs/vehicle_fleet_continuation/',import.meta.url);fs.mkdirSync(output,{recursive:true});fs.writeFileSync(new URL('seat_qa.json',output),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({status:report.status,models:report.models,seats:seatCount,failures,sourceSha256:heroHash,factorySha256:report.factorySha256,bodySha256:report.bodySha256}));
process.exitCode=failures.length?1:0;
