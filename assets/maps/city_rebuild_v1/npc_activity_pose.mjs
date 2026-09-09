// Source-owned activities only: offsets affect presentation, never AI coordinates.
export function createNpcActivityPose({THREE,walker}){
 const c=walker.artistContext(),phone=new THREE.Group(),clamp=x=>Math.max(0,Math.min(1,x));
 phone.name='NPC_Phone';phone.visible=false;
 const shell=new THREE.Mesh(new THREE.BoxGeometry(.15,.29,.025),new THREE.MeshStandardMaterial({color:0x24282a,roughness:.35,metalness:.35}));
 const screen=new THREE.Mesh(new THREE.BoxGeometry(.116,.225,.006),new THREE.MeshStandardMaterial({color:0x607e83,roughness:.3,emissive:0x152326,emissiveIntensity:.18}));
 screen.position.z=.016;phone.add(shell,screen);phone.position.set(0,.06,.045);phone.rotation.set(.1,0,Math.PI/2);c.bones.hand_r.add(phone);
 // Capture shoe bounds once in each foot's frame; target the sole, not ankle height.
 const footBounds={};c.object.updateMatrixWorld(true);
 for(const side of ['l','r']){
  const bone=c.bones['foot_'+side],inverse=bone.matrixWorld.clone().invert(),box=new THREE.Box3();
  c.scene.traverse(mesh=>{if(!mesh.isSkinnedMesh)return;mesh.skeleton.update();const ids=mesh.geometry.attributes.skinIndex,w=mesh.geometry.attributes.skinWeight;
   for(let i=0;i<ids.count;i++){let weight=0;for(let j=0;j<4;j++)if(mesh.skeleton.bones[ids.getComponent(i,j)]===bone)weight+=w.getComponent(i,j);if(weight>.5)box.expandByPoint(mesh.getVertexPosition(i,new THREE.Vector3()).applyMatrix4(mesh.matrixWorld).applyMatrix4(inverse));}
  });
  footBounds[side]=box.isEmpty()?[]:[...Array(8)].map((_,i)=>new THREE.Vector3(i&1?box.max.x:box.min.x,i&2?box.max.y:box.min.y,i&4?box.max.z:box.min.z));
 }
 const up=new THREE.Vector3(0,1,0),seatTarget=new THREE.Vector3(),localDelta=new THREE.Vector3(),rootQ=new THREE.Quaternion(),heading=new THREE.Quaternion(),center=new THREE.Vector3(),footTargets={l:new THREE.Vector3(),r:new THREE.Vector3()},footQs={l:new THREE.Quaternion(),r:new THREE.Quaternion()},footScales={l:new THREE.Vector3(),r:new THREE.Vector3()},soleCorner=new THREE.Vector3(),handQs={l:new THREE.Quaternion(),r:new THREE.Quaternion()},feet=[['l',-1],['r',1]];
 let lastSeat=null,weight=0,lastTime=null;
 function apply({life={},time=0,blend=1,blocked=false,armed=false,groundY=0}={}){
  const threat=life.cowering||life.surrendering||life.cuffed||life.arrested||life.fleeing||/panic|flee|cower|surrender/.test(String(life.state||''));
  phone.visible=!blocked&&!armed&&!threat&&!!life.phoneCalling;
  const dt=lastTime===null?0:Math.max(0,Math.min(.25,time-lastTime));lastTime=time;
  if(blocked||armed||threat){weight=0;lastSeat=null;return false;}
  const seat=life.seat,activity=life.routinePlan?.phase||life.activity||'',height=seat?.seatWorldY??seat?.height;
  const sitting=seat&&['sit','sitting','rest','sit_down'].includes(seat.phase||activity)&&Number.isFinite(height);
  if(sitting){
   if(!lastSeat){const age=Number.isFinite(seat.since)?Math.max(0,time-seat.since/1000):0;weight=clamp(age/.5);}
   if(!lastSeat)lastSeat={};lastSeat.id=seat.id;lastSeat.c=seat.c;lastSeat.r=seat.r;lastSeat.yaw=seat.yaw;lastSeat.seatWorldY=height;weight=Math.min(1,weight+dt/.5);
  }else weight=Math.max(0,weight-dt/.5);
  if(lastSeat&&weight>0){
   const seated=THREE.MathUtils.smoothstep(weight,0,1)*clamp(blend),s=lastSeat;
   walker.vehiclePose(seated,0,{driver:false});
   const yaw=Number.isFinite(s.yaw)?s.yaw:c.object.rotation.y;
   c.visualPivot.rotation.y=Math.atan2(Math.sin(yaw-c.object.rotation.y),Math.cos(yaw-c.object.rotation.y))*seated;
   c.rotate('chest',.04*seated);c.rotate('neck',-.02*seated);c.rotate('head',0,Math.sin(time*.32)*.12*seated);c.object.updateMatrixWorld(true);
   const hip=c.worldPosition('thigh_l').add(c.worldPosition('thigh_r')).multiplyScalar(.5);
   seatTarget.set(Number.isFinite(s.c)?s.c*4.1:hip.x,s.seatWorldY+.075*walker.height/1.9,Number.isFinite(s.r)?s.r*4.1:hip.z);
   localDelta.copy(seatTarget).sub(hip).applyQuaternion(c.object.getWorldQuaternion(rootQ).invert());
   c.visualPivot.position.addScaledVector(localDelta,seated);c.object.updateMatrixWorld(true);
   heading.setFromAxisAngle(up,yaw);center.copy(c.worldPosition('thigh_l')).add(c.worldPosition('thigh_r')).multiplyScalar(.5);
   for(const [side,sign]of feet){
    const foot=c.worldPosition('foot_'+side),q=c.bones['foot_'+side].getWorldQuaternion(footQs[side]);
    const target=footTargets[side].set(sign*.12*walker.height/1.9,0,.12*walker.height/1.9).applyQuaternion(heading).add(center),scale=c.bones['foot_'+side].getWorldScale(footScales[side]);let sole=0;for(const corner of footBounds[side])sole=Math.min(sole,soleCorner.copy(corner).multiply(scale).applyQuaternion(q).y);target.y=groundY-sole+.003;
    c.reachFoot?.(side,foot.lerp(target,seated),q);
    const palm=c.worldPosition('socket_hand_'+side),knee=c.worldPosition('shin_'+side);knee.y+=.06;
    c.reachPalm(side,palm.lerp(knee,seated),c.bones['hand_'+side].getWorldQuaternion(handQs[side]));
   }
   c.object.updateMatrixWorld(true);return true;
  }
  if(!sitting)lastSeat=null;
  if(['browsing','look_around','inspect','waiting'].includes(activity)){
   c.rotateAdd('head',Math.sin(time*.7)*.05*blend,Math.sin(time*.5)*.35*blend);
   c.rotateAdd('chest',0,Math.sin(time*.5)*.07*blend);c.object.updateMatrixWorld(true);return true;
  }
  return phone.visible;
 }
 return {apply,phone,diagnostics:()=>({seated:weight,seatId:lastSeat?.id??null})};
}

