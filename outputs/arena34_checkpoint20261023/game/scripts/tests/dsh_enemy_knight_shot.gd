extends SceneTree
## Renders the real castle enemy knight so the medium harness, city skin and walk
## pose can be judged instead of guessed at. Saves PNGs under the workspace.

var _scene: Node3D
var _host: Node
var _out := ""

func _initialize() -> void:
	_run.call_deferred()

func _settle(frames: int) -> void:
	for i: int in frames:
		await physics_frame

func _shot(name: String, camera: Camera3D) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null:
		print("ENEMY_SHOT_IMAGE_FAIL ", name); return
	var path := _out.path_join("enemy_knight_%s.png" % name)
	print("ENEMY_SHOT ", name, " err=", image.save_png(path), " path=", path)

func _run() -> void:
	_out = OS.get_environment("DSH_SHOT_DIR")
	if _out == "": _out = "C:/Users/Слава/Documents/deepseek-harness/default-workspace/_enemy_knight_shots"
	DirAccess.make_dir_recursive_absolute(_out)
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null: print("ENEMY_SHOT_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	root.size = Vector2i(1280, 720)
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and _scene.get("preview_ready") != true:
		await process_frame
	var player: CharacterBody3D = _scene.get("_player") as CharacterBody3D
	_host = _scene.get("preview_sword_prototype") as Node
	if not is_instance_valid(_host):
		var script: Script = load("res://scripts/weapons/sword_prototype.gd")
		_host = script.new()
		_host.name = "SwordPrototype"
		_scene.add_child(_host)
		print("ENEMY_SHOT_INSTALL ", JSON.stringify(_host.call("install", _scene, player)))
	else:
		print("ENEMY_SHOT_EXISTING_HOST status=", _scene.get("sword_prototype_status"))
	var bound := false
	for i: int in 480:
		await physics_frame
		if bool(_host.snapshot().get("npc_bound", false)):
			bound = true
			break
	if not bound:
		print("ENEMY_SHOT_FAIL npc"); quit(2); return
	var snap: Dictionary = _host.snapshot()
	if not bool(snap.get("npc_bound", false)):
		print("ENEMY_SHOT_FAIL npc"); quit(2); return
	var npc: Vector3 = snap.get("npc_position", Vector3.ZERO)
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.far = 400.0
	_scene.add_child(cam)
	cam.current = true
	var front := (player.global_position - npc)
	front.y = 0.0
	front = front.normalized() if front.length_squared() > 0.01 else Vector3.FORWARD
	var side := front.cross(Vector3.UP)
	# The actual opening view: the player ten metres from the knight at the gate.
	print("ENEMY_SHOT_GATE_DISTANCE ", player.global_position.distance_to(npc))
	cam.global_position = player.global_position + front * 5.2 + Vector3.UP * 2.4
	cam.look_at(npc + Vector3.UP * 1.15, Vector3.UP)
	await _settle(18)
	await _shot("gate", cam)
	# Front three-quarter, eye height, close enough for the mail and face to read.
	cam.global_position = npc + front * 3.0 + side * 1.5 + Vector3.UP * 1.65
	cam.look_at(npc + Vector3.UP * 1.05, Vector3.UP)
	await _settle(24)
	await _shot("front", cam)
	# Side view: the city skin and the medium plates on the same 28-bone resident.
	cam.global_position = npc + side * 3.2 + front * 0.6 + Vector3.UP * 1.55
	cam.look_at(npc + Vector3.UP * 1.02, Vector3.UP)
	await _settle(12)
	await _shot("side", cam)
	# A few seconds of fight: the same camera looks at the live exchange.
	await _settle(220)
	snap = _host.snapshot()
	cam.global_position = (snap.get("npc_position", npc) as Vector3) + front * 4.2 + side * 2.0 + Vector3.UP * 1.8
	cam.look_at((snap.get("npc_position", npc) as Vector3) + Vector3.UP * 1.0, Vector3.UP)
	await _settle(12)
	await _shot("fight", cam)
	print("ENEMY_SHOT_SNAP ", JSON.stringify({"state": snap.get("npc_state"), "hp": snap.get("npc_hp"),
		"swings": snap.get("npc_swings"), "hits": snap.get("npc_hits"),
		"clashes": snap.get("enemy_clashes"), "evades": snap.get("enemy_evades"),
		"armor": snap.get("npc_armor"), "gait": snap.get("npc_walk_gait")}))
	print("ENEMY_SHOT_DONE")
	quit(0)
