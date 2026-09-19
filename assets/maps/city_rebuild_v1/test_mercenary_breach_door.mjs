import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {createMercenaryBreachDoor} from './mercenary_breach_door.mjs';
const T=await import(pathToFileURL(process.env.MAFIOZY_THREE||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
function distance(p,polygon){let inside=false,min=Infinity;for(let i=0,j=polygon.length-1;i<polygon.length;j=i++){const a=polygon[j],b=polygon[i],dx=b[0]-a[0],dz=b[1]-a[1],t=Math.max(0,Math.min(1,((p.x-a[0])*dx+(p.z-a[1])*dz)/(dx*dx+dz*dz)));min=Math.min(min,Math.hypot(p.x-a[0]-t*dx,p.z-a[1]-t*dz));if((a[1]>p.z)!==(b[1]>p.z)&&p.x<(b[0]-a[0])*(p.z-a[1])/(b[1]-a[1])+a[0])inside=!inside;}return inside?0:min;}
const clear=(door,p)=>door.colliders.filter(b=>b.minYM<p.y+1.9&&b.maxYM>p.y).every(b=>distance(p,b.polygonCR.map(v=>v.map(n=>n*4.1)))>=.738);
const fixture=(options={})=>createMercenaryBreachDoor({THREE:T,site:{id:'door-test',x:20,y:2,z:30},onCollisionChange:()=>true,...options});

test('refused physical transaction keeps real locked door; accepted kick/bomb happens once',()=>{
 let allowed=false,changes=0,blasts=0;const door=fixture({onCollisionChange:()=>{changes++;return allowed;},onBlast:()=>blasts++});
 try{
  assert.equal(door.breakOpen().ok,false);assert.equal(door.getState().locked,true);assert.equal(door.leaf.rotation.y,0);
  allowed=true;assert.equal(door.blast({targetId:'other'}).reason,'wrong_target');assert.equal(door.blast({targetId:'door-test',actionId:3}).ok,true);assert.equal(blasts,1);
  assert.equal(door.blast({actionId:3}).duplicate,true);assert.equal(door.breakOpen({actionId:4}).duplicate,true);assert.equal(blasts,1);assert.equal(changes,2);
  for(let i=0;i<60;i++)door.update(1/60);assert.equal(changes,3,'two accepted collision transactions total');assert.equal(door.getState().opening,false);assert.equal(door.getState().locked,false);assert(door.leaf.rotation.y< -Math.PI/2);
  const meta=door.object.userData.mercenaryTarget;assert.equal(meta.breachable,false);assert.equal(meta.bombable,false);assert.equal(meta.opened,true);assert(door.object.getObjectByName('Broken_Lock_Fragment').visible);assert(!door.object.getObjectByName('Breakable_Lock_Strike').visible);
 }finally{door.dispose();}assert.equal(door.breakOpen().reason,'disposed');
});

test('door opens away from operator, keeps .738 m body clear at all tolerance edges, and final passage is physically traversable',()=>{
 for(const yaw of[0,Math.PI/2,Math.PI,.4]){
  const door=fixture({site:{id:'door-test',x:20,y:2,z:30,yaw}});
  try{
   const points=[];for(let n=0;n<16;n++)points.push(door.object.localToWorld(new T.Vector3(.6+.08*Math.cos(n*Math.PI/8),0,-1.08+.08*Math.sin(n*Math.PI/8))));
   for(const p of points)assert(clear(door,p));assert.equal(door.breakOpen().ok,true);for(const p of points)assert(clear(door,p),'sweep reservation leaves working point free');
   for(let i=0;i<160;i++){door.update(.005);for(const p of points)assert(clear(door,p));}
   for(let z=-2;z<3;z+=.02)assert(clear(door,door.object.localToWorld(new T.Vector3(0,0,z))),'1.476 m diameter body fits opened passage');
   const target=door.object.userData.mercenaryTarget;assert.equal(target.workRange,.08);assert(Math.abs(target.getWorkPoint().y-2.85)<1e-6);assert(target.getWorkNormal().length()>.99);
  }finally{door.dispose();}
 }
});

test('animation reserves entire rendered leaf sweep, never creates per-frame geometry and settles idle',()=>{
 let changes=0;const door=fixture({onCollisionChange:()=>{changes++;return true;}}),samples=[];
 try{
  door.breakOpen();const bounds=door.colliders.at(-1).polygonCR.map(v=>v.map(n=>n*4.1));
  for(let i=0;i<160;i++){
   const start=performance.now();door.update(.005);samples.push(performance.now()-start);door.object.updateMatrixWorld(true);
   door.leaf.traverse(mesh=>{if(!mesh.isInstancedMesh)return;const matrix=new T.Matrix4(),p=new T.Vector3(),a=mesh.geometry.attributes.position;for(let j=0;j<mesh.count;j++){mesh.getMatrixAt(j,matrix);matrix.premultiply(mesh.matrixWorld);for(let k=0;k<a.count;k++){p.fromBufferAttribute(a,k).applyMatrix4(matrix);assert(distance(p,bounds)<1e-6,'rendered plank/handle stays inside reserved arc');}}});
  }
  assert.equal(changes,2);for(let i=0;i<100;i++)assert.equal(door.update(.1),false);samples.sort((a,b)=>a-b);let draws=0,triangles=0;door.object.traverseVisible(mesh=>{if(mesh.isMesh&&mesh.material?.visible!==false){draws++;triangles+=mesh.geometry.index.count/3*(mesh.count||1);}});console.log(JSON.stringify({scenario:'QA door animation CPU only',p50Ms:samples[80],p95Ms:samples[152],collisionTransactions:changes,draws,triangles,limitation:'Loaded scene performance not verified'}));
 }finally{door.dispose();}
});
