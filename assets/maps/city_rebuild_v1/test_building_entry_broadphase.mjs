import assert from 'node:assert/strict';
import {collectNearbyBuildingEntries} from './building_entry_broadphase.mjs';

const entry=(id,minX,minZ,maxX,maxZ)=>({id,sampleBounds:{min:{x:minX,z:minZ},max:{x:maxX,z:maxZ}}});
const noBounds={id:'legacy'};
const entries=[entry('near',-2,-1,2,1),entry('edge',10,0,12,2),entry('far',30,30,32,32),noBounds];
const scratch=['stale'];
assert.deepEqual(collectNearbyBuildingEntries(entries,{x:0,z:0},0,scratch).map(item=>item.id),['near','legacy'],'inside exact bound and unbounded legacy entry remain');
assert.deepEqual(collectNearbyBuildingEntries(entries,{x:0,z:0},10,scratch).map(item=>item.id),['near','edge','legacy'],'radius reaches an AABB edge exactly');
assert.deepEqual(collectNearbyBuildingEntries(entries,{x:0,z:0},9.99,scratch).map(item=>item.id),['near','legacy'],'radius does not over-include a farther entry');
assert.deepEqual(collectNearbyBuildingEntries(entries,null,12,scratch),[],'missing focus has no candidates');
assert.equal(collectNearbyBuildingEntries(entries,{x:0,z:0},0,scratch),scratch,'caller-owned scratch is reused');
console.log('PASS building-entry broadphase: exact XZ AABB radius, legacy entries, scratch reuse');
