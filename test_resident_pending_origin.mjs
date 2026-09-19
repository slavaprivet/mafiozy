import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const source=fs.readFileSync('world.html','utf8'),fn=name=>{const start=source.indexOf('function '+name+'(');let p=source.indexOf('{',start),d=1;for(p++;d;p++){if(source[p]==='{')d++;if(source[p]==='}')d--;}return source.slice(start,p);};
const planner=source.slice(source.indexOf('let _npcRouteWorkFrame='),source.indexOf('function _planNpcEscapeRoute('));
const footEnd=source.indexOf('  // Entries are collected after iteration'),footStart=source.lastIndexOf('    if (now < n.idleUntil)',footEnd),foot=source.slice(footStart,footEnd).replace(/\s*}\s*$/,'');
function run(frozen){
 let clock=1000;const n={id:'pending-person',r:2.5,c:2.5,tr:8.5,tc:2.5,walkPhase:0,idleUntil:0,_civilianPlan:{phase:'walk_to_shop',doorId:'fixed-door'}};
 const ctx={Math,Number,Map,Set,performance:{now:()=>clock},prevT:1,MAP_ROWS:30,MAP_COLS:30,_walkNpcNavigationResolver:()=>({blocked:false,depth:0}),npcPassable:(r,c)=>r>=0&&c>=0&&r<30&&c<30,npcPassableForSnitch:(r,c)=>r>=0&&c>=0&&r<30&&c<30,_npcBodyPassable:(r,c,pass)=>pass(r,c),_npcPathPassable:(r,c,rr,cc,pass)=>pass(rr,cc),_npcEffectiveSpeed:()=>1,pickNpcWaypoint(){},_civilianArrivalRadius:()=>.08,_residentEnterBuilding:()=>false,_civilianPlanArrive:()=>false};
 vm.createContext(ctx);vm.runInContext(fs.readFileSync('assets/maps/city_rebuild_v1/npc_city_population_source.js','utf8'),ctx);vm.runInContext(fs.readFileSync('assets/maps/city_rebuild_v1/npc_civilian_elapsed_source.js','utf8'),ctx);vm.runInContext(planner,ctx);for(const name of ['_clearNpcRoute','_setNpcRoute'])vm.runInContext(fn(name),ctx);
 let route=fn('_civilianRouteTo');if(!frozen)route=route.replace('if(n._routeSearchPending){n.tr=n.r;n.tc=n.c;n.idleUntil=0;n.walking=false;return false;}','if(n._routeSearchPending)return false;');vm.runInContext(route,ctx);vm.runInContext('globalThis.foot=(npc,dt,now)=>{for(const n of [npc]){const civilianRoutineDt=_npcConsumeCivilianElapsed(n,dt,now);'+foot+'}}',ctx);
 for(let i=0;i<5;i++){
  clock+=50;ctx.prevT=i+1;vm.runInContext('_npcRouteWorkFrame=prevT;_npcRouteWorkCount=2;_npcRouteWorkDeadline=0;',ctx);
  assert.equal(ctx._civilianRouteTo(n,14.5,2.5,'building_entry'),false);assert(n._routeSearchPending);ctx.foot(n,.5,clock);
 }
 const deferredR=n.r;clock+=50;ctx.prevT=99;assert(ctx._civilianRouteTo(n,14.5,2.5,'building_entry'),'actual planner resumes after two occupied frame slots free');assert.equal(n._routeGoalR,14.5);
 return deferredR;
}
assert(run(false)>3.5,'previous source generic movement changes search origin while work is deferred');assert.equal(run(true),2.5,'pending work never walks toward the obsolete target');
console.log('PASS actual source frame-budget exhaustion + generic foot branch: pre-fix origin drift reproduced, pending target freeze preserves origin and unchanged goal resumes');
