extends SceneTree
## Actual source scene only. Results diagnose engine/owner behavior, not admission.
class DeferredMarker extends RefCounted:
	var ran := false
	func mark() -> void: ran = true

var scene: Node3D
var failures: Array[String] = []
var report := {"schema":1,"gpu":false,"editor_pause_ready":false,"synthetic_marker_is_nav_receipt":false}
var action := ""
func _initialize() -> void:
	_run.call_deferred()
func require(condition: bool, label: String) -> void:
	if not condition: failures.append(label)
func _run() -> void:
	if DisplayServer.get_name() != "headless":
		quit(2); return
	scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in range(240):
		await physics_frame
		if scene.preview_ready: break
	require(scene.preview_ready, "actual main ready")
	require(scene.transport_status == "ready", "actual vehicle ready")
	require(scene.melee_status == "ground_practice_no_combat_targets" and scene.preview_melee.snapshot().ready, "actual melee ready")
	if not failures.is_empty(): _finish(); return
	var player: CharacterBody3D = scene._player
	var body: RigidBody3D = scene.preview_transport.body
	var melee: Node = scene.preview_melee
	for i in range(90): await physics_frame
	require(player._pose_authority == &"on_foot" and player._jump.is_empty() and player.is_on_floor(), "stable grounded ON_FOOT")
	report["baseline"] = {"revision":scene.PREVIEW_RUNTIME_REVISION,"printshop":scene.printshop_status,"water":scene.water_status,"vehicle":scene.transport_status,"melee":scene.melee_status,"population":scene.population_status,"on_floor":player.is_on_floor(),"pose":str(player._pose_authority),"body_tick":body._physics_tick,"body_velocity":str(body.linear_velocity)}
	if not failures.is_empty(): _finish(); return
	# Actual owner input; do not cancel/reset source timers before snapshots.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true
	require(melee.input_event(press), "actual owner press")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT; release.pressed = false
	require(melee.input_event(release), "actual owner release")
	var initial: Dictionary = melee.snapshot()
	require(initial.cooldown and initial.source.timers > 0, "real cooldown_release timer created")
	report["melee_before_pause"] = initial
	# Diagnostic InputMap held state is scoped solely to this isolated process.
	action = player.ACTION_FORWARD
	Input.action_press(action)
	paused = true
	var tick_before: int = body._physics_tick
	var transform_before := body.global_transform
	var player_before := player.global_transform
	var velocity_before := body.linear_velocity
	var time_before := Time.get_ticks_usec()
	var runtime_before: float = scene._runtime_seconds
	var marker := DeferredMarker.new()
	marker.mark.call_deferred()
	# Default process_always timer deliberately demonstrates documented semantics.
	await create_timer(.65, true).timeout
	var during: Dictionary = melee.snapshot()
	report["paused"] = {"wall_elapsed_us":Time.get_ticks_usec()-time_before,"native_tick_before":tick_before,"native_tick_after":body._physics_tick,"vehicle_transform_unchanged":body.global_transform==transform_before,"vehicle_velocity_unchanged":body.linear_velocity==velocity_before,"player_transform_unchanged":player.global_transform==player_before,"main_runtime_unchanged":scene._runtime_seconds==runtime_before,"held_input":Input.is_action_pressed(action),"deferred_marker_ran":marker.ran,"melee":during,"owner_clock_ms":melee.clock_ms()}
	require(body._physics_tick==tick_before and body.global_transform==transform_before, "native physics frozen during tree pause")
	require(player.global_transform==player_before and scene._runtime_seconds==runtime_before, "pausable actual game callbacks frozen")
	require(Time.get_ticks_usec()-time_before>=600000, "wall clock continued")
	require(Input.is_action_pressed(action) and marker.ran, "held input/deferred work persisted")
	require(during.cooldown and during.source.timers==initial.source.timers, "cooldown pending while advance stopped")
	Input.action_release(action)
	paused = false
	await physics_frame
	await physics_frame
	report["after_resume"] = {"body_tick":body._physics_tick,"melee":melee.snapshot(),"held_input":Input.is_action_pressed(action)}
	require(not melee.snapshot().cooldown, "real elapsed cooldown drained after resume")
	require(body._physics_tick>tick_before, "actual native physics resumed")
	_finish()
func _finish() -> void:
	if not action.is_empty(): Input.action_release(action)
	paused = false
	if is_instance_valid(scene):
		if is_instance_valid(scene.preview_melee): scene.preview_melee.cancel("diagnostic_cleanup")
		scene.free()
	report["failures"] = failures
	report["diagnostic_pass"] = failures.is_empty()
	var file := FileAccess.open("res://CPU_REPORT.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("ACTUAL_PAUSE_DIAGNOSTIC ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
