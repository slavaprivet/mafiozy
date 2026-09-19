import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {createCarWorld,carFits} from './car_drive.mjs';
import {createParkingOriginResolver} from './city_parking_origin.mjs';

const read=path=>JSON.parse(fs.readFileSync(new URL(path,import.meta.url),'utf8'));
const scene=read('../../../outputs/roads_logical_20260912/integration_candidate_snapshot.json'),topology=read('./topology_for_placement.json'),parking=scene.parkingPlan,M=4.1;
const instances=[...scene.buildings,...scene.authoredDecor],bodies=instances.flatMap(i=>i.collision?.worldBodies||[]).concat(scene.decorPlan.colliders,scene.roadPlan.colliders,parking.colliders),world=createCarWorld(topology,bodies,M),profile={halfLength:2.4542,halfWidth:1.152};
const resolver=createParkingOriginResolver({parking,isRoad:(x,z)=>!!topology.roadMask[Math.floor(z/M)]?.[Math.floor(x/M)],poseAllowed:(x,z,yaw,shape)=>carFits(x,z,yaw,world,shape)}),samples=[],rows=[];
for(let round=0;round<6;round++)for(const bay of parking.bays){const start=performance.now(),route=resolver.resolve({from:bay,profile,firstOnly:true})[0],elapsedMs=performance.now()-start;if(round) samples.push(elapsedMs);if(!route)throw Error('No departure: '+bay.id);if(!round)rows.push({bayId:bay.id,points:route.prefix.length,gearChanges:route.gearChanges.length});}
samples.sort((a,b)=>a-b);const pick=q=>samples[Math.min(samples.length-1,Math.floor(samples.length*q))],report={createdAt:new Date().toISOString(),status:'PASS',scope:'CPU actual static city, compact_sedan full rectangle, cached resolver, first safe origin only; no renderer/FPS',lots:parking.lots.length,bays:parking.bays.length,guardedCases:20,profile,query:{count:samples.length,p50Ms:pick(.5),p95Ms:pick(.95),maxMs:samples.at(-1)},prefix:{minPoints:Math.min(...rows.map(r=>r.points)),maxPoints:Math.max(...rows.map(r=>r.points)),maxGearChanges:Math.max(...rows.map(r=>r.gearChanges))},diagnostics:resolver.diagnostics()};
fs.writeFileSync(new URL('../../../outputs/roads_logical_20260912/parking_occupied_departures_audit.json',import.meta.url),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
