import assert from 'node:assert/strict';
import {planBlastKnockback as plan,stepBlastKnockback as step} from './vehicle_blast_motion.mjs';
import {movePedestrian} from './walk_motion.mjs';
const REFERENCE_STEP=1/120,REFERENCE_RADIUS=.58,REFERENCE_GRAVITY=18;
// Pre-allocation reference for the former implementation.  This checks the
// public state after every fixed step, not just the landing result.
function referenceStep(body,dt,allowed=()=>true,{groundHeight,ceilingHeight}={}){
 if(!body)return null;
 if(body.done||!Number.isFinite(dt)||dt<=0)return {...body};
 let s={...body},remaining=(s.remainder??0)+Math.min(.25,dt);
 const floorAt=(x,z,fallback)=>{const value=groundHeight?.(x,z);return Number.isFinite(value)?value:fallback};
 while(remaining+1e-10>=REFERENCE_STEP&&!s.done){
  remaining-=REFERENCE_STEP;
  const currentFloor=floorAt(s.x,s.z,s.baseY),grounded=s.y<=currentFloor+1e-8&&s.vy<=0;
  const speed=Math.hypot(s.vx,s.vz),nextSpeed=Math.max(0,speed-(grounded?8:.4)*REFERENCE_STEP),ratio=speed?nextSpeed/speed:0;
  let vx=s.vx*ratio,vz=s.vz*ratio;
  const delta={x:(s.vx+vx)*.5*REFERENCE_STEP,z:(s.vz+vz)*.5*REFERENCE_STEP};
  let moved=movePedestrian(s,delta,allowed,REFERENCE_RADIUS);
  let bx=Math.abs(moved.x-s.x-delta.x)>1e-6,bz=Math.abs(moved.z-s.z-delta.z)>1e-6;
  if(bx)vx=0;if(bz)vz=0;
  let vy=s.vy-REFERENCE_GRAVITY*REFERENCE_STEP,y=s.y+(s.vy+vy)*.5*REFERENCE_STEP;
  let baseY=floorAt(moved.x,moved.z,s.baseY);
  if(groundHeight&&baseY>Math.max(y,currentFloor)){
   const rise=baseY-Math.max(y,currentFloor),v2=vx*vx+vz*vz,cost=2*REFERENCE_GRAVITY*rise;
   if(cost>v2){moved={x:s.x,z:s.z};baseY=currentFloor;vx=0;vz=0;bx=true;bz=true}
   else {const uphillRatio=v2?Math.sqrt(Math.max(0,v2-cost)/v2):0;vx*=uphillRatio;vz*=uphillRatio}
  }
  if(y<=baseY){y=baseY;vy=0}
  const ceiling=ceilingHeight?.(moved.x,moved.z);
  let ceilingBlocked=false,cramped=false;
  if(Number.isFinite(ceiling)){
   const maxY=Math.max(baseY,ceiling-.65);cramped=ceiling-baseY<.65;
   if(y>maxY){y=maxY;vy=Math.min(0,vy);ceilingBlocked=true}
  }
  const elapsed=Math.min(s.duration,s.elapsed+REFERENCE_STEP),progress=elapsed/s.duration,done=progress>=1-1e-9&&y<=baseY+1e-8&&vy<=0;
  s={...s,x:moved.x,z:moved.z,y,baseY,vx:done?0:vx,vy:done?0:vy,vz:done?0:vz,elapsed,progress:done?1:Math.min(.999,progress),done,blocked:s.blocked||bx||bz,ceilingBlocked:(s.ceilingBlocked??false)||ceilingBlocked,cramped};
 }
 s.remainder=s.done?0:Math.max(0,remaining);return s;
}
const blast={point:{x:0,y:0,z:0},power:1,radius:10};
const point={x:2,y:0,z:0};
const normal=plan(point,blast),strong=plan(point,{...blast,power:4}),far=plan({x:8,y:0,z:0},blast);
assert.ok(strong.vx>normal.vx&&strong.vy>normal.vy&&strong.duration>normal.duration&&strong.rolls>normal.rolls);
assert.ok(normal.vx>far.vx&&normal.vy>far.vy&&normal.duration>far.duration);
assert.equal(plan({x:10,z:0},blast),null);
assert.equal(plan(point,blast,()=>false),null);
assert.ok(plan(point,blast,()=>.5).vx<normal.vx);
assert.equal(plan({x:NaN,z:0},blast),null);
assert.equal(plan(point,{...blast,power:Infinity}),null);
assert.equal(plan(point,blast,()=>NaN),null);
const center=plan({x:0,z:0},blast);
assert.ok(Object.values(center).filter(v=>typeof v==='number').every(Number.isFinite));
const capped=plan({x:0,z:0},{...blast,power:1e300});
assert.ok(Math.hypot(capped.vx,capped.vz)<=15&&capped.vy<=8.5&&capped.duration<=3);
function run(fps,allowed=()=>true){
 let s=plan(point,{...blast,power:4}),peak=0;
 for(let i=0;i<fps*4;i++){
  s=step(s,1/fps,allowed);peak=Math.max(peak,s.y);
  assert.ok(s.y>=s.baseY);
  assert.ok(Object.values(s).filter(v=>typeof v==='number').every(Number.isFinite));
 }
 assert.equal(s.done,true);assert.equal(s.y,s.baseY);assert.equal(s.progress,1);
 return {...s,peak};
}
const a=run(30),b=run(60),c=run(120);
for(const key of ['x','y','z','vx','vy','vz','elapsed','progress']){
 assert.ok(Math.abs(a[key]-b[key])<1e-9);assert.ok(Math.abs(a[key]-c[key])<1e-9);
}
for(const fps of [30,60,120]){
 const hit=run(fps,(x,z)=>x<4);
 assert.ok(hit.x<=4-.58+1e-8);assert.ok(hit.blocked);assert.equal(hit.vx,0);
 // A thin wall cannot be skipped even at the maximum blast speed.
 const thin=run(fps,x=>x<4||x>4.1);
 assert.ok(thin.x<=4-.58+1e-8);
}
let elevated=plan({x:2,y:3,z:0},{...blast,point:{x:0,y:3,z:0}});
for(let i=0;i<400;i++)elevated=step(elevated,1/120);
assert.equal(elevated.y,3);assert.equal(elevated.done,true);
console.log('PASS: strength/distance/cover/caps, finite centre, 30/60/120Hz same trajectory, walls/thin walls, ground and elevated landing');
const kineticPotential=s=>.5*(s.vx*s.vx+s.vy*s.vy+s.vz*s.vz)+18*s.y;
for(const floor of [x=>.12*(x-2),x=>-.15*(x-2),x=>x>3?-30:0,x=>x>3?20:0]){
 const finals=[];
 for(const fps of [30,60,120]){
  let s=plan(point,{...blast,power:4});
  for(let i=0;i<fps*10;i++){
   const before=kineticPotential(s);
   s=step(s,1/fps,()=>true,{groundHeight:floor});
   assert.ok(s.y>=floor(s.x)-1e-8,'body above sampled floor');
   assert.ok(kineticPotential(s)<=before+1e-7,'terrain cannot create energy');
  }
  assert.ok(s.done);assert.ok(Math.abs(s.y-floor(s.x))<1e-8);
  finals.push(s);
 }
 for(const other of finals.slice(1))for(const key of ['x','y','z'])assert.ok(Math.abs(finals[0][key]-other[key])<1e-9);
}
let seat=plan({x:2,y:1.94,z:0,groundY:0},blast);
assert.equal(seat.y,1.94);assert.equal(seat.baseY,0);
for(let i=0;i<600;i++)seat=step(seat,1/120,()=>true,{groundHeight:()=>0});
assert.equal(seat.y,0);assert.ok(seat.done);
let invalidFloor=plan(point,blast);
invalidFloor=step(invalidFloor,1/30,()=>true,{groundHeight:()=>NaN});
assert.equal(invalidFloor.baseY,0);
console.log('PASS: sampled uphill/downhill/cliff/wall, energy nonincrease and FPS parity, car-seat height landing, invalid sampler fallback');
for(const ceiling of [2.4,.8,.4]){
 let s=plan(point,{...blast,power:100});
 for(let i=0;i<600;i++){
  const before=kineticPotential(s);
  s=step(s,1/120,()=>true,{groundHeight:()=>0,ceilingHeight:()=>ceiling});
  assert.ok(s.y>=0);assert.ok(s.y<=Math.max(0,ceiling-.65)+1e-8);
  assert.ok(kineticPotential(s)<=before+1e-8);
 }
 assert.ok(s.ceilingBlocked);assert.ok(s.done);
 assert.equal(s.cramped,ceiling<.65);
}
let outside=plan(point,blast),without=plan(point,blast);
for(let i=0;i<500;i++){
 outside=step(outside,1/120,()=>true,{ceilingHeight:()=>null});without=step(without,1/120);
 assert.deepEqual(outside,without);
}
console.log('PASS: powerful indoor blast ceiling clearance .65, low rooms floor-safe, no energy gain, outside null unchanged');
const parityCases=[
 {dt:1/30,allowed:()=>true,options:{}},
 {dt:1/60,allowed:(x,z)=>x<4||z<-.25,options:{groundHeight:x=>.12*(x-2)}},
 {dt:1/120,allowed:()=>true,options:{groundHeight:x=>x>3?20:0,ceilingHeight:()=>.8}},
];
for(const {dt,allowed,options} of parityCases){
 let actual=plan({x:2,y:0,z:0},{...blast,power:4}),reference=plan({x:2,y:0,z:0},{...blast,power:4});
 for(let frame=0;frame<360;frame++){
  actual=step(actual,dt,allowed,options);reference=referenceStep(reference,dt,allowed,options);
  assert.deepEqual(actual,reference,`mutable fixed-step result differs at frame ${frame}, dt ${dt}`);
 }
}
console.log('PASS: exact state parity with pre-allocation fixed-step reference: flat, wall/slope and cramped ceiling');
