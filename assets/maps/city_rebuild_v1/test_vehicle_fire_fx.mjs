import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createVehicleFireFx} from './vehicle_fire_fx.mjs';
const T=await import(pathToFileURL(process.env.MAFIOZY_THREE||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const cold={smoking:false,burning:false,destroying:false,wrecked:false,wreckAge:0},burn={...cold,smoking:true,burning:true};
const wreck=age=>({...burn,wrecked:true,wreckAge:age});
function fixture({parent=true,groundHeight=()=>0}={}){
 const scene=new T.Scene(),object=new T.Group(),bay=new T.Group();object.add(bay);if(parent)scene.add(object);
 const car={object,profile:{width:2},hood:{bay},hoodSpec:{engineBounds:{min:[-.5,.3,.8],max:[.5,1.1,1.8]}}};
 const fx=createVehicleFireFx(T,car,{groundHeight});const meshes=fx.object.children.filter(m=>m.isMesh),uniforms=meshes[0].material.uniforms,light=fx.object.children.find(n=>n.isLight);
 return{scene,car,fx,meshes,uniforms,light};
}
function finiteUniforms(f){for(const [name,{value}]of Object.entries(f.uniforms)){if(typeof value==='number')assert(Number.isFinite(value),name+' must remain finite');else if(value.isVector3)assert(value.toArray().every(Number.isFinite),name+' must remain finite')}}
const close=(a,b,label)=>assert(a.distanceTo(b)<1e-8,label+': '+a.toArray()+' != '+b.toArray());

test('fixed 122-particle pools survive fire, one blast, dust/smoke fade, 5s idle, and reset without allocations',()=>{
 const f=fixture();try{
  const children=[...f.fx.object.children],resources=f.meshes.map(m=>({geometry:m.geometry,material:m.material,particle:m.geometry.attributes.particle,uniforms:m.material.uniforms}));
  assert.deepEqual(f.meshes.map(m=>m.geometry.instanceCount),[24,32,18,16,32]);assert.equal(f.fx.stats().poolCapacity,122);
  f.fx.update(0,cold,0);assert.equal(f.fx.stats().active,false);assert.equal(f.fx.stats().drawCalls,0);assert.equal(f.light.visible,false,'cold pool starts fully hidden');
  f.fx.update(1/60,burn,10);assert.equal(f.fx.stats().flames,24);assert.equal(f.fx.stats().smoke,32);assert.equal(f.fx.stats().embers,32);assert.equal(f.fx.stats().fireball,0);assert(f.light.visible);
  const start=f.uniforms.uSince.value;f.fx.update(1/60,{...burn,destroying:true},10.5);assert(f.uniforms.uSince.value>start,'fatal transition does not restart the burning timeline');
  for(const [age,fireball,dust]of [[0,18,16],[.5,18,16],[1,0,16],[2.3,0,0],[4.5,0,0]]){
   f.fx.update(.1,wreck(age),11+age);assert.equal(f.fx.stats().fireball,fireball);assert.equal(f.fx.stats().dust,dust);assert.equal(f.fx.stats().smoke,32);finiteUniforms(f);
  }
  assert.equal(f.uniforms.uFade.value,.5);f.fx.update(.1,wreck(5),16);assert.equal(f.fx.stats().active,false);assert.equal(f.fx.stats().drawCalls,0);assert.equal(f.light.intensity,0);assert(!f.fx.object.visible);
  const settledUpdates=f.fx.stats().updates;for(let i=0;i<600;i++)f.fx.update(1/60,wreck(6+i/60),17+i/60);assert.equal(f.fx.stats().updates,settledUpdates);
  for(let i=0;i<3;i++){f.fx.reset();assert.equal(f.fx.stats().updates,0);f.fx.update(.1,burn,30+i);assert.equal(f.uniforms.uSince.value,0)}
  assert.deepEqual(f.fx.object.children,children);f.meshes.forEach((m,i)=>{assert.equal(m.geometry,resources[i].geometry);assert.equal(m.material,resources[i].material);assert.equal(m.geometry.attributes.particle,resources[i].particle);assert.equal(m.material.uniforms,resources[i].uniforms)});
 }finally{f.fx.dispose()}
});

test('external explosion suppresses duplicate fireball while vehicle fire and smoke remain',()=>{
 const f=fixture();try{for(const age of [0,.2,.8,1.5]){f.fx.update(.1,{...wreck(age),externalBlast:true},age);assert.equal(f.fx.stats().fireball,0);assert.equal(f.uniforms.uBurst.value,0);assert.equal(f.fx.stats().flames,24);assert.equal(f.fx.stats().smoke,32);finiteUniforms(f)}}finally{f.fx.dispose()}
});

test('world engine anchors follow deformed bay while billboards remain upright under yaw/roll, including no-scene fallback',()=>{
 for(const parent of [true,false]){const f=fixture({parent,groundHeight:(x,z)=>2+x*.002-z*.001});try{
  f.car.object.position.set(15,3,-8);f.car.object.rotation.set(.23,.8,Math.PI*.65);f.car.hood.bay.position.set(.09,-.12,-.46);f.car.object.updateWorldMatrix(true,true);
  const expectedEngine=f.car.hood.bay.localToWorld(new T.Vector3(0,.7,1.3)),expectedCenter=f.car.object.localToWorld(new T.Vector3(0,.65,0));
  f.fx.update(.1,burn,3);close(f.uniforms.uEngine.value,expectedEngine,'engine world anchor');close(f.uniforms.uCenter.value,expectedCenter,'centre world anchor');
  assert.equal(f.uniforms.uGround.value.x,expectedCenter.x);assert.equal(f.uniforms.uGround.value.z,expectedCenter.z);assert(Math.abs(f.uniforms.uGround.value.y-(2+expectedCenter.x*.002-expectedCenter.z*.001+.06))<1e-8);
  f.fx.object.updateWorldMatrix(true,true);close(f.light.getWorldPosition(new T.Vector3()),expectedEngine,'light uses same world emitter');
  for(const m of f.meshes){assert(m.material.vertexShader.includes('viewMatrix*vec4(center,1.)'));assert(!m.material.vertexShader.includes('modelViewMatrix'));assert(!m.material.vertexShader.includes('modelMatrix'));assert(m.material.vertexShader.includes('mv.xy+=position.xy*size'));assert.equal(m.frustumCulled,false)}
  finiteUniforms(f);
 }finally{f.fx.dispose()}}
});

test('direct engine bay uses one root refresh while retaining legacy anchors, ground and light exactly',()=>{
 const height=(x,z)=>1.7+x*.013-z*.021,actual=fixture({groundHeight:height}),reference=fixture({groundHeight:height});try{
  let actualRootRefreshes=0,referenceRootRefreshes=0;
  const actualRefresh=actual.car.object.updateWorldMatrix.bind(actual.car.object),referenceRefresh=reference.car.object.updateWorldMatrix.bind(reference.car.object);
  actual.car.object.updateWorldMatrix=(...args)=>{actualRootRefreshes++;return actualRefresh(...args)};
  reference.car.object.updateWorldMatrix=(...args)=>{referenceRootRefreshes++;return referenceRefresh(...args)};
  const legacyAnchors=()=>{
   const {object}=reference.car,center=new T.Vector3(0,.65,0),engine=new T.Vector3(0,.7,1.3),ground=new T.Vector3();
   object.updateWorldMatrix(true,false);object.localToWorld(center);reference.car.hood.bay.updateWorldMatrix(true,false);reference.car.hood.bay.localToWorld(engine);
   ground.set(center.x,height(center.x,center.z)+.06,center.z);return{engine,center,ground};
  };
  for(const [time,state,position,rotation,bayPosition] of [
   [2,burn,[4,1,-7],[.14,.72,-.35],[.12,-.07,-.44]],
   [2.6,{...burn,destroying:true},[-3,2,5],[.31,-1.18,.62],[-.08,.19,.38]],
   [3.4,wreck(.32),[8,-.5,-2],[-.22,2.41,-.73],[.21,.04,-.17]],
  ]){
   for(const f of [actual,reference]){f.car.object.position.fromArray(position);f.car.object.rotation.fromArray(rotation);f.car.hood.bay.position.fromArray(bayPosition)}
   actualRootRefreshes=0;referenceRootRefreshes=0;const expected=legacyAnchors();actual.fx.update(1/60,state,time);
   assert.equal(referenceRootRefreshes,4,'legacy direct-bay path refreshes the root four times');assert.equal(actualRootRefreshes,1,'optimized direct-bay path refreshes the root once');
   close(actual.uniforms.uEngine.value,expected.engine,'optimized engine anchor');close(actual.uniforms.uCenter.value,expected.center,'optimized centre anchor');close(actual.uniforms.uGround.value,expected.ground,'optimized ground anchor');
   close(actual.light.getWorldPosition(new T.Vector3()),expected.engine,'optimized light anchor');finiteUniforms(actual);
  }
 }finally{actual.fx.dispose();reference.fx.dispose()}
});

test('invalid ground samples cannot put nonfinite coordinates into GPU uniforms',()=>{
 for(const bad of [NaN,Infinity,undefined]){const f=fixture({groundHeight:()=>bad});try{f.fx.update(.1,burn,1);finiteUniforms(f)}finally{f.fx.dispose()}}
});

test('reset retains resources, dispose releases each owned geometry/material once and makes updates inert',()=>{
 const f=fixture(),disposed=new Map();for(const m of f.meshes)for(const resource of [m.geometry,m.material]){disposed.set(resource,0);resource.addEventListener('dispose',()=>disposed.set(resource,disposed.get(resource)+1))}
 f.fx.update(.1,burn,1);f.fx.reset();assert([...disposed.values()].every(n=>n===0));assert.throws(()=>f.fx.update(NaN,burn,1));assert.throws(()=>f.fx.update(.1,burn,Infinity));
 f.fx.dispose();f.fx.dispose();f.fx.update(.1,burn,2);assert.equal(f.fx.object.parent,null);assert([...disposed.values()].every(n=>n===1));assert.equal(f.fx.stats().active,false);assert.equal(f.fx.stats().drawCalls,0);
});
