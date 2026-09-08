import assert from 'node:assert/strict';
import {resolveVehiclePairImpulse as solve} from './vehicle_pair_impulse.mjs';
const body=(values={})=>({mass:1500,x:0,z:0,yaw:0,vx:0,vz:0,yawRate:0,halfWidth:.9,halfLength:2,...values});
const contact={point:{x:1,z:0},normal:{x:1,z:0}};
const near=(a,b,eps=1e-9)=>assert.ok(Math.abs(a-b)<eps,`${a} != ${b}`);
const energy=(body,v)=>.5*body.mass*(v.vx*v.vx+v.vz*v.vz)+body.mass*(body.halfWidth**2+body.halfLength**2)/6*v.yawRate**2;
const sedan=body({vx:10}),other=body({x:2});
const original=JSON.stringify([sedan,other,contact]);
const equal=solve(sedan,other,contact);
near(equal.a.vx,4.4);near(equal.b.vx,5.6);near(equal.deltaVA,equal.deltaVB);
assert.equal(JSON.stringify([sedan,other,contact]),original);
const truck=body({mass:12000,x:2});
const lightIntoHeavy=solve(sedan,truck,contact);
near(lightIntoHeavy.deltaVA/lightIntoHeavy.deltaVB,8);
assert.ok(lightIntoHeavy.a.vx<.05);assert.ok(lightIntoHeavy.b.vx<1.3);
const heavyIntoLight=solve(body({mass:12000,vx:10}),other,contact);
near(heavyIntoLight.deltaVB/heavyIntoLight.deltaVA,8);
assert.ok(heavyIntoLight.b.vx>9.9);
assert.equal(solve(body({vx:-10}),other,contact).resolved,false);
assert.equal(solve(body(),other,contact).impulse,0);
assert.equal(solve(body({mass:0}),other,contact).resolved,false);
assert.equal(solve(body(),other,{...contact,normal:{x:0,z:0}}).resolved,false);
assert.equal(solve(body(),other,{...contact,point:{x:NaN,z:0}}).resolved,false);
const off=solve(sedan,other,{...contact,point:{x:1,z:1}});
assert.ok(off.a.yawRate<0&&off.b.yawRate>0);
const flat=solve(sedan,other,{...contact,point:{x:1,z:1}},{angular:false});
near(flat.a.yawRate,0);near(flat.b.yawRate,0);near(flat.deltaVA,equal.deltaVA);
// Deterministic broad physical cases: energy never grows and total momentum
// (linear and about the world origin) is conserved for offset contacts.
let seed=17;
const random=()=>((seed=Math.imul(seed,1664525)+1013904223>>>0)/4294967296);
const momentumY=(b,v)=>b.mass*(b.z*v.vx-b.x*v.vz)+b.mass*(b.halfWidth**2+b.halfLength**2)/3*v.yawRate;
for(let i=0;i<2000;i++){
 const make=()=>body({mass:500+random()*20000,x:random()*20-10,z:random()*20-10,vx:random()*40-20,vz:random()*40-20,yawRate:random()*4-2,halfWidth:.6+random()*2,halfLength:1+random()*6});
 const a=make(),b=make(),angle=random()*Math.PI*2;
 const c={point:{x:random()*10-5,z:random()*10-5},normal:{x:Math.cos(angle),z:Math.sin(angle)}};
 const r=solve(a,b,c);
 assert.ok(energy(a,r.a)+energy(b,r.b)<=energy(a,a)+energy(b,b)+1e-6);
 near(a.mass*r.a.vx+b.mass*r.b.vx,a.mass*a.vx+b.mass*b.vx,1e-6);
 near(a.mass*r.a.vz+b.mass*r.b.vz,a.mass*a.vz+b.mass*b.vz,1e-6);
 near(momentumY(a,r.a)+momentumY(b,r.b),momentumY(a,a)+momentumY(b,b),1e-5);
 const reverse=solve(b,a,{point:c.point,normal:{x:-c.normal.x,z:-c.normal.z}});
 near(r.a.vx,reverse.b.vx);near(r.a.vz,reverse.b.vz);near(r.a.yawRate,reverse.b.yawRate);
 near(r.b.vx,reverse.a.vx);near(r.b.vz,reverse.a.vz);near(r.b.yawRate,reverse.a.yawRate);
}
console.log('PASS: equal masses, 12000/1500 kg asymmetry, separating/invalid contacts, yaw impulses, 2000 energy/momentum/swap cases');
