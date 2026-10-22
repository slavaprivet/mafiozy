extends "res://scripts/vehicle_physics/vehicle_crash_solver_batch_candidate.gd"
## Additive candidate for heterogeneous per-state drive/thermal inputs. Every
## row is validated and copied before submit, so malformed input cannot partially
## advance a fleet. The inherited worker/lifecycle/claim contract is unchanged.

func begin_step_batch_rows(input_rows_value: Variant) -> Dictionary:
	var preparation := _prepare_input_rows(input_rows_value)
	if preparation.get("accepted") != true:
		return preparation
	var prepared: Array = preparation.rows
	_guard.lock()
	# Public APIs are main-thread-only, but retain the inherited atomic guard.
	if _in_flight or _retired or _poisoned:
		_guard.unlock()
		return {"accepted": false, "reason": "invalid-or-busy"}
	for index in _slots.size():
		var slot: JobSlot = _slots[index]
		var holder: ResultHolder = _holders[index]
		var row: Dictionary = prepared[index]
		slot.delta = row.delta
		slot.speed = row.speed
		slot.throttle = row.throttle
		slot.physics_tick = row.physics_tick
		holder.completed = false
		holder.step_result = {}
	_in_flight = true
	_join_claimed = false
	_in_flight_task_id = WorkerThreadPool.add_group_task(_run_job, _slots.size(),
		mini(_worker_limit, _slots.size()), false,
		"native vehicle crash heterogeneous batch")
	var task_id := _in_flight_task_id
	_guard.unlock()
	return {"accepted": true, "task_id": task_id, "states": _slots.size(),
		"workers": mini(_worker_limit, _slots.size()), "fast_path": false}

func step_batch_rows(input_rows_value: Variant) -> Dictionary:
	var preparation := _prepare_input_rows(input_rows_value)
	if preparation.get("accepted") != true:
		return preparation
	var prepared: Array = preparation.rows
	if _slots.size() != 1:
		var begun := begin_step_batch_rows(prepared)
		if begun.get("accepted") != true:
			return begun
		var result := finish_step_batch(begun.task_id)
		result.fast_path = false
		return result
	# Exact single-state source path: same solver.step and same joined publication
	# schema, without creating a worker group whose scheduling cost exceeds work.
	var slot: JobSlot = _slots[0]
	var row: Dictionary = prepared[0]
	var step_result: Dictionary = slot.solver.step(row.delta, row.speed, row.throttle,
		row.physics_tick)
	if step_result.get("accepted") != true:
		_poisoned = true
		return {"accepted": false, "reason": "single-state-rejected-session-poisoned",
			"poisoned": true}
	var published := [{"vehicle_id": slot.vehicle_id,
		"life_generation": slot.life_generation, "step": step_result.duplicate(true),
		"mechanical": slot.solver.mechanical_snapshot(),
		"deformation": slot.solver.deformation_snapshot_native()}]
	return {"accepted": true, "session_id": _session_id, "states": published,
		"fast_path": true}

func input_contract() -> Dictionary:
	if not Thread.is_main_thread():
		return {}
	return {"per_state_rows": true, "required_fields": ["vehicle_id",
		"life_generation", "delta", "speed", "throttle", "physics_tick"],
		"full_preflight_before_submit": true, "copied_scalar_inputs": true,
		"single_state_serial_fast_path": true}

func _prepare_input_rows(input_rows_value: Variant) -> Dictionary:
	if not Thread.is_main_thread():
		return {"accepted": false, "reason": "main-thread-required"}
	if not _configured or _retired or _poisoned or _in_flight \
			or not input_rows_value is Array or _slots.is_empty():
		return {"accepted": false, "reason": "invalid-or-busy"}
	var input_rows: Array = input_rows_value
	if input_rows.size() != _slots.size():
		return {"accepted": false, "reason": "complete-state-set-required"}
	var by_identity := {}
	for row_value: Variant in input_rows:
		if not row_value is Dictionary:
			return {"accepted": false, "reason": "invalid-row"}
		var row: Dictionary = row_value
		if not row.get("vehicle_id") is String or (row.vehicle_id as String).is_empty() \
				or not row.get("life_generation") is int \
				or int(row.life_generation) < 1 or not row.get("physics_tick") is int \
				or int(row.physics_tick) < 0 or not _finite_number(row.get("delta")) \
				or float(row.delta) < 0.0 or not _finite_number(row.get("speed")) \
				or not _finite_number(row.get("throttle")):
			return {"accepted": false, "reason": "invalid-row"}
		var key := JSON.stringify([row.vehicle_id, int(row.life_generation)])
		if by_identity.has(key):
			return {"accepted": false, "reason": "duplicate-row-identity"}
		# Copy only value scalars; caller dictionaries are never retained by a job.
		by_identity[key] = {"vehicle_id": String(row.vehicle_id),
			"life_generation": int(row.life_generation), "delta": float(row.delta),
			"speed": float(row.speed), "throttle": float(row.throttle),
			"physics_tick": int(row.physics_tick)}
	var prepared: Array = []
	prepared.resize(_slots.size())
	for index in _slots.size():
		var slot: JobSlot = _slots[index]
		var key := JSON.stringify([slot.vehicle_id, slot.life_generation])
		if not by_identity.has(key):
			return {"accepted": false, "reason": "unknown-or-missing-state"}
		var row: Dictionary = by_identity[key]
		if int(row.physics_tick) <= int(slot.solver.runtime_contract().last_step_physics_tick):
			return {"accepted": false, "reason": "stale-state-tick"}
		prepared[index] = row
	return {"accepted": true, "rows": prepared}
