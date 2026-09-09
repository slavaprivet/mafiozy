// NPC-only private template optimization. Unknown/moving pieces stay individual.
const STATIC_NAMES=new Set(('barrel barrel_clamp barrel_collar barrel_joining_rib barrel_retaining_nut bore_recess carry_handle carry_handle_support compensator_slot cooling_fin cutts_compensator ejection_port engraved_rosette flash_hider flash_hider_slot fore_end foregrip foregrip_rib forestock frame frame_screw front_post front_sight front_sight_base front_sight_hood gas_block gas_tube gold_side_rib gold_top_rib grip_medallion_l grip_medallion_r grip_panel_l grip_panel_r grip_screw handguard_rib handguard_vent heat_shield_rib launcher_band launcher_tube m16_foregrip muzzle_crown muzzle_thread optical_range_plate primary_grip range_tick rear_aperture rear_aperture_base rear_cone rear_notch rear_sight rear_sight_aperture rear_sight_notch receiver receiver_pin receiver_rivet receiver_vent scope scope_eye_cup scope_mount scope_objective scope_ring shoulder_pad sight_ear_l sight_ear_r sling_stud_front sling_stud_rear stock stock_pad top_strap top_vent trigger_guard trigger_guard_detail tt_grip_star twin_barrel wood_foregrip').split(' '));

// All owned persistent GPU resources remain reachable from returned object.
// The caller may use dispose(), OR its existing deduplicated tree disposer.
// Do not use both. The original template is untouched and may be freed at once.
// Static names become transform-only anchors; consumers requiring a named
// mesh's individual geometry should continue using the original hero template.
export function createNpcWeaponBatch({THREE,template}={}){
 if(!THREE||!template?.isObject3D)throw Error('THREE and authored weapon template required');
 const object=template.clone(true),materials=new Map(),geometries=new Set();let disposed=false;
 object.weaponId=template.weaponId;object.twoHanded=template.twoHanded;
 object.traverse(node=>{if(node.geometry){node.geometry=node.geometry.clone();geometries.add(node.geometry)}if(node.material){const copy=m=>{if(!materials.has(m))materials.set(m,m.clone());return materials.get(m)};node.material=Array.isArray(node.material)?node.material.map(copy):copy(node.material)}});
 const groups=new Map();let before=0,mergedMeshes=0;
 object.traverse(node=>{if(node.isMesh)before++});
 for(const mesh of object.children){
  const geometry=mesh.geometry,material=mesh.material;
  if(!mesh.isMesh||mesh.isSkinnedMesh||mesh.isInstancedMesh||mesh.children.length||!STATIC_NAMES.has(mesh.name)||!mesh.visible||!material||Array.isArray(material)||material.transparent||!material.visible||geometry.morphAttributes&&Object.keys(geometry.morphAttributes).length||geometry.drawRange.start!==0||Number.isFinite(geometry.drawRange.count))continue;
  const attributes=Object.entries(geometry.attributes);if(attributes.some(([name,a])=>a.isInterleavedBufferAttribute||a.isGLBufferAttribute||a.normalized||!['position','normal','uv','uv1','color','tangent'].includes(name)))continue;
  mesh.updateMatrix();if(mesh.matrix.determinant()<=0)continue;
  const signature=attributes.map(([name,a])=>name+':'+a.itemSize+':'+a.array.constructor.name).sort().join('|');
  const key=[material.uuid,signature,mesh.castShadow,mesh.receiveShadow,mesh.renderOrder,mesh.layers.mask,mesh.frustumCulled].join('/');
  if(!groups.has(key))groups.set(key,[]);groups.get(key).push(mesh);
 }
 let batches=0;
 for(const meshes of groups.values()){
  if(meshes.length<2)continue;const converted=[];
  for(const mesh of meshes){const geometry=mesh.geometry.index?mesh.geometry.toNonIndexed():mesh.geometry.clone();geometry.applyMatrix4(mesh.matrix);converted.push(geometry)}
  const geometry=new THREE.BufferGeometry();
  for(const [name,attribute]of Object.entries(converted[0].attributes)){
   const length=converted.reduce((sum,g)=>sum+g.attributes[name].array.length,0),array=new attribute.array.constructor(length);let offset=0;
   for(const source of converted){array.set(source.attributes[name].array,offset);offset+=source.attributes[name].array.length}
   geometry.setAttribute(name,new THREE.BufferAttribute(array,attribute.itemSize,false));
  }
  geometry.computeBoundingBox();geometry.computeBoundingSphere();geometries.add(geometry);
  const first=meshes[0],batch=new THREE.Mesh(geometry,first.material);batch.name='NPC_StaticWeaponBatch_'+batches++;batch.castShadow=first.castShadow;batch.receiveShadow=first.receiveShadow;batch.renderOrder=first.renderOrder;batch.layers.mask=first.layers.mask;batch.frustumCulled=first.frustumCulled;batch.userData.npcWeaponBatch=true;batch.userData.sourceNames=meshes.map(mesh=>mesh.name);
  for(const mesh of meshes){const anchor=new THREE.Object3D().copy(mesh,false);anchor.userData={...mesh.userData,npcWeaponBatchAnchor:true};const index=object.children.indexOf(mesh);object.remove(mesh);object.add(anchor);object.children.splice(object.children.indexOf(anchor),1);object.children.splice(index,0,anchor);geometries.delete(mesh.geometry);mesh.geometry.dispose();mergedMeshes++;}
  object.add(batch);for(const geometry of converted)geometry.dispose();
 }
 object.updateMatrixWorld(true);
 const stats={beforeDrawMeshes:before,afterDrawMeshes:before-mergedMeshes+batches,mergedMeshes,batches};
 return {object,stats,dispose(){if(disposed)return;disposed=true;object.removeFromParent();for(const geometry of geometries)geometry.dispose();for(const material of materials.values())material.dispose();geometries.clear();materials.clear()}};
}
