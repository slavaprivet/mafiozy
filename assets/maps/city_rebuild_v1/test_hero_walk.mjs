import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {createHeroWalker,HERO_ASSET} from './hero_walk.mjs';
import {ARSENAL,createWeaponModel} from './hero_arsenal.mjs';
import {DRIVER_SEAT,createDemoCar} from './car_drive.mjs';
const here=path.dirname(fileURLToPath(import.meta.url)),deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,nextResolve){return nextResolve(specifier==='three'?pathToFileURL(path.join(deps,'build/three.module.js')).href:specifier,context);}});
const THREE=await import(pathToFileURL(path.join(deps,'build/three.module.js')));
const {GLTFLoader}=await import(pathToFileURL(path.join(deps,'addons/loaders/GLTFLoader.js')));
// Geometry-independent animation test; production uses the real RoundedBoxGeometry in-browser.
class TestBoxGeometry extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
const receipt=JSON.parse(fs.readFileSync(path.join(here,'hero_walk.manifest.json'),'utf8'));
const bytes=fs.readFileSync(path.join(here,'hero_models/player_male.8130dfb1f7eb.glb'));
assert.equal(bytes.length,HERO_ASSET.bytes);assert.equal(createHash('sha256').update(bytes).digest('hex'),HERO_ASSET.sha256);
assert.equal(receipt.sha256,HERO_ASSET.sha256);assert.equal(bytes.readUInt32LE(8),bytes.length);
const json=JSON.parse(bytes.subarray(20,20+bytes.readUInt32LE(12)).toString());assert.ok(json.skins.length>0);
const gltf=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
const source=gltf.scene,bones={};source.traverse(o=>{if(o.isBone)bones[o.name]=o;});
for(const side of ['l','r']){assert.ok(bones['shin_'+side].parent===bones['thigh_'+side]);assert.ok(bones['foot_'+side].parent===bones['shin_'+side]);}
const walker=createHeroWalker({THREE,scene:source});assert.equal(walker.height,1.9);
const before={};for(const[n,b]of Object.entries(bones))before[n]=b.matrix.toArray();
const restHeight=new THREE.Box3().setFromObject(walker.object).getSize(new THREE.Vector3()).y;
assert.ok(Math.abs(restHeight-1.9)<1e-5);
walker.object.position.set(20,0,30);walker.object.rotation.y=.7;
for(let i=0;i<25;i++)walker.update(1/60,true,false);
assert.notDeepEqual(bones.thigh_l.matrix.toArray(),before.thigh_l);
assert.notDeepEqual(bones.upperarm_r.matrix.toArray(),before.upperarm_r);
assert.deepEqual(walker.object.position.toArray(),[20,0,30]);assert.equal(walker.object.rotation.y,.7);
for(const[n,b]of Object.entries(bones)){const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3(),p0=new THREE.Vector3(),q0=new THREE.Quaternion(),s0=new THREE.Vector3();b.matrix.decompose(p,q,s);new THREE.Matrix4().fromArray(before[n]).decompose(p0,q0,s0);assert.ok(p.distanceTo(p0)<1e-6);assert.ok(s.distanceTo(s0)<1e-6);}
for(let i=0;i<180;i++)walker.update(1/60,false,false);
assert.equal(walker.diagnostics().gait,0);for(const[n,b]of Object.entries(bones))assert.deepEqual(b.matrix.toArray(),before[n]);
walker.update(.04,true,true);assert.ok(walker.diagnostics().gait>0);walker.reset();assert.equal(walker.diagnostics().gait,0);
walker.vehiclePose(1,.5);assert.notDeepEqual(bones.thigh_l.matrix.toArray(),before.thigh_l);assert.notDeepEqual(bones.forearm_l.matrix.toArray(),before.forearm_l);
assert.deepEqual(walker.object.position.toArray(),[20,0,30]);walker.reset();for(const[n,b]of Object.entries(bones))assert.deepEqual(b.matrix.toArray(),before[n]);
walker.vehiclePose(.55,.2,{phase:'inner_leg',innerLeg:.8,outerLeg:0,handReach:.7,duck:.6,side:1});assert.notDeepEqual(bones.thigh_r.matrix.toArray(),before.thigh_r,'inner leg enters first from the left door');assert(bones.thigh_l.matrix.toArray().every((value,index)=>Math.abs(value-before.thigh_l[index])<1e-12),'outer leg remains outside until its phase');assert.notDeepEqual(bones.upperarm_l.matrix.toArray(),before.upperarm_l,'door-side hand reaches the open door');walker.reset();
walker.vehiclePose(.7,.1,{phase:'exit',side:-1});assert.notDeepEqual(bones.thigh_l.matrix.toArray(),before.thigh_l);assert.notDeepEqual(bones.thigh_r.matrix.toArray(),before.thigh_r,'legacy exit without staged legs keeps a symmetric fold');walker.reset();
walker.object.position.set(DRIVER_SEAT.side,DRIVER_SEAT.y,DRIVER_SEAT.front);walker.object.rotation.y=0;walker.vehiclePose(1,0);walker.object.updateMatrixWorld(true);
const seatedBounds=new THREE.Box3(),vertex=new THREE.Vector3();walker.object.traverse(mesh=>{if(!mesh.isMesh)return;if(mesh.isSkinnedMesh)mesh.skeleton.update();const positions=mesh.geometry.attributes.position;for(let i=0;i<positions.count;i++){vertex.fromBufferAttribute(positions,i);if(mesh.isSkinnedMesh)mesh.applyBoneTransform(i,vertex);vertex.applyMatrix4(mesh.matrixWorld);seatedBounds.expandByPoint(vertex)}});
assert(seatedBounds.min.y>.4,'shoes must be above the car floor');assert(seatedBounds.max.y<2.08,`hat must fit below the roof: ${seatedBounds.max.y}`);assert(seatedBounds.min.x>-.65&&seatedBounds.max.x<1.05);assert(seatedBounds.min.z>-1.24&&seatedBounds.max.z<.75);
for(let i=0;i<12;i++)walker.vehiclePose(1,0,{driver:true,steer:.8,dt:.1});const headForward=new THREE.Vector3(0,0,1).applyQuaternion(bones.head.getWorldQuaternion(new THREE.Quaternion())).applyQuaternion(walker.object.getWorldQuaternion(new THREE.Quaternion()).invert()).normalize();assert(headForward.x>.12&&headForward.z>.85,'driver must look gently into the turn while retaining the road ahead');assert(Math.abs(headForward.y)<.2,'neutral seated spine must not make the driver stare at the floor');const driverArms=[...bones.upperarm_l.matrix.toArray(),...bones.forearm_l.matrix.toArray()];walker.reset();walker.vehiclePose(1,0,{driver:false,steer:1,dt:.1});assert.equal(walker.diagnostics().vehicleHeadYaw,0,'passenger does not track steering');assert.notDeepEqual([...bones.upperarm_l.matrix.toArray(),...bones.forearm_l.matrix.toArray()],driverArms,'passenger keeps hands on the lap rather than the wheel');walker.reset();
walker.vehiclePose(1,0,{driver:true});const wheelGrips={left:bones.socket_hand_r.getWorldPosition(new THREE.Vector3()).add(new THREE.Vector3(-.015,.012,.008)),right:bones.socket_hand_l.getWorldPosition(new THREE.Vector3()).add(new THREE.Vector3(.015,.012,.008))};walker.vehiclePose(1,0,{driver:true,steeringGrips:wheelGrips,steer:.4,dt:1/60});const wheelPalmL=bones.socket_hand_l.getWorldPosition(new THREE.Vector3()),wheelPalmR=bones.socket_hand_r.getWorldPosition(new THREE.Vector3()),directGripError=wheelPalmL.distanceTo(wheelGrips.left)+wheelPalmR.distanceTo(wheelGrips.right),crossGripError=wheelPalmL.distanceTo(wheelGrips.right)+wheelPalmR.distanceTo(wheelGrips.left);assert(Math.min(directGripError,crossGripError)<.02,'both driver palms must stay on rotating steering-rim grips');assert.notEqual(walker.diagnostics().vehicleGripAssignment,'driver-fallback');walker.reset();
const vehicle=createDemoCar(THREE,TestBoxGeometry);vehicle.update({steer:.3,distance:1,handbrake:false});assert(vehicle.wheels.every(w=>w.wheel.rotation.x>0));assert(vehicle.wheels.filter(w=>w.front).every(w=>w.pivot.rotation.y===.3));assert(vehicle.wheels.filter(w=>!w.front).every(w=>w.pivot.rotation.y===0));const rear=vehicle.wheels.find(w=>!w.front),beforeBrake=rear.wheel.rotation.x;vehicle.update({steer:-.2,distance:1,handbrake:true});assert.equal(rear.wheel.rotation.x,beforeBrake,'rear wheels lock on handbrake');
vehicle.setDoor(1,1);vehicle.setDoor(1,-1);vehicle.setDoor(0);
for(const p of [0,.1,.25,.4,.55,.7,.85,1]){
 walker.object.position.set(4,0,6);walker.object.rotation.y=.4;walker.tumblePose(p,2);walker.object.updateMatrixWorld(true);const bounds=new THREE.Box3();
 walker.object.traverse(mesh=>{if(!mesh.isMesh)return;if(mesh.isSkinnedMesh)mesh.skeleton.update();const positions=mesh.geometry.attributes.position;for(let i=0;i<positions.count;i++){vertex.fromBufferAttribute(positions,i);if(mesh.isSkinnedMesh)mesh.applyBoneTransform(i,vertex);vertex.applyMatrix4(mesh.matrixWorld);bounds.expandByPoint(vertex)}});
 assert(bounds.min.y>=-1e-5&&bounds.min.y<.001,'actual tumbling skin stays on/above ground');assert.deepEqual(walker.object.position.toArray(),[4,0,6]);
}
walker.reset();for(const[n,b]of Object.entries(bones))assert.deepEqual(b.matrix.toArray(),before[n],'roll must restore authored rest pose');
const localBounds=()=>{const bounds=new THREE.Box3(),inverse=new THREE.Matrix4().copy(walker.object.matrixWorld).invert();walker.object.traverse(mesh=>{if(!mesh.isMesh)return;if(mesh.isSkinnedMesh)mesh.skeleton.update();const positions=mesh.geometry.attributes.position;for(let i=0;i<positions.count;i++){vertex.fromBufferAttribute(positions,i);if(mesh.isSkinnedMesh)mesh.applyBoneTransform(i,vertex);vertex.applyMatrix4(mesh.matrixWorld).applyMatrix4(inverse);bounds.expandByPoint(vertex)}});return bounds};
const standingSize=localBounds().getSize(new THREE.Vector3());
for(const directional of [false,true]){
 for(const p of [0,.07,.14,.32,.5,.64,.72,.85,.99,1]){
  walker.object.position.set(4,.85,6);walker.object.rotation.y=-1.2;walker.jumpPose(p,directional);
  const bounds=localBounds();assert(Math.abs(bounds.min.y)<1e-5,'jump skin bottom must follow ballistic root without ground penetration');
  assert.deepEqual(walker.object.position.toArray(),[4,.85,6]);assert.equal(walker.object.rotation.y,-1.2,'jump pose cannot redirect physics');
  if(p===.32){
   const size=bounds.getSize(new THREE.Vector3());assert(size.y<standingSize.y,'flight must visibly tuck or dive');
   if(directional){
    assert(size.z>standingSize.z*1.5,'directional dive must extend along travel');
    walker.object.updateMatrixWorld(true);const origin=bones.head.getWorldPosition(new THREE.Vector3()),tip=new THREE.Vector3(0,0,1).applyQuaternion(bones.head.getWorldQuaternion(new THREE.Quaternion())).add(origin);
    walker.object.worldToLocal(origin);walker.object.worldToLocal(tip);const gaze=tip.sub(origin).normalize();assert(gaze.z>.9&&Math.abs(gaze.y)<.2,'face must look along the horizontal dive direction');
   }
  }
 }
 for(const[n,b]of Object.entries(bones))assert.deepEqual(b.matrix.toArray(),before[n],'jump landing must restore rest pose');
 assert(Math.abs(localBounds().getSize(new THREE.Vector3()).y-standingSize.y)<1e-5);
 walker.jumpPose(.4,directional);walker.reset();for(const[n,b]of Object.entries(bones))assert.deepEqual(b.matrix.toArray(),before[n],'jump reset must restore every bone');
}
const propA=new THREE.Group(),propB=new THREE.Group();walker.mountWeapon(propA);assert.equal(propA.parent,bones.socket_weapon);walker.mountWeapon(propB);assert.equal(propA.parent,null);assert.equal(propB.parent,bones.socket_weapon);
walker.update(.04,false,false,{twoHanded:true});assert.notDeepEqual(bones.upperarm_l.matrix.toArray(),before.upperarm_l);assert.notDeepEqual(bones.upperarm_r.matrix.toArray(),before.upperarm_r);walker.mountWeapon(null);walker.reset();
const held=createWeaponModel({THREE,id:'m16'});walker.mountWeapon(held);walker.update(.04,false,false,{twoHanded:true});walker.object.updateMatrixWorld(true);
const grip=new THREE.Vector3().applyMatrix4(held.matrixWorld),muzzle=new THREE.Vector3(...held.userData.muzzle).applyMatrix4(held.matrixWorld);walker.object.worldToLocal(grip);walker.object.worldToLocal(muzzle);const barrel=muzzle.sub(grip);
const rootQ=walker.object.getWorldQuaternion(new THREE.Quaternion()),socketQ=bones.socket_weapon.getWorldQuaternion(new THREE.Quaternion()),relativeQ=rootQ.clone().invert().multiply(socketQ),desiredSocketAxis=new THREE.Vector3(0,0,1).applyQuaternion(relativeQ.clone().invert());
assert(barrel.z>.2,`mounted barrel must point along the hero forward direction: barrel=${JSON.stringify(barrel.toArray())}, desiredSocketAxis=${JSON.stringify(desiredSocketAxis.toArray())}`);assert(grip.y>.5&&grip.y<2.2,`weapon socket must remain near the hands: ${JSON.stringify(grip.toArray())}`);
const foregrip=new THREE.Vector3(...held.userData.supportGrip).applyMatrix4(held.matrixWorld),leftPalm=bones.socket_hand_l.getWorldPosition(new THREE.Vector3());walker.object.worldToLocal(foregrip);walker.object.worldToLocal(leftPalm);assert(leftPalm.distanceTo(foregrip)<.01,`support hand must reach the foregrip: palm=${JSON.stringify(leftPalm.toArray())}, foregrip=${JSON.stringify(foregrip.toArray())}`);walker.mountWeapon(null);walker.reset();
// Exercise every model against the real GLB, including root heading, movement,
// aim and recoil. A forward muzzle alone misses a grip crossing the torso.
for(const spec of ARSENAL.filter(spec=>spec.id!=='none')){
 const weapon=createWeaponModel({THREE,id:spec.id});walker.mountWeapon(weapon);
 for(const aimPitch of [-1.25,-.65,0,.65,1.25])for(const recoil of [0,1]){
  walker.object.rotation.y=1.3;walker.update(.04,true,true,spec,{aimPitch,recoil});
  const rightPalm=bones.socket_hand_r.getWorldPosition(new THREE.Vector3());
  const primaryGrip=new THREE.Vector3(0,-.13,-.02).applyMatrix4(weapon.matrixWorld);
  assert(rightPalm.distanceTo(primaryGrip)<.01,`${spec.id}: primary grip must stay in the right palm at aim ${aimPitch}`);
  const direction=new THREE.Vector3(0,0,1).transformDirection(weapon.matrixWorld).applyQuaternion(walker.object.getWorldQuaternion(new THREE.Quaternion()).invert());
  assert(Math.abs(direction.x)<1e-5&&direction.z>.1,`${spec.id}: barrel must keep its positive forward component at every aim/recoil`);
  assert(Math.abs(Math.atan2(direction.y,direction.z)-(aimPitch+recoil*(spec.twoHanded?.13:.105)))<1e-5,`${spec.id}: barrel pitch must match aim and recoil`);
  const palmLocal=walker.object.worldToLocal(rightPalm.clone());assert(palmLocal.x>0,`${spec.id}: right hand must remain on the right side of the torso`);
  const pad=weapon.getObjectByName('stock_pad');
  if(pad){
   const positions=pad.geometry.attributes.position;
   for(let i=0;i<positions.count;i++){
    const corner=walker.object.worldToLocal(new THREE.Vector3().fromBufferAttribute(positions,i).applyMatrix4(pad.matrixWorld));
     const backLimit=.015;
     assert(corner.z>backLimit,`${spec.id}: shoulder pad must not protrude through the back at aim ${aimPitch}, z=${corner.z}`);
   }
  }
  const rearNames=['stock','stock_pad','folding_stock','launcher_tube','rear_cone','shoulder_pad'];
  const rearPoints=[];for(const name of rearNames){const part=weapon.getObjectByName(name);if(!part?.geometry?.attributes?.position)continue;const positions=part.geometry.attributes.position;for(let i=0;i<positions.count;i++)rearPoints.push(walker.object.worldToLocal(new THREE.Vector3().fromBufferAttribute(positions,i).applyMatrix4(part.matrixWorld)))}
  if(rearPoints.length){const insideBand=rearPoints.filter(point=>Math.abs(point.x)<.28&&point.y>.72&&point.y<1.56);const minZ=insideBand.length?Math.min(...insideBand.map(point=>point.z)):Infinity;assert(minZ>.015,`${spec.id}: rear assembly must remain ahead of the torso/back band at aim ${aimPitch}, recoil ${recoil}, z=${minZ}`)}
  if(spec.twoHanded){
   const point=weapon.userData.supportGrip;
   const support=new THREE.Vector3(...point).applyMatrix4(weapon.matrixWorld);
   assert(bones.socket_hand_l.getWorldPosition(new THREE.Vector3()).distanceTo(support)<.01,`${spec.id}: support palm must stay on the foregrip`);
  }
 }
 walker.reset();walker.update(0,false,false,spec);
 if(!spec.twoHanded){assert.deepEqual(bones.upperarm_l.matrix.toArray(),before.upperarm_l,'one-handed weapons leave the left arm relaxed');assert.deepEqual(bones.forearm_l.matrix.toArray(),before.forearm_l);}
 for(const[n,b]of Object.entries(bones)){
  const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3(),p0=new THREE.Vector3(),q0=new THREE.Quaternion(),s0=new THREE.Vector3();
  b.matrix.decompose(p,q,s);new THREE.Matrix4().fromArray(before[n]).decompose(p0,q0,s0);assert(p.distanceTo(p0)<1e-6&&s.distanceTo(s0)<1e-6,'weapon IK cannot stretch or translate bones');
 }
 walker.mountWeapon(null);walker.reset();
}
walker.dispose();walker.dispose();assert.equal(walker.diagnostics().disposed,true);
console.log(JSON.stringify({passed:true,checks:['source_release_hash','actual_glb_bytes','rest_hierarchy','actual_height_1.9m','moving_legs_and_arms','no_bone_scale_or_translation_change','idle_exact_recovery','controller_position_preserved','vehicle_staged_legs','vehicle_floor_seat_roof_fit','driver_road_gaze','steering_rim_world_ik','passenger_lap_pose','jump_and_dive_skinned_grounding','directional_dive_silhouette','forward_jump_gaze','jump_landing_rest_recovery','weapon_socket_and_grip','mounted_weapon_forward_axis','vertical_aim','recoil_body_chain','all_14_idle_aim_recoil','all_rear_assemblies_back_clearance','run_reset_dispose'],sourceHeight:walker.sourceHeight,uniformScale:walker.scale,metres:walker.height,bones:Object.keys(bones).length}));
