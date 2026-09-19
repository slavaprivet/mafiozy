import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {performance} from 'node:perf_hooks';
import {createIndoorCamera} from './indoor_camera.mjs';
import {createIndoorCamera as createPreviousIndoorCamera} from '../../../outputs/indoor_camera_20260912/indoor_camera.before.mjs';
const root='C:/Users/Слава/Desktop/Мафиози/';
const base=pathToFileURL(root+'assets/maps/city_rebuild_v1/');
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){
 if(s==='three')return next(pathToFileURL(vendor+'build/three.module.js').href,c);
 if(c.parentURL?.includes('/.perf-camera/')&&['./building_entry_profiles.mjs','./building_room_profiles.mjs','./building_floor_surface.mjs'].includes(s))return next(new URL(s,base).href,c);
 return next(s,c);
}});
const T=await import(pathToFileURL(vendor+'build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const {createBuildingEntry,resolveBuildingCameraPosition:solve}=await import('./building_entry.mjs');
const before=solve;
const placements=JSON.parse(fs.readFileSync(new URL('buildings_placement.v1.json',base)));
const results=[],performanceCases=[],entries=[];
for(const id of ['strip_club','old_town_narrow_townhouse_v1','eastside_garden_walkup_v1','eastside_stepped_apartment_v1','coastal_orchard_house_v1','garden_lane_house_v1','hillstep_chalet_v1','pine_ridge_cottage_v1','veranda_bungalow_v1','woodland_crosswing_house_v1']){
 const item=placements.instances.find(i=>i.assetId===id),buf=fs.readFileSync(root+item.binding.url.slice(1));
 const visual=(await new GLTFLoader().parseAsync(buf.buffer.slice(buf.byteOffset,buf.byteOffset+buf.byteLength),'')).scene;
 const group=new T.Group(),t=item.transform;visual.position.fromArray(t.modelLocalOffsetM);group.position.fromArray(t.positionM);group.rotation.y=t.yawDegrees*Math.PI/180;group.scale.setScalar(t.uniformScale);group.add(visual);group.updateMatrixWorld(true);
 const entry=createBuildingEntry({THREE:T,visual,instance:item});entries.push(entry);group.updateMatrixWorld(true);
 const point=entry.roomCenterPoint?.()||entry.roomPoint(),from=point.clone();from.y=entry.floorHeight(point.x,point.z)+1.1;
 const ceilingY=entry.ceilingHeight(point),rows=[];
 for(let angle=0;angle<Math.PI*2;angle+=Math.PI/4){
  const desired=from.clone().add(new T.Vector3(Math.sin(angle)*7,6,Math.cos(angle)*7));
  const args={THREE:T,from,desired,objects:[visual]},a=before(args),b=solve({...args,ceilingY});
  assert.deepEqual(solve(args).toArray(),a.toArray(),'ordinary/aim path unchanged');
  assert(b.y<=ceilingY-.28+.001,'below ceiling');
  // Resolving the final segment again must find no intervening walls.
  assert(solve({...args,desired:b}).distanceTo(b)<1e-6,'final segment unobstructed');
  assert(b.distanceTo(from)+.001>=a.distanceTo(from),'no stronger indoor zoom');
  const feet=point.clone();feet.y=entry.floorHeight(point.x,point.z);
  const indoor=createIndoorCamera({THREE:T,resolvePosition:solve}),indoorArgs={feet,eyeHeight:1.1,desired,target:from,objects:[visual],ceilingY,inside:true,dt:1/60};
  const view=indoor.solve(indoorArgs);
  assert.notEqual(view.mode,'eye','a compressed real room never teleports into first person');
  assert(view.position.y<=ceilingY-.28+.001,'third-person position remains below actual room ceiling');
  assert(solve({...args,desired:view.position}).distanceTo(view.position)<1e-6,'new third-person segment keeps the existing camera volume clear');
  if(view.separation>=2.05)assert.equal(view.hideHead,false,'usable shoulder clearance keeps the rig visible');
  const aim=indoor.solve({...indoorArgs,aiming:true});
  assert(aim.target.clone().sub(aim.position).distanceTo(from.clone().sub(desired))<1e-8,'actual room aim direction is preserved exactly');
  const exterior=indoor.solve({...indoorArgs,inside:false});
  assert(exterior.position.distanceTo(b)<1e-8,'outside path remains the legacy result');
  performanceCases.push({indoor,previous:createPreviousIndoorCamera({THREE:T,resolvePosition:solve}),indoorArgs,args:{...args,ceilingY}});
  rows.push({before:a.distanceTo(from),after:b.distanceTo(from)});
 }
 results.push({id,ceilingY,rows});
}

console.log('PASS 80 actual GLB room directions: continuous third-person collision boom, clear volume, ceiling clearance, exact aim and unchanged outside path');

// Analytic room walls exercise camera volume clearance while the player
// rotates beside a corner. This is physical geometry, not a canned resolver.
const walls=new T.Group(),geometry=[],material=new T.MeshBasicMaterial({side:T.DoubleSide});
for(const [position,size]of[[[-2.6,1.35,0],[.2,2.7,6.4]],[[2.6,1.35,0],[.2,2.7,6.4]],[[0,1.35,-3.1],[5.4,2.7,.2]],[[0,1.35,3.1],[5.4,2.7,.2]],[[0,2.8,0],[5.4,.2,6.4]]]){
 const g=new T.BoxGeometry(...size),mesh=new T.Mesh(g,material);geometry.push(g);mesh.position.fromArray(position);walls.add(mesh);
}
walls.updateMatrixWorld(true);
const camera=createIndoorCamera({THREE:T,resolvePosition:solve}),feet=new T.Vector3(1.96,0,2.46),target=feet.clone().add(new T.Vector3(0,1.64,0)),origin=feet.clone().add(new T.Vector3(0,1.45,0));
let previous=null,largestRotationStep=0,largestRecoveryStep=0;
for(let frame=0;frame<360;frame++){
 const angle=frame*Math.PI/180,desired=target.clone().add(new T.Vector3(Math.sin(angle)*5,2,Math.cos(angle)*5));
 const view=camera.solve({feet,target,desired,objects:[walls],ceilingY:2.7,inside:true,dt:1/60});
 assert(Math.abs(view.position.x)<=2.5-.12+1e-6&&Math.abs(view.position.z)<=3-.12+1e-6,'camera volume remains in front of both corner walls');
 assert(view.position.y<=2.7-.16+1e-6,'camera volume remains below low ceiling');
 assert(solve({THREE:T,from:origin,desired:view.position,objects:[walls]}).distanceTo(view.position)<1e-6,'recovery interpolation never cuts across a wall');
 if(previous){const step=view.position.distanceTo(previous.position);largestRotationStep=Math.max(largestRotationStep,step);if(view.resolvedDistance>=previous.resolvedDistance)largestRecoveryStep=Math.max(largestRecoveryStep,step);else if(step>.3)assert(Math.abs(view.resolvedDistance-view.availableLength)<1e-6,'a large inward step must be forced by actual wall collision, never by view mode')}
 previous=view;
}
assert(largestRecoveryStep<.3,'slow wall rotation has no outward recovery jump');
console.log('PASS 360 corner rotations in a 5 by 6m room: no clipping, max recovery step '+largestRecoveryStep.toFixed(4)+'m; mandatory wall retraction max '+largestRotationStep.toFixed(4)+'m');
for(const g of geometry)g.dispose();material.dispose();

// Comparable CPU scene work only: same ten loaded GLBs, camera requests,
// warm-up and sample count. No FPS or GPU performance claim is made here.
const legacyCall=record=>record.previous.solve(record.indoorArgs);
const currentCall=record=>record.indoor.solve(record.indoorArgs);
for(let pass=0;pass<2;pass++)for(const record of performanceCases){legacyCall(record);currentCall(record)}
const timings={before:[],after:[]};
for(let pass=0;pass<5;pass++)for(const record of performanceCases){
 const calls=pass%2?[['after',currentCall],['before',legacyCall]]:[['before',legacyCall],['after',currentCall]];
 for(const [key,call]of calls){const start=performance.now();call(record);timings[key].push(performance.now()-start)}
}
const summary=samples=>{samples.sort((a,b)=>a-b);return{samples:samples.length,p50Ms:+samples[Math.floor(samples.length*.5)].toFixed(4),p95Ms:+samples[Math.floor(samples.length*.95)].toFixed(4)}};
console.log(JSON.stringify({cameraUpdateCpu:{before:summary(timings.before),after:summary(timings.after)},scene:'same 10 actual GLBs / 80 camera requests',scope:'CPU only; loaded-game GPU/frame-time performance not measured'}));
for(const entry of entries)entry.dispose();
