import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const s=fs.readFileSync(process.argv[2]||'world.html','utf8').replace(/\r\n/g,'\n');
function fn(name){const a=s.indexOf(`function ${name}(`);assert.ok(a>=0,name);return s.slice(a,s.indexOf('\n}',a)+2);}
function world({wall=false,car=false}={}){
 let now=1000;
 const hit=(r,c)=>r>5&&r<6&&c>3&&c<8;
 const env={performance:{now:()=>now},document:{documentElement:{dataset:{}}},MAP_COLS:40,player:{r:25,c:5,ang:0},
  npcPassableForSnitch:(r,c)=>r>.5&&c>.5&&r<35&&c<35&&!(wall&&hit(r,c)),isBlockedPed:()=>false,
  _npcRouteWalkBlocked:(r,c)=>car&&hit(r,c),_prisonIslandCollisionAt:()=>null};
 vm.createContext(env);
 vm.runInContext(s.match(/const NPC_HERO_PACE=Object.freeze\([^\n]+/)[0],env);
 for(const n of ['_npcPacedSpeed','_npcReserveRouteWork','_npcRouteWorkExpired','_policeCrewPassable','_policeCrewBodyPassable','_policeCrewSegmentPassable','_clearPoliceFootRoute','_reservePoliceFootRoute','_planPoliceFootRoute','_movePoliceFootCop','_movePoliceBackup'])vm.runInContext(fn(n),env);
 vm.runInContext('let _policeFootRouteFrame=-1,_policeFootRoutesThisFrame=0,_policeFootRouteDeferredCount=0,_policeFootRoutePlanCount=0,_policeFootRouteCacheHits=0,_policeFootRouteMaxMs=0;const _policeFootRouteSharedCache=new Map();',env);
 return {env,advance:dt=>now+=dt*1000};
}
for(const kind of ['wall','car'])for(const fps of [30,60,144]){
 const w=world({[kind]:true}),u={id:'backup_test',r:2,c:5,walkPhase:0};let moved=0;
 for(let i=0;i<fps*25;i++){
  const old={r:u.r,c:u.c};w.advance(1/fps);w.env._movePoliceBackup(u,12,5,1/fps);
  const step=Math.hypot(u.r-old.r,u.c-old.c);moved+=step;
  assert.ok(step*4.1<=7.8/fps+1e-8,'per-frame bound excludes teleport');
  assert.ok(w.env._policeCrewBodyPassable(u.r,u.c),`${kind} body collision`);
 }
 assert.ok(Math.hypot(u.r-12,u.c-5)<.7,`${kind}: route must actually reach far side, not stop forever`);
 assert.ok(moved>10,'route detours rather than crossing wall/car');
}
const w=world(),far={id:'backup_far',r:2,c:2,walkPhase:0};w.env._movePoliceBackup(far,25,25,1/60);
assert.ok(Math.hypot(far.r-2,far.c-2)*4.1<=7.8/60+1e-9,'distance>12 cannot teleport');
vm.runInContext(fn('_prisonEscortBodyPassable'),w.env);
w.env._prisonIslandCollisionAt=()=>({blocked:false});w.env._npcRouteWalkBlocked=()=>true;
assert.equal(w.env._policeCrewPassable(2,2),false,'prison free tile cannot bypass native obstacle');
assert.equal(w.env._prisonEscortBodyPassable(2,2),false);
w.env._npcRouteWalkBlocked=()=>false;w.env._prisonIslandCollisionAt=()=>({blocked:true,kind:'personal-release-gate-locked'});
assert.equal(w.env._prisonEscortBodyPassable(2,2),true,'lawful escort gate exception retained');
console.log('PASS actual backup BFS through wall/car detours30/60/144FPS, no teleport, prison native gate and lawful escort');
