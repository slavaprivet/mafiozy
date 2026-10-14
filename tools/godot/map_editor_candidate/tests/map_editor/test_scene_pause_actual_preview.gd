extends SceneTree
## Run with --path godot/mafiozi_walk; production scripts read-only, no GPU.
const Pause = preload("C:/Users/Слава/Desktop/Мафиози/tools/godot/map_editor_candidate/scripts/map_editor/scene_pause_owner.gd")
var scene: Node3D
var owner: RefCounted
var failures: Array = []
var checks := 0
var support_enabled := true
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func admit(request: Dictionary) -> bool:
	return scene.preview_ready and not scene.preview_dead and not scene.preview_physics_fault and request.owner_id == scene.get_instance_id() and scene.preview_transport.phase == "ON_FOOT" and scene._player._jump.is_empty() and not scene.preview_transport._e_down
func ready(_receipt: Dictionary) -> bool:
	return scene.preview_transport.phase == "ON_FOOT" and scene._player._jump.is_empty() and scene.preview_transport.runtime.host.driver(scene.preview_transport._vehicle_ref).is_empty()
func ground() -> Dictionary:
	return {"unchanged_source_sha256": FileAccess.get_sha256("res://data/block.json")}
func resume_admission(receipt: Dictionary, objects: Dictionary, terrain: Dictionary) -> bool:
	if not support_enabled or receipt.owner_id != scene.get_instance_id() or objects != {"unchanged_source_buildings": scene._block.buildings} or terrain != ground(): return false
	# Actual current support: no floor ownership is invented by editor callback.
	var feet: Vector3 = scene._player.global_position
	var query := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.2, feet - Vector3.UP * 0.3, 1, [scene._player.get_rid(), scene.preview_transport.body.get_rid()])
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider is StaticBody3D and absf(hit.position.y - feet.y) < 0.21
func run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	scene.preview_residents_enabled = false
	scene.preview_transport_enabled = true
	root.add_child(scene)
	check(scene.preview_ready and scene.transport_status == "ready", "Actual source main/transport ready")
	if not scene.preview_ready or scene.transport_status != "ready": finish(); return
	for i in 60: await physics_frame
	var player: CharacterBody3D = scene._player
	var transport: Node3D = scene.preview_transport
	var body: RigidBody3D = transport.body
	check(player.is_on_floor() and transport.phase == "ON_FOOT", "Actual player on admitted source parking floor")
	owner = Pause.new()
	var config: Dictionary = owner.configure(scene, [
		{"node": scene, "stop_input": false, "fields": ["_runtime_seconds", "_clock", "_door_feedback_seconds"]},
		{"node": player, "identity": {"actor_id": player.get_meta("actor_id"), "life_generation": player.get_meta("life_generation")}, "fields": ["_jump", "_jump_key_down", "_pose_epoch", "velocity"]},
		{"node": transport, "fields": ["_clock", "_sequence", "phase", "_e_down", "_pending_exit"]}
	], [{"node": body, "identity": {"vehicle_id": body.get_meta("vehicle_id"), "life_generation": body.get_meta("life_generation"), "source_clock": body.get_meta("source_clock")}, "fields": ["_physics_tick", "_control_sequence", "_control_source_clock", "_throttle", "_steering_input", "_brake", "_handbrake"], "guard_fields": ["_control_sequence", "_control_source_clock"]}], {"admit_pause": admit, "validate_resume": resume_admission, "transaction_ready": ready, "ground_patch": ground})
	check(config.ok, "Actual main/player/transport/nativebody inventory admitted without production edits")
	if not config.ok: failures.append(str(config.error)); finish(); return
	var logical_clock: int = transport._clock
	var physics_tick: int = body._physics_tick
	var feet: Vector3 = player.global_position
	var frame := body.global_transform
	var velocity := body.linear_velocity
	var sequence: int = body._control_sequence
	var flags := [scene.is_processing(), scene.is_physics_processing(), player.is_physics_processing(), player.is_processing_unhandled_input(), transport.is_physics_processing()]
	var request := {"owner_id": scene.get_instance_id(), "request_id": "actual-source-preview-pause"}
	var paused_state: Dictionary = owner.pause_gameplay(request)
	check(paused_state.ok, "Actual source actors and vehicle acquired native frozen lease")
	if not paused_state.ok: failures.append(str(paused_state.error)); owner.cancel_pause(request); finish(); return
	Input.action_press("preview_move_forward")
	for i in 12: await physics_frame
	check(player.global_position.is_equal_approx(feet), "Held W polling cannot move actual player while paused")
	check(transport._clock == logical_clock and body._physics_tick == physics_tick and body._control_sequence == sequence, "Actual transport clock and native integrator/control sequence stay unchanged")
	check(body.global_transform.is_equal_approx(frame) and body.linear_velocity.is_equal_approx(velocity) and body.freeze, "Actual native vehicle remains frozen without clear_control or authority override")
	check(owner.verify_pause(paused_state.receipt) and owner.transaction_ready(paused_state.receipt), "Actual source lease stable across physics frames")
	support_enabled = false
	check(not owner.resume_gameplay(paused_state.receipt, {"unchanged_source_buildings": scene._block.buildings}, ground()).ok and body.freeze, "Absent source support admission cannot unfreeze actual vehicle")
	support_enabled = true
	Input.action_release("preview_move_forward")
	check(owner.resume_gameplay(paused_state.receipt, {"unchanged_source_buildings": scene._block.buildings}, ground()).ok, "Actual native support ray plus unchanged source receipt admits resume")
	check(flags == [scene.is_processing(), scene.is_physics_processing(), player.is_physics_processing(), player.is_processing_unhandled_input(), transport.is_physics_processing()] and not body.freeze, "Actual original process flags and native freeze restored exactly")
	for i in 3: await physics_frame
	check(transport._clock > logical_clock and body._physics_tick > physics_tick, "Actual source transport/native integration resumes")
	var authority_request := {"owner_id": scene.get_instance_id(), "request_id": "new-native-control-during-pause"}
	var authority_pause: Dictionary = owner.pause_gameplay(authority_request)
	check(authority_pause.ok, "Actual source control-drift guard lease acquired")
	if authority_pause.ok:
		var next_sequence: int = body._control_sequence + 1
		var next_clock: int = maxi(body._control_source_clock, body.profile.source_clock) + 1
		check(body.submit_authoritative_control(0.2, 0, 0, false, next_sequence, str(body.profile.vehicle_id), int(body.profile.life_generation), next_clock), "Actual native control API accepts matching life while isolated test frozen")
		check(not owner.verify_pause(authority_pause.receipt), "New source-control sequence invalidates old frozen receipt")
		check(not owner.cancel_pause(authority_request).ok and body.freeze and body._control_sequence == next_sequence and body._control_source_clock == next_clock, "Pause rollback refuses to rewind newly accepted actual control authority")
	finish()
func finish() -> void:
	Input.action_release("preview_move_forward")
	if is_instance_valid(scene): scene.free()
	print(JSON.stringify({"suite": "pause-actual-source-preview", "checks": checks, "failures": failures, "gpu": false, "unchangedMapOnly": true, "wholeGamePauseVerified": false}))
	quit(0 if failures.is_empty() else 1)
