import assert from 'node:assert/strict';
import {FIREARM_IDS,WEAPON_HANDLING,createWeaponFireState,weaponFireProfile,stepWeaponFire,sampleWeaponRecoil,sampleWeaponAccuracy} from './hero_weapon_fire.mjs';
import {createWeaponInventory} from './weapon_inventory.mjs';

const epsilon=(a,b,message)=>assert(Math.abs(a-b)<1e-10,`${message}: ${a} vs ${b}`);
const magnitude=shot=>Math.hypot(shot.projectiles[0].yawOffset,shot.projectiles[0].pitchOffset);
const fireFirst=(id,input={})=>stepWeaponFire(createWeaponFireState(id),{triggerPressed:true,...input},0);
function burst(id,input={},shots=5){
  const profile=weaponFireProfile(id);let state=createWeaponFireState(id),receipts=[];
  for(let n=0;n<shots;n++){
    // Fixture refill does not alter the handling history (RPG has one round).
    state={...state,magazine:profile.magazineSize,triggerHeld:false};
    const fired=stepWeaponFire(state,{triggerPressed:true,...input},n===0?0:profile.cooldown);
    state=fired.state;assert.equal(fired.shots.length,1,id);receipts.push(fired.shots[0]);
  }
  return {state,shots:receipts};
}
assert.deepEqual(Object.keys(WEAPON_HANDLING),FIREARM_IDS);
assert.equal(new Set(Object.values(WEAPON_HANDLING).map(tune=>tune.seed)).size,14);
const statistics=[];
for(const id of FIREARM_IDS){
  const profile=weaponFireProfile(id),fresh=fireFirst(id);
  assert.equal(fresh.shots[0].projectiles[0].yawOffset,0,`${id} first bullet horizontal reticle`);
  assert.equal(fresh.shots[0].projectiles[0].pitchOffset,0,`${id} first bullet vertical reticle`);
  const standing=burst(id),crouch=burst(id,{posture:'crouch'}),prone=burst(id,{posture:'prone'}),aim=burst(id,{aiming:true});
  const standingError=standing.shots.slice(1).reduce((sum,shot)=>sum+magnitude(shot),0);
  const crouchError=crouch.shots.slice(1).reduce((sum,shot)=>sum+magnitude(shot),0);
  const proneError=prone.shots.slice(1).reduce((sum,shot)=>sum+magnitude(shot),0);
  assert(standingError>0,`${id} sustained shots drift physically`);
  assert(crouchError<standingError&&proneError<crouchError,`${id} crouch/prone accuracy ordering`);
  epsilon(crouchError/standingError,.65,`${id} crouch ratio`);
  epsilon(proneError/standingError,.38,`${id} prone ratio`);
  assert(aim.shots.slice(1).reduce((sum,shot)=>sum+magnitude(shot),0)<standingError,`${id} aiming improves`);
  const walking=fireFirst(id,{moving:true}),running=fireFirst(id,{running:true});
  const crosshair=sampleWeaponAccuracy(createWeaponFireState(id),{moving:true});
  epsilon(crosshair.recoilYaw,walking.shots[0].projectiles[0].yawOffset,`${id} crosshair/projectile yaw agreement`);
  epsilon(crosshair.recoilPitch,walking.shots[0].projectiles[0].pitchOffset,`${id} crosshair/projectile pitch agreement`);
  epsilon(crosshair.spread,walking.shots[0].handling.spread+crosshair.pelletSpread,`${id} crosshair cone agreement`);
  assert(magnitude(walking.shots[0])>0,`${id} walking penalizes first shot`);
  assert(magnitude(running.shots[0])>magnitude(walking.shots[0]),`${id} running penalizes more`);
  assert.deepEqual(standing.shots,burst(id).shots,`${id} seeded repeatability`);
  let recovered=stepWeaponFire(standing.state,{triggerHeld:false},profile.handling.recovery+.01).state;
  assert.equal(recovered.sprayHeat,0);assert.equal(recovered.sprayShots,0);
  recovered={...recovered,magazine:profile.magazineSize};
  const recoveredShot=stepWeaponFire(recovered,{triggerPressed:true},0).shots[0];
  assert.equal(magnitude(recoveredShot),0,`${id} first shot after recovery is exact`);
  assert(recoveredShot.sequence>1,'recovery cannot reset unique shot sequence');
  assert(sampleWeaponRecoil(prone.state).cameraKick<sampleWeaponRecoil(standing.state).cameraKick);
  for(const shot of standing.shots)for(const projectile of shot.projectiles){
    assert(Number.isFinite(projectile.yawOffset)&&Number.isFinite(projectile.pitchOffset));
    assert(Math.abs(projectile.yawOffset)<.4&&Math.abs(projectile.pitchOffset)<.4,'readable bounded angular pattern');
  }
  if(profile.pellets>1){
    assert(fresh.shots[0].projectiles.slice(1).every(p=>Math.hypot(p.yawOffset,p.pitchOffset)>0),'shotguns keep pellet cone');
    epsilon(fresh.shots[0].projectiles.reduce((sum,p)=>sum+p.yawOffset,0),0,'first shotgun cone is centered horizontally');
    epsilon(fresh.shots[0].projectiles.reduce((sum,p)=>sum+p.pitchOffset,0),0,'first shotgun cone is centered vertically');
  }
  statistics.push({id,standingError:+standingError.toFixed(5),crouchError:+crouchError.toFixed(5),proneError:+proneError.toFixed(5)});
}

for(const id of FIREARM_IDS.filter(id=>weaponFireProfile(id).automatic)){
  // Verify identical shot timestamps/handling across a slow frame and 120Hz.
  const total=.83,batch=stepWeaponFire(createWeaponFireState(id),{triggerHeld:true},total);
  let state=createWeaponFireState(id),shots=[];
  for(let frame=0;frame<100;frame++){
    const next=stepWeaponFire(state,{triggerHeld:true},total/100);state=next.state;shots.push(...next.shots);
  }
  assert.equal(shots.length,batch.shots.length,`${id} frame partition shot count`);
  for(let n=0;n<shots.length;n++){
    epsilon(shots[n].projectiles[0].yawOffset,batch.shots[n].projectiles[0].yawOffset,`${id} frame partition yaw ${n}`);
    epsilon(shots[n].projectiles[0].pitchOffset,batch.shots[n].projectiles[0].pitchOffset,`${id} frame partition pitch ${n}`);
  }
  epsilon(state.sprayHeat,batch.state.sprayHeat,`${id} frame partition recovery`);
  assert(batch.shots.at(-1).handling.heat>batch.shots[1].handling.heat,'automatic heat grows over burst');
  assert(batch.shots.at(-1).handling.pitch>batch.shots[1].handling.pitch,'automatic upward recoil grows');
}

const inventory=createWeaponInventory();inventory.equip('uzi');
const hot=stepWeaponFire(inventory.getFireState(),{triggerHeld:true},.4).state;
inventory.equip('none',hot);const reequipped=inventory.equip('uzi').fireState;
assert.equal(reequipped.sprayHeat,hot.sprayHeat);assert.equal(reequipped.sprayShots,hot.sprayShots);
const dropped=inventory.drop({position:{x:0,y:0,z:0},fireState:reequipped}).drop;
assert.equal(inventory.pickup(dropped.uid).equippedId,'none');
const picked=inventory.equip('uzi').fireState;
assert.equal(picked.sprayHeat,hot.sprayHeat);assert.equal(picked.sprayRecoveryRemaining,hot.sprayRecoveryRemaining);
const next=stepWeaponFire(picked,{triggerPressed:true},picked.cooldown);
assert(magnitude(next.shots[0])>0,'equip/drop/pickup cannot manufacture recovered perfect first shot');

console.log(JSON.stringify({passed:true,weapons:14,checks:['first-shot-reticle','recovered-first-shot','persistent-receipt-sequence','distinct-seeded-patterns','physical-spray-growth','crouch-prone-accuracy','movement-running-penalty','aim-accuracy','symmetric-shotgun-cone','automatic-frame-partition','inventory-no-reset-exploit'],statistics}));
