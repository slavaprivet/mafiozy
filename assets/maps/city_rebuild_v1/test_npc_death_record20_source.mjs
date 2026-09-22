import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {normalizeNpcLifecycle} from './npc_source_lifecycle.mjs';
import {normalizeNpcDeathProfile} from './npc_death_profile20.mjs';
const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
const helper=fs.readFileSync(new URL('./npc_death_record20_source.js',import.meta.url),'utf8');
function actual(name){const start=source.indexOf('function '+name+'(');assert(start>=0,name);return source.slice(start,source.indexOf('\n}',start)+2);}
function fixture({random=.99}={}){
  let now=5000,fresh=null,atReplacement=null,damageEvents=[];
  const noop=()=>{}, ctx={performance:{now:()=>now},Math:Object.create(Math),QP:{uid:'local'},player:{r:1,c:1},NPC_ARCHETYPES:{worker:{}},_residentRespawnSeed:10,RESIDENT_RESPAWN_BACKLOG:[],
    _threeNpcIds:new WeakMap(),_threeNpcIdSeq:0,_threeNpcDeathTimes:new Map(),_walkShotContext:null,_walkMeleeDamageContext:null,_walkPendingShots:new Map(),
    window:{dispatchEvent:event=>damageEvents.push(event.detail)},CustomEvent:class{constructor(type,options){Object.assign(this,options);}},
    _markCombatBleeding:noop,_npcPathPassable:()=>true,_npcRememberAggression:noop,_npcSpreadRumor:noop,npcCivilianUnarmed:()=>false,_npcTrySurrenderAfterHit:()=>false,_npcTriggerFight:noop,
    _registerMurderIncident:(entity)=>{atReplacement=entity._deathRecord20;},_isRespawnableResident:()=>true,_pickResidentRespawnDoor:()=>({r:2,c:3}),
    spawnNpc:()=>fresh={hp:100,dead:false,_arcKey:'worker'},_residentEnterBuilding:()=>true,
    _capArr:noop,bloodSplats:[],_MAX_BLOOD:100,impacts:[],_MAX_IMPACTS:100,spawnFloatText:noop,_igniteLocalCharacter:noop};
  ctx.Math.random=()=>random;
  vm.createContext(ctx);
  vm.runInContext(helper+'\n'+['_threeNpcEntityId','_threeNpcDeathState','_walkConfirmDamage','_scheduleResidentRespawn','_respawnResidentImmediately','hitNpc'].map(actual).join('\n'),ctx);
  const npc={id:'existing',hp:20,r:4,c:7,_arcKey:'worker'};
  return {ctx,npc,setNow:value=>now=value,get fresh(){return fresh;},get beforeReplacement(){return atReplacement;},damageEvents,
    hit:(weapon='pistol',damage=30,dirR=0,dirC=1)=>ctx.hitNpc(npc,dirR,dirC,weapon,damage,{kind:'npc'}),
    projection:()=>{const id=ctx._threeNpcEntityId(npc),death=ctx._threeNpcDeathState(npc,id,now);return {id,death,record:ctx.projectNpcFatalRecord20(npc,id,death)};}};
}
test('actual hitNpc survival never creates fatal record, final death attaches before actual fresh-resident replacement',()=>{
  const survival=fixture({random:.1});survival.hit();assert.equal(survival.npc.hp,1);assert.equal(survival.npc._medicalDowned,true);assert.equal(survival.npc.dead,undefined);assert.equal(survival.npc._deathRecord20,undefined);assert.equal(survival.fresh,null);
  const f=fixture();f.hit();const {npc}=f;assert.equal(npc.dead,true);assert.equal(npc._deathRecord20.cause,'bullet');assert.equal(npc._deathRecord20,f.beforeReplacement);
  assert.notEqual(f.fresh,npc);assert.equal(f.fresh.dead,false);assert.equal(f.fresh._deathRecord20,undefined);assert.equal(npc._residentReplacementScheduled,true);
  const p=f.projection();assert.equal(p.record,npc._deathRecord20);assert.equal(f.projection().record,p.record);
  assert.equal(normalizeNpcDeathProfile({targetId:p.id,lifecycle:normalizeNpcLifecycle(p.death,{sourceNowMs:5100}),record:p.record}).cause,'bullet');
  assert.equal(f.ctx.projectNpcFatalRecord20(f.fresh,f.ctx._threeNpcEntityId(f.fresh),{dead:false}),null);
});
test('actual hitNpc current accepted weapon selects bullet, fists, blast, fire and unknown; zero blast direction remains unknown',()=>{
  for(const [weapon,cause]of [['ak74','bullet'],['fists','melee'],['rpg','blast'],['grenade','blast'],['burn_tick','fire'],['vehicle','vehicle'],['new_unregistered_weapon','unknown']]){
    const f=fixture();f.npc._threeHitWeapon='pistol';f.hit(weapon,30,0,0);
    assert.equal(f.npc._deathRecord20.cause,cause,weapon);assert.equal(f.npc._deathRecord20.travelWorld,null);
  }
});
test('actual accepted melee receipt gives super/kick/dropkick only in its matching active local context',()=>{
  for(const [type,cause]of [['punch','melee'],['heavy','super'],['kick','kick'],['dropkick','dropkick']]){
    const f=fixture(),ctx={ref:f.npc,npcId:'npc_existing',at:4900,window:[30,360],melee:true,animation:{type,heavy:type==='heavy'},airborne:type==='dropkick',contact:{point:{x:10,y:1.3,z:20},normal:{x:-1,y:0,z:0}},shotId:'attack1'};
    f.ctx._walkMeleeDamageContext=ctx;f.hit('fists');
    assert.equal(f.damageEvents[0].fatal,false,'accepted damage still precedes final fatal decision');
    assert.equal(f.npc._deathRecord20.cause,cause);assert.equal(f.npc._deathRecord20.pointWorldMeters.x,10);
    assert(Object.isFrozen(f.npc._deathRecord20));assert(Object.isFrozen(f.npc._deathRecord20.travelWorld));
    ctx.contact.point.x=90;assert.equal(f.npc._deathRecord20.pointWorldMeters.x,10);assert.equal(ctx.at,4900);
  }
});
test('stale/future/wrong-target/server melee context never promotes generic fists or borrows contact',()=>{
  for(const change of [{at:3000},{at:5001},{npcId:'other'},{ref:{}},{serverMelee:true},{melee:false},{window:null}]){
    const f=fixture();f.ctx._walkMeleeDamageContext={ref:f.npc,npcId:'npc_existing',at:4900,window:[30,360],melee:true,animation:{type:'heavy',heavy:true},contact:{point:{x:1,y:2,z:3},normal:{x:0,y:0,z:1}},...change};
    f.hit('fists');assert.equal(f.npc._deathRecord20.cause,'melee',JSON.stringify(change));assert.equal(f.npc._deathRecord20.pointWorldMeters,null);
  }
});
test('source projection rejects old epoch, revived state and identity-changing corpse clone; repeated accepted record is stable',()=>{
  const f=fixture();f.hit();const {id,death,record}=f.projection();
  assert.equal(f.ctx.projectNpcFatalRecord20({...f.npc},id,death),record,'same-identity presentation clone keeps epoch');
  assert.equal(f.ctx.projectNpcFatalRecord20({...f.npc,id:'another'},'npc_another',death),null);
  assert.equal(f.ctx.projectNpcFatalRecord20(f.npc,id,{...death,deadAt:5001}),null);
  assert.equal(f.ctx.projectNpcFatalRecord20(f.npc,id,{...death,deathConfirmed:false}),null);
  assert.equal(f.ctx.projectNpcFatalRecord20(f.npc,id,{dead:false,deathConfirmed:false}),null);
  assert.equal(f.ctx.createNpcFatalRecord20({entity:f.npc,targetId:id,now:5000,weapon:'grenade'}),record);
  assert.equal(f.ctx.createNpcFatalRecord20({entity:f.npc,targetId:id,now:5001,weapon:'grenade'}),null);
  // Legacy same-object revival is isolated by the next death epoch, too.
  f.npc.dead=false;f.npc.hp=10;f.setNow(6000);f.hit('grenade');assert.notEqual(f.npc._deathRecord20,record);assert.equal(f.npc._deathRecord20.deathKey,'6000');
});
test('world loads source helper, exports guarded street record, and all inline scripts remain valid',()=>{
  assert(source.includes('<script src="assets/maps/city_rebuild_v1/npc_death_record20_source.js"></script>'));
  const expression=source.match(/deathRecord:(typeof projectNpcFatalRecord20[^\n]+),/);assert(expression);
  const f=fixture();f.hit();const {id,death,record}=f.projection();f.ctx.x=f.npc;f.ctx.id=id;f.ctx.death=death;
  assert.equal(vm.runInContext(expression[1],f.ctx),record,'actual street snapshot expression');
  for(const script of source.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi))if(!/type=['"](?:module|importmap|application\/json)/.test(script[1])&&script[2].trim())new vm.Script(script[2]);
});
