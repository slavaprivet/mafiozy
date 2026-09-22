import {normalizeNpcDeathProfile} from './npc_death_profile20.mjs';
const UNKNOWN=Object.freeze({known:false,cause:'unknown'});
// One immutable choice per rendered death. Late receipts cannot rearrange a
// corpse; an unposed actor may still acquire its matching source record.
export function createNpcDeathPresentation20(id){
 let profile=UNKNOWN,record=null,locked=false,visualReplaced=false;
 const normalize=(value,key,yaw)=>normalizeNpcDeathProfile({targetId:id,lifecycle:{dead:true,key},record:value,yaw});
 function reset(){profile=UNKNOWN;record=null;locked=false;visualReplaced=false;}
 function observe(lifecycle){
  if(locked||profile.known||!lifecycle.dead||!lifecycle.deathRecord)return;
  const next=normalize(lifecycle.deathRecord,lifecycle.key);
  if(!next.known)return;
  record=Object.freeze({version:1,confirmed:true,fatal:true,targetId:id,eventId:next.eventId,deathKey:next.deathKey,cause:next.cause,travelWorld:next.directionWorld,pointWorldMeters:next.pointWorldMeters});profile=next;
 }
 function select(yaw){if(!locked){if(record)profile=normalize(record,record.deathKey,yaw);locked=true;}return profile;}
 function prepareRestore(saved,key,dead){
  if(saved==null)return {profile:UNKNOWN,record:null,locked:false,visualReplaced:false};
  if(saved.visualReplaced!==undefined&&typeof saved.visualReplaced!=='boolean'||saved.visualReplaced&&(!dead||!saved.record))throw Error('Invalid replaced NPC death visual');
  if(typeof saved.locked!=='boolean'||saved.record!==null&&typeof saved.record!=='object'||saved.yaw!==null&&!Number.isFinite(saved.yaw))throw Error('Invalid NPC death presentation');
  if(saved.record){const next=normalize(saved.record,key,saved.yaw);if(!dead||!next.known||saved.visualReplaced&&next.cause!=='blast')throw Error('Invalid NPC death presentation identity');return {profile:next,record:Object.freeze({version:1,confirmed:true,fatal:true,targetId:id,eventId:next.eventId,deathKey:next.deathKey,cause:next.cause,travelWorld:next.directionWorld,pointWorldMeters:next.pointWorldMeters}),locked:saved.locked,visualReplaced:saved.visualReplaced===true};}
  return {profile:UNKNOWN,record:null,locked:saved.locked,visualReplaced:false};
 }
 // Store the yaw used to choose a local pose, not a later root transform.
 let selectedYaw=null;
 return {reset(){reset();selectedYaw=null;},observe,select(yaw){if(!locked)selectedYaw=Number.isFinite(yaw)?yaw:null;return select(yaw);},markReplaced(key){if(!profile.known||profile.cause!=='blast'||profile.deathKey!==key)return false;visualReplaced=true;return true;},isReplaced:key=>visualReplaced&&profile.deathKey===key,save:()=>({record,locked,yaw:selectedYaw,visualReplaced}),prepareRestore,restore(prepared,saved){profile=prepared.profile;record=prepared.record;locked=prepared.locked;visualReplaced=prepared.visualReplaced;selectedYaw=saved?.yaw??null;},diagnostics:()=>profile};
}
