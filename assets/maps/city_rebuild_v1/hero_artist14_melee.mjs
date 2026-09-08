// Artist14 accepted demo v13 pose port. Host owns attack admission, hits and root physics.
export const ARTIST14_MELEE_DURATIONS=Object.freeze({punch:.34,kick:.62,heavy:.50,backfist:.50,dropkick:1.25});
export function selectArtist14OrdinaryAttack(roll){if(!Number.isFinite(roll)||roll<0||roll>=1)throw Error('Expected roll in [0,1)');return roll<.20?'kick':'punch'}
export function createArtist14Melee({THREE,bones,rest,offset,visualPivot,object,targetHeight,sourceHeight,rotateAdd,groundPose}){
 const actor=offset,unit=targetHeight/sourceHeight;
 object.updateMatrixWorld(true);
 const inv=offset.matrixWorld.clone().invert(),baseQ=offset.getWorldQuaternion(new THREE.Quaternion()).invert(),records={};
 for(const [name,bone] of Object.entries(bones)) records[name]={worldP:bone.getWorldPosition(new THREE.Vector3()).applyMatrix4(inv),worldQ:baseQ.clone().multiply(bone.getWorldQuaternion(new THREE.Quaternion()))};
 for(const side of ['l','r'])for(const [name,child]of [[`upperarm_${side}`,`forearm_${side}`],[`forearm_${side}`,`hand_${side}`],[`thigh_${side}`,`shin_${side}`],[`shin_${side}`,`foot_${side}`]]){const r=records[name];r.dir=records[child].worldP.clone().sub(r.worldP);r.length=r.dir.length();r.dir.normalize();}
 const current={bones,rest:records,root:object,armNames:{}};
 for(const side of ['l','r'])current.armNames[side]={upper:`upperarm_${side}`,fore:`forearm_${side}`,hand:`hand_${side}`,socket:`socket_hand_${side}`};
 const v1=new THREE.Vector3(),v2=v1.clone(),v3=v1.clone(),v4=v1.clone(),wrist=v1.clone(),shoulder=v1.clone(),dir=v1.clone(),elbow=v1.clone(),pole=v1.clone(),palm=v1.clone(),scale=v1.clone();
 const q1=new THREE.Quaternion(),q2=q1.clone(),footGaitQ=q1.clone(),footKickQ=q1.clone(),euler=new THREE.Euler(),m1=new THREE.Matrix4(),m2=m1.clone();
 const axisX=new THREE.Vector3(1,0,0),axisY=new THREE.Vector3(0,1,0),axisZ=new THREE.Vector3(0,0,1);
 let posture={crouch:0,prone:0},phase=0,gait=0;
 function setWorld(name,start,orientation,s=1){const bone=bones[name];v1.copy(start).applyMatrix4(actor.matrixWorld);q2.copy(actor.getWorldQuaternion(new THREE.Quaternion())).multiply(orientation);scale.copy(actor.getWorldScale(new THREE.Vector3())).multiply(new THREE.Vector3(1,s,1));m1.compose(v1,q2,scale);m2.copy(bone.parent.matrixWorld).invert();bone.matrix.multiplyMatrices(m2,m1);bone.matrixWorldNeedsUpdate=true;bone.updateMatrixWorld(true);}
 function segment(name,start,end){const r=records[name];v2.subVectors(end,start);const length=v2.length();v2.normalize();q1.setFromUnitVectors(r.dir,v2).multiply(r.worldQ);setWorld(name,start,q1,length/r.length);}
 function rotateRest(name,x=0,y=0,z=0){rotateAdd(name,x,y,z)}
function poseArm(side,targetPalm,handTilt=0){const names=current.armNames[side],r=current.rest[names.hand];
  q1.setFromAxisAngle(axisX,handTilt);v3.subVectors(current.rest[names.socket].worldP,r.worldP).applyQuaternion(q1);wrist.copy(targetPalm).sub(v3);
  shoulder.copy(current.bones[names.upper].getWorldPosition(v4));actor.worldToLocal(shoulder);
  dir.subVectors(wrist,shoulder);let d=dir.length();dir.normalize();const l1=current.rest[names.upper].length,l2=current.rest[names.fore].length,stretch=Math.max(1,d/(l1+l2-.015));
  const a=(l1*l1*stretch*stretch-l2*l2*stretch*stretch+d*d)/(2*Math.max(.01,d)),height=Math.sqrt(Math.max(.005,l1*l1*stretch*stretch-a*a));
  const crawl=posture.prone*gait*Math.sin(phase)*(side==='l'?-1:1);
  pole.set((side==='l'?-1:1)*(THREE.MathUtils.lerp(1,.5,posture.prone)+crawl*.25),THREE.MathUtils.lerp(-.55,-1,posture.prone),THREE.MathUtils.lerp(-.08,-.6,posture.prone)+crawl*.25);pole.addScaledVector(dir,-pole.dot(dir)).normalize();elbow.copy(shoulder).addScaledVector(dir,a).addScaledVector(pole,height);
  segment(names.upper,shoulder,elbow);segment(names.fore,elbow,wrist);q1.setFromAxisAngle(axisX,handTilt).multiply(r.worldQ);setWorld(names.hand,wrist,q1);
}
function poseKick(side,sign,lift,extend,blend,dropkick=false,high=false){
  shoulder.copy(current.bones['thigh_'+side].getWorldPosition(v4));actor.worldToLocal(shoulder);
  palm.copy(current.bones['foot_'+side].getWorldPosition(v4));actor.worldToLocal(palm);
  current.bones['foot_'+side].getWorldQuaternion(footGaitQ);q2.copy(actor.getWorldQuaternion(new THREE.Quaternion())).invert();footGaitQ.premultiply(q2);
  wrist.set(sign*.35,.27+lift*(dropkick?1.05-extend*.95:.68+extend*.45),lift*(.20+extend*.92)).lerp(palm,1-blend);
  if(high){const sweep=.90*(1-2*extend);wrist.set(sign*(.35+Math.sin(sweep)*1.08*lift),.27+lift*1.65,Math.cos(sweep)*1.08*lift).lerp(palm,1-blend);}
  const legScale=high?1+.20*lift*blend:1;
  if(high)wrist.sub(shoulder).multiplyScalar(legScale).add(shoulder);
  dir.subVectors(wrist,shoulder);const l1=current.rest['thigh_'+side].length*legScale,l2=current.rest['shin_'+side].length*legScale;
  const d=THREE.MathUtils.clamp(dir.length(),Math.abs(l1-l2)+.000001,l1+l2);dir.normalize();wrist.copy(shoulder).addScaledVector(dir,d);
  const a=(l1*l1-l2*l2+d*d)/(2*d),height=Math.sqrt(Math.max(0,l1*l1-a*a));
  pole.set(high?sign*.45:0,high?-.12:1,high?1:.5);pole.addScaledVector(dir,-pole.dot(dir)).normalize();elbow.copy(shoulder).addScaledVector(dir,a).addScaledVector(pole,height);
  segment('thigh_'+side,shoulder,elbow);segment('shin_'+side,elbow,wrist);
  footKickQ.setFromAxisAngle(axisX,-lift*(high?.15:.20)).multiply(current.rest['foot_'+side].worldQ);q1.copy(footGaitQ).slerp(footKickQ,blend);setWorld('foot_'+side,wrist,q1);
}

 function apply(action,postureArg={},phaseArg=0,gaitArg=0){
  // Host must restore its rig/pivot before calling each frame. Inactive and armed routes are exact no-ops.
  if(!action||action.armed||action.weaponId&&action.weaponId!=='none')return null;
  posture={crouch:postureArg.crouch||0,prone:postureArg.prone||0};phase=phaseArg;gait=gaitArg;
  const type=action.type==='backfist'?'heavy':action.type||'none';
  if(type!=='none'&&!ARTIST14_MELEE_DURATIONS[type])throw Error('Unknown melee action '+type);
  const progressInput=THREE.MathUtils.clamp(Number.isFinite(action.progress)?action.progress:0,0,1);
  const isActive=type!=='none'&&progressInput<1;
  // The hold timer starts on mouse-down, but its wind-up must not overwrite
  // the immediate one-hand opener with a two-hand charging pose.
  const opener=isActive&&(type==='punch'||type==='kick');
  const charge=opener?0:THREE.MathUtils.clamp(Number.isFinite(action.charge)?action.charge:0,0,1),blockHeld=!!action.blocking,charging=charge>0;
  if(!isActive&&!blockHeld&&!charging)return null;
  if(posture.prone>.01||posture.crouch>.01)return null; // host stands before admitting attack
  const attackType=type==='dropkick'?'heavy':type,heavyDouble=type==='dropkick',punchSide=action.side<0?-1:1;
  const time=progressInput*(ARTIST14_MELEE_DURATIONS[type]||1),punchAt=0,guardBlend=Math.max(blockHeld?1:0,charge);
  const attackDuration=()=>ARTIST14_MELEE_DURATIONS[type]||1,attackActive=()=>isActive;
   const age=time-punchAt,duration=attackDuration(),active=attackActive(),progress=active?age/duration:0;
   // Fast extension, then a longer controlled recovery. Charge already supplied
   // the heavy wind-up: do not play another slow preparation after release.
   const peak=attackType==='heavy'?.10:.09;
   const pulse=active?(attackType==='kick'?Math.sin(Math.PI*progress):THREE.MathUtils.smoothstep(age,0,peak)*(1-THREE.MathUtils.smoothstep(age,peak,duration-.07))):0;
   const blend=active?THREE.MathUtils.smoothstep(age,0,attackType==='kick'?.14:.055)*(1-THREE.MathUtils.smoothstep(age,duration-.14,duration)):0;
   const doubleKick=active&&heavyDouble,heavy=active&&attackType==='heavy'&&!doubleKick,kick=active&&attackType==='kick',guard=Math.max(guardBlend,blend,heavy?1-THREE.MathUtils.smoothstep(progress,.68,1):0);
   const wind=heavy?1-THREE.MathUtils.smoothstep(age,0,.08):0;
   const sweep=heavy?THREE.MathUtils.smoothstep(age,0,.16):0,recover=heavy?THREE.MathUtils.smoothstep(age,.19,.50):0;
   rotateRest('chest',Math.sin(time*2)*.012-(doubleKick?.25*Math.sin(Math.PI*progress):0)+(blockHeld?.06:0)+charge*.06+(heavy?wind*.06+pulse*.08:0),charging?-punchSide*charge*.20:heavy?punchSide*(.20-1.05*sweep)*(1-recover):0,kick?punchSide*pulse*.22:0);current.root.updateMatrixWorld(true);
   for(const [s,sign] of [['l',-1],['r',1]]){const striking=sign===punchSide;let px=sign*(blockHeld?.46:.38),py=blockHeld?3.72:3.38,pz=blockHeld?.80:.5;
     if(charging&&sign===-punchSide){px=sign*(.38-charge*.98);py=3.38+charge*.22;pz=.5+charge*.25;}
     if(active&&!kick&&!doubleKick){px=sign*(.38-pulse*.10+(heavy&&striking?wind*.43:0));py=3.38-pulse*.1-(heavy&&striking?wind*.13:0);pz=.5+(striking?pulse*(heavy?1.35:1.1)-(heavy?wind*.55:0):0);}
     // Backfist: sweep from the opposite cheek out across the target, with a
     // sideways wrist, rather than driving the knuckles straight forward.
     if(heavy&&striking){px=sign*THREE.MathUtils.lerp(-.60+1.80*sweep,.38,recover);py=THREE.MathUtils.lerp(3.60,3.38,recover);pz=THREE.MathUtils.lerp(.75+.80*Math.sin(Math.PI*sweep),.50,recover);}
     const armBlend=active&&attackType==='punch'&&!striking&&!blockHeld&&!charging?guard*.16:guard;
     palm.set(THREE.MathUtils.lerp(sign*1.1,px,armBlend),THREE.MathUtils.lerp(1.77,py,armBlend)-posture.crouch*.60,THREE.MathUtils.lerp(sign*Math.sin(phase)*gait*.43,pz,armBlend));palm.lerp(v4.set(sign*.78,.30+Math.max(0,sign*Math.sin(phase))*gait*.08,2.12+sign*Math.sin(phase)*gait*.23),posture.prone);
     if(heavy&&striking){
       // Extend from the actual turned shoulder, not an actor-space target
       // near the face. Keep the original bone lengths and a small elbow bend.
       actor.worldToLocal(current.bones['upperarm_'+s].getWorldPosition(v3));
       current.bones.chest.getWorldQuaternion(q2);q1.copy(actor.getWorldQuaternion(new THREE.Quaternion())).invert();q2.premultiply(q1);
       v4.set(sign,.025,.20).normalize().applyQuaternion(q2).multiplyScalar((current.rest['upperarm_'+s].length+current.rest['forearm_'+s].length)*.98).add(v3);
       v4.add(v3.subVectors(current.rest['socket_hand_'+s].worldP,current.rest['hand_'+s].worldP));
       palm.lerp(v4,THREE.MathUtils.smoothstep(age,.025,.12)*(1-THREE.MathUtils.smoothstep(age,.30,.49)));
       actor.worldToLocal(current.bones['upperarm_'+s].getWorldPosition(v4));
       dir.copy(palm).sub(v3).sub(v4).clampLength(0,current.rest['upperarm_'+s].length+current.rest['forearm_'+s].length-.02);
       palm.copy(v4).add(dir).add(v3);
     }
     poseArm(s,palm,posture.prone*1.2);
     if(heavy&&striking){const hand=current.bones['hand_'+s];actor.worldToLocal(hand.getWorldPosition(v3));euler.set(0,-sign*Math.PI/2*(1-recover),0);q1.setFromEuler(euler).multiply(current.rest['hand_'+s].worldQ);setWorld('hand_'+s,v3,q1);}
   }
   if(doubleKick&&blend>0){const lift=THREE.MathUtils.smoothstep(age,0,.10)*(1-THREE.MathUtils.smoothstep(age,.58,1.20)),extend=THREE.MathUtils.smoothstep(age,.16,.25)*(1-THREE.MathUtils.smoothstep(age,.36,.62));for(const [side,sign] of [['l',-1],['r',1]])poseKick(side,sign,lift,extend*.95,blend,true);}
   if(kick&&blend>0){const lift=THREE.MathUtils.smoothstep(age,0,.13)*(1-THREE.MathUtils.smoothstep(age,.36,.58)),extend=THREE.MathUtils.smoothstep(age,.13,.32);poseKick(punchSide<0?'l':'r',punchSide,lift,extend,blend,false,true);}
  const s=THREE.MathUtils.smoothstep;
  let bodyQ=new THREE.Quaternion(),lift=0,travel=0;
  if(isActive&&attackType==='kick')lift=1.95*s(age,0,.18)*(1-s(age,.34,.60));
  if(isActive&&attackType==='heavy'&&!heavyDouble)bodyQ.setFromAxisAngle(axisY,-punchSide*Math.PI*2*s(age,0,.50));
  if(isActive&&heavyDouble){
    const tilt=(1.20*s(age,.02,.22)+.16*s(age,.38,.64))*(1-s(age,.72,1.25));
    const rise=.90*s(age,0,.18)*(1-s(age,.28,.65));
    const fall=-.32*s(age,.40,.70)*(1-s(age,.78,1.25));
    const bank=punchSide*.65*s(age,.03,.16)*(1-s(age,.46,.72));
    bodyQ.setFromAxisAngle(axisZ,bank).multiply(new THREE.Quaternion().setFromAxisAngle(axisX,-tilt));
    // Same source-rig hip pivot as accepted demo; root position remains host-owned.
    const hip=new THREE.Vector3(0,1.46,0).add(offset.position).multiplyScalar(unit);
    const displacement=hip.clone().sub(hip.clone().applyQuaternion(bodyQ));displacement.y+=(rise+fall)*unit;
    visualPivot.position.add(displacement.applyQuaternion(visualPivot.quaternion));
    travel=(2.8*s(age,0,.34)+.35*s(age,.34,.58))*unit;
  }
  visualPivot.quaternion.multiply(bodyQ);visualPivot.position.y+=lift*unit;object.updateMatrixWorld(true);
  if(isActive&&heavyDouble&&groundPose){const before=visualPivot.position.y;groundPose();visualPivot.position.y=Math.max(before,visualPivot.position.y);object.updateMatrixWorld(true);}
  const window=heavyDouble?[.16,.38]:attackType==='kick'?[.18,.34]:attackType==='heavy'?[.07,.36]:[.035,.19];
  return {type,active:isActive,side:punchSide,age,duration:attackDuration(),contactActive:isActive&&age>=window[0]&&age<=window[1],contactSides:heavyDouble?['l','r']:[punchSide<0?'l':'r'],contactKind:heavyDouble||attackType==='kick'?'foot':'fist',desiredForwardDistance:travel,locksMovement:heavyDouble&&isActive,visualLift:lift*unit};
 }
 return {apply};
}
