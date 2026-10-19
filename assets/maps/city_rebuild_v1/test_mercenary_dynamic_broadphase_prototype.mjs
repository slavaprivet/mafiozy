// CPU-only experiment, deliberately NOT imported by runtime. No cached owner
// contract exists here: audit every query, use the same native sphere/matrix
// snapshots as Mesh.raycast, and fall back for the entire query on custom code.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {ARTIST_VEHICLE_PROFILES,createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createVehicleRenderBatches} from './vehicle_render_batches.mjs';
const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const native={ray:T.Mesh.prototype.raycast,compute:T.Mesh.prototype._computeIntersections,vertex:T.Mesh.prototype.getVertexPosition,empty:T.Object3D.prototype.raycast};
const sphere=new T.Sphere(),extent=new T.Vector3(),minimum=new T.Vector3();
function broadphase(ray,roots){
 let nodes=0,unknown=0;const groups=[];
 function visit(node,list){
  nodes++;
  if(node.isMesh){
   if(node.raycast!==native.ray||node._computeIntersections!==native.compute||node.getVertexPosition!==native.vertex||node.isSkinnedMesh||node.isInstancedMesh||node.isBatchedMesh||!node.geometry?.boundingSphere)unknown++;
   else list.push(node);
  }else if(node.raycast!==native.empty)unknown++;
  for(const child of node.children)visit(child,list);
 }
 for(const root of roots){const meshes=[];visit(root,meshes);groups.push({root,meshes});}
 // A custom callback can alter another root or emit a hit outside its subtree.
 // Falling back merely its own root is insufficient to preserve ordering.
 if(unknown)return {roots,nodes,unknown,retained:roots.length};
 const selected=[];
 for(const {root,meshes} of groups){const box=new T.Box3();for(const mesh of meshes){sphere.copy(mesh.geometry.boundingSphere).applyMatrix4(mesh.matrixWorld);extent.setScalar(sphere.radius);box.expandByPoint(minimum.copy(sphere.center).sub(extent));box.expandByPoint(extent.add(sphere.center));}
  if(!Number.isFinite(box.min.x)||!Number.isFinite(box.max.x)||ray.ray.intersectsBox(box))selected.push(root);
 }
 return {roots:selected,nodes,unknown,retained:selected.length};
}
const ray=new T.Raycaster(new T.Vector3(0,1,15),new T.Vector3(0,0,-1),0,80);
const visible=o=>{for(let n=o;n;n=n.parent)if(n.visible===false)return false;return true;};
const signature=hits=>hits.filter(h=>visible(h.object)&&!h.object.userData.mercenaryPickIgnore).map(h=>[h.object.uuid,h.distance,h.faceIndex,h.instanceId,h.point.toArray()]);
let cases=0;
function parity(roots){assert.deepEqual(signature(ray.intersectObjects(broadphase(ray,roots).roots,true)),signature(ray.intersectObjects(roots,true)));cases++;}
const geometry=new T.BoxGeometry(1,2,1);geometry.computeBoundingSphere();const material=new T.MeshBasicMaterial();
const group=new T.Group(),door=new T.Group(),mesh=new T.Mesh(geometry,material);door.add(mesh);group.add(door);group.updateMatrixWorld(true);
parity([group,group]);group.position.x=20;parity([group]);group.updateMatrixWorld(true);parity([group]);door.position.x=-20;door.rotation.y=.8;group.updateMatrixWorld(true);parity([group]);
mesh.visible=false;parity([group]);mesh.visible=true;material.transparent=true;material.opacity=.2;material.visible=false;parity([group]);
door.remove(mesh);const replacement=new T.Mesh(geometry,material);door.add(replacement);group.updateMatrixWorld(true);parity([group]);replacement.layers.set(2);parity([group]);replacement.layers.set(0);replacement.userData.mercenaryPickIgnore=true;parity([group]);
const custom=new T.Group(),external=new T.Mesh(geometry,material);custom.raycast=(_ray,out)=>out.push({object:external,distance:1,faceIndex:0,point:new T.Vector3()});assert.equal(broadphase(ray,[group,custom]).unknown,1);parity([group,custom]);
custom.raycast=()=>false;custom.add(new T.Mesh(geometry,material));custom.updateMatrixWorld(true);parity([custom,group]);custom.layers.set(2);parity([custom,group]);
// Use one actual factory vehicle, 32 distinct transformed object graphs. This
// is not a live 32-model fleet or an FPS benchmark. Include the audit itself.
const profile=ARTIST_VEHICLE_PROFILES[0],bytes=fs.readFileSync(new URL('./models/artist_vehicle_pack/'+profile.modelFile,import.meta.url));
const gltf=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
const car=createArtistVehicle(T,RoundedBoxGeometry,gltf.scene,profile);
car.object.traverse(n=>{if(n.isMesh&&!n.geometry.boundingSphere)n.geometry.computeBoundingSphere()});
const roots=Array.from({length:32},(_,i)=>{const root=car.object.clone(true);root.position.set(i===0?0:10+i*5,0,-i);root.updateMatrixWorld(true);return root});
parity(roots);const census=broadphase(ray,roots);
const quantile=(values,p)=>[...values].sort((a,b)=>a-b)[Math.floor((values.length-1)*p)];
function measure(fn){const times=[];for(let i=0;i<16;i++){const start=performance.now();fn();if(i>=4)times.push(performance.now()-start)}return {p50:quantile(times,.5),p95:quantile(times,.95)}}
const before=measure(()=>ray.intersectObjects(roots,true));
const auditPlusQuery=measure(()=>ray.intersectObjects(broadphase(ray,roots).roots,true));
const auditOnly=measure(()=>broadphase(ray,roots));
const batcher=createVehicleRenderBatches({THREE:T,root:car.object,includeBody:true,includeDoors:true});car.object.updateMatrixWorld(true);
const batched=broadphase(ray,[car.object]);parity([car.object]);assert(batched.unknown>0,'actual render batches require an explicit trusted-noop identity contract');batcher.dispose();
console.log(JSON.stringify({cases,model:profile.id,raw32:{nodes:census.nodes,unknown:census.unknown,retained:census.retained,beforeMs:before,auditPlusQueryMs:auditPlusQuery,auditOnlyMs:auditOnly},actualBatchedOne:{unknown:batched.unknown,nodes:batched.nodes,retained:batched.retained},scope:'CPU only; full fresh audit + native sphere union + native query, no GPU/FPS; matrices deliberately never refreshed by the query'}));
