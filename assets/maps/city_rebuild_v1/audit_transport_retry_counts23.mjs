// Read-only counter semantics audit, not a reproduction of a live obstruction.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {createNpcVehicleNavigation} from './npc_vehicle_navigation.mjs';

const nav=createNpcVehicleNavigation({poseAllowed:()=>false,isRoad:()=>true,frameBudgetMs:100});
const request={mode:'route',carId:'one-car',requestId:'same-request',from:{r:10,c:10,angle:0},to:{r:20,c:20,angle:0},roadsOnly:true};
let result;for(let i=0;i<100;i++){nav.beginFrame();result=nav.query(request);}
assert.equal(result.status,'blocked');assert.equal(nav.diagnostics().failed,1,'polling a retained blocked job does not add failures');

let now=0;const car={id:'one-car',r:10,c:10,ang:0,parked:true,model:{L:1.8,W:.88}},npc={id:'one-resident',r:9,c:10,hp:60},requests=[],lanes=[];
const productionNav=createNpcVehicleNavigation({poseAllowed:()=>false,isRoad:()=>true,frameBudgetMs:100});
const doors=Array.from({length:12},(_,i)=>({id:'door-'+i,r:30+i*4,c:30}));
const ctx={CARS:[car],NPCS:[npc],prevT:0,performance:{now:()=>now},window:{__npcTripDiagnostics:true},_walkRendererActive:()=>true,_threeVehicleEntityId:c=>c.id,_threeNpcEntityId:n=>n.id,
 _walkTrafficNavigationResolver(q){
  if(q.mode==='parking-destination')return {ready:true,status:'ready',lotIds:['destination-lot']};
  if(q.mode==='parking-anchors')return {ready:true,slots:[{id:'bay',lotId:'destination-lot',r:80,c:80,angle:0,widthM:5,lengthM:10}]};
  if(q.mode==='lane-route'){lanes.push(q.requestId);return {status:'blocked',reason:'controlled_lane_refusal'};}
  if(q.mode==='road-targets')return {status:'ready',points:Array.from({length:4},(_,i)=>({r:q.from.r,c:q.from.c+i+1,angle:0}))};
  if(q.mode==='route'){requests.push({id:q.requestId,from:q.from,to:q.to});return productionNav.query(q);}
  return {status:'blocked',reason:'route_cancelled'};
 }};
vm.createContext(ctx);vm.runInContext(fs.readFileSync(new URL('./civilian_parking_trip_source.js',import.meta.url),'utf8'),ctx);
ctx.car=car;ctx.npc=npc;ctx.doors=doors;
vm.runInContext('_civilianTripRegister({car,npc,carId:car.id,phase:"planning"});car._civilianNativePlan={status:"pending",doors,doorIndex:0,attempt:0,nextAt:0,laneRejected:false,createdAt:0};',ctx);
for(let frame=0;frame<100&&car._civilianNativePlan.status!=='blocked';frame++){now+=200;ctx.prevT=now;productionNav.beginFrame();ctx._civilianTripNativePlan(car);}
const unique=new Set(requests.map(r=>r.id));assert.equal(unique.size,48);assert.equal(lanes.length,12);assert.equal(productionNav.diagnostics().failed,48);assert.equal(car._civilianNativePlan.reason,'no-reachable-building');
const report={sameBlockedJob100Polls:{failed:nav.diagnostics().failed},oneNpcOneCarOnePlanningCycle:{laneAttempts:lanes.length,nativeRouteRequests:requests.length,uniqueNativeRequestIds:unique.size,nativeFailed:productionNav.diagnostics().failed,doors:doors.length,finalReason:car._civilianNativePlan.reason},limits:'Actual production planner and native route counter; controlled lane refusal and blocked geometry solely demonstrate count units. These 48 failures are NOT observations from the browser.'};
fs.writeFileSync(new URL('../../../outputs/transport_retry_counts23.json',import.meta.url),JSON.stringify(report,null,2));console.log(report);
