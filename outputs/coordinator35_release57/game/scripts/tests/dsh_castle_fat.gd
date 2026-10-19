extends SceneTree
## DSH_CASTLE: how thick is the wall's collision compared with the wall?
## Rays are fired straight at the south wall from outside; the hit distance is compared with
## the wall face at half.

var _scene: Node
var _castle: Node3D

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null: print("FAT_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	_castle = _scene.get("preview_castle")
	if _castle == null: print("FAT_FAIL castle"); quit(1); return
	await _settle(30)
	var half: float = float(_castle.call("wall_half"))
	var base: Vector3 = _castle.global_position
	var space: PhysicsDirectSpaceState3D = _castle.get_world_3d().direct_space_state
	for x: float in [20.0, 40.0, -30.0]:
		var from: Vector3 = base + Vector3(x, 1.4, half + 8.0)
		var to: Vector3 = base + Vector3(x, 1.4, half - 6.0)
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = 1
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			print("FAT x=", x, " NO HIT")
		else:
			var zh: float = (hit.position as Vector3).z - base.z
			print("FAT x=", x, " hit_z=", zh, " wall_face=", half, " extra=", zh - half,
				" collider=", (hit.collider as Node).name)
	print("FAT_DONE")
	quit(0)