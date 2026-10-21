extends RefCounted
## Pure local launch adapter for vehicle_crash.mjs detach; never damage authority.
## Its six values are deterministic sine evaluations and consume zero shared RNG.
const PART_IDS := ["hood","trunk","door_front_left","door_front_right","door_rear_left","door_rear_right","bumper_front","bumper_rear","wheel_front_left","wheel_front_right","wheel_rear_left","wheel_rear_right"]
const UINT32_MOD := 4294967296.0

static func launch(part_id: String, impact_count: int, normal_native: Vector3, impact_speed_mps: float, signed_speed_mps: float, travel_yaw_native: float) -> Dictionary:
	if part_id not in PART_IDS or impact_count < 0 or not normal_native.is_finite() or not is_finite(impact_speed_mps) or impact_speed_mps < 0.0 or not is_finite(signed_speed_mps) or not is_finite(travel_yaw_native):
		return {"ok":false}
	# JS performs the whole reduce as binary64 and applies >>>0 only at the end.
	var raw_seed := float(impact_count)+1.0
	for index in part_id.length(): raw_seed=raw_seed*31.0+part_id.unicode_at(index)
	var seed := int(fposmod(floor(raw_seed),UINT32_MOD))
	var random: Array[float]=[]
	for offset in range(1,7): random.append(sin(float(seed)+offset*2.399)*.5+.5)
	var impact := minf(24.0,8.0 if impact_speed_mps==0.0 else impact_speed_mps)
	# RY(pi): source polar X/Z and axial spin X/Z both change sign.
	var velocity:=Vector3(
		-sin(travel_yaw_native)*signed_speed_mps*.72-normal_native.x*impact*.15-(random[0]-.5)*3.0,
		1.3+impact*.12+random[1],
		-cos(travel_yaw_native)*signed_speed_mps*.72-normal_native.z*impact*.15-(random[2]-.5)*3.0)
	var angular:=Vector3(-(random[3]-.5)*7.0,(random[4]-.5)*7.0,-(random[5]-.5)*7.0)
	if not velocity.is_finite() or not angular.is_finite(): return {"ok":false}
	return {"ok":true,"linear_velocity_mps":velocity,"angular_velocity_rad_s":angular,"mass_kg":24.0 if part_id.begins_with("wheel") else 18.0,"source_seed_u32":seed,"deterministic_sine_draws":6,"shared_rng_draws":0}
