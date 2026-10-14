// Presentation-only steep terrain pose. The host owns terrain admission, root
// motion and contact queries. Signed slopeGrade is rise/run along travel.
const clamp01=value=>Math.max(0,Math.min(1,Number.isFinite(value)?value:0));
const smooth=(value,min=0,max=1)=>{const t=clamp01((value-min)/(max-min||1));return t*t*(3-2*t)};
const finitePoint=p=>p&&['x','y','z'].every(key=>Number.isFinite(p[key]));
const SIDES=Object.freeze([Object.freeze(['l',1]),Object.freeze(['r',-1])]);
const BONE_NAMES=Object.freeze({l:Object.freeze({thigh:'thigh_l',shin:'shin_l',foot:'foot_l',upperarm:'upperarm_l',forearm:'forearm_l',hand:'hand_l'}),r:Object.freeze({thigh:'thigh_r',shin:'shin_r',foot:'foot_r',upperarm:'upperarm_r',forearm:'forearm_r',hand:'hand_r'})});
const poseCaches=new WeakMap();

function createLimb(THREE,names){return {names,states:names.map(()=>({p:new THREE.Vector3(),q:new THREE.Quaternion(),s:new THREE.Vector3(),solved:new THREE.Quaternion()})),scratchP:new THREE.Vector3(),scratchS:new THREE.Vector3()}}
function poseCache(THREE,context){let cache=poseCaches.get(context);if(cache)return cache;cache={goal:new THREE.Vector3(),footQ:new THREE.Quaternion(),rootQ:new THREE.Quaternion(),palmTurn:new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),-Math.PI/2),inverseRootQ:new THREE.Quaternion(),handQ:new THREE.Quaternion(),handWorldQ:new THREE.Quaternion(),limbs:{foot_l:createLimb(THREE,['thigh_l','shin_l','foot_l']),foot_r:createLimb(THREE,['thigh_r','shin_r','foot_r']),hand_l:createLimb(THREE,['upperarm_l','forearm_l','hand_l']),hand_r:createLimb(THREE,['upperarm_r','forearm_r','hand_r'])}};poseCaches.set(context,cache);return cache}
function saveLimb(context,limb){for(let i=0;i<limb.names.length;i++)context.bones[limb.names[i]].matrix.decompose(limb.states[i].p,limb.states[i].q,limb.states[i].s)}
function blendLimb(context,limb,weight){weight=clamp01(weight);for(let i=0;i<limb.names.length;i++){const bone=context.bones[limb.names[i]],state=limb.states[i];bone.matrix.decompose(limb.scratchP,state.solved,limb.scratchS);bone.matrix.compose(state.p,state.q.slerp(state.solved,weight),state.s);bone.matrixWorldNeedsUpdate=true}context.object.updateMatrixWorld(true)}
function rotate(context,name,x=0,y=0,z=0){context.rotateAdd(name,x,y,z)}

export const HERO_SLOPE_BLEND=Object.freeze({
  enterGrade:.42,
  fullGrade:.78,
  handEnterGrade:.72,
  handFullGrade:.92,
  downhillBrakeGrade:.30,
  downhillFullBrakeGrade:.72,
  rise90Seconds:.18,
  fall90Seconds:.22,
});

// Exact exponential integration: a constant target produces the same result at
// 10, 30, 60 and 144 Hz apart from floating-point rounding. dt=0 is a no-op.
export function stepHeroSlopeBlend(current,target,dt,{rise90Seconds=HERO_SLOPE_BLEND.rise90Seconds,fall90Seconds=HERO_SLOPE_BLEND.fall90Seconds}={}){
  current=clamp01(current);target=clamp01(target);dt=Math.max(0,Number.isFinite(dt)?dt:0);
  const duration=Math.max(.001,target>current?rise90Seconds:fall90Seconds),tau=duration/Math.log(10);
  return target+(current-target)*Math.exp(-dt/tau);
}

export function sampleHeroSlopeMotion({
  slopeGrade=0,
  blend=null,
  gaitPhase=0,
  gaitWeight=1,
  moving=true,
  armed=false,
  footL=null,
  footR=null,
  handL=null,
  handR=null,
}={},out=null){
  slopeGrade=Number.isFinite(slopeGrade)?Math.max(-1.15,Math.min(1.15,slopeGrade)):0;
  gaitPhase=Number.isFinite(gaitPhase)?gaitPhase:0;gaitWeight=clamp01(gaitWeight);
  const magnitude=Math.abs(slopeGrade),target=smooth(magnitude,HERO_SLOPE_BLEND.enterGrade,HERO_SLOPE_BLEND.fullGrade);
  const poseBlend=clamp01(blend===null?target:blend)*(moving?1:0);
  const uphill=slopeGrade>=0,downhillBrake=uphill?0:smooth(-slopeGrade,HERO_SLOPE_BLEND.downhillBrakeGrade,HERO_SLOPE_BLEND.downhillFullBrakeGrade)*poseBlend;
  const handBlend=smooth(magnitude,HERO_SLOPE_BLEND.handEnterGrade,HERO_SLOPE_BLEND.handFullGrade)*poseBlend;
  out=out&&typeof out==='object'?out:null;const sample=out||{};sample.phaseName=uphill?'scramble-up':'scramble-down';sample.slopeGrade=slopeGrade;
  sample.targetBlend=target;sample.blend=poseBlend;sample.gaitPhase=gaitPhase;sample.gaitWeight=gaitWeight;
  sample.downhillBrake=downhillBrake;sample.handBlend=handBlend;sample.uphill=uphill;sample.armed=!!armed;
  sample.footL=footL;sample.footR=footR;sample.handL=handL;sample.handR=handR;
  sample.weaponPolicy=armed&&poseBlend>.55?'holster':armed?'carry-safe':'none';return out?sample:Object.freeze(sample);
}

export function applyHeroSlopeMotionPose(THREE,context,sample){
  if(!THREE||!context?.bones||!context.rotateAdd||!sample||!Number.isFinite(sample.blend))return false;
  const blend=clamp01(sample.blend);if(blend<=0)return true;
  const grade=Math.max(-1.15,Math.min(1.15,sample.slopeGrade||0)),angle=Math.atan(grade),uphill=grade>=0;
  const phase=sample.gaitPhase||0,gait=clamp01(sample.gaitWeight),brake=clamp01(sample.downhillBrake),hands=clamp01(sample.handBlend);
  const strideScale=1-blend*(uphill?.46:.34)-brake*.22;
  const cache=poseCache(THREE,context);
  // Counter the portion of the ordinary walk stride removed by scramble. The
  // same host gait phase is required, so the walk-to-scramble transition is
  // continuous rather than starting a second animation clock.
  for(const [side,sign]of SIDES){
    const names=BONE_NAMES[side];
    const ordinary=Math.sin(phase)*sign*gait*.56,removed=ordinary*(1-strideScale);
    rotate(context,names.thigh,-removed);
    rotate(context,names.shin,-Math.max(0,-ordinary)*.52*(1-strideScale));
    rotate(context,names.foot,ordinary*.22*(1-strideScale));
  }
  const forwardLean=angle*(uphill?.64:.38)*blend;
  rotate(context,'chest',forwardLean+brake*.12,0,Math.sin(phase)*.018*blend);
  rotate(context,'neck',-forwardLean*.42-brake*.05);rotate(context,'head',-forwardLean*.28-brake*.06);
  for(const [side,sign]of SIDES){
    const names=BONE_NAMES[side];
    const cycle=Math.sin(phase)*sign;
    const hip=(uphill?.31:.2)*blend+brake*.28;
    rotate(context,names.thigh,-hip+cycle*.11*blend);
    rotate(context,names.shin,hip*1.25-cycle*.08*blend);
    rotate(context,names.foot,-hip*.22+brake*.08);
    if(!sample.armed||sample.weaponPolicy==='holster'){
      const balance=(uphill?.4:.55)*blend+brake*.28;
      rotate(context,names.upperarm,-balance-cycle*.16*blend,0,sign*(.2*blend+.18*brake));
      rotate(context,names.forearm,-.24*blend+cycle*.07*blend);
    }
  }
  context.object.updateMatrixWorld(true);
  // Support points are supplied by physics/raycast code. Missing points simply
  // retain the articulated leg; presentation never guesses a collision plane.
  for(const [side]of SIDES){const target=side==='l'?sample.footL:sample.footR;if(finitePoint(target)){
    const names=BONE_NAMES[side],limb=side==='l'?cache.limbs.foot_l:cache.limbs.foot_r;cache.goal.set(target.x,target.y,target.z);context.bones[names.foot].getWorldQuaternion(cache.footQ);
    saveLimb(context,limb);context.reachFoot(side,cache.goal,cache.footQ,0);blendLimb(context,limb,blend);
  }
  }
  context.object.updateMatrixWorld(true);
  if(hands>.001&&(!sample.armed||sample.weaponPolicy==='holster')){
    context.object.getWorldQuaternion(cache.rootQ);cache.inverseRootQ.copy(cache.rootQ).invert();
    for(const [side]of SIDES){const target=side==='l'?sample.handL:sample.handR;if(finitePoint(target)){
      const names=BONE_NAMES[side],limb=side==='l'?cache.limbs.hand_l:cache.limbs.hand_r;cache.goal.set(target.x,target.y,target.z);context.bones[names.hand].getWorldQuaternion(cache.handWorldQ);cache.handQ.copy(cache.rootQ).multiply(cache.palmTurn).multiply(cache.inverseRootQ).multiply(cache.handWorldQ);
      saveLimb(context,limb);context.reachPalm(side,cache.goal,cache.handQ);blendLimb(context,limb,hands);
    }
    }
  }
  context.object.updateMatrixWorld(true);return true;
}
