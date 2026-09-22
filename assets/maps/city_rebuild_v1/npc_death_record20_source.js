// Source-owned presentation metadata, created only AFTER definitive local death.
// No HP, damage, authority, timestamps, context lifetime or movement is changed.
const _npcDeathBulletWeapons20=new Set(['pistol','pistol_heavy','pistol_gold','revolver','nagan','shotgun','smg','tommy_gun','golden_tommy','rifle','sniper','tt','tt_pistol','pm','glock','desert_eagle','deagle','golden_colt','sawn_off','uzi','ump','mp5','golden_uzi','ak','ak74','m4','m16']);
function createNpcFatalRecord20({entity,targetId,weapon,dirR,dirC,now,meleeContext=null}){
  if(!entity||entity.dead!==true||entity._medicalDowned||!(entity.deadAt>0)||!Number.isFinite(entity.deadAt)||entity.deadAt!==now||typeof targetId!=='string'||!targetId)return null;
  const deathKey=String(entity.deadAt),old=entity._deathRecord20;
  if(old?.confirmed===true&&old.fatal===true&&old.targetId===targetId&&old.deathKey===deathKey)return old;
  let cause=_npcDeathBulletWeapons20.has(weapon)?'bullet':weapon==='fists'?'melee':['rpg','grenade','c4','vehicle_explosion','gas_explosion'].includes(weapon)?'blast':['burn_tick','molotov','molotov_fire'].includes(weapon)?'fire':weapon==='vehicle'?'vehicle':'unknown';
  const ctx=meleeContext,age=ctx?now-ctx.at:NaN;
  const accepted=weapon==='fists'&&ctx?.ref===entity&&ctx.npcId===targetId&&ctx.melee===true&&ctx.serverMelee!==true&&ctx.confirmed===true&&Number.isFinite(age)&&age>=0&&Array.isArray(ctx.window)&&Number.isFinite(ctx.window[1])&&age<=ctx.window[1]+250;
  if(accepted){
    const type=ctx.animation?.type;
    if(type==='heavy'&&ctx.animation.heavy===true)cause='super';
    else if(type==='kick')cause='kick';
    else if(type==='dropkick'&&ctx.airborne===true)cause='dropkick';
  }
  const length=Number.isFinite(dirR)&&Number.isFinite(dirC)?Math.hypot(dirR,dirC):0;
  const travelWorld=length>1e-8?Object.freeze({x:dirC/length,y:0,z:dirR/length}):null;
  const contact=accepted?ctx.contact?.point:null;
  const pointWorldMeters=contact&&[contact.x,contact.y,contact.z].every(Number.isFinite)?Object.freeze({x:contact.x,y:contact.y,z:contact.z}):null;
  return Object.freeze({version:1,confirmed:true,fatal:true,targetId,eventId:`local-death:${targetId}:${deathKey}`,deathKey,cause,travelWorld,pointWorldMeters});
}
function projectNpcFatalRecord20(entity,targetId,death){
  const record=entity?._deathRecord20;
  return death?.dead===true&&death.deathConfirmed===true&&Number.isFinite(death.deadAt)&&death.deadAt>0&&record?.version===1&&record.confirmed===true&&record.fatal===true&&record.targetId===targetId&&record.deathKey===String(death.deadAt)?record:null;
}
