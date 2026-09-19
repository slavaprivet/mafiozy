import assert from 'node:assert/strict';
import {createNpcVehicleNavigation} from './npc_vehicle_navigation.mjs';
import {collisionPolygon} from './vehicle_collision_shape.mjs';
import {polygonVehicleContact} from './vehicle_contact.mjs';
const rect=(x,z,w,h)=>[[x-w,z-h],[x+w,z-h],[x+w,z+h],[x-w,z+h]];
let solids=[],water=false,vehicles=[];
const nav=createNpcVehicleNavigation({worldScale:1,frameBudgetMs:5,poseAllowed:(x,z,yaw,shape)=>!solids.some(p=>polygonVehicleContact(collisionPolygon(x,z,yaw,shape),p)),isRoad:(x,z)=>Math.abs(z)<12&&Math.abs(x)<30,waterAt:(x,z)=>water&&x>3&&x<5?{level:1}:null,getVehicles:()=>vehicles});
const from={r:0,c:0,angle:0},to={r:0,c:8,angle:0},request={carId:'a',from,to,halfWidth:.3,halfLength:.6,roadsOnly:true};
assert.equal(nav.query(request).clear,true);
solids=[rect(4,0,.01,3)];assert.equal(nav.query(request).clear,false,'thin building blocks swept car');solids=[];
water=true;assert.equal(nav.query(request).reason,'water');water=false;
vehicles=[{id:'b',object:{position:{x:4,y:0,z:0},rotation:{y:0},scale:{x:1,z:1},userData:{vehicleProfile:{halfWidth:.7,halfLength:1.5}}}}];
nav.beginFrame();assert.equal(nav.query(request).reason,'vehicle');vehicles[0].id='a';assert.equal(nav.query(request).clear,true,'own car excluded');vehicles=[];nav.beginFrame();
assert.equal(nav.query({...request,to:{r:40,c:8,angle:0}}).reason,'off-road');
const unloaded=createNpcVehicleNavigation({ready:()=>false,poseAllowed:()=>true});assert.equal(unloaded.query(request),null);
solids=[rect(4,0,.7,2)];let result;
for(let i=0;i<300;i++){nav.beginFrame();result=nav.query({...request,mode:'route',requestId:'detour'});if(result.status!=='pending')break;}
assert.equal(result.status,'ready',JSON.stringify(result));assert.ok(result.points.some(p=>Math.abs(p.r)>2),'route goes around building');
for(let i=1;i<result.points.length;i++)assert.equal(nav.query({...request,from:result.points[i-1],to:result.points[i]}).clear,true,'every route edge physically clear');
// A dynamic blockade added after planning still prevents movement on the stale path.
const p=result.points[2];vehicles=[{id:'b',object:{position:{x:p.c,y:0,z:p.r},rotation:{y:0},userData:{vehicleProfile:{halfWidth:1,halfLength:2}}}}];
nav.beginFrame();assert.equal(nav.query({...request,from:result.points[1],to:p}).clear,false);
console.log('PASS native car sweep, water, solids, own-car exclusion, route detour and post-plan blockade',nav.diagnostics());
