import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import {performance} from 'node:perf_hooks';
const world=fs.readFileSync('world.html','utf8'),helper=fs.readFileSync('assets/maps/city_rebuild_v1/npc_city_population_source.js','utf8');
const fn=name=>{const start=world.indexOf('function '+name+'(');assert(start>=0,name);let p=world.indexOf('{',start),d=1;for(p++;d;p++){if(world[p]==='{')d++;if(world[p]==='}')d--;}return world.slice(start,p);};
let time=1000,native=true,seed=39;const math=Object.create(Math);math.random=()=>((seed=Math.imul(seed,1664525)+1013904223>>>0)/4294967296);
const ctx={Math:math,Number,Uint16Array,NPCS:[],MAP_ROWS:200,MAP_COLS:180,MAP:Array.from({length:200},()=>Array(180).fill(9)),player:{r:100,c:90},performance:{now:()=>time},NPC_RESPAWN_MIN_DIST:42,TARGET_NPC_COUNT:96,getGameHour:()=>2,_walkRendererActive:()=>native,inArena:()=>false,inLair:()=>false,_pickArchetype:()=>'worker',NPC_ARCHETYPES:{worker:{speedRange:[.6,1]}},_initNpcEmotions(){},_npcEffectiveSpeed:()=>1,_npcRouteWalkBlocked:()=>false};
// Same body/segment sweep as production, with a thin wall and a water bank.
ctx.npcPassable=ctx.npcPassableForSnitch=(r,c)=>!(c>10&&c<10.08)&&r<180;
vm.createContext(ctx);vm.runInContext('let _residentSerial=0;',ctx);
for(const name of ['_npcBodyPassable','_npcPathPassable','spawnNpc','_targetNpcCount'])vm.runInContext(fn(name),ctx);vm.runInContext(helper,ctx);
assert.equal(ctx._targetNpcCount(),288);native=false;assert.equal(ctx._targetNpcCount(),28);native=true;
for(let i=0;i<160&&ctx.NPCS.length<288;i++){const previous=ctx.NPCS.length;assert(ctx._npcNativePopulationFill(288-previous,time)<=3);assert(ctx.NPCS.length-previous<=3);time+=1200;}
assert.equal(ctx.NPCS.length,288);assert.equal(new Set(ctx.NPCS.map(n=>n.id)).size,288);
assert(ctx.NPCS.every(n=>Math.hypot(n.r-100,n.c-90)>=42),'no visible creation');
const sectors=ctx._npcCityPopulationCensus();assert(sectors.filter(n=>n>0).length>=26,'residents distributed around city, excluding visible spawn exclusion');
const special={id:'boss',r:5,c:5,_uniqueNpc:true,hp:100};ctx.NPCS.push(special);assert.equal(ctx._npcCityPopulationCensus().reduce((a,b)=>a+b),288,'story roles remain additive');
assert.equal(special.hp,100);assert.equal(ctx.NPCS.at(-1),special);
const walker={r:20,c:9,tr:20,tc:11,walkPhase:0};assert.equal(ctx._npcRoutineStep(walker,3,ctx.npcPassable),false,'far cadence cannot tunnel through thin obstruction');assert.equal(walker.c,9);
walker.c=11;walker.tc=11.1;assert(ctx._npcRoutineStep(walker,.25,ctx.npcPassable));assert.equal(walker.c,11.1,'long frame cannot overshoot target then oscillate');assert.equal(walker.walking,true);
const water={r:179,c:20,tr:181,tc:20,walkPhase:0};assert(!ctx._npcRoutineStep(water,3,ctx.npcPassable));assert.equal(water.r,179);
const samples=[];for(let i=0;i<160;i++){const start=performance.now();for(let j=0;j<20;j++){const census=ctx._npcCityPopulationCensus();for(let k=0;k<3;k++)ctx._npcCityLeastPopulatedSector(census);}samples.push((performance.now()-start)/20);}samples.sort((a,b)=>a-b);
ctx.RESIDENTS_INDOORS=[];ctx.RESIDENT_RESPAWN_BACKLOG=[];ctx._placeSaidInCity=()=>{};let routeCalls=0;ctx.pickNpcWaypoint=()=>routeCalls++;vm.runInContext(fn('initNpcs'),ctx);ctx.initNpcs();assert.equal(ctx.NPCS.length,288);assert.equal(routeCalls,0,'initial native population does not launch obsolete route searches in one burst');assert(ctx.NPCS.every(n=>n._npcInitialPlacementPending),'unvalidated initial positions cannot be presented');ctx._walkNpcNavigationResolver=()=>({blocked:false,depth:0});ctx.initNpcs();assert(ctx.NPCS.every(n=>!n._npcInitialPlacementPending),'reinitialization with ready native geometry does not strand residents pending forever');native=false;ctx.initNpcs();assert.equal(ctx.NPCS.length,96);assert.equal(routeCalls,96,'legacy init preserved');
assert(world.includes('_npcNativePopulationFill(need,now);return;'));
console.log(JSON.stringify({pass:true,residents:288,occupiedSectors:sectors.filter(n=>n>0).length,maxBirthsPerTick:3,censusCpuMs:{p50:samples[80],p95:samples[152]},limits:'Population scheduling and actual source body sweep; not loaded-city FPS/full AI cost'}));
