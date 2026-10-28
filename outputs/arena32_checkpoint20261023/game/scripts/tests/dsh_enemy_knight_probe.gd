extends SceneTree
## Read-only probe for the castle enemy knight. Loads the real castle scene and
## reports the opponent's model, armour, position and first combat beats.

var _scene: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _settle(frames: int) -> void:
	for i: int in frames:
		await physics_frame

func _pick(snap: Dictionary) -> Dictionary:
	var keys := ["npc_bound", "npc_state", "npc_engaged", "npc_hp", "npc_swings",
		"npc_hits", "npc_blocked", "npc_position", "player_position", "player_blocks",
		"npc_speed_scale", "armour_plates", "npc_severed", "npc_disarmed", "npc_dead"]
	var out := {}
	for key: String in keys:
		if snap.has(key): out[key] = snap[key]
	return out

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("ENEMY_PROBE_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and _scene.get("preview_ready") != true:
		await process_frame
	print("ENEMY_PROBE_READY ", _scene.get("preview_ready"))
	await _settle(300)
	var host: Node = _scene.find_child("SwordPrototype", true, false)
	if not is_instance_valid(host):
		var player: CharacterBody3D = _scene.get("_player") as CharacterBody3D
		if not is_instance_valid(player):
			print("ENEMY_PROBE_FAIL player"); quit(2); return
		var script: Script = load("res://scripts/weapons/sword_prototype.gd")
		host = script.new()
		host.name = "SwordPrototype"
		_scene.add_child(host)
		var installed: Dictionary = host.call("install", _scene, player)
		print("ENEMY_PROBE_INSTALL ", JSON.stringify(installed))
	print("ENEMY_PROBE_HOST ", is_instance_valid(host))
	if not is_instance_valid(host):
		quit(2); return
	var first: Dictionary = host.snapshot()
	print("ENEMY_PROBE_FIRST ", JSON.stringify(_pick(first)))
	await _settle(240)
	var second: Dictionary = host.snapshot()
	print("ENEMY_PROBE_SECOND ", JSON.stringify(_pick(second)))
	var a: Vector3 = first.get("npc_position", Vector3.ZERO)
	var b: Vector3 = second.get("npc_position", Vector3.ZERO)
	print("ENEMY_PROBE_MOVED ", a.distance_to(b))
	print("ENEMY_PROBE_ARMOR ", JSON.stringify(host.call("npc_armor_snapshot31")))
	print("ENEMY_PROBE_VISUAL ", JSON.stringify(host.call("npc_armor_visual_snapshot31")) if host.has_method("npc_armor_visual_snapshot31") else "{}")
	quit(0)
