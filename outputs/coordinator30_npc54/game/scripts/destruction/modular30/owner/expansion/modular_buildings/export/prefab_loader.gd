extends RefCounted
## Portable prefab reader/binder. No Builder, Panels census, collider or owner mutation.
const SCHEMA:="mafiozi.modular-prefab/v1"
const PART:="modular_body_v1"
const PROVENANCE:="GENERATED_CLOSED_BOX_MODULES_V1"
const MAX_PARTS:=512

static func _no(reason: String) -> Dictionary: return {"ok":false,"reason":reason,"scene_mutated":false,"collision_replacement_approved":false}

static func instantiate_prefab(path: String,expected_sha256: String) -> Dictionary:
	var started:=Time.get_ticks_usec()
	if expected_sha256.length()!=64 or not expected_sha256.is_valid_hex_number() or not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=expected_sha256.to_lower(): return _no("pinned_prefab_sha_required")
	var packed: Resource=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not packed is PackedScene: return _no("packed_scene_required")
	var instance: Node=packed.instantiate()
	if not instance is Node3D: instance.free(); return _no("prefab_root_required")
	var valid:=validate_prefab(instance)
	if not valid.ok: instance.free(); return valid
	return {"ok":true,"instance":instance,"payload":valid.payload,"mesh_node":valid.mesh_node,"prefab_sha256":expected_sha256,"load_validate_usec":Time.get_ticks_usec()-started,"scene_mutated":false,"collision_replacement_approved":false}

static func validate_prefab(instance: Node3D) -> Dictionary:
	if not is_instance_valid(instance) or instance.get_script()!=null or instance.get_child_count()!=1 or not instance.has_meta("modular_payload"): return _no("single_mesh_prefab_required")
	var payload: Variant=instance.get_meta("modular_payload")
	if not payload is Dictionary or payload.get("schema")!=SCHEMA or payload.get("geometry_provenance")!=PROVENANCE: return _no("new_module_payload_required")
	if str(payload.get("source_id","")).is_empty() or str(payload.get("asset_id","")).is_empty() or payload.get("source_part_id")!=PART or str(payload.get("source_sha256","")).length()!=64 or str(payload.get("builder_sha256","")).length()!=64 or str(payload.get("specs_sha256","")).length()!=64: return _no("new_module_identity_and_pins_required")
	if not payload.get("frame") is Transform3D or instance.transform!=payload.frame or not payload.frame.is_finite() or payload.frame.basis.determinant()<=0: return _no("prefab_placement_frame_changed")
	var node: Node=instance.get_child(0)
	if not node is MeshInstance3D or str(node.name)!=PART or node.get_script()!=null or node.transform!=Transform3D.IDENTITY or not node.mesh is ArrayMesh or node.get_child_count()!=0 or node.material_override!=null: return _no("single_identity_mesh_child_required")
	if instance.is_inside_tree() and node.global_transform!=payload.frame: return _no("prefab_requires_preserved_world_placement")
	for surface: int in node.get_surface_override_material_count():
		if node.get_surface_override_material(surface)!=null: return _no("prefab_material_override_changed")
	var mesh: ArrayMesh=node.mesh
	if mesh.get_surface_count()<1 or mesh.get_surface_count()>4 or mesh.get_blend_shape_count()!=0 or mesh.shadow_mesh!=null: return _no("bounded_modular_array_mesh_required")
	if not payload.get("parts") is Array or payload.parts.is_empty() or payload.parts.size()>MAX_PARTS: return _no("bounded_exact_module_parts_required")
	if not payload.get("owner_obligations") is Dictionary or not payload.owner_obligations.get("protected_interiors") is Array or not payload.owner_obligations.get("glazing_pending") is Array or not payload.owner_obligations.get("entry_connectors_pending") is Array: return _no("explicit_external_owner_obligations_required")
	if payload.get("protected_interiors_attached",true)!=false or payload.get("glazing_integrated",true)!=false or payload.get("collision_replacement_approved",true)!=false: return _no("prefab_must_not_claim_external_owner_or_collision_approval")
	var counts:=PackedInt32Array(); var owners: Array=[]; var total:=0
	for surface: int in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: return _no("triangle_mesh_required")
		var n:=mesh.surface_get_array_index_len(surface)
		if n==0: n=mesh.surface_get_array_len(surface)
		if n%3!=0: return _no("triangle_index_count")
		counts.append(n/3); total+=n/3
		if total>MAX_PARTS*12: return _no("modular_triangle_budget")
		var seen:=PackedByteArray(); seen.resize(n/3); owners.append(seen)
	if total!=payload.parts.size()*12: return _no("exact_twelve_triangles_per_box_required")
	var assigned:=0
	for id: int in payload.parts.size():
		var part: Variant=payload.parts[id]
		if not part is Dictionary or part.get("component_id")!=id or part.get("source_triangles")!=12 or part.get("closed_manifold")!=true or not part.get("source_faces") is Array or part.source_faces.size()!=12 or not part.get("profile") is Dictionary or not part.get("bounds") is AABB: return _no("part_identity_or_closed_box_contract")
		var profile: Dictionary=part.profile
		if profile.get("geometry_mode")!="measured_convex_solid" or profile.get("provenance")!="USER_AUTHORIZED_NEW_GAMEPLAY_TEMPLATE" or str(profile.get("profile_id","")).is_empty() or profile.get("material_class") not in ["wood","plaster","brick","stone","concrete","metal"] or not profile.get("reveal_material") is Material: return _no("explicit_generated_part_profile_required")
		for face: Variant in part.source_faces:
			if not face is Vector2i or face.x<0 or face.x>=counts.size() or face.y<0 or face.y>=counts[face.x] or owners[face.x][face.y]!=0: return _no("exact_disjoint_triangle_selectors_required")
			owners[face.x][face.y]=1; assigned+=1
	if assigned!=total: return _no("complete_triangle_selector_coverage_required")
	return {"ok":true,"payload":payload,"mesh_node":node,"surface_counts":counts,"source_triangles":total,"scene_mutated":false}

static func bind_record(instance: Node3D,original_record: Dictionary,collision_replacement_approved: bool=false) -> Dictionary:
	var started:=Time.get_ticks_usec()
	var valid:=validate_prefab(instance)
	if not valid.ok: return valid
	var payload: Dictionary=valid.payload; var node: MeshInstance3D=valid.mesh_node; var mesh: ArrayMesh=node.mesh
	if original_record.get("id")!=payload.source_id or original_record.get("assetId",original_record.get("asset_id"))!=payload.asset_id: return _no("original_record_identity_mismatch")
	if not original_record.get("runtime_extra_roots",[]).is_empty(): return _no("external_runtime_roots_require_owner_binding")
	var arrays: Array=[]; var materials: Array=[]; var components: Array=[]; var profiles: Array=[]
	for surface: int in mesh.get_surface_count(): arrays.append(mesh.surface_get_arrays(surface)); materials.append(node.get_active_material(surface))
	for part: Dictionary in payload.parts:
		components.append({"component_id":part.component_id,"source_faces":part.source_faces.duplicate(),"source_triangles":12,"closed_manifold":true,"bounds":payload.frame*part.bounds})
		profiles.append({"component_id":part.component_id,"source_faces":part.source_faces.duplicate(),"profile":part.profile.duplicate(true)})
	var partition: Dictionary={"ok":true,"provenance":PROVENANCE,"source_components":components,"source_snapshot":{"mesh":mesh,"surface_arrays":arrays,"materials":materials,"surface_counts":valid.surface_counts,"source_id":payload.source_id,"source_part_id":PART,"frame":payload.frame},"coverage":{"complete":true,"source_triangles":valid.source_triangles,"assigned_triangles":valid.source_triangles,"duplicates":0,"missing":0}}
	var profile: Dictionary={"geometry_mode":"compound_source_node","profile_id":"new_modular_building_v1","provenance":"USER_AUTHORIZED_NEW_GAMEPLAY_TEMPLATE","material_class":"mixed","components":profiles,"generated_partition":partition}
	var record: Dictionary=original_record.duplicate(true)
	record.component_profiles={PART:profile}
	# Explicit argument only, even when the input record already contained true.
	record.collision_replacement_approved=collision_replacement_approved
	record.modular_geometry_provenance=PROVENANCE
	record.modular_prefab_source_sha256=payload.source_sha256
	record.modular_owner_obligations=payload.owner_obligations.duplicate(true)
	return {"ok":true,"record":record,"component_profile":profile,"partition":partition,"mesh_node":node,"source":{"mesh":mesh,"current_mesh":mesh,"materials":materials,"source_id":payload.source_id,"source_part_id":PART,"label":PART},"frame":payload.frame,"bind_usec":Time.get_ticks_usec()-started,"geometry_rebuilt":false,"panels_census_run":false,"colliders_created":false,"collision_replacement_approved":collision_replacement_approved,"external_owner_integration_pending":true,"scene_mutated":false}
