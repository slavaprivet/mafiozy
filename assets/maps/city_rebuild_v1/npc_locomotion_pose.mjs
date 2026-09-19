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
 const settings={stride:length*2.32,stance:.52,radiansPerMetre:0,running:false};let weight=0;
 function configure({running=false,slowWalking=false,speed=0}={}){
  settings.running=running;settings.stride=running?Math.max(length*2.85,speed*.52):length*(slowWalking?1.9:2.32);
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
  const reach=travel/2;let drop=0;for(const l of legs)drop=Math.max(drop,l.height-Math.sqrt(Math.max(.001,(l.a+l.b-.004)**2-reach**2)));
  c.scaled.position.y=c.scaled.position.y*(1-blend)-drop*blend;
  c.object.getWorldQuaternion(rootQ);
  for(let i=0;i<legs.length;i++){
   const l=legs[i],u=((phase/(2*Math.PI)+.25+i*.5)%1+1)%1,stance=u<settings.stance;
   let z,lift=0;
   if(stance)z=travel/2-u*settings.stride;
   else {const t=(u-settings.stance)/(1-settings.stance),smooth=t*t*(3-2*t);z=-travel/2+travel*smooth;lift=Math.sin(Math.PI*t)*(settings.running?.10:.065)*(walker.height/1.9);}
   l.thigh.parent.updateWorldMatrix(true,false);updateWorld(l.thigh);updateWorld(l.shin);updateWorld(l.foot);
   hip.setFromMatrixPosition(l.thigh.matrixWorld);ankle.setFromMatrixPosition(l.foot.matrixWorld);
   target.copy(l.origin);target.z+=z;target.y+=lift;target.applyMatrix4(c.object.matrixWorld);target.lerpVectors(ankle,target,blend);
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
 return{configure,apply,reset(){weight=0;},diagnostics:()=>({weight,...settings,legLength:length})};
}
