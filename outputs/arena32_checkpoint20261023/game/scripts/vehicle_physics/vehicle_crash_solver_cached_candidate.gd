extends "res://scripts/vehicle_physics/vehicle_crash_solver.gd"
## Candidate-only fixed-step cache optimization. The frozen parent owns every
## public API and all authority. This override preserves force order, Float64
## scratch, limits, clamps and 240 Hz integration; it only caches PackedArray
## values in locals and replaces the final velocity sqrt with the exact squared
## threshold comparison.

const MOVING_SPEED_SQUARED := 0.0008 * 0.0008

func _fixed_step(h: float) -> bool:
	for index in NODE_COUNT:
		var offset := index * 3
		var plastic: Vector3 = _plastic[index]
		var position: Vector3 = _position[index]
		var velocity: Vector3 = _velocity[index]
		_force_scratch[offset] = (plastic.x - position.x) * 240.0 - velocity.x * 26.0
		_force_scratch[offset + 1] = (plastic.y - position.y) * 240.0 - velocity.y * 26.0
		_force_scratch[offset + 2] = (plastic.z - position.z) * 240.0 - velocity.z * 26.0
	for beam_index in BEAM_COUNT:
		if _beam_broken[beam_index] != 0:
			continue
		var a: int = _beam_a[beam_index]
		var b: int = _beam_b[beam_index]
		var position_a: Vector3 = _position[a]
		var position_b: Vector3 = _position[b]
		var delta := position_b - position_a
		var length := delta.length()
		if length < 0.00000001:
			continue
		var velocity_a: Vector3 = _velocity[a]
		var velocity_b: Vector3 = _velocity[b]
		var relative := (velocity_b - velocity_a).dot(delta) / length
		var force := clampf((length - _beam_rest_length[beam_index]) * 42.0
			+ relative * 1.8, -100.0, 100.0) / length
		var a_offset := a * 3
		var b_offset := b * 3
		_force_scratch[a_offset] += delta.x * force
		_force_scratch[a_offset + 1] += delta.y * force
		_force_scratch[a_offset + 2] += delta.z * force
		_force_scratch[b_offset] -= delta.x * force
		_force_scratch[b_offset + 1] -= delta.y * force
		_force_scratch[b_offset + 2] -= delta.z * force
	var moving := false
	for index in NODE_COUNT:
		var offset := index * 3
		var plastic: Vector3 = _plastic[index]
		var velocity: Vector3 = _velocity[index]
		var position: Vector3 = _position[index]
		velocity.x = clampf(velocity.x + _force_scratch[offset] * h, -2.0, 2.0)
		position.x += velocity.x * h
		var delta := position.x - plastic.x
		if absf(delta) > 0.15:
			position.x = plastic.x + signf(delta) * 0.15
			velocity.x = 0.0
		velocity.y = clampf(velocity.y + _force_scratch[offset + 1] * h, -2.0, 2.0)
		position.y += velocity.y * h
		delta = position.y - plastic.y
		if absf(delta) > 0.15:
			position.y = plastic.y + signf(delta) * 0.15
			velocity.y = 0.0
		velocity.z = clampf(velocity.z + _force_scratch[offset + 2] * h, -2.0, 2.0)
		position.z += velocity.z * h
		delta = position.z - plastic.z
		if absf(delta) > 0.15:
			position.z = plastic.z + signf(delta) * 0.15
			velocity.z = 0.0
		_velocity[index] = velocity
		_position[index] = position
		if velocity.length_squared() > MOVING_SPEED_SQUARED:
			moving = true
	_simulation_time += h
	return moving
