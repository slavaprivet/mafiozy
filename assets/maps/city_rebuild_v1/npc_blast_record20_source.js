// Enrich only the new final-death record produced synchronously by this hit.
// Pure metadata: no HP/death, target identity, damage or impulse authority.
function enrichNpcBlastRecord20({entity,previousRecord,originSource}={}){
  const record=entity?._deathRecord20;
  if(!entity||entity.dead!==true||entity._medicalDowned||!Number.isFinite(entity.deadAt)||entity.deadAt<=0)return null;
  if(!record||record===previousRecord||record.version!==1||record.confirmed!==true||record.fatal!==true||record.cause!=='blast'||record.deathKey!==String(entity.deadAt))return null;
  if(typeof record.targetId!=='string'||!record.targetId||record.targetId.length>256||typeof record.eventId!=='string'||!record.eventId||record.eventId.length>256)return null;
  if(previousRecord&&previousRecord.targetId===record.targetId&&previousRecord.deathKey===record.deathKey&&previousRecord.eventId===record.eventId)return null;
  if(record.blastPresentation!=null||!Number.isFinite(originSource?.r)||!Number.isFinite(originSource?.c))return null;
  // Five metres/second is an authored effect speed, NOT measured damage impulse.
  const blastPresentation=Object.freeze({version:1,originSource:Object.freeze({r:originSource.r,c:originSource.c}),visualSpeed:5});
  return Object.freeze({...record,blastPresentation});
}
