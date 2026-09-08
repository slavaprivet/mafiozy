import assert from 'node:assert/strict';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {ARSENAL,createWeaponModel} from './hero_arsenal.mjs';
import {createWeaponFireState,PROJECTILE_VISUALS,stepWeaponFire} from './hero_weapon_fire.mjs';
import {createWeaponEffects,resolveWeaponShotTransforms} from './weapon_effects.mjs';

const deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const THREE=await import(pathToFileURL(path.join(deps,'build/three.module.js')));
const impacts=[];
const scene=new THREE.Scene(),effects=createWeaponEffects(THREE,scene,{worldScale:1,onImpact:payload=>impacts.push(payload),limits:{projectiles:18,casings:6,flashes:4,impacts:6,marks:6,explosions:2,pendingCasings:6}});
const ids=ARSENAL.filter(item=>item.id!=='none').map(item=>item.id);
assert.deepEqual(Object.keys(PROJECTILE_VISUALS),ids);
assert.equal(new Set(ids.map(id=>JSON.stringify(PROJECTILE_VISUALS[id]))).size,ids.length,'every weapon needs a distinct projectile visual');

const mounted=createWeaponModel({THREE,id:'m16'});mounted.position.set(3,1,4);mounted.rotation.y=.35;scene.add(mounted);scene.updateMatrixWorld(true);
const transforms=resolveWeaponShotTransforms(THREE,mounted),expectedMuzzle=mounted.localToWorld(new THREE.Vector3().fromArray(mounted.userData.muzzle));
assert(transforms.origin.distanceTo(expectedMuzzle)<1e-9);assert(transforms.ejectionOrigin.distanceTo(transforms.origin)>.01);assert(Math.abs(transforms.direction.length()-1)<1e-9);

const obstacle=new THREE.Mesh(new THREE.BoxGeometry(2,2,.2),new THREE.MeshBasicMaterial());obstacle.position.set(0,1,4);scene.add(obstacle);scene.updateMatrixWorld(true);
const origin=new THREE.Vector3(0,1,0),target=new THREE.Vector3(0,1,10);
const pistolShot=stepWeaponFire(createWeaponFireState('tt_pistol'),{triggerPressed:true},0).shots[0];
assert.equal(effects.shoot(pistolShot,{origin,ejectionOrigin:new THREE.Vector3(.2,1,0)},target,[obstacle]),true);
let active=effects.debugProjectiles();assert.equal(active.length,1);assert.equal(active[0].visualId,'tt_pistol');assert.equal(active[0].hasAura,false);assert(active[0].coreSize.x<=.025&&active[0].coreSize.y<=.12,'bullet must remain a small elongated projectile rather than a ball');assert.equal(scene.getObjectByName('projectile-glow'),undefined,'projectile pool must contain no glow or aura mesh');const initialZ=active[0].position.z;
effects.update(.02);active=effects.debugProjectiles();assert(active.length===1&&active[0].position.z>initialZ,'bullet must visibly advance instead of drawing a full instant ray');const ejectedCase=effects.debugCasings()[0];assert(ejectedCase&&Math.hypot(ejectedCase.velocity.x,ejectedCase.velocity.z)>1.5&&ejectedCase.velocity.y>1.9,'casing must eject distinctly sideways and upward');
for(let i=0;i<20;i++)effects.update(.02);assert.equal(effects.stats().activeProjectiles,0);assert(effects.stats().totalImpacts>=1,'moving projectile must sweep into scene geometry');
const mark=effects.debugMarks()[0];assert(mark&&mark.parent===obstacle,'impact mark must attach to the exact hit mesh');assert(mark.normal.z<-.9,'impact mark must follow the hit face normal');assert.equal(mark.maxLife,5);assert(mark.size<=.035,'ordinary impact must be a small surface chip');assert(mark.color<0x404040,'ordinary impact must be dark, not a burgundy disk');assert.equal(impacts.length,1);assert.equal(impacts[0].weaponId,'tt_pistol');assert.equal(impacts[0].damage,24);assert.equal(impacts[0].shotId,'tt_pistol:1');assert.equal(impacts[0].hit.object,obstacle);assert(impacts[0].direction.z>.9);const markX=mark.position.x;obstacle.position.x+=2;scene.updateMatrixWorld(true);assert(Math.abs(effects.debugMarks()[0].position.x-markX-2)<1e-6,'mark must move with a hit vehicle/door/mesh');obstacle.rotation.y=Math.PI/2;scene.updateMatrixWorld(true);assert(effects.debugMarks()[0].normal.x<-.9,'mark normal must rotate with its hit mesh');
effects.update(.01);assert.equal(effects.stats().totalCases,1,'automatic pistol casing leaves its authored ejection port');

const shotgunShot=stepWeaponFire(createWeaponFireState('shotgun'),{triggerPressed:true},0).shots[0];effects.shoot(shotgunShot,origin,target,[]);assert.equal(effects.stats().activeProjectiles,7);assert(effects.debugProjectiles().every(p=>p.visualId==='shotgun'));assert.equal(effects.stats().pendingCasings,1);effects.update(.1);effects.update(.1);assert.equal(effects.stats().totalCases,1);effects.update(.1);effects.update(.05);assert.equal(effects.stats().totalCases,2,'pump casing waits for the pump phase');
const rocket=stepWeaponFire(createWeaponFireState('rpg'),{triggerPressed:true},0).shots[0];effects.shoot(rocket,origin,target,[obstacle]);assert(effects.debugProjectiles().some(p=>p.visualId==='rpg'));assert.equal(rocket.projectiles[0].visual.kind,'rocket');obstacle.position.set(0,1,4);obstacle.rotation.set(0,0,0);scene.updateMatrixWorld(true);for(let i=0;i<30&&effects.stats().activeExplosions===0;i++)effects.update(.02);assert.equal(effects.stats().totalExplosions,1,'RPG impact must spawn a full bounded fiery explosion');assert.equal(impacts.at(-1).explosive,true);assert.equal(impacts.at(-1).damage,160);

// Every mark owns its own five-second expiry. A younger mark must remain when
// an older mark expires instead of being cleared by one global timeout.
const lifeScene=new THREE.Scene(),lifeWall=new THREE.Mesh(new THREE.BoxGeometry(2,2,.2),new THREE.MeshBasicMaterial());lifeWall.position.set(0,1,3);lifeScene.add(lifeWall);lifeScene.updateMatrixWorld(true);const lifeFx=createWeaponEffects(THREE,lifeScene,{worldScale:1,limits:{projectiles:4,casings:2,flashes:2,impacts:2,marks:3,explosions:1,pendingCasings:2}});
lifeFx.shoot(pistolShot,origin,target,[lifeWall]);for(let i=0;i<20&&lifeFx.stats().activeMarks===0;i++)lifeFx.update(.02);assert.equal(lifeFx.stats().activeMarks,1);for(let i=0;i<10;i++)lifeFx.update(.1);lifeFx.shoot(pistolShot,new THREE.Vector3(.2,1,0),new THREE.Vector3(.2,1,10),[lifeWall]);for(let i=0;i<20&&lifeFx.stats().activeMarks===1;i++)lifeFx.update(.02);assert.equal(lifeFx.stats().activeMarks,2);for(let i=0;i<40;i++)lifeFx.update(.1);assert.equal(lifeFx.stats().activeMarks,1,'younger impact must survive the older impact five-second expiry');for(let i=0;i<11;i++)lifeFx.update(.1);assert.equal(lifeFx.stats().activeMarks,0);lifeFx.dispose();

for(let i=0;i<80;i++)effects.shoot(pistolShot,origin,target,[]);assert(effects.stats().activeProjectiles<=effects.limits.projectiles);assert(effects.stats().activeMarks<=effects.limits.marks);assert(effects.stats().active<=effects.stats().poolCapacity);
assert.throws(()=>effects.update(-1));effects.dispose();effects.dispose();assert.equal(scene.children.includes(mounted),true,'disposing effects cannot remove weapon/gameplay objects');
console.log(JSON.stringify({passed:true,weapons:ids.length,checks:['distinct_projectile_visuals','small_elongated_no_aura','exact_muzzle_transform','ejection_port_transform','side_up_casing_motion','visible_projectile_motion','swept_collision','surface_normal_mark','small_dark_chip','moving_mesh_parenting','per_mark_five_second_expiry','impact_payload_damage_shot_id','shotgun_pellets','rocket_shape','rpg_fiery_explosion','delayed_pump_case','bounded_pools','isolated_dispose']}));
