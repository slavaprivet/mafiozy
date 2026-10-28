extends SceneTree
const Candidate = preload("res://scripts/transport/candidates/transport_actor_transition_moving_exit.gd")
const Access = preload("res://scripts/transport/transport_access_provider.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	for angle in [0.0,.15,-.15]:
		for speed in [2.4,10.0]:
			var world := Node3D.new(); root.add_child(world)
			var floor := StaticBody3D.new(); floor.rotation.z=angle; floor.position=Vector3(sin(angle)*.1,-cos(angle)*.1,0)
			var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size=Vector3(40,.2,40); shape.shape=box; floor.add_child(shape); world.add_child(floor)
			var actor := CharacterBody3D.new(); actor.collision_layer=2; actor.collision_mask=1
			var capsule := CollisionShape3D.new(); capsule.position.y=.95; var cap := CapsuleShape3D.new(); cap.height=1.9; cap.radius=.36; capsule.shape=cap; actor.add_child(capsule); world.add_child(actor)
			# Place capsule support above the sloping plane at its exact radius.
			actor.position.y=.36/cos(angle)-.36+.002
			var vehicle := RigidBody3D.new(); vehicle.freeze=true; vehicle.position=Vector3(0,0,-10); world.add_child(vehicle)
			var provider=Candidate.new(); provider.configure(Access.new())
			var state={"token":"fixture","action":"EXIT","seat_id":"front_left","phase":"RECOVERY","elapsed":0.0,"exit_kind":"tumble","blocked":false,"recovery_velocity":Vector3(speed,0,0),"recovery_initial_speed_mps":speed,"recovery_distance_m":0.0,"source_clock":1,"actor_ref":{"actor_id":"fixture","life_generation":1},"vehicle_ref":{"vehicle_id":"fixture","life_generation":1}}
			await physics_frame; await physics_frame
			var start: Vector3=actor.position
			var previous:=0.0; var hops:=0.0; var result: Dictionary={}
			for frame in range(102):
				result=provider._step_exit(state,actor,vehicle,1.0/60)
				check(state.elapsed>=previous,"recovery clock continuous")
				previous=state.elapsed
				var pose: Dictionary=result.get("pose",result)
				hops=maxf(hops,float(pose.get("body_hop_m",0)))
			check(is_equal_approx(state.elapsed,1.7),"floor contact never freezes recovery")
			check(actor.position.x-start.x>.1,"real planar progress on slope")
			check(hops>.27,"source hop exported")
			check(result.code=="COMPLETE","actual final support probe on slope "+str(angle)+" "+str(result))
			world.free(); await physics_frame
	print("MOVING_EXIT_SLOPE_CANDIDATE ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"actual flat/uphill/downhill capsule+floor; candidate only"}))
	quit(0 if failures.is_empty() else 1)
