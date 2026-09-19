import test from 'node:test';
import assert from 'node:assert/strict';
import {createCityRoadNavigation} from './city_road_navigation.mjs';

test('parking anchors expose actual bay dimensions and source headings without sharing mutable records',()=>{
 const bays=[{id:'bay:1',lotId:'lot:1',x:8.2,z:12.3,yaw:Math.PI/2,width:3.2,length:6.4}];
 let loaded=false;const road={trafficPlan:{}};
 const navigation=createCityRoadNavigation({getRoadPlan:()=>loaded?road:null,getParkingPlan:()=>({lots:[],bays}),createRouter:()=>({route(){throw Error('anchor query must not plan a route')}})});
 assert.equal(navigation.query({mode:'parking-anchors'}).status,'pending');loaded=true;
 const result=navigation.query({mode:'parking-anchors'});assert.equal(result.ready,true);
 assert.deepEqual(result.slots,[{id:'bay:1',lotId:'lot:1',r:12.3/4.1,c:2,angle:0,widthM:3.2,lengthM:6.4}]);
 result.slots[0].id='mutated';assert.equal(navigation.query({mode:'parking-anchors'}).slots[0].id,'bay:1');assert.equal(bays[0].id,'bay:1');
});

test('service manoeuvre retains its signal before reversing and fails closed without that control',()=>{
 const building={id:'detention',role:'district_detention',transform:{yawDegrees:0},stopFootprint:{minC:10,maxC:14,minR:20,maxR:24}},anchor={edgeId:'turn:signal',pointIndex:1,progressM:2,point:{x:12,z:20,yaw:0}};
 const plan={trafficPlan:{},serviceAccess:{routes:[{id:'service:entry',buildingId:building.id,laneAnchor:anchor,retainedTurnId:'turn:signal',speedLimitKmh:4,requiresStopBeforeReverse:true,gear:-1,points:[{x:12,z:20,yaw:0,gear:-1},{x:12,z:16,yaw:0,gear:-1}]}],issues:[]}};
 let retains=true,requested;
 const nav=createCityRoadNavigation({getRoadPlan:()=>plan,getParkingPlan:()=>({lots:[]}),getInstances:()=>[building],isRoad:()=>true,poseAllowed:()=>true,createRouter:()=>({route(q){requested=q;return{status:'ready',points:[q.from,q.to],controls:retains?[{turnId:'turn:signal',rule:'signal',distanceM:2,stopPoint:{x:12,z:12}}]:[]};}})});
 const r=nav.query({mode:'lane-route',from:{c:12/4.1,r:10/4.1,angle:Math.PI/2},to:{buildingId:building.id,c:12/4.1,r:16/4.1}});
 assert.equal(r.status,'ready');assert.equal(requested.toAnchor,anchor);assert.equal(r.points.at(-1).gear,'reverse');assert.equal(r.points.at(-1).speedLimitKmh,4);assert.equal(r.controls[0].appliesUntilM,r.distanceM);
 retains=false;assert.equal(nav.query({mode:'lane-route',from:{r:1,c:2},to:{buildingId:building.id,r:4,c:3}}).reason,'missing_service_approach_control');
});

function fixture({blocked=()=>false,loaded=true,pathControls=()=>[]}={}){
 let builds=0,current=loaded?{trafficPlan:{drivingSide:'right',speedLimitKmh:40},preparedLaneGraph:{version:1}}:null;
 const calls=[],lot={id:'parking:home',buildingId:'home',name:'Парковка у дома',rect:{minX:20,maxX:30,minZ:12,maxZ:20},driveway:{minX:20,maxX:25,minZ:10,maxZ:12}};
 const parking={lots:[lot],coverage:[{buildingId:'home',lotId:lot.id,status:'served',walkingDistance:14}],access:{routes:[{id:'entry',lotId:lot.id,kind:'entry',gear:'forward',points:[{x:22,z:10,yaw:0},{x:22,z:15,yaw:0}]},{id:'exit',lotId:lot.id,kind:'exit',gear:'reverse',points:[{x:22,z:15,yaw:0},{x:22,z:10,yaw:0}]}]}};
 const navigation=createCityRoadNavigation({getRoadPlan:()=>current,getParkingPlan:()=>parking,getInstances:()=>[{id:'home',entry:{roadProbeRC:{c:5,r:2}}}],isRoad:()=>true,poseAllowed:(x,z,yaw)=>!blocked(x,z,yaw),createRouter:options=>{builds++;assert.equal(options.preparedPlan,current.preparedLaneGraph);return {diagnostics:{prepared:true},registerExternalPathControls:pathControls,controlIndex:{approachById:new Map([['a',{id:'a',junctionId:'j',rule:'signal',stopPoint:{x:20.5,z:41},axis:0,offset:7}]])},evaluateControl:()=>({allowed:false,reason:'traffic_signal',stopPoint:{x:20.5,z:41}}),route:q=>{calls.push(q);return {status:'ready',points:[{...q.from,yaw:q.from.yaw??0},{...q.to,yaw:q.to.yaw??0}],controls:[{approachId:'a',distanceM:5,stopPoint:{x:20.5,z:41}}],snappedStart:{point:{...q.from,yaw:q.from.yaw??0}},snappedEnd:{point:{...q.to,yaw:q.to.yaw??0}},edgeIds:['e']}}}}});
 return {navigation,calls,get builds(){return builds},load(){current={trafficPlan:{drivingSide:'right',speedLimitKmh:40},preparedLaneGraph:{version:1}}}};
}
test('source bridge uses native4.1 metres and source heading for every pose field',()=>{
 const {navigation,calls}=fixture();const r=navigation.query({mode:'lane-route',from:{r:1,c:2,angle:Math.PI/2},to:{r:1,c:3}});
 assert.deepEqual({x:calls[0].from.x,z:calls[0].from.z,yaw:calls[0].from.yaw},{x:8.2,z:4.1,yaw:0});assert.equal(r.status,'ready');assert.equal(r.points[0].r,1);assert.equal(r.points[0].c,2);assert.equal(r.points[0].angle,Math.PI/2);assert.equal(r.snappedEnd.point.c,3);assert.deepEqual(r.controls[0].stopPoint,{r:10,c:5});
});
test('road rules use the same controller and convert its stop point to source units',()=>{
 const {navigation}=fixture(),r=navigation.query({mode:'road-rules',approachId:'a',turnId:'t',time:20});assert.equal(r.control.allowed,false);assert.equal(r.control.reason,'traffic_signal');assert.deepEqual(r.approach.stopPoint,{r:10,c:5});assert.deepEqual(r.control.stopPoint,{r:10,c:5});assert.equal(navigation.query({mode:'road-rules',approachId:'missing'}).status,'blocked');
});
test('building destination joins the real driveway and reports its verified walking remainder',()=>{
 const {navigation,calls}=fixture(),r=navigation.route({from:{x:0,z:10,yaw:Math.PI/2},to:{id:'home',x:28,z:30}});assert.equal(calls[0].to.x,22);assert.equal(calls[0].to.z,10);assert.deepEqual(r.points.at(-1),{x:22,z:15,yaw:0});assert.equal(r.destination.lotId,'parking:home');assert.equal(r.destination.walkingDistance,14);assert.deepEqual(r.accessRouteIds,['entry']);
});
test('an obstacle between driveway samples blocks the displayed route',()=>{
 const {navigation}=fixture({blocked:(x,z)=>Math.abs(x-22)<.1&&z>12.1&&z<12.6});const r=navigation.route({from:{x:0,z:10,yaw:Math.PI/2},to:{id:'home',x:28,z:30}});assert.equal(r.status,'blocked');assert.equal(r.points.length,0);
});

test('a crossing near the parking entry stops the car on the preceding road segment',()=>{
 let path;const {navigation}=fixture({pathControls:q=>{path=q;return [{id:'entry:zebra',kind:'pedestrian_crossing',edgeId:'entry',crosswalkIds:['zebra'],progressM:-2,crossingProgressM:2.3,stopPoint:{x:22,z:10}}]}});
 const result=navigation.route({from:{x:0,z:10,yaw:Math.PI/2},to:{id:'home',x:28,z:30}}),control=result.controls.find(c=>c.id==='entry:zebra');
 assert.equal(path.id,'entry');assert.equal(path.points.at(-1).z,15);assert.equal(control.distanceM,20);assert.equal(control.requestedDistanceM,20);assert.deepEqual(control.stopPoint,{x:20,z:10});assert.equal(control.startInsideApproach,false);assert.equal(control.accessRouteId,'entry');
});
test('parking exit retains reverse gear and moves subsequent stop distances forward',()=>{
 const {navigation}=fixture(),r=navigation.query({mode:'lane-route',from:{c:22/4.1,r:15/4.1,angle:Math.PI/2},to:{c:0,r:10/4.1}});assert.equal(r.status,'ready');assert.ok(r.points.some(p=>p.gear==='reverse'));assert.ok(r.points.every(p=>Number.isFinite(p.angle)));assert.equal(r.controls[0].distanceM,10);
});

test('parking exit cannot turn an incorrectly oriented parked car in place',()=>{
 const {navigation,calls}=fixture(),result=navigation.route({from:{x:22,z:15,yaw:Math.PI/2},to:{x:0,z:10}});
 assert.equal(result.status,'blocked');assert.equal(result.reason,'parking_exit_unavailable');assert.equal(calls.length,0);
});

test('parking exit rejects a short sideways jump into its prescribed departure pose',()=>{
 const {navigation,calls}=fixture(),result=navigation.route({from:{x:23,z:15,yaw:0},to:{x:0,z:10}});
 assert.equal(result.status,'blocked');assert.equal(result.reason,'parking_exit_unavailable');assert.equal(calls.length,0);
});

test('parking-exit admission converts the exact source footprint and performs no lane search',()=>{
 const parking={lots:[{id:'lot',rect:{minX:10,maxX:30,minZ:10,maxZ:20}}],access:{routes:[{id:'exit',lotId:'lot',kind:'exit',gear:'reverse',points:[{x:22,z:15,yaw:0},{x:22,z:10,yaw:0}]}]}};
 let checked,block=false,loaded=false;
 const nav=createCityRoadNavigation({getRoadPlan:()=>({trafficPlan:{}}),getParkingPlan:()=>parking,isRoad:()=>true,poseAllowed:(x,z,yaw,p)=>{checked=p;return !block},getVehicleProfile:()=>loaded?{halfWidth:1.5,halfLength:3}:null,createRouter:()=>({route(){throw Error('No lane search in admission')}})});
 const q={mode:'parking-exit',from:{r:15/4.1,c:22/4.1,angle:Math.PI/2},vehicleId:'source-car'};
 assert.equal(nav.query(q).status,'pending');
 const r=nav.query({...q,profile:{halfWidth:1.2/4.1,halfLength:2.5/4.1}});
 assert.equal(r.status,'ready');assert.equal(r.carId,'source-car');assert.equal(checked.halfWidth,1.2);assert.equal(checked.halfLength,2.5);assert.equal(r.points.at(-1).gear,'reverse');assert.equal(r.accessRouteId,'exit');
 assert.equal(nav.query({...q,profile:{halfWidth:0,halfLength:NaN}}).reason,'invalid_vehicle_profile');
 loaded=true;assert.equal(nav.query(q).status,'ready');assert.equal(checked.halfLength,3);
 block=true;assert.equal(nav.query(q).reason,'parking_exit_unavailable');
});

test('source bridge converts both snapped connector paths without leaking world coordinates',()=>{
 const plan={trafficPlan:{}};
 const navigation=createCityRoadNavigation({getRoadPlan:()=>plan,getParkingPlan:()=>({lots:[]}),isRoad:()=>true,poseAllowed:()=>true,createRouter:()=>({route:q=>({status:'ready',points:[q.from,q.to],snappedStart:{point:q.from,connector:{points:[q.from],lengthM:0}},snappedEnd:{point:q.to,connector:{points:[q.to],lengthM:0}}})})});
 const result=navigation.query({mode:'lane-route',from:{c:2,r:3,angle:.25},to:{c:4,r:5,angle:.5}});
 for(const [snap,c,r,heading] of [[result.snappedStart,2,3,.25],[result.snappedEnd,4,5,.5]]){
  assert.equal(snap.connector.lengthM,0);const p=snap.connector.points[0];assert.ok(Math.abs(p.c-c)<1e-12&&Math.abs(p.r-r)<1e-12&&Math.abs(p.angle-heading)<1e-12);assert.equal(p.x,undefined);assert.equal(p.z,undefined);assert.equal(p.yaw,undefined);
 }
});
test('loading, reload and repeated queries cannot retain a stale road index',()=>{
 const f=fixture({loaded:false}),q={from:{x:0,z:0,yaw:0},to:{x:2,z:0}};assert.equal(f.navigation.route(q).status,'pending');f.load();f.navigation.route(q);f.navigation.route(q);assert.equal(f.builds,1);f.navigation.invalidate();f.navigation.route(q);assert.equal(f.builds,2);f.load();f.navigation.route(q);assert.equal(f.builds,3);
});

test('district detention routes target their physical service stop in each authored orientation',()=>{
 for(const degrees of [0,180,270]){
  let requested;
  const building={id:'detention',role:'district_detention',transform:{yawDegrees:degrees},stopFootprint:{minC:10,maxC:14,minR:20,maxR:24}};
  const navigation=createCityRoadNavigation({getRoadPlan:()=>({trafficPlan:{}}),getParkingPlan:()=>({lots:[]}),getInstances:()=>[building],isRoad:()=>true,poseAllowed:()=>true,createRouter:()=>({route:q=>{requested=q;return {status:'ready',points:[q.from,q.to]}}})});
  const result=navigation.route({from:{x:0,z:0,yaw:0},to:{id:building.id,x:99,z:99}});
  assert.equal(result.status,'ready');assert.deepEqual(requested.to,{x:12*4.1,z:22*4.1,yaw:degrees*Math.PI/180-Math.PI/2});assert.equal(result.destination.kind,'service_stop');
 }
});

test('building may use another verified walk-connected parking, while an explicit lot keeps its identity',()=>{
 const lots=['near','reachable'].map((id,i)=>({id,buildingId:'home',rect:{minX:40+i*20,maxX:45+i*20,minZ:10,maxZ:20}}));
 const parking={lots,coverage:[{buildingId:'home',lotId:'near',status:'served'}],walkingAlternatives:[{buildingId:'home',lotId:'near',distance:10},{buildingId:'home',lotId:'reachable',distance:30}],access:{routes:lots.map((l,i)=>({id:'entry-'+l.id,lotId:l.id,kind:'entry',points:[{x:40+i*20,z:8,yaw:0},{x:40+i*20,z:15,yaw:0}]}))}};
 const plan={trafficPlan:{}};
 const navigation=createCityRoadNavigation({getRoadPlan:()=>plan,getParkingPlan:()=>parking,getInstances:()=>[{id:'home',entry:{roadProbeRC:{r:1,c:1}}}],isRoad:()=>true,poseAllowed:()=>true,createRouter:()=>({route:q=>q.to.x===40?{status:'blocked',reason:'no_directed_connection',points:[]}:{status:'ready',points:[q.from,q.to]}})});
 const buildingRoute=navigation.route({from:{x:0,z:8,yaw:0},to:{id:'home',x:44,z:14}});
 assert.equal(buildingRoute.destination.lotId,'reachable');assert.equal(buildingRoute.destination.walkingDistance,30);assert.equal(buildingRoute.points.at(-1).x,60);
 const exactLot=navigation.route({from:{x:0,z:8,yaw:0},to:{lotId:'near',x:44,z:14}});
 assert.equal(exactLot.status,'blocked');assert.equal(exactLot.reason,'no_directed_connection');
 const preflight=navigation.query({mode:'parking-destination',to:{buildingId:'home',r:14/4.1,c:44/4.1}});
 assert.deepEqual(preflight.lotIds,['near','reachable']);
 const availableOnly=navigation.query({mode:'lane-route',from:{r:8/4.1,c:0,angle:Math.PI/2},to:{buildingId:'home',r:14/4.1,c:44/4.1,lotIds:['reachable']}});
 assert.equal(availableOnly.status,'ready');assert.equal(availableOnly.destination.lotId,'reachable');
});

test('mid-block pedestrian rule round-trip keeps stop coordinates and occupied crossings',()=>{
 let checked,occupancy;
 const navigation=createCityRoadNavigation({getRoadPlan:()=>({trafficPlan:{}}),getParkingPlan:()=>({lots:[]}),getInstances:()=>[],isRoad:()=>true,poseAllowed:()=>true,createRouter:()=>({evaluateControl:(control,state)=>{checked=control;occupancy=state;return {allowed:false,reason:'pedestrian_crossing',stopPoint:control.stopPoint}}})});
 const result=navigation.query({mode:'road-rules',control:{kind:'pedestrian_crossing',edgeId:'lane',crosswalkIds:['zebra'],stopPoint:{r:20,c:10}},occupiedCrosswalkIds:['zebra'],time:12});
 assert.deepEqual(checked.stopPoint,{x:41,z:82});assert.deepEqual(occupancy.occupiedCrosswalkIds,['zebra']);assert.equal(result.control.allowed,false);assert.deepEqual(result.control.stopPoint,{r:20,c:10});
});
