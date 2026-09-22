import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import * as module from './mercenary_core.mjs';
import {createMercenaryRoutePlanner} from './mercenary_route.mjs';
import {createMercenaryLongFollow as createMercenaryLongFollow23} from './mercenary_long_follow.mjs';

const read=name=>fs.readFileSync(new URL(name,import.meta.url),'utf8').replace(/\r\n/g,'\n');
const world=read('../../../world.html');
const physicalFunctions=['_npcBodyPassable','_npcPathPassable'].map(name=>{
  const body=world.match(new RegExp('^function '+name+'\\([^]*?^}','m'))?.[0];
  assert(body,'actual source collision helper '+name);return body;
}).join('\n');
let host=read('./mercenary_world.js').replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');
const stageStart=host.indexOf('  // Far followers use local stages');
if(stageStart>=0){const stageEnd=host.indexOf('\n  if(!route){',stageStart);assert(stageEnd>stageStart);host=host.slice(0,stageStart)+host.slice(stageEnd);}
const fixtureText=read('./test_mercenary_rally_actions.mjs');
const fixture=Function('vm','module','script','assert',fixtureText.slice(fixtureText.indexOf('async function fixture('),fixtureText.indexOf('\nfor(const [profession'))+';return fixture;')(vm,module,host,assert);
const distance=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);

// Actual source passability helpers + deterministic native swept rectangles.
// The radius is supplied by production (.18 source tiles == .738 metres).
function physics(walls=[],context=null){
  let nativeChecks=0,maxQueryDistance=0,queries=0;
  const blocked=(x,z,r=0)=>walls.some(([x0,x1,z0,z1])=>x>x0-r&&x<x1+r&&z>z0-r&&z<z1+r);
  const segment=(from,to,r)=>walls.some(([x0,x1,z0,z1])=>{
    let lo=0,hi=1;
    for(const [a,b,min,max]of [[from.x,to.x,x0-r,x1+r],[from.z,to.z,z0-r,z1+r]]){
      const delta=b-a;if(Math.abs(delta)<1e-12){if(a<min||a>max)return false;continue;}
      const p=(min-a)/delta,q=(max-a)/delta;lo=Math.max(lo,Math.min(p,q));hi=Math.min(hi,Math.max(p,q));
      if(lo>hi)return false;
    }
    return true;
  });
  const pass=(r,c)=>!blocked(c*4.1,r*4.1);
  const ctx=context||vm.createContext({});
  Object.assign(ctx,{npcPassable:pass,npcPassableForSnitch:pass,_npcRouteWalkBlocked:(r,c)=>!pass(r,c),
    _walkNpcNavigationResolver:({from,to,radius})=>{nativeChecks++;return {swept:true,blocked:segment({x:from.c*4.1,z:from.r*4.1},{x:to.c*4.1,z:to.r*4.1},radius*4.1)};}});
  vm.runInContext(physicalFunctions,ctx);
  return {walls,blocked,ctx,
    canMove(from,to){queries++;maxQueryDistance=Math.max(maxQueryDistance,distance(from,to));return ctx._npcPathPassable(from.z/4.1,from.x/4.1,to.z/4.1,to.x/4.1,pass);},
    get queries(){return queries;},get nativeChecks(){return nativeChecks;},get maxQueryDistance(){return maxQueryDistance;}};
}

function walkScene({from={x:0,y:0,z:0},goal={x:178,y:0,z:0},walls=[],movingGoal=null,maxFrames=6000}={}){
  let stamp=0,position={...from},maxStep=0,minDistance=Infinity;
  const nav=physics(walls),follow=createMercenaryLongFollow23({canMove:nav.canMove,clock:()=>stamp});
  const initial={...from},statusCounts={};
  for(let frame=0;frame<maxFrames;frame++){
    stamp+=50;if(movingGoal)goal=movingGoal(frame,goal);
    const beforeExpanded=follow.stats.expanded,beforeChecks=follow.stats.checks;
    const result=follow.advance(position,goal);
    assert(follow.stats.expanded-beforeExpanded<=8,'at most 8 actual local expansions per caller slice');
    assert(follow.stats.checks-beforeChecks<=34,'4 neighbours per expansion + endpoint/final connection');
    statusCounts[result.status]=(statusCounts[result.status]||0)+1;
    if(result.status==='arrived')return {nav,follow,position,goal,frames:frame+1,maxStep,statusCounts};
    if(result.waypoint){
      const d=distance(position,result.waypoint),step=Math.min(.275,Math.max(0,d-result.stopDistance));
      const next={x:position.x+(result.waypoint.x-position.x)*step/d,y:0,z:position.z+(result.waypoint.z-position.z)*step/d};
      if(!nav.canMove(position,next)){follow.blocked();continue;}
      assert(!nav.blocked(next.x,next.z,.738),'actual source footprint never crosses a wall');
      maxStep=Math.max(maxStep,distance(position,next));position=next;
    }
    minDistance=Math.min(minDistance,distance(position,goal));
    assert.deepEqual(from,initial,'candidate never mutates the caller position');
  }
  return {nav,follow,position,goal,frames:maxFrames,maxStep,minDistance,statusCounts};
}

test('actual 48m planner rejects the observed 178m gap before checking collision',()=>{
  const from={x:19.6893*4.1,y:0,z:78.5611*4.1},goal={x:40*4.1,y:0,z:40*4.1};
  let calls=0;const search=createMercenaryRoutePlanner({canMove:()=>{calls++;return true;}}).start(from,goal);
  search.advance({maxExpanded:8,budgetMs:.75});
  assert(distance(from,goal)>178);assert(search.done);assert.equal(search.path,null);
  assert.equal(search.stats.expanded,1);assert.equal(calls,0);
});

test('actual host baseline with stages disabled stalls when the long direct sweep is obstructed',async()=>{
  for(const obstructed of [false,true]){
    const f=await fixture(),m=f.recruit('engineer');
    m.c=19.6893;m.r=78.5611;f.ctx.player.c=40;f.ctx.player.r=40;
    physics(obstructed?[[119,126,239,248]]:[],f.ctx);f.api.bindTargets({canMove:()=>true});assert(f.api.follow().ok);
    const before={r:m.r,c:m.c};for(let i=0;i<20;i++)f.tick(.05);
    if(obstructed){assert.deepEqual({r:m.r,c:m.c},before);assert.equal(m._mercenaryMoveReason,'no_route');assert.equal(m._mercenaryPath.stats.expanded,1);}
    else{assert(Math.hypot(m.r-before.r,m.c-before.c)>0);assert.equal(m._mercenaryPath.direct,true);}
  }
});

test('178m following uses bounded actual-router stages around two solid buildings',t=>{
  const result=walkScene({walls:[[69,77,-6,6],[126,132,-8,8]]});
  assert(distance(result.position,result.goal)<=.6,JSON.stringify(result));
  assert(result.follow.stats.completedStages>=6);assert(result.follow.stats.maxSearchExpanded<2400);
  assert(result.maxStep<=.275+1e-8,'no teleport; 50ms physical steps at ordinary 5.5m/s');
  assert(result.nav.maxQueryDistance<=.975+1e-8,'no long direct sweep is hidden inside the staged planner');
  assert(result.statusCounts.candidate_failed>0,'staged endpoint inside building uses a different local endpoint');
  t.diagnostic(JSON.stringify({frames:result.frames,seconds:result.frames*.05,stats:result.follow.stats,nativeChecks:result.nav.nativeChecks,sourceCpuOnly:true}));
});

test('moving leader keeps bounded pending work then follows the newest position',()=>{
  const result=walkScene({walls:[[16,19,-5,5]],movingGoal:(frame,goal)=>frame<500?{x:178,z:frame*.04,y:0}:goal});
  assert(distance(result.position,result.goal)<=.6,JSON.stringify(result));
  assert(result.follow.stats.searches<30,'small drift cannot restart on every frame');
  assert(result.follow.stats.completedStages>=6);
});

test('large leader drift invalidates pending search and returns no stale waypoint',()=>{
  let clock=0;const nav=physics(),follow=createMercenaryLongFollow23({canMove:nav.canMove,clock:()=>clock});
  const from={x:0,z:0},first={x:178,z:0},next={x:0,z:178};
  assert.equal(follow.advance(from,first,{maxExpanded:1}).status,'searching');
  assert.equal(follow.inspect().goal.x,178);clock+=50;
  assert.equal(follow.advance(from,next,{maxExpanded:1}).waypoint,null);
  assert.equal(follow.stats.retargets,1);assert.equal(follow.inspect().goal.z,178);
  let result;for(let i=0;i<100;i++){clock+=50;result=follow.advance(from,next);if(result.waypoint)break;}
  assert(result.waypoint.z>0);assert(Math.abs(result.waypoint.x)<1e-8);
});

test('cancel, non-follow action and unavailable fighter discard all pending/path work',()=>{
  const nav=physics(),follow=createMercenaryLongFollow23({canMove:nav.canMove,clock:()=>0});
  const from={x:0,z:0},goal={x:178,z:0};
  for(const options of [{active:false},{purpose:'plant_bomb'},{purpose:'rally'}]){
    follow.advance(from,goal,{maxExpanded:1});assert(follow.inspect()?.searching);const calls=nav.queries;
    assert.equal(follow.advance(from,goal,options).status,'cancelled');assert.equal(follow.inspect(),null);assert.equal(nav.queries,calls);
  }
  for(let i=0;i<20&&!follow.inspect()?.pathLength;i++)follow.advance(from,goal);
  assert(follow.inspect()?.pathLength);follow.cancel();assert.equal(follow.inspect(),null);
  assert.equal(follow.advance(from,{x:0,z:178},{maxExpanded:1}).waypoint,null);
  assert.equal(follow.inspect().goal.z,178);
});

test('zero budget does no route work; five followers share existing 1.5ms deadline',()=>{
  let clock=0,totalChecks=0;
  const fighters=Array.from({length:5},()=>createMercenaryLongFollow23({clock:()=>clock,canMove:()=>{clock+=.015;totalChecks++;return true;}}));
  const from={x:0,z:0},goal={x:178,z:0};
  for(const f of fighters){assert.equal(f.advance(from,goal,{budgetMs:0}).status,'budget');assert.equal(f.stats.expanded,0);}
  assert.equal(totalChecks,0);
  for(let frame=0;frame<20;frame++){
    const start=clock,deadline=start+1.5;
    for(let offset=0;offset<5;offset++){
      const f=fighters[(frame+offset)%5],before=f.stats.expanded;
      f.advance(from,goal,{maxExpanded:8,budgetMs:Math.min(.75,deadline-clock)});
      assert(f.stats.expanded-before<=8);
    }
    // Actual local planner checks time between node expansions. Four native
    // checks in the last expansion are deliberately non-preemptible.
    assert(clock-start<=1.565+1e-8,'only one bounded local-expansion overrun');
  }
  assert(fighters.every(f=>f.stats.expanded>0),'existing rotating roster prevents starvation');
});

test('new obstacle invalidates physical motion and replans after bounded cooldown',()=>{
  let clock=0;const walls=[],nav=physics(walls),follow=createMercenaryLongFollow23({canMove:nav.canMove,clock:()=>clock});
  const from={x:0,z:0},goal={x:178,z:0};let result;
  for(let i=0;i<20;i++){clock+=50;result=follow.advance(from,goal);if(result.waypoint)break;}
  assert(result.waypoint);walls.push([.1,.2,-1,1]);
  assert.equal(nav.canMove(from,{x:.275,z:0}),false,'host sweep sees the newly introduced obstacle');
  follow.blocked();assert.equal(follow.inspect(),null);const checks=nav.queries;
  assert.equal(follow.advance(from,goal).status,'blocked');assert.equal(nav.queries,checks);
  walls.length=0;clock+=501;assert.equal(follow.advance(from,goal,{maxExpanded:1}).status,'searching');
});

test('fully blocked geometry exhausts a finite fan and waits; it cannot teleport or bypass solids',()=>{
  let clock=0,checks=0;const from={x:0,z:0},goal={x:178,z:0};
  const follow=createMercenaryLongFollow23({clock:()=>clock,canMove:()=>{checks++;return false;}});
  let result;for(let i=0;i<6;i++){clock+=50;result=follow.advance(from,goal);assert.equal(result.waypoint,null);}
  assert.equal(result.status,'blocked');assert.equal(checks,5);assert.equal(follow.stats.expanded,0);
  for(let i=0;i<20;i++){clock+=50;assert.equal(follow.advance(from,goal).status,'blocked');}
  assert.equal(checks,5);assert.deepEqual(from,{x:0,z:0});
});
