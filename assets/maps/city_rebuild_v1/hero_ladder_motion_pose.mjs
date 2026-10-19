// Detailed ladder presentation. Physics/controller owns root and yaw. Weapon
// policy is deliberately explicit so the host can use its existing holster.
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
function rotate(context,name,x,y,z,blend){context.rotateAdd(name,(x||0)*blend,(y||0)*blend,(z||0)*blend)}

function contactWeight(relative){
  const fraction=relative-Math.floor(relative),distance=Math.abs(fraction-.5);
  return smooth(distance,.035,.16);
}

function rungContact(descriptor,position,side,nominalHeight,phaseOffset=0,depth=.38){
  const spacing=descriptor.rungSpacing,base=descriptor.lower.y+.18;
  const relative=(position.y+nominalHeight-base)/spacing+phaseOffset;
  const rung=Math.round(relative),y=base+rung*spacing;
  return {x:position.x-descriptor.normal.x*depth+descriptor.right.x*side,y,z:position.z-descriptor.normal.z*depth+descriptor.right.z*side,blend:contactWeight(relative)};
}

export function sampleHeroLadderMotion(descriptor,position,{
  travelled=0,direction=1,sliding=false,mountProgress=1,dismountProgress=0,
}={}){
  if(!descriptor||!finitePoint(position)||!finitePoint(descriptor.lower)||!Number.isFinite(descriptor.rungSpacing)||descriptor.rungSpacing<=0)return null;
  direction=direction<0?-1:1;travelled=Math.max(0,Number.isFinite(travelled)?travelled:0);
  const enter=smooth(mountProgress,0,1),exit=1-smooth(dismountProgress,0,1),blend=enter*exit;
  // One opposing-limb exchange per rung. A two-pi cycle per rung looks frantic
  // at the production climb speed and magnifies low-FPS limb travel.
  const phase=travelled/descriptor.rungSpacing*Math.PI*direction;
  const normal=descriptor.normal,right=descriptor.right,width=Math.max(.62,Number(descriptor.width)||.8);
  const rail=(side,height)=>({x:position.x-normal.x*.38+right.x*side*width*.5,y:position.y+height,z:position.z-normal.z*.38+right.z*side*width*.5,blend:1});
  let handL,handR,footL,footR;
  if(sliding){
    handL=rail(1,1.37);handR=rail(-1,1.37);
    footL=rail(.13,.11);footR=rail(-.13,.11);
  }else{
    // Opposite limbs share a rung rhythm. Targets stay fixed on a rung and
    // release before switching, preventing a planted hand from skating.
    const reverse=direction<0?.5:0;
    handL=rungContact(descriptor,position,width*.2,1.35,reverse,.3);
    handR=rungContact(descriptor,position,-width*.2,1.35,.5+reverse,.3);
    // Foot bones are at the ankle; leave the shoe length between that joint and
    // the rung plane so the IK chain stays reachable while the toe is planted.
    footL=rungContact(descriptor,position,width*.15,.18,.5+reverse,.1);
    footR=rungContact(descriptor,position,-width*.15,.18,reverse,.1);
  }
  return Object.freeze({phaseName:sliding?'slide':direction>0?'climb-up':'climb-down',phase,direction,sliding,blend,
    handL,handR,footL,footR,weaponPolicy:'holster',yaw:descriptor.yaw});
}

export function applyHeroLadderMotionPose(THREE,context,sample){
  if(!THREE||!context?.bones||!context.reachPalm||!context.reachFoot||!sample||!Number.isFinite(sample.blend))return false;
  // The outer orchestrator owns the action cross-fade. Keeping the authored
  // ladder delta below full solver amplitude prevents sparse 3-7 Hz samples
  // from snapping across a skipped rung while contacts remain recognisable.
  const blend=clamp01(sample.blend)*clamp01(sample.presentationScale??1);if(blend<=0)return true;
  const cycle=Math.sin(sample.phase||0),sliding=!!sample.sliding,direction=sample.direction<0?-1:1;
  const cache=poseCache(THREE,context);
  rotate(context,'chest',sliding?.055:.12,0,0,blend);rotate(context,'neck',sliding?-.035:-.075,0,0,blend);rotate(context,'head',sliding?-.045:-.085,0,0,blend);
  if(sliding){
    for(const [side,sign]of SIDES){const names=BONE_NAMES[side];rotate(context,names.upperarm,-1.72,0,sign*.08,blend);rotate(context,names.forearm,-.36,0,0,blend);rotate(context,names.thigh,-.18,0,sign*.025,blend);rotate(context,names.shin,.3,0,0,blend);rotate(context,names.foot,-.08,0,0,blend);}
  }else{
    for(const [side,sign]of SIDES){
      const names=BONE_NAMES[side];
      const limb=cycle*sign*direction;
      rotate(context,names.upperarm,-1.66-limb*.2,0,sign*.075,blend);rotate(context,names.forearm,-.43+limb*.09,0,0,blend);
      rotate(context,names.thigh,-.48+limb*.31,0,sign*.045,blend);rotate(context,names.shin,.7-limb*.3,0,0,blend);rotate(context,names.foot,-.1+limb*.08,0,0,blend);
    }
  }
  context.object.updateMatrixWorld(true);
  context.object.getWorldQuaternion(cache.rootQ);cache.inverseRootQ.copy(cache.rootQ).invert();
  for(const [side]of SIDES){const target=side==='l'?sample.handL:sample.handR;if(finitePoint(target)){
    const names=BONE_NAMES[side];context.bones[names.hand].getWorldQuaternion(cache.handWorldQ);cache.handQ.copy(cache.rootQ).multiply(cache.palmTurn).multiply(cache.inverseRootQ).multiply(cache.handWorldQ);cache.goal.set(target.x,target.y,target.z);
    const contact=blend*clamp01(target.blend??1);
    const limb=side==='l'?cache.limbs.hand_l:cache.limbs.hand_r;saveLimb(context,limb);context.reachPalm(side,cache.goal,cache.handQ);blendLimb(context,limb,contact);
  }
  }
  context.object.updateMatrixWorld(true);
  for(const [side]of SIDES){const target=side==='l'?sample.footL:sample.footR;if(finitePoint(target)){
    const names=BONE_NAMES[side];cache.goal.set(target.x,target.y,target.z);context.bones[names.foot].getWorldQuaternion(cache.footQ);
    const contact=blend*clamp01(target.blend??1),limb=side==='l'?cache.limbs.foot_l:cache.limbs.foot_r;saveLimb(context,limb);context.reachFoot(side,cache.goal,cache.footQ,0);blendLimb(context,limb,contact);
  }
  }
  context.object.updateMatrixWorld(true);return true;
}
