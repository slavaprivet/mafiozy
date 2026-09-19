import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const trip=fs.readFileSync(new URL('./civilian_parking_trip_source.js',import.meta.url),'utf8');
const source=fs.readFileSync(new URL('./ambient_traffic_driver_source.js',import.meta.url),'utf8');
let now=1000;
const cars=Array.from({length:3},(_,i)=>({id:`car${i}`,r:10+i*3,c:10,ang:0,vr:0,vc:1.6,model:{L:1.8,W:.88}}));
const npcs=cars.map((car,i)=>({id:`resident${i}`,r:car.r-.7,c:car.c,hp:100,speed:.4,walkPhase:0}));
const activeShopper={id:'active-shopper',r:cars[0].r-.45,c:cars[0].c,hp:100,speed:.4,walkPhase:0,_npcAgenda:{current:'shop',started:true}};
const box={
  console,Math,Number,Array,Map,Set,performance:{now:()=>now},prevT:0,
  MAP:Array.from({length:40},()=>Array(40).fill(9)),CARS:cars,NPCS:[activeShopper,...npcs],player:{r:0,c:0},
  myDrivingCarId:null,_parkingNpcs:[],document:{documentElement:{dataset:{}}},window:{},
  _walkRendererActive:()=>true,_threeVehicleEntityId:c=>c.id,_threeNpcEntityId:n=>n.id,
  _civilianPlanEligible:n=>!n.dead&&!n._ambientTrafficDriver,_civilianPlanInterrupted:()=>false,
  _clearNpcRoute:n=>{n._route=null;n._routeIndex=0;},_npcEffectiveSpeed:()=>.4,
  npcPassableForSnitch:()=>true,_npcPathPassable:()=>true,_walkNpcNavigationResolver:()=>({blocked:false,depth:0}),
  _planNpcRouteTo:(n,r,c)=>{n._route=[{r,c}];return true;},_assignCarGoal:()=>{},
  _walkTrafficNavigationResolver:q=>q.mode==='driver'?{ready:true}:{clear:true},
  _walkNpcVehicleAccessResolver:({carId})=>{const car=cars.find(c=>c.id===carId);return car?{outside:{r:car.r-.4,c:car.c},seat:{r:car.r,c:car.c}}:null},
};
vm.createContext(box);
vm.runInContext(trip+'\n'+source+'\nglobalThis.api={assign:_ambientTrafficAssign,drivers:_ambientTrafficDrivers};',box);

const before=npcs.map(n=>({r:n.r,c:n.c}));
box.api.assign(now);
assert.equal(box.api.drivers.size,2,'one bounded pass admits two nearby real drivers');
assert(![...box.api.drivers.values()].some(t=>t.npc===activeShopper),'ambient admission cannot pull a resident out of an active shop agenda');
for(let i=0;i<npcs.length;i++)assert.deepEqual({r:npcs[i].r,c:npcs[i].c},before[i],'admission never teleports a resident');
assert.deepEqual(JSON.parse(box.document.documentElement.dataset.ambientTrafficDrivers).phases,{approach:2,board:0,drive:0});
box.api.assign(now+=349);assert.equal(box.api.drivers.size,2,'interval bounds repeated scans');
box.api.assign(now+=1);assert.equal(box.api.drivers.size,3,'next bounded pass admits the remaining driver');
assert.equal(new Set([...box.api.drivers.values()].map(t=>t.npc.id)).size,3,'every car keeps a distinct existing resident');
console.log('PASS ambient traffic batch admission: 2 per 350ms, distinct live residents, no teleport, phase telemetry');
