// NPC-only standing gait. The host owns displacement; feet use that distance
// phase and a linear support interval instead of sliding through a sine swing.
export function createNpcLocomotionPose({THREE:T,walker}){
 const c=walker.artistContext(),v=()=>new T.Vector3(),q=()=>new T.Quaternion();
 const hip=v(),knee=v(),ankle=v(),line=v(),bend=v(),current=v(),desired=v(),target=v(),base=v(),scratch=v(),worldScale=v();
 const rootQ=q(),parentQ=q(),worldQ=q(),swingQ=q(),localQ=q(),footQ=q(),inverseRoot=q();
 c.object.updateMatrixWorld(true);c.object.getWorldQuaternion(rootQ);inverseRoot.copy(rootQ).invert();
 const legs=['l','r'].map(side=>{const thigh=c.bones['thigh_'+side],shin=c.bones['shin_'+side],foot=c.bones['foot_'+side];
  hip.setFromMatrixPosition(thigh.matrixWorld);knee.setFromMatrixPosition(shin.matrixWorld);ankle.setFromMatrixPosition(foot.matrixWorld);
  const origin=c.object.worldToLocal(ankle.clone()),orientation=foot.getWorldQuaternion(q()).premultiply(inverseRoot);
  return{thigh,shin,foot,origin,orientation,a:hip.distanceTo(knee),b:knee.distanceTo(ankle),height:hip.y-ankle.y};
 });
 const length=(legs[0].a+legs[0].b+legs[1].a+legs[1].b)/2;
 const settings={stride:length*1.9,stance:.52,radiansPerMetre:0,running:false};let weight=0;
 let entryPose=null,entryAge=0,entryVehicle=null,entrySeat=null;
 const entryMeshes=[];c.scene.traverse(mesh=>{if(mesh.isMesh)entryMeshes.push(mesh);});
 const floorInverse=new T.Matrix4(),floorPost=new T.Matrix4(),floorMatrix=new T.Matrix4(),floorPoint=v();let floorRecords=null;
 function entryFloor(){
  // Cache influence buckets, not a previous pose or a shoe-height guess. A
  // conservative transformed box skips only vertices proven above the floor;
  // every bucket that could touch it still uses the original exact skinning.
  if(!floorRecords||floorRecords.some(r=>r.geometry!==r.mesh.geometry||r.position!==r.mesh.geometry.attributes.position||r.version!==r.position?.version||r.skin!==r.mesh.geometry.attributes.skinIndex||r.weights!==r.mesh.geometry.attributes.skinWeight||r.skinVersion!==r.skin?.version||r.weightVersion!==r.weights?.version)){
   floorRecords=entryMeshes.map(mesh=>{
    const geometry=mesh.geometry,position=geometry.attributes.position,skin=geometry.attributes.skinIndex,weights=geometry.attributes.skinWeight,buckets=new Map();let valid=!!position;
    if(mesh.isSkinnedMesh&&(!skin||!weights))valid=false;
    if(valid)for(let i=0;i<position.count;i++){
     const bones=[];let sum=mesh.isSkinnedMesh?0:1;
     if(mesh.isSkinnedMesh)for(let j=0;j<4;j++){const w=weights.getComponent(i,j),bone=skin.getComponent(i,j);if(!Number.isFinite(w)||w<0||!Number.isInteger(bone)||!mesh.skeleton.bones[bone]){valid=false;break;}sum+=w;if(w>0&&!bones.includes(bone))bones.push(bone);}
     if(!valid||!Number.isFinite(sum)||sum<=0){valid=false;break;}
     const key=bones.join(',');let bucket=buckets.get(key);if(!bucket){bucket={bones,indices:[],box:new T.Box3(),minSum:sum,error:0};buckets.set(key,bucket);}
     bucket.minSum=Math.min(bucket.minSum,sum);bucket.error=Math.max(bucket.error,Math.abs(1-sum));bucket.indices.push(i);floorPoint.fromBufferAttribute(position,i);if(mesh.isSkinnedMesh)floorPoint.applyMatrix4(mesh.bindMatrix);bucket.box.expandByPoint(floorPoint);
    }
    return{mesh,geometry,position,version:position?.version,skin,weights,skinVersion:skin?.version,weightVersion:weights?.version,valid,buckets:[...buckets.values()]};
   });
  }
  if(floorRecords.some(r=>!r.valid)){const y=c.visualPivot.position.y;c.groundPose();c.visualPivot.position.y=Math.max(y,c.visualPivot.position.y);return;}
  floorInverse.copy(c.object.matrixWorld).invert();let lowest=0;
  const minY=(box,m)=>{const e=m.elements;return e[13]+e[1]*(e[1]<0?box.max.x:box.min.x)+e[5]*(e[5]<0?box.max.y:box.min.y)+e[9]*(e[9]<0?box.max.z:box.min.z);};
  for(const r of floorRecords){
   const mesh=r.mesh;floorPost.multiplyMatrices(floorInverse,mesh.matrixWorld);if(mesh.isSkinnedMesh){floorPost.multiply(mesh.bindMatrixInverse);mesh.skeleton.update();}
   for(const bucket of r.buckets){
    let lower=mesh.isSkinnedMesh?Infinity:minY(bucket.box,floorPost);
    if(mesh.isSkinnedMesh)for(const bone of bucket.bones){floorMatrix.multiplyMatrices(floorPost,mesh.skeleton.bones[bone].matrixWorld).multiply(mesh.skeleton.boneInverses[bone]);lower=Math.min(lower,minY(bucket.box,floorMatrix));}
    if(lower*bucket.minSum-bucket.error*Math.abs(floorPost.elements[13])>=1e-7)continue;
    for(const i of bucket.indices){floorPoint.fromBufferAttribute(r.position,i);if(mesh.isSkinnedMesh)mesh.applyBoneTransform(i,floorPoint);floorPoint.applyMatrix4(mesh.matrixWorld).applyMatrix4(floorInverse);lowest=Math.min(lowest,floorPoint.y);}
   }
  }
  c.visualPivot.position.y-=lowest;
 }
 function prepareVehicleEntry(binding){
  if(!binding||!binding.transition){entryPose=null;return;}
  if(entryPose&&(entryVehicle!==binding.vehicle||entrySeat!==binding.seatId))entryPose=null;
  if(weight<=0||binding.phase!=='board'||binding.progress>.2)return;
  // Capture once, at the ownership handoff. Walking crowds pay no pose-copy
  // cost; neither the route nor the authoritative actor root is interpolated.
  entryPose={bones:Object.values(c.bones).map(bone=>({bone,p:v(),q:q(),s:v()})),pivotP:c.visualPivot.position.clone(),pivotQ:c.visualPivot.quaternion.clone(),scaledP:c.scaled.position.clone()};
  for(const value of entryPose.bones)value.bone.matrix.decompose(value.p,value.q,value.s);
  entryAge=0;entryVehicle=binding.vehicle;entrySeat=binding.seatId;
 }
 function applyVehicleEntry(dt,binding,allowed){
  if(!allowed||!binding?.transition||binding.vehicle!==entryVehicle||binding.seatId!==entrySeat){entryPose=null;return;}
  if(!entryPose)return;
  const blend=T.MathUtils.smoothstep(entryAge,0,.22);
  if(blend>=1){entryPose=null;return;}
  for(const value of entryPose.bones){
   value.bone.matrix.decompose(base,worldQ,worldScale);localQ.copy(value.q).slerp(worldQ,blend);base.lerpVectors(value.p,base,blend);worldScale.lerpVectors(value.s,worldScale,blend);value.bone.matrix.compose(base,localQ,worldScale);value.bone.matrixWorldNeedsUpdate=true;
  }
  c.visualPivot.position.lerpVectors(entryPose.pivotP,c.visualPivot.position,blend);worldQ.copy(c.visualPivot.quaternion);c.visualPivot.quaternion.copy(entryPose.pivotQ).slerp(worldQ,blend);c.scaled.position.lerpVectors(entryPose.scaledP,c.scaled.position,blend);
  c.object.updateMatrixWorld(true);
  if(entryAge>0){entryFloor();c.object.updateMatrixWorld(true);}
  entryAge+=Math.min(.1,Math.max(0,Number.isFinite(dt)?dt:0));
 }
 function configure({running=false,slowWalking=false,speed=0}={}){
  settings.running=running;settings.stride=running?Math.max(length*2.85,speed*.52):length*(slowWalking?1.65:1.9);
  settings.stance=running?Math.max(.12,Math.min(.42,length*1.2/settings.stride)):.52;
  settings.radiansPerMetre=2*Math.PI/settings.stride;return settings;
 }
 function updateWorld(bone){bone.matrixWorld.multiplyMatrices(bone.parent.matrixWorld,bone.matrix);}
 function orient(bone,child,goal){
  scratch.setFromMatrixPosition(bone.matrixWorld);current.setFromMatrixPosition(child.matrixWorld).sub(scratch).normalize();desired.copy(goal).sub(scratch).normalize();
  swingQ.setFromUnitVectors(current,desired);bone.matrixWorld.decompose(scratch,worldQ,worldScale);worldQ.premultiply(swingQ);
  bone.parent.matrixWorld.decompose(scratch,parentQ,worldScale);localQ.copy(parentQ).invert().multiply(worldQ);
  const rest=c.rest[bone.name];bone.matrix.compose(rest.p,localQ,rest.s);bone.matrixWorldNeedsUpdate=true;updateWorld(bone);
 }
 function apply(dt,enabled,phase,gait){
  weight+=(Number(enabled)-weight)*(1-Math.exp(-18*Math.min(.1,dt)));if(weight<.0001){weight=0;return false;}
  const blend=weight*Math.min(1,gait),travel=settings.stride*settings.stance;
  let drop=0;
  for(let i=0;i<legs.length;i++){
   const l=legs[i],u=((phase/(2*Math.PI)+.25+i*.5)%1+1)%1,stance=u<settings.stance;
   let z,lift=0;
   if(stance)z=travel/2-u*settings.stride;
   else {const t=(u-settings.stance)/(1-settings.stance),smooth=t*t*(3-2*t);z=-travel/2+travel*smooth;lift=Math.sin(Math.PI*t)*(settings.running?.10:.065)*(walker.height/1.9);}
   l.z=z;l.lift=lift;
   // Walk rises over the planted leg. A constant worst-case stride offset
   // kept both knees bent throughout the cycle, even at ordinary walking pace.
   const reach=settings.running?travel/2:Math.abs(z),footLift=settings.running?0:lift;
   drop=Math.max(drop,l.height-footLift-Math.sqrt(Math.max(.001,(l.a+l.b-.004)**2-reach**2)));
  }
  c.scaled.position.y=c.scaled.position.y*(1-blend)-drop*blend;
  c.object.getWorldQuaternion(rootQ);
  for(const l of legs){
   l.thigh.parent.updateWorldMatrix(true,false);updateWorld(l.thigh);updateWorld(l.shin);updateWorld(l.foot);
   hip.setFromMatrixPosition(l.thigh.matrixWorld);ankle.setFromMatrixPosition(l.foot.matrixWorld);
   target.copy(l.origin);target.z+=l.z;target.y+=l.lift;target.applyMatrix4(c.object.matrixWorld);target.lerpVectors(ankle,target,blend);
   target.y=Math.max(target.y,c.object.matrixWorld.elements[13]+l.origin.y);
   line.copy(target).sub(hip);const distance=Math.min(l.a+l.b-.00001,Math.max(Math.abs(l.a-l.b)+.00001,line.length()));line.normalize();target.copy(hip).addScaledVector(line,distance);
   bend.set(0,0,1).applyQuaternion(rootQ);bend.addScaledVector(line,-bend.dot(line)).normalize();
   const along=(l.a*l.a-l.b*l.b+distance*distance)/(2*distance),height=Math.sqrt(Math.max(0,l.a*l.a-along*along));
   knee.copy(hip).addScaledVector(line,along).addScaledVector(bend,height);
   orient(l.thigh,l.shin,knee);updateWorld(l.shin);updateWorld(l.foot);orient(l.shin,l.foot,target);updateWorld(l.foot);
   footQ.copy(rootQ).multiply(l.orientation);l.shin.matrixWorld.decompose(base,parentQ,worldScale);localQ.copy(parentQ).invert().multiply(footQ);
   const rest=c.rest[l.foot.name];l.foot.matrix.compose(rest.p,localQ,rest.s);l.foot.matrixWorldNeedsUpdate=true;
  }
  return true;
 }
 return{configure,apply,prepareVehicleEntry,applyVehicleEntry,reset(){weight=0;},diagnostics:()=>({weight,...settings,legLength:length})};
}
