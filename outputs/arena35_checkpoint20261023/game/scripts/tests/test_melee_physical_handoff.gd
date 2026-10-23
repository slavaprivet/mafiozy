extends SceneTree
## Actual mouse-admitted ground attack, then explicitly TEST_ONLY incoming J.
## No production enemy/damage authority is asserted by this harness.
var main: Node3D
var player: CharacterBody3D
var host: Node
var melee: Node
var driver: RefCounted
var event := {}
var checks := 0
var failures: Array[String] = []
var results := []
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func resolve(handle: Variant) -> Dictionary:
	return event.duplicate(true) if handle==event.get("event_id") else {"ok":false}
func hit(id: String, impulse: Vector3) -> Dictionary:
	var owner: Dictionary=host.current_owner()
	var frames: Dictionary=driver.body.capture_world_frames()
	var chest: Transform3D=frames.chest*driver.body._bone_to_body.chest
	var point:=chest.origin+chest.basis.x*.025
	event={"ok":true,"producer_id":"TEST_ONLY_melee_transition","event_id":id,"kind":"melee","world_point":point,"final_dead":false,"authoritative_knockdown":false}
	for key in ["actor_id","life_generation","session_id","session_generation","pose_epoch","geometry_revision"]: event[key]=owner[key]
	return host.submit(id,{"delivery":"command_unapplied","world_point":point,"impulse_ns":impulse,"physics_tick":Engine.get_physics_frames(),"force_profile_id":"TEST_ONLY_melee_transition"})
func pause(seconds: float) -> void: await create_timer(seconds).timeout
func button(pressed: bool) -> void:
	var input:=InputEventMouseButton.new(); input.button_index=MOUSE_BUTTON_LEFT; input.pressed=pressed
	player._unhandled_input(input)
func run() -> void:
	for kind in ["punch","kick"]:
		main=load("res://scenes/main.tscn").instantiate(); main.preview_melee_enabled=false; root.add_child(main); current_scene=main
		player=main._player; driver=main.preview_transport.character_physics
		await pause(.5)
		check(main._install_preview_melee_practice(),kind+":practice configured")
		if not is_instance_valid(main.preview_melee): main.free(); break
		melee=main.preview_melee
		var inertias: Dictionary={}
		for name in ["spine_01","chest","head","upperarm_l","forearm_l","upperarm_r","forearm_r"]: inertias[name]=1.0
		check(main.install_character_impact_source(resolve,{"mass_kg":75.0,"max_impulse_ns":1000.0,"stance_thresholds_mps":{"standing":.25,"airborne":.25}},inertias).get("ok",false),kind+":TEST_ONLY incoming host configured")
		host=main.preview_character_impacts
		player.set_mouse_captured(true)
		# Seed selects a real source random branch; no animation/attack mutation.
		for seed_value in 100:
			melee._rng.seed=seed_value
			var roll: float=melee.random_draw()
			if (roll<.2)==(kind=="kick"):
				melee._rng.seed=seed_value; break
		button(true); button(false)
		await pause(.06 if kind=="punch" else .22)
		check(melee._source.snapshot().animation.get("type")==kind,kind+":real source attack active")
		var weak:=hit(kind+"_weak",Vector3(1,0,2))
		check(weak.get("ok",false),kind+":weak reaction accepted mid-attack "+str(weak))
		await pause(.035)
		check(host._local_active and host.last_error.is_empty(),kind+":weak pose survives actual decorator")
		var before: Dictionary=driver.body.capture_world_frames()
		var strong:=hit(kind+"_strong",Vector3(0,0,24))
		check(strong.get("ok",false),kind+":strong fall accepted mid-attack "+str(strong))
		check(driver.mode=="FALLING" and player._pose_authority!=&"on_foot",kind+":physical owner takes over")
		check(melee._state.get("start")==null,kind+":outgoing attack cancelled at ownership transfer")
		var after: Dictionary=driver.body.capture_world_frames()
		var worst:=0.0
		for name in before:
			worst=maxf(worst,before[name].origin.distance_to(after[name].origin))
		check(worst<.001,kind+":no first-frame bone teleport "+str(worst))
		var start:=Time.get_ticks_msec()
		while Time.get_ticks_msec()-start<14000 and player._pose_authority!=&"on_foot": await process_frame
		check(player._pose_authority==&"on_foot" and not main.preview_physics_fault,kind+":actual physics recovery")
		results.append({"kind":kind,"weak":weak,"strong":strong,"first_frame_origin_error_m":worst,"recovery_ms":Time.get_ticks_msec()-start})
		main.queue_free(); await process_frame; await process_frame
	print("MELEE_PHYSICAL_HANDOFF ",JSON.stringify({"checks":checks,"failures":failures,"results":results,"scope":"Actual mouse/source attack and player physical owner; incoming impulse admission TEST_ONLY, no live enemy damage"}))
	quit(0 if failures.is_empty() else 1)
