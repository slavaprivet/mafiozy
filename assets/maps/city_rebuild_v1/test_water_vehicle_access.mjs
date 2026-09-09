import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createLandscapePlan} from './landscape_plan.mjs';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';
import {planExplorationDecor} from './exploration_decor_plan.mjs';
import {createExplorationVehicleWorld,poseVehicleOnLandscape} from './exploration_vehicle_support.mjs';
import {carFits,carCorners} from './car_drive.mjs';
import {ARTIST_VEHICLE_PROFILES,createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createWaterInteractionInputSampler} from './water_interaction_inputs.mjs';
import {WATER_VEHICLE_ACCESS as A,isWaterVehicleAccess,waterVehicleAccessPoint as point} from './water_vehicle_access.mjs';
const read=n=>JSON.parse(fs.readFileSync(new URL(n,import.meta.url),'utf8'));
const terrain=createLandscapePlan(),topology=read('./topology_for_placement.json');
const plan=planExplorationDecor({terrain,topology,buildings:read('./buildings_placement.v1.json').instances,existingDecor:read('./decor_placement.v1.json').instances,railPlan:createExplorationRailwayPlan({terrain,topology})});
const support={...terrain,canDrive:(x,z)=>terrain.canDrive(x,z)||isWaterVehicleAccess(terrain,x,z)};
const world=createExplorationVehicleWorld({terrain:support,topology,bodies:plan.colliders});
let wet=0,maxSlope=0,maxDepth=0;
for(let d=.05;d<A.length;d+=.25)for(let side=-3.99;side<4;side+=.5){
 const p=point(d,side);assert.equal(isWaterVehicleAccess(terrain,p.x,p.z),true);
 maxSlope=Math.max(maxSlope,terrain.slopeAt(p.x,p.z));maxDepth=Math.max(maxDepth,terrain.waterAt(p.x,p.z)?.depth||0);if(terrain.waterAt(p.x,p.z))wet++;
}
assert.ok(wet>0);assert.ok(maxSlope<=.27);assert.ok(maxDepth<=.45);
for(const p of [point(-1),point(A.length+1),point(12,4.01),{x:867,z:425},{x:400,z:400},{x:NaN,z:0}])assert.equal(isWaterVehicleAccess(terrain,p.x,p.z),false);
const mid=point(20);assert.equal(isWaterVehicleAccess({...terrain,slopeAt:()=>.271},mid.x,mid.z),false);assert.equal(isWaterVehicleAccess({...terrain,waterAt:()=>({depth:.451})},mid.x,mid.z),false);
for(const profile of ARTIST_VEHICLE_PROFILES){
 let last=0;
 // d=2 starts on the road/connector union even for the 10.8 m bus.
 for(let d=2;d<=35.5;d+=.25){const p=point(d);assert.equal(carFits(p.x,p.z,A.yaw,world,profile),true,profile.id+' blocked at '+d);last=d;}
 for(let d=35.75;d<A.length;d+=.25){const p=point(d);if(!carFits(p.x,p.z,A.yaw,world,profile))break;last=d;}
 const p=point(last);assert.ok(carCorners(p.x,p.z,A.yaw,profile).every(([x,z])=>support.canDrive(x,z)),profile.id+' exact corners');
 const front=last+profile.wheelBase/2,contacts=[-.4,.4].map(side=>point(front,profile.width*side));
 assert.ok(contacts.some(p=>terrain.waterAt(p.x,p.z)?.depth>0),profile.id+' front wheels cannot reach water');
 assert.equal(carFits(...Object.values(point(A.length+8)),A.yaw,world,profile),false,'deep/off-corridor end remains forbidden');
}
console.log('PASS shallow access: actual terrain/decor, 12 car footprints reach water, no city/deep/offroad bypass',JSON.stringify({maxSlope,maxDepth,wet}));
const vendor=(process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
class Box extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
const sampler=createWaterInteractionInputSampler({THREE});
for(const id of ['fire_engine','city_bus']){
 const profile=ARTIST_VEHICLE_PROFILES.find(p=>p.id===id),bytes=fs.readFileSync(new URL('./models/artist_vehicle_pack/'+profile.modelFile,import.meta.url));
 const source=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
 const car=createArtistVehicle(THREE,Box,source,profile);let last=2;
 for(let d=2;d<A.length;d+=.05){const p=point(d);if(!carFits(p.x,p.z,A.yaw,world,car.profile))break;last=d;}
 const state={...point(last),yaw:A.yaw,vehicleProfile:car.profile};poseVehicleOnLandscape(THREE,car,state,terrain);
 const input=sampler.sample({records:[{id,car,state}],dt:1/60}).vehicles[0];
 const contacts=input.contactPoints.map(p=>({...p,depth:terrain.waterAt(p.x,p.z)?.depth,clearance:p.y-(terrain.waterAt(p.x,p.z)?.level??-1000)}));
 console.log('Actual posed wheel water contacts',id,last,JSON.stringify(contacts));
 assert.ok(contacts.some(p=>p.depth>0&&p.clearance<=.045),id+' real supported wheel cannot touch water');
 car.dispose?.();
}
console.log('PASS actual GLB fire engine and bus: slope-supported wheel bottoms physically reach shallow water');
