import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
import {createWaterInteractionSimulator,createWaterInteractionEffects,waterRippleRadius,WATER_RIPPLE_START_RADIUS,WATER_RIPPLE_SPEED,WATER_RIPPLE_LIFETIME} from './water_interaction_fx.mjs';

const waterAt=(x,z)=>Math.abs(x)<20&&Math.abs(z)<20?{level:0,depth:1,floor:-1}:null;
const hero=(x,y,z=0,extra={})=>({id:'hero',position:{x,y,z},...extra});
const car=(x,y,z=0,extra={})=>({id:'car',position:{x,y,z},massKg:1300,footprint:{width:1.9,length:4.5},...extra});
const sim=(extra={})=>createWaterInteractionSimulator({waterAt,random:()=>.4,...extra});
let checks=0;
function test(name,fn){fn();checks++;console.log('PASS',name);}

test('first water observation, stationary actor and water exit never burst',()=>{
  const s=sim();s.update(.05,{hero:hero(0,-.2)});for(let i=0;i<100;i++)s.update(.05,{hero:hero(0,-.2)});assert.equal(s.stats().bursts,0);
  s.update(.05,{hero:hero(0,1)});assert.equal(s.stats().bursts,0);
});
test('downward swept impact survives frame crossing and grounded velocity reset',()=>{
  const s=sim();s.update(.05,{hero:hero(0,1)});s.update(.05,{hero:hero(0,-.2,0,{velocity:{x:0,y:-6,z:0}})});
  assert.equal(s.stats().impacts,1);assert(s.stats().activeDroplets>12);assert(s.getRipples()[0].strength>.5);
  const before=s.stats().bursts;for(let i=0;i<80;i++)s.update(.05,{hero:hero(0,-.2)});assert.equal(s.stats().bursts,before);assert(s.stats().recontacts>0);
});
test('swept horizontal crossing detects a narrow pond even with dry endpoint',()=>{
  const s=sim({waterAt:x=>x>=0&&x<=.6?{level:0,depth:.7}:null});
  s.update(.05,{hero:hero(-.3,0)});s.update(.05,{hero:hero(.9,0)});assert(s.stats().bursts>0);
});
test('airborne pass above lake does not splash',()=>{
  const s=sim({waterAt:x=>x>=0&&x<=.6?{level:0,depth:.7}:null});s.update(.05,{hero:hero(-.3,2)});s.update(.05,{hero:hero(.9,2)});assert.equal(s.stats().bursts,0);
});
test('shallow wading is a small wake, not a jump impact',()=>{
  const s=sim({waterAt:x=>x>=0?{level:0,depth:.04}:null});s.update(.1,{hero:hero(-.1,0)});s.update(.1,{hero:hero(.1,-.02)});
  assert.equal(s.stats().impacts,0);assert.equal(s.stats().wakes,1);assert(s.stats().droplets<12);
});
test('teleport, despawn and long suspended frames suppress fabricated impacts',()=>{
  for(const extra of [{teleport:true},{position:{x:16,y:-.2,z:0}}]){const s=sim();s.update(.05,{hero:hero(0,1)});s.update(.05,{hero:hero(0,-.2,0,extra)});assert.equal(s.stats().bursts,0);}
  const s=sim();s.update(.05,{hero:hero(0,1)});s.update(3,{hero:hero(0,-.2)});assert.equal(s.stats().bursts,0);assert(s.stats().time<.12);
  s.update(.05,{});s.update(.05,{hero:hero(0,-.2)});assert.equal(s.stats().bursts,0);
});
test('heavy vehicle energy and water depth increase bounded spray',()=>{
  const impact=(massKg,depth)=>{const s=sim({waterAt:()=>({level:0,depth})});s.update(.05,{vehicles:[car(0,.08,0,{massKg})]});s.update(.05,{vehicles:[car(.25,-.02,0,{massKg,velocity:{x:5,y:-2,z:0}})]});return s.stats().droplets;};
  assert(impact(10000,1)>impact(1000,1));assert(impact(1000,1)>impact(1000,.025));assert(impact(10000,1)<=96);
});
test('actual world wheel contacts support slopes, wheel removal and dry body centers',()=>{
  const s=sim({waterAt:x=>x>0?{level:0,depth:.3}:null});
  const points=[{x:-.1,y:.3,z:0,front:true},{x:.1,y:.3,z:0,front:true}];
  s.update(.05,{vehicles:[car(-1,1,0,{contactPoints:points})]});
  s.update(.05,{vehicles:[car(-.7,1,0,{contactPoints:points.map(p=>({...p,y:-.1})),velocity:{x:6,y:-3,z:0}})]});assert.equal(s.stats().impacts,1);
  const before=s.stats().bursts;s.update(.05,{vehicles:[car(-.4,1,0,{contactPoints:[{x:.1,y:-.1,z:0}]})]});assert.equal(s.stats().bursts,before,'changing wheel set re-seeds contact history');
});
test('moving front-wheel bow wave follows yaw +Z and stops with the car',()=>{
  const s=sim();s.update(.05,{vehicles:[car(0,-.1,0,{yaw:Math.PI/2})]});s.update(.05,{vehicles:[car(1,-.1,0,{yaw:Math.PI/2})]});
  assert.equal(s.stats().wakes,2);const ripples=s.getRipples();assert(ripples.every(r=>r.x>2),'front axle is +X at yaw PI/2');
  const n=s.stats().bursts;for(let i=0;i<50;i++)s.update(.05,{vehicles:[car(1,-.1,0,{yaw:Math.PI/2})]});assert.equal(s.stats().bursts,n);
});
test('droplets follow gravity 9.81 with drag and recontact instead of hanging',()=>{
  const s=sim({drag:0});s.update(.05,{hero:hero(0,1)});s.update(.05,{hero:hero(0,0)});
  const p=s.droplets.find(p=>p.active),vy=p.vy;s.update(.05,{hero:hero(0,0)});assert(Math.abs(p.vy-(vy-9.81*.05))<1e-9);
  for(let i=0;i<120;i++)s.update(.05,{hero:hero(0,0)});assert.equal(s.stats().activeDroplets,0);assert(s.stats().recontacts>0);assert.equal(s.getRipples().length,0);
});
test('pools, number of actors, render focus and shader ripples stay bounded',()=>{
  const s=sim({maxDroplets:20,maxRings:5,maxFoam:8,maxActors:4});
  const cars=Array.from({length:30},(_,i)=>car(i*.05,1,0,{id:'c'+i}));s.update(.05,{vehicles:cars});assert(s.stats().trackedActors<=4);
  s.update(.05,{vehicles:cars.map(c=>({...c,position:{...c.position,y:-.2}}))});assert(s.stats().activeDroplets<=20);assert(s.stats().activeRings<=5);assert(s.stats().activeFoam<=8);assert(s.getRipples().length<=8);assert(s.getRipples().every(r=>r.age<=4.5&&r.strength<=2));
  s.update(.05,{vehicles:cars,focus:{x:1000,z:1000}});assert.equal(s.stats().trackedActors,0);
  s.dispose();assert.equal(s.stats().activeDroplets,0);s.update(.05,{hero:hero(0,-1)});assert.equal(s.stats().trackedActors,0);
});
test('inputs are never mutated and invalid dt is harmless',()=>{
  const s=sim(),input={hero:hero(0,1),vehicles:[car(2,1)]},original=JSON.stringify(input);s.update(.05,input);assert.equal(JSON.stringify(input),original);const t=s.stats().time;for(const dt of [NaN,Infinity,-1,0])s.update(dt,input);assert.equal(s.stats().time,t);
});
test('every effect radius matches the actual water shader independent of impact strength',()=>{
  const shader=fs.readFileSync(new URL('./environment_surface_materials.mjs',import.meta.url),'utf8');
  const expression=shader.match(/float radius\s*=\s*([.\d]+)\s*\+\s*event\.z\s*\*\s*([.\d]+)/);assert(expression,'actual environmentRippleAt radius contract');
  assert.equal(WATER_RIPPLE_START_RADIUS,Number(expression[1]));assert.equal(WATER_RIPPLE_SPEED,Number(expression[2]));assert.equal(WATER_RIPPLE_LIFETIME,4.5);
  const s=sim({random:()=>.1});s.update(.05,{hero:hero(0,1)});s.update(.05,{hero:hero(0,-.2)});let checked=0,weak=false;
  for(let frame=0;frame<100;frame++){for(const ripple of s.getRipples()){assert(Math.abs(ripple.radius-(Number(expression[1])+ripple.age*Number(expression[2])))<1e-10);assert.equal(ripple.radius,waterRippleRadius(ripple.age));if(ripple.strength<.1)weak=true;checked++;}s.update(.04,{hero:hero(0,-.2)});}
  assert(checked>100&&weak,'includes primary impact and returning-droplet waves');
});
test('wheel fans mirror outward at every yaw and reverse uses the rear leading axle',()=>{
  for(const yaw of [0,Math.PI/2,Math.PI,-.65])for(const direction of [1,-1]){
    let seed=842;const random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
    const s=sim({random}),sin=Math.sin(yaw),cos=Math.cos(yaw),x=sin*.95*direction,z=cos*.95*direction;
    s.update(.1,{vehicles:[car(0,-.1,0,{yaw})]});s.update(.1,{vehicles:[car(x,-.1,z,{yaw})]});
    assert.equal(s.stats().wakes,2);const sides=new Set();
    for(const drop of s.droplets.filter(p=>p.active)){
      const localSide=(drop.x-x)*cos-(drop.z-z)*sin,localFront=(drop.x-x)*sin+(drop.z-z)*cos;
      sides.add(Math.sign(localSide));const vx=drop.vx-x/.1*.18,vz=drop.vz-z/.1*.18;
      assert(localSide*(vx*cos-vz*sin)>0,'spray momentum points away from chassis');
      assert(localFront*direction>1,'leading axle switches when reversing');
      assert((vx*sin+vz*cos)*direction>0,'leading bow fans advance with travel direction');
    }
    assert.equal(sides.size,2,'both sides emit');
  }
});
test('unordered real wheel points infer side and axle from the car transform',()=>{
  const s=sim(),points=[{x:1,y:-.1,z:-2},{x:-1,y:-.1,z:2},{x:-1,y:-.1,z:-2},{x:1,y:-.1,z:2}];
  s.update(.1,{vehicles:[car(0,-.1,0,{contactPoints:points})]});
  s.update(.1,{vehicles:[car(0,-.1,1,{contactPoints:points.map(p=>({...p,z:p.z+1}))})]});
  assert.equal(s.stats().wakes,2);assert(s.getRipples().every(p=>p.z>2.9),'physical front points, not array order');
  assert(s.droplets.filter(p=>p.active).every(p=>p.x*p.vx>0),'physical left/right signs, not array order');
});

const vendor=process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js')).href);
test('actual THREE bounded instances, shader alpha hook and deterministic disposal',()=>{
  const fx=createWaterInteractionEffects({THREE,waterAt,random:()=>.4,maxDroplets:24,maxRings:6,maxFoam:8});
  const scene=new THREE.Scene();scene.add(fx.object);assert.equal(fx.object.children.length,3);assert(fx.object.children.every(m=>m.isInstancedMesh));
  for(const mesh of fx.object.children){const hits=[];mesh.raycast({},hits);assert.equal(hits.length,0,'visual water particles must not intercept weapon/interaction rays');}
  fx.update(.05,{hero:hero(0,1)});fx.update(.05,{hero:hero(0,-.2)});assert(fx.stats().drawCalls<=3);assert(fx.stats().activeDroplets>0);
  let disposed=0;for(const mesh of fx.object.children){mesh.geometry.addEventListener('dispose',()=>disposed++);mesh.material.addEventListener('dispose',()=>disposed++);const shader={vertexShader:THREE.ShaderLib.standard.vertexShader,fragmentShader:THREE.ShaderLib.standard.fragmentShader};mesh.material.onBeforeCompile(shader);assert(shader.vertexShader.includes('vWaterOpacity = waterInstanceOpacity'));assert(shader.fragmentShader.includes('diffuseColor.a *= vWaterOpacity'));assert(mesh.geometry.attributes.waterInstanceOpacity.array.every(Number.isFinite));for(let i=0;i<mesh.count;i++){const matrix=new THREE.Matrix4();mesh.getMatrixAt(i,matrix);assert(matrix.elements.every(Number.isFinite));}}
  fx.dispose();fx.dispose();assert.equal(disposed,6);assert.equal(scene.children.length,0);assert.equal(fx.object.children.length,0);
});
test('expanding ring arcs do not cross dry shore or a different-height pool',()=>{
  const shoreline=(x,z)=>x>0?{level:0,depth:1}:null;
  const fx=createWaterInteractionEffects({THREE,waterAt:shoreline,random:()=>.4,maxRings:1});
  fx.update(.05,{hero:hero(.01,1)});fx.update(.05,{hero:hero(.01,-.2)});
  const arcs=fx.object.children[1];assert(arcs.count>0&&arcs.count<12);
  for(let i=0;i<arcs.count;i++){const matrix=new THREE.Matrix4();arcs.getMatrixAt(i,matrix);const vertices=arcs.geometry.attributes.position;for(let v=0;v<vertices.count;v++){const p=new THREE.Vector3().fromBufferAttribute(vertices,v).applyMatrix4(matrix);assert(p.x>=-1e-7,'no ring geometry on land');}}
  fx.dispose();
});
test('actual foam ring geometry is centered on the shader wavefront, not its inner/outer edge',()=>{
  const fx=createWaterInteractionEffects({THREE,waterAt,random:()=>.4,maxRings:1});fx.update(.05,{hero:hero(0,1)});fx.update(.05,{hero:hero(0,-.2)});
  for(let frame=0;frame<25;frame++){
    const ripple=fx.getRipples()[0],arcs=fx.object.children[1];assert(ripple&&arcs.count===12);
    const matrix=new THREE.Matrix4();arcs.getMatrixAt(0,matrix);let inner=Infinity,outer=0;
    const vertices=arcs.geometry.attributes.position;for(let i=0;i<vertices.count;i++){const p=new THREE.Vector3().fromBufferAttribute(vertices,i).applyMatrix4(matrix),r=Math.hypot(p.x-ripple.x,p.z-ripple.z);inner=Math.min(inner,r);outer=Math.max(outer,r);}
    assert(Math.abs((inner+outer)/2-waterRippleRadius(ripple.age))<1e-6);
    fx.update(.04,{hero:hero(0,-.2)});
  }
  fx.dispose();
});
console.log(JSON.stringify({passed:true,checks,realThreeRevision:THREE.REVISION,scope:'isolated CPU and actual Three geometry; no live renderer/gameplay mutation'}));
