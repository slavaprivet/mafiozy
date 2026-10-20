extends SceneTree
## Drives the real player guard against the real enemy knight and reports the
## natural blade-on-blade beats: parries, both bodies pushed, evades and counters.

var _scene: Node3D
var _host: Node
var _player: CharacterBody3D

func _initialize() -> void:
	_run.call_deferred()

func _settle(frames: int) -> void:
	for i: int in frames:
		await physics_frame

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and _scene.get("preview_ready") != true:
		await process_frame
	_player = _scene.get("_player") as CharacterBody3D
	_host = _scene.get("preview_sword_prototype") as Node
	if not is_instance_valid(_host):
		var script: Script = load("res://scripts/weapons/sword_prototype.gd")
		_host = script.new()
		_host.name = "SwordPrototypeClash"
		_scene.add_child(_host)
		print("ENEMY_CLASH_INSTALL ", JSON.stringify(_host.call("install", _scene, _player)))
	else:
		print("ENEMY_CLASH_EXISTING_HOST status=", _scene.get("sword_prototype_status"))
	_host.call("set_selected", true)
	await _settle(30)
	print("ENEMY_CLASH_ARMED ", JSON.stringify({"weapon": _host.snapshot().get("weapon"),
		"selected": _host.snapshot().get("selected"), "has_sword": _host.snapshot().get("has_sword")}))
	var bound := false
	for i: int in 420:
		await physics_frame
		if bool(_host.snapshot().get("npc_bound", false)): bound = true; break
	if not bound:
		print("ENEMY_CLASH_FAIL npc"); quit(1); return
	var start: Dictionary = _host.snapshot()
	var blocks_start := int(start.get("player_blocks", 0))
	var clashes_start := int(start.get("npc_blocked", 0))
	var p_start: Vector3 = start.get("player_position", Vector3.ZERO)
	var n_start: Vector3 = start.get("npc_position", Vector3.ZERO)
	# Keep the player's steel on the line between the two men: a real guard.
	for i: int in 720:
		var snap: Dictionary = _host.snapshot()
		var npc: Vector3 = snap.get("npc_position", Vector3.ZERO)
		var me: Vector3 = _player.global_position
		var to_npc := npc - me
		to_npc.y = 0.0
		if to_npc.length_squared() > 0.01 and not bool(snap.get("sword_grounded", true)):
			_host.set("_dir", (to_npc.normalized() * 0.7 + Vector3.UP * 0.5).normalized())
		if i % 120 == 0:
			print("ENEMY_CLASH_TICK ", i, " ", JSON.stringify({"blocks": snap.get("player_blocks"),
				"npc_blocked": snap.get("npc_blocked"), "clashes": snap.get("enemy_clashes"),
				"evades": snap.get("enemy_evades"), "swings": snap.get("npc_swings"),
				"hits": snap.get("npc_hits"), "state": snap.get("npc_state")}))
		await physics_frame
	var end: Dictionary = _host.snapshot()
	print("ENEMY_CLASH_RESULT ", JSON.stringify({
		"player_blocks": int(end.get("player_blocks", 0)) - blocks_start,
		"npc_blocked": int(end.get("npc_blocked", 0)) - clashes_start,
		"clashes": end.get("enemy_clashes"), "evades": end.get("enemy_evades"),
		"swings": end.get("npc_swings"), "hits": end.get("npc_hits"),
		"npc_hp": end.get("npc_hp"), "npc_state": end.get("npc_state"),
		"player_moved": (end.get("player_position", Vector3.ZERO) as Vector3).distance_to(p_start),
		"npc_moved": (end.get("npc_position", Vector3.ZERO) as Vector3).distance_to(n_start),
		"npc_push": (end.get("enemy_last_clash_push", 0.0))}))
	print("ENEMY_CLASH_DONE")
	quit(0)
