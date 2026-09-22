import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {normalizeNpcLifecycle} from './npc_source_lifecycle.mjs';
import {normalizeNpcDeathProfile} from './npc_death_profile20.mjs';
const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
const helper=fs.readFileSync(new URL('./npc_death_record20_source.js',import.meta.url),'utf8');
function actual(name){const a=source.indexOf('function '+name+'(');assert(a>=0,name);return source.slice(a,source.indexOf('\n}',a)+2);}
function fixture(){const noop=()=>{},c={performance:{now:()=>5000},Math,currentWeapon:'pistol',_threeNpcIds:new WeakMap(),_threeNpcIdSeq:0,_threeNpcDeathTimes:new Map(),_walkShotContext:null,_walkShotPhysicalContact:()=>null,
  _bankInt:null,_buildingInt:null,_majorInteriorObjectId:null,_authoritativeShotId:'',NPCS:[],CARS:[],cityCops:[],beachgoers:new Map(),_beachShopQueue:[],_beachShopRetargetQueue:noop,_beachgoerWorldPos:n=>({r:n.r,c:n.c}),_interiorNpcHitRadius:()=>.4,
  _walkConfirmDamage:noop,_markCombatBleeding:noop,_capArr:noop,bloodSplats:[],_MAX_BLOOD:100,impacts:[],_MAX_IMPACTS:100,spawnFloatText:noop,showToast:noop,_registerMurderIncident:noop,QP:{uid:'u'}};
  vm.createContext(c);vm.runInContext(helper+'\n'+['_threeNpcEntityId','_threeNpcDeathState','_hitBankGuard','_hitBeachgoer','_hitInteriorNpc','_localBallisticTargets'].map(actual).join('\n'),c);return c;}
function row(c,n,kind){const view=kind==='beach'?{...n,id:`beach_${n.id}`}:n,id=c._threeNpcEntityId(view),death=c._threeNpcDeathState(view,id,5100),record=c.projectNpcFatalRecord20(view,id,death);return {id,death,record};}
test('actual bank/beach/interior ballistic callback retains fired weapon after equip changes; exact bridge profile matches',()=>{
  for(const kind of ['bank','beach','interior'])for(const [weapon,cause]of [['rpg','blast'],['rifle','bullet']]){
    const c=fixture(),n={id:'npc7',hp:10,r:4,c:5,maxHp:10};
    if(kind==='bank')c._bankInt={npcs:[n]};else if(kind==='beach')c.beachgoers.set(n.id,n);else c._buildingInt={type:'shop',W:20,H:20,npcs:[n]};
    const targets=c._localBallisticTargets(weapon);assert.equal(targets.length,1);c.currentWeapon='taser';targets[0].hit(20,.6,.8);
    assert.equal(n.hp,0);assert.equal(n.dead,true);const p=row(c,n,kind);assert(p.record);assert.equal(p.record.cause,cause);assert.equal(p.record.travelWorld.x,.8);assert.equal(p.record.travelWorld.z,.6);
    assert.equal(normalizeNpcDeathProfile({targetId:p.id,lifecycle:normalizeNpcLifecycle(p.death,{sourceNowMs:5100}),record:p.record}).cause,cause);
    assert.equal(c.projectNpcFatalRecord20(n,'wrong',p.death),null);assert.equal(c.projectNpcFatalRecord20(n,p.id,{...p.death,deadAt:5001}),null);
    const saved=p.record;targets[0].hit(20,1,0);assert.equal(n._deathRecord20,saved,'dead target cannot get a new event');
  }
});
test('legacy missing impact stays unknown instead of currentWeapon; nonfatal damage never produces record',()=>{
  for(const kind of ['bank','beach','interior']){
    const c=fixture(),n={id:'7',hp:100,r:4,c:5,maxHp:100};c._buildingInt={type:'shop',W:20,H:20,npcs:[n]};c.currentWeapon='rpg';
    const call=(damage)=>kind==='bank'?c._hitBankGuard(n,0,1,damage):kind==='beach'?c._hitBeachgoer(n,0,1,damage):c._hitInteriorNpc(n,0,1,damage);
    call(1);assert.equal(n.hp,99);assert.equal(n._deathRecord20,undefined);call(100);assert.equal(n._deathRecord20.cause,'unknown');
  }
});
test('local interior protections and server-owned branches do not produce local fatal record',()=>{
  for(const marker of ['_keyNpc','_invulnerable','majorGuard']){
    const c=fixture(),n={id:'7',hp:100,maxHp:100,r:4,c:5,_protectedHintAt:6000,[marker]:true};c._buildingInt={type:'shop',W:20,H:20,npcs:[n]};
    if(marker==='majorGuard'){c._majorInteriorObjectId='casino';c._reserveAuthoritativeTargetClaim=()=>false;}
    c._hitInteriorNpc(n,0,1,999,'grenade');assert.equal(n.hp,100);assert.notEqual(n.dead,true);assert.equal(n._deathRecord20,undefined);
  }
});
test('gas station actual function completes once without interior bi',()=>{
  const noop=()=>{};let saved=0,panic=0;const c={performance:{now:()=>5000},Math,GAS_REPAIR_MS:1000,_gasStationState:()=> 'leaking',_gasPumpPoints:()=>[{r:0,c:0}],_gasBlastDamageAt:()=>0,
    spawnWorldC4Explosion:noop,spawnShockwave:noop,addShake:noop,hapticHit:noop,fireScreenFlash:noop,showEventBanner:noop,pushFeedEvent:noop,player:{r:50,c:50},NPCS:[],cityCops:[],_myGang:[],CARS:[],_saveGang:()=>saved++,triggerNpcPanic:()=>panic++};
  vm.createContext(c);vm.runInContext(actual('_explodeGasStation'),c);const gs={r:0,c:0};
  assert.doesNotThrow(()=>c._explodeGasStation(gs));
  assert.equal(gs._blastApplied,true);assert.equal(gs._damageState,'burning');assert.equal(saved,1);assert.equal(panic,1);
  assert.doesNotThrow(()=>c._explodeGasStation(gs));assert.equal(saved,1,'completed tail is not repeated');assert.equal(panic,1);
});
