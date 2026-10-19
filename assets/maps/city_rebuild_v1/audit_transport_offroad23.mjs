// Read-only replay of a bounded real browser route request against the static
// actual-city fixture. The export has no other-car poses or preceding lane job.
import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';
import {createNpcVehicleNavigation} from './npc_vehicle_navigation.mjs';
import {createCarWorld,carFits} from './car_drive.mjs';

const evidence=JSON.parse(fs.readFileSync(new URL('../../../.git/ai-pipeline-local/live23/transport-before23.json',import.meta.url)));
const recorded=evidence.npcTransport.routes.find(r=>r.carId==='local_vehicle_18');
if(!recorded)throw new Error('Recorded vehicle_18 request missing');
const f=await createCivilianNativeFixture(),M=f.M,world=createCarWorld(f.top,f.bodies,M);
const isRoad=(x,z)=>!!f.top.roadMask?.[Math.floor(z/M)]?.[Math.floor(x/M)];
const nav=createNpcVehicleNavigation({worldScale:M,isRoad,poseAllowed:(x,z,yaw,shape)=>carFits(x,z,yaw,world,shape),waterAt:f.waterAt,groundHeight:f.floor,inspectRoutes:true});
const request={mode:'route',requestId:'actual-export23',carId:recorded.carId,from:recorded.from,to:recorded.to,roadsOnly:true,halfLength:recorded.shape.halfLength/M,halfWidth:recorded.shape.halfWidth/M};
const samples=[];let result,frames=0;
for(;frames<10000;frames++){nav.beginFrame();const start=performance.now();result=nav.query(request);samples.push(performance.now()-start);if(result.status!=='pending')break;}
const x=recorded.from.c*M,z=recorded.from.r*M,nearest=f.snapshot.parkingPlan.bays.map(b=>({id:b.id,lotId:b.lotId,distanceM:Math.hypot(b.x-x,b.z-z),angle:Math.PI/2-b.yaw})).sort((a,b)=>a.distanceM-b.distanceM).slice(0,3);
const origin=f.lanes.query({mode:'parking-exit',carId:recorded.carId,from:recorded.from,profile:{halfLength:recorded.shape.halfLength/M,halfWidth:recorded.shape.halfWidth/M}});
const lane=f.lanes.query({mode:'lane-route',carId:recorded.carId,from:recorded.from,to:recorded.to,vehicleProfile:recorded.shape});
samples.sort((a,b)=>a-b);
const report={capturedAt:evidence.at,recorded,nearestBays:nearest,staticPose:nav.query({...request,mode:undefined,to:request.from,roadsOnly:false}),nativeReplay:{...result,points:result.points?.length||0,frames:frames+1,diagnostics:nav.diagnostics(),cost:{p50Ms:samples[Math.floor(samples.length*.5)],p95Ms:samples[Math.floor(samples.length*.95)]}},parkingExit:{status:origin.status,reason:origin.reason,points:origin.points?.length||0},laneToRecordedRoadTarget:{status:lane.status,reason:lane.reason,points:lane.points?.length||0},limits:'Recorded exact from/to and hull, static actual-city fixture snapshot; no complete LIVE geometry or dynamic actors, no actual preceding lane destination/failure. Does not establish all causes of the observed failure.'};
fs.writeFileSync(new URL('../../../outputs/transport_offroad23_audit.json',import.meta.url),JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
