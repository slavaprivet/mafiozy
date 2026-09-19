import {COVER_ENTRY_SECONDS} from './hero_cover_motion.mjs';
import {vehicleCoverContact} from './hero_cover_contact.mjs';
import {COVER,findCover,moveCover,advanceCoverCorner,coverExposure} from './hero_cover.mjs';
import {applyCoverPose} from './hero_cover_pose.mjs';
import {resolveWeaponShotTransforms} from './weapon_effects.mjs';

// /walk owns feet, posture, inventory and collision. This controller only keeps
// a validated edge attachment and asks those owners to admit each movement.
export function createHeroCover({THREE,document,getHero,getWeapon,getBodies,canOccupy,allowed,requestPosture,getPosture,onMove,onEnter,obstacles,groundHeight=()=>0,contactQuery=vehicleCoverContact,profile=null}) {
 let entryPosture='stand',cover=null,exposure=null,blend=0,poseReady=false,fireReady=false,clock=0,lastFire=-Infinity,heightSampleAt=-Infinity,attachmentId=0,poseDt=0,contactAt=-Infinity,contactWeight=1,contactShift=new THREE.Vector3(),entry=null,lastSide=1,lastMoveAt=-Infinity,moveAlong=0,lastHint='',diagnosticAt=-Infinity,edgePush=0,cornerInput=null,contactKey='',heightKey='',contactCaching=true,pendingEntry=null,hiddenHeight=Infinity,surfaceHeight=null,heightPreview=false;
 const offset=new THREE.Vector3(),ray=new THREE.Raycaster();
 const hint=document.createElement('div');hint.id='hero-cover-hint';hint.hidden=true;
 hint.setAttribute('role','status');hint.style.cssText='position:fixed;bottom:155px;left:50%;transform:translateX(-50%);max-width:560px;padding:9px 14px;border:1px solid #ae9d72;border-radius:6px;background:#172328ec;color:#f6ebd1;z-index:38;text-align:center;font:14px system-ui;pointer-events:none';document.body.append(hint);
 const visible=hit=>{for(let n=hit.object;n;n=n.parent)if(!n.visible)return false;const materials=Array.isArray(hit.object.material)?hit.object.material:[hit.object.material];return materials.some(m=>m&&(m.transmission||0)<.2&&(!m.transparent||m.opacity>.65));};
 function blocked(from,to){const direction=to.clone().sub(from),length=direction.length();if(length<.001)return false;ray.set(from,direction.divideScalar(length));ray.near=.015;ray.far=length;return ray.intersectObjects(obstacles(from,ray.ray.direction,length),true).some(visible);}
 function leave(reason="released"){pendingEntry=null;hiddenHeight=Infinity;surfaceHeight=null;heightPreview=false;entry=null;edgePush=0;cornerInput=null;contactKey='';heightKey='';moveAlong=0;lastHint='';contactWeight=1;contactAt=-Infinity;contactShift.set(0,0,0);lastFire=-Infinity;cover=null;exposure=null;blend=0;offset.set(0,0,0);poseReady=fireReady=false;hint.hidden=true;document.body.dataset.heroCover=JSON.stringify({active:false,reason});}
 function toggle(direction){
  if(cover){const restore=entryPosture;leave();requestPosture(restore);return true;}if(!allowed())return false;
  const hero=getHero();cover=findCover({position:hero.object.position,direction,bodies:getBodies(hero.object.position),canOccupy});
  if(!cover){hint.hidden=false;hint.textContent='Подойдите ближе к стене или машине · Ctrl — в укрытие';setTimeout(()=>{if(!cover)hint.hidden=true;},1800);return false;}
  pendingEntry=null;hiddenHeight=cover.height;surfaceHeight=cover.height;entryPosture=getPosture().target||(getPosture().value>.95?'crouch':'stand');attachmentId++;onEnter();requestPosture(cover.posture);
  entry={from:hero.object.position.clone(),yaw:hero.object.rotation.y,elapsed:0};lastSide=cover.along<cover.length/2?-1:1;
  return true;
 }
 // A short explicit Ctrl request survives a transient busy/grounded frame or
 // the final approach step. Ordinary movement never starts attachment itself.
 function request(direction){
  if(cover)return toggle(direction);
  if(toggle(direction))return true;
  pendingEntry={direction:{x:direction.x,z:direction.z},until:clock+.4,retry:clock+.1};return false;
 }
 function move(delta,{sprinting=false}={}){
  if(!cover)return null;
  if(sprinting&&delta.lengthSq()>1e-8){if(!canOccupy(getHero().object.position,COVER.standingHeight))return false;leave('sprint');requestPosture('stand');return null;}
  if(entry)return false;
  lastMoveAt=clock;const before=getHero().object.position.clone(),distance=delta.length();
  if(cover.cornerTravel){const sign=cornerInput&&delta.x*cornerInput.x+delta.z*cornerInput.z<-.001?-1:1;cover=advanceCoverCorner(cover,cover.cornerTravel.side,sign*distance,canOccupy);}
  else{
   moveAlong=delta.x*cover.tangent.x+delta.z*cover.tangent.z;if(Math.abs(moveAlong)>.001)lastSide=Math.sign(moveAlong);
   const previousAlong=cover.along;cover=moveCover(cover,moveAlong,canOccupy);
   if(Math.abs(cover.along-previousAlong)<.001&&Math.abs(moveAlong)>.001&&exposure?.mode==='hidden'){
    edgePush+=Math.abs(moveAlong);
    if(edgePush>.28){cornerInput={x:cover.tangent.x*lastSide,z:cover.tangent.z*lastSide};cover=advanceCoverCorner(cover,lastSide,Math.min(distance,.08),canOccupy);}
   }else edgePush=0;
  }
  getHero().object.position.set(cover.anchor.x,cover.anchor.y,cover.anchor.z);const shift=getHero().object.position.clone().sub(before);onMove(shift);return shift.lengthSq()>1e-8;
 }
 function update(dt,{direction,aiming,firing}){
  clock+=dt;poseDt=dt;
  if(!cover&&pendingEntry){if(clock>pendingEntry.until)pendingEntry=null;else if(clock>=pendingEntry.retry){pendingEntry.retry=clock+.1;if(allowed())toggle(pendingEntry.direction);}}
  if(!cover)return;
  if(!allowed()){leave('unavailable');return;}
  if(cover.body.valid===false||(typeof cover.body.valid==='function'&&cover.body.valid()===false)){leave('surface-moved');return;}
  if(!canOccupy(cover.anchor,cover.posture==='crouch'?COVER.crouchingHeight:COVER.standingHeight)){leave('capsule-blocked');return;}
  if(clock-lastMoveAt>.12){moveAlong=0;edgePush=0;}
  if(entry){entry.elapsed+=dt;const t=Math.min(1,entry.elapsed/COVER_ENTRY_SECONDS),weight=t*t*(3-2*t),before=getHero().object.position.clone(),destination=new THREE.Vector3(cover.anchor.x,cover.anchor.y,cover.anchor.z);getHero().object.position.lerpVectors(entry.from,destination,weight);onMove(getHero().object.position.clone().sub(before));if(t===1)entry=null;}
  const nextHeightKey=Math.round(cover.anchor.x*10)+':'+Math.round(cover.anchor.z*10);
  if(cover.body.heightAt&&clock-heightSampleAt>.12&&(heightPreview||nextHeightKey!==heightKey||clock-heightSampleAt>1)){
   heightKey=nextHeightKey;heightSampleAt=clock;
   const moving=Math.abs(moveAlong)>.001&&!cover.cornerTravel;
   const aheadAlong=Math.max(COVER.edgeMargin,Math.min(cover.length-COVER.edgeMargin,cover.along+Math.sign(moveAlong)*1.2));
   const preview=moving&&!heightPreview&&Math.abs(aheadAlong-cover.along)>.1;
   heightPreview=preview;
   // Alternate present/ahead probes within the existing query budget, rather
   // than doubling expensive vehicle raycasts in a movement frame.
   const sample=preview?{x:cover.a.x+cover.tangent.x*aheadAlong+cover.normal.x*cover.standOff,y:cover.feetY,z:cover.a.z+cover.tangent.z*aheadAlong+cover.normal.z*cover.standOff}:cover.anchor;
   const top=cover.body.heightAt(sample,cover.normal),height=Number.isFinite(top)?top-cover.feetY:0;
   if(height>=COVER.minHeight)hiddenHeight=Math.min(hiddenHeight,height);
   if(!preview){
    surfaceHeight=height;
    // Seams do not cancel sticky Ctrl attachment. Actual shot rays still
    // decide whether the intervening body protects against each attacker.
    if(height>=COVER.minHeight)cover.height=height;
   }
  }
  if(firing)lastFire=clock;
  exposure=coverExposure(cover,{direction,aiming:!entry&&aiming,firing:!entry&&(firing||clock-lastFire<.20)});
  const target=new THREE.Vector3(exposure.offset.x,exposure.offset.y,exposure.offset.z);
  // A peek cannot put the body inside an adjacent wall, car or low ceiling.
  const peek=getHero().object.position.clone().add(target);
  if(!canOccupy(peek,exposure.posture==='crouch'?COVER.crouchingHeight:COVER.standingHeight)){exposure={...exposure,mode:'blocked',posture:cover.posture};target.set(0,0,0);}
  requestPosture(exposure.posture);offset.lerp(target,1-Math.exp(-12*dt));blend=Math.min(1,blend+dt*6);
  const yaw=Math.atan2(cover.normal.x,cover.normal.z);getHero().object.rotation.y+=Math.atan2(Math.sin(yaw-getHero().object.rotation.y),Math.cos(yaw-getHero().object.rotation.y))*(1-Math.exp(-18*dt));
  poseReady=fireReady=false;
  const message=entry?'Прижимаюсь к укрытию…':cover.cornerTravel?'Обхожу угол · WASD — продолжить или вернуться · Ctrl — выйти':surfaceHeight<COVER.minHeight?'Здесь просвет в укрытии · Двигайтесь вдоль поверхности · Ctrl — выйти':exposure.mode==='blocked'?'Двигайтесь к краю укрытия · Ctrl — выйти':`${cover.body.vehicle?'Укрытие у машины':cover.posture==='crouch'?'Низкое укрытие':'Укрытие стоя'} · WASD — вдоль поверхности · Ctrl — выйти · Shift + движение — бежать · ${getWeapon()?'ПКМ — выглянуть · ЛКМ — огонь вслепую':'Q — достать оружие'}`;
  if(hint.hidden)hint.hidden=false;if(lastHint!==message){hint.textContent=message;lastHint=message;}
 }
 function pose({aimYaw,aimPitch=0}={}){
  if(!cover||!exposure)return;
  const hero=getHero(),context=hero.artistContext(),weapon=getWeapon();
  const local=offset.clone().applyQuaternion(hero.object.quaternion.clone().invert());context.visualPivot.position.add(local);hero.object.updateMatrixWorld(true);
  let gunPosition=null;
  if(exposure.muzzle&&weapon){
   const q=new THREE.Quaternion().setFromEuler(new THREE.Euler(-aimPitch,aimYaw,0,'YXZ'));
   const muzzleOffset=new THREE.Vector3(...(weapon.userData.muzzle||[0,0,.3])).multiply(weapon.getWorldScale(new THREE.Vector3())).applyQuaternion(q);
   gunPosition=new THREE.Vector3(exposure.muzzle.x,exposure.muzzle.y,exposure.muzzle.z).sub(muzzleOffset);
  }
  const result=applyCoverPose(THREE,context,{mode:exposure.mode,normal:cover.normal,side:exposure.side,low:cover.posture==='crouch',coverHeight:exposure.mode==='aimed'?cover.height:Math.min(cover.height,hiddenHeight),blend,weapon,gunPosition,aimYaw,aimPitch,dt:poseDt,attachmentId,moveAlong,carrySide:Math.sign((cover.tangent.x*cover.normal.z-cover.tangent.z*cover.normal.x)*lastSide)||1});
  if(cover.body.vehicle&&cover.body.source?.car?.object){
   const nextContactKey=exposure.mode+':'+Math.round(getPosture().value*20)+':'+Math.round(blend*8)+':'+Math.round(cover.anchor.x*20)+':'+Math.round(cover.anchor.z*20)+':'+Math.round(hero.object.rotation.y*20)+':'+(result?.transitionReady?1:Math.round(clock*10));
   if(poseDt>0&&!cover.cornerTravel&&clock-contactAt>.10&&(!contactCaching||nextContactKey!==contactKey||clock-contactAt>1)){contactAt=clock;contactKey=nextContactKey;const query=()=>contactQuery(THREE,context,cover.body.source.car.object,cover.normal),contact=profile?profile.measure('coverContact',query):query();contactShift.set(contact.x,0,contact.z);}
   if(cover.cornerTravel){contactKey='';contactShift.set(0,0,0);}
   if(poseDt>0)contactWeight+=((exposure.mode==='aimed'||edgePush>0||cover.cornerTravel?0:1)-contactWeight)*(1-Math.exp(-22*poseDt));context.visualPivot.position.add(contactShift.clone().multiplyScalar(contactWeight).applyQuaternion(hero.object.quaternion.clone().invert()));hero.object.updateMatrixWorld(true);
  }
  if(result&&weapon)result.gunPosition=weapon.getWorldPosition(new THREE.Vector3());
  poseDt=0;poseReady=!!result?.applied;
  if(weapon&&poseReady&&['aimed','blind'].includes(exposure.mode)){
   hero.object.updateMatrixWorld(true);const transforms=resolveWeaponShotTransforms(THREE,weapon),mount=weapon.getWorldPosition(new THREE.Vector3());
   const expected=exposure.posture==='crouch'?1:0,postureReady=Math.abs(getPosture().value-expected)<.08;
   const direction=new THREE.Vector3(Math.sin(aimYaw)*Math.cos(aimPitch),Math.sin(aimPitch),Math.cos(aimYaw)*Math.cos(aimPitch));
   fireReady=!entry&&postureReady&&blend>.95&&result.transitionReady!==false&&result.requestedReachable!==false&&result.selfClear!==false&&!blocked(mount,transforms.origin)&&!blocked(transforms.origin,transforms.origin.clone().addScaledVector(direction,.22));
  }
  if(clock-diagnosticAt>.10){diagnosticAt=clock;document.body.dataset.heroCover=JSON.stringify({active:true,entering:!!entry,corner:!!cover.cornerTravel,id:cover.id,height:cover.height,surfaceHeight,concealmentHeight:hiddenHeight,posture:cover.posture,mode:exposure.mode,fireReady,poseReady,along:cover.along,length:cover.length,normal:cover.normal,anchor:cover.anchor,offset:offset.toArray(),gunPosition:result?.gunPosition,reach:result?.requestedReachable,selfClear:result?.selfClear,actualHeadTop:result?.actualHeadTop,fullyConcealed:result?.fullyConcealed,minimumHeadTop:result?.minimumHeadTop,concealmentDepth:result?.concealmentDepth});}
  return result;
 }
 function resolveDamage({sourceR,sourceC,sourceHeight=1.45}={}){
  if(!cover||!Number.isFinite(sourceR)||!Number.isFinite(sourceC))return null;
  const source=new THREE.Vector3(sourceC*4.1,0,sourceR*4.1);source.y=groundHeight(source.x,source.z)+sourceHeight;
  const ctx=getHero().artistContext();ctx.object.updateMatrixWorld(true);
  // Test the posed body, including the arms exposed by blind fire. Protection
  // comes from intervening geometry and disappears for flanking attackers.
  let visibleWeight=0,total=0;
  for(const [bone,weight]of [['head',.20],['chest',.35],['pelvis',.25],['hand_r',.10],['hand_l',.10]]){
   total+=weight;const point=ctx.worldPosition(bone);if(!blocked(source,point))visibleWeight+=weight;
  }
  return visibleWeight<.001?{blocked:true}:{multiplier:visibleWeight/total};
 }
 return {get active(){return !!cover;},get state(){return cover;},setContactCaching(enabled){contactCaching=!!enabled;contactAt=-Infinity;return contactCaching;},get entering(){return !!entry;},get shoulder(){return exposure?.side||lastSide;},get mode(){return exposure?.mode||'hidden';},get canFire(){return !cover||fireReady;},get offset(){return offset;},toggle,request,leave,move,update,pose,resolveDamage};
}
