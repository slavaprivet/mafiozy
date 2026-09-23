import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createStaticRenderBatches} from './static_render_batches.mjs';

const vendor=process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));

class TracedBatchedMesh extends THREE.BatchedMesh{
 setVisibleAt(id,visible){
  const result=super.setVisibleAt(id,visible);
  (this.auditVisibility??=new Map()).set(id,visible);
  return result;
 }
}

const root=new THREE.Group(),geometry=new THREE.BoxGeometry(1,1,1),material=new THREE.MeshStandardMaterial();
const groups=[];
for(let index=0;index<3;index++){
 const group=new THREE.Group(),shell=new THREE.Group(),mesh=new THREE.Mesh(geometry,material);
 group.position.x=index*3;shell.name='StaticShell';mesh.name='NativeOpaqueWall';
 shell.add(mesh);group.add(shell);root.add(group);groups.push({group,shell,mesh});
}
const batches=createStaticRenderBatches({THREE:{...THREE,BatchedMesh:TracedBatchedMesh},root,instances:groups.map(item=>item.group),minInstances:3,maxDistance:100,multiDraw:true});
const batch=root.children.find(node=>node.userData.staticRenderBatch);
assert(batch,'expected one static batch');
const visible=()=>[0,1,2].map(id=>batch.auditVisibility.get(id));
const update=()=>batches.update({focus:new THREE.Vector3(),maxDistance:100});

assert.deepEqual(visible(),[true,true,true]);
groups[0].group.visible=false;update();assert.deepEqual(visible(),[false,true,true],'hidden placement cannot leave a visible batch copy');
groups[0].group.visible=true;update();assert.deepEqual(visible(),[true,true,true],'shown placement restores its batch copy');
groups[1].shell.visible=false;update();assert.deepEqual(visible(),[true,false,true],'hidden intermediate ancestor reaches the batch copy');
groups[1].shell.visible=true;groups[2].mesh.visible=false;update();assert.deepEqual(visible(),[true,true,false],'hidden source mesh reaches the batch copy');
groups[2].mesh.visible=true;update();assert.deepEqual(visible(),[true,true,true]);

batches.dispose();geometry.dispose();material.dispose();
console.log('PASS static render batches preserve live source hierarchy visibility');
