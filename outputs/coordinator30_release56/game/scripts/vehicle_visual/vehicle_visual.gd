extends RefCounted
## Presentation only. The host owns source identity, physics and occupancy.
## Geometry is imported once per instance with private editable resources.
const MAX_BYTES := 67108864
const MAX_NODES := 2048
const MAX_VERTICES := 2000000
const MAX_MANIFEST_BYTES := 4194304

var root: Node3D
var profile_id: String = ""
var entry: Dictionary = {}
var nodes: Dictionary = {}
var doors: Dictionary = {}
var wheels: Dictionary = {}
var _steering_wheel: Node3D
var _disposed := false

static func _sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func load_catalogue(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_MANIFEST_BYTES:
		return {"ok": false, "error": "manifest_size_or_missing"}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or parsed.get("schema") != "mafiozi.vehicle-visual.v1" or parsed.get("godot_forward") != "-Z":
		return {"ok": false, "error": "manifest_schema"}
	var entries: Variant = parsed.get("entries")
	if not entries is Array or entries.is_empty() or entries.size() > 64:
		return {"ok": false, "error": "manifest_entries"}
	var by_id: Dictionary = {}
	for value: Variant in entries:
		if not value is Dictionary:
			return {"ok": false, "error": "entry_type"}
		var id: Variant = value.get("profile_id")
		if not id is String or id.is_empty() or by_id.has(id):
			return {"ok": false, "error": "profile_identity"}
		by_id[id] = value.duplicate(true)
	return {"ok": true, "entries": by_id, "base_path": path.get_base_dir()}

static func instantiate_visual(record: Dictionary, base_path: String) -> Dictionary:
	var file_name: Variant = record.get("file")
	var expected_hash: Variant = record.get("sha256")
	var rows: Variant = record.get("nodes")
	var controls: Variant = record.get("controls")
	if not file_name is String or file_name.get_file() != file_name or not (file_name.ends_with(".glb") or file_name.ends_with(".glb.bytes")):
		return {"ok": false, "error": "asset_path"}
	if not expected_hash is String or expected_hash.length() != 64 or not rows is Array or rows.is_empty() or rows.size() > MAX_NODES or not controls is Dictionary:
		return {"ok": false, "error": "asset_contract"}
	var file := FileAccess.open(base_path.path_join(file_name), FileAccess.READ)
	if file == null or file.get_length() < 20 or file.get_length() > MAX_BYTES or file.get_length() != int(record.get("bytes", -1)):
		return {"ok": false, "error": "asset_size_or_missing"}
	var bytes := file.get_buffer(file.get_length())
	if _sha(bytes) != expected_hash:
		return {"ok": false, "error": "asset_hash"}
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_buffer(bytes, "", state, GLTFDocument.IMPORT_FLAG_FORCE_DISABLE_MESH_COMPRESSION) != OK:
		return {"ok": false, "error": "gltf_parse"}
	var generated := document.generate_scene(state)
	if not generated is Node3D:
		if is_instance_valid(generated):
			generated.free()
		return {"ok": false, "error": "gltf_scene"}
	var result = load("res://scripts/vehicle_visual/vehicle_visual.gd").new()
	result.root = generated
	result.profile_id = str(record.get("profile_id", ""))
	result.entry = record.duplicate(true)
	var error: String = result._bind(rows, controls)
	if not error.is_empty():
		result.dispose()
		return {"ok": false, "error": error}
	return {"ok": true, "visual": result, "material_status": "RENDER_REVIEW_REQUIRED"}

func _bind(rows: Array, controls: Dictionary) -> String:
	var stack: Array[Node] = [root]
	var count := 0
	var vertices := 0
	var materials: Dictionary = {}
	while not stack.is_empty():
		var node := stack.pop_back() as Node
		count += 1
		if count > MAX_NODES:
			return "node_limit"
		for child: Node in node.get_children():
			stack.append(child)
		if node is CollisionObject3D or node is Light3D or node is Camera3D or node is Skeleton3D:
			return "unexpected_gameplay_node"
		var key := str(node.name)
		if nodes.has(key):
			return "duplicate_node_key"
		nodes[key] = node
		if node is MeshInstance3D:
			if not node.mesh is ArrayMesh:
				return "mesh_type"
			# Loader/state are per-instance; explicit mesh/material copies also keep
			# later damage edits from affecting another visual or a cached import.
			var mesh := node.mesh.duplicate() as ArrayMesh
			var source_materials: Variant = entry.get("mesh_materials", {}).get(key)
			if not source_materials is Array:
				return "source_materials_missing"
			for surface in mesh.get_surface_count():
				vertices += mesh.surface_get_array_len(surface)
				if vertices > MAX_VERTICES:
					return "vertex_limit"
				var material := mesh.surface_get_material(surface)
				if not material is StandardMaterial3D:
					return "material_type"
				# glTF emits one primitive per source material group. Current source
				# factory uses scalar materials; reject an ambiguous mapping.
				if source_materials.size() != 1:
					return "source_material_group_mapping"
				var source_material: Dictionary = source_materials[0]
				var source_key: String = str(source_material.get("source_material_id", ""))
				if source_key.is_empty():
					return "source_material_identity"
				var owned: StandardMaterial3D
				if materials.has(source_key):
					owned = materials[source_key]
				else:
					owned = material.duplicate() as StandardMaterial3D
					owned.vertex_color_is_srgb = false
					owned.set_meta("source_material_id", source_key)
					owned.set_meta("source_metadata", source_material.get("source_metadata", {}).duplicate(true))
					materials[source_key] = owned
				mesh.surface_set_material(surface, owned)
			node.mesh = mesh
	for row: Variant in rows:
		if not row is Dictionary or not row.get("key") is String or not row.get("visible") is bool:
			return "node_contract"
		var node: Node3D = nodes.get(row.key) as Node3D
		if node == null:
			return "missing_source_node:" + str(row.key)
		node.visible = row.visible
		node.set_meta("source_name", str(row.get("source_name", "")))
		node.set_meta("source_metadata", row.get("source_metadata", {}).duplicate(true))
		if node is MeshInstance3D:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if row.get("cast_shadow", false) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if row.get("parent") != null and str(node.get_parent().name) != row.parent:
			return "source_parent_changed:" + row.key
	if not controls.get("doors") is Dictionary or not controls.get("wheels") is Dictionary:
		return "controls_contract"
	for id: String in controls.doors:
		var node: Node3D = nodes.get(controls.doors[id]) as Node3D
		if node == null or id not in ["front_left", "front_right", "rear_left", "rear_right"]:
			return "door_binding"
		doors[id] = node
	for id: String in controls.wheels:
		var wheel: Variant = controls.wheels[id]
		if not wheel is Dictionary or not wheel.get("front") is bool:
			return "wheel_contract"
		var pivot: Node3D = nodes.get(wheel.get("pivot")) as Node3D
		var spin: Node3D = nodes.get(wheel.get("spin")) as Node3D
		var radius: float = float(wheel.get("rolling_radius_m", 0.0))
		if pivot == null or spin == null or not is_finite(radius) or radius <= 0.0:
			return "wheel_binding"
		wheels[id] = {"pivot": pivot, "spin": spin, "front": wheel.front, "radius": radius}
	_steering_wheel = nodes.get(controls.get("steering_wheel")) as Node3D
	return "" if doors.size() in [2, 4] and wheels.size() == 4 and _steering_wheel != null else "incomplete_controls"

func set_door_amount(id: String, amount: float) -> bool:
	if _disposed or not is_instance_valid(root) or not doors.has(id) or not is_finite(amount):
		return false
	var door: Node3D = doors[id]
	# Imported nodes retain their source local frames under one basis wrapper.
	door.rotation.y = (-1.0 if id.ends_with("left") else 1.0) * clampf(amount, 0.0, 1.0) * 1.18
	return true

func update_wheels(steer: float, distance_delta_m: float, handbrake: bool = false) -> bool:
	if _disposed or not is_instance_valid(root) or not is_finite(steer) or not is_finite(distance_delta_m):
		return false
	for wheel: Dictionary in wheels.values():
		var pivot: Node3D = wheel.pivot
		var spin: Node3D = wheel.spin
		pivot.rotation.y = steer if wheel.front else 0.0
		if wheel.front or not handbrake:
			spin.rotation.x += distance_delta_m / float(wheel.radius)
	_steering_wheel.rotation.z = -steer * 2.1
	return true

func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	if is_instance_valid(root):
		root.free()
	root = null
	nodes.clear()
	doors.clear()
	wheels.clear()
	_steering_wheel = null
