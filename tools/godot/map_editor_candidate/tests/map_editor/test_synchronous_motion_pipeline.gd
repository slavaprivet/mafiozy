extends SceneTree
const SceneOwner = preload("res://scripts/map_editor/scene_pause_owner_v2.gd")
const AnimationOwner = preload("res://scripts/map_editor/animation_pause_adapter_v2.gd")
const JointOwner = preload("res://scripts/map_editor/compound_pause_owner.gd")
const Host = preload("res://scripts/map_editor/editor_host_adapter.gd")
const Workspace = preload("res://scripts/map_editor/editor_workspace.gd")
const Controller = preload("res://scripts/map_editor/editor_controller.gd")
const Registry = preload("res://scripts/map_editor/object_registry.gd")
const Pipeline = preload("res://scripts/map_editor/synchronous_motion_pipeline.gd")
class ScriptGetter extends Node:
	var getter_calls := 0
	var custom_clock: float:
		get:
			getter_calls += 1
			return 0.0
var checks := 0
var failed := 0
var current := {}
var mutation := ""
var callback_calls := 0
var accept_ready := true
var motion: InputEventMouseMotion
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func owner_ready(_receipt: Dictionary) -> bool:
	callback_calls += 1
	if not current.is_empty() and current.has("pipeline"):
		var pipeline: RefCounted = current.pipeline
		check(not pipeline.consume_proof(pipeline.last_token) and not pipeline.consume_proof(RefCounted.new()), "Proof invalidated before external callback; forged token refused")
		check(pipeline._issue() == null, "Even private diagnostic issuance cannot issue proof DURING callback")
		check(not pipeline.try_motion(motion).ok, "Callback synchronous dispatch reentry refused")
		if mutation == "scene_timer": current.timer.wait_time += 1
		if mutation == "scene_control": current.body.set_meta("control_sequence", 2)
	return accept_ready
func external_gate(phase: String, _details: Dictionary) -> bool:
	if phase == "ready" and not current.is_empty() and current.has("pipeline"):
		callback_calls += 1
		check(not current.pipeline.consume_proof(current.pipeline.last_token), "No proof crosses second external owner Callable")
		check(current.pipeline._issue() == null, "External callback inflight fence blocks fresh proof issuance")
		check(not current.pipeline.try_motion(motion).ok, "Second callback reentry refused")
		if mutation == "external_timer": current.timer.wait_time += 1
		if mutation == "external_control": current.body.set_meta("control_sequence", 2)
		if mutation == "external_route_child": current.editor.camera.add_child(Node.new())
	return true
func make_fixture(body_count: int, with_getter: bool = false) -> Dictionary:
	var main := Node3D.new()
	root.add_child(main)
	var nodes: Array = [{"node": main, "stop_input": false}]
	var bodies: Array = []
	var mixers: Array = []
	var first_body: RigidBody3D
	var first_timer: Timer
	for i in body_count:
		var body := RigidBody3D.new()
		body.gravity_scale = 0
		body.position = Vector3(i * 3, 0, 100)
		main.add_child(body)
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		body.add_child(shape)
		body.set_meta("control_sequence", 1)
		bodies.append({"node": body, "identity": {"control_sequence": 1}})
		if i == 0: first_body = body
	for i in 8:
		var timer := Timer.new()
		main.add_child(timer)
		timer.start(30)
		nodes.append({"node": timer})
		if i == 0: first_timer = timer
		var pose := Node3D.new()
		pose.name = "Pose" + str(i)
		main.add_child(pose)
		var player := AnimationPlayer.new()
		main.add_child(player)
		var animation := Animation.new()
		animation.length = 20
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath(str(pose.name) + ":position"))
		animation.track_insert_key(track, 0, Vector3.ZERO)
		animation.track_insert_key(track, 20, Vector3(2, 0, 0))
		var library := AnimationLibrary.new()
		library.add_animation("walk", animation)
		player.add_animation_library("", library)
		player.play("walk")
		player.advance(0.25)
		mixers.append({"mixer": player, "pose_targets": [{"node": pose, "properties": ["position"]}]})
	var getter: Node
	if with_getter:
		getter = ScriptGetter.new()
		main.add_child(getter)
		nodes.append({"node": getter, "fields": ["custom_clock"]})
	var scene := SceneOwner.new()
	check(scene.configure(main, nodes, bodies, {"admit_pause": func(_r): return true, "validate_resume": func(_r, _o, _g): return true, "transaction_ready": owner_ready, "ground_patch": func(): return {}}).ok, "Real native scene inventory")
	var animation_owner := AnimationOwner.new()
	check(animation_owner.configure(main, mixers).ok, "Real native animation inventory")
	var joint := JointOwner.new()
	check(joint.configure(scene, animation_owner, external_gate).ok, "Explicit isolated owner admission")
	var host := Host.new()
	check(host.mount(main, joint.callbacks()).ok, "Real Host mounted")
	var registry := Registry.new()
	var visual := MeshInstance3D.new()
	visual.mesh = BoxMesh.new()
	main.add_child(visual)
	check(registry.register_object("box", visual, {"kind": "building", "source": {"fixture": true}}).ok, "Native mesh fixture")
	var game := Camera3D.new()
	main.add_child(game)
	game.position = Vector3(0, 0, 10)
	game.make_current()
	var editor := Controller.new()
	main.add_child(editor)
	check(editor.setup(registry, registry.source_document("proof-native-fixture"), game, host.enter, host.leave).ok, "Frozen Controller setup")
	var workspace := Workspace.new()
	main.add_child(workspace)
	workspace.editor = editor
	workspace._transaction_ready = host.transaction_ready
	check(host.bind_workspace(workspace).ok, "Frozen Workspace object branch bound (not fullgroundsetup)")
	check(editor.enter_editor().ok, "Held editor entry")
	var pipeline := Pipeline.new()
	check(pipeline.configure(host, workspace, joint, scene, animation_owner).ok, "Explicit exact-script motion pipeline configured")
	return {"main": main, "host": host, "workspace": workspace, "editor": editor, "scene": scene, "animation": animation_owner, "compound": joint, "pipeline": pipeline, "body": first_body, "timer": first_timer, "bodies": bodies, "mixers": mixers, "getter": getter}
static func quantile(values: Array, fraction: float) -> int:
	values.sort()
	return values[int((values.size() - 1) * fraction)]
func run() -> void:
	root.size = Vector2i(1280, 720)
	motion = InputEventMouseMotion.new()
	motion.position = Vector2(640, 360)
	motion.relative = Vector2(1, 0)
	current = make_fixture(50)
	await physics_frame
	await process_frame
	check(current.pipeline.admit_current_lease().ok, "Native-only read-only getter admission")
	var result: Dictionary = current.pipeline.try_motion(motion)
	check(result.ok and result.handled and result.full_checks == 3, "Initial plus both callback all-owner postflight, no checks skipped")
	check(not current.pipeline.consume_proof(current.pipeline.last_token), "Consumed proof cannot be reused outside same dispatch")
	var old_token: RefCounted = current.pipeline.last_token
	check(not current.pipeline.consume_proof(old_token), "Across-event proof reuse refused")
	var thread := Thread.new()
	thread.start(func(): return current.pipeline.consume_proof(old_token))
	check(thread.wait_to_finish() == false, "Off-thread token consumption refused without touching native objects")
	var baseline: Array = []
	var optimized: Array = []
	# Same current inventory/camera/settings, alternating comparable warm calls.
	for i in 120:
		var begin := Time.get_ticks_usec()
		current.host.handle_input(motion)
		baseline.append(Time.get_ticks_usec() - begin)
		begin = Time.get_ticks_usec()
		current.pipeline.try_motion(motion)
		optimized.append(Time.get_ticks_usec() - begin)
	current.editor.panel._search.grab_focus()
	check(current.pipeline.try_motion(motion).handled == false, "Original native text GUI guard retained")
	current.editor.panel._search.release_focus()
	motion.position = current.editor.panel._root.get_global_rect().get_center()
	check(current.pipeline.try_motion(motion).handled == false, "Original pointer GUI guard retained")
	motion.position = Vector2(640, 360)
	var click := InputEventMouseButton.new()
	check(current.pipeline.try_motion(click).eligible == false, "Click/mutations never use motion proof")
	current.workspace.mode = "ground"
	check(current.pipeline.try_motion(motion).eligible == false, "Ground mode never uses object proof")
	current.workspace.mode = "objects"
	accept_ready = false
	current.editor.camera._keys[KEY_W] = true
	result = current.pipeline.try_motion(motion)
	check(result.pending and result.handled and current.editor.camera._keys.is_empty() and not current.host.state().fault, "Unready owner preserves freeze and clears camera keys exactly like Workspace")
	accept_ready = true
	var alternative := Pipeline.new()
	var original_ready: Callable = current.workspace._transaction_ready
	current.workspace._transaction_ready = func(): return false
	check(not alternative.configure(current.host, current.workspace, current.compound, current.scene, current.animation).ok, "Independent Workspace ground/atomic readiness callback cannot be bypassed")
	check(not current.pipeline.try_motion(motion).eligible, "Changed readiness binding invalidates old proof admission")
	current.workspace._transaction_ready = original_ready
	current.main.free()
	current = {}
	for kind in ["scene_timer", "external_timer", "scene_control", "external_control", "external_route_child"]:
		current = make_fixture(2)
		await physics_frame
		await process_frame
		check(current.pipeline.admit_current_lease().ok, "Fresh native negative case admission")
		mutation = kind
		result = current.pipeline.try_motion(motion)
		check(not result.ok and result.handled and current.host.state().fault and current.compound.state().fault, "Callback mutation denies route and retains joint lease: " + kind)
		for item: Dictionary in current.bodies: check(item.node.freeze, "No mixed running body on callback fault")
		for item: Dictionary in current.mixers: check(not item.mixer.active, "No mixed animation resume on callback fault")
		if kind.ends_with("control"): check(current.body.get_meta("control_sequence") == 2, "New authority sequence never rewound")
		mutation = ""
		current.main.free()
		current = {}
	current = make_fixture(2, true)
	await physics_frame
	await process_frame
	var getter_calls: int = current.getter.getter_calls
	check(not current.pipeline.admit_current_lease().ok and current.getter.getter_calls == getter_calls, "Unknown script getter rejects fast proof without invoking getter")
	check(not current.pipeline.try_motion(motion).eligible, "Unadmitted getter layout falls back to original Host route")
	current.main.free()
	current = {}
	print(JSON.stringify({"suite":"synchronous-motion-proof-native", "checks":checks,"failures":failed,"baseline_p50_us":quantile(baseline,0.5),"baseline_p95_us":quantile(baseline,0.95),"candidate_p50_us":quantile(optimized,0.5),"candidate_p95_us":quantile(optimized,0.95),"candidate_full_checks":3,"native_bodies":50,"native_timers":8,"native_animation_players":8,"gpu":false,"production_wired":false,"actual_NPC_admission":false,"script_control_fields_fastproof":false}))
	quit(0 if failed == 0 else 1)
