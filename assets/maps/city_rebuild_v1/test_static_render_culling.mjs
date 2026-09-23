import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createStaticRenderBatches} from './static_render_batches.mjs';
const T=await import(pathToFileURL((process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/')+'build/three.module.js'));
const reports=[];
for(const fallback of [false,true]){
 const scene=new T.Scene(),root=new T.Group(),instances=[],parts=10,count=20;
 scene.add(root);
 const geometry=new T.BoxGeometry(1,1,1),material=new T.MeshStandardMaterial();
 let distances=0,writes=0;
 for(let i=0;i<count;i++){
  const group=new T.Group();group.position.set(i*5,0,0);root.add(group);instances.push(group);
  for(let j=0;j<parts;j++){const mesh=new T.Mesh(geometry,material);mesh.position.z=j;group.add(mesh)}
  const original=group.position.distanceToSquared;
  group.position.distanceToSquared=function(p){distances++;return original.call(this,p)};
 }
 const api=createStaticRenderBatches({THREE:fallback?{...T,BatchedMesh:undefined}:T,root,instances,minInstances:3,multiDraw:true});
 const batch=root.children.find(n=>n.userData.staticRenderBatch);
 assert.equal(api.stats().members,count*parts);
 const method=fallback?'setMatrixAt':'setVisibleAt',original=batch[method];
 batch[method]=function(...args){writes++;return original.apply(this,args)};
 const matrix=new T.Matrix4(),previous=Array(count).fill(true);
 let referenceWrites=0;
 for(let frame=0;frame<240;frame++){
  const x=frame<100?0:Math.floor((frame-100)/7)*8,focus=frame===200?undefined:new T.Vector3(x,0,0),maxDistance=frame===150?5:20;
  const expected=instances.map(group=>!focus||(group.position.x-x)**2<maxDistance**2);
  const changed=expected.reduce((n,show,i)=>n+(show!==previous[i]?parts:0),0),beforeWrites=writes,beforeDistances=distances,version=batch.instanceMatrix?.version;
  const result=api.update({focus,maxDistance});
  assert.equal(result.visible,expected.filter(Boolean).length*parts);
  assert.equal(result.activeBatches,result.visible?1:0);
  assert.equal(distances-beforeDistances,focus?count:0,'one distance per placement');
  assert.equal(writes-beforeWrites,changed,'only changed visibility is uploaded');
  if(fallback&&changed===0)assert.equal(batch.instanceMatrix.version,version,'unchanged matrix buffer stays clean');
  for(let i=0;i<count;i++)for(let j=0;j<parts;j++){
   const id=i*parts+j;
   if(!fallback)assert.equal(batch.getVisibleAt(id),expected[i]);
   else{
    batch.getMatrixAt(id,matrix);
    assert.equal(matrix.elements[0],expected[i]?1:0);
    if(expected[i]){assert.equal(matrix.elements[12],i*5);assert.equal(matrix.elements[14],j)}
   }
  }
  expected.forEach((show,i)=>previous[i]=show);referenceWrites+=count*parts;
 }
 api.dispose();assert.equal(api.stats().members,0);
 assert(instances.every(group=>group.children.every(mesh=>mesh.material===material)));
 geometry.dispose();material.dispose();
 reports.push({mode:fallback?'InstancedMesh':'BatchedMesh',updates:240,referenceWrites,actualWrites:writes,distanceTests:distances});
}
console.log('PASS exact culling at boundary, travel, repeated focus, reset and fallback',JSON.stringify(reports));
