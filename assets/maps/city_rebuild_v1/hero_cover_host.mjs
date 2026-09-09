import {vehicleCoverContact} from './hero_cover_contact.mjs';
import {COVER,findCover,moveCover,coverExposure} from './hero_cover.mjs';
import {applyCoverPose} from './hero_cover_pose.mjs';
import {resolveWeaponShotTransforms} from './weapon_effects.mjs';

// /walk owns feet, posture, inventory and collision. This controller only keeps
// a validated edge attachment and asks those owners to admit each movement.
export function createHeroCover({THREE,document,getHero,getWeapon,getBodies,canOccupy,allowed,requestPosture,getPosture,onMove,onEnter,obstacles,groundHeight=()=>0}) {
 let cover=null,exposure=null,blend=0,poseReady=false,fireReady=false,clock=0,lastFire=-Infinity,heightSampleAt=-Infinity,attachmentId=0,poseDt=0,contactAt=-Infinity,contactWeight=1,contactShift=new THREE.Vector3();
 const offset=new THREE.Vector3(),ray=new THREE.Raycaster();
 const hint=document.createElement('div');hint.id='hero-cover-hint';hint.hidden=true;
 hint.setAttribute('role','status');hint.style.cssText='position:fixed;bottom:155px;left:50%;transform:translateX(-50%);max-width:560px;padding:9px 14px;border:1px solid #ae9d72;border-radius:6px;background:#172328ec;color:#f6ebd1;z-index:38;text-align:center;font:14px system-ui;pointer-events:none';document.body.append(hint);
 const visible=hit=>{for(let n=hit.object;n;n=n.parent)if(!n.visible)return false;const materials=Array.isArray(hit.object.material)?hit.object.material:[hit.object.material];return materials.some(m=>m&&(m.transmission||0)<.2&&(!m.transparent||m.opacity>.65));};
 function blocked(from,to){const direction=to.clone().sub(from),length=direction.length();if(length<.001)return false;ray.set(from,direction.divideScalar(length));ray.near=.015;ray.far=length;return ray.intersectObjects(obstacles(from,ray.ray.direction,length),true).some(visible);}
 function leave(){contactWeight=1;contactAt=-Infinity;contactShift.set(0,0,0);lastFire=-Infinity;cover=null;exposure=null;blend=0;offset.set(0,0,0);poseReady=fireReady=false;hint.hidden=true;document.body.dataset.heroCover=JSON.stringify({active:false});}
 function toggle(direction){
  if(cover){leave();return true;}if(!allowed())return false;
  const hero=getHero();cover=findCover({position:hero.object.position,direction,bodies:getBodies(hero.object.position),canOccupy});
  if(!cover){hint.hidden=false;hint.textContent='Подойдите ближе к стене или машине · C — присесть';setTimeout(()=>{if(!cover)hint.hidden=true;},1800);return false;}
  attachmentId++;onEnter();requestPosture(cover.posture);const before=hero.object.position.clone();hero.object.position.set(cover.anchor.x,cover.anchor.y,cover.anchor.z);onMove(hero.object.position.clone().sub(before));
  hero.object.rotation.y=Math.atan2(cover.normal.x,cover.normal.z);return true;
 }
 function move(delta){
  if(!cover)return null;
  if(delta.x*cover.normal.x+delta.z*cover.normal.z>delta.length()*.65){leave();return null;}
  const before=getHero().object.position.clone();cover=moveCover(cover,delta.x*cover.tangent.x+delta.z*cover.tangent.z,canOccupy);
  getHero().object.position.set(cover.anchor.x,cover.anchor.y,cover.anchor.z);const shift=getHero().object.position.clone().sub(before);onMove(shift);return shift.lengthSq()>1e-8;
 }
 function update(dt,{direction,aiming,firing}){
  clock+=dt;poseDt=dt;if(!cover)return;
  if(!allowed()||(cover.body.valid===false||(typeof cover.body.valid==='function'&&cover.body.valid()===false))||!canOccupy(cover.anchor,cover.posture==='crouch'?COVER.crouchingHeight:COVER.standingHeight)){leave();return;}
  if(cover.body.heightAt&&clock-heightSampleAt>.12){heightSampleAt=clock;const top=cover.body.heightAt(cover.anchor);if(Number.isFinite(top))cover.height=top-cover.feetY;if(cover.height<.75){leave();return;}}
  if(firing)lastFire=clock;
  exposure=coverExposure(cover,{direction,aiming,firing:firing||clock-lastFire<.20});
  const target=new THREE.Vector3(exposure.offset.x,exposure.offset.y,exposure.offset.z);
  // A peek cannot put the body inside an adjacent wall, car or low ceiling.
  const peek=getHero().object.position.clone().add(target);
  if(!canOccupy(peek,exposure.posture==='crouch'?COVER.crouchingHeight:COVER.standingHeight)){exposure={...exposure,mode:'blocked',posture:cover.posture};target.set(0,0,0);}
  requestPosture(exposure.posture);offset.lerp(target,1-Math.exp(-12*dt));blend=Math.min(1,blend+dt*6);
  getHero().object.rotation.y=Math.atan2(cover.normal.x,cover.normal.z);
  poseReady=fireReady=false;
  hint.hidden=false;hint.textContent=exposure.mode==='blocked'?'Укрытие закрывает выстрел · двигайтесь к краю · Ctrl — выйти':`${cover.posture==='crouch'?'Низкое укрытие':'Укрытие стоя'} · WASD — вдоль края · Ctrl — выйти · ПКМ — выглянуть · ЛКМ — огонь вслепую`;
  if(!getWeapon())hint.textContent='Укрытие · WASD — вдоль края · Ctrl — выйти · Q — достать оружие';
 }
 function pose({aimYaw,aimPitch=0}={}){
  if(!cover||!exposure)return;
  const hero=getHero(),context=hero.artistContext(),weapon=getWeapon();
  const local=offset.clone().applyQuaternion(hero.object.quaternion.clone().invert());context.visualPivot.position.add(local);hero.object.updateMatrixWorld(true);
  if(cover.body.vehicle&&cover.body.source?.car?.object){
   if(poseDt>0&&clock-contactAt>.10){contactAt=clock;const contact=vehicleCoverContact(THREE,context,cover.body.source.car.object,cover.normal);contactShift.set(contact.x,0,contact.z);}
   if(poseDt>0)contactWeight+=((exposure.mode==='aimed'?0:1)-contactWeight)*(1-Math.exp(-22*poseDt));context.visualPivot.position.add(contactShift.clone().multiplyScalar(contactWeight).applyQuaternion(hero.object.quaternion.clone().invert()));hero.object.updateMatrixWorld(true);
  }
  let gunPosition=null;
  if(exposure.muzzle&&weapon){
   const q=new THREE.Quaternion().setFromEuler(new THREE.Euler(-aimPitch,aimYaw,0,'YXZ'));
   const muzzleOffset=new THREE.Vector3(...(weapon.userData.muzzle||[0,0,.3])).multiply(weapon.getWorldScale(new THREE.Vector3())).applyQuaternion(q);
   gunPosition=new THREE.Vector3(exposure.muzzle.x,exposure.muzzle.y,exposure.muzzle.z).sub(muzzleOffset);
   if(exposure.mode==='aimed'){gunPosition=weapon.getWorldPosition(new THREE.Vector3());if(cover.height<=1.5){const muzzle=resolveWeaponShotTransforms(THREE,weapon).origin;gunPosition.y+=Math.max(0,cover.feetY+cover.height+.12-muzzle.y);}}
  }
  const result=applyCoverPose(THREE,context,{mode:exposure.mode,normal:cover.normal,side:exposure.side,low:cover.posture==='crouch',coverHeight:cover.height,blend,weapon,gunPosition,aimYaw,aimPitch,dt:poseDt,attachmentId});
  poseDt=0;poseReady=!!result?.applied;
  if(weapon&&poseReady&&['aimed','blind'].includes(exposure.mode)){
   hero.object.updateMatrixWorld(true);const transforms=resolveWeaponShotTransforms(THREE,weapon),mount=weapon.getWorldPosition(new THREE.Vector3());
   const expected=exposure.posture==='crouch'?1:0,postureReady=Math.abs(getPosture().value-expected)<.08;
   const direction=new THREE.Vector3(Math.sin(aimYaw)*Math.cos(aimPitch),Math.sin(aimPitch),Math.cos(aimYaw)*Math.cos(aimPitch));
   fireReady=postureReady&&blend>.95&&result.transitionReady!==false&&result.requestedReachable!==false&&result.selfClear!==false&&!blocked(mount,transforms.origin)&&!blocked(transforms.origin,transforms.origin.clone().addScaledVector(direction,.22));
  }
  document.body.dataset.heroCover=JSON.stringify({active:true,id:cover.id,height:cover.height,posture:cover.posture,mode:exposure.mode,fireReady,poseReady,along:cover.along,length:cover.length,normal:cover.normal,anchor:cover.anchor,offset:offset.toArray(),gunPosition:result?.gunPosition,reach:result?.requestedReachable,selfClear:result?.selfClear});
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
 return {get active(){return !!cover;},get state(){return cover;},get mode(){return exposure?.mode||'hidden';},get canFire(){return !cover||fireReady;},get offset(){return offset;},toggle,leave,move,update,pose,resolveDamage};
}
