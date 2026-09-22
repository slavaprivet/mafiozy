// NPC-only authored death presentation. Source/profile validation is upstream.
// Unknown causes preserve Artist14 exactly; no damage, root motion or randomness.
const limbs=Object.freeze({
 bullet:[-.42,-.20,.78,.38,-.16,-.42,.10,.48,-.38,-.24],
 melee:[-.65,-.35,1.05,.62,-.48,-.30,-.36,.48,-1.05,-.75],
 super:[-.12,-.30,.32,.66,.42,-.65,.16,.72,-.18,-.38],
 kick:[-.72,-.22,1.15,.42,.26,-.40,-.16,.60,-.65,-.25],
 dropkick:[-.28,-.62,.48,.98,.44,-.72,.32,.78,-.28,-.48],
 blast:[-.16,-.50,.36,.92,.64,-.95,.38,1.02,-.14,-.42]
});
const canonical=[-.35,-.17,.62,.35,-.30,-.48,-.12,.65,-.35,-.28];
export function createNpcDeathPose20({THREE,basePose}){
 const baseQ=new THREE.Quaternion(),targetQ=new THREE.Quaternion(),rotation=new THREE.Quaternion(),euler=new THREE.Euler();
 const axis=new THREE.Vector3(),pivot=new THREE.Vector3(),rotatedPivot=new THREE.Vector3(),offset=new THREE.Vector3();
 const a=new Float64Array(10);
 const mix=(a,b,t)=>a+(b-a)*t;
 function reaction(s,c,profile){
  const angles=profile?.known===true?limbs[profile.cause]:null;
  if(s.kind!=='dead'||!angles){basePose.reaction(s,c);return;}
  const rawAge=Number.isFinite(s.rawAge)?s.rawAge:s.age;
  const w=Number.isFinite(s.visualWeight)?THREE.MathUtils.clamp(s.visualWeight,0,1):THREE.MathUtils.smoothstep(s.age,.03,.62);
  // Enter from the canonical current fall/recovery instead of snapping a
  // fallen NPC into a different cause pose when the fatal event arrives.
  const blend=THREE.MathUtils.smoothstep(rawAge,0,.28),side=Number.isFinite(s.side)?THREE.MathUtils.clamp(s.side,-1,1):1;
  for(let index=0;index<a.length;index++)a[index]=mix(canonical[index],angles[index],blend)*w;
  c.rotate('thigh_l',a[0],0,-.12*w);c.rotate('thigh_r',a[1],0,.16*w);
  c.rotate('shin_l',a[2]);c.rotate('shin_r',a[3]);c.rotate('head',-.12*w,0,side*.16*w);
  c.rotate('upperarm_l',a[4],0,a[5]);c.rotate('upperarm_r',a[6],0,a[7]);
  c.rotate('forearm_l',a[8]);c.rotate('forearm_r',a[9]);
  baseQ.setFromEuler(euler.set(-Math.PI/2*w,0,side*.12*w));
  const direction=profile.directionLocal,horizontal=direction?Math.hypot(direction.x,direction.z):0;
  if(Number.isFinite(horizontal)&&horizontal>1e-5){
   axis.set(direction.z/horizontal,0,-direction.x/horizontal);targetQ.setFromAxisAngle(axis,Math.PI/2*w);
   rotation.copy(baseQ).slerp(targetQ,blend);
  }else rotation.copy(baseQ);
  const unit=c.targetHeight/c.sourceHeight;
  pivot.set(0,1.46,0).add(c.offset.position).multiplyScalar(unit);
  rotatedPivot.copy(pivot).applyQuaternion(rotation);offset.copy(pivot).sub(rotatedPivot);
  c.visualPivot.position.add(offset.applyQuaternion(c.visualPivot.quaternion));c.visualPivot.quaternion.multiply(rotation);
  c.object.updateMatrixWorld(true);c.groundPose();
 }
 return {reaction};
}
