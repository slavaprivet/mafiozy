import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {prepareNpcBlastPalette20} from './npc_blast_palette_prototype20.mjs';
const vendor=process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c);}});
const T=await import(pathToFileURL(vendor+'/build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
async function actorFor(sex){const b=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene;const actor=createNpcActor({THREE:T,scene:new T.Scene(),source,cloneSkeleton:clone,id:sex,sex,height:1.9});actor.update(.016,{time:10,position:{x:3.1,y:2.7,z:-2.2},yaw:.7});return actor;}
// CPU emulation of Three's GPU skinning chunks using the actual frozen Float32
// palette, rather than getVertexPosition's double-precision Bone matrices.
function gpuPoint(mesh,index){
  const g=mesh.geometry,p=new T.Vector3().fromBufferAttribute(g.attributes.position,index);
  if(mesh.isSkinnedMesh){p.applyMatrix4(mesh.bindMatrix);const input=new T.Vector4(p.x,p.y,p.z,1),out=new T.Vector4(0,0,0,0),m=new T.Matrix4();for(let j=0;j<4;j++){m.fromArray(mesh.skeleton.boneMatrices,g.attributes.skinIndex.getComponent(index,j)*16);out.add(input.clone().applyMatrix4(m).multiplyScalar(g.attributes.skinWeight.getComponent(index,j)));}p.set(out.x,out.y,out.z).applyMatrix4(mesh.bindMatrixInverse);}
  return p.applyMatrix4(mesh.matrixWorld);
}
for(const sex of ['male','female'])test(`${sex}: prepared GPU skin pieces equal CPU bake; ownership, pivots and bounded palette`,async()=>{
  const actor=await actorFor(sex),root=actor.walker.artistContext().scene;
  const p0=performance.now(),prepared=prepareNpcBlastPalette20(T,root),prepareMs=performance.now()-p0;
  // Preparation must not freeze an earlier pose.
  actor.update(.11,{time:10.11,position:{x:-4.3,y:1.2,z:5.7},yaw:-1.2,moving:true,speed:3});
  const t0=performance.now(),fx=prepared.freeze(),admitMs=performance.now()-t0;
  assert.equal(fx.parts.length,6);assert(fx.stats.drawCalls<=30);assert.equal(fx.stats.paletteFloats,448);
  const references=[],point=new T.Vector3();let maxGpuError=0,vertices=0;
  for(const pair of fx.pairs){const {source,fragment}=pair,g=fragment.geometry;assert.notEqual(g.attributes.position.array,source.geometry.attributes.position.array);assert.notEqual(fragment.material,source.material);assert.equal(fragment.frustumCulled,false);
    for(const index of new Set(g.index.array)){source.getVertexPosition(index,point).applyMatrix4(source.matrixWorld);const expected=point.clone(),actual=fragment.getVertexPosition(index,new T.Vector3()).applyMatrix4(fragment.matrixWorld);assert(actual.distanceTo(expected)<1e-11);const err=gpuPoint(fragment,index).distanceTo(expected);maxGpuError=Math.max(err,maxGpuError);assert(err<2e-5);references.push({fragment,index,expected});vertices++;}
  }
  assert.throws(()=>prepared.dispose(),/retain/);
  const warm=[],originalVertexGetters=new Map(fx.pairs.map(p=>[p.source,p.source.getVertexPosition]));
  for(const source of originalVertexGetters.keys())source.getVertexPosition=()=>{throw Error('Admission must not bake any vertex');};
  try{for(let i=0;i<40;i++){const start=performance.now(),one=prepared.freeze();warm.push(performance.now()-start);one.dispose();}}finally{for(const [source,getter]of originalVertexGetters)source.getVertexPosition=getter;}
  warm.sort((a,b)=>a-b);
  const fx2=prepared.freeze();assert.throws(()=>prepared.freeze(),/unavailable/);assert.notEqual(fx.skeletons[0].boneMatrices,fx2.skeletons[0].boneMatrices);assert.notEqual(fx.pairs[0].fragment.material,fx2.pairs[0].fragment.material);
  actor.update(.2,{time:10.5,position:{x:100,y:10,z:100},yaw:2.7});actor.dispose();
  fx.group.updateMatrixWorld(true);for(const s of fx.skeletons)s.update();
  for(const {fragment,index,expected}of references)assert(gpuPoint(fragment,index).distanceTo(expected)<2e-5);
  // Independent rigid displacement about the region's own pivot.
  const before=fx.parts.map(p=>p.matrixWorld.clone()),rotation=new T.Quaternion().setFromAxisAngle(new T.Vector3(0,1,0),.83);
  fx.parts[2].quaternion.copy(rotation);fx.parts[2].position.add(new T.Vector3(.3,.8,-.4));fx.group.updateMatrixWorld(true);
  const transform=fx.parts[2].matrixWorld.clone().multiply(before[2].clone().invert());
  for(const {fragment,index,expected}of references){const moved=expected.clone();if(fragment.parent===fx.parts[2])moved.applyMatrix4(transform);assert(gpuPoint(fragment,index).distanceTo(moved)<2e-5);}
  let disposedMaterials=0,disposedSkeletons=0;for(const m of new Set(fx.pairs.map(p=>p.fragment.material)))m.addEventListener('dispose',()=>disposedMaterials++);
  for(const s of fx.skeletons){s.computeBoneTexture();s.boneTexture.addEventListener('dispose',()=>disposedSkeletons++);}
  fx.dispose();fx.dispose();assert(disposedMaterials>0);assert.equal(disposedSkeletons,1);assert.equal(prepared.stats().leases,1);fx2.dispose();prepared.dispose();assert.throws(()=>prepared.freeze(),/unavailable/);
  console.log(JSON.stringify({sex,prepareMs,admitMs,warmFreezeP50Ms:warm[20],warmFreezeP95Ms:warm[38],vertices,maxGpuError,drawCalls:fx.stats.drawCalls,twoVictimDrawCalls:fx.stats.drawCalls*2,paletteFloats:fx.stats.paletteFloats,limits:'CPU shader emulation only; GPU upload/compile, full scene FPS, conservative ground bounds and final seam appearance not accepted'}));
});
