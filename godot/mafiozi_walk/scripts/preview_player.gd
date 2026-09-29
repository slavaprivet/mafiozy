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
const LocomotionPose = preload("res://scripts/preview_locomotion.gd")
const AirbornePose = preload("res://scripts/preview_airborne.gd")
const DivePose = preload("res://scripts/preview_dive.gd")
const SOURCE_JUMP_RADIUS := 0.36

var _visual: Node3D
var _yaw_pivot: Node3D
var _spring_arm: SpringArm3D
var _camera: Camera3D
var _gravity: float = 9.8
var _heading: float = 0.0
var _camera_yaw: float = 0.0
var _camera_pitch: float = -0.24
var _right_mouse_down: bool = false
var _free_mouse_look: bool = false
var _model_loaded: bool = false
var _model_error: String = ""
var _source_height: float = 0.0
var _model_scale: float = 1.0
var _mesh_count: int = 0
var _animation_names: PackedStringArray = PackedStringArray()
var _vertex_color_surfaces: int = 0
var _material_names: PackedStringArray = PackedStringArray()
var _locomotion: LocomotionPose
var _airborne: AirbornePose
var _pose_skeleton: Skeleton3D
var _pose_motion: Node3D
var _pose_authority: StringName = &"on_foot"
var _pose_epoch: int = 0
var _pose_revision: int = 0
const MELEE_POSE_RECEIPT := &"melee_skin_pose"
var _pose_affine_active := false
var _pose_affine_globals: Array[Transform3D] = []
var _dive: RefCounted
var _jump: Dictionary = {}
var _jump_pose: Dictionary = {}
var _jump_surface_guard: Callable
var _jump_event_consumed: bool = false
var _jump_key_down: bool = false
var _jump_actual_velocity := Vector3.ZERO
var _jump_permission_shape: CapsuleShape3D
var _jump_query: PhysicsShapeQueryParameters3D
var _jump_floor_ray: PhysicsRayQueryParameters3D
var _jump_ceiling_ray: PhysicsRayQueryParameters3D
var _jump_physics_visible: bool = true
var _source_falling: bool = false
var _hit_pose_decorator: Callable
var _melee_practice: Node


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
	_jump_permission_shape = CapsuleShape3D.new()
	_jump_permission_shape.radius = SOURCE_JUMP_RADIUS
	_jump_permission_shape.height = model_target_height
	_jump_query = PhysicsShapeQueryParameters3D.new()
	_jump_query.shape = _jump_permission_shape
	_jump_query.collision_mask = collision_mask
	_jump_query.exclude = [get_rid()]
	_jump_query.margin = 0.001
	_jump_floor_ray = PhysicsRayQueryParameters3D.new()
	_jump_floor_ray.collision_mask = collision_mask
	_jump_floor_ray.exclude = [get_rid()]
	_jump_ceiling_ray = PhysicsRayQueryParameters3D.new()
	_jump_ceiling_ray.collision_mask = collision_mask
	_jump_ceiling_ray.exclude = [get_rid()]
	set_process_unhandled_input(true)
	set_mouse_captured(false)


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
	var visual_motion: Node3D = Node3D.new()
	visual_motion.name = "LocomotionOffset"
	_visual.add_child(visual_motion)
	visual_motion.add_child(normalized)
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
	# Embedded clips stay disabled; the canonical procedural gait owns this rig.
	var animation_players: Array[Node] = hero.find_children("*", "AnimationPlayer", true, false)
	for node: Node in animation_players:
		var animation_player: AnimationPlayer = node as AnimationPlayer
		for animation_name: String in animation_player.get_animation_list():
			if animation_name != "RESET" and not _animation_names.has(animation_name):
				_animation_names.append(animation_name)
		animation_player.stop()
	_locomotion = LocomotionPose.new()
	if not _locomotion.bind(hero, visual_motion):
		push_warning(str(_locomotion.get_status().get("error", "Locomotion bind failed")))
		return
	_pose_skeleton = hero.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_pose_motion = visual_motion
	_airborne = AirbornePose.new()
	if not _airborne.bind(hero, visual_motion):
		push_warning(str(_airborne.get_status().get("error", "Airborne bind failed")))
	_dive = DivePose.new()
	if not _dive.bind(hero, visual_motion):
		push_warning("Canonical source dive bind failed")
		_dive = null


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
	_jump_pose = {}
	if is_instance_valid(_melee_practice): _melee_practice.advance(delta)
	if _pose_authority != &"on_foot":
		_jump_event_consumed = false
		return # External owner owns movement as well as the final pose.
	if _free_mouse_look and not _jump_event_consumed and not _text_control_focused() and Input.is_action_just_pressed(ACTION_JUMP):
		_request_preview_jump(float(Time.get_ticks_msec()))
	_jump_event_consumed = false
	if not _jump.is_empty():
		_advance_preview_jump(delta)
		_update_owned_pose(delta)
		return
	if _source_falling and (not _jump_frame_visible() or not is_finite(delta) or delta <= 0.0 or delta > 1.0):
		_update_owned_pose(0.0)
		return
	var source_fall_next_velocity := velocity.y
	if not is_on_floor():
		if _source_falling:
			var fall_dt := minf(delta, 0.1)
			source_fall_next_velocity = velocity.y - 18.0 * fall_dt
			velocity.y = (velocity.y * fall_dt - 9.0 * fall_dt * fall_dt) / _body_motion_delta()
		else:
			velocity.y -= _gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
		_source_falling = false
	var typing: bool = not _free_mouse_look or _text_control_focused()
	var axes: Vector2 = Vector2.ZERO
	if not typing:
		axes = Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_FORWARD, ACTION_BACK)
	var direction: Vector3 = Basis(Vector3.UP, _camera_yaw) * Vector3(axes.x, 0.0, axes.y)
	var speed: float = run_speed if Input.is_action_pressed(ACTION_RUN) else walk_speed
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	if direction.length_squared() > 0.001:
		var target_heading: float = atan2(-direction.x, -direction.z)
		_heading = lerp_angle(_heading, target_heading, minf(1.0, delta * 12.0))
		_visual.rotation.y = _heading + deg_to_rad(visual_yaw_degrees)
	move_and_slide()
	if _source_falling:
		if is_on_floor():
			_source_falling = false
			velocity.y = 0.0
		else:
			velocity.y = source_fall_next_velocity
	_update_owned_pose(delta)


func set_preview_jump_surface_guard(guard: Callable) -> void:
	_jump_surface_guard = guard


func _body_motion_delta() -> float:
	# CharacterBody3D.move_and_slide uses this same engine context delta, not
	# our source substep. Normal runtime calls are inside the physics frame.
	return maxf(get_physics_process_delta_time() if Engine.is_in_physics_frame() else get_process_delta_time(), 0.000001)


func _jump_direction() -> Vector2:
	var axes := Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_FORWARD, ACTION_BACK)
	var world := Basis(Vector3.UP, _camera_yaw) * Vector3(axes.x, 0.0, axes.y)
	return Vector2(world.x, world.z).normalized()


func _request_preview_jump(now_ms: float) -> bool:
	if not _free_mouse_look or _pose_authority != &"on_foot" or _text_control_focused() or not _jump_physics_visible or _dive == null or not is_finite(now_ms):
		return false
	var direction := _jump_direction()
	if not _jump.is_empty():
		if direction.is_zero_approx():
			direction = _jump.direction
		if direction.is_zero_approx():
			direction = Vector2(-sin(_camera_yaw), -cos(_camera_yaw))
		var next: Dictionary = DivePose.cinematic_upgrade(_jump, direction, now_ms, global_position.y - float(_jump.base_y))
		var changed: bool = _jump.mode != next.mode
		_jump = next
		return changed
	if not is_on_floor() or not _jump_surface_allowed(global_position):
		return false
	var support: Dictionary = _jump_surfaces(global_position, global_position.y)
	var base_y: float = support.floor if is_finite(support.floor) else global_position.y
	_jump = {"elapsed": 0.0, "startedAt": now_ms, "mode": "normal", "direction": direction,
		"progress": 0.0, "diveBlend": 0.0, "base_y": base_y, "falling": false,
		"fall_velocity": 0.0, "ceilingHit": false, "blocked": false, "done": false, "grounded": true}
	_source_falling = false
	_airborne.reset()
	_dive.reset()
	_locomotion.reset_state()
	_heading = _camera_yaw
	_visual.rotation.y = _camera_yaw + PI - global_rotation.y
	return true


func _jump_surface_allowed(at: Vector3) -> bool:
	return bool(_jump_surface_guard.call(at, SOURCE_JUMP_RADIUS)) if _jump_surface_guard.is_valid() else true


func _jump_horizontal_allowed(from: Vector3, motion: Vector3) -> bool:
	if not _jump_surface_allowed(from + motion):
		return false
	_jump_query.transform = Transform3D(Basis.IDENTITY, from + Vector3.UP * (model_target_height * 0.5 + 0.002))
	_jump_query.motion = motion
	var fractions := get_world_3d().direct_space_state.cast_motion(_jump_query)
	if fractions.size() != 2 or fractions[0] < 0.99999:
		return false
	# A cast may round a barely overlapping endpoint to safe=1; its next cast
	# then ignores that initially overlapping wall. Admit only a clear endpoint.
	_jump_query.transform.origin += motion
	_jump_query.motion = Vector3.ZERO
	return get_world_3d().direct_space_state.intersect_shape(_jump_query, 1).is_empty()


func _permitted_jump_horizontal(requested: Vector3, foot_y: float) -> Vector3:
	# Source's <=.12m walk samples and X/Z slide order, with an additional exact
	# radius.36 capsule sweep so a thin solid wall cannot be skipped by a sample.
	var count := maxi(1, ceili(requested.length() / 0.12))
	var step := requested / float(count)
	var accepted := Vector3.ZERO
	var start := Vector3(global_position.x, foot_y, global_position.z)
	for i in range(count):
		var here := start + accepted
		if _jump_horizontal_allowed(here, step):
			accepted += step
		elif not is_zero_approx(step.x) and _jump_horizontal_allowed(here, Vector3(step.x, 0, 0)):
			accepted.x += step.x
		elif not is_zero_approx(step.z) and _jump_horizontal_allowed(here, Vector3(0, 0, step.z)):
			accepted.z += step.z
	if accepted.distance_to(requested) > 0.00001:
		_jump.blocked = true
	return accepted


func _jump_surfaces(at: Vector3, probe_y: float) -> Dictionary:
	_jump_floor_ray.from = Vector3(at.x, probe_y + 0.02, at.z)
	_jump_floor_ray.to = Vector3(at.x, probe_y - 2000.0, at.z)
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(_jump_floor_ray)
	_jump_ceiling_ray.from = Vector3(at.x, global_position.y + 0.04, at.z)
	_jump_ceiling_ray.to = Vector3(at.x, global_position.y + 2000.0, at.z)
	var ceiling_hit := get_world_3d().direct_space_state.intersect_ray(_jump_ceiling_ray)
	return {"floor": floor_hit.position.y if not floor_hit.is_empty() else -INF,
		"ceiling": ceiling_hit.position.y if not ceiling_hit.is_empty() else INF}


func _jump_frame_visible() -> bool:
	return _jump_physics_visible and (DisplayServer.get_name() == "headless" or (get_window().visible and get_window().mode != Window.MODE_MINIMIZED))


func _advance_preview_jump(delta: float) -> void:
	var visible := _jump_frame_visible()
	var steps: PackedFloat64Array = DivePose.frame_steps(delta, visible)
	var frame_start := global_position
	var consumed := 0.0
	var engine_step := _body_motion_delta()
	var old_snap := floor_snap_length
	floor_snap_length = 0.0
	for dt: float in steps:
		if _jump.is_empty():
			break
		var cinematic: bool = _jump.get("profile", "") == DivePose.CINEMATIC_PROFILE
		var flight: float = DivePose.CINEMATIC_FLIGHT if cinematic else DivePose.FLIGHT
		var next: Dictionary = DivePose.cinematic_proposal(_jump, dt)
		if not next.get("valid", false):
			_jump.clear()
			break
		var desired_y: float = float(_jump.base_y) + (0.0 if cinematic and float(_jump.contact_elapsed) >= 0.0 else float(next.arc_y))
		var direction: Vector2 = _jump.direction
		var horizontal := _permitted_jump_horizontal(Vector3(direction.x, 0, direction.y) * float(next.travel), maxf(global_position.y, desired_y))
		var before := global_position
		var surfaces := _jump_surfaces(before + horizontal, maxf(before.y, desired_y))
		var floor_y: float = surfaces.floor
		var ceiling_foot: float = float(surfaces.ceiling) - model_target_height - 0.04
		# Actual source resolveJumpSurface order: detect ceiling/edge, then
		# integrate its gravity18 fall in THIS substep, not one frame later.
		# Source's 2cm floor tolerance cannot complete cinematic recovery: on a
		# slightly lower floor it leaves the body hovering at the launch height.
		# After the arc, absent actual contact always continues swept gravity.
		var needs_floor_contact: bool = cinematic and not is_on_floor()
		if not bool(_jump.falling) and (desired_y > ceiling_foot or (float(next.elapsed) >= flight and (desired_y > floor_y + 0.02 or needs_floor_contact))):
			_jump.falling = true
			_jump.ceilingHit = desired_y > ceiling_foot
			_jump.fall_y = minf(before.y, minf(desired_y, ceiling_foot))
			_jump.fall_velocity = 0.0 if _jump.ceilingHit else minf(0.0, (desired_y - before.y) / maxf(0.001, dt))
		if bool(_jump.falling):
			_jump.fall_y += float(_jump.fall_velocity) * dt - 9.0 * dt * dt
			_jump.fall_velocity -= 18.0 * dt
			desired_y = _jump.fall_y
			if desired_y <= floor_y:
				_jump.falling = false
				_jump.base_y = floor_y
				if not cinematic:
					next.elapsed = maxf(float(next.elapsed), DivePose.FLIGHT)
					next.progress = float(next.elapsed) / (DivePose.FLIGHT + DivePose.RECOVERY)
				desired_y = floor_y
		desired_y = maxf(floor_y, minf(desired_y, maxf(floor_y, ceiling_foot)))
		if float(next.elapsed) >= flight and absf(desired_y - before.y) < 0.005 and is_on_floor():
			desired_y -= 0.005 # Real contact probe; collider, not a timer, holds feet.
		velocity = Vector3(horizontal.x, desired_y - before.y, horizontal.z) / engine_step
		move_and_slide() # Every physical displacement is swept, never teleported.
		var actual := (global_position - before) / dt
		_jump.elapsed = next.elapsed
		_jump.progress = next.progress
		_jump.diveBlend = next.diveBlend
		_jump.grounded = is_on_floor()
		if is_on_ceiling() and desired_y > before.y:
			_jump.ceilingHit = true
			_jump.falling = true
			_jump.fall_velocity = minf(0.0, actual.y)
			_jump.fall_y = global_position.y - 9.0 * dt * dt
			_jump.fall_velocity -= 18.0 * dt
			velocity = Vector3(0, float(_jump.fall_y) - global_position.y, 0) / engine_step
			move_and_slide() # Conservative shape-edge ceiling missed by centre ray.
		if is_on_floor() and bool(_jump.falling):
			_jump.falling = false
			if not cinematic:
				_jump.elapsed = maxf(float(_jump.elapsed), DivePose.FLIGHT)
				_jump.progress = float(_jump.elapsed) / (DivePose.FLIGHT + DivePose.RECOVERY)
			_jump.base_y = global_position.y
		if cinematic:
			# Recovery is armed by swept physical contact, never by flight time.
			if is_on_floor() and (float(next.elapsed) >= flight or bool(_jump.ceilingHit) or before.y > global_position.y + 0.00001):
				if float(_jump.contact_elapsed) < 0.0:
					_jump.contact_elapsed = _jump.elapsed
					_jump.base_y = global_position.y
				_jump.falling = false
			if float(_jump.contact_elapsed) >= 0.0:
				_jump.progress = lerpf(0.72, 1.0, clampf((float(_jump.elapsed) - float(_jump.contact_elapsed)) / DivePose.RECOVERY, 0.0, 1.0))
			_jump.done = float(_jump.contact_elapsed) >= 0.0 and float(_jump.elapsed) - float(_jump.contact_elapsed) >= DivePose.RECOVERY
		else:
			_jump.done = float(_jump.elapsed) >= DivePose.FLIGHT + DivePose.RECOVERY
		consumed += dt
		_jump_pose = _jump.duplicate()
		if _jump.done:
			_source_falling = bool(_jump.falling)
			velocity = Vector3(0.0, float(_jump.fall_velocity) if bool(_jump.falling) else 0.0, 0.0)
			_jump.clear()
			break
	floor_snap_length = old_snap
	if consumed > 0.0:
		_jump_actual_velocity = (global_position - frame_start) / consumed
	if not _jump.is_empty():
		velocity = _jump_actual_velocity
		if _jump_pose.is_empty():
			_jump_pose = _jump.duplicate()


func set_preview_pose_authority(owner: StringName, new_lifetime: bool = false) -> void:
	# Ownership handoff cancels source flight as well as its visual lifetime.
	# Explicit new lifetimes cover respawn/teleport even when owner is unchanged.
	if owner == _pose_authority and not new_lifetime:
		return
	_clear_affine_pose()
	if is_instance_valid(_melee_practice): _melee_practice.cancel("pose_authority")
	_invalidate_pose_receipt()
	_pose_authority = owner
	_pose_epoch += 1
	_jump.clear()
	_jump_pose.clear()
	_jump_event_consumed = false
	_source_falling = false
	velocity = Vector3.ZERO
	if _dive != null:
		_dive.reset()
	if is_instance_valid(_pose_motion):
		_pose_motion.quaternion = Quaternion.IDENTITY
	if _airborne != null:
		_airborne.reset()
	if _locomotion != null:
		_locomotion.reset_state()


func _update_owned_pose(delta: float) -> void:
	if _pose_authority != &"on_foot" or _locomotion == null or not is_instance_valid(_pose_skeleton):
		return
	var expected_epoch := _pose_epoch
	if not _jump_pose.is_empty() and _dive != null:
		var direction: Vector2 = _jump_pose.direction
		var aim_yaw := _camera_yaw + PI
		var travel_yaw := atan2(direction.x, direction.y) if not direction.is_zero_approx() else aim_yaw
		var source: Dictionary = _dive.sample(float(_jump_pose.progress), float(_jump_pose.diveBlend), _visual.global_rotation.y,
			aim_yaw, _camera_pitch, travel_yaw, _pose_authority, _pose_epoch)
		if bool(source.get("valid", false)) and bool(source.get("active", false)):
			_apply_selected_pose(_decorate_hit_pose(delta, source), expected_epoch)
			return
	var actual_velocity: Vector3 = get_real_velocity()
	var grounded: bool = is_on_floor()
	var selected: Dictionary = _locomotion.sample(delta, actual_velocity, grounded)
	if not bool(selected.get("valid", false)):
		return
	if _airborne != null:
		var air: Dictionary = _airborne.sample(delta, grounded, actual_velocity.y,
			selected["poses"], selected["visual_offset"], _pose_authority, _pose_epoch)
		if bool(air.get("valid", false)):
			selected = air
	if is_instance_valid(_melee_practice): selected = _melee_practice.decorate(selected,delta)
	_apply_selected_pose(_decorate_hit_pose(delta, selected), expected_epoch)


func set_hit_pose_decorator(decorator: Callable) -> bool:
	# One optional presentation consumer, before the existing sole bone writer.
	if decorator.is_valid() and _hit_pose_decorator.is_valid() and decorator != _hit_pose_decorator:
		return false
	_hit_pose_decorator = decorator
	return true


func _decorate_hit_pose(delta: float, selected: Dictionary) -> Dictionary:
	if not _hit_pose_decorator.is_valid(): return selected
	var decorated: Variant = _hit_pose_decorator.call(delta, selected)
	return decorated if decorated is Dictionary and decorated.get("valid", false) else selected


func _apply_selected_pose(selected: Dictionary, expected_epoch: int = -1) -> bool:
	# The sole runtime writer applies one selected pose after actual physics.
	if not Thread.is_main_thread(): return false
	if expected_epoch >= 0 and (expected_epoch != _pose_epoch or _pose_authority != &"on_foot"): return false
	_invalidate_pose_receipt()
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(_pose_skeleton) or not is_instance_valid(_pose_motion): return false
	var ancestor: Node = self
	while ancestor != null:
		if ancestor.is_queued_for_deletion(): return false
		ancestor = ancestor.get_parent()
	if not is_ancestor_of(_pose_motion) or not _pose_motion.is_ancestor_of(_pose_skeleton): return false
	if _pose_skeleton.is_queued_for_deletion() or _pose_motion.is_queued_for_deletion() or not selected.get("valid", false) or not selected.get("poses") is Array: return false
	if selected.poses.size() != _pose_skeleton.get_bone_count(): return false
	var offset: Variant = selected.get("visual_offset")
	var rotation: Variant = selected.get("visual_rotation", Quaternion.IDENTITY)
	if not offset is Vector3 or not offset.is_finite() or not rotation is Quaternion or not rotation.is_finite() or not rotation.is_normalized(): return false
	for frame: Variant in selected.poses:
		if not frame is Transform3D or not frame.is_finite(): return false
	var poses: Array[Transform3D] = []
	poses.assign(selected["poses"])
	var affine := selected.has("melee")
	if not affine: _clear_affine_pose()
	for bone: int in range(poses.size()):
		_pose_skeleton.set_bone_pose(bone, poses[bone])
	# Authored melee IK contains inverse-parent shear. Skeleton3D's local setter
	# decomposes that matrix into rotation/scale, moving a kick's skin by >5 cm.
	# Keep complete hierarchy products in the engine's final pose override.
	if affine:
		_pose_affine_globals.resize(poses.size())
		for bone: int in range(poses.size()):
			var parent := _pose_skeleton.get_bone_parent(bone)
			_pose_affine_globals[bone] = poses[bone] if parent < 0 else _pose_affine_globals[parent] * poses[bone]
			_pose_skeleton.set_bone_global_pose_override(bone, _pose_affine_globals[bone], 1.0, true)
		_pose_affine_active = true
	_pose_motion.position = selected["visual_offset"]
	_pose_motion.quaternion = selected.get("visual_rotation", Quaternion.IDENTITY)
	_pose_revision += 1
	# A receipt describes the completed displayed pose, never a proposed pose.
	# External vehicle/physical writers need their own publication integration.
	if _pose_authority == &"on_foot":
		var actor_id: Variant = get_meta("actor_id", "")
		var life: Variant = get_meta("life_generation", 0)
		if actor_id is String and not actor_id.is_empty() and life is int and life > 0:
			var receipt := {"actor_id":actor_id,"life_generation":life,"pose_epoch":_pose_epoch,"pose_revision":_pose_revision,"pose_owner":String(_pose_authority)}
			receipt.make_read_only()
			set_meta(MELEE_POSE_RECEIPT, receipt)
	return true


func _invalidate_pose_receipt() -> void:
	if has_meta(MELEE_POSE_RECEIPT): remove_meta(MELEE_POSE_RECEIPT)


func _clear_affine_pose() -> void:
	_invalidate_pose_receipt()
	if _pose_affine_active and is_instance_valid(_pose_skeleton):
		_pose_skeleton.clear_bones_global_pose_override()
	_pose_affine_active = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE):
			set_mouse_captured(false)
			get_viewport().set_input_as_handled()
			return
		if not _free_mouse_look: return
		if key.is_action_released(ACTION_JUMP):
			_jump_key_down = false
		if key.pressed and not key.echo:
			if not _text_control_focused() and key.is_action_pressed(ACTION_JUMP):
				if _jump_key_down:
					return
				_jump_key_down = true
				_jump_event_consumed = true
				_request_preview_jump(float(Time.get_ticks_msec()))
				get_viewport().set_input_as_handled()
				return
			if not _text_control_focused() and key.is_action_pressed(ACTION_CAPTURE):
				set_mouse_captured(not _free_mouse_look)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if _text_control_focused():
			return
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed and not _free_mouse_look:
			set_mouse_captured(true)
			get_viewport().set_input_as_handled()
			return
		if not _free_mouse_look: return
		if is_instance_valid(_melee_practice) and _melee_practice.input_event(event):
			get_viewport().set_input_as_handled()
			return
		if button.pressed and _free_mouse_look and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			# Walk uses exponential wheel zoom with on-foot limits 3..16 metres.
			var steps := button.factor if button.factor > 0.0 else 1.0
			var direction := -1.0 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			camera_distance = clampf(camera_distance * exp(direction * steps * 0.12), 3.0, 16.0)
			_spring_arm.spring_length = camera_distance
			get_viewport().set_input_as_handled()
			return
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_right_mouse_down = button.pressed
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if _free_mouse_look and not _text_control_focused():
			_camera_yaw -= motion.relative.x * mouse_sensitivity
			_camera_pitch = clampf(_camera_pitch - motion.relative.y * mouse_sensitivity, -1.05, 0.45)
			_update_camera_rotation()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_mouse_captured(false)
		_jump_key_down = false
		# Source blur releases controls; only hidden/minimized presentation freezes
		# its trajectory clock. An unfocused but visible window keeps simulating.
		for action: StringName in [ACTION_LEFT, ACTION_RIGHT, ACTION_FORWARD, ACTION_BACK, ACTION_RUN, ACTION_JUMP]:
			Input.action_release(action)
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_jump_physics_visible = true


func _exit_tree() -> void:
	_invalidate_pose_receipt()
	set_mouse_captured(false)


func _update_camera_rotation() -> void:
	if is_instance_valid(_yaw_pivot) and is_instance_valid(_spring_arm):
		# Camera horizon is independent of the vehicle's roll and pitch.
		_yaw_pivot.global_basis = Basis(Vector3.UP, _camera_yaw)
		_spring_arm.rotation.x = _camera_pitch


func _text_control_focused() -> bool:
	var focused: Control = get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit


func set_mouse_captured(captured: bool) -> void:
	if not captured and is_instance_valid(_melee_practice): _melee_practice.cancel("mouse_released")
	_right_mouse_down = false
	_free_mouse_look = captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	if not captured:
		_jump_key_down = false
		_jump_event_consumed = false
		for action: StringName in [ACTION_LEFT, ACTION_RIGHT, ACTION_FORWARD, ACTION_BACK, ACTION_RUN, ACTION_JUMP]:
			if InputMap.has_action(action): Input.action_release(action)


func get_preview_camera() -> Camera3D:
	return _camera


func get_preview_status() -> Dictionary:
	var locomotion_status: Dictionary = _locomotion.get_status() if _locomotion != null else {}
	return {
		"model_loaded": _model_loaded,
		"model_error": _model_error,
		"source_mesh_count": _mesh_count,
		"source_height_m": _source_height,
		"uniform_scale": _model_scale,
		"height_m": model_target_height,
		"animations_found": _animation_names.duplicate(),
		"animation_status": ("Canonical locomotion and ground melee practice; combat targets not connected" if is_instance_valid(_melee_practice) else ("Canonical idle/walk/run/jump/landing; combat animation not migrated" if _airborne != null and bool(_airborne.get_status().get("ready", false)) else "Canonical idle/walk/run; jump and combat animation not migrated")) if bool(locomotion_status.get("ready", false)) else "Static pose; locomotion binding failed",
		"locomotion": locomotion_status,
		"airborne": _airborne.get_status() if _airborne != null else {},
		"pose_authority": _pose_authority,
		"pose_epoch": _pose_epoch,
		"pose_revision": _pose_revision,
		"vertex_color_surfaces": _vertex_color_surfaces,
		"material_names": _material_names.duplicate(),
		"grounded": is_on_floor(),
		"speed_mps": Vector2(velocity.x, velocity.z).length(),
		"mouse_captured": Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"free_mouse_look": _free_mouse_look,
		"camera_distance_m": camera_distance,
		"source_jump": _jump.duplicate(),
		"source_jump_pose": _jump_pose.duplicate(),
		"source_dive_ready": _dive != null and bool(_dive.get_status().get("ready", false)),
		"source_falling": _source_falling,
		"jump_surface_guard_bound": _jump_surface_guard.is_valid(),
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
