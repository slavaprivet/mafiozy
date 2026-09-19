import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import {performance}from'node:perf_hooks';
const source=fs.readFileSync(new URL('npc_activity_reservations_source.js',import.meta.url),'utf8');
function fixture(){let now=1000;const doors=[],NPCS=[],RESIDENTS_INDOORS=[],b={performance:{now:()=>now},Map,Set,WeakMap,Math,Number,Infinity,NPCS,RESIDENTS_INDOORS,_residentBuildingDoors:()=>doors};vm.createContext(b);vm.runInContext(source,b);return{b,doors,NPCS,RESIDENTS_INDOORS,tick:t=>{now=t;return b._npcActivitySlotsTick(t);}};}
const f=fixture(),b=f.b,door={id:'native:shop-a',native:true,instanceId:'shop-a',sourceId:'same-prototype',objectId:'not-instance'},other={id:'native:shop-b',native:true,instanceId:'shop-b',sourceId:'same-prototype',objectId:'not-instance'};f.doors.push(door,other);
assert.equal(b._npcActivityDoorKey(door),'native:shop-a');assert.notEqual(b._npcActivityDoorKey(door),b._npcActivityDoorKey(other));
assert.equal(b._npcActivityDoorKey({...door,id:'other-entrance'}),b._npcActivityDoorKey(door),'physical aliases share instance');
assert.equal(b._npcActivityDoorKey({native:true,id:'native:shop-a'}),'native:shop-a');
assert.equal(b._npcActivityDoorKey({id:'shop-a'}),'legacy:shop-a');assert.equal(b._npcActivityDoorKey({native:true,sourceId:'prototype'}),null);
const n={id:'resident',hp:100,r:1,c:2,_civilianPlan:{phase:'walk_to_shop',doorId:door.id},_routeKind:'building_entry',_route:[{r:3,c:2}],_routeIndex:0};f.NPCS.push(n);
assert(b._npcActivityClaimDoor(n,door,1000));f.tick(1000);
for(let t=2000;t<=60000;t+=1000){n.r+=.05;f.tick(t);}
assert.equal(b._npcActivityBuildingReservation(n).phase,'reserved','moving long approach retains claim');
n._residentNativeVisit={phase:'entering',door};assert(b._npcActivityEnterDoor(n,door,61000));f.tick(61000);
assert(!b._npcActivityCancelPending(n,'panic'),'pending cancel cannot steal physically occupied slot');
n.panicUntil=10000000;n._residentNativeVisit.phase='exiting';f.doors.length=0;f.tick(1000000);
assert.equal(b._npcActivityBuildingReservation(n).phase,'inside','exiting panic and empty streaming registry preserve capacity');
n._residentNativeVisit=null;f.tick(1000250);assert.equal(b._npcActivityBuildingReservation(n),null,'physical exit releases');
const legacy={id:'legacy-shop'},l={id:'indoors',hp:100,_residentIndoors:true,_residentDoor:legacy};f.RESIDENTS_INDOORS.push(l);assert(b._npcActivityEnterDoor(l,legacy,1000250));f.tick(1000500);
assert.equal(b._npcActivityBuildingReservation(l).phase,'inside','legacy interior list preserves absent exterior actor');
f.RESIDENTS_INDOORS.length=0;f.tick(1000750);assert.equal(b._npcActivityBuildingReservation(l),null,'actual object removal releases');
const g=fixture(),gb=g.b;g.doors.push(door);
const stalled={id:'stalled',hp:100,r:2,c:3,_civilianPlan:{phase:'seek_shop',doorId:door.id},_routeSearchKind:'building_entry',_routeSearchPending:true,_npcDirectedSearch:{qi:0}};g.NPCS.push(stalled);
assert(gb._npcActivityClaimDoor(stalled,door,1000));g.tick(1000);g.tick(45999);assert(gb._npcActivityBuildingReservation(stalled));g.tick(46250);assert.equal(gb._npcActivityBuildingReservation(stalled),null,'no progress times out');
assert(!gb._npcActivityClaimDoor(stalled,door,46251),'stalled same door cannot immediately reclaim indefinitely');
assert(gb._npcActivityClaimDoor(stalled,door,61251),'temporary stalled cooldown expires');
// Search growth refreshes normal lease but not an endless no-movement loop.
for(let t=61501;t<=181501;t+=250){stalled._npcDirectedSearch.qi++;g.tick(t);}
assert.equal(gb._npcActivityBuildingReservation(stalled),null,'search alone cannot hold a slot longer than 120 seconds');
const h=fixture(),hb=h.b;h.doors.push(door);
const noPlan={id:'bandit',hp:100,r:2,c:3,_residentDoor:door,_routeKind:'building_entry',_route:[{r:4,c:3}]};h.NPCS.push(noPlan);assert(hb._npcActivityClaimDoor(noPlan,door,1000));h.tick(1000);noPlan.r+=.1;h.tick(4000);assert(hb._npcActivityBuildingReservation(noPlan),'non-purposeful source actor completed route retains residentDoor');
noPlan._routeKind='walk';noPlan._route=null;h.tick(4250);assert.equal(hb._npcActivityBuildingReservation(noPlan),null,'abandoned target releases');
const active={id:'death',hp:100,_residentNativeVisit:{phase:'browsing',door}};h.NPCS.push(active);assert(hb._npcActivityEnterDoor(active,door,4500));active.hp=0;h.tick(4500);assert.equal(hb._npcActivityBuildingReservation(active),null,'inside death releases on lifecycle tick');
const perf=fixture(),times=[];
for(let i=0;i<24;i++)perf.doors.push({id:'native:shop-'+i,instanceId:'shop-'+i,native:true});
for(let i=0;i<288;i++){const d=perf.doors[Math.floor(i/12)],owner={id:'perf'+i,hp:100,r:10,c:10,_civilianPlan:{phase:'walk_to_shop',doorId:d.id},_routeKind:'building_entry',_route:[{r:30,c:10}]};perf.NPCS.push(owner);assert(perf.b._npcActivityClaimDoor(owner,d,1000));}
for(let i=0;i<300;i++){for(const owner of perf.NPCS)owner.r+=.04;const start=performance.now();perf.tick(1000+i*250);times.push(performance.now()-start);}
times.sort((a,b)=>a-b);assert.equal(perf.b._npcActivityBuildingReservationSummary().owners,288);
console.log(JSON.stringify({pass:true,checks:'canonical physical aliases; moving approach; active pending/search timeout; no-plan resident; abandoned target; entering/exiting; empty streamed registry; legacy inside; death and removal; stalled cooldown',performance:{residents:288,ticks:300,p50Ms:times[150],p95Ms:times[285],maxMs:times.at(-1)},limit:'Actual world-safe helper/adapters with controlled source fields; no full world tick or GPU.'},null,2));
