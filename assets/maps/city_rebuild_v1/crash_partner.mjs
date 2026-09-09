import {createDemoCar,carFits,carCorners,carOverlapsCircle} from './car_drive.mjs';
import {createVehicleDamage} from './vehicle_damage.mjs';
import {createVehicleRollover} from './vehicle_rollover.mjs';
import {polygonVehicleContact} from './vehicle_contact.mjs';
import {resolveVehiclePairImpulse} from './vehicle_pair_impulse.mjs';
export function createCrashPartner(T,{scene,RoundedBox,mainCar,mainState,world,mainDamage,mainRoll,onExplosion=()=>{}}){
 const initial=mainState();let spawn=null;
 for(const front of [14,20,10,26])for(const side of [0,6,-6]){const yaw=initial.yaw+Math.PI/2,x=initial.x+Math.sin(initial.yaw)*front+Math.cos(initial.yaw)*side,z=initial.z+Math.cos(initial.yaw)*front-Math.sin(initial.yaw)*side;if(!spawn&&carFits(x,z,yaw,world()))spawn={x,z,yaw}}
 if(!spawn)return null;
 const car=createDemoCar(T,RoundedBox);scene.add(car.object);car.object.userData.massKg=1500;mainCar.object.userData.massKg=1500;
 let state={...spawn,vx:0,vz:0,yawRate:0},contacts=0,lastImpulse=null;
 car.object.position.set(state.x,0,state.z);car.object.rotation.y=state.yaw;
 const roll=createVehicleRollover(T,car),damage=createVehicleDamage(T,car,{onExplosion:event=>onExplosion(event)}),wrappers=new WeakMap();
 const mass=c=>Math.max(400,Math.min(40000,Number(c.object.userData.massKg)||1500));
 const contactAt=(x,z,yaw)=>{const hit=polygonVehicleContact(carCorners(x,z,yaw),carCorners(state.x,state.z,state.yaw));return hit?{...hit,otherVehicle:'crash_partner'}:null};
 function blockingWorld(base){if(wrappers.has(base))return wrappers.get(base);const allowed=(x,z)=>base(x,z)&&!carOverlapsCircle(state,x,z,0);allowed.poseAllowed=(x,z,yaw)=>carFits(x,z,yaw,base)&&!contactAt(x,z,yaw);allowed.contactAt=(x,z,yaw)=>contactAt(x,z,yaw)||base.contactAt?.(x,z,yaw);wrappers.set(base,allowed);return allowed}
 function resolve(before,after,contact){
  const a={...before,mass:mass(mainCar),vx:Math.sin(before.travelYaw??before.yaw)*before.speed,vz:Math.cos(before.travelYaw??before.yaw)*before.speed,halfWidth:1.28,halfLength:2.24};
  const b={...state,mass:mass(car),halfWidth:1.28,halfLength:2.24};
  const result=resolveVehiclePairImpulse(a,b,contact);if(!result.resolved)return result;
  contacts++;lastImpulse=result;after.speed=Math.hypot(result.a.vx,result.a.vz);after.travelYaw=Math.atan2(result.a.vx,result.a.vz);after.yawRate=result.a.yawRate;
  state.vx=result.b.vx;state.vz=result.b.vz;state.yawRate=result.b.yawRate;
  const first={...contact,impactSpeed:result.deltaVA,slideSpeed:0},second={...contact,normal:{x:-contact.normal.x,y:0,z:-contact.normal.z},impactSpeed:result.deltaVB,slideSpeed:0};
  mainDamage.contactImpact(first);mainRoll.impact(first,before.yaw);damage.contactImpact(second);roll.impact(second,state.yaw);return result;
 }
 function update(dt){
  // At rest, the partner cannot discover a new contact by integrating zero
  // motion. The main car's resolver assigns velocity before this next update,
  // so the full solver resumes immediately on impact.
  const moving=state.vx!==0||state.vz!==0||state.yawRate!==0;
  const n=moving?Math.max(1,Math.ceil(Math.min(dt,.1)*120)):0,h=n?Math.min(dt,.1)/n:0;
  for(let i=0;i<n;i++){
   const x=state.x+state.vx*h,z=state.z+state.vz*h,yaw=state.yaw+state.yawRate*h;
   const a=mainState(),hit=polygonVehicleContact(carCorners(a.x,a.z,a.yaw),carCorners(x,z,yaw));
   if(hit){resolve(a,a,hit);state.vx*=.8;state.vz*=.8}
   else if(carFits(x,z,yaw,world())){state.x=x;state.z=z;state.yaw=yaw}
   else {const hit=world().contactAt?.(x,z,yaw);if(hit){const speed=Math.max(0,state.vx*hit.normal.x+state.vz*hit.normal.z);damage.contactImpact({...hit,impactSpeed:speed,slideSpeed:0});roll.impact({...hit,impactSpeed:speed},state.yaw)}state.vx=state.vz=state.yawRate=0}
   state.vx*=Math.exp(-1.15*h);state.vz*=Math.exp(-1.15*h);state.yawRate*=Math.exp(-2*h);
  }
  car.object.position.set(state.x,0,state.z);car.object.rotation.y=state.yaw;roll.update(dt);car.update({speed:Math.hypot(state.vx,state.vz),distance:Math.hypot(state.vx,state.vz)*dt,steer:0});damage.update(dt);
 }
 function reset(){damage.reset();roll.reset();state={...spawn,vx:0,vz:0,yawRate:0};car.object.position.set(state.x,0,state.z);car.object.rotation.y=state.yaw;contacts=0;lastImpulse=null}
 function dispose(){damage.dispose();const gs=new Set(),ms=new Set();car.object.traverse(n=>{if(n.geometry)gs.add(n.geometry);for(const m of Array.isArray(n.material)?n.material:n.material?[n.material]:[])ms.add(m)});car.object.removeFromParent();for(const g of gs)g.dispose();for(const m of ms)m.dispose()}
 return{car,damage,roll,blockingWorld,resolve,update,reset,dispose,get state(){return state},overlaps:(x,z,r=.36)=>carOverlapsCircle(state,x,z,r),stats:()=>({massKg:mass(car),mainMassKg:mass(mainCar),contacts,lastImpulse,state:{...state},roll:roll.stats(),damage:damage.stats()})};
}
