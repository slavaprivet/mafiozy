import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {performance as nodePerformance} from 'node:perf_hooks';

const agenda=fs.readFileSync(new URL('./npc_activity_agenda_source.js',import.meta.url),'utf8');
const trips=fs.readFileSync(new URL('./civilian_parking_trip_source.js',import.meta.url),'utf8');
function setup(){
 let now=1000,cancelled=0;
 const box={Math,Number,Object,Map,WeakMap,Set,Array,String,JSON,
  performance:{now:()=>now},document:{documentElement:{dataset:{}}},location:{search:''},
  CARS:[],NPCS:[],MAP:Array.from({length:30},()=>Array(30).fill(9)),PARKING_LOTS:[],player:{r:25,c:25},myDrivingCarId:null,_parkingNpcs:[],
  _walkRendererActive:()=>true,_walkNpcNavigationResolver:()=>({blocked:false,depth:0,surface:'land'}),_isRespawnableResident:()=>true,
  _threeVehicleEntityId:car=>String(car.id),_threeNpcEntityId:n=>String(n.id),_npcBodyPassable:()=>true,npcPassableForSnitch:()=>true,npcWaypointOk:()=>true,
  _civilianPlanEligible:()=>true,_civilianPlanInterrupted:()=>false,_civilianPlanCancel:n=>{cancelled++;n._civilianPlan=null;},_clearNpcRoute:n=>{n._route=null;},
  _trafficRoadTile:()=>true,_trafficHardTileAt:()=>false,
 };
 vm.createContext(box);vm.runInContext(agenda+'\n'+trips+`;globalThis.api={ensure:_npcAgendaEnsure,wants:_npcAgendaWantsDrive,tryDrive:_npcAgendaTryDrive,nearby:_npcAgendaDriveNearbyCars,schedule:_civilianTripSchedule,release:_civilianTripRelease,tripForNpc:_civilianTripForNpc,tripForCar:_civilianTripForCar,count:_civilianTripCount};`,box);
 return{box,api:box.api,get cancelled(){return cancelled;},setNow:value=>{now=value;}};
}
const resident=id=>({id,hp:100,r:10,c:10,_arcKey:'worker',_civilianPlan:{phase:'seek_shop',cycle:2}});
const car=(id,r,c)=>({id,r,c,ang:0,dirDx:1,dirDy:0,parked:true,model:{L:1.8,W:.88}});
function chooseDrive(api,n){const a=api.ensure(n);a.index=a.queue.indexOf('drive');a.current='drive';a.started=true;return a;}

{
 const h=setup(),n=resident('agenda-driver'),far=car('far',10,18),near=car('near',10,12);h.box.NPCS.push(n);h.box.CARS.push(far,near);const a=chooseDrive(h.api,n);
 assert(h.api.wants(n,1000));assert(h.api.tryDrive(n,1000),'drive activity claims a reachable car');
 const trip=h.api.tripForNpc(n);assert.equal(trip.car,near,'nearest free car wins');assert.equal(h.api.tripForCar(near),trip);assert.equal(trip.agenda,true);assert.equal(h.cancelled,1,'old plan is cancelled only after registry ownership');assert.equal(n._civilianPlan.phase,'walk_to_car');assert.equal(a.current,'drive');
 h.api.release(trip,'arrived');assert.equal(h.api.count(),0);assert.equal(n._civilianTrip,undefined);assert.equal(a.lastResult.reason,'arrived');assert.notEqual(a.current,'drive','release advances the finite agenda');
}
{
 const h=setup(),owner=resident('owner'),waiting=resident('waiting'),only=car('only',10,11);h.box.NPCS.push(owner,waiting);h.box.CARS.push(only);chooseDrive(h.api,owner);chooseDrive(h.api,waiting);
 assert(h.api.tryDrive(owner,1000));const cancelled=h.cancelled;assert.equal(h.api.tryDrive(waiting,1000),false,'the same car cannot be reserved twice');assert.equal(h.cancelled,cancelled,'failed reservation leaves the waiting resident plan intact');assert.equal(waiting._civilianTrip,undefined);
}
{
 const h=setup(),n=resident('large-city-driver');chooseDrive(h.api,n);h.box.NPCS.push(n);for(let i=0;i<160;i++)h.box.CARS.push(car('distant-'+i,25+(i%4),25+Math.floor(i/4)));const nearest=car('near-after-128',10,11);h.box.CARS.push(nearest);
 assert(h.api.tryDrive(n,1000),'spatial cache searches the whole large fleet');assert.equal(h.api.tripForNpc(n).car,nearest,'array order does not hide the nearest car');
}
{
 const h=setup(),drivers=[];for(let i=0;i<5;i++){const n=resident('budget-'+i);n.r=5+i*3;n.c=5;chooseDrive(h.api,n);drivers.push(n);h.box.NPCS.push(n);h.box.CARS.push(car('budget-car-'+i,n.r,n.c+1));}
 assert.deepEqual(drivers.map(n=>h.api.tryDrive(n,1000)),[true,true,true,true,false],'one frame admits at most four agenda drive searches');
}
{
 const h=setup(),shopping=resident('shopping'),driver=resident('driver'),only=car('scheduled',10,11);shopping.r=10;shopping.c=10.5;shopping._npcAgenda={queue:['shop','drive'],index:0,current:'shop',started:true,completed:0,lastResult:null};driver.r=10;driver.c=12;chooseDrive(h.api,driver);h.box.NPCS.push(shopping,driver);h.box.CARS.push(only);
 h.api.schedule(1000);assert.equal(h.api.tripForCar(only)?.npc,driver,'global admission filters by the drive agenda');assert.equal(shopping._civilianTrip,undefined,'shopping resident is not pulled into a car');assert.equal(shopping._npcAgenda.current,'shop');
}

const perf=setup();for(let i=0;i<720;i++)perf.box.CARS.push(car('perf-'+i,2+(i%30)*6,2+Math.floor(i/30)*6));const probe=resident('perf-probe'),samples=[];for(let i=0;i<120;i++){probe.r=5+(i%24)*6;probe.c=5+(i%20)*6;const started=nodePerformance.now();perf.api.nearby(probe,1000+i*501,new Set());samples.push(nodePerformance.now()-started);}samples.sort((a,b)=>a-b);const timing={fleet:720,p50Ms:samples[60],p95Ms:samples[114]};assert(timing.p95Ms<5,'spatial drive lookup stays bounded for a large fleet');
console.log(JSON.stringify({pass:true,checks:['nearest spatial reservation across whole fleet','single car ownership','four drive admissions per frame','mutation after registry success','release advances agenda','global and ambient schedulers preserve active agenda owners'],timing,limits:'CPU adapter lookup only; full-scene FPS and GPU are not measured.'}));
