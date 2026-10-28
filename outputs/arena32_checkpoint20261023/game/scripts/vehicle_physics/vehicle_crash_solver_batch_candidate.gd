extends RefCounted
## Candidate-only WorkerThreadPool executor for independent native crash solver
## states. Binding transfers exclusive mutation authority to this executor until
## reset/retire. Workers use no SceneTree, Node, Resource or Rendering/Physics
## server API. One immutable slot index maps to one solver and one result holder.

const MAX_STATES := 72
const DEFAULT_CAPACITY := 16
const ALLOWED_WORKERS := [1, 2, 4, 8]
static var _solver_claims := {}

class JobSlot extends RefCounted:
	var solver: RefCounted
	var vehicle_id := ""
	var life_generation := 0
	var delta := 0.0
	var speed := 0.0
	var throttle := 0.0
	var physics_tick := -1

class ResultHolder extends RefCounted:
	var completed := false
	var step_result: Dictionary = {}

var _configured := false
var _retired := false
var _poisoned := false
var _session_id := ""
var _capacity := DEFAULT_CAPACITY
var _worker_limit := 4
var _slots: Array = []
var _holders: Array = []
var _claimed_solver_ids: Array[int] = []
var _in_flight := false
var _in_flight_task_id := -1
var _join_claimed := false
var _guard := Mutex.new()

func configure(session_id_value: Variant, capacity_value := DEFAULT_CAPACITY,
		worker_limit_value := 4) -> bool:
	if not Thread.is_main_thread() or _configured or not session_id_value is String \
			or (session_id_value as String).is_empty() \
			or not capacity_value is int or int(capacity_value) < 1 \
			or int(capacity_value) > MAX_STATES \
			or not worker_limit_value is int \
			or not ALLOWED_WORKERS.has(int(worker_limit_value)):
		return false
	_session_id = session_id_value
	_capacity = int(capacity_value)
	_worker_limit = int(worker_limit_value)
	_configured = true
	return true

func bind_states(rows_value: Variant) -> bool:
	if not Thread.is_main_thread() or not _configured or _retired or _poisoned or _in_flight \
			or not rows_value is Array:
		return false
	var rows: Array = rows_value
	if rows.is_empty() or rows.size() > _capacity:
		return false
	var next_slots: Array = []
	var next_holders: Array = []
	next_slots.resize(rows.size())
	next_holders.resize(rows.size())
	var solver_ids := {}
	var identity_pairs := {}
	var next_claims: Array[int] = []
	for index in rows.size():
		var row_value: Variant = rows[index]
		if not row_value is Dictionary:
			return false
		var row: Dictionary = row_value
		if not row.get("solver") is RefCounted or not row.get("vehicle_id") is String \
				or (row.vehicle_id as String).is_empty() \
				or not row.get("life_generation") is int \
				or int(row.life_generation) < 1:
			return false
		var solver: RefCounted = row.solver
		if not (solver is NativeVehicleCrashSolver) \
				or not solver.has_method("mechanical_snapshot") \
				or not solver.has_method("runtime_contract") \
				or not solver.has_method("step") \
				or not solver.has_method("deformation_snapshot_native"):
			return false
		var instance_id := solver.get_instance_id()
		var identity_key := JSON.stringify([row.vehicle_id, int(row.life_generation)])
		var claim_owner: int = int(_solver_claims.get(instance_id, 0))
		if solver_ids.has(instance_id) or identity_pairs.has(identity_key) \
				or claim_owner != 0 and claim_owner != get_instance_id():
			return false
		var mechanical: Dictionary = solver.mechanical_snapshot()
		var runtime: Dictionary = solver.runtime_contract()
		if mechanical.is_empty() or mechanical.get("vehicle_id") != row.vehicle_id \
				or mechanical.get("life_generation") != row.life_generation \
				or runtime.get("configured") != true \
				or not runtime.get("last_step_physics_tick") is int:
			return false
		solver_ids[instance_id] = true
		identity_pairs[identity_key] = true
		next_claims.append(instance_id)
		var slot := JobSlot.new()
		slot.solver = solver
		slot.vehicle_id = row.vehicle_id
		slot.life_generation = row.life_generation
		next_slots[index] = slot
		next_holders[index] = ResultHolder.new()
	# Fixed arrays are replaced only on the main consumer before any worker starts.
	_release_claims()
	for instance_id: int in next_claims:
		_solver_claims[instance_id] = get_instance_id()
	_claimed_solver_ids = next_claims
	_slots = next_slots
	_holders = next_holders
	return true

func begin_step_batch(delta_value: Variant, speed_value: Variant,
		throttle_value: Variant, physics_tick_value: Variant) -> Dictionary:
	if not Thread.is_main_thread():
		return {"accepted": false, "reason": "main-thread-required"}
	_guard.lock()
	var valid := _configured and not _retired and not _poisoned and not _in_flight \
		and not _slots.is_empty() and _finite_number(delta_value) \
		and float(delta_value) >= 0.0 and _finite_number(speed_value) \
		and _finite_number(throttle_value) and physics_tick_value is int \
		and int(physics_tick_value) >= 0
	if valid:
		for slot_value: Variant in _slots:
			var slot: JobSlot = slot_value
			if int(physics_tick_value) <= int(slot.solver.runtime_contract().last_step_physics_tick):
				valid = false
				break
	if not valid:
		_guard.unlock()
		return {"accepted": false, "reason": "invalid-or-busy"}
	for index in _slots.size():
		var slot: JobSlot = _slots[index]
		var holder: ResultHolder = _holders[index]
		slot.delta = float(delta_value)
		slot.speed = float(speed_value)
		slot.throttle = float(throttle_value)
		slot.physics_tick = int(physics_tick_value)
		holder.completed = false
		holder.step_result = {}
	_in_flight = true
	_join_claimed = false
	_in_flight_task_id = WorkerThreadPool.add_group_task(_run_job, _slots.size(),
		mini(_worker_limit, _slots.size()), false, "native vehicle crash solver batch")
	var task_id := _in_flight_task_id
	_guard.unlock()
	return {"accepted": true, "task_id": task_id, "states": _slots.size(),
		"workers": mini(_worker_limit, _slots.size())}

func finish_step_batch(task_id_value: Variant) -> Dictionary:
	if not Thread.is_main_thread():
		return {"accepted": false, "reason": "main-thread-required"}
	_guard.lock()
	if not task_id_value is int or not _in_flight \
			or int(task_id_value) != _in_flight_task_id or _join_claimed:
		_guard.unlock()
		return {"accepted": false, "reason": "wrong-or-consumed-task"}
	_join_claimed = true
	var task_id := _in_flight_task_id
	_guard.unlock()
	WorkerThreadPool.wait_for_group_task_completion(task_id)
	var all_accepted := true
	for holder_value: Variant in _holders:
		var holder: ResultHolder = holder_value
		if not holder.completed or holder.step_result.get("accepted") != true:
			all_accepted = false
			break
	if not all_accepted:
		_guard.lock()
		_poisoned = true
		_in_flight = false
		_in_flight_task_id = -1
		_join_claimed = false
		_guard.unlock()
		return {"accepted": false, "reason": "worker-rejected-session-poisoned",
			"poisoned": true}
	# Worker task is fully joined. Snapshot copying and publication happen only now
	# on the main consumer; workers never touch a shared result array.
	var published: Array = []
	published.resize(_slots.size())
	for index in _slots.size():
		var slot: JobSlot = _slots[index]
		var holder: ResultHolder = _holders[index]
		published[index] = {"vehicle_id": slot.vehicle_id,
			"life_generation": slot.life_generation,
			"step": holder.step_result.duplicate(true),
			"mechanical": slot.solver.mechanical_snapshot(),
			"deformation": slot.solver.deformation_snapshot_native()}
	_guard.lock()
	_in_flight = false
	_in_flight_task_id = -1
	_join_claimed = false
	_guard.unlock()
	return {"accepted": true, "session_id": _session_id, "states": published}

func step_batch(delta_value: Variant, speed_value: Variant,
		throttle_value: Variant, physics_tick_value: Variant) -> Dictionary:
	if not Thread.is_main_thread():
		return {"accepted": false, "reason": "main-thread-required"}
	var begun := begin_step_batch(delta_value, speed_value, throttle_value, physics_tick_value)
	if begun.get("accepted") != true:
		return begun
	return finish_step_batch(begun.task_id)

func reset_session_wait(next_session_id_value: Variant) -> bool:
	if not Thread.is_main_thread() or not next_session_id_value is String \
			or (next_session_id_value as String).is_empty():
		return false
	if _in_flight:
		if _join_claimed:
			return false
		var discarded := finish_step_batch(_in_flight_task_id)
		if discarded.get("accepted") != true and not discarded.get("poisoned", false):
			return false
	_slots = []
	_holders = []
	_release_claims()
	_session_id = next_session_id_value
	_poisoned = false
	return true

func retire_wait() -> bool:
	if not Thread.is_main_thread():
		return false
	if _retired:
		return true
	if _in_flight:
		if _join_claimed:
			return false
		var discarded := finish_step_batch(_in_flight_task_id)
		if discarded.get("accepted") != true and not discarded.get("poisoned", false):
			return false
	_slots = []
	_holders = []
	_release_claims()
	_poisoned = false
	_retired = true
	return true

func contract() -> Dictionary:
	if not Thread.is_main_thread():
		return {}
	return {"configured": _configured, "retired": _retired, "poisoned": _poisoned,
		"session_id": _session_id, "capacity": _capacity,
		"worker_limit": _worker_limit, "bound_states": _slots.size(),
		"in_flight": _in_flight, "in_flight_task_id": _in_flight_task_id,
		"exclusive_solver_mutation_required": true, "max_states": MAX_STATES,
		"explicit_retire_required_to_release_claims": true,
		"workers_touch_scene_or_servers": false}

func _run_job(index: int) -> void:
	# _slots/_holders lengths and references are immutable until the group joins.
	# Every index owns a distinct solver and holder, so no worker writes shared state.
	var slot: JobSlot = _slots[index]
	var holder: ResultHolder = _holders[index]
	holder.step_result = slot.solver.step(slot.delta, slot.speed, slot.throttle,
		slot.physics_tick)
	holder.completed = true

static func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func _release_claims() -> void:
	# Main-thread-only. A forgotten retire intentionally leaves a fail-closed claim.
	for instance_id: int in _claimed_solver_ids:
		if int(_solver_claims.get(instance_id, 0)) == get_instance_id():
			_solver_claims.erase(instance_id)
	_claimed_solver_ids.clear()
