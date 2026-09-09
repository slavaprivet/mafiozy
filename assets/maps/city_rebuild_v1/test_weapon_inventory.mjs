import assert from 'node:assert/strict';
import {createWeaponInventory} from './weapon_inventory.mjs';
import {FIREARM_IDS,beginWeaponReload,createWeaponFireState,stepWeaponFire} from './hero_weapon_fire.mjs';

const position={x:2,y:.25,z:-5};
const inventory=createWeaponInventory();
assert.equal(inventory.equippedId,'none');
assert.deepEqual(inventory.getOwnedIds(),FIREARM_IDS);
assert.equal(inventory.equip('invented').reason,'not_owned');
assert.equal(inventory.drop({position}).reason,'unarmed');
assert.throws(()=>createWeaponInventory({ownedIds:['none']}),/known/);
assert.throws(()=>createWeaponInventory({ownedIds:['uzi','uzi']}),/unique/);

for(const id of FIREARM_IDS){
  const equipped=inventory.equip(id);
  assert.equal(equipped.ok,true);
  const fired=stepWeaponFire(equipped.fireState,{triggerHeld:true},0).state;
  const reloading=beginWeaponReload(fired);
  const before=inventory.snapshot();
  assert.equal(inventory.drop({position:{x:NaN,y:0,z:0},fireState:reloading}).reason,'invalid_transform');
  assert.equal(inventory.drop({position,yaw:Infinity,fireState:reloading}).reason,'invalid_transform');
  assert.equal(inventory.drop({position,fireState:{...reloading,magazine:NaN}}).reason,'invalid_fire_state');
  assert.deepEqual(inventory.snapshot(),before,'failed drops must be atomic');
  const dropped=inventory.drop({position,yaw:.6,fireState:reloading});
  assert.equal(dropped.ok,true);assert.equal(dropped.equippedId,'none');
  assert.equal(inventory.getOwnedIds().includes(id),false);
  assert.equal(inventory.equip(id).reason,'not_owned','Q must not select dropped guns');
  assert.equal(inventory.drop({position}).reason,'unarmed','key repeats cannot duplicate drops');
  assert.equal(dropped.drop.fireState.magazine,fired.magazine);
  assert.equal(dropped.drop.fireState.reserveAmmo,fired.reserveAmmo);
  assert.equal(dropped.drop.fireState.sequence,fired.sequence);
  assert.equal(dropped.drop.fireState.cooldown,fired.cooldown,'drop/pickup does not reset fire cadence');
  assert.equal(dropped.drop.fireState.reloadRemaining,0);
  assert.equal(dropped.drop.fireState.triggerHeld,false);
  assert.equal(dropped.drop.fireState.recoil,0);
  // Returned values never leak mutable inventory ownership/ammo/transforms.
  dropped.drop.position.x=999;dropped.drop.fireState.magazine=999;
  const copied=inventory.getDropped();copied[0].position.x=888;copied[0].fireState.reserveAmmo=888;
  const snapshot=inventory.snapshot();snapshot.dropped[0].fireState.sequence=888;snapshot.ownedIds.length=0;
  assert.equal(inventory.getDropped()[0].position.x,position.x);
  const restored=inventory.pickup(dropped.drop.uid);
  assert.equal(restored.ok,true);assert.equal(restored.equippedId,'none','pickup does not auto-equip from fists');
  assert.equal(restored.fireState.weaponId,'none');assert.equal(restored.drop.weaponId,id);
  assert.equal(inventory.getFireState(id).magazine,fired.magazine);
  assert.equal(inventory.getFireState(id).reserveAmmo,fired.reserveAmmo);
  assert.equal(inventory.getFireState(id).sequence,fired.sequence);
  assert.equal(inventory.pickup(dropped.drop.uid).reason,'missing_drop');
  assert.equal(inventory.getDropped().length,0);
  restored.fireState.magazine=999;
  assert.equal(inventory.getFireState(id).magazine,fired.magazine);
  assert.equal(inventory.equip(id).fireState.magazine,fired.magazine,'explicit Q selection equips the collected gun');
}

const switching=createWeaponInventory();
let first=switching.equip('tt_pistol');
const fired=stepWeaponFire(first.fireState,{triggerHeld:true},0).state;
switching.equip('uzi',fired);
assert.equal(switching.equip('tt_pistol').fireState.magazine,fired.magazine,'switching cannot mint ammo');
const reload=beginWeaponReload(fired);
switching.updateFireState(reload);
assert.equal(switching.equip('tt_pistol',reload).fireState.reloadRemaining,reload.reloadRemaining);
switching.equip('none',reload);
assert.equal(switching.getFireState('tt_pistol').reloadRemaining,0);
assert.equal(switching.getFireState('tt_pistol').magazine,fired.magazine);
const pistolDrop=switching.equip('tt_pistol');
const drop=switching.drop({position,fireState:pistolDrop.fireState}).drop;
first=switching.equip('uzi');
const uziFired=stepWeaponFire(first.fireState,{triggerHeld:true},0).state;
const collected=switching.pickup(drop.uid,uziFired);
assert.equal(switching.equippedId,'uzi');
assert.deepEqual(collected.fireState,uziFired,'pickup preserves current trigger, recoil and entire active fire state');
assert.deepEqual(switching.getFireState(),uziFired);
assert.equal(switching.getFireState('uzi').magazine,uziFired.magazine,'picking a gun retains previously held gun');
assert.equal(switching.getOwnedIds().length,14);
const before=switching.snapshot();
assert.equal(switching.updateFireState(createWeaponFireState('tt_pistol')).reason,'invalid_fire_state');
assert.deepEqual(switching.snapshot(),before,'wrong-id fire state cannot corrupt equipped ammo');

// Collect during an active reload: E is not a free reload cancellation or switch.
switching.equip('tt_pistol');const reloadDrop=switching.drop({position}).drop;
switching.equip('uzi');const liveReload=beginWeaponReload(uziFired);
assert(liveReload.reloadRemaining>0);
const duringReload=switching.pickup(reloadDrop.uid,liveReload);
assert.equal(duringReload.equippedId,'uzi');assert.deepEqual(duringReload.fireState,liveReload);
assert.deepEqual(switching.getFireState('uzi'),liveReload);
assert.equal(switching.getFireState('tt_pistol').reloadRemaining,0,'collected gun is stored safely');

const duplicate=createWeaponInventory({dropped:[{uid:'world-tt',weaponId:'tt_pistol',position,yaw:0,fireState:createWeaponFireState('tt_pistol')}]});
const duplicateBefore=duplicate.snapshot();
assert.equal(duplicate.pickup('world-tt').reason,'already_owned');
assert.deepEqual(duplicate.snapshot(),duplicateBefore,'duplicate pickup must not consume world item');
const limited=createWeaponInventory({maxDrops:1});
limited.equip('uzi');const limitedDrop=limited.drop({position}).drop;
limited.equip('m16');const limitedBefore=limited.snapshot();
assert.equal(limited.drop({position}).reason,'drop_limit');
assert.deepEqual(limited.snapshot(),limitedBefore,'full world capacity must not lose old or new gun');
limited.pickup(limitedDrop.uid);limited.drop({position});
assert.notEqual(limited.getDropped()[0].uid,limitedDrop.uid,'uids remain unique across pickup/drop');

// Repeated empty/full cycles preserve the exact per-item total, never respawn ammo.
const endurance=createWeaponInventory();
for(let pass=0;pass<20;pass++)for(const id of FIREARM_IDS){
  const state=endurance.equip(id).fireState;
  const dropped=endurance.drop({position:{x:pass,y:0,z:0},fireState:state}).drop;
  const picked=endurance.pickup(dropped.uid);
  assert.equal(picked.equippedId,'none');
  const stored=endurance.getFireState(id);
  assert.equal(stored.magazine+stored.reserveAmmo,state.magazine+state.reserveAmmo);
}
for(const id of FIREARM_IDS){endurance.equip(id);assert(endurance.drop({position}).ok);}
assert.equal(endurance.getOwnedIds().length,0);assert.equal(endurance.getDropped().length,14);
assert.equal(endurance.equippedId,'none');
for(const drop of endurance.getDropped())assert(endurance.pickup(drop.uid).ok);
assert.deepEqual(endurance.getOwnedIds(),FIREARM_IDS);assert.equal(endurance.getDropped().length,0);
assert.equal(endurance.equippedId,'none','collecting all14 still leaves fists equipped');
console.log(JSON.stringify({passed:true,weapons:14,cycles:280,checks:['owned-only-selection','atomic-invalid-drop','ammo-conservation','reload-cancel','cooldown-sequence-preserved','same-item-reload-preserved','pickup-inventory-only','pickup-keeps-fists','pickup-preserves-live-trigger-reload','explicit-selection-equips','previous-item-kept','duplicate-pickup-safe','capacity-no-eviction','unique-drop-id','snapshot-isolation','all-dropped-all-recovered']}));
