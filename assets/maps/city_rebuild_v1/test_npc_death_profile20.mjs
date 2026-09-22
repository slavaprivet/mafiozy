import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {normalizeNpcLifecycle} from './npc_source_lifecycle.mjs';
import {normalizeNpcDeathProfile} from './npc_death_profile20.mjs';

const base = {targetId:'npc_existing_7', lifecycle:{dead:true,key:'5000'}, yaw:Math.PI/2};
const record = {version:1, confirmed:true, fatal:true, targetId:base.targetId, eventId:'shot-7', deathKey:'5000', cause:'bullet'};
test('explicit fatal record preserves causes and exact death epoch without mutation', () => {
  for (const cause of ['bullet','melee','super','kick','dropkick','blast','fire','vehicle','bleedout']) {
    const input = {...base,record:{...record,cause}}, before=JSON.stringify(input), result=normalizeNpcDeathProfile(input);
    assert.equal(result.known,true); assert.equal(result.cause,cause); assert.equal(result.directionWorld,null);
    assert.equal(JSON.stringify(input),before); assert(Object.isFrozen(result));
  }
});
test('HP, old hit fields, generic epoch, wrong actor/event and new lifetime cannot choose a cause', () => {
  for (const input of [
    {...base,record:null}, {...base,lifecycle:{dead:false,key:'5000'},record},
    {...base,lifecycle:{dead:true,key:'dead'},record}, {...base,lifecycle:{dead:true,key:'6000'},record},
    {...base,targetId:'other',record}, ...[{eventId:''},{confirmed:false},{fatal:false},{deathKey:'4999'},{cause:'rpg'},{version:2}].map(change=>({...base,record:{...record,...change}})),
    {...base,record:{hitWeapon:'rpg',hitAt:5000,hp:0,dead:true}},
  ]) assert.equal(normalizeNpcDeathProfile(input).known,false,JSON.stringify(input));
});
test('world travel direction has explicit inverse-yaw local transform; contact stays in metres', () => {
  const input={...base,record:{...record,travelWorld:{x:4.1,y:0,z:0},pointWorldMeters:{x:41,y:1.2,z:82}}};
  const p=normalizeNpcDeathProfile(input);
  assert.deepEqual(p.directionWorld,{x:1,y:0,z:0}); assert(Math.abs(p.directionLocal.x)<1e-12); assert.equal(p.directionLocal.z,1);
  assert.deepEqual(p.pointWorldMeters,{x:41,y:1.2,z:82}); assert(Object.isFrozen(p.directionWorld));
  input.record.travelWorld.x=0; assert.equal(p.directionWorld.x,1);
  assert.equal(normalizeNpcDeathProfile({...base,record:{...record,travelWorld:{x:0,y:0,z:0}}}).known,false);
  assert.equal(normalizeNpcDeathProfile({...base,record:{...record,pointWorldMeters:{x:0,y:NaN,z:0}}}).known,false);
  assert.equal(normalizeNpcDeathProfile({...base,yaw:undefined,record:{...record,travelWorld:{x:0,y:1,z:0}}}).directionLocal,null);
});

const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
function between(start,end){const a=source.indexOf(start), b=source.indexOf(end,a);assert(a>=0&&b>a);return source.slice(a,b);}
test('actual world death classification and lifecycle keep legacy causes unknown, including downed survival', () => {
  const c={_threeNpcDeathTimes:new Map()};
  vm.runInNewContext(between('function _threeNpcDeathState(','function _threeNpcPoliceObservation(')+'\nthis.classify=_threeNpcDeathState;',c);
  for (const weapon of ['pistol','fists','rpg','grenade','vehicle','burn_tick']) {
    const raw={hp:0,dead:true,deadAt:5000,_threeHitWeapon:weapon,_threeHitAngle:.7,_threeHitPower:1.2};
    const projected=c.classify(raw,base.targetId,5100), lifecycle=normalizeNpcLifecycle({...raw,...projected},{sourceNowMs:5100});
    assert.equal(lifecycle.dead,true); assert.equal(lifecycle.key,'5000');
    assert.equal(normalizeNpcDeathProfile({...base,lifecycle,record:raw}).cause,'unknown');
  }
  const down={hp:1,dead:false,_medicalDowned:true};
  assert.equal(normalizeNpcLifecycle(c.classify(down,base.targetId,5100),{sourceNowMs:5100}).dead,false);
});
test('actual accepted hit receipt does not prove final death: zero HP before source downed decision', () => {
  const events=[], ref={hp:0,dead:false}, ctx={ref,at:5000,shotId:'shot-7',npcId:base.targetId,contact:{point:{x:1,y:1,z:2},normal:{x:-1,y:0,z:0},zone:'torso'}};
  const c={performance:{now:()=>5000},_walkShotContext:ctx,_walkMeleeDamageContext:null,_walkPendingShots:new Map(),window:{dispatchEvent:event=>events.push(event.detail)},CustomEvent:class{constructor(type,options){Object.assign(this,options);}}};
  vm.runInNewContext(between('function _walkConfirmDamage(','function _walkConfirmServerHit(')+'\nthis.confirm=_walkConfirmDamage;',c);
  for (const attackType of [null,'punch','heavy','kick','dropkick']) {
    ctx.confirmed=false; ctx.melee=attackType!==null; ctx.animation=attackType?{type:attackType,heavy:attackType==='heavy'}:null;
    assert.equal(c.confirm(ref,100),true); const receipt=events.at(-1);
    assert.equal(receipt.fatal,false); assert.equal(receipt.attackType,attackType??undefined);
    assert.equal(normalizeNpcDeathProfile({...base,record:receipt}).known,false);
  }
  ctx.confirmed=false; assert.equal(c.confirm(ref,100,'',true),true);
  assert.equal(events.at(-1).fatal,true);
  assert.equal(normalizeNpcDeathProfile({...base,record:events.at(-1)}).known,false,'even fatal ACK needs exact source death epoch binding');
});
