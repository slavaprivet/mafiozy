import {stampBatchedShadowBounds} from './shadow_bounds_stamp.mjs';

// Presentation-only batching of stationary cabin and optional body parts. The owning car and
// Interior_* hierarchy stay intact. Door batches stay in their own moving roots by default.
// The traffic-only rootDoorBatches path can combine exact opaque rigid door parts across pivots;
// their root-local matrices and aggregate bounds are refreshed by the same door-pose update.
const moving=/(?:Steering|Wheel|Door|Hinge|Engine|Hood|Trunk|Bumper|Damage|Detached|Glass|Window|Light|Lamp|Gauge_needle|Gear_lever|Pedal)/i;
const movingDoorPart=/(?:Steering|Wheel|Hinge|Engine|Hood|Trunk|Damage|Detached|Glass|Light|Lamp|Handle|Gauge_needle|Gear_lever|Pedal)/i;
const movingRootDoorPart=/(?:Steering|Wheel|Hinge|Engine|Hood|Trunk|Damage|Detached|Glass|Light|Lamp|Gauge_needle|Gear_lever|Pedal)/i;
const sourceMaterials=new WeakMap();
// Other narrowly scoped vehicle batch owners use the same canonical lookup for
// damage/debris copies. Never erase a newer owner's registration on teardown.
export function registerVehicleRenderSourceMaterial(mesh,hidden,material){
 if(sourceMaterials.has(mesh))throw Error('Vehicle source material already has a batch owner');
 sourceMaterials.set(mesh,{hidden,material});
}
export function unregisterVehicleRenderSourceMaterial(mesh,hidden){
 if(sourceMaterials.get(mesh)?.hidden===hidden)sourceMaterials.delete(mesh);
}
const detailManagers=new WeakMap();
export function setVehicleRenderDetailOptimization(root,enabled){return detailManagers.get(root)?.setDetailOptimizationEnabled(enabled)??null;}
// Debris copies use the authored material, not the invisible presentation-only
// replacement. Original source objects and their gameplay ownership stay intact.
export function getVehicleRenderSourceMaterial(mesh){const saved=sourceMaterials.get(mesh);return saved&&mesh.material===saved.hidden?saved.material:mesh.material;}
const doorRoot=node=>!node.isMesh&&/^Door_(?:front|rear)_(?:left|right)$/.test(node.name)&&!!node.userData.vehicleDoorId;
const geometryStamp=g=>({index:g.index,indexVersion:g.index?.version,start:g.drawRange.start,count:g.drawRange.count,attributes:Object.keys(g.attributes).map(key=>{const a=g.attributes[key];return{key,attribute:a,count:a.count,version:a.version,array:a.array}})});
// This runs for every batched source every frame. Compare in place instead of
// sorting keys and allocating several temporary arrays for each mesh.
function geometryUnchanged(g,stamp){
 if(g.index!==stamp.index||g.index?.version!==stamp.indexVersion||g.drawRange.start!==stamp.start||g.drawRange.count!==stamp.count)return false;
 let count=0;for(const key in g.attributes)count++;if(count!==stamp.attributes.length)return false;
 for(const saved of stamp.attributes){const a=g.attributes[saved.key];if(a!==saved.attribute||a.count!==saved.count||a.version!==saved.version||a.array!==saved.array)return false;}return true;
}
const sameStamp=(a,b)=>a.length===b.length&&a.every((v,i)=>v===b[i]);
const materialStamp=m=>[m.version,m.visible,m.opacity,m.transparent,m.transmission,m.side,m.color?.r,m.color?.g,m.color?.b,m.emissive?.r,m.emissive?.g,m.emissive?.b,m.emissiveIntensity,m.roughness,m.metalness,m.depthWrite,m.depthTest,m.alphaTest,m.map,m.normalMap,m.roughnessMap,m.metalnessMap,m.emissiveMap,m.alphaMap,m.aoMap,m.lightMap,m.envMap,m.wireframe,m.vertexColors,m.flatShading,m.toneMapped,m.blending,m.polygonOffset,m.polygonOffsetFactor,m.polygonOffsetUnits];
function layout(g){
 // Geometry groups only select materials for material arrays, excluded above.
 if(Object.keys(g.morphAttributes||{}).length||g.drawRange.start!==0||g.drawRange.count!==Infinity)return null;
 return [g.index?'indexed':'plain',...Object.keys(g.attributes).sort().map(k=>{const a=g.attributes[k];return`${k}:${a.itemSize}:${a.normalized}:${a.array.constructor.name}`})].join('|');
}
export function createVehicleRenderBatches({THREE:T,root,includeDoors=false,includeBody=false,detailOptimization=true,rootDoorBatches=false}={}){
 if(!T?.BatchedMesh||!root?.traverse)throw Error('Vehicle render batches require THREE.BatchedMesh and a vehicle root');
 rootDoorBatches=!!rootDoorBatches&&!!includeDoors&&!!includeBody&&!!detailOptimization;
 const interiors=[];root.traverse(n=>{if(!n.isMesh&&/^Interior_/.test(n.name)||includeDoors&&!rootDoorBatches&&doorRoot(n))interiors.push(n)});
 if(includeBody&&!interiors.includes(root))interiors.push(root);
 const records=[],hiddenMaterials=new Map(),ownedHidden=new Set(),scratch=new T.Matrix4();let disposed=false,fallbackMembers=0,detailEnabled=!!detailOptimization;
 const stats={batches:0,members:0,doorBatches:0,doorMembers:0,rootDoorBatches:0,rootDoorMembers:0,bodyBatches:0,bodyMembers:0,includeDoors:!!includeDoors,includeBody:!!includeBody,rootDoorBatching:rootDoorBatches,detailOptimizationAvailable:!!detailOptimization,detailOptimizationEnabled:detailEnabled,detailBatches:0,detailMembers:0,archMembers:0,fixtureMembers:0,fixtureBatches:0,activeMembers:0,activeBatches:0,fallbackMembers:0,mode:'BatchedMesh'};
 const localMatrix=(mesh,interior,target)=>{
  target.identity();for(let n=mesh;n&&n!==interior;n=n.parent){if(n.matrixAutoUpdate)n.updateMatrix();target.premultiply(n.matrix)}return target;
 };
 const attachedAndVisible=(mesh,interior)=>{for(let n=mesh;n;n=n.parent){if(n===interior)return true;if(!n.visible)return false}return false};
 const rootDoorOwner=mesh=>{for(let n=mesh.parent;n&&n!==root;n=n.parent)if(doorRoot(n))return n;return null};
 const authoredPrefix='LOD0_'+String(root.userData?.vehicleModelId||'')+'_';
 // Only the four fixed painted arch lips are body parts. Rolling tyres, liners,
 // steering and arbitrary nodes bearing a Wheel label retain their old guard.
 const fixedArch=mesh=>{const id=mesh.userData.wheelArchFor;return typeof id==='string'&&/^(?:front|rear)_(?:left|right)$/.test(id)&&mesh.name==='Wheel_arch_lip_'+id&&mesh.parent?.name==='Wheel_arch_'+id&&mesh.parent.parent===root;};
 // Exact root-mounted fixtures only, not lamps, bumpers or engine assemblies.
 // Keep their independent damage/material/geometry ownership and all flags.
 const fixedFixture=mesh=>mesh.parent===root&&mesh.userData.assembledBody===true&&/^(?:(?:Headlamp_housing|Front_bumper_bracket|Rear_bumper_bracket|Rear_corner_lamp_mount|Engine_bay_sidewall)_(?:-1|1)|Engine_bay_firewall)$/.test(mesh.name);
 const rootDoorPart=(mesh,owner)=>{if(!rootDoorBatches||!owner)return false;for(let n=mesh;n&&n!==owner;n=n.parent){const name=authoredPrefix.length>6&&n.name.startsWith(authoredPrefix)?n.name.slice(authoredPrefix.length):n.name;if(movingRootDoorPart.test(name)||n.userData.vehicleDoorId||n.userData.vehicleWheelId||n.userData.detached||n.userData.crashDetached||n.userData.detachedVehiclePart||n.userData.damagePart)return false;}return true};
 const fixedPart=(mesh,interior,isDoor,owner=rootDoorOwner(mesh))=>{if(interior===root&&owner)return rootDoorPart(mesh,owner);const arch=interior===root&&fixedArch(mesh),fixture=interior===root&&fixedFixture(mesh);for(let n=mesh;n&&n!==interior;n=n.parent)if((!((arch&&(n===mesh||n===mesh.parent))||(fixture&&n===mesh))&&(isDoor?movingDoorPart:moving).test(n.name))||interior===root&&/^Interior_/.test(n.name)||n.userData.vehicleDoorId||n.userData.vehicleWheelId||n.userData.detached||n.userData.damagePart)return false;return true};
 for(const interior of interiors){
  const isDoor=doorRoot(interior);
  const groups=new Map();
  interior.traverse(mesh=>{
   if(!mesh.isMesh||mesh.isSkinnedMesh||mesh.isInstancedMesh||mesh.isBatchedMesh||Array.isArray(mesh.material)||!mesh.geometry?.attributes?.position)return;
   const material=mesh.material;
   if(!material||material.transparent||material.opacity<1||material.transmission>0||!material.visible||mesh.userData.breakableGlass)return;
   const rootDoor=interior===root?rootDoorOwner(mesh):null;
   if(!fixedPart(mesh,interior,isDoor,rootDoor))return;
   const keyLayout=layout(mesh.geometry);if(!keyLayout)return;
   const arch=interior===root&&!rootDoor&&fixedArch(mesh),fixture=interior===root&&!rootDoor&&fixedFixture(mesh);
   // Separate arch and fixture members so disabling detail batches restores precisely
   // the former draw path, never a partially changed legacy body batch.
   const key=[material.uuid,keyLayout,mesh.castShadow,mesh.receiveShadow,mesh.renderOrder,mesh.layers.mask,rootDoor?'root-door':arch?'arch':fixture?'fixture':'legacy'].join('|');
   let entry=groups.get(key);if(!entry){entry={interior,isDoor:!!rootDoor||isDoor,rootDoor:!!rootDoor,arch,fixture,material,members:[],geometries:new Map()};groups.set(key,entry)}
   const matrix=localMatrix(mesh,interior,new T.Matrix4());if(matrix.determinant()<=0)return;
   entry.members.push({mesh,door:rootDoor,geometry:mesh.geometry,stamp:geometryStamp(mesh.geometry),matrix,active:true,shown:null});entry.geometries.set(mesh.geometry,0);
  });
  for(const entry of groups.values()){
   if(entry.members.length<2)continue;
   entry.detail=entry.rootDoor||entry.arch||entry.fixture||entry.members.length===2;
   // The caller supplies the renderer capability. Without multi-draw these
   // extra groups cannot save submissions, so do not allocate them at all.
   if(entry.detail&&!detailOptimization)continue;
   let vertices=0,indices=0;for(const g of entry.geometries.keys()){vertices+=g.attributes.position.count;indices+=g.index?.count||0;}
   const batch=new T.BatchedMesh(entry.members.length,vertices,indices||vertices*2,entry.material),sample=entry.members[0].mesh;
   for(const g of entry.geometries.keys())entry.geometries.set(g,batch.addGeometry(g));
   batch.name=entry.isDoor?'Vehicle_Door_Render_Batch':interior===root?'Vehicle_Body_Render_Batch':'Vehicle_Interior_Render_Batch';batch.userData.vehicleRenderBatch=true;batch.userData.vehicleDoorRenderBatch=entry.isDoor;batch.userData.vehicleRootDoorRenderBatch=entry.rootDoor;batch.userData.vehicleBodyRenderBatch=interior===root&&!entry.rootDoor;batch.userData.vehicleDetailRenderBatch=entry.detail;batch.userData.vehicleFixtureRenderBatch=entry.fixture;batch.castShadow=sample.castShadow;batch.receiveShadow=sample.receiveShadow;batch.renderOrder=sample.renderOrder;batch.layers.mask=sample.layers.mask;batch.raycast=()=>{};
   // Material visibility suppresses rendering only. Original meshes retain
   // geometry, visibility, ancestry, layers and Mesh.raycast for gameplay hits.
   let hidden=hiddenMaterials.get(entry.material);
   if(!hidden){hidden=entry.material.clone();hidden.name=entry.material.name;hidden.visible=false;hiddenMaterials.set(entry.material,hidden);ownedHidden.add(hidden)}
   entry.hidden=hidden;entry.hiddenStamp=materialStamp(hidden);entry.batch=batch;
   for(const member of entry.members){member.id=batch.addInstance(entry.geometries.get(member.geometry));batch.setMatrixAt(member.id,member.matrix);member.mesh.material=entry.detail&&!detailEnabled?entry.material:hidden;sourceMaterials.set(member.mesh,{hidden,material:entry.material});}
   batch.computeBoundingBox();batch.computeBoundingSphere();stampBatchedShadowBounds(batch);interior.add(batch);records.push(entry);stats.members+=entry.members.length;
   if(entry.isDoor){stats.doorBatches++;stats.doorMembers+=entry.members.length;}
   if(entry.rootDoor){stats.rootDoorBatches++;stats.rootDoorMembers+=entry.members.length;}
   if(interior===root&&!entry.rootDoor){stats.bodyBatches++;stats.bodyMembers+=entry.members.length;}
   if(entry.detail){stats.detailBatches++;stats.detailMembers+=entry.members.length;}if(entry.arch)stats.archMembers+=entry.members.length;if(entry.fixture){stats.fixtureBatches++;stats.fixtureMembers+=entry.members.length;}
  }
 }
 stats.batches=records.length;
 function fallback(entry,member,hiddenChanged){
  if(!member.active)return;member.active=false;entry.batch.setVisibleAt(member.id,false);fallbackMembers++;sourceMaterials.delete(member.mesh);
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
    if(hiddenChanged||mesh.material!==(entry.detail&&!detailEnabled?entry.material:entry.hidden)||mesh.geometry!==member.geometry||mesh.castShadow!==entry.batch.castShadow||mesh.receiveShadow!==entry.batch.receiveShadow||mesh.renderOrder!==entry.batch.renderOrder||mesh.layers.mask!==entry.batch.layers.mask||entry.rootDoor&&rootDoorOwner(mesh)!==member.door||entry.fixture&&!fixedFixture(mesh)||!fixedPart(mesh,entry.interior,entry.isDoor,member.door)||!geometryUnchanged(mesh.geometry,member.stamp)){fallback(entry,member,hiddenChanged);continue;}
    // A detached/reparented part is no longer owned by this cabin batch.
    let ancestor=mesh.parent;while(ancestor&&ancestor!==entry.interior)ancestor=ancestor.parent;
    if(!ancestor){fallback(entry,member,false);continue;}
    const visible=attachedAndVisible(mesh,entry.interior)&&entry.material.visible;
    if(member.shown!==visible){entry.batch.setVisibleAt(member.id,visible);member.shown=visible;}
    if(visible){localMatrix(mesh,entry.interior,scratch);if(scratch.determinant()<=0){fallback(entry,member,false);continue;}shown++;if(!scratch.equals(member.matrix)){member.matrix.copy(scratch);entry.batch.setMatrixAt(member.id,member.matrix);matricesChanged=true;}}
   }
   entry.batch.visible=shown>0&&(!entry.detail||detailEnabled);if(entry.batch.visible){stats.activeMembers+=shown;stats.activeBatches++;}
   if(matricesChanged){entry.batch.computeBoundingBox();entry.batch.computeBoundingSphere();stampBatchedShadowBounds(entry.batch);}
  }
  stats.fallbackMembers=fallbackMembers;return stats;
 }
 function setDetailOptimizationEnabled(enabled){
  if(disposed)return null;enabled=!!enabled&&!!detailOptimization;if(enabled===detailEnabled)return enabled;
  // Validate while the old representation is still authoritative. Mutations
  // made during an A/B pause must fall back, not be swallowed by re-enabling.
  update();
  for(const entry of records)if(entry.detail)for(const member of entry.members)if(member.active)member.mesh.material=enabled?entry.hidden:entry.material;
  detailEnabled=enabled;stats.detailOptimizationEnabled=enabled;update();return enabled;
 }
 function dispose(){
  if(disposed)return;disposed=true;
  for(const entry of records){for(const member of entry.members){sourceMaterials.delete(member.mesh);if(member.active&&member.mesh.material===entry.hidden)member.mesh.material=entry.material;}entry.batch.removeFromParent();entry.batch.dispose();}
  for(const hidden of ownedHidden)hidden.dispose();ownedHidden.clear();stats.activeMembers=0;stats.activeBatches=0;if(detailManagers.get(root)===api)detailManagers.delete(root);
 }
 const api={update,dispose,stats,setDetailOptimizationEnabled};update();detailManagers.set(root,api);return api;
}
