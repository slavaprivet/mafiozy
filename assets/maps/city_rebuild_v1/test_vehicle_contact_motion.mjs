import test from 'node:test';
import assert from 'node:assert/strict';
import {moveVehicleWithContacts,vehicleStateFromVelocity} from './vehicle_contact_motion.mjs';
import {polygonVehicleContact} from './vehicle_contact.mjs';
const shape={halfWidth:1,halfLength:2};
const polygon=(s)=>[[-1,-2],[1,-2],[1,2],[-1,2]].map(([x,z])=>[s.x+x*Math.cos(s.yaw)+z*Math.sin(s.yaw),s.z-x*Math.sin(s.yaw)+z*Math.cos(s.yaw)]);
function wall(angle=0){
 const convert=([x,z])=>[x*Math.cos(angle)+z*Math.sin(angle),-x*Math.sin(angle)+z*Math.cos(angle)];
 const obstacle=[[1,-100],[10,-100],[10,100],[1,100]].map(convert);
 const contactAt=(x,z,yaw)=>polygonVehicleContact(polygon({x,z,yaw}),obstacle);
 return {shape,contactAt,fits:(x,z,yaw)=>!contactAt(x,z,yaw)};
}
function run(start,seconds,world){let s={...start};for(let t=0;t<seconds-1e-6;t+=1/120)s=moveVehicleWithContacts(s,s,1/120,world);return s;}
test('wall tangency is independent of map axes and keeps motion',()=>{
 for(const angle of [0,.3,.78,1.3,2.4]){
  const world=wall(angle),s={x:-.015*Math.cos(angle),z:.015*Math.sin(angle),yaw:angle,speed:8,travelYaw:angle,yawRate:0,vx:8*Math.sin(angle),vz:8*Math.cos(angle)};
  const out=run(s,1,world);
  assert.ok(Math.hypot(out.x-s.x,out.z-s.z)>7.9,`tangent stuck at angle ${angle}`);
  assert.ok(world.fits(out.x,out.z,out.yaw));
 }
});
test('a diagonal scrape dissipates normal energy while preserving tangential motion',()=>{
 const world=wall(.51),angle=.51,s=vehicleStateFromVelocity({x:-.04*Math.cos(angle),z:.04*Math.sin(angle),yaw:angle,speed:8},2*Math.cos(angle)+8*Math.sin(angle),-2*Math.sin(angle)+8*Math.cos(angle),0);
 const out=run(s,1,world),along=(out.x-s.x)*Math.sin(angle)+(out.z-s.z)*Math.cos(angle);
 assert.ok(along>5,`scrape travelled only ${along}`);assert.ok(world.fits(out.x,out.z,out.yaw));
 assert.ok(Math.hypot(out.vx,out.vz)<=Math.hypot(s.vx,s.vz)+1e-6);
});
test('slight pre-existing overlap permits separation and reversing',()=>{
 const world=wall(),s={x:.02,z:0,yaw:Math.PI/2,speed:-2,travelYaw:Math.PI/2,yawRate:0,vx:-2,vz:0};
 // Use a square here: the initial 2 cm overlap has a known outward normal.
 const squareWorld={...world,contactAt:(x,z)=>polygonVehicleContact([[x-1,z-1],[x+1,z-1],[x+1,z+1],[x-1,z+1]],[[1,-100],[10,-100],[10,100],[1,100]])};
 squareWorld.fits=(x,z,yaw)=>!squareWorld.contactAt(x,z,yaw);
 const out=run(s,.2,squareWorld);assert.ok(out.x<-.35);assert.ok(squareWorld.fits(out.x,out.z,out.yaw));
});
test('fast head-on contact reaches the surface without passing through it',()=>{
 const world=wall(),s={x:-.1,z:0,yaw:0,speed:30,travelYaw:Math.PI/2,yawRate:0,vx:30,vz:0};
 const out=moveVehicleWithContacts(s,s,1/120,world);
 assert.ok(out.x<=0&&out.x>-.003);assert.ok(out.bumped);assert.ok(out.contact.impactSpeed>29);
 assert.ok(Math.abs(out.vx)<.001);assert.ok(world.fits(out.x,out.z,out.yaw));
});
test('unknown boolean obstacle clips safely and a stopped state stays finite',()=>{
 const s={x:0,z:0,yaw:0,speed:30,travelYaw:0,yawRate:0,vx:0,vz:30};
 const out=moveVehicleWithContacts(s,s,.1,{shape,fits:(x,z)=>z<.2});
 assert.ok(out.z<.2&&out.z>.199);assert.equal(out.speed,0);
 assert.ok([out.vx,out.vz,out.travelYaw,out.slipAngle].every(Number.isFinite));
});
