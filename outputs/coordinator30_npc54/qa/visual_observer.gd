extends Node
## Optional QA only. Attach under the running scene and set output_path if needed.
## Read the actual existing bones and visual transform AFTER the scene's physics
## callback; never move the actor, set a pose, or issue a walk request.
var resident_id := "resident_1"
var output_path := ""
var _previous: Dictionary = {}
var _samples: Array[Dictionary] = []
var _walk_samples := 0
var _moving_bone_samples := 0
var _distance := 0.0
var _max_yaw_error := 0.0


func _ready() -> void:
	process_physics_priority = 1000


func _physics_process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if not is_instance_valid(scene): return
	var population: Variant = scene.get("preview_population")
	if population == null: return
	var host: Variant = population.get("residents")
	if host == null: return
	var records: Variant = host.get("_records")
	if not records is Dictionary: return
	var record: Dictionary = records.get(resident_id, {})
	if record.is_empty(): return
	var body: CharacterBody3D = record.get("body")
	var motion: Node3D = record.get("motion")
	var gait: Variant = record.get("gait")
	if not is_instance_valid(body) or not is_instance_valid(motion) or gait == null: return
	var rig: Skeleton3D = gait.get("_skeleton")
	if not is_instance_valid(rig): return
	var left: int = rig.find_bone("thigh_l")
	var right: int = rig.find_bone("thigh_r")
	if left < 0 or right < 0: return
	var current := {"frame": Engine.get_physics_frames(), "body_id": body.get_instance_id(),
		"position": body.global_position, "left": rig.get_bone_pose_rotation(left),
		"right": rig.get_bone_pose_rotation(right), "yaw": motion.global_rotation.y,
		"status": str(record.get("status", "")), "dead": bool(record.owner.dead)}
	if not _previous.is_empty() and current.body_id == _previous.body_id:
		var movement: Vector3 = current.position - _previous.position
		movement.y = 0.0
		var distance: float = movement.length()
		var bone_delta: float = maxf((current.left as Quaternion).angle_to(_previous.left), (current.right as Quaternion).angle_to(_previous.right))
		if distance > .001:
			_walk_samples += 1
			_distance += distance
			if bone_delta > .0001: _moving_bone_samples += 1
			# Rig forward is +Z; body heading is -Z, bridged by motion's PI.
			var expected: float = atan2(movement.x, movement.z)
			var error: float = absf(wrapf(float(current.yaw) - expected, -PI, PI))
			_max_yaw_error = maxf(_max_yaw_error, error)
		if Engine.get_physics_frames() % 6 == 0:
			var capsule: Dictionary = {}
			for child: Node in body.get_children():
				if child is CollisionShape3D and child.shape is CapsuleShape3D:
					capsule = {"radius": child.shape.radius, "height": child.shape.height, "disabled": child.disabled, "shape_id": child.shape.get_instance_id()}
			_samples.append({"frame": current.frame, "body_id": current.body_id, "position": [current.position.x, current.position.y, current.position.z], "travel_m": distance, "thigh_delta_rad": bone_delta, "visual_yaw": current.yaw, "dead": current.dead, "status": current.status, "capsule": capsule, "collision_layer": body.collision_layer, "collision_mask": body.collision_mask})
	_previous = current
	if Engine.get_physics_frames() % 60 == 0:
		print("VISUAL51 ", JSON.stringify(summary()))


func summary() -> Dictionary:
	return {"resident": resident_id, "moving_frames": _walk_samples,
		"moving_frames_with_bone_change": _moving_bone_samples, "distance_m": _distance,
		"max_transient_yaw_error_rad": _max_yaw_error, "samples": _samples.size()}


func save() -> void:
	if output_path.is_empty(): return
	var handle := FileAccess.open(output_path, FileAccess.WRITE)
	if handle != null:
		handle.store_string(JSON.stringify({"summary": summary(), "samples": _samples}, "\t"))
		handle.close()


func capture_png(path: String) -> int:
	# Caller invokes only in a graphical run. Capture is read-only and asynchronous.
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	if frame == null or frame.is_empty(): return ERR_UNAVAILABLE
	return frame.save_png(path)
