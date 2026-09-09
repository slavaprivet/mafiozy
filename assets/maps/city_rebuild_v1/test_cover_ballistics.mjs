import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {FIREARM_IDS,createWeaponFireState,stepWeaponFire,sampleWeaponAccuracy,weaponFireProfile} from './hero_weapon_fire.mjs';
import {createWorldWalkCombat} from './world_walk_combat.mjs';

const near=(a,b,label)=>assert(Math.abs(a-b)<1e-10,`${label}: ${a} != ${b}`);
let cases=0;
for(const id of FIREARM_IDS){
  const fresh=createWeaponFireState(id),profile=weaponFireProfile(id);
  const aimed=stepWeaponFire(fresh,{triggerPressed:true,aiming:true,coverFire:'aim'},0).shots[0];
  near(aimed.projectiles[0].yawOffset,0,id+' aimed first yaw');
  near(aimed.projectiles[0].pitchOffset,0,id+' aimed first pitch');
  for(const posture of ['stand','crouch','prone']){
    const input={triggerPressed:true,coverFire:'blind',posture};
    const result=stepWeaponFire(fresh,input,0),shot=result.shots[0],accuracy=sampleWeaponAccuracy(fresh,input);
    assert.equal(result.state.magazine,fresh.magazine-1);
    assert.equal(shot.damage,profile.damage);
    near(result.state.cooldown,profile.cooldown,'unchanged cadence');
    const radius=Math.hypot(shot.projectiles[0].yawOffset,shot.projectiles[0].pitchOffset);
    assert(radius>=.052&&radius<=.090000001,id+' meaningful bounded first shot');
    near(accuracy.recoilYaw,shot.projectiles[0].yawOffset,id+' reticle yaw');
    near(accuracy.recoilPitch,shot.projectiles[0].pitchOffset,id+' reticle pitch');
    near(accuracy.coverSpread,.09,id+' cover cone');
    assert.deepEqual(shot,stepWeaponFire(fresh,input,0).shots[0],id+' seeded repeatability');
    const recovered={...stepWeaponFire(result.state,{},Math.min(5,profile.handling.recovery+.1)).state,magazine:profile.magazineSize};
    const next=stepWeaponFire(recovered,input,0).shots[0];
    assert(next&&next.sequence===2);
    assert(Math.hypot(next.projectiles[0].yawOffset-shot.projectiles[0].yawOffset,next.projectiles[0].pitchOffset-shot.projectiles[0].pitchOffset)>.02,id+' recovery cannot repeat a learnable offset');
    cases++;
  }
}

const THREE=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const origin=new THREE.Vector3(3,1.2,7),yaw=.31,pitch=.14,range=8;
const forward=new THREE.Vector3(Math.cos(yaw)*Math.cos(pitch),Math.sin(pitch),Math.sin(yaw)*Math.cos(pitch));
for(const coverFire of [undefined,'aim','blind']){
  let accepted=true,source={magazine:4,reserve:19},requestSeen;
  const sourceSpread=.013;
  const bridge={getPlayerState:()=>source,reloadWalkWeapon(){},fireWalkShot(request){
    requestSeen=request;
    request.resolveContact({angle:request.angle+sourceSpread,range});
    if(accepted)source={...source,magazine:source.magazine-1};
    return {accepted,shotId:'source:cover',state:source};
  }};
  const combat=createWorldWalkCombat({THREE,bridge,getActors:()=>[],obstacles:()=>[]});
  const fresh=createWeaponFireState('tt_pistol'),input={triggerPressed:true,coverFire};
  const accuracy=sampleWeaponAccuracy(fresh,input);
  const result=combat.step(fresh,input,.016,{origin,forward}),shot=result.shots[0];
  near(requestSeen.angle,yaw+accuracy.coverYaw,'source receives cover yaw once');
  near(requestSeen.pitch,pitch+accuracy.coverPitch,'source receives cover pitch');
  const actual=shot.worldTarget.clone().sub(origin).normalize();
  near(Math.atan2(actual.z,actual.x),yaw+sourceSpread+accuracy.coverYaw,'physical direction preserves source spread and adds cover once');
  near(Math.asin(actual.y),pitch+accuracy.coverPitch,'physical pitch follows cover');
  assert(shot.projectiles.every(p=>p.yawOffset===0&&p.pitchOffset===0),'worldTarget prevents double cosmetic spread');
  assert.equal(result.state.magazine,3);assert.equal(result.state.reserveAmmo,19);
  accepted=false;
  const rejected=combat.step(result.state,input,1,{origin,forward});
  assert.equal(rejected.shots.length,0);assert.equal(rejected.state.magazine,3);
  assert.equal(rejected.state.sequence,result.state.sequence,'rejection cannot consume cover sequence');
  combat.dispose();cases++;
}
console.log(`PASS cover ballistics: ${cases} weapon/posture/source cases; actual first-shot cone, aimed precision, unchanged authority/ammo/cadence, deterministic sequence, physical source direction without double spread`);
