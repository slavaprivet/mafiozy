import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const world=fs.readFileSync('world.html','utf8');
const fn=name=>{const at=world.indexOf('function '+name+'(');assert(at>=0,name);const line=world.slice(at,world.indexOf('\n',at));return line.trimEnd().endsWith('}')?line:world.slice(at,world.indexOf('\n}',at)+2);};
const start=world.indexOf('    if(n._empireCrew&&!n._hostile&&!n._fighting&&!n._fightingMelee&&!(n.panicUntil>now)){'),end=world.indexOf('    if(n._empireBoss&&n._empireAction',start),deployed=world.slice(start,end);
const before="if(!n._empireRouteQueued)_planEmpireRouteTo(n,target.r,target.c,.75,6000,'empire_escort'";
const after="if(!n._empireRouteQueued||n._empirePendingRoute?.kind==='empire_escort'&&Math.hypot(n._empirePendingRoute.goalR-target.r,n._empirePendingRoute.goalC-target.c)>5.2)_planEmpireRouteTo(n,target.r,target.c,.75,6000,'empire_escort'";
const original=deployed.replace(after,before);
assert(original.includes(before),'candidate applies only to pending escort request');
if(process.argv.includes('--require-fixed'))assert(deployed.includes(after),'actual production includes retarget guard');
const candidate=process.argv.includes('--require-fixed')?deployed:original.replace(before,after);
const live={r:33.39145238586954,c:74.38497662929882,oldGoal:{r:30.5,c:72.5},target:{r:27.5,c:80.5},leader:{r:28.763414634146336,c:78.5}};
function fixture(fixed){
 let now=1000;
 const leader={...live.leader,_specialistId:'sofia',speed:.76,ang:0},b={Math,Number,Map,Set,Array,Uint32Array,MAP_COLS:200,MAP_ROWS:200,performance:{now:()=>now},prevT:1,SPECIALIST_NPCS:[leader],document:{documentElement:{dataset:{}}},_walkNpcNavigationResolver:()=>({surface:'land'}),_npcPacedSpeed:s=>s,_empireMovementWatch:()=>{},_empireSpeak:()=>{},_empireSeparationVector:()=>({r:0,c:0})};
 b.npcPassable=()=>{now+=.1;return true;};b._empireBossPassable=b.npcPassable;b._empireBossWaypointPassable=b.npcPassable;
 vm.createContext(b);vm.runInContext(world.slice(world.indexOf('let _npcRouteWorkFrame='),world.indexOf('function _planNpcRouteTo(')),b);vm.runInContext(world.slice(world.indexOf('const _empireRoutePlanQueue=[];'),world.indexOf('function _empireCrewOrigin(')),b);
 for(const name of ['_clearNpcRoute','_setNpcRoute','_planNpcRouteTo','_npcAdvanceRoute','_npcBodyPassable','_npcPathPassable','_nearestEmpireWalkPoint','_empireFormationOffset','_cancelEmpireEscortRoute','_planEmpireRouteTo','_processEmpireRoutePlanQueue'])vm.runInContext(fn(name),b);
 vm.runInContext('globalThis.crewTick=(actor,dt,now)=>{for(const n of [actor]){'+(fixed?candidate:original)+'}};',b);
 const n={id:'empire_crew_sofia_12',r:live.r,c:live.c,hp:60,walkPhase:0,speed:1.06,_empireCrew:true,_empireLeaderId:'sofia',_empireRouteGeneration:4,_empireCrewSlot:3,_empireFormationTarget:{...live.target},_empireFormationTargetAt:Infinity,_empireFormationLeaderR:leader.r,_empireFormationLeaderC:leader.c};
 b.n=n;
 return{b,n,get now(){return now},frame(){now+=150;b.prevT++;},read:s=>vm.runInContext(s,b)};
}
function request(f,goal=live.oldGoal,kind='empire_escort'){f.b._planEmpireRouteTo(f.n,goal.r,goal.c,.75,6000,kind,1200,6,'sofia');}
function run(fixed){
 const f=fixture(fixed),{b,n}=f;request(f);b._processEmpireRoutePlanQueue(f.now);assert(n._routeSearchPending);const previous=n._npcDirectedSearch;
 f.read('_npcRouteWorkQueue.set({id:"older"},_npcRouteWorkEpoch);_npcRouteWorkQueue.set(n,_npcRouteWorkEpoch);_npcRouteWorkQueue.set({id:"younger"},_npcRouteWorkEpoch);');
 const sharedBefore=f.read('[..._npcRouteWorkQueue.keys()].map(n=>n.id).join(",")');
 const queueBefore=f.read('_empireRoutePlanQueue.slice()');f.frame();b.crewTick(n,1/7,f.now);
 const q=n._empirePendingRoute;assert(q);assert.equal(f.read('_empireRoutePlanQueue.length'),1);assert.equal(f.read('_empireRoutePlanQueue[0]'),queueBefore[0]);
 assert.equal(f.read('[..._npcRouteWorkQueue.keys()].map(n=>n.id).join(",")'),sharedBefore,'coalesce preserves shared queue position');assert.equal(q.generation,4);assert.equal(q.targetKey,'sofia');
 if(fixed){assert.equal(q.goalR,live.target.r);assert.equal(q.goalC,live.target.c);}
 else{assert.equal(q.goalR,live.oldGoal.r);assert.equal(q.goalC,live.oldGoal.c);}
 for(let i=0;i<8;i++){f.frame();b.crewTick(n,1/7,f.now);assert.equal(n._empirePendingRoute,q,'identical current target does not replace request every frame');}
 b._processEmpireRoutePlanQueue(f.now);if(fixed)assert.notEqual(n._npcDirectedSearch,previous,'next slice rebuilds frontier for the new target');
 return{fixed,requestGoal:{r:q.goalR,c:q.goalC},queueLength:f.read('_empireRoutePlanQueue.length'),restarts:n._routeSearchRestarts||0};
}
const reports=[run(false),run(true)];
for(const mode of ['near-drift','other-owner','hostile','melee','panic']){
 const f=fixture(true),{b,n}=f;
 request(f,mode==='near-drift'?{r:live.target.r+5,c:live.target.c}:live.oldGoal,mode==='other-owner'?'empire_retreat':'empire_escort');
 const q=n._empirePendingRoute;if(mode==='hostile')n._hostile=true;if(mode==='melee')n._fightingMelee=true;if(mode==='panic')n.panicUntil=Infinity;
 b.crewTick(n,1/7,f.now);assert.equal(n._empirePendingRoute,q,mode);
}
fs.writeFileSync('outputs/empire_escort_retarget23_candidate.json',JSON.stringify({reports,production:process.argv.includes('--require-fixed'),capturedAt:'2026-09-22T22:29:59.531Z',driftCells:Math.hypot(live.oldGoal.r-live.target.r,live.oldGoal.c-live.target.c),limits:'Captured Sofia12 start/request/current formation, actual crew/pump/planner with controlled open predicates. With --require-fixed the fixed branch is read verbatim from world.html. No native geometry or LIVE acceptance in this test.'},null,2));
console.log(reports);
