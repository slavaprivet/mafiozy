import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createWalkCollisionIndex} from './walk_collision_index.mjs';
const read = name => JSON.parse(fs.readFileSync(new URL(name, import.meta.url)));
const bodies = ['buildings_placement.v1.json','decor_placement.v1.json'].flatMap(name => read(name).instances.flatMap(i => i.collision?.worldBodies || []));
// Include exact grid edges, negative cells, degenerate and height-layered bodies.
bodies.push({polygonCR:[[-4,-4],[0,-4],[0,0],[-4,0]]}, {polygonCR:[[4,4],[4,4],[4,4]]});
const index = createWalkCollisionIndex([bodies]);
// Independent legacy layout: every sampled query must retain the exact ordered
// candidate list, not merely remain conservative.
function legacyIndex(items, cellSize=4){
  const cells=new Map(),empty=[];
  for(const body of items){
    const polygon=body.polygonCR;if(!polygon?.length)continue;
    let minC=Infinity,maxC=-Infinity,minR=Infinity,maxR=-Infinity;
    for(const [c,r] of polygon){minC=Math.min(minC,c);maxC=Math.max(maxC,c);minR=Math.min(minR,r);maxR=Math.max(maxR,r)}
    for(let r=Math.floor(minR/cellSize);r<=Math.floor(maxR/cellSize);r++)for(let c=Math.floor(minC/cellSize);c<=Math.floor(maxC/cellSize);c++){
      const key=`${c},${r}`;if(!cells.has(key))cells.set(key,[]);cells.get(key).push(body);
    }
  }
  return (c,r)=>cells.get(`${Math.floor(c/cellSize)},${Math.floor(r/cellSize)}`)||empty;
}
const legacy=legacyIndex(bodies);
let seed=42, checks=0;
const random=()=>((seed=(1664525*seed+1013904223)>>>0)/4294967296);
for(let i=0;i<25000;i++) {
  const c=i<100?i-50:random()*210-5,r=i<100?i-50:random()*190-5;
  const candidates=new Set(index(c,r));
  if(i<100||i%251===0)assert.deepEqual(index(c,r),legacy(c,r),'numeric row/column index preserves the legacy candidate list');
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
