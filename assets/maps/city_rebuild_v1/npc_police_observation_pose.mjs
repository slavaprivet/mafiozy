// An arrived source inspection owns the deadline and root facing. This overlay
// adds only a bounded head scan; weapon hands and gameplay sight remain unchanged.
export function createNpcPoliceObservationPose({THREE,walker}){
 const context=walker.artistContext();
 const position=new THREE.Vector3(),scale=new THREE.Vector3(),rotation=new THREE.Quaternion(),delta=new THREE.Quaternion(),euler=new THREE.Euler();
 function rotate(name,x,y){const bone=context.bones[name],rest=context.rest[name];bone.matrix.decompose(position,rotation,scale);rotation.multiply(delta.setFromEuler(euler.set(x,y,0)));bone.matrix.compose(rest.p,rotation,rest.s);bone.matrixWorldNeedsUpdate=true;}
 return {apply(observation,time,blocked=false){
  if(blocked||!observation||!Number.isFinite(time)||!Number.isFinite(observation.since)||!Number.isFinite(observation.until))return false;
  const age=time-observation.since/1000,remaining=observation.until/1000-time;
  if(age<0||remaining<=0)return false;
  const weight=Math.min(1,age/.3,remaining/.4),blend=weight*weight*(3-2*weight),scan=Math.sin(age*1.7)*blend;
  rotate('neck',-.025*blend,scan*.09);
  rotate('head',Math.sin(age*2.1)*.035*blend,scan*.27);
  return true;
 }};
}
