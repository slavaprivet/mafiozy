extends SceneTree
## Headless integration test. It does not claim visual/FPS acceptance.

const PlayerController = preload("res://scripts/preview_player.gd")
var _failures: Array[String] = []
var _world: Node3D
var _player: PlayerController


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_add_box(Vector3(0.0, -0.5, 0.0), Vector3(40.0, 1.0, 40.0))
	_player = PlayerController.new()
	_player.position = Vector3(0.0, 0.1, 2.0)
	_world.add_child(_player)
	await _frames(45)
	var status: Dictionary = _player.get_preview_status()
	_check(bool(status.get("model_loaded", false)), "actual hero imports as PackedScene")
	_check(int(status.get("source_mesh_count", 0)) == 7, "all seven source hero meshes load")
	_check(float(status.get("source_height_m", 0.0)) > 0.1, "actual source bounds exist")
	_check(absf(float(status.get("source_height_m", 0.0)) * float(status.get("uniform_scale", 0.0)) - 1.9) < 0.0001, "uniform imported height is 1.9 metres")
	_check(_player.is_on_floor(), "gravity settles player on physical floor")
	_check(absf(_player.position.y) < 0.015, "capsule feet rest at floor height")
	_check(_player.get_preview_camera().current, "player camera becomes current")
	_check(str(status.get("animation_status", "")).contains("not migrated"), "unfinished animation is reported")
	Input.action_press(&"preview_move_forward")
	await _frames(60)
	var walking_speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	_check(walking_speed > 3.1 and walking_speed < 3.3, "walking reaches configured speed")
	Input.action_press(&"preview_move_right")
	await _frames(30)
	var diagonal_speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	_check(absf(diagonal_speed - walking_speed) < 0.02, "diagonal input does not exceed walk speed")
	Input.action_press(&"preview_run")
	await _frames(30)
	_check(Vector2(_player.velocity.x, _player.velocity.z).length() > 5.7, "Shift reaches run speed")
	_release_movement()
	await _frames(30)
	_check(Vector2(_player.velocity.x, _player.velocity.z).length() < 0.001, "release stops horizontal movement")
	Input.action_press(&"preview_jump")
	await _frames(1)
	Input.action_release(&"preview_jump")
	var peak_y: float = _player.position.y
	var airborne: bool = false
	for frame: int in range(90):
		if frame == 18:
			Input.action_press(&"preview_jump")
		elif frame == 20:
			Input.action_release(&"preview_jump")
		await _frames(1)
		peak_y = maxf(peak_y, _player.position.y)
		airborne = airborne or not _player.is_on_floor()
	_check(airborne and peak_y > 1.1 and peak_y < 1.5, "grounded jump follows bounded arc; second press cannot double-jump")
	_check(_player.is_on_floor(), "jump lands on physical floor")
	_add_box(Vector3(0.0, 2.0, -2.0), Vector3(6.0, 4.0, 0.3))
	_player.position = Vector3(0.0, 0.05, 2.0)
	_player.velocity = Vector3.ZERO
	await _frames(15)
	Input.action_press(&"preview_move_forward")
	await _frames(150)
	Input.action_release(&"preview_move_forward")
	_check(_player.position.z > -1.57 and _player.position.z < -1.45, "wall blocks movement at capsule surface")
	var locomotion_status: Dictionary = _player.get_preview_status().get("locomotion", {}) as Dictionary
	_check(float(locomotion_status.get("gait", 1.0)) < 0.001, "held movement against wall stops actual walking pose")
	_player.position = Vector3(0.0, 0.05, 2.0)
	_player.velocity = Vector3.ZERO
	_add_box(Vector3(0.0, 2.0, 4.4), Vector3(3.0, 4.0, 0.3))
	await _frames(30)
	var arm: SpringArm3D = _player.get_node("CameraYaw/CameraSpringArm") as SpringArm3D
	_check(arm.get_hit_length() > 0.1 and arm.get_hit_length() < 3.0, "camera arm retracts at real wall")
	_release_movement()
	if _failures.is_empty():
		print("PASS preview_player: real model, uniform scale, floor, walk/run/diagonal, jump, wall, camera obstruction; no LIVE/FPS claim")
	else:
		for failure: String in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await physics_frame
		await process_frame


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_failures.append(label)


func _add_box(at: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	_world.add_child(body)


func _release_movement() -> void:
	for action: StringName in [&"preview_move_forward", &"preview_move_back", &"preview_move_left", &"preview_move_right", &"preview_run", &"preview_jump"]:
		Input.action_release(action)
