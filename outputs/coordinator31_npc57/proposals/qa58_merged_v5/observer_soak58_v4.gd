extends "observer_soak31_v3.gd"
## Cached native collision/body/steering fields at the existing1Hz cadence.
## No intersect/cast/test_move/floor/planner calls and no actor/route writes.

func _route_state31(life:RefCounted,row:Dictionary)->void:
	super._route_state31(life,row)
	var body:CharacterBody3D=life._token.body
	var basis:Basis=body.global_basis
	var slides:Array=[]
	for index:int in body.get_slide_collision_count():
		var hit:KinematicCollision3D=body.get_slide_collision(index)
		var collider:Variant=hit.get_collider()
		slides.append({"collider":str(collider.get_path()) if is_instance_valid(collider) and collider is Node else str(collider),
			"normal":_v31(hit.get_normal()),"point":_v31(hit.get_position()),
			"travel":_v31(hit.get_travel()),"remainder":_v31(hit.get_remainder()),"depth":hit.get_depth()})
	var trace:Dictionary={"sample_physics_frame":Engine.get_physics_frames(),"last_driver_frame":life._frame,
		"basis":[_v31(basis.x),_v31(basis.y),_v31(basis.z)],"velocity":_v31(body.velocity),
		"on_floor":body.is_on_floor(),"floor_normal":_v31(body.get_floor_normal()) if body.is_on_floor() else [],
		"collision_layer":body.collision_layer,"collision_mask":body.collision_mask,"slides":slides,"driver":{}}
	var owner:Array=_slow_owner31(life)
	var driver:RefCounted=owner[1]
	if driver!=null:
		var steer:Dictionary=driver._avoidance29_state
		var direction:Variant=steer.get("direction")
		trace.driver={"way":driver._way,"leg":driver._leg,"target_source":driver._target_source,
			"stall_s":driver._stall_s,"roam_step_phase":driver._roam_step29_phase,
			"roam_watch":driver._roam_watch29_state.duplicate(true),
			"way_best_distance":driver._service_best_distance56 if is_finite(driver._service_best_distance56) else -1.0,
			"way_idle_s":driver._service_way_idle_s56,
			"ready_frame":driver._route._ready_frame if driver._route!=null else -1,
			"last_query_failure":driver._route._last_query_failure if driver._route!=null else "",
			"last_query_collider_historical":driver._route._last_collider if driver._route!=null else "",
			"avoidance":{"direction":_v31(direction) if direction is Vector3 else [],
				"ratio":steer.get("ratio",0.0),"waiting":steer.get("waiting",false),
				"reason":steer.get("reason",""),"replan":steer.get("replan",false)}}
	row.native_trace58=trace
