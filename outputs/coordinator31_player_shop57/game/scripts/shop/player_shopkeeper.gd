extends Node3D
## Shopkeeper of the local preview: a standing character at the shop entrance who
## turns to the player and owns the "Поговорить" prompt position. He owns no
## money, no goods and no input: the host asks him for range and head position.
const DEFAULT_MODEL := "res://assets/hero.glb"
const MODEL_YAW_DEGREES := 180.0
const TURN_RANGE_M := 10.0
const TURN_SPEED := 6.0
var source_id := ""
var ready_for_use := false
var model_status := "created"
var _visual: Node3D
var _player: Node3D
var _height := 1.8
var _head := Vector3.ZERO
var _idle_yaw := 0.0
var _yaw := 0.0
var _mesh_count := 0
var _source_height := 0.0

func configure(at: Vector3, idle_yaw: float, source: String = "", model_path: String = DEFAULT_MODEL, target_height: float = 1.8) -> Dictionary:
	if ready_for_use:
		return {"ok": false, "reason": "already_configured"}
	if not at.is_finite() or not is_finite(idle_yaw):
		return {"ok": false, "reason": "invalid_transform"}
	source_id = source
	_height = target_height
	_idle_yaw = idle_yaw
	_yaw = idle_yaw
	global_position = at
	rotation.y = _yaw
	_visual = Node3D.new()
	_visual.name = "VisualHeading"
	_visual.rotation.y = deg_to_rad(MODEL_YAW_DEGREES)
	add_child(_visual)
	var loaded := _build_model(model_path)
	if not loaded.get("ok", false):
		_build_placeholder()
		model_status = str(loaded.get("reason", "model"))
	else:
		model_status = "source_model"
	_head = at + Vector3.UP * (_height + 0.34)
	ready_for_use = true
	return {
		"ok": true,
		"source_id": source_id,
		"model": model_status,
		"meshes": _mesh_count,
		"source_height_m": _source_height,
		"height_m": _height,
		"at": [at.x, at.y, at.z]
	}

func set_player(player: Node3D) -> void:
	_player = player

func head_world() -> Vector3:
	return _head

func height() -> float:
	return _height

func horizontal_distance(point: Vector3) -> float:
	var delta := point - global_position
	return Vector2(delta.x, delta.z).length()

func in_talk_range(point: Vector3, radius: float = 3.5) -> bool:
	if not ready_for_use or not point.is_finite():
		return false
	if absf(point.y - global_position.y) > 3.0:
		return false
	return horizontal_distance(point) <= radius

func snapshot() -> Dictionary:
	return {
		"source_id": source_id,
		"ready": ready_for_use,
		"model": model_status,
		"meshes": _mesh_count,
		"source_height_m": _source_height,
		"height_m": _height,
		"at": [global_position.x, global_position.y, global_position.z],
		"yaw": _yaw
	}

func _process(delta: float) -> void:
	if not ready_for_use or not is_instance_valid(_player):
		return
	if not is_finite(delta) or delta <= 0.0:
		return
	var target := _idle_yaw
	var delta_to_player := _player.global_position - global_position
	if Vector2(delta_to_player.x, delta_to_player.z).length() <= TURN_RANGE_M:
		# Face the visitor: the same greeting the residents use in version53.
		target = atan2(delta_to_player.x, delta_to_player.z)
	_yaw = lerp_angle(_yaw, target, clampf(delta * TURN_SPEED, 0.0, 1.0))
	rotation.y = _yaw

func _build_model(model_path: String) -> Dictionary:
	if not ResourceLoader.exists(model_path):
		return {"ok": false, "reason": "asset_missing"}
	var resource: Resource = load(model_path)
	var scene: PackedScene = resource as PackedScene
	if scene == null:
		return {"ok": false, "reason": "asset_not_packed_scene"}
	var instance: Node = scene.instantiate()
	var model: Node3D = instance as Node3D
	if model == null:
		instance.free()
		return {"ok": false, "reason": "asset_root"}
	var normalized := Node3D.new()
	normalized.name = "UniformModelScale"
	normalized.add_child(model)
	_visual.add_child(normalized)
	var bounds := AABB()
	var have_bounds := false
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.push_front(model)
	for node: Node in meshes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var to_model: Transform3D = normalized.global_transform.affine_inverse() * mesh_instance.global_transform
		var mesh_bounds: AABB = to_model * mesh_instance.get_aabb()
		bounds = bounds.merge(mesh_bounds) if have_bounds else mesh_bounds
		have_bounds = true
		_mesh_count += 1
	if not have_bounds or bounds.size.y <= 0.001 or not bounds.size.is_finite():
		normalized.queue_free()
		return {"ok": false, "reason": "asset_bounds"}
	_source_height = bounds.size.y
	var scale := _height / _source_height
	normalized.scale = Vector3.ONE * scale
	# Stand the model on the ground point instead of the authored pivot.
	normalized.position.y = -bounds.position.y * scale
	return {"ok": true}

func _build_placeholder() -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.30
	capsule.height = _height - 0.30
	capsule.radial_segments = 12
	capsule.rings = 4
	body.mesh = capsule
	body.position.y = (_height - 0.30) * 0.5 + 0.15
	_visual.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	sphere.radial_segments = 12
	sphere.rings = 6
	head.mesh = sphere
	head.position.y = _height - 0.16
	_visual.add_child(head)
	_mesh_count = 2
