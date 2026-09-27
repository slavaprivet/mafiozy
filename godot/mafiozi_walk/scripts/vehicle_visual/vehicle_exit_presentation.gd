extends RefCounted
## User-approved presentation timing, independent of the physical exit clock.
## No body, collision, rig or authority writes. Canonical pose geometry is kept.

const PROVIDER := "VEHICLE_EXIT_PRESENTATION_V1"
const PHYSICAL_DECELERATION_MPS2 := 9.0
const MIN_ROLL_WINDOW_S := .25
const MAX_ROLL_WINDOW_S := 1.19
const CANONICAL_ROLL_END := .70
const SPEED_EPSILON := .00001

## elapsed/duration are the unchanged physical RECOVERY clock. initial_speed
## is planar launch speed, retained once per exit token (never current speed).
## previous_progress belongs to this same token/epoch, starts at zero, and only
## guards against a stale/repeated sample. A brief blocked sweep must not reset
## or freeze elapsed; the physical owner separately decides safe completion.
static func sample(elapsed_s: float, duration_s: float, initial_planar_speed_mps: float,
		previous_progress: float = 0.0, blocked: bool = false) -> Dictionary:
	if not is_finite(elapsed_s) or not is_finite(duration_s) or not is_finite(initial_planar_speed_mps) or not is_finite(previous_progress):
		return {"valid":false,"reason":"non_finite"}
	if duration_s <= 0.0 or elapsed_s < 0.0 or initial_planar_speed_mps < 0.0 or previous_progress < 0.0 or previous_progress > 1.0:
		return {"valid":false,"reason":"invalid_range"}
	var maximum_window := minf(MAX_ROLL_WINDOW_S, duration_s * .70)
	var window := clampf(initial_planar_speed_mps / PHYSICAL_DECELERATION_MPS2,
		minf(MIN_ROLL_WINDOW_S, maximum_window), maximum_window)
	var elapsed := minf(elapsed_s, duration_s)
	var progress: float
	if elapsed <= window:
		var u := elapsed / window
		# Finite initial derivative; canonical .06 rotation threshold is reached
		# within the first 60-Hz step for the minimum and current native windows.
		progress = CANONICAL_ROLL_END * u * (2.0 - u)
	else:
		var u := (elapsed - window) / (duration_s - window)
		progress = CANONICAL_ROLL_END + (1.0-CANONICAL_ROLL_END) * u*u*(3.0-2.0*u)
	progress = maxf(previous_progress, clampf(progress,0.0,1.0))
	return {"valid":true,"provider":PROVIDER,"visual_progress":progress,
		"roll_window_s":window,"physical_progress":elapsed/duration_s,
		"rolls_scale":0.0 if initial_planar_speed_mps <= SPEED_EPSILON else 1.0,
		"blocked":blocked,"done":elapsed >= duration_s}
