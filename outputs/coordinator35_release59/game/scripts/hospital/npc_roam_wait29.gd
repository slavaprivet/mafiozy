extends RefCounted
## Roam-only: queue time is not failed movement. Inner replans preserve both
## accumulated goal work and attempted-motion time. Only a new goal resets all.
const PLAN_WALL_MS := 15000
const PLAN_SERVICE_US := 250000
const MOTION_STALL_MS := 2500
var _last_ms := -1
var _planning_ms := 0
var _planning_us := 0
var _motion_idle_ms := 0
# DSH_ROAMBUDGET: --city-roam-budget-progress-reset=1 releases the accumulated
# planning-service budget when the watcher has just measured real travel. The
# budget exists to bound work that makes no progress (see the file header: queue
# time is not failed movement); 0 (default) keeps today's text and verdicts.
var _dsh_roam_budget_progress := -1

func _progress_reset() -> bool:  # DSH_ROAMBUDGET
	if _dsh_roam_budget_progress < 0:
		_dsh_roam_budget_progress = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-roam-budget-progress-reset="):
				_dsh_roam_budget_progress = 1 if argument.trim_prefix("--city-roam-budget-progress-reset=") == "1" else 0
	return _dsh_roam_budget_progress == 1

func begin(now_ms: int) -> void:
	_last_ms=now_ms;_planning_ms=0;_planning_us=0;_motion_idle_ms=0

func observe(now_ms: int, phase: String, moved_m: float, planner_service_delta_us: int = 0) -> Dictionary:
	if _last_ms<0:begin(now_ms)
	if now_ms<_last_ms or phase not in ["planning","walking","idle"] or planner_service_delta_us<0 or not is_finite(moved_m) or moved_m<0.0:
		return {"blocked":true,"reason":"invalid_watch_sample"}
	var elapsed: int=now_ms-_last_ms
	_last_ms=now_ms
	_planning_us+=planner_service_delta_us
	if moved_m>.005 and _progress_reset():_planning_us=0  # DSH_ROAMBUDGET
	if moved_m>.005:_motion_idle_ms=0
	if phase=="planning":
		_planning_ms+=elapsed
		# Preserve accumulated failed motion, but do not count queue wait as more.
	elif phase=="walking" and moved_m<=.005:
		_motion_idle_ms+=elapsed
	var reason := ""
	if _planning_us>=PLAN_SERVICE_US:reason="roam_planning_work_limit"
	elif _planning_ms>=PLAN_WALL_MS:reason="roam_planning_wait_limit"
	elif _motion_idle_ms>=MOTION_STALL_MS:reason="roam_motion_stalled"
	return {"blocked":not reason.is_empty(),"reason":reason,"phase":phase,"planning_ms":_planning_ms,
		"planning_service_us":_planning_us,"motion_idle_ms":_motion_idle_ms}

static func retry_delay_ms(actor_id: String, attempt: int, reason: String) -> int:
	# Stable per actor/attempt, changing on the next goal. No shared RNG sequence
	# or identical fixed-delay stampede. Preserve the caller's diagnostic reason.
	var spread: int=hash(actor_id+":"+str(attempt)) & 0x7fffffff
	var detail: String=reason.trim_prefix("guide:")
	if detail in ["roam_planning_wait_limit","authority_queue_timeout","native_admission_timeout","prepare_queue_timeout","shared_queue_full","guide_capacity","shared_memory_capacity"]:
		return 2000+spread%4001
	return 1000+spread%2001
