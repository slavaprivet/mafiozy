import test from 'node:test';
import assert from 'node:assert/strict';
import {stepVehicleDynamics as step} from './vehicle_dynamics.mjs';
const init={x:0,z:0,yaw:0,speed:0},profile={wheelBase:2.65,maxSpeed:22,reverseSpeed:6,acceleration:6.5};
function simulate(state,input,seconds,dt=1/60,p=profile){let s={...state},x=0,z=0;for(let i=0;i<Math.round(seconds/dt);i++){s=step(s,typeof input==='function'?input(i*dt,s):input,dt,p);x+=s.vx*dt;z+=s.vz*dt}return{...s,pathX:x,pathZ:z}}
const near=(a,b,tolerance=1e-8)=>assert(Math.abs(a-b)<=tolerance,`${a} != ${b}`);

test('gas, signed reverse, independent service brake, parking brake and smooth steering retain controls',()=>{
 assert.equal(simulate(init,{forward:true},4).speed,22);assert.equal(simulate(init,{reverse:true},4).speed,-6);
 const left=simulate(init,{forward:true,left:true},2),right=simulate(init,{forward:true,right:true},2);assert(left.yaw>0&&left.pathX>0);near(left.yaw,-right.yaw);near(left.pathX,-right.pathX);
 const parked=simulate(init,{left:true},1);assert(parked.steer>.5);assert.equal(parked.yaw,0);assert(Math.abs(simulate(parked,{},1).steer)<.001);
 assert(parked.steer<=.56,'full lock stays within the verified wheel-arch sweep');assert(simulate({...init,steer:.8,crashEffects:{steerFactor:2}},{left:true},1,1/60,{...profile,dynamics:{maxSteer:.8}}).steer<=.56);
 const reverse=simulate(init,{reverse:true,right:true},1);assert(reverse.speed<0&&reverse.yaw>0);assert(Math.abs(reverse.travelYaw-reverse.yaw)<Math.PI/2,'reverse heading is forward-facing signed convention');
 const braking=simulate({...init,speed:8},{reverse:true},.2);assert(braking.speed>0&&braking.braking);
 const stopped=simulate({...init,speed:15},{handbrake:true,forward:true},1);assert(stopped.speed<3.1);assert.equal(simulate({...init,speed:15},{handbrake:true,forward:true},2).speed,0);
 assert.equal(simulate(init,{handbrake:true},1).rearSlip,0);assert(simulate({...init,speed:15},{},1).speed>10);
 const fast=simulate({...init,speed:22},{forward:true,left:true},1);assert(Math.abs(fast.yawRate*fast.speed)<=10.01);assert(fast.frontSlip>.2);
});

test('rear lock creates controllable drift; countersteering corrects yaw, and release recovers grip without snapping momentum',()=>{
 const start={...init,speed:18},normal=simulate(start,{left:true},.5),drift=simulate(start,{left:true,handbrake:true},.5);
 assert(Math.abs(drift.slipAngle)>Math.abs(normal.slipAngle)*2);assert(drift.rearSlip>.9&&drift.braking);
 const released=step(drift,{},1/120,profile);assert(Math.abs(released.lateralVelocity)>.5*Math.abs(drift.lateralVelocity),'side velocity persists on release');assert(released.rearGripBlend>drift.rearGripBlend&&released.rearGripBlend<.3,'rear grip recovers progressively');
 const counter=simulate(drift,{right:true},.5),uncorrected=simulate(drift,{left:true},.5);assert(counter.yawRate<0);assert(Math.abs(counter.yaw-drift.yaw)<Math.abs(uncorrected.yaw-drift.yaw),'opposite steering arrests spin');
 const recovered=simulate(drift,{},2);assert(Math.abs(recovered.slipAngle)<.001);assert(recovered.rearGripBlend>.999);assert(recovered.speed>0,'release retains travel momentum');
 console.log(JSON.stringify({normalSlip:normal.slipAngle,driftSlip:drift.slipAngle,releasedLateral:released.lateralVelocity,recoveredSlip:recovered.slipAngle,counterYaw:counter.yawRate}));
});

test('fixed 120Hz dynamics agree at 30/60/120 FPS through acceleration, braking, reverse, drift and recovery',()=>{
 const phases=[[2,{forward:true}],[1,{forward:true,left:true}],[.5,{left:true,handbrake:true}],[.5,{right:true}],[2,{}],[2,{reverse:true}]];
 const result=[];for(const fps of [30,60,120]){let s={...init};for(const [seconds,input]of phases)s=simulate(s,input,seconds,1/fps);result.push(s)}
 for(const s of result)for(const key of ['speed','travelYaw','yaw','yawRate','steer','vx','vz','rearGripBlend'])near(s[key],result[0][key],1e-7);
});

test('external fleet speed/travelYaw are authoritative; lateral and angular collision impulse are not instantly discarded',()=>{
 const external={...init,speed:8,travelYaw:.8,vx:900,vz:-400,lateralVelocity:900,longitudinalVelocity:-400,yawRate:1.5};
 const clean={...external,vx:0,vz:0,lateralVelocity:0,longitudinalVelocity:0};const a=step(external,{},1/120,profile),b=step(clean,{},1/120,profile);
 near(a.vx,b.vx);near(a.vz,b.vz);assert(a.vx>5);assert(a.yawRate>1.3);assert(a.speed>7.7);
 const reverse={...init,speed:-5,travelYaw:0},next=step(reverse,{},1/120,profile);assert(next.vz<0&&next.speed<0);assert(Math.abs(next.travelYaw)<1e-8);
 near(a.vx,Math.sin(a.travelYaw)*a.speed);near(a.vz,Math.cos(a.travelYaw)*a.speed);
 assert.equal(a.x,external.x);assert.equal(a.z,external.z,'dynamics do not admit world displacement');
});

test('engine stall, braking damage, punctured tyres, pull and reduced attainable top speed preserve momentum',()=>{
 const disabled={engineDisabled:true},moving={...init,speed:12,crashEffects:disabled},coast=step(moving,{},1/60,profile),brake=step(moving,{reverse:true},1/60,profile);assert(coast.speed>11.5);assert(brake.speed<coast.speed);assert(brake.braking);assert.equal(simulate({...init,crashEffects:disabled},{forward:true},3).speed,0);
 const limited=step({...init,speed:20,crashEffects:{speedFactor:.2,powerFactor:.15,rollingDrag:2}},{forward:true},1/60,profile);assert(limited.speed>19.5&&limited.speed<20);
 const healthy=simulate(init,{forward:true},3),damaged=simulate({...init,crashEffects:{powerFactor:.3,speedFactor:.4,frontGrip:.4,rearGrip:.3,rollingDrag:2,pull:.15,steerFactor:.4}},{forward:true},3);assert(damaged.speed<healthy.speed*.5);assert(damaged.yaw>0);
 const goodBrake=simulate({...init,speed:12},{reverse:true},.5),badBrake=simulate({...init,speed:12,crashEffects:{brakeFactor:.2}},{reverse:true},.5);assert(badBrake.speed>goodBrake.speed+3);
 const tyres=simulate({...init,tyreEffects:{speedFactor:.5,frontGrip:.4,rearGrip:.4,pull:.12}},{forward:true},3);assert(tyres.speed<healthy.speed);assert(tyres.yaw>0);
 const bus=simulate({...init,speed:5},{left:true},.8,1/60,{...profile,wheelBase:5.4,acceleration:2.6,maxSpeed:17});assert(Math.abs(bus.yaw)<Math.abs(simulate({...init,speed:5},{left:true},.8).yaw)*.65);
});

test('coasting tire forces never generate translation energy; invalid inputs stay finite and zero dt preserves motion',()=>{
 for(let i=0;i<40;i++){let s={...init,speed:3+i*.7,travelYaw:Math.sin(i)*.9,yawRate:Math.cos(i)*1.4};for(let j=0;j<240;j++){const before=Math.abs(s.speed);s=step(s,{left:j%40<20,right:j%40>=20},1/120,profile);assert(Math.abs(s.speed)<=before+1e-8);for(const key of ['speed','yaw','travelYaw','vx','vz','yawRate','steer'])assert(Number.isFinite(s[key]))}}
 assert.throws(()=>step(init,{},NaN));assert.throws(()=>step({...init,yaw:NaN},{},.01));assert.throws(()=>step(init,{},-.01));
 const s={...init,speed:-4,travelYaw:.15,yawRate:.2,steer:.1};const zero=step(s,{},0,profile);for(const key of ['speed','yaw','travelYaw','yawRate','steer'])near(zero[key],s[key]);
 const robust=step({...init,speed:10,tyreEffects:{frontGrip:NaN},crashEffects:{rollingDrag:Infinity}}, {}, .1,{wheelBase:0,maxSpeed:NaN,dynamics:{frontStiffness:NaN}});assert(Number.isFinite(robust.speed));
});
