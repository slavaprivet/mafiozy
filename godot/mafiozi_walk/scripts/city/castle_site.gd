extends Node3D
## DSH_CASTLE: a large mediaeval castle as its own map, built from BRICKS that come down.
##
## Every course of every curtain wall, the battlements, the gate towers and the keep's
## crown are laid as individual bricks. Drawing thousands of separate bodies would cost
## more than the map is worth, so the bricks are DRAWN as one MultiMesh per material - a
## single draw call per wall - and a brick becomes a real falling body the moment a strike
## reaches it. Nothing about the look is faked: the bricks you see are the bricks that
## fall, the whole way through the wall.
##
## A hole opens upwards as well: bricks that lose the ones under them are dropped a moment
## later, so a hit low on a wall brings the courses above it down instead of leaving them
## hanging in the air.
##
## The map also has what an archer needs: two flights of stairs to the wall-walk, arrow
## slits in every wall and tower, four corner towers, a gatehouse with two hammered gates,
## and a keep in the courtyard.

const BRICK := Vector3(1.00, 0.54, 0.58)
const ArmoryStorage = preload("res://scripts/city/castle_armory_storage.gd")
var armory_storage: Node

func _build_furniture_meshes() -> void:
	# Unit sized profiles use the same chunked MultiMesh/damage path as brick cells.
	var turned := CylinderMesh.new()
	turned.top_radius = 0.34
	turned.bottom_radius = 0.43
	turned.height = 1.0
	turned.radial_segments = 8
	var cup := CylinderMesh.new()
	cup.top_radius = 0.45
	cup.bottom_radius = 0.24
	cup.height = 1.0
	cup.radial_segments = 10
	var disk := CylinderMesh.new()
	disk.top_radius = 0.5
	disk.bottom_radius = 0.5
	disk.height = 1.0
	disk.radial_segments = 12
	var soft := SphereMesh.new()
	soft.radius = 0.5
	soft.height = 1.0
	soft.radial_segments = 12
	soft.rings = 6
	_furniture_meshes = {"turned": turned, "cup": cup, "disk": disk, "soft": soft}
	var tower_floor := CylinderMesh.new()
	tower_floor.top_radius = 0.5
	tower_floor.bottom_radius = 0.5
	tower_floor.height = 1.0
	tower_floor.radial_segments = 20
	_furniture_meshes["tower_floor55"] = tower_floor
	var tower_roof := CylinderMesh.new()
	tower_roof.top_radius = 0.8 / ((TOWER_RADIUS + 0.4) * 2.0)
	tower_roof.bottom_radius = 0.5
	tower_roof.height = 1.0
	tower_roof.radial_segments = 20
	_furniture_meshes["tower_roof55"] = tower_roof
## DSH_OPT: a blast must not spawn a thousand solvers. Active debris is capped; a
## substantial piece is baked into a static, collidable rubble batch only after a real
## support query proves that it is resting on something. Static rubble has no solver.
const MAX_FALLING := 150
const BRICK_SETTLE_S := 1.4
const TINY_DEBRIS_LIFE_S := 8.0
const RUBBLE_MIN_VOLUME := 0.030
const RUBBLE_MIN_EXTENT := 0.20
const SUPPORT_CONTACT_PROBE := 0.075
const SUPPORT_PROOF_FRAMES := 3
const DEBRIS_BACKLOG_PER_FRAME := 8
const RUBBLE_BANK_CAPACITY := 128
const RUBBLE_SPATIAL_CELL := 8.0
const RUBBLE_SUPPORT_AUDITS_PER_FRAME := 16
var _debris_mesh: BoxMesh
var _debris_materials: Dictionary = {}
## DSH_OPT: dead stones come back here instead of being freed. A blast that reuses its stones
## allocates nothing, and allocation spikes are what a hitch is made of.
var _debris_pool: Array[RigidBody3D] = []
var _rubble_root: Node3D
var _rubble_bodies: Dictionary = {}
var _rubble_batches: Dictionary = {}
var _persistent_rubble := 0
var _rubble_entries: Dictionary = {}
var _rubble_entry_ids: Array[int] = []
var _rubble_next_id := 0
var _rubble_audit_cursor := 0
## A large blast can detach more cells than the bounded active-body budget. They wait as
## lightweight records and enter physics as earlier bodies settle; none are discarded.
var _debris_backlog: Array[Dictionary] = []
## DSH_OPT: the build is timed by phase when --castle-timing=1 is passed, so a slow map
## load is attacked where the seconds actually are.
var _phase_us := 0
var _phase_name := ""
var _phase_report: Array[String] = []
var _phase_enabled := false

func _phase(label: String) -> void:
	var now := Time.get_ticks_usec()
	if _phase_name != "":
		_phase_report.append("%s=%.1fms" % [_phase_name, float(now - _phase_us) / 1000.0])
	_phase_name = label
	_phase_us = now

func _phase_done() -> void:
	var now := Time.get_ticks_usec()
	if _phase_name != "":
		_phase_report.append("%s=%.1fms" % [_phase_name, float(now - _phase_us) / 1000.0])
	_phase_name = ""
	if _phase_enabled:
		print("DSH_PHASES ", " ".join(_phase_report))
	_phase_report.clear()
const DEBRIS_POOL_MAX := 220
var _reused_stones := 0

## Put a stone away: hidden, frozen, out of every collision, and kept for the next blast.
func _recycle_stone(body: RigidBody3D) -> void:
	if not is_instance_valid(body): return
	if _debris_pool.size() >= DEBRIS_POOL_MAX:
		body.queue_free()
		return
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	body.visible = false
	_debris_pool.append(body)

func _ensure_rubble_storage() -> void:
	if is_instance_valid(_rubble_root): return
	_rubble_root = Node3D.new()
	_rubble_root.name = "PersistentRubble33"
	add_child(_rubble_root)

func _is_substantial_rubble(cell: Dictionary) -> bool:
	var size: Vector3 = cell.get("size", BRICK)
	return size.x * size.y * size.z >= RUBBLE_MIN_VOLUME \
		and maxf(size.x, maxf(size.y, size.z)) >= RUBBLE_MIN_EXTENT

func _rubble_body_at(at: Vector3) -> StaticBody3D:
	var gx := int(floor(at.x / RUBBLE_SPATIAL_CELL))
	var gy := int(floor(at.y / RUBBLE_SPATIAL_CELL))
	var gz := int(floor(at.z / RUBBLE_SPATIAL_CELL))
	var key := "%d|%d|%d" % [gx, gy, gz]
	var existing: StaticBody3D = _rubble_bodies.get(key)
	if is_instance_valid(existing):
		return existing
	var body := StaticBody3D.new()
	body.name = "RubbleCollision33_%s" % key.replace("|", "_")
	body.position = Vector3(float(gx), float(gy), float(gz)) * RUBBLE_SPATIAL_CELL
	body.collision_layer = 1
	body.collision_mask = 1
	body.set_meta("castle_rubble", true)
	body.set_meta("rubble_spatial_key", key)
	body.set_meta("surface", "stone")
	_rubble_root.add_child(body)
	_rubble_bodies[key] = body
	return body

## MultiMesh instance storage is preallocated. Growing instance_count on every insertion
## can reallocate the backing buffer; visible_instance_count reveals one more slot without
## moving earlier instances. A full bank is followed by another fixed-capacity bank.
func _rubble_visual_bank(batch_key: String, mesh: Mesh, material: Material) -> Dictionary:
	var record: Dictionary = _rubble_batches.get(batch_key, {})
	if record.is_empty():
		record = {"banks": []}
		_rubble_batches[batch_key] = record
	for candidate: Dictionary in record["banks"]:
		if int(candidate["count"]) < RUBBLE_BANK_CAPACITY:
			return candidate
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = RUBBLE_BANK_CAPACITY
	multi.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.name = "Rubble_%s_%d" % [batch_key.replace("|", "_"),
		(record["banks"] as Array).size()]
	node.multimesh = multi
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_rubble_root.add_child(node)
	var data := PackedFloat32Array()
	data.resize(RUBBLE_BANK_CAPACITY * 12)
	var bank := {"node": node, "multi": multi, "count": 0, "slots": [], "pose_buffer": data}
	(record["banks"] as Array).append(bank)
	return bank

## A settled body is copied into static spatial collision and a fixed-capacity visual
## bank. Persistent rubble adds no rigid solver and has no arbitrary global piece cap.

## Keep the complete fixed bank on CPU. Partial instance writes can restore stale
## motion-vector cache regions after a quiet render frame (Godot 4.7.2/TAA).
## Updating only this 128-instance buffer preserves every surviving fragment pose.
func _write_rubble_bank_pose(bank: Dictionary, slot: int, pose: Transform3D) -> void:
	var data: PackedFloat32Array = bank["pose_buffer"]
	var at := slot * 12
	data[at] = pose.basis.x.x
	data[at + 1] = pose.basis.y.x
	data[at + 2] = pose.basis.z.x
	data[at + 3] = pose.origin.x
	data[at + 4] = pose.basis.x.y
	data[at + 5] = pose.basis.y.y
	data[at + 6] = pose.basis.z.y
	data[at + 7] = pose.origin.y
	data[at + 8] = pose.basis.x.z
	data[at + 9] = pose.basis.y.z
	data[at + 10] = pose.basis.z.z
	data[at + 11] = pose.origin.z
	bank["pose_buffer"] = data
	(bank["multi"] as MultiMesh).buffer = data

func _promote_rubble(body: RigidBody3D, cell: Dictionary) -> bool:
	if not is_instance_valid(body):
		return false
	var body_shape: CollisionShape3D = body.get_node_or_null("Shape") as CollisionShape3D
	var mesh_instance: MeshInstance3D = body.get_node_or_null("Mesh") as MeshInstance3D
	if body_shape == null or body_shape.shape == null or mesh_instance == null or mesh_instance.mesh == null:
		return false
	var support_hit := _support_contact_hit(body, body_shape)
	if support_hit.is_empty():
		return false
	_ensure_rubble_storage()
	var shape_copy: Shape3D = body_shape.shape.duplicate()
	var collision_body := _rubble_body_at(body.position)
	var collision := CollisionShape3D.new()
	collision.shape = shape_copy
	var collision_xf: Transform3D = body.transform * body_shape.transform
	collision_xf.origin -= collision_body.position
	collision.transform = collision_xf
	var piece_id := _rubble_next_id
	_rubble_next_id += 1
	collision.set_meta("rubble_piece", piece_id)
	collision_body.add_child(collision)
	var material_key: String = str(cell.get("material", "stone"))
	var shape_key: String = str(cell.get("shape", "box"))
	var material_id: int = mesh_instance.material_override.get_instance_id() \
		if mesh_instance.material_override != null else 0
	var spatial_key := str(collision_body.get_meta("rubble_spatial_key", ""))
	var batch_key := "%s|%s|%d|%s" % [shape_key, material_key, material_id, spatial_key]
	var batch := _rubble_visual_bank(batch_key, mesh_instance.mesh,
		mesh_instance.material_override)
	var visual := batch.get("multi") as MultiMesh
	var slot := int(batch.get("count", 0))
	_write_rubble_bank_pose(batch, slot, body.transform * mesh_instance.transform)
	visual.visible_instance_count = slot + 1
	batch["count"] = slot + 1
	(batch["slots"] as Array).append(piece_id)
	var support_body := support_hit.get("collider") as StaticBody3D
	var support_shape: CollisionShape3D = null
	var hit_shape := int(support_hit.get("shape", -1))
	if is_instance_valid(support_body) and hit_shape >= 0:
		var owner_id := support_body.shape_find_owner(hit_shape)
		var owner: Object = support_body.shape_owner_get_owner(owner_id)
		if owner is CollisionShape3D:
			support_shape = owner as CollisionShape3D
	_rubble_entries[piece_id] = {"id": piece_id, "collision": collision,
		"bank": batch, "slot": slot, "support_body": support_body,
		"support_shape": support_shape, "support_world_xf": support_shape.global_transform \
			if is_instance_valid(support_shape) else support_body.global_transform,
		"body_xf": body.transform,
		"shape_xf": body_shape.transform, "shape": shape_copy,
		"mesh_xf": mesh_instance.transform, "mesh": mesh_instance.mesh,
		"material": mesh_instance.material_override, "cell": cell.duplicate()}
	_rubble_entry_ids.append(piece_id)
	_persistent_rubble += 1
	return true

## Inspect a fixed number of recorded supports each physics frame. A destroyed floor or
## a released lower rubble shape invalidates its dependents without scanning the whole
## rubble field in one frame.
func _audit_persistent_rubble() -> void:
	var remaining := mini(RUBBLE_SUPPORT_AUDITS_PER_FRAME, _rubble_entry_ids.size())
	while remaining > 0 and not _rubble_entry_ids.is_empty():
		if _rubble_audit_cursor >= _rubble_entry_ids.size():
			_rubble_audit_cursor = 0
		var piece_id := _rubble_entry_ids[_rubble_audit_cursor]
		_rubble_audit_cursor += 1
		remaining -= 1
		var entry: Dictionary = _rubble_entries.get(piece_id, {})
		if entry.is_empty():
			continue
		var support_body: Variant = entry.get("support_body")
		var support_shape: Variant = entry.get("support_shape")
		var valid_support: bool = is_instance_valid(support_body) \
			and not support_body.is_queued_for_deletion() \
			and (support_body.collision_layer & 1) != 0
		if typeof(support_shape) == TYPE_OBJECT:
			valid_support = valid_support and is_instance_valid(support_shape) \
				and not support_shape.is_queued_for_deletion() and not support_shape.disabled
		if valid_support:
			var support_node: Node3D = support_shape if is_instance_valid(support_shape) else support_body
			var previous: Transform3D = entry["support_world_xf"]
			var current: Transform3D = support_node.global_transform
			# Ignore sub-5mm translation and sub-0.001 basis noise; compare to promotion,
			# so gradual motion still releases rubble. Existing audit budget bounds cost.
			valid_support = previous.origin.distance_squared_to(current.origin) <= 0.000025 \
				and previous.basis.x.distance_squared_to(current.basis.x) <= 0.000001 \
				and previous.basis.y.distance_squared_to(current.basis.y) <= 0.000001 \
				and previous.basis.z.distance_squared_to(current.basis.z) <= 0.000001
		if not valid_support:
			_release_persistent_rubble(piece_id, entry)

func _release_persistent_rubble(piece_id: int, entry: Dictionary) -> void:
	var bank: Dictionary = entry.get("bank", {})
	var multi: MultiMesh = bank.get("multi")
	var slots: Array = bank.get("slots", [])
	var slot := int(entry.get("slot", -1))
	var last := slots.size() - 1
	if multi == null or slot < 0 or slot > last:
		return
	if slot != last:
		var moved_id := int(slots[last])
		var moved: Dictionary = _rubble_entries[moved_id]
		# Use the fragment's retained pose: renderer readback during repeated bank
		# compaction can return a cleared slot and make a surviving piece invisible.
		var moved_xf: Transform3D = moved["body_xf"] * moved["mesh_xf"]
		_write_rubble_bank_pose(bank, slot, moved_xf)
		slots[slot] = moved_id
		moved["slot"] = slot
	slots.pop_back()
	bank["count"] = last
	multi.visible_instance_count = last
	var collision: CollisionShape3D = entry.get("collision")
	if is_instance_valid(collision):
		collision.set_deferred("disabled", true)
		collision.queue_free()
	_rubble_entries.erase(piece_id)
	var position := _rubble_entry_ids.find(piece_id)
	if position >= 0:
		_rubble_entry_ids.remove_at(position)
		if position < _rubble_audit_cursor:
			_rubble_audit_cursor -= 1
	_persistent_rubble -= 1
	_debris_backlog.push_front({"restore": entry,
		"due_frame": Engine.get_physics_frames() + 2})

func _restore_persistent_rubble(entry: Dictionary) -> void:
	var body := RigidBody3D.new()
	body.name = "RestoredCastleRubble33"
	body.collision_layer = 1
	body.collision_mask = 1
	body.contact_monitor = true
	body.max_contacts_reported = 4
	var cell: Dictionary = entry.get("cell", {})
	var size: Vector3 = cell.get("size", BRICK)
	var density := 3.5 if str(cell.get("material", "stone")).begins_with("wood") else 18.0
	body.mass = clampf(size.x * size.y * size.z * density, 0.3, 80.0)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = (entry.get("shape") as Shape3D).duplicate()
	shape.transform = entry.get("shape_xf", Transform3D.IDENTITY)
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.mesh = entry.get("mesh")
	visual.material_override = entry.get("material")
	visual.transform = entry.get("mesh_xf", Transform3D.IDENTITY)
	body.add_child(visual)
	body.transform = entry.get("body_xf", Transform3D.IDENTITY)
	add_child(body)
	body.linear_velocity = Vector3.DOWN * 0.2
	_falling.append({"body": body, "age": 0.0, "cell": cell.duplicate(),
		"substantial": true, "support_frames": 0})

func get_rubble_snapshot() -> Dictionary:
	var collision_shapes := 0
	for body: StaticBody3D in _rubble_bodies.values():
		if not is_instance_valid(body):
			continue
		for child: Node in body.get_children():
			if child is CollisionShape3D and (child as CollisionShape3D).shape != null:
				collision_shapes += 1
	var bank_count := 0
	var capacity := 0
	for record: Dictionary in _rubble_batches.values():
		for bank: Dictionary in record.get("banks", []):
			bank_count += 1
			capacity += int((bank.get("multi") as MultiMesh).instance_count)
	return {
		"persistent": _persistent_rubble,
		"collision_shapes": collision_shapes,
		"visual_batches": _rubble_batches.size(),
		"visual_banks": bank_count,
		"visual_capacity": capacity,
		"static_rubble_bodies": _rubble_bodies.size(),
		"active_falling": _falling.size(),
		"debris_backlog": _debris_backlog.size(),
	}

const WALL_HEIGHT := 19.0
const WALL_HALF := 68.0          # half of the outside square: a siege map, not a yard
const WALL_THICK := 1.1
const ARROW_PORT_WIDTH := 0.32
const ARROW_PORT_HEIGHT := 1.55
const ARROW_PORT_Y := 14.4
const ARROW_PORT_ALONG := [-20.0, 0.0, 20.0]
const TOWER_RADIUS := 5.6
const TOWER_HEIGHT := 27.0
const GATE_WIDTH := 9.2
const GATE_HEIGHT := 12.0
const DETACH_IMPULSE := 30.0
const SUPPORT_DELAY_MS := 240
const KEEP_SIZE := Vector3(26.0, 38.0, 26.0)

var _ready := false
var _materials: Dictionary = {}
var _brick_mesh: BoxMesh
var _furniture_meshes: Dictionary = {}
var _cells: Array[Dictionary] = []
## Small lookup for direct furniture hits; a sword never scans all 60k wall stones.
var _furniture_cells: Dictionary = {}
## One MultiMesh per material, holding every brick that is still in place.
var _buckets: Dictionary = {}     # material_id -> {instance: MultiMeshInstance3D, indices: Array}
## DSH_OPT: a blast is local. This grid of cell indices means it tests the stones the
## explosion touches instead of walking all sixty thousand of them three times.
const SPATIAL_STEP := 8.0
var _spatial: Dictionary = {}
var _falling: Array[Dictionary] = []
var _gate_leaves: Array[Dictionary] = []
var _detached := 0
## DSH_NET: сколько взрывов реально применено к кладке. Проверка «нет двойного
## урона» сравнивает этот счётчик у обеих сторон.
var _explosions := 0
var _collapsed := 0
var _events: Array[Dictionary] = []
## Indexed by cell. The dictionary gives both O(1) de-duplication and a bounded scan per
## physics frame while a tall unsupported column is still settling.
var _pending_support: Dictionary = {}
var _support_ceiling55 := 0.0
var _stair_families: Dictionary = {}
var _wall_collision: Array[Dictionary] = []
## Exact visual step -> ramp segment binding. A blasted step cannot leave an
## invisible piece of climbable deck behind, including support-cascade failures.
var _stair_step_collision: Dictionary = {}
var _merlon_collision: Dictionary = {}
var _courtyard_shapes43: Dictionary = {}
var _courtyard_bodies43: Dictionary = {}
var _courtyard_dependents43: Dictionary = {}
# Exact surviving masonry replaces coarse collision only around actual damage.
var _masonry_shapes55: Dictionary = {}
var _masonry_bodies55: Dictionary = {}
var _masonry_changed55: Dictionary = {}
var _ground: StaticBody3D
var _player: CharacterBody3D
var _world_ref: Node3D

## Mechanical support is deliberately conservative. A cell survives a 56% loss only when
## the remaining support straddles opposite sides, which is the useful approximation for a
## lintel or arch. A single surviving edge is not enough for an ordinary brick course.
const SUPPORT_VERTICAL_GAP := 0.08
const SUPPORT_SEARCH_BELOW := 0.42
const SUPPORT_COVERAGE_MIN := 0.56
const SUPPORT_BALANCED_MIN := 0.18
const SUPPORT_AUDIT_XZ_MARGIN := 2.2
const SUPPORT_CHECKS_PER_FRAME := 48
const SUPPORT_TIME_BUDGET_US := 1800

## ------------------------------------------------------------------ build
func install(world: Node3D, origin: Vector3) -> Dictionary:
	if _ready: return {"ok": false, "reason": "already"}
	if not is_instance_valid(world): return {"ok": false, "reason": "no_world"}
	# DSH_OPT: --castle-timing=1 prints what each phase of the build costs.
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--castle-timing="):
			_phase_enabled = int(argument.trim_prefix("--castle-timing=")) != 0
	_world_ref = world
	_player = world.get("_player") as CharacterBody3D
	# DSH_OPT: the project runs 4x MSAA and TAA at the same time. TAA already resolves
	# the brick edges - two settings measured 0.6/255 mean difference on stills - so on
	# the castle map the samples are spent on pixels instead. The city map keeps its own.
	if get_viewport() != null:
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	if _phase_enabled: _phase("_build_materials")
	_build_materials()
	_brick_mesh = BoxMesh.new()
	_brick_mesh.size = BRICK
	_build_furniture_meshes()
	if _phase_enabled: _phase("_build_environment")
	_build_environment()
	if _phase_enabled: _phase("_build_ground")
	_build_ground()
	if _phase_enabled: _phase("_build_path")
	_build_path()
	if _phase_enabled: _phase("_build_curtain_walls")
	_build_curtain_walls()
	if _phase_enabled: _phase("_build_corner_towers")
	_build_corner_towers()
	if _phase_enabled: _phase("_build_gatehouse")
	_build_gatehouse()
	if _phase_enabled: _phase("_build_exterior_crowns")
	_build_exterior_crowns()
	if _phase_enabled: _phase("_build_stairs")
	_build_stairs()
	if _phase_enabled: _phase("_build_wall_walks")
	_build_wall_walks()
	if _phase_enabled: _phase("_build_corner_bypasses")
	_build_corner_bypasses()
	if _phase_enabled: _phase("_build_gatehouse_bypass")
	_build_gatehouse_bypass()
	if _phase_enabled: _phase("_build_keep")
	_build_keep()
	if _phase_enabled: _phase("_build_keep_rooms")
	_build_keep_rooms()
	if _phase_enabled: _phase("_build_keep_interior")
	_build_keep_interior()
	if _phase_enabled: _phase("_build_keep_details")
	_build_keep_details()
	if _phase_enabled: _phase("_build_gate_arch")
	_build_gate_arch()
	if _phase_enabled: _phase("_build_banners")
	_build_banners()
	if _phase_enabled: _phase("_build_ring_road")
	_build_ring_road()
	if _phase_enabled: _phase("_build_tower_platforms")
	_build_tower_platforms()
	if _phase_enabled: _phase("_build_gate_bridge")
	_build_gate_bridge()
	# The far slabs are retired: the bricks are drawn at every distance anyway, so the
	# slab only covered the gate opening and any breach seen from afar with intact stone.
	if _phase_enabled: _phase("_build_string_courses")
	_build_string_courses()
	if _phase_enabled: _phase("_build_facade_relief")
	_build_facade_relief()
	if _phase_enabled: _phase("_build_entrance_layer31")
	_build_entrance_layer31()
	if _phase_enabled: _phase("_build_gate_art38")
	_build_gate_art38()
	if _phase_enabled: _phase("_build_wall_banners")
	_build_wall_banners()
	if _phase_enabled: _phase("_build_brick_floor")
	_build_brick_floor()
	_build_courtyard43()
	if _phase_enabled: _phase("_add_rubble")
	_add_rubble()
	if _phase_enabled: _phase("_build_torches")
	_build_torches()
	# The non-colliding decorative grid across the inner gateway was removed.
	if _phase_enabled: _phase("_build_gate_lamps")
	_build_gate_lamps()
	if _phase_enabled: _phase("_build_gate_deck")
	_build_gate_deck()
	if _phase_enabled: _phase("_cull_small_shadows")
	_cull_small_shadows()
	# Same triangles, same materials, same shadows - just not one draw call per bracket.
	if _phase_enabled: _phase("_batch_static_decoration")
	_batch_static_decoration()
	if _phase_enabled: _phase("_flush_buckets")
	_flush_buckets()
	_build_masonry_hits55()
	if _phase_enabled: _phase("_prewarm_debris_pool")
	_prewarm_debris_pool()
	if _phase_enabled: _phase_done()
	_ready = true
	if is_instance_valid(world.get("preview_weapons")):
		armory_storage = ArmoryStorage.new()
		armory_storage.name = "ArmoryStorage"
		add_child(armory_storage)
		var armoury_origin := Vector3(8.0, 0.0, -14.2)
		var points: Array[Vector3] = []
		for dz: float in [-3.85, -2.95, -0.45, 0.45, 2.95, 3.85]:
			points.append(armoury_origin + Vector3(1.1, 0.0, dz))
		points.append(armoury_origin + Vector3(1.1, 0.0, 5.2))
		armory_storage.configure(self, world.get("preview_weapons"), points,
			armoury_origin + Vector3(-2.6, 0.0, -2.0))
	return {"ok": true, "origin": origin, "bricks": _cells.size(),
		"gates": _gate_leaves.size(), "stats": get_stats()}

func _build_materials() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.66, 0.63, 0.57)
	stone.roughness = 0.94
	var stone_warm := StandardMaterial3D.new()
	stone_warm.albedo_color = Color(0.58, 0.54, 0.47)
	stone_warm.roughness = 0.96
	var stone_cold := StandardMaterial3D.new()
	stone_cold.albedo_color = Color(0.52, 0.52, 0.51)
	stone_cold.roughness = 0.93
	# The gate leaves sat in the shadow of the arch and read as a black hole. Oak, not tar.
	var wood := StandardMaterial3D.new()
	# Oak. It read as pale plaster under a strong sun, so it is darker and rougher.
	wood.albedo_color = Color(0.38, 0.24, 0.13)
	wood.roughness = 0.96
	var wood_alt := StandardMaterial3D.new()
	wood_alt.albedo_color = Color(0.33, 0.205, 0.11)
	wood_alt.roughness = 0.97
	var floor_wood := ShaderMaterial.new()
	var floor_grain := Shader.new()
	floor_grain.code = """
shader_type spatial;
render_mode diffuse_burley;
void fragment() {
	float bend = sin(UV.y * 8.0) * 1.4 + sin(UV.y * 19.0) * 0.35;
	float open_grain = sin(UV.x * 83.0 + bend) * 0.035;
	float fine_grain = sin(UV.x * 217.0 + UV.y * 5.0) * 0.012;
	float worn_edge = smoothstep(0.0, 0.10, UV.x) * (1.0 - smoothstep(0.90, 1.0, UV.x));
	ALBEDO = vec3(0.47, 0.30, 0.175) * (0.91 + 0.09 * worn_edge + open_grain + fine_grain) * COLOR.rgb;
	ROUGHNESS = 0.93;
}
"""
	floor_wood.shader = floor_grain
	var linen := StandardMaterial3D.new()
	linen.albedo_color = Color(0.57, 0.52, 0.43)
	linen.roughness = 1.0
	var ochre := StandardMaterial3D.new()
	ochre.albedo_color = Color(0.70, 0.49, 0.19)
	ochre.roughness = 0.82
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.26, 0.27, 0.30)
	iron.metallic = 0.8
	iron.roughness = 0.42
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.33, 0.41, 0.24)
	grass.roughness = 0.98
	var paving := StandardMaterial3D.new()
	paving.albedo_color = Color(0.39, 0.36, 0.31)
	paving.roughness = 0.98
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.03, 0.04)
	dark.roughness = 1.0
	var velvet := StandardMaterial3D.new()
	velvet.albedo_color = Color(0.42, 0.055, 0.075)
	velvet.roughness = 0.9
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.8, 0.59, 0.19)
	gold.metallic = 0.55
	gold.roughness = 0.4
	_materials = {"stone": stone, "warm": stone_warm, "cold": stone_cold,
		"wood": wood, "wood_alt": wood_alt, "floor_wood": floor_wood,
		"linen": linen, "ochre": ochre,
		"iron": iron, "grass": grass, "paving": paving, "dark": dark,
		"velvet": velvet, "gold": gold}

func _build_ground() -> void:
	_ground = StaticBody3D.new()
	_ground.name = "CastleGround"
	_ground.collision_layer = 1
	_ground.collision_mask = 1
	add_child(_ground)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600.0, 2.0, 600.0)
	shape.shape = box
	shape.position.y = -1.0
	_ground.add_child(shape)
	var slab := MeshInstance3D.new()
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(600.0, 2.0, 600.0)
	slab.mesh = slab_mesh
	slab.material_override = _materials["grass"]
	slab.position.y = -1.03
	_ground.add_child(slab)

## ------------------------------------------------------------------ light and setting
## A castle needs its own sky and sun: the city's dusk lighting flattened every face of
## the stone into one grey tone, which is most of why it did not read as stone.
func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	environment.name = "CastleSky"
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.32, 0.47, 0.72)
	sky_material.sky_horizon_color = Color(0.78, 0.80, 0.80)
	sky_material.ground_bottom_color = Color(0.25, 0.26, 0.24)
	sky_material.ground_horizon_color = Color(0.62, 0.63, 0.60)
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.14
	var sky := Sky.new()
	sky.sky_material = sky_material
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	settings.ambient_light_sky_contribution = 0.7
	settings.ambient_light_energy = 0.95
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_exposure = 0.82
	settings.ssao_enabled = true
	settings.ssao_radius = 2.4
	settings.ssao_intensity = 1.4
	settings.glow_enabled = true
	settings.glow_intensity = 0.35
	settings.fog_enabled = true
	settings.fog_light_color = Color(0.72, 0.75, 0.80)
	settings.fog_density = 0.0016
	settings.fog_aerial_perspective = 0.3
	environment.environment = settings
	add_child(environment)
	# The city already has a WorldEnvironment, and its dusk sky kept winning. The castle
	# is its own map, so it takes the sky over: every other environment is retired.
	for other: Node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		if other != environment:
			(other as WorldEnvironment).environment = null
	if get_viewport() != null and get_viewport().world_3d != null:
		get_viewport().world_3d.environment = settings
	var sun := DirectionalLight3D.new()
	sun.name = "CastleSun"
	sun.light_energy = 0.85
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_blur = 1.6
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 95.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.rotation_degrees = Vector3(-38.0, 128.0, 0.0)
	add_child(sun)

## A road in from the gate, and cobbles across the courtyard.
func _build_path() -> void:
	var road := StandardMaterial3D.new()
	road.albedo_color = Color(0.34, 0.29, 0.22)
	road.roughness = 1.0
	var cobble := StandardMaterial3D.new()
	cobble.albedo_color = Color(0.45, 0.43, 0.39)
	cobble.roughness = 0.95
	var road_mesh := MeshInstance3D.new()
	var road_box := BoxMesh.new()
	road_box.size = Vector3(11.0, 0.12, 42.0)
	road_mesh.mesh = road_box
	road_mesh.material_override = road
	road_mesh.position = Vector3(0.0, -0.04, WALL_HALF + 21.0)
	add_child(road_mesh)
	var courtyard := MeshInstance3D.new()
	var courtyard_box := BoxMesh.new()
	# Reach the inner edge of the outer ring road on every side. The previous
	# 68.8 m edge left a green strip between the wall and the road at 70 m.
	var paved_span := WALL_HALF * 2.0 + 2.0 * RING_GAP + 0.5
	courtyard_box.size = Vector3(paved_span, 0.12, paved_span)
	courtyard.mesh = courtyard_box
	courtyard.material_override = cobble
	courtyard.position = Vector3(0.0, -0.04, 0.0)
	add_child(courtyard)
	# The paving is a SURFACE of its own, a whisker above the earth: without this a footstep
	# inside the walls would take the ground slab underneath and sound like a field.
	var paving_body := StaticBody3D.new()
	paving_body.name = "CourtyardPaving"
	paving_body.collision_layer = 1
	paving_body.collision_mask = 1
	paving_body.set_meta("surface", "stone")
	paving_body.position = Vector3(0.0, -0.02, 0.0)
	add_child(paving_body)
	var paving_area := CollisionShape3D.new()
	var paving_shape := BoxShape3D.new()
	paving_shape.size = Vector3(paved_span, 0.10, paved_span)
	paving_area.shape = paving_shape
	paving_body.add_child(paving_area)

## Torches on either side of the gate and along the wall-walk: light is what makes stone
## read as stone at night, and they give the gate a warm mouth instead of a black hole.
func _build_torches() -> void:
	var positions: Array[Vector3] = [
		Vector3(-GATE_WIDTH * 0.5 - 1.2, 5.2, WALL_HALF + 0.9),
		Vector3(GATE_WIDTH * 0.5 + 1.2, 5.2, WALL_HALF + 0.9),
		Vector3(-GATE_WIDTH * 0.5 - 1.2, 5.2, WALL_HALF - 0.9),
		Vector3(GATE_WIDTH * 0.5 + 1.2, 5.2, WALL_HALF - 0.9),
		Vector3(-WALL_HALF * 0.5, WALL_HEIGHT + 1.2, WALL_HALF - 0.8),
		Vector3(WALL_HALF * 0.5, WALL_HEIGHT + 1.2, WALL_HALF - 0.8),
	]
	# GPU vertex sway animates every flame without a per-frame script or light flicker.
	# One shared material keeps all sconces in the same static batch. The
	# cylinder's UV.y runs from zero at the tip to one at the bowl after batching.
	var flame_shader := Shader.new()
	flame_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
void vertex() {
	float height = clamp(1.0 - UV.y, 0.0, 1.0);
	float phase = TIME * 5.4 + VERTEX.x * 0.61 + VERTEX.z * 0.37;
	VERTEX.x += sin(phase + height * 3.8) * 0.095 * height;
	VERTEX.z += cos(phase * 0.78 + height * 4.1) * 0.055 * height;
}
void fragment() {
	vec3 ember = vec3(1.0, 0.27, 0.055);
	vec3 tip = vec3(1.0, 0.85, 0.34);
	ALBEDO = mix(ember, tip, clamp(1.0 - UV.y, 0.0, 1.0));
	EMISSION = ALBEDO * 3.2;
}
"""
	var flame := ShaderMaterial.new()
	flame.shader = flame_shader
	for at: Vector3 in positions:
		var outward: float = 1.0 if at.z > WALL_HALF else -1.0
		var plate := MeshInstance3D.new()
		plate.name = "GateSconceBackplate"
		var plate_mesh := BoxMesh.new()
		plate_mesh.size = Vector3(0.42, 0.64, 0.10)
		plate.mesh = plate_mesh
		plate.material_override = _materials["iron"]
		plate.position = at - Vector3(0.0, 0.06, outward * 0.22)
		add_child(plate)
		var bracket := MeshInstance3D.new()
		var bracket_mesh := BoxMesh.new()
		bracket_mesh.size = Vector3(0.16, 0.16, 0.76)
		bracket.mesh = bracket_mesh
		bracket.material_override = _materials["iron"]
		bracket.position = at + Vector3(0.0, -0.10, outward * 0.18)
		add_child(bracket)
		var cup_at := at + Vector3(0.0, 0.10, outward * 0.52)
		var bowl := MeshInstance3D.new()
		bowl.name = "GateSconceBowl"
		var bowl_mesh := CylinderMesh.new()
		bowl_mesh.top_radius = 0.31
		bowl_mesh.bottom_radius = 0.14
		bowl_mesh.height = 0.30
		bowl_mesh.radial_segments = 8
		bowl.mesh = bowl_mesh
		bowl.material_override = _materials["iron"]
		bowl.position = cup_at
		add_child(bowl)
		var torch := MeshInstance3D.new()
		torch.name = "GateSconceFlame"
		var torch_mesh := CylinderMesh.new()
		torch_mesh.top_radius = 0.0
		torch_mesh.bottom_radius = 0.23
		torch_mesh.height = 0.62
		torch_mesh.radial_segments = 7
		torch.mesh = torch_mesh
		torch.material_override = flame
		torch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		torch.position = cup_at + Vector3.UP * 0.40
		add_child(torch)
		# HALF THE LIGHTS, ALL OF THE GLOW. Four torches flank the gate but only one light per
		# side is needed - they are two metres apart - and the two high on the wall throw no
		# light at all: nothing a player can see is up there but the emissive flame itself.
		# Ten lights became four, and every lit surface in range stopped paying for them.
		if at.y < WALL_HEIGHT and at.x < 0.0:
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.66, 0.34)
			light.light_energy = 2.6
			light.omni_range = 9.5
			light.position = at + Vector3(0.0, 0.3, 0.0)
			add_child(light)

## The portcullis, raised behind the arch: the bars are what a gate is actually held by.
func _build_gate_lamps() -> void:
	for side: float in [-1.0, 1.0]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.76, 0.48)
		# Three metres out and faint: at half a metre the inverse-square turned the oak
		# into a white panel.
		lamp.light_energy = 0.45
		lamp.omni_range = 6.0
		lamp.position = Vector3(side * GATE_WIDTH * 0.60, GATE_HEIGHT * 0.55, WALL_HALF + 3.0)
		add_child(lamp)

## A plank deck through the gate passage: a timber floor under the arch, which is what a
## gate is actually floored with - and the one place on the map where a boot lands on wood.
func _build_gate_deck() -> void:
	var deck_material := StandardMaterial3D.new()
	deck_material.albedo_color = Color(0.42, 0.30, 0.18)
	deck_material.roughness = 0.94
	var body := StaticBody3D.new()
	body.name = "GateDeck"
	body.collision_layer = 1
	body.collision_mask = 1
	body.set_meta("surface", "wood")
	body.position = Vector3(0.0, -0.02, WALL_HALF)
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GATE_WIDTH + 2.0, 0.10, 6.0)
	shape.shape = box
	body.add_child(shape)
	var deck := MeshInstance3D.new()
	var deck_box := BoxMesh.new()
	deck_box.size = box.size
	deck.mesh = deck_box
	deck.material_override = deck_material
	deck.position = body.position
	add_child(deck)
	# The gate deck and courtyard floor already meet here. A separate raised
	# threshold made a visible lip while adding an unnecessary collision island.
	_add_gate_threshold(Vector3(0.0, 0.02, WALL_HALF + 13.0),
		Vector3(GATE_WIDTH + 14.0, 0.12, 20.0), "GateOuterApron")
	_build_gate_forecourt_pavers()
	# The boards, drawn as seams across the deck.
	var seam := StandardMaterial3D.new()
	seam.albedo_color = Color(0.24, 0.16, 0.09)
	seam.roughness = 0.96
	for i: int in 9:
		var strip := MeshInstance3D.new()
		var strip_box := BoxMesh.new()
		strip_box.size = Vector3(GATE_WIDTH + 2.0, 0.02, 0.06)
		strip.mesh = strip_box
		strip.material_override = seam
		strip.position = Vector3(0.0, 0.03, WALL_HALF - 2.6 + float(i) * 0.68)
		add_child(strip)

func _add_gate_threshold(at: Vector3, size: Vector3, label: String) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 1
	body.set_meta("surface", "stone")
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	# Share the forecourt's existing paving material with its exposed apron rim.
	visual.material_override = _materials["paving"]
	body.add_child(visual)

## One batched paving draw call gives the wide stone approach a visible bond.
## The slab beneath, rather than hundreds of separate tiles, owns collision.
func _build_gate_forecourt_pavers() -> void:
	var tile := BoxMesh.new()
	tile.size = Vector3(1.78, 0.035, 0.86)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = tile
	multi.instance_count = 12 * 22
	var slot := 0
	for row: int in 22:
		for column: int in 12:
			var x := (float(column) - 5.5) * 1.86 + (0.45 if row % 2 == 1 else 0.0)
			var z := WALL_HALF + 3.0 + (float(row) + 0.5) * 0.88
			multi.set_instance_transform(slot, Transform3D(Basis.IDENTITY,
				Vector3(x, 0.093, z)))
			var tone := 0.88 + float((row * 17 + column * 29) % 11) * 0.013
			# Blend the outer two courses into the darker approach using existing
			# MultiMesh instance colors, with no new geometry or collision.
			var edge := mini(mini(row, 21 - row), mini(column, 11 - column))
			tone *= 0.82 if edge == 0 else 0.92 if edge == 1 else 1.0
			multi.set_instance_color(slot, Color(tone, tone * 0.98, tone * 0.94))
			slot += 1
	var stones := MultiMeshInstance3D.new()
	stones.name = "GateForecourtPavers"
	stones.multimesh = multi
	stones.material_override = _materials["paving"]
	stones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stones)

## Dress the keep: quoins down its corners, windows with arched heads, and a buttress at
## each face, so it stops being a flat dark box.
func _build_keep_details() -> void:
	var base := Vector3(0.0, 0.0, -8.0)
	var half_x := KEEP_SIZE.x * 0.5
	var half_z := KEEP_SIZE.z * 0.5
	# Quoins: alternate long and short stones down every corner.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var courses := int(KEEP_SIZE.y / BRICK.y)
		for row: int in courses:
			var longer: bool = row % 2 == 0
			var size := Vector3(0.86 if longer else 0.56, BRICK.y, 0.86 if longer else 0.56)
			var at := base + Vector3(corner.x * (half_x - size.x * 0.5 + 0.06),
				(float(row) + 0.5) * BRICK.y, corner.y * (half_z - size.z * 0.5 + 0.06))
			_add_brick(at, size, "cold", Vector3.ZERO, "keep_quoin", row, 0)
	# Windows: a dark recess with a lit sill, two per face, three storeys.
	for storey: int in 3:
		for side: float in [-1.0, 1.0]:
			for i: int in 2:
				# Two faces run along X, two along Z: windows on all four, or the tower
				# is blind on the sides the player actually walks past.
				var at_x := base + Vector3(side * (half_x + WALL_THICK * 0.68),
					6.0 + float(storey) * 9.0, -4.6 + float(i) * 9.2)
				_add_brick(at_x, Vector3(0.14, 2.4, 1.2), "dark", Vector3.ZERO, "keep_window", storey, i)
				_add_brick(at_x + Vector3(side * 0.12, -1.3, 0.0),
					Vector3(0.5, 0.18, 1.5), "stone", Vector3.ZERO, "keep_sill55")
				var at_z := base + Vector3(-4.6 + float(i) * 9.2,
					6.0 + float(storey) * 9.0, side * (half_z + WALL_THICK * 0.68))
				_add_brick(at_z, Vector3(1.2, 2.4, 0.14), "dark", Vector3.ZERO, "keep_window_z", storey, i)
				_add_brick(at_z + Vector3(0.0, -1.3, side * 0.12),
					Vector3(1.5, 0.18, 0.5), "stone", Vector3.ZERO, "keep_sill55")
	# Buttresses at the corners of each face.
	for side: float in [-1.0, 1.0]:
		for other: float in [-1.0, 1.0]:
			var at := base + Vector3(side * (half_x + 0.45), KEEP_SIZE.y * 0.5, other * 5.4)
			for row: int in int((KEEP_SIZE.y - 3.0) / BRICK.y):
				_add_brick(Vector3(at.x, 1.5 + (float(row) + 0.5) * BRICK.y, at.z),
					Vector3(0.9, BRICK.y, 1.5), "warm", Vector3.ZERO, "keep_buttress", row, 0)
	# Stone bands mark the four levels; short modules can fall where struck.
	for level: int in 4:
		var height := 5.0 + float(level) * 9.0
		for i: int in 13:
			var along := -12.0 + float(i) * 2.0
			for side: float in [-1.0, 1.0]:
				_add_brick(base + Vector3(along, height, side * (half_z + 0.66)),
					Vector3(1.98, 0.26, 0.26), "cold", Vector3.ZERO, "keep_band", level, i)
				_add_brick(base + Vector3(side * (half_x + 0.66), height, along),
					Vector3(0.26, 0.26, 1.98), "cold", Vector3.ZERO, "keep_band", level, i)
	# The roof has an actual battlement silhouette instead of a flat square lid.
	for i: int in 13:
		if i % 2 == 1: continue
		var along := -12.0 + float(i) * 2.0
		for side: float in [-1.0, 1.0]:
			_add_brick(base + Vector3(along, KEEP_SIZE.y + 0.85, side * half_z),
				Vector3(1.75, 1.7, 0.95), "stone", Vector3.ZERO, "keep_merlon", 0, i)
			_add_brick(base + Vector3(side * half_x, KEEP_SIZE.y + 0.85, along),
				Vector3(0.95, 1.7, 1.75), "stone", Vector3.ZERO, "keep_merlon", 0, i)
## ------------------------------------------------------------------ bricks
## One brick at a place, drawn through its material's MultiMesh until it is knocked out.
func _add_brick(at: Vector3, size: Vector3, material_key: String, rotation: Vector3,
		group: String, row: int = 0, column: int = 0, shape_key: String = "box") -> int:
	var index := _cells.size()
	_cells.append({
		"at": at, "size": size, "material": material_key, "rotation": rotation,
		"group": group, "row": row, "column": column, "shape": shape_key,
		"alive": true, "instance": -1,
	})
	if "merlon" in group:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 1
		body.position = at
		body.rotation = rotation
		body.set_meta("surface", "stone")
		add_child(body)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		_merlon_collision[index] = shape
	return index

## DSH_OPT: bricks are drawn in CHUNKS, not as one MultiMesh for the whole castle.
##
## A single MultiMesh is never frustum-culled - the engine has no way to know that most of
## a hundred-and-thirty-metre wall is behind you - so one big mesh would draw thirty
## thousand bricks every frame. Split into chunks of a few metres, each chunk is culled on
## its own and the cost follows what is on screen. Bricks that are knocked out are moved
## out of the chunk's mesh, and the falling body is spawned as before.
const CHUNK_X := 26.0
const CHUNK_Y := 10.0
const CHUNK_Z := 26.0

## DSH_OPT: a bracket, a stud, a rope or a lantern glass does not need to cast a shadow, and
## every caster is a draw in the shadow pass - the whole castle was 390 of them. Only shapes
## bigger than a metre and a half keep their shadow, so the walls, towers, gate and banners
## still throw exactly the shadow they did before.
func _cull_small_shadows() -> void:
	var kept := 0
	var dropped := 0
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null: continue
		if mesh_instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: continue
		var size := 0.0
		if mesh_instance.mesh != null:
			size = mesh_instance.mesh.get_aabb().size.length()
		if size <= 1.8:
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			dropped += 1
		else:
			kept += 1
	print("DSH_SHADOWS kept=", kept, " dropped=", dropped)
## DSH_OPT: one mesh per material instead of one node per bracket.
## Everything under the castle that never moves is appended into a single surface per
## material and the originals are freed. Triangles, materials and shadows are unchanged; the
## draw calls go from hundreds to a handful. The gate leaves (which swing and lose planks one
## by one) and the lever (which turns) are skipped.
func _batch_static_decoration() -> void:
	var groups: Dictionary = {}
	var doomed: Array[MeshInstance3D] = []
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance == null or instance.mesh == null: continue
		if _under_moving_parent(instance): continue
		# LOD slabs carry their own visibility range. Flattening them into the near
		# decoration mesh made the plain distant proxy cover all nearby masonry.
		if instance.visibility_range_begin > 0.0 or instance.visibility_range_end > 0.0:
			continue
		var material: Variant = instance.material_override
		if material == null and instance.mesh.get_surface_count() > 0:
			material = instance.mesh.surface_get_material(0)
		if material == null: continue
		# Family by LOOK, not by identity: a duplicate material with the same colour and the same
		# parameters draws identically, so it can share one merged surface.
		var key: String = _material_family(material) + "|" + instance.mesh.get_class()
		if not groups.has(key):
			groups[key] = {"material": material, "items": [], "shadow": false}
		var group: Dictionary = groups[key]
		(group["items"] as Array).append(instance)
		if instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			group["shadow"] = true
	var merged_nodes := 0
	var merged_sources := 0
	# Only what was really merged goes: the list is filled inside the merge loop, because a
	# group with a single member is left exactly as it is.
	var to_free: Array[MeshInstance3D] = []
	for key: String in groups:
		var group: Dictionary = groups[key]
		var items: Array = group.get("items", [])
		if items.size() < 2: continue
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var appended := 0
		for item: MeshInstance3D in items:
			if not is_instance_valid(item) or item.mesh == null: continue
			var relative: Transform3D = global_transform.affine_inverse() * item.global_transform
			tool.append_from(item.mesh, 0, relative)
			appended += 1
		if appended < 2: continue
		var merged: Mesh = tool.commit()
		if merged == null: continue
		var node := MeshInstance3D.new()
		node.name = "Batched_" + str(merged_nodes)
		node.mesh = merged
		node.material_override = group.get("material")
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(group.get("shadow", false)) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		merged_nodes += 1
		merged_sources += items.size()
		# The geometry is copied into the merged surface; the originals can go now.
		for item: MeshInstance3D in items:
			if is_instance_valid(item):
				item.queue_free()
	print("DSH_BATCH merged_nodes=", merged_nodes, " sources_merged=", merged_sources,
		" left=", find_children("*", "MeshInstance3D", true, false).size())

## A stable key for "this will look the same as that": colour, roughness, metalness, emission
## and shading mode. Textured materials are keyed by their texture as well.
func _material_family(material: Variant) -> String:
	var standard := material as StandardMaterial3D
	if standard == null:
		return "other|%d" % (material as Resource).get_instance_id()
	var key := "%s|%s|%.3f|%.3f|%s|%d|%.2f" % [
		standard.albedo_color.to_html(),
		str(standard.albedo_texture != null),
		standard.roughness, standard.metallic,
		standard.emission.to_html(),
		standard.shading_mode,
		standard.emission_energy_multiplier]
	if standard.albedo_texture != null:
		key += "|%d" % standard.albedo_texture.get_instance_id()
	return key

func _under_moving_parent(node: Node) -> bool:
	var walk: Node = node
	while walk != null and walk != self:
		var name_text := String(walk.name)
		if name_text.begins_with("GateLeaf") or name_text.begins_with("Lever") \
			or name_text.begins_with("OuterLever"):
			return true
		walk = walk.get_parent()
	return false

## DSH_OPT: the iron bands, studs, hinges, stiles and the seam strips of one gate leaf
## never come apart on their own - they go when the whole leaf goes. Merged into one mesh
## per material they still swing on the hinge, and the leaf drops from ~40 draws to 2.
func _merge_pivot_decoration(pivot: Node3D) -> void:
	var groups: Dictionary = {}
	for child: Node in pivot.get_children():
		if child is MultiMeshInstance3D: continue
		var item := child as MeshInstance3D
		if item == null or item.mesh == null: continue
		var material: Variant = item.material_override
		if material == null and item.mesh.get_surface_count() > 0:
			material = item.mesh.surface_get_material(0)
		if material == null: continue
		var key: String = _material_family(material)
		if not groups.has(key):
			groups[key] = {"material": material, "items": []}
		(groups[key]["items"] as Array).append(item)
	var pivot_inverse: Transform3D = pivot.global_transform.affine_inverse()
	for key: String in groups:
		var items: Array = groups[key]["items"]
		if items.size() < 2: continue
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var appended := 0
		for item: MeshInstance3D in items:
			if not is_instance_valid(item) or item.mesh == null: continue
			tool.append_from(item.mesh, 0, pivot_inverse * item.global_transform)
			appended += 1
		if appended < 2: continue
		var merged: Mesh = tool.commit()
		if merged == null: continue
		var node := MeshInstance3D.new()
		node.name = "GateLeafFittings"
		node.mesh = merged
		node.material_override = groups[key]["material"]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(node)
		for item: MeshInstance3D in items:
			if is_instance_valid(item):
				item.queue_free()

func _flush_buckets() -> void:
	_buckets.clear()
	_spatial.clear()
	_stair_families.clear()
	_support_ceiling55 = 0.0
	for index: int in _cells.size():
		var cell: Dictionary = _cells[index]
		var family_group := str(cell.get("group", ""))
		if family_group.begins_with("stairs_"):
			var family := family_group.get_slice("_",
				family_group.get_slice_count("_") - 1)
			if not _stair_families.has(family):
				_stair_families[family] = []
			(_stair_families[family] as Array).append(index)
		var at: Vector3 = cell.get("at", Vector3.ZERO)
		var bounds := _cell_bounds55(cell)
		cell["bounds55"] = bounds
		_support_ceiling55 = maxf(_support_ceiling55, bounds.end.y)
		for gx: int in range(int(floor(bounds.position.x / SPATIAL_STEP)), int(floor(bounds.end.x / SPATIAL_STEP)) + 1):
			for gy: int in range(int(floor(bounds.position.y / SPATIAL_STEP)), int(floor(bounds.end.y / SPATIAL_STEP)) + 1):
				for gz: int in range(int(floor(bounds.position.z / SPATIAL_STEP)), int(floor(bounds.end.z / SPATIAL_STEP)) + 1):
					var spatial_key := "%d|%d|%d" % [gx, gy, gz]
					if not _spatial.has(spatial_key): _spatial[spatial_key] = []
					(_spatial[spatial_key] as Array).append(index)
		var key := "%s|%s|%d|%d|%d" % [str(cell.get("material", "stone")),
			str(cell.get("shape", "box")),
			int(floor(at.x / CHUNK_X)), int(floor(at.y / CHUNK_Y)), int(floor(at.z / CHUNK_Z))]
		if not _buckets.has(key):
			_buckets[key] = {"indices": [], "material": str(cell.get("material", "stone")),
				"shape": str(cell.get("shape", "box"))}
		(_buckets[key]["indices"] as Array).append(index)
	var chunk_count := 0
	for key: String in _buckets.keys():
		var bucket: Dictionary = _buckets[key]
		var indices: Array = bucket["indices"]
		if indices.is_empty(): continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = _furniture_meshes.get(str(bucket.get("shape", "box")), _brick_mesh)
		multi.instance_count = indices.size()
		for slot: int in indices.size():
			var cell: Dictionary = _cells[int(indices[slot])]
			cell["bucket"] = key
			cell["instance"] = slot
			multi.set_instance_transform(slot, _brick_transform(cell))
			multi.set_instance_color(slot, _brick_tint(cell))
		var node := MultiMeshInstance3D.new()
		node.name = "Bricks%d" % chunk_count
		node.multimesh = multi
		node.material_override = _materials[str(bucket.get("material", "stone"))]
		if str(bucket.get("material", "")) == "floor_wood":
			# Thin boards sit directly on solid tiles, so their shadow pass only
			# repeats the same surface at extra draw cost.
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# No global-illumination participation for thousands of static stones: it buys
		# nothing on a wall and costs a lot to bake.
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(node)
		bucket["node"] = node
		chunk_count += 1
	_chunk_total = chunk_count

var _chunk_total := 0

## How much of the castle is actually being drawn, for the optimisation to be measured
## rather than claimed.
##
## A chunk node is added at the castle's own origin and its bricks are spread along a whole
## wall, so asking whether the NODE's position is inside the camera said every chunk was on
## screen: all 60k stones "in frame" from any angle. The real answer is the world-space AABB
## of the chunk's LIVE instances, tested against the camera's frustum. Dead bricks are left
## out on purpose - a knocked-out stone is parked kilometres below the map so the engine
## would otherwise count it again.
func render_stats() -> Dictionary:
	var camera: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	var planes: Array[Plane] = []
	var inside_point := Vector3.ZERO
	if camera != null:
		planes = camera.get_frustum()
		# The camera lies ON four of its six planes (the sides), so it cannot say which
		# side of them is "inside". A metre in front of the lens can.
		inside_point = camera.global_position - camera.global_basis.z
	# One pass over the cells: each live brick grows the box of its own chunk, and each
	# chunk's live count is kept for the report.
	var bounds: Dictionary = {}
	var live_by_chunk: Dictionary = {}
	var alive := 0
	for cell: Dictionary in _cells:
		if not bool(cell.get("alive", false)): continue
		var key: String = str(cell.get("bucket", ""))
		if key == "": continue
		alive += 1
		live_by_chunk[key] = int(live_by_chunk.get(key, 0)) + 1
		var brick_box: AABB = _brick_transform(cell) * AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
		if bounds.has(key):
			bounds[key] = (bounds[key] as AABB).merge(brick_box)
		else:
			bounds[key] = brick_box
	var visible := 0
	var instances := 0
	var live := 0
	for key: String in _buckets.keys():
		var node: MultiMeshInstance3D = (_buckets[key] as Dictionary).get("node")
		if not is_instance_valid(node) or not bounds.has(key): continue
		live += 1
		var world_box: AABB = global_transform * (bounds[key] as AABB)
		if planes.is_empty() or _aabb_in_frustum(world_box, planes, inside_point):
			visible += 1
			instances += int(live_by_chunk.get(key, 0))
	return {"chunks": _chunk_total, "chunks_live": live, "chunks_in_frustum": visible,
		"bricks_in_frustum": instances, "bricks": _cells.size(), "bricks_alive": alive,
		"bounds_alive": bounds.size()}

## Conservative frustum test against a world-space box: a box is outside when its corner
## furthest along one plane's inward normal is still behind that plane. The inward side is
## anchored on the camera itself, which is always inside its own frustum.
func _aabb_in_frustum(box: AABB, planes: Array[Plane], inside_point: Vector3) -> bool:
	for plane: Plane in planes:
		var inward: float = 1.0 if plane.distance_to(inside_point) >= 0.0 else -1.0
		var positive := box.position
		if plane.normal.x >= 0.0: positive.x += box.size.x
		if plane.normal.y >= 0.0: positive.y += box.size.y
		if plane.normal.z >= 0.0: positive.z += box.size.z
		if plane.distance_to(positive) * inward < 0.0:
			return false
	return true
## A brick's transform: its place, its size, and a few degrees of settling so the wall
## does not look machine-made.
func _brick_transform(cell: Dictionary) -> Transform3D:
	var at: Vector3 = cell.get("at", Vector3.ZERO)
	var size: Vector3 = cell.get("size", BRICK)
	var group: String = str(cell.get("group", ""))
	var structural: bool = group == "keep" or group == "keep_floor_board" or group in ["north", "south", "east", "west", "tower", "gatehouse"]
	if structural:
		# A dark slit through a wall reads as a missing stone. Keep the joint tight;
		# colour variation and relief still give each course its bond.
		size = Vector3(size.x * 0.99, size.y * 0.98, size.z * 0.995)
	var rotation: Vector3 = cell.get("rotation", Vector3.ZERO)
	var jitter := 0.0 if structural or group.begins_with("stairs_") or group.begins_with("courtyard43_") or "merlon" in group or group in ["tower_floor55", "tower_roof55"] else 1.0
	var basis := Basis.from_euler(Vector3(
		rotation.x + jitter * float(int(at.x * 7.0 + at.y * 13.0) % 5) * 0.004,
		rotation.y + jitter * float(int(at.z * 11.0 + at.y * 5.0) % 5) * 0.004,
		rotation.z))
	if str(cell.get("shape", "box")) == "box":
		basis = basis.scaled(Vector3(size.x / BRICK.x, size.y / BRICK.y, size.z / BRICK.z))
	else:
		basis = basis.scaled(size)
	return Transform3D(basis, at)

## Slight colour variation per brick, so the wall reads as stone rather than as paint.
func _brick_tint(cell: Dictionary) -> Color:
	var at: Vector3 = cell.get("at", Vector3.ZERO)
	var hash := int(at.x * 11317.0) ^ int(at.y * 7111.0) ^ int(at.z * 5309.0)
	var tone := float(abs(hash) % 1000) / 1000.0
	if str(cell.get("group", "")) == "keep_floor_board":
		# Every board has its own oak shade; the grain is still one shared material.
		var oak := 0.89 + tone * 0.18
		return Color(oak * 1.035, oak, oak * 0.94)
	# One stone in sixteen is weathered: a wall of stones all the same age is a wall of
	# stones nobody has ever lived with.
	var multiplier := 0.945 + tone * 0.11
	if abs(hash) % 16 == 0:
		multiplier *= 0.86
	return Color(multiplier, multiplier * 0.99, multiplier * 0.95)

func _kill_brick(index: int, impulse: Vector3, power: float) -> void:
	if index < 0 or index >= _cells.size(): return
	var cell: Dictionary = _cells[index]
	if not bool(cell.get("alive", false)): return
	cell["alive"] = false
	_masonry_changed55[index] = true
	var masonry_shape: CollisionShape3D = _masonry_shapes55.get(index)
	if is_instance_valid(masonry_shape): masonry_shape.set_deferred("disabled", true)
	var courtyard_shape: CollisionShape3D = _courtyard_shapes43.get(index)
	if is_instance_valid(courtyard_shape):
		courtyard_shape.set_deferred("disabled", true)
	if _courtyard_dependents43.has(index):
		var attached: Array = _courtyard_dependents43[index]
		_courtyard_dependents43.erase(index)
		for dependent: int in attached:
			_kill_brick(dependent, impulse, power)
	var merlon_shape: CollisionShape3D = _merlon_collision.get(index)
	if is_instance_valid(merlon_shape):
		merlon_shape.set_deferred("disabled", true)
	_detached += 1
	# Removing any stone invalidates the support question for the cells above its
	# footprint. The audit walks upward through what actually remains; it is not limited
	# to a fixed blast radius or just the nearest course.
	_queue_support_audit(index)
	# Take it out of the drawing: the instance is moved far below the world, which is
	# cheaper than rebuilding the MultiMesh.
	var key: String = str(cell.get("bucket", ""))
	if _buckets.has(key):
		var bucket: Dictionary = _buckets[key]
		var node: MultiMeshInstance3D = bucket.get("node")
		var slot: int = int(cell.get("instance", -1))
		if is_instance_valid(node) and slot >= 0:
			node.multimesh.set_instance_transform(slot,
				Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.0001), Vector3(0.0, -4000.0, 0.0)))
	# Long furnishings split into short boards instead of flying away as one
	# implausibly large box. The existing capped debris pool owns every piece.
	var material_key: String = str(cell.get("material", "stone"))
	var group: String = str(cell.get("group", ""))
	if group.begins_with("stairs_"):
		var stair_key := "%s:%d" % [group, int(cell.get("row", -1))]
		var stair_shape: CollisionShape3D = _stair_step_collision.get(stair_key)
		if is_instance_valid(stair_shape):
			stair_shape.set_deferred("disabled", true)
	var size: Vector3 = cell.get("size", BRICK)
	if material_key.begins_with("wood") and (group.begins_with("hall_") or
			group.begins_with("armour_") or group.begins_with("archive_") or
			group.begins_with("chamber_")) and maxf(size.x, size.z) >= 1.5:
		var along_x: bool = size.x >= size.z
		var length: float = size.x if along_x else size.z
		var pieces: int = clampi(int(ceil(length / 1.0)), 2, 4)
		for piece: int in pieces:
			var fragment: Dictionary = cell.duplicate()
			var fragment_size := size
			var fragment_at: Vector3 = cell["at"]
			var offset: float = (float(piece) + 0.5 - float(pieces) * 0.5) * length / float(pieces)
			if along_x:
				fragment_size.x = length / float(pieces) * 0.97
				fragment_at.x += offset
			else:
				fragment_size.z = length / float(pieces) * 0.97
				fragment_at.z += offset
			fragment["size"] = fragment_size
			fragment["at"] = fragment_at
			_spawn_falling_brick(fragment, impulse, power * 0.65)
	else:
		_spawn_falling_brick(cell, impulse, power)

func _new_debris_body() -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "Brick"
	body.mass = 18.0
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	body.add_child(shape)
	if _debris_mesh == null:
		_debris_mesh = BoxMesh.new()
		_debris_mesh.size = Vector3.ONE
	var fresh_mesh := MeshInstance3D.new()
	fresh_mesh.name = "Mesh"
	fresh_mesh.mesh = _debris_mesh
	fresh_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(fresh_mesh)
	add_child(body)
	return body

## DSH_OPT: the first wall blast used to allocate every stone it throws, and 150 new
## RigidBody3D nodes in one frame froze the game for two hundred milliseconds. The pool is
## filled during the build instead, so a breach reuses bodies that already exist.
func _prewarm_debris_pool() -> void:
	var started := Time.get_ticks_usec()
	while _debris_pool.size() < MAX_FALLING:
		_recycle_stone(_new_debris_body())
	print("DSH_DEBRIS_PREWARM bodies=", _debris_pool.size(), " ms=",
		float(Time.get_ticks_usec() - started) / 1000.0)

func _spawn_falling_brick(cell: Dictionary, impulse: Vector3, power: float) -> void:
	if _falling.size() >= MAX_FALLING:
		_debris_backlog.append({"cell": cell.duplicate(), "impulse": impulse,
			"power": power})
		return
	_spawn_falling_brick_now(cell, impulse, power)

func _spawn_falling_brick_now(cell: Dictionary, impulse: Vector3, power: float) -> void:
	# FROM THE POOL when there is one: a blast that reuses its stones allocates nothing.
	var body: RigidBody3D = null
	while not _debris_pool.is_empty():
		var candidate: RigidBody3D = _debris_pool.pop_back()
		if is_instance_valid(candidate):
			body = candidate
			break
	var from_pool: bool = body != null
	if body == null:
		body = _new_debris_body()
	var size: Vector3 = cell.get("size", BRICK)
	var material_key: String = str(cell.get("material", "stone"))
	var volume: float = size.x * size.y * size.z
	var density: float = 3.5 if material_key in ["wood", "wood_alt", "floor_wood"] else \
		0.8 if material_key in ["linen", "velvet"] else 18.0
	body.mass = clampf(volume * density, 0.3, 80.0)
	var body_shape: CollisionShape3D = body.get_node_or_null("Shape") as CollisionShape3D
	var shape_key: String = cell.get("shape", "box")
	if body_shape != null:
		body_shape.scale = Vector3.ONE
		if shape_key == "tower_floor55":
			var cylinder := CylinderShape3D.new()
			cylinder.radius = size.x * 0.5
			cylinder.height = size.y
			body_shape.shape = cylinder
		elif shape_key == "tower_roof55":
			body_shape.shape = (_furniture_meshes[shape_key] as Mesh).create_convex_shape()
			body_shape.scale = size
		else:
			var box := BoxShape3D.new()
			box.size = size
			body_shape.shape = box
	var mesh_instance: MeshInstance3D = body.get_node_or_null("Mesh") as MeshInstance3D
	if mesh_instance != null:
		mesh_instance.mesh = _furniture_meshes[shape_key] if shape_key in ["tower_floor55", "tower_roof55"] else _debris_mesh
		mesh_instance.scale = size
		var key: String = str(cell.get("material", "stone"))
		var tint: Color = _brick_tint(cell)
		var debris_key := "%s|%d" % [key, int(tint.r * 40.0)]
		if not _debris_materials.has(debris_key):
			var base_material: Material = _materials.get(key, _materials["stone"])
			if base_material is StandardMaterial3D:
				var tinted: StandardMaterial3D = base_material.duplicate()
				tinted.albedo_color = Color(base_material.albedo_color.r * tint.r,
					base_material.albedo_color.g * tint.g, base_material.albedo_color.b * tint.b)
				_debris_materials[debris_key] = tinted
			else:
				_debris_materials[debris_key] = base_material
		mesh_instance.material_override = _debris_materials[debris_key]
	body.freeze = false
	body.collision_layer = 1
	body.collision_mask = 1
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.visible = true
	body.position = cell.get("at", Vector3.ZERO)
	body.rotation = cell.get("rotation", Vector3.ZERO)
	var direction: Vector3 = impulse.normalized() if impulse.length_squared() > 1.0e-6 else Vector3.DOWN
	body.linear_velocity = (direction * 0.55 + Vector3.UP * 0.55).normalized() \
		* clampf(power * 0.35, 2.0, 26.0) * randf_range(0.7, 1.3)
	body.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	_falling.append({"body": body, "age": 0.0, "cell": cell.duplicate(),
		"substantial": _is_substantial_rubble(cell), "support_frames": 0})
	if from_pool:
		_reused_stones += 1
func _build_curtain_walls() -> void:
	# Four walls round the courtyard, laid course by course with a half-brick offset on
	# every other course, which is how a real bond looks.
	for side: String in ["north", "south", "east", "west"]:
		_build_wall(side)
		_add_battlements(side)
		# Narrow shooting ports are cut through both brick skins and collision.
		_add_plinth(side)
		_add_corbels(side)
		_add_buttresses(side)

## The wall is laid in TWO skins of brick, an outer and an inner. A single skin with a dark
## slab behind it is what a breach used to show: a grey square, with the street beyond it.
## Two skins give a breach depth, and the joints between the bricks read dark on their own
## because the opposite skin sits half a metre behind them in shadow.
func _build_wall(side: String) -> void:
	var courses := int(WALL_HEIGHT / BRICK.y)
	var per_course := int((WALL_HALF * 2.0) / BRICK.x)
	var layer_depth := WALL_THICK * 0.5
	for layer: int in 2:
		var layer_sign: float = -1.0 if layer == 0 else 1.0
		var inset: float = layer_sign * (WALL_THICK * 0.5 - layer_depth * 0.5)
		for row: int in courses:
			var offset := 0.0 if (row + layer) % 2 == 0 else BRICK.x * 0.5
			for column: int in per_course:
				var along := (float(column) - float(per_course - 1) * 0.5) * BRICK.x + offset
				# The gate is a real opening: no bricks inside it.
				if side == "south" and row * BRICK.y < GATE_HEIGHT \
					and absf(along) < GATE_WIDTH * 0.5 + BRICK.x * 0.5:
					continue
				var height := (float(row) + 0.5) * BRICK.y
				var at := Vector3.ZERO
				var size := BRICK
				match side:
					"north":
						at = Vector3(along, height, -WALL_HALF + inset)
						size = Vector3(BRICK.x, BRICK.y, layer_depth)
					"south":
						at = Vector3(along, height, WALL_HALF + inset)
						size = Vector3(BRICK.x, BRICK.y, layer_depth)
					"east":
						at = Vector3(WALL_HALF + inset, height, along)
						size = Vector3(layer_depth, BRICK.y, BRICK.x)
					"west":
						at = Vector3(-WALL_HALF + inset, height, along)
						size = Vector3(layer_depth, BRICK.y, BRICK.x)
				_add_slit_cut_brick(at, size, side, row, column)
		# The wall itself is solid: one collision slab per wall, so the map is a place you
		# can lean on, not a curtain of loose stones.
	if side == "south":
		# The wall is solid EXCEPT at the gate: two piers and a lintel, so the opening can
		# be walked through and the masonry either side of it is still a wall.
		var pier: float = (WALL_HALF * 2.0 - GATE_WIDTH) * 0.5
		for pier_side: float in [-1.0, 1.0]:
			_add_wall_collision(Vector3(pier_side * (GATE_WIDTH * 0.5 + pier * 0.5), WALL_HEIGHT * 0.5, WALL_HALF),
				Vector3(pier, WALL_HEIGHT, WALL_THICK), "south")
		_add_wall_collision(Vector3(0.0, (WALL_HEIGHT + GATE_HEIGHT) * 0.5, WALL_HALF),
			Vector3(GATE_WIDTH, WALL_HEIGHT - GATE_HEIGHT, WALL_THICK), "south")
	elif side == "north":
		# RUN PAST THE CORNER. The wall box ended exactly at the corner, where the round
		# tower begins, and that joint was a seam a player could squeeze into. Extending it by
		# a tower radius costs nothing visible - the thickness is unchanged - and shuts it.
		_add_wall_collision(Vector3(0.0, WALL_HEIGHT * 0.5, -WALL_HALF),
			Vector3(WALL_HALF * 2.0 + TOWER_RADIUS * 2.0, WALL_HEIGHT, WALL_THICK), "north")
	else:
		_add_wall_collision(Vector3(WALL_HALF if side == "east" else -WALL_HALF, WALL_HEIGHT * 0.5, 0.0),
			Vector3(WALL_THICK, WALL_HEIGHT, WALL_HALF * 2.0 + TOWER_RADIUS * 2.0), side)

func _add_mortar(at: Vector3, size: Vector3, vertical: bool = false) -> void:
	# A dark core, a little thinner than the wall, seen through the joints between bricks.
	var mortar := MeshInstance3D.new()
	if vertical:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = size.x * 0.5
		cylinder.bottom_radius = size.x * 0.5
		cylinder.height = size.y
		cylinder.radial_segments = 16
		mortar.mesh = cylinder
	else:
		var box := BoxMesh.new()
		box.size = size
		mortar.mesh = box
	mortar.material_override = _materials["cold"]
	mortar.position = at
	add_child(mortar)

func _slit_pieces(at: Vector3, size: Vector3, side: String) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = [{"at": at, "size": size}]
	if side not in ["north", "south", "east", "west"]: return pieces
	if at.y + size.y * 0.5 <= ARROW_PORT_Y - ARROW_PORT_HEIGHT * 0.5 \
		or at.y - size.y * 0.5 >= ARROW_PORT_Y + ARROW_PORT_HEIGHT * 0.5:
		return pieces
	var along_x := side in ["north", "south"]
	for opening: float in ARROW_PORT_ALONG:
		var next_pieces: Array[Dictionary] = []
		for piece: Dictionary in pieces:
			var centre: Vector3 = piece["at"]
			var dimensions: Vector3 = piece["size"]
			var along: float = centre.x if along_x else centre.z
			var span: float = dimensions.x if along_x else dimensions.z
			var lo: float = along - span * 0.5
			var hi: float = along + span * 0.5
			var bottom: float = centre.y - dimensions.y * 0.5
			var top: float = centre.y + dimensions.y * 0.5
			var cut_lo: float = maxf(lo, opening - ARROW_PORT_WIDTH * 0.5)
			var cut_hi: float = minf(hi, opening + ARROW_PORT_WIDTH * 0.5)
			var cut_bottom: float = maxf(bottom, ARROW_PORT_Y - ARROW_PORT_HEIGHT * 0.5)
			var cut_top: float = minf(top, ARROW_PORT_Y + ARROW_PORT_HEIGHT * 0.5)
			if cut_hi <= cut_lo or cut_top <= cut_bottom:
				next_pieces.append(piece)
				continue
			for interval: Vector2 in [Vector2(lo, cut_lo), Vector2(cut_hi, hi)]:
				if interval.y - interval.x < 0.025: continue
				var fragment_at := centre
				var fragment_size := dimensions
				if along_x:
					fragment_at.x = (interval.x + interval.y) * 0.5
					fragment_size.x = interval.y - interval.x
				else:
					fragment_at.z = (interval.x + interval.y) * 0.5
					fragment_size.z = interval.y - interval.x
				next_pieces.append({"at": fragment_at, "size": fragment_size})
			for interval: Vector2 in [Vector2(bottom, cut_bottom), Vector2(cut_top, top)]:
				if interval.y - interval.x < 0.025: continue
				var fragment_at := centre
				var fragment_size := dimensions
				fragment_at.y = (interval.x + interval.y) * 0.5
				fragment_size.y = interval.y - interval.x
				if along_x:
					fragment_at.x = (cut_lo + cut_hi) * 0.5
					fragment_size.x = cut_hi - cut_lo
				else:
					fragment_at.z = (cut_lo + cut_hi) * 0.5
					fragment_size.z = cut_hi - cut_lo
				next_pieces.append({"at": fragment_at, "size": fragment_size})
		pieces = next_pieces
	return pieces

func _add_slit_cut_brick(at: Vector3, size: Vector3, side: String, row: int, column: int) -> void:
	for piece: Dictionary in _slit_pieces(at, size, side):
		_add_brick(piece["at"], piece["size"], "stone", Vector3.ZERO, side, row, column)

func _add_wall_collision(at: Vector3, size: Vector3, slit_side: String = "") -> void:
	# Split collision into bounded sections. A catapult breach must remove the solid
	# collision behind its missing bricks without making the whole wall intangible.
	var along_x := size.x >= size.z
	var horizontal := size.x if along_x else size.z
	var columns := maxi(1, int(ceil(horizontal / 3.8)))
	var levels := maxi(1, int(ceil(size.y / 3.8)))
	for column: int in columns:
		for level: int in levels:
			var section_size := size
			if along_x: section_size.x = horizontal / float(columns)
			else: section_size.z = horizontal / float(columns)
			section_size.y = size.y / float(levels)
			var section_at := at
			if along_x: section_at.x += -horizontal * 0.5 + (float(column) + 0.5) * section_size.x
			else: section_at.z += -horizontal * 0.5 + (float(column) + 0.5) * section_size.z
			section_at.y += -size.y * 0.5 + (float(level) + 0.5) * section_size.y
			for piece: Dictionary in _slit_pieces(section_at, section_size, slit_side):
				_add_breakable_collision(piece["at"], piece["size"])

func _add_breakable_collision(at: Vector3, size: Vector3, rotation_y: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = at
	body.rotation.y = rotation_y
	body.set_meta("castle_brick", true)
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_wall_collision.append({"body": body, "at": at, "size": size, "alive": true})

func _break_collision_near(at: Vector3, radius: float) -> void:
	var world_at: Vector3 = to_global(at)
	for section: Dictionary in _wall_collision:
		if not bool(section.get("alive", false)): continue
		var body: StaticBody3D = section["body"]
		if not is_instance_valid(body): continue
		if not body.get_meta("castle_furnishing", false) and not body.get_meta("castle_keep_floor", false):
			continue # Wall sections were refined to their surviving cells above.
		var size: Vector3 = section["size"]
		# DSH_OPT: a cheap sphere reject first. The exact test inverts a transform and
		# clamps a point, and most of the 2k sections are nowhere near the strike.
		var reach: float = radius + size.length() * 0.5
		if body.global_position.distance_squared_to(world_at) > reach * reach: continue
		# Floor tiles lose their own support when struck, leaving adjacent tiles intact.
		if body.get_meta("castle_keep_floor", false) and section["at"].distance_to(at) > radius:
			continue
		var local_hit: Vector3 = body.global_transform.affine_inverse() * world_at
		var nearest := Vector3(clampf(local_hit.x, -size.x * 0.5, size.x * 0.5),
			clampf(local_hit.y, -size.y * 0.5, size.y * 0.5),
			clampf(local_hit.z, -size.z * 0.5, size.z * 0.5))
		# The visible masonry uses the full impact radius; the collision must leave
		# the same opening, including curved tower panels just behind the outer skin.
		if nearest.distance_to(local_hit) > radius: continue
		section["alive"] = false
		body.collision_layer = 0

func _add_battlements(side: String) -> void:
	var per_course := int((WALL_HALF * 2.0) / BRICK.x)
	for row: int in 3:
		for column: int in per_course:
			if column % 2 == 1: continue
			var along := (float(column) - float(per_course - 1) * 0.5) * BRICK.x
			var height := WALL_HEIGHT + (float(row) + 0.5) * BRICK.y
			var at := Vector3.ZERO
			var size := BRICK
			match side:
				"north": at = Vector3(along, height, -WALL_HALF)
				"south": at = Vector3(along, height, WALL_HALF)
				"east": at = Vector3(WALL_HALF, height, along)
				"west": at = Vector3(-WALL_HALF, height, along)
			if side in ["east", "west"]:
				size = Vector3(BRICK.z, BRICK.y, BRICK.x)
			_add_brick(at, size, "warm" if row == 1 else "stone", Vector3.ZERO, side + "_merlon", row, column)

func _add_plinth(side: String) -> void:
	var per_course := int((WALL_HALF * 2.0) / BRICK.x)
	for column: int in per_course:
		var along := (float(column) - float(per_course - 1) * 0.5) * BRICK.x
		# The gate opening must also cut the decorative footing. These stones
		# otherwise form a knee-high, non-colliding threshold across both leaves.
		if side == "south" and absf(along) < GATE_WIDTH * 0.5 + BRICK.x * 0.51:
			continue
		var at := Vector3.ZERO
		var size := Vector3(BRICK.x * 1.02, BRICK.y * 1.1, WALL_THICK * 1.35)
		match side:
			"north": at = Vector3(along, BRICK.y * 0.5, -WALL_HALF)
			"south": at = Vector3(along, BRICK.y * 0.5, WALL_HALF)
			"east":
				at = Vector3(WALL_HALF, BRICK.y * 0.5, along)
				size = Vector3(WALL_THICK * 1.35, BRICK.y * 1.1, BRICK.x * 1.02)
			"west":
				at = Vector3(-WALL_HALF, BRICK.y * 0.5, along)
				size = Vector3(WALL_THICK * 1.35, BRICK.y * 1.1, BRICK.x * 1.02)
		_add_brick(at, size, "cold", Vector3.ZERO, side + "_plinth", 0, column)

func _add_arrow_slits(side: String) -> void:
	var step := 9.0
	var count := int((WALL_HALF * 2.0) / step)
	for i: int in count:
		var along := (float(i) - float(count - 1) * 0.5) * step
		for height: float in [5.2, 9.0]:
			var at := Vector3.ZERO
			var size := Vector3(0.30, 1.30, 0.14)
			match side:
				"north":
					at = Vector3(along, height, -WALL_HALF + WALL_THICK * 0.5 + 0.02)
				"south":
					at = Vector3(along, height, WALL_HALF - WALL_THICK * 0.5 - 0.02)
				"east":
					at = Vector3(WALL_HALF - WALL_THICK * 0.5 - 0.02, height, along)
					size = Vector3(0.14, 1.30, 0.30)
				"west":
					at = Vector3(-WALL_HALF + WALL_THICK * 0.5 + 0.02, height, along)
					size = Vector3(0.14, 1.30, 0.30)
			_add_brick(at, size, "dark", Vector3.ZERO, side + "_slit", 0, i)

## ------------------------------------------------------------------ towers, gate, keep
func _build_corner_towers() -> void:
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var centre := Vector3(corner.x * WALL_HALF, 0.0, corner.y * WALL_HALF)
		# The tower is laid as rings of bricks: it is round because the bricks are.
		var courses := int(TOWER_HEIGHT / BRICK.y)
		var around: int = maxi(12, int(round(TAU * TOWER_RADIUS / (BRICK.x * 0.98))))
		var brick_length: float = TAU * TOWER_RADIUS / float(around) * 1.06
		for row: int in courses:
			var radius := TOWER_RADIUS - float(row) * 0.012
			var angle_offset: float = (float(row % 2)) * (TAU / float(around)) * 0.5
			for i: int in around:
				var angle: float = TAU * float(i) / float(around) + angle_offset
				var at := centre + Vector3(cos(angle) * radius,
					(float(row) + 0.5) * BRICK.y, sin(angle) * radius)
				var size := Vector3(brick_length, BRICK.y, BRICK.z * 1.5)
				var key := "stone" if row % 4 != 0 else "cold"
				_add_brick(at, size, key, Vector3(0.0, -angle, 0.0), "tower")
		# Sixteen curved collision panels per level keep the tower hollow. A stone
		# removes only the panels behind its visible masonry breach; no hidden
		# cylinder or corner block can continue to stop a player afterwards.
		var to_centre: Vector3 = Vector3(-corner.x, 0.0, -corner.y).normalized()
		var doorway_angle: float = atan2(to_centre.z, to_centre.x)
		var levels := int(ceil(TOWER_HEIGHT / 3.8))
		var segments := 16
		var arc_width := TAU * (TOWER_RADIUS - 0.25) / float(segments) * 1.035
		for level: int in levels:
			var panel_height := TOWER_HEIGHT / float(levels)
			var y := (float(level) + 0.5) * panel_height
			for segment: int in segments:
				var angle: float = TAU * (float(segment) + 0.5) / float(segments)
				if y > WALL_HEIGHT and absf(wrapf(angle - doorway_angle, -PI, PI)) < 0.42:
					continue
				var panel_at := centre + Vector3(cos(angle) * (TOWER_RADIUS - 0.25), y,
					sin(angle) * (TOWER_RADIUS - 0.25))
				_add_breakable_collision(panel_at, Vector3(arc_width, panel_height, 1.0),
					PI * 0.5 - angle)
		# Slits, facing outwards at three heights.
		for i: int in 6:
			var slit_angle := TAU * float(i) / 6.0
			for height: float in [6.4, 10.2, 14.4]:
				_add_brick(centre + Vector3(cos(slit_angle) * (TOWER_RADIUS + 0.05), height,
					sin(slit_angle) * (TOWER_RADIUS + 0.05)),
					Vector3(0.30, 1.25, 0.16), "dark", Vector3(0.0, -slit_angle, 0.0), "tower_slit")

## Projecting courses and spaced merlons make the four towers read above the long
## curtain walls. They use the existing breakable masonry buckets: no new static
## draw calls, lights, shadow casters or permanent collision bodies per stone.
func _build_exterior_crowns() -> void:
	var around := maxi(12, int(round(TAU * TOWER_RADIUS / (BRICK.x * 0.98))))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var centre := Vector3(corner.x * WALL_HALF, 0.0, corner.y * WALL_HALF)
		for tier: int in 2:
			var radius := TOWER_RADIUS + 0.22 + float(tier) * 0.28
			var height := TOWER_HEIGHT - 0.38 + float(tier) * 0.44
			for segment: int in around:
				var angle := TAU * (float(segment) + float(tier % 2) * 0.5) / float(around)
				_add_brick(centre + Vector3(cos(angle) * radius, height, sin(angle) * radius),
					Vector3(1.13, 0.38, 0.62), "cold" if tier == 0 else "warm",
					Vector3(0.0, -angle, 0.0), "tower_crown", tier, segment)
		for segment: int in around:
			if segment % 2 != 0: continue
			var angle := TAU * float(segment) / float(around)
			_add_brick(centre + Vector3(cos(angle) * (TOWER_RADIUS + 0.34),
				TOWER_HEIGHT + 0.85, sin(angle) * (TOWER_RADIUS + 0.34)),
				Vector3(1.12, 1.70, 0.72), "stone", Vector3(0.0, -angle, 0.0),
				"tower_crown_merlon", 0, segment)
	# A compact heraldic stone shield above the gate gives the entrance a focal
	# point. Relief stays in front of the facade and never closes the passage.
	var face_z := WALL_HALF + WALL_THICK * 0.98
	for row: int in 4:
		var half_width := 1.7 if row < 2 else (1.25 if row == 2 else 0.75)
		_add_brick(Vector3(0.0, 15.7 + float(row) * 0.68, face_z),
			Vector3(half_width * 2.0, 0.62, 0.28), "cold", Vector3.ZERO,
			"gate_shield", row, 0)
	_add_brick(Vector3(0.0, 16.92, face_z + 0.19), Vector3(0.35, 2.05, 0.12),
		"ochre", Vector3.ZERO, "gate_device")
	_add_brick(Vector3(0.0, 17.31, face_z + 0.19), Vector3(1.85, 0.32, 0.12),
		"ochre", Vector3.ZERO, "gate_device")

func _build_gatehouse() -> void:
	var at := Vector3(0.0, 0.0, WALL_HALF)
	for side: float in [-1.0, 1.0]:
		var centre := at + Vector3(side * (GATE_WIDTH * 0.5 + 3.6), 0.0, 0.0)
		var courses := int(20.0 / BRICK.y)
		var per_course := 6
		for row: int in courses:
			for column: int in per_course:
				var along := (float(column) - float(per_course - 1) * 0.5) * BRICK.x
				_add_brick(centre + Vector3(along, (float(row) + 0.5) * BRICK.y, 0.0),
					Vector3(BRICK.x, BRICK.y, WALL_THICK * 1.6),
					"warm" if (row / 4) % 2 == 0 else "stone", Vector3.ZERO, "gatehouse", row, column)
		_add_wall_collision(centre + Vector3.UP * 10.0,
			Vector3(per_course * BRICK.x, 20.0, WALL_THICK * 1.6))
	# Quoins down the outer corners, battlements on top, and corbels carrying them: a
	# gatehouse is the part of a castle a lord pays to have look expensive.
	for side: float in [-1.0, 1.0]:
		var tower_centre := at + Vector3(side * (GATE_WIDTH * 0.5 + 3.6), 0.0, 0.0)
		var tower_courses: int = int(20.0 / BRICK.y)
		var tower_per_course: int = 6
		for row: int in tower_courses:
			var longer: bool = row % 2 == 0
			var size := Vector3(0.7 if longer else 0.44, BRICK.y, WALL_THICK * 1.75)
			_add_brick(tower_centre + Vector3(side * (tower_per_course * BRICK.x * 0.5 - size.x * 0.5 + 0.02),
				(float(row) + 0.5) * BRICK.y, 0.0), size, "cold", Vector3.ZERO, "gate_quoin", row, 0)
		for i: int in 5:
			_add_brick(tower_centre + Vector3(-tower_per_course * BRICK.x * 0.4
				+ float(i) * tower_per_course * BRICK.x * 0.2,
				20.0 + BRICK.y * 0.5, 0.0), Vector3(BRICK.x, BRICK.y, WALL_THICK * 1.6),
				"stone", Vector3.ZERO, "gate_merlon", 0, i)
		for i: int in 4:
			_add_brick(tower_centre + Vector3(-tower_per_course * BRICK.x * 0.36
				+ float(i) * tower_per_course * BRICK.x * 0.24, 19.4, 0.0),
				Vector3(0.36, 0.5, WALL_THICK * 2.4), "cold", Vector3.ZERO, "gate_corbel55")
	# The arch over the gate.
	var arch_rows := 3
	for row: int in arch_rows:
		var per_course := int((GATE_WIDTH + 7.0) / BRICK.x)
		for column: int in per_course:
			var along := (float(column) - float(per_course - 1) * 0.5) * BRICK.x
			_add_brick(at + Vector3(along, GATE_HEIGHT + (float(row) + 0.5) * BRICK.y, 0.0),
				Vector3(BRICK.x, BRICK.y, WALL_THICK * 1.6), "stone", Vector3.ZERO, "gate_arch", row, column)
	# THE LEAVES are hung on HINGES: each one a pivot at its own edge, so it can be swung.
	# The leaf is ONE SOLID SHIELD of oak with the plank seams cut into its face. Built from
	# six separate boards it had finger-wide gaps between them, and an oak gate that you can
	# see through is a grille.
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "GateLeaf" + ("Left" if side < 0.0 else "Right")
		pivot.position = at + Vector3(side * GATE_WIDTH * 0.5, 0.0, 0.0)
		add_child(pivot)
		var leaf_width := GATE_WIDTH * 0.5
		var board := leaf_width / 6.0
		# THE LEAF IS A GRID OF PLANKS: six columns by eight rows. A single tall board meant
		# that knocking it out tore an eleven-metre strip out of the door; with a grid a hit
		# opens a hole the size of the strike, which is what was asked for.
		# DSH_OPT: the planks are drawn as TWO MultiMeshes per leaf, one per oak tone, not
		# as forty-eight meshes. A plank still breaks on its own: the broken one is parked
		# out of the world, exactly like a knocked-out brick, and its collider is disabled.
		var leaf_columns := 6
		var leaf_rows := 8
		var board_w := leaf_width / float(leaf_columns)
		var board_h := (GATE_HEIGHT * 0.96) / float(leaf_rows)
		var board_box := BoxMesh.new()
		# IN CONTACT, with a hair of overlap: at 0.98 and 0.97 the planks showed light
		# through the joints, which read as cracks in the door.
		board_box.size = Vector3(board_w * 1.004, board_h * 1.004, 0.62)
		var tone_counts: Dictionary = {}
		for column: int in leaf_columns:
			var tone: String = "wood_alt" if column % 3 == 1 else "wood"
			tone_counts[tone] = int(tone_counts.get(tone, 0)) + 1
		var board_multis: Dictionary = {}
		for tone: String in tone_counts:
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = board_box
			multi.instance_count = int(tone_counts[tone]) * leaf_rows
			var boards_node := MultiMeshInstance3D.new()
			boards_node.name = "GateBoards_" + tone
			boards_node.multimesh = multi
			boards_node.material_override = _materials[tone]
			boards_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(boards_node)
			board_multis[tone] = boards_node
		var board_slots: Dictionary = {}
		var boards: Array = []
		for row: int in leaf_rows:
			for column: int in leaf_columns:
				var tone: String = "wood_alt" if column % 3 == 1 else "wood"
				var slot: int = int(board_slots.get(tone, 0))
				board_slots[tone] = slot + 1
				var board_at := Vector3(
					-side * (board_w * (float(column) + 0.5)),
					board_h * (float(row) + 0.5) + GATE_HEIGHT * 0.02,
					0.0)
				(board_multis[tone] as MultiMeshInstance3D).multimesh.set_instance_transform(
					slot, Transform3D(Basis.IDENTITY, board_at))
				boards.append({"at": board_at, "broken": false, "size": board_box.size,
					"multi": board_multis[tone], "slot": slot})
		# The seams between the boards: shallow dark strips on the face, not slots.
		var seam_material := StandardMaterial3D.new()
		seam_material.albedo_color = Color(0.24, 0.15, 0.08)
		seam_material.roughness = 0.95
		for i: int in range(1, 6):
			var seam := MeshInstance3D.new()
			var seam_mesh := BoxMesh.new()
			seam_mesh.size = Vector3(0.045, GATE_HEIGHT * 0.94, 0.05)
			seam.mesh = seam_mesh
			seam.material_override = seam_material
			seam.position = Vector3(-side * (board * float(i)), GATE_HEIGHT * 0.5, 0.335)
			pivot.add_child(seam)
		for band: int in 3:
			var strip := MeshInstance3D.new()
			var strip_mesh := BoxMesh.new()
			strip_mesh.size = Vector3(leaf_width * 0.98, 0.30, 0.14)
			strip.mesh = strip_mesh
			strip.material_override = _materials["iron"]
			strip.position = Vector3(-side * leaf_width * 0.5, GATE_HEIGHT * (0.18 + float(band) * 0.3), 0.39)
			pivot.add_child(strip)
			for stud: int in 5:
				var bolt := MeshInstance3D.new()
				var bolt_mesh := BoxMesh.new()
				bolt_mesh.size = Vector3(0.11, 0.11, 0.18)
				bolt.mesh = bolt_mesh
				bolt.material_override = _materials["iron"]
				bolt.position = Vector3(-side * leaf_width * (0.1 + float(stud) * 0.2),
					GATE_HEIGHT * (0.18 + float(band) * 0.3), 0.46)
				pivot.add_child(bolt)
		# A square forged frame has identical dimensions on both leaves. The old
		# diagonals were offset and made the ironwork appear crooked.
		for edge: float in [0.18, leaf_width - 0.18]:
			var stile := MeshInstance3D.new()
			var stile_box := BoxMesh.new()
			stile_box.size = Vector3(0.16, GATE_HEIGHT * 0.94, 0.16)
			stile.mesh = stile_box
			stile.material_override = _materials["iron"]
			stile.position = Vector3(-side * edge, GATE_HEIGHT * 0.5, 0.39)
			pivot.add_child(stile)
		for edge_y: float in [0.54, GATE_HEIGHT - 0.54]:
			var rail := MeshInstance3D.new()
			var rail_box := BoxMesh.new()
			rail_box.size = Vector3(leaf_width * 0.98, 0.16, 0.16)
			rail.mesh = rail_box
			rail.material_override = _materials["iron"]
			rail.position = Vector3(-side * leaf_width * 0.5, edge_y, 0.39)
			pivot.add_child(rail)
		for hinge_index: int in 3:
			var hinge := MeshInstance3D.new()
			var hinge_box := BoxMesh.new()
			hinge_box.size = Vector3(1.1, 0.34, 0.36)
			hinge.mesh = hinge_box
			hinge.material_override = _materials["iron"]
			hinge.position = Vector3(-side * 0.55,
				GATE_HEIGHT * (0.18 + float(hinge_index) * 0.3), 0.43)
			pivot.add_child(hinge)
		var plate := MeshInstance3D.new()
		var plate_box := BoxMesh.new()
		plate_box.size = Vector3(0.56, 0.82, 0.12)
		plate.mesh = plate_box
		plate.material_override = _materials["iron"]
		plate.position = Vector3(-side * (leaf_width - 0.55), 4.95, 0.47)
		pivot.add_child(plate)
		var pull := MeshInstance3D.new()
		var pull_mesh := TorusMesh.new()
		pull_mesh.inner_radius = 0.18
		pull_mesh.outer_radius = 0.26
		pull.mesh = pull_mesh
		pull.material_override = _materials["iron"]
		pull.position = plate.position + Vector3(0.0, -0.10, 0.16)
		pull.rotation.x = PI * 0.5
		pivot.add_child(pull)
		# The collision rides with the hinge, so an open gate is really open.
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 1
		body.position = Vector3.ZERO
		pivot.add_child(body)
		# One collider for each board: the hole made by a stone can be walked and shot
		# through while the sound boards continue to swing on the hinge.
		for board_entry: Dictionary in boards:
			var board_shape := CollisionShape3D.new()
			var board_shape_box := BoxShape3D.new()
			board_shape_box.size = board_entry["size"]
			board_shape.shape = board_shape_box
			board_shape.position = board_entry["at"]
			body.add_child(board_shape)
			board_entry["shape"] = board_shape
		body.set_meta("castle_gate", true)
		body.set_meta("surface", "wood")
		_build_inner_gate40(pivot, boards, board_w, board_h)
		_merge_pivot_decoration(pivot)
		_gate_leaves.append({"pivot": pivot, "side": side, "body": body, "detached": false,
			"boards": boards})
		if side < 0.0: _gate_left = pivot
		else: _gate_right = pivot
	# Wall-mounted lever at eye height, on the courtyard side of the gate.
	var lever_base := at + Vector3(GATE_WIDTH * 0.5 + 3.4, 1.55, -1.1)
	var lever_plate := MeshInstance3D.new()
	lever_plate.name = "LeverWallPlate"
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.50, 1.85, 0.15)
	lever_plate.mesh = plate_mesh
	lever_plate.material_override = _materials["iron"]
	lever_plate.position = lever_base + Vector3(0.0, 0.0, 0.17)
	add_child(lever_plate)
	_add_lever_plate_collision("LeverWallPlateBody", lever_plate.position, plate_mesh.size)
	for marker_y: float in [-0.64, 0.64]:
		var stop := MeshInstance3D.new()
		var stop_mesh := BoxMesh.new()
		stop_mesh.size = Vector3(0.24, 0.13, 0.22)
		stop.mesh = stop_mesh
		stop.material_override = _materials["cold"]
		stop.position = lever_base + Vector3(0.0, marker_y, -0.02)
		add_child(stop)
	_lever_pivot = Node3D.new()
	_lever_pivot.name = "LeverArm"
	_lever_pivot.position = lever_base
	add_child(_lever_pivot)
	var axle := MeshInstance3D.new()
	var axle_mesh := CylinderMesh.new()
	axle_mesh.top_radius = 0.16
	axle_mesh.bottom_radius = 0.16
	axle_mesh.height = 0.32
	axle.mesh = axle_mesh
	axle.rotation.x = PI * 0.5
	axle.position.z = -0.18
	axle.material_override = _materials["cold"]
	_lever_pivot.add_child(axle)
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.065
	handle_mesh.bottom_radius = 0.10
	handle_mesh.height = 0.68
	handle.mesh = handle_mesh
	handle.material_override = _materials["wood"]
	handle.position = Vector3(0.0, 0.34, -0.27)
	_lever_pivot.add_child(handle)
	var grip := MeshInstance3D.new()
	var grip_mesh := SphereMesh.new()
	grip_mesh.radius = 0.18
	grip_mesh.height = 0.36
	grip.mesh = grip_mesh
	grip.material_override = _materials["iron"]
	grip.position = Vector3(0.0, 0.68, -0.27)
	_lever_pivot.add_child(grip)
	_add_lever_handle_collision(_lever_pivot, "LeverHandleBody", -0.27, 0.68, 0.18)
	_lever_pivot.rotation.z = PI # handle points down while gates are closed
	_lever_pos = lever_base
	# A lamp over the lever: a mechanism nobody can find is a mechanism nobody uses.
	var lever_lamp := OmniLight3D.new()
	lever_lamp.light_color = Color(1.0, 0.78, 0.45)
	lever_lamp.light_energy = 2.2
	lever_lamp.omni_range = 6.0
	lever_lamp.position = lever_base + Vector3.UP * 2.1
	add_child(lever_lamp)
	_build_outer_gate_lever()

## The exterior control sits on a fixed pier, clear of both moving leaves.
## It uses the same gate state as the courtyard lever and needs no extra light.
func _build_outer_gate_lever() -> void:
	_outer_lever_pos = Vector3(GATE_WIDTH * 0.5 + 3.0, 1.55, WALL_HALF + 1.25)
	var plate := MeshInstance3D.new()
	plate.name = "OuterLeverWallPlate"
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.58, 1.85, 0.16)
	plate.mesh = plate_mesh
	plate.material_override = _materials["iron"]
	plate.position = _outer_lever_pos - Vector3(0.0, 0.0, 0.18)
	add_child(plate)
	_add_lever_plate_collision("OuterLeverWallPlateBody", plate.position, plate_mesh.size)
	for marker_y: float in [-0.64, 0.64]:
		var stop := MeshInstance3D.new()
		var stop_mesh := BoxMesh.new()
		stop_mesh.size = Vector3(0.28, 0.13, 0.22)
		stop.mesh = stop_mesh
		stop.material_override = _materials["cold"]
		stop.position = _outer_lever_pos + Vector3(0.0, marker_y, 0.06)
		add_child(stop)
	_outer_lever_pivot = Node3D.new()
	_outer_lever_pivot.name = "OuterLeverArm"
	_outer_lever_pivot.position = _outer_lever_pos
	add_child(_outer_lever_pivot)
	var axle := MeshInstance3D.new()
	var axle_mesh := CylinderMesh.new()
	axle_mesh.top_radius = 0.19
	axle_mesh.bottom_radius = 0.19
	axle_mesh.height = 0.36
	axle.mesh = axle_mesh
	axle.rotation.x = PI * 0.5
	axle.position.z = 0.18
	axle.material_override = _materials["cold"]
	_outer_lever_pivot.add_child(axle)
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.085
	handle_mesh.bottom_radius = 0.12
	handle_mesh.height = 0.85
	handle.mesh = handle_mesh
	handle.position = Vector3(0.0, 0.42, 0.31)
	handle.material_override = _materials["wood"]
	_outer_lever_pivot.add_child(handle)
	var grip := MeshInstance3D.new()
	var grip_mesh := SphereMesh.new()
	grip_mesh.radius = 0.21
	grip_mesh.height = 0.42
	grip.mesh = grip_mesh
	grip.position = Vector3(0.0, 0.86, 0.31)
	grip.material_override = _materials["iron"]
	_outer_lever_pivot.add_child(grip)
	_add_lever_handle_collision(_outer_lever_pivot, "OuterLeverHandleBody", 0.31, 0.86, 0.21)
	_outer_lever_pivot.rotation.z = PI

func _add_lever_plate_collision(label: String, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

func _add_lever_handle_collision(pivot: Node3D, label: String, z: float, length: float, radius: float) -> void:
	var body := AnimatableBody3D.new()
	body.name = label
	body.collision_layer = 1
	body.collision_mask = 1
	pivot.add_child(body)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = length + radius * 2.0
	shape.shape = capsule
	shape.position = Vector3(0.0, length * 0.5, z)
	body.add_child(shape)

## Two flights up to the wall-walk, for archers.
##
## The steps are DRAWN, and an invisible RAMP carries the player up underneath them. A
## stair built from boxes of collision is a stair a character gets stuck on - the first
## version used half-metre steps and a single rectangular block for the whole flight, and
## he could not get up it at all. A ramp cannot be stuck on, and the steps are what is seen.
var _gate_left: Node3D
var _gate_right: Node3D
var _lever_pivot: Node3D
var _lever_pos := Vector3.ZERO
var _outer_lever_pivot: Node3D
var _outer_lever_pos := Vector3.ZERO
var _gate_open_state := false
var _gate_angle := 0.0
var _lever_angle := PI

## Swings the two leaves inward, smoothly, and back. The angle is eased every physics step,
## so the gate never snaps: a gate this heavy takes a moment to move.
func set_gate(open: bool) -> void:
	_gate_open_state = open

func _gate_boards_broken() -> int:
	var count := 0
	for entry: Dictionary in _gate_leaves:
		for board: Dictionary in entry.get("boards", []):
			if bool(board.get("broken", false)): count += 1
	return count

func _gate_board_colliders_active() -> int:
	var count := 0
	for entry: Dictionary in _gate_leaves:
		for board: Dictionary in entry.get("boards", []):
			var shape: CollisionShape3D = board.get("shape")
			if is_instance_valid(shape) and not shape.disabled: count += 1
	return count

func _gate_leaves_detached() -> int:
	var count := 0
	for entry: Dictionary in _gate_leaves:
		if bool(entry.get("detached", false)): count += 1
	return count

func gate_open() -> bool:
	return _gate_open_state

func _leaf_debug() -> Dictionary:
	if _gate_leaves.is_empty(): return {}
	var pivot: Node3D = _gate_leaves[0].get("pivot")
	if not is_instance_valid(pivot): return {"pivot": "invalid"}
	var child: Node3D = pivot.get_child(0)
	return {"pivot": pivot.global_position,
		"child": child.global_position if is_instance_valid(child) else "none",
		"child_visible": child.is_visible_in_tree() if is_instance_valid(child) else false,
		"child_name": child.name if is_instance_valid(child) else "",
		"mats": _materials.size()}

func _count_gate_bricks() -> int:
	var count := 0
	for cell: Dictionary in _cells:
		if not bool(cell.get("alive", false)): continue
		var at: Vector3 = cell.get("at", Vector3.ZERO)
		if absf(at.x) < 4.4 and at.y > 1.0 and at.y < 10.0 and absf(at.z - WALL_HALF) < 1.6:
			count += 1
	return count

func gate_angle() -> float:
	return _gate_angle

func lever_position() -> Vector3:
	return to_global(_lever_pos)

func outer_lever_position() -> Vector3:
	return to_global(_outer_lever_pos)

## True when E would work the lever from where the player is standing.
func wants_e() -> bool:
	if not _ready or not is_instance_valid(_player): return false
	return _player.global_position.distance_to(lever_position()) <= 2.6 \
		or _player.global_position.distance_to(outer_lever_position()) <= 2.6

## E at the lever works the gate. The gate is the player's own business, so it answers the
## key itself rather than going through the weapons.
func _unhandled_input(event: InputEvent) -> void:
	if not _ready or not is_instance_valid(_player): return
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code != KEY_F: return
	if not bool(_player.get("_free_mouse_look")): return
	if is_instance_valid(armory_storage) and armory_storage.interact():
		get_viewport().set_input_as_handled()
		return
	if not wants_e(): return
	set_gate(not _gate_open_state)
	get_viewport().set_input_as_handled()

func _advance_gate(delta: float) -> void:
	if not is_instance_valid(_gate_left) or not is_instance_valid(_gate_right): return
	var target := 1.0 if _gate_open_state else 0.0
	_gate_angle = move_toward(_gate_angle, target, (1.0 / 1.6) * delta)
	var eased := smoothstep(0.0, 1.0, _gate_angle)
	_gate_left.rotation.y = eased * 1.85
	_gate_right.rotation.y = -eased * 1.85
	if is_instance_valid(_lever_pivot):
		_lever_angle = lerpf(PI, 0.0, eased)
		_lever_pivot.rotation.z = _lever_angle
	if is_instance_valid(_outer_lever_pivot):
		_outer_lever_pivot.rotation.z = _lever_angle

## Flights up to the wall-walk, one on every wall.
##
## The first version climbed AWAY from the wall: it reached nineteen metres at a point
## twenty-six metres out in the courtyard, with nothing to step onto. A stair to the
## battlements must LAND on them, so each flight now runs from deep in the courtyard up to
## the wall head, and the wall carries a walk along its whole length for the archers.
func _build_stairs() -> void:
	var flights := [
		{"normal": Vector3(0.0, 0.0, 1.0), "name": "south"},
		{"normal": Vector3(1.0, 0.0, 0.0), "name": "east"},
		{"normal": Vector3(0.0, 0.0, -1.0), "name": "north"},
		{"normal": Vector3(-1.0, 0.0, 0.0), "name": "west"},
	]
	for flight: Dictionary in flights:
		_build_stair_flight(flight["normal"], str(flight["name"]))

func _build_stair_flight(normal: Vector3, name: String) -> void:
	var rise := 0.26
	var run := 0.36
	var width := 2.8
	var steps := int(ceil(WALL_HEIGHT / rise))
	# End at the actual wall-walk height, not the next multiple of 26 cm.
	rise = WALL_HEIGHT / float(steps)
	var length := float(steps) * run
	var top_height := float(steps) * rise
	var inward: Vector3 = -normal
	var lateral: Vector3 = Vector3(inward.z, 0.0, -inward.x).normalized()
	var lateral_offset := WALL_HALF * 0.42
	# The wall head is where the flight ENDS; the foot runs back into the courtyard.
	var top_centre: Vector3 = -inward * (WALL_HALF - 2.2) + lateral * lateral_offset
	var bottom_centre: Vector3 = top_centre + inward * length
	# THE FLIGHT IS A THIN DECK ON PILLARS. A solid wedge from the ground up is a wall you
	# cannot pass, and a man should be able to walk under a staircase - that is where a
	# castle puts its stores. The deck carries the climb, the pillars stand every couple of
	# metres, and between them there is a way through.
	var slope: Vector3 = -inward
	var deck_thickness := 0.45
	var deck_point_a: Vector3 = bottom_centre - Vector3.UP * (deck_thickness * 0.5)
	var deck_point_b: Vector3 = top_centre + Vector3.UP * (top_height - deck_thickness * 0.5)
	var deck_mid: Vector3 = (deck_point_a + deck_point_b) * 0.5
	var deck_length: float = (deck_point_b - deck_point_a).length()
	var deck_axis: Vector3 = (deck_point_b - deck_point_a).normalized()
	var deck_up: Vector3 = lateral.cross(deck_axis).normalized()
	var deck_basis := Basis(lateral, deck_up, -deck_axis)
	var deck := StaticBody3D.new()
	deck.collision_layer = 1
	deck.collision_mask = 1
	deck.set_meta("surface", "stone")
	deck.transform = Transform3D(deck_basis, deck_mid)
	add_child(deck)
	# Keep one physics body per flight, but split its sloped shape by visible step.
	# Each section overlaps its neighbour slightly so the intact climb stays smooth.
	var segment_length := deck_length / float(steps)
	for step: int in steps:
		var deck_shape := CollisionShape3D.new()
		var deck_box := BoxShape3D.new()
		deck_box.size = Vector3(width, deck_thickness, segment_length + 0.012)
		deck_shape.shape = deck_box
		deck_shape.position.z = deck_length * (0.5 - (float(step) + 0.5) / float(steps))
		deck.add_child(deck_shape)
		_stair_step_collision["stairs_%s:%d" % [name, step]] = deck_shape
	# Piers meet the actual underside of a specific tread. All masonry and its
	# collision share the same dimensions and destruction binding.
	var tread_depth := 0.65
	var stations: int = maxi(2, int(length / 2.6))
	for station: int in stations:
		var step_index := clampi(int(round((float(station) + 0.5) * float(steps) / float(stations))), 2, steps - 2)
		var along := float(step_index) * run
		var underside := rise * float(step_index) - tread_depth
		for flank: int in 2:
			var side := -1.0 if flank == 0 else 1.0
			var foot := bottom_centre + slope * along + lateral * (side * (width * 0.5 - 0.32))
			var row := station * 2 + flank
			_add_stair_masonry(foot + Vector3.UP * (underside * 0.5),
				Vector3(0.64, underside, 0.64), "cold", "stairs_pier_" + name, row)
			_add_stair_masonry(foot + Vector3.UP * 0.13,
				Vector3(0.90, 0.26, 0.90), "stone", "stairs_base_" + name, row)
			# The cap is no deeper than its tread, so it cannot protrude through
			# the next lower tread or leave a gap beneath the flight.
			var cap_size := Vector3(0.88, 0.24, run) if absf(slope.x) < 0.5 else Vector3(run, 0.24, 0.88)
			_add_stair_masonry(foot + Vector3.UP * (underside - 0.12),
				cap_size, "warm", "stairs_cap_" + name, row)
	# The tread top at each station follows the ramp, instead of being one full
	# riser above it. The first tread merges into the courtyard; the last riser
	# meets the wall-walk. No raised ramp ends can block either direction.
	# The steps, drawn but not colliding: the deck carries the man. They must climb the
	# SAME WAY as the wedge - towards the wall - or the stone you see and the stone you walk
	# on are two different staircases, and the end of the wedge shows as a flat grey face at
	# the foot of the steps.
	for i: int in steps:
		var at: Vector3 = bottom_centre - inward * (float(i) * run) + Vector3.UP * (rise * float(i) - rise * 0.5)
		var across_x: bool = absf(slope.x) < 0.5
		var step_size := Vector3(width, tread_depth, run * 1.04) if across_x \
			else Vector3(run * 1.04, tread_depth, width)
		_add_brick(at - Vector3.UP * ((tread_depth - rise) * 0.5), step_size, "cold", Vector3.ZERO, "stairs_" + name, i, 0)
		_add_stair_masonry(at + lateral * (width * 0.5 + 0.16) + Vector3.UP * 0.55,
			Vector3(0.32, 1.0, run * 1.04) if across_x \
			else Vector3(run * 1.04, 1.0, 0.32), "stone", "stairs_rail_" + name, i)
	# The final step overlaps a broad landing and the wall walk. It does not end
	# at a narrow seam in front of the inner parapet.
	var landing_at := top_centre + normal * 1.7 + Vector3.UP * (WALL_HEIGHT - 0.12)
	# Do not project the horizontal landing into the rising capsule's path.
	# The wall-walk already reaches the last tread; overlap it from the top.
	var landing_size := Vector3(width + 0.6, 0.24, 3.0) if absf(normal.z) > 0.5 \
		else Vector3(3.0, 0.24, width + 0.6)
	_add_brick(landing_at, landing_size, "warm", Vector3.ZERO, "stair_landing_" + name)
	_add_breakable_collision(landing_at, landing_size)

## Bind every rail/pier collision to its visible stone, including cascade removal.
## Reverse face: three oak braces, narrow vertical joints and forged straps.
## Every instance follows its own breakable board; no floating brace spans a hole.
func _build_inner_gate40(pivot: Node3D, boards: Array, board_w: float, board_h: float) -> void:
	var pieces: Dictionary = {"wood_alt": [], "iron": []}
	for index: int in boards.size():
		var board: Dictionary = boards[index]
		var at: Vector3 = board.at
		var row := index / 6
		var column := index % 6
		# Continuous vertical seams only: no crosshatched row grid.
		if column > 0:
			pieces.iron.append({"owner": index, "at": at + Vector3(board_w * 0.48, 0, -0.323),
				"size": Vector3(0.024, board_h * 1.002, 0.018)})
		if row in [1, 4, 6]:
			pieces.wood_alt.append({"owner": index, "at": at + Vector3(0, 0, -0.40),
				"size": Vector3(board_w * 1.004, 0.34, 0.18)})
			if column in [0, 1, 4, 5]:
				pieces.iron.append({"owner": index, "at": at + Vector3(0, 0, -0.51),
					"size": Vector3(board_w * 1.004, 0.16, 0.06)})
			for dx: float in [-0.25, 0.25]:
				pieces.iron.append({"owner": index, "at": at + Vector3(board_w * dx, 0, -0.56),
					"size": Vector3(0.075, 0.075, 0.07)})
	for material: String in pieces:
		var rows: Array = pieces[material]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		multi.mesh = box
		multi.instance_count = rows.size()
		var node := MultiMeshInstance3D.new()
		node.name = "InnerGate40_" + material
		node.multimesh = multi
		node.material_override = _materials[material]
		pivot.add_child(node)
		for slot: int in rows.size():
			var row: Dictionary = rows[slot]
			multi.set_instance_transform(slot, Transform3D(Basis.IDENTITY.scaled(row.size), row.at))
			var board: Dictionary = boards[int(row.owner)]
			if not board.has("inner40"): board.inner40 = []
			board.inner40.append({"multi": node, "slot": slot})

func _add_stair_masonry(at: Vector3, size: Vector3, material: String, group: String, row: int) -> void:
	_add_brick(at, size, material, Vector3.ZERO, group, row, 0)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = at
	body.set_meta("surface", "stone")
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_stair_step_collision["%s:%d" % [group, row]] = shape

func _build_keep() -> void:
	var base := Vector3(0.0, 0.0, -8.0)
	var courses := int(KEEP_SIZE.y / BRICK.y)
	var per_course := int(KEEP_SIZE.x / BRICK.x)
	# The keep is LAID IN BRICKS on all four faces - a solid box underneath it would hide
	# every one of them behind a flat slab, which is exactly how it looked: a featureless
	# monolith with no windows at all.
	for row: int in courses:
		for column: int in per_course:
			var along := (float(column) - float(per_course - 1) * 0.5) * BRICK.x
			for side: float in [-1.0, 1.0]:
				# The south face has a real entrance into the keep.
				if not (side > 0.0 and absf(along) < 2.35 and row * BRICK.y < 4.35):
					_add_brick(base + Vector3(along, (float(row) + 0.5) * BRICK.y,
						side * KEEP_SIZE.z * 0.5),
						Vector3(BRICK.x, BRICK.y, WALL_THICK * 1.3), "stone", Vector3.ZERO, "keep", row, column)
				_add_brick(base + Vector3(side * KEEP_SIZE.x * 0.5,
					(float(row) + 0.5) * BRICK.y, along),
					Vector3(WALL_THICK * 1.3, BRICK.y, BRICK.x), "warm", Vector3.ZERO, "keep", row, column)
	# Hollow shell: no hidden solid block behind the entrance or future breaches.
	for face: float in [-1.0, 1.0]:
		_add_wall_collision(base + Vector3(face * KEEP_SIZE.x * 0.5, KEEP_SIZE.y * 0.5, 0.0),
			Vector3(WALL_THICK * 1.3, KEEP_SIZE.y, KEEP_SIZE.z))
	_add_wall_collision(base + Vector3(0.0, KEEP_SIZE.y * 0.5, -KEEP_SIZE.z * 0.5),
		Vector3(KEEP_SIZE.x, KEEP_SIZE.y, WALL_THICK * 1.3))
	for side: float in [-1.0, 1.0]:
		_add_wall_collision(base + Vector3(side * 7.65, KEEP_SIZE.y * 0.5, KEEP_SIZE.z * 0.5),
			Vector3(10.7, KEEP_SIZE.y, WALL_THICK * 1.3))
	_add_wall_collision(base + Vector3(0.0, (KEEP_SIZE.y + 4.35) * 0.5, KEEP_SIZE.z * 0.5),
		Vector3(4.6, KEEP_SIZE.y - 4.35, WALL_THICK * 1.3))

func _build_keep_rooms() -> void:
	var base := Vector3(0.0, 0.0, -8.0)
	# Ground tiles and roof courses use the same destructible MultiMesh as the walls.
	for x: int in 13:
		for z: int in 13:
			var offset := Vector3(-12.0 + float(x) * 2.0, 0.0, -12.0 + float(z) * 2.0)
			var floor_at := base + offset + Vector3.UP * 0.12
			var floor_size := Vector3(1.995, 0.24, 1.995)
			_add_brick(floor_at, floor_size,
				"warm" if (x + z) % 3 == 0 else "stone", Vector3.ZERO, "keep_floor", x, z)
			_add_breakable_collision(floor_at, Vector3(1.995, 0.32, 1.995))
			(_wall_collision.back()["body"] as StaticBody3D).set_meta("castle_keep_floor", true)
			_add_brick(base + offset + Vector3.UP * (KEEP_SIZE.y + 0.12), Vector3(2.01, 0.24, 2.01),
				"cold", Vector3.ZERO, "keep_roof", x, z)
	# Stagger the end joints from one plank to the next. Cut half boards finish
	# alternate rows at the walls, and all planks use the existing wood batch.
	for column: int in 26:
		var board_x := -12.5 + float(column)
		if column % 2 == 0:
			for segment: int in 13:
				_add_brick(base + Vector3(board_x, 0.25, -12.0 + float(segment) * 2.0),
					Vector3(0.975, 0.055, 1.965), "floor_wood", Vector3.ZERO,
					"keep_floor_board", column, segment)
		else:
			for segment: int in 14:
				var half_board: bool = segment == 0 or segment == 13
				var board_z := -12.5 if segment == 0 else 12.5 if segment == 13 \
					else -11.0 + float(segment - 1) * 2.0
				_add_brick(base + Vector3(board_x, 0.25, board_z),
					Vector3(0.975, 0.055, 0.965 if half_board else 1.965),
					"floor_wood", Vector3.ZERO, "keep_floor_board", column, segment)
	# Four ground-floor rooms open onto a broad central passage. Each opening is
	# wider than the player capsule; partitions are struck and removed in sections.
	for side: float in [-1.0, 1.0]:
		for z_index: int in 10:
			var along := -11.0 + float(z_index) * 2.35
			if absf(along - 5.95) < 1.3 or absf(along + 5.95) < 1.3: continue
			var partition_at := base + Vector3(side * 3.4, 2.45, along)
			for row: int in 9:
				_add_brick(partition_at + Vector3(0.0, -2.16 + float(row) * BRICK.y, 0.0),
					Vector3(0.38, BRICK.y, 2.34), "warm", Vector3.ZERO, "keep_partition", row, z_index)
			_add_breakable_collision(partition_at, Vector3(0.38, 4.9, 2.34))
		for x_index: int in 4:
			var x_pos := 4.7 + float(x_index) * 2.3
			var cross_at := base + Vector3(side * x_pos, 2.45, 0.0)
			for row: int in 9:
				_add_brick(cross_at + Vector3(0.0, -2.16 + float(row) * BRICK.y, 0.0),
					Vector3(2.29, BRICK.y, 0.38), "stone", Vector3.ZERO, "keep_partition", row, x_index)
			_add_breakable_collision(cross_at, Vector3(2.29, 4.9, 0.38))
	# Stone framing leaves a level, unobstructed passage into the keep.
	for side: float in [-1.0, 1.0]:
		for row: int in 9:
			_add_brick(base + Vector3(side * 2.5, (float(row) + 0.5) * BRICK.y, 13.18),
				Vector3(0.65, BRICK.y, 0.9), "cold", Vector3.ZERO, "keep_door_jamb", row, 0)
	_add_brick(base + Vector3(0.0, 4.55, 13.18), Vector3(5.6, 0.5, 0.9),
		"cold", Vector3.ZERO, "keep_door_head")
	# A red runner guides the eye from the entrance through the central passage.
	# Small independent sections keep a local explosion from deleting the whole rug.
	for section: int in 12:
		var z_at := -10.9 + float(section) * 2.0
		var runner := base + Vector3(0.0, 0.295, z_at)
		_add_brick(runner, Vector3(2.15, 0.025, 1.98), "velvet",
			Vector3.ZERO, "keep_runner", section, 0)
		for side: float in [-1.0, 1.0]:
			_add_brick(runner + Vector3(side * 1.1, 0.008, 0.0),
				Vector3(0.075, 0.014, 1.98), "gold", Vector3.ZERO,
				"keep_runner_edge", section, int(side))
		# Small woven diamonds mark each runner panel without a separate material.
		for mark: float in [-0.58, 0.58]:
			_add_brick(runner + Vector3(0.0, 0.016, mark),
				Vector3(0.18, 0.012, 0.18), "gold", Vector3(0, PI * 0.25, 0),
				"keep_runner_pattern", section, int(mark * 10.0))
	for light_z: float in [-7.0, 6.0]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.72, 0.42)
		lamp.light_energy = 1.1
		lamp.omni_range = 9.0
		lamp.shadow_enabled = false
		lamp.position = base + Vector3(0.0, 3.7, light_z)
		add_child(lamp)

## Interior pieces share the masonry MultiMesh and the capped, pooled debris physics.
## Broad surfaces alone need standing collision; trim stays visually breakable.
func _furnish(at: Vector3, size: Vector3, material_key: String, group: String,
		solid: bool = false, shape_key: String = "box") -> void:
	_add_brick(at, size, material_key, Vector3.ZERO, group, 0, 0, shape_key)
	if not _furniture_cells.has(group): _furniture_cells[group] = []
	(_furniture_cells[group] as Array).append(_cells.size() - 1)
	if solid:
		_add_breakable_collision(at, size)
		if material_key in ["stone", "warm", "cold", "iron"]: return
		var section: Dictionary = _wall_collision.back()
		var body: StaticBody3D = section["body"]
		body.set_meta("castle_furnishing", true)
		body.set_meta("castle_furnishing_group", group)
		body.set_meta("castle_furnishing_material", material_key)
		body.set_meta("castle_melee_hp", 2.0 if material_key.begins_with("wood") else 1.0)
		section["group"] = group

func _build_keep_interior() -> void:
	var base := Vector3(0.0, 0.0, -8.0)
	# One unshadowed warm light per room: enough to read colour through thick partitions.
	# No dynamic shadows, reflection probes, or per-object lights.
	for centre: Vector2 in [Vector2(-8.0, -6.3), Vector2(8.0, -6.3),
			Vector2(-8.0, 6.3), Vector2(8.0, 6.3)]:
		# The keep is tall outside, but the ground-floor chambers need a ceiling.
		# Four solid vault panels per chamber retain local destruction and support.
		for panel: int in 4:
			var ceiling_z := centre.y - 3.75 + float(panel) * 2.5
			_furnish(base + Vector3(centre.x, 5.12, ceiling_z),
				Vector3(8.7, 0.22, 2.48), "cold", "room_vault", true)
		for beam_z: float in [-3.75, -1.25, 1.25, 3.75]:
			_furnish(base + Vector3(centre.x, 4.92, centre.y + beam_z),
				Vector3(8.8, 0.28, 0.26), "wood_alt", "room_ceiling_beam")
		for side_z: float in [-2.9, 2.9]:
			var wall_x: float = centre.x + (-3.85 if centre.x < 0.0 else 3.85)
			_furnish(base + Vector3(wall_x, 2.5, centre.y + side_z),
				Vector3(0.44, 4.8, 0.48), "warm", "room_wall_pier")
			_furnish(base + Vector3(wall_x, 4.76, centre.y + side_z),
				Vector3(0.72, 0.32, 0.76), "cold", "room_pier_cap")
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.70, 0.39)
		light.light_energy = 1.55
		light.omni_range = 7.5
		light.shadow_enabled = false
		light.position = base + Vector3(centre.x, 3.7, centre.y)
		add_child(light)
		var sconce := base + Vector3(centre.x, 3.5, centre.y)
		_furnish(sconce, Vector3(0.45, 0.13, 0.45), "gold", "room_lantern")
		_furnish(sconce + Vector3.UP * 0.18, Vector3(0.24, 0.25, 0.24), "linen", "room_lantern")
		var rug := base + Vector3(centre.x, 0.295, centre.y)
		_furnish(rug, Vector3(5.10, 0.025, 6.25), "velvet", "room_rug")
		# A narrow woven border leaves the oak planks visible around each chamber.
		for side: float in [-1.0, 1.0]:
			_furnish(rug + Vector3(side * 2.45, 0.018, 0),
				Vector3(0.060, 0.012, 6.0), "gold", "room_rug_border")
			_furnish(rug + Vector3(0, 0.018, side * 3.00),
				Vector3(4.96, 0.012, 0.060), "gold", "room_rug_border")
			_furnish(rug + Vector3(side * 2.18, 0.016, 0),
				Vector3(0.035, 0.010, 5.45), "linen", "room_rug_border")
			_furnish(rug + Vector3(0, 0.016, side * 2.72),
				Vector3(4.39, 0.010, 0.035), "linen", "room_rug_border")
		var face: float = -1.0 if centre.x < 0.0 else 1.0
		# Hang the cloth in front of the inner stone face; at x=12.58 it was
		# buried inside the thick wall and the room looked empty from the door.
		var banner := base + Vector3(face * 11.78, 2.8, centre.y)
		_furnish(banner, Vector3(0.08, 2.8, 2.0), "velvet", "room_banner")
		_furnish(banner + Vector3(-face * 0.06, 0.45, 0.0),
			Vector3(0.09, 0.48, 0.85), "gold", "room_banner_device")
		_furnish(banner + Vector3(-face * 0.06, -0.8, 0.0),
			Vector3(0.09, 0.07, 2.0), "gold", "room_banner_trim")
	# West/north: feasting table, benches, high-backed seat, wall chests.
	var hall := base + Vector3(-8.1, 0.0, -6.3)
	_furnish(hall + Vector3(0, 1.05, 0), Vector3(2.5, 0.18, 4.0), "wood", "hall_table", true)
	for x_offset: float in [-0.78, 0.0, 0.78]:
		_furnish(hall + Vector3(x_offset, 1.155, 0.0), Vector3(0.72, 0.035, 3.92),
			"wood_alt", "hall_table_slats")
	for side: float in [-1.0, 1.0]:
		_furnish(hall + Vector3(side * 1.19, 0.98, 0.0), Vector3(0.09, 0.16, 3.8),
			"wood_alt", "hall_table_edge")
	_furnish(hall + Vector3(0, 0.48, 0), Vector3(1.85, 0.12, 0.14),
		"wood_alt", "hall_table_brace")
	_furnish(hall + Vector3(0, 0.31, 0), Vector3(0.18, 0.15, 3.05),
		"wood_alt", "hall_table_brace")
	for side: float in [-1.0, 1.0]:
		_furnish(hall + Vector3(side * 1.08, 0.88, 0),
			Vector3(0.12, 0.22, 3.56), "wood_alt", "hall_table_brace")
	for sx: float in [-1.0, 1.0]:
		_furnish(hall + Vector3(sx * 0.95, 0.52, -1.35), Vector3(0.24, 1.04, 0.24),
			"wood_alt", "hall_table_leg", false, "turned")
		_furnish(hall + Vector3(sx * 0.95, 0.52, 1.35), Vector3(0.24, 1.04, 0.24),
			"wood_alt", "hall_table_leg", false, "turned")
		_furnish(hall + Vector3(sx * 2.05, 0.55, 0), Vector3(0.55, 0.16, 3.8), "wood", "hall_bench", true)
		_furnish(hall + Vector3(sx * 2.05, 0.27, -1.3), Vector3(0.2, 0.54, 0.2),
			"wood_alt", "hall_bench_leg", false, "turned")
		_furnish(hall + Vector3(sx * 2.05, 0.27, 1.3), Vector3(0.2, 0.54, 0.2),
			"wood_alt", "hall_bench_leg", false, "turned")
		_furnish(hall + Vector3(sx * 2.05, 0.25, 0), Vector3(0.10, 0.10, 2.65),
			"wood_alt", "hall_bench_leg")
	_furnish(hall + Vector3(0, 0.58, -3.2), Vector3(1.3, 0.16, 1.02),
		"wood_alt", "hall_chair", true)
	_furnish(hall + Vector3(0, 0.69, -3.2), Vector3(1.1, 0.11, 0.82),
		"velvet", "hall_chair_cushion", false, "soft")
	for sx: float in [-1.0, 1.0]:
		for dz: float in [-0.38, 0.38]:
			_furnish(hall + Vector3(sx * 0.5, 0.26, -3.2 + dz), Vector3(0.18, 0.52, 0.18),
				"wood_alt", "hall_chair_leg", false, "turned")
		_furnish(hall + Vector3(sx * 0.52, 1.08, -3.65), Vector3(0.16, 1.25, 0.16),
			"wood_alt", "hall_chair_back", false, "turned")
	_furnish(hall + Vector3(0, 1.55, -3.65), Vector3(1.28, 0.22, 0.18),
		"wood", "hall_chair_back")
	for dz: float in [-3.8, 3.8]:
		_furnish(hall + Vector3(-3.0, 0.55, dz), Vector3(1.4, 1.1, 0.8), "wood_alt", "hall_chest", true)
		_furnish(hall + Vector3(-3.0, 1.13, dz), Vector3(1.45, 0.2, 0.84),
			"wood", "hall_chest_lid", false, "soft")
		_furnish(hall + Vector3(-2.25, 0.7, dz), Vector3(0.08, 0.44, 0.2),
			"iron", "hall_chest_band")
	for dz: float in [-1.2, 0.0, 1.2]:
		_furnish(hall + Vector3(0, 1.21, dz), Vector3(0.72, 0.04, 0.72),
			"gold", "hall_plate", false, "disk")
		_furnish(hall + Vector3(0.55, 1.38, dz), Vector3(0.18, 0.3, 0.18),
			"gold", "hall_goblet", false, "cup")

	# East/north: racks, shield silhouettes, and a compact work bench.
	var armoury := base + Vector3(8.0, 0.0, -6.2)
	for dz: float in [-3.3, 0.0, 3.3]:
		_furnish(armoury + Vector3(2.65, 1.3, dz), Vector3(0.22, 2.6, 2.1), "wood_alt", "armour_rack", true)
		for side: float in [-1.0, 1.0]:
			_furnish(armoury + Vector3(2.46, 1.3, dz + side * 0.95),
				Vector3(0.2, 2.6, 0.2), "wood", "armour_rack_post", false, "turned")
		for height: float in [0.55, 1.35, 2.15]:
			_furnish(armoury + Vector3(2.42, height, dz), Vector3(0.18, 0.16, 1.94),
				"wood", "armour_rack_rail")
		_furnish(armoury + Vector3(2.39, 2.38, dz), Vector3(0.12, 0.28, 0.5),
			"gold", "armour_crest")
	# A paired iron cradle carries each real weapon at its lower end and keeps
	# the shaft against the upper rail. The display mesh no longer hangs in air.
	for slot_z: float in [-3.85, -2.95, -0.45, 0.45, 2.95, 3.85]:
		_furnish(armoury + Vector3(2.52, 1.37, slot_z),
			Vector3(0.035, 1.72, 0.66), "linen", "armour_backer")
		for height: float in [0.66, 1.45]:
			_furnish(armoury + Vector3(2.23, height, slot_z),
				Vector3(0.42, 0.08, 0.17), "iron", "armour_hook")
			_furnish(armoury + Vector3(2.03, height + 0.085, slot_z),
				Vector3(0.08, 0.17, 0.17), "iron", "armour_hook")
	# A separate shield mount on the wall uses the same unique take/drop path.
	_furnish(armoury + Vector3(2.62, 1.58, 5.2), Vector3(0.18, 1.45, 1.05),
		"wood", "armour_shield_mount", true)
	for side: float in [-1.0, 1.0]:
		_furnish(armoury + Vector3(2.48, 1.58, 5.2 + side * 0.43),
			Vector3(0.08, 1.38, 0.07), "iron", "armour_shield_trim")
	_furnish(armoury + Vector3(2.37, 1.39, 5.2), Vector3(0.32, 0.10, 0.24),
		"iron", "armour_shield_hook")
	_furnish(armoury + Vector3(-1.2, 0.83, 0), Vector3(1.7, 0.18, 2.6), "wood", "armour_bench", true)
	for x_offset: float in [-0.5, 0.5]:
		_furnish(armoury + Vector3(-1.2 + x_offset, 0.94, 0), Vector3(0.68, 0.035, 2.5),
			"wood_alt", "armour_bench_slats")
	for dz: float in [-0.9, 0.9]:
		_furnish(armoury + Vector3(-1.7, 0.41, dz), Vector3(0.22, 0.82, 0.22),
			"wood_alt", "armour_leg", false, "turned")
	# Separate floor chest, away from the display racks. Its lid and iron fittings
	# share the furniture destruction path; only this carcass owns storage access.
	var chest_at := armoury + Vector3(-2.6, 0.0, -3.4)
	_furnish(chest_at + Vector3(0, 0.61, 0), Vector3(1.78, 0.92, 1.16),
		"wood_alt", "armour_chest", true)
	for side: float in [-1.0, 1.0]:
		_furnish(chest_at + Vector3(side * 0.75, 0.61, 0.60),
			Vector3(0.10, 0.86, 0.08), "wood", "armour_chest_frame")
		_furnish(chest_at + Vector3(side * 0.72, 0.18, 0),
			Vector3(0.16, 0.28, 0.16), "iron", "armour_chest_foot", false, "turned")
	for side: float in [-1.0, 1.0]:
		_furnish(chest_at + Vector3(side * 0.51, 0.66, 0.60),
			Vector3(0.62, 0.56, 0.07), "wood", "armour_chest_panel")
		_furnish(chest_at + Vector3(side * 0.47, 0.66, 0.65),
			Vector3(0.04, 0.42, 0.03), "gold", "armour_chest_inlay")
	for plank: int in 4:
		_furnish(chest_at + Vector3(-0.66 + plank * 0.44, 1.12, 0),
			Vector3(0.43, 0.15, 1.28), "wood", "armour_chest_lid")
	for band_x: float in [-0.64, 0.64]:
		_furnish(chest_at + Vector3(band_x, 1.22, 0),
			Vector3(0.08, 0.04, 1.34), "iron", "armour_chest_band")
	_furnish(chest_at + Vector3(0, 0.69, 0.67), Vector3(0.24, 0.32, 0.08),
		"iron", "armour_chest_lock")

	# West/south: three tall shelves with individually breakable ledgers.
	var archive := base + Vector3(-8.0, 0.0, 6.4)
	for dz: float in [-3.3, 0.0, 3.3]:
		_furnish(archive + Vector3(-2.9, 1.6, dz), Vector3(0.38, 3.2, 2.5),
			"wood_alt", "archive_shelf", true)
		for side: float in [-1.0, 1.0]:
			_furnish(archive + Vector3(-2.42, 1.6, dz + side * 1.15),
				Vector3(0.22, 3.2, 0.22), "wood", "archive_shelf_post", false, "turned")
		_furnish(archive + Vector3(-2.55, 3.17, dz), Vector3(0.85, 0.2, 2.65),
			"wood", "archive_shelf_crown")
		for level: int in 3:
			for volume: int in 4:
				_furnish(archive + Vector3(-2.27, 0.55 + level * 0.92, dz - 0.76 + volume * 0.5),
					Vector3(0.16, 0.67, 0.44), "velvet" if volume % 2 == 0 else "linen", "archive_books")
			_furnish(archive + Vector3(-2.2, 0.2 + level * 0.92, dz), Vector3(0.72, 0.1, 2.5), "wood", "archive_shelf_trim")
	_furnish(archive + Vector3(0.4, 0.75, 0), Vector3(1.5, 0.16, 2.2), "wood", "archive_desk", true)
	for x_offset: float in [-0.43, 0.43]:
		_furnish(archive + Vector3(0.4 + x_offset, 0.85, 0), Vector3(0.62, 0.025, 2.12),
			"wood_alt", "archive_desk_slats")
		for dz: float in [-0.8, 0.8]:
			_furnish(archive + Vector3(0.4 + x_offset, 0.37, dz), Vector3(0.18, 0.74, 0.18),
				"wood_alt", "archive_desk_leg", false, "turned")
	_furnish(archive + Vector3(0.4, 0.84, 0), Vector3(1.1, 0.04, 1.65), "linen", "archive_map")

	# East/south: bed, canopy, wardrobes, and paired chests.
	var chamber := base + Vector3(8.0, 0.0, 6.3)
	_furnish(chamber + Vector3(0, 0.47, 0), Vector3(2.5, 0.75, 3.3), "wood_alt", "chamber_bed", true)
	for side: float in [-1.0, 1.0]:
		_furnish(chamber + Vector3(side * 1.18, 0.52, 0.0), Vector3(0.18, 0.58, 3.2),
			"wood", "chamber_bed_rail")
	_furnish(chamber + Vector3(0, 0.91, 0), Vector3(2.25, 0.22, 2.95),
		"linen", "chamber_mattress", false, "soft")
	_furnish(chamber + Vector3(0, 1.03, 0.82), Vector3(2.16, 0.045, 1.16),
		"velvet", "chamber_cover")
	for side: float in [-1.0, 1.0]:
		_furnish(chamber + Vector3(side * 0.52, 1.1, -1.0), Vector3(0.82, 0.17, 0.52),
			"linen", "chamber_pillow", false, "soft")
	_furnish(chamber + Vector3(0, 1.68, -1.73), Vector3(2.7, 0.24, 0.22),
		"wood", "chamber_headboard", true)
	_furnish(chamber + Vector3(0, 0.77, 1.66), Vector3(2.54, 0.76, 0.18),
		"wood_alt", "chamber_footboard")
	_furnish(chamber + Vector3(0, 1.12, 1.75), Vector3(2.2, 0.09, 0.08),
		"gold", "chamber_footboard_trim")
	for x_offset: float in [-1.08, -0.36, 0.36, 1.08]:
		_furnish(chamber + Vector3(x_offset, 1.05, -1.73), Vector3(0.2, 1.15, 0.2),
			"wood_alt", "chamber_headboard", true, "turned")
	_furnish(chamber + Vector3(0, 1.84, -1.57), Vector3(0.48, 0.4, 0.14),
		"gold", "chamber_headboard_crest", false, "soft")
	for side: float in [-1.0, 1.0]:
		_furnish(chamber + Vector3(side * 1.18, 1.75, -1.7), Vector3(0.18, 0.45, 0.18),
			"gold", "chamber_headboard_finial", false, "turned")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_furnish(chamber + Vector3(sx * 1.25, 2.08, sz * 1.50),
				Vector3(0.17, 4.16, 0.17), "wood", "chamber_post", false, "turned")
			_furnish(chamber + Vector3(sx * 1.25, 4.25, sz * 1.50),
				Vector3(0.25, 0.26, 0.25), "gold", "chamber_post_finial", false, "soft")
	for stripe: int in 4:
		_furnish(chamber + Vector3(-0.81 + float(stripe) * 0.54, 1.065, 0.83),
			Vector3(0.22, 0.020, 1.10), "gold" if stripe % 2 == 0 else "linen",
			"chamber_cover_trim")
	_furnish(chamber + Vector3(0, 4.2, 0), Vector3(2.65, 0.12, 3.3), "linen", "chamber_canopy")
	_furnish(chamber + Vector3(0, 4.13, 0), Vector3(2.5, 0.03, 3.12), "velvet", "chamber_canopy_lining")
	for side: float in [-1.0, 1.0]:
		_furnish(chamber + Vector3(side * 1.28, 3.9, 0.0), Vector3(0.08, 0.34, 3.25),
			"velvet", "chamber_canopy_valance")
	for sx: float in [-1.0, 1.0]:
		for fold: int in 2:
			_furnish(chamber + Vector3(sx * (1.08 + float(fold) * 0.13), 3.2, -1.42),
				Vector3(0.08, 1.6, 0.28), "velvet", "chamber_drape")
	for dz: float in [-3.3, 3.3]:
		_furnish(chamber + Vector3(2.9, 1.2, dz), Vector3(0.8, 2.4, 1.55), "wood_alt", "chamber_wardrobe", true)
		_furnish(chamber + Vector3(2.48, 2.42, dz), Vector3(0.92, 0.22, 1.7),
			"wood", "chamber_wardrobe_crown")
		for side: float in [-1.0, 1.0]:
			_furnish(chamber + Vector3(2.45, 1.2, dz + side * 0.39),
				Vector3(0.08, 1.95, 0.67), "wood", "chamber_wardrobe_panel")
			_furnish(chamber + Vector3(2.37, 1.2, dz + side * 0.12),
				Vector3(0.09, 0.17, 0.09), "gold", "chamber_handle", false, "cup")

## ------------------------------------------------------------------ colour and banners
## Banners hanging on the walls, in the colour of the house, with a gold device: a
const WALK_WIDTH := 3.0
const WALK_PARAPET := 0.9

## THE WALL-WALK: a continuous platform round all four walls at the wall head, wide enough
## for two men to pass, with a waist-high parapet on the courtyard side. Without it the
## battlements are decoration nobody can stand on.
func _build_wall_walks() -> void:
	# Short spans are visible through the masonry MultiMesh and have matching
	# breakable support. A hit at parapet height can destroy one span without
	# leaving an invisible 136-metre slab across the courtyard.
	var spans := 28
	var length := WALL_HALF * 2.0 / float(spans)
	for side: String in ["north", "south", "east", "west"]:
		var along_x := side == "north" or side == "south"
		var sign: float = 1.0 if side in ["south", "east"] else -1.0
		for span: int in spans:
			var along := -WALL_HALF + (float(span) + 0.5) * length
			var centre := Vector3(along, WALL_HEIGHT - 0.1, sign * (WALL_HALF - 0.55)) if along_x \
				else Vector3(sign * (WALL_HALF - 0.55), WALL_HEIGHT - 0.1, along)
			var deck_size := Vector3(length, 0.24, WALK_WIDTH) if along_x \
				else Vector3(WALK_WIDTH, 0.24, length)
			_add_brick(centre, deck_size, "warm", Vector3.ZERO, side + "_walk", 0, span)
			_add_breakable_collision(centre, deck_size)
			var inner := centre + (Vector3(0.0, 0.0, -sign) if along_x \
				else Vector3(-sign, 0.0, 0.0)) * (WALK_WIDTH * 0.5 - 0.2)
			var rail_at := inner + Vector3.UP * (WALK_PARAPET * 0.5 + 0.12)
			var rail_size := Vector3(length, WALK_PARAPET, 0.35) if along_x \
				else Vector3(0.35, WALK_PARAPET, length)
			# Open the stair landing and both corner connectors through this inner rail.
			var landing: float = WALL_HALF * 0.42 * (1.0 if side in ["north", "east"] else -1.0)
			var segment_min: float = along - length * 0.5
			var segment_max: float = along + length * 0.5
			var intervals: Array[Vector2] = [Vector2(segment_min, segment_max)]
			var corner_lane := WALL_HALF - TOWER_RADIUS - 2.4
			var gap_centres: Array[float] = [landing, -corner_lane, corner_lane]
			if side == "south":
				gap_centres.append_array([-14.0, 14.0])
			for gap_centre: float in gap_centres:
				var gap_min := gap_centre - 1.8
				var gap_max := gap_centre + 1.8
				var remaining: Array[Vector2] = []
				for interval: Vector2 in intervals:
					if interval.y <= gap_min or interval.x >= gap_max:
						remaining.append(interval)
					else:
						if interval.x < gap_min: remaining.append(Vector2(interval.x, gap_min))
						if interval.y > gap_max: remaining.append(Vector2(gap_max, interval.y))
				intervals = remaining
			for interval: Vector2 in intervals:
				if interval.y - interval.x < 0.05: continue
				var piece_at := rail_at
				var piece_size := rail_size
				if along_x:
					piece_at.x = (interval.x + interval.y) * 0.5
					piece_size.x = interval.y - interval.x
				else:
					piece_at.z = (interval.x + interval.y) * 0.5
					piece_size.z = interval.y - interval.x
				_add_brick(piece_at, piece_size, "cold", Vector3.ZERO, side + "_parapet", 0, span)
				_add_breakable_collision(piece_at, piece_size)

func _build_corner_bypasses() -> void:
	# An L-shaped passage inside each tower joins neighbouring wall walks. The
	# tower remains solid until struck, while archers can circulate around it.
	var lane := WALL_HALF - TOWER_RADIUS - 2.4
	var link := (WALL_HALF - 0.55) - lane
	var centre_along := (WALL_HALF - 0.55 + lane) * 0.5
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var first := Vector3(sx * lane, WALL_HEIGHT - 0.1, sz * centre_along)
			var second := Vector3(sx * centre_along, WALL_HEIGHT - 0.1, sz * lane)
			var first_size := Vector3(WALK_WIDTH, 0.24, link + WALK_WIDTH)
			var second_size := Vector3(link + WALK_WIDTH, 0.24, WALK_WIDTH)
			for item: Dictionary in [
				{"at": first, "size": first_size}, {"at": second, "size": second_size}]:
				_add_brick(item["at"], item["size"], "warm", Vector3.ZERO, "corner_walk")
				_add_breakable_collision(item["at"], item["size"])
			# Four short rails protect the inside edge without covering the turn.
			var rail_y := WALL_HEIGHT + WALK_PARAPET * 0.5 + 0.02
			var rail_link := link - 1.8
			var rail_centre := lane + rail_link * 0.5
			var first_rail := Vector3(sx * (lane - WALK_WIDTH * 0.5), rail_y, sz * rail_centre)
			var second_rail := Vector3(sx * rail_centre, rail_y, sz * (lane - WALK_WIDTH * 0.5))
			var first_rail_size := Vector3(0.28, WALK_PARAPET, rail_link)
			var second_rail_size := Vector3(rail_link, WALK_PARAPET, 0.28)
			for item: Dictionary in [
				{"at": first_rail, "size": first_rail_size},
				{"at": second_rail, "size": second_rail_size}]:
				_add_brick(item["at"], item["size"], "cold", Vector3.ZERO, "corner_parapet")
				_add_breakable_collision(item["at"], item["size"])
			# A visible pier under the bend supports both short spans.
			var pier_height := WALL_HEIGHT - 0.24
			var pier_at := Vector3(sx * lane, pier_height * 0.5, sz * lane)
			_add_brick(pier_at, Vector3(0.9, pier_height, 0.9), "stone", Vector3.ZERO,
				"corner_pier")
			_add_breakable_collision(pier_at, Vector3(0.9, pier_height, 0.9))

func _build_gatehouse_bypass() -> void:
	# The gatehouse turrets reach above the main walk. Pass them on the
	# courtyard side while preserving the gate arch and outer silhouette.
	var deck_y := WALL_HEIGHT - 0.1
	var inner_z := WALL_HALF - 5.0
	for side: float in [-1.0, 1.0]:
		for i: int in 3:
			var branch_at := Vector3(side * 14.0, deck_y, 63.5 + float(i) * 1.725)
			var branch_size := Vector3(WALK_WIDTH, 0.24, 2.45)
			_add_brick(branch_at, branch_size, "warm", Vector3.ZERO, "gate_bypass", 0, i)
			_add_breakable_collision(branch_at, branch_size)
	# Twelve short spans keep a blast local instead of erasing the entire bridge.
	for i: int in 12:
		var bridge_at := Vector3(-13.75 + float(i) * 2.5, deck_y, inner_z)
		var bridge_size := Vector3(2.55, 0.24, WALK_WIDTH)
		_add_brick(bridge_at, bridge_size, "warm", Vector3.ZERO, "gate_bypass", 1, i)
		_add_breakable_collision(bridge_at, bridge_size)
	# Stone piers carry the long cross span. The central gate approach stays open.
	for side: float in [-1.0, 1.0]:
		var pier_height := WALL_HEIGHT - 0.24
		var pier_at := Vector3(side * 10.0, pier_height * 0.5, inner_z)
		var pier_size := Vector3(1.1, pier_height, 1.1)
		_add_brick(pier_at, pier_size, "stone", Vector3.ZERO, "gate_bypass_pier")
		_add_breakable_collision(pier_at, pier_size)

## ------------------------------------------------------------------ colour and banners
func _build_wall_banners() -> void:
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.46, 0.07, 0.08)
	cloth.roughness = 0.92
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.72, 0.55, 0.18)
	gold.metallic = 0.6
	gold.roughness = 0.42
	var pole := StandardMaterial3D.new()
	pole.albedo_color = Color(0.26, 0.18, 0.11)
	pole.roughness = 0.9
	var bars: Array[Transform3D] = []
	var flags: Array[Transform3D] = []
	var devices: Array[Transform3D] = []
	for side: String in ["north", "south", "east", "west"]:
		var vertical: bool = side == "north" or side == "south"
		var sign_z: float = 1.0 if side == "south" else -1.0
		var sign_x: float = 1.0 if side == "east" else -1.0
		# On the gate wall the middle bay IS the gate: a banner hanging over it reads as a
		# black stripe across the doors, so that wall gets its two side bays only.
		var bays: Array = [0, 2] if side == "south" else [0, 1, 2]
		for slot: int in bays:
			var along: float = (float(slot) - 1.0) * (WALL_HALF * 0.52)
			var anchor := Vector3.ZERO
			var outward := Vector3.ZERO
			if vertical:
				anchor = Vector3(along, WALL_HEIGHT - 0.5,
					sign_z * (WALL_HALF + WALL_THICK * 0.5 + 0.12))
				outward = Vector3(0.0, 0.0, sign_z)
			else:
				anchor = Vector3(sign_x * (WALL_HALF + WALL_THICK * 0.5 + 0.12),
					WALL_HEIGHT - 0.5, along)
				outward = Vector3(sign_x, 0.0, 0.0)
			var rotation_y: float = 0.0 if vertical else PI * 0.5
			var facing := Basis(Vector3.UP, rotation_y)
			bars.append(Transform3D(facing * Basis(Vector3.FORWARD, PI * 0.5), anchor))
			flags.append(Transform3D(facing,
				anchor + Vector3.DOWN * 2.15 - outward * 0.06))
			# The device remains on the cloth plane on east/west walls as well.
			for petal: int in 3:
				var offset_x: float = 0.0 if petal == 1 else (-0.30 if petal == 0 else 0.30)
				var size := Vector3(0.22, 1.05 if petal == 1 else 0.75, 0.05)
				devices.append(Transform3D(facing.scaled(size),
					anchor + facing * Vector3(offset_x, -1.7, 0.0) + outward * 0.02))
			devices.append(Transform3D(facing.scaled(Vector3(0.95, 0.18, 0.05)),
				anchor + Vector3.DOWN * 2.25 + outward * 0.02))
	var bar_mesh := CylinderMesh.new()
	bar_mesh.top_radius = 0.07
	bar_mesh.bottom_radius = 0.07
	bar_mesh.height = 2.5
	_add_banner_batch("BannerBars", bar_mesh, pole, bars)
	_add_banner_batch("HangingBanners", _make_hanging_banner_mesh(), cloth, flags)
	_add_banner_batch("BannerDevices", BoxMesh.new(), gold, devices)

func _add_banner_batch(label: String, mesh: Mesh, material: Material,
		transforms: Array[Transform3D]) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index: int in transforms.size():
		multi.set_instance_transform(index, transforms[index])
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(node)

func _make_hanging_banner_mesh() -> ArrayMesh:
	var outline := PackedVector2Array([
		Vector2(-1.15, 2.1), Vector2(1.15, 2.1), Vector2(1.15, -2.1),
		Vector2(0.35, -2.1), Vector2(0.0, -1.52), Vector2(-0.35, -2.1),
		Vector2(-1.15, -2.1)])
	var triangles := Geometry2D.triangulate_polygon(outline)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for index: int in triangles:
		var point := outline[index]
		vertices.append(Vector3(point.x, point.y, 0.0))
		normals.append(Vector3.FORWARD)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## ------------------------------------------------------------------ the floor
## The courtyard is laid in BRICKS, a shade cooler and darker than the walls, so the
## ground does not read as one poured slab. Drawn as a MultiMesh (one draw call) with a
## little variation per stone; the collision is the flat slab that was already there.
func _build_brick_floor() -> void:
	var paving := StandardMaterial3D.new()
	paving.albedo_color = Color(0.44, 0.42, 0.40)
	paving.roughness = 1.0
	var stone_mesh := BoxMesh.new()
	# Small, even mortar joints reveal the running bond without the jagged gaps
	# caused by rotating each large paving stone independently.
	stone_mesh.size = Vector3(1.855, 0.10, 0.94)
	var per_row: int = int((WALL_HALF * 2.0) / 1.88)
	var rows: int = int((WALL_HALF * 2.0) / 0.96)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = stone_mesh
	# A straight threshold course covers the scattered ends at the south keep face.
	# It lives in this same MultiMesh: no new draw call or collision island.
	multi.instance_count = per_row * rows + 14
	var slot := 0
	for row: int in rows:
		var offset: float = 0.0 if row % 2 == 0 else 0.94
		for column: int in per_row:
			var x: float = (float(column) - float(per_row - 1) * 0.5) * 1.88 + offset
			var z: float = (float(row) - float(rows - 1) * 0.5) * 0.96
			multi.set_instance_transform(slot, Transform3D(Basis.IDENTITY, Vector3(x, 0.02, z)))
			var tone: float = 0.88 + float(abs(int(x * 131.0) ^ int(z * 977.0)) % 100) / 100.0 * 0.22
			multi.set_instance_color(slot, Color(tone, tone * 0.99, tone * 0.97))
			slot += 1
	for apron: int in 14:
		var x := (float(apron) - 6.5) * 2.0
		var scale := Vector3(1.975 / stone_mesh.size.x, 1.02, 1.30 / stone_mesh.size.z)
		multi.set_instance_transform(slot, Transform3D(Basis.IDENTITY.scaled(scale),
			Vector3(x, 0.035, 6.10)))
		var tone := 0.95 + float(apron % 4) * 0.018
		multi.set_instance_color(slot, Color(tone, tone * 0.99, tone * 0.97))
		slot += 1
	var node := MultiMeshInstance3D.new()
	node.name = "FloorBricks"
	node.multimesh = multi
	node.material_override = paving
	add_child(node)

## String courses: a band of stone standing proud of the wall at two heights, which is the
## cheapest way to break a flat face - one line and the wall stops being a panel.
func _build_string_courses() -> void:
	for side: String in ["north", "south", "east", "west"]:
		var vertical: bool = side == "north" or side == "south"
		var per_course: int = int((WALL_HALF * 2.0) / BRICK.x)
		for height in [WALL_HEIGHT * 0.42, WALL_HEIGHT * 0.78]:
			for column: int in per_course:
				var along: float = (float(column) - float(per_course - 1) * 0.5) * BRICK.x
				# The band stops at the gate: a course of stone run across the doorway is a
				# bar on the doors.
				if side == "south" and absf(along) < GATE_WIDTH * 0.5 + 1.0: continue
				var at := Vector3.ZERO
				var size := Vector3(BRICK.x * 1.02, 0.34, WALL_THICK * 1.22)
				match side:
					"north": at = Vector3(along, height, -WALL_HALF)
					"south": at = Vector3(along, height, WALL_HALF)
					"east":
						at = Vector3(WALL_HALF, height, along)
						size = Vector3(WALL_THICK * 1.22, 0.34, BRICK.x * 1.02)
					"west":
						at = Vector3(-WALL_HALF, height, along)
						size = Vector3(WALL_THICK * 1.22, 0.34, BRICK.x * 1.02)
				_add_brick(at, size, "cold", Vector3.ZERO, side + "_course", 0, column)

## Recessed looking arcade in actual raised stone: the long curtains gain a strong
## rhythm between their existing buttresses without another light or mesh family.
## Each stone remains a breakable cell in the existing chunked MultiMesh.
func _build_facade_relief() -> void:
	for side: String in ["north", "south", "east", "west"]:
		var along_x: bool = side in ["north", "south"]
		var normal: float = 1.0 if side in ["south", "east"] else -1.0
		for bay: int in 8:
			var along := -52.5 + float(bay) * 15.0
			if side == "south" and absf(along) < 10.0: continue
			var face := normal * (WALL_HALF + 0.74)
			for flank: float in [-1.0, 1.0]:
				var foot := along + flank * 2.7
				var jamb_at := Vector3(foot, 5.5, face) if along_x else Vector3(face, 5.5, foot)
				var jamb_size := Vector3(0.48, 3.0, 0.42) if along_x \
					else Vector3(0.42, 3.0, 0.48)
				_add_brick(jamb_at, jamb_size, "cold", Vector3.ZERO, "wall_arcade", bay, 0)
				var arm_at := Vector3(along + flank * 1.37, 8.25, face) if along_x \
					else Vector3(face, 8.25, along + flank * 1.37)
				var arm_size := Vector3(0.48, 3.8, 0.42) if along_x \
					else Vector3(0.42, 3.8, 0.48)
				var tilt := Vector3(0.0, 0.0, flank * 0.63) if along_x \
					else Vector3(-flank * 0.63, 0.0, 0.0)
				_add_brick(arm_at, arm_size, "cold", tilt, "wall_arcade", bay, 1)
			var crown := Vector3(along, 9.73, face + normal * 0.04) if along_x \
				else Vector3(face + normal * 0.04, 9.73, along)
			_add_brick(crown, Vector3(0.92, 0.58, 0.50), "warm", Vector3.ZERO,
				"wall_arcade_keystone", bay, 0)
	# Frame existing keep windows with projecting jambs and small stone hoods.
	# The window dark panels are left exposed and their positions are unchanged.
	var keep_base := Vector3(0.0, 0.0, -8.0)
	for storey: int in 3:
		var height := 6.0 + float(storey) * 9.0
		for side: float in [-1.0, 1.0]:
			for opening: int in 2:
				var along := -4.6 + float(opening) * 9.2
				for along_x: bool in [true, false]:
					var face := side * (KEEP_SIZE.z * 0.5 + 0.92)
					var centre := keep_base + (Vector3(along, height, face) if along_x \
						else Vector3(face, height, along))
					for flank: float in [-1.0, 1.0]:
						var jamb := centre + (Vector3(flank * 0.82, 0.0, 0.0) if along_x \
							else Vector3(0.0, 0.0, flank * 0.82))
						var size := Vector3(0.32, 2.92, 0.38) if along_x \
							else Vector3(0.38, 2.92, 0.32)
						_add_brick(jamb, size, "cold", Vector3.ZERO, "keep_window_frame", storey, opening)
					var hood := centre + Vector3.UP * 1.52
					_add_brick(hood, Vector3(2.15, 0.30, 0.48) if along_x \
						else Vector3(0.48, 0.30, 2.15), "warm", Vector3.ZERO,
						"keep_window_hood", storey, opening)

## A projecting, layered entrance gives the front wall a readable profile from the
## catapult spawn. It only adds stones to the existing breakable MultiMesh cells;
## the gate leaves, passage, support colliders and destruction rules stay intact.
func _build_entrance_layer31() -> void:
	var front := WALL_HALF + WALL_THICK * 1.65
	# Two concentric rings of rotated voussoirs. The gap between the rings casts
	# a real shadow and lets the wooden leaves sit visibly behind stone.
	for ring: int in 2:
		var radius := 5.05 + float(ring) * 0.73
		var depth := front + float(ring) * 0.20
		for segment: int in 23:
			var angle := PI * float(segment) / 22.0
			var at := Vector3(cos(angle) * radius, 10.75 + sin(angle) * radius, depth)
			_add_brick(at, Vector3(0.86, 0.75, 0.54),
				"warm" if segment % 4 == 0 else "cold",
				Vector3(0.0, 0.0, angle - PI * 0.5), "entrance_arch31", ring, segment)
	# Narrow piers step out of the flat gatehouse. Each course is independent,
	# so a catapult breach can remove the trim with the masonry around it.
	for side: float in [-1.0, 1.0]:
		for offset: float in [6.15, 10.65]:
			var x := side * offset
			for row: int in 18:
				var height := 0.56 + float(row) * 1.06
				var face := front - 0.24 + (0.12 if row % 2 == 0 else 0.0)
				_add_brick(Vector3(x, height, face), Vector3(0.82, 1.02, 0.66),
					"warm" if row % 5 == 0 else "cold", Vector3.ZERO,
					"entrance_pier31", row, int(offset))
			for band: float in [4.8, 10.9, 17.8]:
				_add_brick(Vector3(x, band, front + 0.18), Vector3(1.25, 0.34, 0.92),
					"warm", Vector3.ZERO, "entrance_pier_cap31", int(band), int(offset))
		# A stepped capital and short corbels make the gate towers read as towers
		# rather than continuations of the curtain wall.
		for course: int in 3:
			_add_brick(Vector3(side * 8.35, 19.35 + float(course) * 0.46,
				front + 0.16 + float(course) * 0.12),
				Vector3(6.15 + float(course) * 0.36, 0.39, 0.70),
				"cold" if course == 1 else "warm", Vector3.ZERO,
				"entrance_crown31", course, int(side))
		for corbel: int in 5:
			_add_brick(Vector3(side * 8.35 + (float(corbel) - 2.0) * 1.35,
				18.65, front + 0.32), Vector3(0.48, 0.72, 0.86),
				"cold", Vector3.ZERO, "entrance_corbel31", corbel, int(side))
	# A lintel and inset heraldic panel bridge the two tower crowns above the
	# opening. Neither touches the 9.2 m clear gate passage.
	for tier: int in 4:
		_add_brick(Vector3(0.0, 17.15 + float(tier) * 0.75, front - 0.04),
			Vector3(6.65 - float(tier) * 1.05, 0.61, 0.48),
			"warm" if tier % 2 == 0 else "cold", Vector3.ZERO,
			"entrance_pediment31", tier, 0)
	_add_brick(Vector3(0.0, 18.42, front + 0.26), Vector3(0.23, 1.43, 0.14),
		"ochre", Vector3.ZERO, "entrance_crest31")
	_add_brick(Vector3(0.0, 18.75, front + 0.26), Vector3(1.12, 0.20, 0.14),
		"ochre", Vector3.ZERO, "entrance_crest31")
	# Two projecting bastions give the gate a real defensive mass. Their front
	# faces stand 3.4 m ahead of the curtain, and their ten separate collision
	# sections open with the same local breach rules as the existing wall.
	for side: float in [-1.0, 1.0]:
		var tower_x := side * 14.35
		var tower_z := WALL_HALF + 1.55
		for tier: int in 10:
			var at := Vector3(tower_x, 1.02 + float(tier) * 2.04, tower_z)
			var size := Vector3(4.25, 2.02, 3.7)
			_add_brick(at, size, "warm" if tier % 3 == 0 else "stone",
				Vector3.ZERO, "entrance_bastion31", tier, int(side))
			_add_breakable_collision(at, size)
			for edge: float in [-1.0, 1.0]:
				_add_brick(at + Vector3(edge * 1.86, 0.0, 2.00),
					Vector3(0.52, 2.03, 0.55), "cold", Vector3.ZERO,
					"entrance_bastion_quoin31", tier, int(edge))
		for band: float in [5.9, 12.0, 18.2, 20.7]:
			_add_brick(Vector3(tower_x, band, tower_z + 0.15),
				Vector3(4.76, 0.34, 4.15), "cold", Vector3.ZERO,
				"entrance_bastion_band31", int(band), int(side))
		for merlon: int in 3:
			_add_brick(Vector3(tower_x + (float(merlon) - 1.0) * 1.72,
				21.53, tower_z + 1.58), Vector3(0.96, 1.32, 0.88),
				"warm", Vector3.ZERO, "entrance_bastion_merlon31", merlon, int(side))
	# Four roof corner pinnacles break the keep's rectangular outline in the
	# distant approach view. They sit above the existing crenellated roof.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var corner := Vector3(sx * 11.55, 0.0, -8.0 + sz * 11.55)
			for tier: int in 5:
				var width := 2.55 - float(tier) * 0.33
				_add_brick(corner + Vector3.UP * (39.55 + float(tier) * 0.78),
					Vector3(width, 0.72, width), "warm" if tier % 2 == 0 else "cold",
					Vector3.ZERO, "keep_pinnacle31", tier, int(sx * 2.0 + sz))
			_add_brick(corner + Vector3.UP * 43.55, Vector3(0.48, 0.52, 0.48),
				"ochre", Vector3.ZERO, "keep_pinnacle_tip31")
	# Alternating cut-stone plinth and cornice along the four curtain walls.
	# Their projecting shadows split the otherwise uninterrupted flat elevation.
	for side_name: String in ["north", "south", "east", "west"]:
		var along_x := side_name in ["north", "south"]
		var sign := 1.0 if side_name in ["south", "east"] else -1.0
		for part: int in 46:
			var along := -67.5 + float(part) * 3.0
			if side_name == "south" and absf(along) < 12.0: continue
			for level: int in 2:
				var height := 1.05 if level == 0 else 17.9
				var face := sign * (WALL_HALF + 0.77 + (0.10 if part % 2 == 0 else 0.0))
				var at := Vector3(along, height, face) if along_x else Vector3(face, height, along)
				var size := Vector3(2.93, 0.42, 0.50) if along_x else Vector3(0.50, 0.42, 2.93)
				_add_brick(at, size, "warm" if (part + level) % 3 == 0 else "cold",
					Vector3.ZERO, "curtain_trim31", level, part)
## A ROAD AROUND THE CASTLE. Four paved strips running the whole way round the outside of
## the walls, wide enough to march a column along: the wall foot is where an army waits, and
## without it the outside of the castle is a field you can only cross by eye.
const RING_WIDTH := 9.0
const RING_GAP := 2.0

func _build_ring_road() -> void:
	var road := StandardMaterial3D.new()
	road.albedo_color = Color(0.38, 0.34, 0.28)
	road.roughness = 1.0
	var kerb := StandardMaterial3D.new()
	kerb.albedo_color = Color(0.52, 0.50, 0.46)
	kerb.roughness = 0.95
	var ring_radius: float = WALL_HALF + RING_GAP + RING_WIDTH * 0.5
	for side: String in ["north", "south", "east", "west"]:
		var vertical: bool = side == "north" or side == "south"
		var sign_z: float = 1.0 if side == "south" else -1.0
		var sign_x: float = 1.0 if side == "east" else -1.0
		# The strip runs past the corners so the four of them join without a gap.
		var span: float = WALL_HALF * 2.0 + (RING_WIDTH + RING_GAP) * 2.0
		var centre := Vector3(0.0, 0.02, sign_z * ring_radius) if vertical \
			else Vector3(sign_x * ring_radius, 0.02, 0.0)
		var size := Vector3(span, 0.08, RING_WIDTH) if vertical \
			else Vector3(RING_WIDTH, 0.08, span)
		var strip := MeshInstance3D.new()
		var strip_box := BoxMesh.new()
		strip_box.size = size
		strip.mesh = strip_box
		strip.material_override = road
		strip.position = centre
		add_child(strip)
		# A kerb on the inner edge, so the road reads as a road.
		var inner := Vector3(0.0, 0.06, sign_z * (WALL_HALF + RING_GAP * 0.5)) if vertical \
			else Vector3(sign_x * (WALL_HALF + RING_GAP * 0.5), 0.06, 0.0)
		var kerb_size := Vector3(span, 0.12, 0.5) if vertical else Vector3(0.5, 0.12, span)
		var kerb_mesh := MeshInstance3D.new()
		var kerb_box := BoxMesh.new()
		kerb_box.size = kerb_size
		kerb_mesh.mesh = kerb_box
		kerb_mesh.material_override = kerb
		kerb_mesh.position = inner
		add_child(kerb_mesh)
	# The ground under the road must be walkable stone, so a footstep there is stone too.
	var ring_body := StaticBody3D.new()
	ring_body.name = "RingRoad"
	ring_body.collision_layer = 1
	ring_body.collision_mask = 1
	ring_body.set_meta("surface", "stone")
	ring_body.position = Vector3(0.0, -0.02, 0.0)
	add_child(ring_body)
	var ring_shape := CollisionShape3D.new()
	var ring_box_shape := BoxShape3D.new()
	var outer: float = WALL_HALF + RING_GAP + RING_WIDTH
	ring_box_shape.size = Vector3(outer * 2.0, 0.10, outer * 2.0)
	ring_shape.shape = ring_box_shape
	ring_body.add_child(ring_shape)
## ------------------------------------------------------------------ masonry detail
## A wall of identical stones still looks manufactured. These are the things that make it
## read as a building that has stood for a century: brackets under the battlements,
## buttresses where the wall is weakest, worn stones here and there, rubble at the foot.

## Machicolation corbels: the brackets that carry the battlements out over the wall.
func _add_corbels(side: String) -> void:
	var step := 2.6
	var count := int((WALL_HALF * 2.0) / step)
	for i: int in count:
		var along := (float(i) - float(count - 1) * 0.5) * step
		var at := Vector3.ZERO
		var size := Vector3(0.55, 0.9, 0.85)
		match side:
			"north": at = Vector3(along, WALL_HEIGHT - 0.45, -WALL_HALF + 0.55)
			"south": at = Vector3(along, WALL_HEIGHT - 0.45, WALL_HALF - 0.55)
			"east":
				at = Vector3(WALL_HALF - 0.55, WALL_HEIGHT - 0.45, along)
				size = Vector3(0.85, 0.9, 0.55)
			"west":
				at = Vector3(-WALL_HALF + 0.55, WALL_HEIGHT - 0.45, along)
				size = Vector3(0.85, 0.9, 0.55)
		_add_brick(at, size, "cold", Vector3.ZERO, side + "_corbel", 0, i)

## Buttresses: a thicker pier against the wall every dozen metres, which is both how the
## wall stands up and where the eye rests.
func _add_buttresses(side: String) -> void:
	var step := 15.0
	var count := int((WALL_HALF * 2.0) / step)
	for i: int in count:
		var along := (float(i) - float(count - 1) * 0.5) * step
		# NOT across the gate. A pier lands every fifteen metres, and one of them lands dead
		# centre on the opening - a column of brick standing where the doors are.
		if side == "south" and absf(along) < GATE_WIDTH * 0.5 + 2.5: continue
		for row: int in int(WALL_HEIGHT / BRICK.y):
			var at := Vector3.ZERO
			var size := Vector3(1.5, BRICK.y, 1.9)
			match side:
				"north": at = Vector3(along, (float(row) + 0.5) * BRICK.y, -WALL_HALF - 0.5)
				"south": at = Vector3(along, (float(row) + 0.5) * BRICK.y, WALL_HALF + 0.5)
				"east":
					at = Vector3(WALL_HALF + 0.5, (float(row) + 0.5) * BRICK.y, along)
					size = Vector3(1.9, BRICK.y, 1.5)
				"west":
					at = Vector3(-WALL_HALF - 0.5, (float(row) + 0.5) * BRICK.y, along)
					size = Vector3(1.9, BRICK.y, 1.5)
			_add_brick(at, size, "warm", Vector3.ZERO, side + "_buttress", row, i)

## Shallow stone relief over the gate. All details remain breakable masonry instances.
func _build_gate_arch() -> void:
	var face_z := WALL_HALF + WALL_THICK * 0.72
	# A real voussoir rhythm replaces the three isolated diamonds. The shallow
	# arch follows the gateway and stays below the separate heraldic shield.
	for stone: int in 17:
		var angle := deg_to_rad(11.0 + float(stone) * 9.875)
		var x := cos(angle) * 4.05
		var y := 10.9 + sin(angle) * 4.05
		_add_brick(Vector3(x, y, face_z + 0.14),
			Vector3(1.18, 1.12, 0.48) if stone == 8 else Vector3(0.94, 0.90, 0.42),
			"warm" if stone == 8 else "cold", Vector3.ZERO,
			"gate_voussoir", stone, 0)
	for side: float in [-1.0, 1.0]:
		_add_brick(Vector3(side * 4.75, 12.08, face_z), Vector3(1.22, 0.36, 0.46),
			"warm", Vector3.ZERO, "gate_impost")
	for side: float in [-1.0, 1.0]:
		_add_brick(Vector3(side * 6.22, GATE_HEIGHT + 1.9, face_z),
			Vector3(0.30, 3.12, 0.40), "cold", Vector3.ZERO, "gate_relief")
	# Paired courses retain the old jamb footprint while showing actual stone bond.
	# The inner edge stays outside the passage; the gate leaves are unchanged.
	for side: float in [-1.0, 1.0]:
		for row: int in 12:
			for column: int in 2:
				var x := side * (GATE_WIDTH * 0.5 + 0.44 + float(column) * 1.02)
				_add_brick(Vector3(x, (float(row) + 0.5) * GATE_HEIGHT / 12.0, WALL_HALF),
					Vector3(0.96, GATE_HEIGHT / 12.0 * 0.91, WALL_THICK * 1.7),
					"cold" if (row + column) % 3 == 0 else "stone", Vector3.ZERO,
					"gate_jamb", row, column)
			# Projecting stone ends break the flat facade at every second course.
			if row % 2 == 0:
				_add_brick(Vector3(side * (GATE_WIDTH * 0.5 + 1.45),
					(float(row) + 0.5) * GATE_HEIGHT / 12.0, WALL_HALF + 1.02),
					Vector3(0.48, 0.84, 0.24), "warm", Vector3.ZERO,
					"gate_jamb_quoin", row, 0)

## Rubble: chips of stone fallen from the walls over the years.
func _add_rubble() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20251017
	for i: int in 240:
		var side := i % 4
		var along := rng.randf_range(-WALL_HALF + 2.0, WALL_HALF - 2.0)
		var out := WALL_HALF + rng.randf_range(-1.2, 3.0)
		var at := Vector3.ZERO
		match side:
			0: at = Vector3(along, rng.randf_range(0.02, 0.12), -out)
			1: at = Vector3(along, rng.randf_range(0.02, 0.12), out)
			2: at = Vector3(out, rng.randf_range(0.02, 0.12), along)
			_: at = Vector3(-out, rng.randf_range(0.02, 0.12), along)
		var size := Vector3(rng.randf_range(0.20, 0.55), rng.randf_range(0.10, 0.24),
			rng.randf_range(0.20, 0.55))
		_add_brick(at, size, "cold" if i % 3 != 0 else "warm",
			Vector3(0.0, rng.randf_range(0.0, TAU), 0.0), "rubble", 0, i)

## Banners on the corner towers: cloth, a pole, and a colour that carries.
func _build_banners() -> void:
	var pole := StandardMaterial3D.new()
	pole.albedo_color = Color(0.30, 0.22, 0.14)
	pole.roughness = 0.9
	# A single shared mesh and shader draw all four forked pennants. The vertex
	# wave runs on the GPU; no per-frame scene-tree work or cloth physics is added.
	var cloth := ShaderMaterial.new()
	var cloth_shader := Shader.new()
	cloth_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
void vertex() {
	float reach = clamp(UV.x, 0.0, 1.0);
	VERTEX.z += sin(TIME * 1.5 - reach * 5.0) * 0.17 * reach;
}
void fragment() {
	vec3 red = vec3(0.36, 0.025, 0.045);
	vec3 gold = vec3(0.79, 0.57, 0.18);
	float edge = 1.0 - step(0.065, UV.y) + step(0.935, UV.y);
	float charge = step(abs(UV.x - 0.33) + abs(UV.y - 0.5) * 0.68, 0.19);
	ALBEDO = mix(red, gold, clamp(edge + charge, 0.0, 1.0));
}
"""
	cloth.shader = cloth_shader
	var flag_mesh := _make_forked_flag_mesh()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var centre := Vector3(corner.x * WALL_HALF, 0.0, corner.y * WALL_HALF)
		var mast := MeshInstance3D.new()
		var mast_mesh := CylinderMesh.new()
		mast_mesh.top_radius = 0.08
		mast_mesh.bottom_radius = 0.10
		mast_mesh.height = 7.0
		mast.mesh = mast_mesh
		mast.material_override = pole
		mast.position = centre + Vector3.UP * (TOWER_HEIGHT + 3.4)
		add_child(mast)
		var flag := MeshInstance3D.new()
		flag.mesh = flag_mesh
		flag.material_override = cloth
		flag.position = centre + Vector3(0.12, TOWER_HEIGHT + 5.55, 0.0)
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flag)

func _make_forked_flag_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	for strip: int in 8:
		var left := float(strip) * 0.3
		var right := float(strip + 1) * 0.3
		for point: Vector2 in [Vector2(left, -0.75), Vector2(right, -0.75),
				Vector2(right, 0.75), Vector2(left, -0.75),
				Vector2(right, 0.75), Vector2(left, 0.75)]:
			vertices.append(Vector3(point.x, point.y, 0.04 * sin(point.x * 2.0)))
			uvs.append(Vector2(point.x / 3.0, (point.y + 0.75) / 1.5))
			normals.append(Vector3.FORWARD)
	# The two tapered tails leave a distinct V-shaped notch in the free edge.
	for point: Vector2 in [Vector2(2.4, 0.0), Vector2(3.0, 0.75), Vector2(2.4, 0.75),
			Vector2(2.4, -0.75), Vector2(3.0, -0.75), Vector2(2.4, 0.0)]:
		vertices.append(Vector3(point.x, point.y, 0.04 * sin(point.x * 2.0)))
		uvs.append(Vector2(point.x / 3.0, (point.y + 0.75) / 1.5))
		normals.append(Vector3.FORWARD)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
## ------------------------------------------------------------------ towers and bridges
## A tower that is a solid drum is a box. Each corner tower gets a FLOOR at the level of the
## wall-walk, an opening onto it, and crenellations above: a room at the top a man can walk
## into from the battlements, which is what the reference picture shows.
func _build_tower_platforms() -> void:
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var centre := Vector3(corner.x * WALL_HALF, 0.0, corner.y * WALL_HALF)
		_add_brick(centre + Vector3.UP * (WALL_HEIGHT - 0.1),
			Vector3((TOWER_RADIUS - 0.35) * 2.0, 0.24, (TOWER_RADIUS - 0.35) * 2.0),
			"warm", Vector3.ZERO, "tower_floor55", 0, 0, "tower_floor55")
		_add_brick(centre + Vector3.UP * (TOWER_HEIGHT + 1.2),
			Vector3((TOWER_RADIUS + 0.4) * 2.0, 2.4, (TOWER_RADIUS + 0.4) * 2.0),
			"cold", Vector3.ZERO, "tower_roof55", 0, 0, "tower_roof55")

## A HANGING BRIDGE between the two gate towers, at the height of the wall-walk: planks,
## two ropes, and nothing under them. The planks are bricks like everything else, so a stone
## from a catapult takes the bridge apart exactly the way it takes a wall apart.
func _build_gate_bridge() -> void:
	var y := WALL_HEIGHT + 0.15
	var span := GATE_WIDTH + 7.2
	var planks := 22
	var plank_w: float = span / float(planks)
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color(0.52, 0.44, 0.30)
	rope.roughness = 0.95
	for i: int in planks:
		var x: float = -span * 0.5 + plank_w * (float(i) + 0.5)
		# A shallow sag in the middle, the way a rope bridge hangs.
		var sag: float = -0.28 * sin(PI * (float(i) + 0.5) / float(planks))
		_add_brick(Vector3(x, y + sag, WALL_HALF), Vector3(plank_w * 0.94, 0.16, 2.2),
			"wood", Vector3.ZERO, "bridge", 0, i)
	for side: float in [-1.0, 1.0]:
		for i: int in 9:
			var t_norm: float = float(i) / 8.0
			var x: float = -span * 0.5 + span * t_norm
			var sag: float = -0.28 * sin(PI * t_norm)
			var rope_mesh := MeshInstance3D.new()
			var rope_cylinder := CylinderMesh.new()
			rope_cylinder.top_radius = 0.05
			rope_cylinder.bottom_radius = 0.05
			rope_cylinder.height = span / 8.0 * 1.1
			rope_mesh.mesh = rope_cylinder
			rope_mesh.material_override = rope
			rope_mesh.position = Vector3(x, y + sag + 0.95, WALL_HALF + side * 1.15)
			rope_mesh.rotation = Vector3(0.0, 0.0, PI * 0.5)
			add_child(rope_mesh)
## ------------------------------------------------------------------ destruction
func owns_collider(body: Node) -> bool:
	if not is_instance_valid(body): return false
	return body.get_meta("castle_brick", false) or body.get_meta("castle_gate", false)

## A blade can splinter timber furnishings, but cannot fracture masonry, iron or
## the oak gate. The caller supplies the exact physics collider and contact point.
## DSH_NET: удар мечом по кладке. По сети нельзя передать Node-коллайдер,
## поэтому секция адресуется своей мировой точкой, а повтор помечается meta
## `net_replay`, чтобы он не ушёл обратно в сеть.
func apply_melee_hit(collider: Node, point: Vector3, speed: float,
		impulse: Vector3) -> Dictionary:
	if Net.online() and not (is_instance_valid(collider) and collider.get_meta("net_replay", false)):
		var key: Variant = section_world_of(collider)
		if key == null:
			return {"ok": false, "reason": "no_section"}
		if not Net.is_host():
			Net.send_event_to_host("melee_hit_request", {"site": "castle", "k": key,
				"p": point, "s": speed, "i": impulse})
			return {"ok": false, "reason": "requested"}
		var applied: Dictionary = _apply_melee_hit_local(collider, point, speed, impulse)
		Net.broadcast_event("melee_hit", {"site": "castle", "k": key, "p": point,
			"s": speed, "i": impulse})
		return applied
	return _apply_melee_hit_local(collider, point, speed, impulse)


## Мировая точка секции, которой принадлежит коллайдер (адрес для сети).
func section_world_of(collider: Node) -> Variant:
	if not is_instance_valid(collider):
		return null
	for candidate: Dictionary in _wall_collision:
		if candidate.get("body") == collider:
			return to_global(candidate.get("at", Vector3.ZERO))
	return null


## Коллайдер живой секции по её мировой точке (приём сетевого удара).
## `only_furnishing` — только те секции, которые меч вообще может рубить:
## обычная кладка помечена как blade_resistant и по сети не адресуется.
func section_collider_at(world_at: Vector3, only_furnishing: bool = true) -> Node:
	var best: Node = null
	var best_distance := 0.8
	for candidate: Dictionary in _wall_collision:
		if not bool(candidate.get("alive", false)):
			continue
		var body: Variant = candidate.get("body")
		if not is_instance_valid(body):
			continue
		if only_furnishing and not bool((body as Node).get_meta("castle_furnishing", false)):
			continue
		var distance: float = to_global(candidate.get("at", Vector3.ZERO)).distance_to(world_at)
		if distance < best_distance:
			best_distance = distance
			best = body as Node
	return best


func wall_section_points(only_furnishing: bool = true) -> Array:
	var points: Array = []
	for candidate: Dictionary in _wall_collision:
		if not bool(candidate.get("alive", false)):
			continue
		var body: Variant = candidate.get("body")
		if not is_instance_valid(body):
			continue
		if only_furnishing and not bool((body as Node).get_meta("castle_furnishing", false)):
			continue
		points.append(to_global(candidate.get("at", Vector3.ZERO)))
	return points


func _apply_melee_hit_local(collider: Node, point: Vector3, speed: float,
		impulse: Vector3) -> Dictionary:
	if not _ready or not is_instance_valid(collider) or collider.get_parent() != self:
		return {"ok": false, "reason": "foreign_or_unready"}
	if not bool(collider.get_meta("castle_furnishing", false)) or speed < 1.5:
		return {"ok": false, "reason": "blade_resistant"}
	var group: String = str(collider.get_meta("castle_furnishing_group", ""))
	var material_key: String = str(collider.get_meta("castle_furnishing_material", ""))
	var section: Dictionary = {}
	for candidate: Dictionary in _wall_collision:
		if candidate.get("body") == collider and bool(candidate.get("alive", false)):
			section = candidate
			break
	if section.is_empty(): return {"ok": false, "reason": "already_broken"}
	var hp: float = float(collider.get_meta("castle_melee_hp", 2.0)) - \
		clampf(speed / 5.0, 0.5, 1.5)
	collider.set_meta("castle_melee_hp", hp)
	if hp > 0.0:
		return {"ok": true, "broken": false, "material": material_key, "hp": hp}
	var local_point: Vector3 = to_local(point)
	var best_index := -1
	var best_distance := INF
	for value: Variant in _furniture_cells.get(group, []):
		var index: int = int(value)
		var cell: Dictionary = _cells[index]
		if not bool(cell.get("alive", false)):
			continue
		var centre: Vector3 = cell["at"]
		var half: Vector3 = cell["size"] * 0.5
		var delta: Vector3 = local_point - centre
		var nearest := Vector3(clampf(delta.x, -half.x, half.x),
			clampf(delta.y, -half.y, half.y), clampf(delta.z, -half.z, half.z))
		var distance: float = (delta - nearest).length()
		if distance < best_distance:
			best_distance = distance
			best_index = index
	if best_index < 0 or best_distance > 0.5:
		return {"ok": false, "reason": "no_matching_piece"}
	_kill_brick(best_index, impulse, clampf(speed * 1.2, 3.0, 12.0))
	_release_furniture_dependents(group, section["at"], impulse, speed)
	section["alive"] = false
	(collider as CollisionObject3D).collision_layer = 0
	(collider as CollisionObject3D).collision_mask = 0
	if material_key.begins_with("wood"):
		for splinter: int in 3:
			_spawn_falling_brick({"at": local_point + Vector3(
				randf_range(-0.15, 0.15), randf_range(-0.15, 0.15),
				randf_range(-0.15, 0.15)), "size": Vector3(0.08, 0.28, 0.06),
				"material": material_key, "rotation": Vector3.ZERO,
				"row": 0, "column": splinter}, impulse, speed)
	return {"ok": true, "broken": true, "material": material_key, "group": group}

func _release_furniture_dependents(group: String, at: Vector3,
		impulse: Vector3, speed: float) -> void:
	var dependent: Array[String] = []
	var reach := 2.5
	if group == "chamber_bed": reach = 4.5 # Canopy and four posts belong to this bed.
	match group:
		"hall_table": dependent = ["hall_table_leg", "hall_table_slats", "hall_table_edge",
			"hall_table_brace", "hall_plate", "hall_goblet"]
		"hall_bench": dependent = ["hall_bench_leg"]
		"hall_chair": dependent = ["hall_chair_cushion", "hall_chair_leg", "hall_chair_back"]
		"hall_chest": dependent = ["hall_chest_band", "hall_chest_lid"]
		"armour_rack": dependent = ["armour_rack_post", "armour_rack_rail", "armour_crest",
			"armour_hook", "armour_backer"]
		"armour_shield_mount": dependent = ["armour_shield_trim", "armour_shield_hook"]
		"armour_bench": dependent = ["armour_leg", "armour_bench_slats"]
		"armour_chest": dependent = ["armour_chest_lid", "armour_chest_frame",
			"armour_chest_foot", "armour_chest_panel", "armour_chest_inlay",
			"armour_chest_band", "armour_chest_lock"]
		"archive_shelf": dependent = ["archive_shelf_post", "archive_shelf_crown",
			"archive_books", "archive_shelf_trim"]
		"archive_desk": dependent = ["archive_desk_slats", "archive_desk_leg", "archive_map"]
		"chamber_bed": dependent = ["chamber_bed_rail", "chamber_mattress",
			"chamber_cover", "chamber_cover_trim", "chamber_pillow",
			"chamber_post", "chamber_post_finial", "chamber_canopy",
			"chamber_canopy_lining", "chamber_canopy_valance", "chamber_drape",
			"chamber_footboard", "chamber_footboard_trim"]
		"chamber_headboard": dependent = ["chamber_headboard_crest", "chamber_headboard_finial"]
		"chamber_wardrobe": dependent = ["chamber_wardrobe_crown",
			"chamber_wardrobe_panel", "chamber_handle"]
		_: return
	for dependent_group: String in dependent:
		for value: Variant in _furniture_cells.get(dependent_group, []):
			var index: int = int(value)
			var cell: Dictionary = _cells[index]
			if bool(cell.get("alive", false)) and \
					(cell["at"] as Vector3).distance_to(at) <= reach:
				_kill_brick(index, impulse, minf(speed, 8.0))

func wall_half() -> float:
	return WALL_HALF

func get_stats() -> Dictionary:
	return {
		"ok": _ready, "bricks": _cells.size(), "detached": _detached,
		"explosions": _explosions,
		"collapsed": _collapsed, "gates": _gate_leaves.size(),
		"gate_open": _gate_leaves.size() > 0 and bool(_gate_leaves[0].get("detached", false)),
		"gate_leaves_detached": _gate_leaves_detached(),
		"gate_boards_broken": _gate_boards_broken(),
		"gate_board_colliders_active": _gate_board_colliders_active(),
		"wall_collision_active": _wall_collision.filter(func(section: Dictionary) -> bool:
			return bool(section.get("alive", false))).size(),
		"falling": _falling.size(), "events": _events.size(), "leaf_dbg": _leaf_debug(),
		"gate_bricks": _count_gate_bricks(),
		"support_pending": _pending_support.size(),
		"persistent_rubble": _persistent_rubble,
	}

## DSH_OPT: every cell index whose grid box overlaps a cube round `at`. The boxes are
## coarse (8 m) so a blast touches a few dozen of them, not the whole map.
func _indices_near(at: Vector3, reach: float) -> Array[int]:
	return _indices_box(at - Vector3.ONE * reach, at + Vector3.ONE * reach)

## Every cell index whose grid box overlaps the given world box.
func _indices_box(low: Vector3, high: Vector3) -> Array[int]:
	var out: Array[int] = []
	var seen := {}
	var gx0 := int(floor(low.x / SPATIAL_STEP))
	var gx1 := int(floor(high.x / SPATIAL_STEP))
	var gy0 := int(floor(low.y / SPATIAL_STEP))
	var gy1 := int(floor(high.y / SPATIAL_STEP))
	var gz0 := int(floor(low.z / SPATIAL_STEP))
	var gz1 := int(floor(high.z / SPATIAL_STEP))
	for gx: int in range(gx0, gx1 + 1):
		for gy: int in range(gy0, gy1 + 1):
			for gz: int in range(gz0, gz1 + 1):
				var bucket: Variant = _spatial.get("%d|%d|%d" % [gx, gy, gz])
				if bucket != null:
					for index: int in bucket:
						if seen.has(index): continue
						seen[index] = true
						out.append(index)
	return out

## A blast knocks out every brick inside its radius, and the courses above them come down
## a moment later.
## DSH_NET: разрушение решает только хост.
##
## Клиент НЕ ломает кладку у себя: он просит хоста, хост применяет удар и
## рассылает его всем. Так два игрока не «убивают» один кирпич по-разному, и
## у гостя не появляется дыра, которой нет у хоста.
## Одиночная игра и повтор с флагом `from_network` идут прямо в локальную ветку.
func apply_explosion(event: Dictionary) -> Dictionary:
	if Net.online() and not bool(event.get("from_network", false)):
		if not Net.is_host():
			Net.send_event_to_host("destruction_request", {"site": "castle", "e": event})
			return {"ok": false, "reason": "requested", "detached": 0, "state": "requested"}
		var applied: Dictionary = _apply_explosion_local(event)
		Net.broadcast_event("destruction", {"site": "castle", "e": event,
			"dead": applied.get("dead", [])})
		return applied
	return _apply_explosion_local(event)


func _apply_explosion_local(event: Dictionary) -> Dictionary:
	if not _ready: return {"ok": false, "reason": "not_ready"}
	_explosions += 1
	# The strike arrives in WORLD coordinates - a catapult stone knows nothing of this
	# node - while the bricks are laid in local ones.
	# The strike arrives in WORLD coordinates - a catapult stone knows nothing of this
	# node - while the bricks are laid in local ones. Both are kept: the gates hang on
	# nodes whose positions are world, and comparing those against a local point put them
	# nine hundred metres from every blast.
	var at_world: Vector3 = event.get("position", Vector3.ZERO)
	var at: Vector3 = to_local(at_world)
	var radius: float = maxf(1.0, float(event.get("radius", 3.0)))
	var power: float = maxf(1.0, float(event.get("power", 40.0)))
	var direction: Vector3 = event.get("direction", Vector3.DOWN)
	get_tree().call_group("castle_armor_displays", "receive_castle_explosion", self, event)
	var killed := 0
	## DSH_NET: точный список выбитых кирпичей уходит клиентам, чтобы они били
	## ровно те же, а не пересчитывали радиус у себя (иначе стены расходятся).
	var dead: Array = []
	for index: int in _indices_near(at, radius):
		var cell: Dictionary = _cells[index]
		if not bool(cell.get("alive", false)): continue
		var brick_at: Vector3 = cell.get("at", Vector3.ZERO)
		var distance := _cell_distance55(cell, at) if _wall_masonry55(cell) else brick_at.distance_to(at)
		if distance > radius: continue
		_kill_brick(index, direction, power)
		dead.append(index)
		killed += 1
	for entry: Dictionary in _gate_leaves:
		var pivot: Node3D = entry.get("pivot")
		if not is_instance_valid(pivot): continue
		var boards: Array = entry.get("boards", [])
		# SECTION BY SECTION, where the stone struck. Each leaf has six plank columns
		# and eight short courses; a hit opens a local hole. The hinge releases only
		# when every section of the leaf has been destroyed.
		# The planks are drawn through the leaf's MultiMesh, so the distance is taken
		# in the PIVOT's space: the leaf can be swinging, and the planks swing with it.
		# Distance to the NEAREST POINT of the board, not to its middle: a stone that
		# strikes the top of a door is four metres from the centre of every board and was
		# measured as a miss.
		var pivot_hit: Vector3 = pivot.to_local(at_world)
		for board: Dictionary in boards:
			if bool(board.get("broken", false)): continue
			var local_hit: Vector3 = pivot_hit
			var board_at: Vector3 = board.get("at", Vector3.ZERO)
			var board_size: Vector3 = board.get("size", Vector3(0.8, 1.4, 0.26))
			var nearest := Vector3(
				clampf(local_hit.x, board_at.x - board_size.x * 0.5, board_at.x + board_size.x * 0.5),
				clampf(local_hit.y, board_at.y - board_size.y * 0.5, board_at.y + board_size.y * 0.5),
				clampf(local_hit.z, board_at.z - board_size.z * 0.5, board_at.z + board_size.z * 0.5))
			var hole: float = clampf(0.5 + power * 0.004, 0.6, 2.0)
			if local_hit.distance_to(nearest) > hole: continue
			board["broken"] = true
			var multi: MultiMeshInstance3D = board.get("multi")
			var slot: int = int(board.get("slot", -1))
			if is_instance_valid(multi) and multi.multimesh != null and slot >= 0:
				multi.multimesh.set_instance_transform(slot,
					Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.0001),
						Vector3(0.0, -4000.0, 0.0)))
			for fitting: Dictionary in board.get("inner40", []):
				var inner_multi: MultiMeshInstance3D = fitting.multi
				inner_multi.multimesh.set_instance_transform(int(fitting.slot),
					Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.0001), Vector3(0, -4000, 0)))
			var board_shape: CollisionShape3D = board.get("shape")
			if is_instance_valid(board_shape): board_shape.disabled = true
			killed += 1
			# The fallen plank and chips share the bounded debris pool with masonry.
			var plank_at: Vector3 = to_local(pivot.global_transform * board_at) \
				+ Vector3(0.0, 0.2, 0.9)
			_spawn_falling_brick({"at": plank_at, "size": board_size, "material": "wood",
				"rotation": Vector3.ZERO, "row": 0, "column": 0}, direction, power * 0.45)
			for splinter: int in 3:
				_spawn_falling_brick({"at": plank_at + Vector3(randf_range(-0.3, 0.3),
					randf_range(-0.4, 0.4), 0.1), "size": Vector3(randf_range(0.05, 0.10),
					randf_range(0.20, 0.48), randf_range(0.04, 0.08)),
					"material": "wood", "rotation": Vector3.ZERO, "row": 0, "column": splinter},
					direction, power * 0.4)
		var remaining := 0
		for board: Dictionary in boards:
			if not bool(board.get("broken", false)): remaining += 1
		if remaining > 0 or bool(entry.get("detached", false)): continue
		entry["detached"] = true
		_gate_open_state = false
		_gate_angle = 0.0
		pivot.visible = false
		for child: Node in pivot.get_children():
			var child_body := child as StaticBody3D
			if is_instance_valid(child_body):
				child_body.collision_layer = 0
				child_body.collision_mask = 0
		_detached += 1
		killed += 1
	if killed > 0:
		_sync_masonry_collision55()
		_break_collision_near(at, radius)
	# SHIP63: a small, fast ball opens a small hole; it must not trigger the
	# whole-section support cascade that a siege stone does.  Callers may pass
	# a narrower support radius; the catapult keeps the full blast radius.
	var support_radius: float = clampf(float(event.get("support_radius", radius)), 0.20, radius)
	_schedule_support_failure(at, support_radius)
	var result := {"ok": killed > 0, "detached": killed, "state": "committed",
		"event_id": str(event.get("event_id", "")), "total": _detached, "dead": dead}
	_events.append(result.duplicate())
	if _events.size() > 24: _events.pop_front()
	# DSH_NET: счётчик мгновенно выбитых кирпичей. По нему тест доказывает, что
	# дубль не нанёс второй урон: значения обязаны совпасть у обеих сторон.
	print("NET_EXPLOSION path=local killed=", killed, " dead=", dead.size(), " at=", at_world)
	return result


## DSH_NET: клиент применяет РОВНО тот набор кирпичей, который выбил хост.
## Свой радиальный пересчёт не делается: разный порядок обхода и разный момент
## каскада давали расхождение в пару процентов кладки. Обломки и опоры после
## этого считаются локально — они косметика.
func apply_dead_cells(indices: Array, event: Dictionary) -> Dictionary:
	if not _ready:
		return {"ok": false, "reason": "not_ready"}
	_explosions += 1
	var at_world: Vector3 = event.get("position", Vector3.ZERO)
	var at: Vector3 = to_local(at_world)
	var radius: float = maxf(1.0, float(event.get("radius", 3.0)))
	var power: float = maxf(1.0, float(event.get("power", 40.0)))
	var direction: Vector3 = event.get("direction", Vector3.DOWN)
	var killed := 0
	for value: Variant in indices:
		var index: int = int(value)
		if index < 0 or index >= _cells.size():
			continue
		var cell: Dictionary = _cells[index]
		if not bool(cell.get("alive", false)):
			continue
		_kill_brick(index, direction, power)
		killed += 1
	if killed > 0:
		_sync_masonry_collision55()
		_break_collision_near(at, radius)
	var support_radius: float = clampf(float(event.get("support_radius", radius)), 0.20, radius)
	_schedule_support_failure(at, support_radius)
	var result := {"ok": killed > 0, "detached": killed, "state": "network",
		"total": _detached, "dead": []}
	_events.append(result.duplicate())
	if _events.size() > 24: _events.pop_front()
	print("NET_EXPLOSION path=dead killed=", killed, " wanted=", indices.size(), " at=", at_world)
	return result

## Removing a stone invalidates support only in the vertical shadow above it. The audit
## filters candidates by footprint, then `support_state` measures the live cells that
## actually touch the candidate's underside. Opposite-side support preserves lintels,
## while a single surviving edge does not keep an ordinary course floating.
func _schedule_support_failure(at: Vector3, radius: float) -> void:
	# Direct kills already invalidated their own shadow. This seed also covers a caller
	# that reports a blast radius whose surviving lip now overhangs the hole.
	if radius <= 0.0:
		return
	for index: int in _indices_near(at, radius + 0.5):
		if bool((_cells[index] as Dictionary).get("alive", false)):
			_queue_support_audit(index)

func _queue_support_audit(killed_index: int) -> void:
	if killed_index < 0 or killed_index >= _cells.size():
		return
	var killed: Dictionary = _cells[killed_index]
	var bounds: AABB = killed.get("bounds55", _cell_bounds55(killed))
	var low := Vector3(bounds.position.x - SUPPORT_AUDIT_XZ_MARGIN,
		bounds.end.y + SUPPORT_VERTICAL_GAP, bounds.position.z - SUPPORT_AUDIT_XZ_MARGIN)
	var high := Vector3(bounds.end.x + SUPPORT_AUDIT_XZ_MARGIN,
		_support_ceiling55 + SUPPORT_VERTICAL_GAP, bounds.end.z + SUPPORT_AUDIT_XZ_MARGIN)
	var due := Time.get_ticks_msec() + SUPPORT_DELAY_MS
	for candidate: int in _indices_box(low, high):
		if candidate == killed_index or not bool((_cells[candidate] as Dictionary).get("alive", false)):
			continue
		var candidate_cell: Dictionary = _cells[candidate]
		var candidate_bounds: AABB = candidate_cell.get("bounds55", _cell_bounds55(candidate_cell))
		if candidate_bounds.position.x > bounds.end.x + SUPPORT_AUDIT_XZ_MARGIN \
			or candidate_bounds.end.x < bounds.position.x - SUPPORT_AUDIT_XZ_MARGIN \
			or candidate_bounds.position.z > bounds.end.z + SUPPORT_AUDIT_XZ_MARGIN \
			or candidate_bounds.end.z < bounds.position.z - SUPPORT_AUDIT_XZ_MARGIN:
			continue
		var previous := int(_pending_support.get(candidate, 0x7fffffff))
		if due < previous:
			_pending_support[candidate] = due
	# A removed plank or voussoir can sever a horizontal load path without leaving an
	# empty vertical shadow. Recheck that connected plate only after it was damaged.
	var killed_group := str(killed.get("group", ""))
	if killed_group == "keep_roof" or killed_group == "bridge" \
		or killed_group == "gate_voussoir":
		for candidate: int in _cells.size():
			var candidate_cell: Dictionary = _cells[candidate]
			if not bool(candidate_cell.get("alive", false)) \
				or str(candidate_cell.get("group", "")) != killed_group:
				continue
			var previous := int(_pending_support.get(candidate, 0x7fffffff))
			if due < previous:
				_pending_support[candidate] = due
	if killed_group.begins_with("stairs_"):
		var suffix := killed_group.get_slice("_", killed_group.get_slice_count("_") - 1)
		for candidate: int in _stair_families.get(suffix, []):
			var candidate_cell: Dictionary = _cells[candidate]
			if not bool(candidate_cell.get("alive", false)):
				continue
			var previous := int(_pending_support.get(candidate, 0x7fffffff))
			if due < previous:
				_pending_support[candidate] = due

func _cell_vertical_span55(cell: Dictionary) -> Vector2:
	var basis := Basis.from_euler(cell.get("rotation", Vector3.ZERO))
	var half: Vector3 = (cell.get("size", BRICK) as Vector3) * 0.5
	var span := Vector2(INF, -INF)
	for x: float in [-half.x, half.x]:
		for y: float in [-half.y, half.y]:
			for z: float in [-half.z, half.z]:
				var world_y := ((cell.get("at", Vector3.ZERO) as Vector3) + basis * Vector3(x, y, z)).y
				span.x = minf(span.x, world_y)
				span.y = maxf(span.y, world_y)
	return span

func _cell_footprint55(cell: Dictionary) -> PackedVector2Array:
	var at: Vector3 = cell.get("at", Vector3.ZERO)
	var size: Vector3 = cell.get("size", BRICK)
	var basis := Basis.from_euler(cell.get("rotation", Vector3.ZERO))
	var points := PackedVector2Array()
	if str(cell.get("shape", "box")) in ["tower_floor55", "tower_roof55"]:
		for step: int in 16:
			var angle := TAU * float(step) / 16.0
			var local := Vector3(cos(angle) * size.x * 0.5, 0.0,
				sin(angle) * size.z * 0.5)
			var point := at + basis * local
			points.append(Vector2(point.x, point.z))
		return points
	var corners: Array[Vector3] = [
		Vector3(-size.x * 0.5, 0.0, -size.z * 0.5),
		Vector3(size.x * 0.5, 0.0, -size.z * 0.5),
		Vector3(size.x * 0.5, 0.0, size.z * 0.5),
		Vector3(-size.x * 0.5, 0.0, size.z * 0.5),
	]
	for corner: Vector3 in corners:
		var point := at + basis * corner
		points.append(Vector2(point.x, point.z))
	return points

func _clip_polygon_edges55(subject: PackedVector2Array,
		clipper: PackedVector2Array) -> PackedVector2Array:
	var output := subject
	for edge: int in clipper.size():
		if output.is_empty():
			return output
		var a := clipper[edge]
		var b := clipper[(edge + 1) % clipper.size()]
		var edge_ab := b - a
		var input := output
		output = PackedVector2Array()
		var start := input[input.size() - 1]
		var start_inside := edge_ab.cross(start - a) >= -1.0e-6
		for point: Vector2 in input:
			var point_inside := edge_ab.cross(point - a) >= -1.0e-6
			if point_inside != start_inside:
				var segment := point - start
				var denominator := edge_ab.cross(segment)
				if absf(denominator) > 1.0e-8:
					var t := edge_ab.cross(a - start) / denominator
					output.append(start + segment * t)
			if point_inside:
				output.append(point)
			start = point
			start_inside = point_inside
	return output

func _polygon_area55(points: PackedVector2Array) -> float:
	if points.size() < 3:
		return 0.0
	var area := 0.0
	for index: int in points.size():
		area += points[index].cross(points[(index + 1) % points.size()])
	return absf(area) * 0.5

func _footprint_overlap55(a: PackedVector2Array, b: PackedVector2Array) -> float:
	return _polygon_area55(_clip_polygon_edges55(a, b))

func _horizontal_network_supported55(index: int, cell: Dictionary) -> Dictionary:
	var group := str(cell.get("group", ""))
	if group not in ["keep_roof", "bridge", "gate_voussoir"]:
		return {"supported": false, "reason": "not_plate"}
	var anchor := func(candidate: Dictionary) -> bool:
		if group == "keep_roof":
			return int(candidate.get("row", -1)) in [0, 12] \
				or int(candidate.get("column", -1)) in [0, 12]
		if group == "bridge":
			return absf((candidate.get("at", Vector3.ZERO) as Vector3).x) >= 6.35
		return int(candidate.get("row", -1)) in [0, 16]
	var seen: Dictionary = {index: true}
	var queue: Array[int] = [index]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		var current_cell: Dictionary = _cells[current]
		if bool(anchor.call(current_cell)):
			return {"supported": true, "reason": "anchored_plate", "sources": seen.size()}
		var current_bounds: AABB = current_cell.get("bounds55", _cell_bounds55(current_cell))
		var low := current_bounds.position - Vector3(1.7, 0.9, 1.7)
		var high := current_bounds.end + Vector3(1.7, 0.9, 1.7)
		for neighbour: int in _indices_box(low, high):
			if seen.has(neighbour):
				continue
			var next_cell: Dictionary = _cells[neighbour]
			if not bool(next_cell.get("alive", false)) \
				or str(next_cell.get("group", "")) != group:
				continue
			var next_span := _cell_vertical_span55(next_cell)
			var current_span := _cell_vertical_span55(current_cell)
			if absf((next_span.x + next_span.y) - (current_span.x + current_span.y)) > 1.8:
				continue
			if _footprint_overlap55(_cell_footprint55(current_cell),
					_cell_footprint55(next_cell)) <= 0.00001 \
				and (next_cell.get("at", Vector3.ZERO) as Vector3).distance_to(
					current_cell.get("at", Vector3.ZERO)) > 1.9:
				continue
			seen[neighbour] = true
			queue.append(neighbour)
	return {"supported": false, "reason": "detached_plate", "sources": seen.size()}

func _tower_ring_support55(index: int, cell: Dictionary) -> Dictionary:
	if str(cell.get("shape", "box")) not in ["tower_floor55", "tower_roof55"]:
		return {"supported": false, "reason": "not_tower_plate"}
	var centre: Vector3 = cell.get("at", Vector3.ZERO)
	var low := centre + Vector3(-7.0, -2.0, -7.0)
	var high := centre + Vector3(7.0, 2.0, 7.0)
	var quadrants := {}
	var sources := 0
	for source: int in _indices_box(low, high):
		if source == index:
			continue
		var support: Dictionary = _cells[source]
		if not bool(support.get("alive", false)) \
			or not str(support.get("group", "")).begins_with("tower"):
			continue
		var support_at: Vector3 = support.get("at", Vector3.ZERO)
		if absf(support_at.y - centre.y) > 2.0:
			continue
		var offset := Vector2(support_at.x - centre.x, support_at.z - centre.z)
		if offset.length() < 2.0 or offset.length() > 7.0:
			continue
		sources += 1
		quadrants[(int(floor((atan2(offset.y, offset.x) + PI) / (PI * 0.5))) % 4)] = true
	var supported := sources >= 3 and quadrants.size() >= 3
	return {"supported": supported, "reason": "curved_ring" if supported else "ring_failed",
		"sources": sources, "quadrants": quadrants.size()}

func _stair_network_supported55(index: int, cell: Dictionary) -> Dictionary:
	var group := str(cell.get("group", ""))
	if not group.begins_with("stairs_"):
		return {"supported": false, "reason": "not_stairs"}
	var suffix := group.get_slice("_", group.get_slice_count("_") - 1)
	var seen: Dictionary = {index: true}
	var queue: Array[int] = [index]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		var current_cell: Dictionary = _cells[current]
		var current_group := str(current_cell.get("group", ""))
		var current_span := _cell_vertical_span55(current_cell)
		if current_span.x <= 0.16 or current_group.contains("pier") \
			or current_group.contains("base"):
			return {"supported": true, "reason": "stair_ground_path", "sources": seen.size()}
		var current_at: Vector3 = current_cell.get("at", Vector3.ZERO)
		for candidate: int in _stair_families.get(suffix, []):
			if seen.has(candidate):
				continue
			var next: Dictionary = _cells[candidate]
			if not bool(next.get("alive", false)):
				continue
			var next_at: Vector3 = next.get("at", Vector3.ZERO)
			if next_at.distance_to(current_at) > 1.8:
				continue
			seen[candidate] = true
			queue.append(candidate)
	return {"supported": false, "reason": "detached_stairs", "sources": seen.size()}

## A support is a live cell whose top touches this cell's underside and whose footprint
## overlaps it. Coverage is measured in the horizontal plane. A bridge/arch remains stable
## with less total coverage only when opposite sides are both held.
func support_state(index: int) -> Dictionary:
	if index < 0 or index >= _cells.size():
		return {"supported": false, "reason": "invalid", "coverage": 0.0}
	var cell: Dictionary = _cells[index]
	if not bool(cell.get("alive", false)):
		return {"supported": false, "reason": "dead", "coverage": 0.0}
	var bounds: AABB = cell.get("bounds55", _cell_bounds55(cell))
	var candidate_span := _cell_vertical_span55(cell)
	if candidate_span.x <= 0.16:
		return {"supported": true, "reason": "ground", "coverage": 1.0}
	var low := Vector3(bounds.position.x - 0.04,
		candidate_span.x - SUPPORT_SEARCH_BELOW, bounds.position.z - 0.04)
	var high := Vector3(bounds.end.x + 0.04,
		candidate_span.x + SUPPORT_VERTICAL_GAP, bounds.end.z + 0.04)
	var centre := bounds.get_center()
	var footprint := _cell_footprint55(cell)
	var area := maxf(0.0001, _polygon_area55(footprint))
	var covered := 0.0
	var left := false
	var right := false
	var front := false
	var back := false
	var sources := 0
	for source: int in _indices_box(low, high):
		if source == index or not bool((_cells[source] as Dictionary).get("alive", false)):
			continue
		var support: Dictionary = _cells[source]
		var support_bounds: AABB = support.get("bounds55", _cell_bounds55(support))
		var support_span := _cell_vertical_span55(support)
		if absf(support_span.y - candidate_span.x) > SUPPORT_VERTICAL_GAP:
			continue
		var overlap := _footprint_overlap55(footprint, _cell_footprint55(support))
		if overlap <= 0.00001:
			continue
		sources += 1
		covered += overlap
		var support_centre := support_bounds.get_center()
		if support_centre.x < centre.x: left = true
		elif support_centre.x > centre.x: right = true
		if support_centre.z < centre.z: front = true
		elif support_centre.z > centre.z: back = true
	var coverage := clampf(covered / area, 0.0, 1.0)
	var balanced: bool = (left and right) or (front and back)
	var supported: bool = coverage >= SUPPORT_COVERAGE_MIN \
		or (balanced and coverage >= SUPPORT_BALANCED_MIN)
	if not supported:
		var ring := _tower_ring_support55(index, cell)
		if bool(ring.get("supported", false)):
			return {
				"supported": true,
				"reason": ring.get("reason", "curved_ring"),
				"coverage": coverage,
				"sources": int(ring.get("sources", 0)),
				"balanced": balanced,
			}
		var stairs := _stair_network_supported55(index, cell)
		if bool(stairs.get("supported", false)):
			return {
				"supported": true,
				"reason": stairs.get("reason", "stair_ground_path"),
				"coverage": coverage,
				"sources": int(stairs.get("sources", 0)),
				"balanced": balanced,
			}
		var plate := _horizontal_network_supported55(index, cell)
		if bool(plate.get("supported", false)):
			return {
				"supported": true,
				"reason": plate.get("reason", "anchored_plate"),
				"coverage": coverage,
				"sources": int(plate.get("sources", 0)),
				"balanced": balanced,
			}
	return {
		"supported": supported,
		"reason": "coverage" if coverage >= SUPPORT_COVERAGE_MIN else
			("balanced" if supported else "unsupported"),
		"coverage": coverage,
		"sources": sources,
		"balanced": balanced,
	}

## Velocity alone cannot distinguish rest from the apex of a throw. Probe downward
## from the lowest shape points and accept only an upward-facing contact surface.
func _support_contact_hit(body: RigidBody3D, shape: CollisionShape3D) -> Dictionary:
	if not is_instance_valid(body) or not is_instance_valid(shape) or shape.shape == null:
		return {}
	var world := get_world_3d()
	if world == null:
		return {}
	var local_points: Array[Vector3] = []
	if shape.shape is BoxShape3D:
		var half: Vector3 = (shape.shape as BoxShape3D).size * 0.5
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					local_points.append(Vector3(sx * half.x, sy * half.y, sz * half.z))
	elif shape.shape is CylinderShape3D:
		var cylinder := shape.shape as CylinderShape3D
		for sy: float in [-1.0, 1.0]:
			for index: int in 8:
				var angle := TAU * float(index) / 8.0
				local_points.append(Vector3(cos(angle) * cylinder.radius,
					sy * cylinder.height * 0.5, sin(angle) * cylinder.radius))
	elif shape.shape is ConvexPolygonShape3D:
		for point: Vector3 in (shape.shape as ConvexPolygonShape3D).get_points():
			local_points.append(point)
	if local_points.is_empty():
		return {}
	var bottom := INF
	var world_points: Array[Vector3] = []
	for point: Vector3 in local_points:
		var position: Vector3 = shape.global_transform * point
		world_points.append(position)
		bottom = minf(bottom, position.y)
	var bottom_center := Vector3.ZERO
	var bottom_count := 0
	for point: Vector3 in world_points:
		if point.y <= bottom + 0.025:
			bottom_center += point
			bottom_count += 1
	if bottom_count > 0:
		world_points.push_front(bottom_center / float(bottom_count))
	var checked := 0
	for point: Vector3 in world_points:
		if point.y > bottom + 0.025:
			continue
		var query := PhysicsRayQueryParameters3D.create(
			point + Vector3.UP * 0.25,
			point + Vector3.DOWN * SUPPORT_CONTACT_PROBE, 1, [body.get_rid()])
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if hit.get("collider") is StaticBody3D \
				and (hit.get("normal", Vector3.ZERO) as Vector3).dot(Vector3.UP) > 0.45:
			return hit
		checked += 1
		if checked >= 8:
			break
	return {}

func _has_support_contact(body: RigidBody3D, shape: CollisionShape3D) -> bool:
	return not _support_contact_hit(body, shape).is_empty()

func _drain_debris_backlog() -> void:
	var started := 0
	while started < DEBRIS_BACKLOG_PER_FRAME and _falling.size() < MAX_FALLING \
		and not _debris_backlog.is_empty():
		if int(_debris_backlog[0].get("due_frame", 0)) > Engine.get_physics_frames():
			break
		var next: Dictionary = _debris_backlog.pop_front()
		if next.has("restore"):
			_restore_persistent_rubble(next["restore"])
		else:
			_spawn_falling_brick_now(next.get("cell", {}), next.get("impulse", Vector3.DOWN),
				float(next.get("power", 30.0)))
		started += 1

func _physics_process(_delta: float) -> void:
	_audit_persistent_rubble()
	if not _ready:
		_drain_debris_backlog()
		return
	_advance_gate(_delta)
	# The cascade.
	if not _pending_support.is_empty():
		var now := Time.get_ticks_msec()
		var checks := 0
		var started := Time.get_ticks_usec()
		for key: Variant in _pending_support.keys():
			if checks >= SUPPORT_CHECKS_PER_FRAME \
				or Time.get_ticks_usec() - started >= SUPPORT_TIME_BUDGET_US:
				break
			var cell_index := int(key)
			if now < int(_pending_support.get(cell_index, 0)):
				continue
			_pending_support.erase(cell_index)
			checks += 1
			if cell_index < 0 or cell_index >= _cells.size() \
				or not bool((_cells[cell_index] as Dictionary).get("alive", false)):
				continue
			if not bool(support_state(cell_index).get("supported", false)):
				_kill_brick(cell_index, Vector3.DOWN, 30.0)
				_collapsed += 1
	_sync_masonry_collision55()
	# Bodies enter physics in a bounded stream. A detachment larger than MAX_FALLING is
	# deferred, never silently deleted or frozen in the air.
	if _falling.is_empty():
		_drain_debris_backlog()
		return
	for index: int in range(_falling.size() - 1, -1, -1):
		var entry: Dictionary = _falling[index]
		var body: RigidBody3D = entry.get("body")
		if not is_instance_valid(body):
			_falling.remove_at(index)
			continue
		var age: float = float(entry.get("age", 0.0)) + _delta
		entry["age"] = age
		# A stone that has stopped is rubble, not a moving body. Retiring its solver is the
		# single biggest saving after a blast: a hundred solvers awake is what stalls the
		# frame, and once they are asleep the cost is their meshes and nothing else.
		# ONLY when it has actually come to rest. Freezing on a timer alone left boards
		# hanging in mid-air exactly where they were blown to.
		var resting: bool = body.linear_velocity.length() < 0.7 \
			and body.angular_velocity.length() < 1.6
		var shape := body.get_node_or_null("Shape") as CollisionShape3D
		var contact := resting and _has_support_contact(body, shape)
		entry["support_frames"] = int(entry.get("support_frames", 0)) + 1 if contact else 0
		if age > BRICK_SETTLE_S and int(entry["support_frames"]) >= SUPPORT_PROOF_FRAMES:
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
			var substantial := bool(entry.get("substantial", false))
			if substantial and _promote_rubble(body, entry.get("cell", {})):
				_recycle_stone(body)
				_falling.remove_at(index)
				continue
		if age > TINY_DEBRIS_LIFE_S and not bool(entry.get("substantial", false)) \
			and int(entry.get("support_frames", 0)) >= SUPPORT_PROOF_FRAMES:
			# Cosmetic chips do not form routes and are the only debris retired by time.
			_recycle_stone(body)
			_falling.remove_at(index)
	_drain_debris_backlog()

## Where the player appears: in the courtyard, with the gate behind him.
func spawn_point() -> Vector3:
	return global_position + Vector3(0.0, 1.2, 14.0)

## Gate38: a recognisable siege entrance above the original breakable leaves.
## Every piece uses the existing masonry batches and damage cells. There are no
## new permanent collision bodies or materials in the clear gateway.
func _build_gate_art38() -> void:
	var face: float = WALL_HALF + 2.75
	# Seven machicolations project out of the gateway. Their gaps are dark from
	# below and the continuous rail ties the two pre-existing bastions together.
	for bracket: int in 7:
		var x: float = (float(bracket) - 3.0) * 1.68
		_add_brick(Vector3(x, 20.22, face + 0.22), Vector3(0.58, 1.13, 1.52),
			"cold", Vector3.ZERO, "gate38_machicolation", 0, bracket)
	_add_brick(Vector3(0.0, 21.12, face + 0.44), Vector3(13.4, 0.47, 1.45),
		"warm", Vector3.ZERO, "gate38_gallery_rail")
	for merlon: int in 7:
		var x: float = (float(merlon) - 3.0) * 1.86
		_add_brick(Vector3(x, 22.08, face + 0.60), Vector3(1.05, 1.50, 1.05),
			"stone", Vector3.ZERO, "gate38_gallery_merlon", 0, merlon)
	# The little watch turrets break the flat curtain silhouette. Eight stone
	# faces per course form a real octagon; stepped slate roofs carry a gold finial.
	for side: float in [-1.0, 1.0]:
		var cx: float = side * 14.35
		var cz: float = WALL_HALF + 1.55
		for course: int in 5:
			for facet: int in 8:
				var angle: float = TAU * float(facet) / 8.0
				var radial := Vector3(sin(angle), 0.0, cos(angle))
				_add_brick(Vector3(cx, 22.22 + float(course) * 1.04, cz) + radial * 2.02,
					Vector3(1.72, 1.01, 0.40),
					"warm" if course == 0 or course == 4 else "stone",
					Vector3(0.0, angle, 0.0), "gate38_turret_wall", course, facet)
		for ring: int in 4:
			var radius: float = 1.93 - float(ring) * 0.43
			for facet: int in 8:
				var angle: float = TAU * float(facet) / 8.0
				var radial := Vector3(sin(angle), 0.0, cos(angle))
				_add_brick(Vector3(cx, 27.55 + float(ring) * 0.56, cz) + radial * radius,
					Vector3(1.56 - float(ring) * 0.22, 0.49, 0.48), "cold",
					Vector3(0.0, angle, 0.0), "gate38_slate_roof", ring, facet)
		_add_brick(Vector3(cx, 29.88, cz), Vector3(0.58, 0.72, 0.58),
			"ochre", Vector3.ZERO, "gate38_finial")
		# A black slit, cut-stone jambs and a sill face the attackers. The slit
		# stays well above head height and does not alter the wall collision.
		_add_brick(Vector3(cx, 24.77, cz + 2.29), Vector3(0.27, 1.72, 0.07),
			"dark", Vector3.ZERO, "gate38_arrow_slit")
		for jamb_side: float in [-1.0, 1.0]:
			_add_brick(Vector3(cx + jamb_side * 0.25, 24.77, cz + 2.32),
				Vector3(0.19, 1.91, 0.15), "cold", Vector3.ZERO,
				"gate38_arrow_jamb")
		_add_brick(Vector3(cx, 23.76, cz + 2.36), Vector3(0.71, 0.18, 0.18),
			"cold", Vector3.ZERO, "gate38_arrow_sill")
		# Narrow burgundy standards identify the two turrets from the long approach.
		_add_brick(Vector3(cx, 20.84, cz + 2.40), Vector3(1.42, 2.22, 0.075),
			"velvet", Vector3.ZERO, "gate38_standard")
		_add_brick(Vector3(cx, 20.84, cz + 2.46), Vector3(0.19, 1.60, 0.04),
			"gold", Vector3.ZERO, "gate38_standard_device")
	# A layered pointed pediment above the gallery reads from the siege camp.
	for tier: int in 5:
		_add_brick(Vector3(0.0, 23.30 + float(tier) * 0.52, face + 0.02),
			Vector3(5.80 - float(tier) * 0.91, 0.47, 0.56),
			"warm" if tier % 2 == 0 else "cold", Vector3.ZERO,
			"gate38_pediment", tier, 0)
	_add_brick(Vector3(0.0, 24.13, face + 0.36), Vector3(1.06, 1.36, 0.12),
		"velvet", Vector3.ZERO, "gate38_heraldry")
	_add_brick(Vector3(0.0, 24.13, face + 0.46), Vector3(0.18, 1.08, 0.07),
		"gold", Vector3.ZERO, "gate38_heraldry_device")

## Street-scale landmarks: open supply shelters outside the gate, a courtyard well,
## rest benches and connected paving. All solids use the existing masonry batches
## and exact per-piece destruction ownership; no new lights or physics loops.
func _courtyard_piece43(at: Vector3, size: Vector3, material: String,
		group: String, solid: bool = true, rotation: Vector3 = Vector3.ZERO, profile: String = "box") -> int:
	var index := _add_brick(at, size, material, rotation, "courtyard43_" + group, 0, 0, profile)
	if solid:
		var chunk := Vector2i(int(floor(at.x / 12.0)), int(floor(at.z / 12.0)))
		var body: StaticBody3D = _courtyard_bodies43.get(chunk)
		if body == null:
			body = StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 1
			body.set_meta("surface", "stone")
			add_child(body)
			_courtyard_bodies43[chunk] = body
		var shape := CollisionShape3D.new()
		shape.position = at
		shape.rotation = rotation
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		_courtyard_shapes43[index] = shape
	return index

func _build_courtyard43() -> void:
	var leaf := SphereMesh.new()
	leaf.radius = 0.5
	leaf.height = 1.0
	leaf.radial_segments = 8
	leaf.rings = 4
	_furniture_meshes["courtyard_leaf"] = leaf
	# Low paving overlays the existing continuous walkable courtyard surface.
	for i: int in 26:
		var z := 11.0 + float(i) * 2.0
		_courtyard_piece43(Vector3(0, 0.075, z), Vector3(5.8, 0.03, 1.94), "warm", "avenue", false)
		for side: float in [-1.0, 1.0]:
			_courtyard_piece43(Vector3(side * 3.0, 0.08, z), Vector3(0.14, 0.04, 1.94), "ochre", "avenue_edge", false)
	for side: float in [-1.0, 1.0]:
		for i: int in 6:
			_courtyard_piece43(Vector3(side * (4.0 + i * 2.0), 0.075, 32),
				Vector3(1.94, 0.03, 3.6), "warm", "side_path", false)
	# A true open stone ring, not a solid invisible cylinder inside the well.
	var well := Vector3(-18.0, 0.07, 32.0)
	_courtyard_piece43(well + Vector3(0, 0.035, 0), Vector3(2.95, 0.035, 2.95), "dark", "well_depth", false, Vector3.ZERO, "disk")
	for row: int in 3:
		for segment: int in 12:
			var angle := TAU * (float(segment) + float(row % 2) * 0.5) / 12.0
			var radial := Vector3(sin(angle), 0, cos(angle))
			_courtyard_piece43(well + radial * 1.65 + Vector3.UP * (0.20 + row * 0.38),
				Vector3(0.93, 0.38, 0.48), "warm" if row == 1 else "cold", "well_ring", true, Vector3(0, angle, 0))
	for segment: int in 12:
		var angle := TAU * float(segment) / 12.0
		_courtyard_piece43(well + Vector3(sin(angle) * 1.65, 1.22, cos(angle) * 1.65),
			Vector3(0.99, 0.18, 0.65), "stone", "well_cap", true, Vector3(0, angle, 0))
	for side: float in [-1.0, 1.0]:
		_courtyard_piece43(well + Vector3(side * 1.8, 1.6, 0), Vector3(0.22, 3.2, 0.24), "wood", "well_post")
	var well_beam := _courtyard_piece43(well + Vector3(0, 3.12, 0), Vector3(3.82, 0.22, 0.30), "wood_alt", "well_crossbeam")
	var rope := _courtyard_piece43(well + Vector3(0, 2.12, 0), Vector3(0.045, 1.82, 0.045), "linen", "well_rope", false)
	var bucket := _courtyard_piece43(well + Vector3(0, 1.12, 0), Vector3(0.44, 0.32, 0.44), "wood", "well_bucket", true, Vector3.ZERO, "turned")
	var fittings: Array[int] = []
	for height: float in [1.02, 1.22]:
		fittings.append(_courtyard_piece43(well + Vector3(0, height, 0), Vector3(0.46, 0.045, 0.46), "iron", "bucket_band", false, Vector3.ZERO, "disk"))
	_courtyard_dependents43[bucket] = fittings
	_courtyard_dependents43[well_beam] = [rope, bucket]
	# Benches have four feet meeting the seat; their back does not float behind it.
	for x: float in [-24, -12, 13, 23]:
		var bench := Vector3(x, 0.07, 22)
		var seat := _courtyard_piece43(bench + Vector3(0, 0.62, 0), Vector3(3.0, 0.18, 0.72), "wood", "bench_seat")
		for side: float in [-1, 1]:
			for depth: float in [-0.24, 0.24]:
				_courtyard_piece43(bench + Vector3(side * 1.13, 0.265, depth), Vector3(0.20, 0.53, 0.20), "wood_alt", "bench_leg")
			_courtyard_piece43(bench + Vector3(side * 1.13, 1.03, 0.30), Vector3(0.16, 0.82, 0.16), "wood_alt", "bench_backpost")
		_courtyard_piece43(bench + Vector3(0, 1.23, 0.30), Vector3(3.0, 0.34, 0.14), "wood", "bench_back")
		var bench_parts: Array[int] = []
		for index: int in range(seat + 1, _cells.size()): bench_parts.append(index)
		_courtyard_dependents43[seat] = bench_parts
	# Two grounded supply shelters sit inside the courtyard beside the keep.
	# The central avenue, stair approaches and exterior siege field stay open.
	for side: float in [-1, 1]:
		var stall := Vector3(side * 26.0, 0.07, 12.0)
		for sx: float in [-1, 1]:
			for sz: float in [-1, 1]:
				_courtyard_piece43(stall + Vector3(sx * 3.0, 1.75, sz * 2.0), Vector3(0.24, 3.5, 0.24), "wood_alt", "stall_post")
			_courtyard_piece43(stall + Vector3(0, 3.5, sx * 2.0), Vector3(6.24, 0.22, 0.24), "wood", "stall_beam")
			for stripe: int in 10:
				var roof_material := "linen" if stripe % 3 == 0 else ("velvet" if side < 0 else "ochre")
				var roof := _courtyard_piece43(stall + Vector3(sx * 1.57, 3.91, -2.07 + stripe * 0.46), Vector3(3.35, 0.16, 0.46),
					roof_material, "stall_roof", true, Vector3(0, 0, -sx * 0.22))
				var fringe := _courtyard_piece43(stall + Vector3(sx * 3.15, 3.43, -2.07 + stripe * 0.46),
					Vector3(0.10, 0.30 if stripe % 2 == 0 else 0.23, 0.45), roof_material, "stall_valance", false)
				_courtyard_dependents43[roof] = [fringe]
			for depth: float in [-2.0, 2.0]:
				_courtyard_piece43(stall + Vector3(sx * 2.65, 3.04, depth), Vector3(0.14, 1.10, 0.16), "wood", "stall_brace", true, Vector3(0,0,-sx * .72))
		_courtyard_piece43(stall + Vector3(0, 4.26, 0), Vector3(0.20, 0.20, 4.68), "wood_alt", "stall_ridge")
		for sx: float in [-1, 1]:
			_courtyard_piece43(stall + Vector3(sx * 3.0, 3.52, 0), Vector3(0.22, 0.22, 4.3), "wood", "stall_eave")
		# Rear counter, with a full-width brace between four short supports.
		_courtyard_piece43(stall + Vector3(0, 1.0, -1.2), Vector3(5.0, 0.16, 1.1), "wood", "counter")
		for sx: float in [-1, 1]:
			for dz: float in [-0.36, 0.36]:
				_courtyard_piece43(stall + Vector3(sx * 2.12, 0.46, -1.2 + dz), Vector3(0.20, 0.92, 0.20), "wood_alt", "counter_leg")
		for crate: int in 3:
			var at := stall + Vector3(-1.7 + crate * 1.55, 1.38, -1.2)
			var crate_index := _courtyard_piece43(at, Vector3(1.02, 0.60, 0.82), "wood_alt", "supply_crate")
			var bands: Array[int] = []
			for band: float in [-0.32, 0.32]:
				bands.append(_courtyard_piece43(at + Vector3(band, 0.31, 0), Vector3(0.07, 0.035, 0.85), "iron", "crate_band", false))
				bands.append(_courtyard_piece43(at + Vector3(band, 0, 0.42), Vector3(0.07, 0.60, 0.04), "iron", "crate_band", false))
			_courtyard_dependents43[crate_index] = bands
	# Four planted islands break the huge paved plane without narrowing the main route.
	for x: float in [-23, 23]:
		for z: float in [38, 49]:
			var planter := Vector3(x, 0.07, z)
			var plinth := _courtyard_piece43(planter + Vector3(0, .16, 0), Vector3(5.8,.32,4.2), "warm", "planter_base")
			_courtyard_piece43(planter + Vector3(0,.34,0), Vector3(5.42,.06,3.82), "dark", "planter_soil", false)
			for side: float in [-1,1]:
				_courtyard_piece43(planter + Vector3(side * 2.8,.48,0),Vector3(.22,.36,4.2),"stone","planter_rim")
				_courtyard_piece43(planter + Vector3(0,.48,side * 2.0),Vector3(5.8,.36,.22),"stone","planter_rim")
			var trunk := _courtyard_piece43(planter + Vector3(0,2.12,0), Vector3(.48,3.5,.48), "wood_alt", "tree_trunk", true, Vector3.ZERO, "turned")
			var canopy: Array[int] = []
			for side: float in [-1,1]:
				canopy.append(_courtyard_piece43(planter + Vector3(side * .52,3.25,0),Vector3(.20,1.5,.20),"wood_alt","tree_branch",false,Vector3(0,0,-side * .7),"turned"))
				canopy.append(_courtyard_piece43(planter + Vector3(side * .94,4.35,.12),Vector3(2.8,2.6,2.8),"grass","tree_crown",false,Vector3.ZERO,"courtyard_leaf"))
			canopy.append(_courtyard_piece43(planter + Vector3(0,5.35,-.2),Vector3(2.65,2.8,2.65),"grass","tree_crown",false,Vector3.ZERO,"courtyard_leaf"))
			_courtyard_dependents43[trunk] = canopy
			for side: float in [-1,1]:
				for i: int in 4:
					_courtyard_piece43(planter+Vector3(-1.8+i*1.2,.68,side*1.28),Vector3(.75,.68,.75),"grass","low_shrub",false,Vector3.ZERO,"courtyard_leaf")
			var planter_parts: Array[int] = []
			for index: int in range(plinth + 1, _cells.size()): planter_parts.append(index)
			_courtyard_dependents43[plinth] = planter_parts


## Damage and collision use the same live masonry, including projecting stonework.
func _wall_masonry55(cell: Dictionary) -> bool:
	var group: String = cell.get("group", "")
	if group.begins_with("keep_floor") or group.begins_with("keep_runner"): return false
	if cell.get("material", "") not in ["stone", "warm", "cold", "dark", "ochre"]: return false
	for prefix: String in ["north", "south", "east", "west", "tower", "gate", "entrance",
			"keep", "corner", "curtain", "wall_arcade", "stairs_", "stair_landing",
			"room_wall_pier", "room_pier_cap", "room_vault"]:
		if group.begins_with(prefix): return true
	return false

func _cell_bounds55(cell: Dictionary) -> AABB:
	var size: Vector3 = cell["size"]
	return Transform3D(Basis.from_euler(cell["rotation"]), cell["at"]) * AABB(-size * 0.5, size)

func _cell_distance55(cell: Dictionary, at: Vector3) -> float:
	var local_hit: Vector3 = Basis.from_euler(cell["rotation"]).transposed() * (at - (cell["at"] as Vector3))
	var half: Vector3 = (cell["size"] as Vector3) * 0.5
	if cell.get("shape", "box") == "tower_floor55":
		return Vector2(maxf(Vector2(local_hit.x, local_hit.z).length() - half.x, 0.0),
			maxf(absf(local_hit.y) - half.y, 0.0)).length()
	if cell.get("shape", "box") == "tower_roof55":
		var p := Vector2(Vector2(local_hit.x, local_hit.z).length(), local_hit.y)
		var top_radius := half.x * 0.8 / (TOWER_RADIUS + 0.4)
		var radius_at_y := lerpf(half.x, top_radius, clampf((p.y + half.y) / (half.y * 2.0), 0.0, 1.0))
		if absf(p.y) <= half.y and p.x <= radius_at_y: return 0.0
		var profile: Array[Vector2] = [Vector2(0, -half.y), Vector2(half.x, -half.y),
			Vector2(top_radius, half.y), Vector2(0, half.y)]
		var distance := INF
		for i: int in 3:
			var segment := profile[i + 1] - profile[i]
			var closest := profile[i] + segment * clampf((p - profile[i]).dot(segment) / segment.length_squared(), 0.0, 1.0)
			distance = minf(distance, p.distance_to(closest))
		return distance
	return (local_hit - local_hit.clamp(-half, half)).length()

func _ensure_masonry_shape55(index: int) -> void:
	if _masonry_shapes55.has(index) or _merlon_collision.has(index) or _courtyard_shapes43.has(index): return
	var cell: Dictionary = _cells[index]
	var group: String = cell.group
	if _stair_step_collision.has("%s:%d" % [group, int(cell.row)]): return
	var at: Vector3 = cell.at
	var key := "%d|%d|%d" % [int(floor(at.x / SPATIAL_STEP)), int(floor(at.y / SPATIAL_STEP)), int(floor(at.z / SPATIAL_STEP))]
	var body: StaticBody3D = _masonry_bodies55.get(key)
	if not is_instance_valid(body):
		body = StaticBody3D.new()
		body.name = "Masonry55_%d" % _masonry_bodies55.size()
		body.collision_layer = 1
		body.collision_mask = 1
		body.set_meta("castle_brick", true)
		body.set_meta("surface", "stone")
		add_child(body)
		_masonry_bodies55[key] = body
	var shape := CollisionShape3D.new()
	shape.position = at
	shape.rotation = cell.rotation
	var size: Vector3 = cell.size
	if cell.get("shape", "box") == "tower_floor55":
		var cylinder := CylinderShape3D.new()
		cylinder.radius = size.x * 0.5
		cylinder.height = size.y
		shape.shape = cylinder
	elif cell.get("shape", "box") == "tower_roof55":
		var mesh: Mesh = _furniture_meshes["tower_roof55"]
		shape.shape = mesh.create_convex_shape()
		shape.scale = size
	else:
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
	body.add_child(shape)
	_masonry_shapes55[index] = shape

func _build_masonry_hits55() -> void:
	# Core walls retain their cheap coarse panels until damaged. Projecting trim
	# and columns need real surface hits even where no panel exists behind them.
	for index: int in _cells.size():
		var cell: Dictionary = _cells[index]
		if not _wall_masonry55(cell): continue
		if cell.group in ["north", "south", "east", "west", "tower", "keep", "gatehouse", "keep_partition"]: continue
		_ensure_masonry_shape55(index)

func _sync_masonry_collision55() -> void:
	if _masonry_changed55.is_empty(): return
	var dirty := AABB()
	var regions: Array[AABB] = []
	var first := true
	for index: int in _masonry_changed55:
		var bounds: AABB = _cells[index].bounds55
		regions.append(bounds.grow(0.04))
		dirty = bounds if first else dirty.merge(bounds)
		first = false
	_masonry_changed55.clear()
	dirty = dirty.grow(0.04)
	for section: Dictionary in _wall_collision:
		if not section.alive: continue
		var body: StaticBody3D = section.body
		if not is_instance_valid(body): continue
		if body.get_meta("castle_furnishing", false) or body.get_meta("castle_keep_floor", false): continue
		var size: Vector3 = section.size
		var local_transform: Transform3D = body.transform
		var bounds: AABB = local_transform * AABB(-size * 0.5, size)
		if not bounds.intersects(dirty): continue
		# Simultaneous distant collapses must not refine every untouched wall in
		# the large box between them. Only actual damaged volumes own this work.
		var touched := false
		for region: AABB in regions:
			if bounds.intersects(region): touched = true; break
		if not touched: continue
		# Keep every surviving layer hittable. A second stone must strike the rear
		# skin instead of crossing a visual wall whose whole panel was disabled.
		for index: int in _indices_box(bounds.position, bounds.end):
			var cell: Dictionary = _cells[index]
			if not cell.alive or (not _wall_masonry55(cell) and cell.group != "bridge"): continue
			if not (cell.bounds55 as AABB).intersects(bounds): continue
			_ensure_masonry_shape55(index)
		section.alive = false
		body.collision_layer = 0
		body.collision_mask = 0
