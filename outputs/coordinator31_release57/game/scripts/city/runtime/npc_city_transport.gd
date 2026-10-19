extends "res://scripts/preview_transport.gd"
## City-era transport host. The living-city scene needs the NPC trip roster,
## parking reservations and door guard that release48's curated preview dropped;
## those members plus the six hooks that drive them are ported here verbatim.
## main.tscn (palazzo preview) keeps using scripts/preview_transport.gd untouched.

const NpcTransportAdapter = preload("res://scripts/npc_transport_adapter.gd")
const NpcParkingPreloader = preload("res://scripts/transport/transport_parking_access_preloader.gd")
var _npc_trip: RefCounted
var _npc_roster: Dictionary
var _npc_parking_reservations := {}
var _npc_parking_data: RefCounted
var _npc_parking_loader: RefCounted
var _npc_block := {}

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
	var birth: Dictionary = runtime.bootstrap_new_session(request)
	if birth.get("code") != "OK":
		return _failure("bootstrap:" + str(birth.get("code")))
	var packet: Dictionary = birth.packet
	_session = packet.session.duplicate(true)
	var pair: Dictionary = packet.physics_births[0]
	var record: Dictionary = pair.vehicle_record
	# Refuse an old provider that ignored the explicit source-world origin.
	var source_bay: Dictionary = runtime.catalog.parking_bay(PARKING_ID)
	var expected := _vector(source_bay.position_m) - origin
	if _vector(record.position_m).distance_to(expected) > 0.0001:
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
	_npc_roster=roster.duplicate(true)
	_npc_parking_loader=NpcParkingPreloader.new()
	_npc_parking_loader.begin(runtime.catalog)
	var npc_block: Variant=get_parent().get("_block")
	if npc_block is Dictionary: _npc_block=npc_block.duplicate(true)
	for id: String in visual.doors:
		_door_amounts[id] = 0.0
	_last_body_position = body.global_position
	_build_hint()
	ready_for_play = true
	return {"ok": true, "vehicle_id": record.vehicle_id, "profile_id": record.profile_id,
		"parking_id": PARKING_ID, "spawn": approach("front_left") + body.global_basis * Vector3(-0.7, 0.08, 0.0)}

func _unhandled_input(event: InputEvent) -> void:
	if _npc_trip!=null and _npc_trip.active(): return
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
	if _npc_parking_loader!=null and _npc_parking_data==null:
		var loaded: Dictionary=_npc_parking_loader.poll()
		if loaded.get("code")=="READY": _npc_parking_data=loaded.parking
	if _npc_trip!=null and _npc_trip.active():
		_npc_physics_process(delta);return
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

func _exit_tree() -> void:
	if _npc_parking_loader!=null: _npc_parking_loader.close()
	if is_instance_valid(runtime) and not token.is_empty():
		runtime.cancel_interaction(token)
	if visual != null:
		if compartments != null:
			compartments.dispose()
		visual.dispose()
	if character_physics != null: character_physics.dispose()

func _vector(value: Dictionary) -> Vector3:
	return Vector3(float(value.x), float(value.y), float(value.z))


## Trusted scene-owner entry point for the explicit native factory-car permit.
## The NPC supplies its original identity; it is never registered as player.
func request_npc_trip(resident_host: RefCounted, binding: Dictionary, activity_owner: RefCounted = null) -> Dictionary:
	if not Thread.is_main_thread() or not ready_for_play or phase!="ON_FOOT" or (_npc_trip!=null and _npc_trip.active()): return {"ok":false,"reason":"transport_owner_busy"}
	_npc_trip=NpcTransportAdapter.new()
	var result: Dictionary=_npc_trip.configure(self,resident_host,binding,activity_owner)
	if not result.get("ok",false): return result
	_e_down=false;_pending_exit=false;_selected_seat=""
	result["adapter"]=_npc_trip
	return result

func _npc_physics_process(delta: float) -> void:
	if not is_instance_valid(body) or body.get_meta("vehicle_id","")!=_vehicle_ref.vehicle_id or body.get_meta("life_generation",0)!=_vehicle_ref.life_generation:
		_npc_trip.retire_from_owner("vehicle_life_changed");return
	var session: Dictionary=runtime.host.diagnostics().session
	if session.get("session_id")!=_session.session_id or session.get("session_generation")!=_session.session_generation:
		_npc_trip.retire_from_owner("transport_session_changed");return
	_clock+=maxi(1,int(round(delta*1000000.0)));_sequence+=1
	_last_delta=delta
	if not is_finite(delta) or delta<=0.0 or delta>.05:
		body.submit_authoritative_control(0.0,0.0,1.0,true,_sequence,_vehicle_ref.vehicle_id,_vehicle_ref.life_generation,_clock)
		return
	if runtime.sync_native_vehicle_pose(_vehicle_ref,body,_clock).get("code")!="OK":
		_npc_trip.retire_from_owner("vehicle_pose_sync_refused")
	else:
		_npc_trip.tick(delta)
	if not _npc_trip.active():
		# Retirement cannot leave a stale throttle latched on this current car.
		_sequence+=1
		body.submit_authoritative_control(0.0,0.0,1.0,true,_sequence,_vehicle_ref.vehicle_id,_vehicle_ref.life_generation,_clock)
		_parked_brake=true
	for seat_id: String in _door_amounts:
		_door_amounts[seat_id]=_npc_trip.door_amount(seat_id)
		visual.set_door_amount(seat_id,_door_amounts[seat_id])
	var state: Dictionary=body.snapshot_state()
	var travelled := (body.global_position-_last_body_position).dot(-body.global_basis.z)
	visual.update_wheels(float(state.steering_angle_rad),travelled,body.linear_velocity.length()<.05)
	_last_body_position=body.global_position
	if compartments.is_animating(): compartments.step(delta)
	if is_instance_valid(_panel): _panel.visible=false
