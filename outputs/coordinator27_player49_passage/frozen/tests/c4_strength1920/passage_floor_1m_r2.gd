extends "passage_floor_1m.gd"
## QA diagnostics only. An intact foundation blocking PREBLOCK must not prevent
## the real floor C4 attempt. Complete W/S acceptance is still decided honestly.
const CONTACT_SAMPLE_CAP := 16384
var preblock_record: Dictionary = {}

func collider_evidence(body: CollisionObject3D) -> Dictionary:
	var shapes: Array[Dictionary] = []
	for owner_id: int in body.get_shape_owners():
		var owner: Object = body.shape_owner_get_owner(owner_id)
		var local: Transform3D = body.shape_owner_get_transform(owner_id)
		for slot: int in body.shape_owner_get_shape_count(owner_id):
			var shape: Shape3D = body.shape_owner_get_shape(owner_id, slot)
			var data: Dictionary = {"class":shape.get_class(), "resource_id":shape.get_instance_id()}
			if shape is BoxShape3D: data.size = Observe.vector(shape.size)
			elif shape is CapsuleShape3D: data.height = shape.height; data.radius = shape.radius
			elif shape is SphereShape3D: data.radius = shape.radius
			elif shape is ConvexPolygonShape3D:
				var points: Array = []
				for point: Vector3 in shape.points: points.append(Observe.vector(point))
				data.points = points
			else: data.native_data = str(PhysicsServer3D.shape_get_data(shape.get_rid()))
			shapes.append({"owner_id":owner_id, "node":str(owner.get_path()) if owner is Node else str(owner), "shape_index":body.shape_owner_get_shape_index(owner_id, slot), "disabled":body.is_shape_owner_disabled(owner_id), "local_frame":Observe.frame(local), "world_frame":Observe.frame(body.global_transform * local), "shape":data})
	return {"id":body.get_instance_id(), "path":str(body.get_path()), "class":body.get_class(), "layer":body.collision_layer, "mask":body.collision_mask, "owned_rigid":site.owns_collider(body), "static":body is StaticBody3D, "detached":body.get_meta("detached", false), "body_frame":Observe.frame(body.global_transform), "site_local_frame":Observe.frame(site.global_transform.affine_inverse() * body.global_transform), "shapes":shapes}

func static_site_evidence() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node: Node in site.find_children("*", "StaticBody3D", true, false):
		result.append(collider_evidence(node as StaticBody3D))
	return result

func intact_wall_witness() -> Dictionary:
	# Independent read-only native stone-face contact. This does not mutate the
	# actor or become a production placement ray; equipment still selects ground.
	var from: Vector3 = wall_origin * Vector3(0, -.95, 1.2)
	var to: Vector3 = wall_origin * Vector3(0, -.95, -.8)
	var excluded: Array[RID] = [player.get_rid()]
	var query := PhysicsRayQueryParameters3D.create(from, to, player.collision_mask, excluded)
	query.hit_from_inside = true
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	var collider: CollisionObject3D = hit.get("collider") as CollisionObject3D
	var exact: bool = is_instance_valid(wall) and wall.freeze and not wall.get_meta("detached", false) and not wall.get_meta("fracture_active", false) and (wall.collision_layer & 1) != 0 and collider == wall
	return {"ok":exact, "route":"read-only native ray through solid lower stone, independent of W and C4 query", "from":Observe.vector(from), "to":Observe.vector(to), "collider_id":collider.get_instance_id() if is_instance_valid(collider) else 0, "contact":Observe.vector(hit.get("position", Vector3.ZERO)), "normal":Observe.vector(hit.get("normal", Vector3.ZERO)), "shape_index":hit.get("shape", -1), "wall":collider_evidence(wall)}

func observe_contacts(record: Dictionary) -> void:
	# A KinematicCollision3D can hold several contacts. Preserve ALL of them,
	# rather than only contact0 / the last normal for each collider.
	for slide: int in player.get_slide_collision_count():
		var collision: KinematicCollision3D = player.get_slide_collision(slide)
		for contact_index: int in collision.get_collision_count():
			if record.contact_samples.size() >= CONTACT_SAMPLE_CAP:
				record.contact_overflow = true
				return
			var body: CollisionObject3D = collision.get_collider(contact_index) as CollisionObject3D
			var id: int = body.get_instance_id() if is_instance_valid(body) else 0
			if is_instance_valid(body) and not record.colliders.has(str(id)):
				record.colliders[str(id)] = collider_evidence(body)
			var normal: Vector3 = collision.get_normal(contact_index)
			var local_shape: Object = collision.get_local_shape(contact_index)
			record.contact_samples.append({"phase":record.phase_class, "frame":Engine.get_physics_frames(), "slide_index":slide, "contact_index":contact_index, "collider_id":id, "collider_shape_index":collision.get_collider_shape_index(contact_index), "normal":Observe.vector(normal), "position":Observe.vector(collision.get_position(contact_index)), "collider_velocity":Observe.vector(collision.get_collider_velocity(contact_index)), "depth":collision.get_depth(), "local_shape":str(local_shape.get_path()) if local_shape is Node else str(local_shape), "owned_rigid":site.owns_collider(body) if is_instance_valid(body) else false, "static":body is StaticBody3D})
			if is_instance_valid(body) and absf(normal.dot(site.global_basis.z.normalized())) > .5:
				record.horizontal_blocker_ids[str(id)] = true

func walk_line(label: String, code: Key, destination_z: float, max_frames: int, must_block: bool = false) -> bool:
	var phase_class: String = "PREBLOCK" if must_block else ("POSTBLAST" if not callbacks.is_empty() else "INPUT_SETUP")
	phase = phase_class + "::" + label
	var start: Vector3 = site.to_local(player.global_position)
	var prior: Vector3 = start
	var record: Dictionary = {"label":label, "phase_class":phase_class, "key":"W" if code == KEY_W else "S", "start":Observe.vector(start), "end":Observe.vector(start), "target_z":destination_z, "reached":false, "stationary_ticks":0, "min_local_z":start.z, "max_lane_error_m":0.0, "max_height_change_m":0.0, "samples":[], "contact_samples":[], "colliders":{}, "horizontal_blocker_ids":{}, "contact_overflow":false, "complete":false, "static_site_before":static_site_evidence()}
	# Register BEFORE the first await. Watchdog/early finish can therefore retain
	# the last completed frame's positions, every contact and static shape owner.
	movements.append(record)
	evidence.movements = movements
	if must_block:
		preblock_record = record
		record.intact_wall_witness = intact_wall_witness()
	key(code, true)
	for index: int in max_frames:
		await step()
		if finished: key(code, false); return false
		var at: Vector3 = site.to_local(player.global_position)
		var delta_xz: float = Vector2(at.x - prior.x, at.z - prior.z).length()
		record.stationary_ticks = int(record.stationary_ticks) + 1 if delta_xz < .003 else 0
		record.min_local_z = minf(record.min_local_z, at.z)
		record.max_lane_error_m = maxf(record.max_lane_error_m, absf(at.x - LANE_X))
		record.max_height_change_m = maxf(record.max_height_change_m, absf(at.y - start.y))
		record.end = Observe.vector(at)
		observe_contacts(record)
		record.samples.append({"frame":Engine.get_physics_frames(), "local":Observe.vector(at), "velocity":Observe.vector(player.velocity), "on_floor":player.is_on_floor(), "held":Input.is_physical_key_pressed(code), "step_m":delta_xz})
		prior = at
		record.reached = at.z <= destination_z if code == KEY_W else at.z >= destination_z
		if record.reached or (must_block and record.stationary_ticks >= 12): break
	key(code, false)
	await step(8)
	if finished: return false
	var end: Vector3 = site.to_local(player.global_position)
	record.end = Observe.vector(end)
	record.complete = true
	record.actor_policy_unchanged = current_policy() == actor_policy and not capsule.disabled and camera == player.get_preview_camera()
	record.static_site_after = static_site_evidence()
	if must_block:
		# No owned-rigid requirement: OriginalFoundation, road or another real
		# static collider can explain the approach stop before the intact wall.
		record.actual_blocked = not record.reached and record.stationary_ticks >= 12 and record.min_local_z > WALL_Z + .17 and start.z - end.z >= .2 and not record.horizontal_blocker_ids.is_empty()
		record.foundation_observed = false
		for body: Dictionary in record.colliders.values():
			if body.path.ends_with("/OriginalFoundation") and record.horizontal_blocker_ids.has(str(body.id)): record.foundation_observed = true
		record.placement_prerequisite = false
		record.assertions_deferred_until_after_C4 = true
		# This return means the diagnostic approach completed, NOT "wall touched".
		# Correct parent outcome to the observed value in finish(), after the real
		# floor-C4 attempt; never convert the observation into a fabricated PASS.
		return true
	check(not record.contact_overflow, label + ": all native slide contacts fit the declared bounded evidence storage")
	check(record.max_lane_error_m <= .20 and record.max_height_change_m <= .60, label + ": stayed in the same lower-wall lane, not around or over it")
	unchanged_actor(label)
	return check(record.reached, label + ": actual input reached the opposite endpoint")

func finish() -> void:
	if finished: return
	if not preblock_record.is_empty():
		outcomes.blocked_before = preblock_record.get("actual_blocked", false)
		evidence.preblock = preblock_record
		evidence.preblock_intact_wall_proof = preblock_record.get("intact_wall_witness", {})
		check(preblock_record.get("complete", false), "PREBLOCK observation completed before the deadline")
		check(preblock_record.get("intact_wall_witness", {}).get("ok", false), "native independent ray proved the intact lower wall before C4")
		check(not preblock_record.get("contact_overflow", false), "PREBLOCK saved every native slide contact within explicit bound")
		check(preblock_record.get("actor_policy_unchanged", false), "PREBLOCK preserved original actor/capsule/mask/speed")
		check(preblock_record.max_lane_error_m <= .20 and preblock_record.max_height_change_m <= .60, "PREBLOCK stayed in the same lower-wall lane")
	evidence.preblock_scope = "Approach obstruction is diagnostic only. Foundation/static contacts never abort before floor C4. Final status still requires actual blocked-before and true POSTBLAST W/S endpoints; no transform/collision/step repair is injected."
	evidence.gui_helper_status = "Inherited exact12db; separate owner GUI diagnosis/revision remains necessary before native run."
	super.finish()
