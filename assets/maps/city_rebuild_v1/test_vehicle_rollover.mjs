import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createVehicleRollover} from './vehicle_rollover.mjs';
import {polygonVehicleContact,contactKinematics} from './vehicle_contact.mjs';
const T=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const car={object:new T.Group()},roll=createVehicleRollover(T,car),contact={normal:{x:1,y:0,z:0},impactSpeed:3};
roll.impact(contact);for(let i=0;i<600;i++)roll.update(1/60);assert(Math.abs(roll.stats().angle)<.01,'minor contact returns upright');
const runs=[];for(const hz of [30,60,120]){roll.reset();roll.impact({...contact,impactSpeed:16});for(let i=0;i<hz*8;i++)roll.update(1/hz);runs.push(roll.stats().angle);assert(roll.stats().overturned);assert(!roll.stats().active);assert(car.object.position.y>=0)}
assert(Math.max(...runs)-Math.min(...runs)<.01,'consistent substeps');roll.reset();assert.equal(car.object.rotation.z,0);
roll.impact({normal:{x:0,y:0,z:1},impactSpeed:22});assert.equal(roll.stats().angularVelocity,0,'head-on collision does not invent lateral torque');
const hit=polygonVehicleContact([[-1,-2],[1,-2],[1,2],[-1,2]],[[.9,-.5],[2,-.5],[2,.5],[.9,.5]]);assert(hit);assert(hit.normal.x>.99);assert(Math.abs(hit.point.x-1)<1e-8);assert(Math.abs(hit.point.z)<1e-8);
const motion=contactKinematics(hit,10,Math.PI/2);assert.equal(motion.impactSpeed,10);assert(motion.slideSpeed<1e-6);
console.log('PASS light/heavy/front roll, 30/60/120Hz, grounded reset, actual contact face and normal speed',runs);
