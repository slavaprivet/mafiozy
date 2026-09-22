import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {gunzipSync} from 'node:zlib';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';

const snapshot=JSON.parse(gunzipSync(fs.readFileSync('assets/maps/city_rebuild_v1/test_fixtures/native_static_collision19.json.gz')));
const helper=fs.readFileSync('test_empire_escort_cancel23.mjs','utf8').match(/const helper=`([\s\S]*?)`;/)[1];
async function run(fixed){
 const f=await createCivilianNativeFixture({snapshot}),b=f.box,s=f.source;
 for(const name of ['_inEmpireRecruitmentYard','_empireBossPassable','_empireBossWaypointPassable','_nearestEmpireWalkPoint','_empireFormationOffset','_empireLeaderIdOf','_empireCombatPool','_empireSeparationVector','_empireRecoverySide','_pauseEmpireMovementWatch','_empireMovementWatch'])vm.runInContext(sourceFunction(s,name),b);
 vm.runInContext(s.slice(s.indexOf('const _empireRoutePlanQueue=[];'),s.indexOf('function _empireCrewOrigin('))+sourceFunction(s,'_planEmpireRouteTo')+sourceFunction(s,'_processEmpireRoutePlanQueue')+helper,b);
 const start=s.indexOf('    if(n._empireCrew&&!n._hostile&&!n._fighting&&!n._fightingMelee&&!(n.panicUntil>now)){'),end=s.indexOf('    if(n._empireBoss&&n._empireAction',start);
 let branch=s.slice(start,end).replaceAll('_cancelEmpireEscortRoute(n);','');
 if(fixed)branch=branch.replace('_clearNpcRoute(n);const step=','_cancelEmpireEscortRoute(n);_clearNpcRoute(n);const step=').replace("if(moved==='arrived'||distance<.8){_clearNpcRoute(n);","if(moved==='arrived'||distance<.8){_cancelEmpireEscortRoute(n);_clearNpcRoute(n);");
 vm.runInContext('globalThis.crewTick=(actor,dt,now)=>{for(const n of [actor]){'+branch+'}};',b);
 // Observed Leila and escort3 positions from water-before23. Slot0 and the
 // old queued destination are controlled inputs, absent from the old export.
 const leader={id:'unique_leila',r:25.5,c:23.5,_specialistId:'leila',ang:0,speed:.8};
 const n={id:'empire_crew_leila_3',r:25.395547440325018,c:20.30881461788325,hp:60,_empireCrew:true,_empireLeaderId:'leila',_empireCrewSlot:0,speed:.98,walkPhase:0};
 b.SPECIALIST_NPCS=[leader];b.EMPIRE_CREW_NPCS=[n];b.EMPIRE_HOLDING_GUARDS=[];b._empireSpeak=()=>{};b.NPCS.push(n,leader);
 b._planEmpireRouteTo(n,24.5,15.5,.75,6000,'empire_escort',1200,6,'leila');
 const origin={r:n.r,c:n.c};f.nextFrame(1/7);b.crewTick(n,1/7,f.now);
 const moved=Math.hypot(n.r-origin.r,n.c-origin.c);assert(moved>0,'actual geometry permits a physical direct approach');
 assert(b._npcPathPassable(origin.r,origin.c,n.r,n.c,b._empireBossPassable));
 let calls=0;const pass=b._empireBossWaypointPassable;b._empireBossWaypointPassable=(...args)=>{calls++;return pass(...args);};
 const at=performance.now();f.nextFrame(1/7);b._processEmpireRoutePlanQueue(f.now);const pumpMs=performance.now()-at;
 if(fixed){assert.equal(calls,0);assert(!n._empirePendingRoute);assert(!n._routeSearchPending);}
 else assert(calls>0);
 return{fixed,moved,calls,pumpMs,position:{r:n.r,c:n.c},limits:f.limits};
}
const before=await run(false),after=await run(true);assert.deepEqual(after.position,before.position,'physical approach unchanged');
const report={before,after,limits:'Observed positions, controlled slot and old request; actual native geometry, crew branch and pump. No new LIVE or full-scene performance claim.'};
fs.writeFileSync('outputs/empire_escort_cancel_geometry23.json',JSON.stringify(report,null,2));console.log(report);
