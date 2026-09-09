import {createVehicleImpactReaction} from './vehicle_impact_reaction.mjs';
import {buildVehicleCollisionShape} from './vehicle_collision_shape.mjs';
// Shared /walk fleet ownership. The active vehicle is driven by walk's input;
// every other vehicle retains its own damage and passive rigid-body motion.
import {CAR,carCorners,carFits,carOverlapsCircle} from './car_drive.mjs';
import {polygonVehicleContact,contactKinematics} from './vehicle_contact.mjs';
import {resolveVehiclePairImpulse} from './vehicle_pair_impulse.mjs';
import {createVehicleDamage} from './vehicle_damage.mjs';
import {createVehicleRollover} from './vehicle_rollover.mjs';
import {createTyreDamage} from './tyre_damage.mjs';
import {createVehicleTrunk} from './vehicle_trunk.mjs';
import {createVehicleHood} from './vehicle_hood.mjs';
import {mergeWaterDriveEffects,resetVehicleWater} from './vehicle_water_state.mjs';

const finite=(value,fallback=0)=>Number.isFinite(value)?value:fallback;
const approach=(value,amount)=>Math.sign(value)*Math.max(0,Math.abs(value)-amount);
const velocity=state=>({vx:Math.sin(state.travelYaw??state.yaw)*state.speed,vz:Math.cos(state.travelYaw??state.yaw)*state.speed});
const profileOf=car=>({...CAR,massKg:finite(car.object?.userData?.massKg,1500),...car.profile});

export function createVehicleFleet(T,{scene,RoundedBox,world=()=>()=>true,groundHeight=()=>0,pose=null,getHero=()=>null,onExplosion=()=>{}}={}){
 if(!scene||!RoundedBox)throw Error('Fleet requires scene and RoundedBox');
 const records=[],byId=new Map(),wrappers=new WeakMap(),pairDamageTimes=new Map();
 let activeRecord=null,time=0,disposed=false,sequence=0,contacts=0,lastImpulse=null,parkedCache=[],parkedCacheActive=null,parkedCacheCount=-1;
 const parkedRecords=()=>{if(parkedCacheActive!==activeRecord||parkedCacheCount!==records.length){parkedCache=records.filter(record=>record!==activeRecord);parkedCacheActive=activeRecord;parkedCacheCount=records.length;}return parkedCache;};
 const idOf=value=>typeof value==='string'?value:value?.id;
 const shape=record=>record.state.vehicleProfile||record.car.profile||CAR;
 const mass=record=>Math.max(400,Math.min(40000,finite(shape(record).massKg,finite(record.car.object.userData.massKg,1500))));
 function fromVelocity(state,vx,vz,yawRate=state.yawRate||0){
  state.vx=finite(vx);state.vz=finite(vz);state.yawRate=finite(yawRate);
  const speed=Math.hypot(state.vx,state.vz);
  if(speed<.025){state.speed=state.vx=state.vz=0;state.travelYaw=state.yaw;return state}
  const sign=state.vx*Math.sin(state.yaw)+state.vz*Math.cos(state.yaw)<0?-1:1;
  state.speed=sign*speed;state.travelYaw=Math.atan2(state.vx*sign,state.vz*sign);return state;
 }
 function initialState(car,spawn={}){
  const yaw=finite(spawn.yaw),profile=profileOf(car),state={x:finite(spawn.x),z:finite(spawn.z),yaw,speed:finite(spawn.speed),travelYaw:finite(spawn.travelYaw,yaw),steer:0,yawRate:0,distance:0,bumped:false,contact:null,frontSlip:0,rearSlip:0,vehicleProfile:profile,seats:car.seats,...spawn};
  Object.assign(state,velocity(state));return state;
 }
 function render(record,dt,animate=true){
  const {car,state,roll,damage,tyres,trunk,hood}=record;
  const rollAngle=roll?.angle,restAngle=Number.isFinite(rollAngle)?rollAngle:roll?.stats?.().angle||0;
  // A parked dry car has a stable terrain/water pose.  Re-sampling its four
  // wheel supports, engine vertex and water envelope every render frame was
  // pure duplicate work (the pose is invalidated by movement, yaw or roll).
  // Never reuse a wet pose: sinking/flooding remains simulated each frame.
  const cachedPose=record.staticPose;
  const poseUnchanged=animate&&cachedPose&&cachedPose.x===state.x&&cachedPose.z===state.z&&cachedPose.yaw===state.yaw&&cachedPose.angle===restAngle&&!cachedPose.wet&&!roll?.unstable&&
   Math.abs(finite(state.vx))<.025&&Math.abs(finite(state.vz))<.025&&Math.abs(finite(state.yawRate))<.001;
  if(!poseUnchanged){
   car.object.position.set(state.x,0,state.z);car.object.rotation.y=state.yaw;
   roll?.update?.(dt);const currentRoll=roll?.angle,angle=Number.isFinite(currentRoll)?currentRoll:roll?.stats?.().angle||0;
   if(pose)pose(car,state,angle,dt);else car.object.position.y+=finite(groundHeight(state.x,state.z));
   record.staticPose={x:state.x,z:state.z,yaw:state.yaw,angle,wet:!!state.waterState?.inWater};
  }
  if(animate){record.impactReaction?.update(dt);car.update?.(state,state.braking);tyres?.update?.(state,dt);damage?.update?.(dt);damage?.crash?.applyWheels?.({tyres:tyres?.state});trunk?.update?.(dt,{vehicleState:state,damageState:damage?.state});hood?.update?.(dt,{vehicleState:state,damageState:damage?.state,crashState:damage?.crash?.state})}
 }
 function addCar(carOrRecord,spawn={}){
  if(disposed)throw Error('Fleet is disposed');
  const supplied=carOrRecord?.car?carOrRecord:null,car=supplied?.car||carOrRecord;
  if(!car?.object)throw Error('Fleet vehicle needs an object');
  if(records.some(r=>r.car===car))return records.find(r=>r.car===car);
  let id=supplied?.id||car.profile?.id||car.object.userData.vehicleModelId||'red_sedan';
  if(byId.has(id)){const base=id;do{id=base+'_'+(++sequence)}while(byId.has(id))}
  if(!car.object.parent)scene.add(car.object);
  // Capture the physical footprint once, before damage. Seating/admission and
  // water retain their authored profile dimensions; only contact uses the hull.
  if(!car.profile?.collisionHull&&(car.wheels?.length||car.shell?.length))car.profile={...car.profile,...buildVehicleCollisionShape(T,car)};
  const state=supplied?.state||initialState(car,spawn);
  state.vehicleProfile={...profileOf(car),...state.vehicleProfile};state.seats=car.seats||state.seats;
  state.travelYaw??=state.yaw;Object.assign(state,velocity(state));
  const record={id,car,state,impactReaction:supplied?.impactReaction||createVehicleImpactReaction(),spawn:{x:state.x,z:state.z,yaw:state.yaw},damage:null,roll:null,tyres:null,trunk:null,hood:null,mapColor:car.object.userData.mapColor||car.profile?.mapColor||'#a75048'};
  record.trunk=supplied?.trunk||car.trunk||createVehicleTrunk(T,RoundedBox,car,{scene,groundHeight});car.trunk=record.trunk;
  record.hood=supplied?.hood||car.hood||createVehicleHood(T,RoundedBox,car,{scene,groundHeight});car.hood=record.hood;
  record.damage=supplied?.damage||createVehicleDamage(T,car,{scene,groundHeight,allowed:(x,z)=>world()(x,z),getState:()=>record.state,trunk:record.trunk,profile:{maxHp:Math.max(240,Math.min(1200,Math.round(mass(record)*.16)))},onExplosion:event=>onExplosion({...event,record})});
  record.roll=supplied?.roll||createVehicleRollover(T,car);
  record.tyres=supplied?.tyres||createTyreDamage(T,car,{groundHeight});
  car.object.userData.vehicleFleetId=id;car.object.userData.receiveCollision=contact=>notifyContact(record,contact);records.push(record);byId.set(id,record);
  if(!activeRecord)activeRecord=record;
  render(record,0,false);return record;
 }
 function activate(value){
  const target=byId.get(idOf(value));if(!target)throw Error('Unknown fleet vehicle '+idOf(value));
  if(activeRecord){Object.assign(activeRecord.state,velocity(activeRecord.state));activeRecord.state.distance=0;}
  activeRecord=target;fromVelocity(target.state,target.state.vx,target.state.vz,target.state.yawRate);target.state.distance=0;
  return target;
 }
 function syncActive(state){
  if(!activeRecord)return null;
  activeRecord.state=state;state.vehicleProfile??=profileOf(activeRecord.car);state.seats??=activeRecord.car.seats;Object.assign(state,velocity(state));return activeRecord;
 }
 function contactAt(x,z,yaw,vehicleShape=shape(activeRecord),ignore=activeRecord?.id){
  const corners=carCorners(x,z,yaw,vehicleShape);let best=null;
  for(const other of records){if(other.id===ignore)continue;const s=other.state;
   const limit=vehicleShape.halfLength+shape(other).halfLength+vehicleShape.halfWidth+shape(other).halfWidth;
   if(Math.abs(x-s.x)>limit||Math.abs(z-s.z)>limit)continue;
   const hit=polygonVehicleContact(corners,carCorners(s.x,s.z,s.yaw,shape(other)));
   if(hit&&(!best||hit.depth>best.depth))best={...hit,otherVehicle:other.id};
  }return best;
 }
 function blockingWorld(base){
  if(wrappers.has(base))return wrappers.get(base);
  const allowed=(x,z)=>base(x,z)&&!overlaps(x,z,0,activeRecord?.id);
  allowed.poseAllowed=(x,z,yaw,vehicleShape=activeRecord?shape(activeRecord):CAR)=>carFits(x,z,yaw,base,vehicleShape)&&!contactAt(x,z,yaw,vehicleShape);
  allowed.contactAt=(x,z,yaw,vehicleShape=activeRecord?shape(activeRecord):CAR)=>contactAt(x,z,yaw,vehicleShape)||base.contactAt?.(x,z,yaw,vehicleShape);
  wrappers.set(base,allowed);return allowed;
 }
 function body(record,state=record.state){
  const v=record===activeRecord?velocity(state):{vx:finite(state.vx),vz:finite(state.vz)};
  return {...state,...v,mass:mass(record),halfWidth:shape(record).collisionHalfWidth??shape(record).halfWidth,halfLength:shape(record).collisionHalfLength??shape(record).halfLength};
 }
 function notifyContact(record,contact){
  // Passive bodies can travel several substeps since their last visible pose.
  // Contact rays/deformation must use the current body transform.
  render(record,0,false);record.car.object.updateWorldMatrix(true,true);
  const damaged=record.damage?.contactImpact?.(contact),rolled=record.roll?.impact?.(contact,record.state.yaw),reacted=record.impactReaction?.impact(contact,{yaw:record.state.yaw});return !!(damaged||rolled||reacted);
 }
 function resolvePair(a,b,contact,{before=a.state,after=a.state}={}){
  const incoming=body(a,before);
  if(contact.incomingPose&&contact.velocity){Object.assign(incoming,contact.incomingPose,{vx:contact.velocity.x,vz:contact.velocity.z,yawRate:contact.incomingYawRate??incoming.yawRate});}
  const result=resolveVehiclePairImpulse(incoming,body(b),contact);if(!result.resolved)return result;
  fromVelocity(after,result.a.vx,result.a.vz,result.a.yawRate);if(a===activeRecord)a.state=after;
  fromVelocity(b.state,result.b.vx,result.b.vz,result.b.yawRate);
  contacts++;lastImpulse={a:a.id,b:b.id,...result};
  const key=[a.id,b.id].sort().join('|');
  if(time-(pairDamageTimes.get(key)??-Infinity)>=.25){
   pairDamageTimes.set(key,time);
   const first={...contact,impactSpeed:result.deltaVA,slideSpeed:0,velocity:{x:result.a.vx,y:0,z:result.a.vz},eventId:`fleet:${key}:${time}`};
   const second={...contact,normal:{x:-contact.normal.x,y:-finite(contact.normal.y),z:-contact.normal.z},impactSpeed:result.deltaVB,slideSpeed:0,velocity:{x:result.b.vx,y:0,z:result.b.vz},eventId:first.eventId};
   notifyContact(a,first);notifyContact(b,second);
  }
  return result;
 }
 function resolve(before,after,contact){
  const other=byId.get(contact?.otherVehicle);if(!activeRecord||!other||other===activeRecord)return null;
  return resolvePair(activeRecord,other,contact,{before,after});
 }
 function update(dt){
  if(disposed)return;if(!Number.isFinite(dt)||dt<0)throw Error('Invalid fleet timestep');
  const elapsed=Math.min(dt,.1);time+=elapsed;
  const parked=parkedRecords(),steps=Math.max(1,Math.ceil(elapsed*120)),h=elapsed/steps;
  for(const r of parked){r.state.distance=0;r.state.contact=null;r.state.bumped=false;r.state.throttle=0;r.state.handbrake=false;r.state.braking=false;r.state.crashEffects=r.damage?.crashEffects;r.state.tyreEffects=r.tyres?.effects;}
  for(let i=0;i<steps;i++)for(const record of parked){
   const s=record.state;
   if(Math.hypot(s.vx||0,s.vz||0)<.025&&Math.abs(s.yawRate||0)<.001){fromVelocity(s,0,0,0);continue}
   const x=s.x+s.vx*h,z=s.z+s.vz*h,yaw=s.yaw+(s.yawRate||0)*h,vehicleShape=shape(record),hit=contactAt(x,z,yaw,vehicleShape,record.id);
   if(hit){resolvePair(record,byId.get(hit.otherVehicle),hit);s.bumped=true;s.contact=hit}
   else if(carFits(x,z,yaw,world(),vehicleShape)){const sign=s.speed<0?-1:1;s.distance+=Math.hypot(x-s.x,z-s.z)*sign;s.x=x;s.z=z;s.yaw=yaw;}
   else{
    const wall=world().contactAt?.(x,z,yaw,vehicleShape);s.bumped=true;
    if(wall){const contact=contactKinematics(wall,s.speed,s.travelYaw);s.contact=contact;notifyContact(record,contact);const normalSpeed=Math.max(0,s.vx*wall.normal.x+s.vz*wall.normal.z);s.vx-=wall.normal.x*normalSpeed*1.08;s.vz-=wall.normal.z*normalSpeed*1.08;s.yawRate*=.6;}
    else{s.vx=s.vz=s.yawRate=0}
   }
   const speed=Math.hypot(s.vx,s.vz),mechanical=mergeWaterDriveEffects(s,record.damage?.crashEffects||{}),tyre=record.tyres?.effects||{};
   const drag=.65+finite(mechanical.rollingDrag)+(1-finite(tyre.speedFactor,1))*1.5+.009*speed*speed+(record.roll?.unstable||record.damage?.disabled?5.5:0);
   const next=approach(speed,drag*h),ratio=speed>0?next/speed:0;
   fromVelocity(s,s.vx*ratio,s.vz*ratio,(s.yawRate||0)*Math.exp(-2*h));
  }
  for(const record of parked)render(record,elapsed);
 }
 function overlaps(x,z,radius=.36,ignoreId=null){return records.some(record=>record.id!==idOf(ignoreId)&&carOverlapsCircle(record.state,x,z,radius))}
 function nearby(point,range=12){
  const limit=typeof range==='object'?(range.range??12):range;
  return records.map(record=>({record,distance:Math.hypot(record.state.x-point.x,record.state.z-point.z)})).filter(item=>item.distance<=limit+shape(item.record).halfLength).sort((a,b)=>a.distance-b.distance).map(item=>item.record);
 }
 function findSpawn(profile,origin,{topology=null,hero=getHero(),maxRadius=240,meters=4.1,spacing=.70}={}){
  const vehicleShape={...CAR,...profile},padded={...vehicleShape,halfWidth:vehicleShape.halfWidth+spacing,halfLength:vehicleShape.halfLength+spacing,collisionPadding:vehicleShape.collisionHull?(vehicleShape.collisionPadding||0)+spacing:0};
  const hx=hero?.object?.position?.x??hero?.x,hz=hero?.object?.position?.z??hero?.z;
  const originYaw=finite(origin.yaw),base=world(),roadAt=(x,z)=>!!topology?.roadMask?.[Math.floor(z/meters)]?.[Math.floor(x/meters)];
  const rings=[0];for(let r=12;r<=maxRadius;r+=9)rings.push(r);
  const preferred=topology?.roadMask?[true,false]:[false];
  for(const roadOnly of preferred)for(const radius of rings){
   const count=radius?Math.max(12,Math.ceil(2*Math.PI*radius/10)):1;
   for(let i=0;i<count;i++){
    const angle=originYaw+i/count*Math.PI*2,x=origin.x+Math.sin(angle)*radius,z=origin.z+Math.cos(angle)*radius;
    if(roadOnly&&!roadAt(x,z))continue;
    for(const yaw of [originYaw,originYaw+Math.PI/2,0,Math.PI/2]){
     if(!carFits(x,z,yaw,base,padded)||contactAt(x,z,yaw,padded,null))continue;
     if(Number.isFinite(hx)&&Number.isFinite(hz)&&carOverlapsCircle({x,z,yaw,vehicleProfile:padded},hx,hz,.8))continue;
     return {x,z,yaw};
    }
   }
  }return null;
 }
 function reset(){
  pairDamageTimes.clear();time=contacts=0;lastImpulse=null;
  for(const record of records){resetVehicleWater(record.car,record.state);record.impactReaction?.reset();record.damage?.reset?.();record.tyres?.reset?.();record.roll?.reset?.();record.trunk?.reset?.();record.hood?.reset?.();record.state=initialState(record.car,record.spawn);render(record,0,false)}
  return activeRecord;
 }
 function dispose(){
  if(disposed)return;disposed=true;
  for(const record of records){record.damage?.dispose?.();record.tyres?.dispose?.();record.trunk?.dispose?.();record.hood?.dispose?.();record.roll?.dispose?.();
   delete record.car.object.userData.receiveCollision;
   const geometries=new Set(),materials=new Set();record.car.object.traverse(n=>{if(n.geometry)geometries.add(n.geometry);for(const m of Array.isArray(n.material)?n.material:n.material?[n.material]:[])materials.add(m)});
   record.car.object.removeFromParent();for(const g of geometries)g.dispose();for(const m of materials)m.dispose();
  }
  records.length=0;parkedCache=[];parkedCacheActive=null;parkedCacheCount=0;byId.clear();pairDamageTimes.clear();activeRecord=null;
 }
 return {records,addCar,activate,syncActive,blockingWorld,resolve,update,overlaps,nearby,findSpawn,reset,dispose,get active(){return activeRecord},get activeId(){return activeRecord?.id??null},stats:()=>({activeId:activeRecord?.id??null,count:records.length,contacts,lastImpulse,vehicles:records.map(record=>({id:record.id,massKg:mass(record),mapColor:record.mapColor,state:{...record.state},damage:record.damage?.stats?.(),trunk:record.trunk?.stats?.(),hood:record.hood?.stats?.(),impactReaction:record.impactReaction?.sample(),roll:record.roll?.stats?.()}))})};
}
