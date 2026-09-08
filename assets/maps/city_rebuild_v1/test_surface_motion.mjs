import assert from 'node:assert/strict';
import {createSurfaceMotion,resolveJumpSurface} from './surface_motion.mjs';
import {launchJump,stepJump} from './hero_jump.mjs';
const motion=createSurfaceMotion();
const ramp=(x,z)=>z>=0&&z<=4?1-z/4:z<0?1:0;
motion.reset({x:0,y:1,z:0});for(let i=1;i<=50;i++){const z=i*.1,result=motion.update({x:0,z,dt:1/60,floorHeight:ramp});assert.equal(result.blocked,false);assert.equal(result.grounded,true);assert.ok(Math.abs(result.y-ramp(0,z))<1e-8,'ramp follows physical floor in both directions')}
for(let i=49;i>=0;i--){const z=i*.1,result=motion.update({x:0,z,dt:1/60,floorHeight:ramp});assert.equal(result.blocked,false);assert.equal(result.y,ramp(0,z))}
const cliff=(x,z)=>x<1?1:0;motion.reset({x:.95,y:1,z:0});let falling=motion.update({x:1.05,z:0,dt:1/60,floorHeight:cliff});assert.equal(falling.grounded,false);assert.ok(falling.y>.99,'edge drop must not teleport down');let previous=falling.y;for(let i=0;i<40;i++){falling=motion.update({x:1.05,z:0,dt:1/60,floorHeight:cliff});assert.ok(falling.y<=previous&&falling.y>=0);previous=falling.y}assert.equal(falling.y,0);assert.equal(falling.grounded,true);
motion.reset({x:1.1,y:0,z:0});assert.equal(motion.update({x:.9,z:0,dt:1/60,floorHeight:cliff}).blocked,true,'cannot smooth upward through platform');assert.equal(motion.state.x,1.1);
const step=(x,z)=>x<1?0:.2;motion.reset({x:.95,y:0,z:0});assert.equal(motion.update({x:1.05,z:0,dt:1/60,floorHeight:step}).y,.2);
const hiddenWall=(x,z)=>x>.9&&x<1.1?2:0;assert.equal(motion.canMove({x:0,z:0},{x:2,z:0},hiddenWall),false,'subsamples catch skipped raised surfaces');
console.log('PASS support: ramp both directions, ballistic edge, stair admission, no floor penetration, long-frame probes');
let jump={...launchJump({x:0,z:0},{x:0,z:0}),baseY:0},y=0,hitCeiling=false;
for(let i=0;i<90&&!jump.done;i++){jump=stepJump(jump,1/60,()=>true);jump=resolveJumpSurface(jump,{floor:0,ceiling:2.45,previousY:y,dt:1/60});y=jump.worldY;hitCeiling||=jump.ceilingHit;assert.ok(y>=0&&y+1.9<=2.45);}
assert.equal(hitCeiling,true);assert.equal(y,0);
let edge={...launchJump({x:0,z:0},{x:0,z:0}),baseY:1.5};y=1.5;
for(let i=0;i<85&&!edge.done;i++){edge=stepJump(edge,1/60,()=>true);edge=resolveJumpSurface(edge,{floor:0,previousY:y,dt:1/60});if(edge.elapsed>.85)assert.ok(edge.worldY<1.5,'off-platform recovery must continue falling');y=edge.worldY;assert.ok(y>=0)}
assert.equal(y,0);console.log('PASS jump support: ceiling contact, gravity descent, landing, off-platform recovery without teleport');
