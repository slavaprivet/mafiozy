import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import * as module from './mercenary_core.mjs';
const script=fs.readFileSync(new URL('./mercenary_world.js',import.meta.url),'utf8').replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');
const fixtureText=fs.readFileSync(new URL('./test_mercenary_rally_actions.mjs',import.meta.url),'utf8');
const fixture=Function('vm','module','script','assert',fixtureText.slice(fixtureText.indexOf('async function fixture('),fixtureText.indexOf('\nfor(const [profession'))+';return fixture;')(vm,module,script,assert);
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
const physicalFunctions=['_npcBodyPassable','_npcPathPassable'].map(name=>world.match(new RegExp('^function '+name+'\\([^]*?^}','m'))?.[0]).join('\n');
function nativeCage(f,walls=[[39.88,46.12,43.88,44.12],[39.88,40.12,43.88,49.12],[45.88,46.12,43.88,49.12],[39.88,46.12,48.88,49.12]]){
 const pointBlocked=(x,z,radius=0)=>walls.some(([x0,x1,z0,z1])=>x>x0-radius&&x<x1+radius&&z>z0-radius&&z<z1+radius);
 const pass=(r,c)=>!pointBlocked(c*4.1,r*4.1);
 let checks=0;Object.assign(f.ctx,{npcPassable:pass,npcPassableForSnitch:pass,_npcRouteWalkBlocked:(r,c)=>!pass(r,c),_walkNpcNavigationResolver:({from,to,radius})=>{checks++;const count=Math.ceil(Math.hypot(to.r-from.r,to.c-from.c)*4.1/.04);for(let i=1;i<=Math.max(1,count);i++){const t=i/Math.max(1,count);if(pointBlocked((from.c+(to.c-from.c)*t)*4.1,(from.r+(to.r-from.r)*t)*4.1,radius*4.1))return{swept:true,blocked:true};}return{swept:true,blocked:false};}});
 vm.runInContext(physicalFunctions,f.ctx);return {pointBlocked,get checks(){return checks;}};
}
test('back-side specialist physically routes around actual source .18-tile footprint to front and cuts once',async()=>{
 const f=await fixture(),m=f.recruit('engineer'),native=nativeCage(f);m.c=43/4.1;m.r=52/4.1;
 const target={id:'cage:front',kind:'fence',cuttable:true,workRange:.08,position:{x:43,y:0,z:44-.92}};let cuts=0;f.api.bindTargets({get:()=>target,canMove:()=>true,performEffect:()=>{cuts++;target.cut=true;return true;}});
 assert(f.api.command('cut_fence',target).ok);let maxX=m.c*4.1,minX=maxX,planned=null;
 for(let i=0;i<700&&!cuts;i++){const before={r:m.r,c:m.c};f.tick();assert(f.ctx._npcPathPassable(before.r,before.c,m.r,m.c,f.ctx.npcPassableForSnitch));assert(!native.pointBlocked(m.c*4.1,m.r*4.1,.738));maxX=Math.max(maxX,m.c*4.1);minX=Math.min(minX,m.c*4.1);planned=m._mercenaryPath?.stats||planned;}
 assert.equal(cuts,1);assert(maxX>=46.858||minX<=39.142,'must walk past the side of the complete cage');assert(planned?.slices>1,'search continues across bounded update slices');assert(planned.expanded<2400);assert.equal(f.api.getAction(m.id),null);
});
test('actual source footprint rejects obsolete fence approach but permits physical front clearance',async()=>{
 const f=await fixture(),m=f.recruit('engineer');nativeCage(f);m.c=43/4.1;m.r=42/4.1;
 assert.equal(f.ctx._npcBodyPassable((44-.65)/4.1,43/4.1,f.ctx.npcPassableForSnitch),false);assert.equal(f.ctx._npcPathPassable(42/4.1,43/4.1,43/4.1,43/4.1,f.ctx.npcPassableForSnitch),true);
});
test('blocked specialist search is bounded and follow immediately clears it without teleporting',async()=>{
 const f=await fixture(),m=f.recruit('engineer'),target={id:'blocked',kind:'fence',cuttable:true,workRange:.2,position:{x:55,y:0,z:41}};f.api.bindTargets({get:()=>target,canMove:()=>false});const before={r:m.r,c:m.c};assert(f.api.command('cut_fence',target).ok);for(let i=0;i<10;i++)f.tick();assert.deepEqual({r:m.r,c:m.c},before);assert(m._mercenaryPath);assert(f.api.follow().ok);assert.equal(m._mercenaryPath,null);assert.equal(f.api.getAction(m.id),null);
});
for(const mode of ['rally','follow'])test(`all five ${mode} members walk around cage, keep orders and settle without side-to-side oscillation`,async()=>{
 const f=await fixture();for(const p of ['medic','bruiser','engineer','safecracker','demolitions'])f.recruit(p);const native=nativeCage(f);f.api.bindTargets({canMove:()=>true});f.ctx.player.c=43/4.1;f.ctx.player.r=38/4.1;
 f.ctx._myGang.forEach((m,i)=>{m.c=(39+i*2)/4.1;m.r=52/4.1;});assert(mode==='rally'?f.api.rally({x:43,y:0,z:39}).ok:f.api.follow().ok);
 for(let i=0;i<1100;i++){f.tick();for(const m of f.ctx._myGang)assert(!native.pointBlocked(m.c*4.1,m.r*4.1,.738));}
 for(const m of f.ctx._myGang){assert(m.r*4.1<43.14,JSON.stringify({mode,id:m.id,x:m.c*4.1,z:m.r*4.1,route:m._mercenaryPath}));assert.equal(f.api.getRoster().members.find(r=>r.id===m.id).order,mode);}
 const settled=f.ctx._myGang.map(m=>({r:m.r,c:m.c}));for(let i=0;i<30;i++)f.tick();for(let i=0;i<5;i++)assert(Math.hypot(f.ctx._myGang[i].r-settled[i].r,f.ctx._myGang[i].c-settled[i].c)*4.1<.12);
});
test('bounded source CPU comparison retains real collision predicate and fixes the former back-side failure',async t=>{
 const results=[];
 for(const enabled of [false,true]){
  const factory=Function('vm','module','script','assert',fixtureText.slice(fixtureText.indexOf('async function fixture('),fixtureText.indexOf('\nfor(const [profession'))+';return fixture;')(vm,enabled?module:{...module,createMercenaryRoutePlanner:undefined},script,assert);
  const f=await factory(),m=f.recruit('engineer');nativeCage(f);m.c=43/4.1;m.r=52/4.1;let cuts=0;
  const target={id:'perf-cage',kind:'fence',cuttable:true,workRange:.08,position:{x:43,y:0,z:44-.92}};f.api.bindTargets({get:()=>target,canMove:()=>true,performEffect:()=>{cuts++;target.cut=true;return true;}});f.api.command('cut_fence',target);
  const times=[];for(let i=0;i<700;i++){const start=performance.now();f.tick();times.push(performance.now()-start);}times.sort((a,b)=>a-b);results.push({planner:enabled,cuts,p50ms:+times[350].toFixed(4),p95ms:+times[665].toFixed(4)});
 }
 assert.equal(results[0].cuts,0);assert.equal(results[1].cuts,1);t.diagnostic(JSON.stringify({sourceCpuOnly:results,limitations:'Synthetic same loaded collision fixture; no graphics or total game FPS.'}));
});
test('actual demo car footprint requires its 1.28m half-width, then planting and safe retreat produce one explosion',async()=>{
 const f=await fixture(),m=f.recruit('demolitions'),x=45,z=49;nativeCage(f,[[x-1.28,x+1.28,z-2.24,z+2.24]]);m.c=(x-7)/4.1;m.r=(z-8)/4.1;
 assert.equal(f.ctx._npcBodyPassable(z/4.1,(x-1-.84-.068)/4.1,f.ctx.npcPassableForSnitch),false,'fallback width1 work anchor remains inside actual collision footprint');
 const target={id:'car-real-profile',kind:'vehicle',valid:true,workRange:.08,position:{x:x-1.28-.84,y:0,z},center:{x,y:0,z}};let explosions=0;f.api.bindTargets({get:()=>target,canMove:()=>true,performEffect:()=>{assert(Math.hypot(m.c*4.1-x,m.r*4.1-z)>=8);explosions++;return true;}});assert(f.api.command('plant_bomb',target).ok);
 let armed=false;for(let i=0;i<800&&!explosions;i++){const before={r:m.r,c:m.c};f.tick();assert(f.ctx._npcPathPassable(before.r,before.c,m.r,m.c,f.ctx.npcPassableForSnitch));armed=armed||!!f.api.getAction(m.id)?.armed;}
 assert(armed);assert.equal(explosions,1);assert.equal(f.api.getAction(m.id),null);
});
