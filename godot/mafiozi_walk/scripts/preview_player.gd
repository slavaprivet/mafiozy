class_name WalkPreviewPlayer
extends CharacterBody3D
## Local migration preview only: no health, inventory, ownership or persistence.

@export_file("*.glb", "*.tscn") var hero_scene_path: String = "res://assets/hero.glb"
@export var model_target_height: float = 1.9
## Imported glTF characters face +Z; the movement heading uses Godot's -Z.
@export var visual_yaw_degrees: float = 180.0
@export var walk_speed: float = 3.2
@export var run_speed: float = 5.8
@export var acceleration: float = 18.0
@export var jump_speed: float = 5.2
@export var mouse_sensitivity: float = 0.003
@export var camera_distance: float = 4.8

const ACTION_LEFT: StringName = &"preview_move_left"
const ACTION_RIGHT: StringName = &"preview_move_right"
const ACTION_FORWARD: StringName = &"preview_move_forward"
const ACTION_BACK: StringName = &"preview_move_back"
const ACTION_RUN: StringName = &"preview_run"
const ACTION_JUMP: StringName = &"preview_jump"
const ACTION_CAPTURE: StringName = &"preview_capture_mouse"

var _visual: Node3D
var _yaw_pivot: Node3D
var _spring_arm: SpringArm3D
var _camera: Camera3D
var _gravity: float = 9.8
var _heading: float = 0.0
var _camera_yaw: float = 0.0
var _camera_pitch: float = -0.24
var _right_mouse_down: bool = false
var _model_loaded: bool = false
var _model_error: String = ""
var _source_height: float = 0.0
var _model_scale: float = 1.0
var _mesh_count: int = 0
var _animation_names: PackedStringArray = PackedStringArray()
var _vertex_color_surfaces: int = 0
var _material_names: PackedStringArray = PackedStringArray()


func _ready() -> void:
	name = "PreviewPlayer"
	_ensure_input_actions()
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(46.0)
	floor_stop_on_slope = true
	up_direction = Vector3.UP
	collision_layer = 2
	collision_mask = 1
	_build_collision()
	_build_visual()
	_build_camera()
	set_process_unhandled_input(true)


func _build_collision() -> void:
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.height = model_target_height
	shape.radius = 0.30
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "PlayerCapsule"
	collider.shape = shape
	collider.position.y = model_target_height * 0.5
	add_child(collider)


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "VisualHeading"
	_visual.rotation.y = deg_to_rad(visual_yaw_degrees)
	add_child(_visual)
	if not ResourceLoader.exists(hero_scene_path):
		_model_error = "Hero asset unavailable: " + hero_scene_path
		_build_missing_asset_marker()
		return
	var resource: Resource = load(hero_scene_path)
	var hero_scene: PackedScene = resource as PackedScene
	if hero_scene == null:
		_model_error = "Hero asset is not an imported PackedScene"
		_build_missing_asset_marker()
		return
	var hero_node: Node = hero_scene.instantiate()
	var hero: Node3D = hero_node as Node3D
	if hero == null:
		hero_node.free()
		_model_error = "Hero scene has no Node3D root"
		_build_missing_asset_marker()
		return
	var normalized: Node3D = Node3D.new()
	normalized.name = "UniformModelScale"
	_visual.add_child(normalized)
	normalized.add_child(hero)
	# Merge actual imported mesh bounds in one coordinate space before scaling.
	var bounds: AABB = AABB()
	var have_bounds: bool = false
	var meshes: Array[Node] = hero.find_children("*", "MeshInstance3D", true, false)
	if hero is MeshInstance3D:
		meshes.push_front(hero)
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
		_model_error = "Hero asset has invalid mesh bounds"
		_build_missing_asset_marker()
		return
	_source_height = bounds.size.y
	_model_scale = model_target_height / _source_height
	normalized.scale = Vector3.ONE * _model_scale
	var center: Vector3 = bounds.get_center()
	normalized.position = Vector3(-center.x, -bounds.position.y, -center.z) * _model_scale
	_model_loaded = true
	_restore_authored_vertex_colors(meshes)
	# Import discovery is diagnostic only. No procedural Walk animation is claimed.
	var animation_players: Array[Node] = hero.find_children("*", "AnimationPlayer", true, false)
	for node: Node in animation_players:
		var animation_player: AnimationPlayer = node as AnimationPlayer
		for animation_name: String in animation_player.get_animation_list():
			if animation_name != "RESET" and not _animation_names.has(animation_name):
				_animation_names.append(animation_name)
		animation_player.stop()


func _restore_authored_vertex_colors(meshes: Array[Node]) -> void:
	# This GLB stores its actual palette in linear COLOR_0, not flat material
	# albedo. Godot's imported materials currently leave vertex albedo disabled.
	# Override instances with copies so imported/shared resources stay immutable.
	var copies: Dictionary = {}
	for node: Node in meshes:
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface: int in range(instance.mesh.get_surface_count()):
			var original: BaseMaterial3D = instance.get_active_material(surface) as BaseMaterial3D
			if original == null or original.resource_name not in ["FABRIC", "HAIR", "SKIN", "TRIM"]:
				continue
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if colors.is_empty() or colors.size() != vertices.size():
				push_warning("Canonical hero surface lacks COLOR_0: " + str(instance.name))
				continue
			var material_id: int = original.get_instance_id()
			var restored: BaseMaterial3D = copies.get(material_id) as BaseMaterial3D
			if restored == null:
				restored = original.duplicate() as BaseMaterial3D
				restored.vertex_color_use_as_albedo = true
				restored.vertex_color_is_srgb = false
				copies[material_id] = restored
				_material_names.append(original.resource_name)
			instance.set_surface_override_material(surface, restored)
			_vertex_color_surfaces += 1


func _build_missing_asset_marker() -> void:
	# Explicit magenta diagnostic, never a silent replacement for the real hero.
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.name = "MISSING_HERO_ASSET"
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = 0.30
	mesh.height = model_target_height
	marker.mesh = mesh
	marker.position.y = model_target_height * 0.5
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.0, 0.65)
	marker.material_override = material
	_visual.add_child(marker)
	push_warning(_model_error)


func _build_camera() -> void:
	_yaw_pivot = Node3D.new()
	_yaw_pivot.name = "CameraYaw"
	_yaw_pivot.position.y = model_target_height * 0.79
	add_child(_yaw_pivot)
	_spring_arm = SpringArm3D.new()
	_spring_arm.name = "CameraSpringArm"
	_spring_arm.spring_length = camera_distance
	_spring_arm.margin = 0.16
	_spring_arm.collision_mask = 1
	# A sphere also protects near-plane corners at oblique walls.
	var camera_shape: SphereShape3D = SphereShape3D.new()
	camera_shape.radius = 0.24
	_spring_arm.shape = camera_shape
	_yaw_pivot.add_child(_spring_arm)
	_spring_arm.add_excluded_object(get_rid())
	_camera = Camera3D.new()
	_camera.name = "PlayerCamera"
	_camera.fov = 65.0
	_camera.near = 0.08
	_camera.far = 1600.0
	_spring_arm.add_child(_camera)
	_camera.make_current()
	_update_camera_rotation()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	var typing: bool = _text_control_focused()
	var axes: Vector2 = Vector2.ZERO
	if not typing:
		axes = Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_FORWARD, ACTION_BACK)
	var direction: Vector3 = Basis(Vector3.UP, _camera_yaw) * Vector3(axes.x, 0.0, axes.y)
	var speed: float = run_speed if Input.is_action_pressed(ACTION_RUN) else walk_speed
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	if not typing and Input.is_action_just_pressed(ACTION_JUMP) and is_on_floor():
		velocity.y = jump_speed
	if direction.length_squared() > 0.001:
		var target_heading: float = atan2(-direction.x, -direction.z)
		_heading = lerp_angle(_heading, target_heading, minf(1.0, delta * 12.0))
		_visual.rotation.y = _heading + deg_to_rad(visual_yaw_degrees)
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE:
				set_mouse_captured(false)
				get_viewport().set_input_as_handled()
				return
			if not _text_control_focused() and key.is_action_pressed(ACTION_CAPTURE):
				set_mouse_captured(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_right_mouse_down = button.pressed
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if (_right_mouse_down and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_camera_yaw -= motion.relative.x * mouse_sensitivity
			_camera_pitch = clampf(_camera_pitch - motion.relative.y * mouse_sensitivity, -1.05, 0.45)
			_update_camera_rotation()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_mouse_captured(false)


func _exit_tree() -> void:
	set_mouse_captured(false)


func _update_camera_rotation() -> void:
	if is_instance_valid(_yaw_pivot) and is_instance_valid(_spring_arm):
		_yaw_pivot.rotation.y = _camera_yaw
		_spring_arm.rotation.x = _camera_pitch


func _text_control_focused() -> bool:
	var focused: Control = get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit


func set_mouse_captured(captured: bool) -> void:
	_right_mouse_down = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func get_preview_camera() -> Camera3D:
	return _camera


func get_preview_status() -> Dictionary:
	return {
		"model_loaded": _model_loaded,
		"model_error": _model_error,
		"source_mesh_count": _mesh_count,
		"source_height_m": _source_height,
		"uniform_scale": _model_scale,
		"height_m": model_target_height,
		"animations_found": _animation_names.duplicate(),
		"animation_status": "Imported static pose; Walk animations are not migrated",
		"vertex_color_surfaces": _vertex_color_surfaces,
		"material_names": _material_names.duplicate(),
		"grounded": is_on_floor(),
		"speed_mps": Vector2(velocity.x, velocity.z).length(),
		"mouse_captured": Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
	}


func _ensure_input_actions() -> void:
	_ensure_keys(ACTION_LEFT, [KEY_A, KEY_LEFT])
	_ensure_keys(ACTION_RIGHT, [KEY_D, KEY_RIGHT])
	_ensure_keys(ACTION_FORWARD, [KEY_W, KEY_UP])
	_ensure_keys(ACTION_BACK, [KEY_S, KEY_DOWN])
	_ensure_keys(ACTION_RUN, [KEY_SHIFT])
	_ensure_keys(ACTION_JUMP, [KEY_SPACE])
	_ensure_keys(ACTION_CAPTURE, [KEY_TAB])


func _ensure_keys(action: StringName, key_codes: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for code: int in key_codes:
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = code as Key
		InputMap.action_add_event(action, key)
