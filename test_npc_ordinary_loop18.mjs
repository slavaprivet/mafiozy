import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
const f=await createCivilianNativeFixture(),b=f.box,s=f.source;
const end=s.indexOf('  // Entries are collected after iteration'),start=s.lastIndexOf('    if (now < n.idleUntil)',end),foot=s.slice(start,end).replace(/\s*}\s*$/,'');
const reserve=sourceFunction(s,'_npcReserveRouteWork');assert(reserve.includes('_npcRouteWorkCount>=8'));
const oldPause=foot.replace('n.idleUntil = purposefulWalk?now:now+(1200+Math.random()*2600)*Math.max(.65,idM);','n.idleUntil = now+(1200+Math.random()*2600)*Math.max(.65,idM);');assert.notEqual(foot,oldPause);
b._civilianPlanNext=()=>false;b._maybePlanResidentBuildingVisit=()=>false;
vm.runInContext(sourceFunction(s,'pickNpcWaypoint'),b);
const all=[];
for(let r=3;r<b.MAP_ROWS-4;r+=2)for(let c=3;c<b.MAP_COLS-4;c+=2){const n={r:r+.5,c:c+.5};if(b.npcWaypointOk(n,n.r,n.c)&&b._npcBodyPassable(n.r,n.c,b.npcPassable))all.push(n);}
const origins=Array.from({length:288},(_,i)=>all[Math.floor(i*all.length/288)]);
const p=(a,q)=>[...a].sort((a,b)=>a-b)[Math.min(a.length-1,Math.floor(a.length*q))]||0;
function run(before){
 let seed=77;const math=Object.create(Math);math.random=()=>((seed=Math.imul(seed,1664525)+1013904223>>>0)/4294967296);b.Math=math;
 b.NPCS.length=0;for(let i=0;i<288;i++){const o=origins[i];b.NPCS.push({id:'resident_'+i,...o,tr:o.r,tc:o.c,hp:100,max_hp:100,speed:1,walkPhase:0,idleUntil:0,alive:true});}
 vm.runInContext('_npcRouteWorkFrame=null;_npcRouteWorkQueue.clear();_npcRouteWorkServed.clear();',b);
 vm.runInContext(before?reserve.replace('_npcRouteWorkCount>=8','_npcRouteWorkCount>=2'):reserve,b);
 vm.runInContext('globalThis.tick=(n,dt,now)=>{for(const actor of [n]){const civilianRoutineDt=dt;'+(before?oldPause:foot)+'}};',b);
 const costs=[],waits=[];let moving=0,pending=0,resting=0,blocked=0,routes=0;
 const originalSet=b._setNpcRoute;b._setNpcRoute=(n,path,...args)=>{routes++;if(n.requestAt!=null){waits.push(f.now-n.requestAt);n.requestAt=null;}return originalSet(n,path,...args);};
 for(let frame=0;frame<600;frame++){
  f.nextFrame(.1);const at=performance.now();
  for(const n of b.NPCS){
   if(!n._route?.length&&!(n.idleUntil>f.now))n.requestAt??=f.now;
   const r=n.r,c=n.c;b.tick(n,.1,f.now);
   const d=Math.hypot(n.r-r,n.c-c);assert(d<=.041+1e-6,'movement remains actual walking speed');
   if(d&&!b._npcPathPassable(r,c,n.r,n.c,b.npcPassableForSnitch))blocked++;
   if(frame>=400){moving+=d>1e-9;pending+=!!(n._npcWanderSearch||n._routeSearchPending);resting+=n.idleUntil>f.now;}
  }
  costs.push(performance.now()-at);
 }
 b._setNpcRoute=originalSet;assert.equal(blocked,0);
 return{before,routes,last20Seconds:{moving:moving/(200*288),pending:pending/(200*288),resting:resting/(200*288)},routeWaitMs:{p50:p(waits,.5),p95:p(waits,.95)},ordinaryLoopCpuMs:{p50:p(costs,.5),p95:p(costs,.95)},blocked};
}
const reverse=process.argv.includes('--reverse');
const results=reverse?[run(false),run(true)]:[run(true),run(false)];
const report={scenario:'288 residents across actual geometry, actual ordinary foot/pick/motion loop, 60 seconds at 10Hz. Compare cap2+automatic arrival idle versus applied cap8+activity-owned rest; same 4ms planner budget.',results,limits:f.limits+' Only ordinary outings; visits/social/traffic scheduling excluded. Not LIVE or full-scene FPS.'};
fs.writeFileSync('outputs/npc_ordinary_loop18'+(reverse?'_reverse':'')+'.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
