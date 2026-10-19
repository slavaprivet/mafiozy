extends RefCounted
## Life owns priority and the weighted ambient/shop/continue decision.
## This controller owns only one short action and its physical bench approach.
const Pose = preload("res://scripts/npc_ambient/ambient_pose28.gd")
const Props = preload("res://scripts/npc_ambient/ambient_props28.gd")
const Benches = preload("res://scripts/npc_ambient/ambient_benches28.gd")
const Windows29 = preload("res://scripts/npc_ambient/ambient_windows29.gd")
const Route = preload("res://scripts/hospital/npc_physical_route51.gd")
const Driver = preload("res://scripts/hospital/npc_simple_hospital.gd")
const TITLES := ["Посидеть на лавочке", "Почитать книгу", "Осмотреться", "Проверить часы", "Поправить рукава", "Потянуться", "Потереть ладони", "Размять шею", "Размять плечи", "Поправить воротник", "Протереть лоб", "Почесать голову", "Осмотреть витрину", "Посмотреть вдаль", "Почитать газету", "Сфотографировать вид", "Осмотреть карман", "Посмотреть телефон"]
const MAX_APPROACH_S := 6.0
var _host: RefCounted
var _token: Dictionary = {}
var _scene: Node3D
var _body: CharacterBody3D
var _map: RID
var _route: RefCounted
var _driver: RefCounted
var _benches: RefCounted
var _props: RefCounted
var _rng := RandomNumberGenerator.new()
var _phase := "IDLE"
var _kind := ""
var _previous := ""
var _serial := 0
var _elapsed := 0.0
var _duration := 0.0
var _age := 0.0
var _anchor := Vector3.ZERO
var _face := Vector3.ZERO
var _seat: Dictionary = {}
var _window: WeakRef
var _frame := -1
var _pose_frames := 0
var _roams_completed := 0
var _last_reason := ""
var _configured := false
var _seed_label := "randomized"

func configure(host: RefCounted, token: Dictionary, scene: Node3D, map: RID) -> bool:
	if _configured or not is_instance_valid(host) or not host.target_current(token) or not is_instance_valid(scene): return false
	var actor: Variant = token.get("body")
	if not actor is CharacterBody3D or not is_instance_valid(actor): return false
	_host = host; _token = token.duplicate(); _scene = scene; _body = actor; _map = map
	_route = Route.new()
	if not _route.configure(_body): return false
	_benches = Benches.new(); _benches.configure(scene)
	_props = Props.new(); _rng.randomize()
	var qa_seed := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--city-sandbox-seed="): qa_seed = argument.trim_prefix("--city-sandbox-seed=")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--npc-ambient28-seed="): qa_seed = argument.trim_prefix("--npc-ambient28-seed=")
	if not qa_seed.is_empty() and qa_seed.is_valid_int():
		_rng.seed = int(qa_seed) + int(str(_token.source_id).hash()) + 2731
		_seed_label = qa_seed
	_body.tree_exiting.connect(Callable(self,"cancel").bind("body_exiting"))
	_configured = true
	_log("configured", "real_benches=" + str(_benches.count()))
	return true

func notify_roam_completed() -> void:
	_roams_completed += 1

func active() -> bool:
	return _phase in ["APPROACH", "DOCK", "ALIGN", "ACTING"]

func _current() -> bool:
	return _configured and is_instance_valid(_host) and is_instance_valid(_body) and _body.is_inside_tree() and not _body.is_queued_for_deletion() and _host.target_current(_token)

func _supported_here() -> bool:
	if not _body.is_on_floor(): return false
	var floor: Variant = _route.floor_at(_body.global_position, _body.global_position.y)
	return floor is Vector3 and absf(floor.y-_body.global_position.y) < .08 and _route.standing(floor)

func try_begin(allowed: Array = []) -> bool:
	if active() or not _current() or not _supported_here(): return false
	var choices: Array = Pose.KINDS.duplicate()
	if not allowed.is_empty():
		choices = choices.filter(func(kind: String) -> bool: return kind in allowed)
	choices.erase(_previous)
	# Conditional bench/window choices can fail without forcing an unsuitable act.
	# At most five choices, no unbounded scene sampling or retry loops.
	for attempt: int in 5:
		if choices.is_empty(): break
		var index: int = _rng.randi_range(0, choices.size()-1)
		var kind: String = choices.pop_at(index)
		_seat = {}; _window = null
		_face = -_body.global_basis.z
		if kind == "bench":
			_seat = _benches.reserve_nearest(_body, _route, self, _serial+1)
			if _seat.is_empty(): _log("unavailable", "bench_requires_real_reachable_seat"); continue
			_face = _seat.face
		elif kind == "window":
			var window: Dictionary = _visible_window()
			if window.is_empty(): _log("unavailable", "window_requires_visible_real_glazing"); continue
			_window = window.node; _face = window.direction
		elif kind in ["look_around", "look_far", "camera"]:
			var angle: float = _rng.randf_range(-PI,PI)
			_face = Vector3(sin(angle),0,cos(angle))
		_kind = kind; _previous = kind; _serial += 1
		_duration = _rng.randf_range(4.0,8.0); _elapsed = 0.0; _age = 0.0
		_pose_frames = 0; _frame = -1; _last_reason = ""
		if kind == "bench":
			_driver = Driver.new()
			# Existing physical solver's ordinary outdoor path, never its medical door mode.
			if not _driver.begin(_seat.approach, _body, _map, str(_token.source_id), "roam"):
				_driver.cancel(); _driver = null
				_benches.release(_seat,self,_body); _seat = {}; _kind = ""; continue
			_phase = "APPROACH"
		else: _phase = "ALIGN"
		if not _current(): cancel("actor_life_changed_during_begin"); return false
		# Owner registration is available to immediate death pruning before posing.
		_body.set_meta(Pose.META,{"active":false,"owner":weakref(self),"serial":_serial,"body_id":_body.get_instance_id(),"kind":_kind})
		_log("started", "random_choice")
		return true
	_phase = "IDLE"; _kind = ""
	return false

func _visible_window() -> Dictionary:
	var best := {}; var distance := 22.0
	var eye: Vector3 = _body.global_position + Vector3.UP*1.55
	var space: PhysicsDirectSpaceState3D = _body.get_world_3d().direct_space_state
	var checked := 0
	for reference: WeakRef in Windows29.for_scene(_scene).panes():
		if checked >= 96: return best
		var child: StaticBody3D = reference.get_ref() as StaticBody3D
		if not _window_current(child): continue
		var point: Vector3 = child.global_position
		var candidate_distance: float = eye.distance_to(point)
		if candidate_distance > distance or candidate_distance < 1.2 or point.y > _body.global_position.y+3.2: continue
		checked += 1
		var ray := PhysicsRayQueryParameters3D.create(eye, point, _body.collision_mask, [_body.get_rid()])
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty() or hit.get("collider") != child: continue
		var direction: Vector3 = (point-_body.global_position).slide(Vector3.UP)
		if direction.length_squared() < .01: continue
		best = {"node":weakref(child),"direction":direction.normalized()}; distance = candidate_distance
	return best

func _window_current(child: StaticBody3D) -> bool:
	if not is_instance_valid(child) or child.is_queued_for_deletion() or not child.is_inside_tree() or not child.is_visible_in_tree() or child.collision_layer == 0 or child.get_meta("material_class", "") != "glass": return false
	var parent: Node = child.get_parent()
	return parent is Node3D and parent.name == "OwnedWindowGlazing" and _scene.is_ancestor_of(child)

func _hold(delta: float) -> void:
	var before: Vector3 = _body.global_position
	_route.hold(delta)
	_publish_motion(before,delta)

func _publish_motion(before: Vector3, delta: float) -> void:
	var after: Vector3 = _body.global_position
	var velocity: Vector3 = (after-before)/delta
	_body.set_meta("npc_physical_drive51", {"frame":Engine.get_physics_frames(), "body_id":_body.get_instance_id(), "from":before, "to":after, "velocity":velocity, "delta":delta, "walking":Vector2(velocity.x,velocity.z).length()>.03})

func step(delta: float) -> String:
	if not active(): return "done"
	if not _current(): cancel("actor_life_ended"); return "blocked"
	if _kind == "bench" and not _benches.renew(_seat,self,_body): cancel("bench_lease_lost"); return "blocked"
	if not is_finite(delta) or delta <= 0 or delta > .05: return "active"
	var frame: int = Engine.get_physics_frames()
	if _frame == frame: return "active"
	_frame = frame; _age += delta
	if _phase == "APPROACH":
		if _age > MAX_APPROACH_S or not _benches.supported(_seat,_body): cancel("bench_approach_timeout_or_support_lost"); return "blocked"
		var result: String = _driver.step(delta)
		if result == "blocked": cancel("bench_approach_blocked"); return "blocked"
		if result == "arrived":
			_driver.cancel(); _driver = null
			if Vector2(_body.global_position.x-_seat.approach.x,_body.global_position.z-_seat.approach.z).length() > .42:
				cancel("bench_arrival_too_far"); return "blocked"
			_phase = "DOCK"; _age = 0.0
		return "active"
	if not _supported_here(): cancel("standing_support_lost"); return "blocked"
	if _kind == "bench" and not _benches.supported(_seat,_body): cancel("seat_support_lost"); return "blocked"
	if _kind == "window" and (_window == null or not _window_current(_window.get_ref() as StaticBody3D)): cancel("window_removed"); return "blocked"
	if _phase == "DOCK":
		if _age > 2.0: cancel("bench_precise_approach_blocked"); return "blocked"
		var direction: Vector3 = Vector3(_seat.approach)-_body.global_position
		direction.y = 0.0
		var remaining: float = direction.length()
		if remaining <= .02:
			_hold(delta)
			if not _benches.occupy(_seat,self,_body): cancel("bench_occupancy_refused"); return "blocked"
			_phase = "ALIGN"; _age = 0.0; return "active"
		var floor: Variant = _route.floor_at(_seat.approach,_body.global_position.y)
		if not floor is Vector3 or not _route.edge_clear(_body.global_position,floor): cancel("bench_precise_approach_obstructed"); return "blocked"
		var before: Vector3 = _body.global_position
		_route.move(direction/remaining,minf(remaining,.6*delta),delta)
		_publish_motion(before,delta)
		return "active"
	if _phase == "ALIGN":
		var desired: float = atan2(-_face.x,-_face.z)
		var difference: float = wrapf(desired-_body.global_rotation.y,-PI,PI)
		_body.rotate_y(clampf(difference,-4.0*delta,4.0*delta))
		_hold(delta)
		if _age > 2.0: cancel("orientation_blocked"); return "blocked"
		if absf(difference) < .035:
			if not _props.begin(_token.rig,_kind): cancel("prop_rig_unavailable"); return "blocked"
			_phase = "ACTING"; _age = 0.0; _anchor = _body.global_position
		return "active"
	_hold(delta)
	if _body.global_position.distance_to(_anchor) > .05: cancel("actor_displaced"); return "blocked"
	_elapsed += delta
	if _elapsed >= _duration:
		var completed: bool = _pose_frames >= 8
		_log("completed" if completed else "blocked", "pose_committed" if completed else "host_pose_not_committed")
		cancel("finished" if completed else "pose_not_committed")
		return "done" if completed else "blocked"
	var value: Dictionary = {"active":true,"owner":weakref(self),"serial":_serial,"frame":frame,"body_id":_body.get_instance_id(),"delta":delta,"kind":_kind,"elapsed_s":_elapsed,"duration_s":_duration}
	if _kind == "bench": value["seat"] = _seat.seat; value["bench_path"] = _seat.bench_path
	_body.set_meta(Pose.META,value)
	return "active"

## Called during the host's busy section: no recursive host identity lookup here.
## The host has already passed its own life/ragdoll/transport/current-frame guards.
func sample_current(value: Dictionary) -> bool:
	if _kind == "bench" and not _benches.matches(_seat,self,_body): return false
	return _phase == "ACTING" and is_instance_valid(_body) and int(value.get("serial",-1)) == _serial and str(value.get("kind","")) == _kind and int(value.get("frame",-1)) == _frame and _body.global_position.distance_to(_anchor) <= .05

## Registry only calls this from life-side claim/renew, never from host composition.
func bench_slot_living29(lease_serial: int) -> bool:
	return active() and _kind == "bench" and _current() and int(_seat.get("slot",{}).get("serial",-1)) == lease_serial

func pose_committed(rig: Skeleton3D, value: Dictionary) -> void:
	if not sample_current(value) or rig != _token.get("rig"): _props.hide(); return
	if float(value.get("pose_weight",0.0)) <= .01: _props.hide(); return
	_pose_frames += 1
	_props.sync_after_pose(rig,_kind)

func pose_suppressed() -> void:
	if _props != null: _props.hide()

func cancel(reason: String = "cancelled") -> void:
	if _benches != null: _benches.release(_seat,self,_body)
	if _props != null: _props.clear()
	if _driver != null: _driver.cancel(); _driver = null
	if is_instance_valid(_body):
		var value: Variant = _body.get_meta(Pose.META,{})
		if value is Dictionary and value.get("owner") is WeakRef and value.owner.get_ref() == self: _body.remove_meta(Pose.META)
		# Only clear the published physical frame while this controller owns movement.
		if active() and _body.has_meta("npc_physical_drive51"): _body.remove_meta("npc_physical_drive51")
		if active(): _body.velocity.x = 0.0; _body.velocity.z = 0.0
	_last_reason = reason; _phase = "IDLE"; _seat = {}; _window = null

func snapshot() -> Dictionary:
	return {"active":active(),"phase":_phase,"kind":_kind,"title":TITLES[Pose.KINDS.find(_kind)] if _kind in Pose.KINDS else "","serial":_serial,"elapsed_s":_elapsed,"duration_s":_duration,"pose_frames":_pose_frames,"roams_completed":_roams_completed,"reason":_last_reason,"qa_seed":_seed_label,"bench_slot":_seat.get("slot",{}),"bench_inventory":_benches.snapshot() if _benches != null else {}}

func _log(event: String, reason: String) -> void:
	print("NPC_AMBIENT28 ",JSON.stringify({"event":event,"reason":reason,"id":_token.get("source_id",""),"generation":_token.get("life_generation",-1),"kind":_kind,"phase":_phase,"duration_s":_duration,"pose_frames":_pose_frames,"frame":Engine.get_physics_frames(),"qa_seed":_seed_label}))
