// Ordinary residents cannot gain a firearm from stale source defaults. Protected
// armed roles retain their source inventory and the coordinator's draw policy.
export function npcCivilianUnarmed(n){
 if(!n)return true;
 if(n.police||n.isPolice||n._guard||n.prisonStaff||n.gang||n._gang||n.gangId||n.gang_id||n._empireBoss||n.empireBoss||n._empireCrew||n.empireCrew||n.npcEmpireBoss||n._uniqueNpc||n.uniqueNpc||n._said||n._keyNpc||n._storyNpc||n.armedStoryRole||n.mercenary||n.isMercenary||n._formerMercenary||n.uniqueWeaponId||n._empireWeaponId||n._arc?.panicMult===0)return false;
 const role=[n.role,n.type,n.kind,n._arcKey,n.visualRole].filter(Boolean).join(' ').toLowerCase();
 return !/(police|cop|guard|boss|gang|bandit|mafia|soldier|convoy|mercenary|hired|recruit|michael|said|armed_story)/.test(role);
}
export function npcVisibleWeapon(n){
 if(npcCivilianUnarmed(n))return 'none';
 if(n?._formerMercenary&&!n._fighting&&!n._hostile&&!(n._lastShotAt>performance.now()-500))return 'none';
 return String(n?._empireBoss?(n._empireWeaponBase||'pistol_heavy'):(n?.weapon||n?._fightWeapon||''));
}
export function npcCarriedGun(n){const weapon=n?._formerMercenary?String(n._formerMercenaryWeapon||n.weapon||'pistol'):npcVisibleWeapon(n);return /^(none|unarmed|fists|melee)?$/.test(weapon)?'':weapon;}
