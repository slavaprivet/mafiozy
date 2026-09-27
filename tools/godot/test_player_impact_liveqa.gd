extends SceneTree
## TEST_ONLY admitted events against the real scene/hero. Not gameplay combat.
var main: Node3D
var player: CharacterBody3D
var host: Node
var driver: RefCounted
var output := ""
var headless := false
var event: Dictionary = {}
var events: Array[Dictionary] = []
var failures: Array[String] = []
var hashes := {}
var started := 0
var finished := false
var samples: Array[Dictionary] = []
var cancelled := false
var observing := false
var frame_samples := {}
var frame_phase := "warmup"
var skip_frames := 0
class Observer extends Node:
	var qa: SceneTree
	var last_frame_us := 0
	func _process(_delta: float) -> void:
		var now := Time.get_ticks_usec()
		var elapsed_ms := float(now - last_frame_us) / 1000.0
		last_frame_us = now
		if qa.skip_frames > 0:
			qa.skip_frames -= 1
			return
		if qa.observing and qa.frame_phase != "warmup":
			if not qa.frame_samples.has(qa.frame_phase): qa.frame_samples[qa.frame_phase] = []
			qa.frame_samples[qa.frame_phase].append(elapsed_ms)
	func _input(input: InputEvent) -> void:
		if qa.observing and (input is InputEventKey or input is InputEventMouseButton or (input is InputEventMouseMotion and input.relative.length() > 1.0)):
			qa.cancelled = true
const SOURCES := ["main.gd","preview_player.gd","preview_transport.gd",
	"character_physics/player_impact_host.gd","character_physics/character_physics_driver.gd",
	"character_physics/character_impact_sink.gd","character_physics/local_hit_reaction.gd",
	"character_physics/exit_ragdoll_body.gd","character_physics/character_physics_pose.gd"]

func _initialize() -> void:
	call_deferred("run")

func _resolve(handle: Variant) -> Dictionary:
	return event.duplicate(true) if handle == event.get("event_id") else {"ok":false}

func hit(id: String, impulse: Vector3) -> Dictionary:
	if cancelled: return {"ok":false,"error":"user_input_cancelled"}
	var owner: Dictionary = host.current_owner()
	var frames: Dictionary = driver.body.capture_world_frames()
	var chest: Transform3D = frames.chest * driver.body._bone_to_body.chest
	var point := chest.origin + chest.basis.x * .025
	event = {"ok":true,"producer_id":"TEST_ONLY_native_impact_qa","event_id":id,"kind":"melee",
		"world_point":point,"final_dead":false,"authoritative_knockdown":false}
	for key in ["actor_id","life_generation","session_id","session_generation","pose_epoch","geometry_revision"]: event[key] = owner[key]
	var result: Dictionary = host.submit(id, {"delivery":"command_unapplied","world_point":point,"impulse_ns":impulse,
		"physics_tick":Engine.get_physics_frames(),"force_profile_id":"TEST_ONLY_native_impact_qa"})
	events.append({"id":id,"result":result,"host_error":host.last_error})
	if not result.get("ok",false): failures.append(id+":"+str(result))
	return result

func pause(seconds: float) -> void:
	await create_timer(seconds).timeout

func capture(label: String) -> void:
	if headless or cancelled: return
	skip_frames = 3
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image.save_png(output.path_join(label+".png")) != OK: failures.append("capture:"+label)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--impact-liveqa-output="): output = arg.trim_prefix("--impact-liveqa-output=")
		elif arg == "--impact-liveqa-selftest": headless = true
	if not output.is_absolute_path() or headless != (DisplayServer.get_name()=="headless"):
		quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	for source in SOURCES: hashes[source] = FileAccess.get_sha256("res://scripts/"+source)
	var observer := Observer.new()
	observer.qa = self
	root.add_child(observer)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main); current_scene = main
	player = main._player; driver = main.preview_transport.character_physics
	await pause(.8 if headless else 5.0)
	var inertias := {}
	for name in ["spine_01","chest","head","upperarm_l","forearm_l","upperarm_r","forearm_r"]: inertias[name] = 1.0
	var configured: Dictionary = main.install_character_impact_source(Callable(self,"_resolve"),
		{"mass_kg":75.0,"max_impulse_ns":1000.0,"stance_thresholds_mps":{"standing":.25,"airborne":.25}},inertias)
	if not configured.get("ok",false):
		failures.append("configure:"+str(configured)); await finish(); return
	host = main.preview_character_impacts
	observing = not headless
	frame_phase = "baseline"
	await pause(.1 if headless else 2.0)
	await capture("baseline")
	frame_phase = "weak"
	hit("weak", Vector3(0,0,2))
	await pause(.07)
	await capture("weak-local")
	await pause(.8)
	frame_phase = "fall"
	hit("strong", Vector3(0,0,24))
	await pause(.15)
	await capture("first-fall")
	hit("repeat", Vector3(8,0,0))
	await pause(.45)
	await capture("repeat-fall")
	started = Time.get_ticks_msec()
	var captured_getup := false
	var last_sample := -1
	while not cancelled and Time.get_ticks_msec()-started < 20000 and player._pose_authority != &"on_foot":
		var sample_slot := (Time.get_ticks_msec()-started)/250
		if sample_slot != last_sample:
			last_sample = sample_slot
			var sample := {"ms":Time.get_ticks_msec()-started,"mode":driver.mode,"driver_elapsed":driver._elapsed,
				"stable":driver._stable,"recovery_stable":driver._recovery_stable,"dead":driver._dead,"impact_dead":driver._impact_dead,
				"host_processing":host.is_physics_processing(),"host_owns":host._owns_physical_advance,"pose_owner":str(player._pose_authority),"host_error":host.last_error,"block":driver.recovery_block_reason}
			for key in ["settled","anchor_world","core_max_linear_speed","core_max_angular_speed","specific_kinetic_energy_j_kg","max_linear_speed","max_angular_speed","core_support_contact_count","support_contact_count","max_joint_anchor_error_m"]:
				sample[key] = driver.last_snapshot.get(key)
			samples.append(sample)
		if driver.mode == "GETTING_UP": frame_phase = "getup"
		if driver.mode == "GETTING_UP" and driver._getup_elapsed >= .4 and not captured_getup:
			await capture("getup"); captured_getup = true
		await process_frame
	if player._pose_authority != &"on_foot": failures.append("recovery_timeout:"+str(driver.mode)+":"+str(driver.recovery_block_reason))
	frame_phase = "recovered"
	await pause(.1 if headless else 2.0)
	await capture("settled")
	await finish()

func finish() -> void:
	if finished: return
	finished = true
	observing = false
	if cancelled: failures.append("user_input_cancelled")
	var stable := true
	for source in hashes: stable = stable and hashes[source] == FileAccess.get_sha256("res://scripts/"+source)
	if not stable: failures.append("source_changed")
	var restored := false
	if not cancelled:
		main.queue_free()
		await process_frame
		await process_frame
	if not headless and not cancelled:
		main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main); current_scene = main
		restored = main.preview_ready and main.preview_transport.ready_for_play
	var timings := {}
	for phase in frame_samples:
		var values: Array = frame_samples[phase]
		values.sort()
		if not values.is_empty(): timings[phase] = {"frames":values.size(),"p50_ms":values[int((values.size()-1)*.5)],"p95_ms":values[int((values.size()-1)*.95)]}
	var report := {"passed":failures.is_empty(),"failures":failures,"test_only_admission":true,"frame_times":timings,
		"production_combat":false,"headless":headless,"events":events,"samples":samples,"source_hashes":hashes,
		"stable_hashes":stable,"restored_interactive":restored}
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("IMPACT_NATIVE_QA "+JSON.stringify({"passed":report.passed,"failures":failures,"stable_hashes":stable,"headless":headless,"test_only_admission":true}))
	if headless: quit(0 if failures.is_empty() else 1)
