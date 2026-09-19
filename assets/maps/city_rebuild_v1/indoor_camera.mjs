// The caller keeps the requested orbit separately from this rendered position.
// A room wall shortens the boom; it must not turn a useful shoulder view into
// an abrupt first-person jump merely because the room is less than 3m deep.
// At the game's 45 degree FOV the stylized head already fills the centre at
// 1.48m (bank wall repro). Protect the view before entering that range, not
// only after the camera reaches the head. Different exit/entry distances keep
// the render mask stable; these limits never push a camera through a wall.
import {createIndoorCameraClearance} from './indoor_camera_clearance.mjs';
export const INDOOR_CAMERA_BODY_CLEARANCE=Object.freeze({hide:1.8,restore:2});
export function createIndoorCamera({THREE:T,resolvePosition}){
 const bodyClearance=createIndoorCameraClearance({THREE:T,resolvePosition});
 const origin=new T.Vector3(),eye=new T.Vector3(),endpoint=new T.Vector3(),direction=new T.Vector3(),forward=new T.Vector3(),look=new T.Vector3(),lastOrigin=new T.Vector3();
 let closeView=false,previousLength=0,initialized=false;
 function reset(){closeView=false;previousLength=0;initialized=false;bodyClearance.reset()}
 function solve({feet,eyeHeight=1.64,desired,target,objects,ceilingY=Infinity,inside=false,aiming=false,dt=1/60}){
  origin.copy(feet);origin.y+=Math.min(eyeHeight,1.45);
  if(!inside){
   const wasClose=closeView;reset();
   const position=resolvePosition({THREE:T,from:origin,desired,objects,ceilingY:aiming?Infinity:ceilingY});
   eye.copy(feet);eye.y+=eyeHeight;
   const headDistance=position.distanceTo(eye),desiredDistance=desired.distanceTo(origin),resolvedDistance=position.distanceTo(origin);
   closeView=headDistance<(wasClose?INDOOR_CAMERA_BODY_CLEARANCE.restore:INDOOR_CAMERA_BODY_CLEARANCE.hide);
   // Preserve the exact legacy exterior boom and aim result.
   // Only the render-time rig mask follows a close wall outside an entrance.
   return{position,target:aiming?target.clone().add(direction.copy(position).sub(desired)):target.clone(),hideHead:closeView,mode:'orbit',headDistance,separation:Math.hypot(position.x-feet.x,position.z-feet.z),desiredDistance,resolvedDistance,collisionLimited:resolvedDistance<desiredDistance-.001,occlusionReason:resolvedDistance<desiredDistance-.001?'exterior-wall':'none'};
  }
  eye.copy(feet);eye.y+=eyeHeight;
  if(Number.isFinite(ceilingY)){eye.y=Math.min(eye.y,ceilingY-.28);origin.y=Math.min(origin.y,ceilingY-.28)}
  endpoint.copy(desired);
  // Resolve one ceiling-safe segment. The legacy resolver compares the high
  // outdoor ray with a lowered ray; a ceiling-constrained room needs the latter.
  // Aiming retains its supplied direction and normal collision segment.
  if(!aiming&&Number.isFinite(ceilingY)&&endpoint.y>origin.y)endpoint.y=Math.min(endpoint.y,Math.max(origin.y,ceilingY-.44));
  const position=resolvePosition({THREE:T,from:origin,desired:endpoint,objects,ceilingY:Infinity});
  direction.copy(position).sub(origin);
  const availableLength=direction.length(),requestedLength=endpoint.distanceTo(origin);
  const seconds=Number.isFinite(dt)?Math.max(0,Math.min(.1,dt)):1/60;
  // Retraction must be immediate to stay in front of a wall. Only recovery is
  // damped. Interpolate distance on this frame's tested segment, never world
  // positions across a corner; mouse yaw/pitch remain responsive throughout.
  if(!initialized||lastOrigin.distanceToSquared(origin)>9){previousLength=availableLength;initialized=true}
  let length=availableLength;
  if(availableLength>previousLength){
   // Exact integration of a damped recovery capped at 8m/s: a suddenly clear
   // 7m boom cannot jump half a metre in one frame, and 30/60Hz agree.
   const gap=availableLength-previousLength,linearTime=Math.max(0,(gap-1)/8);
   length=seconds<=linearTime?previousLength+8*seconds:availableLength-Math.min(gap,1)*Math.exp(-8*(seconds-linearTime));
  }
  if(availableLength>1e-8)position.copy(origin).addScaledVector(direction,length/availableLength);
  previousLength=length;lastOrigin.copy(origin);
  const clearance=bodyClearance.solve({origin,eye,position,desired:endpoint,objects,ceilingY,dt});
  const bodyShift=clearance.position.clone().sub(position);position.copy(clearance.position);
  const headDistance=position.distanceTo(eye),separation=Math.hypot(position.x-feet.x,position.z-feet.z);
  // Mask the actual rig only at near-body distances. This flag has
  // hysteresis, but crossing its threshold never changes camera position.
  closeView=headDistance<(closeView?INDOOR_CAMERA_BODY_CLEARANCE.restore:INDOOR_CAMERA_BODY_CLEARANCE.hide);
  const viewTarget=target.clone();
  if(aiming)viewTarget.add(direction.copy(position).sub(desired));
  else if(clearance.active||bodyShift.lengthSq()>1e-8){
   // Move to a shoulder without turning the player's view/aim into the face.
   viewTarget.copy(position).add(forward.copy(target).sub(desired));
  }
  else if(headDistance<1.4){
   // At the very end of the boom, looking at the shoulder target would pitch
   // sharply up into the face. Blend toward the user's existing view direction.
   forward.copy(target).sub(desired).normalize();if(forward.lengthSq()<.5)forward.set(0,0,1);
   look.copy(target).sub(position).normalize();if(look.lengthSq()<.5)look.copy(forward);
   const t=Math.max(0,Math.min(1,(1.4-headDistance)/.85)),blend=t*t*(3-2*t);
   look.lerp(forward,blend).normalize();viewTarget.copy(position).addScaledVector(look,5);
  }
  const collisionLimited=availableLength<requestedLength-.001;
  const ceilingLimited=endpoint.y!==desired.y,recovering=length<availableLength-.001;
  return{position,target:viewTarget,hideHead:closeView,mode:clearance.active?'body-shoulder':closeView?'close':collisionLimited||recovering?'shoulder':'orbit',bodyClearanceActive:clearance.active,bodyClearanceBlocked:clearance.blocked,bodyClearanceProbes:clearance.probes,separation,headDistance,boomLength:length,availableLength,collisionLimited,desiredDistance:desired.distanceTo(origin),resolvedDistance:position.distanceTo(origin),occlusionReason:clearance.active?'body-clearance':collisionLimited?(ceilingLimited?'wall-and-ceiling':'wall'):ceilingLimited?'ceiling':recovering?'recovery':'none'};
 }
 return{solve,reset,get closeView(){return closeView}};
}
