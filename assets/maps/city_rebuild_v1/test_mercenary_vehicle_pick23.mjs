import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createNpcTrafficVehicleBinding} from './npc_vehicle_pose.mjs';
import {setVehicleWindowOpen} from './vehicle_window_fire.mjs';
import {createMercenaryTargets} from './mercenary_targets.mjs';
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(vendor+'/build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const load=async url=>{const bytes=fs.readFileSync(url);return(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;};
class Box extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d);}}
const scene=new THREE.Scene(),car=createArtistVehicle(THREE,Box,await load(new URL('./models/artist_vehicle_pack/compact_sedan.glb',import.meta.url)),'compact_sedan');scene.add(car.object);
const binding=createNpcTrafficVehicleBinding({THREE,actor:car}),npc=createNpcActor({THREE,scene,source:await load(new URL(NPC_ASSETS.male.url)),cloneSkeleton:clone,id:'npc_pick_enemy',sex:'male'});
const camera=new THREE.PerspectiveCamera(55,1.5,.1,100),roots=[car.object,npc.object],targets=createMercenaryTargets({THREE,camera,getRoots:()=>roots,getPickRoots:()=>roots,getFleet:()=>({records:[{id:'audit',car}]}),getNpcs:()=>[{id:npc.id,object:npc.object}]}),rows=[];
for(const side of [-1,1])for(const open of [false,true]){
 for(const seat of car.seats)if(seat.side===side)setVehicleWindowOpen(car,seat.id,open);
 npc.update(0,{time:1,position:{x:side*8,y:0,z:0},yaw:0,life:{}});const aim=npc.walker.artistContext().worldPosition('chest');
 const driver=binding.getSeatRootWorld('front_left').clone();
 for(const [label,position] of [['cabin-driver',driver.clone().add(new THREE.Vector3(0,1.2,0))],['chase-behind',new THREE.Vector3(0,3,-6)],['outside-same-side',new THREE.Vector3(side*4,2,-3)]]){
  camera.position.copy(position);camera.lookAt(aim);camera.updateMatrixWorld(true);const hit=targets.pick();
  rows.push({side,open,camera:label,pick:hit?.id??null,kind:hit?.kind??null,centerLos:targets.hasLineOfSight({x:0,y:0,z:0},{x:side*8,y:0,z:0},npc.id),driverLos:targets.hasLineOfSight(driver,{x:side*8,y:0,z:0},npc.id)});
 }
 for(const seat of car.seats)setVehicleWindowOpen(car,seat.id,false);
}
assert(rows.some(r=>r.pick==='fleet:audit'),'actual car wins some camera aim rays');
assert(rows.some(r=>r.kind==='npc'&&!r.centerLos),'valid target picking can still fail actual hero-origin LOS');

let ignoredRoot=car.object;
const candidate=createMercenaryTargets({THREE,camera,getRoots:()=>roots,getPickRoots:()=>roots,getCommandIgnoredRoot:()=>ignoredRoot,getFleet:()=>({records:[{id:'audit',car}]}),getNpcs:()=>[{id:npc.id,object:npc.object}]});
let positives=0;
for(const side of [-1,1])for(const open of [false,true]){
 for(const seat of car.seats)if(seat.side===side)setVehicleWindowOpen(car,seat.id,open);
 npc.update(0,{time:1,position:{x:side*8,y:0,z:0},yaw:0,life:{}});const aim=npc.walker.artistContext().worldPosition('chest');
 const driver=binding.getSeatRootWorld('front_left').clone();
 for(const position of [driver.clone().add(new THREE.Vector3(0,1.2,0)),new THREE.Vector3(0,3,-6),new THREE.Vector3(side*4,2,-3)]){
  camera.position.copy(position);camera.lookAt(aim);camera.updateMatrixWorld(true);
  assert.equal(candidate.pick()?.kind,'npc');assert.equal(candidate.hasLineOfSight({x:0,y:0,z:0},{x:side*8,y:0,z:0},npc.id),true);assert.equal(candidate.hasLineOfSight(driver,{x:side*8,y:0,z:0},npc.id),true);positives++;
 }
 for(const seat of car.seats)setVehicleWindowOpen(car,seat.id,false);
}
const driver=binding.getSeatRootWorld('front_left').clone(),to={x:8,y:0,z:0};camera.position.copy(driver).add(new THREE.Vector3(0,1.2,0));camera.lookAt(npc.walker.artistContext().worldPosition('chest'));camera.updateMatrixWorld(true);
ignoredRoot=null;assert.equal(candidate.pick()?.id,'fleet:audit');assert.equal(candidate.hasLineOfSight(driver,to,npc.id),false);ignoredRoot=car.object;
const wall=new THREE.Mesh(new THREE.BoxGeometry(.3,5,5),new THREE.MeshBasicMaterial());wall.position.set(4,1,0);scene.add(wall);roots.push(wall);scene.updateMatrixWorld(true);assert.equal(candidate.hasLineOfSight(driver,to,npc.id),false,'wall still blocks');assert.notEqual(candidate.pick()?.kind,'npc');roots.pop();scene.remove(wall);
const other=createArtistVehicle(THREE,Box,await load(new URL('./models/artist_vehicle_pack/compact_sedan.glb',import.meta.url)),'compact_sedan');other.object.position.set(4,0,0);scene.add(other.object);roots.push(other.object);scene.updateMatrixWorld(true);assert.equal(candidate.hasLineOfSight(driver,to,npc.id),false,'other car still blocks');assert.notEqual(candidate.pick()?.kind,'npc');roots.pop();scene.remove(other.object);
const friend=createNpcActor({THREE,scene,source:await load(new URL(NPC_ASSETS.male.url)),cloneSkeleton:clone,id:'npc_friend',sex:'male'});friend.update(0,{time:1,position:{x:(driver.x+to.x)/2,y:0,z:(driver.z+to.z)/2},yaw:0,life:{}});roots.push(friend.object);scene.updateMatrixWorld(true);assert.equal(candidate.hasLineOfSight(driver,to,npc.id),false,'friendly actual skin still blocks');assert.notEqual(candidate.pick()?.id,'npc:npc_pick_enemy');
assert.equal(candidate.get('fleet:audit')?.kind,'vehicle','own vehicle remains a resolvable effect target');
roots.pop();scene.remove(friend.object);let assisted=false;
for(const z of [.45,.55,.65]){camera.lookAt(new THREE.Vector3(8,1,z));camera.updateMatrixWorld(true);const hit=candidate.pick();if(hit?.id==='npc:npc_pick_enemy'&&hit.assisted)assisted=true;}
assert(assisted,'assisted target LOS also ignores only the own car');
const ground=new THREE.Mesh(new THREE.PlaneGeometry(40,40),new THREE.MeshBasicMaterial());ground.rotation.x=-Math.PI/2;ground.position.y=-.1;scene.add(ground);roots.push(ground);scene.updateMatrixWorld(true);camera.position.set(0,5,0);camera.lookAt(0,0,0);camera.updateMatrixWorld(true);assert.equal(candidate.pickGround(),null,'own car still blocks ground rally picking');
console.log(JSON.stringify({status:'PASS',positives,negativeCases:['callback null keeps baseline owncar blocker','wall blocks','other car blocks','friend skin blocks','get/effect registry keeps owncar'],limits:'Actual models and production picker; LIVE remains separate.'}));targets.dispose();candidate.dispose();npc.dispose();friend.dispose();
