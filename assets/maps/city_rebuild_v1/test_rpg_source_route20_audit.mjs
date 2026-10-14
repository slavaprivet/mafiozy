// Read-only audit: execute actual source scheduling, selection and HP mutation.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
function actual(name){const a=source.indexOf('function '+name+'(');assert(a>=0,name);return source.slice(a,source.indexOf('\n}',a)+2);}
function fixture(){
 const timers=[],bullets=[],noop=()=>{},c={performance:{now:()=>5000},Math:Object.create(Math),QP:{uid:'local'},player:{r:0,c:0},myDead:true,myDrivingCarId:null,CARS:[],cityCops:[],_bankInt:null,_buildingInt:null,beachgoers:new Map(),currentWeapon:'rpg',
  _walkShotContext:null,_walkMeleeDamageContext:null,_authoritativeShotId:'rocket1',_authoritativeTargetClaims:new Set(),_pendingBallisticFxTimers:0,
  weaponProfile:()=>({dmg:160,bulletSpeed:15}),isBlocked:()=>false,_usesPooled3DFx:()=>true,_explosionSound:noop,_capArr:noop,explosionBursts:[],impacts:[],_MAX_IMPACTS:100,bloodSplats:[],_MAX_BLOOD:100,
  _damageCasinoPropsInRadius:()=>0,_currentShotDamage:x=>x,spawnImpact:noop,_showCurrentShotCritical:noop,_sendWorldWeaponFire:noop,addShake:noop,hapticHit:noop,
  _markCombatBleeding:noop,_walkConfirmDamage:noop,_npcPathPassable:()=>true,_npcRememberAggression:noop,_npcSpreadRumor:noop,npcCivilianUnarmed:()=>false,_npcTrySurrenderAfterHit:()=>false,_registerMurderIncident:noop,_respawnResidentImmediately:noop,spawnFloatText:noop,
  setTimeout:(fn,delay)=>{timers.push({fn,delay});},spawnBullet:(...args)=>bullets.push(args)};
 c.Math.random=()=>.99;const npc={id:'near-impact',r:1,c:1,hp:1000};c.NPCS=[npc];
 vm.createContext(c);vm.runInContext(['_walkShotAllows','_walkShotPhysicalContact','_weaponWallDistance','_projectTargetOnRay','_localBallisticTargets','_scheduleBallisticFx','_fireRpgRound','_spawnRpgExplosion','hitNpc'].map(actual).join('\n'),c);
 return {c,npc,timers,bullets,flush(){c._walkShotContext=null;for(const t of timers.splice(0))t.fn();}};
}
test('actual scheduled RPG no-contact route explodes at source range, not nearby native floor/object impact',()=>{
 const f=fixture();f.c._walkShotContext={ref:null,contact:null,request:{resolveContact:()=>null,muzzleR:0,muzzleC:0}};
 assert.equal(f.c._localBallisticTargets('rpg').length,0);
 f.c._fireRpgRound(0,0,0,1,15,null);
 assert.equal(f.timers.length,1);assert.equal(f.timers[0].delay,1000);assert.equal(f.bullets[0][3],15);
 f.flush();assert.equal(f.c.explosionBursts[0].c,15);assert.equal(f.npc.hp,1000,'no damage beside a native floor/object impact at (0,1)');
 // Same actual source resolver at that native impact point does inflict HP loss.
 f.c._spawnRpgExplosion(0,1,null,'rpg','verified-impact');assert(f.npc.hp<1000);
});
test('actual scheduled direct NPC contact admits its point, then radius damages other local targets too',()=>{
 const f=fixture(),second={id:'splash',r:1,c:1.5,hp:1000};f.c.NPCS.push(second);
 f.c._walkShotContext={ref:f.npc,contact:{point:{x:4.1,y:1,z:4.1}},request:{resolveContact(){},muzzleR:0,muzzleC:0}};
 assert.equal(f.c._localBallisticTargets('rpg').length,1);
 f.c._fireRpgRound(0,0,Math.SQRT1_2,Math.SQRT1_2,15,null);f.flush();
 assert(Math.abs(f.c.explosionBursts[0].r-1)<1e-8);assert(f.npc.hp<1000);assert(second.hp<1000);
});
test('actual explosion under active missed-contact context selects zero NPCs; cleared delayed context restores HP damage',()=>{
 const f=fixture();f.c._walkShotContext={ref:null,request:{resolveContact:()=>null}};
 f.c._spawnRpgExplosion(0,1,null,'rpg','active');assert.equal(f.npc.hp,1000);
 f.c._walkShotContext=null;f.c._spawnRpgExplosion(0,1,null,'rpg','delayed');assert(f.npc.hp<1000);
});
