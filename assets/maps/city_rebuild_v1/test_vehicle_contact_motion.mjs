import test from 'node:test';
import assert from 'node:assert/strict';
import {moveVehicleWithContacts,vehicleStateFromVelocity} from './vehicle_contact_motion.mjs';
import {polygonVehicleContact} from './vehicle_contact.mjs';
const shape={halfWidth:1,halfLength:2};
function referenceVehicleStateFromVelocity(state,vx,vz,yawRate=state.yawRate){
 const magnitude=Math.hypot(vx,vz),forward=vx*Math.sin(state.yaw)+vz*Math.cos(state.yaw);
 const sign=Math.abs(forward)>.01?Math.sign(forward):Math.sign(state.speed)||1;
 const stopped=magnitude<.015;
 const finite=(v,f=0)=>Number.isFinite(v)?v:f;
 const delta=(a,b)=>Math.atan2(Math.sin(a-b),Math.cos(a-b));
 return {...state,vx:stopped?0:vx,vz:stopped?0:vz,speed:stopped?0:sign*magnitude,
  travelYaw:stopped?state.yaw:Math.atan2(vx*sign,vz*sign),yawRate:finite(yawRate),
  longitudinalVelocity:stopped?0:forward,lateralVelocity:stopped?0:vx*Math.cos(state.yaw)-vz*Math.sin(state.yaw),
  slipAngle:stopped?0:delta(state.yaw,Math.atan2(vx*sign,vz*sign))};
}
const polygon=(s)=>[[-1,-2],[1,-2],[1,2],[-1,2]].map(([x,z])=>[s.x+x*Math.cos(s.yaw)+z*Math.sin(s.yaw),s.z-x*Math.sin(s.yaw)+z*Math.cos(s.yaw)]);
function wall(angle=0){
 const convert=([x,z])=>[x*Math.cos(angle)+z*Math.sin(angle),-x*Math.sin(angle)+z*Math.cos(angle)];
 const obstacle=[[1,-100],[10,-100],[10,100],[1,100]].map(convert);
 const contactAt=(x,z,yaw)=>polygonVehicleContact(polygon({x,z,yaw}),obstacle);
 return {shape,contactAt,fits:(x,z,yaw)=>!contactAt(x,z,yaw)};
}
function run(start,seconds,world){let s={...start};for(let t=0;t<seconds-1e-6;t+=1/120)s=moveVehicleWithContacts(s,s,1/120,world);return s;}
// Independent pre-optimization SAT reference.  Keep this here so a future
// allocation optimization cannot subtly change the hit face, normal or depth.
function referencePolygonVehicleContact(car,obstacle){
 let depth=Infinity,normal=null;
 const center=p=>p.reduce((a,v)=>[a[0]+v[0]/p.length,a[1]+v[1]/p.length],[0,0]);
 const aCenter=center(car),bCenter=center(obstacle);
 for(const poly of [car,obstacle])for(let i=0;i<poly.length;i++){
  const a=poly[i],b=poly[(i+1)%poly.length],dx=b[0]-a[0],dz=b[1]-a[1],len=Math.hypot(dx,dz);if(len<1e-8)continue;
  let nx=-dz/len,nz=dx/len;
  const project=p=>p.map(v=>v[0]*nx+v[1]*nz),ap=project(car),bp=project(obstacle);
  const overlap=Math.min(Math.max(...ap),Math.max(...bp))-Math.max(Math.min(...ap),Math.min(...bp));
  if(overlap<0)return null;
  if(overlap<depth){if((bCenter[0]-aCenter[0])*nx+(bCenter[1]-aCenter[1])*nz<0){nx=-nx;nz=-nz}depth=overlap;normal={x:nx,y:0,z:nz}}
 }
 if(!normal)return null;const {x:nx,z:nz}=normal,tx=-nz,tz=nx;
 const along=p=>p.map(v=>v[0]*tx+v[1]*tz),ap=along(car),bp=along(obstacle);
 const tangentMid=(Math.max(Math.min(...ap),Math.min(...bp))+Math.min(Math.max(...ap),Math.max(...bp)))/2;
 const support=Math.max(...car.map(v=>v[0]*nx+v[1]*nz));
 const face=car.filter(v=>support-(v[0]*nx+v[1]*nz)<1e-6).map(v=>v[0]*tx+v[1]*tz);
 const tangent=Math.max(Math.min(...face),Math.min(Math.max(...face),tangentMid));
 return {point:{x:nx*support+tx*tangent,y:.8,z:nz*support+tz*tangent},normal,depth};
}
function regularPolygon(x,z,r,yaw,count){return Array.from({length:count},(_,i)=>{const a=yaw+i*Math.PI*2/count;return[x+Math.cos(a)*r,z+Math.sin(a)*r]})}
function assertSameContact(actual,expected,label){
 assert.equal(actual===null,expected===null,`${label}: contact/null result`);
 if(!actual)return;
 for(const path of [['depth'],['normal','x'],['normal','y'],['normal','z'],['point','x'],['point','y'],['point','z']]){
  const actualValue=path.reduce((value,key)=>value[key],actual),expectedValue=path.reduce((value,key)=>value[key],expected);
  assert.ok(Math.abs(actualValue-expectedValue)<=1e-12,`${label}: ${path.join('.')} ${actualValue} !== ${expectedValue}`);
 }
}
test('reused travel yaw is bit-exact with the independent state reference',()=>{
 const states=[
  {x:0,z:0,yaw:0,speed:0,travelYaw:0,yawRate:0},
  {x:-14.25,z:8.75,yaw:1.381,speed:-23.2,travelYaw:-.9,yawRate:.17,tag:'car'},
  {x:99,z:-44,yaw:-2.91,speed:4.7,travelYaw:2.4,yawRate:Infinity},
 ];
 const velocities=[[0,0,0],[.0149,-.0002,undefined],[.015,0,0],[-14.5,3.75,-.8],[Number.NaN,2,NaN]];
 for(const state of states)for(const [vx,vz,yawRate] of velocities){
  const actual=vehicleStateFromVelocity(state,vx,vz,yawRate);
  const expected=referenceVehicleStateFromVelocity(state,vx,vz,yawRate);
 assert.deepEqual(actual,expected,{state,vx,vz,yawRate});
 }
});
test('allocation-free SAT preserves the independent hit geometry reference',()=>{
 for(let i=0;i<720;i++){
  const car=regularPolygon(Math.sin(i*.71)*.2,Math.cos(i*.31)*.2,.7+(i%7)*.13,i*.173,3+i%7);
  const separated=i%3===0,obstacle=regularPolygon(separated?7+Math.sin(i):.35+Math.sin(i*.19),separated?6+Math.cos(i):.25+Math.cos(i*.29),.6+(i%5)*.19,i*.127,3+(i*3)%8);
  assertSameContact(polygonVehicleContact(car,obstacle),referencePolygonVehicleContact(car,obstacle),`pair ${i}`);
 }
});
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
