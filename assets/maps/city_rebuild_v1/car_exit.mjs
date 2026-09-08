// Moving exit planning and body motion; no browser/rendering dependencies.
import {stepCar,carOverlapsCircle} from './car_drive.mjs';
import {circleFits,movePedestrian} from './walk_motion.mjs';
import {entryPose} from './car_entry.mjs';
import {DRIVER_SEAT} from './car_drive.mjs';
export const EXIT=Object.freeze({tumbleSpeed:15/3.6,releaseSeconds:.55,walkRecovery:.6,tumbleRecovery:1.7,radius:.58});
export const exitKind=speed=>Math.abs(speed)>EXIT.tumbleSpeed?'tumble':'walk';
export function exitLocal(car,side,front=0,y=0){const sin=Math.sin(car.yaw),cos=Math.cos(car.yaw);return {x:car.x+cos*side+sin*front,z:car.z-sin*side+cos*front,y}}
export function departurePoint(car,side,distance,progress){
 const pose=entryPose(progress,true),seat=exitLocal(car,side*DRIVER_SEAT.side+(DRIVER_SEAT.side-side*DRIVER_SEAT.side)*pose.cabinSlide,DRIVER_SEAT.front,DRIVER_SEAT.y),outside=exitLocal(car,side*distance,-.05);
 return {x:outside.x+(seat.x-outside.x)*pose.seat,z:outside.z+(seat.z-outside.z)*pose.seat,y:seat.y*pose.seat+.08*Math.sin(Math.PI*pose.seat),pose};
}
export function planMovingExit(car,preferred,roadAllowed,walkAllowed){
 // Predict the same coasting motion used at runtime, checking the full doorway sweep.
 for(const side of [preferred,-preferred])for(const distance of [1.9,2.4]){
  let predicted={...car},clear=true;
  for(let i=0;i<=44;i++){
   if(i)predicted=stepCar(predicted,{},EXIT.releaseSeconds/44,roadAllowed);
   const p=departurePoint(predicted,side,distance,i/44);
   if(!circleFits(p.x,p.z,walkAllowed,EXIT.radius)){clear=false;break}
  }
  const landing=exitLocal(predicted,side*distance,-.05);
  if(clear&&!carOverlapsCircle(predicted,landing.x,landing.z,EXIT.radius))return {side,distance,kind:exitKind(car.speed),predictedCar:predicted};
 }return null;
}
export function launchExitBody(position,car,side,kind=exitKind(car.speed)){
 const forward=car.travelYaw??car.yaw,inherited=car.speed*(kind==='tumble'?.6:.45),outward=kind==='tumble'?2.4:.8;
 const vx=Math.sin(forward)*inherited+Math.cos(car.yaw)*side*outward,vz=Math.cos(forward)*inherited-Math.sin(car.yaw)*side*outward;
 return {x:position.x,z:position.z,y:0,vx,vz,elapsed:0,kind,heading:Math.atan2(vx,vz),rolls:Math.abs(car.speed)>14?2:1,done:false,blocked:false};
}
export function stepExitBody(body,dt,allowed){
 if(![dt,body.x,body.z,body.vx,body.vz].every(Number.isFinite))throw Error('Invalid exit body');
 dt=Math.min(.1,Math.max(0,dt));const fast=body.kind==='tumble',duration=fast?EXIT.tumbleRecovery:EXIT.walkRecovery;
 const speed=Math.hypot(body.vx,body.vz),nextSpeed=Math.max(0,speed-(fast?9:6)*dt),ratio=speed?nextSpeed/speed:0;
 let vx=body.vx*ratio,vz=body.vz*ratio;const delta={x:(body.vx+vx)*.5*dt,z:(body.vz+vz)*.5*dt};
 const moved=movePedestrian(body,delta,allowed,EXIT.radius),blocked=Math.hypot(moved.x-body.x-delta.x,moved.z-body.z-delta.z)>.001;
 if(blocked&&dt>0){vx=(moved.x-body.x)/dt;vz=(moved.z-body.z)/dt}
 const elapsed=Math.min(duration,body.elapsed+dt),progress=elapsed/duration,done=progress>=1;
 return {...body,x:moved.x,z:moved.z,y:fast&&elapsed<.3?.28*Math.sin(Math.PI*elapsed/.3):0,vx:done?0:vx,vz:done?0:vz,elapsed,progress,done,blocked};
}
