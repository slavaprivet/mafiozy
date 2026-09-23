import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import * as runtimeModule from './mercenary_core.mjs';
import {createNpcNativeNavigation} from './npc_native_navigation.mjs';
import {createMercenaryVehicleBridge} from './mercenary_vehicle_bridge.mjs';

const read=name=>fs.readFileSync(new URL(name,import.meta.url),'utf8').replace(/\r\n/g,'\n');
const source=read('./mercenary_world.js');
const integrated=source.includes('stagedFollow:longFollowFactory(');
assert(integrated,'exercise the complete integrated production adapter');
const after=source;
const stageStart=after.indexOf('  // Far followers use local stages'),stageEnd=after.indexOf('\n  if(!route){',stageStart);
assert(stageStart>0&&stageEnd>stageStart);
// Counterfactual baseline disables only the new host stage dispatch; the
// production action, movement, crew and collision contracts remain intact.
const before=after.slice(0,stageStart)+after.slice(stageEnd);
const module=runtimeModule;
const world=read('../../../world.html');
const physicalFunctions=['_npcBodyPassable','_npcPathPassable'].map(name=>world.match(new RegExp('^function '+name+'\\([^]*?^}','m'))?.[0]).join('\n');
const audit=read('./test_mercenary_long_follow23_candidate.mjs');
const physics=Function('vm','physicalFunctions','distance',audit.slice(audit.indexOf('function physics('),audit.indexOf('\nfunction walkScene'))+';return physics;')(vm,physicalFunctions,(a,b)=>Math.hypot(a.x-b.x,a.z-b.z));
const fixtureText=read('./test_mercenary_rally_actions.mjs');
const fixtureBody=fixtureText.slice(fixtureText.indexOf('async function fixture('),fixtureText.indexOf('\nfor(const [profession'));

async function fixture({enabled=true,walls=[],five=false}={}){
  const script=(enabled?after:before).replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');
  const factory=Function('vm','module','script','assert',fixtureBody+';return fixture;')(vm,module,script,assert);
  const f=await factory({qa:true}),crew=(five?['medic','bruiser','safecracker','engineer','demolitions']:['engineer']).map(p=>f.recruit(p));
  const native=physics(walls,f.ctx);let maxQuery=0,calls=0;
  const actual=f.ctx._npcPathPassable;f.ctx._npcPathPassable=(r,c,r1,c1,pass)=>{calls++;maxQuery=Math.max(maxQuery,Math.hypot(r1-r,c1-c)*4.1);return actual(r,c,r1,c1,pass);};
  f.api.bindTargets({canMove:()=>true,groundHeight:()=>0});
  crew.forEach((m,i)=>Object.assign(m,{c:40/4.1,r:(60+i*3)/4.1}));Object.assign(f.ctx.player,{c:218/4.1,r:66/4.1,ang:0});assert(f.api.follow().ok);
  return {...f,crew,native,get maxQuery(){return maxQuery;},get calls(){return calls;}};
}

function run(f,frames,{leader=null,dt=.05}={}){
  let maxStep=0,arrived=0,maxFrameExpanded=0;const times=[];
  for(let frame=0;frame<frames;frame++){
    leader?.(frame);const origins=f.crew.map(m=>({r:m.r,c:m.c,stage:m._mercenaryPath?.stagedFollow,expanded:m._mercenaryPath?.stagedFollow?.stats.expanded||0}));
    const begin=performance.now();f.tick(dt);times.push(performance.now()-begin);
    let frameExpanded=0;
    for(let i=0;i<f.crew.length;i++){
      const m=f.crew[i],origin=origins[i],step=Math.hypot(m.r-origin.r,m.c-origin.c)*4.1;
      maxStep=Math.max(maxStep,step);assert(step<=5.5*Math.min(.3,dt)+1e-7,'full host remains within its ordinary bounded movement steps');
      assert(!f.native.blocked(m.c*4.1,m.r*4.1,.738),'actual host footprint remains clear');
      for(let j=i+1;j<f.crew.length;j++)assert(Math.hypot(m.r-f.crew[j].r,m.c-f.crew[j].c)*4.1>=1.1-1e-7,'crew separation');
      const stage=m._mercenaryPath?.stagedFollow;if(stage)frameExpanded+=stage.stats.expanded-(stage===origin.stage?origin.expanded:0);
    }
    maxFrameExpanded=Math.max(maxFrameExpanded,frameExpanded);assert(frameExpanded<=f.crew.length*8);
    arrived=f.crew.filter(m=>Math.hypot(m.r-f.ctx.player.r,m.c-f.ctx.player.c)*4.1<7&&m._mercenaryMoveReason==='arrived').length;
    if(arrived===f.crew.length&&!leader)break;
  }
  times.sort((a,b)=>a-b);return {arrived,maxStep,maxFrameExpanded,cpuP50ms:times[Math.floor(times.length*.5)],cpuP95ms:times[Math.floor(times.length*.95)],frames:times.length,distances:f.crew.map(m=>Math.hypot(m.r-f.ctx.player.r,m.c-f.ctx.player.c)*4.1),reasons:f.crew.map(m=>m._mercenaryMoveReason)};
}

test('full actual host before/after: five distant followers negotiate solids and rejoin the formation',async t=>{
  const results=[];
  for(const enabled of [false,true]){
    const f=await fixture({enabled,five:true,walls:[[105,112,52,80],[170,177,60,73]]});
    const result=run(f,3600);results.push({enabled,...result,maxQueryMeters:f.maxQuery});
    if(enabled){assert.equal(result.arrived,5,JSON.stringify(result));assert(f.maxQuery<=7+1e-7,'no unbudgeted long direct sweep before stages');}
    else{assert.equal(result.arrived,0);assert(result.reasons.every(r=>r==='no_route'));assert(f.maxQuery>170);}
  }
  t.diagnostic(JSON.stringify({actualHostCpuOnly:results,integrated}));
});

for(const fps of [7,15])test(`full host: five long followers and moving leader at ${fps} FPS`,async t=>{
  const f=await fixture({five:true,walls:[[105,112,52,80],[170,177,60,73]]});
  run(f,fps*35,{dt:1/fps,leader:()=>{f.ctx.player.r+=.25/fps/4.1;}});
  const result=run(f,fps*220,{dt:1/fps});assert.equal(result.arrived,5,JSON.stringify(result));
  t.diagnostic(JSON.stringify({fps,...result}));
});

test('full host follows leader drift, including a large retarget, without restarting every frame',async()=>{
  const f=await fixture({five:true,walls:[[105,112,52,80]]});let stages=new Set();
  run(f,700,{leader:frame=>{
    if(frame<400)f.ctx.player.r+=.012/4.1;
    if(frame===400)f.ctx.player.r+=20/4.1;
    for(const m of f.crew){if(m._mercenaryPath?.stagedFollow)stages.add(m._mercenaryPath.stagedFollow);}
  }});
  const result=run(f,3000);assert.equal(result.arrived,5,JSON.stringify(result));assert(stages.size<40,'no per-frame route recreation');
});

test('full host physical blocker cancels the old stage and safely replans',async()=>{
  const walls=[],f=await fixture({walls}),m=f.crew[0];
  for(let i=0;i<50&&m._mercenaryMoveReason!=='route_moving';i++)f.tick(.05);
  assert.equal(m._mercenaryMoveReason,'route_moving');const old=m._mercenaryPath.stagedFollow,oldSearches=old.stats.searches;
  const x=m.c*4.1;walls.push([x+1.5,x+1.6,m.r*4.1-3,m.r*4.1+3]);
  const result=run(f,2500);assert.equal(result.arrived,1,JSON.stringify(result));assert(old.stats.searches>oldSearches,'new native blocker caused a fresh bounded search');
});

test('full host clears staged state on rally, follow cancellation, action, downed and hospital transitions',async()=>{
  const f=await fixture(),m=f.crew[0];
  const start=()=>{m.hp=80;m.dead=false;m._mercenaryHospital=false;m._mercenaryOrder='follow';m.r=60/4.1;m.c=40/4.1;f.api.follow();f.tick(.05);assert(m._mercenaryPath?.stagedFollow);};
  start();assert(f.api.rally({x:215,y:0,z:65}).ok);assert.equal(m._mercenaryPath,null);
  start();f.api.follow();assert.equal(m._mercenaryPath,null);
  start();const target={id:'panel',kind:'power_panel',powered:true,position:{x:43,y:0,z:60}};f.api.bindTargets({canMove:()=>true,get:()=>target});assert(f.api.command('disable_power',target).ok);f.tick(.05);assert(!m._mercenaryPath?.stagedFollow);assert(f.api.cancelCommand(m.id).ok);
  start();m.hp=0;f.tick(.05);assert.equal(m._mercenaryPath,null);
  const separate=await fixture(),other=separate.crew[0];separate.tick(.05);assert(other._mercenaryPath?.stagedFollow);other._mercenaryHospital=true;separate.tick(.05);assert.equal(other._mercenaryPath,null);
});

test('full host clears staged state when the fighter becomes a vehicle passenger',async()=>{
  const f=await fixture(),m=f.crew[0];f.tick(.05);assert(m._mercenaryPath?.stagedFollow);const retired=m._mercenaryPath.stagedFollow;
  const actor={object:{parent:{},position:{x:m.c*4.1+2,z:m.r*4.1,y:0},rotation:{y:0},scale:{x:1,y:1,z:1}},profile:{halfWidth:1},seats:[{id:'front_right',canDrive:false,side:-1,doorDistance:2,doorFront:0,anchor:{side:-.5,front:0,y:.7}}],setDoorById(){}};
  let playerVehicle={id:'fleet:test-car',seatId:'front_left',ready:true};
  const squadTransport=createMercenaryVehicleBridge({canCross:(id,from,to)=>f.ctx._walkNpcNavigationResolver({mode:'sweep',from,to,radius:.18}).blocked===false,getFleet:()=>({records:[{id:'test-car',car:actor,state:{speed:0}}]}),getPlayer:()=>playerVehicle});
  f.api.bindTargets({squadTransport,canMove:()=>true,groundHeight:()=>0,safeCatchupPoint:p=>({ok:true,point:{...p,y:0}})});
  f.ctx._civilianTripDoorPath=(trip,r,c,r1,c1)=>f.ctx._npcPathPassable(r,c,r1,c1);
  f.ctx.player.r=m.r;f.ctx.player.c=m.c;
  f.tick(.05);assert(m._mercenaryVehicleSeat);assert.equal(m._mercenaryVehiclePhase,'board');assert.equal(m._mercenaryPath,null);
  for(let i=0;i<18;i++)f.tick(.05);assert.equal(m._mercenaryVehiclePhase,'drive');
  playerVehicle=null;for(let i=0;i<100&&m._mercenaryVehicleSeat;i++)f.tick(.05);
  assert(!m._mercenaryVehicleSeat);assert.notEqual(m._mercenaryPath?.stagedFollow,retired);
});

test('full host shares its original 1.5ms deadline among five staged searches',async()=>{
  const f=await fixture({five:true});let charged=0;const originalClock=f.ctx.performance.now,actualPath=f.ctx._npcPathPassable;
  f.ctx.performance.now=()=>originalClock()+charged;
  f.ctx._npcPathPassable=(...args)=>{charged+=.012;return actualPath(...args);};
  for(let frame=0;frame<8;frame++){
    const start=charged;f.tick(.05);
    // Budget checks are between local node expansions. Retain the existing
    // one-expansion overrun and bounded formation validation overhead.
    assert(charged-start<1.61,JSON.stringify({frame,charged:charged-start}));
  }
  assert(f.crew.every(m=>m._mercenaryPath?.stats.expanded>0),'actual rotating host roster gives every search progress');
});

test('full host keeps fully enclosed follower inside solids and bounds failed work',async()=>{
  const f=await fixture({walls:[[38,39,58,62],[41,42,58,62],[38,42,58,59],[38,42,61,62]]}),m=f.crew[0],origin={r:m.r,c:m.c};
  const result=run(f,500);assert.equal(result.arrived,0);assert.deepEqual({r:m.r,c:m.c},origin);
  assert(m._mercenaryPath?.stats.maxSearchExpanded<2400);assert(result.maxFrameExpanded<=8);
});

test('full actual water host leaves water then completes a >48m follow',async t=>{
  const waterSource=read('./test_mercenary_water_follow23.mjs');
  const body=waterSource.slice(waterSource.indexOf('async function sourceFixture('),waterSource.indexOf("\ntest('water source mirror"));
  const water=world.slice(world.indexOf('// NPC_NATIVE_WATER_ROUTING_START'),world.indexOf('// NPC_NATIVE_WATER_ROUTING_END'));
  const names=['npcPassable','npcPassableForSnitch','_npcBodyPassable','_npcPathPassable','_clearNpcRoute','_npcEffectiveSpeed','_npcPacedSpeed'];
  const functions=names.map(name=>world.match(new RegExp('^function '+name+'\\([^]*?^}','m'))?.[0]);functions[functions.length-1]=world.match(/^function _npcPacedSpeed\([^\n]+/m)?.[0];
  const routeBudget=world.slice(world.indexOf('let _npcRouteWorkFrame='),world.indexOf('function _planNpcRouteTo('));
  const make=Function('module','source','vm','assert','createNpcNativeNavigation','water','functions','routeBudget',body+';return fixture;')(module,after,vm,assert,createNpcNativeNavigation,water,functions,routeBudget);
  const f=await make({player:{r:40,c:40}});Object.assign(f.ctx,{MAP:Array.from({length:128},()=>Array(128).fill(9)),MAP_ROWS:128,MAP_COLS:128});f.api.follow();
  let dryAt=null,seenStage=false;
  for(let i=0;i<3500;i++){
    const from={r:f.m.r,c:f.m.c},wasWet=f.bodyDepth(f.m)>.025;f.tick(.05);
    assert(Math.hypot(f.m.r-from.r,f.m.c-from.c)*4.1<=.275+1e-7);
    if(wasWet&&f.bodyDepth(f.m)>.025)assert(!f.m._mercenaryPath?.stagedFollow,'water owns movement before dry path');
    if(f.bodyDepth(f.m)<=.025&&dryAt===null)dryAt=i*.05;
    if(f.m._mercenaryPath?.stagedFollow)seenStage=true;
    if(f.m._mercenaryMoveReason==='arrived'&&Math.hypot(f.m.r-40,f.m.c-40)*4.1<7)break;
  }
  assert(dryAt!==null);assert.equal(f.bodyDepth(f.m),0);assert(seenStage);
  assert(Math.hypot(f.m.r-40,f.m.c-40)*4.1<7,JSON.stringify({m:f.api.getMember(f.m.id),reason:f.m._mercenaryMoveReason}));
  t.diagnostic(JSON.stringify({dryAt,reason:f.m._mercenaryMoveReason,distanceToLeader:Math.hypot(f.m.r-40,f.m.c-40)*4.1}));
});
