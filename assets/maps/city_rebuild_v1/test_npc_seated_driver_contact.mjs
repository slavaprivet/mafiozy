import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createNpcTrafficVehicleBinding} from './npc_vehicle_pose.mjs';
import {createNpcContactRay} from './npc_contact_ray.mjs';
import {createGlassBreakage,isBreakableGlass} from './glass_breakage.mjs';
import {setVehicleWindowOpen} from './vehicle_window_fire.mjs';
import {createVehicleRenderBatches} from './vehicle_render_batches.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c);}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
// Paired CPU baseline changes only the pre-fix broadphase; both versions use
// the same real skin/obstruction work and already-loaded GLB scene.
let baselineCode=fs.readFileSync(new URL('./npc_contact_ray.mjs',import.meta.url),'utf8');
const broadStart=baselineCode.indexOf('   // Seat binding'),broadEnd=baselineCode.indexOf('   if(distance>9)',broadStart);
assert(broadStart>=0&&broadEnd>broadStart);
baselineCode=baselineCode.slice(0,broadStart)+'   record.object.getWorldPosition(actorCenter);actorCenter.y+=1;const distance=ray.ray.distanceSqToPoint(actorCenter);\n'+baselineCode.slice(broadEnd);
baselineCode=baselineCode.replace("'./npc_contact_anchor.mjs'",JSON.stringify(new URL('./npc_contact_anchor.mjs',import.meta.url).href));
const {createNpcContactRay:createBaseline}=await import('data:text/javascript;base64,'+Buffer.from(baselineCode).toString('base64'));
const glb=async url=>{const b=fs.readFileSync(url);return(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene;};
class Box extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d);}}
const vehicleSource=await glb(new URL('./models/artist_vehicle_pack/police_interceptor.glb',import.meta.url));
const output=[];
for(const sex of ['male','female']){
 const world=new THREE.Scene(),car=createArtistVehicle(THREE,Box,vehicleSource,'police_interceptor');
 const batches=createVehicleRenderBatches({THREE,root:car.object,includeDoors:true,includeBody:true,detailOptimization:true});
 world.add(car.object);car.object.position.set(22,.2,18);car.object.rotation.y=.7;
 const binding=createNpcTrafficVehicleBinding({THREE,actor:car});
 const npc=createNpcActor({THREE,scene:world,source:await glb(new URL(NPC_ASSETS[sex].url)),cloneSkeleton:clone,id:'driver_'+sex,sex,height:sex==='male'?1.85:1.72,getVehicle:()=>binding});
 npc.update(.1,{position:{x:22,y:.2,z:18},yaw:.7,life:{civilianTripRiding:true,civilianTripCarId:'police',civilianTripPhase:'drive',vehicleSeatId:'front_left'}});
 world.updateMatrixWorld(true);
 const c=npc.walker.artistContext(),head=c.worldPosition('head');
 const outward=new THREE.Vector3(Math.sign(car.seats.find(s=>s.id==='front_left').anchor.side),0,0).applyQuaternion(car.object.quaternion),direction=outward.clone().negate();
 const contact=createNpcContactRay({THREE,getActors:()=>[npc],obstacles:()=>[car.object]});
 const rawRay=new THREE.Raycaster();
 const samples=[];
 for(const dy of [0,.06,.12,.18,.24]){
  const target=head.clone().add(new THREE.Vector3(0,dy,0)),origin=target.clone().addScaledVector(outward,3);
  rawRay.set(origin,direction);rawRay.far=4;
  const hit=rawRay.intersectObject(car.object,true).find(h=>h.object.visible);
  const material=hit&&(Array.isArray(hit.object.material)?hit.object.material[hit.face?.materialIndex||0]:hit.object.material);
  const closed=contact({origin,direction,range:4});
  assert(hit&&isBreakableGlass(hit.object,material),'own side window is the first physical obstacle');
  assert.equal(closed,null,'intact glass stops contact');
  setVehicleWindowOpen(car,'front_left',true);world.updateMatrixWorld(true);
  batches.update();
  const opened=contact({origin,direction,range:4});
  assert.equal(opened?.npcId,npc.id);assert.equal(opened.zone,'head');
  setVehicleWindowOpen(car,'front_left',false);world.updateMatrixWorld(true);
  batches.update();
  samples.push({dy,mesh:hit?.object.name,material:material?.name,glass:hit&&isBreakableGlass(hit.object,material),closed:closed?.zone,opened:opened?.zone});
 }
 const target=head.clone().add(new THREE.Vector3(0,.12,0)),origin=target.clone().addScaledVector(outward,3);
 rawRay.set(origin,direction);rawRay.far=4;const hit=rawRay.intersectObject(car.object,true).find(h=>h.object.visible);
 const glass=createGlassBreakage(THREE,world,{maxShards:8,maxDecoratedPanels:2});
 assert.equal(glass.stats().registeredMeshes,0);
 assert(glass.hit(hit,{direction,impulse:24,weaponId:'pistol'}).broken,'first actual impact lazily registers traffic glass');
 assert.equal(contact({origin,direction,range:4}),null,'brief fracture phase still has intact triangles');
 glass.update(.1);world.updateMatrixWorld(true);
 assert.equal(contact({origin,direction,range:4})?.zone,'head','broken pane passes head contact');
 const bare=createNpcContactRay({THREE,getActors:()=>[npc],obstacles:()=>[]});
 const metalSamples=[];
 for(const dy of [.08,0,-.08,-.16]){
  const lowOrigin=c.worldPosition('chest').add(new THREE.Vector3(0,dy,0)).addScaledVector(outward,3);
  rawRay.set(lowOrigin,direction);const metal=rawRay.intersectObject(car.object,true).find(h=>h.object.visible);
  const material=metal&&(Array.isArray(metal.object.material)?metal.object.material[metal.face?.materialIndex||0]:metal.object.material);
  const skin=bare({origin:lowOrigin,direction,range:4}),blocked=contact({origin:lowOrigin,direction,range:4});
  metalSamples.push({dy,mesh:metal?.object.name,material:material?.name,skin:skin?.zone,blocked:blocked?.zone});
  if(skin&&metal&&!isBreakableGlass(metal.object,material))assert.equal(blocked,null,'metal below the broken window still protects the occupant');
 }
 assert(metalSamples.some(row=>row.skin&&row.mesh&&!row.blocked),'metal case must have a real skin target behind it');
 const staleRoot=car.object.position.clone().add(new THREE.Vector3(0,0,7).applyQuaternion(car.object.quaternion));
 npc.update(.1,{position:staleRoot,yaw:.7,life:{civilianTripRiding:true,civilianTripCarId:'police',civilianTripPhase:'drive',vehicleSeatId:'front_left'}});
 world.updateMatrixWorld(true);
 assert(c.worldPosition('head').distanceTo(head)<1e-6,'seat binding keeps actual head fixed while source authority root differs');
 assert.equal(contact({origin,direction,range:4})?.zone,'head','broadphase follows the actual bound skin instead of stale source root');
 npc.update(.1,{position:{x:22,y:.2,z:18},yaw:.7,life:{civilianTripRiding:true,civilianTripCarId:'police',civilianTripPhase:'drive',vehicleSeatId:'front_left'}});
 const baseline=createBaseline({THREE,getActors:()=>[npc],obstacles:()=>[car.object]}),times={before:[],after:[]};
 for(let i=0;i<20;i++)for(const [name,query]of i%2?[['before',baseline],['after',contact]]:[['after',contact],['before',baseline]]){
  const at=performance.now();assert.equal(query({origin,direction,range:4})?.zone,'head');if(i>=5)times[name].push(performance.now()-at);
 }
 for(const t of Object.values(times))t.sort((a,b)=>a-b);
 output.push({sex,closedOpenCases:samples.length,fractureWithoutPrepare:true,staleSourceRoot:true,metalSamples,cpuMs:Object.fromEntries(Object.entries(times).map(([name,t])=>[name,{p50:t[7],p95:t[14]}]))});
 glass.dispose();batches.dispose();
 npc.dispose();
}
console.log(JSON.stringify(output,null,2));
