extends RigidBody3D
## Cosmetic, pushable rubble: retain contact collisions, but settle tiny tremors.
var quiet_time: float = 0.0
var stable_anchor: Vector3 = Vector3.ZERO
var stable_time: float = 0.0
var park_pending: bool = false
var previous_velocity: Vector3 = Vector3.ZERO

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var impact_velocity = state.linear_velocity if state.linear_velocity.length_squared() > previous_velocity.length_squared() else previous_velocity
	if impact_velocity.length_squared() > 1.44:
		for i in range(state.get_contact_count()):
			var other = state.get_contact_collider_object(i)
			if other is RigidBody3D and other.get_meta("parked",false):
				get_parent().get_parent()._impact_wake.call_deferred(other,impact_velocity)
	previous_velocity = state.linear_velocity
	if state.angular_velocity.length_squared() > 9.0:
		state.angular_velocity = state.angular_velocity.normalized()*3.0
	var grounded = state.get_contact_count() > 0
	if state.transform.origin.distance_squared_to(stable_anchor) > .0064:
		stable_anchor = state.transform.origin
		stable_time = 0.0
	elif grounded:
		stable_time += state.step
	else:
		stable_time = 0.0
	var quiet = state.linear_velocity.length_squared() < .0625 and state.angular_velocity.length_squared() < .49
	quiet_time = quiet_time+state.step if grounded and quiet else 0.0
	if not park_pending and (quiet_time >= .65 or (stable_time > 1.0 and state.linear_velocity.length_squared() < .36)):
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		park_pending = true
		get_parent().get_parent()._park_debris.call_deferred(self)
		quiet_time = 0.0
