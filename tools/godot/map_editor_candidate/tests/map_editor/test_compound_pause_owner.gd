extends SceneTree
const SceneOwner = preload("res://scripts/map_editor/scene_pause_owner_v2.gd")
const AnimationOwner = preload("res://scripts/map_editor/animation_pause_adapter_v2.gd")
const JointOwner = preload("res://scripts/map_editor/compound_pause_owner.gd")
class ControlledBody extends RigidBody3D:
	var server_sequence := 1
	var throttle := 0.4
	var source_clock := 5.0
	var allow_control_reconciliation := false
	func authorize_control(handle: RefCounted, receipt: Dictionary, current: Array) -> Dictionary:
		return {"ok": allow_control_reconciliation and handle != null and not receipt.token.is_empty() and current.back().instance_id == get_instance_id() and current.back().values.server_sequence == server_sequence, "control_owner_id": get_instance_id()}
var checks := 0
var failures := 0
var refuse_partial := false
var external_ready := true
var allow_cancel := true
var admission_calls := 0
var joint: RefCounted
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func gate(phase: String, _details: Dictionary) -> bool:
	admission_calls += 1
	if joint != null: check(not joint.cancel_pause({}).ok, "Owner callback reentry refused")
	return allow_cancel if phase == "cancel" else external_ready
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main := Node3D.new()
	root.add_child(main)
	var body := ControlledBody.new()
	body.gravity_scale = 0
	body.set_meta("generation", 4)
	main.add_child(body)
	body.linear_velocity = Vector3.ZERO
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	body.set_process(false)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	var timer := Timer.new()
	main.add_child(timer)
	timer.start(30)
	var pose := Node3D.new()
	pose.name = "Pose"
	main.add_child(pose)
	var player := AnimationPlayer.new()
	main.add_child(player)
	player.set_meta("generation", 7)
	var animation := Animation.new()
	animation.length = 20
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("Pose:position"))
	animation.track_insert_key(track, 0, Vector3.ZERO)
	animation.track_insert_key(track, 20, Vector3(2, 0, 0))
	var library := AnimationLibrary.new()
	library.add_animation("walk", animation)
	player.add_animation_library("", library)
	player.play("walk")
	player.advance(0.25)
	await physics_frame
	await process_frame
	var scene := SceneOwner.new()
	check(scene.configure(main, [{"node": main}, {"node": timer}], [{"node": body, "identity": {"generation": 4}, "fields": ["server_sequence", "throttle", "source_clock"], "guard_fields": ["server_sequence"]}], {"admit_pause": func(_request): return true, "validate_resume": func(_receipt, _objects, _ground): return true, "transaction_ready": func(_receipt): return true, "ground_patch": func(): return {}, "pause_step": func(_step): return not refuse_partial}).ok, "Real scene inventory configured")
	check(not scene.configure_control_reconciliation(body, func(_handle, _receipt, _current): return true).ok, "Unbound foreign reconciliation callback denied")
	check(scene.configure_control_reconciliation(body, body.authorize_control).ok, "Configure-time actual inventory control owner bound")
	var anim := AnimationOwner.new()
	check(anim.configure(main, [{"mixer": player, "identity": {"generation": 7}, "pose_targets": [{"node": pose, "properties": ["position"]}]}]).ok, "Actual AnimationPlayer configured")
	joint = JointOwner.new()
	check(joint.configure(scene, anim, gate).ok, "Mandatory explicit compound inventory gate")
	check(joint.callbacks().size() == 6, "Six host callbacks")
	var request := {"owner_id": main.get_instance_id(), "request_id": "joint-real-1"}
	external_ready = false
	check(not joint.pause_gameplay(request).ok and not body.freeze and player.active and not timer.paused, "Unadmitted NPC/nav inventory refuses before writes")
	external_ready = true
	var paused: Dictionary = joint.pause_gameplay(request)
	check(paused.ok and body.freeze and not player.active and timer.paused, "All actual owners stopped")
	var saved_left: float = timer.time_left
	var saved_position: float = player.current_animation_position
	var scene_handle: RefCounted = scene._issued
	var anim_handle: RefCounted = anim._issued
	var calls_before := admission_calls
	var barrier_before: int = scene._settled_frame
	check(scene.preflight_restore(scene_handle).ok and anim.preflight_restore(anim_handle).ok, "All-owner preflight passes")
	check(calls_before == admission_calls and barrier_before == scene._settled_frame, "Preflight read-only without owner callbacks/frame mutation")
	check(not scene.preflight_restore(RefCounted.new()).ok and not anim.preflight_restore(RefCounted.new()).ok, "Forged child capsule refused")
	await physics_frame
	await process_frame
	check(timer.time_left == saved_left and player.current_animation_position == saved_position and body.freeze, "Native physics/Timer/animation clocks stable across frame")
	check(joint.transaction_ready(paused.receipt), "Real frame barrier with external admission")
	player.speed_scale = 2
	check(not joint.cancel_pause(request).ok and body.freeze and not player.active and timer.paused, "Second owner refusal does not restore first owner")
	check(scene._issued == scene_handle and anim._issued == anim_handle, "Refusal retains issued capsules")
	player.speed_scale = 1 # Test-owned config repair, not play/seek or clock rewrite.
	check(joint.cancel_pause(request).ok and not body.freeze and player.active and not timer.paused, "Explicit owner repair then synchronous joint restore")
	check(body.freeze_mode == RigidBody3D.FREEZE_MODE_KINEMATIC and not body.is_processing(), "Initially disabled flags and native body mode exact")
	check(timer.time_left == saved_left and player.current_animation_position == saved_position, "Restore did not rewind/advance clocks")
	request.request_id = "joint-control"
	paused = joint.pause_gameplay(request)
	check(paused.ok, "Second admitted pause")
	body.server_sequence = 2
	check(not joint.cancel_pause(request).ok and body.server_sequence == 2 and body.freeze and not player.active, "New server control remains new while both owners held")
	check(not scene.reconcile_guard_fields(scene._issued).ok and body.server_sequence == 2, "No unadmitted authority repair/rewind")
	body.allow_control_reconciliation = true
	check(scene.reconcile_guard_fields(scene._issued).ok, "Actual source owner acknowledges same-payload sequence bump")
	check(joint.cancel_pause(request).ok and body.server_sequence == 2 and body.throttle == 0.4 and player.active and not body.freeze, "Authorized recovery never restores stale server control")
	request.request_id = "joint-generation"
	check(joint.pause_gameplay(request).ok, "Generation test pause")
	player.set_meta("generation", 8)
	check(not joint.cancel_pause(request).ok and body.freeze and not player.active, "Changed generation prevents any restoration")
	player.set_meta("generation", 7) # This fixture owner repairs original session.
	var other := Node3D.new()
	main.add_child(other)
	player.reparent(other)
	check(not joint.cancel_pause(request).ok and body.freeze and not player.active, "Reparented second owner prevents first restore")
	player.reparent(main)
	check(joint.cancel_pause(request).ok and player.active and not body.freeze, "Owner restores exact original parent before recovery")
	request.request_id = "joint-partial"
	refuse_partial = true
	var partial: Dictionary = joint.pause_gameplay(request)
	check(not partial.ok and not partial.retained and not body.freeze and player.active and not timer.paused and not joint.state().leased, "Partial pause cleanup restores all exact originals synchronously")
	request.request_id = "joint-partial-retained"
	allow_cancel = false
	partial = joint.pause_gameplay(request)
	check(not partial.ok and partial.retained and body.freeze and not player.active and timer.paused and joint.state().fault, "Refused support cancellation keeps all actual owners stopped after partial pause")
	check(not joint.cancel_pause(request).ok and body.freeze and not player.active, "Retained partial pause does not guess support admission")
	allow_cancel = true
	check(joint.cancel_pause(request).ok and not body.freeze and player.active and not timer.paused, "Actual owner repairs support admission then exact joint cancellation")
	refuse_partial = false
	request.request_id = "joint-resume"
	paused = joint.pause_gameplay(request)
	check(paused.ok, "Resume scenario pause")
	await physics_frame
	await process_frame
	check(joint.resume_gameplay(paused.receipt, {}, {}).ok and not body.freeze and player.active and not timer.paused, "Six API real joint resume")
	request.request_id = "joint-new-packet-requires-new-session"
	check(joint.pause_gameplay(request).ok, "Changed payload negative scenario lease")
	body.server_sequence = 3
	body.throttle = 0.8
	check(not scene.reconcile_guard_fields(scene._issued).ok and body.throttle == 0.8 and body.server_sequence == 3 and body.freeze and not player.active, "New sequence plus changed nonguard throttle cannot replay old payload")
	body.source_clock = 6
	check(not scene.reconcile_guard_fields(scene._issued).ok and body.source_clock == 6, "Clock cannot be reconciled or rewound")
	check(not joint.cancel_pause(request).ok and body.freeze and not player.active and timer.paused and body.source_clock == 6 and body.throttle == 0.8, "Different packet/clock remains retained; requires actual source owner's NEW session, no rewind")
	main.free()
	print("COMPOUND_PAUSE ", checks, " checks ", failures, " failures; native body/timer/player; production_wired=false; NPC capsule mandatory")
	quit(0 if failures == 0 else 1)
