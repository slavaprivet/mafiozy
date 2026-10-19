extends RefCounted
## Isolated static geometry admission; gameplay/interior authority is never enabled.
var _catalog: Dictionary = {}
var _resources: Dictionary = {}
var _objects: Dictionary = {}
var _trusted_adapters: Dictionary = {}
var _helpers := RegEx.new()
var packed_cache: Dictionary = {}
var resource_root := "res://assets/map_editor/"
var loads := 0

func _init() -> void:
	_helpers.compile("(?i)(^|[_\\s])(collision|collider|clearance|socket|anchor|keepout|nav|proxy|datum)([_\\s]|$)|^(COLLISION|SOCKET|CLEARANCE|NAV_|COL_)")

func configure(data: Dictionary, root_path: String = "res://assets/map_editor/", trusted_adapters: Dictionary = {}) -> bool:
	if data.get("schema", "") != "mafiozi.godot.map-editor-catalog/v1":
		return false
	if not _valid_v3(data.get("originM", null)) or not _finite_number(data.get("metresPerCell", null)) or not is_equal_approx(float(data.metresPerCell), 4.1):
		return false
	if root_path != "res://assets/map_editor/":
		return false
	var admitted_resources: Dictionary = {}
	var admitted_objects: Dictionary = {}
	for entry in data.get("resources", []):
		if not entry is Dictionary or not _valid_sha(entry.get("id", "")) or entry.get("sha256", "") != entry.id or admitted_resources.has(entry.id) or not _finite_number(entry.get("bytes", null)) or int(entry.bytes) < 20:
			return false
		admitted_resources[entry.id] = entry.duplicate(true)
	for entry in data.get("objects", []):
		if not entry is Dictionary or not entry.get("key", "") is String or str(entry.key).is_empty() or admitted_objects.has(entry.key):
			return false
		if entry.has("resourceId") and not admitted_resources.has(entry.resourceId):
			return false
		admitted_objects[entry.key] = entry.duplicate(true)
	for adapter in trusted_adapters.values():
		if not adapter is Callable or not adapter.is_valid():
			return false
	_catalog = {"originM": data.originM.duplicate(), "metresPerCell": data.metresPerCell}
	resource_root = root_path
	_resources = admitted_resources
	_objects = admitted_objects
	_trusted_adapters = trusted_adapters.duplicate()
	packed_cache.clear()
	loads = 0
	return true

func spawn_key(key: String, options: Dictionary = {}) -> Dictionary:
	if not _objects.has(key):
		return {"ok": false, "status": "unknown-source-object"}
	return spawn({"key": key}, options)

func cached_scene(resource_id: String) -> PackedScene:
	if packed_cache.has(resource_id):
		return packed_cache[resource_id] as PackedScene
	if not _valid_sha(resource_id) or not _resources.has(resource_id):
		return null
	var path := resource_root + resource_id + ".glb"
	var bytes := FileAccess.get_file_as_bytes(path)
	var entry: Dictionary = _resources[resource_id]
	if bytes.size() != int(entry.bytes):
		return null
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	if hashing.finish().hex_encode() != resource_id:
		return null
	var scene := load(path) as PackedScene
	if scene != null:
		packed_cache[resource_id] = scene
		loads += 1
	return scene

func spawn(object: Dictionary, options: Dictionary = {}) -> Dictionary:
	# External dictionary is a selector only, never an asset/geometry authority.
	var key := str(object.get("key", ""))
	if not _objects.has(key):
		return {"ok": false, "status": "unknown-source-object"}
	object = _objects[key]
	if not object.has("resourceId") or not object.has("sourceRecord"):
		return {"ok": false, "status": "pending-native-generator"}
	var source: Dictionary = object.sourceRecord
	var transform_data: Dictionary = source.get("transform", {})
	var horizontal: Array = transform_data.get("horizontalScale", [1.0, 1.0])
	var uniform := float(transform_data.get("uniformScale", 1.0))
	if not _valid_v3(object.get("positionLocalM", null)) or not _valid_v3(transform_data.get("modelLocalOffsetM", [0.0, 0.0, 0.0])):
		return {"ok": false, "status": "invalid-source-transform"}
	if horizontal.size() != 2 or not is_finite(uniform) or uniform <= 0.0 or not is_finite(float(horizontal[0])) or not is_finite(float(horizontal[1])) or float(horizontal[0]) <= 0.0 or float(horizontal[1]) <= 0.0 or not is_finite(float(transform_data.get("yawDegrees", 0.0))):
		return {"ok": false, "status": "invalid-source-transform"}
	var scene := cached_scene(str(object.resourceId))
	if scene == null:
		return {"ok": false, "status": "missing-or-unverified-native-resource"}
	var root := Node3D.new()
	root.name = str(source.id).validate_node_name()
	root.set_meta("source_id", source.id)
	root.set_meta("source_key", object.get("key", ""))
	root.set_meta("source_record", source.duplicate(true))
	root.set_meta("gameplay_active", false)
	root.set_meta("resource_id", object.resourceId)
	root.position = _v3(object.positionLocalM)
	root.rotation.y = deg_to_rad(float(transform_data.get("yawDegrees", 0.0)))
	var visual_transform := Node3D.new()
	visual_transform.name = "OriginalVisualTransform"
	visual_transform.scale = Vector3(uniform * float(horizontal[0]), uniform, uniform * float(horizontal[1]))
	var visual := scene.instantiate() as Node3D
	visual.position = _v3(transform_data.get("modelLocalOffsetM", [0.0, 0.0, 0.0]))
	visual_transform.add_child(visual)
	root.add_child(visual_transform)
	_hide_helpers(visual, source.get("hideNodeNames", []))
	var collisions: Array[StaticBody3D] = []
	var pending: Array[String] = []
	var special := str(source.get("role", "")) in ["district_detention", "bank_shell"] or str(source.get("assetId", "")).begins_with("bank_")
	if special:
		var adapter: Callable = _trusted_adapters.get("special_building", Callable())
		if adapter.is_valid():
			var admission: Variant = adapter.call(root, visual, source.duplicate(true))
			if not admission is Dictionary or not admission.get("ok", false) or not admission.get("handled", false):
				pending.append("special-building-author-adapter-required")
		else:
			pending.append("special-building-author-adapter-required")
	elif options.get("exterior_collisions", false):
		var origin := _v3(_catalog.originM)
		var cell := float(_catalog.metresPerCell)
		var inverse := root.transform.affine_inverse()
		var bodies: Array = source.get("collision", {}).get("worldBodies", [])
		for index in bodies.size():
			var body_data: Dictionary = bodies[index]
			var collision_layer := 1
			if body_data.get("carOnly", false):
				var layer_adapter: Callable = _trusted_adapters.get("vehicle_collision_layer", Callable())
				var admitted_layer: Variant = layer_adapter.call(source.duplicate(true), body_data.duplicate(true)) if layer_adapter.is_valid() else null
				if not admitted_layer is int or admitted_layer <= 0 or admitted_layer > 0xFFFFFFFF:
					pending.append("vehicle-layer-author-contract-required")
					continue
				collision_layer = admitted_layer
			var polygon: Array = body_data.get("polygonCR", [])
			if polygon.size() < 3 or not body_data.has("minYM") or not body_data.has("maxYM"):
				pending.append("unsupported-source-collider")
				continue
			var points := PackedVector3Array()
			for point: Array in polygon:
				for height in [float(body_data.minYM), float(body_data.maxYM)]:
					points.append(inverse * (Vector3(float(point[0]) * cell, height, float(point[1]) * cell) - origin))
			var shape := ConvexPolygonShape3D.new()
			shape.points = points
			var body := StaticBody3D.new()
			body.set_meta("source_id", source.id)
			body.set_meta("source_index", index)
			body.set_meta("source_body", body_data.duplicate(true))
			body.collision_layer = collision_layer
			var collision := CollisionShape3D.new()
			collision.shape = shape
			body.add_child(collision)
			root.add_child(body)
			collisions.append(body)
	return {"ok": true, "status": "native-static-geometry-only", "root": root, "visual": visual, "colliders": collisions, "pending": pending, "resource": scene, "gameplayActive": false}

func _v3(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _valid_v3(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component in value:
		if not typeof(component) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(component)):
			return false
	return true

func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

func _valid_sha(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character in value:
		if not character in "0123456789abcdef":
			return false
	return true

func _hide_helpers(node: Node, explicit_names: Array) -> void:
	var hidden := false
	for original in explicit_names:
		if str(node.name) == str(original) or str(node.name) == str(original).validate_node_name():
			hidden = true
	# Match export_preview_block.py exactly; no substring heuristics.
	hidden = hidden or _helpers.search(str(node.name)) != null
	if hidden and node is Node3D:
		(node as Node3D).visible = false
	for child in node.get_children():
		_hide_helpers(child, explicit_names)

