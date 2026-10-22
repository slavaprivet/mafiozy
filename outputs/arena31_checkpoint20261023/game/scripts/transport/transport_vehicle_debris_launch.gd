extends RefCounted
## Source explosion launch only; host supplies seven ordered shared RNG draws.
## Coordinates are native (-Z forward), not THREE +Z.
static func explosion(index: int, source_offset_native: Vector3, signed_speed_mps: float, travel_yaw_native: float, draws: Array) -> Dictionary:
	if index < 0 or index >= 10 or not source_offset_native.is_finite() or not is_finite(signed_speed_mps) or not is_finite(travel_yaw_native) or draws.size() != 7:
		return {"ok": false}
	for value in draws:
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0 or float(value) >= 1:
			return {"ok": false}
	var outward := source_offset_native.slide(Vector3.UP)
	if outward.length_squared() < .01:
		outward = Vector3(-cos(index * 2.399), 0, -sin(index * 2.399))
	outward = outward.normalized()
	var angle := (float(draws[0]) - .5) * 1.2
	var strength := .65 + float(draws[1]) * .7
	var velocity := outward.rotated(Vector3.UP, angle) * ((3.5 + index % 3 * .65) * strength)
	var speed := clampf(signed_speed_mps, -35, 35)
	velocity += Vector3(-sin(travel_yaw_native), 0, -cos(travel_yaw_native)) * speed
	velocity.y = 2.8 + float(draws[2]) * 2.4
	# RNG slot3 is source landing yaw even though native rigid bodies own landing.
	var spin := Vector3(-(float(draws[4]) - .5) * 6, (float(draws[5]) - .5) * 6, -(float(draws[6]) - .5) * 6)
	return {"ok": true, "linear_velocity_mps": velocity, "angular_velocity_rad_s": spin, "source_landing_yaw": float(draws[3]) * TAU, "rng_draws": 7}
