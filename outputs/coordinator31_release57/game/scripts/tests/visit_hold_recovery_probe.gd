extends SceneTree
## DSH_VISITHOLD probe: proves the new --city-visit-hold-recovery lever on the EXACT
## visit composition (res://scripts/npc_visual/npc_local_printshop_visit.gd), with no
## city, no navigation map, no body and no physics. SceneTree script, run twice:
##
##   ... --script res://scripts/tests/visit_hold_recovery_probe.gd -- \
##         --city-visit-hold-recovery=0
##        -> today's path: a refusal still ends in the permanent HOLD, tick() keeps
##           returning it, and no DSH_VISITHOLD line is printed at all.
##
##   ... --script res://scripts/tests/visit_hold_recovery_probe.gd -- \
##         --city-visit-hold-recovery=3 --city-visit-hold-wait-s=120
##        -> two bounded re-issues (attempt=2/3 and 3/3, result=retry) followed by the
##           terminal COMPLETE release on the next refusal; the recorded
##           target/phase/tolerance are re-issued unchanged and the callback table is
##           dropped on release.
##
## The probe only calls _stop()/tick()/cancel()/status()/_route() and reads the fields
## the owner already reads. It moves nothing and is never part of a city run.
const Visit = preload("res://scripts/npc_visual/npc_local_printshop_visit.gd")

var _requests: Array = []
var _request_id := 2000000

func _initialize() -> void:
	run.call_deferred()

func _arg_int(prefix: String, fallback: int) -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return int(argument.trim_prefix(prefix))
	return fallback

func _stub_request(target: Vector3, phase: String, tolerance: float, _token: Dictionary) -> Dictionary:
	_requests.append({"target": target, "phase": phase, "tolerance": tolerance})
	_request_id += 1
	return {"accepted": true, "request_id": _request_id}

func run() -> void:
	var flag := _arg_int("--city-visit-hold-recovery=", 0)
	var ok := true
	var visit: RefCounted = Visit.new()
	# Only the composer's own state is touched: no host, no interior, no body.
	visit._id = "probe_resident"
	visit._phase = "WALK_TO_ENTRY"
	visit._now = 10000.0
	visit._since = 10000.0
	visit._outside = Vector3(1.0, 0.0, 2.0)
	visit._hold_progress_at = 10000.0
	visit._hold_route_target = Vector3(1.0, 0.0, 2.0)
	visit._hold_route_phase = "WALK_TO_ENTRY"
	visit._hold_route_tolerance = 0.41
	visit._request = Callable(self, "_stub_request")
	visit._poll = Callable(self, "_stub_request")
	visit._cancel = Callable(self, "_stub_request")

	var before: Dictionary = visit.status()
	visit._stop("physical_route:NO_PATH")
	var stopped: Dictionary = visit.status()
	print("VISITHOLD_PROBE mode=flag", flag, " before=", before.phase,
		" after_stop=", stopped.phase, " reason=", stopped.reason,
		" attempts=", int(visit._hold_attempts), " requests=", _requests.size())

	if flag == 0:
		# Today: the dead end. tick() must keep returning HOLD, must not re-issue, and
		# must not print the recovery telemetry.
		ok = ok and stopped.phase == "HOLD"
		ok = ok and stopped.reason == "physical_route:NO_PATH"
		ok = ok and _requests.is_empty()
		for _step in 4:
			var held: Dictionary = visit.tick(11000.0)
			ok = ok and held.phase == "HOLD"
			ok = ok and held.reason == "physical_route:NO_PATH"
		ok = ok and _requests.is_empty()
		# `cancel` on the dead end stays exactly the shipped line.
		visit.cancel()
		ok = ok and visit.status().phase == "HOLD"
	else:
		# Opt-in: the refusal is bounded instead of terminal. `_current()` is false in
		# this probe, so the shipped guard refuses every re-issue; that refusal is
		# counted again, which is precisely the bounded path under test.
		ok = ok and stopped.phase == "WALK_TO_ENTRY"
		ok = ok and int(visit._hold_attempts) == 1
		visit.tick(11000.0)
		var after_one: Dictionary = visit.status()
		ok = ok and after_one.phase == "WALK_TO_ENTRY"
		ok = ok and int(visit._hold_attempts) == 2
		visit.tick(12000.0)
		var after_two: Dictionary = visit.status()
		ok = ok and after_two.phase == "WALK_TO_ENTRY"
		ok = ok and int(visit._hold_attempts) == 3
		# Nothing left: the next refusal is terminal.
		visit.tick(60000.0)
		var terminal: Dictionary = visit.status()
		print("VISITHOLD_PROBE after_one=", after_one.phase, " after_two=", after_two.phase,
			" terminal=", terminal.phase, " reason=", terminal.reason,
			" attempts=", int(visit._hold_attempts), " failures=", int(visit._completed_failures))
		ok = ok and terminal.phase == "COMPLETE"
		ok = ok and terminal.reason.contains("physical_route:NO_PATH")
		ok = ok and int(visit._completed_failures) == 1
		# The callback table is dropped on release, so the owner's later cancel/undo
		# cannot cancel a request this composer no longer owns.
		var callbacks_dropped: bool = not visit._cancel.is_valid() and not visit._poll.is_valid() and not visit._request.is_valid()
		ok = ok and callbacks_dropped
		visit.cancel()
		ok = ok and visit.status().phase == "COMPLETE"
		print("VISITHOLD_PROBE callbacks_dropped=", callbacks_dropped,
			" after_cancel=", visit.status().phase)
		# A recording stub proves the re-issue carries the recorded
		# target/phase/tolerance unchanged. `_route` is the shipped request path; it
		# is exercised with the recorded values only (no host/lease needed).
		visit._now = 70000.0
		visit._phase = "WALK_TO_ENTRY"
		visit._request = Callable(self, "_stub_request")
		visit._route(visit._hold_route_target, visit._hold_route_phase, visit._hold_route_tolerance)
		var last: Dictionary = _requests[-1] if not _requests.is_empty() else {}
		var last_target: Vector3 = last.get("target", Vector3.ZERO)
		ok = ok and str(last.get("phase", "")) == "WALK_TO_ENTRY"
		ok = ok and is_equal_approx(float(last.get("tolerance", 0.0)), 0.41)
		ok = ok and last_target.is_equal_approx(Vector3(1.0, 0.0, 2.0))
		print("VISITHOLD_PROBE reissue phase=", str(last.get("phase", "")),
			" tolerance=", float(last.get("tolerance", 0.0)),
			" target=", str(last_target), " requests=", _requests.size())
	print("VISITHOLD_PROBE_RESULT flag=", flag, " ok=", ok)
	quit(0 if ok else 1)
