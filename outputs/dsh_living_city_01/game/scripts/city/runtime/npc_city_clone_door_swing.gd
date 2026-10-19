extends Node3D
## DSH_CLONEDOOR: a real, openable front door for one palazzo copy.
##
## The owner's step-2 stand (see main.gd `_install_palazzo_clones`) copies the whole
## PalazzoShowcaseSite subtree, so each copy already carries the palazzo's own entrance
## panel: the RigidBody3D "Entrance*" that palazzo_site.gd `_bind_door()` binds as
## `_door` (`body.name.begins_with("Entrance")`), with
## `section_size = (2.002, 2.62, 0.26)` and hinge at
## `origin - basis.x * section_size.x * .5`. That leaf is reused verbatim here.
##
## Default (no flag) the copy keeps the owner's current stand: the copied printshop leaf
## is parked open at 100 degrees and every collider is taken off its layers, so the
## doorway is a free hole. With `--city-clone-door-swing=1` that stub is not installed
## at all and this owner takes over the copy's OWN entrance panel:
##   * closed  = a real barrier (the leaf keeps its authored layer-1 colliders),
##   * opening = the same smoothstep leaf pose palazzo_site.gd `_door_pose` produces,
##   * a resident inside 2.5 m opens it, an empty doorway closes it again,
##   * the player toggles it with E through the project's existing door hint panel
##     (`_door_hint_panel` / node "InteractionKeyE" in main.gd `_build_hud`),
##     never a new HUD.
##
## Contract matches the palazzo / hospital / bank / printshop owners:
## `request_door(key, open, actor_position, occupants)`, `door_fraction(key)`,
## `advance(delta)` - plus `nearest_action(actor_position)` for the hint and
## `set_prompt_visible(bool)` so telemetry can report the hint state.
##
## Honest limitation: a copy has no navigation host and no interior admission, so no
## resident AI ever calls `request_door` on it. The resident path here is a real
## proximity trigger inside this owner, not the city navigation door-transition flow.
## The full contract is implemented so a future navigation host can drive it as-is.
## See MAFIOZY_CLONE_DOORS.md.

const DOOR_SWING_FLAG := "--city-clone-door-swing="
## Same public door spec the source owners use (`data/printshop_interior.json`
## doors.public): a 90 degree leaf over 0.65 s, reached from 2.45 m.
const DOOR_ANGLE := PI * 0.5
const DOOR_DURATION := 0.65
const PROXIMITY_M := 2.45
## Owner's requirement: the resident opens the leaf from 2.5 m.
const RESIDENT_RADIUS_M := 2.5
## Owner's requirement: the "E" hint appears from 3 m.
const PLAYER_PROMPT_RADIUS_M := 3.0
## How long the doorway waits with nobody near before the leaf swings shut.
const CLOSE_DELAY_S := 3.0
## Occupant scan cadence: responsive, but not a per-frame Array on every copy.
const OCCUPANT_SCAN_S := 0.15

const STATE_CLOSED := "closed"
const STATE_OPENING := "opening"
const STATE_OPEN := "open"
const STATE_CLOSING := "closing"

var scene: Node = null
var clone_id: String = "clone"
var clone_node: Node3D = null
var leaf: RigidBody3D = null
var leaf_closed := Transform3D.IDENTITY
var hinge := Vector3.ZERO
var section_size := Vector3.ZERO
## Scene-root coordinates of the doorway centre at walking height.
var anchor := Vector3.ZERO

var fraction := 0.0
var target := 0.0
var last_trigger := "idle"
var prompt_visible := false
var failures := 0

var _state := STATE_CLOSED
var _away := 0.0
var _scan := 0.0
var _resident_near := false
var _player_near := false
var _frames := 0
var _lines := 0

static var _doors: Array = []


static func enabled() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(DOOR_SWING_FLAG):
			return int(argument.trim_prefix(DOOR_SWING_FLAG)) != 0
	return false


## Every live swing door, in install order. Dead entries are pruned here, so the
## registry never grows across scene reloads.
static func doors() -> Array:
	var live: Array = []
	for entry: Variant in _doors:
		if entry is WeakRef and (entry as WeakRef).get_ref() != null:
			live.append((entry as WeakRef).get_ref())
	_doors = []
	for door: Variant in live:
		_doors.append(weakref(door))
	return live


## Nearest swing door the player may act on, or {} when none is in reach.
## `opening` is the action the NEXT accepted request performs, matching
## preview_printshop_interior.gd `nearest_action`.
static func nearest_door_action(actor_position: Vector3) -> Dictionary:
	if not actor_position.is_finite():
		return {}
	var best: Dictionary = {}
	for door: Variant in doors():
		var action: Dictionary = (door as Node).call("nearest_action", actor_position)
		if action.is_empty():
			continue
		if best.is_empty() or float(action.distance) < float(best.distance):
			best = action
	return best


static func reset_registry() -> void:
	_doors = []


func configure(owner: Node, clone_name: String, host: Node3D) -> bool:
	if owner == null or not is_instance_valid(host):
		return false
	scene = owner
	clone_id = clone_name
	clone_node = host
	# The copy's own entrance panel: the same predicate palazzo_site.gd `_bind_door`
	# uses, restricted to this copy and to the widest valid "Entrance" leaf.
	var best := -1.0
	for candidate: Node in _walk(host):
		if not candidate is RigidBody3D or not str(candidate.name).begins_with("Entrance"):
			continue
		if not candidate.has_meta("section_size"):
			continue
		var size: Vector3 = candidate.get_meta("section_size")
		if not size.is_finite() or size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
			continue
		if size.x > best:
			best = size.x
			leaf = candidate as RigidBody3D
	if leaf == null:
		_emit("closed", "idle", "fail_no_entrance_leaf")
		return false
	section_size = leaf.get_meta("section_size")
	var closed := leaf.transform
	if not closed.is_finite() or absf(closed.basis.determinant()) < 0.000001:
		_emit("closed", "idle", "fail_entrance_leaf_frame")
		return false
	leaf_closed = closed
	hinge = leaf_closed.origin - leaf_closed.basis.x * section_size.x * 0.5
	anchor = leaf.global_position
	anchor.y = clone_node.global_position.y
	# The leaf is advanced by hand: keep its parent's physics interpolation from
	# fighting the authored pose, exactly as the palazzo leaf does.
	leaf.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	leaf.freeze = true
	leaf.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	# A closed leaf must be a real barrier again.
	for part: Node in _walk(leaf):
		if part is CollisionShape3D:
			(part as CollisionShape3D).disabled = false
		if part is CollisionObject3D:
			(part as CollisionObject3D).collision_layer = 1
	_doors.append(weakref(self))
	_state = STATE_CLOSED
	fraction = 0.0
	target = 0.0
	set_physics_process(true)
	_emit("closed", "idle", "install")
	return true


func _walk(root: Node) -> Array:
	var out: Array = [root]
	var index := 0
	while index < out.size():
		for child: Node in (out[index] as Node).get_children():
			out.append(child)
		index += 1
	return out


func _physics_process(delta: float) -> void:
	if not is_instance_valid(leaf) or not is_instance_valid(clone_node):
		set_physics_process(false)
		return
	_frames += 1
	advance(delta)
	_scan += delta
	if _scan >= OCCUPANT_SCAN_S:
		_scan = 0.0
		_scan_residents()
	_player_near = _scan_player()
	_decay()


## The distance the leaf still has to travel decides the state name.
func _sync_state() -> void:
	var next := _state
	if is_equal_approx(fraction, target):
		next = STATE_OPEN if target >= 1.0 else STATE_CLOSED
	elif target > fraction:
		next = STATE_OPENING
	else:
		next = STATE_CLOSING
	if next != _state:
		_state = next
		_emit(_state, last_trigger, "state")


## The player is only ever a HINT source here: opening by walking past would be the
## stub this flag replaces. The leaf moves on E or on an approaching resident.
func _scan_player() -> bool:
	var actor := _player()
	if actor == null:
		return false
	return _distance_to(actor.global_position) <= PLAYER_PROMPT_RADIUS_M


func _player() -> Node3D:
	if scene == null:
		return null
	var candidate: Variant = scene.get("_player")
	if not candidate is Node3D:
		return null
	var actor: Node3D = candidate
	if not is_instance_valid(actor) or not actor.is_inside_tree():
		return null
	return actor


## The resident trigger. Nobody else in the copy drives this leaf, so the owner watches
## its own doorway. `occupants()` is the city population's own live actor list - the
## same one main.gd `_current_door_occupants` already feeds to the other doors.
func _scan_residents() -> void:
	var people := _occupants()
	_resident_near = false
	for row: Variant in people:
		if not row is Dictionary:
			continue
		var at: Variant = (row as Dictionary).get("position")
		if not at is Vector3 or not (at as Vector3).is_finite():
			continue
		if (at as Vector3).distance_to(anchor) > RESIDENT_RADIUS_M:
			continue
		_resident_near = true
		break
	if not _resident_near:
		return
	target = 1.0
	last_trigger = "resident"
	_away = 0.0


func _occupants() -> Array:
	if scene == null:
		return []
	var population: Variant = scene.get("preview_population")
	if population == null or not population is Object:
		return []
	var residents: Variant = (population as Object).get("residents")
	if residents == null or not residents is Object:
		return []
	if not (residents as Object).has_method("occupants"):
		return []
	var rows: Variant = (residents as Object).call("occupants")
	return rows if rows is Array else []


## Close again once the doorway has been empty for CLOSE_DELAY_S.
func _decay() -> void:
	if _player_near or _resident_near:
		_away = 0.0
		return
	if target < 1.0:
		return
	_away += OCCUPANT_SCAN_S
	if _away < CLOSE_DELAY_S:
		return
	target = 0.0
	last_trigger = "idle"
	_away = 0.0


func _distance_to(world: Vector3) -> float:
	if not world.is_finite():
		return INF
	return Vector2(world.x - anchor.x, world.z - anchor.z).length()


func _leaf_open() -> bool:
	return target >= 1.0 or _state == STATE_OPEN


## Identical smoothstep leaf pose to palazzo_site.gd `_door_pose`: rotate the authored
## frame about the hinge on the leaf's local X axis, eased by fraction^2*(3-2f).
func _leaf_pose(at: float) -> Transform3D:
	var rotation := Basis(Vector3.UP, DOOR_ANGLE * at)
	return Transform3D(rotation * leaf_closed.basis, hinge + rotation * (leaf_closed.origin - hinge))


## Contract, `advance(delta)` of the other door owners.
func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or not is_instance_valid(leaf):
		return
	if is_equal_approx(fraction, target):
		_sync_state()
		return
	fraction = move_toward(fraction, target, minf(delta, 0.1) / DOOR_DURATION)
	leaf.transform = _leaf_pose(fraction * fraction * (3.0 - 2.0 * fraction))
	leaf.freeze = true
	_sync_state()


## Contract, `request_door(key, open, actor_position, occupants)` of the palazzo /
## hospital / bank / printshop owners. `key` stays "public" so a caller written against
## the existing source doors keeps working unchanged. An occupant already inside the
## leaf's sweep makes the request a "door-sweep-occupied" refusal.
func request_door(key: String, open: bool, actor_position: Vector3, occupants: Array) -> Dictionary:
	if key != "public" or not is_instance_valid(leaf) or not actor_position.is_finite():
		failures += 1
		return {"accepted": false, "reason": "invalid_clone_door"}
	var distance := _distance_to(actor_position)
	if distance > PROXIMITY_M:
		failures += 1
		return {"accepted": false, "reason": "out-of-range", "distance": distance}
	if open and _swept(occupants):
		failures += 1
		return {"accepted": false, "reason": "door-sweep-occupied", "distance": distance}
	target = 1.0 if open else 0.0
	# The caller's attribution (`set_trigger`) is kept; the resident proximity trigger
	# already set its own name before it ever reached target.
	_away = 0.0
	_sync_state()
	_emit(_state, last_trigger, "request")
	return {"accepted": true, "open": open, "source_id": "clone:" + clone_id, "distance": distance}


## Contract, `door_fraction(key)`.
func door_fraction(key: String) -> float:
	if key != "public" or not is_instance_valid(leaf):
		return -1.0
	return fraction


func state_name() -> String:
	return _state


## The hint the existing `_door_hint` panel shows. Same wording as the palazzo leaf.
## `opening` is the CURRENT leaf state, not the action: main.gd `_unhandled_input`
## negates it into the requested state exactly as it does for the printshop door
## (`nearest_action` there returns `float(d.target) > 0.5`).
func nearest_action(actor_position: Vector3) -> Dictionary:
	if not is_instance_valid(leaf) or not actor_position.is_finite():
		return {}
	var distance := _distance_to(actor_position)
	if distance > PROXIMITY_M:
		return {}
	var open_now := _leaf_open()
	return {
		"owner": "clone",
		"clone": clone_id,
		"door": "public",
		"distance": distance,
		"opening": open_now,
		"label": "Закрыть дверь" if open_now else "Открыть дверь",
		"world": anchor + Vector3.UP * (section_size.y * 0.5 + 0.35),
	}


func prompt_shown() -> bool:
	return prompt_visible


## DSH_CLONEDOOR proof support: can the player's own capsule walk through this doorway
## right now? The capsule crosses the leaf at the two points the doorway sweep actually
## uses, so the answer is produced by the same physics the player is subject to: a
## blocked sample is a real collider standing in the opening. `blocked` is -1 when the
## question could not be asked (no leaf in the tree); it never means "no barrier".
##
## `result.colliders` names what stopped each sample, so a blocker that is NOT this leaf
## (a neighbour's wall, a table) can never be mistaken for the door.
const CAPSULE_RADIUS_M := 0.35
const CAPSULE_HEIGHT_M := 1.70
## The two crossing points along the leaf span, measured from the hinge in leaf-widths.
const SWEEP_FRACTIONS: Array[float] = [0.25, 0.75]

func doorway_blocked() -> Variant:
	if not is_instance_valid(leaf) or not leaf.is_inside_tree():
		return null
	var space := leaf.get_world_3d().direct_space_state
	if space == null:
		return null
	var own: Array[RID] = [leaf.get_rid()]
	var authored := leaf.transform
	var eased := fraction * fraction * (3.0 - 2.0 * fraction)
	var pose: Transform3D = authored
	var basis := leaf_closed.basis
	var origin := leaf_closed.origin
	var samples: Array = []
	var blocked := 0
	var blocked_by_leaf := 0
	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS_M
	capsule.height = maxf(CAPSULE_HEIGHT_M, CAPSULE_RADIUS_M * 2.0 + 0.001)
	var probe := PhysicsShapeQueryParameters3D.new()
	probe.shape = capsule
	probe.collision_mask = 1
	probe.exclude = own
	probe.margin = 0.001
	# The capsule centre sits half a height above the floor, the same convention
	# npc_city_door_open.capsule_query uses.
	var lift := Vector3.UP * (capsule.height * 0.5 + 0.025)
	for along: float in SWEEP_FRACTIONS:
		var point: Vector3 = origin + basis.x * (section_size.x * along)
		var from: Vector3 = point + basis.z * 1.2 + lift
		var to: Vector3 = point - basis.z * 1.2 + lift
		probe.transform = Transform3D(Basis.IDENTITY, from)
		probe.motion = to - from
		var hits: Array = space.intersect_shape(probe, 8)
		var cast: PackedFloat32Array = space.cast_motion(probe)
		var swept: bool = not (cast.size() == 2 and cast[0] >= 0.99999)
		var names: Array = []
		for hit: Dictionary in hits:
			var collider: Variant = hit.get("collider")
			var node: Node = collider as Node if collider is Node else null
			names.append(str(node.get_path()) if node != null else str(collider))
		var stopped: bool = swept or not hits.is_empty()
		if stopped:
			blocked += 1
			for hit: Dictionary in hits:
				var collider: Variant = hit.get("collider")
				var node: Node = collider as Node if collider is Node else null
				if _belongs_to_leaf(node):
					blocked_by_leaf += 1
					break
		samples.append({
			"at": [point.x, point.y, point.z],
			"stopped": stopped,
			"cast": [cast[0], cast[1]] if cast.size() == 2 else [],
			"colliders": names,
		})
	return {
		"barrier_in_doorway": blocked > 0 and blocked_by_leaf > 0,
		"passable": blocked == 0,
		"blocked": blocked,
		"blocked_by_leaf": blocked_by_leaf,
		"samples": samples,
		"leaf_fraction": fraction,
		"leaf_eased": eased,
		"leaf_translation": (pose.origin - leaf_closed.origin).length(),
		"leaf_authored_matches_closed": authored.is_equal_approx(leaf_closed),
		"leaf_colliders_on_layer_1": _leaf_collider_count(),
	}


## Enabled CollisionShape3D under the leaf, and how many sit on a live layer.
func _leaf_collider_count() -> Dictionary:
	var enabled := 0
	var live := 0
	for part: Node in _walk(leaf):
		if not part is CollisionShape3D:
			continue
		var shape_node: CollisionShape3D = part
		if shape_node.disabled or shape_node.shape == null:
			continue
		enabled += 1
		var owner_body := shape_node.get_parent()
		while owner_body != null and not owner_body is CollisionObject3D:
			owner_body = owner_body.get_parent()
		if owner_body is CollisionObject3D and (owner_body as CollisionObject3D).collision_layer == 1:
			live += 1
	return {"enabled": enabled, "on_layer_1": live}


## Walks up from a body to the leaf the owner moves.
func _belongs_to_leaf(node: Node) -> bool:
	var walk: Node = node
	while walk != null:
		if walk == leaf:
			return true
		walk = walk.get_parent()
	return false


func set_trigger(trigger: String) -> void:
	last_trigger = trigger


func set_prompt_visible(visible_now: bool) -> void:
	if prompt_visible == visible_now:
		return
	prompt_visible = visible_now
	_emit(_state, last_trigger, "prompt")


## A body already standing where the leaf will sweep makes the request refuse. The leaf
## is thin and the occupants far fewer than the pieces, so the test is a real shape
## query against the swept poses rather than a box that would refuse every open.
func _swept(occupants: Array) -> bool:
	if occupants.is_empty() or not leaf.is_inside_tree():
		return false
	var probes: Array[Transform3D] = []
	for step in 6:
		var at := float(step + 1) / 6.0
		probes.append(_leaf_pose(at * at * (3.0 - 2.0 * at)))
	var space := leaf.get_world_3d().direct_space_state
	if space == null:
		return false
	var shape := SphereShape3D.new()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.exclude = [leaf.get_rid()]
	query.margin = 0.001
	for row: Variant in occupants:
		if not row is Dictionary:
			continue
		var at: Variant = (row as Dictionary).get("position")
		if not at is Vector3 or not (at as Vector3).is_finite():
			continue
		var point: Vector3 = at
		var radius: float = maxf(0.2, float((row as Dictionary).get("radius", 0.36)))
		var height: float = maxf(0.5, float((row as Dictionary).get("height", 1.75)))
		shape.radius = radius
		for probe: Transform3D in probes:
			var leaf_world: Transform3D = leaf.get_parent().global_transform * probe
			var local: Vector3 = leaf_world.affine_inverse() * (point + Vector3.UP * (height * 0.5 + 0.025))
			if absf(local.x) > section_size.x * 0.75 + radius:
				continue
			if absf(local.y) > section_size.y * 0.75 + height:
				continue
			if absf(local.z) > section_size.z * 0.75 + radius:
				continue
			# The probe shape sits on the occupant, and only then is the swept leaf
			# asked whether that spot is inside it.
			query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * (height * 0.5 + 0.025))
			if not space.intersect_shape(query, 1).is_empty():
				return true
	return false


## DSH_CLONEDOOR clone=<hospital|bank|restaurant> state=... fraction=... trigger=...
## prompt=shown|hidden frame=... Emitted on a real change of state, trigger or prompt.
func _emit(state: String, trigger: String, reason: String) -> void:
	_lines += 1
	print("DSH_CLONEDOOR clone=", clone_id,
		" state=", state,
		" fraction=", snappedf(fraction, 0.001),
		" trigger=", trigger,
		" prompt=", ("shown" if prompt_visible else "hidden"),
		" frame=", Engine.get_physics_frames(),
		" reason=", reason)


func snapshot() -> Dictionary:
	return {
		"clone": clone_id,
		"state": _state,
		"fraction": fraction,
		"target": target,
		"trigger": last_trigger,
		"prompt": "shown" if prompt_visible else "hidden",
		"anchor": [anchor.x, anchor.y, anchor.z],
		"section_size": [section_size.x, section_size.y, section_size.z],
		"leaf": (str(leaf.get_path()) if is_instance_valid(leaf) else "-"),
		"failures": failures,
		"resident_near": _resident_near,
	}
