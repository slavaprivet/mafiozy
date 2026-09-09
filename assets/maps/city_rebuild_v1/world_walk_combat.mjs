import {createWeaponFireState,stepWeaponFire,weaponFireProfile,sampleWeaponAccuracy} from './hero_weapon_fire.mjs';
import {createNpcContactRay} from './npc_contact_ray.mjs';
import {resolveNpcContactAnchor} from './npc_contact_anchor.mjs';

// All admission, inventory, cadence and ammo come from the existing world.
export function createWorldWalkCombat({THREE,bridge,getActors,obstacles,now=()=>performance.now()}){
 const contactRay=createNpcContactRay({THREE,getActors,obstacles});
 const pendingAnchors=new Map(),pendingLifetime=15000,maxPendingAnchors=512,contactDirection=new THREE.Vector3(),contactTarget=new THREE.Vector3();let nextPendingExpiry=Infinity;
 function refreshPendingExpiry(){nextPendingExpiry=Infinity;for(const pending of pendingAnchors.values())nextPendingExpiry=Math.min(nextPendingExpiry,pending.at+pendingLifetime);}
 // Receipts remain sparse even during automatic fire. Do not enumerate their
 // bounded map, or call the clock, on every rendered combat frame before the
 // oldest one can expire. The strict comparison matches the prior lifetime.
 function expire(){if(!pendingAnchors.size)return;const clock=now();if(clock<=nextPendingExpiry)return;for(const [id,pending]of pendingAnchors)if(clock-pending.at>pendingLifetime)pendingAnchors.delete(id);refreshPendingExpiry();}
 function step(previous,input,dt,{origin,forward}){
  expire();
  const profile=weaponFireProfile(previous.weaponId);
  let source=bridge.getPlayerState();
  if(input.reload){bridge.reloadWalkWeapon();source=bridge.getPlayerState();}
  const idle=stepWeaponFire({...previous,reloadRemaining:0},{},dt);
  let result=idle;
  const wants=profile&&(input.triggerPressed||(profile.automatic&&input.triggerHeld));
  if(wants&&origin){
   let lastContact=null;
   // The source already owns normal weapon spread. Add only the cover
   // penalty here, once, before it resolves the final physical contact ray.
   const accuracy=sampleWeaponAccuracy(idle.state,input);
   const coverYaw=accuracy.coverYaw||0,coverPitch=accuracy.coverPitch||0;
   const pitch=Math.max(-Math.PI/2,Math.min(Math.PI/2,Math.asin(Math.max(-1,Math.min(1,forward.y)))+coverPitch));
   const receipt=bridge.fireWalkShot({angle:Math.atan2(forward.z,forward.x)+coverYaw,pitch,muzzleR:origin.z/4.1,muzzleC:origin.x/4.1,
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
    const target=contactTarget.clone();
    result.shots=result.shots.map(shot=>({...shot,shotId:receipt.shotId,worldTarget:target,
     projectiles:shot.projectiles.map(p=>({...p,yawOffset:0,pitchOffset:0}))}));
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
 return {step,resolveConfirmedReceipt,dispose(){pendingAnchors.clear();nextPendingExpiry=Infinity;}};
}
