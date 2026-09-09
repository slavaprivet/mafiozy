// CPU integration of the actual walk functions; DOM/camera/character posing only are stubbed.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createLandscapePlan} from './landscape_plan.mjs';
import {buildExplorationDecorPlan} from './exploration_decor_worker_core.mjs';
import {buildEnvironmentVisualPlans} from './environment_planning_worker_core.mjs';
import {explorationKeepouts} from './exploration_scene_support.mjs';
import {createWalkCollisionIndex} from './walk_collision_index.mjs';
import {stepCar,createCarWorld,carOverlapsCircle,pointInPolygon} from './car_drive.mjs';
import {poseVehicleOnLandscape} from './exploration_vehicle_support.mjs';
import {ARTIST_VEHICLE_PROFILES,createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createVehicleHood} from './vehicle_hood.mjs';
import {stepVehicleWater,mergeWaterDriveEffects,resetVehicleWater} from './vehicle_water_state.mjs';
import {waterVehicleSurfaceAt,waterVehicleAccessPoint,WATER_VEHICLE_ACCESS} from './water_vehicle_access.mjs';
import {vehicleWaterDeparturePoint,vehicleWaterSeatPoint,createVehicleWaterExitSurface,canAscendFromVehicle} from './vehicle_water_exit.mjs';
import {vehicleSeat,canControlVehicle} from './vehicle_seats.mjs';
import {EXIT,launchExitBody,stepExitBody} from './car_exit.mjs';
import {createExitSwimHandoff} from './vehicle_exit_surface.mjs';
const read=name=>JSON.parse(fs.readFileSync(new URL(name,import.meta.url),'utf8'));
const source=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8').replace(/\r/g,'');
function extract(name){const start=source.indexOf('function '+name+'(');assert(start>=0,name);const lineEnd=source.indexOf('\n',start);return source.slice(start,source.slice(start,lineEnd).trimEnd().endsWith('}')?lineEnd:source.indexOf('\n}',start)+2);}
const vendor=(process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
class Box extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
const terrain=createLandscapePlan(),heights=terrain.grid.heights.slice(),topology=read('./topology_for_placement.json');
const instances=[...read('./buildings_placement.v1.json').instances,...read('./decor_placement.v1.json').instances],keepouts=explorationKeepouts(instances);
const decor=buildExplorationDecorPlan({topology,instances,keepouts});
const environment=buildEnvironmentVisualPlans({topology,instances,keepouts,decorPlan:decor});
const bodies=[...instances.flatMap(i=>i.collision?.worldBodies||[]),...decor.colliders,...environment.roadPlan.colliders,...environment.parkingPlan.colliders];
assert(environment.roadPlan.colliders.length>0&&environment.parkingPlan.colliders.length>0);
const index=createWalkCollisionIndex([bodies]);let probes=[];
const allowed=createCarWorld(topology,bodies,4.1,{surfaceAt:(x,z)=>waterVehicleSurfaceAt({terrain,topology,waterAt:terrain.waterAt},x,z)});
const cars=[];
for(const id of ['compact_sedan','fire_engine']){const profile=ARTIST_VEHICLE_PROFILES.find(p=>p.id===id),bytes=fs.readFileSync(new URL('./models/artist_vehicle_pack/'+profile.modelFile,import.meta.url));const glb=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');const car=createArtistVehicle(THREE,Box,glb,profile);car.hood=createVehicleHood(THREE,Box,car);cars.push(car);}
const hero={object:new THREE.Group(),reset(){},update(){}};
const context={THREE,EXIT,hero,M:4.1,poseVehicleOnLandscape,stepVehicleWater,explorationSurface:terrain,waterAt:terrain.waterAt,groundHeight:terrain.groundHeight,heroGroundHeight:terrain.groundHeight,ceilingHeight:()=>Infinity,traversalMapContains:terrain.contains,walkCollisionIndex:(c,r)=>[...index(c,r),...probes],inPolygon:(r,c,p)=>pointInPolygon(c,r,p),carOverlapsCircle,vehicleSeat,vehicleWaterDeparturePoint,vehicleWaterSeatPoint,createVehicleWaterExitSurface,canAscendFromVehicle,launchExitBody,stepExitBody,createExitSwimHandoff,canControlVehicle,carRollover:null,exitQaMode:false,performance,poseVehicleOccupant(){},artistSurfaceState:{swim:{liftWorld:0}},surfaceMotion:{reset(){}},setWalking(){},ensureVehicleExitVisible(){},camera:{},controls:{},postureEyeHeight:()=>1.7,keys:new Set(),$:()=>({}),exitSwimHandoff:null};
context.fleet={records:[],activeId:'active',overlaps(x,z,r,except){return this.records.some(v=>v.id!==except&&carOverlapsCircle(v.state,x,z,r))}};
context.canWalk=(x,z)=>terrain.canWalk(x,z);vm.createContext(context);
for(const name of ['poseWalkVehicle','waterExitCapsule','isWaterExit','planWaterExit','pedestrianAllowed','finishExit','abortExit','updateMovingExit'])vm.runInContext(extract(name),context);
const reports=[];
function configure(car,state){const other=cars.find(c=>c!==car);other.object.position.set(900,5,800);const otherState={x:900,z:800,yaw:0,vehicleProfile:other.profile};context.car=car;context.carState=state;context.fleet.records=[{id:'active',car,state},{id:'other',car:other,state:otherState}];return context.fleet.records[1];}
function diagnose(seatId){const state=context.carState,car=context.car;return [1.9,2.4].map(distance=>{let failure=null,last;for(let i=0;i<=24;i++){last=vehicleWaterDeparturePoint({THREE,car,state,seatId,distance,progress:i/24});if(!context.waterExitCapsule(last)){const floors=[[0,0],[EXIT.radius,0],[-EXIT.radius,0],[0,EXIT.radius],[0,-EXIT.radius]].map(([dx,dz])=>terrain.groundHeight(last.x+dx,last.z+dz)-last.y);failure={step:i,point:{x:last.x,y:last.y,z:last.z},floorAboveFoot:Math.max(...floors)};break;}}return{distance,failure,ownOverlap:!failure&&carOverlapsCircle(state,last.x,last.z,EXIT.radius),canAscend:!failure&&canAscendFromVehicle({position:last,waterAt:terrain.waterAt,canOccupy:context.waterExitCapsule})}});}
function exercise(car,state,label){configure(car,state);const outputs=[];for(const seat of car.seats){const wet=context.isWaterExit(seat.id),plan=context.planWaterExit(seat.id);if(!plan){outputs.push({seat:seat.id,wet,plan:false,diagnostic:diagnose(seat.id)});continue;}context.occupiedSeat=seat.id;context.transition={...plan,exiting:true,phase:'door',elapsed:0,door:0};const start=vehicleWaterSeatPoint({THREE,car,state,seatId:seat.id});hero.object.position.set(start.x,start.y,start.z);let count=0,maxBodyStep=0;while(context.transition&&count++<1200){const wasBody=context.transition.phase==='body',before=hero.object.position.clone();context.updateMovingExit(1/60);if(wasBody){const dy=hero.object.position.y-before.y;assert(dy>=-1e-8,'passive ascent must not teleport downward');maxBodyStep=Math.max(maxBodyStep,dy);assert(dy<=.9/60+1e-7,'passive ascent/finish remains continuous');}}assert(!context.transition,label+' finishes');assert.equal(context.occupiedSeat,null,label+' actually leaves seat');const level=terrain.waterAt(hero.object.position.x,hero.object.position.z).level;assert(Math.abs(hero.object.position.y-(level-.05))<1e-6);assert(Math.hypot(hero.object.position.x-plan.landing.x,hero.object.position.z-plan.landing.z)<.5,'no coast teleport');outputs.push({seat:seat.id,wet,plan:true,frames:count,maxBodyStep});}reports.push({label,outputs});console.log(JSON.stringify(reports.at(-1)));return outputs;}
for(const car of cars){let state={...waterVehicleAccessPoint(20),yaw:WATER_VEHICLE_ACCESS.yaw,travelYaw:WATER_VEHICLE_ACCESS.yaw,speed:0,steer:0,yawRate:0,vehicleProfile:car.profile,seats:car.seats};resetVehicleWater(car,state);context.poseWalkVehicle(car,state,0,0);for(let i=0;i<900;i++){state.crashEffects=mergeWaterDriveEffects(state,{powerFactor:1});state=stepCar(state,{forward:!state.waterState.flooded},1/60,allowed);context.poseWalkVehicle(car,state,0,1/60);}assert(state.waterState.flooded&&state.waterState.sunk);exercise(car,state,car.profile.id+' deepdrive');}
// Exact failed LIVE pose supplied by coordinator, reproduced using actual terrain orientation.
const fire=cars[1],live={x:845.1249065120309,z:412.7816500976088,yaw:1.2855328379666866,travelYaw:1.2855328379666866,speed:0,steer:0,yawRate:0,vehicleProfile:fire.profile,seats:fire.seats};resetVehicleWater(fire,live);context.poseWalkVehicle(fire,live,0,0);fire.object.position.y=-2.1885111647135904;fire.object.updateWorldMatrix(true,true);exercise(fire,live,'LIVE fire-engine flooded exit');
// Physical occupancy still rejects OTHER actual GLB cars and height-qualified solids.
const other=configure(fire,live),clearPlan=context.planWaterExit('front_right');assert(clearPlan);
const p=clearPlan.landing;assert(context.waterExitCapsule(p),'own car is excluded from capsule, not other cars');
other.state.x=p.x;other.state.z=p.z;other.car.object.position.set(p.x,p.y,p.z);
assert(!context.waterExitCapsule(p),'another car at the exit is solid');
assert(!context.planWaterExit('front_right'),'blocked dynamic exit is not admitted');
other.state.x=900;other.state.z=800;other.car.object.position.set(900,5,800);
const box=(y0,y1)=>({polygonCR:[[p.x-3,p.z-3],[p.x+3,p.z-3],[p.x+3,p.z+3],[p.x-3,p.z+3]].map(([x,z])=>[x/4.1,z/4.1]),minYM:y0,maxYM:y1});
probes=[box(p.y-.1,p.y+2)];assert(!context.waterExitCapsule(p),'static wall blocks capsule');assert(!context.planWaterExit('front_right'));
probes=[box(p.y+1.3,p.y+1.5)];assert(context.waterExitCapsule(p),'initial doorway is below overhead obstruction');assert(!canAscendFromVehicle({position:p,waterAt:terrain.waterAt,canOccupy:context.waterExitCapsule}),'underwater overhead blocks complete ascent');
const surface=createVehicleWaterExitSurface({position:p,groundHeight:terrain.groundHeight,waterAt:terrain.waterAt,canOccupy:context.waterExitCapsule});let blocked;for(let i=0;i<240;i++)blocked=surface.update({dt:1/60});assert(blocked.blocked&&!blocked.grounded);assert(blocked.y<p.y+.3,'ascent cannot cross overhead slab');probes=[];
console.log('PASS real other-car/static/overhead rejection; occupied car alone does not block departure');
const fleetSource=fs.readFileSync(new URL('./vehicle_fleet.mjs',import.meta.url),'utf8');
assert.match(extract('entrySpot'),/record\.state\?\.waterState\?\.flooded\)continue/,'flooded wreck cannot offer a fresh entry');
const frame=source.slice(source.indexOf('function frame(){'));
const merge=frame.indexOf('mergeWaterDriveEffects(carState,carState.crashEffects)'),solve=frame.indexOf('stepCar(carState,input,dt,'),pose=frame.indexOf('poseWalkVehicle(car,carState,'),vapor=frame.indexOf('waterVapor?.update('),capture=frame.indexOf('captureWaterInspection(dt)');
assert(merge>=0&&merge<solve&&solve<pose&&pose<vapor&&vapor<capture,'active water torque -> drive -> sink -> vapor -> inspection order');
assert.match(source,/pose:\(vehicle,state,angle,dt\)=>poseWalkVehicle\(vehicle,state,angle,dt\)/);
assert.match(fleetSource,/pose\(car,state,angle,dt\)/);assert.match(fleetSource,/mergeWaterDriveEffects\(s,record.damage\?\.crashEffects\|\|\{\}\)/);
assert.match(fleetSource,/resetVehicleWater\(record.car,record.state\)/);assert.match(fleetSource,/render\(record,elapsed/);
console.log('PASS actual active/passive water wiring, fleet pose dt/reset, vapor order');
assert.deepEqual(terrain.grid.heights,heights,'exit audit cannot alter terrain');
console.log(JSON.stringify({passed:reports.every(r=>r.outputs.every(s=>s.plan)),reports,staticBodies:bodies.length,scope:'Actual GLBs, terrain, planned static bodies and extracted root exit/finish helpers; character animation, DOM and camera presentation are stubbed. Active/passive fleet wiring is source-asserted, not a browser input test.'},null,2));
for(const car of cars){car.hood.dispose();car.dispose?.();}
assert(reports.every(r=>r.outputs.every(s=>s.plan)),'all real occupied seats must have a valid water exit on the tested open lake bed; see diagnostics');
