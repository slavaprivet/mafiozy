// Artist13 appearance and presentation only. Host owns controls/server/combat.
import {createArtist14Melee} from './hero_artist14_melee.mjs';
import {posturePresentation} from './hero_posture.mjs';
import {sampleMeleePresentation,sampleReloadPresentation} from './hero_motion_presentation.mjs';
export const HERO_ASSET=Object.freeze({url:new URL('./hero_models/player_male.8130dfb1f7eb.glb',import.meta.url).href,bytes:652732,sha256:'8130dfb1f7eb91bff31e932fEEF1717672070a6767ccc726d7cb1ee23133fd00'.toLowerCase()});
const required=['chest','neck','head','socket_weapon','socket_hand_l','socket_hand_r','hand_l','hand_r','thigh_l','thigh_r','shin_l','shin_r','foot_l','foot_r','upperarm_l','upperarm_r','forearm_l','forearm_r'];
export function createHeroWalker({THREE,scene,targetHeight=1.9}){
  if(!THREE||!scene||!Number.isFinite(targetHeight)||targetHeight<1||targetHeight>3)throw Error('Invalid hero host/height');
  scene.updateMatrixWorld(true);
  const bones={},rest={};scene.traverse(o=>{if(o.isBone){bones[o.name]=o;const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();o.matrix.decompose(p,q,s);rest[o.name]={matrix:o.matrix.clone(),p,q,s};o.matrixAutoUpdate=false;}
    if(o.isMesh){o.castShadow=true;o.receiveShadow=true;o.frustumCulled=false;}});
  for(const name of required)if(!bones[name])throw Error('Missing Artist13 rest node '+name);
  const box=new THREE.Box3().setFromObject(scene),size=box.getSize(new THREE.Vector3()),sourceHeight=size.y;
  if(!Number.isFinite(sourceHeight)||sourceHeight<=0)throw Error('Empty hero bounds');
  const object=new THREE.Group(),visualPivot=new THREE.Group(),scaled=new THREE.Group(),offset=new THREE.Group();object.name='Artist13_Walk_Hero';scaled.scale.setScalar(targetHeight/sourceHeight);
  offset.position.set(-(box.min.x+box.max.x)/2,-box.min.y,-(box.min.z+box.max.z)/2);offset.add(scene);scaled.add(offset);visualPivot.add(scaled);object.add(visualPivot);
  let phase=0,gait=0,vehicleHeadYaw=0,vehicleGripAssignment='none',disposed=false;
  const euler=new THREE.Euler(),delta=new THREE.Quaternion(),posed=new THREE.Quaternion();
  const restore=()=>{visualPivot.rotation.set(0,0,0);visualPivot.position.set(0,0,0);for(const[name,bone]of Object.entries(bones)){bone.matrix.copy(rest[name].matrix);bone.matrixWorldNeedsUpdate=true;}};
  const rotate=(name,x=0,y=0,z=0)=>{const bone=bones[name],r=rest[name];if(!bone)return;delta.setFromEuler(euler.set(x,y,z));posed.copy(r.q).multiply(delta);bone.matrix.compose(r.p,posed,r.s);bone.matrixWorldNeedsUpdate=true;};
  const reset=()=>{phase=0;gait=0;vehicleHeadYaw=0;vehicleGripAssignment='none';scaled.position.y=0;restore();if(mountedWeapon)applyReloadPose(mountedWeapon,0);object.updateMatrixWorld(true);};
  function update(dt,moving=false,running=false,weapon=null,aim={},presentation={}){
    if(disposed)return;dt=Math.min(.1,Math.max(0,Number.isFinite(dt)?dt:0));
    gait+=(Number(moving)-gait)*(1-Math.exp(-10*dt));if(!moving&&gait<.0001)gait=0;
    const posture=posturePresentation(presentation.posture||aim.posture||{target:'stand',value:0,blocked:false},{running});
    phase+=dt*(moving?(posture.prone>.5?3.8:posture.maxSpeed*2.3):3);restore();
    if(Number.isFinite(aim.aimYaw))visualPivot.rotation.y=aim.aimYaw-object.rotation.y;
    if(gait){rotate('chest',0,0,Math.sin(phase)*gait*.018);for(const[side,sign]of[['l',1],['r',-1]]){
      const step=Math.sin(phase)*sign*gait;rotate('thigh_'+side,step*.56);rotate('shin_'+side,Math.max(0,-step)*.52);rotate('foot_'+side,-step*.22);
      rotate('upperarm_'+side,-step*.38);rotate('forearm_'+side,-Math.max(0,step)*.12);
    }}
    scaled.position.y=Math.abs(Math.sin(phase))*gait*.026*(1-posture.prone);posturePose(posture,moving);object.updateMatrixWorld(true);
    if(weapon){weaponPose(weapon,{...aim,posture,reloadProgress:presentation.reloadProgress});applyReloadPose(mountedWeapon||weapon,presentation.reloadProgress,posture)}
    else meleePose(presentation.action||aim.action,posture);
    if(Number.isFinite(aim.aimYaw))lookAlongAim(aim.aimYaw,aim.aimPitch);
    if(posture.prone>.001)groundPose();
  }
  function rotateAdd(name,x=0,y=0,z=0){const bone=bones[name],r=rest[name];if(!bone)return;const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);q.multiply(new THREE.Quaternion().setFromEuler(euler.set(x,y,z)));bone.matrix.compose(r.p,q,r.s);bone.matrixWorldNeedsUpdate=true;}
  function posturePose(posture,moving){
    const c=posture.crouch,p=posture.prone,crawl=p*gait,cycle=Math.sin(phase),bob=Math.cos(phase*2);
    if(c<1e-5&&p<1e-5)return;
    object.updateMatrixWorld(true);const feet={};for(const side of ['l','r'])feet[side]={p:worldPosition('foot_'+side),q:bones['foot_'+side].getWorldQuaternion(new THREE.Quaternion())};
    const pelvisRest=rest.pelvis,pivot=new THREE.Vector3(0,1.46,0);delta.setFromEuler(euler.set(p*Math.PI/2,0,0));
    // The authored pelvis bone is at .20, not at the virtual hip pivot1.46.
    // Match the reference's orbit about the hip before lowering the body.
    const pelvisPosition=pelvisRest.p.clone().sub(pivot).applyQuaternion(delta).add(pivot);pelvisPosition.y-=c*.60+p*.60;
    posed.copy(pelvisRest.q).multiply(delta);bones.pelvis.matrix.compose(pelvisPosition,posed,pelvisRest.s);bones.pelvis.matrixWorldNeedsUpdate=true;
    // The pelvis rotates about its authored hip. Lift the prone presentation so
    // the deformed chest/arms rest on the floor instead of passing through it.
    // No arbitrary world-space lift: final skinned floor contact resolves below.
    rotateAdd('chest',c*.16-p*.12+crawl*bob*.02,crawl*cycle*.04,crawl*cycle*.035);
    rotateAdd('neck',-p*.40);rotateAdd('head',-p*.55);
    object.updateMatrixWorld(true);
    for(const[side,sign]of[['l',-1],['r',1]]){
      const stride=cycle*sign*gait;
      const rootQ=visualPivot.getWorldQuaternion(new THREE.Quaternion());
      // Extend back from the actual hip; fixed world targets folded the knees.
      const proneFoot=worldPosition('thigh_'+side).add(new THREE.Vector3(sign*(.05+Math.max(0,stride)*.12),-.18,-1.16+Math.max(0,stride)*.20).multiplyScalar(targetHeight/sourceHeight).applyQuaternion(rootQ));
      const footTarget=feet[side].p.clone().lerp(proneFoot,p);
      const footQ=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0).applyQuaternion(rootQ),p*.95).multiply(feet[side].q);
      reachFoot(side,footTarget,footQ,p);
      if(p>.001&&!mountedWeapon){
        const palm=worldPosition('socket_hand_'+side),support=offset.localToWorld(new THREE.Vector3(sign*.78,.30+Math.max(0,stride)*.08,2.12+stride*.23));
        reachPalm(side,palm.lerp(support,p),visualPivot.getWorldQuaternion(new THREE.Quaternion()).multiply(handRest[side]));
      }
    }
  }
  function reachFoot(side,target,footQ,prone=0){
    const thigh='thigh_'+side,shin='shin_'+side,foot='foot_'+side,hip=worldPosition(thigh),a=hip.distanceTo(worldPosition(shin)),b=worldPosition(shin).distanceTo(worldPosition(foot)),line=target.clone().sub(hip),distance=Math.min(a+b-1e-6,Math.max(Math.abs(a-b)+1e-6,line.length()));line.normalize();
    const rootQ=visualPivot.getWorldQuaternion(new THREE.Quaternion()),bend=new THREE.Vector3((side==='r'?1:-1)*prone*.15,-prone,1-prone*1.12).applyQuaternion(rootQ);bend.addScaledVector(line,-bend.dot(line)).normalize();const along=(a*a-b*b+distance*distance)/(2*distance),height=Math.sqrt(Math.max(0,a*a-along*along)),knee=hip.clone().addScaledVector(line,along).addScaledVector(bend,height);
    pointBone(thigh,shin,knee);pointBone(shin,foot,target);worldRotation(foot,footQ);
  }
  function dispose(){if(disposed)return;disposed=true;object.removeFromParent();const gs=new Set(),ms=new Set(),ts=new Set();scene.traverse(o=>{if(o.geometry)gs.add(o.geometry);for(const m of Array.isArray(o.material)?o.material:o.material?[o.material]:[])ms.add(m);});for(const m of ms){for(const v of Object.values(m))if(v?.isTexture)ts.add(v);m.dispose();}for(const t of ts)t.dispose();for(const g of gs)g.dispose();}
  function vehiclePose(seated=0,reach=0,entryData=null){
    seated=Math.max(0,Math.min(1,+seated||0));reach=Math.max(0,Math.min(1,+reach||0));
    const staged=entryData&&typeof entryData==='object',value=(key,fallback)=>Number.isFinite(+entryData?.[key])?Math.max(0,Math.min(1,+entryData[key])):fallback;
    // Exit poses intentionally omit staged leg fields and retain the proven
    // symmetric fold. Entry may fold the cabin-side leg first, then the leg by
    // the open door, matching the actual doorway sequence.
    const inner=value('innerLeg',seated),outer=value('outerLeg',seated),duck=value('duck',0),handReach=value('handReach',reach),closeReach=value('closeReach',0),doorSide=entryData?.side<0?'r':'l',driver=entryData?.driver!==false;
    const dt=Math.min(.1,Math.max(0,Number.isFinite(+entryData?.dt)?+entryData.dt:1/60)),steer=driver&&Number.isFinite(+entryData?.steer)?Math.max(-1,Math.min(1,+entryData.steer)):0,targetHeadYaw=steer*.42;
    vehicleHeadYaw+=(targetHeadYaw-vehicleHeadYaw)*(1-Math.exp(-6*dt));
    const chestPitch=seated*.48+duck*.3;
    restore();scaled.position.y=0;rotate('chest',chestPitch,0,(entryData?.side<0?-1:1)*(handReach*.1-closeReach*.08));rotate('neck',-chestPitch*.72,vehicleHeadYaw*.72);rotate('head',-chestPitch*.28,vehicleHeadYaw*.28);
    for(const side of ['l','r']){
      const leg=staged?(side===doorSide?outer:inner):seated,doorArm=side===doorSide?handReach:0,closeArm=side===doorSide?closeReach:0;
      rotate('thigh_'+side,-leg*1.7);rotate('shin_'+side,leg*.94);rotate('foot_'+side,-leg*.09);
      const driverUpper=-seated*(side==='l'?.82:.72)-reach*(side==='l'?.65:.1),passengerUpper=-seated*.34,driverFore=-seated*.42-reach*.3,passengerFore=-seated*.92;
      rotate('upperarm_'+side,(driver?driverUpper:passengerUpper)-doorArm*.42-closeArm*.28,0,(side==='l'?1:-1)*(doorArm*.58-closeArm*.34+(driver?0:.16*seated)));
      rotate('forearm_'+side,(driver?driverFore:passengerFore)-doorArm*.55-closeArm*.42,0,(side==='l'?-1:1)*(driver?0:.1*seated));
    }
    object.updateMatrixWorld(true);
    const steeringGrips=entryData?.steeringGrips;
    if(driver&&steeringGrips?.left?.isVector3&&steeringGrips?.right?.isVector3){
      const palms={l:worldPosition('socket_hand_l'),r:worldPosition('socket_hand_r')},direct=palms.l.distanceTo(steeringGrips.left)+palms.r.distanceTo(steeringGrips.right),crossed=palms.l.distanceTo(steeringGrips.right)+palms.r.distanceTo(steeringGrips.left),targets=direct<=crossed?{l:steeringGrips.left,r:steeringGrips.right}:{l:steeringGrips.right,r:steeringGrips.left};
      vehicleGripAssignment=direct<=crossed?'direct':'nearest-cross-map';
      const rootQ=object.getWorldQuaternion(new THREE.Quaternion());
      for(const side of ['l','r'])reachPalm(side,targets[side].clone(),rootQ.clone().multiply(handRest[side]));
      object.updateMatrixWorld(true);
    }else vehicleGripAssignment=driver?'driver-fallback':'passenger-lap';
  }
  const poseMeshes=[];scene.traverse(mesh=>{if(mesh.isMesh)poseMeshes.push(mesh)});
  const inverseRoot=new THREE.Matrix4(),sample=new THREE.Vector3();
  const smooth=t=>{t=Math.max(0,Math.min(1,t));return t*t*(3-2*t)};
  function groundPose(){
    object.updateMatrixWorld(true);inverseRoot.copy(object.matrixWorld).invert();let lowest=Infinity;
    for(const mesh of poseMeshes){if(mesh.isSkinnedMesh)mesh.skeleton.update();const vertices=mesh.geometry.attributes.position;for(let i=0;i<vertices.count;i++){sample.fromBufferAttribute(vertices,i);if(mesh.isSkinnedMesh)mesh.applyBoneTransform(i,sample);sample.applyMatrix4(mesh.matrixWorld).applyMatrix4(inverseRoot);lowest=Math.min(lowest,sample.y)}}
    if(Number.isFinite(lowest))visualPivot.position.y-=lowest;object.updateMatrixWorld(true);
  }
  const jumpYawQ=new THREE.Quaternion(),jumpTiltQ=new THREE.Quaternion(),jumpAxis=new THREE.Vector3();
  function jumpPose(progress,directional=true,weapon=null,aim={}){
    if(disposed)return;
    const p=Math.max(0,Math.min(1,Number.isFinite(progress)?progress:0));
    // Flight occupies 64% of the action; the remainder absorbs the landing and stands up.
    const launch=smooth(p/.14),recover=smooth((p-.64)/.36);
    const landing=smooth((p-.5)/.14)*(1-smooth((p-.72)/.28));
    const downAim=weapon?smooth((-(Number.isFinite(aim.aimPitch)?aim.aimPitch:0)-.4)/.7):0,air=launch*(1-recover)*(1-downAim*landing);
    restore();scaled.position.y=0;
    if((p===0||p===1)&&!weapon&&!Number.isFinite(aim.aimYaw)){groundPose();return;}
    const aimYaw=Number.isFinite(aim.aimYaw)?aim.aimYaw:object.rotation.y,relative=aimYaw-object.rotation.y;
    jumpYawQ.setFromAxisAngle(jumpAxis.set(0,1,0),relative);
    jumpTiltQ.setFromAxisAngle(jumpAxis.set(Math.cos(-relative),0,-Math.sin(-relative)),directional?air*1.2:0);
    visualPivot.quaternion.copy(jumpYawQ).multiply(jumpTiltQ);
    // Keep the gaze on the travel line while the body pitches into the dive.
    // Without this counter-rotation the whole face points mostly at the ground.
    if(directional){rotate('neck',-air*.82);rotate('head',-air*.38)}
    rotate('chest',directional?landing*.22:landing*.35);
    for(const[side,sign]of [['l',1],['r',-1]]){
      rotate('thigh_'+side,-air*(directional?.2:.65)-landing*.8);
      rotate('shin_'+side,air*(directional?.4:.8)+landing*.85);
      rotate('foot_'+side,-air*.14-landing*.15);
      rotate('upperarm_'+side,-air*(directional?1.45:.65),0,sign*air*.15);
      rotate('forearm_'+side,-air*(directional?.35:.8));
    }
    // Root height is the ballistic trajectory; keep even the extended diving mesh above it.
    groundPose();
    if(weapon)weaponPose(weapon,{...aim,airborne:true,airBlend:air});
    if(weapon||Number.isFinite(aim.aimYaw))lookAlongAim(aimYaw,aim.aimPitch);
  }
  function tumblePose(progress,rolls=1){
    const p=Math.max(0,Math.min(1,progress)),smooth=t=>{t=Math.max(0,Math.min(1,t));return t*t*(3-2*t)},tuck=1-smooth((p-.72)/.28);
    restore();rotate('chest',tuck*.95);for(const side of ['l','r']){rotate('thigh_'+side,-tuck*1.9);rotate('shin_'+side,tuck*1.35);rotate('upperarm_'+side,-tuck*1.3);rotate('forearm_'+side,-tuck*1.1)}
    scaled.position.y=-.65;visualPivot.position.y=.65;visualPivot.rotation.x=Math.PI*2*rolls*smooth((p-.06)/.64);object.updateMatrixWorld(true);
    // Ground the actual deformed mesh, not a standing capsule, through the somersault.
    groundPose();
  }
  let mountedWeapon=null;
  // The authored arm bones have diagonal local axes: fixed Euler angles do not
  // produce a forward grip. Solve in world space without stretching the skin.
  const handRest={};
  for(const side of ['l','r'])handRest[side]=object.getWorldQuaternion(new THREE.Quaternion()).invert().multiply(bones['hand_'+side].getWorldQuaternion(new THREE.Quaternion()));
  const headRest=object.getWorldQuaternion(new THREE.Quaternion()).invert().multiply(bones.head.getWorldQuaternion(new THREE.Quaternion()));
  const reloadRest=new WeakMap();
  function lookAlongAim(aimYaw,aimPitch){
    const look=object.getWorldQuaternion(new THREE.Quaternion()).multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0,1,0),aimYaw-object.rotation.y));
    const pitch=Math.max(-1.28,Math.min(1.28,Number.isFinite(aimPitch)?aimPitch:0));
    look.multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),-pitch));worldRotation('head',look.multiply(headRest));
  }
  const worldPosition=name=>bones[name].getWorldPosition(new THREE.Vector3());
  function worldRotation(name,q){
    const bone=bones[name],r=rest[name],parentQ=bone.parent.getWorldQuaternion(new THREE.Quaternion());
    bone.matrix.compose(r.p,parentQ.invert().multiply(q),r.s);bone.matrixWorldNeedsUpdate=true;object.updateMatrixWorld(true);
  }
  function pointBone(name,end,target){
    const origin=worldPosition(name),from=worldPosition(end).sub(origin).normalize(),to=target.clone().sub(origin).normalize();
    const swing=new THREE.Quaternion().setFromUnitVectors(from,to);
    worldRotation(name,swing.multiply(bones[name].getWorldQuaternion(new THREE.Quaternion())));
  }
  function reachPalm(side,target,handQ){
    const upper='upperarm_'+side,fore='forearm_'+side,hand='hand_'+side,palm='socket_hand_'+side;
    const rootQ=object.getWorldQuaternion(new THREE.Quaternion());
    const wristOffset=rest[palm].p.clone().multiplyScalar(targetHeight/sourceHeight).applyQuaternion(handQ);
    const wrist=target.clone().sub(wristOffset),shoulder=worldPosition(upper);
    const a=shoulder.distanceTo(worldPosition(fore)),b=worldPosition(fore).distanceTo(worldPosition(hand));
    const line=wrist.clone().sub(shoulder),distance=Math.min(a+b-1e-6,Math.max(Math.abs(a-b)+1e-6,line.length()));line.normalize();
    const bend=new THREE.Vector3(side==='r'?.35:-.35,-1,-.15).applyQuaternion(rootQ);bend.addScaledVector(line,-bend.dot(line)).normalize();
    const along=(a*a-b*b+distance*distance)/(2*distance),height=Math.sqrt(Math.max(0,a*a-along*along));
    const elbow=shoulder.clone().addScaledVector(line,along).addScaledVector(bend,height);
    pointBone(upper,fore,elbow);pointBone(fore,hand,wrist);worldRotation(hand,handQ);
  }
  let meleeResult=null;
  function meleePose(action,posture){meleeResult=artistMelee.apply(action,posture,phase,gait);return meleeResult;}

  function applyReloadPose(weapon,progress,posture={crouch:0,prone:0}){
    let record=reloadRest.get(weapon);if(!record){const nodes=[],slides=[];weapon.traverse?.(node=>{if(/^(magazine|drum_magazine)$/i.test(node.name))nodes.push({node,position:node.position.clone()});if(/^slide$/i.test(node.name))slides.push({node,position:node.position.clone()})});record={nodes,slides};reloadRest.set(weapon,record)}
    for(const item of [...record.nodes,...record.slides])item.node.position.copy(item.position);
    if(!Number.isFinite(progress))return;const reload=sampleReloadPresentation(progress);
    for(const item of record.nodes){item.node.position.y-=reload.pull*.62*(1-posture.prone);item.node.position.x-=reload.pull*.25*posture.prone;}
    for(const item of record.slides)item.node.position.z-=reload.bolt*.12;
    weapon.updateMatrixWorld?.(true);
    if(reload.grab>.001&&record.nodes.length){const node=record.nodes[0].node,grip=node.getWorldPosition(new THREE.Vector3());grip.y-=.025*(targetHeight/1.9);const held=worldPosition('socket_hand_l');reachPalm('l',held.lerp(grip,reload.grab),bones.hand_l.getWorldQuaternion(new THREE.Quaternion()));}
  }
  function weaponPose(weapon,{aimPitch=0,recoil=0,recoilYaw=0,aimYaw=object.rotation.y,airborne=false,airBlend=1,posture={crouch:0,prone:0},reloadProgress=0}={}){
    const weaponData=weapon.userData||mountedWeapon?.userData||{},long=Boolean(weapon.twoHanded??weaponData.twoHanded),unit=targetHeight/1.9;
    const pitch=Math.max(-1.28,Math.min(1.28,Number.isFinite(aimPitch)?aimPitch:0));
    const kick=Math.max(0,Math.min(1,Number.isFinite(recoil)?recoil:0)),sideKick=Math.max(-1,Math.min(1,Number.isFinite(recoilYaw)?recoilYaw:0));
    // Recoil moves the complete shoulder chain and chest before IK resolves the
    // palms. As the host envelope decays to zero, restore() returns every bone
    // exactly to its authored matrix without accumulating pose drift.
    if(!airborne){rotateAdd('chest',-kick*(long?.055:.035),sideKick*.035,sideKick*(long?.018:.028));rotateAdd('neck',kick*.022,-sideKick*.018);rotateAdd('head',kick*.014,-sideKick*.012);}
    else for(const [name,x,y,z] of [['chest',-kick*(long?.055:.035),sideKick*.035,sideKick*(long?.018:.028)],['neck',kick*.022,-sideKick*.018,0],['head',kick*.014,-sideKick*.012,0]])rotateAdd(name,x,y,z);
    object.updateMatrixWorld(true);
    const reload=sampleReloadPresentation(reloadProgress);
    const aimQ=new THREE.Quaternion().setFromEuler(euler.set(-pitch-kick*(long?.13:.105)-reload.lower*.16,sideKick*.025,sideKick*.012));
    const rootQ=object.getWorldQuaternion(new THREE.Quaternion()).multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0,1,0),Number.isFinite(aimYaw)?aimYaw-object.rotation.y:0)),weaponQ=rootQ.clone().multiply(aimQ);
    const mount=weaponData.mountOffset||(long?[.15,1.10,.18]:[.24,1.07,.26]);
    const origin=new THREE.Vector3(...mount).multiplyScalar(unit);
    // Keep the butt ahead of the chest surface, including recoil; IK follows
    // the complete prop instead of hiding the stock inside the jacket.
    if(long){origin.z+=.075*unit;origin.x-=.055*unit;}
    origin.y+=scaled.position.y-(posture.crouch||0)*.10-(posture.prone||0)*.43+kick*(long?.018:.028)*unit;origin.z+=(posture.prone||0)*.45-kick*(long?.07:.045)*unit;
    const originWorld=visualPivot.localToWorld(origin),propScale=targetHeight/sourceHeight;
    if((posture.prone||0)>.001){
      // Artist14 accepted source-space prone mount, transformed once through
      // asset normalization/scale. The receiver stays ahead of the cheek.
      const p=posture.prone,proneMount=new THREE.Vector3(long?.36:.43,.70, long?2.35:2.45);
      proneMount.x+=Math.sin(phase)*gait*.045;proneMount.y+=(1+Math.cos(phase*2))*gait*.015;proneMount.z+=Math.cos(phase*2)*gait*.10;
      originWorld.lerp(offset.localToWorld(proneMount),p);
    }
    if(airborne)originWorld.lerp(long?worldPosition('upperarm_r').add(worldPosition('upperarm_l')).multiplyScalar(.5).add(new THREE.Vector3(.03,-.06,.10).multiplyScalar(unit).applyQuaternion(rootQ)):worldPosition('upperarm_r').add(new THREE.Vector3(-.07,-.11,.25).multiplyScalar(unit).applyQuaternion(rootQ)),Math.max(0,Math.min(1,airBlend)));
    originWorld.y-=reload.lower*.03*unit;
    const gripPoint=point=>new THREE.Vector3(...point).multiplyScalar(propScale).applyQuaternion(weaponQ).add(originWorld);
    const palmQ=side=>rootQ.clone().multiply(aimQ).multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),-Math.PI/2)).multiply(handRest[side]);

    const id=weapon.weaponId??weapon.id??weapon.userData?.weaponId??mountedWeapon?.weaponId;
    const support=weaponData.supportGrip??({uzi:[0,-.01,.5],golden_uzi:[0,-.01,.5],tommy_gun:[0,-.1,.62],sawn_off:[0,.1,.42],rpg:[0,.09,.62]}[id])??[0,.1,.62];
    if(long||(posture.prone||0)>.001){
      // Keep both wrists reachable at extreme aim angles and with every prop.
      // Move the prop mount, never stretch a limb to fake a grip.
      const constraints=[['r',[0,-.13,-.02]],...(long?[['l',support]]:[])].map(([side,point])=>{
        const shoulder=worldPosition('upperarm_'+side),radius=shoulder.distanceTo(worldPosition('forearm_'+side))+worldPosition('forearm_'+side).distanceTo(worldPosition('hand_'+side))-.004*unit;
        const center=shoulder.sub(new THREE.Vector3(...point).multiplyScalar(propScale).applyQuaternion(weaponQ)).add(rest['socket_hand_'+side].p.clone().multiplyScalar(propScale).applyQuaternion(palmQ(side)));
        return {center,radius};
      });
      for(let i=0;i<16;i++)for(const {center,radius} of constraints){const d=originWorld.clone().sub(center);if(d.length()>radius)originWorld.copy(center).add(d.setLength(radius));}
    }
    reachPalm('r',gripPoint([0,-.13,-.02]),palmQ('r'));
    const reloadTarget=gripPoint([-.08,-.34,.12]);
    if(long||reload.grab>.001){const supportTarget=long?gripPoint(support):worldPosition('socket_hand_l');reachPalm('l',supportTarget.lerp(reloadTarget,reload.grab),palmQ('l'));}
    if(!long&&reload.grab<.001&&(posture.prone||0)>.001){const crawl=gait*Math.sin(phase);reachPalm('l',offset.localToWorld(new THREE.Vector3(-.78,.30+Math.max(0,-crawl)*.08,2.12-crawl*.23)),rootQ.clone().multiply(handRest.l));}
    if(mountedWeapon){
      mountedWeapon.position.copy(bones.socket_weapon.worldToLocal(originWorld.clone()));
      mountedWeapon.quaternion.copy(bones.socket_weapon.getWorldQuaternion(new THREE.Quaternion()).invert().multiply(weaponQ));
    }
    object.updateMatrixWorld(true);
  }
  function mountWeapon(node=null){
    if(mountedWeapon){applyReloadPose(mountedWeapon,0);mountedWeapon.removeFromParent();}mountedWeapon=node;
    if(node){
      node.position.set(0,0,0);
      node.quaternion.identity();
      bones.socket_weapon.add(node);
    }
    object.updateMatrixWorld(true);return node;
  }
  const artistMelee=createArtist14Melee({THREE,bones,rest,offset,visualPivot,object,targetHeight,sourceHeight,rotateAdd,groundPose});
  const artistContext=()=>({object,visualPivot,scaled,offset,scene,bones,rest,targetHeight,sourceHeight,rotate,rotateAdd,reachPalm,groundPose,worldPosition,worldRotation});
  reset();return{artistContext,meleePresentation:()=>meleeResult,object,height:targetHeight,sourceHeight,scale:targetHeight/sourceHeight,frontAxis:'+Z',update,vehiclePose,tumblePose,jumpPose,mountWeapon,reset,dispose,
    diagnostics:()=>({gait,phase,vehicleHeadYaw,vehicleGripAssignment,disposed,boneCount:Object.keys(bones).length,sourceBounds:{min:box.min.toArray(),max:box.max.toArray()},requiredNodes:[...required]})};
}
export async function loadHeroWalker({THREE,loader,targetHeight=1.9,signal}={}){
  if(!loader)throw Error('Host GLTFLoader instance required');
  const response=await fetch(HERO_ASSET.url,{signal});if(!response.ok)throw Error('Hero fetch HTTP '+response.status);
  const bytes=await response.arrayBuffer();if(bytes.byteLength!==HERO_ASSET.bytes)throw Error('Hero bytes mismatch');
  const digest=[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(n=>n.toString(16).padStart(2,'0')).join('');
  if(digest!==HERO_ASSET.sha256)throw Error('Hero SHA256 mismatch');
  if(signal?.aborted)throw new DOMException('Aborted','AbortError');
  const gltf=loader.parseAsync?await loader.parseAsync(bytes,HERO_ASSET.url.slice(0,HERO_ASSET.url.lastIndexOf('/')+1)):await new Promise((resolve,reject)=>loader.parse(bytes,'',resolve,reject));
  return createHeroWalker({THREE,scene:gltf.scene,targetHeight});
}
