import assert from 'node:assert/strict';
import {ARSENAL} from './hero_arsenal.mjs';
import {FIREARM_IDS,WEAPON_FIRE_PROFILES,WEAPON_PROFILE_ALIASES,beginWeaponReload,createWeaponFireState,sampleWeaponRecoil,stepWeaponFire,weaponFireProfile} from './hero_weapon_fire.mjs';

const expected=ARSENAL.filter(item=>item.id!=='none').map(item=>item.id);
const worldDamage={nagan:32,tt_pistol:24,revolver:86,deagle:72,golden_colt:48,sawn_off:76,shotgun:76,uzi:15,golden_uzi:15,ak74:42,m16:42,tommy_gun:24,sniper:132,rpg:160};
assert.deepEqual(FIREARM_IDS,expected,'fire profiles must retain every arsenal item id and menu order');
assert.equal(Object.keys(WEAPON_FIRE_PROFILES).length,14);
for(const id of expected){
  const profile=weaponFireProfile(id),initial=createWeaponFireState(id);
  assert.equal(profile.id,id);assert.equal(initial.weaponId,id);assert.equal(initial.magazine,profile.magazineSize);
  assert(profile.cooldown>0&&profile.reloadSeconds>0&&profile.recoil>0&&profile.projectileSpeed>0);
  const fired=stepWeaponFire(initial,{triggerHeld:true,aiming:true},1/60);
  assert.equal(fired.shots.length,1,`${id} must fire from a full magazine`);
  assert.equal(fired.state.magazine,profile.magazineSize-1);assert(fired.state.recoil>0);
  assert.equal(fired.shots[0].weaponId,id,'owner-facing id must survive family balance lookup');
  assert.equal(fired.shots[0].damage,worldDamage[id],'shot receipts must carry exact world WEAPON_FX_CFG base damage');
  assert.equal(fired.shots[0].shotId,`${id}:1`,'each trigger receipt needs a stable id for shotgun-pellet dedupe');
  assert.equal(fired.shots[0].projectiles.length,profile.pellets);
  assert(fired.shots[0].projectiles.every(p=>p.color===profile.color&&p.speed===profile.projectileSpeed));
  assert(sampleWeaponRecoil(fired.state).normalized>0);
  const cooled=stepWeaponFire(fired.state,{triggerHeld:false},profile.recoilRecovery+.01);
  assert.equal(cooled.state.recoil,0,'recoil envelope must recover to rest');
}

assert.equal(WEAPON_PROFILE_ALIASES.deagle,'pistol_heavy');
assert.equal(weaponFireProfile('deagle').id,'deagle');
assert.equal(weaponFireProfile('m16').balanceId,'rifle');
assert.throws(()=>weaponFireProfile('invented_gun'),/Unknown firearm/);
assert.equal(weaponFireProfile('none'),null);

let pistol=createWeaponFireState('tt_pistol');
let shot=stepWeaponFire(pistol,{triggerHeld:true},.01);pistol=shot.state;
assert.equal(shot.shots.length,1);
shot=stepWeaponFire(pistol,{triggerHeld:true},1);pistol=shot.state;
assert.equal(shot.shots.length,0,'semi-auto must require a new trigger press even after cooldown');
pistol=stepWeaponFire(pistol,{triggerHeld:false},0).state;
shot=stepWeaponFire(pistol,{triggerHeld:true},0).state;
assert.equal(shot.magazine,weaponFireProfile('tt_pistol').magazineSize-2,'released semi-auto trigger may fire again');

let uzi=createWeaponFireState('uzi');
const automatic=stepWeaponFire(uzi,{triggerHeld:true},.315);
assert.equal(automatic.shots.length,4,'automatic cadence must include immediate shot and timed repeats');
assert.equal(automatic.state.magazine,26);

const empty=createWeaponFireState('deagle',{magazine:0,reserveAmmo:7});
const dry=stepWeaponFire(empty,{triggerHeld:true},0);
assert.equal(dry.shots.length,0);assert.equal(dry.dryFire,true);
const heldDry=stepWeaponFire(dry.state,{triggerHeld:true},.5);
assert.equal(heldDry.dryFire,false,'held empty trigger must not click every frame');

let reload=createWeaponFireState('deagle',{magazine:2,reserveAmmo:3});
reload=beginWeaponReload(reload);assert.equal(reload.reloadRemaining,weaponFireProfile('deagle').reloadSeconds);
let reloading=stepWeaponFire(reload,{triggerHeld:true},reload.reloadRemaining-.01);
assert.equal(reloading.shots.length,0);assert.equal(reloading.state.magazine,2);
reloading=stepWeaponFire(reloading.state,{},.02);
assert.equal(reloading.reloadFinished,true);assert.equal(reloading.state.magazine,5);assert.equal(reloading.state.reserveAmmo,0);

const shotgun=stepWeaponFire(createWeaponFireState('shotgun'),{triggerPressed:true},0);
assert.equal(shotgun.shots[0].projectiles.length,7);
assert.equal(shotgun.shots[0].casing.delay,.34,'pump shotgun casing is delayed until the pump action');
assert.deepEqual(shotgun.shots[0].projectiles,stepWeaponFire(createWeaponFireState('shotgun'),{triggerPressed:true},0).shots[0].projectiles,'spread pattern must be deterministic');
assert.equal(stepWeaponFire(createWeaponFireState('rpg'),{triggerPressed:true},0).shots[0].casing,null,'RPG must not eject a brass casing');
assert.equal(stepWeaponFire(createWeaponFireState('revolver'),{triggerPressed:true},0).shots[0].casing,null,'revolver retains cases in its cylinder');

console.log(JSON.stringify({passed:true,weapons:expected.length,checks:['arsenal_id_parity','owner_id_preserved','world_balance_aliases','exact_world_damage_receipts','stable_shot_id','semi_trigger_edge','automatic_cadence','magazine_empty_dry_fire','finite_reserve_reload','deterministic_spread','seven_pellet_shotgun','delayed_pump_case','rpg_no_case','revolver_retained_cases','recoil_envelope']}));
