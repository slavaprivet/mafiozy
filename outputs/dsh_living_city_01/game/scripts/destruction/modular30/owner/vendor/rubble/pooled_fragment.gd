extends RigidBody3D
## Only genuine physics observations enter the manager. No timer-only parking.
var manager: WeakRef
var pool_index: int=-1
var generation: int=0
var record_id: String=""
var previous_velocity:=Vector3.ZERO

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if manager==null or record_id.is_empty(): return
	var owner: Object=manager.get_ref()
	if not is_instance_valid(owner): return
	if state.angular_velocity.length_squared()>9.0: state.angular_velocity=state.angular_velocity.normalized()*3.0
	var impact: Vector3=state.linear_velocity if state.linear_velocity.length_squared()>previous_velocity.length_squared() else previous_velocity
	previous_velocity=state.linear_velocity
	var supports: Array=[]
	var impacts: Array=[]
	for i: int in state.get_contact_count():
		var collider: Object=state.get_contact_collider_object(i)
		if not is_instance_valid(collider): continue
		# Godot returns this body's contact point/normal in world coordinates;
		# 'local' distinguishes the side of the contact, not local transform space.
		var normal: Vector3=state.get_contact_local_normal(i)
		var point: Vector3=state.get_contact_local_position(i)
		if collider is StaticBody3D and normal.y>.5 and collider.constant_linear_velocity.length_squared()<.0001 and collider.constant_angular_velocity.length_squared()<.0001:
			supports.append({"collider":collider,"point":point})
		if impact.length_squared()>1.44 and collider.has_meta("rubble_region"):
			impacts.append({"region":str(collider.get_meta("rubble_region")),"point":point,"velocity":impact.limit_length(4.0)*.25})
	owner.observe_physics(pool_index,generation,record_id,{"frame":state.transform,"linear":state.linear_velocity,"angular":state.angular_velocity,"step":state.step,"supports":supports,"impacts":impacts,"tick":Engine.get_physics_frames()})
