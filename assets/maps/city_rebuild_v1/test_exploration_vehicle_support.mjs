import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createCarWorld,carFits} from './car_drive.mjs';
import {createExplorationVehicleWorld,sampleVehicleGround,poseVehicleOnLandscape} from './exploration_vehicle_support.mjs';
const THREE=await import(pathToFileURL((process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const topology={grid:Array.from({length:20},()=>Array(20).fill(8)),policeMask:Array.from({length:20},()=>Array(20).fill(false))};topology.grid[5][5]=16;topology.policeMask[3][3]=true;
const terrain={contains:(x,z)=>x<0,groundHeight:(x,z)=>-x*.15+z*.04,canDrive:(x,z)=>x<0&&z>5&&z<30};
const world=createExplorationVehicleWorld({topology,bodies:[],terrain}),old=createCarWorld(topology,[],4.1);
for(let z=4;z<78;z+=2)for(let x=4;x<78;x+=2){assert.equal(world(x,z),old(x,z));assert.equal(carFits(x,z,.6,world),carFits(x,z,.6,old));}
assert.equal(carFits(-10,15,0,world),true);assert.equal(carFits(-10,3,0,world),false);
const obstacle={polygonCR:[[-11/4.1,14/4.1],[-9/4.1,14/4.1],[-9/4.1,16/4.1],[-11/4.1,16/4.1]],minYM:2.1,maxYM:5};
const blocked=createExplorationVehicleWorld({topology,bodies:[obstacle],terrain});assert.equal(carFits(-10,15,0,blocked),false,'elevated tree collider must not be discarded by flat car height filter');
for(const yaw of [0,.7,2,3.5]){
 const state={x:-40,z:18,yaw},sample=sampleVehicleGround(THREE,state,terrain),car={object:new THREE.Group()};
 poseVehicleOnLandscape(THREE,car,state,terrain);
 assert.ok(car.object.position.y>6,'car must be on raised terrain');
 const up=new THREE.Vector3(0,1,0).applyQuaternion(car.object.quaternion);assert.ok(up.distanceTo(sample.normal)<1e-6);
 for(const side of [-.96,.96])for(const front of [-1.35,1.3]){const wheel=new THREE.Vector3(side,0,front).applyMatrix4(car.object.matrixWorld);assert.ok(Math.abs(wheel.y-terrain.groundHeight(wheel.x,wheel.z))<1e-6,'wheel contacts follow inclined plane');}
 poseVehicleOnLandscape(THREE,car,state,terrain,Math.PI);assert.ok(car.object.position.y>=sample.y+2.15,'existing overturn lift survives terrain support');
 poseVehicleOnLandscape(THREE,car,{x:40,z:40,yaw},terrain,0);assert.equal(car.object.position.y,0);assert.ok(new THREE.Vector3(0,1,0).applyQuaternion(car.object.quaternion).distanceTo(new THREE.Vector3(0,1,0))<1e-6,'return to flat city resets grade');
}
console.log('PASS exploration vehicle support: native world preserved, paths admission, hillside obstacles, wheels on slopes, rollover and return to city');
