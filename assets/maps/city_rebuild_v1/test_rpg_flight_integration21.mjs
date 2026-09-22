// Actual source HP resolver + bridge + travelling Three projectile. Admission
// accounting is separately exercised by the source/server contract tests.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {pathToFileURL} from 'node:url';
import {createWorldWalkCombat} from './world_walk_combat.mjs';
import {createWeaponFireState} from './hero_weapon_fire.mjs';
import {createWeaponEffects} from './weapon_effects.mjs';
const THREE=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
function actual(name){const a=source.indexOf('function '+name+'(');assert(a>=0,name);return source.slice(a,source.indexOf('\n}',a)+2);}
const bridgeStart=source.indexOf('  fireWalkShot(request={}){'),bridgeCode=source.slice(bridgeStart,source.indexOf('\n  fire(angle, muzzleR, muzzleC)',bridgeStart));
function fixture(){
 let now=5000,ammo=1,sequence=0;const noop=()=>{},scene=new THREE.Scene(),actors=[],roots=[],impacts=[],slices=[];
 const c={performance:{now:()=>now},Math:Object.create(Math),QP:{uid:'fixture'},player:{r:0,c:0},myDead:true,myDrivingCarId:null,CARS:[],cityCops:[],_bankInt:null,_buildingInt:null,beachgoers:new Map(),currentWeapon:'rpg',
  _walkShotContext:null,_walkMeleeDamageContext:null,_walkPendingShots:new Map(),_authoritativeShotId:'',_authoritativeTargetClaims:new Set(),_threeNpcActionRefs:new Map(),
  resolveWeapon:w=>w,_walkRendererActive:()=>true,_isArmed:()=>true,weaponsForPick:()=>[{id:'rpg'}],weaponProfile:()=>({dmg:160,bulletSpeed:15}),
  _usesPooled3DFx:()=>true,_explosionSound:noop,_capArr:noop,explosionBursts:[],impacts:[],_MAX_IMPACTS:100,bloodSplats:[],_MAX_BLOOD:100,
  _damageCasinoPropsInRadius:()=>0,_currentShotDamage:x=>x,spawnImpact:noop,_showCurrentShotCritical:noop,addShake:noop,hapticHit:noop,_sendWorldWeaponFire:noop,
  _markCombatBleeding:noop,_walkConfirmDamage:noop,_npcPathPassable:()=>true,_npcRememberAggression:noop,_npcSpreadRumor:noop,npcCivilianUnarmed:()=>false,_npcTrySurrenderAfterHit:()=>false,_registerMurderIncident:noop,_respawnResidentImmediately:noop,spawnFloatText:noop,
  setTimeout:()=>{throw Error('native flight cannot schedule a legacy explosion');},spawnBullet:()=>{throw Error('native flight cannot create legacy projectile');}};
 c.Math.random=()=>.99;c.NPCS=[{id:'near',r:1,c:1,hp:1000},{id:'far',r:8,c:8,hp:1000}];
 c._walkShotNativeRef=id=>c.NPCS.find(n=>n.id===id)||null;
 vm.createContext(c);vm.runInContext(['_walkShotAllows','_walkShotPhysicalContact','_walkResolveShotContact','_localBallisticTargets','_fireRpgRound','_spawnRpgExplosion','hitNpc','_walkImpactRpg'].map(actual).join('\n'),c);
 c._threeBridgeFireAccepted=angle=>{
  if(!ammo)return false;
  ammo--;const ctx=c._walkShotContext,range=15,aim=ctx.request.resolveAim({range});
  ctx.shotId=c._authoritativeShotId='native:'+ ++sequence;ctx.pitch=aim.pitch;c._walkPendingShots.set(ctx.shotId,ctx);
  c._walkResolveShotContact(aim.angle,range,'rpg');
  c._fireRpgRound(ctx.request.muzzleR,ctx.request.muzzleC,Math.sin(aim.angle),Math.cos(aim.angle),range,null);return true;
 };
 vm.runInContext('globalThis.bridge={getPlayerState(){return {magazine:0,reserve:0};},'+bridgeCode+'};',c);
 const combat=createWorldWalkCombat({THREE,bridge:c.bridge,getActors:()=>actors,obstacles:()=>roots,now:()=>now});
 const effects=createWeaponEffects(THREE,scene,{onImpact(payload){const receipt=c.bridge.impactWalkRpg({shotId:payload.shotId,point:payload.point});impacts.push({payload,receipt});},limits:{projectiles:4,casings:1,flashes:2,impacts:2,marks:2,explosions:2,pendingCasings:1}});
 function fire(direction){const origin=new THREE.Vector3(0,1.5,0),result=combat.step(createWeaponFireState('rpg'),{triggerPressed:true},0,{origin,forward:direction});assert.equal(result.shots.length,1);const shot=result.shots[0];assert(shot.nativeRpgImpact);assert.equal(shot.projectiles[0].range,15);effects.shoot(shot,new THREE.Vector3(10,10,10),shot.worldTarget,roots,{resolveContact:combat.projectileContact});assert.deepEqual(effects.debugProjectiles()[0].position.toArray(),origin.toArray(),'late mount motion cannot move admitted origin');return shot;}
 function tick(dt){now+=dt*1000;const at=performance.now();effects.update(dt);slices.push(performance.now()-at);}
 function dispose(){effects.dispose();combat.dispose();for(const root of roots)root.traverse(n=>{n.geometry?.dispose();n.material?.dispose();});for(const a of actors)a.object.traverse(n=>{n.geometry?.dispose();n.material?.dispose();});}
 return {c,scene,actors,roots,impacts,slices,combat,effects,fire,tick,dispose};
}
const reports=[];
for(const fps of [7,15,60]){
 const f=fixture(),floor=new THREE.Mesh(new THREE.PlaneGeometry(30,30),new THREE.MeshBasicMaterial({side:THREE.DoubleSide}));floor.rotation.x=-Math.PI/2;f.scene.add(floor);f.roots.push(floor);
 const shot=f.fire(new THREE.Vector3(4.1,-1.5,0).normalize());assert.equal(f.c.NPCS[0].hp,1000);
 for(let i=0;i<fps*2&&!f.impacts.length;i++)f.tick(1/fps);
 assert.equal(f.impacts.length,1);const event=f.impacts[0];assert(event.receipt.accepted);assert(Math.abs(event.payload.point.x-4.1)<1e-8);assert(Math.abs(event.payload.point.y)<1e-8);assert(f.c.NPCS[0].hp<1000);assert.equal(f.c.NPCS[1].hp,1000);
 const hp=f.c.NPCS[0].hp;assert.equal(f.c.bridge.impactWalkRpg({shotId:shot.shotId,point:event.payload.point}).reason,'duplicate');f.tick(2);assert.equal(f.c.NPCS[0].hp,hp);assert.equal(f.impacts.length,1);
 reports.push({scenario:'floor',fps,damage:1000-hp,impact:event.payload.point.toArray(),maxUpdateMs:Math.max(...f.slices)});f.dispose();
}
// A posed, moving skin intercepts the travelling rocket at its current position.
{
 const f=fixture(),root=new THREE.Group(),bone=new THREE.Bone(),g=new THREE.PlaneGeometry(2,2);g.setAttribute('skinIndex',new THREE.Uint16BufferAttribute(new Uint16Array(16),4));g.setAttribute('skinWeight',new THREE.Float32BufferAttribute([1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0],4));
 const skin=new THREE.SkinnedMesh(g,new THREE.MeshBasicMaterial({side:THREE.DoubleSide}));root.add(bone,skin);skin.bind(new THREE.Skeleton([bone]));root.rotation.y=Math.PI/2;root.position.set(4.1,1.5,0);f.scene.add(root);root.updateMatrixWorld(true);f.actors.push({id:'near',object:root});f.c.NPCS[0].r=0;f.c.NPCS[0].c=1;
 f.fire(new THREE.Vector3(1,0,0));root.position.x=6.15;f.c.NPCS[0].c=1.5;f.tick(.2);
 assert.equal(f.impacts.length,1);assert(f.impacts[0].receipt.accepted);assert.equal(f.impacts[0].payload.object,skin);assert(Math.abs(f.impacts[0].payload.point.x-6.15)<1e-8);assert.equal(f.c.NPCS[0].hp,840);assert.equal(f.effects.stats().totalMarks,0,'no scenery scorch attached to skinned NPC');reports.push({scenario:'moving skin',damage:160});f.dispose();
}
// Missed native rockets still have the old authored end-of-range detonation.
{
 const f=fixture();f.c.NPCS[0].r=0;f.c.NPCS[0].c=15;f.fire(new THREE.Vector3(1,0,0));f.tick(2);
 assert.equal(f.impacts.length,1);assert(f.impacts[0].receipt.accepted);assert(f.impacts[0].payload.rangeEnd);assert.equal(f.impacts[0].payload.hit,null);assert(Math.abs(f.impacts[0].payload.point.x-61.5)<1e-8);assert.equal(f.c.NPCS[0].hp,840);f.tick(1);assert.equal(f.impacts.length,1);reports.push({scenario:'range endpoint',damage:160});f.dispose();
}
// A nearer real wall wins over a farther skin; renderer rejection emits nothing.
{
 const f=fixture(),wall=new THREE.Mesh(new THREE.BoxGeometry(.2,5,5),new THREE.MeshBasicMaterial());wall.position.set(4,1.5,0);f.roots.push(wall);f.scene.add(wall);f.fire(new THREE.Vector3(1,0,0));f.tick(.1);assert.equal(f.impacts.length,1);assert.equal(f.impacts[0].payload.object,wall);assert(Math.abs(f.impacts[0].payload.point.x-3.9)<1e-8);assert(f.impacts[0].receipt.accepted);
 const rejected=f.combat.step(createWeaponFireState('rpg'),{triggerPressed:true},0,{origin:new THREE.Vector3(0,1.5,0),forward:new THREE.Vector3(1,0,0)});assert.equal(rejected.shots.length,0);reports.push({scenario:'wall + rejected second shot'});f.dispose();
}
console.log(JSON.stringify({pass:true,reports,limits:'CPU actual source/bridge/Three swept collision; no loaded-scene FPS or authenticated server AoE claim.'},null,2));
