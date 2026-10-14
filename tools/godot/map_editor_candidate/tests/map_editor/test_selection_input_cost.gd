extends SceneTree
const SceneOwner = preload("res://scripts/map_editor/scene_pause_owner_v2.gd")
const AnimationOwner = preload("res://scripts/map_editor/animation_pause_adapter_v2.gd")
const JointOwner = preload("res://scripts/map_editor/compound_pause_owner.gd")
const Host = preload("res://scripts/map_editor/editor_host_adapter.gd")
const Workspace = preload("res://scripts/map_editor/editor_workspace.gd")
const Controller = preload("res://scripts/map_editor/editor_controller.gd")
class CountingScene extends "res://scripts/map_editor/scene_pause_owner_v2.gd":
	var checks := 0
	func preflight_restore(handle: Variant) -> Dictionary:
		checks += 1
		return super.preflight_restore(handle)
	func verify_pause(receipt: Dictionary) -> bool:
		checks += 1
		return super.verify_pause(receipt)
class CountingAnimation extends "res://scripts/map_editor/animation_pause_adapter_v2.gd":
	var checks := 0
	func verify() -> bool:
		checks += 1
		return super.verify()
class CountingRegistry extends "res://scripts/map_editor/object_registry.gd":
	var pick_calls := 0
	var bounds_calls := 0
	func pick(origin: Vector3, direction: Vector3, distance: float = 10000.0) -> String:
		pick_calls += 1
		return super.pick(origin, direction, distance)
	func world_bounds(id: String) -> Variant:
		bounds_calls += 1
		return super.world_bounds(id)
var checks := 0
var failed := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
static func quantile(values: Array, fraction: float) -> int:
	values.sort()
	return values[int((values.size() - 1) * fraction)]
func run() -> void:
	root.size = Vector2i(1280, 720)
	var main := Node3D.new()
	root.add_child(main)
	var node_inventory: Array = [{"node": main, "stop_input": false}]
	var body_inventory: Array = []
	var animation_inventory: Array = []
	for i in 50:
		var body := RigidBody3D.new()
		body.gravity_scale = 0
		body.position = Vector3(i * 3, 0, 100)
		main.add_child(body)
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		body.add_child(shape)
		body.set_meta("generation", i)
		body_inventory.append({"node": body, "identity": {"generation": i}})
	for i in 8:
		var timer := Timer.new()
		main.add_child(timer)
		timer.start(30)
		node_inventory.append({"node": timer})
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
		animation_inventory.append({"mixer": player, "pose_targets": [{"node": pose, "properties": ["position"]}]})
	await physics_frame
	await process_frame
	var scene := CountingScene.new()
	check(scene.configure(main, node_inventory, body_inventory, {"admit_pause": func(_r): return true, "validate_resume": func(_r, _o, _g): return true, "transaction_ready": func(_r): return true, "ground_patch": func(): return {}}).ok, "Native fixture explicit50body/8timer inventory")
	var animation_owner := CountingAnimation.new()
	check(animation_owner.configure(main, animation_inventory).ok, "Native fixture explicit8AnimationPlayer inventory (not actual NPC admission)")
	var joint := JointOwner.new()
	check(joint.configure(scene, animation_owner, func(_phase, _details): return true).ok, "Isolated native fixture owner admission; not gameplay/server/nav")
	var host := Host.new()
	check(host.mount(main, joint.callbacks()).ok, "Real HostAdapter mounted")
	var registry := CountingRegistry.new()
	var visual := MeshInstance3D.new()
	visual.mesh = BoxMesh.new()
	main.add_child(visual)
	check(registry.register_object("native-fixture-box", visual, {"kind": "building", "source": {"fixture": true}}).ok, "Actual native object registered")
	var game := Camera3D.new()
	game.position = Vector3(0, 0, 10)
	main.add_child(game)
	game.make_current()
	var editor := Controller.new()
	main.add_child(editor)
	check(editor.setup(registry, registry.source_document("native-input-fixture"), game, host.enter, host.leave).ok, "Actual Controller configured")
	# Object-mode method fixture only. Ground setup is intentionally NOT claimed:
	# these dependencies are not consulted by the object motion branch.
	var workspace := Workspace.new()
	main.add_child(workspace)
	workspace.editor = editor
	workspace._transaction_ready = host.transaction_ready
	check(host.bind_workspace(workspace).ok, "Actual Workspace object-mode route bound")
	check(editor.enter_editor().ok, "Real compound pause before input")
	await physics_frame
	await process_frame
	check(host.transaction_ready(), "Actual frame barrier and fully checked fixture lease")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(640, 360)
	motion.relative = Vector2(1, 0)
	var scene_before := scene.checks
	var animation_before := animation_owner.checks
	var begin := Time.get_ticks_usec()
	check(host.handle_input(motion), "Inclusive real Host→Workspace→Controller input")
	var first_us := Time.get_ticks_usec() - begin
	var scene_per_motion := scene.checks - scene_before
	var animation_per_motion := animation_owner.checks - animation_before
	var times: Array = []
	for i in 500:
		begin = Time.get_ticks_usec()
		host.handle_input(motion)
		times.append(Time.get_ticks_usec() - begin)
	check(registry.pick_calls == 0, "Mousemotion never calls registry.pick even with current lease checks")
	check(registry.bounds_calls == 1, "Only initial empty selection world_bounds call; no mousemotion bounds scans")
	editor.panel._search.grab_focus()
	check(not host.handle_input(motion) and registry.pick_calls == 0, "Text GUI guard remains exact after full lease verification")
	editor.panel._search.release_focus()
	motion.position = editor.panel._root.get_global_rect().get_center()
	check(not host.handle_input(motion) and registry.pick_calls == 0, "Pointer GUI guard remains exact")
	check(scene_per_motion == 6 and animation_per_motion == 4, "Inclusive six scene/four animation verifications per object motion")
	var timer: Timer = node_inventory[1].node
	timer.wait_time += 1
	check(host.handle_input(motion) and host.state().fault and registry.pick_calls == 0, "Mutated real timer denies lease/input; no cachedtrue bypass")
	for item: Dictionary in body_inventory: check(item.node.freeze, "Rejected stale lease keeps native bodies stopped")
	for item: Dictionary in animation_inventory: check(not item.mixer.active, "Rejected stale lease keeps native mixers stopped")
	print(JSON.stringify({"suite":"inclusive-native-input-route", "checks":checks,"failures":failed,"motion_p50_us":quantile(times,0.5),"motion_p95_us":quantile(times,0.95),"first_motion_us":first_us,"scene_checks_per_motion":scene_per_motion,"animation_checks_per_motion":animation_per_motion,"native_bodies":50,"native_timers":8,"native_animation_players":8,"actual_NPC_admission":false,"full_ground_workspace_setup":false,"pick_calls":registry.pick_calls,"gpu":false,"production_wired":false}))
	main.free()
	quit(0 if failed == 0 else 1)
