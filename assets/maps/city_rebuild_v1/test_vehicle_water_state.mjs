import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import vm from 'node:vm';
import {CAR,createDemoCar,stepCar,createCarWorld} from './car_drive.mjs';
import {createVehicleHood} from './vehicle_hood.mjs';
import {ARTIST_VEHICLE_PROFILES,createArtistVehicle} from './vehicle_fleet_models.mjs';
import {poseVehicleOnLandscape} from './exploration_vehicle_support.mjs';
import {stepVehicleWater,mergeWaterDriveEffects,resetVehicleWater,sampleVehicleEngineHighPoint,VEHICLE_WATER_RULES as RULES} from './vehicle_water_state.mjs';
import {createLandscapePlan} from './landscape_plan.mjs';
import {waterVehicleSurfaceAt,WATER_VEHICLE_ACCESS,waterVehicleAccessPoint} from './water_vehicle_access.mjs';

const vendor=(process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
class Box extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
const waterAt=()=>({level:0,floor:-5,depth:5});
const terrainAt=y=>({contains:()=>true,groundHeight:()=>y});
const stateFor=car=>({x:0,z:0,yaw:0,travelYaw:0,speed:0,steer:0,yawRate:0,vehicleProfile:car.profile});
function sedan(){const car=createDemoCar(THREE,Box);car.profile={...CAR,width:CAR.halfWidth*2,length:CAR.halfLength*2,height:2.22,massKg:1500};car.hood=createVehicleHood(THREE,Box,car);return car;}
function poseAndStep(car,state,support,dt=1/60,water=waterAt,rollAngle=0){const terrain=typeof support==='number'?terrainAt(support):support;poseVehicleOnLandscape(THREE,car,state,terrain,rollAngle);return stepVehicleWater({THREE,car,state,waterAt:water,terrain,dt,rollAngle});}
let checks=0;
function test(name,fn){fn();checks++;console.log('PASS',name);}

test('dry pose is an exact NOOP and lake beneath bridge does not submerge the car',()=>{
  const car=sedan(),state=stateFor(car);state.yaw=.7;
  const terrain={contains:()=>true,groundHeight:(x,z)=>4+x*.06-z*.03};
  poseVehicleOnLandscape(THREE,car,state,terrain,.25);const matrix=car.object.matrixWorld.toArray(),position=car.object.position.toArray(),rotation=car.object.quaternion.toArray(),scale=car.object.scale.toArray();
  const w=stepVehicleWater({THREE,car,state,waterAt:()=>null,terrain,dt:.1});
  assert.deepEqual(car.object.matrixWorld.toArray(),matrix);assert.deepEqual(car.object.position.toArray(),position);assert.deepEqual(car.object.quaternion.toArray(),rotation);assert.deepEqual(car.object.scale.toArray(),scale);assert(!w.inWater&&!w.engineDisabled);
  const underBridge=poseAndStep(car,state,4,.1,waterAt,.25);assert(!underBridge.inWater&&!underBridge.flooded&&!underBridge.sunk);assert.equal(car.object.position.y,underBridge.supportY);
  car.hood.dispose();
});
test('shallow water preserves torque and damage flags; repeated merge is idempotent',()=>{
  const car=sedan(),state=stateFor(car),w=poseAndStep(car,state,-.15,.1);assert(w.inWater&&!w.flooded&&!w.sunk);
  const base={engineDisabled:false,powerFactor:.63,brakeFactor:.42,steerFactor:.31,speedFactor:.52,rollingDrag:.7,customDamage:'preserved'},copy=JSON.stringify(base);
  const effects=mergeWaterDriveEffects(state,base);assert.equal(JSON.stringify(base),copy);assert.equal(effects.powerFactor,.63);assert.equal(effects.brakeFactor,.42);assert.equal(effects.customDamage,'preserved');assert(effects.rollingDrag>.7);
  assert.deepEqual(mergeWaterDriveEffects(state,effects),effects);
  const moving=stepCar({...state,crashEffects:effects},{forward:true},.1,()=>true);assert(moving.speed>0);car.hood.dispose();
});
test('descent is continuous, terminal-limited and stops at actual support, with a permanent engine latch',()=>{
  const car=sedan();let state=stateFor(car);poseAndStep(car,state,.2,.1,()=>null);
  let last=.2,firstFlood=null,firstSubmerged=null;const history=[];
  for(let i=0;i<700;i++){
    state={...state};const w=poseAndStep(car,state,-4,1/60);history.push(w.y);
    assert(w.y>=-4&&w.y<=last+1e-9);assert(last-w.y<=RULES.terminalSpeed/60+1e-9);assert(w.velocityY>=-RULES.terminalSpeed);
    if(w.flooded&&firstFlood===null)firstFlood=i;if(w.submerged&&firstSubmerged===null)firstSubmerged=i;
    last=w.y;
  }
  assert(firstFlood>0&&firstSubmerged>firstFlood);assert.equal(last,-4);assert(state.waterState.sunk&&state.waterState.engineDisabled);assert.equal(state.waterState.velocityY,0);
  const moving={...state,speed:5,crashEffects:mergeWaterDriveEffects(state,{powerFactor:1,brakeFactor:.5})};
  const next=stepCar(moving,{forward:true},.1,()=>true);assert(next.speed<5&&next.speed>0,'coasting is damped, not deleted');assert.equal(next.waterState,state.waterState);
  const stopped=stepCar({...moving,speed:0},{forward:true},.1,()=>true);assert.equal(stopped.speed,0,'no underwater torque');
  poseAndStep(car,state,3,.1,()=>null);assert(state.waterState.flooded&&state.waterState.engineDisabled);assert(!state.waterState.inWater&&!state.waterState.submerged&&!state.waterState.sunk);assert.equal(car.object.position.y,3);
  state=stateFor(car);poseAndStep(car,state,3,.1,()=>null);assert(state.waterState.engineDisabled,'controller reset does not fix this flooded car');
  const fresh=sedan(),other={...state};poseAndStep(fresh,other,3,.1,()=>null);assert(!other.waterState.engineDisabled,'another car does not inherit copied water state');assert.notEqual(other.waterState,state.waterState);
  resetVehicleWater(car,state);poseAndStep(car,state,3,.1,()=>null);assert(!state.waterState.engineDisabled,'explicit full-demo/QA reset clears only this car latch');
  assert(!other.waterState.engineDisabled);car.hood.dispose();fresh.hood.dispose();
});
test('dt clamp, invalid steps and rising floor are safe',()=>{
  const car=sedan(),state=stateFor(car);poseAndStep(car,state,.1,.1,()=>null);let w=poseAndStep(car,state,-8,50);assert(.1-w.y<=RULES.terminalSpeed*RULES.maxDt);
  const previous=w.y;for(const dt of [NaN,Infinity,-1,0]){w=poseAndStep(car,state,-8,dt);assert.equal(w.y,previous);assert(Number.isFinite(w.velocityY));}
  w=poseAndStep(car,state,1,.1);assert.equal(w.y,w.supportY);assert.equal(car.object.position.y,1);car.hood.dispose();
});
test('sink trajectory remains stable at 30/60/120 Hz',()=>{
  const results=[];for(const dt of [1/30,1/60,1/120]){const car=sedan(),state=stateFor(car);poseAndStep(car,state,.1,dt,()=>null);for(let i=0;i<2/dt;i++)poseAndStep(car,state,-8,dt);results.push(state.waterState.y);car.hood.dispose();}assert(Math.max(...results)-Math.min(...results)<.002);
});
test('engine sample tracks real vertices, mount deformation, pitch/roll and not the open hood',()=>{
  const car=sedan();car.object.position.set(2,4,-3);car.object.rotation.set(.23,.81,-.36);car.hood.bay.position.set(.08,-.03,-.20);car.object.updateWorldMatrix(true,true);
  let max=-Infinity;car.hood.bay.traverse(mesh=>{if(!/^(Engine_block|Engine_valve_cover|Valve_cover_rib|Oil_filler_cap)$/.test(mesh.name))return;const a=mesh.geometry.attributes.position;for(let i=0;i<a.count;i++)max=Math.max(max,new THREE.Vector3().fromBufferAttribute(a,i).applyMatrix4(mesh.matrixWorld).y);});
  const a=sampleVehicleEngineHighPoint({THREE,car});assert(Math.abs(a.y-max)<1e-10);assert.equal(a.source,'engine-detail');
  car.hood.hinge.rotation.x=1.4;car.object.updateWorldMatrix(true,true);const b=sampleVehicleEngineHighPoint({THREE,car});assert.deepEqual(b,a,'lid opening must not move engine flooding threshold');
  car.hood.bay.position.y-=.25;car.object.updateWorldMatrix(true,true);const c=sampleVehicleEngineHighPoint({THREE,car});assert(c.y<a.y-.2,'actual crashed mount lowers engine, despite cached support point');car.hood.dispose();
});

const actualEngines=[],driveCars=new Map();
for(const profile of ARTIST_VEHICLE_PROFILES){
  const bytes=fs.readFileSync(new URL('./models/artist_vehicle_pack/'+profile.modelFile,import.meta.url));
  const source=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
  const car=createArtistVehicle(THREE,Box,source,profile);car.hood=createVehicleHood(THREE,Box,car);
  const state=stateFor(car);poseVehicleOnLandscape(THREE,car,state,terrainAt(0));const anchor=sampleVehicleEngineHighPoint({THREE,car});
  assert(anchor&&anchor.source==='engine-detail'&&Number.isFinite(anchor.y),profile.id+' actual engine available');
  assert(profile.id==='city_bus'?anchor.z<0:anchor.z>0,profile.id+' correct front/rear engine position');
  const below=()=>({level:anchor.y-.015,depth:10,floor:anchor.y-10});let w=poseAndStep(car,state,0,0,below);assert(!w.flooded,profile.id+' runs until highest engine point is covered');
  const above=()=>({level:anchor.y+.015,depth:10,floor:anchor.y-10});w=poseAndStep(car,state,0,0,above);assert(w.flooded&&w.engineDisabled,profile.id+' floods when actual engine is covered');
  const engineOnlyWater=(x,z)=>Math.abs(x-anchor.x)<.2&&Math.abs(z-anchor.z)<.2?above():null;
  poseAndStep(car,state,0,.1,engineOnlyWater);assert(Math.abs(state.waterState.engineDepth-.015)<1e-10);
  actualEngines.push({id:profile.id,part:anchor.part,engineY:anchor.y,engineZ:anchor.z});
  if(['compact_sedan','fire_engine'].includes(profile.id))driveCars.set(profile.id,car);else{car.hood.dispose();car.dispose?.();}
}
checks++;console.log('PASS all 12 real GLB engine landmarks, front/rear thresholds and per-car flood state');

const walkSource=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8').replace(/\r/g,'');
const hookStart=walkSource.indexOf('function poseWalkVehicle('),hookEnd=walkSource.indexOf('\n}',hookStart)+2;assert(hookStart>=0&&hookEnd>hookStart);
const terrain=createLandscapePlan(),heights=terrain.grid.heights.slice(),topology=JSON.parse(fs.readFileSync(new URL('./topology_for_placement.json',import.meta.url),'utf8'));
const allowed=createCarWorld(topology,[],4.1,{surfaceAt:(x,z)=>waterVehicleSurfaceAt({terrain,topology,waterAt:terrain.waterAt},x,z)});
const context={THREE,poseVehicleOnLandscape,stepVehicleWater,explorationSurface:terrain,waterAt:terrain.waterAt};vm.createContext(context);vm.runInContext(walkSource.slice(hookStart,hookEnd),context);
const deepDrive=[];
for(const [id,car] of driveCars){
  let state={...stateFor(car),...waterVehicleAccessPoint(20),yaw:WATER_VEHICLE_ACCESS.yaw,travelYaw:WATER_VEHICLE_ACCESS.yaw};resetVehicleWater(car,state);
  const pose=dt=>{Object.assign(context,{car,state,dt});return vm.runInContext('poseWalkVehicle(car,state,0,dt)',context)};pose(0);
  let flood=null,sinkAfterFlood=0,stoppedAt=null;
  for(let frame=0;frame<1800;frame++){
    const oldY=state.waterState.y,wasFlooded=state.waterState.flooded;
    state.crashEffects=mergeWaterDriveEffects(state,{engineDisabled:false,powerFactor:1,rollingDrag:0});
    state=stepCar(state,{forward:!wasFlooded},1/60,allowed);const w=pose(1/60);
    if(!flood&&w.flooded)flood={time:frame/60,x:state.x,z:state.z,y:w.y,speed:state.speed,engineY:w.engineY,level:w.waterLevel};
    if(wasFlooded&&w.y<oldY)sinkAfterFlood+=oldY-w.y;
    if(flood&&Math.abs(state.speed)<.001&&stoppedAt===null)stoppedAt=frame/60;
    assert(w.y>=w.supportY-1e-9,'never penetrate actual posed lake bed');
  }
  assert(flood&&flood.time>1,id+' real drive reaches engine flooding without depth wall');
  assert(sinkAfterFlood>.1,id+' flooded unattended car continues passive vertical sinking');
  assert(state.waterState.sunk&&stoppedAt!==null,id+' settles on bottom and loses horizontal momentum');
  for(const input of [{forward:true},{reverse:true}]){const locked=stepCar({...state,speed:0,crashEffects:mergeWaterDriveEffects(state,{powerFactor:1})},input,.1,allowed);assert.equal(locked.speed,0,id+' W/S cannot propel flooded vehicle');}
  deepDrive.push({id,flood,stoppedAt,sinkAfterFlood,bottom:state.waterState.y,waterLevel:state.waterState.waterLevel,submerged:state.waterState.submerged});car.hood.dispose();car.dispose?.();
}
assert.deepEqual(terrain.grid.heights,heights);checks++;console.log('PASS real sedan/fire-engine stepCar -> actual poseWalkVehicle -> flood -> passive sink; W/S cannot restart');
console.log(JSON.stringify({passed:true,checks,actualEngines,deepDrive,scope:'offline CPU and actual engine geometry; walk/fleet/exit/admission unchanged'},null,2));
