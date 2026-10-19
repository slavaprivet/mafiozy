extends Node
## Explicit current-preview owner callback adapter. No map editing yet.
const Host = preload("res://scripts/map_editor/editor_host_adapter_v3.gd")
const Router = preload("res://scripts/map_editor/editor_input_router_v2.gd")
var editor: Node = self
var active := false
var status := "booting"
var attempts := 0
var enters := 0
var exits := 0
var _main: Node3D
var _host: RefCounted
var _router: Node
var _receipt: Dictionary = {}
var _pause_start_usec := 0
var _k_released := true
var _escape_recovery_armed := false
var _document: Dictionary = {}
var _ground: Dictionary = {}
var _clock_receipt: Dictionary = {}
var _snapshot: Dictionary = {}
var _critical_snapshot: Dictionary = {}
var _source_block_bytes := PackedByteArray()
var _source_session_bytes := PackedByteArray()
var _pause_tree: SceneTree
var _owns_tree_pause := false
var _current_request: Dictionary = {}
const PAUSE_META := "map_editor_pause_owner_token"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_mount")

func _mount() -> void:
	_main = get_parent() as Node3D
	if not is_instance_valid(_main) or not _main.preview_ready:
		status = "actual_main_not_ready"
		return
	_host = Host.new()
	var callbacks := {"pause_gameplay":_pause_gameplay,"cancel_pause":_cancel_pause,"verify_pause":_verify_pause,"resume_gameplay":_resume_gameplay,"transaction_ready":_transaction_ready,"ground_patch":_ground_patch}
	var mounted: Dictionary = _host.mount(_main, callbacks)
	if not mounted.get("ok", false):
		status = str(mounted.get("error", "host_mount"))
		return
	var bound: Dictionary = _host.bind_workspace(self)
	if not bound.get("ok", false):
		status = str(bound.get("error", "workspace_bind"))
		return
	_router = Router.new()
	_router.name = "PauseOnlyInputRouter"
	_main.add_child(_router)
	var routed: Dictionary = _router.configure(_main, _host)
	status = "pause_only_available" if routed.get("ok", false) else str(routed.get("error", "router_bind"))

func _key_k(event: InputEvent) -> bool:
	return event is InputEventKey and (event.physical_keycode == KEY_K or event.keycode == KEY_K)

func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE) and active:
		return true
	if not _key_k(event): return active
	if event.echo: return true
	if not event.pressed:
		_k_released = true
		return true
	if not _k_released: return true
	if active:
		var left: Dictionary = _host.leave(_document.duplicate(true))
		_k_released = false
		status = "pause_only_exited" if left.get("ok", false) else "exit_refused:" + str(left.get("error", "unknown"))
		if left.get("ok", false): exits += 1
	else:
		_k_released = false
		attempts += 1
		var entered: Dictionary = _host.enter()
		status = "pause_only_entered" if entered.get("ok", false) else "entry_refused:" + str(entered.get("error", "unknown")) + ":" + status
		if entered.get("ok", false): enters += 1
	return true

func handle_recovery(event: InputEvent) -> bool:
	# Only a faulted lease may recover, after K and Escape are released and all
	# physical gameplay input is neutral. The press merely arms; release commits.
	if not active or _host == null or not _host._fault or not (event is InputEventKey) or event.echo or (event.physical_keycode != KEY_ESCAPE and event.keycode != KEY_ESCAPE):
		_escape_recovery_armed = false
		return true
	if event.pressed:
		_escape_recovery_armed = _k_released and not _gameplay_input_held(true)
		if not _escape_recovery_armed: status = "recovery_refused:input_not_neutral"
		return true
	var armed := _escape_recovery_armed
	_escape_recovery_armed = false
	if not armed or not _k_released or _gameplay_input_held():
		status = "recovery_refused:input_not_neutral"
	elif _verify_pause(_receipt) and _source_block_bytes == var_to_bytes(_main._block) and _source_session_bytes == var_to_bytes(_main.preview_transport._session):
		_emergency_cancel("manual_current_owner_recovery")
	else:
		status = "recovery_refused:owner_changed"
	return true

func _admission() -> String:
	if not is_instance_valid(_main) or not _main.preview_ready or _main.preview_dead or _main.preview_physics_fault: return "main_or_life"
	if _main.get_tree().paused or active: return "existing_pause"
	if _main.preview_population != null or _main.preview_residents_enabled or OS.get_cmdline_user_args().has("--preview-residents"): return "nav_owner_missing"
	if is_instance_valid(_main.preview_character_impacts): return "impact_owner_missing"
	var player: Variant = _main._player
	if not is_instance_valid(player) or player._pose_authority != &"on_foot" or not player._jump.is_empty() or not player.is_on_floor(): return "player_or_airborne"
	if player._text_control_focused() or not player._free_mouse_look: return "player_input_lease"
	var transport: Variant = _main.preview_transport
	if not is_instance_valid(transport) or not transport.ready_for_play or transport.phase != "ON_FOOT" or transport._e_down or transport._pending_exit or not is_instance_valid(transport.body): return "transport_lease"
	var body: RigidBody3D = transport.body
	if not transport._parked_brake or body.linear_velocity.length_squared() > 0.0001 or body.angular_velocity.length_squared() > 0.0001 or body._contact_buffer.size() != 0 or body._contact_buffer.has_gap(): return "rolling_or_contact_vehicle"
	var melee: Variant = _main.preview_melee
	if not is_instance_valid(melee) or melee.gameplay_clock == null or melee._left_held or melee._right_held: return "melee_lease"
	var practice: Dictionary = melee.snapshot()
	var action: Dictionary = practice.get("action", {})
	var source: Dictionary = practice.get("source", {})
	if not practice.get("ready", false) or not str(practice.get("error", "")).is_empty() or practice.get("cooldown", false) or action.get("start") != null or action.get("held", false) or str(action.get("action", {}).get("type", "none")) != "none" or source.get("block", false) or float(source.get("chargeStartedAt", 0.0)) != 0.0 or not source.get("animation", {}).is_empty() or not source.get("pending", {}).is_empty() or int(source.get("timers", -1)) != 0 or float(melee.gameplay_clock.now_ms()) - float(source.get("lastPunchClientT", 0.0)) < 300.0: return "melee_lease"
	if _gameplay_input_held(): return "held_gameplay_input"
	if not is_instance_valid(_main._printshop): return "printshop_owner_missing"
	for door: Dictionary in _main._printshop._doors.values():
		if not is_equal_approx(float(door.fraction), float(door.target)): return "door_motion_lease"
	return ""

func _gameplay_input_held(ignore_escape := false) -> bool:
	for key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E, KEY_R, KEY_F, KEY_SPACE, KEY_SHIFT, KEY_CTRL, KEY_TAB, KEY_ESCAPE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		if ignore_escape and key == KEY_ESCAPE: continue
		if Input.is_physical_key_pressed(key): return true
	for button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if Input.is_mouse_button_pressed(button): return true
	for action: StringName in [&"preview_move_left", &"preview_move_right", &"preview_move_forward", &"preview_move_back", &"preview_run", &"preview_jump", &"preview_capture_mouse"]:
		if Input.is_action_pressed(action): return true
	return false

func _capture() -> Dictionary:
	var player: CharacterBody3D = _main._player
	var transport: Node3D = _main.preview_transport
	var body: RigidBody3D = transport.body
	var doors := {}
	if is_instance_valid(_main._printshop):
		for key in _main._printshop._doors:
			var door: Dictionary = _main._printshop._doors[key]
			var colliders := []
			for node: Node in door.node.get_children():
				if node is CollisionObject3D: colliders.append([node.get_instance_id(), node.collision_layer, node.collision_mask, node.transform])
				for shape: Node in node.get_children():
					if shape is CollisionShape3D: colliders.append([shape.get_instance_id(), shape.shape.get_instance_id() if shape.shape != null else 0, shape.disabled, shape.transform])
			doors[key] = [float(door.fraction), float(door.target), door.node.get_instance_id(), door.node.transform, colliders]
	var body_shapes := []
	for node: Node in body.get_children():
		if node is CollisionShape3D: body_shapes.append([node.get_instance_id(), node.shape.get_instance_id() if node.shape != null else 0, node.disabled, node.transform])
	var water_id: int = _main._water_host.get_instance_id() if _main._water_host != null else 0
	var water_factory_id: int = _main._water_host._factory.get_instance_id() if _main._water_host != null and _main._water_host._factory != null else 0
	return {"player_transform":player.global_transform,"player_velocity":player.velocity,"pose_epoch":player._pose_epoch,"pose_authority":player._pose_authority,"mouse_look":player._free_mouse_look,"right_mouse_down":player._right_mouse_down,"jump_key_down":player._jump_key_down,"jump_event_consumed":player._jump_event_consumed,"mouse_mode":Input.mouse_mode,"melee_state":_main.preview_melee.snapshot(),"transport_phase":transport.phase,"transport_clock":transport._clock,"transport_sequence":transport._sequence,"body_transform":body.global_transform,"body_linear_velocity":body.linear_velocity,"body_angular_velocity":body.angular_velocity,"body_state":body.snapshot_state(),"body_throttle":body._throttle,"body_steering":body._steering_input,"body_brake":body._brake,"body_handbrake":body._handbrake,"body_contact_sequence":body._contact_sequence,"body_contact_buffer_size":body._contact_buffer.size(),"body_contact_buffer_gap":body._contact_buffer.has_gap(),"body_ledger_keys":body._contact_ledger._keys.duplicate(),"body_ledger_seen":body._contact_ledger._last_seen_ticks.duplicate(),"body_ledger_active":body._contact_ledger._active.duplicate(),"body_ledger_accepted":body._contact_ledger._accepted_tick.duplicate(),"body_collision_layer":body.collision_layer,"body_collision_mask":body.collision_mask,"body_freeze":body.freeze,"body_sleeping":body.sleeping,"body_shapes":body_shapes,"doors":doors,"water_host_id":water_id,"water_factory_id":water_factory_id,"water_time":float(_main._water_host._factory._time) if _main._water_host != null and _main._water_host._factory != null else -1.0}

func _pause_gameplay(request: Dictionary) -> Dictionary:
	_current_request = request.duplicate(true)
	var reason := _admission()
	if not reason.is_empty():
		status = reason
		return {"ok":false,"reason":reason}
	var melee: Variant = _main.preview_melee
	var clock: RefCounted = melee.gameplay_clock
	_clock_receipt = clock.pause(_main, melee)
	if not _clock_receipt.get("ok", false):
		status = "clock_pause_refused"
		return {"ok":false}
	_pause_start_usec = Time.get_ticks_usec()
	_source_block_bytes = var_to_bytes(_main._block)
	_source_session_bytes = var_to_bytes(_main.preview_transport._session)
	var block_digest := _sha256(_source_block_bytes)
	_document = {"schema_version":1,"map_id":"actual-preview-pause-only","metadata":{"block_sha256":block_digest},"objects":[]}
	_ground = {"pause_only":true,"block_sha256":block_digest,"water_id":_main._water_host.get_instance_id() if _main._water_host != null else 0}
	_snapshot = _capture()
	_critical_snapshot = _without_focus_state(_snapshot)
	_receipt = {"owner_id":_main.get_instance_id(),"request_id":request.get("request_id"),"token":"pause-only:" + str(_pause_start_usec),"player_id":_main._player.get_instance_id(),"transport_id":_main.preview_transport.get_instance_id(),"melee_id":melee.get_instance_id()}
	active = true
	_escape_recovery_armed = false
	_pause_tree = _main.get_tree()
	_owns_tree_pause = true
	_pause_tree.set_meta(PAUSE_META, _receipt.token)
	_main.get_tree().paused = true
	return {"ok":true,"receipt":_receipt.duplicate(true)}

func _verify_pause(receipt: Dictionary) -> bool:
	return active and _owns_tree_pause and _pause_tree == _main.get_tree() and _pause_tree.paused and _pause_tree.get_meta(PAUSE_META, "") == _receipt.get("token", "") and receipt == _receipt and is_instance_valid(_main._player) and _main._player.get_instance_id() == int(_receipt.get("player_id", -1)) and is_instance_valid(_main.preview_transport) and _main.preview_transport.get_instance_id() == int(_receipt.get("transport_id", -1)) and is_instance_valid(_main.preview_transport.body) and _main.preview_transport.phase == "ON_FOOT" and is_instance_valid(_main.preview_melee) and _main.preview_melee.get_instance_id() == int(_receipt.get("melee_id", -1)) and _main.preview_melee.gameplay_clock.receipt_live(_clock_receipt) and _main.preview_population == null and not is_instance_valid(_main.preview_character_impacts) and _capture() == _snapshot

func _transaction_ready(receipt: Dictionary) -> bool:
	return _verify_pause(receipt) and _source_block_bytes == var_to_bytes(_main._block) and _source_session_bytes == var_to_bytes(_main.preview_transport._session) and not _gameplay_input_held()

func _ground_patch() -> Dictionary:
	return _ground.duplicate(true) if _verify_pause(_receipt) else {}

func _resume_gameplay(receipt: Dictionary, document: Dictionary, ground: Dictionary) -> Dictionary:
	if not _verify_pause(receipt) or _source_block_bytes != var_to_bytes(_main._block) or _source_session_bytes != var_to_bytes(_main.preview_transport._session) or document != _document or ground != _ground or not _k_released or _gameplay_input_held():
		return {"ok":false,"reason":"pause_only_receipt_or_input"}
	var clock: RefCounted = _main.preview_melee.gameplay_clock
	if not clock.resume(_clock_receipt): return {"ok":false,"reason":"clock_resume"}
	_main.editor_water_pause_usec += maxi(0, Time.get_ticks_usec() - _pause_start_usec)
	_main._last_frame_usec = Time.get_ticks_usec()
	_main.get_tree().paused = false
	_pause_tree.remove_meta(PAUSE_META)
	_owns_tree_pause = false
	active = false
	_escape_recovery_armed = false
	var result := {"ok":true,"owner_id":_main.get_instance_id(),"request_id":receipt.get("request_id")}
	_receipt.clear(); _clock_receipt.clear(); _document.clear(); _ground.clear(); _snapshot.clear(); _critical_snapshot.clear(); _source_block_bytes.clear(); _source_session_bytes.clear(); _current_request.clear(); _pause_start_usec = 0
	return result

func _cancel_pause(request: Dictionary) -> Dictionary:
	if request != _current_request or not is_instance_valid(_main) or request.get("owner_id") != _main.get_instance_id(): return {"ok":false,"reason":"stale_cancel_request"}
	if active and is_instance_valid(_main) and is_instance_valid(_main.preview_melee):
		if request.get("request_id") != _receipt.get("request_id") or not _verify_pause(_receipt) or _source_block_bytes != var_to_bytes(_main._block) or _source_session_bytes != var_to_bytes(_main.preview_transport._session): return {"ok":false,"reason":"changed_pause_state"}
		var clock: RefCounted = _main.preview_melee.gameplay_clock
		if not clock.receipt_live(_clock_receipt) or not clock.resume(_clock_receipt): return {"ok":false}
		_main.editor_water_pause_usec += maxi(0, Time.get_ticks_usec() - _pause_start_usec)
		_main._last_frame_usec = Time.get_ticks_usec()
		_main.get_tree().paused = false
		_pause_tree.remove_meta(PAUSE_META)
		_owns_tree_pause = false
	active = false
	_escape_recovery_armed = false
	_receipt.clear(); _clock_receipt.clear(); _document.clear(); _ground.clear(); _snapshot.clear(); _critical_snapshot.clear(); _source_block_bytes.clear(); _source_session_bytes.clear(); _current_request.clear(); _pause_start_usec = 0
	return {"ok":true}

func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _without_focus_state(snapshot: Dictionary) -> Dictionary:
	var critical := snapshot.duplicate(true)
	for key in ["mouse_look", "right_mouse_down", "jump_key_down", "jump_event_consumed", "mouse_mode", "melee_state"]: critical.erase(key)
	return critical

func _notification(what: int) -> void:
	# The actual player blur callback releases mouse/melee/jump state while the
	# tree is paused. End this read-only lease first, preserving native blur.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _owns_tree_pause:
		_emergency_cancel("focus_out")

func _exit_tree() -> void:
	if _owns_tree_pause:
		_emergency_cancel("workspace_exit")

func _emergency_cancel(reason: String) -> void:
	if not _owns_tree_pause: return
	if _pause_tree == null or _pause_tree.get_meta(PAUSE_META, "") != _receipt.get("token", ""):
		status = "emergency_hold:foreign_tree_owner"
		return
	if is_instance_valid(_main) and not _main.is_queued_for_deletion() and _main.is_inside_tree():
		if not is_instance_valid(_main._player) or not is_instance_valid(_main.preview_transport) or not is_instance_valid(_main.preview_transport.body) or not is_instance_valid(_main.preview_melee):
			status = "emergency_hold:owner_lifetime"
			return
		if _source_block_bytes != var_to_bytes(_main._block) or _source_session_bytes != var_to_bytes(_main.preview_transport._session) or _without_focus_state(_capture()) != _critical_snapshot:
			status = "emergency_hold:changed_owner"
			return
	if is_instance_valid(_main) and is_instance_valid(_main.preview_melee):
		var clock: RefCounted = _main.preview_melee.gameplay_clock
		if clock != null and clock.receipt_live(_clock_receipt):
			if not clock.resume(_clock_receipt): status = "emergency_hold:clock"; return
		elif not _main.is_queued_for_deletion() and _main.is_inside_tree(): status = "emergency_hold:clock_owner"; return
		_main.editor_water_pause_usec += maxi(0, Time.get_ticks_usec() - _pause_start_usec)
		_main._last_frame_usec = Time.get_ticks_usec()
	if _pause_tree.paused: _pause_tree.paused = false
	_pause_tree.remove_meta(PAUSE_META)
	_owns_tree_pause = false
	active = false
	_escape_recovery_armed = false
	status = "emergency_cancel:" + reason
	if is_instance_valid(_router): _router.queue_free()
	_router = null
	_host = null
	_receipt.clear(); _clock_receipt.clear(); _document.clear(); _ground.clear(); _snapshot.clear(); _critical_snapshot.clear(); _source_block_bytes.clear(); _source_session_bytes.clear(); _current_request.clear(); _pause_start_usec = 0
