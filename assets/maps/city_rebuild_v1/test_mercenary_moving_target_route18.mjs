import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import * as module from './mercenary_core.mjs';
const script=fs.readFileSync(new URL('./mercenary_world.js',import.meta.url),'utf8').replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');
const fixtureText=fs.readFileSync(new URL('./test_mercenary_rally_actions.mjs',import.meta.url),'utf8');
const fixture=Function('vm','module','script','assert',fixtureText.slice(fixtureText.indexOf('async function fixture('),fixtureText.indexOf('\nfor(const [profession'))+';return fixture;')(vm,module,script,assert);
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8'),physicalFunctions=['_npcBodyPassable','_npcPathPassable'].map(name=>world.match(new RegExp('^function '+name+'\\([^]*?^}','m'))?.[0]).join('\n');
const routeText=fs.readFileSync(new URL('./test_mercenary_route.mjs',import.meta.url),'utf8'),nativeCage=Function('vm','physicalFunctions',routeText.slice(routeText.indexOf('function nativeCage('),routeText.indexOf("\ntest('back-side"))+';return nativeCage;')(vm,physicalFunctions);

test('moving bomb target preserves multi-slice route progress at 5/10/30 FPS, then stops and explodes once',async t=>{
 for(const fps of [5,10,30]){
  const f=await fixture({qa:true}),m=f.recruit('demolitions'),native=nativeCage(f);m.c=43/4.1;m.r=52/4.1;
  const target={id:'moving-car',kind:'vehicle',valid:true,workRange:.08,position:{x:43,y:0,z:39},center:{x:43,y:0,z:37},speed:2};let effects=0,slices=0;
  f.api.bindTargets({get:()=>target,canMove:()=>true,performEffect:()=>{assert(Math.hypot(m.c*4.1-target.center.x,m.r*4.1-target.center.z)>=8);effects++;return true;}});
  assert(f.api.command('plant_bomb',target).ok);f.api.tick(0);
  const step=()=>{const before={r:m.r,c:m.c};f.tick(1/fps);assert(f.ctx._npcPathPassable(before.r,before.c,m.r,m.c,f.ctx.npcPassableForSnitch));assert(!native.pointBlocked(m.c*4.1,m.r*4.1,.738));slices=Math.max(slices,m._mercenaryPath?.stats?.slices||m._mercenaryPath?.search?.stats.slices||0);};
  for(let i=1;i<=fps*6;i++){target.position.x=43+i/fps*2;target.center.x=target.position.x;step();}
  assert(Math.hypot(m.c*4.1-43,m.r*4.1-52)>3,'must progress while each new target position drifts instead of restarting every search');assert(slices>1,'route spans bounded search slices');assert.equal(effects,0);
  target.speed=0;for(let i=0;i<fps*35&&!effects;i++)step();
  t.diagnostic(JSON.stringify({fps,slices,effects,position:{x:m.c*4.1,z:m.r*4.1},last:f.api.getMember(m.id).movement.lastAction}));
  assert.equal(effects,1);assert.equal(f.api.getAction(m.id),null);for(let i=0;i<fps*2;i++)step();assert.equal(effects,1);
 }
});

test('V cancels moving-target pursuit immediately without replay or teleport',async()=>{
 const f=await fixture({qa:true}),m=f.recruit('demolitions'),target={id:'moving',kind:'vehicle',valid:true,position:{x:60,y:0,z:41},speed:4};let effects=0;
 f.api.bindTargets({get:()=>target,canMove:()=>true,performEffect:()=>{effects++;return true;}});assert(f.api.command('plant_bomb',target).ok);for(let i=0;i<10;i++){target.position.x+=.8;f.tick(.2);}const before={r:m.r,c:m.c};assert(f.api.follow().ok);assert.equal(f.api.getAction(m.id),null);assert.deepEqual({r:m.r,c:m.c},before);for(let i=0;i<80;i++)f.tick(.2);assert.equal(effects,0);
});

test('actual source resumes chase when car moves during planting and restarts the full timer after stopping',async()=>{
 const f=await fixture({qa:true}),m=f.recruit('demolitions'),target={id:'restart-car',kind:'vehicle',valid:true,workRange:.08,position:{x:41,y:0,z:41},center:{x:41,y:0,z:39},speed:0};let effects=0;m.c=10;m.r=10;
 f.api.bindTargets({get:()=>target,canMove:()=>true,performEffect:()=>{effects++;return true;}});assert(f.api.command('plant_bomb',target).ok);for(let i=0;i<10;i++)f.tick(.2);assert.equal(f.api.getAction(m.id).phase,'working');assert(f.api.getAction(m.id).progress>.3);
 target.speed=2;for(let i=0;i<15;i++){target.position.x+=.4;target.center.x+=.4;f.tick(.2);assert.equal(f.api.getAction(m.id).phase,'approach');assert.equal(f.api.getAction(m.id).progress,0);}assert(m.c*4.1>44,'operator actually pursues the resumed vehicle');assert.equal(effects,0);
 target.speed=0;let began=false;for(let i=0;i<100;i++){f.tick(.2);if(f.api.getAction(m.id)?.phase==='working'){began=true;break;}}assert(began);for(let i=0;i<14;i++)f.tick(.2);assert.equal(f.api.getAction(m.id).phase,'working');assert.equal(f.api.getAction(m.id).armed,false);
 for(let i=0;i<100&&!effects;i++)f.tick(.2);assert.equal(effects,1);assert.equal(f.api.getAction(m.id),null);
});
