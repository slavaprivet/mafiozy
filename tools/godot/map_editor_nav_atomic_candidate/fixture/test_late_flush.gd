extends SceneTree
const Backend = preload("res://scripts/navigation/atomic_backend.gd")
const FaultBackend = preload("res://fault_backend.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _initialize() -> void:
	call_deferred("_run")

func _arm(backend: RefCounted, owner: Node, epoch: int, bake_token: int) -> Dictionary:
	backend._authority = "native-atomic-fixture"
	backend._generation = 1; backend._version = 1
	backend._epoch = epoch; backend._baking_token = bake_token
	backend._state = "BAKING"
	var receipt: Dictionary = backend.begin_editor_pause(owner)
	check(not receipt.is_empty(), "begin")
	paused = true
	var ticket: Dictionary = backend.prepare_editor_resume_atomic(receipt)
	check(not ticket.is_empty(), "prepare")
	check(not backend.commit_editor_resume_atomic(ticket).is_empty(), "commit")
	check(backend.finalize_editor_resume_atomic(ticket), "finalize")
	paused = false
	return ticket

func _run() -> void:
	var owner := Node.new()
	root.add_child(owner)
	var normal: RefCounted = Backend.new(Queue.new(), Callable())
	var ticket := _arm(normal, owner, 7, 7)
	var mesh := NavigationMesh.new()
	var geometry := NavigationMeshSourceGeometryData3D.new()
	var result := NavigationPathQueryResult3D.new()
	normal._finish_bake(7, mesh, geometry, Time.get_ticks_usec())
	normal._finish_query(999, 7, 0, result)
	check(normal._held_completions.size() == 2, "late_completions_held")
	check(normal._state == "BAKING", "late_bake_not_applied")
	check(normal.begin_editor_pause(owner).is_empty(), "second_pause_refused")
	check(normal.flush_editor_resume_atomic(ticket), "normal_flush")
	check(normal._state == "EMPTY_MAP", "normal_bake_effect")
	check(int(normal._stats.stale_queries) == 1, "normal_query_effect")
	check(not normal.flush_editor_resume_atomic(ticket), "single_use_flush")
	normal.dispose()

	var faulted: RefCounted = FaultBackend.new(Queue.new(), Callable())
	var fault_ticket := _arm(faulted, owner, 8, 7)
	faulted._finish_bake(7, mesh, geometry, Time.get_ticks_usec())
	faulted._finish_query(999, 8, 0, result)
	check(not faulted.flush_editor_resume_atomic(fault_ticket), "fault_after_first_replay")
	check(faulted.callback_effects == 1, "first_callback_side_effect")
	check(faulted._atomic_replayed == 1, "exactly_one_replayed")
	check(faulted._editor_fault and faulted._atomic_flush_pending, "fault_retains_guard")
	check(faulted._held_completions.size() == 2, "unprocessed_and_reentrant_tail_held")
	check(int(faulted._stats.stale_queries) == 0, "tail_not_applied")
	check(not faulted.flush_editor_resume_atomic(fault_ticket), "partial_retry_refused")
	check(faulted.callback_effects == 1 and faulted._held_completions.size() == 2, "retry_has_no_effect")
	faulted.dispose()
	owner.queue_free()
	print(JSON.stringify({"suite":"atomic-nav-late-flush","checks":checks,"failures":failures,"gpu":false}))
	quit(0 if failures.is_empty() else 1)
