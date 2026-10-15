extends RefCounted
## Reversible static lease. Caller owns whitelist, shared sun/sky admission and
## restores BEFORE moving/hiding/changing any source, ancestor or resource.
## No automatic scene scan, frame callback, physics change or GPU measurement.
const PRINTSHOP_ID := "REBUILD-VISUAL-print_shop-001"
const MAX_ROOTS := 32
const MAX_NODES := 4096
const MAX_INSTANCES := 64
const RENDER_PROPERTIES := ["layers", "cast_shadow", "extra_cull_margin", "ignore_occlusion_culling", "lod_bias", "gi_mode"]
var errors: Array[String] = []
var _groups: Array = []
var _hidden: Array = []
var _batches: Array = []
var _host: WeakRef
var _host_frame := Transform3D.IDENTITY
var _mesh_cache: Dictionary = {}
var _material_cache: Dictionary = {}
var _visited := 0
var _applied := false
var _stats: Dictionary = {}
var _receipts: Array = []

static func _digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

static func _positive_orthogonal(b: Basis, uniform: bool) -> bool:
	if not b.is_finite() or b.determinant() <= 0.00000001:
		return false
	var lengths := Vector3(b.x.length(), b.y.length(), b.z.length())
	if minf(lengths.x, minf(lengths.y, lengths.z)) <= 0.00001:
		return false
	var x := b.x / lengths.x
	var y := b.y / lengths.y
	var z := b.z / lengths.z
	if maxf(absf(x.dot(y)), maxf(absf(x.dot(z)), absf(y.dot(z)))) > 0.000001:
		return false
	return not uniform or maxf(lengths.x, maxf(lengths.y, lengths.z)) - minf(lengths.x, minf(lengths.y, lengths.z)) <= 0.000001 * maxf(lengths.x, maxf(lengths.y, lengths.z))

static func _resource_value(value: Variant) -> Variant:
	if value is Resource:
		return [value.get_class(), value.get_instance_id()]
	if value is Array:
		var result := []
		for item: Variant in value:
			result.append(_resource_value(item))
		return result
	if value is Dictionary:
		var result := {}
		var keys: Array = value.keys()
		keys.sort()
		for key: Variant in keys:
			result[key] = _resource_value(value[key])
		return result
	return value

func _material_payload(material: StandardMaterial3D) -> PackedByteArray:
	var id := material.get_instance_id()
	if _material_cache.has(id):
		return _material_cache[id]
	var values := {}
	for property: Dictionary in material.get_property_list():
		var key: String = property.name
		if int(property.usage) & PROPERTY_USAGE_STORAGE == 0 or key in ["resource_name", "resource_path", "resource_local_to_scene"] or key.begins_with("metadata/"):
			continue
		values[key] = _resource_value(material.get(key))
	var bytes := var_to_bytes(values)
	_material_cache[id] = bytes
	return bytes

func _mesh_payload(mesh: ArrayMesh, shadow: bool = false) -> PackedByteArray:
	if shadow and mesh.shadow_mesh != null:
		return PackedByteArray()
	var id := mesh.get_instance_id()
	if _mesh_cache.has(id):
		return _mesh_cache[id]
	if mesh.get_blend_shape_count() != 0 or mesh.custom_aabb != AABB():
		return PackedByteArray()
	var surfaces := []
	for index: int in range(mesh.get_surface_count()):
		var surface := RenderingServer.mesh_get_surface(mesh.get_rid(), index)
		if surface.is_empty() or not surface.has("vertex_data") or int(surface.get("vertex_count", 0)) <= 0 or surface.vertex_data.is_empty() or int(surface.get("primitive", -1)) != Mesh.PRIMITIVE_TRIANGLES:
			return PackedByteArray()
		if not surface.get("lods", []).is_empty() or not surface.get("skin_data", PackedByteArray()).is_empty() or not surface.get("blend_shape_data", PackedByteArray()).is_empty():
			return PackedByteArray()
		if int(surface.get("format", 0)) & Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE:
			return PackedByteArray()
		surface.erase("material") # Effective material is compared separately.
		surfaces.append(surface)
	var shadow_bytes := PackedByteArray()
	if mesh.shadow_mesh != null:
		if shadow or mesh.shadow_mesh == mesh:
			return PackedByteArray()
		shadow_bytes = _mesh_payload(mesh.shadow_mesh, true)
		if shadow_bytes.is_empty():
			return PackedByteArray()
	var bytes := var_to_bytes([surfaces, shadow_bytes, mesh.lightmap_size_hint])
	_mesh_cache[id] = bytes
	return bytes

func _rejection(node: MeshInstance3D, owner: Node3D, static_gi_admitted: bool = false) -> String:
	if not node.is_visible_in_tree() or node.mesh == null:
		return "hidden_or_empty"
	if not node.mesh is ArrayMesh or node.skin != null or node.get_node_or_null(node.skeleton) is Skeleton3D:
		return "unsupported_or_skinned"
	if node.get_child_count() != 0:
		return "non_leaf"
	if node.material_overlay != null or node.material_override != null:
		return "material_override_or_overlay"
	if (node.gi_mode != GeometryInstance3D.GI_MODE_DISABLED and not (static_gi_admitted and node.gi_mode == GeometryInstance3D.GI_MODE_STATIC)) or node.transparency != 0.0 or node.custom_aabb != AABB():
		return "gi_or_geometry_override"
	if node.visibility_range_begin != 0.0 or node.visibility_range_end != 0.0 or node.visibility_range_begin_margin != 0.0 or node.visibility_range_end_margin != 0.0 or not node.visibility_parent.is_empty():
		return "visibility_dependency"
	if node.sorting_offset != 0.0 or not node.sorting_use_aabb_center:
		return "sorting_override"
	if not node.global_transform.is_finite() or not _positive_orthogonal(node.global_basis, false):
		return "reflected_singular_or_sheared"
	var branch: Node = node
	while branch != null:
		if branch is PhysicsBody3D and not branch is StaticBody3D:
			return "dynamic_body_branch"
		if branch.get_script() != null:
			return "scripted_branch"
		if branch is Node3D and branch.top_level:
			return "top_level_branch"
		var branch_name := str(branch.name).to_lower()
		for word: String in ["door", "hinge", "handle", "interactive", "safe", "stockroom", "socket", "clearance"]:
			if word in branch_name:
				return "interactive_or_helper_branch"
		if branch == owner:
			break
		branch = branch.get_parent()
	if branch != owner:
		return "owner_mismatch"
	for index: int in range(node.mesh.get_surface_count()):
		if node.get_surface_override_material(index) != null:
			return "surface_override"
		var material := node.get_active_material(index)
		if not material is StandardMaterial3D or material.get_script() != null:
			return "unknown_material"
		if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.next_pass != null or material.blend_mode != BaseMaterial3D.BLEND_MODE_MIX or material.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or material.grow or material.fixed_size or material.use_particle_trails or material.proximity_fade_enabled or material.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED:
			return "non_static_material"
		if material.uv1_triplanar or material.uv2_triplanar:
			return "local_projection_material"
	return ""

func _render_values(node: GeometryInstance3D) -> Dictionary:
	var values := {}
	for key: String in RENDER_PROPERTIES:
		values[key] = node.get(key)
	return values

func _collect(node: Node, result: Array) -> void:
	_visited += 1
	if _visited > MAX_NODES:
		return
	if node is AnimationPlayer or node is AnimationTree or node is Skeleton3D or node is Light3D or node is ReflectionProbe or node is LightmapGI or node is VoxelGI:
		errors.append("Owner has animation, skeleton, local light or probe: " + str(node.name))
	if node is MeshInstance3D:
		result.append(node)
	for child: Node in node.get_children():
		_collect(child, result)

func _lighting_clear(node: Node, budget: Array) -> bool:
	budget[0] += 1
	if budget[0] > MAX_NODES * 4:
		return false
	if (node is Light3D and not node is DirectionalLight3D) or node is ReflectionProbe or node is LightmapGI or node is VoxelGI:
		return false
	if node is WorldEnvironment and node.environment != null and node.environment.sdfgi_enabled:
		return false
	for child: Node in node.get_children():
		if not _lighting_clear(child, budget):
			return false
	return true

## Invoke before introducing GI/local-light/probe dependencies; restore BEFORE
## activation. Conservative whole-tree preflight also runs at plan and commit.
func lighting_contract_valid() -> bool:
	if _host == null or not is_instance_valid(_host.get_ref()):
		return false
	var host: Node3D = _host.get_ref()
	return host.is_inside_tree() and _lighting_clear(host.get_tree().root, [0])

## Each declaration: root, source_id, static_authorized=true,
## shared_sun_sky_only=true. These are explicit caller guarantees, not detection.
func plan(host: Node3D, declarations: Array, chunk_m: float = 16.0) -> Dictionary:
	if _applied:
		return {"ok": false, "error": "Restore before replanning"}
	errors.clear()
	_groups.clear()
	_mesh_cache.clear()
	_material_cache.clear()
	_visited = 0
	_stats = {"ok": false, "visited": 0, "eligible": 0, "batched_sources": 0, "batch_nodes": 0, "surface_submissions_before": 0, "surface_submissions_after": 0, "rejections": {}}
	if not is_instance_valid(host) or not host.is_inside_tree() or not host.global_transform.is_finite() or not _positive_orthogonal(host.global_basis, false) or declarations.is_empty() or declarations.size() > MAX_ROOTS or not is_finite(chunk_m) or chunk_m < 1.0 or chunk_m > 32.0:
		errors.append("Invalid host, whitelist or chunk size")
		return _stats.duplicate(true)
	_host = weakref(host)
	_host_frame = host.global_transform
	if not lighting_contract_valid():
		errors.append("Global local-light, probe or GI dependency not admitted")
		return _stats.duplicate(true)
	var buckets := {}
	var seen := {}
	for declaration: Variant in declarations:
		if not declaration is Dictionary or declaration.get("static_authorized") != true or declaration.get("shared_sun_sky_only") != true or not declaration.get("root") is Node3D:
			errors.append("Explicit static and lighting declaration required")
			continue
		var owner: Node3D = declaration.root
		var source_id: String = declaration.get("source_id", "")
		if not is_instance_valid(owner) or not host.is_ancestor_of(owner) or source_id.is_empty() or source_id == PRINTSHOP_ID or owner.get_meta("source_id", "") != source_id or (not source_id.begins_with("REBUILD-VISUAL-") and not source_id.begins_with("LAMP-")):
			errors.append("Unknown or excluded owner")
			continue
		var nodes := []
		_collect(owner, nodes)
		for node: MeshInstance3D in nodes:
			if seen.has(node.get_instance_id()):
				errors.append("Overlapping owner declarations")
				continue
			seen[node.get_instance_id()] = true
			var static_gi: bool = declaration.get("allow_static_gi_without_capture", false) == true
			var reason := _rejection(node, owner, static_gi)
			var payload := PackedByteArray()
			var materials := []
			if reason.is_empty():
				payload = _mesh_payload(node.mesh)
				if payload.is_empty():
					reason = "mesh_lod_skin_or_unknown_buffers"
				for index: int in range(node.mesh.get_surface_count()):
					materials.append(_material_payload(node.get_active_material(index)))
			var box := node.global_transform * node.get_aabb()
			box = box.grow(node.extra_cull_margin)
			var start := Vector2i(floori(box.position.x / chunk_m), floori(box.position.z / chunk_m))
			var end := Vector2i(floori(box.end.x / chunk_m), floori(box.end.z / chunk_m))
			if reason.is_empty() and (start != end or not box.position.is_finite() or not box.size.is_finite()):
				reason = "spans_chunk"
			if not reason.is_empty():
				_stats.rejections[reason] = int(_stats.rejections.get(reason, 0)) + 1
				continue
			_stats.eligible += 1
			var state := _render_values(node)
			var material_bytes := var_to_bytes(materials)
			var key := str([owner.get_instance_id(), source_id, start, _digest(payload), _digest(material_bytes), _digest(var_to_bytes(state))])
			if not buckets.has(key):
				buckets[key] = []
			var entry := {"node": weakref(node), "owner": weakref(owner), "source_id": source_id, "mesh": node.mesh, "payload": payload, "materials": material_bytes, "state": state, "frame": node.global_transform, "visible": node.visible, "parent": node.get_parent().get_instance_id(), "box": box, "static_gi": static_gi}
			var assigned := false
			for group: Dictionary in buckets[key]:
				if group.entries.size() >= MAX_INSTANCES or group.payload != payload or group.materials != material_bytes:
					continue
				var relative: Basis = group.basis.inverse() * node.global_basis
				if _positive_orthogonal(relative, true):
					group.entries.append(entry)
					group.box = group.box.merge(box)
					assigned = true
					break
			if not assigned:
				buckets[key].append({"basis": node.global_basis, "entries": [entry], "box": box, "payload": payload, "materials": material_bytes})
	if _visited > MAX_NODES:
		errors.append("Node budget exceeded")
	for bucket: Array in buckets.values():
		for group: Dictionary in bucket:
			if group.entries.size() < 2:
				continue
			_groups.append(group)
			var count: int = group.entries.size()
			var surfaces: int = group.entries[0].mesh.get_surface_count()
			_stats.batched_sources += count
			_stats.batch_nodes += 1
			_stats.surface_submissions_before += count * surfaces
			_stats.surface_submissions_after += surfaces
	_stats.visited = _visited
	_stats.ok = errors.is_empty()
	_stats["errors"] = errors.duplicate()
	if not _stats.ok:
		_groups.clear()
		_stats.batched_sources = 0
		_stats.batch_nodes = 0
		_stats.surface_submissions_before = 0
		_stats.surface_submissions_after = 0
	return _stats.duplicate(true)

func apply() -> bool:
	if _applied or not _stats.get("ok", false) or _host == null:
		return false
	var host: Node3D = _host.get_ref()
	if not is_instance_valid(host) or host.global_transform != _host_frame:
		errors.append("Host changed after plan")
		return false
	if not lighting_contract_valid():
		errors.append("Lighting changed after plan")
		return false
	var owners := {}
	_visited = 0
	for group: Dictionary in _groups:
		var owner: Node3D = group.entries[0].owner.get_ref()
		if not is_instance_valid(owner):
			return false
		if not owners.has(owner.get_instance_id()):
			owners[owner.get_instance_id()] = true
			_collect(owner, [])
	if not errors.is_empty() or _visited > MAX_NODES:
		errors.append("Owner dependencies changed after plan")
		return false
	# Refresh signatures once before committing: resource/owner mutation fails closed.
	_mesh_cache.clear()
	_material_cache.clear()
	for group: Dictionary in _groups:
		for entry: Dictionary in group.entries:
			var node: MeshInstance3D = entry.node.get_ref()
			var owner: Node3D = entry.owner.get_ref()
			if not is_instance_valid(node) or not is_instance_valid(owner) or not host.is_ancestor_of(owner) or not _rejection(node, owner, entry.static_gi).is_empty() or node.global_transform != entry.frame or node.visible != entry.visible or node.mesh != entry.mesh or node.get_parent().get_instance_id() != entry.parent or owner.get_meta("source_id", "") != entry.source_id or _render_values(node) != entry.state or _mesh_payload(node.mesh) != entry.payload:
				errors.append("Source changed after plan")
				return false
			var materials := []
			for index: int in range(node.mesh.get_surface_count()):
				materials.append(_material_payload(node.get_active_material(index)))
			if var_to_bytes(materials) != entry.materials:
				errors.append("Material changed after plan")
				return false
	for group: Dictionary in _groups:
		var first: Dictionary = group.entries[0]
		var batch_frame := Transform3D(group.basis, group.box.get_center())
		var inverse := batch_frame.affine_inverse()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = first.mesh
		multi.instance_count = group.entries.size()
		var box := AABB()
		var ids := []
		var frames := []
		var source_nodes := []
		for index: int in range(group.entries.size()):
			var entry: Dictionary = group.entries[index]
			var frame: Transform3D = inverse * entry.frame
			multi.set_instance_transform(index, frame)
			frames.append(frame)
			source_nodes.append(entry.node)
			var local_box: AABB = frame * entry.mesh.get_aabb()
			box = local_box if index == 0 else box.merge(local_box)
			ids.append(entry.source_id)
		multi.custom_aabb = box
		var batch := MultiMeshInstance3D.new()
		batch.name = "StaticBatch_%d" % _batches.size()
		batch.multimesh = multi
		for property: String in RENDER_PROPERTIES:
			batch.set(property, first.state[property])
		var owner: Node3D = first.owner.get_ref()
		batch.transform = owner.global_transform.affine_inverse() * batch_frame
		batch.set_meta("source_ids", ids)
		owner.add_child(batch)
		_batches.append(weakref(batch))
		_receipts.append({"batch": weakref(batch), "instance_transforms": frames, "custom_aabb": box, "source_ids": ids, "source_nodes": source_nodes, "mesh_payload_sha256": _digest(first.payload), "material_payload_sha256": _digest(first.materials)})
	for group: Dictionary in _groups:
		for entry: Dictionary in group.entries:
			var node: MeshInstance3D = entry.node.get_ref()
			node.visible = false
			_hidden.append({"node": entry.node, "visible": entry.visible})
	_applied = true
	# Signatures are startup/precommit scratch, not a second retained mesh store.
	_groups.clear()
	_mesh_cache.clear()
	_material_cache.clear()
	return true

func restore() -> void:
	for reference: WeakRef in _batches:
		var batch: Node = reference.get_ref()
		if is_instance_valid(batch):
			batch.free()
	_batches.clear()
	_receipts.clear()
	for entry: Dictionary in _hidden:
		var node: MeshInstance3D = entry.node.get_ref()
		if is_instance_valid(node):
			node.visible = entry.visible
	_hidden.clear()
	_applied = false
	_groups.clear()
	_mesh_cache.clear()
	_material_cache.clear()
	_stats.clear()

func batch_nodes() -> Array:
	var result := []
	for reference: WeakRef in _batches:
		var node: Node = reference.get_ref()
		if is_instance_valid(node):
			result.append(node)
	return result

## CPU upload arguments, not native renderer readback (headless dummy does not
## retain MultiMesh transforms). Useful for independent geometry admission.
func batch_receipts() -> Array:
	return _receipts.duplicate(true)
