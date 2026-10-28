extends SceneTree
## Loads the ordinary castle game with no test shortcut, no manual install and no
## weapon equip: the enemy knight must already exist and come at the player.

var _scene: Node3D

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
	print("AUTO_READY ", _scene.get("preview_ready"))
	var host: Node = _scene.get("preview_sword_prototype")
	print("AUTO_HOST ", is_instance_valid(host), " status=", _scene.get("sword_prototype_status"))
	if not is_instance_valid(host):
		quit(2); return
	var bound := false
	for i: int in 600:
		await physics_frame
		if bool(host.snapshot().get("npc_bound", false)): bound = true; break
	print("AUTO_NPC ", bound)
	var s: Dictionary = host.snapshot()
	print("AUTO_SNAP ", JSON.stringify({"npc": s.get("npc_bound"), "state": s.get("npc_state"),
		"engaged": s.get("npc_engaged"), "selected": s.get("selected"), "weapon": s.get("weapon"),
		"armor": s.get("npc_armor"), "gait": s.get("npc_walk_gait"),
		"player": s.get("player_position"), "npc_pos": s.get("npc_position")}))
	await _settle(360)
	var t: Dictionary = host.snapshot()
	print("AUTO_FIGHT ", JSON.stringify({"state": t.get("npc_state"), "engaged": t.get("npc_engaged"),
		"swings": t.get("npc_swings"), "hits": t.get("npc_hits"), "clashes": t.get("enemy_clashes"),
		"npc_hp": t.get("npc_hp"), "player_hp": t.get("sparring_hp"), "distance":
		(t.get("npc_position", Vector3.ZERO) as Vector3).distance_to(t.get("player_position", Vector3.ZERO))}))
	print("AUTO_DONE")
	quit(0)
