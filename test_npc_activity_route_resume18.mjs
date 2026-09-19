import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import { performance } from 'node:perf_hooks';

const world=fs.readFileSync('world.html','utf8');
const source=fs.readFileSync('assets/maps/city_rebuild_v1/npc_civilian_activity_source.js','utf8');
function fn(name){const start=world.indexOf('function '+name+'(');let end=world.indexOf('{',start),depth=1;for(end++;depth;end++){if(world[end]==='{')depth++;if(world[end]==='}')depth--;}return world.slice(start,end);}
function fixture(code=source){
 let now=1000,blocked=false;
 const pass=(r,c)=>r>0&&r<30&&c>0&&c<30&&!(blocked&&r>5.3&&r<5.7);
 const c={Math,Number,Set,Map,performance:{now:()=>now},_npcStableUnit:()=>.2,_residentCanSocialize:n=>!n.dead&&!n._civilianActivity,
  _npcEffectiveSpeed:()=>.44,npcPassableForSnitch:pass,npcPassable:pass,_npcRouteWalkBlocked:(r,c)=>!pass(r,c),
  _walkNpcNavigationResolver:({r,c})=>({blocked:!pass(r,c),depth:0,surface:'land'}),
  _cancelNpcDirectedSearch:n=>{n._routeSearchPending=false;},_civilianPlanCancel(){}};
 vm.createContext(c);
 for(const name of ['_clearNpcRoute','_setNpcRoute','_npcBodyPassable','_npcPathPassable'])vm.runInContext(fn(name),c);
 vm.runInContext(code,c);
 return {c,actor(){const n={id:'resident_resume',r:5,c:5,hp:100,walking:true,_civilianPlan:{phase:'wander',doorId:null,cycle:1}};c._setNpcRoute(n,[{r:4,c:5},{r:6,c:5},{r:7,c:5}],'walk');n._routeIndex=1;n.tr=6;return n;},finish(n){now=n._civilianActivity.until+1;c._npcPurposefulActivityTick(n,.05,now);if(n._civilianActivity){now=n._civilianActivity.until+1;c._npcPurposefulActivityTick(n,.05,now);}},block(){blocked=true;}};
}
const stationary=['smoke','stretch','squat','lookaround'];
function start(f,n,kind){assert(kind==='smoke'?f.c._npcStartStandingSmoke(n,1000):f.c._npcStartOutdoorRoutine(n,kind,1000));}
for(const kind of stationary){
 const f=fixture(),n=f.actor(),plan=n._civilianPlan;start(f,n,kind);
 assert.equal(n._route,null,'paused resident does not keep moving');f.finish(n);
 assert.equal(n._civilianActivity,null);
 assert.equal(n._civilianPlan,plan,'same ordinary walking intent');
 assert.deepEqual(Array.from(n._route??[],p=>[p.r,p.c]),[[6,5],[7,5]],kind+' resumes untravelled route without a new search');
 assert.equal(n._routeKind,'walk');assert.equal(n._routeIndex,0);assert.equal(n.tr,6);assert.equal(n.idleUntil,0);
}
for(const reason of ['threat','moved','new-plan','changed-plan','new-cycle','blocked','player-chat']){
 const f=fixture(),n=f.actor();start(f,n,'smoke');
 if(reason==='threat')n.panicUntil=100000;
 if(reason==='moved')n.r+=.1;
 if(reason==='new-plan')n._civilianPlan={...n._civilianPlan};
 if(reason==='changed-plan')n._civilianPlan.doorId='other-shop';
 if(reason==='new-cycle')n._civilianPlan.cycle++;
 if(reason==='blocked')f.block();
 if(reason==='player-chat'){n._playerConversationOpen=true;n._talking=Number.MAX_SAFE_INTEGER;}
 f.finish(n);assert.equal(n._route,null,reason+' cannot resurrect stale travel');
 if(reason==='player-chat')assert.equal(n._talking,Number.MAX_SAFE_INTEGER);
}
for(const flag of ['_routeSearchPending','_npcWanderSearch']){const pending=fixture(),pn=pending.actor();pn[flag]=flag==='_npcWanderSearch'?{nodes:new Map()}:true;const route=pn._route;assert(!pending.c._npcStartStandingSmoke(pn,1000));assert(!pending.c._npcStartOutdoorRoutine(pn,'stretch',1000));assert(pn[flag]);assert.equal(pn._route,route,'optional activity preserves queued journey');}
// Reconstruct just the previous attach/release behavior for a matched small
// CPU comparison; all other production activity code is identical.
const baseline=source.replace(/ const resumeRoute=\['smoke'[\s\S]*?:null;\n/,' const resumeRoute=null;\n');
function measure(code){const samples=[],f=fixture(code);for(let i=0;i<1800;i++){const n=f.actor();const t=performance.now();start(f,n,'smoke');f.finish(n);if(i>=200)samples.push(performance.now()-t);}samples.sort((a,b)=>a-b);return {p50:samples[Math.floor(samples.length*.5)],p95:samples[Math.floor(samples.length*.95)]};}
const old=fixture(baseline),oldNpc=old.actor();start(old,oldNpc,'smoke');old.finish(oldNpc);assert.equal(oldNpc._route,null,'baseline reproduces lost published route');
console.log(JSON.stringify({pass:true,cases:stationary.length+9,scope:'actual activity module, actual route/path functions; CPU only',pauseAndResumeMs:{before:measure(baseline),after:measure(source)}}));
