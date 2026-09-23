import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import zlib from 'node:zlib';
import vm from 'node:vm';
import * as module from './mercenary_core.mjs';
import {createMercenarySafePlacement,advanceMercenarySafeDrop,createMercenaryCatchup,mercenaryCatchupEligible} from './mercenary_catchup.mjs';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';
import {npcVehicleBlocks} from './world_traffic_presentation.mjs';
import {createMercenaryVehicleBridge} from './mercenary_vehicle_bridge.mjs';

const member=(id='m',x=100,z=0)=>({id,owned:true,status:'active',hp:100,order:'follow',position:{x,z}});
const hero={position:{x:0,z:0},alive:true,angle:0};
const allow=point=>({ok:true,point:{...point,y:0}});
function simulate(controller,members,seconds,{fps=20,heroValue=hero,enabled=true,apply=true}={}){
 const relocations=[];for(let i=0;i<=seconds*fps;i++){
  const result=controller.update({now:i*1000/fps,hero:heroValue,members,enabled});assert(result.checks<=4);
  for(const r of result.relocations){relocations.push({...r,at:i*1000/fps});if(apply)members.find(m=>m.id===r.id).position=r.point;}
 }return relocations;
}

test('five sustained far followers recover safely at 7/15/60Hz; progress alone does not cancel far recovery',()=>{
 for(const fps of [7,15,60]){
  const crew=Array.from({length:5},(_,i)=>member('m'+i,100+i*3)),controller=createMercenaryCatchup({placement:{check:allow}}),moves=simulate(controller,crew,8,{fps});
  assert.equal(moves.length,5);assert(moves.every(m=>m.at>=6000&&m.reason==='far'));
  for(let i=0;i<crew.length;i++)for(let j=0;j<i;j++)assert(Math.hypot(crew[i].position.x-crew[j].position.x,crew[i].position.z-crew[j].position.z)>=1.6);
  assert(controller.stats.maxChecksPerUpdate<=4);
 }
});

test('stuck threshold, physical progress, interruption, authority and cooldown are distinct',()=>{
 const crew=[member('m',30)],controller=createMercenaryCatchup({placement:{check:allow}}),moves=simulate(controller,crew,11);assert.equal(moves.length,1);assert(moves[0].at>=10000);assert.equal(moves[0].reason,'stuck');
 crew[0].position={x:100,z:0};for(let now=11050;now<30000;now+=50)assert.equal(controller.update({now,hero,members:crew}).relocations.length,0);
 const moving=member('moving',30),motion=createMercenaryCatchup({placement:{check:allow}});for(let now=0;now<12000;now+=50){moving.position.z=now/1000;assert.equal(motion.update({now,hero,members:[moving]}).relocations.length,0);}
 const paused=createMercenaryCatchup({placement:{check:allow}}),far=member();simulate(paused,[far],5);assert.equal(paused.update({now:20000,hero,members:[far]}).relocations.length,0);assert.equal(paused.inspect(far.id).reason,'ineligible');
 assert.equal(simulate(createMercenaryCatchup({placement:{check:allow}}),[member()],15,{enabled:false}).length,0);
 for(const override of [{alive:false},{interior:true},{inVehicle:true}])assert.equal(simulate(createMercenaryCatchup({placement:{check:allow}}),[member()],15,{heroValue:{...hero,...override}}).length,0);
});

test('tasks, fighting, hospital, carry, seats, conversation and non-owned NPCs cannot recover',()=>{
 const exclusions=[{owned:false},{status:'downed'},{status:'hospital'},{status:'returning'},{hp:0},{dead:true},{order:'rally'},{action:{}},{queued:true},{combat:true},{carried:true},{carrying:true},{seated:true},{vehicleChase:true},{interior:true},{safeExit:true},{conversation:true}];
 for(const fields of exclusions){const m={...member(),...fields};assert(!mercenaryCatchupEligible(m));assert.equal(simulate(createMercenaryCatchup({placement:{check:allow}}),[m],15).length,0,JSON.stringify(fields));}
 const c=createMercenaryCatchup({placement:{check:allow}}),m=member();simulate(c,[m],5);m.action={};for(let now=5050;now<=12000;now+=50)c.update({now,hero,members:[m]});m.action=null;
 for(let now=12050;now<18000;now+=50)assert.equal(c.update({now,hero,members:[m]}).relocations.length,0,'task completion starts a fresh grace period');
});

test('bounded shared search waits when no free point, revalidates stable ground and follows moving origin',()=>{
 const state={},origin={x:0,z:0};let calls=0;const blocked=()=>{calls++;return {ok:false}};
 for(let now=0;now<400;now+=50){const r=advanceMercenarySafeDrop(state,{origin,memberId:'a',now,validate:blocked});assert(r.checks<=4);assert.equal(r.point,null);}
 assert.equal(calls,32);assert.equal(state.status,'blocked');for(let now=400;now<2350;now+=50)advanceMercenarySafeDrop(state,{origin,memberId:'a',now,validate:blocked});assert.equal(calls,32);
 advanceMercenarySafeDrop(state,{origin,memberId:'a',now:2350,validate:blocked});assert.equal(calls,36);
 const stable={};assert.equal(advanceMercenarySafeDrop(stable,{origin,memberId:'b',now:0,validate:allow}).point,null);assert.equal(advanceMercenarySafeDrop(stable,{origin,memberId:'b',now:50,validate:allow}).checks,0);
 const changed=advanceMercenarySafeDrop(stable,{origin,memberId:'b',now:100,validate:p=>({ok:true,point:{...p,y:1}})});assert.equal(changed.point,null);assert(changed.refused>0);
 const moved=advanceMercenarySafeDrop(stable,{origin:{x:20,z:0},memberId:'b',now:200,validate:allow});assert.equal(moved.point,null);const final=advanceMercenarySafeDrop(stable,{origin:{x:20,z:0},memberId:'b',now:300,validate:allow});assert(final.point);assert(Math.hypot(final.point.x-20,final.point.z)<10);
});

test('validator requires full footprint, dry stable supports, building exclusion and actual vehicle clearance',()=>{
 const base={worldScale:4.1,ready:()=>true,queryPoint:()=>({blocked:false,depth:0}),bodyClear:()=>true,groundHeight:()=>0,isInsideBuilding:()=>false,blocksVehicle:()=>false},p={x:0,z:0};
 assert(createMercenarySafePlacement(base).check(p,member()).ok);
 for(const [key,value,reason]of [['ready',()=>false,'resolver_unavailable'],['bodyClear',()=>false,'body_blocked'],['queryPoint',q=>({blocked:false,depth:q.x>0?.1:0}),'water'],['groundHeight',x=>x>0?1:0,'uneven_ground'],['isInsideBuilding',p=>p.x>0,'building'],['blocksVehicle',()=>true,'vehicle']])assert.equal(createMercenarySafePlacement({...base,[key]:value}).check(p,member()).reason,reason);
 assert.equal(createMercenarySafePlacement({...base,blocksVehicle:undefined}).check(p,member()).reason,'resolver_unavailable');
});

const originalScript=fs.readFileSync(new URL('mercenary_world.js',import.meta.url),'utf8');
const script=originalScript.replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');
const hostSource=fs.readFileSync(new URL('test_mercenary_rally_actions.mjs',import.meta.url),'utf8');
const hostBody=hostSource.slice(hostSource.indexOf('async function fixture('),hostSource.indexOf("for(const [profession,kind,targetKind]"));
const fixture=Function('vm','module','script','assert',hostBody+';return fixture;')(vm,module,script,assert);
let actualPromise;
const actual=()=>actualPromise??=(async()=>{const snapshot=JSON.parse(zlib.gunzipSync(fs.readFileSync(new URL('test_fixtures/native_static_collision19.json.gz',import.meta.url))));return createCivilianNativeFixture({snapshot,assetId:'woodland_crosswing_house_v1'});})();
function actualPlacement(f,bodyClear){return createMercenarySafePlacement({worldScale:f.M,ready:()=>true,queryPoint:p=>f.pedestrian.query({r:p.z/f.M,c:p.x/f.M}),bodyClear:bodyClear||((p)=>f.box._npcPathPassable(p.z/f.M,p.x/f.M,p.z/f.M,p.x/f.M,f.box.npcPassableForSnitch)),groundHeight:f.floor,isInsideBuilding:p=>f.entry.containsInterior(p),blocksVehicle:(p,b)=>npcVehicleBlocks(f.actor,p.x,p.z,b.radius,{y:p.y,height:b.height})});}

test('actual static native city187 shore can recover to hero with real full-body geometry; center-water and actual car are rejected',async()=>{
 const f=await actual(),placement=actualPlacement(f),start={x:45.13844472385925*f.M,z:27.799313847727056*f.M},h={position:{x:40*f.M,z:40*f.M},alive:true};
 assert(placement.check(start,{id:'187'}).ok,'reported shore point really is dry and passable');
 const m={...member('187'),position:start},c=createMercenaryCatchup({placement}),moves=simulate(c,[m],11,{heroValue:h});assert.equal(moves.length,1);assert.equal(moves[0].reason,'stuck');assert(placement.check(m.position,m).ok);assert(Math.hypot(m.position.x-h.position.x,m.position.z-h.position.z)<10);
 assert(!placement.check({x:41.644286187278674*f.M,z:start.z},{id:'wet'}).ok,'original water point is not an allowed drop');
 f.car.r=m.position.z/f.M;f.car.c=m.position.x/f.M;f.nextFrame();assert(!placement.check(m.position,m).ok,'actual compact sedan occupies the chosen destination');
 f.car.r=f.car.c=0;f.nextFrame();assert(placement.check(m.position,m).ok);
});

test('actual source host187 recovers, preserves ownership/cash/HP, then resumes ordinary physical follow',async()=>{
 const f=await actual(),host=await fixture(),m=host.recruit('bruiser');host.ctx.player.r=40;host.ctx.player.c=40;m.r=27.799313847727056;m.c=45.13844472385925;
 host.ctx._npcPathPassable=(...args)=>f.box._npcPathPassable(...args.slice(0,4),f.box.npcPassableForSnitch);host.ctx._npcBodyPassable=(r,c)=>f.box._npcBodyPassable(r,c,f.box.npcPassableForSnitch);host.ctx._clearNpcRoute=f.box._clearNpcRoute;
 const placement=actualPlacement(f,(p,n)=>host.api.canMoveMember(n.id,{r:p.z/f.M,c:p.x/f.M},{r:p.z/f.M,c:p.x/f.M}));
 const saved={cash:host.ctx.QP.cash,id:m.id,hp:m.hp,weapon:m.weapon},samples=[],costs=[];
 host.api.bindTargets({groundHeight:f.floor,canMove:()=>true,safeCatchupPoint:(p,id)=>{const t=performance.now(),r=placement.check(p,{id});costs.push(performance.now()-t);return r;}});
 for(let i=0;i<240;i++){f.nextFrame(.05);host.tick(.05);if(m._mercenaryCatchup&&!samples.length)samples.push({...m._mercenaryCatchup});}
 assert.equal(samples.length,1);assert.equal(samples[0].reason,'stuck');assert(placement.check({x:samples[0].c*f.M,z:samples[0].r*f.M},{id:m.id}).ok);assert(Math.hypot((m.r-40)*f.M,(m.c-40)*f.M)<10);
 assert.deepEqual({cash:host.ctx.QP.cash,id:m.id,hp:m.hp,weapon:m.weapon},saved);assert.equal(host.api.getRoster().members.length,1);assert.equal(m._waterEscaping,false);
 const delta=Math.hypot((m.r-samples[0].r)*f.M,(m.c-samples[0].c)*f.M);assert(delta>.05,'post-recovery body moves physically toward formation');
 costs.sort((a,b)=>a-b);console.log(JSON.stringify({case:'actual187',drop:samples[0],checks:costs.length,checkMs:{p50:costs[Math.floor(costs.length*.5)],p95:costs[Math.floor(costs.length*.95)]},afterMovementM:delta,limits:f.limits}));
});

test('actual city five followers recover from the shared lake point while hero walks; maximum four checks/frame',async()=>{
 const f=await actual(),h=await fixture(),crew=['medic','bruiser','safecracker','engineer','demolitions'].map(p=>h.recruit(p));h.ctx.player.r=40;h.ctx.player.c=40;
 for(const m of crew){m.r=27.799313847727056;m.c=41.644286187278674;}
 h.ctx._npcPathPassable=(...args)=>f.box._npcPathPassable(...args.slice(0,4),f.box.npcPassableForSnitch);h.ctx._npcBodyPassable=(r,c)=>f.box._npcBodyPassable(r,c,f.box.npcPassableForSnitch);h.ctx._clearNpcRoute=f.box._clearNpcRoute;
 const placement=actualPlacement(f,(p,n)=>h.api.canMoveMember(n.id,{r:p.z/f.M,c:p.x/f.M},{r:p.z/f.M,c:p.x/f.M}));let checks=0,maxChecks=0;const seen=new Map();
 h.api.bindTargets({groundHeight:f.floor,canMove:()=>true,safeCatchupPoint:(p,id)=>{checks++;return placement.check(p,{id})}});
 for(let i=0;i<270;i++){
  if(i>=180)h.ctx.player.c+=.001;f.nextFrame(.05);checks=0;h.tick(.05);maxChecks=Math.max(maxChecks,checks);assert(checks<=4);
  for(const m of crew)if(m._mercenaryCatchup&&!seen.has(m.id)){
   const p={x:m._mercenaryCatchup.c*f.M,z:m._mercenaryCatchup.r*f.M};assert(placement.check(p,{id:m.id}).ok);assert(Math.hypot(p.x-h.ctx.player.c*f.M,p.z-h.ctx.player.r*f.M)<10);
   for(const other of crew)if(other!==m&&!other._mercenaryVehicleSeat)assert(Math.hypot(p.x-other.c*f.M,p.z-other.r*f.M)>=1.5,'crew body spacing after same-tick physical follow');seen.set(m.id,p);
  }
 }
 assert.equal(seen.size,5);assert(crew.every(m=>Math.hypot((m.r-h.ctx.player.r)*f.M,(m.c-h.ctx.player.c)*f.M)<10));console.log(JSON.stringify({case:'actualFiveSharedWater',recovered:seen.size,maxChecksPerTick:maxChecks}));
});

test('actual house interior is separately rejected even when native foot collision allows that room',async()=>{
 const f=await actual(),center=f.entry.roomCenterPoint(),placement=actualPlacement(f);let interior=null;
 for(let dx=-5;dx<=5&&!interior;dx+=.4)for(let dz=-5;dz<=5&&!interior;dz+=.4){const p={x:center.x+dx,z:center.z+dz};if(f.entry.containsInterior({...p,y:f.floor(p.x,p.z)+.9})&&f.box._npcPathPassable(p.z/f.M,p.x/f.M,p.z/f.M,p.x/f.M,f.box.npcPassableForSnitch))interior=p;}
 assert(interior,'actual room has a physically accessible point');assert.equal(placement.check(interior,{id:'m'}).reason,'building');
});

test('actual host cannot recover without native validator or while authority, task, rally or pause blocks it',async()=>{
 for(const gate of ['missing','authority','rally','hidden','combat','carried','action','local_vehicle','vehicle_enter','vehicle_exit']){
  const h=await fixture(),m=h.recruit('bruiser');m.c+=30;let checks=0;
  h.api.bindTargets({canMove:()=>false,...(gate==='missing'?{}:{safeCatchupPoint:p=>{checks++;return allow(p)}})});
  if(gate==='authority')h.ctx._serverAuthoritativeAmmo=true;if(gate==='rally')m._mercenaryOrder='rally';if(gate==='hidden')h.ctx.document.hidden=true;if(gate==='combat')m._threatUntil=2000000;if(gate==='carried')m._carriedByAmbulance=true;
  if(gate==='action'){const target={id:'target',kind:'npc',hp:100,position:{x:1000,z:1000}};h.api.bindTargets({canMove:()=>false,get:()=>target,safeCatchupPoint:p=>{checks++;return allow(p)}});assert(h.api.command('intimidate',target).ok);}
  if(gate==='local_vehicle')h.api.bindTargets({canMove:()=>false,safeCatchupPoint:p=>{checks++;return allow(p)},squadTransport:{setReservations:()=>{},getPlayerVehicle:()=>({id:'fleet:test',ready:true,r:10,c:10,ang:0,speed:0,seats:['front_right','rear_left','rear_right'],occupied:['front_right','rear_left','rear_right']})}});
  if(gate==='vehicle_enter'||gate==='vehicle_exit'){
   const bridge=createMercenaryVehicleBridge({getPlayer:()=>({id:'fleet:test',seatId:'front_left',ready:gate!=='vehicle_enter',exiting:gate==='vehicle_exit'})});assert.equal(bridge.getPlayerVehicle(),null);assert.equal(bridge.isPlayerInVehicle(),true);
   h.api.bindTargets({canMove:()=>false,safeCatchupPoint:p=>{checks++;return allow(p)},squadTransport:bridge});
  }
  for(let i=0;i<150;i++)h.tick(.05);assert.equal(m._mercenaryCatchup,undefined,gate);assert.equal(checks,0,gate);
 }
});

test('actual shared wrapper excludes player/citizens, fails closed on population overflow, and reserves one common four-check allowance',async()=>{
 // Expose existing lexical functions for this test; their bodies are unchanged.
 const exposed=script.replace('window.MafioziMercenaries=api;','window.__drop={findSquadSafeDrop,validateSquadSafeDrop};window.MafioziMercenaries=api;');
 const make=Function('vm','module','script','assert',hostBody+';return fixture;')(vm,module,exposed,assert),h=await make(),m=h.recruit('bruiser');let checks=0;
 h.api.bindTargets({canMove:()=>true,safeCatchupPoint:p=>{checks++;return allow(p)}});h.tick();const drop=h.ctx.window.__drop;
 assert.equal(drop.validateSquadSafeDrop(m,{x:41,z:41}),null,'player owns this spot');
 h.ctx.NPCS.push({id:'passing',hp:100,r:50/4.1,c:50/4.1});h.tick();
 assert.equal(drop.validateSquadSafeDrop(m,{x:50,z:50}),null,'live passing citizen owns this spot');
 assert(drop.validateSquadSafeDrop(m,{x:60,z:60}));assert(drop.validateSquadSafeDrop(m,{x:60,z:60}));assert(drop.validateSquadSafeDrop(m,{x:60,z:60}));assert.equal(drop.validateSquadSafeDrop(m,{x:60,z:60}),null);assert.equal(checks,3);
 h.ctx.NPCS=Array.from({length:1025},(_,i)=>({id:'crowd'+i,hp:100,r:100,c:100}));h.tick();assert.equal(drop.validateSquadSafeDrop(m,{x:60,z:60}),null,'overflow cannot silently omit possible occupant');assert.equal(checks,3);
});

test('ordinary near-leader five-member updates do no geometry work',()=>{
 let geometry=0;const c=createMercenaryCatchup({placement:{check:p=>{geometry++;return allow(p)}}}),crew=Array.from({length:5},(_,i)=>member('near'+i,3+i));
 const costs=[];for(let i=0;i<6600;i++){const start=performance.now();c.update({now:i*1000/60,hero,members:crew});if(i>=600)costs.push(performance.now()-start);}
 assert.equal(geometry,0);costs.sort((a,b)=>a-b);console.log(JSON.stringify({case:'dryFiveNoRecovery',geometryChecks:geometry,updateMs:{p50:costs[3000],p95:costs[5700]}}));
});
