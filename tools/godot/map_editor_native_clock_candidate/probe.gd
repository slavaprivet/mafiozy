extends SceneTree
var failures: Array[String] = []
var report := {"schema":1,"gpu":false,"editor_pause_ready":false,"source_parity_claim":false,"actual_navigation_tested":false}
var scene: Node3D
var held_action := ""

func _initialize() -> void: _run.call_deferred()
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func timer(seconds: float) -> void: await create_timer(seconds, true).timeout
func wait_until_wall(deadline_us: int, max_slices: int) -> bool:
	for i in range(max_slices):
		if Time.get_ticks_usec() >= deadline_us: return true
		await timer(.02)
	return Time.get_ticks_usec() >= deadline_us
func load_actual() -> Node3D:
	var actual: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(actual)
	for i in range(240):
		await physics_frame
		if actual.preview_ready: break
	check(actual.preview_ready and actual.transport_status == "ready" and actual.melee_status == "ground_practice_no_combat_targets", "actual main/source bootstrap")
	return actual

func _run() -> void:
	if DisplayServer.get_name() != "headless": quit(2); return
	var original: Node3D = Node3D.new()
	original.set_script(load("res://scripts/main.gd"))
	root.add_child(original)
	for i in range(240):
		await physics_frame
		if original.preview_ready: break
	check(original.preview_ready and original.transport_status == "ready" and original.melee_status == "ground_practice_no_combat_targets", "unchanged native main bootstrap")
	if not failures.is_empty(): finish(); return
	var original_ground_frames := 0
	for i in range(90):
		if original._player.is_on_floor(): break
		await physics_frame
		original_ground_frames += 1
	check(original._player.is_on_floor(), "unchanged native owner grounded")
	if not failures.is_empty(): finish(); return
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true
	var release := InputEventMouseButton.new(); release.button_index = MOUSE_BUTTON_LEFT; release.pressed = false
	var original_before := Time.get_ticks_usec() / 1000.0
	var original_press: bool = original.preview_melee.input_event(press)
	var original_release: bool = original.preview_melee.input_event(release)
	var original_after := Time.get_ticks_usec() / 1000.0
	var original_first: Dictionary = original.preview_melee.snapshot()
	check(original_press and original_release and original_first.cooldown and original_first.source.attackSeq == 1, "unchanged native first eligible attack admitted")
	check(original_before-1.0 <= float(original_first.source.lastPunchClientT) and float(original_first.source.lastPunchClientT) <= original_after+1.0, "unchanged native first attack uses absolute Time")
	original.free()
	scene = await load_actual()
	if not failures.is_empty(): finish(); return
	var host: Node = scene.preview_melee
	var clock: RefCounted = host.gameplay_clock
	var wall_before := Time.get_ticks_usec() / 1000.0
	var initial_clock: float = host.clock_ms()
	var wall_after := Time.get_ticks_usec() / 1000.0
	check(wall_before-1.0 <= initial_clock and initial_clock <= wall_after+1.0, "before-first-pause clock retains absolute native Time baseline")
	report["initial_clock"] = {"wall_before_ms":wall_before,"candidate_ms":initial_clock,"wall_after_ms":wall_after}
	check(host.get_script().resource_path == "res://diagnostic/clocked_melee.gd", "actual SourceMelee host subclass")
	check(host._source.get_script().resource_path == "res://scripts/combat/melee_attack_source.gd", "actual unchanged SourceMelee")
	check(host.get("_input").get_script().resource_path == "res://scripts/combat/melee_input.gd", "actual unchanged Input")
	var input_clock: Callable = host.get("_input").get("_now")
	check(input_clock.is_valid() and input_clock.get_object() == host and absf(float(input_clock.call())*1000.0-host.clock_ms())<1.0, "optional Input clock bound to exact host clock")
	check(host.snapshot().ready and host._source.snapshot().fault == "", "actual source configured")
	var candidate_ground_frames := 0
	for i in range(90):
		if scene._player.is_on_floor(): break
		await physics_frame
		candidate_ground_frames += 1
	var player: CharacterBody3D = scene._player
	var body: RigidBody3D = scene.preview_transport.body
	check(player._pose_authority == &"on_foot" and player._jump.is_empty() and player.is_on_floor(), "candidate actual owner grounded")
	if not failures.is_empty(): finish(); return
	var attack_before := Time.get_ticks_usec() / 1000.0
	var candidate_press: bool = host.input_event(press)
	var candidate_release: bool = host.input_event(release)
	var attack_after := Time.get_ticks_usec() / 1000.0
	var initial: Dictionary = host.snapshot()
	check(candidate_press and candidate_release, "candidate actual host accepts first press/release")
	check(initial.cooldown and initial.source.timers > 0 and initial.source.attackSeq == 1, "candidate first real 300ms cooldown allocated")
	check(original_first.cooldown == initial.cooldown and original_first.source.timers == initial.source.timers and original_first.source.attackSeq == initial.source.attackSeq, "first eligible attack matches unchanged native owner")
	check(attack_before-1.0 <= float(initial.source.lastPunchClientT) and float(initial.source.lastPunchClientT) <= attack_after+1.0, "first SourceMelee timestamp retains absolute native baseline")
	report["first_attack"] = {"original_ground_frames":original_ground_frames,"candidate_ground_frames":candidate_ground_frames,"original_wall_before_ms":original_before,"original_wall_after_ms":original_after,"candidate_wall_before_ms":attack_before,"candidate_wall_after_ms":attack_after,"original_last_punch_ms":original_first.source.lastPunchClientT,"candidate_last_punch_ms":initial.source.lastPunchClientT,"original_cooldown":original_first.cooldown,"candidate_cooldown":initial.cooldown,"original_timers":original_first.source.timers,"candidate_timers":initial.source.timers,"original_seq":original_first.source.attackSeq,"candidate_seq":initial.source.attackSeq}
	var options_before: Dictionary = host._options()
	check(absf(float(options_before.time)*1000.0-host.clock_ms()) < 1.0, "Input options share source clock")
	held_action = player.ACTION_FORWARD
	Input.action_press(held_action)
	var lease: Dictionary = clock.pause(scene,host)
	check(lease.get("ok",false), "owner issued first clock lease")
	var entry_clock: float = clock.now_ms()
	check(entry_clock == float(lease.at_ms), "pause receipt and immediate clock share exact boundary")
	check(not clock.pause(scene,host).get("ok",false), "nested pause refused")
	var wrong := lease.duplicate(); wrong.clock = RefCounted.new()
	check(not clock.resume(wrong) and clock.is_paused(), "wrong clock refused without rewind")
	wrong = lease.duplicate(); wrong.generation = int(lease.generation)+1
	check(not clock.resume(wrong) and clock.is_paused(), "wrong generation refused without rewind")
	wrong = lease.duplicate(); wrong.serial = int(lease.serial)-1
	check(not clock.resume(wrong) and clock.is_paused(), "stale receipt refused without rewind")
	var active_at_pause: float = clock.now_ms()
	check(active_at_pause == float(lease.at_ms), "pause boundary remains exact after receipt negatives")
	var body_tick: int = body._physics_tick
	var body_transform := body.global_transform
	var body_velocity := body.linear_velocity
	var player_transform := player.global_transform
	var runtime: float = scene._runtime_seconds
	paused = true
	var wall_start := Time.get_ticks_usec()
	# SceneTreeTimer advances by engine time, which may outrun wall time in
	# headless mode. Measure the actual monotonic wall interval explicitly.
	check(await wait_until_wall(wall_start+650000,80), "bounded wall pause wait reached 650ms")
	var paused_snapshot: Dictionary = host.snapshot()
	var active_after: float = clock.now_ms()
	var option_time: float = float(host._options().time)*1000.0
	var fallback_time: float = float(input_clock.call())*1000.0
	report["pause"] = {"wall_elapsed_us":Time.get_ticks_usec()-wall_start,"lease_at_ms":lease.at_ms,"entry_clock_ms":entry_clock,"clock_after_pause_ms":active_after,"clock_delta_ms":active_after-active_at_pause,"input_clock_delta_ms":option_time-active_after,"body_tick_before":body_tick,"body_tick_after":body._physics_tick,"body_transform_same":body.global_transform==body_transform,"body_velocity_same":body.linear_velocity==body_velocity,"player_transform_same":player.global_transform==player_transform,"runtime_same":scene._runtime_seconds==runtime,"cooldown":paused_snapshot.cooldown,"timers":paused_snapshot.source.timers,"held_input":Input.is_action_pressed(held_action)}
	check(Time.get_ticks_usec()-wall_start >= 600000, "650ms wall pause elapsed")
	check(absf(active_after-active_at_pause)<1.0 and absf(option_time-active_after)<1.0 and absf(fallback_time-active_after)<1.0, "Source and both Input clock paths frozen")
	check(active_after == float(lease.at_ms), "clock equals exact receipt after 650ms wall pause")
	check(body._physics_tick==body_tick and body.global_transform==body_transform and body.linear_velocity==body_velocity, "actual native physics tick frozen")
	check(player.global_transform==player_transform and scene._runtime_seconds==runtime, "actual main/player frozen")
	check(paused_snapshot.cooldown and paused_snapshot.source.timers==initial.source.timers, "cooldown remains pending during pause")
	check(Input.is_action_pressed(held_action), "global held Input persists during pause")
	Input.action_release(held_action); held_action = ""
	check(clock.resume(lease), "exact live receipt resumes clock")
	check(not clock.resume(lease), "duplicate resume refused")
	var release_boundary_clock: float = clock.now_ms()
	check(release_boundary_clock == float(lease.at_ms), "first post-resume read equals exact receipt before active step")
	paused = false
	var resume_wall_start := Time.get_ticks_usec()
	await physics_frame
	var immediate: Dictionary = host.snapshot()
	check(immediate.cooldown and immediate.source.timers==initial.source.timers, "300ms cooldown pending immediately after resume")
	check(await wait_until_wall(resume_wall_start+100000,30), "bounded active wall wait reached 100ms")
	var early: Dictionary = host.snapshot()
	var early_wall_us := Time.get_ticks_usec()-resume_wall_start
	check(early_wall_us < 280000, "early snapshot before 300ms source threshold")
	check(early.cooldown and early.source.timers==initial.source.timers, "remaining active cooldown not drained at 100ms")
	check(await wait_until_wall(resume_wall_start+370000,50), "bounded active wall wait reached 370ms")
	var drained: Dictionary = host.snapshot()
	check(not drained.cooldown and drained.source.timers==0 and body._physics_tick>body_tick, "real cooldown drains naturally after active 300ms and physics resumes")
	report["resume"] = {"release_boundary_clock_ms":release_boundary_clock,"immediate_cooldown":immediate.cooldown,"early_wall_us":early_wall_us,"at_100ms_cooldown":early.cooldown,"drained_wall_us":Time.get_ticks_usec()-resume_wall_start,"after_370ms_cooldown":drained.cooldown,"source_timers":drained.source.timers,"body_tick_after":body._physics_tick,"source_attack_seq_unchanged":drained.source.attackSeq==initial.source.attackSeq,"source_fault":drained.source.fault,"input_options_clock_ms":float(host._options().time)*1000.0,"source_clock_ms":host.clock_ms()}
	check(drained.source.attackSeq==initial.source.attackSeq and drained.source.fault=="", "source identity/sequence intact")
	check(absf(float(host._options().time)*1000.0-host.clock_ms())<1.0, "Input options still share resumed clock")
	var lease2: Dictionary = clock.pause(scene,host)
	check(lease2.get("ok",false) and not clock.receipt_live(lease), "repeated pause invalidates prior receipt")
	paused = true
	await timer(.08)
	check(not clock.resume(lease) and clock.is_paused(), "old receipt cannot release newer pause")
	check(clock.resume(lease2), "new receipt releases repeated pause")
	paused = false
	var old_receipt := lease2.duplicate()
	var old_clock := clock
	# A freed actual main/host makes an orphan lease unusable even if held externally.
	scene.free(); scene = null
	check(not old_clock.receipt_live(old_receipt) and not old_clock.pause(null,null).get("ok",false), "orphan clock rejects owner operations")
	var second: Node3D = await load_actual()
	if failures.is_empty():
		var second_host: Node = second.preview_melee
		var second_clock: RefCounted = second_host.gameplay_clock
		check(second_clock != old_clock and not second_clock.resume(old_receipt), "new main life rejects old receipt")
		var second_lease: Dictionary = second_clock.pause(second,second_host)
		check(second_lease.get("ok",false) and second_clock.resume(second_lease), "new owner generation has independent clock lease")
	second.free()
	finish()

func finish() -> void:
	if not held_action.is_empty(): Input.action_release(held_action)
	paused = false
	if is_instance_valid(scene): scene.free()
	report["failures"] = failures
	report["diagnostic_pass"] = failures.is_empty()
	var file := FileAccess.open("res://CPU_REPORT.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("ACTUAL_NATIVE_CLOCK_DIAGNOSTIC ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
