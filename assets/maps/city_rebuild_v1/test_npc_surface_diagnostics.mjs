import assert from 'node:assert/strict';
import {summarizeNpcSurfaces} from './npc_surface_diagnostics.mjs';
const rows=[['idle',false,0,0,0,true],['hit',false,2,1,3,true],['dead',true,3,2,4,false],['fall',false,0,0,0,true]];
let calls=0;
const records=rows.map(([reaction,inWater,wetMeshes,activeBleedingWounds,particles,visible],index)=>({lastPoseAt:index,actor:{object:{visible},surface:{performanceState(){calls++;return {reaction,inWater,wetMeshes,activeBleedingWounds,particles};},snapshot(){throw Error('Must not serialize');}}}}));
const expected={cached:4,visible:3,alive:3,dead:1,inWater:1,wet:2,drying:1,bleeding:2,activeBleedingWounds:3,particles:7,reactions:{idle:1,hit:1,dead:1,fall:1},lastPoseAt:3};
assert.deepEqual(summarizeNpcSurfaces(records.values()),expected);assert.equal(calls,4);
assert.deepEqual(summarizeNpcSurfaces([]),{cached:0,visible:0,alive:0,dead:0,inWater:0,wet:0,drying:0,bleeding:0,activeBleedingWounds:0,particles:0,reactions:{},lastPoseAt:null});
console.log('PASS surface diagnostics: mixed cached actors, visibility, wet/drying, reaction, bleeding, particles, empty; no serialization');
