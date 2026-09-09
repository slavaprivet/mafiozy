import assert from 'node:assert/strict';
import {createWeaponInventory,WEAPON_DROP_LIFETIME_MS} from './weapon_inventory.mjs';
import {createWeaponFireState,stepWeaponFire} from './hero_weapon_fire.mjs';

const position={x:1,y:0,z:2};let time=0;
const inventory=createWeaponInventory({now:()=>time});assert.equal(WEAPON_DROP_LIFETIME_MS,300000);
const initial=inventory.equip('tt_pistol').fireState,fired=stepWeaponFire(initial,{triggerHeld:true},0).state;
const first=inventory.drop({position,fireState:fired}).drop;
assert.equal(first.droppedAt,0);assert.equal(first.expiresAt,300000);
time=299999;assert.deepEqual(inventory.expireDrops(),[]);assert.equal(inventory.getDropped().length,1);
time=300000;const expired=inventory.expireDrops();assert.equal(expired.length,1);assert.equal(expired[0].uid,first.uid);assert.equal(expired[0].fireState.magazine,fired.magazine);assert.equal(inventory.getDropped().length,0);assert(!inventory.getOwnedIds().includes('tt_pistol'));assert.equal(inventory.getFireState('tt_pistol'),null);assert.equal(inventory.pickup(first.uid).reason,'missing_drop');assert.deepEqual(inventory.expireDrops(),[]);

// Distinct ages are not reset by unrelated drops, equip or maintenance sweeps.
time=500000;inventory.equip('uzi');const uzi=inventory.drop({position}).drop;
time=600000;inventory.equip('ak74');const ak=inventory.drop({position}).drop;
time=799999;assert.deepEqual(inventory.expireDrops(),[]);
time=800000;assert.deepEqual(inventory.expireDrops().map(drop=>drop.uid),[uzi.uid]);assert.deepEqual(inventory.getDropped().map(drop=>drop.uid),[ak.uid]);
time=900000;assert.deepEqual(inventory.expireDrops().map(drop=>drop.uid),[ak.uid]);

// Pickup just before the old deadline, then re-drop: a full new five minutes.
time=1000000;inventory.equip('m16');const rifle=inventory.drop({position}).drop;
time=1299999;const recovered=inventory.pickup(rifle.uid);assert(recovered.ok);assert.equal(recovered.equippedId,'none');const stored=inventory.getFireState('m16'),ammo=stored.magazine+stored.reserveAmmo;
time=1400000;assert.deepEqual(inventory.expireDrops(),[],'stored item has no ground expiry');
assert.equal(inventory.getFireState('m16').magazine,stored.magazine);inventory.equip('m16');
const redropped=inventory.drop({position}).drop;assert.notEqual(redropped.uid,rifle.uid);assert.equal(redropped.droppedAt,1400000);assert.equal(redropped.expiresAt,1700000);
time=1699999;assert.deepEqual(inventory.expireDrops(),[]);assert.equal(inventory.getDropped()[0].fireState.magazine+inventory.getDropped()[0].fireState.reserveAmmo,ammo);
time=1700000;assert.equal(inventory.expireDrops().length,1);assert.equal(inventory.getFireState('m16'),null);

// No prior sweep: input after a suspended tab must reject/remove the expired gun.
time=2000000;inventory.equip('shotgun');const shotgun=inventory.drop({position}).drop;
time=2300000;const rejected=inventory.pickup(shotgun.uid);assert.equal(rejected.reason,'expired_drop');assert.deepEqual(rejected.expired.map(drop=>drop.uid),[shotgun.uid]);assert.equal(inventory.getDropped().length,0);assert.equal(inventory.getFireState('shotgun'),null);assert.equal(inventory.equippedId,'none');
rejected.expired[0].fireState.reserveAmmo=9999;assert.equal(inventory.getFireState('shotgun'),null,'expired ammo cannot be resurrected through returned copies');

// Legacy fixture drops acquire creation time; timestamped fixtures keep theirs.
time=3000000;const fixture={uid:'fixture',weaponId:'nagan',position,yaw:0,fireState:createWeaponFireState('nagan')};
const legacy=createWeaponInventory({ownedIds:[],dropped:[fixture],now:()=>time});assert.equal(legacy.getDropped()[0].droppedAt,time);assert.equal(legacy.getDropped()[0].expiresAt,time+300000);
const restored=createWeaponInventory({ownedIds:[],dropped:[{...fixture,droppedAt:100,expiresAt:300100}],now:()=>time});assert.equal(restored.pickup('fixture').reason,'expired_drop');assert.equal(restored.getDropped().length,0);
assert.throws(()=>createWeaponInventory({dropped:[{...fixture,droppedAt:0,expiresAt:999999}]}),/expiry/);
assert.throws(()=>createWeaponInventory({now:123}),/clock/);assert.throws(()=>legacy.expireDrops(NaN),/clock/);
const copies=legacy.getDropped();copies[0].expiresAt=Infinity;assert.equal(legacy.getDropped()[0].expiresAt,time+300000);
assert.equal(legacy.expireDrops(time+300000).length,1,'explicit sweep clock is supported');

// All 14 expire permanently together; no ownership, magazines or reserve return.
time=4000000;const all=createWeaponInventory({now:()=>time});for(const id of all.getOwnedIds()){all.equip(id);all.drop({position});}
time+=300000;assert.equal(all.expireDrops().length,14);assert.deepEqual(all.getOwnedIds(),[]);assert.deepEqual(all.getDropped(),[]);assert.deepEqual(all.snapshot().fireStates,{});
console.log(JSON.stringify({passed:true,checks:['five_minutes_exact','299999_vs_300000','independent_drop_ages','pickup_before_deadline','pickup_redrop_resets_full_five_minutes','held_item_no_expiry','suspended_tab_pickup_rejected','no_ammo_resurrection','legacy_fixtures','timestamp_validation','copy_isolation','all14_permanent_removal']}));
