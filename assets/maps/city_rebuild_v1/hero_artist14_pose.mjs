// Final presentation callbacks in the existing normalized host hierarchy.
export function createArtist14Pose(THREE){
 const q=new THREE.Quaternion(),offset=new THREE.Vector3(),pivot=new THREE.Vector3();
 function aroundHip(ctx,rotation){const unit=ctx.targetHeight/ctx.sourceHeight;pivot.set(0,1.46,0).add(ctx.offset.position).multiplyScalar(unit);offset.copy(pivot).sub(pivot.clone().applyQuaternion(rotation));ctx.visualPivot.position.add(offset.applyQuaternion(ctx.visualPivot.quaternion));ctx.visualPivot.quaternion.multiply(rotation);ctx.object.updateMatrixWorld(true);}
 function swim(s,c){
  if(s.blend<=0)return;const b=s.blend,phase=s.phase;
  c.rotateAdd('chest',-.05*b,Math.sin(phase)*.1*b);c.rotateAdd('neck',-.25*b);c.rotateAdd('head',-.30*b);
  for(const [side,sign] of [['l',1],['r',-1]]){const p=phase+(sign<0?Math.PI:0),f=Math.sin(phase*2+sign*Math.PI/2);c.rotate('thigh_'+side,f*(s.moving?.22:.1)*b);c.rotate('shin_'+side,Math.max(0,-f)*(s.moving?.28:.18)*b);c.rotate('foot_'+side,.18*b-f*.09*b);c.object.updateMatrixWorld(true);
   const palm=new THREE.Vector3(-sign*(s.moving?.80:1),s.moving?3+Math.cos(p)*1.1:2.65+Math.cos(p)*.22,s.moving?Math.sin(p)*.65:.45+Math.sin(p)*.30);c.offset.localToWorld(palm);const hand=c.worldPosition('socket_hand_'+side).lerp(palm,b);c.reachPalm(side,hand,c.bones['hand_'+side].getWorldQuaternion(new THREE.Quaternion()));
  }
  aroundHip(c,q.setFromEuler(new THREE.Euler(s.tilt,0,Math.sin(phase)*.07*b)));
 }
 function reaction(s,c){
  const weight=Math.sin(Math.PI*Math.min(1,s.age/.48)),side=s.side;
  if(s.kind==='hit'||s.kind==='block'){c.rotateAdd('chest',-.10*weight,0,-side*.13*weight);c.rotateAdd('head',-.19*weight,side*.23*weight);c.object.updateMatrixWorld(true);if(s.kind==='block')for(const [hand,sign]of[['l',-1],['r',1]])c.reachPalm(hand,c.offset.localToWorld(new THREE.Vector3(sign*.46,3.72,.8)),c.bones['hand_'+hand].getWorldQuaternion(new THREE.Quaternion()));return;}
  const ease=THREE.MathUtils.smoothstep,w=ease(s.age,.03,.62)*(s.kind==='dead'?1:1-ease(s.age,1.55,2.7));
  c.rotate('thigh_l',-.35*w,0,-.12*w);c.rotate('thigh_r',-.17*w,0,.16*w);c.rotate('shin_l',.62*w);c.rotate('shin_r',.35*w);c.rotate('head',-.12*w,0,side*.16*w);c.rotate('upperarm_l',-.3*w,0,-.48*w);c.rotate('upperarm_r',-.12*w,0,.65*w);c.rotate('forearm_l',-.35*w);c.rotate('forearm_r',-.28*w);
  aroundHip(c,q.setFromEuler(new THREE.Euler(-Math.PI/2*w,0,side*.12*w)));c.groundPose();
 }
 return {swim,reaction};
}
