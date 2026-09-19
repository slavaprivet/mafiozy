import assert from 'node:assert/strict';
import {createMercenarySquad,MERCENARY_PROFESSIONS} from './mercenary_core.mjs';

function harness(extra={}){
  let time=1000;const live=new Map(),effects=[],moves=[],poses=[];
  const squad=createMercenarySquad({now:()=>time,getMember:id=>live.get(id),getTarget:id=>live.get(id),
    moveMember:(...a)=>moves.push(a),onAction:(...a)=>poses.push(a),
    performEffect:e=>{effects.push(e);return true;},...extra});
  const entity=(id,kind='npc',x=0)=>{const e={id,kind,position:{x,y:0,z:0},hp:100,maxHp:100,valid:true};live.set(id,e);return e;};
  const recruit=(profession,id=profession)=>{entity(id);assert(squad.recruit({id,profession}).ok);return live.get(id);};
  return {squad,live,effects,moves,poses,entity,recruit,tick:(dt=0)=>{time+=dt;squad.update();},time:()=>time};
}

for(const [profession,kind,targetKind] of [['medic','revive','player'],['bruiser','intimidate','npc'],['safecracker','unlock_safe','safe'],['safecracker','unlock_door','door'],['engineer','cut_fence','fence']]){
  const h=harness();h.recruit(profession);const t=h.entity('target',targetKind);t.locked=true;if(kind==='revive'){t.hp=0;t.downed=true;}
  assert(h.squad.command(profession,kind,'target').ok);h.tick();assert.equal(h.squad.getAction(profession).phase,'working');h.tick(10);h.tick();
  assert.equal(h.effects.filter(e=>e.kind===kind).length,1,kind);assert.equal(h.squad.getRoster()[0].xp,25);
  assert.equal(t.hp,kind==='revive'?0:100,'Core must not author HP');
}
{
  const h=harness();h.recruit('safecracker');const car=h.entity('parked:42','vehicle');car.locked=true;
  assert(h.squad.command('safecracker','unlock_door',car.id).ok);h.tick();
  assert.equal(h.squad.getAction('safecracker').kind,'unlock_door');
  h.tick(4.9);assert.equal(h.effects.length,0);h.tick(.1);
  assert.equal(h.effects.length,1);assert.equal(h.effects[0].targetId,car.id);
  h.tick(2);assert.equal(h.effects.length,1);assert.equal(car.locked,true,'Core awaits authoritative lock mutation');
}
for(const flags of [{locked:false},{locked:true,lockpickable:false}]){
  const h=harness();h.recruit('safecracker');const car=Object.assign(h.entity('car','vehicle'),flags);
  assert.equal(h.squad.command('safecracker','unlock_door',car.id).ok,false);assert.equal(h.effects.length,0);
}
{
  const h=harness();h.recruit('safecracker');const car=h.entity('car','vehicle');car.locked=true;
  assert(h.squad.command('safecracker','unlock_door',car.id).ok);h.tick();car.lockpickable=false;h.tick(5);
  assert.equal(h.squad.getAction('safecracker'),null);assert.equal(h.effects.length,0);
}
{
  const h=harness();const m=h.recruit('safecracker');h.entity('target','safe',20).locked=true;
  assert(h.squad.command('safecracker','unlock_safe','target').ok);h.tick();assert.equal(m.position.x,0,'No teleport');
  assert.equal(h.moves.at(-1)[1].id,'target');h.tick(11);assert.equal(h.squad.getAction('safecracker'),null);assert.equal(h.effects.length,0);
}
{
  const h=harness();const m=h.recruit('engineer');const t=h.entity('target','fence');
  h.squad.command('engineer','cut_fence','target');h.tick();h.tick(3);t.position.x=20;h.tick();
  assert.equal(h.squad.getAction('engineer').phase,'approach');m.position.x=20;h.tick();h.tick(3);assert.equal(h.effects.length,0,'Work resets out of range');
  t.valid=false;h.tick(10);assert.equal(h.effects.length,0);
}
{
  const h=harness();const m=h.recruit('demolitions');const t=h.entity('car','vehicle');
  h.squad.command('demolitions','plant_bomb','car');h.tick();h.tick(4);
  assert.equal(h.effects.length,0,'Planting is not detonation');assert.equal(h.squad.cancel('demolitions').reason,'bomb_armed');
  t.position.x=20;h.tick(2);assert.equal(h.effects.length,0);m.hp=0;m.dead=true;h.tick(4);h.tick(10);
  const explosions=h.effects.filter(e=>e.kind==='plant_bomb');assert.equal(explosions.length,1);assert.equal(explosions[0].target.position.x,20);
}
{
  const h=harness();h.recruit('demolitions');h.entity('car','vehicle');h.squad.setWeapon('demolitions',{id:'pistol',ammo:9});
  h.squad.command('demolitions','plant_bomb','car');h.tick();h.tick(4);
  const dismissed=h.squad.dismiss('demolitions');assert(dismissed.ok);assert.equal(dismissed.member.weapon.ammo,9);assert.equal(h.squad.getRoster().length,0);
  h.tick(6);h.tick(6);assert.equal(h.effects.length,1,'Dismissal preserves armed fuse');
}
{
  let h;h=harness({scanReviveTargets:()=>[{id:'player'}]});h.recruit('medic');const t=h.entity('player','player');t.hp=0;t.downed=true;
  h.tick();assert.equal(h.squad.getAction('medic').targetId,'player');h.tick();h.tick(4);assert.equal(h.effects.length,1);h.tick();assert.equal(h.squad.getAction('medic'),null,'Cooldown prevents revive spam');
}
{
  const h=harness();const m=h.recruit('bruiser');assert.equal(h.squad.stats('bruiser').hpMultiplier,1.65);
  h.squad.addXP('bruiser',210);assert(h.squad.upgrade('bruiser','melee').ok);h.squad.setWeapon('bruiser',{id:'shotgun',ammo:8});
  m.hp=0;m.downed=true;h.tick();assert.equal(h.squad.getRoster()[0].status,'downed');h.tick(19);assert.equal(h.effects.length,0);
  h.tick(1);assert.equal(h.squad.getRoster()[0].hospitalUntil,1320);assert.equal(h.effects[0].kind,'hospitalize');h.tick(3);assert.equal(h.effects.length,1);
  const saved=h.squad.snapshot();saved.members[0].hp=9999;
  const j=harness();j.entity('bruiser').hp=0;assert(j.squad.restore(saved).ok);assert.equal(j.live.get('bruiser').hp,0);assert.equal(j.squad.getRoster()[0].weapon.ammo,8);
  assert.equal(j.squad.getRoster()[0].hospitalUntil,1320,'Reload preserves absolute deadline');j.tick(319);assert.equal(j.effects.length,0);j.tick(1);
  assert.equal(j.effects[0].kind,'discharge');assert.equal(j.squad.getRoster()[0].status,'returning');assert.equal(j.squad.stats('bruiser').skillLevel.melee,1);
}
{
  const h=harness();const m=h.recruit('bruiser');m.dead=true;m.hp=0;h.tick();h.squad.dismiss('bruiser');h.tick(400);assert.equal(h.effects.length,1,'Dismissed hospital member never returns');
}
{
  const h=harness({performEffect:()=>false});h.recruit('demolitions');h.entity('car','vehicle');h.squad.command('demolitions','plant_bomb','car');h.tick();h.tick(4);h.live.get('demolitions').position.x=10;h.tick(6);
  assert.equal(h.squad.getRoster()[0].xp,0);assert.equal(h.poses.at(-1)[1].phase,'cancelled','Rejected effect is not completed');
}
for(const rejected of [undefined,{ok:false}]){
  const h=harness({performEffect:()=>rejected});h.recruit('safecracker');h.entity('safe','safe').locked=true;h.squad.command('safecracker','unlock_safe','safe');h.tick();h.tick(10);
  assert.equal(h.squad.getRoster()[0].xp,0,'Only explicit synchronous success is accepted');
}
{
  const h=harness();for(const profession of Object.keys(MERCENARY_PROFESSIONS))h.recruit(profession);
  assert.equal(h.squad.recruit({id:'six',profession:'medic'}).reason,'squad_full');
  assert.equal(h.squad.command('medic','plant_bomb','car').reason,'wrong_profession');
  const s=h.squad.snapshot();s.members[0].skills.medicine=99;s.members[0].skillPoints=99;h.squad.restore(s);assert.equal(h.squad.getRoster()[0].skills.medicine,0);
}
console.log('mercenary core: all professions, approach/cancel, moving bomb/once, medic, progression, hospital save/return, dismissal PASS');
{
  const h=harness();h.recruit('demolitions');h.entity('car','vehicle');h.squad.command('demolitions','plant_bomb','car');h.tick();h.tick(4);h.tick(2);
  const original=h.squad.getAction('demolitions');h.squad.dismiss('demolitions');const save=h.squad.snapshot();
  assert.equal(save.charges.length,1);assert.equal(save.members.length,0);
  const j=harness();j.entity('car','vehicle',100);j.tick(6);assert(j.squad.restore(save).ok);
  assert.equal(j.squad.getAction('demolitions').id,original.id);j.tick(3);assert.equal(j.effects.length,0);j.tick(1);j.tick(10);
  assert.equal(j.effects.length,1);assert.equal(j.effects[0].target.position.x,100);assert.equal(j.effects[0].actionId,original.id);
  assert.equal(j.squad.snapshot().charges.length,0,'Completed effects never reserialized');
  assert(j.squad.restore(save).ok);j.tick();assert.equal(j.effects.length,1,'Same runtime cannot replay old charge receipt');
  const receipt=j.squad.snapshot();receipt.charges=save.charges;const replay=harness();replay.entity('car','vehicle');replay.squad.restore(receipt);replay.tick(100);assert.equal(replay.effects.length,0,'Persisted settled receipts suppress replay');
  const expired=harness();expired.entity('car','vehicle',55);expired.tick(100);expired.squad.restore(save);expired.tick();expired.tick();assert.equal(expired.effects.length,1);
  const missing=harness();missing.tick(100);missing.squad.restore(save);missing.tick();assert.equal(missing.effects.length,0);assert.equal(missing.squad.getAction('demolitions'),null);
  const work=harness();work.recruit('demolitions');work.entity('car','vehicle');work.squad.command('demolitions','plant_bomb','car');work.tick();
  const workSave=work.squad.snapshot();assert.equal(workSave.charges.length,0,'Unarmed work does not survive reload');
}
console.log('mercenary core: armed charges persist identity/deadline after dismissal, expired once, missing target safe PASS');
for(const success of [true,false]){
  let settle,calls=0;const receipt=new Promise((resolve,reject)=>{settle=success?()=>resolve({ok:true,opened:true}):()=>reject(new Error('Denied'));});
  const h=harness({performEffect:()=>{calls++;return receipt;}});h.recruit('safecracker');h.entity('door','door').locked=true;
  h.squad.command('safecracker','unlock_door','door');h.tick();h.tick(5);
  assert.equal(h.squad.getAction('safecracker').phase,'awaiting');assert.equal(h.squad.getRoster()[0].xp,0);
  assert.equal(h.squad.cancel('safecracker').reason,'effect_pending');assert.equal(h.squad.command('safecracker','unlock_door','door').reason,'busy');
  h.tick(100);assert.equal(calls,1);settle();await Promise.resolve();await Promise.resolve();
  assert.equal(h.squad.getAction('safecracker'),null);assert.equal(h.squad.getRoster()[0].xp,success?25:0);h.tick();assert.equal(calls,1);
}
{
  let resolve;const pending=new Promise(r=>resolve=r);const h=harness({performEffect:()=>pending});h.recruit('safecracker');h.entity('safe','safe').locked=true;
  h.squad.command('safecracker','unlock_safe','safe');h.tick();h.tick(8);const requestId=h.squad.getAction('safecracker').id;
  h.squad.dismiss('safecracker');const saved=h.squad.snapshot();assert.equal(saved.pendingTransactions[0].requestId,requestId);
  const poseCount=h.poses.length;resolve({ok:true});await Promise.resolve();await Promise.resolve();
  assert.equal(h.squad.getRoster().length,0);assert.equal(h.poses.length,poseCount,'Late receipt cannot animate dismissed NPC');
  const j=harness();j.squad.restore(saved);j.tick(500);assert.equal(j.effects.length,0,'Restored request is never blindly resubmitted');
  assert(j.squad.getAction('safecracker').requiresReconciliation);assert(j.squad.resolvePending(requestId,{ok:true}).ok);
  assert.equal(j.squad.resolvePending(requestId,{ok:true}).reason,'unknown_request');assert.equal(j.squad.snapshot().pendingTransactions.length,0);
}
{
  let resolve;const h=harness({performEffect:()=>new Promise(r=>resolve=r)});h.recruit('demolitions');h.entity('car','vehicle');
  h.squad.command('demolitions','plant_bomb','car');h.tick();h.tick(4);h.live.get('demolitions').position.x=10;h.tick(6);assert.equal(h.squad.getAction('demolitions').phase,'awaiting');
  resolve({ok:true});await Promise.resolve();await Promise.resolve();assert.equal(h.squad.getRoster()[0].xp,25);
}
console.log('mercenary core: async acknowledged effects, reject, busy/cancel, late dismiss, safe restored reconciliation PASS');
{
  let scans=0,targetReads=0,time=1000;
  const members=Object.fromEntries(Array.from({length:5},(_,i)=>['m'+i,{hp:100,position:{x:0,y:0,z:0}}]));
  const core=createMercenarySquad({now:()=>time,getMember:id=>members[id],getTarget:()=>{targetReads++;return null;},scanReviveTargets:()=>{scans++;return Array.from({length:100},(_,i)=>({id:'t'+i}));}});
  for(let i=0;i<5;i++)core.recruit({id:'m'+i,profession:'medic'});
  core.update();assert.equal(targetReads,30,'Only six revive candidates per each of five medics');
  for(let i=0;i<100;i++)core.update();assert.equal(scans,1,'Medic scan throttled');
  const samples=[];
  for(let i=0;i<5000;i++){time+=.016;const begin=performance.now();core.update();samples.push(performance.now()-begin);}
  samples.sort((a,b)=>a-b);
  console.log(`mercenary core CPU 5 members / 5000 ticks: p50=${samples[2500].toFixed(4)}ms p95=${samples[4750].toFixed(4)}ms; source/GPU costs excluded`);
}
