import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';
import {createNpcVehicleNavigation} from './npc_vehicle_navigation.mjs';
import {createCarWorld,carFits} from './car_drive.mjs';
import {collisionPolygon} from './vehicle_collision_shape.mjs';
import {polygonVehicleContact} from './vehicle_contact.mjs';

// Four real source trips share one actual city lane.  A fifth full-hull car
// closes the lane long enough for a physical queue to form, then leaves.  The
// original drivers/routes must continue without overlap or a replacement car.
const f=await createCivilianNativeFixture({tripLimit:8}),{M,box}=f;
const world=createCarWorld(f.top,f.bodies,M),actors=new Map(),rows=[];
f.actor.object.visible=false;f.cars.splice(0);f.npcs.splice(0);
const road=(x,z)=>!!f.top.roadMask[Math.floor(z/M)]?.[Math.floor(x/M)];
const nav=createNpcVehicleNavigation({
 worldScale:M,
 poseAllowed:(x,z,yaw,shape)=>carFits(x,z,yaw,world,shape),
 isRoad:road,waterAt:f.waterAt,groundHeight:f.floor,
 getVehicle:id=>actors.get(id)||f.actor,
 getVehicles:()=>[...actors].map(([id,actor])=>({id,actor}))
});
const route=(carId,from,to)=>{
 let result;
 for(let frame=0;frame<300;frame++){
  nav.beginFrame();
  result=nav.query({mode:'route',requestId:carId+':convoy',carId,from,to,roadsOnly:true});
  if(result.status!=='pending')break;
 }
 return result;
};
let lane=null;
for(const r of [9.356984627970292,12.5,18.5,25.5]){
 for(let c=80;c<180;c+=2){
  const starts=Array.from({length:4},(_,i)=>({r,c:c+i*2,angle:0}));
  const ends=starts.map(p=>({...p,c:p.c+20}));
  const clear=starts.every((p,i)=>road(p.c*M,p.r*M)&&nav.query({carId:'probe',from:p,to:ends[i],roadsOnly:true}).clear);
  if(clear){lane={starts,ends};break;}
 }
 if(lane)break;
}
assert(lane,'actual city has a straight lane long enough for the convoy');
const profile=f.actor.profile,shape={
 halfWidth:(profile.collisionHalfWidth??profile.halfWidth)*Math.abs(f.actor.object.scale.x),
 halfLength:(profile.collisionHalfLength??profile.halfLength)*Math.abs(f.actor.object.scale.z)
};
for(let i=0;i<4;i++){
 const id='actual_convoy_'+i,start=lane.starts[i],end=lane.ends[i];
 const actor={object:f.actor.object.clone(true),profile,seats:f.actor.seats};
 actor.object.visible=true;f.scene.add(actor.object);actors.set(id,actor);
 const car={id,r:start.r,c:start.c,ang:0,dirDx:1,dirDy:0,parked:false,model:{L:1.8,W:.88}};
 const npc={id:'convoy_driver_'+i,r:start.r,c:start.c,hp:100,max_hp:100,walkPhase:0,look:{hair:i},speed:1,_civilianTripRiding:true};
 const planned=route(id,start,end);assert.equal(planned.status,'ready',JSON.stringify(planned));
 const trip={car,npc,carId:id,phase:'drive',plan:{native:true,points:planned.points,goal:{door:{id:'convoy_goal_'+i}},lots:[],controls:[]},index:0,progress:1,since:0,travelledM:0};
 rows.push({id,actor,car,npc,trip,start,end});f.cars.push(car);f.npcs.push(npc);
}
const sync=()=>{for(const row of rows){const {car,actor}=row;actor.object.position.set(car.c*M,f.floor(car.c*M,car.r*M),car.r*M);actor.object.rotation.y=Math.PI/2-car.ang;actor.object.updateMatrixWorld(true);}};
sync();
box.nativeConvoyQuery=q=>q.mode==='driver'?{ready:rows.some(v=>v.id===q.carId&&v.npc.id===q.npcId&&v.npc.hp>0)}:nav.query(q);
vm.runInContext('_walkTrafficNavigationResolver=nativeConvoyQuery;globalThis.register=_civilianTripRegister;globalThis.byCar=_civilianTripForCar;',box);
for(const row of rows)assert(box.register(row.trip));

const front=rows.at(-1),blocker={object:front.actor.object.clone(true),profile};
blocker.object.visible=true;
const blockerC=front.start.c+6.60;
blocker.object.position.set(blockerC*M,f.floor(blockerC*M,front.end.r*M),front.end.r*M);
blocker.object.rotation.y=Math.PI/2;blocker.object.updateMatrixWorld(true);actors.set('convoy_blocker',blocker);
const costs=[],minimumGaps=[];
// Current native acceleration reaches the blocker in about nine seconds and
// the first follower closes its safe gap by eleven; keep
// this below the twelve-second congestion recovery threshold.
for(let frame=0;frame<220;frame++){
 f.nextFrame(.05);nav.beginFrame();const started=performance.now();
 for(const row of rows)box._civilianTripTickCar(row.car,.05);
 costs.push(performance.now()-started);sync();
 let gap=Infinity;
 for(let i=1;i<rows.length;i++)gap=Math.min(gap,Math.hypot(rows[i].car.r-rows[i-1].car.r,rows[i].car.c-rows[i-1].car.c)*M);
 minimumGaps.push(gap);
 for(let i=0;i<rows.length;i++)for(let j=i+1;j<rows.length;j++)assert(!polygonVehicleContact(
  collisionPolygon(rows[i].car.c*M,rows[i].car.r*M,Math.PI/2-rows[i].car.ang,shape),
  collisionPolygon(rows[j].car.c*M,rows[j].car.r*M,Math.PI/2-rows[j].car.ang,shape)
 ),'queued full hulls never overlap');
}
const queued=rows.filter(row=>row.car._civilianBlockReason==='vehicle');
assert(queued.length>=2,'the stopped leader forms a real multi-car queue: '+JSON.stringify(rows.map(row=>({c:row.car.c,phase:row.trip.phase,reason:row.car._civilianBlockReason,travelledM:row.trip.travelledM}))));
assert(queued.every(row=>row.car._civilianBlockerId),'every vehicle block identifies the exact blocking car');
assert.equal(front.car._civilianBlockerId,'convoy_blocker','the queue leader identifies the external blocker');
assert(rows.every(row=>box.byCar(row.car)===row.trip&&row.trip.phase==='drive'),'short congestion retains every original trip and driver');
const stopped=rows.map(row=>({id:row.id,c:row.car.c,travelledM:row.trip.travelledM||0,reason:row.car._civilianBlockReason||null,blockerId:row.car._civilianBlockerId||null}));
actors.delete('convoy_blocker');
for(let frame=0;frame<600&&rows.some(row=>row.trip.phase==='drive');frame++){
 f.nextFrame(.05);nav.beginFrame();const started=performance.now();
 for(const row of rows)box._civilianTripTickCar(row.car,.05);
 costs.push(performance.now()-started);sync();
}
assert(rows.every(row=>row.trip.phase==='parked'),'every queued original driver resumes and reaches its own target');
assert(rows.every(row=>row.trip.travelledM>20),'every source car records physical route progress');
costs.sort((a,b)=>a-b);
const report={
 passed:true,drivers:rows.length,queued:queued.length,staticBodies:f.bodies.length,
 minimumQueueGapM:Math.min(...minimumGaps),stopped,
 completed:rows.map(row=>({id:row.id,travelledM:row.trip.travelledM,phase:row.trip.phase,position:{r:row.car.r,c:row.car.c}})),
 cost:{p50Ms:costs[Math.floor(costs.length*.5)],p95Ms:costs[Math.floor(costs.length*.95)],maxMs:costs.at(-1)},
 nav:nav.diagnostics(),
 limits:'Actual static city and compact-sedan profile, actual source trip registry/TickCar and full dynamic hulls. Controlled four-car same-lane queue; no rendered scene, intersections, parking admission, pedestrian boarding or global FPS.'
};
fs.writeFileSync(new URL('../../../outputs/npc_traffic_convoy_actual_20260919.json',import.meta.url),JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
