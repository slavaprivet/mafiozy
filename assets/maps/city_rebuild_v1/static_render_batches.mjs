const zeroMatrixMarker='StaticRenderBatch_Zero';

function hiddenMaterial(T,material){
 const clone=material.clone();clone.visible=false;clone.name=`${material.name||'material'}_hidden_render_source`;clone.userData={...clone.userData,staticRenderSource:true};return clone;
}

function hierarchyNodeBatchable(node,interiorInstances){
 if(!node.visible)return false;
 const name=String(node.name||'');
 // This audited GLB's root names the building, not a glass surface. Rejecting
 // its "GLASS" label excluded every opaque wall, roof and furnishing below it.
 // Descendant panes, doors, hinges and light nodes still use the normal guard.
 const pavilionRoot=!node.isMesh&&name==='MAFIOZI_GLASS_PAVILION_SMALL_V1';
 if(!pavilionRoot&&/Glass|Window|Door|ResidentialWindow|Light|Lamp|Glow|Hinge/i.test(name))return false;
 // Interior furnishing pools sit below the generated storey root. They are
 // static InstancedMesh data; the generated entry/door runtime remains out.
 if(!interiorInstances&&/(?:Entry_|Runtime_)/i.test(name))return false;
 return !node.userData?.glassEffect&&!node.userData?.blastEffect;
}

// A building template has many sibling meshes below the same two or three
// groups. Its visibility/name/effect ancestry does not change while a batch
// is assembled, so remember that result per ancestor. The cache has separate
// lanes because interior furnishing pools intentionally have one extra
// allowed parent category.
function hierarchyBatchable(node,interiorInstances,cache){
 if(!node)return true;
 const lane=interiorInstances?1:0,prior=cache.get(node);
 if(prior&&prior[lane]!==null)return prior[lane];
 const result=hierarchyNodeBatchable(node,interiorInstances)&&hierarchyBatchable(node.parent,interiorInstances,cache);
 const saved=prior||[null,null];saved[lane]=result;cache.set(node,saved);return result;
}

function batchableMesh(mesh,hierarchyCache){
 const interiorInstances=mesh?.isInstancedMesh&&/^Interior_Furnishings_/.test(mesh.name||'');
 if(!mesh?.isMesh||mesh.isSkinnedMesh||mesh.isInstancedMesh&&!interiorInstances||Array.isArray(mesh.material)||!mesh.geometry?.attributes?.position)return false;
 const material=mesh.material;if(!material||material.transparent||material.opacity<1||material.transmission>0||material.visible===false)return false;
 if(mesh.userData?.breakableGlass||material.userData?.breakableGlass)return false;
 // Batched copies live outside the original hierarchy. Never resurrect a
 // hidden collision proxy, clearance volume or authored hidden mesh.
 return hierarchyNodeBatchable(mesh,interiorInstances)&&hierarchyBatchable(mesh.parent,interiorInstances,hierarchyCache);
}

function batchKey(mesh,layout=geometryLayoutKey(mesh.geometry)){
 const material=mesh.material;
 return [
  mesh.isInstancedMesh?interiorMaterialKey(material):material.uuid,mesh.castShadow?'cast':'nocast',mesh.receiveShadow?'receive':'noreceive',
  mesh.renderOrder,material.side,material.depthWrite,material.depthTest,
  layout,
 ].join('|');
}

// Interior pools deliberately create local material instances so they can be
// disposed with one building. Their shader settings are nevertheless the
// same; batching their static, per-instance-coloured furniture is safe.
function interiorMaterialKey(material){
 const c=material.color;
 return ['interior',material.type,c?.r,c?.g,c?.b,material.roughness,material.metalness,material.side,material.depthWrite,material.depthTest,material.toneMapped,material.flatShading].join('|');
}

function geometryLayoutKey(geometry){
 const names=Object.keys(geometry.attributes).sort();
 if(Object.keys(geometry.morphAttributes||{}).length)return null;
 return [
  geometry.index?'indexed':'plain',
  geometry.morphTargetsRelative?'morph-relative':'morph-absolute',
  ...names.map(name=>{const a=geometry.attributes[name];return `${name}:${a.itemSize}:${a.normalized}:${a.array.constructor.name}`}),
 ].join('|');
}

function geometrySize(geometry){
 return {vertices:geometry.attributes.position.count,indices:geometry.index?.count??0};
}

export function createStaticRenderBatches({THREE:T,root,instances,minInstances=3,maxDistance=220}={}){
 if(!T?.InstancedMesh||!root?.add||!Array.isArray(instances))throw Error('Static render batches require THREE, root and instances');
 root.updateWorldMatrix(true,true);
 const rootInverse=new T.Matrix4().copy(root.matrixWorld).invert(),groups=new Map(),restores=[],hiddenMaterials=new Map(),geometryLayouts=new WeakMap(),hierarchyCache=new WeakMap(),zero=new T.Matrix4().makeScale(0,0,0);
 const layoutFor=geometry=>{if(geometryLayouts.has(geometry))return geometryLayouts.get(geometry);const layout=geometryLayoutKey(geometry);geometryLayouts.set(geometry,layout);return layout;};
 for(const group of instances){
  group.updateWorldMatrix(true,true);
  group.traverse(mesh=>{
   if(!batchableMesh(mesh,hierarchyCache))return;const layout=layoutFor(mesh.geometry);if(!layout)return;
   const key=batchKey(mesh,layout),geometryKey=mesh.isInstancedMesh?'interior:'+mesh.name:mesh.geometry.uuid,entry=groups.get(key)||{material:mesh.material,members:[],geometries:new Map(),castShadow:mesh.castShadow,receiveShadow:mesh.receiveShadow,renderOrder:mesh.renderOrder,interiorInstances:mesh.isInstancedMesh};
   if(!groups.has(key))groups.set(key,entry);
   if(mesh.isInstancedMesh){const local=new T.Matrix4(),matrix=new T.Matrix4(),color=mesh.instanceColor?new T.Color():null;for(let i=0;i<mesh.count;i++){mesh.getMatrixAt(i,local);matrix.multiplyMatrices(rootInverse,mesh.matrixWorld).multiply(local);if(color)mesh.getColorAt(i,color);entry.members.push({group,mesh,matrix:matrix.clone(),color:color?.clone(),sourceInstanced:true,geometryKey})}}
   else entry.members.push({group,mesh,matrix:new T.Matrix4().multiplyMatrices(rootInverse,mesh.matrixWorld),geometryKey});
   entry.geometries.set(geometryKey,mesh.geometry);
  });
 }
 const batches=[],instancedSourceMaterials=new Map();
 for(const entry of groups.values()){
  if(entry.members.length<minInstances)continue;
  const material=entry.material.clone(),geometries=[...entry.geometries.values()];if(entry.interiorInstances)material.vertexColors=true;
  let batch,memberIds;
  if(T.BatchedMesh){
   const totals=geometries.reduce((sum,geometry)=>{const size=geometrySize(geometry);sum.vertices+=size.vertices;sum.indices+=size.indices;return sum},{vertices:0,indices:0});
   batch=new T.BatchedMesh(entry.members.length,totals.vertices,totals.indices||totals.vertices*2,material);
   const geometryIds=new Map();for(const [geometryKey,geometry]of entry.geometries)geometryIds.set(geometryKey,batch.addGeometry(geometry));
   memberIds=entry.members.map(member=>{const id=batch.addInstance(geometryIds.get(member.geometryKey));batch.setMatrixAt(id,member.matrix);if(member.color)batch.setColorAt(id,member.color);return id});
  }else{
   const geometry=geometries[0];
   if(geometries.length!==1){material.dispose();continue}
   batch=new T.InstancedMesh(geometry,material,entry.members.length);
   memberIds=entry.members.map((member,i)=>{batch.setMatrixAt(i,member.matrix);if(member.color)batch.setColorAt(i,member.color);return i});
   batch.instanceMatrix.needsUpdate=true;
  }
  batch.name='Static_Render_Batch';batch.userData.breakableGlass=false;batch.userData.staticRenderBatch=true;batch.castShadow=entry.castShadow;batch.receiveShadow=entry.receiveShadow;batch.renderOrder=entry.renderOrder;batch.raycast=()=>{};
  batch.computeBoundingBox?.();batch.computeBoundingSphere?.();root.add(batch);
  for(const member of entry.members){
   if(member.sourceInstanced){
    if(instancedSourceMaterials.has(member.mesh))continue;
    const source=member.mesh.material,hidden=hiddenMaterials.get(source)||hiddenMaterial(T,source);hiddenMaterials.set(source,hidden);instancedSourceMaterials.set(member.mesh,source);restores.push({mesh:member.mesh,material:source});member.mesh.material=hidden;continue;
   }
   const source=member.mesh.material,hidden=hiddenMaterials.get(source)||hiddenMaterial(T,source);hiddenMaterials.set(source,hidden);
   restores.push({mesh:member.mesh,material:source});
   member.mesh.material=hidden;
  }
  batches.push({mesh:batch,members:entry.members,memberIds});
 }
 // All static parts of one placed object share its distance cull decision.
 // Compute that once per placement rather than once per constituent mesh.
 const placements=new Map();
 for(const batch of batches)for(let index=0;index<batch.members.length;index++){
  const member=batch.members[index];
  if(!placements.has(member.group))placements.set(member.group,{group:member.group,visible:false,initialized:false,members:[]});
  const placement=placements.get(member.group);member.placement=placement;placement.members.push({batch,index,member});
 }
 for(const batch of batches)batch.visibleMembers=0;
 let disposed=false,lastVisible=-1,lastActiveBatches=-1,visibleMembers=0,activeBatches=0;
 function update({focus,maxDistance:nextDistance=maxDistance}={}){
  if(disposed)return {visible:lastVisible,batches:batches.length,activeBatches:lastActiveBatches};
  const distanceSq=nextDistance*nextDistance,point=focus?.isVector3?focus:null;let touched=null;
  for(const placement of placements.values()){
   const show=!point||placement.group.position.distanceToSquared(point)<distanceSq;
   if(placement.initialized&&placement.visible===show)continue;
   placement.visible=show;placement.initialized=true;
   for(const {batch,index,member}of placement.members){
    if(member.shown===show)continue;
    const wasShown=member.shown===true,delta=show?1:wasShown?-1:0,before=batch.visibleMembers;
    if(batch.mesh.isBatchedMesh)batch.mesh.setVisibleAt(batch.memberIds[index],show);
    else batch.mesh.setMatrixAt(batch.memberIds[index],show?member.matrix:zero);
    member.shown=show;batch.visibleMembers+=delta;visibleMembers+=delta;
    if(before===0&&batch.visibleMembers>0)activeBatches++;else if(before>0&&batch.visibleMembers===0)activeBatches--;
    (touched??=new Set()).add(batch);
   }
  }
  for(const batch of touched||[]){batch.mesh.visible=batch.visibleMembers>0;if(batch.mesh.instanceMatrix)batch.mesh.instanceMatrix.needsUpdate=true}
  lastVisible=visibleMembers;lastActiveBatches=activeBatches;return {visible:lastVisible,batches:batches.length,activeBatches:lastActiveBatches};
 }
 function dispose(){
  if(disposed)return;disposed=true;
  for(const restore of restores)restore.mesh.material=restore.material;
  for(const hidden of hiddenMaterials.values())hidden.dispose();hiddenMaterials.clear();
  for(const batch of batches){batch.mesh.removeFromParent();batch.mesh.material.dispose();batch.mesh.dispose()}
  batches.length=0;restores.length=0;placements.clear();
 }
 update();
 return {update,dispose,stats(){return{batches:batches.length,members:batches.reduce((sum,b)=>sum+b.members.length,0),sourceMaterials:hiddenMaterials.size,visible:lastVisible,activeBatches:lastActiveBatches,mode:T.BatchedMesh?'BatchedMesh':zeroMatrixMarker}}};
}
