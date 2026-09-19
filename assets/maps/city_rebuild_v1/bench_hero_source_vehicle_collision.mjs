import assert from 'node:assert/strict';
import {trafficActorBlocks} from './world_traffic_presentation.mjs';
import {carOverlapsCircle} from './car_drive.mjs';
const actors=Array.from({length:200},(_,i)=>({object:{visible:true,position:{x:i%20*14,z:Math.floor(i/20)*14,y:0},rotation:{y:i*.37},scale:{x:1,y:1,z:1}},profile:{halfWidth:1.15,halfLength:2.4,height:1.8}}));
// Exact former final narrowphase after the same visibility/vertical guards.
function before(actor,x,z,radius){const object=actor.object,profile=actor.profile;return carOverlapsCircle({x:object.position.x,z:object.position.z,yaw:object.rotation.y,vehicleProfile:{halfWidth:profile.halfWidth*Math.abs(object.scale.x),halfLength:profile.halfLength*Math.abs(object.scale.z)}},x,z,radius);}
const points=[[-3,0],[-1.4,0],[-1.0,0],[0,0],[2.5,2.5],[5,5],[12,8],[18,15]];
for(const actor of actors)for(const [x,z]of points)assert.equal(trafficActorBlocks(actor,x,z,.36),before(actor,x,z,.36));
const times={before:[],after:[]};let sink=0;
for(let n=0;n<125;n++)for(const [name,fn]of n%2?[['after',trafficActorBlocks],['before',before]]:[['before',before],['after',trafficActorBlocks]]){
 const start=performance.now();for(const [x,z]of points)for(const actor of actors)sink+=fn(actor,x,z,.36)?1:0;const elapsed=performance.now()-start;if(n>=25)times[name].push(elapsed);
}
const stats=a=>{a.sort((x,y)=>x-y);return {p50Ms:a[50],p95Ms:a[95]};};
console.log(JSON.stringify({parity:true,actors:200,points:8,warmup:25,samples:100,before:stats(times.before),after:stats(times.after),sink,scope:'CPU 1600 candidate contacts; not scene FPS'}));
