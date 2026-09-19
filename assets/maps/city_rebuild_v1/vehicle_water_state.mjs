/** Per-car water gameplay state. Call immediately AFTER the original ground/roll pose.
 * Does not choose horizontal movement, admit terrain, repair damage, or handle exits.
 * state.waterState survives stepCar's state spreads; the car object also retains its
 * flooded latch across replacement of a local controller state. A new car is
 * independent. Persistence across save/reload belongs to the existing state owner.
 */
export const VEHICLE_WATER_RULES=Object.freeze({sinkAcceleration:2.2,terminalSpeed:1.05,maxDt:.1,contactTolerance:.025,floodTolerance:.005});
const finite=(value,fallback=0)=>Number.isFinite(value)?value:fallback;
const clamp=(value,min,max)=>Math.max(min,Math.min(max,value));
const engines=new WeakMap(),vehicles=new WeakMap(),owners=new WeakMap();
const ENGINE_PARTS=/^(Engine_block|Engine_valve_cover|Valve_cover_rib|Oil_filler_cap)$/;

function validWater(w){if(!w||!Number.isFinite(w.level))return null;const depth=Number.isFinite(w.depth)?w.depth:Number.isFinite(w.floor)?w.level-w.floor:0;return depth>.012?{level:w.level,depth,floor:Number.isFinite(w.floor)?w.floor:w.level-depth}:null;}
function engineMeshes(car){
  const bay=car.hood?.bay||car.object.getObjectByName('Engine_bay_detail')||null;
  const core=car.hoodSpec?.core||car.object.getObjectByName('Engine_core')||null;
  let cache=engines.get(car);
  if(!cache||cache.bay!==bay||cache.core!==core){
    const meshes=[];if(bay)bay.traverse(node=>{if(ENGINE_PARTS.test(node.name)&&node.geometry?.attributes?.position)meshes.push(node);});
    if(!meshes.length&&core)core.traverse(node=>{if(node.geometry?.attributes?.position)meshes.push(node);});
    cache={bay,core,meshes,support:new WeakMap(),source:meshes.length?(bay&&meshes[0]!==core?'engine-detail':'engine-core'):'missing'};engines.set(car,cache);
  }
  return cache;
}

/** Exact highest rendered engine vertex, including mount displacement, pitch and roll.
 * Hidden hood detail remains the mechanical engine, not the animated lid/smoke/bay wall.
 * Vertex support index is reused while the transform's vertical projection is unchanged.
 */
export function sampleVehicleEngineHighPoint({THREE,car}={}){
  if(!THREE?.Vector3||!car?.object)return null;
  const cache=engineMeshes(car);let best=null;
  for(const mesh of cache.meshes){
    // Only the engine and its ancestors are consumed here. Updating every door,
    // wheel, interior and body mesh once per sample duplicated the renderer's
    // normal traversal (four full traversals in a sinking step). Ancestor updates
    // also cover moved mounts/reparenting; no cached world transform is trusted.
    mesh.updateWorldMatrix(true,false);
    const attr=mesh.geometry.attributes.position,e=mesh.matrixWorld.elements;let support=cache.support.get(mesh);
    if(!support||support.attr!==attr||support.version!==attr.version||support.a!==e[1]||support.b!==e[5]||support.c!==e[9]){
      let max=-Infinity,index=0;for(let i=0;i<attr.count;i++){const y=attr.getX(i)*e[1]+attr.getY(i)*e[5]+attr.getZ(i)*e[9];if(y>max){max=y;index=i;}}
      support={attr,version:attr.version,a:e[1],b:e[5],c:e[9],index};cache.support.set(mesh,support);
    }
    const p=new THREE.Vector3().fromBufferAttribute(attr,support.index).applyMatrix4(mesh.matrixWorld);
    if(!best||p.y>best.y)best={x:p.x,y:p.y,z:p.z,source:cache.source,part:mesh.name};
  }
  return best;
}

function bodyEnvelope(THREE,car){
  const profile=car.profile||{},w=finite(profile.width,finite(profile.halfWidth)*2),h=finite(profile.height),l=finite(profile.length,finite(profile.halfLength)*2);
  if(!(w>0&&h>0&&l>0))return null;
  // The world Y coordinate is affine: e[1]*x + e[5]*y + e[9]*z + e[13].
  // Its extrema on the car's local box are therefore the corresponding signed
  // corners. This is exactly the old eight-corner result, including scale,
  // pitch and roll, but avoids two temporary vectors and six coordinate arrays
  // every water step (the envelope is sampled before and after a possible sink).
  const e=car.object.matrixWorld.elements,halfW=w*.5,halfL=l*.5;
  const x=Math.abs(e[1])*halfW,z=Math.abs(e[9])*halfL,y=e[5]*h,base=e[13];
  return {top:base+x+z+(y>0?y:0),bottom:base-x-z+(y<0?y:0)};
}

function recordFor(car,state,supportY){
  let record=vehicles.get(car);if(record){state.waterState=record.water;return record;}
  const supplied=state.waterState,restored=supplied&&typeof supplied==='object'&&(!owners.has(supplied)||owners.get(supplied)===car)?supplied:null;
  const latched=!!(restored?.engineDisabled||restored?.flooded);
  const water={engineDisabled:latched,flooded:latched,submerged:false,sunk:false,inWater:false,y:finite(restored?.y,supportY),velocityY:Math.min(0,finite(restored?.velocityY)),waterLevel:null,engineY:null,engineDepth:0,depth:0,supportY,drag:0,engineAnchor:'missing'};
  record={water,latched,initialized:!!restored};vehicles.set(car,record);owners.set(water,car);state.waterState=water;return record;
}

export function stepVehicleWater({THREE,car,state,waterAt,terrain,dt=0,rollAngle=0}={}){
  if(!THREE?.Vector3||!car?.object||!state||typeof waterAt!=='function')throw new TypeError('THREE, car, state and waterAt are required');
  // Ground/bridge/roll support is the pose the caller just resolved. Never replace it
  // with water.floor or terrain.groundHeight: that would sink vehicles through bridges.
  car.object.updateWorldMatrix(true,false);
  const origin=new THREE.Vector3().setFromMatrixPosition(car.object.matrixWorld),supportY=origin.y;
  if(!Number.isFinite(supportY))return state.waterState||null;
  const record=recordFor(car,state,supportY),w=record.water,previousY=w.y;
  const seconds=clamp(finite(dt),0,VEHICLE_WATER_RULES.maxDt);
  let atEngine=sampleVehicleEngineHighPoint({THREE,car});
  const centreWater=validWater(waterAt(origin.x,origin.z)),engineWater=atEngine?validWater(waterAt(atEngine.x,atEngine.z)):null;
  const water=centreWater||engineWater;
  const envelope=bodyEnvelope(THREE,car),bottomOffset=envelope?envelope.bottom-supportY:0;
  // A supported dry bridge may overhang water; water alone must not move its pose.
  const touchesWater=!!water&&supportY+bottomOffset<=water.level+VEHICLE_WATER_RULES.contactTolerance;
  let y=supportY,velocityY=0;
  if(touchesWater&&record.initialized&&previousY>supportY){
    y=previousY;velocityY=Math.min(0,finite(w.velocityY));
    const steps=Math.max(1,Math.ceil(seconds/(1/120))),h=seconds/steps;
    for(let i=0;i<steps;i++){
      const next=Math.max(-VEHICLE_WATER_RULES.terminalSpeed,velocityY-VEHICLE_WATER_RULES.sinkAcceleration*h);
      y+=(velocityY+next)*.5*h;velocityY=next;
      if(y<=supportY){y=supportY;velocityY=0;break;}
    }
    // Change the vertical world position only. Usual walk vehicle parents are identity;
    // the conversion also preserves world X/Z under a transformed scene parent.
    const local=new THREE.Vector3(origin.x,y,origin.z);if(car.object.parent)car.object.parent.worldToLocal(local);
    car.object.position.copy(local);car.object.updateWorldMatrix(true,false);
    atEngine=sampleVehicleEngineHighPoint({THREE,car});
  }
  // Rising support (bank/solid obstacle) wins immediately; dry scenes are exact NOOPs.
  const finalEngineWater=atEngine?validWater(waterAt(atEngine.x,atEngine.z)):null;
  const engineDepth=atEngine&&finalEngineWater?finalEngineWater.level-atEngine.y:0;
  if(finalEngineWater&&atEngine&&engineDepth>=VEHICLE_WATER_RULES.floodTolerance)record.latched=true;
  const finalEnvelope=bodyEnvelope(THREE,car),currentWater=centreWater||finalEngineWater;
  const inWater=!!currentWater&&(finalEnvelope?.bottom??y)<=currentWater.level+VEHICLE_WATER_RULES.contactTolerance;
  const depth=inWater?Math.max(0,currentWater.level-(finalEnvelope?.bottom??y)):0;
  Object.assign(w,{engineDisabled:record.latched,flooded:record.latched,
    submerged:!!currentWater&&!!finalEnvelope&&finalEnvelope.top<currentWater.level,
    sunk:record.latched&&inWater&&Math.abs(y-supportY)<.003&&velocityY===0,inWater,y,velocityY,supportY,
    waterLevel:currentWater?.level??null,engineY:atEngine?.y??null,engineDepth,depth,
    drag:inWater?.3+3*clamp(depth/1.5,0,1):0,engineAnchor:atEngine?.source||'missing',enginePart:atEngine?.part||null});
  record.initialized=true;state.waterState=w;return w;
}

/** Idempotent composition; the base damage object is never changed. No momentum reset.
 * Apply BEFORE stepCar; engineDisabled gates its torque, rollingDrag slows coasting.
 */
export function mergeWaterDriveEffects(state,baseCrashEffects={}){
  const water=state?.waterState,drag=Math.max(0,finite(water?.drag));
  const baseDrag=Math.max(0,finite(baseCrashEffects.rollingDrag)-Math.max(0,finite(baseCrashEffects.waterDrag)));
  return {...baseCrashEffects,engineDisabled:!!baseCrashEffects.engineDisabled||!!water?.engineDisabled,
    ...(water?.engineDisabled?{powerFactor:0}:{}),rollingDrag:baseDrag+drag,waterDrag:drag};
}

/** Only the explicit full-demo reset / opted-in local QA fixture may call this.
 * Never call on activation, ordinary repair, exit or synchronization.
 */
export function resetVehicleWater(car,state){
  const record=vehicles.get(car);
  if(record){record.latched=false;Object.assign(record.water,{engineDisabled:false,flooded:false,sunk:false,submerged:false,inWater:false,velocityY:0,drag:0});owners.delete(record.water);}
  vehicles.delete(car);if(state)delete state.waterState;
}
