import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import * as module from './mercenary_core.mjs';
const coreTest=fs.readFileSync(new URL('./test_mercenary_core.mjs',import.meta.url),'utf8');
const harness=Function('createMercenarySquad','assert',coreTest.slice(coreTest.indexOf('function harness('),coreTest.indexOf('\nfor(const [profession'))+';return harness;')(module.createMercenarySquad,assert);
const script=fs.readFileSync(new URL('./mercenary_world.js',import.meta.url),'utf8').replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');
const fixtureText=fs.readFileSync(new URL('./test_mercenary_rally_actions.mjs',import.meta.url),'utf8');
const fixture=Function('vm','module','script','assert',fixtureText.slice(fixtureText.indexOf('async function fixture('),fixtureText.indexOf('\nfor(const [profession'))+';return fixture;')(vm,module,script,assert);

function door(h,flags={}){return Object.assign(h.entity('door','door'),{locked:true,breachable:true,bombable:true},flags);}
test('door capabilities explicitly gate bruiser and demolition commands',()=>{
 for(const flags of [{breachable:false,bombable:false},{breachable:undefined,bombable:undefined},{locked:false},{opened:true},{destroyed:true},{valid:false}]){
  const h=harness();h.recruit('bruiser');h.recruit('demolitions');const target=door(h,flags);assert.equal(h.squad.availableActions(target).length,0);assert.equal(h.squad.command('bruiser','breach_door','door').ok,false);assert.equal(h.squad.command('demolitions','plant_bomb','door').ok,false);
 }
});
test('bruiser kicks after its 2.5 second timer and applies one acknowledged effect',()=>{
 const h=harness();h.recruit('bruiser');door(h);assert(h.squad.command('bruiser','breach_door','door').ok);h.tick();assert.equal(h.poses.at(-1)[1].duration,2.5);h.tick(2.49);assert.equal(h.effects.length,0);h.tick(.01);assert.equal(h.effects.length,1);assert.equal(h.effects[0].noiseRadius,12);h.tick(10);assert.equal(h.effects.length,1);assert.equal(h.squad.getRecord('bruiser').xp,25);
});
for(const cause of ['hit','death','cancel','opened'])test(`breach interruption ${cause} before timer zero cannot force the door`,()=>{
 const h=harness(),m=h.recruit('bruiser'),target=door(h);h.squad.command('bruiser','breach_door','door');h.tick();h.tick(2);
 if(cause==='hit')m.hp--;if(cause==='death'){m.hp=0;m.dead=true;}if(cause==='cancel')h.squad.cancel('bruiser');if(cause==='opened')target.opened=true;h.tick(1);assert.equal(h.effects.filter(e=>e.kind==='breach_door').length,0);assert.equal(h.squad.getRecord('bruiser').xp,0);
});
test('lockpick, kick and bomb compete for one door across different professionals',()=>{
 const h=harness();h.recruit('safecracker');h.recruit('bruiser');h.recruit('demolitions');const target=door(h);h.squad.command('bruiser','breach_door','door');
 assert(h.squad.availableActions(target).every(row=>!row.available));assert.equal(h.squad.command('demolitions','plant_bomb','door').reason,'target_busy');assert.equal(h.squad.command('safecracker','unlock_door','door').reason,'target_busy');h.squad.cancel('bruiser');assert(h.squad.command('demolitions','plant_bomb','door').ok);
});
test('door bomb uses four seconds planting, six second fuse and at least eight metres retreat',()=>{
 const h=harness(),m=h.recruit('demolitions'),target=door(h);target.position.x=1;target.center={x:0,y:0,z:0};h.squad.command('demolitions','plant_bomb','door');h.tick();h.tick(4);assert(h.squad.getAction('demolitions').armed);h.tick(6);assert.equal(h.effects.length,0);assert(h.squad.getAction('demolitions').waitingForSafety);m.position.x=8.1;h.tick();assert.equal(h.effects.length,1);assert.equal(h.effects[0].noiseRadius,40);h.tick(20);assert.equal(h.effects.length,1);
});
test('pending breach receipt is not repeated; rejection grants no XP and success remains singular',async()=>{
 for(const ok of [false,true]){let resolve,calls=0;const h=harness({performEffect:()=>{calls++;return new Promise(r=>resolve=r);}});h.recruit('bruiser');door(h);h.squad.command('bruiser','breach_door','door');h.tick();h.tick(2.5);h.tick(20);assert.equal(calls,1);assert.equal(h.squad.getAction('bruiser').phase,'awaiting');resolve({ok});await Promise.resolve();await Promise.resolve();h.tick();assert.equal(calls,1);assert.equal(h.squad.getRecord('bruiser').xp,ok?25:0);}
});
test('source door commands expose labels, route with contact metadata and invoke real adapter once at 5/10/30fps',async()=>{
 for(const fps of [5,10,30])for(const [profession,kind]of [['bruiser','breach_door'],['demolitions','plant_bomb']]){
  const f=await fixture({qa:true}),m=f.recruit(profession);m.c=10;m.r=10;let calls=0;
  const target={id:'door:source',kind:'door',valid:true,locked:true,breachable:true,bombable:true,position:{x:45,y:0,z:41},center:{x:46,y:0,z:41},workRange:.08,workPoint:{x:45.95,y:.8,z:41},workNormal:{x:-1,y:0,z:0}};
  f.api.bindTargets({get:()=>target,canMove:()=>true,performEffect:e=>{if(kind==='plant_bomb')assert(Math.hypot(m.c*4.1-46,m.r*4.1-41)>=8);assert.equal(e.kind,kind);calls++;target.locked=false;target.opened=true;return {ok:true};}});
  assert.equal(f.api.getActions(target).find(row=>row.id===kind).label,kind==='breach_door'?'Выбить дверь':'Подорвать');assert(f.api.command(kind,target).ok);
  for(let i=0;i<fps*30&&!calls;i++)f.tick(1/fps);assert.equal(calls,1);assert.equal(f.api.getAction(m.id),null);
 }
});
