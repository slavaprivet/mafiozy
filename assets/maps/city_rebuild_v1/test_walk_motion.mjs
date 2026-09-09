import assert from 'node:assert/strict';
import {circleFits,movePedestrian} from './walk_motion.mjs';
function legacyCircleProbe(x,z,radius){
 const points=[];circleFits(x,z,(a,b)=>{points.push([a,b]);return true},radius);return points;
}
function directCircleProbe(x,z,radius){
 const points=[[x,z]];for(let i=0;i<12;i++){const angle=i*Math.PI/6;points.push([x+Math.cos(angle)*radius,z+Math.sin(angle)*radius])}return points;
}
for(const [x,z,radius] of [[0,0,.36],[12.5,-3.75,.05],[-7.2,18.4,2.1]])assert.deepEqual(legacyCircleProbe(x,z,radius),directCircleProbe(x,z,radius),'cached footprint directions retain every legacy sample coordinate');
assert(circleFits(1,1,()=>true));
assert(!circleFits(.1,1,(x,z)=>x>=0));
const wall=(x,z)=>x<2;
const hit=movePedestrian({x:1,z:1},{x:3,z:0},wall);
assert(hit.x<1.65&&hit.x>1.4);
const slide=movePedestrian({x:1.5,z:1},{x:1,z:1},wall);
assert(slide.x<1.65&&slide.z>1.9);
const water=(x,z)=>!(x>=2&&x<=2.1);
assert(movePedestrian({x:1,z:1},{x:4,z:0},water).x<2);
assert(!movePedestrian({x:1,z:1},{x:0,z:0},()=>true).moved);
assert.throws(()=>movePedestrian({x:1,z:1},{x:NaN,z:0},()=>true));
console.log('PASS: radius clearance, wall, slide, thin barrier, idle and finite inputs');
