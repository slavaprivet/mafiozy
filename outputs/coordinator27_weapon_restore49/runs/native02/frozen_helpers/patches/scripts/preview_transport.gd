extends Node3D
## First explicit native new-session vehicle in the existing source quarter.
## Imported saves are never bootstrapped here. No health/economy/server writes.
const Runtime = preload("res://scripts/transport/transport_runtime.gd")
const BodyFactory = preload("res://scripts/vehicle_physics/vehicle_body_factory.gd")
const Visual = preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const OccupantPose = preload("res://scripts/vehicle_visual/vehicle_occupant_pose.gd")
const Compartments = preload("res://scripts/vehicle_visual/vehicle_compartments.gd")
const ExitPose = preload("res://scripts/vehicle_visual/vehicle_exit_pose_blend.gd")
const ExitPresentation = preload("res://scripts/vehicle_visual/vehicle_exit_presentation.gd")
const Timing = preload("res://scripts/transport/transport_timing.gd")
const CharacterPhysics = preload("res://scripts/character_physics/character_physics_driver.gd")
const RagdollTransition = preload("res://scripts/character_physics/ragdoll_actor_transition.gd")
const PARKING_ID := "parking:REBUILD-VISUAL-old_town_narrow_townhouse_v1-004:bay:0"
const ACTOR := {"actor_id": "player", "life_generation": 1}
var runtime: Node3D
var body: RigidBody3D
var visual: RefCounted
var player: CharacterBody3D
var ready_for_play := false
var error := ""
var phase := "ON_FOOT"
var active_seat := ""
var token := ""
var pose_writer: Callable
var _clock := 0
var _sequence := 0
var _vehicle_ref: Dictionary
var _selected_seat := ""
var _e_down := false
var _door_amounts: Dictionary = {}
var _hint: Label
var _key: PanelContainer
var _panel: PanelContainer
var _hint_position := Vector3.ZERO
var _last_body_position := Vector3.ZERO
var _roster_revision := 1
var _session: Dictionary
var _pending_exit := false
var _occupant_pose: RefCounted
var _last_delta := 1.0 / 60.0
var _transition_door := 0.0
var _access_exclude: Array[RID] = []
var _blocked_transition := false
var _seat_collision_owned := false
var _walking_collision_layer := 0
var _walking_collision_mask := 0
var _parked_brake := true
var compartments: RefCounted
var _selected_panel: Dictionary = {}
var _cargo_item_hint_focus := false
var _dead_in_seat := false
var _exit_pose: RefCounted
var _exit_floor_ray: PhysicsRayQueryParameters3D
var _exit_rolls := 1.0
var _exit_presentation_token := ""
var _exit_presentation_progress := 0.0
var _last_exit_presentation: Dictionary = {}
var character_physics: RefCounted
var articulated_enabled := true

func setup(existing_player: CharacterBody3D, origin: Vector3) -> Dictionary:
	if player != null or existing_player == null or not existing_player.is_inside_tree():
		return {"ok": false, "error": "player_binding"}
	player = existing_player
	var catalogue := Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	if not catalogue.get("ok", false):
		return _failure("visual_catalogue")
	runtime = Runtime.new()
	add_child(runtime)
	if not runtime.initialized:
		return _failure("transport_runtime:" + str(runtime.error))
	_clock = maxi(1, Time.get_ticks_usec())
	var session_id := "godot-preview-" + str(Time.get_unix_time_from_system()) + "-" + str(_clock)
	var request := {"session_id": session_id, "session_generation": 1,
		"session_source_clock": _clock, "roster_source_clock": _clock + 1,
		"factory_slot_id": "parked-hatchback", "parking_id": PARKING_ID,
		"origin_m": {"x": origin.x, "y": origin.y, "z": origin.z}}
	var resume:RefCounted=get_tree().root.get_meta("private_restore49") if get_tree().root.has_meta("private_restore49") else null
	var birth:Dictionary
	if resume==null:
		birth=runtime.bootstrap_new_session(request)
	else:
		var restored:Dictionary=resume.transport_packet(self,origin)
		if not restored.get("ok",false):return _failure("resume_packet:"+str(restored))
		var begun:Dictionary=runtime.begin_session(restored.session)
		if begun.code!="OK":return _failure("resume_session")
		var published_restore:Dictionary=runtime.publish_roster(restored.roster)
		if published_restore.code!="OK":return _failure("resume_roster")
		_clock=int(restored.session.source_clock)
		birth={"code":"OK","packet":restored}
		set_meta("local_restore_without_factory",true)
	if birth.get("code") != "OK":
		return _failure("bootstrap:" + str(birth.get("code")))
	var packet: Dictionary = birth.packet
	_session = packet.session.duplicate(true)
	var pair: Dictionary = packet.physics_births[0]
	var record: Dictionary = pair.vehicle_record
	# Refuse an old provider that ignored the explicit source-world origin.
	var source_bay: Dictionary = runtime.catalog.parking_bay(PARKING_ID)
	var expected := _vector(source_bay.position_m) - origin
	if resume==null and _vector(record.position_m).distance_to(expected) > 0.0001:
		return _failure("bootstrap_origin_not_applied")
	var factory := BodyFactory.new()
	body = factory.spawn_from_descriptor(record, pair.profile_descriptor)
	if body == null:
		return _failure("physics:" + factory.last_error)
	var imported := Visual.instantiate_visual(catalogue.entries[record.profile_id], catalogue.base_path)
	if not imported.get("ok", false):
		body.free()
		body = null
		return _failure("visual:" + str(imported.get("error")))
	visual = imported.visual
	add_child(body)
	body.add_child(visual.root)
	# The camera follows this car's occupant; treating its own cabin as an
	# obstacle collapsed the spring arm into the hero's head during exit.
	player._spring_arm.add_excluded_object(body.get_rid())
	compartments = Compartments.new()
	var compartment_setup: Dictionary = compartments.configure(visual)
	if not compartment_setup.get("ok", false):
		return _failure("compartments:" + str(compartment_setup.get("error")))
	_access_exclude = [body.get_rid()]
	_vehicle_ref = {"vehicle_id": record.vehicle_id, "life_generation": record.life_generation}
	player.set_meta("actor_id", ACTOR.actor_id)
	player.set_meta("life_generation", ACTOR.life_generation)
	_occupant_pose = OccupantPose.new()
	if not _occupant_pose.configure(player._pose_skeleton, player._pose_motion, player._locomotion._rest_poses, player._model_scale):
		return _failure("occupant_pose_binding")
	pose_writer = Callable(self, "_apply_transport_pose")
	_exit_pose = ExitPose.new()
	if not _exit_pose.configure(player._pose_skeleton, player._pose_motion, player._locomotion._rest_poses, player._model_scale, player._pose_motion):
		return _failure("exit_pose_binding")
	_exit_floor_ray = PhysicsRayQueryParameters3D.new()
	_exit_floor_ray.collision_mask = player.collision_mask
	_exit_floor_ray.exclude = [player.get_rid(), body.get_rid()]
	_exit_floor_ray.collide_with_areas = false
	if articulated_enabled or OS.get_cmdline_user_args().has("--preview-ragdoll"):
		character_physics = CharacterPhysics.new()
		var physics_setup: Dictionary = character_physics.configure(player, self)
		if not physics_setup.get("ok", false): return _failure("character_physics:" + str(physics_setup.get("error")))
		for rid: RID in character_physics.body.body_rids(): player._spring_arm.add_excluded_object(rid)
		runtime.actor_transition.cancel_all()
		runtime.actor_transition = RagdollTransition.new()
		runtime.actor_transition.configure(runtime.access)
		runtime.actor_transition.character_physics = character_physics
	var roster: Dictionary = packet.roster.duplicate(true)
	_clock += 2
	_roster_revision += 1
	roster.source_clock = _clock
	roster.roster_revision = _roster_revision
	roster.actors = [{"actor_id": ACTOR.actor_id, "life_generation": ACTOR.life_generation, "active": true}]
	var published: Dictionary = runtime.publish_roster(roster)
	if published.get("code") != "OK":
		return _failure("actor_publish:" + str(published.get("code")))
	for id: String in visual.doors:
		_door_amounts[id] = 0.0
	_last_body_position = body.global_position
	_build_hint()
	ready_for_play = true
	return {"ok": true, "vehicle_id": record.vehicle_id, "profile_id": record.profile_id,
		"parking_id": PARKING_ID, "spawn": approach("front_left") + body.global_basis * Vector3(-0.7, 0.08, 0.0)}

func _failure(reason: String) -> Dictionary:
	error = reason
	return {"ok": false, "error": reason}

func approach(seat_id: String) -> Vector3:
	var descriptor: Dictionary = runtime.catalog.seat(body.get_meta("profile_id"), seat_id)
	return body.global_transform * _vector(descriptor.approach_local_m)

func _seat_position(seat_id: String) -> Vector3:
	var descriptor: Dictionary = runtime.catalog.seat(body.get_meta("profile_id"), seat_id)
	return body.global_transform * _vector(descriptor.anchor_local_m)

func _nearest_seat() -> String:
	var best := ""
	var distance := 2.0
	for id: String in _door_amounts:
		var next := player.global_position.distance_to(approach(id))
		if next < distance:
			distance = next
			best = id
	return best

func _nearest_panel() -> Dictionary:
	if phase != "ON_FOOT" or compartments == null or body.linear_velocity.length() > .5 or not body.is_upright(.65):
		return {}
	var local := body.to_local(player.global_position)
	var best: Dictionary = {}
	for kind: String in ["hood", "trunk"]:
		var profile: Dictionary = compartments.access_profile(kind)
		var anchor: Vector3 = profile.position_local_m
		var outward: Vector3 = profile.outward_local
		var offset := local - anchor
		var near := Vector2(offset.x, offset.z).length()
		if offset.dot(outward) < .10 or absf(local.x) > float(profile.get("width", 1.91)) * .5 + .3 or absf(local.y) > 1.8 or near > float(profile.range_m):
			continue
		if best.is_empty() or near < float(best.distance):
			best = {"kind": kind, "distance": near, "anchor": body.to_global(anchor)}
	return best

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(player) or not player._free_mouse_look:
		_e_down = false; _pending_exit = false
		return
	if not ready_for_play or phase in ["DEAD", "FAULTED"] or not event is InputEventKey or event.echo:
		return
	if phase == "ON_FOOT" and player._pose_authority != &"on_foot":
		_e_down = false
		return
	if event.physical_keycode != KEY_E and event.keycode != KEY_E:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return
	if phase == "ON_FOOT" and event.pressed:
		var panel := _nearest_panel()
		if not panel.is_empty():
			compartments.set_open(panel.kind, not compartments.is_open(panel.kind))
			_e_down = false
			get_viewport().set_input_as_handled()
			return
	if phase == "ON_FOOT" and _nearest_seat().is_empty():
		return
	_e_down = event.pressed
	if event.pressed and phase == "EXITING" and _blocked_transition and (character_physics == null or character_physics.mode in ["IDLE", "DONE"]):
		phase = "RETURNING_TO_SEAT"
	if event.pressed and phase == "SEATED":
		_pending_exit = true
	get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if not ready_for_play:
		return
	if character_physics != null and character_physics.mode == "FAULTED":
		phase = "FAULTED"
		_e_down = false
		_pending_exit = false
		if is_instance_valid(body): body.clear_control(_sequence + 1)
		return
	if not is_instance_valid(player) or not is_instance_valid(body) or player.get_meta("actor_id", "") != ACTOR.actor_id or int(player.get_meta("life_generation", 0)) != ACTOR.life_generation or body.get_meta("vehicle_id", "") != _vehicle_ref.vehicle_id or int(body.get_meta("life_generation", 0)) != int(_vehicle_ref.life_generation):
		_drop_binding("LIFETIME_ENDED")
		return
	if phase == "DEAD":
		if _dead_in_seat:
			_follow_seat()
		elif character_physics != null and character_physics.mode == "FALLING":
			var fallen: Dictionary = character_physics.advance(delta, false)
			if fallen.get("valid", false) and fallen.get("pose", {}).get("valid", false): player._apply_selected_pose(fallen.pose)
		body.clear_control(_sequence + 1)
		return
	_clock += maxi(1, int(round(delta * 1000000.0)))
	_last_delta = delta
	_sequence += 1
	var session_now: Dictionary = runtime.host.diagnostics().session
	if session_now.get("session_id") != _session.session_id or session_now.get("session_generation") != _session.session_generation:
		_drop_binding("SESSION_REPLACED")
		return
	if runtime.has_method("sync_native_vehicle_pose"):
		var synced: Dictionary = runtime.sync_native_vehicle_pose(_vehicle_ref, body, _clock)
		if synced.get("code") != "OK":
			_drop_binding("VEHICLE_SYNC:" + str(synced.get("code")))
			return
	if phase in ["SEATED", "EXIT_HOLD", "EXITING", "RETURNING_TO_SEAT"]:
		var current: Dictionary = runtime.host.vehicle_record(_vehicle_ref)
		var occupant: Dictionary = current.get("seats", {}).get(active_seat, {})
		if occupant.get("actor_id") != ACTOR.actor_id or int(occupant.get("life_generation", 0)) != ACTOR.life_generation:
			_drop_binding("SEAT_AUTHORITY_CHANGED")
			return
	var focused := get_viewport().gui_get_focus_owner()
	var allow_input: bool = player._free_mouse_look and not (focused is LineEdit or focused is TextEdit) and (DisplayServer.get_name() == "headless" or get_window().has_focus())
	if not allow_input: _e_down = false; _pending_exit = false
	var pressed := allow_input and _e_down and Input.is_physical_key_pressed(KEY_E)
	var pose_this_tick: Dictionary = {}
	if DisplayServer.get_name() == "headless":
		pressed = allow_input and _e_down
	if phase == "ON_FOOT":
		_selected_panel = _nearest_panel()
		_selected_seat = _nearest_seat()
		if player._pose_authority != &"on_foot":
			_e_down = false
		elif pressed and not _selected_seat.is_empty() and pose_writer.is_valid() and player.is_on_floor():
			active_seat = _selected_seat
			phase = "APPROACH"
			# Transfer the on-foot heading without a first-frame turn toward +Z.
			player.global_rotation.y = player._visual.global_rotation.y - PI
			player._visual.rotation.y = PI
			player.set_preview_pose_authority(&"vehicle")
	elif phase == "APPROACH":
		if not pressed:
			_return_on_foot()
		else:
			var target := approach(active_seat)
			var motion := (target - player.global_position).slide(Vector3.UP).limit_length(2.0 * delta)
			var hit := player.move_and_collide(motion)
			if motion.length_squared() > .000001:
				player.global_rotation.y = lerp_angle(player.global_rotation.y, atan2(-motion.x, -motion.z), minf(1.0, delta * 10.0))
			var gait: Dictionary = player._locomotion.sample(delta, motion / maxf(delta, .000001) if hit == null else Vector3.ZERO, true)
			if gait.get("valid", false):
				player._apply_selected_pose(gait)
			if hit != null:
				_return_on_foot()
			elif player.global_position.distance_to(target) <= 0.20:
				var begun: Dictionary = runtime.begin_board(ACTOR, _vehicle_ref, active_seat, _clock, player.global_position, true, _access_exclude)
				if begun.get("code") == "HOLDING":
					token = begun.token
					phase = "HOLD"
				else:
					error = str(begun.get("code"))
					_return_on_foot()
	elif phase == "HOLD":
		var idle: Dictionary = player._locomotion.sample(delta, Vector3.ZERO, true)
		if idle.get("valid", false):
			player._apply_selected_pose(idle)
		var result: Dictionary = runtime.advance_interaction(token, pressed, _clock, player.global_position, true, _access_exclude)
		if result.get("code") == "TRANSITION_REQUIRED":
			var started: Dictionary = runtime.begin_actor_transition(token, _clock, player, body)
			if started.get("code") == "ACTIVE":
				phase = "BOARDING"
			else:
				error = str(started.get("code"))
				_return_on_foot()
		elif result.get("code") != "HOLDING":
			_return_on_foot()
	elif phase in ["BOARDING", "EXITING"]:
		var transition: Dictionary = runtime.advance_actor_transition(token, delta, _clock)
		var pose: Dictionary = transition.get("pose", transition.get("physical", {}).get("pose", transition if transition.has("fold") or transition.has("body_progress") else {}))
		if not pose.is_empty() and pose_writer.is_valid():
			pose_this_tick = pose
			_transition_door = float(pose.get("door", 0.0))
		if transition.get("code") == "BOARDED":
			_blocked_transition = false
			phase = "SEATED"
			token = ""
			_follow_seat()
		elif transition.get("code") == "EXITED":
			_blocked_transition = false
			token = ""
			_return_on_foot()
		elif transition.get("code") == "BLOCKED":
			# Keep the live provider/seat and its collision exception. A blocked
			# sweep cannot grant walking authority or release occupancy.
			_blocked_transition = true
			error = "BLOCKED"
		elif transition.get("code") in ["ACTIVE", "TRANSITION_ACTIVE", "TRANSITION_UNCONFIRMED"]:
			_blocked_transition = false
			if error == "BLOCKED":
				error = ""
		else:
			error = str(transition.get("code"))
			_drop_binding(error)
	elif phase == "RETURNING_TO_SEAT":
		var target := _seat_position(active_seat)
		var lateral := (target - player.global_position).slide(Vector3.UP).limit_length(1.5 * delta)
		player.move_and_collide(lateral)
		player.move_and_collide(Vector3.UP * clampf(target.y - player.global_position.y, -delta, delta))
		pose_this_tick = {"fold": 1.0, "progress": 1.0, "phase": "SEATED"}
		if player.global_position.distance_to(target) < .08:
			runtime.cancel_interaction(token)
			token = ""
			phase = "SEATED"
			_blocked_transition = false
			error = ""
	elif phase == "SEATED":
		# Keep the seated body attached to the actual vehicle transform. Source
		# admission/exit producer owns when the actor may leave this occupied seat.
		_follow_seat()
		if pose_writer.is_valid():
			pose_this_tick = {"fold": 1.0, "progress": 1.0, "phase": "SEATED"}
		if active_seat == "front_left":
			var drive := Input.get_axis("preview_move_back", "preview_move_forward") if allow_input else 0.0
			var turn := Input.get_axis("preview_move_left", "preview_move_right") if allow_input else 0.0
			body.submit_authoritative_control(drive, -turn, 0.0 if allow_input else 1.0, allow_input and Input.is_physical_key_pressed(KEY_SPACE), _sequence, _vehicle_ref.vehicle_id, _vehicle_ref.life_generation, _clock)
		if _pending_exit:
			_pending_exit = false
			var begun: Dictionary = runtime.begin_exit(ACTOR, _vehicle_ref, active_seat, _clock, player.global_position, true, _access_exclude)
			if begun.get("code") == "HOLDING":
				token = begun.token
				phase = "EXIT_HOLD"
				_parked_brake = false
	elif phase == "EXIT_HOLD":
		_follow_seat()
		pose_this_tick = {"fold": 1.0, "progress": 1.0, "phase": "SEATED"}
		var result: Dictionary = runtime.advance_interaction(token, pressed, _clock, player.global_position, true, _access_exclude)
		if result.get("code") == "TRANSITION_REQUIRED":
			_restore_walking_collision()
			_exit_rolls = 2.0 if body.linear_velocity.length() > 14.0 else 1.0
			var started: Dictionary = runtime.begin_actor_transition(token, _clock, player, body)
			if started.get("code") == "ACTIVE":
				phase = "EXITING"
			else:
				error = str(started.get("code"))
				runtime.cancel_interaction(token)
				token = ""
				phase = "SEATED"
		elif result.get("code") != "HOLDING":
			token = ""
			phase = "SEATED"
			error = "exit_hold:" + str(result.get("code"))
	if phase != "SEATED":
		# Leaving releases the controls, not the vehicle's momentum. The initial
		# parking brake must never be silently re-applied to a rolling empty car.
		body.submit_authoritative_control(0.0, 0.0, 1.0 if _parked_brake else 0.0, _parked_brake, _sequence, _vehicle_ref.vehicle_id, _vehicle_ref.life_generation, _clock)
	for id: String in _door_amounts:
		var target_amount := 1.0 if id == active_seat and phase in ["HOLD", "BOARDING", "EXIT_HOLD", "EXITING", "RETURNING_TO_SEAT"] else 0.0
		if id == active_seat and phase in ["BOARDING", "EXITING"]:
			target_amount = _transition_door
		_door_amounts[id] = move_toward(float(_door_amounts[id]), target_amount, delta * 2.0)
		visual.set_door_amount(id, _door_amounts[id])
	var state: Dictionary = body.snapshot_state()
	var travelled := (body.global_position - _last_body_position).dot(-body.global_basis.z)
	visual.update_wheels(float(state.steering_angle_rad), travelled, _parked_brake if phase != "SEATED" else allow_input and Input.is_physical_key_pressed(KEY_SPACE))
	if body.linear_velocity.length() > 2.5:
		for kind: String in ["hood", "trunk"]:
			if compartments.is_open(kind):
				compartments.set_open(kind, false)
	if compartments.is_animating():
		compartments.step(delta)
	# Hands use this frame's actual hinge/wheel transforms; apply once to avoid
	# advancing the pose sampler's smoothing twice during a single tick.
	if not pose_this_tick.is_empty() and phase != "ON_FOOT" and pose_writer.is_valid():
		pose_writer.call(pose_this_tick, active_seat, body, visual)
	# External approach/boarding motion rotates the actor while the player
	# controller is suspended. Preserve the user's world camera heading every
	# tick, rather than inheriting those rotations until the first seated frame.
	player._update_camera_rotation()
	_last_body_position = body.global_position
	_update_hint()

func _return_on_foot() -> void:
	_exit_presentation_token = ""
	_exit_presentation_progress = 0.0
	_restore_walking_collision()
	if not token.is_empty():
		runtime.cancel_interaction(token)
	token = ""
	phase = "ON_FOOT"
	active_seat = ""
	_e_down = false
	_pending_exit = false
	error = ""
	var heading := player.global_rotation.y
	player.global_rotation = Vector3.ZERO
	player._heading = heading
	player._visual.rotation.y = heading + PI
	player.set_preview_pose_authority(&"on_foot")
	player._yaw_pivot.position = Vector3(0, player.model_target_height * .79, 0)

func _drop_binding(reason: String) -> void:
	error = reason
	phase = "UNAVAILABLE"
	ready_for_play = false
	if is_instance_valid(body):
		body.clear_control(_sequence + 1)
	if is_instance_valid(runtime) and not token.is_empty():
		runtime.cancel_interaction(token)
	token = ""
	# A replaced preview session retires this session's presentation, rather
	# than leaving the surviving player locked to a seat in the obsolete world.
	# No pose/position is written to a player whose life was replaced.
	if reason == "SESSION_REPLACED":
		if visual != null:
			visual.dispose()
		if is_instance_valid(body) and body.get_meta("vehicle_id", "") == _vehicle_ref.vehicle_id and int(body.get_meta("life_generation", 0)) == int(_vehicle_ref.life_generation):
			body.queue_free()
		if is_instance_valid(player) and player.get_meta("actor_id", "") == ACTOR.actor_id and int(player.get_meta("life_generation", 0)) == ACTOR.life_generation:
			_restore_walking_collision()
			player.global_rotation = Vector3.ZERO
			player.set_preview_pose_authority(&"on_foot")
	if is_instance_valid(_panel):
		_panel.visible = false

func _follow_seat() -> void:
	# Once admitted, the occupant is part of the vehicle, not a second walking
	# capsule sweeping against walls/floors. Those sweeps stranded the rider when
	# the vehicle rolled or fell. Restore the exact walking filters before exit.
	if not _seat_collision_owned:
		_walking_collision_layer = player.collision_layer
		_walking_collision_mask = player.collision_mask
		_seat_collision_owned = true
		player.collision_layer = 0
		player.collision_mask = 0
	player.global_transform = Transform3D(body.global_basis.orthonormalized(), _seat_position(active_seat))
	player.velocity = Vector3.ZERO
	# Keep the orbit camera upright while the character rolls with the cabin.
	player._yaw_pivot.global_position = player.global_position + Vector3.UP * player.model_target_height * .79
	player._update_camera_rotation()

func mark_dead() -> void:
	if phase == "DEAD":
		return
	_dead_in_seat = phase in ["SEATED", "EXIT_HOLD"]
	if not _dead_in_seat:
		_restore_walking_collision()
	phase = "DEAD"
	_e_down = false
	_pending_exit = false
	player.set_preview_pose_authority(&"dead")
	if character_physics != null: character_physics.continue_after_death()
	if _dead_in_seat:
		_apply_transport_pose({"fold": 1.0}, active_seat, body, visual)
	_panel.visible = false

func _restore_walking_collision() -> void:
	if not _seat_collision_owned or not is_instance_valid(player):
		return
	player.collision_layer = _walking_collision_layer
	player.collision_mask = _walking_collision_mask
	_seat_collision_owned = false
	var forward := -player.global_basis.z
	var yaw: float = atan2(-forward.x, -forward.z) if forward.slide(Vector3.UP).length_squared() > .000001 else float(player._heading)
	player.global_basis = Basis(Vector3.UP, yaw)
	player._yaw_pivot.position = Vector3(0, player.model_target_height * .79, 0)
	player._update_camera_rotation()

func _apply_transport_pose(state: Dictionary, seat_id: String, _body: RigidBody3D, _visual: RefCounted) -> void:
	if state.get("source_phase") == "exit_ragdoll":
		var physical_pose: Dictionary = state.get("physical_pose", {})
		if physical_pose.get("valid", false):
			player._apply_selected_pose(physical_pose)
			var anchor: Vector3 = character_physics.last_snapshot.get("anchor_world", player.global_position + Vector3.UP)
			var focus_y := clampf(anchor.y - player.global_position.y + .35, .5, player.model_target_height * .79)
			player._yaw_pivot.position.y = lerpf(player._yaw_pivot.position.y, focus_y, 1.0 - exp(-_last_delta * 8.0))
		return
	if state.get("source_phase") == "exit_body":
		if state.get("exit_kind") == "tumble":
			var pose_token := str(state.get("token", token))
			if pose_token != _exit_presentation_token:
				_exit_presentation_token = pose_token
				_exit_presentation_progress = 0.0
			_last_exit_presentation = ExitPresentation.sample(float(state.get("recovery_elapsed_s", 0.0)), Timing.EXIT_TUMBLE_RECOVERY_S, float(state.get("recovery_initial_speed_mps", 0.0)), _exit_presentation_progress, bool(state.get("blocked", false)))
			if not _last_exit_presentation.get("valid", false):
				error = "exit_presentation_invalid"
				return
			_exit_presentation_progress = float(_last_exit_presentation.visual_progress)
			var rolled: Dictionary = _exit_pose.sample(_exit_presentation_progress, _exit_rolls * float(_last_exit_presentation.rolls_scale), Callable(self, "_exit_floor_height"), null, player._pose_epoch)
			if rolled.get("valid", false):
				# The source exit hop is presentation only. Swept native movement
				# remains the sole writer of the physical character position.
				rolled.visual_offset += player._pose_motion.get_parent().global_basis.inverse() * Vector3.UP * float(state.get("body_hop_m", 0.0))
				player._apply_selected_pose(rolled)
				var focus_y := clampf(float(rolled.skin_height) * .65, .45, float(player.model_target_height) * .79)
				player._yaw_pivot.position.y = lerpf(player._yaw_pivot.position.y, focus_y, 1.0 - exp(-_last_delta * 8.0))
			else:
				error = "exit_pose:" + str(rolled.get("reason", "invalid"))
		else:
			var walking: Dictionary = player._locomotion.sample(_last_delta, Vector3.ZERO, true)
			if walking.get("valid", false):
				player._apply_selected_pose(walking)
		_transition_door = float(state.get("door", 0.0))
		return
	var seat: Dictionary = runtime.catalog.seat(body.get_meta("profile_id"), seat_id)
	var profile: Dictionary = runtime.catalog.profile(body.get_meta("profile_id"))
	player._visual.rotation.y = PI
	var wheel: Node3D = visual.nodes[visual.entry.controls.steering_wheel]
	var door: Node3D = visual.doors[seat_id]
	# Source handle is exported at amount=0; transform it back to the closed
	# source hinge frame, then apply the actual animated hinge world transform.
	var door_record: Dictionary = {}
	for item: Dictionary in profile.doors:
		if item.id == seat_id:
			door_record = item
	var handle_local := _vector(door_record.handle_local_m) - _vector(door_record.hinge_local_m)
	# The GLB keeps source (+Z) local hinge axes beneath the RY(pi) wrapper.
	handle_local = Vector3(-handle_local.x, handle_local.y, -handle_local.z)
	var source_pose := state.duplicate()
	for source_key: String in {"inner_leg": "innerLeg", "outer_leg": "outerLeg", "hand_reach": "handReach", "close_reach": "closeReach", "source_phase": "phase"}:
		if source_pose.has(source_key):
			var target_key: String = {"inner_leg": "innerLeg", "outer_leg": "outerLeg", "hand_reach": "handReach", "close_reach": "closeReach", "source_phase": "phase"}[source_key]
			source_pose[target_key] = source_pose[source_key]
	var options := {"fold": float(state.get("fold", 0.0)), "reach": float(state.get("reach", 0.0)), "pose": source_pose,
		"gripBlend": smoothstep(.62, 1.0, float(state.get("fold", 0.0))),
		"side": int(seat.source_side), "dt": _last_delta, "steer": float(body.snapshot_state().steering_angle_rad),
		"steering_left": wheel.to_global(Vector3(.16 * cos(PI / 6.0), .08, -.023)),
		"steering_right": wheel.to_global(Vector3(-.16 * cos(PI / 6.0), .08, -.023)),
		"doorGrip": door.to_global(handle_local), "doorGripBlend": maxf(float(state.get("hand_reach", 0.0)), float(state.get("close_reach", 0.0)))}
	var sampled: Dictionary = _occupant_pose.sample({"id": seat_id, "can_drive": seat.can_drive, "side": seat.source_side,
		"recline": profile.cabin_derivation.seat_recline_rad}, options, null, player._pose_epoch)
	if sampled.get("valid", false) and state.get("source_phase") == "exit" and state.get("exit_kind") == "tumble":
		sampled = _exit_pose.blend_release(sampled, float(state.get("progress", 0.0)), Callable(self, "_exit_floor_height"), null, player._pose_epoch)
	if sampled.get("valid", false):
		player._apply_selected_pose(sampled)
	else:
		error = "occupant_pose_rejected"
	_transition_door = float(state.get("door", 0.0))

func _exit_floor_height(x: float, z: float) -> float:
	_exit_floor_ray.from = Vector3(x, player.global_position.y + 2.0, z)
	_exit_floor_ray.to = Vector3(x, player.global_position.y - 2.0, z)
	var hit := get_world_3d().direct_space_state.intersect_ray(_exit_floor_ray)
	return float(hit.position.y) if not hit.is_empty() else NAN

func _build_hint() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.06, 0.9)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(_panel)
	var row := HBoxContainer.new()
	_panel.add_child(row)
	_key = PanelContainer.new()
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color("f0c86b")
	_key.add_theme_stylebox_override("panel", key_style)
	_key.custom_minimum_size = Vector2(24, 24)
	row.add_child(_key)
	var label := Label.new()
	label.text = "E"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("15191b"))
	_key.add_child(label)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 14)
	row.add_child(_hint)

func set_cargo_item_hint_focus(focused: bool) -> void:
	# Presentation cache supplied by cargo's existing .15s aim sample; never
	# runs item ray picking from the transport physics/update loop.
	if _cargo_item_hint_focus == focused: return
	_cargo_item_hint_focus = focused
	if ready_for_play and is_instance_valid(_panel) and is_inside_tree(): _update_hint()

func _update_hint() -> void:
	if character_physics != null and character_physics.mode in ["FALLING", "GETTING_UP", "FAULTED"]:
		_panel.visible = false
		return
	if phase == "ON_FOOT" and not _selected_panel.is_empty():
		var kind: String = _selected_panel.kind
		if kind == "trunk" and _cargo_item_hint_focus and compartments.is_open("trunk"):
			_panel.visible = false
			return
		_panel.visible = true
		_hint.text = "  " + ("Закрыть " if compartments.is_open(kind) else "Открыть ") + ("капот" if kind == "hood" else "багажник")
		_hint_position = _selected_panel.anchor + Vector3.UP * .45
		_panel.reset_size()
		return
	var seat := active_seat if not active_seat.is_empty() else _selected_seat
	_panel.visible = not seat.is_empty()
	if not _panel.visible:
		return
	_hint.text = "  Удерживай — выйти" if phase == "SEATED" else "  Удерживай — сесть: " + ("водитель" if seat == "front_left" else "пассажир")
	if phase in ["BOARDING", "EXITING"]:
		_hint.text = "  Посадка…" if phase == "BOARDING" else "  Выход…"
	if _blocked_transition:
		_hint.text = "  Проход занят. Нажми E — вернуться" if phase == "EXITING" else "  Проход занят"
	_hint_position = approach(seat) + Vector3.UP * 2.15
	_panel.reset_size()

func _process(_delta: float) -> void:
	if not ready_for_play or _panel == null or not _panel.visible:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(_hint_position):
		_panel.visible = false
		return
	_panel.position = camera.unproject_position(_hint_position) - Vector2(_panel.size.x * .5, _panel.size.y)

func _exit_tree() -> void:
	if is_instance_valid(runtime) and not token.is_empty():
		runtime.cancel_interaction(token)
	if visual != null:
		if compartments != null:
			compartments.dispose()
		visual.dispose()
	if character_physics != null: character_physics.dispose()

func _vector(value: Dictionary) -> Vector3:
	return Vector3(float(value.x), float(value.y), float(value.z))
