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
## Coordinator28 proposal: all callers share the same live-shape sweep. The
## occupants argument remains API compatible; it cannot grant collision exemptions.
## The native clone site remains responsible for geometry and batched rendering.

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
const MAX_ARC_STEP := PI / 90.0
const MAX_SWEEP_HITS := 64
const BLOCKED_RETRY_S := 0.10

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
## A rejected open still asks the blocking NPC to clear the live leaf arc.
## A later close request revokes that intent even if target was already closed.
var _opening_requested31 := false
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
var _hold_s := 0.0
var _blocked_reason := ""
var _sweep_checks := 0
var _visual_mode := "unbound"
var _entrance_count := 0
var _configured := false
var _request_retry_s := 0.0
var _request_blocked_target := -1.0
var _sweep_query := PhysicsShapeQueryParameters3D.new()
var _shape_rows: Array[Dictionary] = []

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
## `opening` is the current requested open state, matching
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
	set_physics_process(false)
	_configured = false
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
		_entrance_count += 1
	# Freshly instantiated sites expose the actual leaf their render records own.
	# Never select a foreign body retained in duplicated metadata.
	var native_leaf: Variant = clone_node.get("_door")
	if native_leaf is RigidBody3D and clone_node.is_ancestor_of(native_leaf):
		leaf = native_leaf as RigidBody3D
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
	# Preserve the authored filters/shapes. An already disabled or fractured leaf
	# must not be resurrected by an interaction controller.
	if not _available() or not _collect_shapes() or not _bind_visual_owner():
		_emit("closed", "idle", "fail_leaf_collision_or_visual_binding")
		return false
	leaf.freeze = true
	leaf.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	_sweep_query.collision_mask = 0xFFFFFFFF
	_sweep_query.collide_with_areas = false
	_sweep_query.collide_with_bodies = true
	_sweep_query.exclude = [leaf.get_rid()]
	_configured = true
	_doors.append(weakref(self))
	_state = STATE_CLOSED
	fraction = 0.0
	target = 0.0
	_opening_requested31 = false
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
	if not _configured or not _available():
		set_physics_process(false)
		return
	_frames += 1
	_request_retry_s = maxf(0.0, _request_retry_s - delta)
	advance(delta)
	_scan += delta
	if _scan >= OCCUPANT_SCAN_S:
		_scan = 0.0
		_scan_residents()
	_player_near = _scan_player()
	_decay(delta)


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
	_away = 0.0
	if target < 1.0:
		_request_target(true, "resident")


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
func _decay(delta: float) -> void:
	if _player_near or _resident_near:
		_away = 0.0
		return
	if target < 1.0:
		return
	_away += delta
	if _away < CLOSE_DELAY_S:
		return
	# A blocked request is retried on the bounded occupant cadence, not every tick.
	_away = CLOSE_DELAY_S - OCCUPANT_SCAN_S
	_request_target(false, "idle")


func _distance_to(world: Vector3) -> float:
	if not world.is_finite():
		return INF
	return Vector2(world.x - anchor.x, world.z - anchor.z).length()


func _leaf_open() -> bool:
	return target >= 1.0 or _state == STATE_OPEN


## Identical smoothstep leaf pose to palazzo_site.gd `_door_pose`: rotate the authored
## frame about the vertical hinge axis, eased by fraction^2*(3-2f).
func _leaf_pose(at: float) -> Transform3D:
	var rotation := Basis(Vector3.UP, DOOR_ANGLE * at)
	return Transform3D(rotation * leaf_closed.basis, hinge + rotation * (leaf_closed.origin - hinge))


## Contract, `advance(delta)` of the other door owners.
func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or not _available():
		return
	if is_equal_approx(fraction, target):
		_sync_state()
		return
	_hold_s = maxf(0.0, _hold_s - delta)
	if _hold_s > 0.0:
		return
	var next: float = move_toward(fraction, target, minf(delta, 0.1) / DOOR_DURATION)
	var reason: String = _sweep_reason(_ease(fraction), _ease(next))
	if not reason.is_empty():
		_set_blocked(reason)
		_hold_s = BLOCKED_RETRY_S
		return
	_set_blocked("")
	fraction = next
	_commit_pose()
	_sync_state()


## Contract, `request_door(key, open, actor_position, occupants)` of the palazzo /
## hospital / bank / printshop owners. `key` stays "public" so a caller written against
## the existing source doors keeps working unchanged. An occupant already inside the
## leaf's sweep makes the request a "door-sweep-occupied" refusal.
func request_door(key: String, open: bool, actor_position: Vector3, _occupants: Array) -> Dictionary:
	if key != "public" or not _configured or not _available() or not actor_position.is_finite():
		failures += 1
		return {"accepted": false, "reason": "invalid_clone_door"}
	var distance := _distance_to(actor_position)
	if distance > PROXIMITY_M:
		failures += 1
		return {"accepted": false, "reason": "out-of-range", "distance": distance}
	var requested: Dictionary = _request_target(open, last_trigger)
	if not bool(requested.get("accepted", false)):
		failures += 1
		return {"accepted": false, "reason": "door-sweep-occupied", "distance": distance}
	return {"accepted": true, "open": open, "source_id": "clone:" + clone_id, "distance": distance}


func opening_requested31() -> bool:
	return _configured and _available() and _opening_requested31


func _request_target(open: bool, trigger: String) -> Dictionary:
	_opening_requested31 = open
	var next: float = 1.0 if open else 0.0
	if is_equal_approx(target, next):
		return {"accepted": true}
	if _request_retry_s > 0.0 and is_equal_approx(_request_blocked_target, next):
		return {"accepted": false, "reason": "sweep_retry_pending"}
	var reason: String = _sweep_reason(_ease(fraction), next)
	if not reason.is_empty():
		_request_retry_s = BLOCKED_RETRY_S
		_request_blocked_target = next
		_set_blocked(reason)
		return {"accepted": false, "reason": reason}
	target = next
	last_trigger = trigger
	_away = 0.0
	_hold_s = 0.0
	_request_retry_s = 0.0
	_set_blocked("")
	_sync_state()
	_emit(_state, last_trigger, "request")
	return {"accepted": true}


## Contract, `door_fraction(key)`.
func door_fraction(key: String) -> float:
	if key != "public" or not _configured or not _available():
		return -1.0
	return fraction


func state_name() -> String:
	return _state


## The hint the existing `_door_hint` panel shows. Same wording as the palazzo leaf.
## `opening` is the CURRENT leaf state, not the action: main.gd `_unhandled_input`
## negates it into the requested state exactly as it does for the printshop door
## (`nearest_action` there returns `float(d.target) > 0.5`).
func nearest_action(actor_position: Vector3) -> Dictionary:
	if not _configured or not _available() or not actor_position.is_finite():
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


## Read-only full-body proof at the live doorway. The player's actual capsule,
## basis and mask are retained; ONLY the player is excluded, never the leaf.
## This is a geometric sweep, not evidence that an actor actually walked across.
func doorway_blocked() -> Variant:
	var actor: CharacterBody3D = _player() as CharacterBody3D
	if not _available() or actor == null:
		return null
	var capsule: CollisionShape3D = null
	for child: Node in actor.get_children():
		if child is CollisionShape3D and not child.disabled and child.shape is CapsuleShape3D:
			capsule = child as CollisionShape3D
			break
	if capsule == null:
		return null
	var frame: Transform3D = leaf.get_parent().global_transform * leaf_closed
	var normal: Vector3 = frame.basis.z.normalized()
	normal.y = 0.0
	normal = normal.normalized()
	var ends: Array[Vector3] = [anchor + normal * 1.35, anchor - normal * 1.35]
	var space: PhysicsDirectSpaceState3D = leaf.get_world_3d().direct_space_state
	var floors: Array[float] = []
	for point: Vector3 in ends:
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			point + Vector3.UP * 0.75, point - Vector3.UP, actor.collision_mask, [actor.get_rid()])
		var floor_hit: Dictionary = space.intersect_ray(ray)
		if floor_hit.is_empty() or (floor_hit.normal as Vector3).dot(Vector3.UP) < 0.7:
			return {"ok": false, "reason": "doorway_floor_missing", "passable": false}
		floors.append(float(floor_hit.position.y))
	var floor_y: float = maxf(floors[0], floors[1])
	ends[0].y = floor_y + 0.003
	ends[1].y = floor_y + 0.003
	var samples: Array[Dictionary] = []
	var blocked: int = 0
	var blocked_by_leaf: int = 0
	for direction: int in 2:
		var start: Vector3 = ends[direction]
		var finish: Vector3 = ends[1 - direction]
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = capsule.shape
		query.transform = Transform3D(actor.global_basis, start) * capsule.transform
		query.collision_mask = actor.collision_mask
		query.exclude = [actor.get_rid()]
		query.margin = 0.001
		var hits: Array[Dictionary] = space.intersect_shape(query, MAX_SWEEP_HITS)
		var collision := KinematicCollision3D.new()
		var stopped: bool = actor.test_move(Transform3D(actor.global_basis, start),
			finish - start, collision, actor.safe_margin, false, 16)
		var names: Array[String] = []
		var own_hit: bool = false
		for hit: Dictionary in hits:
			var node: Node = hit.get("collider") as Node
			if node != null:
				names.append(str(node.get_path()))
				own_hit = own_hit or _belongs_to_leaf(node)
		for index: int in collision.get_collision_count():
			var node: Node = collision.get_collider(index) as Node
			if node != null:
				names.append(str(node.get_path()))
				own_hit = own_hit or _belongs_to_leaf(node)
		stopped = stopped or not hits.is_empty()
		if stopped:
			blocked += 1
		if own_hit:
			blocked_by_leaf += 1
		samples.append({"direction": direction, "stopped": stopped,
			"colliders": names, "start": start, "finish": finish})
	return {"ok": true, "barrier_in_doorway": blocked_by_leaf > 0,
		"passable": blocked == 0, "blocked": blocked, "blocked_by_leaf": blocked_by_leaf,
		"samples": samples, "leaf_fraction": fraction, "leaf_excluded": false,
		"capsule_radius": capsule.shape.radius, "capsule_height": capsule.shape.height,
		"floor_samples": floors, "physical_traversal": false,
		"leaf_colliders_on_layer_1": _leaf_collider_count()}


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


func _available() -> bool:
	return is_instance_valid(clone_node) and is_instance_valid(leaf) and leaf.is_inside_tree() \
		and clone_node.is_ancestor_of(leaf) and leaf.collision_layer != 0 \
		and not clone_node.is_queued_for_deletion() and not leaf.is_queued_for_deletion() \
		and not leaf.get_meta("detached", false) and not leaf.get_meta("fracture_active", false)


func _collect_shapes() -> bool:
	_shape_rows.clear()
	for child: Node in leaf.get_children():
		if not child is CollisionShape3D or child.disabled or child.shape == null:
			continue
		# The authored Palazzo leaf has boxes. An unknown shape is never replaced
		# with a smaller approximate shape just to let the door move.
		if not child.shape is BoxShape3D:
			return false
		_shape_rows.append({"node": weakref(child)})
	return not _shape_rows.is_empty()


func _bind_visual_owner() -> bool:
	var records: Variant = clone_node.get("render_by_id")
	if records is Dictionary and records.has(leaf.get_instance_id()):
		var record: Dictionary = records[leaf.get_instance_id()]
		if record.get("body") == leaf and clone_node.has_method("_queue_render") \
			and clone_node.has_method("_sync_batches"):
			_visual_mode = "native_batch"
			return true
	# A truly unbatched leaf needs no resource rewrite. Hidden batched sources
	# without an owner are an error, not permission to unhide duplicate meshes.
	var visible_meshes: int = 0
	for child: Node in leaf.get_children():
		if child is MeshInstance3D:
			if not child.visible:
				return false
			visible_meshes += 1
	_visual_mode = "direct_mesh" if visible_meshes > 0 else "unbound"
	return visible_meshes > 0


static func _ease(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)


func _commit_pose() -> void:
	var eased: float = _ease(fraction)
	var pose: Transform3D = _leaf_pose(eased)
	leaf.transform = pose
	# Native render records own the matching mesh instances. Never write to a
	# MultiMesh resource found by mesh/position heuristics (copies may share it).
	if _visual_mode != "native_batch":
		return
	clone_node.call("_queue_render", leaf)
	var chunks: Variant = leaf.get_meta("pooled_fragments", [])
	if chunks is Array:
		for entry: Variant in chunks:
			if not entry is RigidBody3D or not is_instance_valid(entry):
				continue
			var chunk: RigidBody3D = entry
			if not clone_node.is_ancestor_of(chunk) or chunk.get_parent() != leaf.get_parent():
				continue
			if chunk.get_meta("detached", false) or not chunk.has_meta("panel_center"):
				continue
			var centre: Variant = chunk.get_meta("panel_center")
			if not centre is Vector3:
				continue
			chunk.transform = pose * Transform3D(Basis.IDENTITY, centre)
			var initial: Variant = clone_node.get("initial_transforms")
			if initial is Dictionary:
				initial[chunk.get_instance_id()] = chunk.global_transform
			clone_node.call("_queue_render", chunk)
	if clone_node.get("_door") == leaf:
		clone_node.set("_door_angle", DOOR_ANGLE * eased)
		clone_node.set("_door_target_open", target >= 1.0)
		clone_node.set("_door_open", fraction >= 1.0)
	var glazing: Variant = clone_node.get("_glazing")
	if glazing is Node and is_instance_valid(glazing) and clone_node.is_ancestor_of(glazing):
		if glazing.has_method("sync_moving_panes"):
			glazing.call("sync_moving_panes")
	clone_node.call("_sync_batches")
	if clone_node.has_method("_mark_structure_dirty"):
		clone_node.call("_mark_structure_dirty")


func _blocks_swing(collider: Variant) -> bool:
	if not collider is CollisionObject3D:
		return false
	if collider is CharacterBody3D:
		return true
	# Same physical classes as native door_close43, plus parked/detached rubble.
	# The authored floor/jamb contact is static architecture, not an actor.
	# It remains fully collidable for player/NPC movement and passage queries.
	if (collider.collision_layer & (2 | 256 | 512 | 1024)) != 0:
		return true
	return collider is RigidBody3D and (not collider.freeze \
		or collider.get_meta("detached", false) or collider.get_meta("parked", false))


func _sweep_reason(from_eased: float, to_eased: float) -> String:
	if not _available() or _shape_rows.is_empty():
		return "leaf_unavailable"
	var space: PhysicsDirectSpaceState3D = leaf.get_world_3d().direct_space_state
	if space == null:
		return "physics_unavailable"
	var span: float = absf(to_eased - from_eased) * DOOR_ANGLE
	var steps: int = maxi(1, int(ceil(span / MAX_ARC_STEP)))
	var parent_frame: Transform3D = leaf.get_parent().global_transform
	for row: Dictionary in _shape_rows:
		var shape_node: CollisionShape3D = row.node.get_ref() as CollisionShape3D
		if not is_instance_valid(shape_node) or shape_node.disabled or not shape_node.shape is BoxShape3D:
			return "leaf_shape_changed"
		# A midpoint pose enlarged by the largest point's possible arc travel
		# conservatively contains the whole angular segment, including endpoints.
		var box: BoxShape3D = shape_node.shape as BoxShape3D
		var centre: Vector3 = leaf_closed * shape_node.position
		var scale: Vector3 = shape_node.transform.basis.get_scale().abs()
		var shape_radius: float = box.size.length() * 0.5 * maxf(scale.x, maxf(scale.y, scale.z))
		var radius: float = centre.distance_to(hinge) + shape_radius
		_sweep_query.shape = shape_node.shape
		_sweep_query.margin = 0.001 + radius * span / float(steps) * 0.5
		_sweep_query.motion = Vector3.ZERO
		for step: int in steps:
			var at: float = lerpf(from_eased, to_eased, (float(step) + 0.5) / float(steps))
			_sweep_query.transform = parent_frame * _leaf_pose(at) * shape_node.transform
			var hits: Array[Dictionary] = space.intersect_shape(_sweep_query, MAX_SWEEP_HITS)
			_sweep_checks += 1
			if hits.size() >= MAX_SWEEP_HITS:
				return "sweep_query_saturated"
			for hit: Dictionary in hits:
				var collider: Variant = hit.get("collider")
				if _blocks_swing(collider):
					return "sweep_body:" + str((collider as Node).get_path())
	return ""


func _set_blocked(reason: String) -> void:
	if _blocked_reason == reason:
		return
	_blocked_reason = reason
	_emit(_state, last_trigger, "motion_clear" if reason.is_empty() else reason)


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
		"opening_requested31": _opening_requested31,
		"trigger": last_trigger,
		"prompt": "shown" if prompt_visible else "hidden",
		"anchor": [anchor.x, anchor.y, anchor.z],
		"section_size": [section_size.x, section_size.y, section_size.z],
		"leaf": (str(leaf.get_path()) if is_instance_valid(leaf) else "-"),
		"failures": failures,
		"resident_near": _resident_near,
		"motion_blocked": not _blocked_reason.is_empty(),
		"blocked_reason": _blocked_reason,
		"empty_seconds": _away,
		"visual_mode": _visual_mode,
		"entrance_count": _entrance_count,
		"configured": _configured,
		"sweep_checks": _sweep_checks,
	}
