// Dedicated opt-in presentation of the five factory-owned wheel material roles.
// Source objects remain in the actual steering/spinning hierarchy for gameplay.
import {getVehicleWheelRenderBinding} from './vehicle_wheels.mjs';
import {registerVehicleRenderSourceMaterial,unregisterVehicleRenderSourceMaterial} from './vehicle_render_batches.mjs';

const managers=new WeakMap(),ids=new Set(['front_left','front_right','rear_left','rear_right']);
const materialStamp=m=>[m.version,m.visible,m.opacity,m.transparent,m.transmission,m.side,m.color?.r,m.color?.g,m.color?.b,m.emissive?.r,m.emissive?.g,m.emissive?.b,m.emissiveIntensity,m.roughness,m.metalness,m.depthWrite,m.depthTest,m.alphaTest,m.map,m.normalMap,m.roughnessMap,m.metalnessMap,m.emissiveMap,m.alphaMap,m.aoMap,m.lightMap,m.envMap,m.wireframe,m.vertexColors,m.flatShading,m.toneMapped,m.blending,m.polygonOffset,m.polygonOffsetFactor,m.polygonOffsetUnits,m.onBeforeCompile,m.displacementMap];
const same=(a,b)=>a.length===b.length&&a.every((v,i)=>v===b[i]);
const stampGeometry=g=>({index:g.index,indexVersion:g.index?.version,start:g.drawRange.start,count:g.drawRange.count,attributes:Object.keys(g.attributes).map(key=>{const a=g.attributes[key];return {key,attribute:a,version:a.version,array:a.array,count:a.count,itemSize:a.itemSize,normalized:a.normalized};})});
function unchanged(g,stamp){
 if(g.index!==stamp.index||g.index?.version!==stamp.indexVersion||g.drawRange.start!==stamp.start||g.drawRange.count!==stamp.count||Object.keys(g.morphAttributes||{}).length)return false;
 let count=0;for(const key in g.attributes)count++;if(count!==stamp.attributes.length)return false;
 for(const s of stamp.attributes){const a=g.attributes[s.key];if(a!==s.attribute||a.version!==s.version||a.array!==s.array||a.count!==s.count||a.itemSize!==s.itemSize||a.normalized!==s.normalized)return false;}return true;
}
function layout(g){
 if(!g?.attributes?.position||g.drawRange.start!==0||g.drawRange.count!==Infinity||Object.keys(g.morphAttributes||{}).length)return null;
 for(const a of Object.values(g.attributes))if(a.isInterleavedBufferAttribute||a.isGLBufferAttribute)return null;
 return [g.index?'indexed':'plain',...Object.keys(g.attributes).sort().map(k=>{const a=g.attributes[k];return [k,a.itemSize,a.normalized,a.array.constructor.name].join(':');})].join('|');
}
export function setVehicleWheelRenderOptimization(root,enabled){return managers.get(root)?.setEnabled(enabled)??null;}
export function createVehicleWheelRenderBatches({THREE:T,car,multiDraw=false,enabled=true}={}){
 const root=car?.object;if(!root?.isObject3D||!Array.isArray(car.wheels))throw Error('Wheel batching requires an actual vehicle');
 if(managers.has(root))throw Error('Wheel batching already owns this vehicle');
 const available=!!multiDraw&&!!T?.BatchedMesh,entries=[],ownedHidden=new Set(),scratch=available?new T.Matrix4():null;
 let disposed=false,active=available&&!!enabled;
 const stats={available,enabled:active,batches:0,members:0,activeBatches:0,activeMembers:0,fallbackMembers:0};
 const supportedMaterial=m=>m?.isMeshStandardMaterial&&!m.transparent&&m.opacity===1&&!(m.transmission>0)&&!m.displacementMap&&m.onBeforeCompile===T.Material.prototype.onBeforeCompile;
 const defaultCallbacks=mesh=>['onBeforeRender','onAfterRender','onBeforeShadow','onAfterShadow'].every(key=>mesh[key]===T.Object3D.prototype[key]);
 function localMatrix(mesh,target){target.identity();for(let n=mesh;n&&n!==root;n=n.parent){if(n.matrixAutoUpdate)n.updateMatrix();target.premultiply(n.matrix);}return target;}
 function owned(member){
  const {mesh,binding,wheel,parent,ancestry}=member;
  if(mesh.parent!==parent||getVehicleWheelRenderBinding(mesh)!==binding||binding.palette.owner!==root||binding.wheel!==wheel.wheel||binding.id!==wheel.id||mesh.userData.vehicleWheelId!==wheel.id||wheel.wheel.parent!==wheel.pivot||wheel.pivot.parent!==root)return false;
  let n=mesh,reachedWheel=false;
  for(const saved of ancestry){if(n!==saved.node||n.parent!==saved.parent||n.userData.detached||n.userData.crashDetached||n.userData.detachedVehiclePart||n.userData.damagePart)return false;if(n===wheel.wheel)reachedWheel=true;n=n.parent;}
  return n===root&&reachedWheel;
 }
 function visible(mesh){for(let n=mesh;n&&n!==root;n=n.parent)if(!n.visible)return false;return true;}
 try{if(available){
  const groups=new Map();
  for(const wheel of car.wheels){
   if(!ids.has(wheel.id)||wheel.pivot?.parent!==root||wheel.wheel?.parent!==wheel.pivot)continue;
   wheel.wheel.traverse(mesh=>{
    const binding=getVehicleWheelRenderBinding(mesh),keyLayout=layout(mesh.geometry);
    if(!binding||!keyLayout||!mesh.isMesh||mesh.isSkinnedMesh||mesh.isInstancedMesh||mesh.isBatchedMesh||binding.palette.owner!==root||binding.wheel!==wheel.wheel||binding.id!==wheel.id||mesh.material!==binding.palette.materials[binding.role]||!supportedMaterial(mesh.material)||!defaultCallbacks(mesh)||mesh.customDepthMaterial||mesh.customDistanceMaterial)return;
    const ancestry=[];for(let n=mesh;n&&n!==root;n=n.parent)ancestry.push({node:n,parent:n.parent});
    const member={mesh,binding,wheel,parent:mesh.parent,ancestry,geometry:mesh.geometry,stamp:stampGeometry(mesh.geometry),matrix:localMatrix(mesh,new T.Matrix4()),active:true,shown:null};
    if(!owned(member)||member.matrix.determinant()<=0)return;
    const key=[mesh.material.uuid,binding.role,keyLayout,mesh.castShadow,mesh.receiveShadow,mesh.renderOrder,mesh.layers.mask].join('|');
    let entry=groups.get(key);if(!entry){entry={material:mesh.material,members:[],geometries:new Map()};groups.set(key,entry);}
    entry.members.push(member);entry.geometries.set(mesh.geometry,0);
   });
  }
  for(const entry of groups.values()){
   if(entry.members.length<2)continue;
   let vertices=0,indices=0;for(const g of entry.geometries.keys()){vertices+=g.attributes.position.count;indices+=g.index?.count||0;}
   const sample=entry.members[0].mesh,batch=new T.BatchedMesh(entry.members.length,vertices,indices||vertices*2,entry.material);
   batch.name='Vehicle_Wheel_Render_Batch';batch.userData.vehicleRenderBatch=true;batch.userData.vehicleWheelRenderBatch=true;batch.userData.vehicleWheelId='render_batch';batch.castShadow=sample.castShadow;batch.receiveShadow=sample.receiveShadow;batch.renderOrder=sample.renderOrder;batch.layers.mask=sample.layers.mask;batch.raycast=()=>{};
   const hidden=entry.material.clone();hidden.visible=false;entry.hidden=hidden;entry.hiddenStamp=materialStamp(hidden);entry.batch=batch;ownedHidden.add(hidden);entries.push(entry);
   for(const g of entry.geometries.keys())entry.geometries.set(g,batch.addGeometry(g));
   for(const member of entry.members){member.id=batch.addInstance(entry.geometries.get(member.geometry));batch.setMatrixAt(member.id,member.matrix);registerVehicleRenderSourceMaterial(member.mesh,hidden,entry.material);member.registered=true;if(active)member.mesh.material=hidden;}
   batch.computeBoundingBox();batch.computeBoundingSphere();root.add(batch);stats.members+=entry.members.length;
  }
 }}catch(error){
  for(const entry of entries){for(const member of entry.members)if(member.registered){if(member.mesh.material===entry.hidden)member.mesh.material=entry.material;unregisterVehicleRenderSourceMaterial(member.mesh,entry.hidden);}entry.batch.removeFromParent();entry.batch.dispose();}
  for(const hidden of ownedHidden)hidden.dispose();throw error;
 }
 stats.batches=entries.length;
 function fallback(entry,member,hiddenChanged){
  member.active=false;entry.batch.setVisibleAt(member.id,false);stats.fallbackMembers++;unregisterVehicleRenderSourceMaterial(member.mesh,entry.hidden);
  if(member.mesh.material===entry.hidden){if(hiddenChanged){entry.hidden.visible=entry.material.visible;ownedHidden.delete(entry.hidden);}else member.mesh.material=entry.material;}
 }
 function update(){
  if(disposed)return stats;stats.activeBatches=stats.activeMembers=0;
  for(const entry of entries){
   const hiddenChanged=!same(materialStamp(entry.hidden),entry.hiddenStamp);let shown=0,matricesChanged=false;
   for(const member of entry.members){
    if(!member.active)continue;const mesh=member.mesh;
    if(hiddenChanged||!owned(member)||mesh.material!==(active?entry.hidden:entry.material)||!supportedMaterial(entry.material)||mesh.geometry!==member.geometry||!unchanged(mesh.geometry,member.stamp)||mesh.castShadow!==entry.batch.castShadow||mesh.receiveShadow!==entry.batch.receiveShadow||mesh.renderOrder!==entry.batch.renderOrder||mesh.layers.mask!==entry.batch.layers.mask||!defaultCallbacks(mesh)||mesh.customDepthMaterial||mesh.customDistanceMaterial){fallback(entry,member,hiddenChanged);continue;}
    const show=visible(mesh);if(member.shown!==show){entry.batch.setVisibleAt(member.id,show);member.shown=show;}
    if(show){localMatrix(mesh,scratch);if(scratch.determinant()<=0){fallback(entry,member,false);continue;}shown++;if(!scratch.equals(member.matrix)){member.matrix.copy(scratch);entry.batch.setMatrixAt(member.id,scratch);matricesChanged=true;}}
   }
   entry.batch.visible=active&&shown>0;if(entry.batch.visible){stats.activeBatches++;stats.activeMembers+=shown;}
   if(matricesChanged){entry.batch.computeBoundingBox();entry.batch.computeBoundingSphere();}
  }
  return stats;
 }
 function setEnabled(value){
  if(disposed)return null;value=available&&!!value;if(value===active)return active;
  update();for(const entry of entries)for(const member of entry.members)if(member.active)member.mesh.material=value?entry.hidden:entry.material;
  active=value;stats.enabled=active;update();return active;
 }
 function dispose(){
  if(disposed)return;disposed=true;
  for(const entry of entries){for(const member of entry.members){unregisterVehicleRenderSourceMaterial(member.mesh,entry.hidden);if(member.active&&member.mesh.material===entry.hidden)member.mesh.material=entry.material;}entry.batch.removeFromParent();entry.batch.dispose();}
  for(const hidden of ownedHidden)hidden.dispose();ownedHidden.clear();stats.activeBatches=stats.activeMembers=0;if(managers.get(root)===api)managers.delete(root);
 }
 const api={stats,update,setEnabled,dispose};managers.set(root,api);update();return api;
}
