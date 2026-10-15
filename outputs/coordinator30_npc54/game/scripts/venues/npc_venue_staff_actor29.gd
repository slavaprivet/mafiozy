extends CharacterBody3D
## One stationary physical staff body; never a ResidentHost or resident pose writer.
var role29 := "cashier"
var serving29 := false
var pose_updates29 := 0
var _site: WeakRef
var _counter29: WeakRef
var _registry: RefCounted
var _venue := ""
var _anchor := Vector3.ZERO
var _motion: Node3D
var _skeleton: Skeleton3D
var _poses: Array[Transform3D] = []
var _bones: Dictionary = {}
var _clock := 0.0
var _next_pose := 0.0
var _next_status := 0.0
var _ready29 := false
var _disabled29 := false

func configure29(site: Node3D, registry: RefCounted, venue: String, point: Vector3, inward: Vector3, appearance: Dictionary, kind: String) -> bool:
	if _ready29 or not appearance.get("ok", false): return false
	_site = weakref(site); _registry = registry; _venue = venue; _anchor = point
	role29 = "medic" if kind == "hospital" else "cashier"
	name = "Medic29" if role29 == "medic" else "Cashier29"
	collision_layer = 1; collision_mask = 1; floor_snap_length = .25
	var capsule := CapsuleShape3D.new(); capsule.radius = .36; capsule.height = 1.9
	var shape := CollisionShape3D.new(); shape.shape = capsule; shape.position.y = .95; add_child(shape)
	_motion = Node3D.new(); _motion.name = "StaffVisual29"; add_child(_motion)
	_motion.add_child(appearance.visual); _motion.rotation.y = PI
	_skeleton = appearance.skeleton
	if _skeleton.get_bone_count() != 28: return false
	for bone: int in range(_skeleton.get_bone_count()):
		_poses.append(_skeleton.get_bone_pose(bone)); _bones[str(_skeleton.get_bone_name(bone))] = bone
	global_position = point
	# Native forward -Z points toward the customer, opposite the doorway inward.
	rotation.y = atan2(inward.x, inward.z)
	_ready29 = true
	set_meta("npc_staff29", true); set_meta("staff_role29", role29)
	return true

func available29() -> bool:
	var site: Variant = _site.get_ref() if _site != null else null
	var counter: Variant = _counter29.get_ref() if _counter29 != null else null
	return _ready29 and not _disabled29 and is_instance_valid(site) and not site.is_queued_for_deletion() and not bool(site.get_meta("venue_closed29", false)) and is_instance_valid(counter) and not counter.is_queued_for_deletion() and counter.freeze and is_on_floor() and global_position.distance_to(_anchor) < .12

func disable29() -> void:
	_disabled29 = true; serving29 = false

func _physics_process(delta: float) -> void:
	if not _ready29: return
	_clock += delta
	velocity.x = 0; velocity.z = 0; velocity.y -= 9.8 * delta
	move_and_slide()
	if _clock >= _next_status:
		_next_status = _clock + .1
		serving29 = available29() and _registry.service_customer29(_venue) != null
	var camera: Camera3D = get_viewport().get_camera_3d()
	var distance: float = global_position.distance_to(camera.global_position) if is_instance_valid(camera) else 0.0
	_motion.visible = distance < 65.0
	if _clock < _next_pose: return
	_next_pose = _clock + (.05 if serving29 or distance < 25.0 else .5)
	var poses: Array[Transform3D] = _poses.duplicate()
	_turn29(poses, "chest", Vector3.RIGHT, sin(_clock * 1.8) * .012)
	_turn29(poses, "head", Vector3.UP, sin(_clock * .6) * .035)
	if serving29:
		var pulse: float = sin(_clock * 8.0)
		_turn29(poses, "upperarm_r", Vector3.RIGHT, -.32 + pulse * .045)
		_turn29(poses, "forearm_r", Vector3.RIGHT, -.48 + pulse * .11)
		if role29 == "medic":
			_turn29(poses, "upperarm_l", Vector3.RIGHT, -.30)
			_turn29(poses, "forearm_l", Vector3.RIGHT, -.40 - pulse * .055)
	for bone: int in range(poses.size()): _skeleton.set_bone_pose(bone, poses[bone])
	pose_updates29 += 1

func _turn29(poses: Array[Transform3D], label: String, axis: Vector3, angle: float) -> void:
	var bone: int = int(_bones[label])
	poses[bone].basis = poses[bone].basis * Basis(axis, angle)

func snapshot29() -> Dictionary:
	return {"role":role29,"serving":serving29,"available":available29(),"bones":_poses.size(),"pose_updates":pose_updates29,"position":global_position,"resident_host":false}
