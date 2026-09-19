import test from 'node:test';
import assert from 'node:assert/strict';
import {createMercenarySquad} from './mercenary_core.mjs';

function fixture(time=1000, effect=()=>true) {
  const member={id:'member',hp:100,position:{x:0,y:0,z:0}};
  const target={id:'car',kind:'vehicle',position:{x:0,y:0,z:0}};
  const effects=[],moves=[],poses=[];
  const squad=createMercenarySquad({now:()=>time,getMember:()=>member,getTarget:()=>target,
    moveMember:(...args)=>moves.push(args),onAction:(...args)=>poses.push(args),
    performEffect:e=>{effects.push(e);return effect(e);}});
  return {squad,member,target,effects,moves,poses,
    tick:at=>{time=at;squad.update();},
    recruit:profession=>assert.equal(squad.recruit({id:'member',profession}).ok,true)};
}

for(const mode of ['live','restored','legacy-save']) test(`dismissed operator stays detached while fuse survives: ${mode}`,()=>{
  const h=fixture();h.recruit('demolitions');
  assert.equal(h.squad.command('member','plant_bomb','car').ok,true);
  h.tick(1000);h.tick(1004);h.squad.dismiss('member');
  const save=h.squad.snapshot();
  if(mode==='restored')assert.equal(save.charges[0].detached,true);
  if(mode==='legacy-save')delete save.charges[0].detached;
  const f=mode==='live'?h:fixture(1004);
  if(f!==h)assert.equal(f.squad.restore(save).ok,true);
  f.moves.length=0;f.poses.length=0;
  f.tick(1005);f.target.position.x=50;f.tick(1006);
  assert.equal(f.moves.length,0,'dismissed living NPC must not receive retreat/stop orders');
  assert.equal(f.poses.length,0,'dismissed NPC must not receive action poses');
  f.tick(1010);f.tick(1011);
  assert.equal(f.effects.length,1,'existing charge detonates once at its deadline');
  assert.equal(f.effects[0].target.position.x,50,'charge follows the same moving target');
  assert.equal(f.moves.length,0);assert.equal(f.poses.length,0);
});

test('detached async explosion waits for one receipt without publishing poses',async()=>{
  let acknowledge;
  const h=fixture(1000,()=>new Promise(resolve=>{acknowledge=resolve;}));h.recruit('demolitions');
  h.squad.command('member','plant_bomb','car');h.tick(1000);h.tick(1004);h.squad.dismiss('member');
  h.moves.length=0;h.poses.length=0;h.tick(1010);h.tick(1011);
  const pending=h.squad.snapshot();
  assert.equal(pending.pendingTransactions[0].detached,true);
  assert.equal(h.poses.length,0);assert.equal(h.effects.length,1);
  acknowledge({ok:true});await Promise.resolve();
  assert.equal(h.squad.getAction('member'),null);assert.equal(h.moves.length,0);assert.equal(h.poses.length,0);
  const restored=fixture(1011);assert.equal(restored.squad.restore(pending).ok,true);
  restored.tick(1012);assert.equal(restored.effects.length,0,'pending requests are reconciled, never resent');
  const request=pending.pendingTransactions[0].requestId;
  assert.equal(restored.squad.resolvePending(request,true).ok,true);
  assert.equal(restored.squad.resolvePending(request,true).ok,false);
  assert.equal(restored.poses.length,0);assert.equal(restored.moves.length,0);
});

for(const start of [0,1000]) test(`reload retains remaining rescue grace, including timestamp ${start}`,()=>{
  const h=fixture(start);h.recruit('bruiser');h.member.hp=0;h.member.downed=true;h.tick(start);
  const f=fixture(start+15);f.member.hp=0;f.member.downed=true;
  assert.equal(f.squad.restore(h.squad.snapshot()).ok,true);
  assert.equal(f.squad.getRecord('member').status,'downed');
  f.tick(start+19);assert.equal(f.effects.length,0);
  f.tick(start+20);assert.equal(f.effects.length,1);assert.equal(f.effects[0].kind,'hospitalize');
});

for(const kind of ['hospitalize','discharge']) test(`reload preserves rejected ${kind} retry deadline`,()=>{
  const h=fixture(1000,e=>e.kind!==kind);h.recruit('bruiser');h.member.hp=0;h.member.dead=true;
  h.tick(1000);
  const failedAt=kind==='discharge'?1300:1000;
  if(kind==='discharge')h.tick(failedAt);
  const f=fixture(failedAt);f.member.hp=0;f.member.dead=true;
  assert.equal(f.squad.restore(h.squad.snapshot()).ok,true);
  f.tick(failedAt);f.tick(failedAt+.5);assert.equal(f.effects.length,0,'reload must not bypass retry throttle');
  f.tick(failedAt+1);assert.equal(f.effects.length,1);assert.equal(f.effects[0].kind,kind);
});

test('older saves and invalid timer values restore safely',()=>{
  const h=fixture();h.recruit('bruiser');const save=h.squad.snapshot();
  for(const value of [undefined,null,-1,NaN,Infinity,'1000']){
    save.members[0].downedAt=value;save.members[0].lifecycleRetryAt=value;
    const f=fixture();assert.equal(f.squad.restore(save).ok,true);
    assert.equal(f.squad.getRecord('member').downedAt,null);
    f.member.hp=0;f.member.dead=true;f.tick(1000);
    assert.equal(f.effects.length,1,'invalid retry must not block hospitalization');
  }
});
