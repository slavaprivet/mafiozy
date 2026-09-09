// Offline integration: actual walk hook, real GLB tyres and existing movement solvers.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createLandscapePlan} from './landscape_plan.mjs';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';
import {planExplorationDecor} from './exploration_decor_plan.mjs';
import {explorationKeepouts} from './exploration_scene_support.mjs';
import {createCityRoadDressingPlan} from './city_road_dressing_plan.mjs';
import {createExplorationVehicleWorld,poseVehicleOnLandscape} from './exploration_vehicle_support.mjs';
import {stepCar,carFits,pointInPolygon} from './car_drive.mjs';
import {ARTIST_VEHICLE_PROFILES,createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createWaterInteractionInputSampler} from './water_interaction_inputs.mjs';
import {createWaterInteractionSimulator} from './water_interaction_fx.mjs';
import {createEnvironmentSurfaceMaterials} from './environment_surface_materials.mjs';
import {WATER_VEHICLE_ACCESS as access,isWaterVehicleAccess,waterVehicleAccessPoint} from './water_vehicle_access.mjs';
import {findWaterJumpInspection} from './water_inspection.mjs';
import {JUMP,launchJump,stepJump} from './hero_jump.mjs';
import {resolveJumpSurface} from './surface_motion.mjs';
import {createTraversalWorld} from './hero_traversal_world.mjs';

const read=name=>JSON.parse(fs.readFileSync(new URL(name,import.meta.url),'utf8'));
const source=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8').replace(/\r/g,'');
const start=source.indexOf('function updateWaterInteractions(dt)'),end=source.indexOf('\n}',start)+2;
assert(start>=0&&end>start);const hook=source.slice(start,end);
const frame=source.slice(source.indexOf('function frame(){'));
assert(frame.indexOf('artistUpdate(dt,moved,running)')<frame.indexOf('updateWaterInteractions(dt)'),'water samples final artist/physics pose');
assert(frame.indexOf('poseVehicleOnLandscape(THREE,car,carState')<frame.indexOf('updateWaterInteractions(dt)'),'water samples supported tyre pose');
assert(frame.indexOf('updateWaterInteractions(dt)')<frame.indexOf('environmentVisuals?.update('),'ripples reach surface material before render');
assert.match(source,/function clearContent\([^]*?waterEffects\?\.dispose\(\);waterEffects=null;waterInputs.reset\(\)/);

const topology=read('./topology_for_placement.json');
const instances=[...read('./buildings_placement.v1.json').instances,...read('./decor_placement.v1.json').instances];
const landscape=createLandscapePlan(),heightsBefore=landscape.grid.heights.slice(),topologyBefore=JSON.stringify(topology);
const keepouts=explorationKeepouts(instances),railPlan=createExplorationRailwayPlan({landscape,topology});
const decor=planExplorationDecor({terrain:landscape,topology,keepouts,railPlan,metresPerCell:4.1});
// Same road keepout assembly as the live environment worker/wrapper.
const roadKeepouts=[...keepouts,...explorationKeepouts([{collision:{worldBodies:decor.colliders}}])];
const roads=createCityRoadDressingPlan({topology,landscape,railPlan,keepouts:roadKeepouts,instances});
const nativeBodies=instances.flatMap(item=>item.collision?.worldBodies||[]);
const bodies=[...nativeBodies,...decor.colliders,...roads.colliders];
assert(roads.colliders.length>0&&decor.colliders.length>0);
const support={...landscape,canDrive:(x,z)=>landscape.canDrive(x,z)||isWaterVehicleAccess(landscape,x,z)};
const driveAllowed=createExplorationVehicleWorld({topology,bodies,terrain:support});

const vendor=(process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
class Box extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
const materials=createEnvironmentSurfaceMaterials({THREE});
const sampler=createWaterInteractionInputSampler({THREE});
const sim=createWaterInteractionSimulator({waterAt:landscape.waterAt,groundHeight:landscape.groundHeight,random:()=>.4});
const context={waterEffects:sim,waterInputs:sampler,waterTeleported:false,hero:null,fleet:{records:[]},occupiedSeat:null,transition:null,controls:{target:new THREE.Vector3()},environmentVisuals:{setWaterRipples:events=>materials.setWaterRipples(events)}};
vm.createContext(context);vm.runInContext(hook,context);
const update=dt=>{context.dt=dt;vm.runInContext('updateWaterInteractions(dt)',context)};

const profile=ARTIST_VEHICLE_PROFILES.find(p=>p.id==='fire_engine');
const bytes=fs.readFileSync(new URL('./models/artist_vehicle_pack/'+profile.modelFile,import.meta.url));
const glb=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
const car=createArtistVehicle(THREE,Box,glb,profile);
let state={...waterVehicleAccessPoint(20),yaw:access.yaw,travelYaw:access.yaw,speed:0,steer:0,yawRate:0,vehicleProfile:car.profile};
const record={id:'fire_engine',car,state};context.fleet.records=[record];context.occupiedSeat='front_left';
poseVehicleOnLandscape(THREE,car,state,landscape);context.controls.target.copy(car.object.position);
assert(carFits(state.x,state.z,state.yaw,driveAllowed,car.profile),'actual inspection start must be legal');
update(1/60);assert.equal(sim.stats().bursts,0,'preparing the inspection must not fabricate an entry');
let firstImpact=null,firstWet=null,travel=0,maxSpeed=0,frames=0,maxSurfaceRipples=0;
for(let i=0;i<720;i++){
  const before={...state};state=stepCar(state,{forward:i<300,handbrake:i>=300},1/60,driveAllowed);record.state=state;
  travel+=Math.hypot(state.x-before.x,state.z-before.z);maxSpeed=Math.max(maxSpeed,Math.abs(state.speed));
  poseVehicleOnLandscape(THREE,car,state,landscape);context.controls.target.copy(car.object.position);update(1/60);frames++;
  // Sampling a separate read-only adapter cannot move the car or synthesize effects.
  const input=createWaterInteractionInputSampler({THREE}).sample({records:[record],dt:1/60}).vehicles[0];
  assert.equal(input.massKg,10500);
  if(firstWet===null&&input.contactPoints.some(p=>{const w=landscape.waterAt(p.x,p.z);return w&&p.y<=w.level+.045;}))firstWet=i;
  if(firstImpact===null&&sim.stats().impacts>0)firstImpact={frame:i,time:i/60,travel,speed:state.speed,position:{x:state.x,z:state.z}};
  maxSurfaceRipples=Math.max(maxSurfaceRipples,materials.stats.waterRipples);
}
assert(firstWet!==null,'the real posed GLB wheels must cross the water surface');
assert(firstImpact,'driving the actual 10500 kg fire engine must produce a physical entry impact');
assert(firstImpact.travel>10&&firstImpact.speed>1.3,'impact follows genuine accelerated driving, not spawn or static endpoint');
assert(Math.abs(firstImpact.frame-firstWet)<=2,'entry corresponds to actual wheel contact');
assert(sim.stats().recontacts>0&&maxSurfaceRipples>0,'ballistic drops return to water and ripple uniforms receive events');
const carReport={frames,travel,maxSpeed,firstImpact,recontacts:sim.stats().recontacts,bursts:sim.stats().bursts,colliders:{native:nativeBodies.length,decor:decor.colliders.length,road:roads.colliders.length}};
const stillBursts=sim.stats().bursts;for(let i=0;i<120;i++)update(1/60);assert.equal(sim.stats().bursts,stillBursts,'stopped vehicle makes no infinite spray');
car.dispose?.();

// Match actual jump collision/support calls using all static scene bodies.
const buckets=new Map();
for(const body of bodies){if(!body.polygonCR?.length)continue;const xs=body.polygonCR.map(p=>p[0]),zs=body.polygonCR.map(p=>p[1]);for(let x=Math.floor(Math.min(...xs));x<=Math.floor(Math.max(...xs));x++)for(let z=Math.floor(Math.min(...zs));z<=Math.floor(Math.max(...zs));z++){const key=x+','+z;if(!buckets.has(key))buckets.set(key,[]);buckets.get(key).push(body);}}
const traversal=createTraversalWorld({groundHeight:landscape.groundHeight,ceilingHeight:()=>Infinity,bodiesAt:(x,z)=>buckets.get(Math.floor(x/4.1)+','+Math.floor(z/4.1))||[],contains:landscape.contains,walkable:landscape.canWalk,waterAt:landscape.waterAt,blocksDynamic:()=>false,inBody:(body,x,z)=>pointInPolygon(x/4.1,z/4.1,body.polygonCR)});
const entry=findWaterJumpInspection(landscape,(x,z)=>landscape.canWalk(x,z)&&traversal.pointFits(x,z,landscape.groundHeight(x,z),1.9));assert(entry);
const hero={object:new THREE.Group(),height:1.9};hero.object.position.set(entry.origin.x,entry.origin.y,entry.origin.z);
const jumpSim=createWaterInteractionSimulator({waterAt:landscape.waterAt,groundHeight:landscape.groundHeight,random:()=>.4});
context.hero=hero;context.fleet.records=[];context.occupiedSeat=null;context.waterEffects=jumpSim;sampler.reset();update(1/60);
let jump={...launchJump(hero.object.position,entry.direction),baseY:entry.origin.y},jumpImpact=null,apex=entry.origin.y;
for(let i=0;i<180;i++){
  if(!jump.done){const previousY=hero.object.position.y,probe=stepJump(jump,1/60,()=>true),footY=jump.falling?previousY:Math.max(previousY,jump.baseY+probe.y);
    jump=stepJump(jump,1/60,(x,z)=>traversal.pointFits(x,z,footY,1.9));
    jump=resolveJumpSurface(jump,{floor:traversal.supportHeight(jump.x,jump.z,footY),ceiling:Infinity,bodyHeight:1.9,previousY,dt:1/60,flightTime:JUMP.flight});
    hero.object.position.set(jump.x,jump.worldY,jump.z);apex=Math.max(apex,jump.worldY);
  }
  update(1/60);
  if(jumpImpact===null&&jumpSim.stats().impacts>0)jumpImpact={frame:i,time:i/60,position:hero.object.position.toArray()};
}
assert(jump.done&&!jump.blocked);assert(apex>entry.origin.y+1,'ordinary jump reaches its real apex');
assert(jumpImpact&&jumpImpact.time>.4,'real descending trajectory, not initial spawn, generates impact');
assert(landscape.waterAt(jump.x,jump.z)?.depth>.18);
assert(jumpSim.stats().recontacts>0,'hero droplets complete ballistic arcs');
assert.deepEqual(landscape.grid.heights,heightsBefore,'no terrain height was changed for the inspection');
assert.equal(JSON.stringify(topology),topologyBefore,'native map/road/water/police masks unchanged');
const heroReport={entry,apex,jumpImpact,bursts:jumpSim.stats().bursts,recontacts:jumpSim.stats().recontacts};
sim.dispose();jumpSim.dispose();materials.dispose();
console.log(JSON.stringify({passed:true,car:carReport,hero:heroReport,hook:'actual updateWaterInteractions executed; after artist/car pose, before surface render; dispose/reset checked',scope:'CPU actual solvers and GLB, not browser/GPU QA'},null,2));
