import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {createNpcVehicleAccessResolver} from './npc_vehicle_access.mjs';
import {createNpcNativeNavigation} from './npc_native_navigation.mjs';
const source=fs.readFileSync(new URL('./civilian_parking_trip_source.js',import.meta.url),'utf8');
const calls=[],actor={object:{parent:{},position:{x:41,y:0,z:41},rotation:{y:Math.PI/2},scale:{x:1,y:1,z:1}},seats:[{id:'front_left',side:1,doorDistance:1.57,doorFront:.6,anchor:{side:.4,y:.1,front:.4}}]};
const access=createNpcVehicleAccessResolver({traffic:{getActor:id=>id==='car1'?actor:null,setNpcAccess:(...args)=>calls.push(args)}});
assert.equal(access({carId:'missing'}),null,'unloaded native car defers instead of guessed door');
const exact=access({carId:'car1'});assert(Math.abs(exact.outside.r-(41-1.57)/4.1)<1e-12);assert(Math.abs(exact.outside.c-(41+.6)/4.1)<1e-12);
assert.equal(access({carId:'car1'}),exact,'access coordinates reuse owned record');
access({carId:'car1',phase:'board',progress:.5});assert.deepEqual(calls.at(-1),['car1','board',.5,'front_left']);

let other=false;const nav=createNpcNativeNavigation({containsBody:()=>false,blocksDynamic:(x,z,{ignoreId})=>other||ignoreId!=='car1'});
assert(nav.query({r:1,c:1}).blocked);assert(!nav.query({r:1,c:1,ignoreVehicleId:'car1'}).blocked);assert(nav.query({r:1,c:1,ignoreVehicleId:'other'}).blocked,'separate cache key cannot leak one-car exception');
other=true;nav.beginFrame();assert(nav.query({r:1,c:1,ignoreVehicleId:'car1'}).blocked,'other vehicles remain solid');

const car={r:10,c:10,ang:0,parked:true,model:{L:1.8,W:.88}},npc={id:'source-resident',r:9.6,c:10},MAP=Array.from({length:30},()=>Array(30).fill(9));let now=0,blocked=false,water=false,probes=0;
const outside={r:9.6,c:10},seat={r:9.9,c:10},box={MAP,CARS:[car],NPCS:[npc],PARKING_LOTS:[],player:{r:29,c:29},myDrivingCarId:null,performance:{now:()=>now},document:{documentElement:{dataset:{}}},_threeVehicleEntityId:()=> 'car1',_threeNpcEntityId:n=>String(n.id),_trafficRoadTile:()=>false,_trafficHardTileAt:()=>false,_civilianPlanInterrupted:()=>false,_clearNpcRoute:()=>{},npcWaypointOk:()=>true,_npcPathPassable:()=>false,_civilianRouteTo:()=>false,_npcEffectiveSpeed:()=>.4,_npcAdvanceRoute:()=> 'arrived',_walkNpcNavigationResolver:({ignoreVehicleId})=>{probes++;return {blocked:blocked||ignoreVehicleId!=='car1',depth:water?1:0}}};
vm.createContext(box);vm.runInContext(source+`;globalThis.api={access(fn){_walkNpcVehicleAccessResolver=fn},set(t){_civilianTrip=t;t.npc._civilianTrip=true},tick:_civilianTripTickNpc,exit:_civilianTripExit,path:_civilianTripDoorPath,clear:_civilianTripPoseClear,trip(){return _civilianTrip}}`,box);
const api=box.api;api.access(()=>({outside,seat}));const trip={car,npc,carId:'car1',phase:'approach',door:outside,index:0,plan:{goal:{door:{r:9,c:10}},lots:[]}};api.set(trip);api.tick(npc,.05,now);assert.equal(trip.phase,'board');
blocked=true;for(let i=0;i<10;i++){now+=50;api.tick(npc,.05,now);}assert.equal(npc.r,outside.r,'new obstruction stops transition');
blocked=false;water=true;api.tick(npc,.05,now);assert.equal(npc.r,outside.r,'water is never bypassed by own-car ignore');water=false;
let steps=0,maxProbes=0;for(;steps<100&&trip.phase==='board';steps++){probes=0;now+=50;const prior=npc.r;api.tick(npc,5,now);assert(Math.abs(npc.r-prior)<=.070001,'long frame remains bounded');maxProbes=Math.max(maxProbes,probes);}
assert.equal(trip.phase,'drive');assert.equal(npc.r,seat.r);assert(npc._civilianTripRiding);assert(maxProbes<=5,'single capped door step costs at most five terrain probes');
blocked=true;assert(!api.exit(trip));assert.equal(trip.phase,'drive','passenger stays seated when exit blocked');blocked=false;assert(api.exit(trip));
for(let i=0;i<100&&api.trip();i++){now+=50;api.tick(npc,.05,now);}assert.equal(api.trip(),null);assert.equal(npc.r,outside.r,'continuous same-door exit ends outside');assert.equal(box.NPCS[0],npc);assert.equal(box.CARS[0],car);
const lot={r0:0,c0:0,r1:30,c1:30};blocked=true;assert(!api.clear(car,10,10,0,[lot],true),'source-owned driving also checks actual native solids');blocked=false;water=true;assert(!api.clear(car,10,10,0,[lot],true),'source-owned driver cannot drive into native water');
console.log('PASS authored driver door/seat, reusable anchors, scoped collider exclusion/cache, bounded entry/exit, blocked door/water, native driving guard; max door probes '+maxProbes);
