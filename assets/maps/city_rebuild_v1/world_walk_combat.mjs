import {createWeaponFireState,stepWeaponFire,weaponFireProfile,sampleWeaponAccuracy} from './hero_weapon_fire.mjs';
import {createNpcContactRay} from './npc_contact_ray.mjs';
import {resolveNpcContactAnchor} from './npc_contact_anchor.mjs';

// All admission, inventory, cadence and ammo come from the existing world.
export function createWorldWalkCombat({THREE,bridge,getActors,obstacles,now=()=>performance.now()}){
 const contactRay=createNpcContactRay({THREE,getActors,obstacles});
 const pendingAnchors=new Map(),pendingLifetime=15000,maxPendingAnchors=512,contactDirection=new THREE.Vector3(),contactTarget=new THREE.Vector3(),shotForward=new THREE.Vector3(),aimPoint=new THREE.Vector3();let nextPendingExpiry=Infinity;
 function refreshPendingExpiry(){nextPendingExpiry=Infinity;for(const pending of pendingAnchors.values())nextPendingExpiry=Math.min(nextPendingExpiry,pending.at+pendingLifetime);}
 // Receipts remain sparse even during automatic fire. Do not enumerate their
 // bounded map, or call the clock, on every rendered combat frame before the
 // oldest one can expire. The strict comparison matches the prior lifetime.
 function expire(){if(!pendingAnchors.size)return;const clock=now();if(clock<=nextPendingExpiry)return;for(const [id,pending]of pendingAnchors)if(clock-pending.at>pendingLifetime)pendingAnchors.delete(id);refreshPendingExpiry();}
 function step(previous,input,dt,{origin,forward,aimOrigin}){
  expire();
  const profile=weaponFireProfile(previous.weaponId);
  let source=bridge.getPlayerState();
  if(input.reload){bridge.reloadWalkWeapon();source=bridge.getPlayerState();}
  const idle=stepWeaponFire({...previous,reloadRemaining:0},{},dt);
  let result=idle;
  const wants=profile&&(input.triggerPressed||(profile.automatic&&input.triggerHeld));
  if(wants&&origin){
   let lastContact=null;
   shotForward.copy(forward);
   // The source already owns normal weapon spread. Add only the cover
   // penalty here, once, before it resolves the final physical contact ray.
   const accuracy=sampleWeaponAccuracy(idle.state,input);
   const coverYaw=accuracy.coverYaw||0,coverPitch=accuracy.coverPitch||0;
   let pitch=Math.max(-Math.PI/2,Math.min(Math.PI/2,Math.asin(Math.max(-1,Math.min(1,shotForward.y)))+coverPitch));
   const nativeRpg=previous.weaponId==='rpg'&&typeof bridge.impactWalkRpg==='function';
   const receipt=bridge.fireWalkShot({angle:Math.atan2(shotForward.z,shotForward.x)+coverYaw,pitch,muzzleR:origin.z/4.1,muzzleC:origin.x/4.1,muzzleY:origin.y,nativeRpgImpact:nativeRpg,
    // Source calls this only after ammo/cooldown/stance admission and before
    // its one weapon-spread sample. Rejected automatic-fire frames must not
    // skin the nearby crowd merely to compute a camera aim point.
    resolveAim({range:sourceRange}={}){
     shotForward.copy(forward);
     if(aimOrigin){
      const range=(Number.isFinite(sourceRange)&&sourceRange>0?sourceRange:profile.range||24)*4.1+aimOrigin.distanceTo(origin),aim=contactRay({origin:aimOrigin,direction:forward,range,aimOnly:true});
      if(aim)aimPoint.copy(aim.point);else aimPoint.copy(aimOrigin).addScaledVector(forward,range);
      shotForward.copy(aimPoint).sub(origin);
      if(shotForward.dot(forward)<=0||shotForward.lengthSq()<1e-8)shotForward.copy(forward);else shotForward.normalize();
     }
     pitch=Math.max(-Math.PI/2,Math.min(Math.PI/2,Math.asin(Math.max(-1,Math.min(1,shotForward.y)))+coverPitch));
     return {angle:Math.atan2(shotForward.z,shotForward.x)+coverYaw,pitch};
    },
    resolveContact({angle,range}){
     contactDirection.set(Math.cos(angle)*Math.cos(pitch),Math.sin(pitch),Math.sin(angle)*Math.cos(pitch));
     const hit=contactRay({origin,direction:contactDirection,range:range*4.1});
     lastContact=hit;
     if(hit)contactTarget.set(hit.point.x,hit.point.y,hit.point.z);else contactTarget.copy(origin).addScaledVector(contactDirection,range*4.1);
     return hit;
    }});
   source=receipt.state||bridge.getPlayerState();
   if(receipt.accepted){
    if(receipt.shotId&&receipt.contactAccepted!==false&&lastContact?.anchor){
     const pending={anchor:lastContact.anchor,npcId:String(lastContact.npcId),at:now()};pendingAnchors.set(String(receipt.shotId),pending);
     nextPendingExpiry=Math.min(nextPendingExpiry,pending.at+pendingLifetime);
     while(pendingAnchors.size>maxPendingAnchors)pendingAnchors.delete(pendingAnchors.keys().next().value);
     if(pendingAnchors.size===maxPendingAnchors)refreshPendingExpiry();
    }
    // Generate one cosmetic receipt only after the actual source accepts firing.
    result=stepWeaponFire({...idle.state,magazine:1,cooldown:0,reloadRemaining:0},{...input,triggerPressed:true,triggerHeld:false,reload:false},0);
    // The returned shot outlives this synchronous source resolver. Keep its
    // target private while avoiding throw-away target vectors on rejected fire.
    const target=contactTarget.clone(),nativeFlight=nativeRpg&&receipt.nativeRpgImpact===true;
    // Keep the accepted muzzle/ray, even if the mounted weapon animates before
    // effects are emitted. The rocket will sweep actual moving surfaces.
    if(nativeFlight){const angle=receipt.angle,flightPitch=receipt.pitch??pitch;target.copy(origin).addScaledVector(contactDirection.set(Math.cos(angle)*Math.cos(flightPitch),Math.sin(flightPitch),Math.sin(angle)*Math.cos(flightPitch)),receipt.range*4.1);}
    result.shots=result.shots.map(shot=>({...shot,shotId:receipt.shotId,worldTarget:target,
     ...(nativeFlight?{nativeRpgImpact:true,worldOrigin:origin.clone()}:{}),
     projectiles:shot.projectiles.map(p=>({...p,...(nativeFlight?{range:receipt.range}:{}),yawOffset:0,pitchOffset:0}))}));
   }
  }
  result.state={...result.state,magazine:source.magazine||0,reserveAmmo:source.reserve||0,
   reloadRemaining:source.reloading&&profile?(1-source.reloadProgress)*profile.reloadSeconds:0};
  return result;
 }
 function resolveConfirmedReceipt(event){
  expire();
  const detail=event?.detail??event;
  if(detail?.confirmed!==true||typeof detail.shotId!=='string'||!detail.shotId)return null;
  const pending=pendingAnchors.get(detail.shotId);if(!pending)return null;
  if(String(detail.targetId??detail.npcId)!==pending.npcId)return null;
  pendingAnchors.delete(detail.shotId);refreshPendingExpiry();
  const record=getActors().find(actor=>String(actor.id)===pending.npcId);
  const surface=resolveNpcContactAnchor({THREE,record,anchor:pending.anchor});
  return surface?{...detail,...surface}:null;
 }
 // Source-local hits may dispatch during fireWalkShot. The host must defer
 // its receipt listener with queueMicrotask until step has stored shotId.
 return {step,aim:input=>contactRay({...input,aimOnly:false,targetOnly:true}),projectileContact:input=>contactRay({...input,projectileOnly:true}),resolveConfirmedReceipt,dispose(){pendingAnchors.clear();nextPendingExpiry=Infinity;}};
}
