import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createWalkCollisionIndex} from './walk_collision_index.mjs';
const read = name => JSON.parse(fs.readFileSync(new URL(name, import.meta.url)));
const bodies = ['buildings_placement.v1.json','decor_placement.v1.json'].flatMap(name => read(name).instances.flatMap(i => i.collision?.worldBodies || []));
// Include exact grid edges, negative cells, degenerate and height-layered bodies.
bodies.push({polygonCR:[[-4,-4],[0,-4],[0,0],[-4,0]]}, {polygonCR:[[4,4],[4,4],[4,4]]});
const index = createWalkCollisionIndex([bodies]);
let seed=42, checks=0;
const random=()=>((seed=(1664525*seed+1013904223)>>>0)/4294967296);
for(let i=0;i<25000;i++) {
  const c=i<100?i-50:random()*210-5,r=i<100?i-50:random()*190-5;
  const candidates=new Set(index(c,r));
  for(const body of bodies) {
    const xs=body.polygonCR.map(p=>p[0]),zs=body.polygonCR.map(p=>p[1]);
    if(c>=Math.min(...xs)&&c<=Math.max(...xs)&&r>=Math.min(...zs)&&r<=Math.max(...zs))assert(candidates.has(body),'broadphase dropped overlapping AABB');
  }
  checks++;
}
const moving={polygonCR:[[0,0],[1,0],[1,1],[0,1]]};
assert(createWalkCollisionIndex([[moving]])(.5,.5).includes(moving));
moving.polygonCR=moving.polygonCR.map(([c,r])=>[c+20,r]);
const moved=createWalkCollisionIndex([[moving]]);
assert(!moved(.5,.5).includes(moving));assert(moved(20.5,.5).includes(moving));
console.log(`PASS ${checks} conservative spatial queries against actual placement, grid edges and moved door`);
