import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
const recordSource=fs.readFileSync(new URL('./npc_death_record20_source.js',import.meta.url),'utf8');
const blastSource=fs.readFileSync(new URL('./npc_blast_record20_source.js',import.meta.url),'utf8');
function actual(name){const a=source.indexOf('function '+name+'(');assert(a>=0,name);return source.slice(a,source.indexOf('\n}',a)+2);}
const originalRpg=actual('_spawnRpgExplosion');
const hitLine='    try{t.hit(dmg, d > 0.01 ? (t.r-r)/d : 0, d > 0.01 ? (t.c-c)/d : 1);}finally{_authoritativeShotId=pendingId;}';
assert(originalRpg.includes(hitLine));
const beforeLine='    const previousDeathRecord=t.key?._deathRecord20;';
const enrichLine="    if(typeof enrichNpcBlastRecord20==='function'){const record=enrichNpcBlastRecord20({entity:t.key,previousRecord:previousDeathRecord,originSource:{r,c}});if(record)t.key._deathRecord20=record;}";
assert(originalRpg.includes(beforeLine)&&originalRpg.includes(enrichLine),'production RPG must include reviewed metadata hook');
assert(source.includes('<script src="assets/maps/city_rebuild_v1/npc_blast_record20_source.js"></script>'));
const baselineRpg=originalRpg.replace(beforeLine,'').replace(enrichLine,'');
function fixture({random=.99,baseline=false}={}){
  const noop=()=>{},c={performance:{now:()=>5000},Math:Object.create(Math),QP:{uid:'local'},player:{r:50,c:50},myDead:false,myDrivingCarId:null,CARS:[],cityCops:[],_bankInt:null,_buildingInt:null,beachgoers:new Map(),currentWeapon:'rpg',
    _threeNpcIds:new WeakMap(),_threeNpcIdSeq:0,_threeNpcDeathTimes:new Map(),_walkShotContext:null,_walkMeleeDamageContext:null,_walkShotPhysicalContact:()=>null,_authoritativeShotId:'old-context',_authoritativeTargetClaims:new Set(),
    weaponProfile:()=>({dmg:160}),_usesPooled3DFx:()=>true,_explosionSound:noop,_capArr:noop,explosionBursts:[],impacts:[],_MAX_IMPACTS:100,bloodSplats:[],_MAX_BLOOD:100,
    _damageCasinoPropsInRadius:()=>0,_currentShotDamage:x=>x,spawnImpact:noop,_showCurrentShotCritical:noop,_sendWorldWeaponFire:noop,addShake:noop,hapticHit:noop,
    _markCombatBleeding:noop,_walkConfirmDamage:noop,_npcPathPassable:()=>true,_npcRememberAggression:noop,_npcSpreadRumor:noop,npcCivilianUnarmed:()=>false,_npcTrySurrenderAfterHit:()=>false,_registerMurderIncident:noop,_respawnResidentImmediately:noop,spawnFloatText:noop};
  c.Math.random=()=>random;const npc={id:'victim',r:1,c:0,hp:20};c.NPCS=[npc];
  vm.createContext(c);vm.runInContext(recordSource+'\n'+blastSource+'\n'+['_threeNpcEntityId','_threeNpcDeathState','hitNpc','_localBallisticTargets'].map(actual).join('\n')+'\n'+(baseline?baselineRpg:originalRpg),c);return {c,npc};
}
test('helper copies metadata immutably, preserving producer identity and designer speed distinct from damage',()=>{
  const {c}=fixture(),record=Object.freeze({version:1,confirmed:true,fatal:true,cause:'blast',targetId:'source-producer-id',eventId:'fatal7',deathKey:'5000'}),entity={dead:true,deadAt:5000,_deathRecord20:record},origin={r:3,c:7};
  const result=c.enrichNpcBlastRecord20({entity,previousRecord:null,originSource:origin});
  assert.notEqual(result,record);assert.equal(entity._deathRecord20,record);assert.equal(record.blastPresentation,undefined);assert(Object.isFrozen(result));assert(Object.isFrozen(result.blastPresentation));assert(Object.isFrozen(result.blastPresentation.originSource));
  assert.equal(result.targetId,record.targetId);assert.equal(result.eventId,record.eventId);assert.equal(result.deathKey,record.deathKey);assert.equal(result.blastPresentation.visualSpeed,5);
  origin.r=100;assert.equal(result.blastPresentation.originSource.r,3);
});
test('helper rejects stale/replayed/nonfatal/unconfirmed/medical/wrong epoch or invalid origin without changes',()=>{
  const {c}=fixture(),base={version:1,confirmed:true,fatal:true,cause:'blast',targetId:'npc7',eventId:'event7',deathKey:'5000'},originSource={r:0,c:0};
  for(const delta of [{version:2},{confirmed:false},{fatal:false},{cause:'bullet'},{deathKey:'4999'},{targetId:''},{eventId:''},{blastPresentation:{version:1}}]){
    const entity={dead:true,deadAt:5000,_deathRecord20:{...base,...delta}},before=JSON.stringify(entity);assert.equal(c.enrichNpcBlastRecord20({entity,originSource}),null);assert.equal(JSON.stringify(entity),before);
  }
  const record=Object.freeze(base),entity={dead:true,deadAt:5000,_deathRecord20:record};
  assert.equal(c.enrichNpcBlastRecord20({entity,previousRecord:record,originSource}),null);
  assert.equal(c.enrichNpcBlastRecord20({entity,previousRecord:{...record},originSource}),null,'same event copied by another adapter is not new death');
  for(const delta of [{dead:false},{_medicalDowned:true},{deadAt:NaN},{deadAt:0},{_deathRecord20:null}])assert.equal(c.enrichNpcBlastRecord20({entity:{...entity,...delta},originSource}),null);
  for(const origin of [null,{r:Infinity,c:0},{r:0,c:NaN},{r:'0',c:0}])assert.equal(c.enrichNpcBlastRecord20({entity,originSource:origin}),null);
});
test('PRODUCTION actual RPG + actual hitNpc enrich only new confirmed death; base damage/recipients identical',()=>{
  const before=fixture({baseline:true}),after=fixture();before.c._spawnRpgExplosion(0,0,null,'rpg','rpg1');after.c._spawnRpgExplosion(0,0,null,'rpg','rpg1');
  assert.equal(after.npc.dead,true);assert.equal(after.npc.hp,before.npc.hp);assert.equal(after.npc.deadAt,before.npc.deadAt);assert.equal(after.npc.r,before.npc.r);assert.equal(after.npc.c,before.npc.c);
  assert.equal(before.npc._deathRecord20.blastPresentation,undefined);assert.equal(after.npc._deathRecord20.blastPresentation.originSource.r,0);assert.equal(after.npc._deathRecord20.blastPresentation.visualSpeed,5);
  assert.equal(after.npc._deathRecord20.eventId,before.npc._deathRecord20.eventId);assert.equal(after.c._authoritativeShotId,'old-context');
  const saved=after.npc._deathRecord20;after.c._spawnRpgExplosion(1,1,null,'rpg','rpg2');assert.equal(after.npc._deathRecord20,saved,'old corpse does not get a new blast origin');
});
test('PRODUCTION actual RPG preserves medical survival, nonfatal/outside targets, and recordless source classes',()=>{
  const survivor=fixture({random:.1});survivor.c._spawnRpgExplosion(0,0,null,'rpg','medical');assert.equal(survivor.npc._medicalDowned,true);assert.equal(survivor.npc.hp,1);assert.equal(survivor.npc._deathRecord20,undefined);
  const f=fixture();f.npc.hp=1000;const outside={id:'outside',r:3,c:0,hp:20};f.c.NPCS.push(outside);const cop={id:'servercop',alive:true,x:0,y:1,hp:20};f.c.cityCops.push(cop);f.c.hitCityCop=(n,dy,dx,damage)=>{n.hp-=damage;n.alive=false;};
  f.c._spawnRpgExplosion(0,0,null,'rpg','partial');assert(f.npc.hp>0);assert.equal(f.npc._deathRecord20,undefined);assert.equal(outside.hp,20);assert.equal(cop._deathRecord20,undefined);assert.equal(cop.alive,false);
});
test('PRODUCTION callback exception restores original shot context and never enriches afterward',()=>{
  const f=fixture();f.c._localBallisticTargets=()=>[{key:f.npc,r:1,c:0,hit(){throw Error('source rejected');}}];
  assert.throws(()=>f.c._spawnRpgExplosion(0,0,null,'rpg','failure'),/source rejected/);assert.equal(f.c._authoritativeShotId,'old-context');assert.equal(f.npc._deathRecord20,undefined);
});
