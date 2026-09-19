import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import * as module from './mercenary_core.mjs';
const script=fs.readFileSync(new URL('./mercenary_world.js',import.meta.url),'utf8').replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');
const fixtureText=fs.readFileSync(new URL('./test_mercenary_rally_actions.mjs',import.meta.url),'utf8');
const fixture=Function('vm','module','script','assert',fixtureText.slice(fixtureText.indexOf('async function fixture('),fixtureText.indexOf('\nfor(const [profession'))+';return fixture;')(vm,module,script,assert);
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8'),physicalFunctions=['_npcBodyPassable','_npcPathPassable'].map(name=>world.match(new RegExp('^function '+name+'\\([^]*?^}','m'))?.[0]).join('\n');
const routeTest=fs.readFileSync(new URL('./test_mercenary_route.mjs',import.meta.url),'utf8'),nativeCage=Function('vm','physicalFunctions',routeTest.slice(routeTest.indexOf('function nativeCage('),routeTest.indexOf("\ntest('back-side"))+';return nativeCage;')(vm,physicalFunctions);

test('five followers find free formation places next to a wall at 5/10/30fps',async t=>{
 for(const fps of [5,10,30]){
  const f=await fixture({qa:true});for(const p of ['medic','bruiser','engineer','safecracker','demolitions'])f.recruit(p);
  const native=nativeCage(f,[[37,39,30,52]]);f.ctx.player.c=41/4.1;f.ctx.player.r=41/4.1;f.ctx.player.ang=0;f.api.bindTargets({canMove:()=>true});
  f.ctx._myGang.forEach((m,i)=>{m.c=(43+i*1.5)/4.1;m.r=47/4.1;});f.api.follow();f.api.tick(0);
  const costs=[];for(let i=0;i<fps*25;i++){const started=performance.now();f.tick(1/fps);costs.push(performance.now()-started);for(const m of f.ctx._myGang)assert(!native.pointBlocked(m.c*4.1,m.r*4.1,.738));}
  const result=f.ctx._myGang.map(m=>({id:m.id,distance:Math.hypot(m.c*4.1-41,m.r*4.1-41),...f.api.getMember(m.id).movement}));
  costs.sort((a,b)=>a-b);t.diagnostic(JSON.stringify({fps,cpuP50ms:+costs[Math.floor(costs.length*.5)].toFixed(4),cpuP95ms:+costs[Math.floor(costs.length*.95)].toFixed(4),members:result.map(({id,distance,x,z,reason,search})=>({id,distance:distance&&+distance.toFixed(2),x:x&&+x.toFixed(2),z:z&&+z.toFixed(2),reason,expanded:search?.expanded}))}));assert(result.every(m=>m.distance<7&&m.reason==='arrived'));
 }
});

test('five followers make route progress while leader moves beyond a cage at 5/10/30fps',async t=>{
 for(const fps of [5,10,30]){
  const f=await fixture({qa:true});for(const p of ['medic','bruiser','engineer','safecracker','demolitions'])f.recruit(p);
  const native=nativeCage(f);f.ctx.player.c=43/4.1;f.ctx.player.r=38/4.1;f.ctx.player.ang=-Math.PI/2;f.api.bindTargets({canMove:()=>true});
  f.ctx._myGang.forEach((m,i)=>{m.c=(39+i*2)/4.1;m.r=52/4.1;});f.api.follow();f.api.tick(0);
  for(let i=0;i<fps*12;i++){f.ctx.player.c=(43+i/fps)/4.1;f.tick(1/fps);for(const m of f.ctx._myGang)assert(!native.pointBlocked(m.c*4.1,m.r*4.1,.738));}
  const result=f.ctx._myGang.map(m=>({id:m.id,x:m.c*4.1,z:m.r*4.1,...f.api.getMember(m.id).movement}));t.diagnostic(JSON.stringify({fps,members:result.map(({id,distance,x,z,reason,search})=>({id,distance:distance&&+distance.toFixed(2),x:x&&+x.toFixed(2),z:z&&+z.toFixed(2),reason,expanded:search?.expanded}))}));
  assert(result.every(m=>m.z<48),'every follower should make meaningful progress rather than restart the same pending route');
  for(let i=0;i<fps*15;i++){f.tick(1/fps);for(const m of f.ctx._myGang)assert(!native.pointBlocked(m.c*4.1,m.r*4.1,.738));}
  assert(f.ctx._myGang.every(m=>Math.hypot(m.c-f.ctx.player.c,m.r-f.ctx.player.r)*4.1<7),'all five finally catch the stopped leader');
 }
});

test('floating-point arrival at follow and rally radii stops motion and animation',async()=>{
 for(const mode of ['follow','rally']){
  const f=await fixture({qa:true}),m=f.recruit('engineer');f.api.bindTargets({canMove:()=>true});f.ctx.player.c=10;f.ctx.player.r=10;f.ctx.player.ang=0;
  const goal=mode==='follow'?{x:38.5,y:0,z:39.7}:{x:43,y:0,z:41},radius=mode==='follow'?.6:.35;m.c=(goal.x+radius+1e-13)/4.1;m.r=goal.z/4.1;
  if(mode==='follow')f.api.follow();else f.api.rally(goal);const before={r:m.r,c:m.c};for(let i=0;i<30;i++)f.tick(.2);
  assert.equal(f.api.getMember(m.id).movement.reason,'arrived');assert.equal(m._followSpeed,0);assert.equal(m.walkPhase,0);assert.deepEqual({r:m.r,c:m.c},before);
 }
});

test('a newly blocked rally edge is replanned physically instead of walking through the new car',async()=>{
 const f=await fixture({qa:true}),m=f.recruit('engineer'),walls=[],native=nativeCage(f,walls);m.c=41/4.1;m.r=41/4.1;f.api.bindTargets({canMove:()=>true});f.api.rally({x:59,y:0,z:41});
 for(let i=0;i<3;i++)f.tick(.2);walls.push([48.7,51.3,38.5,43.5]);let detoured=false;
 for(let i=0;i<120;i++){f.tick(.2);assert(!native.pointBlocked(m.c*4.1,m.r*4.1,.738));if(Math.abs(m.r*4.1-41)>3)detoured=true;}
 assert(detoured);assert(Math.hypot(m.c*4.1-59,m.r*4.1-41)<.351);assert.equal(f.api.getMember(m.id).movement.reason,'arrived');
});
