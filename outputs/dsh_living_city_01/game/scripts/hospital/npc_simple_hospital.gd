extends RefCounted
## DSH_SIMPLEHOSP: the owner's "the hospital IS the palazzo copy" stand, behind
## `--city-simple-hospital=1` (default 0 = every accepted path is untouched).
##
## Owner's rule: go to the point - the measured centre of the "БОЛЬНИЦА" palazzo copy -
## "just like Walk goes to a point". One forward ray at chest height says whether the way
## is clear; if a wall stands in front, look for an OPENING: a fan of rays left and right
## (15 degree steps, +-90 degrees, widened to +-120 after a stall), and a direction counts
## as a passage only when THREE parallel rays (centre and +-0.45 m) are all clear for ~4 m
## - a slit narrower than the body is not a passage. Go along the chosen opening, re-ask
## the goal direction every step, and go straight again as soon as it is clear. Nothing is
## remembered: every frame asks the CURRENT collision, so a wall the player destroyed
## becomes a passage by itself.
##
## MOVEMENT IS PHYSICAL: the drive writes `body.velocity` and calls `move_and_slide()`, so
## the engine resolves the collisions - the resident cannot pass through a facade, it is
## stopped by it, and that stop is exactly what starts the opening search. The facing is
## written to `body.rotation.y` with the same convention the resident host uses
## (`atan2(-dx, -dz)`), so the shipped yaw smoothing turns the visual after it.
##
## Why this file exists at all: the copy's room centre is OUTSIDE the pinned source crop,
## so the shipped proof chain refuses it at every step - `support_height` returns NaN
## there, `source_admit` refuses the point, and the native city map has no polygon, so
## `npc_daily_walk` ends the errand 25-30 m short. The resident host also refuses to move
## a body outside the admitted source crop. This owner therefore drives the resident's own
## body: the same body, the same physics, only the goal is the copy.
##
## It writes the body's velocity/position and its yaw. It never writes a source row, HP,
## cash, a door, the navigation map or another actor.
##
## Telemetry (state change, every ~0.5 m and every 30 frames while moving):
##   DSH_SIMPLEHOSP id=… target=(x,y,z) dist_m=… moved_m=… hit_wall=true|false gap_deg=…
##   gap_m=… gap_ok=… dir=straight|gap open=door|left|right|breach|none leg=… facing=…
##   result=walking|entered|blocked|retry phase=… reason=… frame=…

const MedMarker = preload("res://scripts/hospital/npc_hospital_marker.gd")

const FLAG := "--city-simple-hospital="
const TARGET_FLAG := "--city-simple-hospital-target="

## Walking speed of the direct drive, inside the authored gait band (<= 1.8 m/s).
const SPEED_MPS := 1.8
const GRAVITY := 9.8
## The owner's arrival test: the body inside the copy, within 1.5 m of the room centre.
const ARRIVE_M := 1.5
## Bounded attempts per errand before the task is released and the condition re-arms it.
const MAX_ATTEMPTS := 3
const RETRY_DELAY_S := 1.0

## Steering rays: how far they look, and how far ahead must be clear to count as
## "nothing in front of me" (the owner's ~1.2 m).
const PROBE_M := 6.0
const FORWARD_CLEAR_M := 1.2
## An opening must let the ray travel past the wall...
const GAP_MIN_M := 1.2
## ...and be wider than the body: three parallel rays (centre, +-GAP_SIDE_M) must all be
## clear for GAP_CLEAR_M. A slit the resident cannot fit through is not a passage.
const GAP_SIDE_M := 0.45
const GAP_CLEAR_M := 4.0
## A generous opening: the owner's "луч уходит далеко (>=6 m)" - preferred inside +-60 deg.
const WIDE_M := 6.0
const WIDE_DEG := 60.0
## The real body: radius and height measured on the resident capsule (0.36 / 1.9).
const BODY_RADIUS := 0.36
const BODY_HEIGHT := 1.9
## Fan of the opening search: +-90 degrees at 15 degree steps, widened to +-120 after a
## stall. No progression/precomputed route is kept.
const FAN_STEP_DEG := 15.0
const FAN_WIDE_DEG := 90.0
const FAN_WIDER_DEG := 120.0
## Within this angle of the copy's own doorway the fan prefers the doorway direction.
const DOOR_BONUS_RAD := 0.52
## No progress of STALL_M within STALL_S means "look for an opening again, wider".
const STALL_M := 0.05
const STALL_S := 1.5
## The owner's turn rate: the body faces its own direction smoothly, never with a snap.
const YAW_RATE := 8.0
## Within this distance of the copy's doorway the resident asks for the door to be open.
const DOOR_NEAR_M := 2.5

## Ground/floor probe: water and world layers, the same pair the room marker probes.
const PROBE_MASK := 1 | 256
## Steering/wall probe: the world layer only.
const BLOCK_MASK := 1
const RAY_LOW := 0.35
const RAY_CHEST := 1.0
const RAY_HIGH := 1.65
## A step higher than this is not a step: it is a wall or a ledge.
const MAX_STEP_UP := 1.0
## A low obstacle below (feet + this) is stepped over, not called a wall.
const STEP_OVER_M := 0.45
const WAYPOINT_M := 0.4
const PRINT_FRAMES := 30
const PRINT_STEP_M := 0.5

static var _flag := -1

var _id := ""
var _target := Vector3.ZERO
var _target_source := ""
var _body: CharacterBody3D = null
var _map := RID()
var _path := PackedVector3Array()
var _edge := 0
var _door := Vector3.ZERO
var _door_valid := false
var _active := false
var _phase := "idle"
var _dir_label := "straight"
var _open_label := "none"
var _leg := "room"
var _gap_m := 0.0
var _gap_deg := 0.0
var _gap_ok := false
var _hit_wall := false
var _anim := false
var _entered := false
var _door_state := "none"
var _door_node: Node3D = null
var _door_owner: Node = null
var _door_open_requested := false
var _gait_ref: RefCounted = null
var _attempts := 0
var _wait_s := 0.0
var _frame := -1
var _printed_frame := -9999
var _printed_dist := -1.0
var _moved_m := 0.0
var _last_reason := ""
## Stall detection: the position and wall clock of the last real progress.
var _stall_from := Vector3.ZERO
var _stall_ms := 0
var _fan_wide := false
## Side hysteresis only (no obstacle memory): keeps a tie between a left and a right
## opening on the same side instead of jittering.
var _side := 0


static func enabled() -> bool:  # DSH_SIMPLEHOSP
	if _flag < 0:
		_flag = 0
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with(FLAG): _flag = 1 if int(argument.trim_prefix(FLAG)) != 0 else 0
	return _flag == 1


static func _arg(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.trim_prefix(prefix)
	return ""


static func parse_vector(text: String) -> Variant:
	var parts := text.split(",", false)
	if parts.size() != 3: return null
	var values := PackedFloat64Array()
	for part: String in parts:
		var number := part.strip_edges().to_float()
		if not is_finite(number): return null
		values.append(number)
	return Vector3(values[0], values[1], values[2])


## The one target of the stand: the measured centre of the palazzo copy signed
## "БОЛЬНИЦА" - the same point `npc_hospital_marker.gd` already measures and marks, so
## the visible green mark and the walked goal can never disagree.
## `--city-simple-hospital-target=x,y,z` overrides it for a manual check.
static func target_of(scene: Node3D) -> Dictionary:  # DSH_SIMPLEHOSP
	var explicit: Variant = parse_vector(_arg(TARGET_FLAG))
	if explicit is Vector3: return {"ok":true,"point":explicit,"source":"flag"}
	var here: Dictionary = MedMarker.current()
	if not here.is_empty() and here.get("marker") is Vector3:
		return {"ok":true,"point":here.marker,"source":"clone_room_centre"}
	if not is_instance_valid(scene): return {"ok":false,"reason":"no_scene"}
	var resolved: Dictionary = MedMarker.resolve(scene)
	if not bool(resolved.get("ok", false)): return {"ok":false,"reason":str(resolved.get("reason", "clone_not_found"))}
	var measured: Dictionary = MedMarker.current()
	if measured.is_empty() or not measured.get("marker") is Vector3: return {"ok":false,"reason":"marker_unresolved"}
	return {"ok":true,"point":measured.marker,"source":"clone_room_centre"}


## The copy's own doorway, in world metres, or null. Both shipped door forms are looked
## for: the copied "SourceDoor_public" leaf of the default stand and the copy's own
## "Entrance*" panel (the swing stand). It is only a PREFERRED direction for the opening
## search - the passage itself is always judged by the live collision.
static func door_of(scene: Node3D) -> Variant:  # DSH_SIMPLEHOSP
	if not is_instance_valid(scene): return null
	var clone: Node3D = _clone_in(scene)
	if clone == null: return null
	var stack: Array[Node] = [clone]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Node3D:
			var name := str(node.name)
			if name.contains("SourceDoor") or name.begins_with("Entrance"):
				var at: Vector3 = (node as Node3D).global_position
				if at.is_finite(): return at
		for child: Node in node.get_children(): stack.append(child)
	return null


## DSH_SIMPLEHOSP: the copy signed "БОЛЬНИЦА", or null. One scan, used by the door lookup.
static func _clone_in(scene: Node3D) -> Node3D:  # DSH_SIMPLEHOSP
	for node: Node in scene.get_children():
		if node.get_meta("dsh_town_extra", false) != true or not node is Node3D: continue
		var sign_node: Node = node.get_node_or_null("TownCloneSign")
		if sign_node is Label3D and str((sign_node as Label3D).text).to_upper().contains("БОЛЬНИЦ"):
			return node as Node3D
	return null


## DSH_SIMPLEHOSP: the copy's doorway in world metres plus its owner when it has one. Both
## shipped door forms are found: the copied "SourceDoor_public" leaf of the default stand
## and the copy's own "Entrance*" panel (the swing stand). The doorway is only a PREFERRED
## direction for the opening search - the passage itself is always the live collision.
func _resolve_door_nodes() -> void:  # DSH_SIMPLEHOSP
	_door_node = null
	_door_owner = null
	_door_valid = false
	var scene: Node3D = _scene_of_body()
	if not is_instance_valid(scene): return
	var clone: Node3D = _clone_in(scene)
	if clone == null: return
	var stack: Array[Node] = [clone]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if _door_owner == null and node.has_method("request_door"): _door_owner = node
		if _door_node == null and node is Node3D:
			var name := str(node.name)
			if name.contains("SourceDoor") or name.begins_with("Entrance"):
				_door_node = node as Node3D
				var at: Vector3 = _door_node.global_position
				if at.is_finite():
					_door = at
					_door_valid = true
		for child: Node in node.get_children(): stack.append(child)


## DSH_SIMPLEHOSP: the owner's step 1 in the only form this city can survive. The standing
## hospital's SOURCE geometry must stay in the scene and must stay attached: on the
## measured path `npc_city_bootstrap._attach_site` needs its original visual and its three
## source envelopes, and `npc_city_daily.configure` refuses to build the daily cycle
## without a real attached hospital site (`actual_hospital_and_bank_required`) - removing
## the `hospital` row from the town keep set therefore leaves the town with ZERO residents.
## What is turned off is everything the player and the residents can see or use: the
## building and its attached interior site are hidden, and no resident is ever handed to
## its visit controller (the life takes the palazzo copy instead).
static func disable_standing_hospital(scene: Node3D, site: Node3D, source_id: String) -> Dictionary:  # DSH_SIMPLEHOSP
	var hidden := 0
	if is_instance_valid(site) and site is Node3D:
		(site as Node3D).visible = false
		hidden += 1
	if is_instance_valid(scene):
		for node: Node in scene.get_children():
			if str(node.get_meta("source_id", "")) != source_id: continue
			if node is Node3D:
				(node as Node3D).visible = false
				hidden += 1
	print("DSH_SIMPLEHOSP standing_hospital=disabled source_id=", source_id, " hidden_nodes=", hidden,
		" geometry_kept=true reason=city_bootstrap_requires_the_real_site")
	return {"ok":hidden > 0, "hidden": hidden}


func begin(target: Vector3, body: CharacterBody3D, map: RID, id: String, source: String) -> bool:
	if not target.is_finite() or not is_instance_valid(body) or not body is CharacterBody3D: return false
	_target = target
	_body = body
	_map = map
	_id = id
	_target_source = source
	_active = true
	_phase = "seek"
	_dir_label = "straight"
	_open_label = "none"
	_leg = "room"
	_gap_m = 0.0
	_gap_deg = 0.0
	_gap_ok = false
	_hit_wall = false
	_anim = false
	_entered = false
	_door_state = "none"
	_door_node = null
	_door_owner = null
	_door_open_requested = false
	_gait_ref = null
	_attempts = 0
	_wait_s = 0.0
	_frame = -1
	_moved_m = 0.0
	_printed_dist = -1.0
	_printed_frame = -9999
	_last_reason = ""
	_fan_wide = false
	_side = 0
	_stall_from = body.global_position
	_stall_ms = Time.get_ticks_msec()
	_plan()
	_resolve_door_nodes()
	_emit("walking")
	return true


func _scene_of_body() -> Node3D:  # DSH_SIMPLEHOSP
	if not is_instance_valid(_body): return null
	var tree: SceneTree = _body.get_tree()
	if tree == null: return null
	return tree.current_scene as Node3D


func active() -> bool: return _active
func target() -> Vector3: return _target
func target_source() -> String: return _target_source
func phase() -> String: return _phase
func attempts() -> int: return _attempts
func moved_m() -> float: return _moved_m
func last_reason() -> String: return _last_reason


func distance_m() -> float:
	if not is_instance_valid(_body): return -1.0
	return _flat(_body.global_position, _target)


func cancel() -> void:
	if is_instance_valid(_body) and _body is CharacterBody3D:
		(_body as CharacterBody3D).velocity = Vector3.ZERO
	_active = false
	_phase = "cancelled"
	_path = PackedVector3Array()
	_edge = 0


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _flat_dir(a: Vector3, b: Vector3) -> Vector3:
	var flat := Vector2(b.x - a.x, b.z - a.z)
	if flat.length() < .0001: return Vector3.ZERO
	flat = flat.normalized()
	return Vector3(flat.x, 0.0, flat.y)


## The native map is asked once for a first leg; the copy is off the pinned source crop,
## so in practice the straight line to the centre is the route. No obstacle is remembered.
func _plan() -> void:
	_path = PackedVector3Array()
	_edge = 0
	if not is_instance_valid(_body): return
	var here: Vector3 = _body.global_position
	if _map.is_valid():
		var native: PackedVector3Array = NavigationServer3D.map_get_path(_map, here, _target, true)
		for point: Vector3 in native:
			if point.is_finite(): _path.append(point)
	if _path.is_empty() or _path[_path.size() - 1].distance_to(_target) > .5:
		_path.append(_target)
	while _edge < _path.size() - 1 and _flat(here, _path[_edge]) <= WAYPOINT_M:
		_edge += 1


func step(delta: float) -> String:
	if not _active or not is_instance_valid(_body) or not is_finite(delta) or delta <= 0.0: return ""
	var frame: int = Engine.get_physics_frames()
	if frame == _frame: return ""
	_frame = frame
	var here: Vector3 = _body.global_position
	var dist: float = _flat(here, _target)
	if dist <= ARRIVE_M:
		_active = false
		_phase = "entered"
		_last_reason = "within_%.1f_m_of_centre" % ARRIVE_M
		_emit("entered", _last_reason)
		return "arrived"
	if _wait_s > 0.0:
		_wait_s = maxf(0.0, _wait_s - delta)
		return ""
	if _edge < 0 or _edge >= _path.size(): _plan()
	if _edge >= _path.size(): return ""
	var goal: Vector3 = _path[_edge]
	if _flat(here, goal) <= WAYPOINT_M and _edge < _path.size() - 1:
		_edge += 1
		goal = _path[_edge]
	var to_goal: Vector3 = _flat_dir(here, goal)
	if to_goal == Vector3.ZERO: return ""
	# 1. Straight to the point: is anything in front of me?
	var forward_free: float = _free_m(here, to_goal)
	var direction: Vector3 = to_goal
	_hit_wall = forward_free < FORWARD_CLEAR_M
	_dir_label = "straight"
	_open_label = "none"
	_gap_deg = 0.0
	_gap_m = 0.0
	_gap_ok = false
	if _hit_wall or not _width_ok(here, to_goal):
		# 2. A wall (or a slit) in front: look for an opening in the live geometry.
		var best: Dictionary = _find_opening(here, to_goal)
		if bool(best.get("ok", false)):
			direction = best.dir
			_dir_label = "gap"
			_open_label = str(best.open)
			_gap_deg = float(best.deg)
			_gap_m = _measure_gap(here, direction)
			_gap_ok = true
			if _side == 0 and _open_label == "left": _side = 1
			elif _side == 0 and _open_label == "right": _side = -1
		else:
			_dir_label = "blocked"
			_open_label = "none"
	# 3. Move one physics step along the chosen direction.
	var travel: float = _advance(direction, delta)
	_moved_m += travel
	if travel < 0.02 and _step_up(here, direction):
		travel = _advance(direction, delta)
		_moved_m += travel
	# 4. Facing: the same convention the resident host uses for its own walking steps
	# (atan2(-dx,-dz)), reached smoothly at YAW_RATE rad/s - never a snap.
	if travel > .002 and is_instance_valid(_body):
		var moved: Vector3 = _body.global_position - here
		var desired_yaw: float = atan2(-moved.x, -moved.z)
		var yaw_delta: float = atan2(sin(desired_yaw - _body.rotation.y), cos(desired_yaw - _body.rotation.y))
		_body.rotation.y += clampf(yaw_delta, -YAW_RATE * delta, YAW_RATE * delta)
	# 4b. The shipped walk layer: hand it the real speed of this drive (see _feed_gait).
	_anim = _feed_gait(delta, travel, direction)
	# 4c. The copy's door: ask its own owner to open it, or report the free-entry stand.
	_update_door()
	# 5. Stall rule: less than 5 cm in 1.5 s means "look again, wider".
	var point: Vector3 = _body.global_position
	var now_ms: int = Time.get_ticks_msec()
	if _flat(point, _stall_from) >= STALL_M:
		_stall_from = point
		_stall_ms = now_ms
		if _fan_wide and _flat(point, _target) < dist: _fan_wide = false
	elif now_ms - _stall_ms >= int(STALL_S * 1000.0):
		if not _fan_wide:
			_fan_wide = true
			_stall_ms = now_ms
			_last_reason = "stall_widen_fan"
		else:
			return _fail_attempt("stall_no_passage")
	var reached: float = _flat(point, _target)
	_leg = "door" if (_door_valid and point.distance_to(_door) <= 8.0) else "room"
	if reached <= 2.5: _entered = true
	if reached <= ARRIVE_M:
		_active = false
		_phase = "entered"
		_last_reason = "within_%.1f_m_of_centre" % ARRIVE_M
		_emit("entered", _last_reason)
		return "arrived"
	if _printed_dist < 0.0 or _printed_dist - reached >= PRINT_STEP_M or frame - _printed_frame >= PRINT_FRAMES:
		_emit("walking")
	return "walking"


## One physical step: velocity + move_and_slide, so the engine resolves the collision and
## the resident is stopped by a facade instead of passing through it. Returns the metres
## actually travelled on the ground plane.
func _advance(direction: Vector3, delta: float) -> float:
	var body := _body
	var before: Vector3 = body.global_position
	var vy: float = body.velocity.y
	if body.is_on_floor() and vy <= 0.0: vy = 0.0
	else: vy -= GRAVITY * delta
	body.velocity = direction * SPEED_MPS + Vector3.UP * vy
	body.move_and_slide()
	return _flat(before, body.global_position)


## The shipped walk layer (`preview_locomotion.gd`, the resident host's `record.gait`) is
## driven by the speed the host hands it - and the host only measures the displacement it
## made ITSELF inside its own step. This drive moves the body in the daily step, i.e. one
## call earlier, so the host hands the layer zero and the resident would slide. This passes
## the REAL speed of the direct drive to that same shipped sampler: no pose is written here,
## no animation is copied - only the speed sign the existing layer reads. Returns true when
## the layer is being driven with a walking speed.
func _feed_gait(delta: float, travel: float, direction: Vector3) -> bool:
	if _gait_ref == null: _resolve_gait()
	if _gait_ref == null or not is_instance_valid(_gait_ref) or not _gait_ref.has_method("update_pose"): return false
	if direction == Vector3.ZERO: return false
	var speed: float = travel / maxf(delta, .0001)
	if speed <= .05: return false
	_gait_ref.update_pose(delta, direction * speed, _body.is_on_floor())
	return true


func _resolve_gait() -> void:
	var scene: Node3D = _scene_of_body()
	if not is_instance_valid(scene): return
	var population: Variant = scene.get("preview_population")
	if population == null: return
	var host: Variant = population.get("residents")
	if host == null: return
	var records: Variant = host.get("_records")
	if not records is Dictionary: return
	var record: Variant = (records as Dictionary).get(_id, {})
	if not record is Dictionary: return
	var gait: Variant = (record as Dictionary).get("gait")
	if gait != null and is_instance_valid(gait) and gait.has_method("update_pose"): _gait_ref = gait


## The copy's doorway. With the swing stand installed the resident asks its own owner to
## open the leaf (`request_door("public", true, ...)`) and reports the fraction the owner
## animates; that owner closes it again on its own when nobody is near. On the default
## free-entry stand there is no owner: the leaf is parked open with every collider off the
## collision layers, so the opening is already a hole and it is only REPORTED - nothing is
## ever re-closed or re-collided here, because the player must keep walking through it.
func _update_door() -> void:
	_door_state = "none"
	if not _door_valid or not is_instance_valid(_body): return
	var actor: Vector3 = _body.global_position
	if actor.distance_to(_door) > DOOR_NEAR_M:
		_door_state = "far"
		return
	_door_state = "near"
	if _door_owner != null and is_instance_valid(_door_owner) and _door_owner.has_method("request_door"):
		if not _door_open_requested:
			var answer: Variant = _door_owner.call("request_door", "public", true, actor, [])
			if answer is Dictionary and bool((answer as Dictionary).get("accepted", false)):
				_door_open_requested = true
		var fraction := 1.0
		if _door_owner.has_method("door_fraction"): fraction = float(_door_owner.call("door_fraction", "public"))
		_door_state = "open" if fraction >= .6 else "opening"
		return
	_door_state = "open"


## A raised threshold (the copy's own doorway step) is not a wall: when the physics step is
## blocked and the floor just ahead is higher but within one legal step, place the body on
## it and let the next step continue. Bounded, live geometry only.
func _step_up(here: Vector3, direction: Vector3) -> bool:
	if not is_instance_valid(_body): return false
	var ahead: Vector3 = here + direction * .35
	var floor: Dictionary = _ground(ahead, here.y)
	if not bool(floor.get("ok", true)): return false
	var y: float = float(floor.get("y", here.y))
	if y <= here.y + .02 or y > here.y + MAX_STEP_UP: return false
	_body.global_position = Vector3(_body.global_position.x, y, _body.global_position.z)
	return true


## The opening search: a fan of rays from -FAN_WIDE_DEG to +FAN_WIDE_DEG (wider after a
## stall), and a direction counts only when its ray travels past the wall AND the three-ray
## width test says the resident fits. The owner's order: a generous opening (>= WIDE_M)
## inside +-WIDE_DEG wins; otherwise the smallest deviation from the goal; the copy's own
## doorway direction and the side already in use break ties. Nothing is cached.
func _find_opening(here: Vector3, to_goal: Vector3) -> Dictionary:
	var limit: float = FAN_WIDER_DEG if _fan_wide else FAN_WIDE_DEG
	var door_dir: Vector3 = Vector3.ZERO
	if _door_valid:
		door_dir = _flat_dir(here, _door)
	var best: Dictionary = {}
	var best_score := 1e9
	var angle: float = FAN_STEP_DEG
	while angle <= limit + .001:
		for side_sign: float in [1.0, -1.0]:
			var offset: float = deg_to_rad(angle) * side_sign
			var direction: Vector3 = to_goal.rotated(Vector3.UP, offset)
			var free: float = _free_m(here, direction)
			if free < GAP_MIN_M: continue
			if not _width_ok(here, direction): continue
			if not _capsule_clear(here, direction): continue
			var opening := "left" if side_sign > 0.0 else "right"
			if free >= WIDE_M: opening = "breach"
			# Cost: generous openings first (the owner's >= 6 m rule inside +-60 deg),
			# then the smallest deviation, then the doorway, then the side in use.
			var score: float = angle
			if free >= WIDE_M and angle <= WIDE_DEG + .001: score -= 100.0 - minf(free, 30.0)
			if _door_valid and door_dir != Vector3.ZERO and direction.dot(door_dir) >= cos(DOOR_BONUS_RAD):
				score -= 25.0
				if opening != "breach": opening = "door"
			if side_sign < 0.0: score += 0.4
			if _side != 0 and side_sign != float(_side): score += 2.0
			if score < best_score:
				best_score = score
				best = {"ok":true,"dir":direction,"free":free,"open":opening,"deg":angle * side_sign}
		angle += FAN_STEP_DEG
	return best


## How far the way is clear along one direction, at the three probe heights. A hit below
## the feet + STEP_OVER_M is a low step, not a wall. This is the live collision only.
func _free_m(here: Vector3, direction: Vector3) -> float:
	if not is_instance_valid(_body): return 0.0
	var world: World3D = _body.get_world_3d()
	if world == null: return 0.0
	var exclude: Array[RID] = [_body.get_rid()]
	var nearest: float = PROBE_M
	for height: float in [RAY_LOW, RAY_CHEST, RAY_HIGH]:
		var from: Vector3 = here + Vector3.UP * height
		var query := PhysicsRayQueryParameters3D.create(from, from + direction * PROBE_M, BLOCK_MASK, exclude)
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if hit.is_empty(): continue
		var point: Vector3 = hit.position
		if point.y <= here.y + STEP_OVER_M: continue
		nearest = minf(nearest, Vector2(point.x - here.x, point.z - here.z).length())
	return nearest


## "Not a slit": three parallel rays (centre and +-0.45 m sideways) must all be clear for
## GAP_CLEAR_M, so the opening is wider than the resident.
func _width_ok(here: Vector3, direction: Vector3) -> bool:
	var side: Vector3 = direction.cross(Vector3.UP)
	if side.length() < .001: return false
	side = side.normalized()
	for lateral: float in [0.0, GAP_SIDE_M, -GAP_SIDE_M]:
		if not _lateral_clear(here, direction, side * lateral): return false
	return true


func _lateral_clear(here: Vector3, direction: Vector3, lateral: Vector3) -> bool:
	if not is_instance_valid(_body): return false
	var world: World3D = _body.get_world_3d()
	if world == null: return false
	var origin: Vector3 = here + Vector3.UP * RAY_CHEST + lateral
	var exclude: Array[RID] = [_body.get_rid()]
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * GAP_CLEAR_M, BLOCK_MASK, exclude)
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty(): return true
	var point: Vector3 = hit.position
	return point.y <= here.y + STEP_OVER_M


## The measured width of the accepted opening: how far the clear corridor extends to both
## sides of the chosen direction. Telemetry only - the passage test is `_width_ok` plus the
## capsule, which run for every fan direction.
func _measure_gap(here: Vector3, direction: Vector3) -> float:
	var side: Vector3 = direction.cross(Vector3.UP)
	if side.length() < .001: return 0.0
	side = side.normalized()
	var width := 0.0
	var offset := 0.15
	while offset <= 1.5:
		if _lateral_clear(here, direction, side * offset) and _lateral_clear(here, direction, -side * offset):
			width = offset * 2.0
		else:
			break
		offset += 0.15
	return width


## The barrel of the body in the chosen direction: a capsule of radius 0.36 / height 1.9
## must fit where the next half metre of the walk will be. A contact the body already has
## at its own spot (standing against a facade) is not this direction's fault, so it does
## not veto the direction; the three-ray width test stays the primary slit gate.
func _capsule_clear(here: Vector3, direction: Vector3) -> bool:
	if not is_instance_valid(_body): return false
	var ahead: Vector3 = here + direction * .7
	var base: float = here.y
	var floor: Dictionary = _ground(ahead, here.y)
	if bool(floor.get("ok", true)): base = float(floor.get("y", here.y))
	if _capsule_hits(Vector3(ahead.x, base, ahead.z)).is_empty(): return true
	return not _capsule_hits(here).is_empty()


func _capsule_hits(at: Vector3) -> Array:
	if not is_instance_valid(_body): return []
	var world: World3D = _body.get_world_3d()
	if world == null: return []
	var shape := CapsuleShape3D.new()
	shape.radius = BODY_RADIUS
	shape.height = BODY_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = BLOCK_MASK
	var exclude: Array[RID] = [_body.get_rid()]
	query.exclude = exclude
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * (BODY_HEIGHT * .5 + .03))
	return world.direct_space_state.intersect_shape(query, 1)


## The floor under one point, asked from just above the body's own feet so a ceiling or
## a roof can never be mistaken for the ground.
func _ground(at: Vector3, current_y: float) -> Dictionary:
	if not is_instance_valid(_body): return {"ok":false,"reason":"no_body"}
	var world: World3D = _body.get_world_3d()
	if world == null: return {"ok":false,"reason":"no_world"}
	var from := Vector3(at.x, current_y + RAY_CHEST, at.z)
	var to := Vector3(at.x, current_y + RAY_CHEST - 2.4, at.z)
	var exclude: Array[RID] = [_body.get_rid()]
	var query := PhysicsRayQueryParameters3D.create(from, to, PROBE_MASK, exclude)
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty(): return {"ok":true,"y":current_y,"reason":"no_floor"}
	var y: float = hit.position.y
	if y > current_y + MAX_STEP_UP: return {"ok":false,"reason":"wall_or_ledge"}
	return {"ok":true,"y":y,"reason":""}


func _fail_attempt(reason: String) -> String:
	_attempts += 1
	_side = 0
	_fan_wide = false
	if is_instance_valid(_body): _body.velocity = Vector3.ZERO
	if _attempts >= MAX_ATTEMPTS:
		_active = false
		_phase = "blocked"
		_dir_label = "blocked"
		_open_label = "none"
		_last_reason = "%s_after_%d_attempts" % [reason, _attempts]
		_emit("blocked", _last_reason)
		return "blocked"
	_phase = "retry"
	_last_reason = reason
	_plan()
	_wait_s = RETRY_DELAY_S
	_stall_from = _body.global_position if is_instance_valid(_body) else Vector3.ZERO
	_stall_ms = Time.get_ticks_msec()
	_emit("retry", "%s_attempt_%d_of_%d" % [reason, _attempts, MAX_ATTEMPTS])
	return "retry"


func _emit(result: String, reason: String = "") -> void:
	_printed_frame = Engine.get_physics_frames()
	var dist: float = distance_m()
	_printed_dist = dist
	var facing := 0.0
	if is_instance_valid(_body): facing = rad_to_deg(_body.rotation.y)
	var line := "DSH_SIMPLEHOSP id=" + _id \
		+ " target=(" + "%.2f" % _target.x + "," + "%.2f" % _target.y + "," + "%.2f" % _target.z + ")" \
		+ " dist_m=" + "%.1f" % dist \
		+ " moved_m=%.1f" % _moved_m \
		+ " hit_wall=" + ("true" if _hit_wall else "false") \
		+ " gap_deg=%.0f" % _gap_deg \
		+ " gap_m=%.2f" % _gap_m + " gap_ok=" + ("true" if _gap_ok else "false") \
		+ " dir=" + _dir_label + " open=" + _open_label + " leg=" + _leg \
		+ " facing=%.0f" % facing \
		+ " anim=" + ("on" if _anim else "off") \
		+ " door=" + _door_state + " entered=" + ("true" if _entered else "false") \
		+ " phase=" + _phase + " result=" + result
	if not reason.is_empty(): line += " reason=" + reason
	line += " attempts=" + str(_attempts) + " source=" + _target_source \
		+ " frame=" + str(Engine.get_physics_frames())
	print(line)
