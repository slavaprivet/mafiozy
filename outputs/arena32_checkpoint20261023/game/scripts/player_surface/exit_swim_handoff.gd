extends RefCounted
## Exact valid-domain port of createExitSwimHandoff. Height math only;
## Root remains the sole actor movement/pose/seat owner.
const SOURCE_SHA256 := "ea4c12aa647bd0587fbcdb15fa57933db3c8a2c20995219e73af75a90d858fde"
const DURATION_S := .45
const MINIMUM_OFFSET_M := 1.05
const MAX_SPEED_MPS := 10.0
var _ready := false
var _minimum := 0.0
var _start := 0.0
var _elapsed := 0.0
var _done := false
var _current := 0.0

func configure(from_y: float, water_level: float) -> Dictionary:
	if not is_finite(from_y) or not is_finite(water_level): return {"ok":false,"error":"FINITE_START_AND_WATER_REQUIRED"}
	_minimum = water_level - MINIMUM_OFFSET_M
	_start = maxf(from_y,_minimum)
	_elapsed = 0.0; _done = false; _current = _start; _ready = true
	return {"ok":true,"state":state()}

func update(target_y: float, dt: float) -> Dictionary:
	if not _ready: return {"ok":false,"error":"NOT_CONFIGURED"}
	if not is_finite(target_y) or not is_finite(dt) or dt < 0.0: return {"ok":false,"error":"FINITE_TARGET_NONNEGATIVE_DT_REQUIRED"}
	# Source uses raw dt here; do not copy the separate swim motion's .25s cap.
	_elapsed += dt
	var progress := minf(1.0,_elapsed / DURATION_S)
	var blend := progress * progress * (3.0-2.0*progress)
	var safe_target := maxf(_minimum,target_y)
	var desired := maxf(_minimum,_start+(safe_target-_start)*blend)
	var max_step := MAX_SPEED_MPS*dt
	_current += maxf(-max_step,minf(max_step,desired-_current))
	_done = _elapsed >= DURATION_S and target_y >= _minimum and absf(_current-target_y)<1e-8
	return {"ok":true,"y":_current,"done":_done}

func state() -> Dictionary:
	return {"ready":_ready,"minimum":_minimum,"start":_start,"elapsed":_elapsed,"done":_done,"current":_current} if _ready else {"ready":false}

func dispose() -> void:
	_ready = false; _minimum=0.0; _start=0.0; _elapsed=0.0; _done=false; _current=0.0
