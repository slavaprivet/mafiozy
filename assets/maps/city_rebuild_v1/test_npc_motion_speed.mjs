import assert from 'node:assert/strict';
import {measureNpcMotion,normalizeNpcSnapshot} from './npc_population.mjs';
import {HERO_POSTURES} from './hero_posture.mjs';
const pos=x=>({x,y:0,z:0});let measured=measureNpcMotion(null,pos(0),0);assert.equal(measured.speed,0);
for(const speed of [HERO_POSTURES.stand.slowWalkSpeed,HERO_POSTURES.stand.walkSpeed,HERO_POSTURES.stand.runSpeed,HERO_POSTURES.crouch.walkSpeed,HERO_POSTURES.prone.walkSpeed]){
 const result=measureNpcMotion({position:pos(0),time:1},pos(speed*.1),1.1);assert(result.valid);assert(Math.abs(result.speed-speed)<1e-9);
}
for(const dt of [.6,1,2]){const result=measureNpcMotion({position:pos(0),time:1},pos(1.5*dt),1+dt);assert(result.valid);assert(Math.abs(result.speed-1.5)<1e-9)}
for(const [time,flags,x]of [[1,{},1],[.9,{},1],[1.1,{reentry:true},1],[1.1,{teleport:true},1],[1.1,{},12]]){
 const result=measureNpcMotion({position:pos(0),time:1},pos(x),time,flags);assert.equal(result.speed,0);assert(!result.valid);
}
assert.equal(normalizeNpcSnapshot({id:'civilian',r:0,c:0,speed:99,walking:true},{time:1}).running,false,'tiles/sec setting never selects run');
console.log('PASS snapshot motion: common hero metres/sec, first sample, reentry, teleport, stale/reversed/zero clocks, source tiles not animation run');
