// Blend an existing landing pose into the requested posture. The host owns
// grounded admission; this only blends local presentation before weapon IK.
export const LANDING_POSTURE_SECONDS=.28;
export function createHeroPoseTransition({THREE,bones,visualPivot,scaled,object}){
 let source=null,elapsed=0,duration=LANDING_POSTURE_SECONDS,progress=1;
 const p=new THREE.Vector3(),q=new THREE.Quaternion(),targetRotation=new THREE.Quaternion(),s=new THREE.Vector3();
 return {
  begin(seconds=LANDING_POSTURE_SECONDS){
   duration=Math.max(.01,seconds);elapsed=0;progress=0;
   object.updateMatrixWorld(true);
   source={pelvisRotation:object.getWorldQuaternion(new THREE.Quaternion()).invert().multiply(bones.pelvis.getWorldQuaternion(new THREE.Quaternion())),bones:Object.entries(bones).map(([name,bone])=>{const position=new THREE.Vector3(),rotation=new THREE.Quaternion(),scale=new THREE.Vector3();bone.matrix.decompose(position,rotation,scale);return {name,position,rotation}}),position:visualPivot.position.clone(),rotation:visualPivot.quaternion.clone(),scaledPosition:scaled.position.clone()};
  },
  cancel(){source=null;progress=1},
  get progress(){return progress},
  step(dt){
   if(!source)return false;
   elapsed+=Math.max(0,dt);const t=Math.min(1,elapsed/duration),blend=t*t*(3-2*t);
   progress=blend;
   object.updateMatrixWorld(true);
   const rootRotation=object.getWorldQuaternion(new THREE.Quaternion()),targetPelvis=rootRotation.clone().invert().multiply(bones.pelvis.getWorldQuaternion(new THREE.Quaternion()));
   for(const state of source.bones){const bone=bones[state.name];bone.matrix.decompose(p,q,s);p.lerpVectors(state.position,p,blend);q.slerpQuaternions(state.rotation,targetRotation.copy(q),blend);bone.matrix.compose(p,q,s);bone.matrixWorldNeedsUpdate=true}
   visualPivot.position.lerpVectors(source.position,visualPivot.position,blend);
   visualPivot.quaternion.slerpQuaternions(source.rotation,targetRotation.copy(visualPivot.quaternion),blend);
   scaled.position.lerpVectors(source.scaledPosition,scaled.position,blend);
   // Interpolate the combined body orientation, not independent opposing
   // root/pelvis rotations which briefly stand the character up en route prone.
   object.updateMatrixWorld(true);
   const desired=rootRotation.multiply(new THREE.Quaternion().slerpQuaternions(source.pelvisRotation,targetPelvis,blend));
   bones.pelvis.matrix.decompose(p,q,s);q.copy(bones.pelvis.parent.getWorldQuaternion(new THREE.Quaternion()).invert().multiply(desired));bones.pelvis.matrix.compose(p,q,s);bones.pelvis.matrixWorldNeedsUpdate=true;
   if(t===1)source=null;return true;
  }
 };
}
