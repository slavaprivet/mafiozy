import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';

const sourcePath=process.argv.find(a=>a.startsWith('--source='))?.slice(9);
const code=fs.readFileSync(sourcePath||new URL('./civilian_parking_trip_source.js',import.meta.url),'utf8');
const slots=[0,1].map(i=>({id:'destination-'+i,lotId:'lot',r:20,c:20+i*5,angle:0,widthM:5,lengthM:10}));
function fixture(phase='drive',reply='route_expired'){
 const car={id:'car',r:10,c:10,ang:0,parked:false,model:{L:1.8,W:.88}},npc={id:'resident',r:10,c:10,hp:100,_civilianTripRiding:phase==='drive'},other={id:'other',r:40,c:40,ang:0,parked:true,model:{L:1.8,W:.88}},calls=[];
 const box={CARS:[car,other],NPCS:[npc],performance:{now:()=>10000},window:{},document:{documentElement:{dataset:{}}},_clearNpcRoute:()=>{},_walkRendererActive:()=>true,_threeVehicleEntityId:c=>c.id,_threeNpcEntityId:n=>n.id,
  _walkTrafficNavigationResolver(q){calls.push(q.mode);return q.mode==='lane-route-touch'?{status:reply==='ready'?'ready':'blocked',reason:reply}:{clear:true};}};
 vm.createContext(box);vm.runInContext(code+';globalThis.api={maintain:_civilianTripMaintainLane,reserve:_nativeParkingAdmission.reservations,admission:_nativeParkingAdmissionTick,free:_civilianTripParkingPoseFree,attach:_civilianTripAttachParking,release:_civilianTripRelease,register:_civilianTripRegister};_nativeParkingAdmission.slots=globalThis.slots;',Object.assign(box,{slots}));
 const goal={id:'shop',r:21,c:21},job=car._civilianNativePlan={status:'ready',laneRequestId:'old-request',parkingSlot:slots[0]},trip={car,npc,carId:car.id,phase,since:0,plan:{native:true,points:[],goal:{door:goal,slot:slots[0]}}};
 box.api.register(trip);box.api.reserve.set(slots[0].id,car);
 return {box,api:box.api,car,npc,other,job,trip,calls,goal};
}

const rows=[];
for(const phase of ['approach','drive']){
 const f=fixture(phase),{api,trip,car,other,goal}=f;
 assert(!api.free(other,slots[0]));assert.equal(api.maintain(trip,10000),false);
 api.admission(10000); // Empty admission queue does not run reservation cleanup.
 const released=api.free(other,slots[0]);
 assert.equal(trip.phase,'planning');assert.equal(trip.destinationDoor,goal);
 assert.equal(car.r,10);assert.equal(car.c,10);assert.equal(car.vr,0);assert.equal(car.vc,0);
 assert.equal(f.npc._civilianTripRiding,phase==='drive');assert.equal(car._civilianNativePlan,undefined);
 const nextJob=car._civilianNativePlan={status:'ready',laneRequestId:'new-request'};
 // A subsequent worker result chooses another bay; exercise actual attachment
 // and release bookkeeping, with clearance controlled at the geometry boundary.
 const next=api.attach(car,goal,{points:[{...slots[1]}],destination:{lotId:'lot'}},nextJob);
 assert(next);assert.equal(next.goal.slot.id,slots[1].id);trip.plan=next;
 api.release(trip,'test-finished');
 rows.push({phase,oldBayFreeAfterExpiry:released,remainingReservations:api.reserve.size});
}

for(const phase of ['board','exit','parked']){
 const f=fixture(phase);assert.equal(f.api.maintain(f.trip,10000),true);assert.equal(f.trip.phase,phase);assert.equal(f.api.reserve.get(slots[0].id),f.car);
}
{
 const f=fixture('drive','ready');assert(f.api.maintain(f.trip,10000));assert.equal(f.api.reserve.get(slots[0].id),f.car);
 f.job.leaseExpired=true;f.api.reserve.set(slots[0].id,f.other);assert(!f.api.maintain(f.trip,15000));assert.equal(f.api.reserve.get(slots[0].id),f.other,'another owner is never cleared');
}
{
 const f=fixture();f.car.r=slots[0].r;f.car.c=slots[0].c;f.api.maintain(f.trip,10000);assert(!f.api.free(f.other,slots[0]),'a physical vehicle still occupies the bay after its reservation expires');
}
const f=fixture(),samples=[];
for(let b=0;b<30;b++){
 const begin=performance.now();
 for(let i=0;i<1000;i++){f.trip.phase='drive';f.car._civilianNativePlan={status:'ready',laneRequestId:'expired',parkingSlot:slots[0],leaseExpired:true};f.api.reserve.set(slots[0].id,f.car);f.api.maintain(f.trip,10000);}
 samples.push((performance.now()-begin)/1000);
}
samples.sort((a,b)=>a-b);
const report={rows,cpu:{p50Ms:samples[15],p95Ms:samples[28]},limits:'Actual source reservation/lease/attachment/release; controlled worker and clearance replies. Geometry, animation, GPU and whole-scene FPS are separate.'};
console.log(JSON.stringify(report,null,2));
assert(rows.every(r=>r.oldBayFreeAfterExpiry&&r.remainingReservations===0),'expired route must not leave an unreachable parking reservation after replanning');
console.log('PASS parking lease cleanup, replacement, foreign ownership, physical occupancy and phase guards');
