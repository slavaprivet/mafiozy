class_name NativeVehicleBody
extends RigidBody3D

const Profile = preload("res://scripts/vehicle_physics/vehicle_profile.gd")
const ContactBuffer = preload("res://scripts/vehicle_physics/vehicle_contact_buffer.gd")
const ContactLedger = preload("res://scripts/vehicle_physics/vehicle_contact_ledger.gd")
const WHEEL_COUNT := 4
const FRONT_WHEEL_MASK := 0b0011
const REAR_WHEEL_MASK := 0b1100
const MAX_CONTACTS_PER_TICK := 8
const CONTROL_DEADZONE := 0.0001
const OPPOSITE_PEDAL_SPEED_EPSILON_MPS := 0.02
const SOURCE_HANDBRAKE_DECEL_MPS2 := 12.0

var profile
var _wheel_rays: Array[RayCast3D] = []
var _contact_buffer = ContactBuffer.new(32)
var _contact_ledger = ContactLedger.new(64)
var _physics_tick := 0
var _contact_sequence := 0
var _control_sequence := -1
var _control_source_clock := -1
var _throttle := 0.0
var _steering_input := 0.0
var _brake := 0.0
var _handbrake := false
var _steering_angle := 0.0
var _grounded_wheel_mask := 0
var _wheel_surface_ids := PackedStringArray(["", "", "", ""])
var _wheel_load_n := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _wheel_slip := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _wheel_longitudinal_mps := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _last_transform := Transform3D.IDENTITY
var _last_linear_velocity := Vector3.ZERO
var _last_angular_velocity := Vector3.ZERO

func _ready() -> void:
	add_to_group("native_vehicle_body", true)
	if profile == null:
		profile = Profile.from_dictionary({"vehicle_id": "native-preview", "profile_id": "compact_sedan"})
	_rebuild_physical_body()

func configure(descriptor: Dictionary) -> bool:
	var next_profile = Profile.from_dictionary(descriptor)
	if next_profile == null:
		return false
	if profile != null:
		if next_profile.vehicle_id != profile.vehicle_id or next_profile.profile_id != profile.profile_id:
			return false
		if next_profile.life_generation < profile.life_generation or next_profile.source_clock < profile.source_clock:
			return false
		if next_profile.life_generation > profile.life_generation:
			_reset_lifetime_state()
	profile = next_profile
	set_meta("vehicle_id", str(profile.vehicle_id))
	set_meta("life_generation", profile.life_generation)
	set_meta("profile_id", str(profile.profile_id))
	set_meta("source_clock", profile.source_clock)
	if is_inside_tree():
		_rebuild_physical_body()
	return true

func _reset_lifetime_state() -> void:
	_throttle = 0.0
	_steering_input = 0.0
	_brake = 0.0
	_handbrake = false
	_steering_angle = 0.0
	_control_sequence = -1
	_control_source_clock = -1
	_physics_tick = 0
	_contact_sequence = 0
	_grounded_wheel_mask = 0
	_wheel_surface_ids.fill("")
	_wheel_load_n.fill(0.0)
	_wheel_slip.fill(0.0)
	_wheel_longitudinal_mps.fill(0.0)
	_contact_buffer.reset_lifetime()
	_contact_ledger.reset_lifetime()
	_last_transform = transform
	_last_linear_velocity = Vector3.ZERO
	_last_angular_velocity = Vector3.ZERO

func submit_control(throttle: float, steering: float, brake: float, handbrake: bool, sequence: int) -> bool:
	if not is_finite(throttle) or not is_finite(steering) or not is_finite(brake) or sequence <= _control_sequence:
		return false
	_control_sequence = sequence
	_throttle = clampf(throttle, -1.0, 1.0)
	_steering_input = clampf(steering, -1.0, 1.0)
	_brake = clampf(brake, 0.0, 1.0)
	_handbrake = handbrake
	sleeping = false
	return true

func submit_authoritative_control(throttle: float, steering: float, brake: float, handbrake: bool,
		sequence: int, vehicle_id: String, life_generation: int, source_clock: int) -> bool:
	if profile == null or vehicle_id != str(profile.vehicle_id) or life_generation != profile.life_generation:
		return false
	if source_clock < profile.source_clock or source_clock < _control_source_clock:
		return false
	if not submit_control(throttle, steering, brake, handbrake, sequence):
		return false
	_control_source_clock = source_clock
	return true

func clear_control(sequence: int) -> bool:
	return submit_control(0.0, 0.0, 0.0, false, sequence)

func snapshot_state() -> Dictionary:
	var published_transform := transform if _physics_tick == 0 else _last_transform
	var published_linear := linear_velocity if _physics_tick == 0 else _last_linear_velocity
	var published_angular := angular_velocity if _physics_tick == 0 else _last_angular_velocity
	var q := published_transform.basis.get_rotation_quaternion()
	return {
		"vehicle_id": str(profile.vehicle_id), "life_generation": profile.life_generation,
		"profile_id": str(profile.profile_id), "source_clock": profile.source_clock, "physics_tick": _physics_tick,
		"position_m": published_transform.origin, "rotation_quat_xyzw": [q.x, q.y, q.z, q.w],
		"linear_velocity_mps": published_linear, "angular_velocity_radps": published_angular,
		"grounded_wheel_mask": _grounded_wheel_mask, "surface_ids": _wheel_surface_ids.duplicate(),
		"wheel_load_n": _wheel_load_n.duplicate(), "wheel_slip": _wheel_slip.duplicate(),
		"wheel_longitudinal_mps": _wheel_longitudinal_mps.duplicate(),
		"steering_angle_rad": _steering_angle, "control_sequence": _control_sequence,
		"control_source_clock": _control_source_clock,
	}

func drain_contact_receipts() -> Array[Dictionary]:
	return _contact_buffer.drain()

func local_anchor_to_global(local_anchor_m: Vector3) -> Vector3:
	return global_transform * local_anchor_m

func velocity_at_local_anchor(local_anchor_m: Vector3) -> Vector3:
	var anchor_basis := global_basis if is_inside_tree() else transform.basis
	var world_offset: Vector3 = anchor_basis * (local_anchor_m - profile.center_of_mass_local_m)
	return linear_velocity + angular_velocity.cross(world_offset)

func is_upright(minimum_up_dot := 0.55) -> bool:
	return global_basis.y.normalized().dot(Vector3.UP) >= clampf(minimum_up_dot, -1.0, 1.0)

static func force_substeps(dt: float) -> int:
	if not is_finite(dt) or dt <= 0.0:
		return 0
	return clampi(int(ceil(dt * 120.0 - 0.0001)), 1, 12)

func wheel_visual_state(index: int) -> Dictionary:
	if index < 0 or index >= WHEEL_COUNT:
		return {"valid": false}
	return {"valid": true, "grounded": (_grounded_wheel_mask & (1 << index)) != 0,
		"surface_id": _wheel_surface_ids[index], "load_n": _wheel_load_n[index],
		"slip": _wheel_slip[index], "longitudinal_mps": _wheel_longitudinal_mps[index]}

func contact_buffer_status() -> Dictionary:
	return {"size": _contact_buffer.size(), "capacity": _contact_buffer.capacity(),
		"overflow_total": _contact_buffer.overflow_total, "high_water": _contact_buffer.high_water,
		"gap": _contact_buffer.has_gap(), "ledger": _contact_ledger.status()}

func body_sweep(target_transform: Transform3D, margin := 0.04) -> Dictionary:
	if profile == null or not is_inside_tree() or not is_finite(margin):
		return {"valid": false, "safe_fraction": 0.0, "unsafe_fraction": 0.0}
	var current_rotation := global_basis.get_rotation_quaternion()
	var target_rotation := target_transform.basis.get_rotation_quaternion()
	if 1.0 - absf(current_rotation.dot(target_rotation)) > 0.0000005:
		return {"valid": false, "reason": "rotation_sweep_unsupported", "safe_fraction": 0.0, "unsafe_fraction": 0.0}
	var shape := BoxShape3D.new()
	shape.size = profile.chassis_half_extents_m() * 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = global_transform.translated_local(profile.chassis_center_local_m())
	query.motion = target_transform.origin - global_transform.origin
	query.margin = clampf(margin, 0.001, 0.25)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	var cast := get_world_3d().direct_space_state.cast_motion(query)
	return {"valid": cast.size() == 2, "safe_fraction": cast[0] if cast.size() == 2 else 0.0,
		"unsafe_fraction": cast[1] if cast.size() == 2 else 0.0}

func _rebuild_physical_body() -> void:
	if profile == null or not profile.is_valid():
		return
	mass = profile.mass_kg
	# Source linear_drag is coast deceleration (m/s²), not velocity damping.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = profile.angular_drag
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = profile.center_of_mass_local_m
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = MAX_CONTACTS_PER_TICK
	can_sleep = true
	custom_integrator = true
	for child: Node in get_children():
		if child.has_meta("native_vehicle_owned"):
			remove_child(child)
			child.queue_free()
	_wheel_rays.clear()
	var collision := CollisionShape3D.new()
	collision.name = "NativeVehicleCollision"
	collision.set_meta("native_vehicle_owned", true)
	var box := BoxShape3D.new()
	box.size = profile.chassis_half_extents_m() * 2.0
	collision.shape = box
	collision.position = profile.chassis_center_local_m()
	add_child(collision)
	var positions: PackedVector3Array = profile.wheel_local_positions()
	for i in WHEEL_COUNT:
		var ray := RayCast3D.new()
		ray.name = "WheelProbe%d" % i
		ray.set_meta("native_vehicle_owned", true)
		ray.position = positions[i]
		ray.target_position = Vector3(0.0, -(profile.suspension_rest_length_m + profile.wheel_radius_m), 0.0)
		ray.collision_mask = collision_mask
		ray.exclude_parent = true
		ray.enabled = true
		add_child(ray)
		_wheel_rays.append(ray)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	state.integrate_forces()
	if profile == null or not profile.is_valid():
		return
	_physics_tick += 1
	_contact_ledger.begin_tick(_physics_tick)
	var dt := state.step
	if dt <= 0.0 or not is_finite(dt):
		return
	_grounded_wheel_mask = 0
	var grounded := 0
	var support_mask := 0
	var gravity_up := Vector3.UP
	if state.total_gravity.length_squared() > 0.000001:
		gravity_up = -state.total_gravity.normalized()
	for i in _wheel_rays.size():
		var ray := _wheel_rays[i]
		ray.force_raycast_update()
		if not ray.is_colliding():
			_wheel_surface_ids[i] = ""
			_wheel_load_n[i] = 0.0
			_wheel_slip[i] = 0.0
			_wheel_longitudinal_mps[i] = 0.0
			continue
		var support_normal := ray.get_collision_normal()
		if not support_normal.is_finite() or support_normal.length_squared() < 0.000001 \
				or support_normal.normalized().dot(gravity_up) <= 0.05:
			_wheel_surface_ids[i] = ""
			_wheel_load_n[i] = 0.0
			_wheel_slip[i] = 0.0
			_wheel_longitudinal_mps[i] = 0.0
			continue
		grounded += 1
		support_mask |= 1 << i
		var collider := ray.get_collider()
		_wheel_surface_ids[i] = str(collider.get_meta("vehicle_surface_id", "default")) if collider is Object else "default"
	_grounded_wheel_mask = support_mask
	var substeps := force_substeps(dt)
	var step_dt := dt / float(substeps)
	for substep in substeps:
		_apply_coast_step(state, step_dt)
		_apply_wheel_step(state, grounded, step_dt)
	_collect_contacts(state)
	_publish_state(state)

func _apply_wheel_step(state: PhysicsDirectBodyState3D, grounded: int, dt: float) -> void:
	if grounded <= 0:
		return
	var basis := state.transform.basis.orthonormalized()
	var body_forward := (-basis.z).normalized()
	var up := basis.y.normalized()
	var local_forward_speed := state.linear_velocity.dot(body_forward)
	var opposite_pedal_braking := _throttle * local_forward_speed < -OPPOSITE_PEDAL_SPEED_EPSILON_MPS
	var requested_service_brake := maxf(_brake, 1.0 if opposite_pedal_braking else 0.0)
	var grounded_rear_count := int((_grounded_wheel_mask & (1 << 2)) != 0) \
		+ int((_grounded_wheel_mask & (1 << 3)) != 0)
	var speed_abs := absf(local_forward_speed)
	var steer_limit: float = profile.steering_limit_rad / (1.0 + speed_abs * 0.035 + speed_abs * speed_abs * 0.0012)
	var target_steer: float = _steering_input * steer_limit
	_steering_angle = move_toward(_steering_angle, target_steer, (10.0 if absf(_steering_input) > CONTROL_DEADZONE else 12.0) * dt)
	for i in _wheel_rays.size():
		var ray := _wheel_rays[i]
		if (_grounded_wheel_mask & (1 << i)) == 0 or not ray.is_colliding():
			continue
		var point := ray.get_collision_point()
		var normal := ray.get_collision_normal().normalized()
		var mount_world := state.transform * ray.position
		var contact_distance := mount_world.distance_to(point)
		var suspension_length := maxf(0.0, contact_distance - profile.wheel_radius_m)
		var compression := clampf(profile.suspension_rest_length_m - suspension_length, 0.0, profile.suspension_rest_length_m)
		var offset := point - state.transform.origin
		var center_of_mass_world: Vector3 = state.transform * profile.center_of_mass_local_m
		var point_velocity := state.linear_velocity + state.angular_velocity.cross(point - center_of_mass_world)
		var static_compression: float = profile.suspension_rest_length_m * (1.0 - Profile.STATIC_SUSPENSION_LENGTH_RATIO)
		var spring_rate: float = profile.mass_kg * state.total_gravity.length() / maxf(0.05, float(WHEEL_COUNT) * static_compression)
		var spring_force := maxf(0.0, spring_rate * compression - point_velocity.dot(normal) * profile.mass_kg * 0.7)
		var normal_load := spring_force
		_wheel_load_n[i] = normal_load
		state.apply_impulse(normal * spring_force * dt, offset)
		var steered_forward := body_forward
		if i < 2:
			# Same +Y steering convention as authored wheel pivots under the
			# source-to-Godot basis wrapper: positive steering turns toward -X.
			steered_forward = body_forward.rotated(up, _steering_angle).normalized()
		var wheel_forward := steered_forward - normal * steered_forward.dot(normal)
		if not wheel_forward.is_finite() or wheel_forward.length_squared() < 0.000001:
			_wheel_slip[i] = 0.0
			_wheel_longitudinal_mps[i] = 0.0
			continue
		wheel_forward = wheel_forward.normalized()
		var wheel_right := wheel_forward.cross(normal)
		if not wheel_right.is_finite() or wheel_right.length_squared() < 0.000001:
			_wheel_slip[i] = 0.0
			_wheel_longitudinal_mps[i] = 0.0
			continue
		wheel_right = wheel_right.normalized()
		var rear_handbrake_wheel := _handbrake and (REAR_WHEEL_MASK & (1 << i)) != 0
		# A handbrake releases rear lateral grip, but does not divide the rear
		# wheel's longitudinal braking traction by the same 0.20 coefficient.
		var lateral_grip: float = profile.handbrake_rear_grip if rear_handbrake_wheel else profile.tyre_grip
		var longitudinal_grip: float = profile.tyre_grip
		var lateral_limit := normal_load * lateral_grip
		var longitudinal_limit := normal_load * longitudinal_grip
		var lateral_force := clampf(-point_velocity.dot(wheel_right) * profile.mass_kg * 4.0 / float(grounded), -lateral_limit, lateral_limit)
		var drive_accel: float = profile.engine_accel_mps2 if _throttle >= 0.0 else profile.reverse_accel_mps2
		var requested_drive: float = _throttle * drive_accel
		# Source braking wins over propulsion. Opposite pedal is a service-brake
		# request until signed forward speed reaches the source transition band.
		if _handbrake or requested_service_brake > CONTROL_DEADZONE:
			requested_drive = 0.0
		if (requested_drive > 0.0 and local_forward_speed >= profile.max_forward_speed_mps) or (requested_drive < 0.0 and local_forward_speed <= -profile.max_reverse_speed_mps):
			requested_drive = 0.0
		var longitudinal_force: float = requested_drive * profile.mass_kg / float(grounded)
		var wheel_long_speed := point_velocity.dot(wheel_forward)
		_wheel_longitudinal_mps[i] = wheel_long_speed
		if absf(wheel_long_speed) > OPPOSITE_PEDAL_SPEED_EPSILON_MPS:
			var brake_force := 0.0
			if requested_service_brake > CONTROL_DEADZONE:
				var service_request: float = profile.brake_decel_mps2 * profile.mass_kg \
					* requested_service_brake / float(grounded)
				var service_stop_limit: float = absf(wheel_long_speed) * profile.mass_kg \
					/ maxf(dt, 0.001) / float(grounded)
				brake_force = minf(service_request, service_stop_limit)
			if rear_handbrake_wheel and grounded_rear_count > 0:
				var handbrake_request: float = SOURCE_HANDBRAKE_DECEL_MPS2 * profile.mass_kg \
					/ float(grounded_rear_count)
				var handbrake_stop_limit: float = absf(wheel_long_speed) * profile.mass_kg \
					/ maxf(dt, 0.001) / float(grounded_rear_count)
				brake_force = maxf(brake_force, minf(handbrake_request, handbrake_stop_limit))
			longitudinal_force -= signf(wheel_long_speed) * brake_force
		# The tyre budget is anisotropic under handbrake: low rear lateral grip
		# remains available for rotation while full longitudinal tyre grip brakes.
		var lateral_ratio := lateral_force / maxf(0.001, lateral_limit)
		var longitudinal_ratio := longitudinal_force / maxf(0.001, longitudinal_limit)
		var ellipse_utilization := sqrt(lateral_ratio * lateral_ratio + longitudinal_ratio * longitudinal_ratio)
		if ellipse_utilization > 1.0:
			lateral_force /= ellipse_utilization
			longitudinal_force /= ellipse_utilization
		var tyre_force := wheel_right * lateral_force + wheel_forward * longitudinal_force
		var utilization := minf(1.0, ellipse_utilization)
		var handbrake_slip := 0.65 if _handbrake and i >= 2 else 0.0
		_wheel_slip[i] = clampf(absf(point_velocity.dot(wheel_right)) * 0.20 + maxf(0.0, utilization - 0.82) * 2.5 + handbrake_slip, 0.0, 1.0)
		state.apply_impulse(tyre_force * dt, offset)

func _apply_coast_step(state: PhysicsDirectBodyState3D, dt: float) -> void:
	# Road coast is a supported-wheel rule, not artificial airborne drag.
	if _grounded_wheel_mask == 0:
		return
	var planar := Vector3(state.linear_velocity.x, 0.0, state.linear_velocity.z)
	var speed := planar.length()
	if speed <= 0.0:
		return
	var forward := -state.transform.basis.z.normalized()
	var braking := _brake > CONTROL_DEADZONE or _handbrake or (_throttle * planar.dot(forward) < -CONTROL_DEADZONE)
	var drive_limit: float = profile.max_reverse_speed_mps if _throttle < 0.0 else profile.max_forward_speed_mps
	if braking or (absf(_throttle) > CONTROL_DEADZONE and speed <= drive_limit):
		return
	# Source aeroDrag=.012; damage/engine-disabled authority remains separate.
	var decel: float = profile.linear_drag + 0.012 * speed * speed
	var remaining := maxf(0.0, speed - decel * dt)
	state.linear_velocity += planar * (remaining / speed - 1.0)

func _collect_contacts(state: PhysicsDirectBodyState3D) -> void:
	var count := mini(state.get_contact_count(), MAX_CONTACTS_PER_TICK)
	for i in count:
		var impulse := state.get_contact_impulse(i)
		if impulse.length_squared() < 0.000001:
			continue
		var collider := state.get_contact_collider_object(i)
		if not (collider is Object) or not collider.has_meta("vehicle_id"):
			continue
		var counterpart := str(collider.get_meta("vehicle_id"))
		if not _contact_ledger.accept(counterpart, _physics_tick):
			continue
		_contact_sequence += 1
		_contact_buffer.push_contact(str(profile.vehicle_id), profile.life_generation, _physics_tick,
			_contact_sequence, counterpart, state.get_contact_collider_position(i),
			state.get_contact_local_normal(i),
			state.linear_velocity - state.get_contact_collider_velocity_at_position(i), impulse.length())

func _publish_state(state: PhysicsDirectBodyState3D) -> void:
	_last_transform = state.transform
	_last_linear_velocity = state.linear_velocity
	_last_angular_velocity = state.angular_velocity
