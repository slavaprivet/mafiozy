extends SceneTree

var out := ""
var errors: Array[String] = []
var rows := []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): out = arg.trim_prefix("--qa-out=")
	call_deferred("run")

func ticks(n: int) -> void:
	for i: int in n: await physics_frame

func scenario(part: String, first: float, second: float) -> void:
	var game: Node3D = load("res://scenes/castle.tscn").instantiate()
	root.add_child(game)
	var deadline := Time.get_ticks_msec() + 45000
	while game.get("preview_ready") != true and Time.get_ticks_msec() < deadline: await process_frame
	if game.get("preview_ready") != true: errors.append(part+"_scene_not_ready"); game.queue_free(); return
	var storage: Node = game.get("preview_castle").get("armory_storage")
	var equipped: Dictionary = storage.acquire_or_select("sledge")
	if not bool(equipped.get("ok",false)): errors.append(part+"_equip_failed")
	await ticks(180)
	var host: Node = game.get("preview_sword_prototype")
	if not is_instance_valid(host) or not is_instance_valid(host.get("_npc_body")):
		errors.append(part+"_npc_not_ready"); game.queue_free(); return
	var initial_hp := float(host.get("_npc_hp"))
	var part_hp := float(host.NPC_PART_HP57[part])
	var player_head := float(host.PART_HP["head"])
	var player_hp := float(host.get("_sparring_hp"))
	if initial_hp != 270.0 or player_head != 50.0 or player_hp != 100.0: errors.append(part+"_initial_health")
	var bone: int = host.get("_npc_rig").find_bone(part)
	var point: Vector3 = host.get("_npc_rig").global_transform * host.get("_npc_rig").get_bone_global_pose(bone).origin
	host._npc_take_blade_part(part,point,6.0,Vector3.FORWARD,first,false,true)
	var after_first := {"hp":host.get("_npc_hp"),"part_hp":host.get("_npc_part_hp").get(part),"dead":host.get("_npc_dead"),"disarmed":host.get("_npc_disarmed"),"part":part}
	if bool(after_first.dead) or absf(float(after_first.hp) - (270.0-first)) > 0.01 or absf(float(after_first.part_hp) - (part_hp-first)) > 0.01:
		errors.append(part+"_first_blow_fatal_or_wrong_damage")
	if float(host.get("_sparring_hp")) != player_hp: errors.append(part+"_player_hp_changed")
	host._npc_take_blade_part(part,point,6.0,Vector3.FORWARD,second,false,true)
	await ticks(4)
	var after_second := {"hp":host.get("_npc_hp"),"part_hp":host.get("_npc_part_hp").get(part),"dead":host.get("_npc_dead"),"corpse":is_instance_valid(host.get("_npc_corpse31"))}
	if not bool(after_second.dead) or not bool(after_second.corpse): errors.append(part+"_repeated_blow_did_not_finish")
	rows.append({"part":part,"before":initial_hp,"threshold":part_hp,"first":after_first,"second":after_second})
	game.queue_free()
	await process_frame
	await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	# Both injuries use a real spawned opponent and its ordinary wound/death owner.
	# 160 is the existing upper bound of one melee contact in this game.
	await scenario("head",160.0,50.0)
	await scenario("chest",160.0,120.0)
	var report := {"passed":errors.is_empty(),"errors":errors,"rows":rows,"scope":"Native spawned NPC, existing named-part wound/death path, maximum single melee wound followed by a second blow; player health untouched."}
	var f := FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("HEALTH57 ",JSON.stringify({"passed":report.passed,"errors":errors}))
	quit(0 if errors.is_empty() else 1)
