import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import {performance} from 'node:perf_hooks';
const world=fs.readFileSync('world.html','utf8'),source=fs.readFileSync('assets/maps/city_rebuild_v1/npc_civilian_activity_source.js','utf8');
function fn(name){const start=world.indexOf('function '+name+'(');assert(start>=0,name);let p=world.indexOf('{',start),depth=1;for(p++;depth;p++){if(world[p]==='{')depth++;if(world[p]==='}')depth--;}return world.slice(start,p);}
function setup(activitySource=source){
 let now=1000,pending=true,routeCalls=0;const bench={id:'physical-bench',r:11,c:10,yaw:0,seatWorldY:.61},NPCS=[];
 const b={Math,Number,Object,Map,Set,NPCS,performance:{now:()=>now},_civilianBenchReservations:new Map(),_civilianPlaces:{benches:[bench]},_civilianPlanEligible:()=>true,_walkNpcNavigationResolver:()=>({surface:'land',depth:0,blocked:false}),_walkRendererActive:()=>true,_npcStableUnit:()=>.2,_residentCanSocialize:()=>false,_findNpcSocialPair:()=>null,_clearNpcRoute:n=>{n._route=null;n._routeKind=null;},_cancelNpcDirectedSearch:n=>{n._routeSearchPending=false;},_civilianRouteTo(n,r,c,kind){routeCalls++;n._routeSearchPending=pending;n._routeSearchKind=pending?kind:null;if(!pending){n._route=[{r,c}];n._routeKind=kind;}return !pending;}};
 vm.createContext(b);vm.runInContext(['_civilianPlanUnit','_civilianPlanInterrupted','_civilianPlanCancel','_civilianPlanNext','_civilianPlanArrive'].map(fn).join('\n')+activitySource+'\nglobalThis.records=_npcCivilianActivities;',b);
 const actor=id=>{const n={id:'resident_'+id,hp:100,r:10,c:10,walking:false,_civilianPlan:{phase:'walk_to_bench',cycle:0}};NPCS.push(n);return n;};
 return {b,bench,actor,setPending:v=>pending=v,get routeCalls(){return routeCalls;},tick(t){now=t;b._npcPurposefulSocialTick(now);},claim(n){return b._civilianPlanNext(n,now);}};
}
// Actual claim-before-search and cleanup: a removed resident cannot hold the
// only bench for its 120-second route lease. The contender can claim next tick.
{
 const f=setup(),owner=f.actor('removed'),other=f.actor('contender');assert.equal(f.claim(owner),false);assert(owner._routeSearchPending);assert.equal(f.routeCalls,1);
 f.b.NPCS.splice(f.b.NPCS.indexOf(owner),1);f.tick(1001);assert.equal(f.b._civilianBenchReservations.size,0);f.claim(other);assert.equal(f.b._civilianBenchReservations.get(f.bench.id).id,other.id);assert.equal(f.routeCalls,2);
}
// Being present but pending, walking or sitting is never an orphan.
for(const phase of ['pending','walking','rest']){
 const f=setup(),n=f.actor(phase);f.setPending(phase==='pending');f.claim(n);
 if(phase==='rest'){n.r=n._civilianPlan.targetR;n.c=n._civilianPlan.targetC;assert(f.b._civilianPlanArrive(n,1000));}
 const claim=f.b._civilianBenchReservations.get(f.bench.id),plan=n._civilianPlan,path=n._route;
 for(const now of [1001,2401,3801])f.tick(now);
 assert.equal(f.b._civilianBenchReservations.get(f.bench.id),claim,phase+' claim retained');assert.equal(n._civilianPlan,plan);assert.equal(n._route,path);
}
// Use the real activity attach/release handlers, with starters disabled so the
// cleanup itself cannot mask a released slot by creating a new activity.
function attach(f,kind,members,phase='active'){
 const record={id:kind,kind,members,phase,until:50000};f.b.records.add(record);
 for(const n of members)f.b._npcCivilianActivityAttach(record,n,phase,1000,record.until);
 return record;
}
for(const kind of ['talk','jog','smoke','read']){
 const f=setup(),a=f.actor(kind),b=kind==='talk'?f.actor('partner'):null,record=attach(f,kind,b?[a,b]:[a]);
 f.tick(1001);assert(f.b.records.has(record),'normal live activity kept '+kind);
 f.b.NPCS.splice(f.b.NPCS.indexOf(a),1);f.tick(1500);assert(f.b.records.has(record),'cleanup waits existing cadence');f.tick(2401);assert(!f.b.records.has(record));assert.equal(a._civilianActivity,null);if(b)assert.equal(b._civilianActivity,null,'both old talk participants released');
}
{
 const f=setup(),a=f.actor('replacement'),partner=f.actor('oldpartner'),old=attach(f,'talk',[a,partner]);
 const replacement=attach(f,'smoke',[a]);const current=a._civilianActivity;f.tick(1001);
 assert(!f.b.records.has(old),'old record releases shared activity limit');assert(f.b.records.has(replacement));assert.equal(a._civilianActivity,current,'new owner survives old cleanup');assert.equal(partner._civilianActivity,null);
}
{
 const f=setup(),a=f.actor('cleared'),old=attach(f,'smoke',[a]);a._civilianActivity=null;f.tick(1001);assert(!f.b.records.has(old),'cleared ownership releases old record');
}
{
 const f=setup(),a=f.actor('deadreader');f.setPending(false);f.claim(a);a.r=a._civilianPlan.targetR;a.c=a._civilianPlan.targetC;assert(f.b._civilianPlanArrive(a,1000));assert(a._civilianActivity?.kind==='read');a.dead=true;f.tick(1001);assert.equal(f.b.records.size,0);assert.equal(a._civilianSeat,null);assert.equal(f.b._civilianBenchReservations.size,0);
}
// A full valid activity set stays full. No eviction to manufacture free slots.
{
 const f=setup();for(let i=0;i<20;i++)attach(f,'smoke',[f.actor('full_'+i)]);f.tick(1001);assert.equal(f.b.records.size,20);
 // Production cleanup must not call linear NPCS.includes per record.
 f.b.NPCS.includes=()=>assert.fail('nested resident membership scan');f.tick(2401);assert.equal(f.b.records.size,20);
}
// CPU-only upper small-world sample: one existing rare cleanup with 288 actors,
// 20 activity records and 100 seat claims; no renderer/FPS claim.
const start=source.indexOf(' // Cleanup shares the existing social cadence.'),end=source.indexOf(' let pairs=0,smokers=0;',start);assert(start>=0&&end>start);
const prior=source.slice(0,start)+" for(const record of _npcCivilianActivities)if(record.members.some(n=>!NPCS.includes(n)||_npcCivilianActivityThreat(n,now)))_npcReleaseCivilianActivity(record,'interrupted',now);\n"+source.slice(end);
const old=setup(prior),removed=old.actor('oldremoved');old.claim(removed);old.b.NPCS.length=0;old.tick(1001);assert.equal(old.b._civilianBenchReservations.size,1,'historical cleanup reproduces retained absent claim');
const detached=old.actor('olddetached'),oldRecord=attach(old,'smoke',[detached]);detached._civilianActivity=null;old.tick(2401);assert(old.b.records.has(oldRecord),'historical cleanup reproduces detached activity');
function cpu(code){const f=setup(code);for(let i=0;i<288;i++)f.actor('cpu_'+i);for(let i=0;i<20;i++)attach(f,'smoke',[f.b.NPCS[i]]);for(let i=0;i<100;i++)f.b._civilianBenchReservations.set('seat_'+i,{id:f.b.NPCS[i].id,until:1e9});const times=[];
 for(let i=0;i<200;i++){const at=performance.now();f.tick(1001+i*1400);if(i>=40)times.push(performance.now()-at);}times.sort((a,b)=>a-b);return{p50:times[80],p95:times[152]};}
console.log(JSON.stringify({pass:true,checks:['old cleanup failures reproduced','removed bench owner releases before lease','pending/walking/rest preserved','normal and removed activities','replacement owner preserved','cleared record released','dead reader releases bench','full active set retained','rare cadence and no nested includes'],cleanupCpuMs:{before:cpu(prior),after:cpu(source)},limits:'Actual source lifecycle with route boundary stub; no production scene/GPU/FPS acceptance'}));
