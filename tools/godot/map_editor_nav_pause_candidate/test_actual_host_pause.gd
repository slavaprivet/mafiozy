extends SceneTree
## Later opt-in actual-scene CPU fixture. Do not equate this with residents K.
const Host = preload("res://scripts/navigation/preview_navigation_host.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "actual_scene_loaded")
	if scene == null: _finish(); return
	var main: Node3D = scene.instantiate()
	main.preview_residents_enabled = false # isolate nav host; no false default-K claim
	root.add_child(main)
	for i in 180:
		if main.preview_ready: break
		await process_frame
	check(main.preview_ready, "actual_scene_ready")
	if not main.preview_ready:
		main.queue_free(); _finish(); return
	var interior: Node3D = main._printshop
	check(is_instance_valid(interior) and interior.ready_for_use, "real_printshop_ready")
	var host: RefCounted = Host.new()
	var attached: bool = host.attach_existing(main, interior, main._block, main._printshop_data, Queue.new(), "actual-scene-pause-test", 1, 1)
	check(attached, "real_navigation_host_attached")
	if attached:
		var receipt: Dictionary = host.begin_editor_pause(main)
		check(not receipt.is_empty(), "real_host_begin")
		if not receipt.is_empty():
			paused = true
			check(host.verify_editor_pause(receipt), "real_host_pause_verified")
			await process_frame
			check(host.verify_editor_pause(receipt), "real_host_remains_verified")
			paused = false
			check(host.can_end_editor_pause(receipt), "real_host_unpaused_preflight")
			check(host._editor_pause_active and host._queue._editor_pause_active and host._backend._editor_paused, "preflight_keeps_all_three_leases")
			check(host.end_editor_pause(receipt), "real_host_resumed")
		var changed: Dictionary = host.begin_editor_pause(main)
		check(not changed.is_empty(), "target_negative_begin")
		if not changed.is_empty():
			paused = true
			var door: Dictionary = interior._doors["public"]
			door.target = 1.0 if float(door.target) == 0.0 else 0.0
			check(not host.verify_editor_pause(changed), "target_flip_invalidates_receipt")
			paused = false
			check(not host.can_end_editor_pause(changed), "target_flip_blocks_preflight")
			check(not host.end_editor_pause(changed), "changed_target_blocks_replay")
			check(host._queue._editor_pause_active and host._backend._editor_paused, "failed_preflight_keeps_queue_and_backend_held")
		host.dispose()
	main.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if paused: paused = false
	print(JSON.stringify({"suite":"actual-scene-navigation-host-pause","checks":checks,"failures":failures,"residents_enabled":false,"default_k_ready":false,"gpu":false}))
	quit(0 if failures.is_empty() else 1)
