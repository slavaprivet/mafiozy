// Presentation only; host owns root position/yaw, controls and weapon visibility.
export function applyRoofLadderPose(hero,sample,THREE){
  if(!hero?.artistContext||!sample||!THREE)return false;
  hero.reset();
  const ctx=hero.artistContext(),hands={};
  hero.object.updateMatrixWorld(true);
  const rootQ=hero.object.getWorldQuaternion(new THREE.Quaternion()),palmTurn=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),-Math.PI/2);
  for(const side of ['l','r'])hands[side]=rootQ.clone().multiply(palmTurn).multiply(rootQ.clone().invert()).multiply(ctx.bones['hand_'+side].getWorldQuaternion(new THREE.Quaternion()));
  for(const [bone,angle] of Object.entries(sample.angles||{}))ctx.rotate(bone,angle.x||0,angle.y||0,angle.z||0);
  ctx.rotate('neck',-.08*(sample.handBlend??1));ctx.rotate('head',-.08*(sample.handBlend??1));
  hero.object.updateMatrixWorld(true);
  for(const [side,target] of [['l',sample.handL],['r',sample.handR]]){
    if(target&&['x','y','z'].every(k=>Number.isFinite(target[k]))){const blend=sample.handBlend??1;if(blend>0){const goal=new THREE.Vector3(target.x,target.y,target.z);if(blend<1)goal.lerpVectors(ctx.bones['hand_'+side].getWorldPosition(new THREE.Vector3()),goal,blend);ctx.reachPalm(side,goal,hands[side]);}}
  }
  // Never call groundPose here: that would move an airborne climber.
  hero.object.updateMatrixWorld(true);
  return true;
}
