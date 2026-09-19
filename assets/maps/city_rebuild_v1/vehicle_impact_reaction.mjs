// Presentation only. Contact normals point out of the car towards the obstacle.
// This module never writes velocity, vehicle transforms, damage or seat ownership.
export const VEHICLE_IMPACT_REACTION=Object.freeze({frequency:16,damping:.58,maxOffset:.12,maxVelocity:3.8,torsoPitch:.13,torsoRoll:.09,headPitch:.06,headRoll:.04,carAngle:.012,minImpactSpeed:.25,fullImpactSpeed:18});
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const finite=v=>Number.isFinite(v);
function spring(x,v,dt){
 const w=VEHICLE_IMPACT_REACTION.frequency,a=w*VEHICLE_IMPACT_REACTION.damping,b=w*Math.sqrt(1-VEHICLE_IMPACT_REACTION.damping**2),e=Math.exp(-a*dt),c=Math.cos(b*dt),s=Math.sin(b*dt);
 return [e*(x*c+(v+a*x)*s/b),e*(v*c-(a*v+w*w*x)*s/b)];
}
export function createVehicleImpactReaction(){
 let x=0,z=0,vx=0,vz=0,time=0,lastAt=-Infinity,lastStrength=0,count=0;
 const events=new Set();
 function reset(){x=z=vx=vz=time=count=lastStrength=0;lastAt=-Infinity;events.clear()}
 function impact(contact,{yaw=0}={}){
  const speed=contact?.deltaV??contact?.impactSpeed,n=contact?.normal;
  if(!finite(speed)||speed<=VEHICLE_IMPACT_REACTION.minImpactSpeed||!n||![n.x,n.z,yaw].every(finite))return false;
  const length=Math.hypot(n.x,n.z);if(length<1e-7)return false;
  const id=contact.eventId;if(id!=null&&events.has(id))return false;
  const strength=clamp((speed-VEHICLE_IMPACT_REACTION.minImpactSpeed)/(VEHICLE_IMPACT_REACTION.fullImpactSpeed-VEHICLE_IMPACT_REACTION.minImpactSpeed),0,1);
  if(time-lastAt<.075&&strength<=lastStrength*1.1)return false;
  if(id!=null){events.add(id);if(events.size>64)events.delete(events.values().next().value)}
  const nx=n.x/length,nz=n.z/length,c=Math.cos(yaw),s=Math.sin(yaw),impulse=3.8*strength;
  vx+=(nx*c-nz*s)*impulse;vz+=(nx*s+nz*c)*impulse;
  const velocity=Math.hypot(vx,vz);if(velocity>VEHICLE_IMPACT_REACTION.maxVelocity){vx*=VEHICLE_IMPACT_REACTION.maxVelocity/velocity;vz*=VEHICLE_IMPACT_REACTION.maxVelocity/velocity}
  lastAt=time;lastStrength=strength;count++;return true;
 }
 function sample(){
  const length=Math.hypot(x,z),scale=length>VEHICLE_IMPACT_REACTION.maxOffset?VEHICLE_IMPACT_REACTION.maxOffset/length:1,side=x*scale,forward=z*scale,ux=side/VEHICLE_IMPACT_REACTION.maxOffset,uz=forward/VEHICLE_IMPACT_REACTION.maxOffset;
  return {active:Math.hypot(x,z,vx,vz)>1e-5,impacts:count,local:{x:side,z:forward},torso:{pitch:uz*VEHICLE_IMPACT_REACTION.torsoPitch,roll:-ux*VEHICLE_IMPACT_REACTION.torsoRoll},head:{pitch:uz*VEHICLE_IMPACT_REACTION.headPitch,roll:-ux*VEHICLE_IMPACT_REACTION.headRoll},car:{pitch:uz*VEHICLE_IMPACT_REACTION.carAngle,roll:-ux*VEHICLE_IMPACT_REACTION.carAngle,heave:-Math.hypot(side,forward)*.12},camera:{x:side,y:-Math.hypot(side,forward)*.16,z:forward}};
 }
 function update(dt){
  if(!finite(dt)||dt<0)throw Error('Invalid impact reaction timestep');time+=dt;
  if(dt>8){x=z=vx=vz=0;return sample()}
  [x,vx]=spring(x,vx,dt);[z,vz]=spring(z,vz,dt);
  if(Math.hypot(x,z,vx,vz)<1e-8)x=z=vx=vz=0;
  return sample();
 }
 return{impact,update,sample,reset};
}

// Call after the ordinary seated pose every frame, never during entry/exit.
// The neutral pose supplies hand targets; IK keeps palms on the rotating rim.
// Real skinned bounds limit the response to the already-authored cabin envelope.
export function createVehicleOccupantImpactPose(T){
 const cache=new WeakMap(),names=['chest','neck','head','upperarm_l','forearm_l','hand_l','upperarm_r','forearm_r','hand_r'];
 function prepare(hero){
  let c=cache.get(hero);if(c)return c;const context=hero.artistContext?.();if(!context)return null;
  c={context,gains:new WeakMap(),rest:names.map(name=>({bone:context.bones[name],matrix:new T.Matrix4()})).filter(row=>row.bone),meshes:[],point:new T.Vector3(),inverse:new T.Matrix4(),bounds:new T.Box3(),baseline:new T.Box3(),handL:new T.Vector3(),handR:new T.Vector3(),qL:new T.Quaternion(),qR:new T.Quaternion()};
  hero.object.traverse(mesh=>{if(mesh.isMesh&&mesh.geometry?.attributes?.position)c.meshes.push(mesh)});cache.set(hero,c);return c;
 }
 function skinBounds(c,hero,car){
  hero.object.updateMatrixWorld(true);car.object.updateWorldMatrix(true,false);c.inverse.copy(car.object.matrixWorld).invert();c.bounds.makeEmpty();
  for(const mesh of c.meshes){if(mesh.isSkinnedMesh)mesh.skeleton.update();const pos=mesh.geometry.attributes.position;
   for(let i=0;i<pos.count;i++){c.point.fromBufferAttribute(pos,i);if(mesh.isSkinnedMesh)mesh.applyBoneTransform(i,c.point);c.point.applyMatrix4(mesh.matrixWorld).applyMatrix4(c.inverse);c.bounds.expandByPoint(c.point)}
  }return c.bounds;
 }
 function apply(hero,car,seatId,reaction){
  if(!reaction?.active)return{applied:false,gain:0};
  const seat=car.seats?.find(s=>s.id===seatId)||(!car.seats&&car.interior?.anchors&&['front_left','front_right','rear_left','rear_right'].includes(seatId)?{id:seatId,canDrive:seatId==='front_left'}:null),c=prepare(hero);if(!c||!seat)return{applied:false,gain:0};
  const ctx=c.context;let voidBox=car.diagnostics?.().interiorVoid;
  if(!voidBox){const floor=car.interior?.object.getObjectByName('Cabin_floor'),anchors=car.interior?.anchors;if(floor?.geometry&&finite(anchors?.roofBottom)){car.object.updateWorldMatrix(true,true);floor.geometry.computeBoundingBox();const local=floor.geometry.boundingBox.clone().applyMatrix4(new T.Matrix4().copy(car.object.matrixWorld).invert().multiply(floor.matrixWorld));voidBox={min:[local.min.x,anchors.floorTop,local.min.z],max:[local.max.x,anchors.roofBottom,local.max.z]}}}
  // A car without an authored cabin envelope keeps camera recoil only.
  if(!voidBox||!ctx.rotateAdd||!ctx.reachPalm||!ctx.bones.socket_hand_l||!ctx.bones.socket_hand_r)return{applied:false,gain:0};
  for(const row of c.rest)row.matrix.copy(row.bone.matrix);
  ctx.bones.socket_hand_l.getWorldPosition(c.handL);ctx.bones.socket_hand_r.getWorldPosition(c.handR);ctx.bones.hand_l.getWorldQuaternion(c.qL);ctx.bones.hand_r.getWorldQuaternion(c.qR);
  // `rotateAdd` below reads/writes local bone matrices only. Defer the world
  // traversal until those local edits are complete, while final restoration
  // still flushes matrices before returning to ordinary rendering.
  const restore=(flush=true)=>{for(const row of c.rest){row.bone.matrix.copy(row.matrix);row.bone.matrixWorldNeedsUpdate=true}if(flush)hero.object.updateMatrixWorld(true)};
  const pitch=clamp(reaction.torso.pitch,-VEHICLE_IMPACT_REACTION.torsoPitch,VEHICLE_IMPACT_REACTION.torsoPitch),roll=clamp(reaction.torso.roll,-VEHICLE_IMPACT_REACTION.torsoRoll,VEHICLE_IMPACT_REACTION.torsoRoll),hp=clamp(reaction.head.pitch,-VEHICLE_IMPACT_REACTION.headPitch,VEHICLE_IMPACT_REACTION.headPitch),hr=clamp(reaction.head.roll,-VEHICLE_IMPACT_REACTION.headRoll,VEHICLE_IMPACT_REACTION.headRoll);
  function pose(gain,headOnly=false,probe=false){
   restore(false);const p=probe?Math.sign(pitch)*VEHICLE_IMPACT_REACTION.torsoPitch:pitch,r=probe?Math.sign(roll)*VEHICLE_IMPACT_REACTION.torsoRoll:roll,hp0=probe?Math.sign(hp)*VEHICLE_IMPACT_REACTION.headPitch:hp,hr0=probe?Math.sign(hr)*VEHICLE_IMPACT_REACTION.headRoll:hr;
   if(!headOnly)ctx.rotateAdd('chest',p*gain,0,r*gain);ctx.rotateAdd('neck',hp0*gain*.4,0,hr0*gain*.4);ctx.rotateAdd('head',hp0*gain*.6,0,hr0*gain*.6);hero.object.updateMatrixWorld(true);
   if(seat.canDrive&&!headOnly){ctx.reachPalm('l',c.handL,c.qL);ctx.reachPalm('r',c.handR,c.qR);hero.object.updateMatrixWorld(true)}
  }
  const palmsSafe=()=>!seat.canDrive||ctx.bones.socket_hand_l.getWorldPosition(c.point).distanceTo(c.handL)<.003&&ctx.bones.socket_hand_r.getWorldPosition(c.point).distanceTo(c.handR)<.003;
  let safe=c.gains.get(car);if(!safe){safe=new Map();c.gains.set(car,safe)}
  // Probe the full signed angular envelope once per seat/steering region. Later
  // frames use the smaller analytic sample; no repeated full skin traversal.
  // Only the driver reaches back to the rotating rim. Passenger pose, skin
  // bounds and palm rule are independent of wheel angle, so steering must not
  // make that exact certificate cold again while the car is turning.
  const steeringRegion=seat.canDrive?Math.round((car.interior?.steeringWheel?.rotation.z||0)*10):'passenger';
  const key=seatId+':'+Math.sign(pitch)+':'+Math.sign(roll)+':'+steeringRegion;
  const known=safe.get(key);
  if(known){if(!known.gain)return{applied:false,gain:0,cached:true};pose(known.gain,known.headOnly);if(palmsSafe())return{applied:true,...known,cached:true};restore();return{applied:false,gain:0,cached:true}}
  c.baseline.copy(skinBounds(c,hero,car));
  // Do not worsen any pre-existing microscopic neutral clearance discrepancy.
  const min=[Math.min(voidBox.min[0]+.005,c.baseline.min.x),Math.min(voidBox.min[1]+.012,c.baseline.min.y),Math.min(voidBox.min[2]+.005,c.baseline.min.z)],max=[Math.max(voidBox.max[0]-.005,c.baseline.max.x),Math.max(voidBox.max[1]-.015,c.baseline.max.y),Math.max(voidBox.max[2]-.005,c.baseline.max.z)];
  let rejected=null;for(const headOnly of [false,true])for(const gain of [1,.5,.25,.125,.0625,.03125]){
   pose(gain,headOnly,true);
   const box=skinBounds(c,hero,car),lo=box.min.toArray(),hi=box.max.toArray();
   rejected={palms:palmsSafe(),low:lo.map((v,i)=>v-min[i]),high:hi.map((v,i)=>max[i]-v)};
   if(palmsSafe()&&lo.every((v,i)=>v>=min[i]-1e-7)&&hi.every((v,i)=>v<=max[i]+1e-7)){
    // IK skin extrema need not be monotone with torso angle; also certify the
    // interior of the recoil envelope before caching a full-strength result.
    let clear=true;for(const fraction of [.75,.5,.25,.1,.03]){pose(gain*fraction,headOnly,true);const b=skinBounds(c,hero,car);if(!palmsSafe()||!b.min.toArray().every((v,i)=>v>=min[i]-1e-7)||!b.max.toArray().every((v,i)=>v<=max[i]+1e-7)){clear=false;break}}
    if(clear){safe.set(key,{gain,headOnly});pose(gain,headOnly);return{applied:true,gain,headOnly,cached:false}}
   }
  }
  restore();safe.set(key,{gain:0});return{applied:false,gain:0,cached:false,rejected};
 }
 return{apply};
}
