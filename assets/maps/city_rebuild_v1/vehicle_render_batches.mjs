// Presentation-only batching of stationary cabin parts. The owning car and
// Interior_* hierarchy stay intact; movable/repairable assemblies stay separate.
const moving=/(?:Steering|Wheel|Door|Hinge|Engine|Hood|Trunk|Damage|Detached|Glass|Window|Light|Lamp|Gauge_needle|Gear_lever|Pedal)/i;
const geometryStamp=g=>[g.uuid,g.index?.version,g.drawRange.start,g.drawRange.count,...Object.keys(g.attributes).sort().flatMap(k=>{const a=g.attributes[k];return[k,a.count,a.version,a.array]})];
const sameStamp=(a,b)=>a.length===b.length&&a.every((v,i)=>v===b[i]);
const materialStamp=m=>[m.version,m.visible,m.opacity,m.transparent,m.transmission,m.side,m.color?.r,m.color?.g,m.color?.b,m.emissive?.r,m.emissive?.g,m.emissive?.b,m.emissiveIntensity,m.roughness,m.metalness,m.depthWrite,m.depthTest,m.alphaTest,m.map,m.normalMap,m.roughnessMap,m.metalnessMap,m.emissiveMap,m.alphaMap,m.aoMap,m.lightMap,m.envMap,m.wireframe,m.vertexColors,m.flatShading,m.toneMapped,m.blending,m.polygonOffset,m.polygonOffsetFactor,m.polygonOffsetUnits];
function layout(g){
 // Geometry groups only select materials for material arrays, excluded above.
 if(Object.keys(g.morphAttributes||{}).length||g.drawRange.start!==0||g.drawRange.count!==Infinity)return null;
 return [g.index?'indexed':'plain',...Object.keys(g.attributes).sort().map(k=>{const a=g.attributes[k];return`${k}:${a.itemSize}:${a.normalized}:${a.array.constructor.name}`})].join('|');
}
export function createVehicleRenderBatches({THREE:T,root}={}){
 if(!T?.BatchedMesh||!root?.traverse)throw Error('Vehicle render batches require THREE.BatchedMesh and a vehicle root');
 const interiors=[];root.traverse(n=>{if(!n.isMesh&&/^Interior_/.test(n.name))interiors.push(n)});
 const records=[],hiddenMaterials=new Map(),ownedHidden=new Set(),scratch=new T.Matrix4();let disposed=false,fallbackMembers=0;
 const stats={batches:0,members:0,activeMembers:0,activeBatches:0,fallbackMembers:0,mode:'BatchedMesh'};
 const localMatrix=(mesh,interior,target)=>{
  target.identity();for(let n=mesh;n&&n!==interior;n=n.parent){if(n.matrixAutoUpdate)n.updateMatrix();target.premultiply(n.matrix)}return target;
 };
 const attachedAndVisible=(mesh,interior)=>{for(let n=mesh;n;n=n.parent){if(n===interior)return true;if(!n.visible)return false}return false};
 for(const interior of interiors){
  const groups=new Map();
  interior.traverse(mesh=>{
   if(!mesh.isMesh||mesh.isSkinnedMesh||mesh.isInstancedMesh||mesh.isBatchedMesh||Array.isArray(mesh.material)||!mesh.geometry?.attributes?.position)return;
   const material=mesh.material;
   if(!material||material.transparent||material.opacity<1||material.transmission>0||!material.visible||mesh.userData.breakableGlass)return;
   for(let n=mesh;n&&n!==interior;n=n.parent)if(moving.test(n.name)||n.userData.vehicleDoorId||n.userData.vehicleWheelId||n.userData.detached||n.userData.damagePart)return;
   const keyLayout=layout(mesh.geometry);if(!keyLayout)return;
   const key=[material.uuid,keyLayout,mesh.castShadow,mesh.receiveShadow,mesh.renderOrder,mesh.layers.mask].join('|');
   let entry=groups.get(key);if(!entry){entry={interior,material,members:[],geometries:new Map()};groups.set(key,entry)}
   const matrix=localMatrix(mesh,interior,new T.Matrix4());if(matrix.determinant()<=0)return;
   entry.members.push({mesh,geometry:mesh.geometry,stamp:geometryStamp(mesh.geometry),matrix,active:true,shown:null});entry.geometries.set(mesh.geometry,0);
  });
  for(const entry of groups.values()){
   if(entry.members.length<3)continue;
   let vertices=0,indices=0;for(const g of entry.geometries.keys()){vertices+=g.attributes.position.count;indices+=g.index?.count||0;}
   const batch=new T.BatchedMesh(entry.members.length,vertices,indices||vertices*2,entry.material),sample=entry.members[0].mesh;
   for(const g of entry.geometries.keys())entry.geometries.set(g,batch.addGeometry(g));
   batch.name='Vehicle_Interior_Render_Batch';batch.userData.vehicleRenderBatch=true;batch.castShadow=sample.castShadow;batch.receiveShadow=sample.receiveShadow;batch.renderOrder=sample.renderOrder;batch.layers.mask=sample.layers.mask;batch.raycast=()=>{};
   // Material visibility suppresses rendering only. Original meshes retain
   // geometry, visibility, ancestry, layers and Mesh.raycast for gameplay hits.
   let hidden=hiddenMaterials.get(entry.material);
   if(!hidden){hidden=entry.material.clone();hidden.name=entry.material.name;hidden.visible=false;hiddenMaterials.set(entry.material,hidden);ownedHidden.add(hidden)}
   entry.hidden=hidden;entry.hiddenStamp=materialStamp(hidden);entry.batch=batch;
   for(const member of entry.members){member.id=batch.addInstance(entry.geometries.get(member.geometry));batch.setMatrixAt(member.id,member.matrix);member.mesh.material=hidden;}
   batch.computeBoundingBox();batch.computeBoundingSphere();interior.add(batch);records.push(entry);stats.members+=entry.members.length;
  }
 }
 stats.batches=records.length;
 function fallback(entry,member,hiddenChanged){
  if(!member.active)return;member.active=false;entry.batch.setVisibleAt(member.id,false);fallbackMembers++;
  if(member.mesh.material===entry.hidden){
   if(hiddenChanged){entry.hidden.visible=entry.material.visible;ownedHidden.delete(entry.hidden)}
   else member.mesh.material=entry.material;
  }
 }
 function update(){
  if(disposed)return stats;
  stats.activeMembers=0;stats.activeBatches=0;
  for(const entry of records){
   // Source materials themselves are used by batches, so mutations through
   // saved material references are reflected immediately. Mutating the hidden
   // source replacement exits batching and keeps that material on the source.
   const hiddenChanged=!sameStamp(materialStamp(entry.hidden),entry.hiddenStamp);
   let shown=0,matricesChanged=false;
   for(const member of entry.members){
    if(!member.active)continue;const mesh=member.mesh;
    if(hiddenChanged||mesh.material!==entry.hidden||mesh.geometry!==member.geometry||!sameStamp(member.stamp,geometryStamp(mesh.geometry))){fallback(entry,member,hiddenChanged);continue;}
    // A detached/reparented part is no longer owned by this cabin batch.
    let ancestor=mesh.parent;while(ancestor&&ancestor!==entry.interior)ancestor=ancestor.parent;
    if(!ancestor){fallback(entry,member,false);continue;}
    const visible=attachedAndVisible(mesh,entry.interior)&&entry.material.visible;
    if(member.shown!==visible){entry.batch.setVisibleAt(member.id,visible);member.shown=visible;}
    if(visible){localMatrix(mesh,entry.interior,scratch);if(scratch.determinant()<=0){fallback(entry,member,false);continue;}shown++;if(!scratch.equals(member.matrix)){member.matrix.copy(scratch);entry.batch.setMatrixAt(member.id,member.matrix);matricesChanged=true;}}
   }
   entry.batch.visible=shown>0;if(shown){stats.activeMembers+=shown;stats.activeBatches++;}
   if(matricesChanged){entry.batch.computeBoundingBox();entry.batch.computeBoundingSphere();}
  }
  stats.fallbackMembers=fallbackMembers;return stats;
 }
 function dispose(){
  if(disposed)return;disposed=true;
  for(const entry of records){for(const member of entry.members)if(member.active&&member.mesh.material===entry.hidden)member.mesh.material=entry.material;entry.batch.removeFromParent();entry.batch.dispose();}
  for(const hidden of ownedHidden)hidden.dispose();ownedHidden.clear();stats.activeMembers=0;stats.activeBatches=0;
 }
 update();return{update,dispose,stats};
}
