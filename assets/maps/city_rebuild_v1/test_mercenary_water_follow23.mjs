import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import * as module from './mercenary_core.mjs';
import {createNpcNativeNavigation} from './npc_native_navigation.mjs';

const base = new URL('./', import.meta.url);
const world = fs.readFileSync(new URL('../../../world.html', import.meta.url), 'utf8');
const source = fs.readFileSync(new URL('mercenary_world.js', base), 'utf8');
const water = world.slice(world.indexOf('// NPC_NATIVE_WATER_ROUTING_START'), world.indexOf('// NPC_NATIVE_WATER_ROUTING_END'));
assert(water.includes('function _npcWaterEscape('));
const names=['npcPassable','npcPassableForSnitch','_npcBodyPassable','_npcPathPassable','_clearNpcRoute','_npcEffectiveSpeed','_npcPacedSpeed'];
const functions=names.map(name=>world.match(new RegExp('^function '+name+'\\([^]*?^}', 'm'))?.[0]);
// _npcPacedSpeed is a one-line function, so do not use a multi-line end anchor.
functions[functions.length-1] = world.match(/^function _npcPacedSpeed\([^\n]+/m)?.[0];
assert(functions.every(Boolean));
const routeBudget=world.slice(world.indexOf('let _npcRouteWorkFrame='),world.indexOf('function _planNpcRouteTo('));

// Execute the complete production adapter. Only its browser import boundary is
// supplied by the Node module namespace; no movement function is replaced.
async function sourceFixture({hostname='localhost',query='?mercenaryqa=1'}={}) {
  let clock=1000;const storage=new Map();
  const ctx={module,URL,Promise,console,Date:{now:()=>clock*1000},performance:{now:()=>clock*1000},
    document:{getElementById:()=>null,documentElement:{dataset:{}},currentScript:{src:'http://localhost/assets/maps/city_rebuild_v1/mercenary_world.js'}},
    location:{origin:'http://'+hostname,hostname,href:'http://'+hostname+'/world.html'+query},
    window:{MAFIOZI_RENDERER_CONFIG:{worldScale:4.1}},localStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v)},
    _LOCAL_PREVIEW:true,_serverAuthoritativeAmmo:false,_customGang:null,_myGang:[],
    NPCS:Array.from({length:8},(_,i)=>({id:'civilian'+i,r:10,c:10+i*.1,hp:80,max_hp:80,name:'NPC '+i,look:{hair:i}})),
    player:{r:10,c:10},myHp:100,myDead:false,GANG_MAX:5,_hiredBotIds:new Set(),_inventoryItems:[],currentWeapon:null,QP:{cash:500},
    _saveGang(){},_syncMyWeaponsFromInventory(){},_npcBodyPassable:()=>true,_npcPathPassable:()=>true};
  const importBoundary="import(new URL('./mercenary_core.mjs',scriptUrl).href)";
  assert.equal(source.split(importBoundary).length-1,1);
  vm.createContext(ctx);vm.runInContext(source.replace(importBoundary,'Promise.resolve(module)'),ctx);
  await new Promise(resolve=>setImmediate(resolve));const api=ctx.window.MafioziMercenaries;
  const recruit=profession=>{const row=api.getRoster().candidates.find(item=>item.profession===profession);assert(row);assert(api.recruit(row.id).ok);return ctx._myGang.at(-1);};
  return {ctx,api,recruit,storage,tick:(dt=.05)=>{clock+=dt;api.tick(.05);}};
}

async function fixture({walls=[], start={r:9,c:9}, player={r:9,c:16}, constant=false,runtime}={}) {
  const f=await sourceFixture(runtime);
  const m=f.recruit('engineer');Object.assign(m,start);Object.assign(f.ctx.player,player,{ang:0});
  const depth=({r,c})=>r>=7&&r<=12&&c>=7&&c<=12?(constant?1:Math.min(r-7,12-r,c-7,12-c)+.1):0;
  const blocked=({r,c})=>walls.some(([r0,r1,c0,c1])=>r>r0&&r<r1&&c>c0&&c<c1);
  const bodies=walls.map(([r0,r1,c0,c1],i)=>({id:'test-wall-'+i,polygonCR:[[c0,r0],[c1,r0],[c1,r1],[c0,r1]],minY:0,maxY:3}));
  const native=createNpcNativeNavigation({worldScale:4.1,waterAt:(x,z)=>{const d=depth({r:z/4.1,c:x/4.1});return d?{level:d,depth:d}:null;},groundHeight:()=>0,bodiesAt:()=>bodies,bodiesInBounds:()=>bodies,containsBody:(body,r,c)=>{const p=body.polygonCR;return r>p[0][1]&&r<p[2][1]&&c>p[0][0]&&c<p[2][0];},terrainAllows:()=>true,surfaceAt:()=> 'land'});
  Object.assign(f.ctx,{MAP:Array.from({length:32},()=>Array(32).fill(9)),MAP_ROWS:32,MAP_COLS:32,isBlockedPed:()=>false,_inPrisonIslandRestrictedZone:()=>false,inArena:()=>false,inLair:()=>false,_cityV3NextSurfaceAt:()=>false,_inPitCorridor:()=>false,NPC_HERO_PACE:{walk:5/4.1,run:8/4.1},nativeQuery:native.query});
  vm.runInContext(water+'\n'+routeBudget+'\n'+functions.join('\n')+`\n_walkNpcNavigationResolver=nativeQuery;
  let waterSearchCalls=0;const actualWaterSearch=_npcWaterSearchStep;
  _npcWaterSearchStep=function(...args){waterSearchCalls++;return actualWaterSearch(...args);};
  globalThis.waterApi={escape:_npcWaterEscape,depth:_npcRouteWaterDepth,body:_npcBodyPassable,pass:npcPassableForSnitch,
    diagnostics:()=>({searchCalls:waterSearchCalls,navigation:{..._npcNavigationStats},route:{..._npcRouteWorkStats}})};`,f.ctx);
  f.api.bindTargets({groundHeight:()=>0,canMove:(a,b)=>{const steps=Math.max(1,Math.ceil(Math.hypot(a.x-b.x,a.z-b.z)/.2));for(let i=1;i<=steps;i++){const t=i/steps,p={r:(a.z+(b.z-a.z)*t)/4.1,c:(a.x+(b.x-a.x)*t)/4.1};if(depth(p)>.025||blocked(p))return false;}return true;}});
  f.api.follow();f.api.tick(0);
  const tick=f.tick;f.tick=(dt)=>{native.beginFrame();tick(dt);};
  const bodyDepth=n=>Math.max(depth(n),...[[-.18,-.18],[-.18,.18],[.18,-.18],[.18,.18]].map(([dr,dc])=>depth({r:n.r+dr,c:n.c+dc})));
  return {...f,m,depth,bodyDepth,blocked,native};
}

test('water source mirror exactly matches the scoped production block',()=>{
  const marker='// NPC_NATIVE_WATER_ROUTING_END';
  const mirror=fs.readFileSync(new URL('npc_native_water_source.js',base),'utf8').replaceAll('\r\n','\n').trim();
  assert.equal(mirror,(water+marker).replaceAll('\r\n','\n').trim());
});

for(const fps of [5,7,10,15,30,60])test(`production source: physical shore exit then follows player at ${fps} FPS`,async t=>{
  const f=await fixture(),m=f.m,id=m.id,name=m.name,weapon=m.weapon,start={r:m.r,c:m.c};let travel=0,dryAt=null;const cpu=[];
  for(let i=0;i<fps*35;i++){
    const before={r:m.r,c:m.c},previousDepth=f.bodyDepth(m),begin=performance.now();f.tick(1/fps);cpu.push(performance.now()-begin);
    const moved=Math.hypot(m.r-before.r,m.c-before.c)*4.1;travel+=moved;
    assert(moved<=5.5/fps+1e-7,'bounded physical step');assert(!f.blocked(m));
    if(previousDepth>.025)assert(f.bodyDepth(m)<=previousDepth+.0021,'no movement toward deeper water');
    if(f.bodyDepth(m)<=.025&&dryAt===null)dryAt=i/fps;
  }
  assert(dryAt!==null);assert(travel>Math.hypot(m.r-start.r,m.c-start.c)*4.1-.001);assert.equal(m.id,id);assert.equal(m.name,name);assert.equal(m.weapon,weapon);assert.equal(m._mercenaryOrder,'follow');
  assert.equal(f.bodyDepth(m),0);assert(Math.hypot(m.r-f.ctx.player.r,m.c-f.ctx.player.c)*4.1<7,'returns to leader');assert.equal(m._mercenaryMoveReason,'arrived');
  cpu.sort((a,b)=>a-b);t.diagnostic(JSON.stringify({fps,dryAt,travelMeters:+travel.toFixed(3),distanceToLeaderMeters:+(Math.hypot(m.r-f.ctx.player.r,m.c-f.ctx.player.c)*4.1).toFixed(3),cpuP50ms:cpu[Math.floor(cpu.length*.5)],cpuP95ms:cpu[Math.floor(cpu.length*.95)]}));
});

test('production clears body at shoreline and does not re-enter water for ordinary follow',async()=>{
  const f=await fixture({start:{r:9,c:6.95},player:{r:9,c:3}});
  for(let i=0;i<200;i++)f.tick(.1);
  assert.equal(f.bodyDepth(f.m),0);assert(Math.hypot(f.m.r-f.ctx.player.r,f.m.c-f.ctx.player.c)*4.1<7);assert.equal(f.m._mercenaryMoveReason,'arrived');
});

test('production selects another shore when preferred ray meets a wall',async t=>{
  const f=await fixture({walls:[[7.1,10.1,10.2,10.5]]});let avoided=false;
  for(let i=0;i<500;i++){f.tick(.1);assert(!f.blocked(f.m));if(f.m.r<7||f.m.r>10.8)avoided=true;}
  assert(avoided);assert.equal(f.bodyDepth(f.m),0);assert(Math.hypot(f.m.r-f.ctx.player.r,f.m.c-f.ctx.player.c)*4.1<7);
  t.diagnostic(JSON.stringify({end:{r:f.m.r,c:f.m.c},reason:f.m._mercenaryMoveReason}));
});

test('production preserves native thin-wall swept veto and refuses an enclosed shore',async()=>{
  const f=await fixture({walls:[[6.5,12.5,12.1,12.105],[6.5,12.5,6.8,6.805],[6.8,6.805,6.5,12.5],[12.1,12.105,6.5,12.5]],constant:true});
  for(let i=0;i<200;i++){f.tick(.1);assert(f.m.r>6.8&&f.m.r<12.1&&f.m.c>6.8&&f.m.c<12.1);}
  assert(f.bodyDepth(f.m)>0);assert(f.native.diagnostics().sweepBlocked>0);assert.equal(f.m._mercenaryMoveReason,'water_egress_pending');
});

test('production does not create a client movement path in server/custom gang modes',async()=>{
  for(const flag of ['_serverAuthoritativeAmmo','_customGang']){
    const f=await fixture();f.ctx[flag]=flag==='_customGang'?{id:'authority-owned'}:true;const before={r:f.m.r,c:f.m.c};
    for(let i=0;i<20;i++)f.tick(.1);assert.deepEqual({r:f.m.r,c:f.m.c},before);
  }
});

test('five production followers leave water without overlapping and catch the leader',async t=>{
  const f=await fixture();
  Object.assign(f.ctx.player,{r:10,c:10});
  const crew=[f.m,...['medic','bruiser','safecracker','demolitions'].map(p=>f.recruit(p))];
  Object.assign(f.ctx.player,{r:9,c:14});
  crew.forEach((m,i)=>Object.assign(m,{r:8+i*.7,c:9}));f.api.follow();
  for(let i=0;i<600;i++){
    const before=crew.map(m=>({r:m.r,c:m.c}));f.tick(.1);
    for(let j=0;j<crew.length;j++){
      assert(Math.hypot(crew[j].r-before[j].r,crew[j].c-before[j].c)*4.1<=.55+1e-7);
      for(let k=j+1;k<crew.length;k++)assert(Math.hypot(crew[j].r-crew[k].r,crew[j].c-crew[k].c)*4.1>=1.1-1e-7,'crew body separation preserved');
    }
  }
  const results=crew.map(m=>({id:m.id,depth:f.bodyDepth(m),distance:Math.hypot(m.r-f.ctx.player.r,m.c-f.ctx.player.c)*4.1,reason:m._mercenaryMoveReason}));
  t.diagnostic(JSON.stringify(results));assert(results.every(m=>m.depth===0&&m.distance<7&&m.reason==='arrived'));
});

for(const fps of [7,15,60])test(`three overlapping hired followers separate and escape without deadlock at ${fps} FPS`,async t=>{
  const f=await fixture();Object.assign(f.ctx.player,{r:10,c:10});
  const crew=[f.m,...['bruiser','safecracker'].map(p=>f.recruit(p))];Object.assign(f.ctx.player,{r:9,c:16});
  crew.forEach(m=>{Object.assign(m,{r:9,c:9});m._mercenaryPath=null;});f.api.follow();
  const origin=crew.map(m=>({id:m.id,r:m.r,c:m.c,weapon:m.weapon}));let separatedAt=null;
  for(let i=0;i<fps*45;i++){
    const before=crew.map(m=>({r:m.r,c:m.c}));f.tick(1/fps);
    for(let j=0;j<crew.length;j++){
      assert(Math.hypot(crew[j].r-before[j].r,crew[j].c-before[j].c)*4.1<=5.5/fps+1e-7,'no teleport on overlap recovery');
      for(let k=j+1;k<crew.length;k++){
        const previous=Math.hypot(before[j].r-before[k].r,before[j].c-before[k].c)*4.1,current=Math.hypot(crew[j].r-crew[k].r,crew[j].c-crew[k].c)*4.1;
        assert(current>=Math.min(previous,1.1)-1e-7,'existing overlap may only improve, established separation remains solid');
      }
    }
    if(separatedAt===null&&crew.every((m,j)=>crew.slice(j+1).every(other=>Math.hypot(m.r-other.r,m.c-other.c)*4.1>=1.1-1e-7)))separatedAt=i/fps;
  }
  assert(separatedAt!==null,'all three eventually separate');
  for(let i=0;i<crew.length;i++){
    assert.equal(crew[i].id,origin[i].id);assert.equal(crew[i].weapon,origin[i].weapon);assert.equal(crew[i]._mercenaryOrder,'follow');
    assert.equal(f.bodyDepth(crew[i]),0);assert(Math.hypot(crew[i].r-f.ctx.player.r,crew[i].c-f.ctx.player.c)*4.1<7);
    assert.equal(crew[i]._mercenaryMoveReason,'arrived');
  }
  t.diagnostic(JSON.stringify({fps,separatedAt,members:crew.map(m=>({id:m.id,r:m.r,c:m.c,reason:m._mercenaryMoveReason}))}));
});

test('production water search retains the actual shared budget/resume contract',async()=>{
  const f=await fixture({constant:true});let checks=0;
  f.ctx._npcReserveRouteWork=()=>true;f.ctx._npcRouteWorkExpired=()=>++checks>6;
  let resumed=false,frames=0;
  for(;frames<600&&!f.m._waterEscapeTarget;frames++){checks=0;f.tick(.05);if(f.m._waterEscapeSearch)resumed=true;}
  assert(resumed&&frames>1&&f.m._waterEscapeTarget);assert(Math.hypot(f.m.r-9,f.m.c-9)*4.1<.1,'pending search never snaps to a shore candidate');
});

test('staged dry follow completes the former 48 m shore-detour failure for all five',async t=>{
  const f=await fixture();Object.assign(f.ctx.player,{r:10,c:10});
  const crew=[f.m,...['medic','bruiser','safecracker','demolitions'].map(p=>f.recruit(p))];Object.assign(f.ctx.player,{r:9,c:16});
  crew.forEach((m,i)=>Object.assign(m,{r:8+i*.7,c:9}));f.api.follow();
  for(let i=0;i<600;i++){
    const before=crew.map(m=>({r:m.r,c:m.c}));f.tick(.1);
    for(let j=0;j<crew.length;j++){
      assert(Math.hypot(crew[j].r-before[j].r,crew[j].c-before[j].c)*4.1<=.55+1e-7,'bounded physical movement');
      for(let k=j+1;k<crew.length;k++)assert(Math.hypot(crew[j].r-crew[k].r,crew[j].c-crew[k].c)*4.1>=1.1-1e-7,'crew separation preserved');
    }
  }
  assert(crew.every(m=>f.bodyDepth(m)===0),'water exit succeeds for all five');
  const result=crew.map(m=>({id:m.id,distanceToLeader:Math.hypot(m.r-f.ctx.player.r,m.c-f.ctx.player.c)*4.1,reason:m._mercenaryMoveReason}));
  assert(result.every(m=>m.distanceToLeader<7&&m.reason==='arrived'),JSON.stringify(result));
  t.diagnostic(JSON.stringify({resolved:'dry follow stages retain the local 48 m cap',crew:result}));
});

test('dry movement never enters water search or consumes shared water route work',async t=>{
  const f=await fixture({start:{r:16,c:14},player:{r:18,c:18}}),costs=[];
  for(let i=0;i<600;i++){
    const started=performance.now();f.tick(1/15);costs.push(performance.now()-started);
    assert.equal(f.bodyDepth(f.m),0);assert(!f.m._waterEscapeSearch);assert(!f.m._waterEscapeTarget);
  }
  const diagnostics=f.ctx.waterApi.diagnostics();assert.equal(diagnostics.searchCalls,0);assert.equal(diagnostics.route.admitted,0);
  assert.equal(f.m._mercenaryMoveReason,'arrived');costs.sort((a,b)=>a-b);
  t.diagnostic(JSON.stringify({scene:'one dry production follower, 600 updates',searchCalls:diagnostics.searchCalls,routeWorkAdmitted:diagnostics.route.admitted,cpuP50ms:costs[300],cpuP95ms:costs[570]}));
});

test('dry body-depth admission is exactly five point probes per actor, zero path searches',async t=>{
  const f=await fixture({start:{r:16,c:14},player:{r:18,c:18}});
  const actors=Array.from({length:5},(_,i)=>({id:'dry-probe-'+i,r:16+i*.4,c:14,hp:80,speed:1}));
  const groups={center:[],body:[]},options={bodyDepth:true,speed:1.5/4.1};
  const run=(body,record)=>{
    f.native.beginFrame();const before=f.ctx.waterApi.diagnostics(),nativeBefore=f.native.diagnostics(),started=performance.now();
    for(const m of actors)assert.equal(f.ctx.waterApi.escape(m,.05,f.ctx.performance.now(),body?options:undefined),false);
    const elapsed=performance.now()-started,after=f.ctx.waterApi.diagnostics(),nativeAfter=f.native.diagnostics();
    assert.equal(after.navigation.queries-before.navigation.queries,body?25:5);
    assert.equal(nativeAfter.queries-nativeBefore.queries,body?25:5);
    assert.equal(after.searchCalls,0);assert.equal(after.route.admitted,0);if(record)groups[body?'body':'center'].push(elapsed);
  };
  for(let i=0;i<100;i++){run(false,false);run(true,false);}
  for(let i=0;i<300;i++)for(const body of [false,true,true,false])run(body,true);
  const summary={};for(const [key,samples]of Object.entries(groups)){samples.sort((a,b)=>a-b);summary[key]={actors:5,samples:samples.length,p50ms:samples[Math.floor(samples.length*.5)],p95ms:samples[Math.floor(samples.length*.95)]};}
  t.diagnostic(JSON.stringify({fixtureOnly:true,summary,additionalBodyProbesPerFiveActors:20,waterSearchCalls:0}));
});

test('localhost NPC QA exposes movement once per second, other pages do not',async()=>{
  const f=await fixture({runtime:{query:'?mercenaryqa=1&npcqa=1'}});
  const first=f.ctx.document.documentElement.dataset.mercenaryMovement;assert(first);
  for(let i=0;i<9;i++)f.tick(.1);assert.equal(f.ctx.document.documentElement.dataset.mercenaryMovement,first);
  f.tick(.11);const next=JSON.parse(f.ctx.document.documentElement.dataset.mercenaryMovement);
  assert.equal(next.version,'water-follow23-v1');assert(next.at>JSON.parse(first).at);assert.equal(next.nativeConnected,true);
  assert.equal(next.crew[0].id,f.m.id);assert(Number.isFinite(next.crew[0].bodyDepth));assert(next.crew[0].waterEscaping);assert(next.crew[0].goal);assert(Number.isFinite(next.crew[0].followSpeed));
  for(const runtime of [{query:'?mercenaryqa=1'}, {hostname:'example.test',query:'?npcqa=1'}]){
    const disabled=await fixture({runtime});for(let i=0;i<30;i++)disabled.tick(.1);
    assert.equal(disabled.ctx.document.documentElement.dataset.mercenaryMovement,undefined);
  }
});

test('QA records moving target during real intimidation work and one terminal receipt',async()=>{
  const f=await sourceFixture({query:'?mercenaryqa=1&npcqa=1'}),m=f.recruit('bruiser');
  const target={id:'moving-intimidation-qa',r:m.r,c:m.c+.25,hp:80,max_hp:80,walking:true};f.ctx.NPCS.push(target);
  f.api.bindTargets({canMove:()=>true,groundHeight:()=>0});assert(f.api.command('intimidate',f.api.getTarget(target.id)).ok);
  for(let i=0;i<80;i++){target.c+=1.2*.05/4.1;f.tick(.05);}
  const snapshot=JSON.parse(f.ctx.document.documentElement.dataset.mercenaryMovement),row=snapshot.crew.find(item=>item.id===m.id),history=snapshot.actionHistory;
  assert.equal(snapshot.actionHistoryVersion,1);assert.equal(row.action,null);assert.equal(row.lastAction.kind,'intimidate');assert.equal(row.lastAction.phase,'completed');assert(Number.isFinite(row.lastAction.at));
  const working=history.filter(item=>item.phase==='working'&&item.kind==='intimidate');assert(working.length>=2);
  assert(working.every(item=>item.targetId===target.id&&item.targetWalking===true&&Number.isFinite(item.memberR)&&Number.isFinite(item.memberC)));
  assert(working.at(-1).targetC>working[0].targetC+.2,'historical work samples show actual target displacement');
  assert(working.at(-1).progress>working[0].progress);assert.equal(history.filter(item=>item.phase==='completed').length,1);
  for(let i=1;i<history.length;i++)assert(history[i].at-history[i-1].at>=1000-1e-5,'one sample per member per second');
  const frozen=JSON.stringify(history);target.c+=5;target.walking=false;for(let i=0;i<30;i++)f.tick(.1);
  assert.equal(JSON.stringify(JSON.parse(f.ctx.document.documentElement.dataset.mercenaryMovement).actionHistory),frozen,'idle sampling neither duplicates lastAction nor rewrites recorded target state');
});

test('QA action history retains at most sixteen primitive snapshots during a pending receipt',async()=>{
  const f=await sourceFixture({query:'?mercenaryqa=1&npcqa=1'}),m=f.recruit('engineer'),target={id:'pending-panel-qa',kind:'power_panel',powered:true,valid:true,position:{...f.api.getMember(m.id).position}};
  f.api.bindTargets({get:()=>target,canMove:()=>true,performEffect:()=>new Promise(()=>{})});assert(f.api.command('disable_power',target).ok);
  for(let i=0;i<250;i++)f.tick(.1);
  const snapshot=JSON.parse(f.ctx.document.documentElement.dataset.mercenaryMovement);assert.equal(snapshot.crew[0].action.phase,'awaiting');assert.equal(snapshot.actionHistory.length,16);
  assert(snapshot.actionHistory.every(item=>item.memberId===m.id&&item.phase==='awaiting'&&item.targetWalking===null));
  assert(snapshot.actionHistory[0].at>1000*1000+5000,'oldest samples were evicted');
});

test('QA action reporting cannot change the gameplay result or actor state',async()=>{
  const enabled=await sourceFixture({query:'?mercenaryqa=1&npcqa=1'}),disabled=await sourceFixture({query:'?mercenaryqa=1'});
  const rows=[];
  for(const f of [enabled,disabled]){const m=f.recruit('bruiser'),target={id:'parity-moving-target',r:m.r,c:m.c+.25,hp:80,max_hp:80,walking:true};f.ctx.NPCS.push(target);f.api.bindTargets({canMove:()=>true,groundHeight:()=>0});assert(f.api.command('intimidate',f.api.getTarget(target.id)).ok);rows.push({f,m,target});}
  for(let i=0;i<80;i++)for(const {f,target}of rows){target.c+=1.2*.05/4.1;f.tick(.05);}
  const states=rows.map(({f,m,target})=>JSON.stringify({member:m,target,action:f.api.getAction(m.id),record:f.api.getRoster().members.find(row=>row.id===m.id)}));
  assert.equal(states[0],states[1]);assert.equal(disabled.ctx.document.documentElement.dataset.mercenaryMovement,undefined);
});
