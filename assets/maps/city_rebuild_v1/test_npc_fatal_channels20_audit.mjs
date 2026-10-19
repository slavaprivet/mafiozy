// Read-only production audit. Proposed record attachment occurs in this test
// only, after actual source final-death functions; no live integration claimed.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {normalizeNpcLifecycle} from './npc_source_lifecycle.mjs';
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
const helper=fs.readFileSync(new URL('./npc_death_record20_source.js',import.meta.url),'utf8');
function actual(name){const a=world.indexOf('function '+name+'(');assert(a>=0,name);return world.slice(a,world.indexOf('\n}',a)+2);}
function fixture(){
  const noop=()=>{},c={performance:{now:()=>5000},Math,QP:{uid:'user'},_threeNpcIds:new WeakMap(),_threeNpcIdSeq:0,_threeNpcDeathTimes:new Map(),NPCS:[],cityCops:[],bloodSplats:[],impacts:[],_MAX_BLOOD:100,_MAX_IMPACTS:100,currentWeapon:'pistol',_capArr:noop,_walkConfirmDamage:noop,_markCombatBleeding:noop,spawnFloatText:noop,_registerMurderIncident:noop,
    _onAnyNpcKilledByPlayer:noop,_onMurderArrestCopKilled:noop,_queueMurderOfficerDownBackup:noop,_sendPoliceWitnessOpenFire:noop,
    _clearNpcRoute:noop,_empireLessonFor:()=>({casualties:0}),_empireLeaderIdOf:()=> 'leila',_empireSpeak:noop,
    _beachgoerWorldPos:b=>({r:b.r,c:b.c}),_beachShopQueue:[],_beachShopRetargetQueue:noop,
    _botLastSeen:new Map(),aggroZones:{},spawnImpact:noop,_AGGRO_BOSS_LOOK:{},_AGGRO_GRUNT_LOOK:{},
    _buildingInt:{type:'shop',W:20,H:20,npcs:[]},_majorInteriorObjectId:null,_authoritativeShotId:'shot',
    _checkpointBusinessInteriorRaidCasualties:noop,document:{documentElement:{dataset:{}}}};
  vm.createContext(c);vm.runInContext(helper+'\n'+['_threeNpcEntityId','_threeNpcDeathState','hitCityCop','_killDecorNpc','_hitBankGuard','_hitBeachgoer','_downEmpireCombatant','spawnBotCorpse','_hitInteriorNpc','_damageBusinessRaidNpc'].map(actual).join('\n'),c);return c;
}
function proposedBlast(c,n,id=c._threeNpcEntityId(n)){
  // Explicit fixture-supplied accepted blast event; never inferred from old hits.
  const record=c.createNpcFatalRecord20({entity:n,targetId:id,weapon:'grenade',dirR:3,dirC:4,now:n.deadAt});
  const projected={...n,_deathRecord20:record},death=c._threeNpcDeathState(n,id,5000);
  return {record,projection:c.projectNpcFatalRecord20(projected,id,death),death};
}
test('actual city cop death creates a different corpse identity: bind destination, not retired cop',()=>{
  const c=fixture(),cop={id:'c7',alive:true,hp:10,x:2,y:3};c.hitCityCop(cop,0,1,20,{kind:'npc'});
  assert.equal(cop.alive,false);const corpse=c.NPCS[0];assert.equal(corpse.dead,true);assert.equal(corpse.deadAt,5000);
  assert.equal(c._threeNpcEntityId({...cop,id:'city_cop_'+cop.id}),'npc_city_cop_c7');assert.equal(c._threeNpcEntityId(corpse),'npc_c7_corpse');
  assert.equal(c.createNpcFatalRecord20({entity:cop,targetId:'npc_city_cop_c7',weapon:'grenade',now:5000}),null,'alive=false alone is not accepted as definitive producer');
  const p=proposedBlast(c,corpse);assert.equal(p.record,p.projection);assert.equal(p.record.cause,'blast');
  assert.equal(c.projectNpcFatalRecord20({...corpse,_deathRecord20:p.record},'npc_city_cop_c7',p.death),null);
});
test('actual decor death replaces bus/parking actor with fresh anonymous corpse; weak identity is stable there',()=>{
  const c=fixture(),person={id:'bus7',r:3,c:4},arr=[person];c._killDecorNpc(person,arr,0,1);
  assert.equal(arr.length,0);const corpse=c.NPCS[0],id=c._threeNpcEntityId(corpse);assert.match(id,/^local_npc_/);assert.equal(c._threeNpcEntityId(corpse),id);
  const p=proposedBlast(c,corpse,id);assert.equal(p.projection,p.record);assert.equal(c.projectNpcFatalRecord20({...corpse,_deathRecord20:p.record},'npc_bus_waiter_0',p.death),null);
});
test('actual bank, beach, empire boss/crew/guard and interior final transitions can bind explicit event after death',()=>{
  for(const kind of ['bank','beach','boss','crew','holding_guard','interior']){
    const c=fixture(),n={id:kind,hp:10,r:3,c:4};
    if(kind==='bank')c._hitBankGuard(n,0,1,20);
    else if(kind==='beach')c._hitBeachgoer(n,0,1,20);
    else if(kind==='interior')c._hitInteriorNpc(n,0,1,20,'grenade');
    else {n[kind==='boss'?'_empireBoss':kind==='crew'?'_empireCrew':'_empireHoldingGuard']=true;c._downEmpireCombatant(n,5000);}
    assert.equal(n.dead,true,kind);assert.equal(n.deadAt,5000,kind);
    if(kind==='bank'||kind==='beach')assert.equal(n._deathRecord20.cause,'unknown','legacy signature has no accepted weapon');
    else if(kind==='interior')assert.equal(n._deathRecord20.cause,'blast','explicit local weapon now has producer');
    else assert.equal(n._deathRecord20,undefined,'empire producer is not wired');
    const id=kind==='beach'?'npc_beach_beach':c._threeNpcEntityId(n),p=proposedBlast(c,n,id);
    assert.equal(p.projection,p.record);assert.equal(p.record.travelWorld.x,n._deathRecord20?1:.8);assert.equal(p.record.travelWorld.z,n._deathRecord20?0:.6);
  }
});
test('actual protected interior NPC remains alive; pressure/immortality must not become blast death',()=>{
  const c=fixture(),n={id:'quest',r:1,c:2,hp:20,maxHp:100,_keyNpc:true,_protectedHintAt:6000};c._hitInteriorNpc(n,0,1,999,'grenade');
  assert.equal(n.dead,false);assert.equal(n.hp,100);assert.equal(proposedBlast(c,n).record,null);
});
test('actual raid casualty marks exact roster row; restored hp0 without transition cannot supply fatal cause',()=>{
  const c=fixture(),n={id:'raid7',hp:5,r:2,c:4,raidRosterGroup:'a',raidRosterId:'r7',businessRaidSide:'attacker'},row={rosterGroup:'a',id:'r7'},state={attackerRoster:[row],guardRoster:[],defenderRoster:[]};
  c._damageBusinessRaidNpc(c._buildingInt,state,n,20,'player');assert.equal(row.casualty,true);assert.equal(n.dead,true);assert.equal(proposedBlast(c,n).record.cause,'blast');
  assert.equal(c.createNpcFatalRecord20({entity:{hp:0},targetId:'npc_raid7',weapon:'grenade',now:5000}),null);
});
test('actual aggro corpse fallback is marked evacuated and requires separate render-admission decision',()=>{
  const c=fixture();c.aggroZones.z={bots:[{id:'g7',x:2,y:3,hp:0,alive:false}]};c.spawnBotCorpse('g7',false);
  const corpse=c.NPCS[0];assert.equal(corpse.dead,true);assert.equal(corpse._evacuated,true);assert.equal(corpse._deathRecord20,undefined);
  c.spawnBotCorpse('g7',false);assert.equal(c.NPCS.length,1,'existing duplicate gate');
  const p=proposedBlast(c,corpse);assert.equal(p.record,p.projection);
  assert(world.includes('||x._evacuated||x._carriedByAmbulance||!prisonNpcAllowed(x))continue;'),'actual render admission removes this corpse despite valid record');
});
test('medical/mercenary downed and alive=false service removal are not newly confirmed fatal events',()=>{
  const c=fixture();for(const n of [{hp:0,_medicalDowned:true},{hp:0,downed:true},{hp:0,lifeState:'downed'},{alive:false,hp:100}]){
    assert.equal(c.createNpcFatalRecord20({entity:n,targetId:'npc_7',weapon:'grenade',now:5000}),null);
  }
  const merc=fs.readFileSync(new URL('./mercenary_world.js',import.meta.url),'utf8'),start=merc.indexOf(' function getMember('),end=merc.indexOf('\n',start),c2={raw:()=>({id:'m7',hp:0,r:2,c:3}),record:()=>({status:'downed'}),squadPosture:()=> 'stand',qaSupported:()=>false,toWorld:()=>({x:1,z:2}),rescueContact:()=>({}),player:{r:0,c:0},scale:()=>4.1};
  vm.runInNewContext(merc.slice(start,end)+'\nthis.row=getMember("m7");',c2);
  assert.equal(c2.row.dead,false);assert.equal(c2.row.downed,true);assert.equal(normalizeNpcLifecycle(c2.row).dead,false);
});
