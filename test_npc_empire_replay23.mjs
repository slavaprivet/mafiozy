import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createInspectionExport} from './assets/maps/city_rebuild_v1/npc_inspection_export.mjs';

const source=fs.readFileSync('world.html','utf8'),start=source.indexOf('function _residentVisitDiagnostics('),end=source.indexOf('\n}',start)+2,fn=source.slice(start,end);
const actors=Array.from({length:520},(_,i)=>({id:'resident_'+i,r:10,c:20,hp:60}));
Object.assign(actors[0],{id:'unique_niko',_empireBoss:true,_specialistId:'niko',_empireAction:{kind:'patrol'},_empireActionKey:'patrol:niko:1',_empireRouteGeneration:2,_empireTarget:{r:7,c:164},_routeRequestAt:500,_routeSearchPending:true,_empireRouteQueued:true,_empirePendingRoute:{goalR:7,goalC:164,goalRadius:.8,maxVisited:42000,kind:'empire_action',generation:2,targetKey:'patrol:niko:1'},_npcDirectedSearch:{algorithm:'astar-visit',fine:true,limit:41999,bestD:2.25,nodes:new Map([[0,{}]]),qi:1,heap:[{}],goalAnchors:new Map(),goalDiscovery:{index:3}}});
Object.assign(actors[1],{id:'empire_crew_leila_3',_empireCrew:true,_empireLeaderId:'leila',_routeRequestAt:10,_routeSearchPending:false,_empireFormationTarget:{r:24.5,c:15.5},_empireCrewSlot:3});
const dataset={},box={NPCS:actors,document:{documentElement:{dataset}},_UP:new Set(['npcqa']),_residentVisitDiagnosticAt:0,_civilianPlanEligible:()=>false,_civilianPlanInterrupted:()=>false,_npcRouteWorkQueue:new Map(),_npcRouteWorkBatch:new Set(),_npcRouteWorkStats:{},_npcRouteWorkUsedMs:0,_npcRouteWorkEpoch:0,_civilianBenchReservations:new Map()};
vm.createContext(box);vm.runInContext(fn,box);box._residentVisitDiagnostics(1000);
const replay=JSON.parse(dataset.npcRouteReplay),boss=replay.actors[0],idle=replay.actors[1];
assert.equal(replay.actors.length,512);assert.equal(boss.ageMs,500);
assert.deepEqual(boss.empireRequest,{goalR:7,goalC:164,goalRadius:.8,maxVisited:42000,kind:'empire_action',generation:2,targetKey:'patrol:niko:1',queued:true});
assert.equal(boss.search.fine,true);assert.equal(boss.search.goalAnchors,0);assert.equal(boss.empire.actionKind,'patrol');
assert.equal(idle.ageMs,null,'finished request is not reported as a current wait');assert.equal(idle.lastRequestAgeMs,990);assert.equal(idle.empire.targetR,24.5);assert.equal(idle.empire.targetC,15.5);
const exported=createInspectionExport({routeReplay:replay});assert.deepEqual(exported.routeReplay.actors[0].empireRequest,boss.empireRequest,'standard UI JSON exporter preserves request fields');
assert(!dataset.npcRouteReplay.includes('"nodes"'));assert(!dataset.npcRouteReplay.includes('"heap"'));
const saved=dataset.npcRouteReplay;box._residentVisitDiagnostics(1200);assert.equal(dataset.npcRouteReplay,saved,'1 Hz');box._UP.clear();box._residentVisitDiagnostics(4000);assert.equal(dataset.npcRouteReplay,saved,'QA only');
// Timings compare the identical 512-actor QA workload with and without the
// scalar additions; no navigation, renderer or gameplay work is invoked.
const baseline=fn.split('\n').filter(line=>!/^\s+(lastRequestAgeMs|empireRequest|empire:|search:)/.test(line)).join('\n');
const cost=code=>{vm.runInContext(code,box);box._UP.add('npcqa');const times=[];for(let i=0;i<250;i++){box._residentVisitDiagnosticAt=0;const at=performance.now();box._residentVisitDiagnostics(10000+i*1000);if(i>=25)times.push(performance.now()-at);}times.sort((a,b)=>a-b);return{p50:times[Math.floor(times.length*.5)],p95:times[Math.floor(times.length*.95)]};};
const report={pass:true,beforeMs:cost(baseline),afterMs:cost(fn),bytes:dataset.npcRouteReplay.length,checks:'512 scalar cap, 1 Hz/QA gates, no frontier serialization, pending goal identity, current versus historical age, standard UI export roundtrip',limits:'CPU diagnostic helper only, no full-scene performance or LIVE proof.'};
fs.writeFileSync('outputs/npc_empire_replay23.json',JSON.stringify(report,null,2));console.log(report);
