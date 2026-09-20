import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
const world=fs.readFileSync('world.html','utf8'),activities=fs.readFileSync('assets/maps/city_rebuild_v1/npc_civilian_activity_source.js','utf8'),elapsed=fs.readFileSync('assets/maps/city_rebuild_v1/npc_civilian_elapsed_source.js','utf8');
function fn(src,name){const start=src.indexOf('function '+name+'(');assert(start>=0,name);let p=src.indexOf('{',start),d=1;for(p++;d;p++){if(src[p]==='{')d++;if(src[p]==='}')d--;}return src.slice(start,p);}
for(const call of ['_npcAccumulateActivityElapsed(n,now)','_npcConsumeActivityElapsed(n,now)','_npcRunActivityElapsed(n,n._residentNativeVisit?civilianActivityElapsed:null,dt,now,_residentNativeVisitTick)','_npcRunActivityElapsed(n,n._civilianActivity?civilianActivityElapsed:null,dt,now,_npcPurposefulActivityTick)'])assert(world.includes(call),call);
const timingStart=world.indexOf('  let dt = (t - prevT) / 1000;'),timing=world.slice(timingStart,world.indexOf('// КРИТИЧНО:',timingStart));
function fixture(kind='visit',far=false){
 let now=1000,wall=Infinity,afterSweep=null;const sweeps=[];
 const n={id:'resident_activity_elapsed',r:80,c:80,walkPhase:0,hp:100,maxHp:100,speed:10,_npcSimDue:1000};
 const context={native:true,hidden:false,battle:false,hitStop:false,resuming:false};
 const sweep=(r,c,r1,c1)=>{sweeps.push(Math.hypot(r1-r,c1-c));afterSweep?.();return r1<wall;};
 const b={Math,Number,performance:{now:()=>now},document:{hidden:false},_battleOpen:false,hitStopUntil:0,_worldResumeFrames:0,player:{r:far?0:80,c:far?0:80},_walkRendererActive:()=>context.native,_civilianPlanInterrupted:()=>false,_walkTrafficNavigationResolver:()=>({ready:true}),_residentNativeSegmentPassable:sweep,_npcOutdoorActivityPath:sweep,_npcPathPassable:sweep,npcPassableForSnitch:()=>true,_npcCivilianActivityThreat:(actor,t)=>actor.dead||actor.panicUntil>t,_npcCivilianActivityStats:{blocked:0},_npcReleaseCivilianActivity:(record,reason)=>{record.released=reason;n._civilianActivity=null;n.walking=false;}};
 vm.createContext(b);vm.runInContext('const NPC_HERO_PACE={walk:1.8/4.1,run:7.8/4.1};const _npcSimulationStats={full:0,distant:0,deferred:0};'+['_npcPacedSpeed','_npcEffectiveSpeed','_npcSimulationDelta','_residentNativeVisitTick'].map(name=>fn(world,name)).join('\n')+['_npcOutdoorRoutineTick','_npcPurposefulActivityTick'].map(name=>fn(activities,name)).join('\n')+elapsed,b);
 vm.runInContext('let prevT=1000;globalThis.frameDelta=t=>{'+timing+'return dt;}',b);
 if(kind==='visit')n._residentNativeVisit={phase:'entering',door:{id:'test-door',inside:{r:100000,c:80}}};
 if(kind==='jog')n._civilianActivity={kind:'jog',phase:'active',until:1e9,record:{members:[n],index:0,path:[{r:100000,c:80}]}};
 if(kind==='social')n._civilianActivity={kind:'talk',phase:'approach',record:{members:[n],targets:[{r:100000,c:80}],deadline:1e9}};
 const tick=kind==='visit'?b._residentNativeVisitTick:b._npcPurposefulActivityTick;
 return {b,n,context,sweeps,tick,now:()=>now,setWall:r=>wall=r,setAfterSweep:f=>afterSweep=f,frame(seconds,{enabled=true,skip=false}={}){
  now+=seconds*1000;b.document.hidden=context.hidden;b._battleOpen=context.battle;b.hitStopUntil=context.hitStop?now+1:0;b._worldResumeFrames=context.resuming?1:0;
  const physics=b.frameDelta(now);if(skip)return;
  b._npcAccumulateCivilianElapsed(n,now);if(enabled)b._npcAccumulateActivityElapsed(n,now);
  const dt=b._npcSimulationDelta(n,physics,now);if(!dt)return;
  b._npcConsumeCivilianElapsed(n,dt,now);const token=enabled?b._npcConsumeActivityElapsed(n,now):null;
  return enabled?b._npcRunActivityElapsed(n,token,dt,now,tick):tick(n,dt,now);
 }};
}
const results=[];
for(const far of [false,true])for(const fps of [5,8,15])for(const kind of ['visit','jog','social'])for(const enabled of [false,true]){
 const f=fixture(kind,far);for(let i=0;i<20*fps;i++)f.frame(1/fps,{enabled});const norm=kind==='jog'?2.6:1.8,mps=(f.n.r-80)*4.1/20;
 assert(Math.abs(mps-norm*(enabled?1:Math.min(1,fps*.1)))<.035,JSON.stringify({kind,far,fps,enabled,mps}));
 if(enabled)assert(f.sweeps.every(d=>d<=norm*.1/4.1+1e-9),'every movement substep retains bounded collision check');
 results.push({kind,far,fps,enabled,mps:+mps.toFixed(3)});
}
for(const kind of ['visit','jog','social']){
 const f=fixture(kind);f.setWall(80+.04);f.frame(.2);assert(f.n.r<80+.04,'substep cannot cross thin obstacle '+kind);const blocked=f.n.r;f.setWall(Infinity);f.frame(.05);assert((f.n.r-blocked)*4.1<=.13+1e-9,'blocked debt not replayed '+kind);
 const threat=fixture(kind);threat.setAfterSweep(()=>threat.n.panicUntil=5000);threat.frame(.2);assert.equal(threat.sweeps.length,1,'threat interrupts remaining substeps '+kind);
}
for(const reason of ['hidden','battle','hitStop','resuming']){
 const f=fixture('jog',true);f.n._npcSimDue=f.now()+240;f.frame(.1);assert(f.n._activityElapsedDebt>.09);const start=f.n.r;
 f.context[reason]=true;for(let i=0;i<40;i++)f.frame(.25,{skip:true});assert.equal(f.n.r,start);
 f.context[reason]=false;f.frame(.05);assert((f.n.r-start)*4.1<=.13+1e-9,'no catch-up after '+reason);
}
for(const field of ['dead','panicUntil','_policeCuffed','_civilianTrip']){
 const f=fixture('jog',true);f.n._npcSimDue=f.now()+240;f.frame(.1);f.n[field]=field==='panicUntil'?1e9:true;
 f.b._npcAccumulateActivityElapsed(f.n,f.now());assert.equal(f.n._activityElapsedDebt,0);delete f.n[field];const start=f.n.r;f.frame(.05);assert((f.n.r-start)*4.1<=.13+1e-9,'no catch-up after '+field);
}
const identity=fixture('jog',true);identity.n._npcSimDue=identity.now()+240;identity.frame(.1);identity.n._civilianActivity={...identity.n._civilianActivity};const identityStart=identity.n.r;identity.frame(.05);assert((identity.n.r-identityStart)*4.1<=.13+1e-9,'new activity cannot inherit debt');
const long=fixture('jog',true);long.n._npcSimDue=long.now()+240;long.frame(.1);const longStart=long.n.r;long.frame(30);assert((long.n.r-longStart)*4.1<=.26+1e-9,'long gap uses only capped fallback');
const phase=fixture();phase.setAfterSweep(()=>phase.n._residentNativeVisit.phase='browsing');phase.frame(.2);assert.equal(phase.sweeps.length,1,'phase transition ends movement substeps');
const pausedToken=fixture();pausedToken.b._npcBeginCivilianElapsedFrame(.2,pausedToken.context);pausedToken.b._npcAccumulateActivityElapsed(pausedToken.n,1000);const token=pausedToken.b._npcConsumeActivityElapsed(pausedToken.n,1000);pausedToken.b._npcResetCivilianElapsed();pausedToken.b._npcRunActivityElapsed(pausedToken.n,token,.05,1000,pausedToken.tick);assert.equal(pausedToken.sweeps.length,1,'stale epoch falls back to current dt only');
// Bound wrapper cost in a CPU-only, equal-distance workload: two legacy .1
// activity calls versus one compensated .2 call; no claim about scene FPS.
function cost(wrapped){const f=fixture();let sum=0;for(let i=0;i<1000;i++){const at=performance.now();if(wrapped)f.frame(.2);else {f.frame(.1,{enabled:false});f.frame(.1,{enabled:false});}sum+=performance.now()-at;}return sum;}
cost(false);cost(true);const cpuEqualDistanceMs={twoLegacySteps:cost(false),compensated:cost(true)};
console.log(JSON.stringify({pass:true,results,cpuEqualDistanceMs,scope:'actual source functions and frame hooks, stub collision boundaries; no browser/FPS acceptance'},null,2));
