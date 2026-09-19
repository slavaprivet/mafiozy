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

test('crew covers same standing/crouched/prone distance at 5, 10, 30 and 60fps despite clamped incoming dt',async t=>{
 const beforeScript=script.replace('const elapsed=movementElapsed(dt)','const elapsed=Math.min(.05,Math.max(0,Number(dt)||0))'),beforeFactory=Function('vm','module','script','assert',fixtureText.slice(fixtureText.indexOf('async function fixture('),fixtureText.indexOf('\nfor(const [profession'))+';return fixture;')(vm,module,beforeScript,assert),before=await beforeFactory(),oldMember=before.recruit('engineer');oldMember.c=10;oldMember.r=10;before.api.bindTargets({canMove:()=>true});before.api.rally({x:47,y:0,z:41});before.api.tick(0);for(let i=0;i<5;i++)before.tick(.2);const prior5fpsMetres=(oldMember.c-10)*4.1;assert(Math.abs(prior5fpsMetres-.75)<1e-6);t.diagnostic(JSON.stringify({priorClamped5fpsMetres:+prior5fpsMetres.toFixed(3)}));
 const results=[];for(const fps of [5,10,30,60])for(const [posture,speed]of [['stand',3],['crouch',1.5],['prone',.65]]){
  const f=await fixture({qa:true}),m=f.recruit('engineer');m.c=10;m.r=10;f.ctx._effectivePlayerStance=()=>posture;f.api.bindTargets({canMove:()=>true});f.api.rally({x:47,y:0,z:41});f.api.tick(0);
  for(let i=0;i<fps;i++){f.tick(1/fps);assert(f.api.getMember(m.id).movement.clock.substeps<=6);}const metres=(m.c-10)*4.1;assert(Math.abs(metres-speed)<1e-6,JSON.stringify({fps,posture,metres,speed}));results.push({fps,posture,metres:+metres.toFixed(3)});
 }t.diagnostic(JSON.stringify(results));
});
test('5/10/30/60fps demo-car route, plant timer and safe-retreat explosion all complete without wall crossing',async t=>{
 const results=[];for(const fps of [5,10,30,60]){
  const f=await fixture({qa:true}),m=f.recruit('demolitions'),x=45,z=49,native=nativeCage(f,[[x-1.28,x+1.28,z-2.24,z+2.24]]);m.c=(x+7)/4.1;m.r=(z-8)/4.1;
  const target={id:'elapsed-car',kind:'vehicle',valid:true,workRange:.08,position:{x:x-1.28-.84,y:0,z},center:{x,y:0,z}};let explosions=0,workingAt=null,armedAt=null,time=0,explodedAt=null,maxSubsteps=0;const costs=[];
  f.api.bindTargets({get:()=>target,canMove:()=>true,performEffect:()=>{assert(Math.hypot(m.c*4.1-x,m.r*4.1-z)>=8);explosions++;explodedAt=time;return true;}});assert(f.api.command('plant_bomb',target).ok);f.api.tick(0);
  for(let i=0;i<fps*45&&!explosions;i++){time=(i+1)/fps;const started=performance.now();f.tick(1/fps);costs.push(performance.now()-started);const action=f.api.getAction(m.id);if(action?.phase==='working'&&workingAt===null)workingAt=time;if(action?.armed&&armedAt===null)armedAt=time;assert(!native.pointBlocked(m.c*4.1,m.r*4.1,.738));maxSubsteps=Math.max(maxSubsteps,f.api.getMember(m.id).movement.clock.substeps);}
  assert.equal(explosions,1,JSON.stringify({fps,movement:f.api.getMember(m.id).movement}));assert(armedAt-workingAt>=4-1e-5);assert(armedAt-workingAt<=4+1/fps+.001);assert(explodedAt-armedAt>=6-1e-5);assert(maxSubsteps<=6);costs.sort((a,b)=>a-b);results.push({fps,workingAt,armedAt,explodedAt,maxSubsteps,sourceCpuP50ms:+costs[Math.floor(costs.length*.5)].toFixed(4),sourceCpuP95ms:+costs[Math.floor(costs.length*.95)].toFixed(4)});
 }assert(Math.max(...results.map(r=>r.workingAt))<15,'bounded path search and physical approach must finish before approach timeout');t.diagnostic(JSON.stringify(results));
});
test('hidden scene, long pause and excess backlog cannot fast-forward or teleport crew',async()=>{
 const f=await fixture({qa:true}),m=f.recruit('engineer');m.c=10;m.r=10;f.api.bindTargets({canMove:()=>true});f.api.rally({x:47,y:0,z:41});f.api.tick(0);f.tick(.2);const moved=m.c;assert(Math.abs((moved-10)*4.1-.6)<1e-6);
 f.tick(20);assert.equal(m.c,moved);assert.equal(f.api.getMember(m.id).movement.clock.paused,true);f.tick(.2);assert(Math.abs((m.c-moved)*4.1-.6)<1e-6);
 f.ctx.document.hidden=true;const beforeHidden=m.c;f.tick(.2);assert.equal(m.c,beforeHidden);f.ctx.document.hidden=false;f.api.resetMovementClock();f.tick(.2);assert((m.c-beforeHidden)*4.1<=.151,'resume uses only a first bounded frame');
 const beforeBacklog=m.c;f.tick(.6);const clock=f.api.getMember(m.id).movement.clock;assert.equal(clock.substeps,6);assert.equal(clock.used,.3);assert(clock.dropped>.29);assert((m.c-beforeBacklog)*4.1<=.901);const afterBacklog=m.c;f.tick(.05);assert((m.c-afterBacklog)*4.1<=.151,'discarded backlog is not replayed');
});
