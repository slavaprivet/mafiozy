// Review candidate only: production source remains unchanged during freeze.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
function actual(name){const a=source.indexOf('function '+name+'(');assert(a>=0,name);return source.slice(a,source.indexOf('\n}',a)+2);}
let copSource=actual('hitCityCop').replace('damage, source = null)', 'damage, source = null, acceptedImpact = null)').replace('let deathWitnessAlerted=false;','let deathWitnessAlerted=false,fatalReceipt=null;');
const corpseStart=copSource.indexOf('    NPCS.push({ id: cop.id'),corpseEnd=copSource.indexOf('\n    // При спасении',corpseStart);assert(corpseStart>=0&&corpseEnd>corpseStart);
const corpseLiteral=copSource.slice(corpseStart,corpseEnd).replace('NPCS.push({','const corpse={').replace(/\}\);\s*$/,'};');
copSource=copSource.slice(0,corpseStart)+corpseLiteral+`
    if(typeof createNpcFatalRecord20==='function')corpse._deathRecord20=createNpcFatalRecord20({entity:corpse,targetId:_threeNpcEntityId(corpse),weapon:acceptedImpact?.weapon,dirR:dirY,dirC:dirX,now:corpse.deadAt});
    NPCS.push(corpse);
    if(corpse._deathRecord20)fatalReceipt=Object.freeze({sourceEntity:cop,fatalEntity:corpse,deathRecord:corpse._deathRecord20});`+copSource.slice(corpseEnd);
copSource=copSource.replace(/\n\}$/,'\n  if(fatalReceipt)return fatalReceipt;\n}');
const targetsSource=actual('_localBallisticTargets').replace('hitCityCop(cop, dy, dx, dmg)','hitCityCop(cop, dy, dx, dmg, null, acceptedImpact)');
let rpgSource=actual('_spawnRpgExplosion');
rpgSource=rpgSource.replace('const previousDeathRecord=t.key?._deathRecord20;','const previousDeathRecord=t.key?._deathRecord20,previousNpcCount=NPCS.length;\n    let hitResult;').replace('try{t.hit(dmg,','try{hitResult=t.hit(dmg,');
const originalEnrich="    if(typeof enrichNpcBlastRecord20==='function'){const record=enrichNpcBlastRecord20({entity:t.key,previousRecord:previousDeathRecord,originSource:{r,c}});if(record)t.key._deathRecord20=record;}";
assert(rpgSource.includes(originalEnrich));
rpgSource=rpgSource.replace(originalEnrich,`    const fatalDestination=hitResult?.sourceEntity===t.key&&hitResult.fatalEntity!==t.key&&hitResult.deathRecord===hitResult.fatalEntity?._deathRecord20&&hitResult.deathRecord?.targetId===_threeNpcEntityId(hitResult.fatalEntity)&&hitResult.deathRecord.deathKey===String(hitResult.fatalEntity.deadAt)&&NPCS.indexOf(hitResult.fatalEntity,previousNpcCount)>=0?hitResult.fatalEntity:null;
    if(typeof enrichNpcBlastRecord20==='function'){const entity=fatalDestination||t.key,record=enrichNpcBlastRecord20({entity,previousRecord:fatalDestination?null:previousDeathRecord,originSource:{r,c}});if(record)entity._deathRecord20=record;}`);
function fixture(){const noop=()=>{},c={Math,performance:{now:()=>5000},QP:{uid:'local'},player:{r:50,c:50},myDead:false,myDrivingCarId:null,_LOCAL_PREVIEW:true,
    NPCS:[],CARS:[],cityCops:[],_bankInt:null,_buildingInt:null,beachgoers:new Map(),currentWeapon:'rpg',_threeNpcIds:new WeakMap(),_threeNpcIdSeq:0,_threeNpcDeathTimes:new Map(),
    _walkShotContext:null,_walkShotPhysicalContact:()=>null,_authoritativeShotId:'original',_authoritativeTargetClaims:new Set(),weaponProfile:()=>({dmg:160}),_usesPooled3DFx:()=>true,_explosionSound:noop,_capArr:noop,explosionBursts:[],impacts:[],_MAX_IMPACTS:100,bloodSplats:[],_MAX_BLOOD:100,
    _damageCasinoPropsInRadius:()=>0,_currentShotDamage:x=>x,spawnImpact:noop,_showCurrentShotCritical:noop,_sendWorldWeaponFire:noop,addShake:noop,hapticHit:noop,_markCombatBleeding:noop,_walkConfirmDamage:noop,_cityCopEngagePlayerAfterHit:noop,_onAnyNpcKilledByPlayer:noop,_onMurderArrestCopKilled:noop,_queueMurderOfficerDownBackup:noop,_sendPoliceWitnessOpenFire:noop,
    CITY_COPS_TARGET:5,_cityCopReplacementQueue:0};
  const cop={id:'officer7',kind:'patrol',alive:true,hp:20,x:0,y:1,max_hp:100};c.cityCops.push(cop);
  vm.createContext(c);vm.runInContext(fs.readFileSync(new URL('./npc_death_record20_source.js',import.meta.url),'utf8')+'\n'+fs.readFileSync(new URL('./npc_blast_record20_source.js',import.meta.url),'utf8')+'\n'+['_threeNpcEntityId','_threeNpcDeathState'].map(actual).join('\n')+'\n'+copSource+'\n'+targetsSource+'\n'+rpgSource,c);return {c,cop};}
test('REVIEW CANDIDATE actual cop fatal callback returns source-bound new corpse record with unchanged clock/ID',()=>{
  const {c,cop}=fixture();const receipt=c.hitCityCop(cop,0,1,50,{kind:'npc'},Object.freeze({weapon:'rifle'}));
  assert.equal(cop.alive,false);assert.equal(cop.deadAt,undefined);assert.equal(cop._deathRecord20,undefined);
  const corpse=c.NPCS[0];assert.equal(corpse.id,'officer7_corpse');assert.equal(corpse.deadAt,5000);assert.equal(corpse._deathRecord20.targetId,'npc_officer7_corpse');assert.equal(corpse._deathRecord20.cause,'bullet');
  assert.equal(receipt.sourceEntity,cop);assert.equal(receipt.fatalEntity,corpse);assert.equal(receipt.deathRecord,corpse._deathRecord20);assert(Object.isFrozen(receipt));
  assert.equal(c.hitCityCop(cop,0,1,50),undefined);assert.equal(c.NPCS.length,1);
});
test('REVIEW CANDIDATE actual RPG enriches destination corpse, not retired cop; weapon callback survives slot switch',()=>{
  const {c,cop}=fixture(),targets=c._localBallisticTargets('rpg');c.currentWeapon='pistol';c._localBallisticTargets=()=>targets;c._spawnRpgExplosion(0,0,null,'rpg','rocket');
  const corpse=c.NPCS[0];assert.equal(corpse._deathRecord20.cause,'blast');assert.equal(corpse._deathRecord20.blastPresentation.originSource.r,0);assert.equal(corpse._deathRecord20.blastPresentation.visualSpeed,5);assert.equal(cop._deathRecord20,undefined);assert.equal(c._authoritativeShotId,'original');
});
test('REVIEW CANDIDATE legacy unknown, nonfatal, service despawn and server convoy admission stay unchanged',()=>{
  let f=fixture();f.c.hitCityCop(f.cop,0,1,50,{kind:'npc'});assert.equal(f.c.NPCS[0]._deathRecord20.cause,'unknown');assert.equal(f.c.NPCS[0]._deathRecord20.blastPresentation,undefined);
  f=fixture();assert.equal(f.c.hitCityCop(f.cop,0,1,1,{kind:'npc'},{weapon:'rpg'}),undefined);assert.equal(f.cop.hp,19);assert.equal(f.c.NPCS.length,0);
  f=fixture();f.cop.alive=false;assert.equal(f.c.hitCityCop(f.cop,0,1,999,{kind:'npc'},{weapon:'rpg'}),undefined);assert.equal(f.c.NPCS.length,0);
  f=fixture();f.c._LOCAL_PREVIEW=false;f.cop._serverConvoyCopId='server7';f.c.hitCityCop(f.cop,0,1,999,{kind:'npc'},{weapon:'rpg'});assert.equal(f.cop.hp,20);assert.equal(f.c.NPCS.length,0);
});
test('REVIEW CANDIDATE RPG rejects old destination, foreign source, mismatched record pointer/target, and detached payload',()=>{
  for(const mode of ['old','source','record','target','detached']){
    const {c,cop}=fixture(),corpse={id:'officer7_corpse',dead:true,deadAt:5000,hp:0,r:1,c:0};corpse._deathRecord20=c.createNpcFatalRecord20({entity:corpse,targetId:mode==='target'?'npc_wrong':c._threeNpcEntityId(corpse),weapon:'rpg',now:5000});
    if(mode==='old')c.NPCS.push(corpse);
    c._localBallisticTargets=()=>[{key:cop,r:1,c:0,hit(){if(mode!=='old'&&mode!=='detached')c.NPCS.push(corpse);return {sourceEntity:mode==='source'?{}:cop,fatalEntity:corpse,deathRecord:mode==='record'?{...corpse._deathRecord20}:corpse._deathRecord20};}}];
    c._spawnRpgExplosion(0,0,null,'rpg','rocket');assert.equal(corpse._deathRecord20.blastPresentation,undefined,mode);
  }
});
