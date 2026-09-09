import assert from 'node:assert/strict';
import fs from 'node:fs';
import {nativePedestrianLand} from './native_pedestrian_surface.mjs';
import {movePedestrian} from './walk_motion.mjs';
const topology=JSON.parse(fs.readFileSync(new URL('./topology_for_placement.json',import.meta.url),'utf8'));
const before=JSON.stringify(topology);let freed=0;
for(let r=0;r<200;r++)for(let c=0;c<180;c++){
 const allowed=nativePedestrianLand(topology,r,c);
 if(topology.grid[r][c]===16)assert.equal(allowed,false,'water is handled by swimming, never as dry land');
 if(topology.walkableMask[r][c])assert.equal(allowed,true);
 if(!topology.walkableMask[r][c]&&allowed){assert.equal(topology.grid[r][c],9);assert.equal(topology.policeMask[r][c],1);freed++;}
}
assert.equal(freed,882);assert.equal(JSON.stringify(topology),before,'placement/server reservations must remain intact');
for(const p of [[-1,4],[4,-1],[200,4],[4,180],[NaN,1]])assert.equal(nativePedestrianLand(topology,...p),false);
const M=4.1,start={x:86.5*M,z:91.5*M},delta={x:0,z:4},old=(x,z)=>!!topology.walkableMask?.[Math.floor(z/M)]?.[Math.floor(x/M)],land=(x,z)=>nativePedestrianLand(topology,z/M,x/M);
assert.equal(movePedestrian(start,delta,old).moved,false,'reproduce invisible reservation wall at central walkway');
const moved=movePedestrian(start,delta,land);assert(Math.abs(moved.z-start.z-4)<1e-8,'walk through visible paving');
// Terrain permission must not erase physical walls added by the host.
const wall=(x,z)=>land(x,z)&&z<start.z+1;
assert(movePedestrian(start,delta,wall).z<start.z+1,'physical wall still stops the capsule');
assert.equal(nativePedestrianLand(topology,52,90),true,'red bridge deck stays walkable');
console.log('PASS central walkway repro, 882 reserved paved cells, physical wall, bridge, water, bounds and unchanged source masks');
