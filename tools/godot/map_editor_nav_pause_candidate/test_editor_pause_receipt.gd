extends SceneTree
## Focused native seam test only; does not certify PreviewPopulation or K.
const Backend = preload("res://scripts/navigation/pause_backend.gd")
const Host = preload("res://scripts/navigation/preview_navigation_host.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _initialize() -> void:
	call_deferred("_run")

func _admit(_point: Vector3, _id: String, _generation: int) -> bool:
	return true

func _run() -> void:
	var owner := Node.new()
	root.add_child(owner)
	var backend: RefCounted = Backend.new(Queue.new(), Callable())
	# A synthetic in-flight bake and stale query exercise deferred callback
	# gating. This is NOT a claim of a baked current production nav map.
	backend._authority = "native-seam-test"
	backend._generation = 1; backend._version = 1; backend._epoch = 7
	backend._baking_token = 7; backend._state = "BAKING"
	var receipt: Dictionary = backend.begin_editor_pause(owner)
	check(not receipt.is_empty(), "backend_begin")
	paused = true
	var mesh := NavigationMesh.new()
	var geometry := NavigationMeshSourceGeometryData3D.new()
	var result := NavigationPathQueryResult3D.new()
	backend._baked_callback(7, mesh, geometry, Time.get_ticks_usec())
	backend._query_callback(999, 7, 0, result)
	await process_frame
	check(backend._held_completions.size() == 2, "async_completions_held")
	check(backend._state == "BAKING" and backend._baking_token == 7, "no_bake_publish_while_paused")
	check(int(backend._stats.stale_queries) == 0, "no_query_mutation_while_paused")
	check(backend.verify_editor_pause(receipt), "exact_live_receipt")
	check(not backend.can_end_editor_pause(receipt), "backend_preflight_requires_unpaused_tree")
	paused = false
	check(not backend.can_end_editor_pause({"serial":-1}), "backend_stale_receipt_refused")
	check(backend.can_end_editor_pause(receipt), "backend_unpaused_preflight")
	check(backend._held_completions.size() == 2 and backend._state == "BAKING", "backend_preflight_does_not_replay")
	check(backend.end_editor_pause(receipt), "resume_replays_completions")
	check(backend._state == "EMPTY_MAP" and backend._baking_token == 0, "bake_completion_after_resume")
	check(int(backend._stats.stale_queries) == 1, "stale_query_after_resume")
	check(not backend.end_editor_pause(receipt), "single_use_receipt")

	var second: Dictionary = backend.begin_editor_pause(owner)
	check(not second.is_empty(), "second_backend_begin")
	paused = true
	var actor: RefCounted = Queue.Owner.new("resident:test", 1)
	check(backend.request_path(actor, Vector3.ZERO, Vector3.RIGHT, Callable(self,"_admit")) == -1, "request_rejected_while_paused")
	check(not backend.verify_editor_pause(second), "foreign_write_faults_receipt")
	paused = false
	backend.dispose()
	check(not backend.end_editor_pause(second), "disposed_owner_receipt_invalid")

	# Queue is a real shared navigation owner. Read-only preflight must not
	# advance its clock or release its gate before the backend replays.
	var queue: RefCounted = Queue.new()
	var queue_receipt: Dictionary = queue.begin_editor_pause(owner)
	check(not queue_receipt.is_empty(), "queue_begin")
	paused = true
	check(queue.verify_editor_pause(queue_receipt), "queue_exact_live_receipt")
	check(not queue.can_end_editor_pause(queue_receipt), "queue_preflight_requires_unpaused_tree")
	paused = false
	var clock_before: int = queue._last_clock
	check(not queue.can_end_editor_pause({"serial":-1}), "queue_stale_receipt_refused")
	check(queue.can_end_editor_pause(queue_receipt), "queue_unpaused_preflight")
	check(queue._editor_pause_active and queue._last_clock == clock_before, "queue_preflight_no_release_or_clock_step")
	check(queue.end_editor_pause(queue_receipt), "queue_end")
	check(not queue.end_editor_pause(queue_receipt), "queue_single_use_receipt")
	check(queue.dispose(), "queue_dispose_after_release")
	var nonempty_queue: RefCounted = Queue.new()
	var queue_actor: RefCounted = Queue.Owner.new("resident:queued", 1)
	nonempty_queue._queue[queue_actor] = 1
	check(nonempty_queue.begin_editor_pause(owner).is_empty(), "nonempty_queue_refused")
	var drift_queue: RefCounted = Queue.new()
	var drift_receipt: Dictionary = drift_queue.begin_editor_pause(owner)
	check(not drift_receipt.is_empty(), "drift_queue_begin")
	paused = true
	drift_queue._stats.admitted += 1 # Deliberate direct-state mutation, not a public callback.
	check(not drift_queue.verify_editor_pause(drift_receipt), "queue_snapshot_drift_detected")
	paused = false
	check(not drift_queue.can_end_editor_pause(drift_receipt) and drift_queue._editor_pause_active, "drift_preflight_retains_lease")
	check(not drift_queue.end_editor_pause(drift_receipt), "drift_queue_cannot_release")
	check(drift_queue.dispose(), "drift_queue_terminal_dispose")
	var fault_queue: RefCounted = Queue.new()
	var fault_receipt: Dictionary = fault_queue.begin_editor_pause(owner)
	check(not fault_receipt.is_empty(), "fault_queue_begin")
	paused = true
	check(not fault_queue.reserve(1, queue_actor), "queue_reserve_rejected_while_paused")
	check(not fault_queue.verify_editor_pause(fault_receipt), "queue_foreign_write_faults_receipt")
	paused = false
	check(not fault_queue.can_end_editor_pause(fault_receipt), "fault_queue_cannot_preflight")
	check(not fault_queue.end_editor_pause(fault_receipt), "fault_queue_cannot_release")
	check(fault_queue.dispose(), "fault_queue_terminal_dispose")

	# The staged host rejects door/request/step at the first line, before its
	# normal scene or geometry validation. It is not yet wired to population.
	var host: RefCounted = Host.new()
	host._editor_pause_active = true
	check(not host.door_transition_started("public", 1.0), "door_rejected")
	check(host._editor_pause_fault, "door_faults_receipt")
	host._editor_pause_fault = false
	check(host.request(actor, null, Vector3.ZERO, Callable(self,"_admit")) == -1, "host_request_rejected")
	host._editor_pause_fault = false
	check(host.step(1, 0.016, 2.0, 9.8).get("status") == "EDITOR_PAUSED", "host_step_rejected")
	host._editor_pause_fault = false
	host.cancel(1)
	check(host._editor_pause_fault, "host_cancel_rejected")
	host._editor_pause_active = false

	var life_owner := Node.new()
	root.add_child(life_owner)
	var life_backend: RefCounted = Backend.new(Queue.new(), Callable())
	life_backend._authority = "native-life-test"
	life_backend._generation = 1; life_backend._version = 1; life_backend._epoch = 2
	life_backend._jobs[1] = {"status":"PENDING"}
	check(life_backend.begin_editor_pause(life_owner).is_empty(), "active_job_ledger_refused")
	life_backend._jobs.clear()
	var life_receipt: Dictionary = life_backend.begin_editor_pause(life_owner)
	check(not life_receipt.is_empty(), "life_begin")
	paused = true
	life_owner.queue_free()
	check(not life_backend.verify_editor_pause(life_receipt), "queued_owner_fails_verify")
	paused = false
	check(not life_backend.end_editor_pause(life_receipt), "queued_owner_cannot_replay")
	life_backend.dispose()
	owner.queue_free()
	await process_frame
	print(JSON.stringify({"suite":"navigation-editor-pause-backend-seam","checks":checks,"failures":failures,"population_ready":false,"gpu":false}))
	quit(0 if failures.is_empty() else 1)
