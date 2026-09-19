import assert from 'node:assert/strict';import {createNpcVehicleNavigation} from './npc_vehicle_navigation.mjs';
const make=opts=>createNpcVehicleNavigation({worldScale:1,frameBudgetMs:20,poseAllowed:()=>true,isRoad:()=>true,...opts}),nav=make();
const targets=q=>{let result;for(let i=0;i<100;i++){nav.beginFrame();result=nav.query({mode:'road-targets',carId:'city_bus',from:{r:0,c:0,angle:0},...q});if(result.status==='ready')break;}return result.points;};
assert(targets({minDistance:3,maxDistance:3}).every(p=>Math.abs(Math.hypot(p.r,p.c)-3)<1e-8));assert(targets({minDistance:0,maxDistance:0}).every(p=>p.r===0&&p.c===0),'zero radius honored and cannot reuse cached radius3 targets');
const route=(n,q)=>{let out;for(let i=0;i<100;i++){n.beginFrame();out=n.query({mode:'route',requestId:'same',carId:'a',roadsOnly:true,...q});if(out.status!=='pending')return out;}return out;};
const to={r:0,c:2,angle:0};assert.equal(route(nav,{from:{r:0,c:0,angle:0},to}).status,'ready');const moved=route(nav,{from:{r:0,c:1,angle:0},to});assert.equal(moved.points[0].c,1,'same requestId with changed origin never returns old route');
for(const id of ['service_police_1','city_bus']){const object={position:{x:0,y:0,z:0},rotation:{y:0},scale:{x:1,z:1},userData:{vehicleProfile:{halfWidth:.5,halfLength:1}}},n=make({getVehicles:()=>[{id,object}]});const p={r:0,c:0,angle:0};assert(n.query({carId:id,from:p,to:p}).clear,'own exact service/bus ID ignored');assert(!n.query({carId:'different',from:p,to:p}).clear,'other source vehicle blocks');assert.equal(route(n,{carId:id,from:p,to:p}).status,'ready');assert.equal(route(n,{carId:'different',from:p,to:p}).status,'blocked','route cache isolates carId even when requestId and poses match');}
console.log('PASS native cache: origin/car identity/radius0, exact service_/city_bus dynamic own-car exclusion');
let ticks=0;const crowded=make({frameBudgetMs:.1,clock:()=>++ticks});
const pendingRequest=i=>({mode:'route',requestId:'pending'+i,carId:'fleet'+i,from:{r:0,c:0,angle:0},to:{r:0,c:50,angle:0}});
crowded.beginFrame();for(let i=0;i<64;i++)assert.equal(crowded.query(pendingRequest(i)).status,'pending');
assert.equal(crowded.query(pendingRequest(64)).reason,'route-capacity');
assert(crowded.diagnostics().routes.some(j=>j.carId==='fleet0'),'New ambient jobs cannot evict an in-progress convoy');
crowded.query(pendingRequest(0));for(let i=0;i<32;i++)crowded.beginFrame();
assert.notEqual(crowded.query(pendingRequest(64)).reason,'route-capacity','Abandoned requests eventually release bounded cache capacity');
console.log('PASS route pressure: active searches survive new requests; abandoned searches expire');
