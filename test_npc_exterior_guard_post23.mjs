// Isolated candidate contract and actual-geometry replay; no runtime edits.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {performance} from 'node:perf_hooks';
import {gunzipSync} from 'node:zlib';
import {registerHooks} from 'node:module';
import {beginExteriorGuardPost23 as begin,stepExteriorGuardPost23 as step} from './npc_exterior_guard_post23_candidate.mjs';
import {createNativeSiteCatalog} from './assets/maps/city_rebuild_v1/native_site_control.mjs';

const binding=()=>{
  const site={siteId:'native-site:test',instanceId:'test',ownerFactionId:'fixture-owner',revision:1,manifestRevision:'fixture-v1',loaded:true,approach:{r:0,c:0}};
  const actor={id:'guard',siteId:site.siteId,ownerFactionId:site.ownerFactionId,generation:1,alive:true,r:0,c:0};
  return {actor,site};
};
let contractCases=0;
function context(extra={}){return {...binding(),admitted:true,budgetMs:2,now:()=>0,bodyClear:()=>true,exterior:()=>true,sweepClear:()=>true,...extra};}
function finish(job,ctx){let result,slices=0;do{result=step(job,ctx);assert(++slices<=200,'finite completion');}while(result.status==='pending');return {result,slices};}
{
  const ctx=context(),job=begin(ctx.actor,ctx.site,0,0),before=JSON.stringify([ctx.actor,ctx.site]);
  const {result}=finish(job,ctx);assert.equal(result.status,'ready');assert.equal(result.path.length,1);
  assert(!('arrived' in result));assert.equal(JSON.stringify([ctx.actor,ctx.site]),before);contractCases++;
}
for(const mutate of [c=>c.site.ownerFactionId='enemy',c=>c.site.revision++,c=>c.site.manifestRevision='v2',c=>c.site.instanceId='other',c=>c.site.loaded=false,c=>c.site.approach.r++,c=>c.actor.id='other',c=>c.actor.generation++,c=>c.actor.siteId='other',c=>c.actor.ownerFactionId='enemy',c=>c.actor.r++,c=>c.actor.alive=false,c=>c.actor.combat=true,c=>c.actor.vehicle=true,c=>c.actor.interior=true]){
  const ctx=context(),job=begin(ctx.actor,ctx.site,0,0);let queries=0;ctx.bodyClear=()=>{queries++;return true;};mutate(ctx);
  assert.equal(step(job,ctx).status,'cancelled');assert.equal(queries,0);contractCases++;
}
for(const mutate of [c=>delete c.site.manifestRevision,c=>c.site.revision=-1,c=>c.actor.generation=-1,c=>c.site.siteId='',c=>c.site.ownerFactionId='enemy',c=>c.actor.r=NaN]){
  const ctx=context();mutate(ctx);assert.equal(begin(ctx.actor,ctx.site,0,0),null);contractCases++;
}
{
  const ctx=context({admitted:false}),job=begin(ctx.actor,ctx.site,0,0);let calls=0;
  ctx.bodyClear=()=>{calls++;return true;};assert.equal(step(job,ctx).status,'pending');assert.equal(calls,0);
  ctx.admitted=true;ctx.budgetMs=0;assert.equal(step(job,ctx).status,'pending');assert.equal(calls,0);contractCases++;
}
{
  const ctx=context({sweepClear:()=>false}),job=begin(ctx.actor,ctx.site,0,0),{result}=finish(job,ctx);
  assert.equal(result.status,'blocked');assert.equal(result.reason,'no-connected-exterior-post');assert.equal(job.attempt,36);assert(!job.target);contractCases++;
}
{
  // Each callback consumes one synthetic millisecond: a slice cannot run more
  // than two callbacks. Suspension must resume the same sample, not restart it.
  let clock=0,calls=0;const query=()=>{clock++;calls++;return true;};
  const ctx=context({now:()=>clock,bodyClear:query,exterior:query,sweepClear:query}),job=begin(ctx.actor,ctx.site,0,0);
  let result,slices=0;do{const before=calls;result=step(job,ctx);assert(calls-before<=2);slices++;assert(slices<100);}while(result.status==='pending');
  assert.equal(result.status,'ready');assert(slices>20);contractCases++;
}
{
  const ctx=context(),job=begin(ctx.actor,ctx.site,0,0);ctx.actor.r=9;job.from.r=9;
  assert.equal(step(job,ctx).reason,'rejoin-approach-required');contractCases++;
}
{
  const ctx=context({occupied:Array.from({length:65},(_,i)=>({id:String(i),r:0,c:0}))}),job=begin(ctx.actor,ctx.site,0,0);
  assert.equal(step(job,ctx).reason,'occupancy-budget-exceeded');contractCases++;
}
{
  // Exact point can be clear while a route crosses an interior or obstacle.
  for(const key of ['bodyClear','exterior']){
    const ctx=context({[key]:p=>Math.hypot(p.r,p.c)<.3||Math.hypot(p.r,p.c)>3}),job=begin(ctx.actor,ctx.site,0,0);
    assert.equal(finish(job,ctx).result.status,'blocked');contractCases++;
  }
}
{
  const ctx=context({bodyClear:()=>{throw new Error('geometry missing');}}),job=begin(ctx.actor,ctx.site,0,0);
  assert.equal(step(job,ctx).reason,'geometry-unavailable');contractCases++;
}
{
  const ctx=context();ctx.actor.r=7;const job=begin(ctx.actor,ctx.site,0,0);
  // Force each otherwise clear proposal to fail only after checking both edges.
  ctx.exterior=()=>!(job.stage==='edge-exterior'&&job.edge===1&&job.sample===job.samples-1);
  assert.equal(step(job,ctx).status,'pending');assert.equal(job.queries,96);
  const {result}=finish(job,ctx);assert.equal(result.reason,'query-budget-exhausted');assert.equal(job.queries,4096);contractCases++;
}
{
  // Reservation arrives between final sweep/body and final exterior slice.
  let time=0;const cost=()=>{time++;return true;};
  const ctx=context({budgetMs:1,now:()=>time,bodyClear:cost,exterior:cost,sweepClear:cost}),job=begin(ctx.actor,ctx.site,0,0);
  while(job.stage!=='final-exterior'){assert.equal(step(job,ctx).status,'pending');}
  const rejected={...job.candidate};ctx.occupied=[{id:'other',...rejected}];
  const {result}=finish(job,ctx);assert.equal(result.status,'ready');
  assert(Math.hypot(result.target.r-rejected.r,result.target.c-rejected.c)>=.65);contractCases++;
}
{
  // Invalid exterior start must fail before choosing any patrol point.
  const ctx=context({exterior:()=>false}),job=begin(ctx.actor,ctx.site,0,0);
  assert.equal(finish(job,ctx).result.reason,'start-not-exterior');contractCases++;
}

const fixtureUrl=new URL('./assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs',import.meta.url);
const hook=registerHooks({load(url,c,next){const result=next(url,c);return url===fixtureUrl.href?{...result,source:String(result.source).replace('new GLTFLoader().parseAsync','new GLTFLoader().register(()=>({name:"cpu-no-textures",loadTexture:()=>Promise.resolve(null)})).parseAsync')}:result;}});
const {createCivilianNativeFixture,sourceFunction}=await import(fixtureUrl.href);hook.deregister();
const snapshot=JSON.parse(gunzipSync(fs.readFileSync('assets/maps/city_rebuild_v1/test_fixtures/native_static_collision19.json.gz')));
const rows=[],baselineRows=[],reservationRows=[],fixtures=[];
const quantiles=values=>{const a=[...values].sort((a,b)=>a-b);return {p50:a[Math.floor(a.length*.5)]??0,p95:a[Math.floor(a.length*.95)]??0,max:a.at(-1)??0};};
for(const assetId of ['hospital','print_shop','bookmaker']){
  const f=await createCivilianNativeFixture({assetId,snapshot}),b=f.box;
  for(const name of ['_inEmpireRecruitmentYard','_empireBossPassable','_empireBossWaypointPassable','_empireTargetFootprintPassable23','_nearestEmpireWalkPoint','_empireHoldingGuardPost'])vm.runInContext(sourceFunction(f.source,name),b);
  const catalog=createNativeSiteCatalog({entries:[f.entry],manifestRevision:'static-collision19-fixture'}),descriptor=catalog.list()[0],approachM=catalog.approach(descriptor.id);
  assert(approachM,'existing native entry approach');
  const approach={r:approachM.z/f.M,c:approachM.x/f.M};
  // Controlled authority input only: no capture operation or authority write.
  const site={siteId:descriptor.id,instanceId:descriptor.instanceId,ownerFactionId:'test-existing-owner',revision:1,manifestRevision:catalog.manifestRevision,loaded:true,approach};
  const scratch=new f.THREE.Vector3(),offsets=[[0,0],[.18,.18],[.18,-.18],[-.18,.18],[-.18,-.18]];
  const exterior=p=>offsets.every(([dr,dc])=>{
    const x=(p.c+dc)*f.M,z=(p.r+dr)*f.M;
    scratch.set(x,f.floor(x,z),z);return f.entry.containsInterior(scratch)!==true;
  });
  let activeOccupants=[];
  const bodyClear=p=>b._empireTargetFootprintPassable23(p.r,p.c)===true&&activeOccupants.every(other=>Math.hypot(p.r-other.r,p.c-other.c)>.36);
  const sweepClear=(from,to)=>f.pedestrian.query({mode:'sweep',from,to,radius:.18})?.blocked===false&&activeOccupants.every(other=>{
    const dr=to.r-from.r,dc=to.c-from.c,length2=dr*dr+dc*dc;
    const t=length2?Math.max(0,Math.min(1,((other.r-from.r)*dr+(other.c-from.c)*dc)/length2)):0;
    return Math.hypot(other.r-from.r-t*dr,other.c-from.c-t*dc)>.36;
  });
  fixtures.push({assetId,instanceId:f.item.id,approach,approachBody:bodyClear(approach),approachExterior:exterior(approach),limits:f.limits});
  function walk(start,target,path){
    const n={id:'physical-guard-replay',...start,walkPhase:0};b._setNpcRoute(n,path,'empire_holding_guard');
    let status=true,unsafe=0,interior=0,steps=0,maxStep=0;
    while(status===true&&steps<1500){
      f.nextFrame(1/7);const from={r:n.r,c:n.c};status=b._npcAdvanceRoute(n,1/7,1.18,b._empireBossPassable);
      const moved=Math.hypot(n.r-from.r,n.c-from.c);maxStep=Math.max(maxStep,moved);
      if(moved>0&&(!sweepClear(from,n)||!b._npcPathPassable(from.r,from.c,n.r,n.c,b._empireBossPassable)))unsafe++;
      if(!exterior(n))interior++;steps++;
    }
    assert(maxStep<=1.18/7+1e-8,'physical movement, no teleport');
    const remaining=Math.hypot(n.r-target.r,n.c-target.c);
    return {status,reached:status==='arrived'&&remaining<.75,remaining,unsafe,interior,steps,end:{r:n.r,c:n.c}};
  }
  function baseline(from,slot,patrolStep){
    // Give both producers the same existing entry approach and starting guard.
    // This is a controlled source comparison, not a captured native guard job.
    vm.runInContext('_npcRouteWorkQueue.clear();_npcRouteWorkBatch.clear();_npcRouteWorkBatchCount=0;',b);
    const started=performance.now(),target=b._empireHoldingGuardPost(approach,slot,patrolStep);
    let cpuMs=performance.now()-started,slices=0,ready=false;
    const n={id:'baseline-guard-'+slot,...from,walkPhase:0},sliceCosts=[];
    do{
      f.nextFrame();const at=performance.now();ready=b._planNpcRouteTo(n,target.r,target.c,b._empireBossWaypointPassable,.7,9000,'empire_holding_guard');
      const cost=performance.now()-at;cpuMs+=cost;sliceCosts.push(cost);assert(++slices<=300,'baseline finite search');
    }while(n._routeSearchPending);
    const movement=ready?walk(from,target,Array.from(n._route||[])):null;
    baselineRows.push({assetId,instanceId:f.item.id,slot,patrolStep,from:{...from},target,ready,cpuMs,slices,sliceMs:quantiles(sliceCosts),movement});
  }
  for(let slot=0;slot<3;slot++){
    let from={...approach};
    for(let patrolStep=0;patrolStep<4;patrolStep++){
      const actor={id:'test-guard-'+slot,...from,siteId:site.siteId,ownerFactionId:site.ownerFactionId,generation:patrolStep,alive:true};
      if(patrolStep%2===0)baseline(from,slot,patrolStep);
      const ctx={actor,site,admitted:true,budgetMs:2,now:()=>performance.now(),bodyClear,exterior,sweepClear};
      const job=begin(actor,site,slot,patrolStep),costs=[];let result,slices=0,maxQueries=0,maxCallbackMs=0;
      for(const key of ['bodyClear','exterior','sweepClear']){const original=ctx[key];ctx[key]=(...args)=>{const at=performance.now();const value=original(...args);maxCallbackMs=Math.max(maxCallbackMs,performance.now()-at);return value;};}
      do{
        f.nextFrame();const previous=job.queries,at=performance.now();result=step(job,ctx);costs.push(performance.now()-at);
        maxQueries=Math.max(maxQueries,job.queries-previous);assert(maxQueries<=96);assert(++slices<=200,'bounded job');
      }while(result.status==='pending');
      const movement=result.status==='ready'?walk(from,result.target,result.path):null;
      if(patrolStep%2===1)baseline(from,slot,patrolStep);
      rows.push({assetId,instanceId:f.item.id,slot,patrolStep,from:{...from},status:result.status,reason:result.reason,target:result.target,attempts:Math.min(36,job.attempt+1),queries:job.queries,slices,cpuMs:costs.reduce((a,b)=>a+b,0),sliceMs:quantiles(costs),maxQueries,maxCallbackMs,movement});
      // Advance only after real arrival. A rejected post stays pending here;
      // this test never promotes EMPTY/partial to an arrived patrol state.
      if(movement?.reached)from=movement.end;
    }
  }
  // Three sequentially placed guards reserve their actual occupied body points.
  // Other guards stand still during each query/movement; this is not crowd AI.
  const placed=new Map();
  for(let patrolStep=0;patrolStep<4;patrolStep++)for(let slot=0;slot<3;slot++){
    const actor={id:'reserved-guard-'+slot,...(placed.get(slot)||approach),siteId:site.siteId,ownerFactionId:site.ownerFactionId,generation:patrolStep,alive:true};
    activeOccupants=[...placed].filter(([other])=>other!==slot).map(([other,point])=>({id:'reserved-guard-'+other,...point}));
    const ctx={actor,site,occupied:activeOccupants,admitted:true,budgetMs:2,now:()=>performance.now(),bodyClear,exterior,sweepClear};
    const job=begin(actor,site,slot,patrolStep),{result,slices}=finish(job,ctx);
    const movement=result.status==='ready'?walk(actor,result.target,result.path):null;
    reservationRows.push({assetId,instanceId:f.item.id,slot,patrolStep,from:{r:actor.r,c:actor.c},approach:{...approach},occupied:activeOccupants.map(p=>({...p})),status:result.status,reason:result.reason,target:result.target,slices,queries:job.queries,movement});
    if(movement?.reached)placed.set(slot,movement.end);
    if(movement){assert(movement.reached);assert.equal(movement.unsafe,0);assert.equal(movement.interior,0);}
  }
}
const summary={candidateOnly:true,contractCases,requests:rows.length,ready:rows.filter(r=>r.status==='ready').length,actualArrivals:rows.filter(r=>r.movement?.reached).length,blocked:rows.filter(r=>r.status==='blocked').length,unsafeMovement:rows.reduce((s,r)=>s+(r.movement?.unsafe||0),0),interiorSteps:rows.reduce((s,r)=>s+(r.movement?.interior||0),0),jobCpuMs:quantiles(rows.map(r=>r.cpuMs)),sliceMaxMs:Math.max(...rows.map(r=>r.sliceMs.max)),queries:rows.reduce((s,r)=>s+r.queries,0)};
const baselineSummary={requests:baselineRows.length,ready:baselineRows.filter(r=>r.ready).length,routeArrived:baselineRows.filter(r=>r.movement?.status==='arrived').length,actualArrivals:baselineRows.filter(r=>r.movement?.reached).length,unsafeMovement:baselineRows.reduce((s,r)=>s+(r.movement?.unsafe||0),0),interiorSteps:baselineRows.reduce((s,r)=>s+(r.movement?.interior||0),0),jobCpuMs:quantiles(baselineRows.map(r=>r.cpuMs)),sliceMaxMs:Math.max(...baselineRows.map(r=>r.sliceMs.max))};
const reservationSummary={requests:reservationRows.length,actualArrivals:reservationRows.filter(r=>r.movement?.reached).length,blocked:reservationRows.filter(r=>r.status==='blocked').length,unsafeMovement:reservationRows.reduce((s,r)=>s+(r.movement?.unsafe||0),0)};
fs.writeFileSync('assets/maps/city_rebuild_v1/test_fixtures/native_guard_crowded23.json',JSON.stringify({source:'test_npc_exterior_guard_post23.mjs; controlled actual-geometry replay, not LIVE captures',cases:reservationRows.filter(r=>r.status==='blocked').map(({movement,...row})=>row)},null,2)+'\n');
fs.writeFileSync('outputs/npc_exterior_guard_post23_candidate.json',JSON.stringify({summary,baselineSummary,reservationSummary,fixtures,rows,baselineRows,reservationRows,limits:'Isolated CPU geometry and synthetic existing-owner inputs. Matched starts/entry approaches, alternating baseline/candidate order; source baseline chooses different goals. Reservation series adds two stationary full-radius guard bodies supplied by the test adapter. No authority writes, runtime hookup, moving crowds/doors/cars of complete live city or FPS. Callback timing is cooperative: one collision callback can overrun a slice; hard query caps are 96/slice and 4096/job, max36 candidates. Caller must reserve shared scheduler admission and validate each movement step.'},null,2)+'\n');
console.log(JSON.stringify({summary,baselineSummary,reservationSummary,fixtures:fixtures.map(({limits,...v})=>v)},null,2));
assert.equal(summary.unsafeMovement,0);assert.equal(summary.interiorSteps,0);
assert.equal(summary.actualArrivals,summary.ready,'every READY must physically arrive');
assert.equal(summary.actualArrivals,36,'all three actual buildings, three slots and four turns');
