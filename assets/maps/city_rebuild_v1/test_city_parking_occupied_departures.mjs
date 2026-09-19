import assert from 'node:assert/strict';
import fs from 'node:fs';
import {test} from 'node:test';
import {createCarWorld,carFits} from './car_drive.mjs';
import {createParkingOriginResolver} from './city_parking_origin.mjs';
import {collisionPolygon} from './vehicle_collision_shape.mjs';
import {polygonVehicleContact} from './vehicle_contact.mjs';

const read=path=>JSON.parse(fs.readFileSync(new URL(path,import.meta.url),'utf8'));
const scene=read('../../../outputs/roads_logical_20260912/integration_candidate_snapshot.json');
const topology=read('./topology_for_placement.json'),parking=scene.parkingPlan,M=4.1;
const instances=[...scene.buildings,...scene.authoredDecor],bodies=instances.flatMap(i=>i.collision?.worldBodies||[]).concat(scene.decorPlan.colliders,scene.roadPlan.colliders,parking.colliders);
const world=createCarWorld(topology,bodies,M),profile={halfLength:2.4542,halfWidth:1.152};
const resolver=createParkingOriginResolver({parking,isRoad:(x,z)=>!!topology.roadMask[Math.floor(z/M)]?.[Math.floor(x/M)],poseAllowed:(x,z,yaw,shape)=>carFits(x,z,yaw,world,shape)});

function occupiedConflict(lot,self,x,z,yaw){
 const moving=collisionPolygon(x,z,yaw,profile);
 return parking.bays.some(other=>other.lotId===lot.id&&other.id!==self.id&&polygonVehicleContact(moving,collisionPolygon(other.x,other.z,other.yaw,profile)));
}

test('all compact-car bays have a departure and the 20 occupied-neighbour cases keep full hulls apart',()=>{
 let guarded=0;
 for(const bay of parking.bays){
  const lot=parking.lots.find(l=>l.id===bay.lotId),index=lot.bayIds.indexOf(bay.id),mustGuard=lot.bayCount===2&&index===0||lot.bayCount===4&&[0,1,3].includes(index);
  const route=resolver.resolve({from:bay,profile,firstOnly:true})[0];assert(route,bay.id+' must leave the parking');
  assert(route.prefix.length>2);assert(!occupiedConflict(lot,bay,bay.x,bay.z,bay.yaw));
  if(!mustGuard)continue;guarded++;
  for(let i=0;i<route.prefix.length;i++){
   const b=route.prefix[i],a=route.prefix[Math.max(0,i-1)],distance=Math.hypot(b.x-a.x,b.z-a.z),dyaw=Math.atan2(Math.sin(b.yaw-a.yaw),Math.cos(b.yaw-a.yaw)),steps=Math.max(1,Math.ceil(distance/.05),Math.ceil(Math.abs(dyaw)/(.5*Math.PI/180)));
   for(let j=0;j<=steps;j++){const t=j/steps;assert.equal(occupiedConflict(lot,bay,a.x+(b.x-a.x)*t,a.z+(b.z-a.z)*t,a.yaw+dyaw*t),false,bay.id+' intersects an occupied bay');}
  }
 }
 assert.equal(parking.bays.length,59);assert.equal(guarded,20);
});
