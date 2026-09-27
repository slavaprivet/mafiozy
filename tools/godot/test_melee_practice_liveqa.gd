extends SceneTree
## Native actual-main input and render acceptance. Practice has no combat target.
var main: Node3D
var player: CharacterBody3D
var host: Node
var output := ""
var observing := false
var injecting := false
var cancelled := false
var skip_frames := 0
var phase := "warmup"
var times := {}
var failures: Array[String] = []
var actions := []
var hashes := {}
const SOURCES := ["main.gd","preview_player.gd","combat/preview_melee.gd","combat/melee_physical_pose.gd","combat/melee_pose.gd","combat/melee_input.gd","combat/melee_attack_source.gd"]
class Observer extends Node:
	var qa: SceneTree
	var previous := 0
	func _process(_delta: float) -> void:
		var now := Time.get_ticks_usec()
		var ms := (now-previous)/1000.0
		previous=now
		if qa.skip_frames>0: qa.skip_frames-=1; return
		if qa.observing:
			if not qa.times.has(qa.phase): qa.times[qa.phase]=[]
			qa.times[qa.phase].append(ms)
	func _input(event: InputEvent) -> void:
		if qa.observing and not qa.injecting and (event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion and event.relative.length()>1): qa.cancelled=true
func _initialize() -> void: run.call_deferred()
func pause(seconds: float) -> void: await create_timer(seconds).timeout
func button(index: MouseButton, pressed: bool) -> void:
	if cancelled: return
	var event:=InputEventMouseButton.new(); event.button_index=index; event.pressed=pressed
	injecting=true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	injecting=false
func capture(label: String) -> void:
	if cancelled: return
	skip_frames=3
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(output.path_join(label+".png"))!=OK: failures.append("capture:"+label)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--melee-liveqa-output="): output=arg.trim_prefix("--melee-liveqa-output=")
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	for source in SOURCES: hashes[source]=FileAccess.get_sha256("res://scripts/"+source)
	var observer:=Observer.new(); observer.qa=self; root.add_child(observer)
	main=load("res://scenes/main.tscn").instantiate(); main.preview_melee_enabled=false; root.add_child(main); current_scene=main
	player=main._player
	# Same quarter, same camera and same pose owner for baseline/action timings.
	player._camera_yaw+=1.45; player._update_camera_rotation()
	await pause(4)
	observing=true; phase="before_disabled"
	await pause(2)
	await capture("baseline")
	observing=false
	if not main._install_preview_melee_practice(): failures.append("practice_binding"); await finish(); return
	host=main.preview_melee
	await pause(.5)
	observing=true; phase="after_idle"
	await pause(2)
	phase="ordinary"
	for kind in ["punch","kick"]:
		for seed_value in 100:
			host._rng.seed=seed_value
			var roll: float=host.random_draw()
			if (roll<.2)==(kind=="kick"): host._rng.seed=seed_value; break
		button(MOUSE_BUTTON_LEFT,true); button(MOUSE_BUTTON_LEFT,false)
		await pause(.12 if kind=="punch" else .28)
		var action: Dictionary=host._source.snapshot().animation
		actions.append({"requested_source_branch":kind,"actual":action.duplicate(true),"host_error":host.last_error,"affine_writer":player._pose_affine_active})
		if action.get("type")!=kind or not player._pose_affine_active: failures.append("input_pose:"+kind)
		await capture(kind)
		await pause(.7)
	phase="guard"
	button(MOUSE_BUTTON_RIGHT,true)
	await pause(.25)
	await capture("guard")
	if not host._source.snapshot().block: failures.append("guard")
	await pause(1.2)
	button(MOUSE_BUTTON_RIGHT,false)
	await pause(.3)
	phase="charged"
	button(MOUSE_BUTTON_LEFT,true)
	await pause(1.40)
	if host._source.snapshot().animation.get("type")!="heavy": failures.append("charged")
	await capture("heavy")
	button(MOUSE_BUTTON_LEFT,false)
	await pause(.65)
	phase="recovered"
	await pause(2)
	await capture("recovered")
	if not host.last_error.is_empty() or player._pose_affine_active: failures.append("recovered:"+host.last_error)
	await finish()
func finish() -> void:
	observing=false
	if cancelled: failures.append("user_input_cancelled")
	var stable:=true
	for source in hashes: stable=stable and hashes[source]==FileAccess.get_sha256("res://scripts/"+source)
	if not stable: failures.append("source_changed")
	var stats: Dictionary={}
	for key in times:
		var values: Array=times[key]; values.sort()
		if not values.is_empty(): stats[key]={"frames":values.size(),"p50_ms":values[int((values.size()-1)*.5)],"p95_ms":values[int((values.size()-1)*.95)]}
	var restored:=false
	if not cancelled:
		if is_instance_valid(main): main.queue_free()
		await process_frame; await process_frame
		main=load("res://scenes/main.tscn").instantiate(); root.add_child(main); current_scene=main
		if not is_instance_valid(main.preview_melee): main._install_preview_melee_practice()
		restored=main.preview_ready and is_instance_valid(main.preview_melee)
	var report:={"passed":failures.is_empty(),"failures":failures,"source_hashes":hashes,"stable_hashes":stable,"frame_times":stats,"actions":actions,"restored_interactive":restored,"qualification":"Actual GPU quarter and real native input route, ground practice only, zero combat targets/HP; not city/crowd benchmark"}
	var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("MELEE_NATIVE_QA ",JSON.stringify({"passed":report.passed,"failures":failures,"restored_interactive":restored,"stable_hashes":stable}))
