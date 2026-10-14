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
// Candidate scope only: an onboard command selects past its own car root.
// The physical fire factory keeps its original obstacles and is not modified.
const candidate=createMercenaryTargets({THREE,camera,getRoots:()=>roots,getPickRoots:()=>roots.filter(root=>root!==car.object),getFleet:()=>({records:[{id:'audit',car}]}),getNpcs:()=>[{id:npc.id,object:npc.object}]});
const driver=binding.getSeatRootWorld('front_left').clone(),to={x:8,y:0,z:0};camera.position.copy(driver).add(new THREE.Vector3(0,1.2,0));camera.lookAt(npc.walker.artistContext().worldPosition('chest'));camera.updateMatrixWorld(true);
assert.equal(candidate.pick()?.kind,'npc');assert.equal(candidate.hasLineOfSight(driver,to,npc.id),true);
const wall=new THREE.Mesh(new THREE.BoxGeometry(.3,5,5),new THREE.MeshBasicMaterial());wall.position.set(4,1,0);scene.add(wall);roots.push(wall);assert.equal(candidate.hasLineOfSight(driver,to,npc.id),false);assert.notEqual(candidate.pick()?.kind,'npc');roots.pop();scene.remove(wall);
const other=createArtistVehicle(THREE,Box,await load(new URL('./models/artist_vehicle_pack/compact_sedan.glb',import.meta.url)),'compact_sedan');other.object.position.set(4,0,0);scene.add(other.object);roots.push(other.object);assert.equal(candidate.hasLineOfSight(driver,to,npc.id),false);assert.notEqual(candidate.pick()?.kind,'npc');
console.log(JSON.stringify({status:'AUDIT_REPRO',productionChanged:false,rows,candidateChecks:['only own car excluded for command picking and command LOS','wall still blocks','other car still blocks'],limits:'No production patch and no browser result; physical fire retains own hull unchanged.'},null,2));targets.dispose();candidate.dispose();npc.dispose();
