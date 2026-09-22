import fs from 'node:fs';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';
import {createParkingOriginResolver} from './city_parking_origin.mjs';
import {createCarWorld,carFits} from './car_drive.mjs';

const f=await createCivilianNativeFixture(),M=f.M,parking=f.snapshot.parkingPlan;
// Exact public vehicle diagnostic captured by coordinator20 in the game.
const recorded={r:14.776657476657771,c:153.6783536585366,angle:3.60913887831611};
const from={x:recorded.c*M,z:recorded.r*M,yaw:Math.PI/2-recorded.angle};
const profile={halfLength:2.449160099029541,halfWidth:1.1009299904108047,collisionPadding:.08};
const exit=parking.access.routes.find(r=>r.id==='parking:REBUILD-VISUAL-garden_lane_house_v1-001:exit:1');
const index=exit.points.findIndex(p=>Math.hypot(p.x-from.x,p.z-from.z)<1e-7);assert(index>0&&index<exit.points.length-1);
const world=createCarWorld(f.top,f.bodies,M),isRoad=(x,z)=>!!f.top.roadMask?.[Math.floor(z/M)]?.[Math.floor(x/M)];
const fits=(x,z,yaw,shape)=>carFits(x,z,yaw,world,shape);
let barrier=false;
const barrierWorld=createCarWorld({grid:[]},[{minYM:0,maxYM:3,polygonCR:[[633.7/M,57/M],[633.8/M,57/M],[633.8/M,67/M],[633.7/M,67/M]]}],M,{surfaceAt:()=>true});
const resolver=createParkingOriginResolver({parking,isRoad,poseAllowed:(x,z,yaw,shape)=>fits(x,z,yaw,shape)&&(!barrier||carFits(x,z,yaw,barrierWorld,shape))});
function verify(origin){
 const begin=performance.now(),routes=resolver.resolve({from:origin,profile,firstOnly:true}),elapsedMs=performance.now()-begin;
 assert(routes.length,'exact observed in-progress reverse exit must resume from its current pose');
 const route=routes[0];assert.equal(route.accessRouteId,exit.id);assert.equal(route.prefix[0].x,origin.x);assert.equal(route.prefix[0].z,origin.z);assert.equal(route.prefix[0].yaw,origin.yaw);
 assert(route.prefix.length<=exit.points.length);assert(route.prefix.every(p=>p.gear==='reverse'));
 assert.deepEqual(route.point,exit.points.at(-1));
 for(let i=1;i<route.prefix.length;i++){
  const a=route.prefix[i-1],b=route.prefix[i],dyaw=Math.atan2(Math.sin(b.yaw-a.yaw),Math.cos(b.yaw-a.yaw)),d=Math.hypot(b.x-a.x,b.z-a.z),steps=Math.max(1,Math.ceil(d/.04));
  if(d)assert(((b.x-a.x)*Math.sin(a.yaw+dyaw/2)+(b.z-a.z)*Math.cos(a.yaw+dyaw/2))/d<-.998,'motion is reverse along the body heading');
  for(let j=0;j<=steps;j++)assert(fits(a.x+(b.x-a.x)*j/steps,a.z+(b.z-a.z)*j/steps,a.yaw+dyaw*j/steps,profile),'actual full hull stays clear');
 }
 return {points:route.prefix.length,elapsedMs};
}
const exact=verify(from),a=exit.points[index],b=exit.points[index+1],mid={x:a.x+(b.x-a.x)*.37,z:a.z+(b.z-a.z)*.37,yaw:a.yaw+(b.yaw-a.yaw)*.37},interpolated=verify(mid);
const beginning=verify(exit.points[0]),lot=parking.lots.find(l=>l.id===exit.lotId);
const lastInside=exit.points.findLastIndex(p=>p.x>=lot.rect.minX&&p.x<=lot.rect.maxX&&p.z>=lot.rect.minZ&&p.z<=lot.rect.maxZ);
const nearEnd=verify(exit.points[lastInside]);
const end=exit.points.at(-1),finished=resolver.resolve({from:end,profile});assert.equal(finished.length,1);assert.deepEqual(finished[0],{point:end,prefix:[]},'finished exit continues from the road without a parking prefix');
barrier=true;assert.equal(resolver.resolve({from,profile}).length,0,'a new barrier across the remaining exit is never bypassed');barrier=false;
assert.equal(resolver.resolve({from:{...from,yaw:from.yaw+.25},profile}).length,0,'a different body heading cannot be snapped onto the old exit');
assert.equal(resolver.resolve({from:{...from,z:from.z+.3},profile}).length,0,'an unrelated position cannot be snapped sideways onto the exit');
const costs=[];for(let i=0;i<40;i++){const begin=performance.now();resolver.resolve({from,profile,firstOnly:true});costs.push(performance.now()-begin);}costs.sort((a,b)=>a-b);
const report={pass:true,recorded,authoredExit:exit.id,pointIndex:index,exact,interpolated,beginning,nearEnd,finishedExit:true,warmCpu:{p50Ms:costs[20],p95Ms:costs[38]},limits:'Exact recorded pose and hull against static city geometry; observed actor and dynamic scene not replayed. No LIVE/GPU/FPS claim.'};
const baselinePath=process.argv.find(a=>a.startsWith('--baseline='))?.slice(11);
if(baselinePath){
 const baselineCode=fs.readFileSync(baselinePath,'utf8').replace(/from '(\.\/[^']+)'/g,(_,path)=>'from '+JSON.stringify(new URL(path,import.meta.url).href));
 const baseline=await import('data:text/javascript,'+encodeURIComponent(baselineCode));
 const prior=baseline.createParkingOriginResolver({parking,isRoad,poseAllowed:fits}),before=[];
 for(let i=0;i<40;i++){const begin=performance.now(),routes=prior.resolve({from,profile,firstOnly:true});before.push(performance.now()-begin);assert.equal(routes.length,0);}
 before.sort((a,b)=>a-b);report.beforeCpu={p50Ms:before[20],p95Ms:before[38]};
 const comparable={before:[],after:[]};
 for(let i=0;i<40;i++)for(const [name,r]of [['before',prior],['after',resolver]]){const begin=performance.now();assert(r.resolve({from:exit.points[0],profile,firstOnly:true}).length);comparable[name].push(performance.now()-begin);}
 report.successfulBayDepartureCpu={};for(const [name,times]of Object.entries(comparable)){times.sort((a,b)=>a-b);report.successfulBayDepartureCpu[name]={p50Ms:times[20],p95Ms:times[38]};}
}
fs.writeFileSync(new URL('../../../outputs/parking_exit_resume23.json',import.meta.url),JSON.stringify(report,null,2));console.log(report);
