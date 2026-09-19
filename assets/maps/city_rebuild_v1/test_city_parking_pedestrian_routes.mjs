import test from 'node:test';
import assert from 'node:assert/strict';
import {createPedestrianAccessPlan} from './city_pedestrian_access_plan.mjs';
import {createParkingPedestrianSurface,crossingControlsConflict} from './city_parking_pedestrian_routes.mjs';

function topology(){return {grid:Array.from({length:12},()=>Array(12).fill(9)),roadMask:Array.from({length:12},()=>Array(12).fill(0))};}
test('full pedestrian circle catches a body corner missed by cardinal probes',()=>{
 const map=topology(),body={polygonCR:[[2,2],[3,2],[3,3],[2,3]],minYM:0,maxYM:2};
 const field=createPedestrianAccessPlan({topology:map,extraBodies:[body],metresPerCell:1,radius:.36,buildEntranceField:false});
 assert.equal(field.clear(1.75,1.75),false);assert.equal(field.clear(1.7,1.7),true);
});
test('full circle rejects a diagonal water-tile corner',()=>{
 const map=topology();map.grid[2][2]=7;
 const field=createPedestrianAccessPlan({topology:map,metresPerCell:1,radius:.36,buildEntranceField:false});
 assert.equal(field.clear(1.75,1.75),false);assert.equal(field.clear(1.7,1.7),true);
});
test('swept capsule catches a grazing corner between discrete clear samples',()=>{
 const map=topology(),body={polygonCR:[[2,2.05],[2.05,2.05],[2.05,2.06],[2,2.06]],minYM:0,maxYM:2},field=createPedestrianAccessPlan({topology:map,extraBodies:[body],metresPerCell:1,radius:.36,buildEntranceField:false}),a={x:1.641,z:1.8},b={x:1.641,z:2.15};
 assert(field.clear(a.x,a.z));assert(field.clear(a.x,(a.z+b.z)/2));assert(field.clear(b.x,b.z));assert.equal(field.segmentClear(a,b),false);
});
test('road traversal uses a complete portal and reports actual walking metres',()=>{
 const map=topology();for(let r=0;r<12;r++)for(const c of[4,5]){map.grid[r][c]=0;map.roadMask[r][c]=1;}
 const base={topology:map,metresPerCell:1,radius:.36,step:.5,allowedTiles:[0,8,9],buildEntranceField:false},surface=createParkingPedestrianSurface({topology:map,parkingPlan:{surfaceRects:[]},crosswalks:[],metresPerCell:1}),physical=createPedestrianAccessPlan(base),field=createPedestrianAccessPlan({...base,surfaceAllowsCircle:surface.allowsCircle}),crossing={id:'crossing',endpoints:[{x:3.4,z:5},{x:6.6,z:5}]};
 assert.equal(field.routeBetween({x:1,z:1},{x:9,z:1}),null);
 assert.deepEqual(field.setCrossingPortals([crossing],physical.segmentClear),{accepted:1,rejected:0});
 const route=field.routeBetween({x:1,z:1},{x:9,z:1});assert(route);assert.deepEqual(route.crosswalkIds,['crossing']);assert(route.points.some(p=>p.x===3.4&&p.z===5));assert(route.points.some(p=>p.x===6.6&&p.z===5));
 const metres=route.points.slice(1).reduce((sum,p,i)=>sum+Math.hypot(p.x-route.points[i].x,p.z-route.points[i].z),0);assert(Math.abs(metres-route.length)<1e-8);assert.equal(field.routeBetween({x:1,z:1},{x:9,z:1},{maxLength:8}),null);
 // Crossing masks are not merged into an asphalt walking area: the goal may
 // not stop or walk longitudinally in the carriageway between two portals.
 field.setCrossingPortals([crossing,{id:'other',endpoints:[{x:3.4,z:6},{x:6.6,z:6}]}],physical.segmentClear);
 assert.equal(field.routeBetween({x:1,z:1},{x:5,z:5.5}),null);
});
test('crossing portals retain final physical blockers',()=>{
 const map=topology();for(let r=0;r<12;r++)for(const c of[4,5]){map.grid[r][c]=0;map.roadMask[r][c]=1;}
 const body={polygonCR:[[4.9,4.9],[5.1,4.9],[5.1,5.1],[4.9,5.1]],minYM:0,maxYM:3},base={topology:map,extraBodies:[body],metresPerCell:1,radius:.36,step:.5,allowedTiles:[0,8,9],buildEntranceField:false},surface=createParkingPedestrianSurface({topology:map,parkingPlan:{surfaceRects:[]},crosswalks:[],metresPerCell:1}),physical=createPedestrianAccessPlan(base),field=createPedestrianAccessPlan({...base,surfaceAllowsCircle:surface.allowsCircle});
 assert.deepEqual(field.setCrossingPortals([{id:'blocked',endpoints:[{x:3.4,z:5},{x:6.6,z:5}]}],physical.segmentClear),{accepted:0,rejected:1});
});
test('private driveway support does not grant access to adjacent public asphalt',()=>{
 const map=topology();for(let r=0;r<12;r++)for(let c=0;c<12;c++){map.grid[r][c]=0;map.roadMask[r][c]=1;}
 const surface=createParkingPedestrianSurface({topology:map,parkingPlan:{surfaceRects:[{minX:2,maxX:4,minZ:2,maxZ:4}]},crosswalks:[],metresPerCell:1});
 assert(surface.allowsCircle(3,3,.38));assert(!surface.allowsCircle(3.8,3.8,.38));assert(!surface.allowsCircle(4.4,3,.38));
});
test('adjacent crossings cannot place another zebra or stop line in their walking band',()=>{
 const crossing=(x,z,tx=1,tz=0)=>({center:{x,z},tx,tz,endpoints:[{x:x+tz*5,z:z-tx*5},{x:x-tz*5,z:z+tx*5}],roadStart:{x:x+tz*4,z:z-tx*4},roadEnd:{x:x-tz*4,z:z+tx*4}}),a=crossing(0,0);
 assert(crossingControlsConflict(a,crossing(0,0,0,1)),'perpendicular zebra collision');assert(crossingControlsConflict(a,crossing(2.7,0)),'disjoint zebras still conflict with the other stop line');assert(!crossingControlsConflict(a,crossing(12,0)));
});
