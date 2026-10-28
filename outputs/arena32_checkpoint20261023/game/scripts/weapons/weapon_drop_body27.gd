extends RigidBody3D
## Gravity sweep begins one step above the current hull so contact-skin overlap
## cannot make cast_motion ignore the floor. Only falling velocity is limited;
## the native solver retains horizontal motion, contact torques and rotation.
var _drop_shape27: CollisionShape3D
var _fall_query27 := PhysicsShapeQueryParameters3D.new()
func set_drop_shape27(value: CollisionShape3D) -> void:
	_drop_shape27 = value
	_fall_query27.shape = value.shape
	_fall_query27.exclude = [get_rid()]
	_fall_query27.margin = 0.001
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not is_instance_valid(_drop_shape27) or state.linear_velocity.y >= 0.0: return
	var fall := -state.linear_velocity.y * state.step
	var rewind := fall + 2.0 * _fall_query27.margin
	_fall_query27.transform = state.transform * _drop_shape27.transform
	_fall_query27.transform.origin.y += rewind
	_fall_query27.collision_mask = collision_mask
	_fall_query27.motion = Vector3.DOWN * (rewind + fall)
	var travel := state.get_space_state().cast_motion(_fall_query27)
	if travel.size() < 2 or travel[0] >= 1.0: return
	var remaining := maxf(0.0, (rewind + fall) * travel[0] - rewind)
	var velocity := state.linear_velocity
	velocity.y = minf(0.0, -remaining / state.step - state.total_gravity.y * state.step)
	state.linear_velocity = velocity
