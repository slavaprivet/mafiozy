// Execute the production bridge method, not a copy of its custody expressions.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source=fs.readFileSync('world.html','utf8').replace(/\r\n/g,'\n');
const start=source.indexOf('  getPlayerState() {');
const end=source.indexOf('\n  setAim(angle)',start);
assert.ok(start>=0&&end>start,'actual Mafiozi3DBridge.getPlayerState exists');
const env={
  Math,Number,String,performance:{now:()=>10000},_LOCAL_PREVIEW:false,_UP:new URLSearchParams(),
  _threePlayerAnimationTelemetry:()=>({speed:0,accel:0,moveAng:0,teleported:false,aiming:false,impact:0}),
  resolveWeapon:()=> 'pistol',_isReloadingWeapon:()=>false,weaponProfile:()=>({}),_reloadUntil:0,
  _punchAnim:null,ARMOR_STYLES:{},_combatState:{body:{current:42,max:100,dead:false},armor:{},combat_version:1},
  _threeVehicleEntrySequence:null,_murderPoliceArrest:null,_murderPoliceArrestProgress:()=>.5,
  _effectivePrisonJailSeconds:()=>0,_effectivePlayerStance:()=> 'stand',_playerStance:{changedAt:0},
  player:{r:10,c:20,ang:0,walking:false,walkPhase:0},myHp:42,myDead:false,myMode:'pvp',
  currentWeapon:null,_familyPistolActive:()=>false,_lastEquippedWeapon:'pistol',myDrivingCarId:null,
  _weaponAmmoState:()=>null,_playerEmergencyPatient:null,_buildingInt:null,_bankInt:null,_majorInteriorObjectId:null,
  _prisonReleaseGateProgress:()=>1,_prisonAlarmActive:()=>false,_prisonAlarmState:{},_bankRob:null,_myBagWeight:0,
  QP:{name:'Captured player',look:{hat:1}},_localChat:null,_localChatT:0,
  _policeState:{employed:false},_mafiaState:{employed:true,family:'retained-family'},
  _meleeBlockHeld:false,_meleeBruiseAt:0,MELEE_BRUISE_LIFETIME_MS:1000,_meleeStunnedIn:0,_meleeChargeStartedAt:0,
  joyL:{},joyR:{},document:{documentElement:{dataset:{}}},
};
vm.createContext(env);
vm.runInContext('globalThis.bridge={'+source.slice(start,end)+'};',env);
const state=()=>env.bridge.getPlayerState();
assert.equal(state().dead,false);
assert.equal(state().role,'mafia');
// Reconnection preserves a living, still-captured player and their street identity.
env._murderPoliceArrest={phase:'awaiting_pickup',_serverCaptureLiving:true,voluntary:true};
let actual=state();
assert.equal(actual.dead,false,'living server capture must not become a corpse after reconnect');
assert.equal(actual.healthDead,false);assert.equal(actual.healthCustody,true);
assert.equal(actual.arrestPhase,'cuffing');assert.equal(actual.hp,42);
assert.equal(actual.role,'mafia');assert.equal(actual.family,'retained-family');assert.equal(actual.prisonBooked,false);
// True death takes priority even while the old custody object still exists for this snapshot.
env.myDead=true;env.myHp=0;env._combatState.body={current:0,max:100,dead:true};
for(const phase of ['awaiting_pickup','cuffing','escort','transport','booking']){
  env._murderPoliceArrest.phase=phase;actual=state();
  assert.equal(actual.dead,true,`confirmed death cannot be masked by living custody in ${phase}`);
  assert.equal(actual.healthDead,true);assert.equal(actual.hp,0);assert.equal(actual.combat_state.body.dead,true);
}
// Existing downed extraction remains a presentation owner, distinguishable from health death.
env.myDead=false;env._combatState.body={current:0,max:100,dead:false};
env._murderPoliceArrest={phase:'downed'};
actual=state();assert.equal(actual.dead,true);assert.equal(actual.healthDead,false);assert.equal(actual.arrestPhase,'downed');
// Alive transport stays alive; custody itself must not create a health death.
env.myHp=42;env._combatState.body.current=42;env._murderPoliceArrest={phase:'transport',_serverCaptureLiving:true};
actual=state();assert.equal(actual.dead,false);assert.equal(actual.healthDead,false);assert.equal(actual.arrestPhase,'transport');assert.equal(actual.arrestHidden,true);
env._murderPoliceArrest=null;env.myDead=true;assert.equal(state().dead,true,'ordinary death remains visible without custody');
console.log('PASS actual getPlayerState: living reconnect/cuffing, faction preserved until booking, true death priority across five custody phases, legacy downed extraction, alive transport and ordinary death');
