import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';

const f=await createCivilianNativeFixture(),{box}=f;
vm.runInContext(fs.readFileSync(new URL('npc_simulation_cadence_source.js',import.meta.url),'utf8'),box);
vm.runInContext("globalThis.sweepEnabled=true;_walkNpcNavigationResolver=q=>q.mode==='sweep'&&!sweepEnabled?{swept:false}:nativePedestrianQuery(q);",box);
const obstructionSamples=[];
const pathStart=f.source.indexOf('function _npcPathPassable('),pathEnd=f.source.indexOf('\n}',pathStart)+2,pathCode=f.source.slice(pathStart,pathEnd);
for(const {dt,spacing,exact}of [{dt:1/60,spacing:.14,exact:false},{dt:.25,spacing:.14,exact:false},{dt:.25,spacing:.04,exact:false},{dt:.25,spacing:.025,exact:false},{dt:.25,spacing:.02,exact:false},{dt:1/60,spacing:.14,exact:true},{dt:.25,spacing:.14,exact:true}]){
 box.sweepEnabled=exact;
 vm.runInContext(pathCode.replace('distance/.14','distance/'+spacing),box);
 const n={id:'resident_obstacle_probe',r:3.5,c:7.5,tr:3.5,tc:4.5,hp:60,max_hp:60,speed:1,walkPhase:0,idleUntil:0};
 for(let i=0;i<Math.round(2/dt);i++){f.nextFrame(dt);box.actualFootTick(n,dt,f.now);}
 obstructionSamples.push({dt,spacing,exact,r:n.r,c:n.c,walking:n.walking});
}
vm.runInContext(pathCode,box);
box.sweepEnabled=true;
assert(obstructionSamples.filter(s=>s.exact).every(s=>!s.walking&&s.c>=6.88),'continuous sweep blocks actual thin geometry at both cadences');
assert(obstructionSamples.find(s=>!s.exact&&s.dt===.25&&s.spacing===.14).walking,'old sampling regression remains reproduced');
console.log('Actual thin-obstacle sampling probe',JSON.stringify(obstructionSamples));
const blockedIntervals=[];let interval=null;
for(let i=0;i<=700;i++){const c=7.3-i*.001,blocked=!box._npcBodyPassable(3.5,c,box.npcPassable);if(blocked){if(!interval){interval={from:c,to:c};blockedIntervals.push(interval)}else interval.to=c;}else interval=null;}
console.log('Forbidden centre intervals',JSON.stringify(blockedIntervals));
const origins=[];
// Real dry segments against the loaded building/decor/car/water fixture. No
// always-clear collision callback, route-success stub or actor teleport in run.
for(let r=3;r<box.MAP_ROWS-4&&origins.length<288;r+=2){
 for(let c=3;c<box.MAP_COLS-4&&origins.length<288;c+=2){
  if(Math.hypot(r+.5-box.player.r,c+.5-box.player.c)<=42)continue;
  if(![8,9].includes(box.MAP[r][c]))continue;
  for(const [dr,dc]of [[0,3],[3,0],[0,-3],[-3,0]]){
   if(!box._npcBodyPassable(r+.5,c+.5,box.npcPassable)||!box._npcPathPassable(r+.5,c+.5,r+.5+dr,c+.5+dc,box.npcPassable))continue;
   // Select genuinely clear benchmark lanes independently of coarse route
   // sampling. The actual thin-obstacle probe above is reported separately.
   let fineClear=true;for(let step=1;step<=160;step++){const d=step/160;if(!box._npcBodyPassable(r+.5+dr/3*d,c+.5+dc/3*d,box.npcPassable)){fineClear=false;break;}}
   if(!fineClear)continue;
   origins.push({r:r+.5,c:c+.5,tr:r+.5+dr,tc:c+.5+dc});break;
  }
 }
}
assert.equal(origins.length,288,'actual city must provide 288 clear ordinary pedestrian segments');
function run(cadence,exact=true){
 box.sweepEnabled=exact;
 const actors=origins.map((origin,i)=>({...origin,id:`resident_cpu_${i}`,hp:60,max_hp:60,speed:.9+(i%7)*.1,walkPhase:0,idleUntil:0})),costs=[],updates=[];
 let checks=0;const original=box._npcRoutineStep;
 box._npcRoutineStep=(...args)=>{checks++;return original(...args)};
 for(let frame=1;frame<=120;frame++){
  f.nextFrame(1/60);let updated=0;
  const start=performance.now();
  for(const n of actors){
   const delta=cadence?box._npcSimulationDelta(n,1/60,f.now):1/60;
   if(!delta)continue;updated++;n.walking=false;box.actualFootTick(n,delta,f.now);
  }
  if(frame>20)costs.push(performance.now()-start);updates.push(updated);
 }
 box._npcRoutineStep=original;
 for(let i=0;i<actors.length;i++){
  const n=actors[i],o=origins[i],travel=Math.hypot(n.r-o.r,n.c-o.c),speed=box._npcEffectiveSpeed(n);
  assert(Math.abs(travel+(n._npcSimCarry||0)*speed-2*speed)<1e-8,'movement elapsed preserved on real source foot branch '+JSON.stringify({cadence,i,o,n,travel,speed}));
  assert(box._npcBodyPassable(n.r,n.c,box.npcPassable),'body remains on actual dry accessible surface');
  assert.equal(n.id,`resident_cpu_${i}`);assert.equal(n.hp,60);
 }
 costs.sort((a,b)=>a-b);
 return {p50Ms:costs[50],p95Ms:costs[95],movementCalls:checks,maxUpdatesPerFrame:Math.max(...updates),minUpdatesPerFrame:Math.min(...updates)};
}
const before=run(false,false),currentFull=run(false),after=run(true);
assert(after.movementCalls<before.movementCalls*.12,'cadence really reduces expensive swept steps');
const report={residents:288,frames:120,staticBodies:f.bodies.length,obstructionSamples,before,currentFull,after,limits:'CPU actual generic source foot branch against loaded native static/door/car/water fixture. before=old point sweep full cadence; currentFull=continuous solid sweep full cadence; after=continuous solid sweep distant cadence. Excludes full updateNpcs scheduling/events, live dynamic fleet, NPC skinning, GPU and loaded-game FPS.'};
fs.writeFileSync(new URL('../../../outputs/npc_native_cadence_movement_20260919.json',import.meta.url),JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
console.log('PASS actual source foot movement with 288 persistent residents: elapsed speed, physical body checks and bounded distant cadence');
