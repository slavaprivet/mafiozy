import test from 'node:test';
import assert from 'node:assert/strict';
import {createRoadTerminalEdges} from './city_road_terminal_edges.mjs';
const lanePoint=(_path,x,direction,index)=>({x,z:direction*2,tx:direction,tz:0,offset:2,laneCount:1});
function approach(){return {id:'end',pathId:'street:0',path:{length:30},progress:0,direction:1,entryDistance:5,nextJunctionId:null,deadEnd:true,component:0,incoming:[{...lanePoint(null,5,-1,0),id:'end:in',index:0}],outgoing:[{...lanePoint(null,5,1,0),id:'end:out',index:0}]};}
test('two road tails end in separate stopping/departure vertices without a U-turn',()=>{
  const a=approach(),r=createRoadTerminalEdges({approaches:[a],lanePoint,laneRoad:()=>true,vehicleFits:(x)=>x<=27});
  assert.equal(r.connections.length,2);assert.equal(r.lanes.length,2);assert.equal(a.deadEnd,true);assert.equal(a.canStopAtRoadEnd,true);
  const arrival=r.connections.find(e=>e.kind==='terminal_arrival'),departure=r.connections.find(e=>e.kind==='terminal_departure');
  assert.equal(arrival.fromLaneId,'end:out');assert.equal(departure.toLaneId,'end:in');assert.ok(arrival.terminalStop);assert.notEqual(arrival.toLaneId,departure.fromLaneId);
  assert.ok(arrival.points.at(-1).x<=27);assert.ok(arrival.points.at(-1).x>26.5);assert.equal(arrival.points.at(-1).z,2);assert.equal(departure.points[0].z,-2);
  assert.ok(departure.points[0].x>departure.points.at(-1).x);assert.ok(departure.points.every(p=>Math.sin(p.yaw)<-.99));
});
test('a tail stops at the first obstacle instead of resuming on the road behind it',()=>{
  const r=createRoadTerminalEdges({approaches:[approach()],lanePoint,laneRoad:(x)=>x<15||x>17,vehicleFits:()=>true});
  assert.equal(r.connections.length,2);assert.ok(r.connections.every(e=>e.points.every(p=>p.x<15)));
});
test('existing junction spans and bridge continuations do not receive false dead ends',()=>{
  const a=approach(),b=approach();a.nextJunctionId='next';b.bridgePeerId='bridge';
  const r=createRoadTerminalEdges({approaches:[a,b],lanePoint,laneRoad:()=>true,vehicleFits:()=>true});assert.equal(r.connections.length,0);
});
