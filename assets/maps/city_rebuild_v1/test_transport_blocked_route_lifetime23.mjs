// Read-only repro: actual source TickCar and real route registry; deterministic
// worker replies isolate ownership/lifetime from route geometry generation.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {createLaneRouteJobs} from './city_lane_route_jobs.mjs';
let now=1000;
const worker={postMessage(message){
 if(message.type==='init')this.onmessage({data:{type:'initialized',generation:message.generation}});
 if(message.type==='route')this.onmessage({data:{type:'result',generation:message.generation,token:message.token,result:{status:'ready',points:[{r:10,c:11,angle:0}],controls:[]}}});
},terminate(){}};
const jobs=createLaneRouteJobs({createWorker:()=>worker,clock:()=>now,setTimer:()=>0,clearTimer(){},maxResults:2});
jobs.initialize({});
const sourcePath=process.argv.find(a=>a.startsWith('--source='))?.slice(9);
let source=fs.readFileSync(sourcePath||new URL('./civilian_parking_trip_source.js',import.meta.url),'utf8');
const candidate=process.argv.includes('--candidate');
const expectFixed=candidate||!process.argv.includes('--expect-bug');
if(candidate){const old='t.destinationDoor=t.plan.goal.door;delete car._civilianNativePlan;t.phase=\'planning\';';assert.equal(source.split(old).length,2);source=source.replace(old,'t.destinationDoor=t.plan.goal.door;_civilianTripCancelLane(car._civilianNativePlan);delete car._civilianNativePlan;t.phase=\'planning\';');}
const car={id:'audit-car',r:10,c:10,ang:0,dirDx:1,dirDy:0,model:{L:1.8,W:.88}},npc={id:'driver',r:10,c:10,hp:100,alive:true,_civilianTripRiding:true},pedestrian={id:'blocking-person',r:10,c:10.95,hp:100};
const calls=[];
const box={console,performance:{now:()=>now},window:{},document:{documentElement:{dataset:{}}},CARS:[car],NPCS:[npc,pedestrian],player:{r:100,c:100},myDrivingCarId:null,prevT:now,MAP:Array.from({length:120},()=>Array(120).fill(9)),_parkingNpcs:[],
 _walkRendererActive:()=>true,_threeVehicleEntityId:c=>c.id,_threeNpcEntityId:n=>n.id,_clearNpcRoute(){},
 _walkTrafficNavigationResolver(q){calls.push(q.mode);if(q.mode==='driver')return {ready:true};if(q.mode==='lane-route-touch')return jobs.touch(q.requestId);if(q.mode==='lane-route-cancel')return jobs.cancel(q.requestId);return {clear:true};}
};
vm.createContext(box);vm.runInContext(source+';globalThis.api={register:_civilianTripRegister,tick:_civilianTripTickCar,release:_civilianTripRelease};',box);
function ready(id){return jobs.query({mode:'lane-route',requestId:id});}
ready('other-live-route');
const route=ready('abandoned-route');assert.equal(route.status,'ready');
car._civilianNativePlan={status:'ready',laneRequestId:'abandoned-route'};
const trip={car,npc,carId:car.id,phase:'drive',since:now,index:0,travelledM:0,plan:{native:true,points:route.points,controls:[],goal:{door:{id:'destination',r:10,c:12}},lots:[]}};
assert(box.api.register(trip));
for(let i=0;i<140&&trip.phase==='drive';i++){now+=100;box.prevT=now;box.api.tick(car,.1);}
assert.equal(car._civilianBlockReason,'pedestrian');assert.equal(trip.phase,'planning');assert.equal(car._civilianNativePlan,undefined);assert.equal(car.r,10);assert.equal(car.c,10);
const afterReplan=jobs.diagnostics(),cancelCallsBeforeRelease=calls.filter(m=>m==='lane-route-cancel').length;
box.api.release(trip,'audit-cleanup');
const afterTripRelease=jobs.diagnostics(),orphanTouch=jobs.touch('abandoned-route');
// Small capacity gives the same ordering as default64: an abandoned route is
// occupies capacity and can displace an older live result on later admission.
ready('new-route');
const evictedOther=jobs.touch('other-live-route');
const result={candidate,expectFixed,reproduced:orphanTouch.status==='ready',blockedBy:car._civilianBlockReason,phaseAfterBlock:'planning',cancelCallsBeforeRelease,afterReplan,afterTripRelease,orphanTouch,capacityDemo:{limit:2,otherLiveRoute:evictedOther},limits:'Actual source TickCar physical pedestrian sweep and real lane-job lifecycle; worker returns deterministic route. Candidate mode edits only in-memory source. No authored-route acceptance, GPU or whole-scene FPS claim.'};
if(expectFixed){assert.equal(cancelCallsBeforeRelease,1);assert.equal(calls.filter(m=>m==='lane-route-cancel').length,1,'release must not cancel the old route twice');assert.equal(orphanTouch.reason,'route_expired');assert.equal(evictedOther.status,'ready');}
else{assert.equal(cancelCallsBeforeRelease,0);assert.equal(orphanTouch.status,'ready');assert.equal(evictedOther.reason,'route_expired');}
fs.writeFileSync(new URL('../../../outputs/transport_blocked_route_lifetime23'+(candidate?'_candidate':expectFixed?'_fixed':'_baseline')+'.json',import.meta.url),JSON.stringify(result,null,2));
console.log(JSON.stringify(result,null,2));jobs.dispose();
