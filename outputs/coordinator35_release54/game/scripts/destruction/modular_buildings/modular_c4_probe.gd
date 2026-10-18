extends Node
## DSH_CITYTOWN probe (flag --city-town-damage-test=1, requires --city-town-damage=1).
##
## Honest end-to-end C4 exercise on a ported modular site. It drives the REAL local
## C4 equipment: real placement query (c4_placement_query45.gd two native rays), real
## 3-second hold, real `consume_detonation` capability and the real blast owner
## (`c4_building_blast.gd`). Nothing is fabricated: the probe only moves the player,
## aims the camera and injects the same left-mouse button events a player produces.
##
## Why this shape: the C4 charge can only be consumed by the exact dictionary the
## equipment itself dispatches (`c4_equipment.gd:351-361`), so there is no legal way
## to prove "C4 removes a part" without going through the equipment. This probe never
## calls `consume_detonation`, `detonate` or `apply_explosion` directly.
##
## Default (no flag): never created. If the probe cannot place a charge, it says so
## and leaves the world untouched (mouse released, no charge, no detonation).

const TAG := "CITY_TOWN_DAMAGE_TEST"
const MAX_FRAMES := 5400        # ~90 s at 60 Hz hard stop for the whole probe.
const MAX_HOLD_FRAMES := 480    # ~8 s for one 3-second hold.
const MAX_VERIFY_FRAMES := 90
const SETTLE_MIN_FRAMES := 2
const SETTLE_MAX_FRAMES := 60
const REACHES := [1.45, 1.85]
const PITCH_OFFSETS := [0.0, -0.05, 0.05, -0.10, 0.10]
const CAMERA_BACK_M := 2.6
const EYE_M := 1.45

var _world: WeakRef
var _site_ref: WeakRef
var _owner_ref: WeakRef
var _state := "wait_ready"
var _frames := 0
var _state_frames := 0
var _mouse_down := false
var _plan: Array[Dictionary] = []
var _plan_cursor := 0
var _pitch_cursor := 0
var _before: Dictionary = {}
var _attempts := 0
var _placed_id := ""

func attach(world: Node3D, site: Node3D, owner: Node) -> bool:
	if not is_instance_valid(world) or not is_instance_valid(site) or not is_instance_valid(owner): return false
	_world = weakref(world)
	_site_ref = weakref(site)
	_owner_ref = weakref(owner)
	set_physics_process(true)
	return true

func _world_ref() -> Node3D:
	return _world.get_ref() if _world != null else null

func _site() -> Node3D:
	return _site_ref.get_ref() if _site_ref != null else null

func _equipment() -> Variant:
	var world: Node3D = _world_ref()
	return world.get("preview_c4") if is_instance_valid(world) else null

func _player() -> Variant:
	var world: Node3D = _world_ref()
	return world.get("_player") if is_instance_valid(world) else null

func _physics_process(_delta: float) -> void:
	if _state == "finished": return
	_frames += 1
	_state_frames += 1
	if _frames >= MAX_FRAMES: _finish("timeout", {}); return
	match _state:
		"wait_ready": _step_wait_ready()
		"place_stand": _step_place_stand()
		"settle": _step_settle()
		"check": _step_check()
		"select": _step_select()
		"hold": _step_hold()
		"drop": _step_drop()
		"detonate": _step_detonate()
		"verify": _step_verify()

func _world_ready() -> bool:
	var world: Node3D = _world_ref()
	var site: Node3D = _site()
	var player: Variant = _player()
	var equipment: Variant = _equipment()
	if not is_instance_valid(world) or not is_instance_valid(site) or not is_instance_valid(player) or not is_instance_valid(equipment): return false
	if world.get("preview_ready") != true or world.get("preview_dead") == true or world.get("preview_physics_fault") == true: return false
	if site.get("site_ready") != true or site.get("rebuilding") == true: return false
	if player.get("_pose_authority") != &"on_foot": return false
	var snapshot: Dictionary = equipment.call("snapshot")
	return snapshot.get("ready", false) == true

func _step_wait_ready() -> void:
	if not _world_ready(): return
	var player: Variant = _player()
	if player.get("_free_mouse_look") != true: player.call("set_mouse_captured", true)
	_plan = _build_plan()
	_plan_cursor = 0
	_pitch_cursor = 0
	var site: Node3D = _site()
	var stats: Dictionary = site.call("get_stats")
	_before = {"detached":int(stats.get("detached", 0)),"pieces":int(stats.get("pieces", 0)),"glazing_broken":_glazing_broken(site)}
	if _plan.is_empty():
		_finish("no_stand_point", {"site_aabb":str(_local_aabb(site))})
		return
	print(TAG, " start ", JSON.stringify({"source_id":str(site.get("source_id")),"stand_points":_plan.size(),"before":_before}))
	_state = "place_stand"; _state_frames = 0

## Stand points around the authored building AABB, expressed in the site's local frame
## and converted to world space by the site transform (yaw included).
func _build_plan() -> Array[Dictionary]:
	var site: Node3D = _site()
	var box: AABB = _local_aabb(site)
	var plan: Array[Dictionary] = []
	if box.size.length_squared() <= 0.000001: return plan
	var centre := box.get_center()
	var half := box.size * 0.5
	var floor_y: float = _floor_y(site, box)
	for index in 8:
		var angle: float = TAU * float(index) / 8.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var support: float = absf(direction.x) * half.x + absf(direction.z) * half.z
		for reach: float in REACHES:
			var stand := Vector3(centre.x, floor_y, centre.z) + direction * (support + reach)
			var aim := Vector3(clampf(stand.x, box.position.x, box.end.x), floor_y + EYE_M, clampf(stand.z, box.position.z, box.end.z))
			plan.append({"stand":site.global_transform * stand,"aim":site.global_transform * aim})
	return plan

func _floor_y(site: Node3D, box: AABB) -> float:
	var recipe: Variant = site.get("_recipe")
	if recipe is Dictionary:
		var soil: Variant = recipe.get("external_soil_required", {})
		if soil is Dictionary:
			var at: Variant = soil.get("at", [])
			var size: Variant = soil.get("size", [])
			if at is Array and size is Array and at.size() == 3 and size.size() == 3:
				return float(at[1]) + float(size[1]) * 0.5
	return box.position.y

func _local_aabb(site: Node3D) -> AABB:
	var root: Variant = site.get("building")
	if not root is Node3D: return AABB()
	var inverse: Transform3D = site.global_transform.affine_inverse()
	var result := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is VisualInstance3D:
			var visual := node as VisualInstance3D
			var local: AABB = inverse * (visual.global_transform * visual.get_aabb())
			if local.size.is_finite() and local.size.length() < 1.0e7:
				result = local if first else result.merge(local)
				first = false
		for child: Node in node.get_children(): stack.append(child)
	return result

func _step_place_stand() -> void:
	var site: Node3D = _site()
	var player: Variant = _player()
	if not is_instance_valid(site) or not is_instance_valid(player): _finish("site_or_actor_retired", {}); return
	if _plan_cursor >= _plan.size():
		_finish("no_valid_stand_point", {"attempts":_attempts})
		return
	var row: Dictionary = _plan[_plan_cursor]
	player.set("global_position", (row.stand as Vector3) + Vector3.UP * 0.10)
	player.set("velocity", Vector3.ZERO)
	_pitch_cursor = 0
	_aim(row)
	_state = "settle"; _state_frames = 0

## Re-aims on every settle frame: `_update_camera_rotation()` moves the spring arm,
## so the camera-space pitch is recomputed from the current player position.
func _aim(row: Dictionary) -> void:
	var player: Variant = _player()
	var camera: Camera3D = player.call("get_preview_camera")
	var stand: Vector3 = row.stand
	var aim: Vector3 = row.aim
	var flat := Vector3(aim.x - stand.x, 0.0, aim.z - stand.z)
	if flat.length_squared() <= 0.0001: return
	var look: Vector3 = flat.normalized()
	var yaw: float = atan2(-look.x, -look.z)
	var camera_estimate: Vector3 = stand + Vector3.UP * EYE_M - look * CAMERA_BACK_M
	var horizontal: float = Vector2(aim.x - camera_estimate.x, aim.z - camera_estimate.z).length()
	var pitch: float = atan2(aim.y - camera_estimate.y, maxf(horizontal, 0.001)) + float(PITCH_OFFSETS[mini(_pitch_cursor, PITCH_OFFSETS.size() - 1)])
	player.set("_camera_yaw", yaw)
	player.set("_heading", yaw)
	player.set("_camera_pitch", clampf(pitch, -0.7, 0.7))
	player.call("_update_camera_rotation")
	if is_instance_valid(camera): camera.force_update_transform()

func _step_settle() -> void:
	var player: Variant = _player()
	if not is_instance_valid(player): _finish("actor_retired", {}); return
	if _plan_cursor < _plan.size(): _aim(_plan[_plan_cursor])
	var speed: float = Vector2(player.get("velocity").x, player.get("velocity").z).length()
	var on_floor: bool = player.call("is_on_floor")
	if _state_frames >= SETTLE_MIN_FRAMES and on_floor and speed <= 0.08:
		_state = "check"; _state_frames = 0
		return
	if _state_frames >= SETTLE_MAX_FRAMES:
		# Unstable stand point: next one.
		_plan_cursor += 1
		_state = "place_stand"; _state_frames = 0

## Oracle: the equipment's own placement query. A non-empty dictionary means the
## camera ray, the actor corroboration ray, reach and surface ownership all pass.
func _step_check() -> void:
	var equipment: Variant = _equipment()
	if not is_instance_valid(equipment): _finish("equipment_retired", {}); return
	var target: Variant = equipment.call("_target")
	if target is Dictionary and not (target as Dictionary).is_empty():
		_state = "select"; _state_frames = 0
		return
	_pitch_cursor += 1
	if _pitch_cursor < PITCH_OFFSETS.size():
		_state = "settle"; _state_frames = 0
		return
	_plan_cursor += 1
	_state = "place_stand"; _state_frames = 0

func _step_select() -> void:
	var equipment: Variant = _equipment()
	if not is_instance_valid(equipment): _finish("equipment_retired", {}); return
	var chosen: Dictionary = equipment.call("select_placement")
	if chosen.get("ok", false) != true:
		_finish("equipment_select_failed", {"detail":chosen})
		return
	_attempts += 1
	_press(true)
	_state = "hold"; _state_frames = 0

func _step_hold() -> void:
	var equipment: Variant = _equipment()
	if not is_instance_valid(equipment): _release(); _finish("equipment_retired", {}); return
	var snapshot: Dictionary = equipment.call("snapshot")
	var placed: Array = snapshot.get("placed", [])
	if not placed.is_empty():
		_placed_id = str((placed[0] as Dictionary).get("id", ""))
		_state = "drop"; _state_frames = 0
		return
	if _state_frames >= MAX_HOLD_FRAMES:
		_release()
		equipment.call("select_placement")
		_pitch_cursor = 0
		_plan_cursor += 1
		_state = "place_stand"; _state_frames = 0

func _step_drop() -> void:
	if _mouse_down: _press(false)
	if _state_frames >= 4: _state = "detonate"; _state_frames = 0

func _step_detonate() -> void:
	var equipment: Variant = _equipment()
	if not is_instance_valid(equipment): _finish("equipment_retired", {}); return
	equipment.call("select_remote")
	_press(true)
	_state = "verify"; _state_frames = 0

func _step_verify() -> void:
	if _state_frames == 4 and _mouse_down: _press(false)
	if _state_frames < MAX_VERIFY_FRAMES: return
	var world: Node3D = _world_ref()
	var site: Node3D = _site()
	var evidence: Dictionary = {"source_id":str(site.get("source_id")) if is_instance_valid(site) else "","charge_id":_placed_id,"attempts":_attempts,"before":_before}
	if is_instance_valid(site):
		var after: Dictionary = site.call("get_stats")
		evidence["after"] = {"detached":int(after.get("detached", 0)),"pieces":int(after.get("pieces", 0)),"status":str(after.get("status", "")),"glazing_broken":_glazing_broken(site)}
		evidence["detached_delta"] = int(after.get("detached", 0)) - int(_before.get("detached", 0))
	if is_instance_valid(world):
		var blast: Variant = world.get("preview_c4_blast")
		if is_instance_valid(blast):
			var snapshot: Dictionary = blast.call("snapshot")
			var events: Array = snapshot.get("events", [])
			if not events.is_empty():
				var last: Dictionary = events[events.size() - 1]
				evidence["blast"] = {"event_id":str(last.get("event_id", "")),"released":(last.get("released", []) as Array).size(),"affected_houses":last.get("affected_houses", []),"physical_charge_consumed":last.get("physical_charge_consumed", false)}
			evidence["blast_events"] = events.size()
	var removed: bool = int(evidence.get("detached_delta", 0)) > 0 or int((evidence.get("after", {}) as Dictionary).get("glazing_broken", 0)) - int(_before.get("glazing_broken", 0)) > 0
	evidence["part_removed"] = removed
	_finish("detonated" if removed else "no_part_removed", evidence)

func _glazing_broken(site: Node3D) -> int:
	var glazing: Variant = site.get("_glazing")
	if not is_instance_valid(glazing) or not glazing.has_method("stats"): return 0
	var stats: Dictionary = glazing.call("stats")
	return int(stats.get("broken", 0))

func _finish(reason: String, detail: Dictionary) -> void:
	if _state == "finished": return
	_release()
	_state = "finished"
	set_physics_process(false)
	print(TAG, " ", JSON.stringify({"ok":reason == "detonated","reason":reason,"frames":_frames,"detail":detail}))
	if is_inside_tree(): queue_free()

func _press(down: bool) -> void:
	if down == _mouse_down: return
	_mouse_down = down
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = get_viewport().get_visible_rect().size * 0.5
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _release() -> void:
	if _mouse_down: _press(false)

func _exit_tree() -> void:
	set_physics_process(false)
