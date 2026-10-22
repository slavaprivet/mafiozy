extends SceneTree
## Actual controller + physics + imported skin; no rendered LIVE/FPS claim.
const PlayerController = preload("res://scripts/preview_player.gd")

class MeasuredPlayer extends PlayerController:
	var costs: Array[int] = []
	func _update_owned_pose(delta: float) -> void:
		var started: int = Time.get_ticks_usec()
		super._update_owned_pose(delta)
		costs.append(Time.get_ticks_usec() - started)

var _player: MeasuredPlayer
var _skeleton: Skeleton3D
var _rest: Array[Transform3D] = []
var _boots: Array[Dictionary] = []
var _failures: Array[String] = []
var _checks: int = 0
var _floor_min: float = INF
var _floor_max: float = -INF
var _skin_samples: int = 0
var _max_skin_step: float = 0.0
var _last_skin: PackedVector3Array = PackedVector3Array()
var _last_phase: String = ""
var _max_skin_transition: String = ""
var _max_continuous_skin_step: float = 0.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(300.0, 1.0, 300.0)
	collider.shape = shape
	floor_body.add_child(collider)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	_player = MeasuredPlayer.new()
	root.add_child(_player)
	_skeleton = _player.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_rest = _capture()
	_collect_full_boot_geometry()
	await _frames(90)
	_check(_player.is_on_floor(), "physical initial settle")
	_check(bool(_player.get_preview_status()["airborne"]["ready"]), "runtime airborne bound")
	for cycle: int in range(4):
		Input.action_press(&"preview_move_forward")
		if cycle % 2 == 1:
			Input.action_press(&"preview_run")
		await _frames(35)
		var speed: float = _player.get_real_velocity().length()
		_check(speed > (5.7 if cycle % 2 == 1 else 3.1), "cycle %d actual walk/run" % cycle)
		Input.action_press(&"preview_jump")
		await _frames(1)
		Input.action_release(&"preview_jump")
		var phases: Dictionary = {}
		var peak: float = 0.0
		var landed: bool = false
		for frame: int in range(120):
			var was_floor: bool = _player.is_on_floor()
			await _frames(1)
			var phase: String = _phase()
			phases[phase] = true
			peak = maxf(peak, _player.position.y)
			if not was_floor and _player.is_on_floor():
				landed = true
				_check(phase == "landing", "contact starts landing immediately")
			if not _player.is_on_floor():
				# Source recovery is clock-based; Godot's exact floor flag can lag
				# the source .8s endpoint by one contact-margin step on a flat floor.
				_check(phase != "idle" and (phase != "landing" or absf(_player.position.y) < 0.015), "source recovery reaches actual support height")
		_check(landed and absf(peak - 1.05) < 0.015, "cycle %d source normal 1.05m physical arc" % cycle)
		_check(phases.has("ascent") and phases.has("fall") and phases.has("landing") and phases.has("idle"), "cycle %d full flight and recovery" % cycle)
		Input.action_release(&"preview_move_forward")
		Input.action_release(&"preview_run")
		await _frames(100)
		_check(_same(_rest, _capture()), "cycle %d exact idle restoration" % cycle)
		_check(_player.get_node("VisualHeading/LocomotionOffset").position.length() < 0.00001, "idle offset restores")
	# Interrupt both flight and landing, then return under a fresh owner lifetime.
	for interrupt_phase: String in ["ascent", "landing"]:
		Input.action_press(&"preview_jump")
		await _frames(1)
		Input.action_release(&"preview_jump")
		for frame: int in range(90):
			if _phase() == interrupt_phase:
				break
			await _frames(1)
		_check(_phase() == interrupt_phase, "interruption phase reached")
		_player.set_preview_pose_authority(&"external_test")
		var held: Array[Transform3D] = _capture()
		var held_offset: Vector3 = _player.get_node("VisualHeading/LocomotionOffset").position
		await _frames(95)
		_check(_same(held, _capture()), "external owner has no runtime bone writes")
		_check(_player.get_node("VisualHeading/LocomotionOffset").position == held_offset, "external owner has no visual offset writes")
		_check(str(_player.get_preview_status()["airborne"]["phase"]) == "idle", "interruption clears pending recovery")
		_check(_player.get_preview_status()["source_jump"].is_empty(), "authority change cancels source trajectory")
		_player.set_preview_pose_authority(&"on_foot")
		_last_skin.clear()
		await _frames(120) # A midair handoff resumes physical fall before idle.
		_check(_player.is_on_floor(), "returned authority physically lands")
		_check(_same(_rest, _capture()), "fresh grounded authority returns to canonical rest")
		_last_skin.clear() # Owner handoffs may deliberately select another pose.
	var epoch: int = int(_player.get_preview_status()["pose_epoch"])
	_player.set_preview_pose_authority(&"on_foot", true)
	_check(int(_player.get_preview_status()["pose_epoch"]) == epoch + 1, "same-owner respawn lifetime advances epoch")
	# A poisoned live pose must not contaminate the pure fresh-base sampler.
	_player.set_physics_process(false)
	var held: Array[Transform3D] = _capture()
	var thigh: int = _skeleton.find_bone("thigh_l")
	_skeleton.set_bone_pose_rotation(thigh, Quaternion(Vector3.RIGHT, 1.0))
	var poisoned: Array[Transform3D] = _capture()
	var locomotion: RefCounted = _player.get("_locomotion")
	var base: Dictionary = locomotion.call("sample", 1.0 / 60.0, Vector3.ZERO, true)
	_check(_same(poisoned, _capture()), "locomotion sample is read-only")
	_check(_same(held, base["poses"]), "fresh base ignores live pose feedback")
	_player.call("_update_owned_pose", 1.0 / 60.0)
	_check(_same(_rest, _capture()), "single owner applies canonical selected pose")
	_check(_floor_min > -0.001 and _floor_max < 0.001, "actual boot skin stays on body foot plane across ordinary cycle")
	# Source hero.jumpPose resets from the locomotion pose on entry, without a
	# crossfade. Preserve that source boundary, report it separately, and retain
	# the old continuity bound within each phase rather than inventing a blend.
	_check(_max_continuous_skin_step < 0.13, "actual boot motion continuous within source phases at 60Hz")
	_player.costs.sort()
	print(JSON.stringify({"passed": _failures.is_empty(), "checks": _checks, "cycles": 4,
		"boot_vertices": _boots.size(), "skin_samples": _skin_samples,
		"minimum_sole_m": _floor_min, "maximum_sole_m": _floor_max, "max_skin_step_m": _max_skin_step,
		"max_skin_transition": _max_skin_transition, "max_continuous_skin_step_m": _max_continuous_skin_step,
		"owned_pose_cpu_p50_us": _player.costs[_player.costs.size()/2],
		"owned_pose_cpu_p95_us": _player.costs[int(_player.costs.size()*0.95)],
		"scope": "actual headless controller physics/boot skin; no LIVE or loaded scene FPS"}))
	for failure: String in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)

func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame
		if str(_player.get_preview_status()["pose_authority"]) == "on_foot":
			var phase := _phase()
			var skin: PackedVector3Array = _skin_all_boot_vertices()
			var lowest: float = INF
			for vertex: int in range(skin.size()):
				lowest = minf(lowest, skin[vertex].y)
				if _last_skin.size() == skin.size():
					var distance := skin[vertex].distance_to(_last_skin[vertex])
					if distance > _max_skin_step:
						_max_skin_step = distance
						_max_skin_transition = _last_phase + " -> " + phase
					if phase == _last_phase:
						_max_continuous_skin_step = maxf(_max_continuous_skin_step, distance)
			_floor_min = minf(_floor_min, lowest)
			_floor_max = maxf(_floor_max, lowest)
			_last_skin = skin
			_last_phase = phase
			_skin_samples += 1
		else:
			_last_skin.clear()

func _phase() -> String:
	var status: Dictionary = _player.get_preview_status()
	var jump: Dictionary = status.get("source_jump_pose", {})
	if not jump.is_empty():
		if float(jump.elapsed) < 0.4:
			return "ascent"
		if float(jump.elapsed) < 0.8:
			return "fall"
		return "landing"
	return str(status["airborne"]["phase"])

func _capture() -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	for bone: int in range(_skeleton.get_bone_count()):
		poses.append(_skeleton.get_bone_pose(bone))
	return poses

func _same(a: Array[Transform3D], b: Array[Transform3D]) -> bool:
	if a.size() != b.size():
		return false
	for bone: int in range(a.size()):
		if not a[bone].is_equal_approx(b[bone]):
			return false
	return true

func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)

func _collect_full_boot_geometry() -> void:
	for node: Node in _player.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.skin == null:
			continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var count: int = joints.size() / positions.size()
			for vertex: int in range(positions.size()):
				for influence: int in range(count):
					var at: int = vertex * count + influence
					if weights[at] < 0.9999:
						continue
					var bind_index: int = joints[at]
					var bone: int = _skeleton.find_bone(str(mesh.skin.get_bind_name(bind_index)))
					if _skeleton.get_bone_name(bone) not in ["foot_l", "foot_r"]:
						continue
					_boots.append({"bone": bone, "bind_pose": mesh.skin.get_bind_pose(bind_index), "point": positions[vertex]})


func _skin_all_boot_vertices() -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	var skeleton_to_body: Transform3D = _player.global_transform.affine_inverse() * _skeleton.global_transform
	for row: Dictionary in _boots:
		var transform: Transform3D = skeleton_to_body * _skeleton.get_bone_global_pose(int(row["bone"])) * (row["bind_pose"] as Transform3D)
		result.append(transform * (row["point"] as Vector3))
	return result


