import test from 'node:test';import assert from 'node:assert/strict';
import {createRoadEdgeControls,evaluateRoadEdgeControl} from './city_road_edge_controls.mjs';
const edge={id:'road-edge',edgeKind:'connection',points:[{x:0,z:0,yaw:0},{x:0,z:20,yaw:0}],cumulative:[0,20]};
const crossing={id:'zebra',roadStart:{x:-4,z:10},roadEnd:{x:4,z:10}};
test('a mid-block zebra has an indexed stop before the crossing and rejects forged controls',()=>{
 const index=createRoadEdgeControls([edge],[crossing]),c=index.byEdge.get(edge.id)[0];assert.equal(c.kind,'pedestrian_crossing');assert.equal(c.progressM,5.7);assert.equal(c.crossingProgressM,10);
 assert.equal(evaluateRoadEdgeControl(index,{...c,crosswalkIds:[]},{occupiedCrosswalkIds:['zebra']}).reason,'pedestrian_crossing');
 assert.equal(evaluateRoadEdgeControl(index,{...c,id:'fake'}).reason,'unknown_road_control');assert.equal(evaluateRoadEdgeControl(index,{...c,edgeId:'wrong'}).allowed,false);
 assert.equal(evaluateRoadEdgeControl(index,c).allowed,true);
});
test('real railway occupancy blocks both connections and turns using its canonical rail ID',()=>{
 const turn={...edge,id:'turn-edge',edgeKind:'turn'},rail={id:'city-rail-crossing-2',x:0,z:12,tx:1,tz:0,length:8};
 const index=createRoadEdgeControls([edge,turn],[],null,[rail]);for(const e of [edge,turn]){const c=index.byEdge.get(e.id)[0];assert.equal(c.kind,'railway_crossing');assert.deepEqual(c.railCrossingIds,[rail.id]);assert.equal(evaluateRoadEdgeControl(index,c,{occupiedRailCrossingIds:[rail.id]}).reason,'railway_crossing_occupied');assert.equal(evaluateRoadEdgeControl(index,c,{occupiedCrosswalkIds:[rail.id]}).allowed,true);}
});
test('worker control data survives structuredClone and keeps service crossings and oncoming duty',()=>{
 const turnaround={...edge,kind:'dead_end_turnaround',controlProgressM:3,speedLimitKmh:5,conflictingEdgeIds:['opposite-lane']},initial=createRoadEdgeControls([turnaround],[{...crossing,id:'service-entry'}]),copy=createRoadEdgeControls([],[],structuredClone([...initial.byEdge]));
 const c=copy.byEdge.get(edge.id).find(c=>c.kind==='road_end_turnaround');assert.equal(evaluateRoadEdgeControl(copy,c,{occupiedEdgeIds:['opposite-lane']}).reason,'yield_to_oncoming');assert.equal(evaluateRoadEdgeControl(copy,c,{occupiedCrosswalkIds:['service-entry']}).reason,'pedestrian_crossing');
});
test('the car body yields where its centreline misses the end of a narrow zebra',()=>{
 const narrow={...crossing,roadStart:{x:-2,z:10},roadEnd:{x:2,z:10}},near={...edge,points:edge.points.map(p=>({...p,x:2.07}))},far={...edge,id:'far',points:edge.points.map(p=>({...p,x:3.4}))};
 const index=createRoadEdgeControls([near,far],[narrow]);assert.equal(index.byEdge.get(near.id).length,1);assert.equal(index.byEdge.has(far.id),false);assert.equal(evaluateRoadEdgeControl(index,index.byEdge.get(near.id)[0],{occupiedCrosswalkIds:['zebra']}).reason,'pedestrian_crossing');
 const angled={...edge,id:'angled',points:[{x:-3,z:6,yaw:Math.PI/4},{x:1,z:10,yaw:Math.PI/4},{x:5,z:14,yaw:Math.PI/4}],cumulative:[0,Math.sqrt(32),Math.sqrt(128)]};
 assert.equal(createRoadEdgeControls([angled],[{...narrow,roadStart:{x:2.9,z:10},roadEnd:{x:4,z:10}}]).byEdge.has('angled'),false,'oriented rectangle slice rejects a bounding projection which does not touch the actual hull');
});
