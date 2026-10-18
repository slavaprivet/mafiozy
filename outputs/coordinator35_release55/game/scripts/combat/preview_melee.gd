extends Node
## Explicit local, unarmed practice in the migration quarter. No targets are
## admitted here: this host cannot authorize damage, network hits or NPC life.
const InputPort = preload("res://scripts/combat/melee_input.gd")
const SourcePort = preload("res://scripts/combat/melee_attack_source.gd")
const Pose = preload("res://scripts/combat/melee_pose.gd")
var _player: CharacterBody3D
var _scene: Node3D
var _source: RefCounted
var _input: RefCounted
var _pose: RefCounted
var _physical_pose: RefCounted
var _rng := RandomNumberGenerator.new()
var _state := {}
var _epoch := -1
var _bound := false
var _allowed_last := false
var _left_held := false
var _right_held := false
var _cooldown := false
var _camera_kick := Vector2.ZERO
var _camera_home := Vector2.ZERO
var _telemetry := {}
var _resolved_seq := -1
var last_error := ""

func configure(scene: Node3D, player: CharacterBody3D, physical_pose: RefCounted) -> bool:
	if _bound or not is_instance_valid(scene) or not is_instance_valid(player) or physical_pose == null: return false
	if player._locomotion == null or not is_instance_valid(player._pose_skeleton): return false
	_scene = scene; _player = player; _physical_pose = physical_pose
	_pose = Pose.new()
	if not _pose.configure(player._pose_skeleton, player._pose_motion, player._locomotion._rest_poses, player._model_scale, player._visual): return false
	_source = SourcePort.new()
	if not _source.configure({"state":source_state,"clock_ms":clock_ms,"rng":random_draw,"effect":effect,"resolve_contact":resolve_contact}).get("ok", false): return false
	_input = InputPort.new()
	if not _input.configure({"beginWalkMelee":Callable(_source,"beginWalkMelee"),"setWalkMeleeCharge":Callable(_source,"setWalkMeleeCharge"),"setWalkMeleeBlock":Callable(_source,"setWalkMeleeBlock")}).get("ok",false): return false
	_rng.randomize()
	_camera_home = Vector2(player._camera.h_offset, player._camera.v_offset)
	_epoch = player._pose_epoch; _bound = true
	return true

func _live() -> bool:
	return _bound and is_instance_valid(_scene) and not _scene.is_queued_for_deletion() and is_instance_valid(_player) and not _player.is_queued_for_deletion()

func _allowed() -> bool:
	# Ground practice first. Airborne attack root motion/contact is a separate
	# integration; an existing Max Payne jump must keep its own sole authority.
	return _live() and last_error.is_empty() and not _scene.preview_dead and not _scene.preview_physics_fault and _player._pose_authority == &"on_foot" and _player._free_mouse_look and not _player._text_control_focused() and _player._jump.is_empty() and _player.is_on_floor()

func clock_ms() -> float: return Time.get_ticks_usec() / 1000.0
func random_draw() -> float:
	# randf() can include 1.0; the source's Math.random contract excludes it.
	return float(_rng.randi()) / 4294967296.0

func source_state() -> Dictionary:
	# These false states describe THIS actual offline practice host, which owns
	# no weapons/chat/arrests/jetski/bus/network session. They are not defaults
	# for a future authenticated game owner. That owner needs a different host.
	if not _live(): return {}
	var point: Vector3 = _player.global_position + _scene._origin
	var cell: float = float(_scene._block.metresPerCell)
	return {"walk_active":_live(),"armed":false,"chat_open":_player._text_control_focused(),"menu_open":not _allowed(),"dead":_scene.preview_dead,"arresting":false,"driving":_player._pose_authority != &"on_foot","jetski":false,"swimming_deep":false,"in_bus":false,"ws_open":false,"stunned":1.0 if _scene.preview_physics_fault else 0.0,"player_r":point.z/cell,"player_c":point.x/cell,"player_angle":PI/2-(_player._heading+PI),"mode":"local","stance":"stand"}

func effect(event: Dictionary) -> Dictionary:
	if not _live(): return {"ok":false,"error":"practice_lifetime"}
	match event.get("kind", ""):
		"heading":
			_player._heading = -PI/2 - float(event.angle)
			_player._visual.rotation.y = _player._heading + PI
		"telemetry": _telemetry[str(event.field)] = event.value
		"camera_kick":
			var k := maxf(.35, float(event.power)) * .95
			_camera_kick += Vector2(-cos(float(event.angle)), -sin(float(event.angle))) * k
			_camera_kick = _camera_kick.clamp(Vector2(-6,-6),Vector2(6,6))
		"cooldown": _cooldown = bool(event.active)
		"renew_locks":
			# The practice target registry is empty by construction. No live NPC
			# is registered or silently accepted by this animation-only owner.
			pass
		_: return {"ok":false,"error":"unsupported_practice_effect"}
	return {"ok":true}

func resolve_contact(_context: Dictionary, _request: Dictionary) -> Dictionary:
	return {"accepted":false,"reason":"practice_has_no_admitted_combat_targets"}

func _options() -> Dictionary:
	return {"allowed":_allowed(),"armed":false,"airborne":false,"yaw":_player._visual.global_rotation.y,"airHeight":0.0,"time":clock_ms()/1000.0,"buttons":1 if _left_held else 0}

func cancel(reason: String = "cancel") -> void:
	if not _live(): return
	_left_held = false; _right_held = false; _allowed_last = false
	_state = _input.cancel()
	_source.reset(reason)
	_physical_pose.reset()
	_camera_kick = Vector2.ZERO
	_restore_camera()

func input_event(event: InputEvent) -> bool:
	if not _live() or not event is InputEventMouseButton: return false
	if event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]: return false
	if not _allowed():
		if _left_held or _right_held: cancel("input_locked")
		return false
	if event.button_index == MOUSE_BUTTON_LEFT:
		_left_held = event.pressed
		_state = _input.press(_options()) if event.pressed else _input.release(_options())
	else:
		_right_held = event.pressed
		_state = _input.block(event.pressed)
	_check(_state)
	return true

func advance(delta: float) -> void:
	if not _live(): return
	if _epoch != _player._pose_epoch:
		cancel("pose_owner_changed"); _epoch = _player._pose_epoch
	var allowed := _allowed()
	if not allowed and (_allowed_last or _left_held or _right_held): cancel("control_locked")
	_allowed_last = allowed
	var result: Dictionary = _source.advance()
	_check(result)
	if allowed:
		_state = _input.step(_options()); _check(_state)
		var start: Variant = _state.get("start")
		if start is Dictionary and int(start.seq) != _resolved_seq and clock_ms()-float(start.sourceStartAt) >= float(start.contactWindow[1]):
			# Real empty-registry miss; never forge a contact/confirmed event.
			_source.resolveWalkMelee({"seq":start.seq,"contact":null})
			_resolved_seq = int(start.seq)
	_camera_kick *= pow(.001, maxf(0,delta))
	if absf(_camera_kick.x)<.05: _camera_kick.x=0
	if absf(_camera_kick.y)<.05: _camera_kick.y=0
	if is_instance_valid(_player._camera):
		# Small screen feedback in native camera units; source accumulation and
		# damping above are retained. This offset never moves the actor.
		_player._camera.h_offset = _camera_home.x + _camera_kick.x*.008
		_player._camera.v_offset = _camera_home.y + _camera_kick.y*.008

func _check(result: Dictionary) -> void:
	if result.has("error"):
		last_error = str(result.error)
		_state = {}; _left_held=false; _right_held=false

func decorate(selected: Dictionary, delta: float) -> Dictionary:
	if not _allowed(): return selected
	var sampled: Dictionary = selected
	if not _state.is_empty() and _state.has("action"):
		var status: Dictionary = _player._locomotion.get_status()
		sampled = _pose.sample(selected,_state.action,{},float(status.phase),float(status.gait),_epoch)
	if not sampled.get("valid",false): _check(sampled); return selected
	var physical: Dictionary = _physical_pose.sample(sampled,selected,_epoch,delta)
	if not physical.get("valid",false): _check(physical); return selected
	return physical

func _restore_camera() -> void:
	if is_instance_valid(_player) and is_instance_valid(_player._camera):
		_player._camera.h_offset=_camera_home.x; _player._camera.v_offset=_camera_home.y

func snapshot() -> Dictionary:
	return {"ready":_bound,"error":last_error,"mode":"unarmed_ground_practice","targets":0,"action":_state.duplicate(true),"source":_source.snapshot() if _source!=null else {},"cooldown":_cooldown,"telemetry":_telemetry.duplicate()}

func _exit_tree() -> void:
	_restore_camera()
	if _input!=null: _input.dispose()
	_bound=false
