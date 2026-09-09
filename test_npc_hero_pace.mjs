import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {HERO_POSTURES} from './assets/maps/city_rebuild_v1/hero_posture.mjs';
const source=fs.readFileSync('world.html','utf8');
const code=source.slice(source.indexOf('const NPC_HERO_PACE='),source.indexOf('// NPC_LIFE_SYSTEM_START'));
const ctx=vm.createContext({});vm.runInContext(code,ctx);
const metres=s=>s*4.1;
assert.equal(metres(ctx._npcPacedSpeed(10)),1.8);
assert.equal(metres(ctx._npcPacedSpeed(10,true)),HERO_POSTURES.stand.runSpeed);
const healthy={speed:1.65,hp:100,maxHp:100};
assert.equal(metres(ctx._npcEffectiveSpeed(healthy)),1.8);
assert.equal(metres(ctx._npcEffectiveSpeed({...healthy,_fear:1,_routineSpeedK:1.4})),1.8);
const slow=ctx._npcEffectiveSpeed({speed:.42,hp:100});assert.equal(slow,.42);
assert(ctx._npcEffectiveSpeed({...healthy,_fatigue:1})<ctx._npcEffectiveSpeed(healthy));
assert(ctx._npcEffectiveSpeed({...healthy,hp:20})<ctx._npcEffectiveSpeed(healthy));
assert(ctx._npcEffectiveSpeed({...healthy,_forcedCrawl:true})<ctx._npcEffectiveSpeed({...healthy,hp:20}));
for(const dt of [1/3,1/30,1/60,1/144]){
 let distance=0;for(let t=0;t<Math.round(1/dt);t++)distance+=ctx._npcEffectiveSpeed(healthy)*dt;
 assert(Math.abs(metres(distance)-1.8)<1e-10);
}
const route=[[84.1,62.5],[84.1,67.3],[87.2,67.3],[87.2,62.5]];
for(const dt of [1/3,1/30,1/60,1/144]){
 let before=ctx._npcTimedWalkRoute(route,0,.54),paused=0;
 for(let t=dt;t<80;t+=dt){const after=ctx._npcTimedWalkRoute(route,t*1000,.54);
  assert(metres(Math.hypot(after.r-before.r,after.c-before.c))/dt<=1.8+1e-8,'yard workers must not sprint along a fixed 4.5-second loop');
  if(after.pause)paused++;before=after;
 }
 assert(paused>0,'work stops preserved');
}
assert.equal(HERO_POSTURES.stand.walkSpeed,4.6,'player speed unchanged');
console.log('PASS source peaceful NPC pace is1.8m/s; running matches hero in metres/sec, yard route corners/pauses, fatigue/injury preserved, frame-rate independent');
