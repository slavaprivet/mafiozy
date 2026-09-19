import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {createLocalWorldWeaponTransfers} from './world_local_weapon_transfers.mjs';

function fixture(){
  const state={enabled:true,weapon:'rifle',owned:new Set(['rifle','pistol']),mags:{rifle:17,pistol:3},reserve:40,player:{r:10,c:10,ang:0},blocked:false,time:1000,changes:0};
  const api=createLocalWorldWeaponTransfers({allowed:()=>state.enabled,getPlayer:()=>state.player,getWeapon:()=>state.weapon,
    getAmmo:id=>state.mags[id],isAvailable:id=>state.owned.has(id),setAvailable:(id,value)=>value?state.owned.add(id):state.owned.delete(id),
    setWeapon:id=>{state.weapon=id;},setMagazine:(id,n)=>{state.mags[id]=n;},canPlace:()=>!state.blocked,now:()=>state.time,changed:()=>state.changes++});
  return {state,api};
}
test('drop/pickup conserves ownership, magazine and shared reserve without autoequip',()=>{
  const {state:s,api}=fixture(),drop=api.drop();assert(drop.ok);assert.equal(s.weapon,null);assert.equal(s.mags.rifle,0);assert(!s.owned.has('rifle'));
  assert.equal(drop.drop.weaponId,'ak74');assert.equal(drop.drop.fireState.magazine,17);assert.equal(drop.drop.fireState.reserveAmmo,0);assert.equal(s.reserve,40);
  assert.equal(api.drop().ok,false,'no duplicate drop after unequip');
  s.weapon='pistol';assert(api.pickup(drop.drop.uid).ok);assert.equal(s.weapon,'pistol');assert.equal(s.mags.rifle,17);assert.equal(s.mags.pistol,3);assert.equal(s.reserve,40);assert(s.owned.has('rifle'));assert.equal(api.getDrops().length,0);
  assert.equal(api.pickup(drop.drop.uid).ok,false,'same ground item cannot be granted twice');
});
test('range, wall, interior and disabled authority checks retain source state',()=>{
  const {state:s,api}=fixture();s.blocked=true;assert.equal(api.drop().error,'blocked_surface');assert.equal(s.weapon,'rifle');s.blocked=false;
  const d=api.drop().drop;s.player.c+=10;assert.equal(api.pickup(d.uid).error,'out_of_reach');s.player.c-=10;
  s.blocked=true;assert.equal(api.pickup(d.uid).error,'blocked_surface');s.blocked=false;s.player.interior=true;assert.equal(api.pickup(d.uid).error,'unsupported_surface');
  s.player.interior=false;s.enabled=false;assert.equal(api.pickup(d.uid).error,'unavailable');assert.equal(api.drop().error,'unavailable');assert.deepEqual(api.getDrops(),[]);s.enabled=true;
  assert(api.pickup(d.uid).ok);assert.equal(s.mags.rifle,17);
});
test('exact five minute expiry never restores an expired weapon',()=>{
  const {state:s,api}=fixture();const d=api.drop().drop;s.time=d.expiresAt;
  assert.equal(api.pickup(d.uid).error,'drop_unavailable');assert.equal(api.getDrops().length,0);assert(!s.owned.has('rifle'));assert.equal(s.mags.rifle,0);
});
test('independent snapshots cannot mutate stored drops and reacquired ownership cannot duplicate ammo',()=>{
  const {state:s,api}=fixture();const d=api.drop().drop;d.fireState.magazine=999;api.getDrops()[0].position.x=999;
  assert.equal(api.getDrops()[0].fireState.magazine,17);s.owned.add('rifle');assert.equal(api.pickup(d.uid).error,'already_owned');assert.equal(api.getDrops().length,1);
});

test('actual world bridge keeps local transfers isolated from network authority',async()=>{
  const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
  const start=source.indexOf('  async getWalkGroundWeapons(){'),end=source.indexOf('  selectWalkWeapon(',start);
  assert(start>0&&end>start);
  let localCalls=0,networkCalls=0;
  const local={getDrops:()=>[],drop:()=>{localCalls++;return {ok:true};},pickup:()=>{localCalls++;return {ok:true};}};
  const remote={refresh:async()=>{},getDrops:()=>[],drop:()=>{networkCalls++;return {ok:true};},pickup:()=>{networkCalls++;return {ok:true};}};
  const context={_LOCAL_PREVIEW:true,_serverAuthoritativeAmmo:false,_walkRendererActive:()=>true,
    _getLocalWalkWeaponTransfers:async()=>local,_getWalkWeaponTransfers:async()=>remote,
    ws:{readyState:1},myDead:false,chatOpen:false,_gameMenuOpen:false,_meleeActionLocked:()=>false,
    _walkTransferBusy:false,_walkEquipPending:false,_profileEquipPending:false,currentWeapon:'rifle'};
  const bridge=vm.runInNewContext('({'+source.slice(start,end)+'})',context);
  assert((await bridge.dropWalkWeapon()).ok);assert((await bridge.pickupWalkWeapon('drop')).ok);assert.equal(localCalls,2);assert.equal(networkCalls,0);
  context._LOCAL_PREVIEW=false;
  assert.equal((await bridge.dropWalkWeapon()).ok,false);assert.equal(localCalls,2,'non-local offline is not granted local authority');
  context._serverAuthoritativeAmmo=true;
  assert((await bridge.dropWalkWeapon()).ok);assert((await bridge.pickupWalkWeapon('drop')).ok);assert.equal(networkCalls,2);assert.equal(localCalls,2);
  context.ws=null;assert.equal((await bridge.dropWalkWeapon()).ok,false);assert.equal(localCalls,2,'network disconnect never falls back to local drops');
});
