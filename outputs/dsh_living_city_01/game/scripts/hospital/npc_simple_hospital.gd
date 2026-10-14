extends RefCounted
## DSH_SIMPLEHOSP: the owner's "the hospital IS the palazzo copy" stand, behind
## `--city-simple-hospital=1` (default 0 = every accepted path is untouched).
##
## Owner's rule (verbatim intent): the standing hospital is off, the hospital is the
## palazzo copy, the resident builds a path to the centre point of the copy and walks
## there "without any bureaucracy".
##
## Why this file exists at all: the copy's room centre is OUTSIDE the pinned source
## crop, so the shipped proof chain refuses it at every step -
##   * `policy.support_height` returns NaN there (measured: `support_height_nan`),
##   * `policy.source_admit` refuses the point (`medical_priority_admission_refused`),
##   * the native city map has no polygon there, so `npc_daily_walk` ends the errand
##     with `destination_not_on_current_native_map`.
## This owner therefore does the one thing the owner asked for and nothing else:
## it drives the resident's own body, one bounded step per physics frame, towards the
## measured centre of the copy. The route is the Godot navigation map
## (`NavigationServer3D.map_get_path`) while the map has an answer; the final leg is
## the plain straight line to the centre, guarded by exactly two physical questions:
## "is there a floor/step here" and "is there a wall in front of me".
##
## It writes: the body's global_position (the same value the host writes when it walks
## the resident) and only its x/z plus a bounded step up/down. It never writes a source
## row, HP, cash, the navigation map, a door or another actor. The resident host moves
## no body without a navigation request, so no other owner fights this drive.
##
## Telemetry (one line per state change and per ~0.5 m of progress):
##   DSH_SIMPLEHOSP id=… target=(x,y,z) dist_m=… phase=… result=walking|arrived|retry|blocked reason=… frame=…

const MedMarker = preload("res://scripts/hospital/npc_hospital_marker.gd")

const FLAG := "--city-simple-hospital="
const TARGET_FLAG := "--city-simple-hospital-target="

## Walking speed of the direct drive. The authored resident gait is <= 1.8 m/s, so this
## stays inside what the body can present without a gait teleport.
const SPEED_MPS := 2.2
## The owner's arrival test: the body standing within 1.5 m of the room centre.
const ARRIVE_M := 1.5
## Bounded attempts per errand before the task is released and the condition re-arms it.
const MAX_ATTEMPTS := 3
const RETRY_DELAY_S := 1.0
## Frames of a fully blocked direction before one attempt is counted as failed.
const STUCK_FRAMES := 12
## Side steps tried when the direct direction is a wall, ordered by how little they
## deviate from the desired direction (radians). A flat city wall needs the wide angles
## (`+-90` and beyond) to become a slide along the facade instead of a dead stop.
const SIDESTEPS := [0.35, -0.35, 0.7, -0.7, 1.05, -1.05, 1.4, -1.4, 1.75, -1.75, 2.1, -2.1, 2.45, -2.45, 2.8, -2.8, 3.14]
## A chosen side step wider than this is remembered and kept for HOLD_FRAMES, so the
## resident walks along the wall (rounds the corner) instead of jittering in place.
const HOLD_RAD := 0.6
const HOLD_FRAMES := 45
## Ground/floor probe: water and world layers, the same pair the room marker probes.
const PROBE_MASK := 1 | 256
## Wall probe: the world layer only.
const BLOCK_MASK := 1
const PROBE_HEIGHTS := [0.35, 1.0, 1.7]
const RAY_UP := 1.2
const RAY_DOWN := 2.4
## A step higher than this is not a step: it is a wall or a ledge.
const MAX_STEP_UP := 1.0
## A floor lower than this is not followed: the drive never drops the body.
const MAX_STEP_DOWN := 1.0
## A low obstacle below (floor + this) is stepped over, not called a wall.
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
var _active := false
var _phase := "idle"
var _attempts := 0
var _stuck := 0
var _wait_s := 0.0
var _frame := -1
var _printed_frame := -9999
var _printed_dist := -1.0
var _moved_m := 0.0
var _last_reason := ""
## Wall-follow memory: the side direction currently held, and for how many frames.
var _hold_dir := Vector3.ZERO
var _hold_frames := 0


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
	_attempts = 0
	_stuck = 0
	_wait_s = 0.0
	_frame = -1
	_moved_m = 0.0
	_printed_dist = -1.0
	_printed_frame = -9999
	_last_reason = ""
	_plan()
	_emit("walking")
	return true


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


## The native map is asked first; the copy is off the pinned source crop, so the answer
## is usually only a partial route. The straight line to the centre is appended as the
## last leg - that is the owner's "just walk to the point of the hospital centre".
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
		_phase = "arrived"
		_last_reason = "within_%.1f_m_of_centre" % ARRIVE_M
		_emit("arrived", _last_reason)
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
	_phase = "map_path" if _edge < _path.size() - 1 else "straight"
	var direction: Vector3 = _flat_dir(here, goal)
	if direction == Vector3.ZERO: return ""
	var step_m: float = maxf(.02, SPEED_MPS * delta)
	# Wall-follow: while a side direction is held, move along it. The direct direction is
	# re-asked on every frame, so the hold is dropped as soon as the goal is reachable again.
	var wanted: Vector3 = direction
	if _hold_frames > 0 and _hold_dir != Vector3.ZERO:
		wanted = _hold_dir
		_hold_frames -= 1
	var move: Dictionary = _candidate(here, wanted, step_m, dist)
	if not bool(move.get("ok", false)):
		move = _best_side_candidate(here, direction, step_m, dist)
		if bool(move.get("ok", false)):
			var offset: float = float(move.get("offset", 0.0))
			if absf(offset) > HOLD_RAD:
				_hold_dir = move.get("dir", Vector3.ZERO)
				_hold_frames = HOLD_FRAMES
				_last_reason = "wall_at_%.0f_deg" % rad_to_deg(offset)
	if not bool(move.get("ok", false)):
		_stuck += 1
		_last_reason = str(move.get("reason", "blocked"))
		if _stuck >= STUCK_FRAMES: return _fail_attempt(_last_reason)
		return ""
	_stuck = 0
	if _hold_frames <= 0: _hold_dir = Vector3.ZERO
	var point: Vector3 = move.point
	_body.velocity = Vector3.ZERO
	_body.global_position = point
	_moved_m += _flat(here, point)
	var reached: float = _flat(point, _target)
	if reached <= ARRIVE_M:
		_active = false
		_phase = "arrived"
		_last_reason = "within_%.1f_m_of_centre" % ARRIVE_M
		_emit("arrived", _last_reason)
		return "arrived"
	if _printed_dist < 0.0 or _printed_dist - reached >= PRINT_STEP_M or frame - _printed_frame >= PRINT_FRAMES:
		_emit("walking")
	return "walking"


func _fail_attempt(reason: String) -> String:
	_attempts += 1
	_hold_dir = Vector3.ZERO
	_hold_frames = 0
	if _attempts >= MAX_ATTEMPTS:
		_active = false
		_phase = "blocked"
		_last_reason = "%s_after_%d_attempts" % [reason, _attempts]
		_emit("blocked", _last_reason)
		return "blocked"
	_phase = "retry"
	_last_reason = reason
	_plan()
	_stuck = 0
	_wait_s = RETRY_DELAY_S
	_emit("retry", "%s_attempt_%d_of_%d" % [reason, _attempts, MAX_ATTEMPTS])
	return "retry"


## The closest clear direction to the desired one. Returns the first candidate that does
## not increase the distance to the goal; otherwise the least-deviating clear candidate,
## which is what makes the resident slide along a facade instead of stopping.
func _best_side_candidate(here: Vector3, direction: Vector3, step_m: float, dist: float) -> Dictionary:
	var fallback := {}
	for angle: float in SIDESTEPS:
		var side: Vector3 = direction.rotated(Vector3.UP, angle)
		var attempt: Dictionary = _candidate(here, side, step_m, dist)
		if not bool(attempt.get("ok", false)): continue
		attempt["offset"] = angle
		attempt["dir"] = side
		if _flat(attempt.point, _target) <= dist + .05: return attempt
		if fallback.is_empty(): fallback = attempt
	return fallback


## One bounded move: the floor under the destination must be a legal step, and no wall
## may stand between the body and it. Nothing else is asked - no admission, no band.
func _candidate(here: Vector3, direction: Vector3, step_m: float, dist: float) -> Dictionary:
	if direction == Vector3.ZERO: return {"ok":false,"reason":"no_direction"}
	var next := Vector3(here.x + direction.x * step_m, here.y, here.z + direction.z * step_m)
	if _flat(next, _target) > dist + .6: return {"ok":false,"reason":"diverges"}
	var floor: Dictionary = _ground(next, here.y)
	if not bool(floor.get("ok", true)): return {"ok":false,"reason":str(floor.get("reason", "no_floor"))}
	var wall: String = _wall_between(here, next, float(floor.get("y", here.y)))
	if not wall.is_empty(): return {"ok":false,"reason":wall}
	return {"ok":true,"point":Vector3(next.x, float(floor.get("y", here.y)), next.z)}


## The floor under one point, asked from just above the body's own feet so a ceiling or
## a roof can never be mistaken for the ground.
func _ground(at: Vector3, current_y: float) -> Dictionary:
	if not is_instance_valid(_body): return {"ok":false,"reason":"no_body"}
	var world: World3D = _body.get_world_3d()
	if world == null: return {"ok":false,"reason":"no_world"}
	var from := Vector3(at.x, current_y + RAY_UP, at.z)
	var to := Vector3(at.x, current_y + RAY_UP - RAY_DOWN, at.z)
	var exclude: Array[RID] = [_body.get_rid()]
	var query := PhysicsRayQueryParameters3D.create(from, to, PROBE_MASK, exclude)
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty(): return {"ok":true,"y":current_y,"reason":"no_floor"}
	var y: float = hit.position.y
	if y > current_y + MAX_STEP_UP: return {"ok":false,"reason":"wall_or_ledge"}
	if y < current_y - MAX_STEP_DOWN: return {"ok":true,"y":current_y,"reason":"drop_refused"}
	return {"ok":true,"y":y,"reason":""}


func _wall_between(from: Vector3, to: Vector3, floor_y: float) -> String:
	if not is_instance_valid(_body): return ""
	var world: World3D = _body.get_world_3d()
	if world == null: return ""
	var exclude: Array[RID] = [_body.get_rid()]
	for height: float in PROBE_HEIGHTS:
		var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * height, to + Vector3.UP * height, BLOCK_MASK, exclude)
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if hit.is_empty(): continue
		# A horizontal face below the destination floor is a low step, not a wall; a
		# vertical face that reaches it is a wall.
		var hit_point: Vector3 = hit.position
		if hit_point.y <= floor_y + STEP_OVER_M: continue
		return "wall_at_%.1fm" % height
	return ""


func _emit(result: String, reason: String = "") -> void:
	_printed_frame = Engine.get_physics_frames()
	var dist: float = distance_m()
	_printed_dist = dist
	var line := "DSH_SIMPLEHOSP id=" + _id \
		+ " target=(" + "%.2f" % _target.x + "," + "%.2f" % _target.y + "," + "%.2f" % _target.z + ")" \
		+ " dist_m=" + "%.1f" % dist \
		+ " phase=" + _phase \
		+ " result=" + result
	if not reason.is_empty(): line += " reason=" + reason
	line += " moved_m=%.1f" % _moved_m + " attempts=" + str(_attempts) \
		+ " source=" + _target_source + " frame=" + str(Engine.get_physics_frames())
	print(line)
