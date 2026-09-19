import test from 'node:test';
import assert from 'node:assert/strict';
import {createPedestrianAccessPlan} from './city_pedestrian_access_plan.mjs';
test('crossing access follows a real dry path to an entrance and never crosses traffic lanes',()=>{
 const grid=Array.from({length:20},()=>Array(30).fill(9));for(let r=0;r<20;r++)grid[r][14]=0;
 const instances=[{id:'left-hospital',entry:{anchorRC:{r:10,c:3}}},{id:'right-hotel',entry:{anchorRC:{r:5,c:26}}}],plan=createPedestrianAccessPlan({topology:{grid},instances,metresPerCell:1,step:.5,maxDistance:60});
 const left=plan.routeToEntrance({x:12,z:10}),right=plan.routeToEntrance({x:17,z:10});assert.equal(left.buildingId,'left-hospital');assert.equal(right.buildingId,'right-hotel');for(const route of [left,right])for(let i=1;i<route.points.length;i++)assert.ok(plan.segmentClear(route.points[i-1],route.points[i]));assert.equal(plan.routeToEntrance({x:14.5,z:10}),null);
});
test('thin collision walls separate walkable islands, with an authored door passage left usable',()=>{
 const grid=Array.from({length:20},()=>Array(25).fill(9)),wall={polygonCR:[[10,0],[10.15,0],[10.15,20],[10,20]],minYM:0,maxYM:2};
 const closed=createPedestrianAccessPlan({topology:{grid},instances:[{id:'door',entry:{anchorRC:{r:10,c:3}}}],extraBodies:[wall],metresPerCell:1,step:.5});assert.equal(closed.routeToEntrance({x:15,z:10}),null);
 const opened=createPedestrianAccessPlan({topology:{grid},instances:[{id:'door',entry:{anchorRC:{r:10,c:3}}}],extraBodies:[{...wall,polygonCR:[[10,0],[10.15,0],[10.15,8],[10,8]]},{...wall,polygonCR:[[10,12],[10.15,12],[10.15,20],[10,20]]}],metresPerCell:1,step:.5});assert.ok(opened.routeToEntrance({x:15,z:10}));
});
