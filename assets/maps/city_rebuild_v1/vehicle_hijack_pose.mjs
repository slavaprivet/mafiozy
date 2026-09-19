import {createArtist14Pose} from './hero_artist14_pose.mjs';
import {createNpcTrafficVehicleBinding,resolveNpcVehicleBinding,applyNpcVehicleBinding} from './npc_vehicle_pose.mjs';

const clamp=n=>Math.max(0,Math.min(1,n));
const smooth=(a,b,n)=>{const t=clamp((n-a)/(b-a));return t*t*(3-2*t)};
export const vehicleHijackActive=s=>!!s&&(s.phase==='seated'||s.phase==='pulled'&&Number.isFinite(s.progress))&&typeof s.carId==='string'&&!!s.carId;

// Host-owned source positions, HP and progress are never modified here. Apply
// after the normal base pose. These callbacks own only the bones/visual pivot.
export function createVehicleHijackPose({THREE,walker,getVehicle}={}){
 const c=walker.artistContext(),deathPose=createArtist14Pose(THREE),bindings=new WeakMap();
 const target=new THREE.Vector3(),base=new THREE.Vector3(),right=new THREE.Vector3(),rootQ=new THREE.Quaternion(),handQ=new THREE.Quaternion(),forward=new THREE.Vector3();
 const life={civilianTripRiding:false,civilianTripPhase:'exit',civilianTripProgress:0,civilianTripCarId:'',vehicleSeatId:'front_left'};
 const armNames=['upperarm_l','upperarm_r','forearm_l','forearm_r','hand_l','hand_r'],armStart=new Map(armNames.map(n=>[n,new THREE.Quaternion()])),armPosition=new THREE.Vector3(),armScale=new THREE.Vector3(),armQ=new THREE.Quaternion();
 let lastPhase=null,armEvent=null;
 function bindingFor(s){
  const actor=getVehicle?.(s.carId);if(!actor)return null;
  let binding=bindings.get(actor);if(!binding){binding=typeof actor.getSeatRootWorld==='function'?actor:createNpcTrafficVehicleBinding({THREE,actor});if(binding)bindings.set(actor,binding)}
  life.civilianTripCarId=s.carId;life.vehicleSeatId=s.seatId||'front_left';life.civilianTripProgress=s.phase==='seated'?0:smooth(0,.60,clamp(s.progress));
  return binding&&resolveNpcVehicleBinding(life,()=>binding);
 }
 function applyVictim(s,{dt=0,dead=false,deathSide=1,blocked=false}={}){
  if(blocked||!vehicleHijackActive(s)){lastPhase=null;return false}
  const binding=bindingFor(s);if(!binding){lastPhase='waiting-for-vehicle';return false}
  const p=s.phase==='seated'?0:clamp(s.progress),side=s.side===1?1:-1;
  applyNpcVehicleBinding({THREE,walker,binding,dt});
  const event=String(s.eventId||s.carId);
  if(armEvent!==event){armEvent=event;for(const name of armNames)c.bones[name].matrix.decompose(armPosition,armStart.get(name),armScale)}
  const pull=smooth(.06,.5,p)*(1-smooth(.64,1,p));
  c.rotateAdd('chest',dead?.10*pull:.06*pull,side*.22*pull,side*.16*pull);
  c.rotateAdd('head',dead?.35*(1-smooth(.58,1,p)):-.12*pull,side*.2*pull);
  if(dead){
   // Arms hang freely instead of holding the wheel. The final fall is the
   // existing authored death pose, so removing this receipt cannot revive it.
   const limp=1-smooth(.57,.78,p);
   for(const [hand,sign]of [['l',-1],['r',1]]){c.rotate('upperarm_'+hand,.13*limp,0,sign*.24*limp);c.rotate('forearm_'+hand,-.18*limp)}
   if(p>.58)deathPose.reaction({kind:'dead',age:smooth(.58,1,p)*.75,side:deathSide===-1?-1:1},c);
  }else{
   const struggle=Math.sin(p*Math.PI*8)*.12*pull;
   c.rotate('upperarm_l',-.95*pull,0,-.55*pull-struggle);c.rotate('upperarm_r',-.68*pull,0,.72*pull+struggle);
   c.rotate('forearm_l',-1.05*pull);c.rotate('forearm_r',-1.18*pull);c.rotate('hand_l');c.rotate('hand_r');
   const arms=smooth(0,.1,p);for(const name of armNames){const bone=c.bones[name];bone.matrix.decompose(armPosition,armQ,armScale);armQ.slerpQuaternions(armStart.get(name),armQ,arms);bone.matrix.compose(c.rest[name].p,armQ,c.rest[name].s);bone.matrixWorldNeedsUpdate=true}
   const stagger=Math.sin(smooth(.60,1,p)*Math.PI)*.18;
   c.rotateAdd('chest',-.25*stagger,0,side*.25*stagger);
   c.rotateAdd('thigh_l',-.25*stagger);c.rotateAdd('shin_l',.5*stagger);
  }
  c.object.updateMatrixWorld(true);lastPhase=dead?'corpse-extraction':'resisting-extraction';return true;
 }
 function applyPuller(s,{blocked=false}={}){
  if(blocked||s?.phase!=='pull_driver'||!Number.isFinite(s.progress))return false;
  const p=clamp(s.progress),blend=smooth(0,.12,p)*(1-smooth(.88,1,p)),pull=smooth(.16,.68,p),unit=walker.height/1.9;
  if(!blend)return true;
  c.rotateAdd('chest',(.24-pull*.39)*blend,0,-.07*blend);c.rotateAdd('head',-.13*blend);
  c.rotateAdd('thigh_l',-.24*blend);c.rotateAdd('shin_l',.38*blend);c.rotateAdd('thigh_r',.12*blend);
  c.object.updateMatrixWorld(true);c.object.getWorldQuaternion(rootQ);
  right.set(1,0,0).applyQuaternion(rootQ);forward.set(0,0,1).applyQuaternion(rootQ);
  const explicit=s.gripWorld;
  if(explicit&&['x','y','z'].every(k=>Number.isFinite(explicit[k])))base.set(explicit.x,explicit.y,explicit.z);
  else{
   const actor=getVehicle?.(s.carId),seat=actor?.seats?.find(x=>x.id===(s.seatId||'front_left'));
   if(actor?.object?.parent&&seat){base.set(seat.anchor.side,seat.anchor.y+.55*unit,seat.anchor.front);actor.object.localToWorld(base)}
   else c.object.getWorldPosition(base).addScaledVector(forward,(.60-.22*pull)*unit).addScaledVector(right,.04*unit).setY(c.object.position.y+1.20*unit);
  }
  for(const [side,sign]of [['l',-1],['r',1]]){
   target.copy(base).addScaledVector(right,sign*.15*unit);target.y+=sign*.045*unit;
   const palm=c.worldPosition('socket_hand_'+side);target.lerpVectors(palm,target,blend);
   c.reachPalm(side,target,c.bones['hand_'+side].getWorldQuaternion(handQ));
  }
  c.object.updateMatrixWorld(true);lastPhase='pulling-driver';return true;
 }
 function applyReaction(s,{time=0,blocked=false}={}){
  if(blocked||!s||!['protest','retake'].includes(s.phase))return false;
  const age=Number.isFinite(s.since)?Math.max(0,time-s.since/1000):.3;
  const duration=Number.isFinite(s.until)&&Number.isFinite(s.since)?Math.max(.1,(s.until-s.since)/1000):1;
  const blend=smooth(0,.12,age)*(1-smooth(Math.max(.12,duration-.2),duration,age));
  const wave=Math.sin(age*13)*.15*blend;
  c.rotateAdd('chest',-.07*blend,Math.sin(age*9)*.10*blend);
  c.rotateAdd('head',-.10*blend,-Math.sin(age*9)*.12*blend);
  c.rotateAdd('upperarm_l',-.65*blend,0,-.9*blend-wave);c.rotateAdd('upperarm_r',-.65*blend,0,.9*blend+wave);
  c.rotateAdd('forearm_l',-.9*blend);c.rotateAdd('forearm_r',-.9*blend);
  c.object.updateMatrixWorld(true);lastPhase=s.phase;return blend>0;
 }
 return {isActive:s=>vehicleHijackActive(s)&&!!bindingFor(s),applyVictim,applyPuller,applyReaction,diagnostics:()=>({phase:lastPhase})};
}
