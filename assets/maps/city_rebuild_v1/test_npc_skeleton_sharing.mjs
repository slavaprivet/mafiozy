// CPU-only actual-GLB audit. No WebGL context or renderer is created.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c);}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {clone}=await import('./vendor/three_skeleton_utils.mjs');
const {shareNpcCloneSkeletons}=await import('./npc_skeleton_sharing.mjs');
const {createNpcActor,NPC_ASSETS}=await import('./npc_actor.mjs');
const {applyNpcAppearance,describeNpcAppearance}=await import('./npc_appearance.mjs');
const collect=root=>{const meshes=[];root.traverse(o=>{if(o.isSkinnedMesh)meshes.push(o)});return meshes;};
const skeletons=root=>new Set(collect(root).map(mesh=>mesh.skeleton));
let tests=0;
function check(name,body){body();tests++;console.log('PASS '+name);}
function fixture(){
 const root=new THREE.Group(),bones=[new THREE.Bone(),new THREE.Bone()];root.add(bones[0]);bones[0].add(bones[1]);root.updateMatrixWorld(true);
 const inverses=bones.map(bone=>bone.matrixWorld.clone().invert());
 for(let i=0;i<2;i++){const mesh=new THREE.SkinnedMesh(new THREE.BufferGeometry(),new THREE.MeshBasicMaterial());mesh.bind(new THREE.Skeleton(bones,inverses),new THREE.Matrix4());root.add(mesh);}
 return {root,meshes:collect(root),bones,inverses};
}
check('same-clone exact identities share once; mesh bindings/resources remain untouched',()=>{
 const {root,meshes}=fixture(),state=meshes.map(m=>[m.bindMatrix,m.bindMatrixInverse,m.geometry,m.material,m.matrix,m.matrixWorld]);
 assert.deepEqual(shareNpcCloneSkeletons({THREE,root}),{skinnedMeshes:2,skeletonsBefore:2,skeletonsAfter:1,sharedMeshes:1,skippedSkeletons:0});
 meshes.forEach((m,i)=>assert.deepEqual([m.bindMatrix,m.bindMatrixInverse,m.geometry,m.material,m.matrix,m.matrixWorld],state[i]));
 assert.equal(shareNpcCloneSkeletons({THREE,root}).sharedMeshes,0);
});
for(const [name,mutate]of [
 ['equal-valued but independently owned inverse array',f=>{f.meshes[1].skeleton.boneInverses=f.inverses.slice();}],
 ['same bones in different order',f=>{f.meshes[1].skeleton.bones.reverse();}],
 ['different current bone matrices',f=>{f.meshes[1].skeleton.boneMatrices[0]=1;}],
 ['external/template bone reference',f=>{for(const m of f.meshes)m.skeleton.bones[0]=new THREE.Bone();}],
 ['allocated bone texture',f=>{f.meshes[1].skeleton.computeBoneTexture();}],
 ['custom update method',f=>{f.meshes[1].skeleton.update=function(){};}],
 ['custom disposal method',f=>{f.meshes[1].skeleton.dispose=function(){throw Error('must not call custom dispose')};}],
 ['custom state',f=>{f.meshes[1].skeleton.userData={};}],
 ['custom subclass',f=>{class CustomSkeleton extends THREE.Skeleton{}f.meshes[1].skeleton=new CustomSkeleton(f.bones,f.inverses);}],
])check('skip '+name,()=>{const f=fixture();mutate(f);assert.equal(shareNpcCloneSkeletons({THREE,root:f.root}).sharedMeshes,0);assert.equal(skeletons(f.root).size,2);f.meshes[1].skeleton.boneTexture?.dispose();});
check('reject missing host/root and allow empty clone',()=>{
 assert.throws(()=>shareNpcCloneSkeletons({}));assert.throws(()=>shareNpcCloneSkeletons({THREE}));
 assert.equal(shareNpcCloneSkeletons({THREE,root:new THREE.Group()}).skeletonsAfter,0);
});
const reports=[];
for(const [sex,asset]of Object.entries(NPC_ASSETS)){
 const bytes=fs.readFileSync(new URL(asset.url)),gltf=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
 const source=gltf.scene,sourceMeshes=collect(source),sourceSkeletons=skeletons(source),sourceBones=new Set(sourceMeshes.flatMap(m=>m.skeleton.bones));
 const raw=clone(source),rawMeshes=collect(raw),rawBefore=rawMeshes.length;
 check(sex+' raw clone inverse ARRAY identity and independent bones',()=>{
  assert.equal(rawBefore,sex==='male'?7:5);
  assert(rawMeshes.every(m=>m.skeleton.boneInverses===rawMeshes[0].skeleton.boneInverses));
  assert(rawMeshes.every(m=>m.skeleton.bones.every(b=>!sourceBones.has(b))));
  const result=shareNpcCloneSkeletons({THREE,root:raw});assert.equal(result.skeletonsAfter,1);assert.equal(result.sharedMeshes,rawBefore-1);
 });
 const id='skeleton_sharing_'+sex,descriptor=describeNpcAppearance(id,{sex});
 function make(shared){
  const actor=createNpcActor({THREE,scene:new THREE.Scene(),source,id,sex,height:1.9,appearanceOwnsResources:true,
   cloneSkeleton:template=>{const result=clone(template);if(shared===true)shareNpcCloneSkeletons({THREE,root:result});else if(shared===false)for(const skeleton of skeletons(result))skeleton.auditKeepSeparate=true;return result;},
   applyAppearance:scene=>applyNpcAppearance({THREE,scene,descriptor,cloneTextures:true})});
  for(const skeleton of skeletons(actor.object))delete skeleton.auditKeepSeparate;
  return actor;
 }
 const original=make(false),shared=make(true),a=collect(original.object),b=collect(shared.object),otherBones=new Set(a.flatMap(m=>m.skeleton.bones));
 check(sex+' production actor creation integrates sharing automatically',()=>{
  const automatic=make();assert.equal(skeletons(automatic.object).size,1);automatic.dispose();
 });
 check(sex+' configured actors: four core meshes, 4→1 private skeletons',()=>{
  assert.equal(a.length,4);assert.equal(b.length,4);assert.equal(skeletons(original.object).size,4);assert.equal(skeletons(shared.object).size,1);
  assert(b.every(m=>m.skeleton.bones.every(bone=>!otherBones.has(bone)&&!sourceBones.has(bone))));
  assert(b.every(m=>!sourceSkeletons.has(m.skeleton)));
 });
 let vertices=0,matrixValues=0;
 check(sex+' exact matrices and every posed world vertex across idle/walk/crouch/prone/water/death',()=>{
  const va=new THREE.Vector3(),vb=new THREE.Vector3();
  for(let step=0;step<8;step++){
   const snapshot={time:1+step*.4,position:{x:step*.1,y:0,z:step*.07},yaw:step*.2,moving:step>0,running:step===3,gaitDistance:.15,motionSpeed:1.5,
    posture:{target:step===2?'crouch':step===3?'prone':'stand',value:step===2?1:step===3?2:0},inWater:step===4,waterLevel:step===4?1.8:undefined,chestWorldY:1.13};
   if(step===6){for(const actor of [original,shared])assert(actor.receive({id:'confirmed-death',confirmed:true,dead:true}));}
   original.update(.04,snapshot);shared.update(.04,snapshot);
   for(const actor of [original,shared])for(const skeleton of skeletons(actor.object))skeleton.update();
   for(let mesh=0;mesh<a.length;mesh++){
    assert.equal(a[mesh].name,b[mesh].name);assert.deepEqual(a[mesh].bindMatrix.elements,b[mesh].bindMatrix.elements);assert.deepEqual(a[mesh].bindMatrixInverse.elements,b[mesh].bindMatrixInverse.elements);
    assert.deepEqual(a[mesh].skeleton.boneMatrices,b[mesh].skeleton.boneMatrices);matrixValues+=a[mesh].skeleton.boneMatrices.length;
    for(let index=0;index<a[mesh].geometry.attributes.position.count;index++){
     a[mesh].getVertexPosition(index,va).applyMatrix4(a[mesh].matrixWorld);b[mesh].getVertexPosition(index,vb).applyMatrix4(b[mesh].matrixWorld);
     assert(va.equals(vb),`${sex} pose ${step} mesh ${mesh} vertex ${index}`);vertices++;
    }
   }
  }
 });
 const report={sex,rawSkeletons:rawBefore,actorSkeletonsBefore:4,actorSkeletonsAfter:1,vertices,matrixValues};
 if(process.argv.includes('--benchmark')){
  const before=[...skeletons(original.object)],after=[...skeletons(shared.object)],times={before:[],after:[]};
  for(let i=0;i<480;i++)for(const key of i%2?['after','before']:['before','after']){const list=key==='before'?before:after,start=performance.now();for(const skeleton of list)skeleton.update();const elapsed=performance.now()-start;if(i>=80)times[key].push(elapsed);}
  report.rendererStyleCpuMs=Object.fromEntries(Object.entries(times).map(([key,values])=>{values.sort((a,b)=>a-b);return [key,{p50:values[Math.floor(values.length*.5)],p95:values[Math.floor(values.length*.95)]}];}));
 }
 check(sex+' CPU bone texture allocation 4→1; dispose one actor leaves other and source intact',()=>{
  const originals=[...skeletons(original.object)],sharedSkeletons=[...skeletons(shared.object)];let disposed=0;
  for(const skeleton of [...originals,...sharedSkeletons]){skeleton.computeBoneTexture();skeleton.boneTexture.addEventListener('dispose',()=>disposed++);}
  const beforeTexture=originals[0].boneTexture;shared.dispose();shared.dispose();assert.equal(disposed,1);assert.equal(originals[0].boneTexture,beforeTexture);
  assert(sourceMeshes.every(m=>m.skeleton.boneTexture===null));original.update(.04,{time:5});original.dispose();original.dispose();assert.equal(disposed,5);
 });
 reports.push(report);
}
console.log(JSON.stringify({tests,reports,scope:'CPU only: renderer-style Skeleton.update, not total actor CPU, GPU time or FPS'},null,2));
