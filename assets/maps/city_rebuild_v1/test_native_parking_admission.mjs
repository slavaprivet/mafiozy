import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
const source=fs.readFileSync(new URL('civilian_parking_trip_source.js',import.meta.url),'utf8');
let now=0,queries=0;
const slots=Array.from({length:59},(_,i)=>({id:'bay_'+i,lotId:'lot_'+i,r:10+Math.floor(i/10)*5,c:10+i%10*5,angle:i%2?Math.PI/2:0,widthM:3,lengthM:6}));
const cars=[],ctx={console,Math,Number,Array,Map,Set,WeakMap,performance:{now:()=>now},prevT:0,CARS:cars,NPCS:[],myDrivingCarId:null,_walkRendererActive:()=>true,_threeVehicleEntityId:c=>c.id,_npcVehicleOccupants:new WeakMap(),document:{documentElement:{dataset:{}}},window:{},_walkTrafficNavigationResolver:q=>q.mode==='parking-anchors'?{ready:true,slots}:q.mode==='initial-vehicle-shape'?{ready:true,halfLength:.6,halfWidth:.28}:q.mode==='parking-exit'?{ready:true,status:'ready',points:[q.from]}:(queries++,{clear:q.from.c!==10,reason:q.from.c===10?'solid-or-surface':undefined})};
vm.createContext(ctx);vm.runInContext(source,ctx);
const add=(id,extra={})=>{const c={id,r:100,c:100,ang:0,parked:true,hp:123,model:{name:'sedan'},...extra};cars.push(c);return c;};
const visible=add('visible',{_nativeParkingPresented:true});ctx._nativeParkingPrepare(visible);assert(!visible._nativeParkingPending,'presented cars never queued');
const occupied=add('occupied');ctx._npcVehicleOccupants.set(occupied,{id:'dead-driver',hp:0});ctx._nativeParkingPrepare(occupied);
const owned=add('owned',{owner_uid:17});ctx._nativeParkingPrepare(owned);
const regular=Array.from({length:20},(_,i)=>ctx._nativeParkingPrepare(add('car_'+i)));
const timings=[];
for(let frame=0;frame<180;frame++){now+=16.667;const q=queries,t=performance.now();ctx._nativeParkingAdmissionTick(now);timings.push(performance.now()-t);assert(queries-q<=2,'bounded geometry queries');}
assert.equal(regular.filter(c=>!c._nativeParkingPending).length,20);
assert.equal(new Set(regular.map(c=>c._nativeParkingAnchor.id)).size,20,'unique reservations');
for(const c of [visible,occupied,owned])assert.deepEqual([c.r,c.c,c.hp],[100,100,123],'visible/occupied/owned actor is never relocated');
for(const c of regular){assert.equal(c.hp,123);assert.equal(c.id.startsWith('car_'),true);assert(c.c!==10,'blocked bay never admitted');}
const before=regular.map(c=>[c.r,c.c]);regular.forEach(c=>c._nativeParkingPresented=true);for(const c of regular)ctx._nativeParkingPrepare(c);now+=20000;ctx._nativeParkingAdmissionTick(now);assert.deepEqual(regular.map(c=>[c.r,c.c]),before,'repeat admission cannot move an actor');
const first=regular[0],anchor=first._nativeParkingAnchor;first.parked=false;first.r+=10;const next=ctx._nativeParkingPrepare(add('replacement'));for(let i=0;i<100&&next._nativeParkingPending;i++){now+=50;ctx._nativeParkingAdmissionTick(now);}assert(!next._nativeParkingPending);
timings.sort((a,b)=>a-b);const report={pass:true,cars:20,uniqueBays:20,geometryQueries:queries,p50Ms:timings[Math.floor(timings.length*.5)],p95Ms:timings[Math.floor(timings.length*.95)],maxMs:timings.at(-1),limits:'Actual source admission, controlled geometry response. Full native geometry chain is separate. No FPS or GPU claim.'};fs.writeFileSync(new URL('../../../outputs/native_parking_admission_20260919.json',import.meta.url),JSON.stringify(report,null,2));console.log(report);
