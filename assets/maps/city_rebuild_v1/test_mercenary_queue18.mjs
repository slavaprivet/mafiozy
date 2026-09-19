import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import * as module from './mercenary_core.mjs';
const text=fs.readFileSync(new URL('./test_mercenary_core.mjs',import.meta.url),'utf8');
const harness=Function('createMercenarySquad','assert',text.slice(text.indexOf('function harness('),text.indexOf('\nfor(const [profession'))+';return harness;')(module.createMercenarySquad,assert);
const script=fs.readFileSync(new URL('./mercenary_world.js',import.meta.url),'utf8').replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)'),fixtureText=fs.readFileSync(new URL('./test_mercenary_rally_actions.mjs',import.meta.url),'utf8');
const fixture=Function('vm','module','script','assert',fixtureText.slice(fixtureText.indexOf('async function fixture('),fixtureText.indexOf('\nfor(const [profession'))+';return fixture;')(vm,module,script,assert);
const target=(h,id,kind='fence')=>Object.assign(h.entity(id,kind),{powered:true,locked:true});

test('power then fence preserves current work and executes FIFO with separate timers and receipts',()=>{
 const h=harness();h.recruit('engineer');target(h,'power','power_panel');target(h,'fence');h.squad.command('engineer','disable_power','power');h.tick();h.tick(1);
 const before=h.squad.getAction('engineer'),queued=h.squad.command('engineer','cut_fence','fence');assert(queued.queued);assert.equal(queued.queuePosition,1);assert.deepEqual(h.squad.getAction('engineer'),before);assert.equal(h.squad.getQueue('engineer')[0].targetId,'fence');
 h.tick(4);assert.deepEqual(h.effects.map(e=>e.targetId),['power']);assert.equal(h.squad.getAction('engineer').targetId,'fence');h.tick();h.tick(5.99);assert.equal(h.effects.length,1);h.tick(.01);assert.deepEqual(h.effects.map(e=>e.targetId),['power','fence']);assert.equal(h.squad.getRecord('engineer').xp,50);
});
test('same action waits its real cooldown, rather than skipping or shortening it',()=>{
 const h=harness();h.recruit('engineer');target(h,'one');target(h,'two');h.squad.command('engineer','cut_fence','one');h.squad.command('engineer','cut_fence','two');h.tick();h.tick(6);assert.equal(h.squad.getAction('engineer'),null);assert.equal(h.squad.getQueue('engineer').length,1);h.tick(1.99);assert.equal(h.squad.getAction('engineer'),null);h.tick(.01);assert.equal(h.squad.getAction('engineer').targetId,'two');h.tick();h.tick(6);assert.equal(h.effects.length,2);
});
test('queue is capped at eight waiting tasks, deduplicates identities and returns isolated copies',()=>{
 const h=harness();h.recruit('engineer');for(let i=0;i<10;i++)target(h,'f'+i);h.squad.command('engineer','cut_fence','f0');for(let i=1;i<=8;i++)assert(h.squad.command('engineer','cut_fence','f'+i).queued);assert.equal(h.squad.command('engineer','cut_fence','f9').reason,'queue_full');assert.equal(h.squad.command('engineer','cut_fence','f2').reason,'target_busy');assert.equal(h.squad.command('engineer','cut_fence','f0').reason,'busy');const copy=h.squad.getQueue('engineer');copy[0].targetId='fake';assert.equal(h.squad.getQueue('engineer')[0].targetId,'f1');assert(h.squad.availableActions(h.live.get('f9')).every(r=>!r.available));
});
test('already completed and missing queued targets are skipped before the next valid job',()=>{
 const h=harness();h.recruit('engineer');target(h,'one','power_panel');target(h,'gone');target(h,'cut');target(h,'last');h.squad.command('engineer','disable_power','one');for(const id of ['gone','cut','last'])h.squad.command('engineer','cut_fence',id);h.live.delete('gone');h.live.get('cut').cut=true;h.tick();h.tick(5);assert.equal(h.squad.getAction('engineer').targetId,'last');assert.equal(h.squad.getQueue('engineer').length,0);
});
for(const damage of ['hit','death'])test(`${damage} clears current unfinished work and every queued task`,()=>{
 const h=harness(),m=h.recruit('engineer');target(h,'one');target(h,'two');h.squad.command('engineer','cut_fence','one');h.squad.command('engineer','cut_fence','two');h.tick();if(damage==='hit')m.hp--;else m.hp=0;h.tick(1);assert.equal(h.squad.getAction('engineer'),null);assert.equal(h.squad.getQueue('engineer').length,0);h.tick(10);assert.equal(h.effects.filter(e=>e.kind==='cut_fence').length,0);
});
test('armed bomb survives while queued future bomb is removed by damage',()=>{
 const h=harness(),m=h.recruit('demolitions');target(h,'car','vehicle');target(h,'other','vehicle');h.squad.command('demolitions','plant_bomb','car');h.squad.command('demolitions','plant_bomb','other');h.tick();h.tick(4);m.hp=0;h.tick();assert(h.squad.getAction('demolitions').armed);assert.equal(h.squad.getQueue('demolitions').length,0);h.tick(6);assert.deepEqual(h.effects.filter(e=>e.kind==='plant_bomb').map(e=>e.targetId),['car']);
});
test('pending receipt holds the first job; cancel removes future tasks without resending the committed effect',async()=>{
 let settle,calls=0;const h=harness({performEffect:()=>{calls++;return new Promise(r=>settle=r);}});h.recruit('engineer');target(h,'one');target(h,'two');h.squad.command('engineer','cut_fence','one');h.tick();h.tick(6);assert(h.squad.command('engineer','cut_fence','two').queued);assert.equal(h.squad.cancel('engineer').reason,'effect_pending');assert.equal(h.squad.getQueue('engineer').length,0);settle(true);await Promise.resolve();await Promise.resolve();h.tick(10);assert.equal(calls,1);
});
test('reload resumes unfinished first job before saved queue, with no restoration of partial work credit',()=>{
 const h=harness();h.recruit('engineer');target(h,'one','power_panel');target(h,'two');h.squad.command('engineer','disable_power','one');h.tick();h.tick(3);h.squad.command('engineer','cut_fence','two');const snapshot=h.squad.snapshot();
 const next=harness();next.entity('engineer');target(next,'one','power_panel');target(next,'two');assert(next.squad.restore(snapshot).ok);next.tick();assert.equal(next.squad.getAction('engineer').targetId,'one');next.tick();next.tick(4.9);assert.equal(next.effects.length,0);next.tick(.1);assert.equal(next.effects[0].targetId,'one');assert.equal(next.squad.getAction('engineer').targetId,'two');
});
test('safe clearance gate keeps next work pending until the physical exit is finished',()=>{
 let free=true;const h=harness({canStartQueued:()=>free});h.recruit('safecracker');target(h,'safe','safe');target(h,'door','door');h.squad.command('safecracker','unlock_safe','safe');h.squad.command('safecracker','unlock_door','door');h.tick();free=false;h.tick(8);assert.equal(h.squad.getAction('safecracker'),null);assert.equal(h.squad.getQueue('safecracker').length,1);free=true;h.tick();assert.equal(h.squad.getAction('safecracker').targetId,'door');
});
test('explicit non-lockpickable QA door never advertises or accepts fictitious lockpicking',()=>{
 const h=harness();h.recruit('safecracker');const door=target(h,'door','door');door.lockpickable=false;assert.equal(h.squad.availableActions(door).length,0);assert.equal(h.squad.command('safecracker','unlock_door','door').reason,'invalid_target');
});
for(const command of ['follow','rally'])test(`source ${command} clears current and queued specialist jobs`,async()=>{
 const f=await fixture({qa:true}),m=f.recruit('engineer'),targets=new Map([['one',{id:'one',kind:'power_panel',powered:true,position:{x:41,y:0,z:41}}],['two',{id:'two',kind:'fence',position:{x:41,y:0,z:41}}]]);let effects=0;f.api.bindTargets({get:id=>targets.get(id),canMove:()=>true,performEffect:()=>{effects++;return true;}});assert(f.api.command('disable_power',targets.get('one')).ok);f.tick();const row=f.api.getActions(targets.get('two')).find(a=>a.id==='cut_fence');assert(row.enabled&&row.willQueue);const result=f.api.command('cut_fence',targets.get('two'));assert(result.queued);assert.equal(f.api.getMember(m.id).queued.length,1);assert.equal(f.api.getRoster().members[0].queued.length,1);assert.equal(f.api.getQueue(m.id).length,1);
 assert(command==='follow'?f.api.follow().ok:f.api.rally({x:50,y:0,z:41}).ok);assert.equal(f.api.getAction(m.id),null);assert.equal(f.api.getQueue(m.id).length,0);for(let i=0;i<60;i++)f.tick(.2);assert.equal(effects,0);
});
test('source engineer finishes shield then gate at 5/10/30fps with physical approach and no repeated effects',async()=>{
 for(const fps of [5,10,30]){const f=await fixture({qa:true}),m=f.recruit('engineer'),targets=new Map([['panel',{id:'panel',kind:'power_panel',powered:true,position:{x:44,y:0,z:41},workRange:.08}],['gate',{id:'gate',kind:'fence',position:{x:47,y:0,z:41},workRange:.08}]]),effects=[];
  f.api.bindTargets({get:id=>targets.get(id),canMove:()=>true,performEffect:e=>{effects.push(e.targetId);if(e.kind==='disable_power')targets.get(e.targetId).powered=false;else targets.get(e.targetId).cut=true;return {ok:true};}});f.api.command('disable_power',targets.get('panel'));assert(f.api.command('cut_fence',targets.get('gate')).queued);for(let i=0;i<fps*30&&effects.length<2;i++)f.tick(1/fps);assert.deepEqual(effects,['panel','gate']);assert.equal(f.api.getQueue(m.id).length,0);assert.equal(f.api.getAction(m.id),null);
 }
});
