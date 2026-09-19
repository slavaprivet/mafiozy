import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {setup} from './test_ambulance_transport.mjs';
import {createNpcVehicleNavigation} from './npc_vehicle_navigation.mjs';
import {collisionPolygon} from './vehicle_collision_shape.mjs';
import {polygonVehicleContact} from './vehicle_contact.mjs';
const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
const start=source.indexOf('function _vehicleStep('),end=source.indexOf('\nfunction ',start+10);
const {s,v}=setup();
Object.assign(s,{SERVICE_TURN_KINDS:new Set(),_serviceVehicleFootprintCapabilities:()=>[],_syncServiceVehicleCargo:()=>{}});
vm.runInContext(source.slice(start,end),s);
let water=false,nearSolid=false,otherCar=false;
const rect=(x,z,w,h)=>[[x-w,z-h],[x+w,z-h],[x+w,z+h],[x-w,z+h]];
const solids=Array.from({length:357},(_,i)=>rect(30+i%21*7,60+Math.floor(i/21)*8,2,2));
const car={id:'other',object:{position:{x:43.2,y:0,z:41},rotation:{y:0},userData:{vehicleProfile:{halfWidth:1,halfLength:2}}}};
const native=createNpcVehicleNavigation({worldScale:4.1,
  poseAllowed:(x,z,yaw,shape)=>{const poly=collisionPolygon(x,z,yaw,shape);return !(nearSolid&&polygonVehicleContact(poly,rect(43.2,41,.02,3)))&&!solids.some(p=>polygonVehicleContact(poly,p));},
  waterAt:(x,z)=>water&&x>42?{level:1}:null,isRoad:()=>true,getVehicles:()=>otherCar?[car]:[]});
s._walkTrafficNavigationResolver=native.query;
v.path=[{r:10,c:20}];v.finalTarget={y:10,x:20};
for(const kind of ['solid','water','car']){
  nearSolid=kind==='solid';water=kind==='water';otherCar=kind==='car';native.beginFrame();
  const before=[v.x,v.y,v.ang];s._ambulanceVehicleStep(v,.016);
  assert.deepEqual([v.x,v.y,v.ang],before,`production native ${kind} blocks source mover`);
}
nearSolid=false;water=false;otherCar=false;native.beginFrame();
const run=method=>{
  const times=[];
  for(let sample=0;sample<45;sample++){
    const t=performance.now();
    for(let i=0;i<40;i++){
      v.x=10;v.y=10;v.ang=0;v.speed=2;v.path=[{r:10,c:20}];v.pathIdx=0;
      native.beginFrame();s[method](v,.016);
    }
    if(sample>=10)times.push((performance.now()-t)/40);
  }
  times.sort((a,b)=>a-b);return {p50:times[17],p95:times[33]};
};
const before=run('_vehicleStep'),after=run('_ambulanceVehicleStep');
console.log(JSON.stringify({scenario:'source ambulance update; 357 fixed polygon fixtures, no GPU; legacy mover before vs actual native sweep after',before,after,native:native.diagnostics()}));
console.log('PASS actual native solids/water/vehicle ambulance source movement');
