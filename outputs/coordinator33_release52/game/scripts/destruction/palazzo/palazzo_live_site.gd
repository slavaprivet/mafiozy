extends "palazzo_site.gd"
## The existing native E/tween/sweep owns motion; this only selects the doorway.
const DOORWAY_REACH_M := 3.0
const DoorClose43 = preload("door_close43.gd")
var _door_close43: RefCounted

func get_door_prompt(actor: Node3D) -> Dictionary:
	if not _door_available() or not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion(): return {"available":false,"reason":"door_or_actor_unavailable"}
	if not actor is CollisionObject3D or actor.get_world_3d()!=get_world_3d(): return {"available":false,"reason":"native_actor_required"}
	var collision_actor: CollisionObject3D=actor as CollisionObject3D
	var frame: Transform3D=building.global_transform*_door_closed
	var size: Vector3=_door.get_meta("section_size")
	if not frame.is_finite() or absf(frame.basis.determinant())<.000001 or not size.is_finite() or size.x<=0.0 or size.y<=0.0: return {"available":false,"reason":"doorway_frame"}
	# Root26 requested three metres to the real stationary opening so the actor
	# can close it from the indoor centre beyond the complete inward swing.
	var local_actor: Vector3=frame.affine_inverse()*actor.global_position
	var nearest: Vector3=frame*Vector3(clampf(local_actor.x,-size.x*.5,size.x*.5),clampf(local_actor.y,-size.y*.5,size.y*.5),0.0)
	var distance_to_door: float=actor.global_position.distance_to(nearest)
	var busy: bool=(is_instance_valid(_door_tween) and _door_tween.is_running()) or (_door_close43!=null and _door_close43.active())
	var prompt: Dictionary={"available":false,"distance":distance_to_door,"open":_door_open,"busy":busy,"text":"Закрыть дверь" if _door_open else "Открыть дверь"}
	if not is_finite(distance_to_door) or distance_to_door>DOORWAY_REACH_M or busy: return prompt
	var camera: Camera3D=get_viewport().get_camera_3d()
	if not is_instance_valid(camera) or camera.get_world_3d()!=get_world_3d(): return prompt
	var screen: Vector2=get_viewport().get_visible_rect().get_center()
	var origin: Vector3=camera.project_ray_origin(screen)
	var direction: Vector3=camera.project_ray_normal(screen)
	var inverse: Transform3D=frame.affine_inverse()
	var local_origin: Vector3=inverse*origin
	var local_direction: Vector3=inverse.basis*direction
	if not local_origin.is_finite() or not local_direction.is_finite() or absf(local_direction.z)<.000001: return prompt
	var along: float=-local_origin.z/local_direction.z
	if not is_finite(along) or along<=0.0: return prompt
	var local_hit: Vector3=local_origin+local_direction*along
	if absf(local_hit.x)>size.x*.5 or absf(local_hit.y)>size.y*.5: return prompt
	var target: Vector3=frame*Vector3(local_hit.x,local_hit.y,0.0)
	# The camera cannot grant access over/through an intervening collider. The
	# actor's actual capsule centre supplies the independent near-side witness.
	var capsule: CollisionShape3D=actor.get_node_or_null("PlayerCapsule") as CollisionShape3D
	if not is_instance_valid(capsule) or capsule.disabled or not capsule.shape is CapsuleShape3D: return prompt
	if not _doorway_visible(origin,target,collision_actor) or not _doorway_visible(capsule.global_position,target,collision_actor): return prompt
	prompt.available=true
	prompt.target=target
	return prompt

func _doorway_visible(origin: Vector3,target: Vector3,actor: CollisionObject3D) -> bool:
	if not origin.is_finite() or not target.is_finite(): return false
	if origin.distance_squared_to(target)<.000001: return true
	# Ignore the actor/leaf, then at most ONE exact pane owned by that current
	# leaf. Repeat the FULL ray after it; another blocker may stand behind glass.
	var excluded: Array[RID]=[actor.get_rid(),_door.get_rid()]
	for pass_index: int in range(2):
		var query:=PhysicsRayQueryParameters3D.create(origin,target,0xFFFFFFFF,excluded)
		query.hit_from_inside=true
		var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): return true
		if pass_index!=0: return false
		# This exact child owner checks source, generation, current body identity,
		# native contact and collision resource before returning its wall WeakRef.
		var glazing: Node=get_node_or_null("OwnedWindowGlazing")
		if not is_instance_valid(glazing) or not glazing.has_method("validate_pane_contact"): return false
		var pane: StaticBody3D=hit.get("collider") as StaticBody3D
		if not is_instance_valid(pane): return false
		var contact: Dictionary=glazing.call("validate_pane_contact",pane,hit.position)
		if not contact.get("ok",false) or contact.get("wall")!=_door: return false
		excluded.append(pane.get_rid())
	return false

func interact_door(actor: Node3D) -> Dictionary:
	var prompt: Dictionary=get_door_prompt(actor)
	if not prompt.get("available",false) or not actor is CharacterBody3D: return {"ok":false,"reason":"door_out_of_reach_busy_or_unavailable"}
	if _door_close43==null: _door_close43=DoorClose43.new(self)
	return _door_close43.begin(actor as CharacterBody3D,not _door_open)

func _move_door(angle: float) -> void:
	if _door_close43!=null and _door_close43.active(): _door_close43.move(angle); return
	super._move_door(angle)

func _door43_commit(angle: float) -> void:
	var pose: Transform3D=_door_pose(angle)
	_door_angle=angle; _door.transform=pose; _queue_render(_door)
	for chunk: RigidBody3D in _door.get_meta("pooled_fragments"):
		chunk.transform=pose*Transform3D(Basis.IDENTITY,chunk.get_meta("panel_center"))
		initial_transforms[chunk.get_instance_id()]=chunk.global_transform; _queue_render(chunk)
	var glazing: Node=get_node_or_null("OwnedWindowGlazing")
	if is_instance_valid(glazing): glazing.call("sync_moving_panes")
	if has_method("_mark_structure_dirty"): call("_mark_structure_dirty")

func _door_finished() -> void:
	if _door_close43!=null and _door_close43.active(): _door_close43.finish(); return
	super._door_finished()

func _stop_door() -> void:
	# Active swing never calls this for an ordinary obstruction: its helper
	# safely aborts/holds. Base calls here retire/reset/fracture the old leaf.
	if _door_close43!=null and _door_close43.active(): _door_close43.retire()
	super._stop_door()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _door_close43!=null: _door_close43.tick(delta)
