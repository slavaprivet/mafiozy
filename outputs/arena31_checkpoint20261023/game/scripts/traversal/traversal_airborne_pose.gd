class_name NativeTraversalAirbornePose
extends RefCounted
## Pure semantic pose receipt for unsupported ledge falls and impact landings.
## The host owns gravity, support, character-physics admission and the sole rig
## writer. This helper never advances time or moves a body.

const PROVIDER := "GODOT_TRAVERSAL_AIRBORNE_POSE_V1"
const LANDING_SETTLE_S := .45
const LONG_FALL_DISTANCE_M := 2.4
const FULL_FALL_SPEED_MPS := 12.0


static func propose(frame: Dictionary, rig: Dictionary = {}) -> Dictionary:
	var grounded := bool(frame.get("grounded", false))
	var vertical_speed := float(frame.get("vertical_speed_mps", NAN))
	var fall_distance := float(frame.get("fall_distance_m", NAN))
	var airborne_age := float(frame.get("airborne_age_s", NAN))
	var landing_age := float(frame.get("landing_age_s", 0.0))
	var impact_speed := float(frame.get("impact_speed_mps", 0.0))
	if not is_finite(vertical_speed) or not is_finite(fall_distance) or fall_distance < 0.0 \
			or not is_finite(airborne_age) or airborne_age < 0.0 or not is_finite(landing_age) \
			or landing_age < 0.0 or not is_finite(impact_speed) or impact_speed < 0.0:
		return {"provider":PROVIDER, "valid":false, "reason":"invalid_motion"}
	var target_height := float(rig.get("target_height_m", 1.9))
	if not is_finite(target_height) or target_height <= 0.0:
		return {"provider":PROVIDER, "valid":false, "reason":"invalid_rig"}
	var unit := target_height / 1.9
	var downward_speed := maxf(0.0, -vertical_speed)
	var speed_blend := _smooth_between(.2, FULL_FALL_SPEED_MPS, downward_speed)
	var distance_blend := _smooth_between(.45, LONG_FALL_DISTANCE_M, fall_distance)
	var long_fall_blend := maxf(speed_blend, distance_blend)
	if not grounded:
		var phase := "ascent" if vertical_speed > .2 else ("apex" if vertical_speed >= -.2 else ("long_fall" if long_fall_blend >= .55 else "fall"))
		var entry := _smooth_between(0.0, .18, airborne_age)
		var stream := long_fall_blend * entry
		return _result(phase, vertical_speed, fall_distance, long_fall_blend, 0.0, 0.0, unit, stream, false)
	if landing_age >= LANDING_SETTLE_S:
		return _result("idle", vertical_speed, fall_distance, long_fall_blend, impact_speed, 0.0, unit, 0.0, true)
	var impact_blend := _smooth_between(2.0, FULL_FALL_SPEED_MPS, impact_speed)
	var normalized_age := landing_age / LANDING_SETTLE_S
	var compression := impact_blend * _smooth_between(0.0, .18, normalized_age) \
		* (1.0 - _smooth_between(.34, 1.0, normalized_age))
	return _result("landing", vertical_speed, fall_distance, long_fall_blend, impact_speed,
		compression, unit, long_fall_blend, true)


static func _result(phase: String, vertical_speed: float, fall_distance: float,
		long_fall_blend: float, impact_speed: float, compression: float, unit: float,
		stream: float, grounded: bool) -> Dictionary:
	var weapon_policy := "restore" if phase == "idle" else ("holster" if phase in ["long_fall", "landing"] or long_fall_blend >= .35 else "carry_safe")
	return {
		"provider":PROVIDER, "valid":true, "reason":"proposal", "phase":phase,
		"grounded":grounded, "vertical_speed_mps":vertical_speed,
		"fall_distance_m":fall_distance, "long_fall_blend":long_fall_blend,
		"impact_speed_mps":impact_speed, "impact_severity":_smooth_between(2.0, FULL_FALL_SPEED_MPS, impact_speed),
		"landing_compression":compression,
		"spine":{"chest_pitch_rad":lerpf(.08, -.18, stream) + .34 * compression,
			"neck_pitch_rad":.06 * stream - .18 * compression,
			"head_pitch_rad":.08 * stream - .12 * compression},
		"arms":{"stream_back_rad":.82 * stream, "spread_rad":.18 * stream},
		"legs":{"stream_rad":.42 * stream, "compression_rad":.92 * compression},
		"pelvis":{"root_owned":false, "visual_offset_y_m":-.09 * unit * compression,
			"clearance_required_m":.03},
		"feet":{"plant_weight":compression, "max_slip_m":.02},
		"head":{"clearance_required_m":.02},
		"weapon_policy":weapon_policy, "weapon_restore_on_terminal":phase == "idle",
		"character_physics_input":{"authority_owned":false, "impact_speed_mps":impact_speed,
			"fall_distance_m":fall_distance, "admission_required":phase == "landing" and impact_speed > 0.0},
	}


static func _smooth_between(start: float, finish: float, value: float) -> float:
	var t := clampf((value - start) / (finish - start), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
