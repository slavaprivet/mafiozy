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
var _gesture_x := 0.0
var _gesture_last_side := 0
const GESTURE_PIXELS := 22.0
const FREE_MOUSE_SCALE := 0.0031
const FREE_SLEW := 10.5
const FREE_NOISE := 1.2
var _free_command := {"left":Vector2.ZERO,"right":Vector2.ZERO}
var _free_hand := {"left":Vector2.ZERO,"right":Vector2.ZERO}
var _free_side := ""
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

func free_mode() -> bool:
	return _live() and bool(_scene.get("castle_map"))

func steering() -> bool:
	return free_mode() and _allowed() and (_left_held or _right_held)

func _allowed() -> bool:
	# Ground practice first. Airborne attack root motion/contact is a separate
	# integration; an existing Max Payne jump must keep its own sole authority.
	return _live() and last_error.is_empty() and not _scene.preview_dead and not _scene.preview_physics_fault and _player._pose_authority == &"on_foot" and _player._free_mouse_look and not _player._text_control_focused() and (free_mode() or (_player._jump.is_empty() and _player.is_on_floor()))

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
	_gesture_x=0.0; _gesture_last_side=0
	_free_side=""
	for side: String in ["left","right"]:
		_free_command[side]=Vector2.ZERO
		_free_hand[side]=Vector2.ZERO
	_state = _input.cancel()
	_source.reset(reason)
	_physical_pose.reset()
	_camera_kick = Vector2.ZERO
	_restore_camera()

func input_event(event: InputEvent) -> bool:
	if not _live(): return false
	if free_mode():
		return _free_input_event(event)
	if event is InputEventMouseMotion:
		if not _allowed() or not (_left_held or _right_held): return false
		var motion := event as InputEventMouseMotion
		if not is_finite(motion.relative.x): return false
		_gesture_x=clampf(_gesture_x+motion.relative.x,-GESTURE_PIXELS*2.0,GESTURE_PIXELS*2.0)
		var side := -1 if _gesture_x < -GESTURE_PIXELS else 1 if _gesture_x > GESTURE_PIXELS else 0
		if side != 0 and (_gesture_last_side != side or not (_left_held and _right_held)):
			var strike_side := side if _left_held and _right_held else -1 if _left_held else 1
			_state=_input.strike(strike_side,_options()); _check(_state)
			if _state.get("started",false):
				_gesture_last_side=side
		if side != 0: _gesture_x=0.0
		return true
	if not event is InputEventMouseButton: return false
	if event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]: return false
	if not _allowed():
		if _left_held or _right_held: cancel("input_locked")
		return false
	if event.button_index == MOUSE_BUTTON_LEFT:
		_left_held = event.pressed
	else:
		_right_held = event.pressed
	_gesture_x=0.0
	if not (_left_held and _right_held): _gesture_last_side=0
	return true

func _free_input_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]: return false
		if not _allowed(): return false
		if event.button_index==MOUSE_BUTTON_LEFT: _left_held=event.pressed
		else: _right_held=event.pressed
		if not _left_held and not _right_held: _free_side=""
		elif _free_side=="left" and not _left_held: _free_side="right"
		elif _free_side=="right" and not _right_held: _free_side="left"
		return true
	if not event is InputEventMouseMotion or not steering(): return false
	var motion:=event as InputEventMouseMotion
	if not motion.relative.is_finite() or absf(motion.relative.x)+absf(motion.relative.y)<FREE_NOISE: return true
	var side: String="left" if _left_held and not _right_held else "right" if _right_held and not _left_held else "left" if motion.relative.x < -FREE_NOISE else "right" if motion.relative.x > FREE_NOISE else _free_side
	if side.is_empty(): return true
	_free_side=side
	_free_command[side]=(_free_command[side] + Vector2(motion.relative.x,-motion.relative.y)*FREE_MOUSE_SCALE).clamp(Vector2(-1,-1),Vector2(1,1))
	# The camera stays put. Face the target with a bounded torso excursion
	# during physics, as sword steering does; an instant full body turn would
	# cancel most of the fist's visible lateral arc.
	return true

func advance(delta: float) -> void:
	if not _live(): return
	if free_mode():
		_free_advance(delta)
		return
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

func _free_advance(delta: float) -> void:
	if _epoch != _player._pose_epoch:
		cancel("pose_owner_changed"); _epoch=_player._pose_epoch
	if not _allowed():
		if _left_held or _right_held: cancel("control_locked")
		return
	for side: String in ["left","right"]:
		var held: bool=_left_held if side=="left" else _right_held
		if not held: _free_command[side]=(_free_command[side] as Vector2).lerp(Vector2.ZERO,clampf(4.5*delta,0,1))
		var difference: Vector2=(_free_command[side] as Vector2)-(_free_hand[side] as Vector2)
		_free_hand[side]=(_free_hand[side] as Vector2)+difference.limit_length(FREE_SLEW*delta)
	_state={"action":{"type":"free_fist","held_left":_left_held,"held_right":_right_held,
		"active_side":_free_side,"command_left":_free_hand.left,"command_right":_free_hand.right,
		"camera_basis":_player._camera.global_basis}}
	if steering():
		var view_forward: Vector3=-_player._camera.global_basis.z
		if Vector2(view_forward.x,view_forward.z).length_squared()>.01:
			var camera_yaw: float=atan2(view_forward.x,view_forward.z)
			var active_command: Vector2=_free_hand.get(_free_side,Vector2.ZERO)
			var wanted_yaw: float=camera_yaw+clampf(active_command.x*.55,-.55,.55)
			var yaw_error: float=wrapf(wanted_yaw-_player._visual.global_rotation.y,-PI,PI)
			_player._visual.rotation.y+=clampf(yaw_error,-8.0*delta,8.0*delta)
			_player._heading=_player._visual.rotation.y-deg_to_rad(_player.visual_yaw_degrees)

func _check(result: Dictionary) -> void:
	if result.has("error"):
		last_error = str(result.error)
		_state = {}; _left_held=false; _right_held=false

func decorate(selected: Dictionary, delta: float) -> Dictionary:
	if not _allowed(): return selected
	var sampled: Dictionary = selected
	if free_mode():
		var status: Dictionary=_player._locomotion.get_status()
		sampled=_pose.sample(selected,_state.get("action",{"type":"free_fist"}),{},float(status.phase),float(status.gait),_epoch)
		if not sampled.get("valid",false): _check(sampled); return selected
		var free_physical: Dictionary=_physical_pose.sample(sampled,selected,_epoch,delta)
		return free_physical if free_physical.get("valid",false) else selected
	if not _state.is_empty() and _state.has("action"):
		var status: Dictionary = _player._locomotion.get_status()
		var action: Dictionary=_state.action.duplicate()
		action.blocking=_left_held and _right_held and action.get("type", "none")=="none"
		action.ready_side=2 if _left_held and _right_held else -1 if _left_held else 1 if _right_held else 0
		sampled = _pose.sample(selected,action,{},float(status.phase),float(status.gait),_epoch)
	elif _left_held or _right_held:
		var status: Dictionary=_player._locomotion.get_status()
		sampled=_pose.sample(selected,{"type":"none","side":1,"blocking":_left_held and _right_held,"ready_side":2 if _left_held and _right_held else -1 if _left_held else 1,"charge":0.0},{},float(status.phase),float(status.gait),_epoch)
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
