import {stampBatchedShadowBounds} from './shadow_bounds_stamp.mjs';

const zeroMatrixMarker='StaticRenderBatch_Zero';

function hiddenMaterial(T,material){
 const clone=material.clone();clone.visible=false;clone.name=`${material.name||'material'}_hidden_render_source`;clone.userData={...clone.userData,staticRenderSource:true};return clone;
}

// Audited architecture created once by entry/storey generation, plus authored
// opaque window surrounds. Panes and all moving door descendants remain excluded.
function auditedStaticArchitecture(mesh){
 if(!/^(?:Entry_Interior_(?:Floor|Left|Right|Rear|Front|Header)|Entry_Corridor_(?:Floor|Wall|Ceiling)|Entry_Continuous_Ramp|Entry_Warm_Fixture|Storey_Walls_And_Ceilings|Storey_Floors|Room_Door_Frames|Stair_Treads_And_Posts|Brass_Stair_Handrails|RoofAccessSigns|(?:Front|Rear)Window\d+(?:Sill|Lintel|TrimLeft|TrimRight|MullionV|MullionH))$/.test(mesh?.name||''))return false;
 for(let node=mesh;node;node=node.parent){const id=node.userData?.instance?.assetId;if(id)return ['old_town_narrow_townhouse_v1','hillstep_chalet_v1','pine_ridge_cottage_v1','woodland_crosswing_house_v1'].includes(id)}
 return false;
}
function hierarchyNodeBatchable(node,interiorInstances){
 if(!node.visible)return false;
 const name=String(node.name||'');
 // This audited GLB's root names the building, not a glass surface. Rejecting
 // its "GLASS" label excluded every opaque wall, roof and furnishing below it.
 // Descendant panes, doors, hinges and light nodes still use the normal guard.
 const pavilionRoot=!node.isMesh&&name==='MAFIOZI_GLASS_PAVILION_SMALL_V1';
 if(!pavilionRoot&&!(node.isMesh&&auditedStaticArchitecture(node))&&/Glass|Window|Door|ResidentialWindow|Light|Lamp|Glow|Hinge/i.test(name))return false;
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

function batchableMesh(T,mesh,hierarchyCache){
 const interiorInstances=auditedStaticArchitecture(mesh)||mesh?.isInstancedMesh&&/^Interior_Furnishings_/.test(mesh.name||'');
 if(!mesh?.isMesh||mesh.isSkinnedMesh||mesh.isInstancedMesh&&!interiorInstances||Array.isArray(mesh.material)||!mesh.geometry?.attributes?.position)return false;
 const prototype=T.Object3D?.prototype;
 if(!prototype||mesh.onBeforeRender!==prototype.onBeforeRender||mesh.onAfterRender!==prototype.onAfterRender||mesh.onBeforeShadow!==prototype.onBeforeShadow||mesh.onAfterShadow!==prototype.onAfterShadow||mesh.customDepthMaterial||mesh.customDistanceMaterial)return false;
 const material=mesh.material;if(!material||material.transparent||material.opacity<1||material.transmission>0||material.visible===false)return false;
 if(mesh.userData?.breakableGlass||material.userData?.breakableGlass)return false;
 // Batched copies live outside the original hierarchy. Never resurrect a
 // hidden collision proxy, clearance volume or authored hidden mesh.
 return hierarchyNodeBatchable(mesh,interiorInstances)&&hierarchyBatchable(mesh.parent,interiorInstances,hierarchyCache);
}

function auditedArchitectureMaterialKey(T,mesh){
 const material=mesh.material;
 if(mesh.userData?.staticRenderMaterialImmutable!==true)return null;
 if(!material?.isMeshStandardMaterial||material.onBeforeCompile!==T.Material.prototype.onBeforeCompile||material.customProgramCacheKey!==T.Material.prototype.customProgramCacheKey)return null;
 if(material.clippingPlanes?.length||Object.values(material).some(value=>value?.isTexture))return null;
 const description=material.toJSON();delete description.metadata;delete description.uuid;description.defines=Object.fromEntries(Object.entries(material.defines||{}).sort(([a],[b])=>a.localeCompare(b)));
 return `audited:${JSON.stringify(description)}`;
}

function batchKey(mesh,layout=geometryLayoutKey(mesh.geometry),materialIdentity=mesh.material.uuid){
 const material=mesh.material;
 return [
  mesh.isInstancedMesh&&!auditedStaticArchitecture(mesh)?interiorMaterialKey(material):materialIdentity,mesh.castShadow?'cast':'nocast',mesh.receiveShadow?'receive':'noreceive',
  mesh.layers.mask,mesh.renderOrder,material.side,material.depthWrite,material.depthTest,
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

function hierarchyVisible(node,cache){
 if(!node)return true;
 if(cache.has(node))return cache.get(node);
 const visible=node.visible!==false&&hierarchyVisible(node.parent,cache);
 cache.set(node,visible);return visible;
}

function attachedTo(node,ancestor){
 for(let current=node;current;current=current.parent)if(current===ancestor)return true;
 return false;
}

// Admission into a static batch already requires immutable source transforms.
// Freeze only ordinary leaf composition, never custom transform/render hooks,
// descendants or inherited world updates. The source remains raycastable.
function standardStaticLocalLeaf(T,mesh){
 const prototype=T.Object3D?.prototype;
 return !!prototype&&!mesh.children.length&&mesh.matrixAutoUpdate===true&&
  !mesh.animations?.length&&!mesh.morphTargetInfluences?.length&&
  mesh.updateMatrix===prototype.updateMatrix&&mesh.updateMatrixWorld===prototype.updateMatrixWorld&&mesh.updateWorldMatrix===prototype.updateWorldMatrix&&
  mesh.onBeforeRender===prototype.onBeforeRender&&mesh.onAfterRender===prototype.onAfterRender&&mesh.onBeforeShadow===prototype.onBeforeShadow&&mesh.onAfterShadow===prototype.onAfterShadow;
}

export function createStaticRenderBatches({THREE:T,root,instances,minInstances=3,maxDistance=220,localMatrixOptimization=false,shadowCensus=null,multiDraw=false}={}){
 if(!T?.InstancedMesh||!root?.add||!Array.isArray(instances))throw Error('Static render batches require THREE, root and instances');
 root.updateWorldMatrix(true,true);
 const rootInverse=new T.Matrix4().copy(root.matrixWorld).invert(),groups=new Map(),restores=[],sourceRestores=new WeakMap(),hiddenMaterials=new Map(),geometryLayouts=new WeakMap(),hierarchyCache=new WeakMap(),zero=new T.Matrix4().makeScale(0,0,0);
 const layoutFor=geometry=>{if(geometryLayouts.has(geometry))return geometryLayouts.get(geometry);const layout=geometryLayoutKey(geometry);geometryLayouts.set(geometry,layout);return layout;};
 for(const group of instances){
  group.updateWorldMatrix(true,true);
  group.traverse(mesh=>{
   if(!batchableMesh(T,mesh,hierarchyCache))return;const layout=layoutFor(mesh.geometry);if(!layout)return;
   const optimization=auditedStaticArchitecture(mesh),materialIdentity=optimization?auditedArchitectureMaterialKey(T,mesh):null,key=batchKey(mesh,layout,materialIdentity||mesh.material.uuid)+(optimization?'|architecture':''),geometryKey=mesh.isInstancedMesh&&!optimization?'interior:'+mesh.name:mesh.geometry.uuid,entry=groups.get(key)||{material:mesh.material,members:[],geometries:new Map(),castShadow:mesh.castShadow,receiveShadow:mesh.receiveShadow,renderOrder:mesh.renderOrder,layersMask:mesh.layers.mask,optimization,interiorInstances:mesh.isInstancedMesh&&!optimization};
   if(!groups.has(key))groups.set(key,entry);
   if(mesh.isInstancedMesh){
    // Every instance below one source mesh shares this world transform.  The
    // old inner loop recomputed it for every furnishing part during startup.
    // Keep the exact multiplication order, but calculate the immutable left
    // side once so global batching cannot change a room's local placement.
    const sourceToRoot=new T.Matrix4().multiplyMatrices(rootInverse,mesh.matrixWorld),local=new T.Matrix4(),matrix=new T.Matrix4(),color=mesh.instanceColor?new T.Color():null;
    for(let i=0;i<mesh.count;i++){mesh.getMatrixAt(i,local);matrix.multiplyMatrices(sourceToRoot,local);if(color)mesh.getColorAt(i,color);entry.members.push({group,mesh,matrix:matrix.clone(),color:color?.clone(),sourceInstanced:true,geometryKey})}
   }
   else entry.members.push({group,mesh,matrix:new T.Matrix4().multiplyMatrices(rootInverse,mesh.matrixWorld),geometryKey});
   entry.geometries.set(geometryKey,mesh.geometry);
  });
 }
 const batches=[],instancedSourceMaterials=new Map(),batchedBackend=multiDraw===true&&!!T.BatchedMesh;
 for(const entry of groups.values()){
  if(entry.members.length<minInstances)continue;
  const material=entry.material.clone(),geometries=[...entry.geometries.values()];material.onBeforeCompile=entry.material.onBeforeCompile;material.customProgramCacheKey=entry.material.customProgramCacheKey;if(entry.interiorInstances)material.vertexColors=true;
  // Without WEBGL_multi_draw, BatchedMesh submits one draw per copied member.
  // Preserve an authored InstancedMesh pool instead of expanding its instances.
  if(!batchedBackend&&entry.members.some(member=>member.sourceInstanced)){material.dispose();continue}
  let batch,memberIds;
  if(batchedBackend){
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
  batch.name='Static_Render_Batch';batch.userData.breakableGlass=false;batch.userData.staticRenderBatch=true;batch.userData.renderIsolationInteriorFurnishings=entry.interiorInstances===true;batch.castShadow=entry.castShadow;batch.receiveShadow=entry.receiveShadow;batch.layers.mask=entry.layersMask;batch.renderOrder=entry.renderOrder;batch.raycast=()=>{};
  batch.computeBoundingBox?.();batch.computeBoundingSphere?.();stampBatchedShadowBounds(batch);root.add(batch);
  shadowCensus?.(batch,entry.members);
  for(const member of entry.members){
   if(member.sourceInstanced){
    const existing=sourceRestores.get(member.mesh);if(existing){existing.members.push(member);continue}
    const source=member.mesh.material,hidden=hiddenMaterials.get(source)||hiddenMaterial(T,source),restore={mesh:member.mesh,group:member.group,material:source,hidden,layersMask:member.mesh.layers.mask,optimization:entry.optimization,members:[member],geometry:member.mesh.geometry,castShadow:member.mesh.castShadow,receiveShadow:member.mesh.receiveShadow,renderOrder:member.mesh.renderOrder,hasInstanceColor:!!member.mesh.instanceColor,detached:false,retired:false};hiddenMaterials.set(source,hidden);instancedSourceMaterials.set(member.mesh,source);restores.push(restore);sourceRestores.set(member.mesh,restore);member.mesh.material=hidden;continue;
   }
   const source=member.mesh.material,hidden=hiddenMaterials.get(source)||hiddenMaterial(T,source);hiddenMaterials.set(source,hidden);
   const restore={mesh:member.mesh,group:member.group,material:source,hidden,layersMask:member.mesh.layers.mask,optimization:entry.optimization,members:[member],geometry:member.mesh.geometry,castShadow:member.mesh.castShadow,receiveShadow:member.mesh.receiveShadow,renderOrder:member.mesh.renderOrder,hasInstanceColor:false,detached:false,retired:false};restores.push(restore);sourceRestores.set(member.mesh,restore);
   member.mesh.material=hidden;
  }
  batches.push({mesh:batch,members:entry.members,memberIds,optimization:entry.optimization});
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
 const restoreAttached=restore=>attachedTo(restore.mesh,restore.group)&&attachedTo(restore.group,root);
 const currentRootInverse=new T.Matrix4(),currentSourceMatrix=new T.Matrix4(),currentMemberMatrix=new T.Matrix4(),currentLocalMatrix=new T.Matrix4(),currentColor=new T.Color();
 const matricesEqual=(a,b)=>a.elements.every((value,index)=>Math.abs(value-b.elements[index])<=1e-7);
 function restorePoseMatches(restore){
  const mesh=restore.mesh;if(mesh.geometry!==restore.geometry||mesh.castShadow!==restore.castShadow||mesh.receiveShadow!==restore.receiveShadow||mesh.renderOrder!==restore.renderOrder||mesh.layers.mask!==restore.layersMask)return false;
  root.updateWorldMatrix(true,false);mesh.updateWorldMatrix(true,false);currentRootInverse.copy(root.matrixWorld).invert();currentSourceMatrix.multiplyMatrices(currentRootInverse,mesh.matrixWorld);
  if(!mesh.isInstancedMesh)return restore.members.length===1&&matricesEqual(currentSourceMatrix,restore.members[0].matrix);
  if(mesh.count!==restore.members.length||!!mesh.instanceColor!==restore.hasInstanceColor)return false;
  for(let i=0;i<restore.members.length;i++){const member=restore.members[i];mesh.getMatrixAt(i,currentLocalMatrix);currentMemberMatrix.multiplyMatrices(currentSourceMatrix,currentLocalMatrix);if(!matricesEqual(currentMemberMatrix,member.matrix))return false;if(restore.hasInstanceColor){mesh.getColorAt(i,currentColor);if(!member.color||Math.abs(currentColor.r-member.color.r)>1e-7||Math.abs(currentColor.g-member.color.g)>1e-7||Math.abs(currentColor.b-member.color.b)>1e-7)return false}}
  return true;
 }
 function restoreOwned(restore){
  if(restore.retired)return false;
  if(!restoreAttached(restore)){restore.detached=true;return false}
  if(restore.mesh.material===restore.hidden)return true;
  if(restore.mesh.material!==restore.material)return false;
  if(restore.optimization&&!optimizationEnabled)return true;
  if(!restore.detached)return false;
  if(!restorePoseMatches(restore)){restore.retired=true;return false}
  restore.detached=false;return true;
 }
 let optimizationEnabled=true,localMatrixOptimizationEnabled=false,frozenLocalSources=0,lastFocus=null,lastDistance=maxDistance;
 let disposed=false,lastVisible=-1,lastActiveBatches=-1,visibleMembers=0,activeBatches=0;
 function update({focus,maxDistance:nextDistance=maxDistance}={}){
 if(disposed)return {visible:lastVisible,batches:batches.length,activeBatches:lastActiveBatches};
  const distanceSq=nextDistance*nextDistance,point=focus?.isVector3?focus:null,visibilityCache=new WeakMap(),ownershipCache=new WeakMap();lastDistance=nextDistance;if(point)(lastFocus??=new T.Vector3()).copy(point);else lastFocus=null;let touched=null;
  for(const placement of placements.values()){
   const placementVisible=!point||placement.group.position.distanceToSquared(point)<distanceSq;
   placement.visible=placementVisible;placement.initialized=true;
   for(const {batch,index,member}of placement.members){
    const restore=sourceRestores.get(member.mesh);let sourceOwned=restore&&ownershipCache.get(restore);if(restore&&!ownershipCache.has(restore)){sourceOwned=restoreOwned(restore);ownershipCache.set(restore,sourceOwned)}
    if(restore&&!sourceOwned&&member.mesh.material===restore.hidden)member.mesh.material=restore.material;
    else if(sourceOwned&&member.mesh.material===restore.material&&(!restore.optimization||optimizationEnabled))member.mesh.material=restore.hidden;
    const show=sourceOwned&&placementVisible&&hierarchyVisible(member.mesh,visibilityCache);
    if(member.shown===show)continue;
    const wasShown=member.shown===true,delta=show?1:wasShown?-1:0,before=batch.visibleMembers;
    if(batch.mesh.isBatchedMesh)batch.mesh.setVisibleAt(batch.memberIds[index],show);
    else batch.mesh.setMatrixAt(batch.memberIds[index],show?member.matrix:zero);
    member.shown=show;batch.visibleMembers+=delta;visibleMembers+=delta;
    if(before===0&&batch.visibleMembers>0)activeBatches++;else if(before>0&&batch.visibleMembers===0)activeBatches--;
    (touched??=new Set()).add(batch);
   }
  }
  for(const batch of touched||[]){batch.mesh.visible=batch.visibleMembers>0&&(!batch.optimization||optimizationEnabled);if(batch.mesh.instanceMatrix)batch.mesh.instanceMatrix.needsUpdate=true}
  lastVisible=visibleMembers;lastActiveBatches=activeBatches;return {visible:lastVisible,batches:batches.length,activeBatches:lastActiveBatches};
 }
 function setOptimizationEnabled(enabled){
  if(disposed)return;optimizationEnabled=!!enabled;
  for(const restore of restores)if(restore.optimization){const attached=restoreAttached(restore);if(!attached)restore.detached=true;let owned=attached&&!restore.retired&&restore.mesh.layers.mask===restore.layersMask;if(optimizationEnabled&&owned&&restore.mesh.material===restore.material){if(restore.detached){owned=restorePoseMatches(restore);restore.detached=!owned;if(!owned)restore.retired=true}if(owned)restore.mesh.material=restore.hidden}else if((!optimizationEnabled||!owned)&&restore.mesh.material===restore.hidden)restore.mesh.material=restore.material;}
  update({focus:lastFocus,maxDistance:lastDistance});
  for(const batch of batches)if(batch.optimization)batch.mesh.visible=optimizationEnabled&&batch.visibleMembers>0;
  return optimizationEnabled;
 }
 function restoreLocalMatrix(restore){
  const state=restore.localMatrixState;if(!state)return;
  restore.mesh.matrix.copy(state.matrix);restore.mesh.matrixAutoUpdate=state.matrixAutoUpdate;
  restore.mesh.matrixWorldNeedsUpdate=true;restore.localMatrixState=null;frozenLocalSources--;
 }
 function setLocalMatrixOptimizationEnabled(enabled){
  if(disposed)return;enabled=!!enabled;if(enabled===localMatrixOptimizationEnabled)return enabled;
  localMatrixOptimizationEnabled=enabled;
  for(const restore of restores){
   if(!enabled){restoreLocalMatrix(restore);continue;}
   const mesh=restore.mesh;if(!standardStaticLocalLeaf(T,mesh))continue;
   mesh.updateMatrix();restore.localMatrixState={matrixAutoUpdate:mesh.matrixAutoUpdate,matrix:mesh.matrix.clone()};
   mesh.matrixAutoUpdate=false;frozenLocalSources++;
  }
  return localMatrixOptimizationEnabled;
 }
 function dispose(){
  if(disposed)return;disposed=true;
  // Restore local composition before entry disposal can restore/reparent sources.
  for(const restore of restores){restoreLocalMatrix(restore);if(restore.mesh.material===restore.hidden)restore.mesh.material=restore.material;}
  localMatrixOptimizationEnabled=false;
  for(const hidden of hiddenMaterials.values())hidden.dispose();hiddenMaterials.clear();
  for(const batch of batches){batch.mesh.removeFromParent();batch.mesh.material.dispose();batch.mesh.dispose()}
  batches.length=0;restores.length=0;placements.clear();
 }
 update();
 if(localMatrixOptimization)setLocalMatrixOptimizationEnabled(true);
 return {update,dispose,setOptimizationEnabled,setLocalMatrixOptimizationEnabled,stats(){return{optimizationEnabled,localMatrixOptimizationEnabled,frozenLocalSources,optimizationBatches:batches.filter(b=>b.optimization).length,optimizationMembers:batches.filter(b=>b.optimization).reduce((s,b)=>s+b.members.length,0),batches:batches.length,members:batches.reduce((sum,b)=>sum+b.members.length,0),sourceMaterials:hiddenMaterials.size,visible:lastVisible,activeBatches:lastActiveBatches,mode:batchedBackend?'BatchedMesh':zeroMatrixMarker}}};
}
