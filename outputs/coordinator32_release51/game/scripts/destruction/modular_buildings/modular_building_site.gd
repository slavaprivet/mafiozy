extends RefCounted
## Shared instantiator for the three ported modular destructible "boxes"
## (restaurant pizza, hospital structural01, small bank).
##
## Scope, deliberately narrow: this class only places geometry, collision, the
## external soil the modular site requires, and the site's own door/glazing
## owners. It adds no gameplay, no NPC admission, no C4 and no damage policy.
##
## Cold path only. The ported site builds every authored section in _ready(), so
## prepare() must not be called on a frame that already has a budget of its own;
## measure it and place the building during setup, exactly like palazzo_host.
##
## Ported from outputs/buildings4_* (see MAFIOZY_BUILDINGS_PORT.md). Nothing in
## scripts/destruction/palazzo/** or scripts/destruction/modular30/** is touched.

const SCHEMA := "mafiozi.modular_building_site/v1"
const SITE_SCRIPT := preload("res://scripts/destruction/modular_buildings/modular_site.gd")

## DSH_CITYTOWN damage wiring (2026-10-14). Opt-in, default OFF: without
## `--city-town-damage=1` this file creates nothing, adds no node and prints nothing,
## so every existing/default run keeps its exact previous scene and log. With the flag
## the site gets the two missing halves of the accepted Palazzo contract: a native
## weapon damage owner (`modular_damage_owner.gd`, same bridge as `palazzo_host.gd`)
## and a C4 target registration (`modular_c4_site_registry.gd`). See
## MAFIOZY_BUILDING_DAMAGE.md. The reference building is the restaurant only; the
## hospital and the small bank keep their previous (non-destructible) behaviour.
const DamageOwner = preload("res://scripts/destruction/modular_buildings/modular_damage_owner.gd")
const DAMAGE_OWNER_PROFILES := ["template:business:pizza"]

## The recipe owns the soil position and thickness: `external_soil_required.at`
## is the declared centre and `.size.y` the declared thickness. Do not invent a
## convention here — restaurant/hospital declare a street-level slab at
## y = -0.435 (top -0.31, resting under their foundation), while the small bank
## declares a deep slab at y = -4.035 because its authored basement reaches
## y = -3.91. These two constants are only the fallback when a recipe declares
## no `at`.
const FALLBACK_SOIL_TOP_Y := -0.31
const FALLBACK_SOIL_THICKNESS := 0.25

var _node: Node3D = null
var _soil: StaticBody3D = null
var _damage_owner: Node = null
var _recipe: Dictionary = {}
var _recipe_path := ""
var _status := "not_prepared"
var _reason := ""
var _stats: Dictionary = {}
var _prepare_ms := 0.0
var _terrain: Dictionary = {}

func status() -> String:
	return _status

func reason() -> String:
	return _reason

func stats() -> Dictionary:
	return _stats.duplicate(true)

func prepare_ms() -> float:
	return _prepare_ms

func recipe_path() -> String:
	return _recipe_path

func profile_id() -> String:
	return str(_recipe.get("profile_id", ""))

func source_id() -> String:
	return str(_recipe.get("source_id", ""))

func node() -> Node3D:
	return _node

func soil() -> StaticBody3D:
	return _soil

## Entry point. parent must already be inside the tree; the site's _ready() runs
## on add_child and its physical support is configured right after, because the
## modular host refuses to become ready without explicit external soil.
func prepare(parent: Node3D, origin: Vector3, yaw_deg: float) -> Dictionary:
	var started := Time.get_ticks_usec()
	if _node != null:
		return _fail("already_prepared")
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return _fail("parent_not_in_tree")
	if not origin.is_finite() or not is_finite(yaw_deg):
		return _fail("invalid_placement")
	var loaded := _load_recipe()
	if not loaded.get("ok", false):
		return loaded
	var built := _create_soil(parent, origin, yaw_deg)
	if not built.get("ok", false):
		return built
	var site: Node3D = SITE_SCRIPT.new()
	if site == null:
		return _fail("site_instance")
	# configure() must happen before add_child: the site refuses a recipe after
	# it has entered the tree.
	var configured: Dictionary = site.configure(_recipe)
	if not configured.get("ok", false):
		site.free()
		return _fail("site_configure:" + str(configured.get("reason", "unknown")))
	site.name = "ModularBuilding:" + source_id()
	# DSH_CITYTOWN: `palazzo_glazing.configure()` (called from the site's own _ready)
	# captures `_site_frame` and `_current()` then requires
	# `site.global_transform == _site_frame` for the rest of the generation. With the
	# flag the final frame is therefore assigned BEFORE add_child, so the captured
	# frame is the real one and the authored window panes survive; measured proof in
	# MAFIOZY_BUILDING_DAMAGE.md (restaurant at (27.6,0,50.6) kept `glazing:false`
	# while the same site placed at the origin kept 53 live panes). Without the flag
	# the previous order is preserved exactly.
	var frame := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), origin)
	if DamageOwner.flag_present():
		site.transform = parent.global_transform.affine_inverse() * frame
	parent.add_child(site)
	site.global_transform = frame
	var ground: Array[StaticBody3D] = [_soil]
	if site.has_method("attach_native_ground"):
		var attached: Dictionary = site.attach_native_ground(ground)
		if not attached.get("ok", false):
			site.queue_free()
			_node = null
			return _fail("native_ground:" + str(attached.get("reason", "unknown")))
	else:
		site.queue_free()
		return _fail("site_api_missing_attach_native_ground")
	_node = site
	_stats = _collect_stats(site)
	_status = str(_stats.get("status", "unknown"))
	if bool(_recipe.get("terrain_cutouts", []).is_empty()):
		_terrain = {"required": false}
	else:
		_terrain = site.verify_terrain_clearance() if site.has_method("verify_terrain_clearance") else {"required": true, "ok": false, "reason": "verify_api_missing"}
	_reason = ""
	_prepare_ms = float(Time.get_ticks_usec() - started) / 1000.0
	var damage_owner: Dictionary = _wire_damage_owner(parent, site)
	_stats["damage_owner"] = damage_owner.duplicate(true)
	return {
		"ok": _status == "intact" or _status == "awaiting_native_basement_clearance",
		"reason": _reason,
		"node": _node,
		"status": _status,
		"source_id": source_id(),
		"profile_id": profile_id(),
		"origin": origin,
		"yaw_deg": yaw_deg,
		"prepare_ms": _prepare_ms,
		"bounds": _recipe.get("bounds", {}),
		"dimensions": _recipe.get("dimensions", []),
		"stats": _stats,
		"terrain": _terrain,
		"soil": _soil,
		"damage_owner": damage_owner,
	}

## DSH_CITYTOWN: the accepted Palazzo damage owner needs a live native weapon host,
## which main.gd creates AFTER this instantiator runs (main.gd:295 vs :214). The owner
## therefore attaches now and performs its own bounded late bind. Disabled by default.
func _wire_damage_owner(parent: Node3D, site: Node3D) -> Dictionary:
	if not DamageOwner.flag_present():
		return {"ok": true, "enabled": false, "status": "disabled_no_flag", "flag": DamageOwner.FLAG, "allowed_profiles": DAMAGE_OWNER_PROFILES}
	if not DAMAGE_OWNER_PROFILES.has(profile_id()):
		return {"ok": true, "enabled": false, "status": "disabled_profile", "profile_id": profile_id(), "allowed_profiles": DAMAGE_OWNER_PROFILES}
	if is_instance_valid(_damage_owner):
		return {"ok": true, "enabled": true, "status": "already_wired", "source_id": source_id()}
	var owner_node: Node = DamageOwner.new()
	owner_node.name = "ModularDamageOwner:" + source_id().validate_node_name()
	parent.add_child(owner_node)
	var attached: Dictionary = owner_node.call("attach", parent, site, source_id(), profile_id())
	if not attached.get("ok", false):
		owner_node.queue_free()
		return {"ok": false, "enabled": true, "status": "attach_failed", "detail": attached}
	_damage_owner = owner_node
	return {"ok": true, "enabled": true, "status": "owner_attached", "source_id": source_id(), "profile_id": profile_id(), "node": str(owner_node.name), "flag": DamageOwner.FLAG}

func damage_owner() -> Node:
	return _damage_owner

func damage_status() -> Dictionary:
	if is_instance_valid(_damage_owner) and _damage_owner.has_method("snapshot"):
		return _damage_owner.call("snapshot")
	return {"owner": "absent"}

func dispose() -> void:
	if is_instance_valid(_damage_owner):
		if _damage_owner.has_method("dispose"): _damage_owner.call("dispose")
		else: _damage_owner.queue_free()
	_damage_owner = null
	if _node != null and is_instance_valid(_node):
		_node.queue_free()
	_node = null
	if _soil != null and is_instance_valid(_soil):
		_soil.queue_free()
	_soil = null
	_status = "disposed"

func _fail(why: String) -> Dictionary:
	_status = "failed"
	_reason = why
	return {"ok": false, "reason": why, "node": null, "status": _status}

func _load_recipe() -> Dictionary:
	if _recipe_path.is_empty():
		return _fail("recipe_path_unset")
	if not FileAccess.file_exists(_recipe_path):
		return _fail("recipe_missing:" + _recipe_path)
	var text := FileAccess.get_file_as_string(_recipe_path)
	if text.is_empty():
		return _fail("recipe_unreadable:" + _recipe_path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return _fail("recipe_not_a_dictionary:" + _recipe_path)
	_recipe = parsed
	_recipe["_recipe_path"] = _recipe_path
	_recipe["_recipe_sha256"] = FileAccess.get_sha256(_recipe_path)
	return {"ok": true}

## The modular host refuses to become ready without explicit external native
## soil, and it validates that soil for real (space, collision layer, bounds).
## This creates exactly the slab the recipe asks for and nothing else.
## For a recipe with terrain_cutouts the slab is built as a ring so the authored
## basement volume is genuinely empty, which is what verify_terrain_clearance()
## then proves with its own physics query.
func _create_soil(parent: Node3D, origin: Vector3, yaw_deg: float) -> Dictionary:
	var requirement: Dictionary = _recipe.get("external_soil_required", {})
	var soil_size := _v3(requirement.get("size", []))
	if soil_size == Vector3.ZERO or not soil_size.is_finite():
		return _fail("external_soil_required_missing")
	var declared_at := _v3(requirement.get("at", []))
	var thickness := soil_size.y if soil_size.y > 0.0 else FALLBACK_SOIL_THICKNESS
	var centre_y := declared_at.y if declared_at.is_finite() and declared_at != Vector3.ZERO else FALLBACK_SOIL_TOP_Y - thickness * 0.5
	var soil := StaticBody3D.new()
	soil.name = "ModularExternalSoil:" + source_id()
	soil.collision_layer = 1
	soil.collision_mask = 1
	parent.add_child(soil)
	soil.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), origin)
	var boxes := _soil_boxes(soil_size, centre_y, thickness)
	if boxes.is_empty():
		soil.queue_free()
		return _fail("soil_box_plan_empty")
	for index in boxes.size():
		var row: Dictionary = boxes[index]
		var shape := BoxShape3D.new()
		shape.size = row.size
		var collision := CollisionShape3D.new()
		collision.name = "SoilBox%d" % index
		collision.shape = shape
		collision.position = row.at
		soil.add_child(collision)
	soil.set_meta("modular_soil_size", soil_size)
	soil.set_meta("modular_soil_boxes", boxes.size())
	soil.set_meta("modular_soil_centre_y", centre_y)
	_soil = soil
	return {"ok": true}

## One solid slab, or a four-piece ring around the authored basement rectangle.
func _soil_boxes(soil_size: Vector3, centre_y: float, thickness: float) -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []
	var half := soil_size * 0.5
	var cuts: Array = _recipe.get("terrain_cutouts", [])
	if cuts.is_empty():
		boxes.append({"size": Vector3(soil_size.x, thickness, soil_size.z), "at": Vector3(0, centre_y, 0)})
		return boxes
	# Authored cutout rect is [min_x, min_z, max_x, max_z] in the recipe's local frame.
	var rect: Array = cuts[0].get("rect", [])
	if rect.size() != 4:
		return boxes
	var cut_bottom := float(cuts[0].get("bottom", 0.0))
	var slab_top := centre_y + thickness * 0.5
	var slab_bottom := centre_y - thickness * 0.5
	# A basement slab that already lies below the excavation needs no ring: the
	# authored volume is empty by construction (this is the small bank case).
	if slab_top <= cut_bottom + 0.001:
		boxes.append({"size": Vector3(soil_size.x, thickness, soil_size.z), "at": Vector3(0, centre_y, 0)})
		return boxes
	var min_x := float(rect[0])
	var min_z := float(rect[1])
	var max_x := float(rect[2])
	var max_z := float(rect[3])
	if max_x - min_x <= 0.001 or max_z - min_z <= 0.001:
		return boxes
	var east_width := half.x - max_x
	if east_width > 0.001:
		boxes.append({"size": Vector3(east_width, thickness, soil_size.z), "at": Vector3(max_x + east_width * 0.5, centre_y, 0)})
	var west_width := min_x + half.x
	if west_width > 0.001:
		boxes.append({"size": Vector3(west_width, thickness, soil_size.z), "at": Vector3(min_x - west_width * 0.5, centre_y, 0)})
	var inner_width := max_x - min_x
	var north_depth := half.z - max_z
	if north_depth > 0.001:
		boxes.append({"size": Vector3(inner_width, thickness, north_depth), "at": Vector3((min_x + max_x) * 0.5, centre_y, max_z + north_depth * 0.5)})
	var south_depth := min_z + half.z
	if south_depth > 0.001:
		boxes.append({"size": Vector3(inner_width, thickness, south_depth), "at": Vector3((min_x + max_x) * 0.5, centre_y, min_z - south_depth * 0.5)})
	return boxes

## AABB of everything the site actually instantiated, plus the recipe's own
## declared bounds so both can be compared in the report.
func _collect_stats(site: Node3D) -> Dictionary:
	var out: Dictionary = {}
	if site.has_method("get_stats"):
		out = site.get_stats()
	# The site is a Node3D whose _ready() creates its own "ModularDestructible"
	# child. Measure that child, not the whole site subtree: the site also owns
	# FX/blast nodes whose AABB is not a building measurement.
	var measured: Node3D = site
	if site.has_method("get") and site.get("building") is Node3D:
		measured = site.get("building")
	var aabb := _node_aabb(measured)
	out["aabb"] = {"position": aabb.position, "size": aabb.size, "end": aabb.end, "measured_root": measured.name}
	out["collision_shapes"] = _count_nodes(measured, "CollisionShape3D")
	out["rigid_bodies"] = _count_nodes(measured, "RigidBody3D")
	out["mesh_instances"] = _count_nodes(measured, "MeshInstance3D")
	out["label3d"] = _count_nodes(measured, "Label3D")
	out["recipe_parts"] = int(_recipe.get("parts", []).size())
	out["recipe_rooms"] = int(_recipe.get("rooms", []).size())
	out["recipe_stair_routes"] = int(_recipe.get("stair_routes", []).size())
	out["soil_boxes"] = int(_soil.get_meta("modular_soil_boxes", 0)) if is_instance_valid(_soil) else 0
	out["recipe_bounds"] = _recipe.get("bounds", {})
	out["recipe_dimensions"] = _recipe.get("dimensions", [])
	out["soil_centre_y"] = float(_soil.get_meta("modular_soil_centre_y", 0.0)) if is_instance_valid(_soil) else 0.0
	return out

func _node_aabb(root: Node) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is VisualInstance3D:
			var visual := current as VisualInstance3D
			var box := visual.get_aabb()
			# A node with an unset/infinite bounds must not poison the merge.
			if box.size.is_finite() and box.size.length() < 1.0e7:
				var world := visual.global_transform * box
				if first:
					result = world
					first = false
				else:
					result = result.merge(world)
		for child: Node in current.get_children():
			stack.append(child)
	return result

func _count_nodes(root: Node, kind: String) -> int:
	var total := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current.is_class(kind):
			total += 1
		for child: Node in current.get_children():
			stack.append(child)
	return total

static func _v3(value: Variant) -> Vector3:
	if not value is Array or value.size() != 3:
		return Vector3.ZERO
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
