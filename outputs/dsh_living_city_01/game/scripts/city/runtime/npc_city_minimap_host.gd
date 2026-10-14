extends CanvasLayer
## City minimap host: real living-city scene nodes -> walk_minimap providers.
##
## The five component scripts under res://addons/walk_minimap/ are used verbatim
## and were not modified. This host only supplies the three provider callables
## (player pose, world bounds, real object rows), gates player input while the
## map is expanded, prints the DSH_MINIMAP telemetry line and owns disposal.
##
## Objects come from the actual instantiated city nodes: Node3D children of the
## city root carrying meta "source_id" without meta "source_index" (the collision
## bodies carry the latter) and declared by the city root's block dictionary
## (buildings/decor). Positions are those nodes' global_position; assetId/role are
## read from the block dictionary the scene already parsed, so no JSON is read
## here. Unknown assetIds map to the source "object" kind.
##
## Main thread only. configure() is idempotent and dispose() is safe on exit.
const Minimap = preload("res://addons/walk_minimap/minimap_control.gd")
const Catalog = preload("res://addons/walk_minimap/map_catalog.gd")

const TELEMETRY_PREFIX := "DSH_MINIMAP"
const PROBE_PREFIX := "DSH_MINIMAP_PROBE"
## Opt-in QA seam: --minimap-expanded-probe drives one full capture -> expanded
## -> guard -> collapse -> restore cycle and prints the observed player capture
## state. It exists because a headless run produces no real input events.
const EXPANDED_PROBE_ARG := "--minimap-expanded-probe"
## Keeps the extreme houses/lamps off the picture frame of the expanded fit.
const BOUNDS_MARGIN_M := 20.0

## exact assetId -> source map kind (27-category catalog in map_catalog.gd).
const ASSET_KINDS: Dictionary = {
	"print_shop": "printshop",
	"gun_shop": "gunshop",
	"pawnshop": "pawnshop",
	"nightclub": "nightclub",
	"strip_club": "stripclub",
	"bookmaker": "bookmaker",
	"hospital": "hospital",
	"civic_hall": "civic",
	"bank_small_shell_v1": "bank",
	"bank_medium_shell_v1": "bank",
	"bank_large_shell_v1": "bank",
	"fountain_central": "fountain",
	"fountain_district": "fountain",
	"fountain_park": "fountain",
	"bench_civic": "bench",
	"bin_civic": "object",
	"planter_round": "object",
	"glass_pavilion_small_v1": "building",
	"compact_podium_glass_tower_v1": "building",
}
## assetId substrings for the residence family (many authored shells).
const RESIDENCE_ASSET_MARKERS: Array[String] = [
	"townhouse", "walkup", "apartment", "cottage", "chalet", "crosswing",
	"bungalow", "orchard", "_house_",
]
const ROLE_KINDS: Dictionary = {
	"residence": "residential",
	"civic_building": "civic",
	"bank_shell": "bank",
	"glass_retail": "building",
	"glass_tower": "building",
	"roadside_lamp": "lamp",
	"decor": "object",
}
## Human place names; everything else falls back to the catalog kind name.
const ASSET_NAMES: Dictionary = {
	"print_shop": "Типография",
	"gun_shop": "Оружейный магазин",
	"pawnshop": "Ломбард",
	"nightclub": "Ночной клуб",
	"strip_club": "Стрип-клуб",
	"bookmaker": "Букмекер",
	"hospital": "Больница",
	"civic_hall": "Общественный зал",
	"bank_small_shell_v1": "Банк",
	"bank_medium_shell_v1": "Банк",
	"bank_large_shell_v1": "Банк",
	"glass_pavilion_small_v1": "Стеклянный павильон",
	"compact_podium_glass_tower_v1": "Стеклянная башня",
	"fountain_central": "Фонтан",
	"fountain_district": "Фонтан",
	"fountain_park": "Фонтан",
	"bench_civic": "Скамейка",
	"bin_civic": "Урна",
	"planter_round": "Клумба",
}

var status := "created"
var objects_count := 0

var _city: Node3D
var _player: Node3D
var _map: Control
var _objects: Array = []
var _bounds: Dictionary = {}
var _records: Dictionary = {}
var _configured := false
var _disposed := false
var _expanded := false
var _restore_captured := false
var _probe_pending := false
var _probe_frames := 0

func configure(city: Node3D, player: Node3D) -> bool:
	if _disposed:
		status = "disposed"
		return false
	if _configured:
		return true
	if not is_inside_tree():
		status = "host_out_of_tree"
		return false
	if not is_instance_valid(city) or not is_instance_valid(player):
		status = "scene_nodes_missing"
		return false
	_city = city
	_player = player
	_collect_records()
	_objects = _collect_objects()
	objects_count = _objects.size()
	_bounds = _compute_bounds(_objects)
	if _objects.is_empty() or not _bounds_valid():
		status = "world_unavailable"
		return false
	_map = Minimap.new()
	_map.name = "WalkMinimap"
	add_child(_map)
	if not _map.is_node_ready():
		_map.queue_free()
		_map = null
		status = "map_not_ready"
		return false
	if not _map.set_providers(Callable(self, "_position_state"), Callable(self, "_bounds_provider"), Callable(self, "_objects_provider")):
		_map.queue_free()
		_map = null
		status = "providers_rejected"
		return false
	_map.expanded_changed.connect(_on_expanded_changed)
	_probe_pending = OS.get_cmdline_user_args().has(EXPANDED_PROBE_ARG)
	set_process(true)
	_configured = true
	status = "ready"
	print(TELEMETRY_PREFIX, " ready=true objects=", objects_count, " bounds=", _bounds_text())
	return true

func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	set_process(false)
	# Teardown only ever releases: re-capturing the mouse while the owner is
	# already leaving would fight preview_player.gd's own _exit_tree release.
	_probe_pending = false
	_expanded = false
	_restore_captured = false
	_configured = false
	if is_instance_valid(_map):
		if _map.expanded_changed.is_connected(_on_expanded_changed):
			_map.expanded_changed.disconnect(_on_expanded_changed)
		# Drop the host callables before the Control leaves the tree.
		_map.set_providers(Callable(), Callable(), Callable())
		_map.queue_free()
	_map = null
	_objects = []
	_records = {}
	status = "disposed"

func get_status() -> Dictionary:
	return {
		"status": status,
		"objects": objects_count,
		"bounds": _bounds.duplicate(),
		"expanded": _expanded,
	}

func _exit_tree() -> void:
	dispose()

func _process(_delta: float) -> void:
	if _probe_pending:
		_advance_expanded_probe()
	# The map's Control consumes its own clicks, but a click on the 3D viewport
	# outside the map would re-capture the player through preview_player.gd's own
	# left-click branch. Re-assert the blocked state instead of adding new input.
	if not _expanded or not is_instance_valid(_player):
		return
	if _player_captured():
		_player.set_mouse_captured(false)

func _advance_expanded_probe() -> void:
	if not is_instance_valid(_map) or not is_instance_valid(_player):
		_probe_pending = false
		return
	_probe_frames += 1
	match _probe_frames:
		10:
			_player.set_mouse_captured(true)
			print(PROBE_PREFIX, " captured_before_expand=", _player_captured())
		30:
			_map.set_expanded(true)
			print(PROBE_PREFIX, " captured_after_expand=", _player_captured())
		60:
			# preview_player.gd gates its movement axes on the same flag, so a zero
			# vector here is the observed standstill while the map is expanded.
			print(PROBE_PREFIX, " move_axes=", Input.get_vector("preview_move_left", "preview_move_right", "preview_move_forward", "preview_move_back"), " captured_while_expanded=", _player_captured())
		90:
			_map.set_expanded(false)
			print(PROBE_PREFIX, " captured_after_collapse=", _player_captured())
		95:
			_player.set_mouse_captured(false)
			print(PROBE_PREFIX, " finished captured=", _player_captured(), " status=", status, " objects=", objects_count)
			_probe_pending = false

func _on_expanded_changed(value: bool) -> void:
	_expanded = value
	if value:
		_restore_captured = _player_captured()
		if is_instance_valid(_player):
			# preview_player.gd:set_mouse_captured(false) is the existing lawful
			# release: it clears _free_mouse_look, held actions and weapon controls.
			_player.set_mouse_captured(false)
	else:
		if _restore_captured and is_instance_valid(_player):
			_player.set_mouse_captured(true)
		_restore_captured = false
	print(TELEMETRY_PREFIX, " expanded=", value)

func _player_captured() -> bool:
	if not is_instance_valid(_player):
		return false
	var free_look: Variant = _player.get("_free_mouse_look")
	return free_look is bool and bool(free_look)

func _position_state() -> Dictionary:
	var state: Dictionary = {"position": {"x": 0.0, "z": 0.0}, "yaw": 0.0}
	if not is_instance_valid(_player):
		return state
	var at: Vector3 = _player.global_position
	if not at.is_finite():
		return state
	return {"position": {"x": at.x, "z": at.z}, "yaw": _player_yaw()}

func _player_yaw() -> float:
	var heading: Variant = _player.get("_heading")
	var value := 0.0
	if heading is float or heading is int:
		value = float(heading)
	else:
		value = _player.global_rotation.y
	# preview_player.gd heading h: forward = (-sin h, -cos h); Walk yaw = atan2(x, z).
	return wrapf(value + PI, -PI, PI)

func _bounds_provider() -> Dictionary:
	return _bounds

func _objects_provider() -> Array:
	return _objects

func _collect_records() -> void:
	_records = {}
	var block: Variant = _city.get("_block")
	if not block is Dictionary:
		return
	for section: String in ["buildings", "decor"]:
		var rows: Variant = block.get(section, [])
		if not rows is Array:
			continue
		for row: Variant in rows:
			if row is Dictionary and row.has("id"):
				_records[str(row["id"])] = row

func _collect_objects() -> Array:
	var result: Array = []
	for child: Node in _city.get_children():
		if not (child is Node3D):
			continue
		if child.has_meta("source_index"):
			continue # CollisionStaticBody of an asset, not the asset itself.
		if not child.has_meta("source_id"):
			continue
		var node: Node3D = child as Node3D
		var source_id: String = str(child.get_meta("source_id", ""))
		if source_id.is_empty():
			continue
		var record: Dictionary = _records.get(source_id, {})
		# With the city block available, only declared building/decor nodes become
		# map objects. Unrelated nodes that merely carry meta "source_id" (interior
		# or transport bodies) are excluded instead of becoming anonymous decor.
		if not _records.is_empty() and record.is_empty():
			continue
		var at: Vector3 = node.global_position
		if not at.is_finite():
			continue
		var asset_id: String = str(record.get("assetId", ""))
		var role: String = str(record.get("role", ""))
		var kind: String = _kind_for(asset_id, role, source_id)
		result.append({
			"id": source_id,
			"buildingId": source_id,
			"name": _name_for(kind, asset_id),
			"kind": kind,
			"x": at.x,
			"z": at.z,
		})
	return result

func _kind_for(asset_id: String, role: String, source_id: String) -> String:
	if ASSET_KINDS.has(asset_id):
		return str(ASSET_KINDS[asset_id])
	if asset_id.begins_with("lamp_"):
		return "lamp"
	if asset_id.contains("bank"):
		return "bank"
	for marker: String in RESIDENCE_ASSET_MARKERS:
		if asset_id.contains(marker):
			return "residential"
	if ROLE_KINDS.has(role):
		return str(ROLE_KINDS[role])
	# Node-name fallback for decor rows whose record is unavailable.
	if source_id.begins_with("LAMP-"):
		return "lamp"
	if source_id.contains("-BENCH-"):
		return "bench"
	if source_id.contains("-FOUNTAIN"):
		return "fountain"
	return "object"

func _name_for(kind: String, asset_id: String) -> String:
	if ASSET_NAMES.has(asset_id):
		return str(ASSET_NAMES[asset_id])
	return Catalog.kind_name(kind)

func _compute_bounds(objects: Array) -> Dictionary:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for object: Variant in objects:
		if not object is Dictionary:
			continue
		var x: float = float(object.get("x", 0.0))
		var z: float = float(object.get("z", 0.0))
		min_x = minf(min_x, x)
		max_x = maxf(max_x, x)
		min_z = minf(min_z, z)
		max_z = maxf(max_z, z)
	if not (is_finite(min_x) and is_finite(max_x) and is_finite(min_z) and is_finite(max_z)):
		return {}
	if max_x <= min_x or max_z <= min_z:
		return {}
	return {
		"minX": min_x - BOUNDS_MARGIN_M,
		"maxX": max_x + BOUNDS_MARGIN_M,
		"minZ": min_z - BOUNDS_MARGIN_M,
		"maxZ": max_z + BOUNDS_MARGIN_M,
	}

func _bounds_valid() -> bool:
	if not _bounds.has("minX"):
		return false
	return float(_bounds["maxX"]) > float(_bounds["minX"]) and float(_bounds["maxZ"]) > float(_bounds["minZ"])

func _bounds_text() -> String:
	if not _bounds_valid():
		return "unavailable"
	return "[%.1f, %.1f, %.1f, %.1f]" % [float(_bounds["minX"]), float(_bounds["minZ"]), float(_bounds["maxX"]), float(_bounds["maxZ"])]
