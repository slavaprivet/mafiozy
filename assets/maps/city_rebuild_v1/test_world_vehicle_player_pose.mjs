import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createHeroWalker} from './hero_walk.mjs';
import {NPC_ASSETS} from './npc_actor.mjs';
import {createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createWorldVehiclePlayerPose} from './world_vehicle_player_pose.mjs';
const vendor=process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c);}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const load=async url=>{const b=fs.readFileSync(url);return(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene;};
class Box extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d);}}
const carSource=await load(new URL('./models/artist_vehicle_pack/police_interceptor.glb',import.meta.url));
const results=[];
for(const sex of ['male','female']){
 const scene=new THREE.Scene(),car=createArtistVehicle(THREE,Box,carSource,'police_interceptor');scene.add(car.object);car.object.position.set(100,1,200);car.object.rotation.y=.7;
 const walker=createHeroWalker({THREE,scene:await load(new URL(NPC_ASSETS[sex].url)),targetHeight:sex==='male'?1.9:1.75});scene.add(walker.object);walker.object.position.set(100.3,1,200.4);walker.object.rotation.y=-.3;
 const root=walker.object.position.clone(),rotation=walker.object.quaternion.clone(),carPosition=car.object.position.clone(),c=walker.artistContext(),children=scene.children.length;
 let available=true,doorCalls=0,lastFold=null;const originalPose=car.poseOccupant.bind(car);car.poseOccupant=(w,id,options)=>{lastFold=options.fold;return originalPose(w,id,options);};
 const helper=createWorldVehiclePlayerPose({THREE,getVehicle:id=>available&&id==='quest-real'?car:null,setDoorPose({actor,doorId,open}){assert.equal(actor,car);actor.setDoorById(open,doorId);doorCalls++;}});
 const base={active:true,sourceCarId:'traffic-original',presentationCarId:'quest-real',seatId:'front_left',phase:'driving',progress:1,r:48.78,c:24.39,ang:.8,hp:73};
 const before=JSON.stringify(base);
 for(const seat of car.seats){
  walker.update(.016,false,false,null,{},{});const source={...base,seatId:seat.id},out=helper.apply(walker,source,.016);assert(out.bound);assert.equal(out.seatId,seat.id);assert.equal(lastFold,1);
  scene.updateMatrixWorld(true);const head=car.object.worldToLocal(c.worldPosition('head').clone());
  assert.ok(Math.abs(head.x-seat.anchor.side)<.45,'actual head belongs to selected seat');assert.ok(head.y<car.profile.height-.25,'head fits under roof');
  assert(walker.object.position.distanceTo(root)<1e-8);assert.deepEqual(walker.object.quaternion.toArray(),rotation.toArray());assert(car.object.position.distanceTo(carPosition)<1e-8);
 }
 for(const phase of ['enter','exit'])for(const progress of [.25,.75]){
  walker.update(.016,false,false,null,{},{});assert(helper.apply(walker,{...base,phase,progress},.016).bound);assert.equal(lastFold,phase==='enter'?progress:1-progress,'entry/exit proportional fold');
 }
 helper.apply(walker,base,.016);const seatedHead=c.worldPosition('head').clone();for(let i=0;i<8;i++)helper.apply(walker,base,.016);
 assert(c.worldPosition('head').distanceTo(seatedHead)<.001,'repeated seated pose does not accumulate offsets');
 const stableDoors=doorCalls;helper.apply(walker,base,.016);assert.equal(doorCalls,stableDoors,'settled door does not dirty render batches each frame');
 available=false;assert.equal(helper.apply(walker,base,.016).bound,false);assert.equal(walker.object.visible,false);
 available=true;helper.apply(walker,base,.016);assert.equal(walker.object.visible,true);
 const oldHead=c.worldPosition('head').clone();car.object.position.x+=1;helper.apply(walker,base,.016);assert(Math.abs(c.worldPosition('head').x-oldHead.x-1)<.001,'seat follows current real actor transform');
 const external=helper.apply(walker,{...base,phase:'pull_driver'},.016);assert.equal(external.ownsPose,false);assert.equal(external.bound,false);const handoffDoors=doorCalls;
 helper.apply(walker,{...base,phase:'pull_driver',progress:.6},.016);assert.equal(doorCalls,handoffDoors,'pull_driver animation owns its door');
 const open=helper.apply(walker,{...base,phase:'open',progress:.6},.016);assert.equal(open.ownsPose,false);assert.equal(open.doorOpen,.6);
 assert.equal(helper.apply(walker,{...base,healthDead:true},.016).active,false);assert.equal(walker.object.visible,true);assert.equal(JSON.stringify(base),before,'source HP/state untouched');assert.equal(scene.children.length,children,'no clone or reparent');
 helper.apply(walker,base,.016);helper.prepare(walker,{active:false});walker.update(.016,false,false,null,{},{});assert(c.visualPivot.position.length()<1e-8,'source exit releases normal on-foot pose');
 const cpu=[];helper.apply(walker,base,.016);for(let i=0;i<35;i++){const start=performance.now();helper.apply(walker,base,.016);if(i>=10)cpu.push(performance.now()-start);}cpu.sort((a,b)=>a-b);results.push({sex,frames:25,warmup:10,p50Ms:cpu[12],p95Ms:cpu[23]});
 helper.dispose();assert.equal(helper.apply(walker,base,.016).active,false);
}
console.log(JSON.stringify({passed:true,checks:'actual male/female GLBs, four seats, enter/exit fold, actual doors, pending model, exact actor follow, stable source roots/HP, pull_driver handoff, death/exit release',cpu:results,scope:'CPU pose only; shared-scene performance and GPU not tested'}));
