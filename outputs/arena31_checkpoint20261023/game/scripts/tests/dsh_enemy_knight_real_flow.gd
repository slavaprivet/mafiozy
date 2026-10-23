extends SceneTree
## Exercises the REAL castle player flow: the arsenal equips a sword, installs the
## prototype host on demand and the enemy knight appears without a test shortcut.

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
	print("REAL_FLOW_READY ", _scene.get("preview_ready"))
	var weapons: Node = _scene.get("preview_weapons")
	print("REAL_FLOW_ARSENAL ", is_instance_valid(weapons))
	if is_instance_valid(weapons):
		var equipped: Dictionary = weapons.call("equip", "sword")
		print("REAL_FLOW_EQUIP ", JSON.stringify(equipped))
	await _settle(30)
	var host: Node = _scene.get("preview_sword_prototype")
	print("REAL_FLOW_HOST ", is_instance_valid(host), " status=", _scene.get("sword_prototype_status"))
	if not is_instance_valid(host):
		quit(2); return
	var bound := false
	for i: int in 420:
		await physics_frame
		if bool(host.snapshot().get("npc_bound", false)): bound = true; break
	print("REAL_FLOW_NPC ", bound)
	var s: Dictionary = host.snapshot()
	print("REAL_FLOW_SNAP ", JSON.stringify({"weapon": s.get("weapon"), "selected": s.get("selected"),
		"npc": s.get("npc_bound"), "state": s.get("npc_state"), "hp": s.get("npc_hp"),
		"armor": s.get("npc_armor"), "gait": s.get("npc_walk_gait"),
		"player_pos": s.get("player_position"), "npc_pos": s.get("npc_position")}))
	await _settle(360)
	var t: Dictionary = host.snapshot()
	print("REAL_FLOW_FIGHT ", JSON.stringify({"state": t.get("npc_state"), "engaged": t.get("npc_engaged"),
		"swings": t.get("npc_swings"), "hits": t.get("npc_hits"), "clashes": t.get("enemy_clashes"),
		"evades": t.get("enemy_evades"), "npc_hp": t.get("npc_hp"), "player_hp": t.get("sparring_hp")}))
	print("REAL_FLOW_DONE")
	quit(0)
