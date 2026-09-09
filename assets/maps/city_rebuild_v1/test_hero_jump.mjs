import assert from 'node:assert/strict';
import {JUMP,NORMAL_JUMP_SPEED,jumpDirection,launchJump,stepJump,tryDiveJump} from './hero_jump.mjs';
const free=()=>true;
for(const forward of [{x:0,z:1},{x:1,z:0}])for(const input of [{forward:true},{back:true},{left:true},{right:true},{forward:true,left:true},{forward:true,right:true},{back:true,left:true},{back:true,right:true}]){
 const d=jumpDirection(forward,input);assert.ok(Math.abs(Math.hypot(d.x,d.z)-1)<1e-12);
 let s=launchJump({x:0,z:0},d);for(let i=0;i<160;i++)s=stepJump(s,.01,free);
 assert.equal(s.done,true);assert.equal(s.y,0);assert.equal(s.mode,'normal');assert.ok(Math.abs(Math.hypot(s.x,s.z)-NORMAL_JUMP_SPEED*JUMP.flight)<1e-9);
 let dive=tryDiveJump(launchJump({x:0,z:0},d),d,100);assert.equal(dive.mode,'dive');while(!dive.done)dive=stepJump(dive,.01,free);assert.ok(Math.abs(Math.hypot(dive.x,dive.z)-JUMP.speed*JUMP.flight)<1e-9);
}
assert.deepEqual(jumpDirection({x:0,z:1},{left:true,right:true}),{x:0,z:0});
let vertical=launchJump({x:2,z:3},{x:0,z:0});for(let i=0;i<4;i++)vertical=stepJump(vertical,.1,free);
assert.ok(Math.abs(vertical.y-JUMP.height)<1e-12);assert.equal(vertical.x,2);assert.equal(vertical.z,3);
for(const boundary of [x=>x<1,x=>!(x>=1&&x<=1.03)]){
 let s=launchJump({x:0,z:0},{x:1,z:0});for(let i=0;i<130;i++)s=stepJump(s,.01,(x,z)=>boundary(x));
 assert.ok(s.x<1-JUMP.radius+.001);assert.equal(s.blocked,true);assert.equal(s.y,0);assert.equal(s.done,true);
}
const simulate=dt=>{let s=launchJump({x:0,z:0},{x:1,z:1});while(!s.done)s=stepJump(s,dt,free);return s};
assert.ok(Math.abs(simulate(.01).x-simulate(.04).x)<1e-9);
assert.throws(()=>stepJump(vertical,NaN,free));
console.log('Directional jump: eight directions, apex, landing, wall/water boundary and timestep checks passed');
let first=launchJump({x:3,z:7},{x:1,z:0},{startedAt:1000});first=stepJump(first,.1,free);first=stepJump(first,.1,free);
const second=tryDiveJump(first,{x:0,z:-1},1200);assert.equal(second.mode,'dive');for(const k of ['x','z','y','elapsed','progress'])assert.equal(second[k],first[k],'double tap must preserve '+k);
assert.equal(second.dz,-1);assert.equal(tryDiveJump(second,{x:1,z:0},1250),second,'third tap cannot restart');
for(const t of [999,1501,5000])assert.equal(tryDiveJump(first,{x:1,z:0},t),first,'late/backward tap ignored');
assert.equal(tryDiveJump(first,{x:1,z:0},1500).mode,'dive');
for(const field of ['done','falling','ceilingHit']){const stopped={...first,[field]:true};assert.equal(tryDiveJump(stopped,{x:1,z:0},1200),stopped)}
let wallDive=tryDiveJump(launchJump({x:0,z:0},{x:1,z:0}),{x:1,z:0},100);while(!wallDive.done)wallDive=stepJump(wallDive,.01,x=>x<1);assert.ok(wallDive.x<1-JUMP.radius+.001);assert.ok(wallDive.blocked);
console.log('PASS immediate normal / double-tap dive, continuous trajectory, late/third tap, ceiling/fall guards and dive walls');
let lowDive=tryDiveJump(launchJump({x:0,z:0},{x:1,z:0}),{x:1,z:0},0);
for(let i=0;i<4;i++)lowDive=stepJump(lowDive,.1,free);
assert.ok(Math.abs(lowDive.y-JUMP.diveHeight)<1e-12,'dive apex is lower than ordinary jump');
assert.ok(lowDive.y<JUMP.height);assert.ok(Math.abs(lowDive.x-JUMP.speed*.4)<1e-10,'lower arc preserves distance');
const midair=stepJump(launchJump({x:0,z:0},{x:1,z:0}),.1,free),lowered=tryDiveJump(midair,{x:1,z:0},100);
assert.equal(stepJump(lowered,0,free).y,midair.y,'lowering starts continuously at the second press');
console.log('PASS lower dive arc, unchanged ordinary apex/distance and continuous midair upgrade');
