import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {createInteriorSafe} from './interior_interactive_safe.mjs';
const T=await import(pathToFileURL(process.env.MAFIOZY_THREE||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const RADIUS=.18*4.1;
function distance(p,polygon){
 let inside=false,min=Infinity;
 for(let i=0,j=polygon.length-1;i<polygon.length;j=i++){
  const a=polygon[j],b=polygon[i],dx=b[0]-a[0],dz=b[1]-a[1],t=Math.max(0,Math.min(1,((p.x-a[0])*dx+(p.z-a[1])*dz)/(dx*dx+dz*dz)));
  min=Math.min(min,Math.hypot(p.x-a[0]-t*dx,p.z-a[1]-t*dz));
  if((a[1]>p.z)!==(b[1]>p.z)&&p.x<(b[0]-a[0])*(p.z-a[1])/(b[1]-a[1])+a[0])inside=!inside;
 }
 return inside?0:min;
}
const collisionDistance=(safe,p)=>Math.min(...safe.getCollisionBodies().map(b=>distance(p,b.polygonCR.map(v=>v.map(n=>n*4.1)))));
function make(options={}){return createInteriorSafe(T,{id:'clearance',buildingId:'test',roomId:'manager',onUnlock:()=>({ok:true,opened:true,lootDropped:true}),...options});}

test('old immediate opening reproduces the real .738 m body trap; full rendered leaf fits guard disc',async()=>{
 const safe=make();try{
  const p=safe.object.userData.mercenaryTarget.getApproachPosition();assert(collisionDistance(safe,p)>RADIUS);
  const mesh=safe.object.getObjectByName('Safe_Hinged_Door'),v=mesh.geometry.attributes.position;
  for(let i=0;i<v.count;i++)assert(Math.hypot(v.getX(i),v.getZ(i))<=.8,'all visible wheel/bars also fit the guard');
  await safe.unlock();let minimum=Infinity;for(let i=0;i<200;i++){safe.update(.005);minimum=Math.min(minimum,collisionDistance(safe,p));}
  assert(minimum<RADIUS,'regression fixture must actually reproduce the obstruction');
 }finally{safe.dispose();}
});

test('accepted unlock leaves the operator a physical exit before the .85 s opening, at every approach tolerance and world yaw',async()=>{
 for(const yaw of[0,Math.PI/2,Math.PI,.43])for(let a=0;a<8;a++){
  let actor,received;
  const safe=make({position:[155.76,2,173.40],yaw,onUnlock:(_,detail)=>{received=detail.context;return {ok:true,opened:true,lootDropped:true};}});
  try{
   const local=new T.Vector3(Math.cos(a*Math.PI/4)*.08,0,1.34+Math.sin(a*Math.PI/4)*.08),start=local.clone();
   actor=safe.object.localToWorld(local.clone());const read=id=>{assert.equal(id,'operator');return actor;};
   const receipt=await safe.unlock({memberId:'operator',getOperatorPosition:read});assert(receipt.ok);assert.equal(received.getOperatorPosition,undefined,'presentation closure never enters authoritative ledger');
   for(let i=0;i<100;i++)safe.update(.016);
   assert.equal(safe.getState().waitingForOperator,true);assert.equal(safe.getState().openFraction,0,'no early leaf movement into body');assert(!safe.lootBag.visible);
   assert(collisionDistance(safe,actor)>RADIUS);
   // A real swept departure toward the old LIVE follow goal (safe-local -7,+4).
   // No position replacement in production; this fixture samples the normal path.
   const end=new T.Vector3(-7,0,4);
   for(let step=1;step<=500;step++){
    actor=safe.object.localToWorld(start.clone().lerp(end,step/500));
    assert(collisionDistance(safe,actor)>=RADIUS,'old collider permits next physical step');
    safe.update(.005);
    assert(collisionDistance(safe,actor)>=RADIUS,'moving leaf does not enter source body');
   }
   for(let i=0;i<200;i++)safe.update(.005);
   assert.equal(safe.getState().openFraction,1);assert.equal(safe.getState().waitingForOperator,false);assert(safe.lootBag.visible);
  }finally{safe.dispose();}
 }
});

test('opening pauses safely if the operator returns; absent and other-floor actors cannot permanently lock presentation',async()=>{
 for(const scenario of['return','absent','other-floor']){
  const safe=make();let actor=safe.object.userData.mercenaryTarget.getApproachPosition();
  try{
   await safe.unlock({memberId:'operator',getOperatorPosition:()=>actor});safe.update(.1);assert.equal(safe.getState().openFraction,0);
   actor=scenario==='absent'?null:scenario==='other-floor'?new T.Vector3(0,4,1.34):new T.Vector3(0,0,4);safe.update(.1);assert(safe.getState().openFraction>0);
   if(scenario==='return'){
    const old=safe.getState().openFraction;actor=new T.Vector3(0,0,1.34);safe.update(.1);assert.equal(safe.getState().openFraction,old);actor.set(0,0,4);
   }
   for(let i=0;i<30;i++)safe.update(.1);assert.equal(safe.getState().openFraction,1);assert.equal(safe.needsUpdate,false);
  }finally{safe.dispose();}
 }
});

test('waiting guard has bounded CPU work and never rebuilds stationary collision geometry',async()=>{
 const safe=make(),actor=safe.object.userData.mercenaryTarget.getApproachPosition(),samples=[];
 try{
  await safe.unlock({memberId:'operator',getOperatorPosition:()=>actor});const bodies=safe.getCollisionBodies(),before=safe.stats();
  for(let i=0;i<4000;i++){const start=performance.now();safe.update(.016);if(i>=500)samples.push(performance.now()-start);assert.equal(safe.getCollisionBodies(),bodies);}
  samples.sort((a,b)=>a-b);const after=safe.stats();assert.equal(after.colliderBuilds,before.colliderBuilds);assert.equal(after.draws,before.draws);assert.equal(after.triangles,before.triangles);
  console.log(JSON.stringify({scenario:'one guarded safe, CPU only; no renderer',guardP50Ms:samples[Math.floor(samples.length*.5)],guardP95Ms:samples[Math.floor(samples.length*.95)],draws:after.draws,triangles:after.triangles,limitation:'Loaded scene performance not verified'}));
 }finally{safe.dispose();}
});
