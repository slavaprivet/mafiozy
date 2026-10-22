class_name NativeVehicleCrashRules
extends RefCounted

const PART_IDS := [
	"hood", "trunk", "door_front_left", "door_front_right",
	"door_rear_left", "door_rear_right", "bumper_front", "bumper_rear",
	"wheel_front_left", "wheel_front_right", "wheel_rear_left", "wheel_rear_right",
]
const WHEEL_IDS := ["front_left", "front_right", "rear_left", "rear_right"]
const IMPACT_MIN_MPS := 2.5
const IMPACT_MAX_MPS := 90.0
const BEAM_YIELD_STRAIN := 0.018
const BEAM_BREAK_STRAIN := 0.64
const PART_DETACH_HEALTH := 0.025
const COLLISION_DAMAGE_COOLDOWN_S := 0.25
const COLLISION_DAMAGE_CAP := 80
const COLLISION_HP_FLOOR := 1
const EXPLOSION_DEBRIS_CAP := 10
const STRUCTURAL_DEBRIS_CAP := 12
const WRECK_FX_SECONDS := 5.0
const DESTRUCTION_DELAY_SECONDS := 1.55
const SMOKE_RATIO := 0.55
const FIRE_RATIO := 0.24
const OCCUPANT_MIN_DELTA_V_MPS := 0.32
const OCCUPANT_FULL_DELTA_V_MPS := 16.0

static func collision_damage(impact_mps: float) -> int:
	if not is_finite(impact_mps) or impact_mps <= 0.0:
		return 0
	return mini(COLLISION_DAMAGE_CAP, roundi(pow(impact_mps / 4.1, 2.0) * 1.4))

static func local_collision_hp_proposal(current_hp: int, impact_mps: float) -> Dictionary:
	# This mirrors only the non-terminal local /walk adapter policy. It is not a
	# server HP mutation and must never revive or modify an existing wreck.
	if current_hp <= 0 or not is_finite(impact_mps):
		return {"valid": false, "proposal_only": true, "reason": "terminal_or_invalid"}
	return {"valid": true, "proposal_only": true,
		"hp_after": maxi(COLLISION_HP_FLOOR, current_hp - collision_damage(impact_mps)),
		"collision_damage_proposal": collision_damage(impact_mps),
		"requires_nonterminal_state": true, "may_start_fire": false,
		"may_start_explosion": false, "cooldown_s": COLLISION_DAMAGE_COOLDOWN_S}

static func crush_limits(profile: Dictionary) -> Vector3:
	var half := _half_extents(profile)
	return Vector3(minf(1.30, half.x * 1.20), minf(0.80, half.y * 2.0 * 0.38), minf(1.65, half.z * 0.72))

static func impact_envelope(profile: Dictionary, local_normal: Vector3, impact_mps: float) -> Dictionary:
	var half := _half_extents(profile)
	var mass_kg := _finite_number(profile.get("mass_kg"))
	if not _profile_geometry_valid(half, mass_kg) or not local_normal.is_finite() \
			or local_normal.length_squared() < 0.0000000000000001 or not is_finite(impact_mps):
		return {"valid": false, "applied": false}
	var speed := clampf(impact_mps, 0.0, IMPACT_MAX_MPS)
	if speed < IMPACT_MIN_MPS:
		return {"valid": true, "applied": false, "impact_mps": speed,
			"collision_damage_proposal": collision_damage(speed), "proposal_only": true}
	var normal := local_normal.normalized()
	var limits := crush_limits(profile)
	var fast := clampf((speed - 6.0) / 12.0, 0.0, 1.0)
	var yield_blend := fast * fast * (3.0 - 2.0 * fast)
	var severity := maxf(0.0, speed * speed - IMPACT_MIN_MPS * IMPACT_MIN_MPS) / 190.0 * (1.0 + 0.32 * yield_blend)
	var radius_m := clampf(0.52 + speed * 0.041, 0.58, 2.05)
	var direction_limit_m := 1.0 / sqrt(pow(normal.x / limits.x, 2.0) + pow(normal.y / limits.y, 2.0) + pow(normal.z / limits.z, 2.0))
	var depth_m := clampf(pow(speed - IMPACT_MIN_MPS, 1.35) * 0.016 * (1.0 + 0.85 * yield_blend), 0.0, direction_limit_m)
	return {"valid": true, "applied": true, "impact_mps": speed,
		"energy_j": 0.5 * mass_kg * speed * speed, "severity": severity,
		"radius_m": radius_m, "depth_m": depth_m, "direction_limit_m": direction_limit_m,
		"collision_damage_proposal": collision_damage(speed), "proposal_only": true}

static func damage_thresholds(max_hp: int) -> Dictionary:
	if max_hp < 120:
		return {"valid": false}
	return {"valid": true, "smoke_hp": floori(max_hp * SMOKE_RATIO),
		"fire_hp": floori(max_hp * FIRE_RATIO), "destruction_delay_s": DESTRUCTION_DELAY_SECONDS,
		"collision_hp_floor": COLLISION_HP_FLOOR}

static func _half_extents(profile: Dictionary) -> Vector3:
	var value: Variant = profile.get("body_half_extents_m")
	if value is Vector3:
		return value
	if value is Dictionary and value.has("x") and value.has("y") and value.has("z"):
		var x := _finite_number(value.x)
		var y := _finite_number(value.y)
		var z := _finite_number(value.z)
		if is_finite(x) and is_finite(y) and is_finite(z):
			return Vector3(x, y, z)
	return Vector3(NAN, NAN, NAN)

static func _finite_number(value: Variant) -> float:
	if value is int or value is float:
		var number := float(value)
		return number if is_finite(number) else NAN
	return NAN

static func _profile_geometry_valid(half: Vector3, mass_kg: float) -> bool:
	# These are the same bounded source inputs used by vehicle_crash_mechanics.
	return half.is_finite() and mass_kg >= 400.0 and mass_kg <= 40000.0 \
		and half.x >= 0.5 and half.x <= 2.6 \
		and half.y * 2.0 >= 0.8 and half.y * 2.0 <= 4.8 \
		and half.z >= 1.2 and half.z <= 8.0
