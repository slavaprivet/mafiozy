import fs from 'node:fs';import vm from 'node:vm';import {performance} from 'node:perf_hooks';
import {createNpcNativeNavigation} from './npc_native_navigation.mjs';
const source=fs.readFileSync(process.argv[2]||new URL('./civilian_parking_trip_source.js',import.meta.url),'utf8');
const nav=createNpcNativeNavigation({groundHeight:()=>0,waterAt:()=>null,containsBody:()=>false,blocksDynamic:()=>false});
const car={r:6,c:6,ang:0,model:{L:1.8,W:.88},parked:false},npc={r:6,c:6,id:'existing'},lot={r0:0,c0:0,r1:30,c1:30},trip={car,npc,carId:'car1',phase:'drive',index:0,plan:{lots:[lot],points:[{r:6,c:8,angle:0}]}};
const box={MAP:Array.from({length:30},()=>Array(30).fill(9)),CARS:[car],NPCS:[npc],player:{r:28,c:28},myDrivingCarId:null,performance,document:{documentElement:{dataset:{}}},_threeVehicleEntityId:()=> 'car1',_trafficRoadTile:()=>false,_trafficHardTileAt:()=>false,_walkNpcNavigationResolver:nav.query,_npcPathPassable:()=>true,npcWaypointOk:()=>true,_civilianPlanInterrupted:()=>false,_clearNpcRoute:()=>{},_civilianRouteTo:()=>false};
vm.createContext(box);vm.runInContext(source+`;globalThis.set=t=>_civilianTrip=t;globalThis.tick=_civilianTripTickCar;`,box);box.set(trip);
const windows=[];for(let window=0;window<140;window++){const start=performance.now();for(let i=0;i<200;i++){nav.beginFrame();car.r=6;car.c=6;box.tick(car,.05);}if(window>=20)windows.push((performance.now()-start)/200);}
windows.sort((a,b)=>a-b);console.log(JSON.stringify({scenario:'One source civilian driver, 200 updates/window, 20 warmup + 120 measured windows, static flat native scene; not renderer FPS',p50Ms:windows[60],p95Ms:windows[114],nativeQueries:nav.diagnostics().queries,updates:28000}));
