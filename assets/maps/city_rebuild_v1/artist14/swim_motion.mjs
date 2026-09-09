// Standalone reference units: walking/swimming integration remains owned by the host.
export function createSwimMotion(THREE){
 const state={active:false,blend:0,speed:0,lift:0,phase:0,fast:false,moving:false,tilt:0};
 const q=new THREE.Quaternion(),pivot=new THREE.Vector3(0,1.46,0),offset=new THREE.Vector3(),palm=new THREE.Vector3();
 function reset(){Object.assign(state,{active:false,blend:0,speed:0,lift:0,phase:0,fast:false,moving:false,tilt:0});}
 function step({dt=0,time=0,waterLevel=null,chestHeight=3,hasMovement=false,fast=false,blocked=false}={}){
  dt=Math.min(.25,Math.max(0,Number.isFinite(dt)?dt:0));
  const submerged=Number.isFinite(waterLevel)&&Number.isFinite(chestHeight);
  if(blocked||!submerged)state.active=false;
  else if(state.active){if(waterLevel<chestHeight-.1)state.active=false;}
  else if(waterLevel>chestHeight)state.active=true;
  const target=state.active?1:0;
  state.blend+=(target-state.blend)*(1-Math.exp(-dt*9));
  if(Math.abs(state.blend-target)<.002)state.blend=target;
  state.fast=!!fast&&!!hasMovement;state.moving=!!hasMovement;
  const cadence=hasMovement?(state.fast?1.5:.9):.55;
  state.phase=(state.phase+dt*Math.PI*2*cadence)%(Math.PI*2);
  state.speed=state.active&&hasMovement?(state.fast?3.4:2):0;
  state.tilt=(hasMovement?1.32:.55)*state.blend;
  // Stable chestHeight is the rest chest world Y, never the animated chest.
  // Rotating about hips lowers the chest; buoyancy brings it just below the water.
  const wanted=submerged?Math.max(0,waterLevel-chestHeight+1.54*(1-Math.cos(state.tilt))-.12):0;
  state.lift+=(wanted*state.blend-state.lift)*(1-Math.exp(-dt*12));
  if(!state.active&&state.blend===0&&state.lift<.002)state.lift=0;
  return {...state};
 }
 function apply(model,actor,rotateRest,poseArm){
  const b=state.blend;if(b<=0)return;
  const moving=state.moving,phase=state.phase;
  rotateRest('chest',-.05*b,Math.sin(phase)*.10*b,0);
  rotateRest('neck',-.25*b);rotateRest('head',-.30*b);
  for(const [side,sign] of [['l',1],['r',-1]]){
   const phaseSide=phase+(sign<0?Math.PI:0),flutter=Math.sin(phase*2+sign*Math.PI/2);
   rotateRest('thigh_'+side,flutter*(moving?.22:.10)*b);
   rotateRest('shin_'+side,Math.max(0,-flutter)*(moving?.28:.18)*b);
   rotateRest('foot_'+side,.18*b-flutter*.09*b);
   if(poseArm){
    // Solve before the final root tilt: local overhead becomes forward reach in water.
    // Interpolate from the current visible hand so entry and exit do not snap.
    model.root.updateMatrixWorld(true);
    const socket=model.bones['socket_hand_'+side];
    const start=socket?actor.worldToLocal(socket.getWorldPosition(new THREE.Vector3())):new THREE.Vector3(-sign*.8,2.5,.3);
    palm.set(-sign*(moving?.80:1.0),moving?3.0+Math.cos(phaseSide)*1.10:2.65+Math.cos(phaseSide)*.22,moving?Math.sin(phaseSide)*.65:.45+Math.sin(phaseSide)*.30);
    palm.lerpVectors(start,palm,b);poseArm(side,palm,-.18*b);
   }
  }
  q.setFromEuler(new THREE.Euler(state.tilt,0,Math.sin(phase)*.07*b));
  model.root.quaternion.copy(model.baseQuaternion).multiply(q);
  offset.copy(pivot).applyQuaternion(q).negate().add(pivot);
  model.root.position.copy(model.basePosition).add(offset);
  model.root.updateMatrixWorld(true);
 }
 return {step,apply,reset,get state(){return {...state};}};
}
