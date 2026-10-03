extends "test_c4_passage_20261003.gd"
## QA derivative only. No touching the wall is required to plant this charge.
## Same intact-wall comparison and native W/S passage as the frozen parent;
## overridden installation uses actual ground one metre from the wall plane.
const FLOOR_CONTACT_LOCAL := Vector3(-3.0, .09, 4.0)
const FLOOR_ACTOR_Z := 4.9
var ground_contact: Dictionary = {}

func aim_ground_1m() -> bool:
	phase = "aim_ground_one_metre_from_wall"
	var plaza: StaticBody3D = site.get_node_or_null("OriginalPlaza") as StaticBody3D
	if not check(is_instance_valid(plaza), "original plaza is the real target ground body"): return false
	target = site.to_global(FLOOR_CONTACT_LOCAL)
	tracking = true
	var steady := 0
	for index: int in 240:
		await step()
		if finished: tracking = false; return false
		var hit: Dictionary = equipment._target()
		var valid: bool = not hit.is_empty() and hit.body == plaza and hit.normal.y > .95 and hit.point.distance_to(target) < .025
		steady = steady + 1 if valid else 0
		if steady >= 6:
			ground_contact = hit
			break
	tracking = false
	await step(6)
	if finished: return false
	var actual: Dictionary = equipment._target()
	if not check(steady >= 6 and not actual.is_empty() and actual.body == plaza and actual.normal.y > .95 and actual.point.distance_to(target) < .025, "native camera and real equipment query select exact nearby ground"): return false
	ground_contact = actual
	var actor_local: Vector3 = site.to_local(player.global_position)
	var contact_local: Vector3 = site.to_local(actual.point)
	var wall_local_contact: Vector3 = wall_origin.affine_inverse() * actual.point
	var plane_distance: float = absf(wall_local_contact.z)
	# Observe the actual point, not a fabricated horizontal surface/raycast result.
	evidence.floor_1m_aim = {"body":str(plaza.get_path()), "body_id":plaza.get_instance_id(), "contact_local":Observe.vector(contact_local), "contact":Observe.vector(actual.point), "normal":Observe.vector(actual.normal), "actor_local":Observe.vector(actor_local), "ground_distance_from_wall_plane_m":plane_distance, "ground_distance_from_stone_outer_face_m":plane_distance - .17, "actor_distance_from_wall_plane_m":absf(actor_local.z - WALL_Z), "horizontal_actor_to_contact_m":Vector2(actor_local.x - contact_local.x, actor_local.z - contact_local.z).length(), "range_from_actor_chest_m":(player.global_position + Vector3.UP).distance_to(actual.point), "actual_query":equipment.snapshot().target_query.last, "wall_contact_required":false}
	check(absf(plane_distance - 1.0) < .03 and absf(contact_local.y - .09) < .03, "ground contact is one metre from the wall plane at actual plaza height")
	check(actor_local.z >= FLOOR_ACTOR_Z - .02 and actor_local.z - WALL_Z > 1.85, "player stands about1.9m from wall, without touching it during installation")
	return unchanged_actor("floor one-metre aim") and failures.is_empty()

func plant_and_detonate() -> bool:
	# Parent's earlier W is a before-destruction comparison only. Native S now
	# moves away before Q/hold; no touch condition is sent to production equipment.
	if not await walk_line("S_to_floor_placement_distance", KEY_S, FLOOR_ACTOR_Z, 90): return false
	if not await q_choice(equipment._button, "actual inventory C4 for ground") or not await aim_ground_1m(): return false
	phase = "plant_on_ground_one_metre_from_wall"
	hold_actor = player.global_position
	hold_drift = 0.0
	first_charge_frame = -1
	watching_hold = true
	var start_frame: int = Engine.get_physics_frames()
	mouse(MOUSE_BUTTON_LEFT, true)
	await create_timer(3.15, false, true).timeout
	if finished: return false
	var held: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	mouse(MOUSE_BUTTON_LEFT, false)
	await step(3)
	watching_hold = false
	if not check(held and equipment._charges.size() == 1 and equipment.snapshot().mode == "remote", "real 3.15-second LMB plants exactly one ground charge"): return false
	check(first_charge_frame - start_frame >= ceili(3.0 * Engine.physics_ticks_per_second) - 1 and hold_drift <= .04 and callbacks.is_empty(), "normal three-second ground hold completes without movement or early blast")
	var id: String = str(equipment._charges.keys()[0])
	var charge: Node3D = equipment._charges[id].node.get_ref()
	var body: PhysicsBody3D = equipment._charges[id].body.get_ref()
	if not check(is_instance_valid(charge) and body == ground_contact.body and charge.get_parent() == body and body != wall, "charge is physically attached to the observed ground, not substituted onto a wall"): return false
	check(charge.global_transform.is_finite() and charge.global_basis.z.normalized().dot(Vector3.UP) > .95, "ground charge has finite upward attachment")
	check(charge.global_position.distance_to(ground_contact.point + ground_contact.normal * .045) < .035, "physical package lies at real ground contact with production attachment offset")
	var local_frame: Transform3D = charge.transform
	await step(15)
	if finished: return false
	check(charge.transform == local_frame and equipment._charges.size() == 1, "ground attachment survives ordinary native updates")
	var charge_at: Vector3 = charge.global_position
	evidence.placement = {"mode":"ground_one_metre_from_wall", "id":id, "point":Observe.vector(charge_at), "contact":Observe.vector(ground_contact.point), "start_frame":start_frame, "first_placed_frame":first_charge_frame, "drift_m":hold_drift, "ground_body_id":body.get_instance_id(), "wall_id":wall.get_instance_id(), "generation":site.rebuild_generation, "wall_contact_required":false}
	await capture("passage_ground_1m_planted")
	if not await aim_lane(): return false
	if not await walk_line("native_retreat_from_ground_charge", KEY_S, 8.0, 150): return false
	if not check(player.global_position.distance_to(charge_at) > 3.5, "native S retreat safely exits the ground charge radius"): return false
	phase = "ground_detonation_and_support"
	var before_remote: Dictionary = equipment.snapshot()
	var before_blast: Dictionary = blast.snapshot()
	if not check(callbacks.is_empty() and before_blast.events.is_empty() and int(before_blast.pending) == 0 and equipment._charges.size() == 1 and equipment._charges.has(id) and is_instance_valid(charge), "one live physical ground charge and no prior dispatch before the real remote click"): return false
	var prior_fx: int = before_blast.fx.total
	var charge_ref: WeakRef = weakref(charge)
	var physical_item_id: int = charge.get_instance_id()
	var remote_input_frame: int = Engine.get_physics_frames()
	mouse(MOUSE_BUTTON_LEFT, true)
	mouse(MOUSE_BUTTON_LEFT, false)
	if not await observe_ground_remote_commit(id, charge_ref, before_remote, remote_input_frame, physical_item_id): return false
	var settled := false
	stable_ticks = 0
	for index: int in 900:
		await step()
		if finished: return false
		var state: Dictionary = blast.snapshot()
		var support: Dictionary = site._structure.diagnostics()
		var stable: bool = state.pending == 0 and state.events.size() == 1 and state.fx.active == 0 and support.get("ok", false) and not support.get("busy", true) and support.get("pending", -1) == 0 and support.get("state", "") == "stable"
		stable_ticks = stable_ticks + 1 if stable else 0
		if stable_ticks >= 30: settled = true; break
	var after: Dictionary = blast.snapshot()
	evidence.blast = after
	evidence.support_after_blast = site._structure.diagnostics()
	if not check(settled, "native support and FX settle for30ticks after actual ground blast"): return false
	if not check(after.events.size() == 1 and after.fx.total == prior_fx + 1, "ground remote commits exactly one native event and effect"): return false
	var event: Dictionary = after.events[0]
	check(event.event_id == callbacks[0].event_id and event.physical_charge_consumed and event.damage == 1920 and event.radius == 3.2 and event.direct_fragment_budget == 48, "ground event keeps physical item identity and stronger profile")
	check(not event.released.is_empty() and event.released.size() <= 48, "ground charge actually releases bounded building fragments")
	check(wall.get_meta("fracture_active", false) and wall.collision_layer == 0, "blast from ground retires the targeted intact wall through production fracture")
	var released: Array[Dictionary] = []
	for body_id: int in event.released:
		var part: Variant = instance_from_id(body_id)
		check(is_instance_valid(part) and part is RigidBody3D and site.owns_collider(part) and part.get_meta("detached", false), "ground blast release resolves to a real owned detached rigid body")
		if is_instance_valid(part) and part is RigidBody3D:
			released.append({"id":body_id, "path":str(part.get_path()), "layer":part.collision_layer, "mask":part.collision_mask, "position":Observe.vector(part.global_position), "frozen":part.freeze, "parked":part.get_meta("parked", false)})
	evidence.released_bodies = released
	mouse(MOUSE_BUTTON_LEFT, true)
	mouse(MOUSE_BUTTON_LEFT, false)
	await step(3)
	check(callbacks.size() == 1 and blast.snapshot().fx.total == prior_fx + 1, "empty remote cannot replay the ground charge")
	return failures.is_empty()

func observe_ground_remote_commit(placement_id: String, charge_ref: WeakRef, before: Dictionary, input_frame: int, physical_item_id: int) -> bool:
	# Observation only: native input owns delivery, the original callback owns
	# consumption/queueing, and physics owns commit. Never replay/force either.
	var samples: Array[Dictionary] = []
	var proof: Dictionary = {"max_physics_steps":12, "input_frame":input_frame, "placement_id":placement_id, "physical_item_id":physical_item_id, "samples":samples, "complete":false}
	evidence.ground_remote_input_fence = proof
	var expected_event: String = placement_id + ":detonate"
	for observation: int in range(13):
		if finished: return false
		var elapsed_frames: int = Engine.get_physics_frames() - input_frame
		var state: Dictionary = blast.snapshot()
		var current: Dictionary = equipment.snapshot()
		var physical_item: Variant = charge_ref.get_ref()
		var item_valid: bool = is_instance_valid(physical_item)
		var queued_for_deletion: bool = item_valid and physical_item.is_queued_for_deletion()
		var item_visible: bool = item_valid and physical_item.visible
		var item_retired: bool = not item_valid or (queued_for_deletion and not item_visible)
		var event_ids: Array[String] = []
		for event: Dictionary in state.events: event_ids.append(str(event.get("event_id", "")))
		var sample: Dictionary = {"physics_frame":Engine.get_physics_frames(), "elapsed_physics_steps":elapsed_frames, "callbacks":callbacks.size(), "pending":state.pending, "event_ids":event_ids, "charges":equipment._charges.size(), "detonated":current.totals.detonated, "disarmed":current.totals.disarmed, "physical_item_valid":item_valid, "physical_item_queued_for_deletion":queued_for_deletion, "physical_item_visible":item_visible, "physical_item_retired":item_retired}
		samples.append(sample)
		if elapsed_frames > 12:
			proof.reason = "actual_physics_step_deadline"
			return check(false, "native remote commit was not observed within12 actual physics steps")
		if callbacks.size() > 1 or state.events.size() > 1 or int(state.pending) > 1 or int(current.totals.detonated) > int(before.totals.detonated) + 1 or int(current.totals.disarmed) != int(before.totals.disarmed):
			proof.reason = "duplicate_or_disarmed_charge"
			return check(false, "ground remote has exactly one consumption and no extra callback/event/disarm")
		var callback_ok := false
		if callbacks.size() == 1:
			var actual: Dictionary = callbacks[0]
			var response: Variant = actual.get("result")
			callback_ok = actual.get("placement_id") == placement_id and actual.get("event_id") == expected_event and actual.get("damage") == 1920 and actual.get("radius") == 3.2 and int(actual.get("physics_frame", -1)) >= input_frame and int(actual.get("physics_frame", -1)) <= input_frame + 12 and int(actual.get("pending_before", -1)) == 0 and int(actual.get("pending_after", -1)) == 1 and response is Dictionary and response.get("ok") == true and response.get("consumed") == true and response.get("queued") == true and response.get("event_id") == expected_event
			if not callback_ok:
				proof.reason = "native_callback_identity_or_queue"
				return check(false, "actual callback consumes and queues the same unique physical charge")
		var committed := false
		if state.events.size() == 1:
			var event: Dictionary = state.events[0]
			committed = event.get("event_id") == expected_event and event.get("ok") == true and event.get("committed") == true and event.get("physical_charge_consumed") == true and event.get("weapon_id") == "c4" and event.get("damage") == 1920 and event.get("radius") == 3.2 and event.get("direct_fragment_budget") == 48
			if not committed:
				proof.reason = "foreign_or_uncommitted_native_event"
				return check(false, "native commit belongs to the same consumed ground charge and profile")
		var consumed: bool = equipment._charges.is_empty() and current.placed.is_empty() and int(current.totals.detonated) == int(before.totals.detonated) + 1 and item_retired
		if callback_ok and committed and consumed and int(state.pending) == 0:
			proof.complete = true; proof.observed_physics_steps = elapsed_frames
			proof.callback = callbacks[0].duplicate(true); proof.committed_event_id = expected_event
			return check(true, "actual ground remote consumption, unique queue, commit and physical item retirement observed within12 physics steps")
		if observation == 12 or elapsed_frames >= 12: break
		await step()
	proof.reason = "consume_queue_commit_incomplete"
	return check(false, "native ground remote did not complete consume/queue/commit and item retirement within12 physics steps")
