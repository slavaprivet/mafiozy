// Read-only replay of coordinator20's DOM observation at source time125260ms.
// Vehicle model/shape and preceding lane rejection were not in that observation.
import fs from 'node:fs';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';
import {createCarWorld,carFits,CAR} from './car_drive.mjs';
import {createNpcVehicleNavigation} from './npc_vehicle_navigation.mjs';
import {createCityRoadNavigation} from './city_road_navigation.mjs';
import {performance} from 'node:perf_hooks';

const observed={atSourceMs:125260,npcId:'resident_2',carId:'local_vehicle_17',phase:'planning',tripAgeMs:52007,from:{r:35.34146341463414,c:42.109756097560975,angle:-Math.PI/2},to:{r:17.44293524101895,c:53.140165315629986,angle:5.890486225480862},goalId:'REBUILD-VISUAL-pine_ridge_cottage_v1-001',doorIndex:4,doors:12,attempt:2,requestAtMs:123087.29999995232,expanded:7,status:'pending',laneRejected:true};
const f=await createCivilianNativeFixture(),M=f.M,world=createCarWorld(f.top,f.bodies,M),isRoad=(x,z)=>!!f.top.roadMask?.[Math.floor(z/M)]?.[Math.floor(x/M)],fits=(x,z,yaw,p)=>carFits(x,z,yaw,world,p);
const building=f.snapshot.buildings.find(b=>b.id===observed.goalId),slot=f.snapshot.parkingPlan.bays.find(b=>Math.hypot(b.x-observed.from.c*M,b.z-observed.from.r*M)<1e-7),rows=[];
const authored=f.actor.profile;
const profiles=[{name:'actual fixture compact sedan (not confirmed LIVE model)',halfLength:authored.collisionHalfLength??authored.halfLength,halfWidth:authored.collisionHalfWidth??authored.halfWidth},{name:'existing default CAR profile (not confirmed LIVE model)',halfLength:CAR.halfLength,halfWidth:CAR.halfWidth}];
for(const profile of profiles){
 const lanes=createCityRoadNavigation({getRoadPlan:()=>f.snapshot.roadPlan,getParkingPlan:()=>f.snapshot.parkingPlan,getInstances:()=>f.snapshot.buildings,isRoad,poseAllowed:fits,metresPerCell:M});
 const nav=createNpcVehicleNavigation({worldScale:M,isRoad,poseAllowed:fits,waterAt:f.waterAt,groundHeight:f.floor,inspectRoutes:true});
 const query={mode:'route',carId:observed.carId,requestId:'trip17-readonly',from:observed.from,to:observed.to,roadsOnly:true,halfLength:profile.halfLength/M,halfWidth:profile.halfWidth/M};
 const begin=performance.now();let result,frames=0;do{nav.beginFrame();result=nav.query(query);frames++;}while(result.status==='pending'&&frames<3000);
 const routeCpuMs=performance.now()-begin;
 const exit=lanes.query({mode:'parking-exit',carId:observed.carId,from:observed.from,profile:{halfLength:profile.halfLength/M,halfWidth:profile.halfWidth/M}});
 const lane=lanes.query({mode:'lane-route',carId:observed.carId,from:observed.from,to:{...building.entry.anchorRC,buildingId:building.id},vehicleProfile:profile});
 rows.push({profile,staticStart:nav.query({...query,mode:undefined,to:query.from,roadsOnly:false}),native:{status:result.status,reason:result.reason,expanded:result.expanded,points:result.points?.length||0,frames,cpuMs:routeCpuMs,diagnostic:nav.diagnostics().routes},parkingExit:{status:exit.status,reason:exit.reason,points:exit.points?.length||0},laneToActualBuilding:{status:lane.status,reason:lane.reason,points:lane.points?.length||0}});
}
const report={observed,currentAttemptAgeMs:observed.atSourceMs-observed.requestAtMs,exactBay:slot?.id,shapeSensitivity:rows,limits:'Exact coordinator-reported from/to, static fixture geometry and two labelled model profiles. LIVE vehicle shape, other cars, preceding lane failure and request timeline are absent; static results do not prove the current LIVE blocker.'};
fs.writeFileSync(new URL('../../../outputs/transport_trip17_23_audit.json',import.meta.url),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
