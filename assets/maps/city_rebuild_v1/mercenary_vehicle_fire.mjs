import {vehicleWindowFrame,planVehicleWindowShot,applyVehicleWindowPose,setVehicleWindowOpen} from './vehicle_window_fire.mjs';
import {createNpcContactRay} from './npc_contact_ray.mjs';

const aliases={pistol:'tt_pistol',pistol_heavy:'deagle',smg:'uzi',rifle:'ak74',golden_ak:'ak74',golden_pistol:'golden_colt',pistol_gold:'golden_colt',golden_tommy:'tommy_gun'};
const supported=new Set(['nagan','tt_pistol','revolver','deagle','golden_colt','uzi','golden_uzi','tommy_gun','sawn_off','shotgun','ak74','m16','sniper']);
export function mercenaryVehicleFireWeapon(value){const id=aliases[value]||value;return supported.has(id)?id:null;}
const point=value=>value&&[value.x,value.y,value.z].every(Number.isFinite);
const visible=object=>{for(let node=object;node;node=node.parent)if(node.visible===false)return false;return !!object?.parent;};
const actorKey=id=>String(id??'').replace(/^npc:/,'').replace(/^npc_/,'').replace(/^crew_/,'');

// Only presentation and physical admission. No HP, ammo, cooldown, or commands.
export function createMercenaryVehicleFirePose({THREE,walker}={}){
 let car=null,seatId=null,frame=null,blend=0,poseBlend=0,riseBlend=0,armBlend=0,result=null,intentKey=null;
 const direction=new THREE.Vector3(),seatPoint=new THREE.Vector3(),muzzleLocal=new THREE.Vector3();let hasMuzzle=false;
 const context=walker.artistContext(),position=new THREE.Vector3(),rotation=new THREE.Quaternion(),boneScale=new THREE.Vector3(),gunPosition=new THREE.Vector3(),gunRotation=new THREE.Quaternion();
 const handReturn=['l','r'].map(side=>({side,p:new THREE.Vector3(),q:new THREE.Quaternion()}));let lastTwoHanded=false;
 // Lift the hands first, then lean and extend the receiver through the window.
 // Return tucks the gun above the sill before the upper body moves inward.
 function setBlend(value){blend=Math.max(0,Math.min(1,value));const rise=Math.min(1,blend/.35),lean=Math.max(0,(blend-.35)/.65);riseBlend=rise*rise*(3-2*rise);poseBlend=lean*lean*(3-2*lean);armBlend=Math.min(1,blend/.45);}
 function upperLean(){
  const c=context,side=frame.side;c.rotateAdd('spine_01',0,0,-side*.6*poseBlend);c.rotateAdd('head',0,0,-side*.45*Math.sin(Math.PI*poseBlend));c.object.updateMatrixWorld(true);
  const local=name=>car.object.worldToLocal(c.worldPosition(name)),head=local('head'),shoulder=local(side>0?'upperarm_r':'upperarm_l'),top=local('socket_head'),plane=Math.max(Math.abs(frame.min[0]),Math.abs(frame.max[0]));
  // Upper torso only: authored window height determines the lift. Pelvis,
  // root and the entire seated leg chain retain their original transforms.
  const dx=side*Math.min(.3,Math.max(0,plane+.14-head.x*side))*poseBlend,
   dy=Math.max(0,Math.min(.5,frame.min[1]+.25-shoulder.y,frame.max[1]-.03-top.y))*riseBlend,
   dz=Math.max(frame.min[2]+.20-Math.min(head.z,shoulder.z),Math.min(0,frame.max[2]-.20-Math.max(head.z,shoulder.z)))*poseBlend;
  const bone=c.bones.spine_01;bone.matrix.decompose(position,rotation,boneScale);
  position.copy(local('spine_01')).add(seatPoint.set(dx,dy,dz));car.object.localToWorld(position);bone.parent.worldToLocal(position);
  bone.matrix.compose(position,rotation,boneScale);bone.matrixWorldNeedsUpdate=true;c.object.updateMatrixWorld(true);
 }

 // Same authored two-bone reach lengths as the walker; only the passenger
 // elbow pole changes so hands outside do not pull sleeves below the sill.
 function reachWindowPalm(side,target,handQ){
  const c=context,upper='upperarm_'+side,fore='forearm_'+side,hand='hand_'+side,palm='socket_hand_'+side;
  const wrist=target.clone().sub(c.rest[palm].p.clone().multiplyScalar(c.targetHeight/c.sourceHeight).applyQuaternion(handQ)),shoulder=c.worldPosition(upper),a=shoulder.distanceTo(c.worldPosition(fore)),b=c.worldPosition(fore).distanceTo(c.worldPosition(hand)),line=wrist.clone().sub(shoulder),distance=Math.min(a+b-1e-6,Math.max(Math.abs(a-b)+1e-6,line.length()));line.normalize();
  const bend=new THREE.Vector3(side==='r'?.35:-.35,.6,-.5).applyQuaternion(car.object.getWorldQuaternion(new THREE.Quaternion()));bend.addScaledVector(line,-bend.dot(line)).normalize();
  const along=(a*a-b*b+distance*distance)/(2*distance),height=Math.sqrt(Math.max(0,a*a-along*along)),elbow=shoulder.clone().addScaledVector(line,along).addScaledVector(bend,height);
  const pointBone=(name,end,target)=>{const origin=c.worldPosition(name),from=c.worldPosition(end).sub(origin).normalize(),to=target.clone().sub(origin).normalize(),swing=new THREE.Quaternion().setFromUnitVectors(from,to);c.worldRotation(name,swing.multiply(c.bones[name].getWorldQuaternion(new THREE.Quaternion())));};
  pointBone(upper,fore,elbow);pointBone(fore,hand,wrist);c.worldRotation(hand,handQ);
 }
 // The shared window solver applies chest/neck/head before solving hands.
 // Add this passenger-only waist lean at that boundary; its weapon/hull/head
 // checks then run against the final actual body rather than an earlier pose.
 const poseContext={...context,reachPalm:reachWindowPalm,rotateAdd(name,...args){context.rotateAdd(name,...args.map(v=>v*poseBlend/Math.max(.001,armBlend)));if(name==='head')upperLean();}};
 function braceFreeHand(weapon){
  if(weapon?(weapon.twoHanded??weapon.userData?.twoHanded):lastTwoHanded)return;
  const hand=frame.side>0?'r':'l',head=car.object.worldToLocal(context.worldPosition('head')),plane=Math.max(Math.abs(frame.min[0]),Math.abs(frame.max[0]));
  const target=car.object.localToWorld(new THREE.Vector3(frame.side*(plane-.10),frame.min[1]+.48,Math.max(frame.min[2]+.15,Math.min(frame.max[2]-.15,head.z+.22))));
  target.lerp(context.worldPosition('socket_hand_'+hand),1-riseBlend);weapon?.getWorldPosition(gunPosition);weapon?.getWorldQuaternion(gunRotation);
  context.reachPalm(hand,target,context.bones['hand_'+hand].getWorldQuaternion(rotation));context.object.updateMatrixWorld(true);
  // A left-handed pistol still lives under the authored right-hand socket.
  // Bracing that free hand must not move the already-validated world muzzle.
  if(weapon){weapon.position.copy(weapon.parent.worldToLocal(gunPosition));weapon.quaternion.copy(weapon.parent.getWorldQuaternion(rotation).invert().multiply(gunRotation));}context.object.updateMatrixWorld(true);
 }
 function reset(){if(car&&seatId)setVehicleWindowOpen(car,seatId,false);car=seatId=frame=result=intentKey=null;blend=poseBlend=riseBlend=armBlend=0;hasMuzzle=false;}
 function apply(dt,{binding,weapon,intent,readiness,allowed=true}={}){
  const presentation=intent||readiness,readyOnly=!intent&&!!readiness;
  const nextCar=binding?.vehicle?.actor,weaponId=mercenaryVehicleFireWeapon(presentation?.weaponId);
  if(!presentation&&allowed&&car===nextCar&&seatId===binding?.seatId&&binding.phase==='drive'&&blend>0){
   const remaining=Math.max(0,blend-Math.max(0,dt)/.22);setBlend(Math.min(1,remaining/.55));blend=remaining;const tuck=Math.min(1,(1-blend)/.45);result={canFire:false,reason:'Возвращаемся в салон'};
   if(blend>0){const c=context,side=frame.side;c.rotateAdd('chest',-.10*poseBlend,side*.92*poseBlend,-side*.46*poseBlend);c.rotateAdd('neck',.08*poseBlend,side*.18*poseBlend,side*.12*poseBlend);c.rotateAdd('head',.02*poseBlend,side*.12*poseBlend,side*.15*poseBlend);upperLean();for(const hand of handReturn){position.copy(hand.p);const plane=Math.max(Math.abs(frame.min[0]),Math.abs(frame.max[0]));position.lerp(seatPoint.set(side*(plane-.28),Math.max(frame.min[1]+.42,Math.min(frame.max[1]-.2,hand.p.y)),Math.max(frame.min[2]+.23,Math.min(frame.max[2]-.23,hand.p.z))),tuck*tuck*(3-2*tuck));car.object.localToWorld(position);position.lerp(c.worldPosition('socket_hand_'+hand.side),1-riseBlend);car.object.getWorldQuaternion(rotation).multiply(hand.q);reachWindowPalm(hand.side,position,rotation);}return result;}reset();return null;
  }
  if(!allowed||!presentation||!weaponId||!nextCar?.object||!weapon||(weapon.weaponId||weapon.userData?.weaponId)!==weaponId||binding.transition||binding.phase!=='drive'||binding.seatId!==presentation.seatId||binding.canDrive===true||!readyOnly&&!point(intent.targetPosition)){reset();return null;}
  const key=[presentation.sourceVehicleId,presentation.seatId,weaponId].join('|');
  if(car!==nextCar||seatId!==binding.seatId){reset();car=nextCar;seatId=binding.seatId;frame=vehicleWindowFrame(THREE,car,seatId);}
  if(!frame){reset();return {canFire:false,reason:'У этого места нет доступного окна'};}
  if(intentKey!==key){blend=0;intentKey=key;hasMuzzle=false;}
  setBlend(blend+Math.max(0,Math.min(.25,dt))/.18);
  car.object.updateWorldMatrix(true,false);seatPoint.set(binding.seat.x,binding.seat.y+1.05,binding.seat.z);
  if(readyOnly)direction.set(frame.side*.8,0,.6).applyQuaternion(car.object.getWorldQuaternion(rotation));
  else direction.set(intent.targetPosition.x,intent.targetPosition.y,intent.targetPosition.z).sub(seatPoint);
  // Place the receiver beyond the pane, not merely the muzzle. Delay that
  // extension until the torso clears the sill; long foregrips pass behind
  // the front window pillar during entry. All shared reach/hull checks remain.
  const planShot=()=>{const p=planVehicleWindowShot({vehicleState:{yaw:binding.yaw},seatId,aimDirection:direction,weaponId,frame});if(p.allowed){const long=!!(weapon.twoHanded??weapon.userData?.twoHanded);const length=(weapon.userData.muzzle?.[2]||.5)*context.targetHeight/context.sourceHeight,plane=Math.max(Math.abs(frame.min[0]),Math.abs(frame.max[0]));p.localMuzzle.y=Math.min(frame.max[1]-.18,frame.min[1]+.40+.7*(1-poseBlend));p.localMuzzle.x=frame.side*(plane-.20+.38*Math.pow(poseBlend,4))+p.localDirection.x*length;p.localMuzzle.z=Math.min(frame.max[2]-.24,p.localMuzzle.z+(long?.3:.18))-(long?.65*(1-poseBlend):0)+p.localDirection.z*length;}return p;};
  let plan=planShot();
  if(!plan.allowed){result={canFire:false,reason:plan.reason};setVehicleWindowOpen(car,seatId,false);return result;}
  if(hasMuzzle)seatPoint.copy(muzzleLocal);else seatPoint.set(plan.localMuzzle.x,plan.localMuzzle.y,plan.localMuzzle.z);car.object.localToWorld(seatPoint);
  if(!readyOnly)direction.set(intent.targetPosition.x,intent.targetPosition.y,intent.targetPosition.z).sub(seatPoint);
  plan=planShot();
  if(!plan.allowed){result={canFire:false,reason:plan.reason};setVehicleWindowOpen(car,seatId,false);return result;}
  setVehicleWindowOpen(car,seatId,true);
  result=applyVehicleWindowPose(THREE,poseContext,{plan,car,weapon,blend:armBlend});if(poseBlend<=.98){result.canFire=false;if(!result.reason)result.reason='Высовываемся из окна';}lastTwoHanded=!!(weapon.twoHanded??weapon.userData?.twoHanded);braceFreeHand(weapon);
  for(const hand of handReturn){hand.p.copy(context.worldPosition('socket_hand_'+hand.side));car.object.worldToLocal(hand.p);context.bones['hand_'+hand.side].getWorldQuaternion(hand.q);hand.q.premultiply(car.object.getWorldQuaternion(rotation).invert());}
  if(result.muzzle){muzzleLocal.copy(result.muzzle);car.object.worldToLocal(muzzleLocal);hasMuzzle=true;}
  if(readyOnly){result.canFire=false;result.reason='Ждём атакующих';}
  return result;
 }
 return {apply,reset,get result(){return result;},get car(){return car;},get seatId(){return seatId;}};
}

export function createMercenaryVehicleFire({THREE,getActors,getActor,getPlayer,obstacles=()=>[],getHost=()=>globalThis.MafioziMercenaries,diagnostics=false}={}){
 let activeActors=[];
 const counts={attempts:0,ready:0,rejected:0,accepted:0,sequence:0,reason:null,memberId:null,seatId:null,targetId:null};
 let pendingProof=null;
 const contact=createNpcContactRay({THREE,getActors:()=>activeActors,obstacles});
 const direction=new THREE.Vector3();
 function prepareShot(intent){
  pendingProof=null;
  if(diagnostics){counts.attempts++;counts.memberId=intent?.memberId??null;counts.seatId=intent?.seatId??null;counts.targetId=intent?.targetId??null;}
  const fail=reason=>{if(diagnostics){counts.rejected++;counts.reason=reason;}return {ready:false,reason};};
  const host=getHost();if(!intent||host?.validateVehicleFireIntent?.(intent)!==true)return fail('source_rejected');
  if(!mercenaryVehicleFireWeapon(intent.weaponId))return fail('weapon_unsupported');
  activeActors=getActors?.()||[];
  const row=activeActors.find(row=>actorKey(row.id)===String(intent.memberId)),actor=getActor?.(row?.id)||row;
  if(!actor||!visible(actor.object)||typeof actor.prepareVehicleShot!=='function')return fail('actor_unavailable');
  const player=getPlayer?.();if(!player?.object)return fail('player_unavailable');
  activeActors=[...activeActors,{id:'player',object:player.object}];
  const pose=actor.prepareVehicleShot(intent);
  if(!pose?.canFire||!point(pose.muzzle)||!point(pose.direction))return fail(pose?.reason||'pose_unavailable');
  direction.copy(pose.direction).normalize();
  const range=Number(intent.rangeMeters);if(!Number.isFinite(range)||range<=0||range>60)return fail('range_invalid');
  const hit=contact({origin:pose.muzzle,direction,range,targetOnly:true});
  if(!hit||actorKey(hit.npcId)!==actorKey(intent.targetId))return fail(hit?'other_body':'occluded');
  if(host.validateVehicleFireIntent(intent)!==true)return fail('source_changed');
  if(diagnostics){counts.ready++;counts.reason='ready';}
  pendingProof={ready:true,memberId:intent.memberId,sourceVehicleId:intent.sourceVehicleId,seatId:intent.seatId,targetId:intent.targetId,weaponId:intent.weaponId,
   origin:{x:pose.muzzle.x,y:pose.muzzle.y,z:pose.muzzle.z},direction:{x:direction.x,y:direction.y,z:direction.z},contact:{...hit.point}};
  return pendingProof;
 }
 function recordAccepted(proof,sequence){if(!proof||proof!==pendingProof||!Number.isSafeInteger(sequence)||sequence<1)return false;pendingProof=null;if(diagnostics){counts.accepted++;counts.sequence=sequence;counts.reason='accepted';}return true;}
 return {prepareShot,recordAccepted,stats:()=>diagnostics?{...counts}:null,supportsWeapon:weapon=>!!mercenaryVehicleFireWeapon(weapon)};
}
