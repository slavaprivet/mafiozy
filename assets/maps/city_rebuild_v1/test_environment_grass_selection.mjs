import assert from 'node:assert/strict';
import {retainNearestGrassCandidate,sortNearestGrassCandidates} from './environment_grass.mjs';
// A stable reference sort proves the bounded collector never changes the
// chosen near-to-far grass order, including equal-distance instances.
for(const limit of [1,2,17,1201]){
 const source=Array.from({length:5000},(_,index)=>({id:'tuft-'+index,_selectionDistance:((index*7919)%1103)/17,_selectionOrder:index}));
 const retained=[];for(const item of source)retainNearestGrassCandidate(retained,item,limit);
 const actual=sortNearestGrassCandidates(retained).map(item=>item.id),expected=source.slice().sort((a,b)=>a._selectionDistance-b._selectionDistance||a._selectionOrder-b._selectionOrder).slice(0,limit).map(item=>item.id);
 assert.deepEqual(actual,expected,'bounded nearest set matches full stable sort at '+limit);
}
console.log('PASS bounded grass selection exactly preserves the nearest stable order');
