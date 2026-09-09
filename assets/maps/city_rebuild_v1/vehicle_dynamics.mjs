// Pure local-game vehicle dynamics. +Z forward, +X left, positive yaw turns left.
// Collision/terrain/fleet remain the owners of displacement admission and impulses.
export const VEHICLE_DYNAMICS=Object.freeze({substep:1/120,maxStep:.1,maxSteer:.56,steerSpeed:.035,steerSpeedSquared:.0012,steerResponse:10,steerReturn:12,frontStiffness:36,rearStiffness:42,lateralAcceleration:10,handbrakeRearGrip:.20,gripReleaseRate:18,gripRecoveryRate:5,serviceDeceleration:11,handbrakeDeceleration:12,coastDrag:.75,aeroDrag:.012,yawAssist:3});
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const finite=(v,fallback=0)=>Number.isFinite(v)?v:fallback;
const angleDelta=(a,b)=>Math.atan2(Math.sin(a-b),Math.cos(a-b));
const toward=(v,target,rate,h)=>target+(v-target)*Math.exp(-rate*h);
const tuning=(p,key,min,max)=>clamp(finite(p.dynamics?.[key],VEHICLE_DYNAMICS[key]),min,max);

export function stepVehicleDynamics(state,input={},dt,profile=state.vehicleProfile||{}){
 if(!Number.isFinite(dt)||dt<0||![state.yaw,state.speed].every(Number.isFinite))throw Error('Invalid vehicle dynamics state/time');
 const elapsed=Math.min(VEHICLE_DYNAMICS.maxStep,dt),steps=Math.max(1,Math.ceil(elapsed/VEHICLE_DYNAMICS.substep)),h=elapsed/steps;
 let yaw=state.yaw,travelYaw=finite(state.travelYaw,yaw),speed=state.speed,steer=clamp(finite(state.steer),-.56,.56),yawRate=finite(state.yawRate),rearGripBlend=clamp(finite(state.rearGripBlend,1),.05,1);
 // Never trust cached vx/vz or local velocity: fleet impacts update speed/travelYaw.
 let vx=Math.sin(travelYaw)*speed,vz=Math.cos(travelYaw)*speed,frontSlip=finite(state.frontSlip),rearSlip=finite(state.rearSlip),braking=false;
 const mechanical=state.crashEffects||{},tyre=state.tyreEffects||{},wheelBase=clamp(finite(profile.wheelBase,2.65),1.5,9),frontShare=clamp(finite(profile.dynamics?.frontWeight,.52),.35,.65);
 const a=wheelBase*(1-frontShare),b=wheelBase*frontShare,inertia=Math.max(.8,wheelBase*wheelBase*clamp(finite(profile.dynamics?.yawInertia,.29),.20,.7));
 const pedal=(input.forward?1:0)-(input.reverse?1:0),steeringInput=(input.left?1:0)-(input.right?1:0),handbrake=!!(input.handbrake||input.brake),engineDisabled=!!mechanical.engineDisabled;
 const frontGrip=clamp(finite(tyre.frontGrip,1)*finite(mechanical.frontGrip,1),.025,1.5),rearGrip=clamp(finite(tyre.rearGrip,1)*finite(mechanical.rearGrip,1),.025,1.5),power=clamp(finite(mechanical.powerFactor,1),0,2),speedFactor=clamp(finite(tyre.speedFactor,1)*finite(mechanical.speedFactor,1),0,2),brakeFactor=clamp(finite(mechanical.brakeFactor,1),0,1.5);
 const maxLat=tuning(profile,'lateralAcceleration',3,15),maxSteer=tuning(profile,'maxSteer',.3,.56),cf=tuning(profile,'frontStiffness',10,65),cr=tuning(profile,'rearStiffness',10,65);
 const speedSteer=tuning(profile,'steerSpeed',0,.1),speedSteerSq=tuning(profile,'steerSpeedSquared',0,.006),pull=clamp(finite(tyre.pull)+finite(mechanical.pull),-.5,.5);
 for(let step=0;step<steps;step++){
  const v0=Math.hypot(vx,vz),priorYawRate=yawRate,sin=Math.sin(yaw),cos=Math.cos(yaw);
  const steerLimit=maxSteer/(1+v0*speedSteer+v0*v0*speedSteerSq),targetSteer=steeringInput*steerLimit*clamp(finite(mechanical.steerFactor,1),0,1);
  steer=toward(steer,targetSteer,steeringInput?tuning(profile,'steerResponse',3,20):tuning(profile,'steerReturn',3,20),h);
  const gripTarget=handbrake?tuning(profile,'handbrakeRearGrip',.08,.6):1;
  rearGripBlend=toward(rearGripBlend,gripTarget,handbrake?tuning(profile,'gripReleaseRate',5,30):tuning(profile,'gripRecoveryRate',2,12),h);
  braking=handbrake||!!(pedal&&speed*pedal<0);
  const driveLimit=(pedal<0?finite(profile.reverseSpeed,6):finite(profile.maxSpeed,22))*speedFactor;
  let drag=clamp(finite(mechanical.rollingDrag),0,30);
  if(braking)drag+=(handbrake?tuning(profile,'handbrakeDeceleration',4,18):tuning(profile,'serviceDeceleration',5,18))*brakeFactor;
  else if(!pedal||engineDisabled||v0>driveLimit)drag+=tuning(profile,'coastDrag',0,3)+tuning(profile,'aeroDrag',0,.08)*v0*v0;
  const remain=Math.max(0,v0-drag*h),ratio=v0>0?remain/v0:0;vx*=ratio;vz*=ratio;
  if(!braking&&pedal&&!engineDisabled&&v0<driveLimit){
   const accel=(pedal>0?clamp(finite(profile.acceleration,6.5),0,20):clamp(finite(profile.reverseAcceleration,4.5),0,12))*power;
   vx+=sin*pedal*accel*h;vz+=cos*pedal*accel*h;
   const powered=Math.hypot(vx,vz);if(powered>driveLimit&&powered>v0){vx*=driveLimit/powered;vz*=driveLimit/powered}
  }
  const afterU=vx*sin+vz*cos,afterV=vx*cos-vz*sin,denom=Math.max(3,Math.abs(afterU)),frontSide=afterV+a*yawRate,frontLong=afterU;
  const wheelSide=frontSide*Math.cos(steer)-frontLong*Math.sin(steer),rearSide=afterV-b*yawRate;
  const alphaF=Math.atan(wheelSide/denom),alphaR=Math.atan(rearSide/denom),frontCap=maxLat*frontShare*frontGrip,rearCap=maxLat*(1-frontShare)*rearGrip*rearGripBlend;
  const ff=clamp(-cf*alphaF,-frontCap,frontCap),fr=clamp(-cr*alphaR,-rearCap,rearCap),fx=ff*Math.cos(steer)+fr,fz=-ff*Math.sin(steer);
  vx+=(cos*fx+sin*fz)*h;vz+=(-sin*fx+cos*fz)*h;
  yawRate+=(a*ff*Math.cos(steer)-b*fr)/inertia*h;
  // Small low-speed bicycle assistance avoids tire-model shudder at parking
  // speeds. At speed the axle forces retain lateral velocity and yaw inertia.
  const bicycle=afterU/wheelBase*Math.tan(steer),yawLimit=maxLat*frontGrip/Math.max(2,Math.hypot(vx,vz)),targetYaw=clamp(bicycle,-yawLimit,yawLimit)+pull*Math.min(1,v0/6)*Math.sign(afterU);
  const assist=tuning(profile,'yawAssist',0,8)*(handbrake?.22:1)*(v0<3?2:1);
  yawRate=toward(yawRate,targetYaw,assist,h);
  if(!handbrake&&rearGripBlend>.99&&Math.abs(priorYawRate)<=yawLimit+.02)yawRate=clamp(yawRate,-yawLimit,yawLimit);
  // Passive friction cannot manufacture translational kinetic energy. The
  // bicycle approximation omits wheel spin energy, so cap numerical tyre gain.
  const available=Math.hypot(afterU,afterV),nextSpeed=Math.hypot(vx,vz);
  if(nextSpeed>available&&nextSpeed>0){vx*=available/nextSpeed;vz*=available/nextSpeed}
  if(Math.hypot(vx,vz)<.0001){vx=vz=0;yawRate=toward(yawRate,0,24,h)}
  yaw+=yawRate*h;
  const forward=vx*Math.sin(yaw)+vz*Math.cos(yaw),magnitude=Math.hypot(vx,vz);
  const sign=magnitude?Math.abs(forward)>.01?Math.sign(forward):(Math.sign(speed)||Math.sign(pedal)||1):0;
  speed=magnitude*sign;
  if(magnitude>1e-7){const heading=Math.atan2(vx*(sign||1),vz*(sign||1));travelYaw+=angleDelta(heading,travelYaw)}else if(Math.abs(yawRate)<.001){travelYaw=yaw;yawRate=0}
  const moving=Math.min(1,magnitude/3),slip=angleDelta(yaw,travelYaw);
  frontSlip=moving*Math.max(braking&&!handbrake?.7:0,clamp((Math.abs(cf*alphaF)-frontCap)/Math.max(1,frontCap),0,1));
  rearSlip=moving*Math.max(handbrake?1:0,clamp((Math.abs(alphaR)-.045)*6,0,1));
 }
 const longitudinalVelocity=vx*Math.sin(yaw)+vz*Math.cos(yaw),lateralVelocity=vx*Math.cos(yaw)-vz*Math.sin(yaw);
 return{...state,yaw,speed,travelYaw,steer,yawRate,vx,vz,braking,handbrake,frontSlip,rearSlip,rearGripBlend,longitudinalVelocity,lateralVelocity,slipAngle:angleDelta(yaw,travelYaw)};
}
