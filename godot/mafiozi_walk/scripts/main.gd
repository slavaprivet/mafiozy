extends Node3D
## First migration quarter: authored assets, walking and source printshop doors.

const PalazzoOnlyPreview = preload("res://scripts/palazzo_only_preview.gd")
const GameCursor = preload("res://scripts/ui/walk_cursor.gd")
const PlayerController = preload("res://scripts/preview_player.gd")
const BlockValidation = preload("res://scripts/preview_block_validation.gd")
const SurfaceMaterials = preload("res://scripts/preview_surface_materials.gd")
const PreviewPerfAdapter = preload("res://scripts/perf/preview_perf_adapter.gd")
const PrintshopInterior = preload("res://scripts/preview_printshop_interior.gd")
const WaterSurface = preload("res://scripts/preview_water_surface.gd")
const UpdatePanel = preload("res://scripts/preview_update_panel.gd")
const StaticBatch = preload("res://scripts/preview_static_batch.gd")
const PreviewTransport = preload("res://scripts/preview_transport.gd")
const PlayerImpactHost = preload("res://scripts/character_physics/player_impact_host.gd")
const PreviewBoundary = preload("res://scripts/preview_boundary.gd")
const PreviewPopulation = preload("res://scripts/preview_population.gd")
const PreviewMelee = preload("res://scripts/combat/preview_melee.gd")
const STATIC_RENDER_OWNER_IDS := [
	"REBUILD-VISUAL-old_town_narrow_townhouse_v1-013", "REBUILD-VISUAL-old_town_narrow_townhouse_v1-005",
	"REBUILD-VISUAL-gun_shop-001", "REBUILD-VISUAL-pawnshop-001",
	"REBUILD-VISUAL-old_town_narrow_townhouse_v1-004", "REBUILD-VISUAL-old_town_narrow_townhouse_v1-012",
	"REBUILD-VISUAL-old_town_narrow_townhouse_v1-007", "LAMP-1-83", "LAMP-15-78", "LAMP-19-97",
	"LAMP-21-84", "LAMP-29-79", "LAMP-30-98", "LAMP-9-102", "LAMP-9-84"
]
const PREVIEW_RUNTIME_REVISION := "s01-20261001-palazzo-frames45"
const PRINTSHOP_DATA_SHA256 := "958a2c2d8cbdc2b2e2e11a57e33bf9bf5a20ec334be8a8997bdad951f9f8086b"
const WATER_DATA_SHA256 := "ac70f924e1beef0f8501c48d09535a89d47effff014bf0f32b8abc72b3e3b824"
@export_file("*.json") var block_data_path: String = "res://data/block.json"
@export_file("*.json") var printshop_data_path: String = "res://data/printshop_interior.json"
@export_file("*.json") var water_data_path: String = "res://data/preview_water.json"
@export var preview_perf_enabled: bool = false
@export var preview_water_detail_enabled: bool = true
@export var preview_start_at_printshop: bool = true
@export var preview_static_batch_enabled: bool = false
@export var preview_transport_enabled: bool = true
@export var preview_start_at_vehicle: bool = true
@export var preview_residents_enabled: bool = true
@export var preview_final_dead_contact_enabled: bool = true
const FINAL_DEAD_CONTACT_LIMITS: Dictionary = {"max_impulse_ns": 3.0, "impulse_ns_per_mps": 1.0, "max_point_delta_energy_j": 1.5, "max_linear_speed_mps": 2.5, "max_angular_speed_rps": 15.0, "cooldown_ms": 160} # Bounded per-contact limits; original masses and joint constraints preserved.
var final_dead_contact_status := "disabled"
var final_dead_block_contract_status := "legacy_v1"
var _final_dead_block_requested := false
@export var preview_resident_walk_enabled: bool = true
@export var preview_melee_enabled: bool = true
@export var preview_weapons_enabled: bool = true
var preview_weapons: Node
var weapons_status := "disabled"
var preview_melee: Node
var melee_status := "disabled"
var preview_population: RefCounted
var preview_modular30: Node
var preview_palazzo: Node
var preview_c4: Node
var preview_c4_blast: Node
const PalazzoGround = preload("res://scripts/destruction/palazzo/palazzo_ground.gd")
var population_status := "disabled"
var preview_transport: Node3D
var preview_character_impacts: Node
var transport_status := "disabled"
var preview_dead := false
var preview_physics_fault := false
var static_batch_status: String = "disabled"
var static_batch_summary: Dictionary = {}
var _static_batch_lease: RefCounted
var _static_render_roots: Array[Node3D] = []
var water_status: String = "not_loaded"
var water_errors: PackedStringArray = []
var water_summary: Dictionary = {}
var _water_host: RefCounted
var _jump_surface_cells: PackedByteArray = PackedByteArray()
var _jump_surface_offsets: PackedVector2Array = PackedVector2Array()
var _jump_surface_cell_size: float = 0.0
var _jump_surface_start: Vector2i
var _jump_surface_size: Vector2i
var printshop_status: String = "not_loaded"
var printshop_errors: PackedStringArray = []
var _printshop: Node3D
var _printshop_data: Dictionary = {}
var _player_capsule: CollisionShape3D
var _door_occupants: Array = [{"position": Vector3.ZERO, "radius": 0.0, "height": 0.0}]
var _door_hint: Label
var _door_hint_panel: PanelContainer
var _door_hint_key: PanelContainer
var _door_hint_world: Vector3 = Vector3.ZERO
var _door_feedback_seconds: float = 0.0
var preview_perf: Node = null
var preview_ready: bool = false
var validation_errors: PackedStringArray = []
var _resource_scenes: Dictionary = {}
var _surface_materials: Dictionary = {}
var _block: Dictionary = {}
var _origin: Vector3
var _player: CharacterBody3D
var _spawn: Vector3
var _stats: Label
var _clock: float = 0.0
var _samples: Array[float] = []
var _runtime_seconds: float = 0.0
var _capture_done: bool = false
var _capture_path: String = ""
var _last_frame_usec: int = 0

func _ready() -> void:
	GameCursor.install()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(block_data_path))
	if not parsed is Dictionary:
		validation_errors = PackedStringArray(["Invalid source block"])
		_show_load_error()
		return
	validation_errors = BlockValidation.validate(parsed)
	if not validation_errors.is_empty():
		_show_load_error()
		return
	set_meta("preview_building_mode", PalazzoOnlyPreview.MODE)
	parsed = PalazzoOnlyPreview.prepare_block(parsed)
	var prepared: Dictionary = BlockValidation.prepare_assets(parsed)
	validation_errors = prepared["errors"]
	if not validation_errors.is_empty():
		_show_load_error()
		return
	_resource_scenes = prepared["scenes"]
	_block = parsed
	_origin = _v3(_block["originM"])
	_cache_jump_surface_contains()
	# Material preparation is also atomic: a failed shader/material must not
	# leave a partially populated scene reporting READY.
	for row: Array in _block["surface"]["grid"]:
		for tile: Variant in row:
			var key: String = str(int(tile))
			if _surface_materials.has(key):
				continue
			var material: Material = SurfaceMaterials.create_material(_block["surface"], int(tile), _origin)
			_surface_materials[key] = material
			if material == null:
				validation_errors.append("Surface material unavailable for tile " + key)
	if not validation_errors.is_empty():
		_surface_materials.clear()
		_resource_scenes.clear()
		_show_load_error()
		return
	_build_lighting()
	_build_surface()
	var boundary := PreviewBoundary.new()
	add_child(boundary)
	PalazzoGround.install(self)
	boundary.configure(PalazzoGround.bounds(_block.surface.boundsLocalM))
	# Removed buildings are never instantiated, including their interior/colliders.
	printshop_status = "removed_by_user"
	for record: Dictionary in _block["decor"]:
		_add_asset(record)
	# Cold registration before player, transport, navigation and static batching.
	# The old modular townhouse is also excluded from this composition.
	preview_palazzo = load("res://scripts/destruction/palazzo/palazzo_host.gd").new()
	preview_palazzo.name = "PalazzoHost"
	add_child(preview_palazzo)
	print("PALAZZO_GEOMETRY ", preview_palazzo.prepare(self))
	if (preview_static_batch_enabled or OS.get_cmdline_user_args().has("--preview-static-batch")) and not OS.get_cmdline_user_args().has("--preview-static-batch-off"):
		apply_preview_static_batches()
	_spawn = _v3(_block["hero"]["spawnLocalM"])
	var spawn_yaw := 0.0
	# User-requested preview start, derived from the real public entrance.
	# Source IDs, authored map spawn and any future saved session stay distinct.
	if preview_start_at_printshop and printshop_status == "ready" and is_instance_valid(_printshop):
		var approach: Vector3 = _printshop.anchor("publicApproach")
		var inside: Vector3 = _printshop.anchor("publicInside")
		if approach.is_finite() and inside.is_finite():
			_spawn = approach + Vector3.UP * 0.05
			var facing := inside - approach
			spawn_yaw = atan2(-facing.x, -facing.z)
	_player = PlayerController.new()
	_player.hero_scene_path = str(_block["hero"]["path"])
	_player.model_target_height = float(_block["hero"]["targetHeightM"])
	_player.position = _spawn
	_player.set("_camera_yaw", spawn_yaw)
	_player.set("_heading", spawn_yaw)
	add_child(_player)
	_player.get_node("VisualHeading").rotation.y = spawn_yaw + deg_to_rad(_player.visual_yaw_degrees)
	_player.set_preview_jump_surface_guard(Callable(self, "preview_jump_surface_allowed"))
	_player_capsule = _player.get_node_or_null("PlayerCapsule") as CollisionShape3D
	if not bool(_player.get_preview_status().get("model_loaded", false)):
		validation_errors.append("Hero did not produce a valid visible model")
		restore_preview_static_batches("invalid_player")
		_dispose_water_surface()
		for child: Node in get_children():
			child.queue_free()
		_show_load_error()
		return
	_build_hud()
	# Negotiate before any transport/support snapshots, without changing masks.
	# Actual resident/weapon setup retains its existing later startup order.
	if preview_residents_enabled or OS.get_cmdline_user_args().has("--preview-residents"):
		preview_population = PreviewPopulation.new()
		if preview_final_dead_contact_enabled:
			var contract: Dictionary = preview_population.final_dead_contact_startup_contract()
			if not contract.is_empty():
				_final_dead_block_requested = _player.prepare_final_dead_block_contract(contract)
				final_dead_block_contract_status = "negotiated_before_transport" if _final_dead_block_requested else "contract_rejected_legacy_v1"
	if preview_transport_enabled or OS.get_cmdline_user_args().has("--preview-transport"):
		preview_transport = PreviewTransport.new()
		preview_transport.name = "PreviewTransport"
		add_child(preview_transport)
		var vehicle_setup: Dictionary = preview_transport.setup(_player, _origin)
		transport_status = "ready" if vehicle_setup.get("ok", false) else str(vehicle_setup.get("error", "failed"))
		if vehicle_setup.get("ok", false) and preview_start_at_vehicle:
			_player.position = vehicle_setup.spawn
			_player.set_preview_pose_authority(&"on_foot", true)
			_player._camera_yaw = preview_transport.body.global_rotation.y - PI / 2.0
			_player._heading = _player._camera_yaw
			_player._visual.rotation.y = _player._heading + PI
			_player._update_camera_rotation()
	# Start beside the requested building while preserving authored source spawn data.
	if is_instance_valid(preview_palazzo.site) and not OS.get_cmdline_user_args().has("--palazzo-start-off"):
		_player.position = preview_palazzo.site.to_global(Vector3(1,.14,6.3))
		_player._camera_yaw = -PI/2.0
		_player._camera_pitch = -.12
		_player._heading = _player._camera_yaw
		_player._visual.rotation.y = _player._heading + PI
		_player._update_camera_rotation()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--preview-capture="):
			_capture_path = argument.trim_prefix("--preview-capture=")
	if preview_melee_enabled or OS.get_cmdline_user_args().has("--preview-melee"):
		_install_preview_melee_practice()
	if preview_weapons_enabled or OS.get_cmdline_user_args().has("--preview-weapons"):
		var weapon_script: Script = load("res://scripts/weapons/preview_weapons.gd")
		if weapon_script != null:
			var weapon_host: Node = weapon_script.new()
			add_child(weapon_host)
			var weapon_setup: Dictionary = weapon_host.configure(self, _player)
			weapons_status = "local_arsenal" if weapon_setup.get("ok",false) else str(weapon_setup)
			if weapon_setup.get("ok",false):
				preview_weapons = weapon_host
				_player._weapon_host = weapon_host
				if is_instance_valid(preview_transport):
					var cargo_script: Script=load("res://scripts/weapons/preview_weapon_cargo.gd")
					if cargo_script != null:
						var cargo_host: Node=cargo_script.new()
						cargo_host.name="WeaponCargo"
						weapon_host.add_child(cargo_host)
						var cargo_result: Dictionary=cargo_host.configure(weapon_host,preview_transport)
						if not cargo_result.get("ok",false):
							push_error("Weapon cargo binding: "+str(cargo_result)); cargo_host.queue_free()
			else: weapon_host.queue_free()
	if is_instance_valid(preview_modular30):
		print("MODULAR30_NATIVE_BINDING ", preview_modular30.bind_weapons())
	if is_instance_valid(preview_palazzo):
		print("PALAZZO_NATIVE_BINDING ", preview_palazzo.bind_weapons())
	if is_instance_valid(preview_weapons) and is_instance_valid(preview_palazzo) and preview_palazzo.status=="ready":
		var blast: Node=load("res://scripts/destruction/palazzo/c4_building_blast.gd").new()
		preview_c4_blast=blast
		if blast.configure(self,Callable(self,"_c4_sites")):
			var equipment: Node=load("res://scripts/destruction/palazzo/c4_equipment.gd").new()
			preview_c4=equipment
			var c4_setup: Dictionary=equipment.configure(self,Callable(blast,"detonate"))
			print("C4_NATIVE_BINDING ",c4_setup)
			if not c4_setup.get("ok",false):
				if equipment.get_parent()==null: equipment.free()
				else: equipment.dispose()
				preview_c4=null; blast.dispose(); preview_c4_blast=null
		else:
			preview_c4_blast=null; blast.free(); push_error("C4 blast binding failed")
	if preview_residents_enabled or OS.get_cmdline_user_args().has("--preview-residents"):
		# Physics must see the authored colliders before source placement proofs.
		await get_tree().physics_frame
		await get_tree().physics_frame
		preview_population.setup(self, true, preview_resident_walk_enabled)
		population_status = preview_population.status
	if preview_final_dead_contact_enabled: _bind_final_dead_contact_port()
	preview_ready = true
	print("PALAZZO_READY ", is_instance_valid(preview_palazzo) and preview_palazzo.status == "ready")
	print("PALAZZO_ONLY43_READY legacy_buildings=", _block.buildings.size(), " palazzo=", int(is_instance_valid(preview_palazzo.site)))
	_setup_preview_perf()
	_last_frame_usec = Time.get_ticks_usec()
	print("MAFIOZI_PREVIEW_READY buildings=%d decor=%d source_colliders=%d renderer=%s" % [_block["counts"]["buildings"], _block["counts"]["decor"], _block["counts"]["collisionBodies"], RenderingServer.get_current_rendering_method()])
	print("PRINTSHOP_INTERIOR_STATUS ", printshop_status)
	print("WATER_SURFACE_STATUS ", water_status)
	print("STATIC_BATCH_STATUS ", static_batch_status)
	print("RESIDENT_POPULATION_STATUS ", population_status)
	print("MELEE_PRACTICE_STATUS ", melee_status)

func _install_preview_melee_practice() -> bool:
	if is_instance_valid(preview_melee) or not is_instance_valid(_player): return false
	# Explicit practice presentation only. A future live combat owner must bind
	# actual targets, state and source consequences instead of reusing this host.
	var adapter_script: Script = load("res://scripts/combat/melee_physical_pose.gd")
	if adapter_script == null:
		melee_status = "physical_pose_unavailable"; return false
	var adapter: RefCounted = adapter_script.new()
	if not adapter.configure(_player._pose_skeleton, _player._locomotion._rest_poses):
		melee_status = "physical_pose_binding"; return false
	var host := PreviewMelee.new()
	host.name = "MeleePractice"
	add_child(host)
	if not host.configure(self, _player, adapter):
		host.queue_free(); melee_status = "host_binding"; return false
	preview_melee = host; _player._melee_practice = host
	melee_status = "ground_practice_no_combat_targets"
	return true

## Startup/controlled rebuild only. Restore BEFORE source geometry, transforms,
## visibility, materials or shared-sun/sky lighting dependencies are changed.
## Printshop, terrain, actors and all physics stay outside this render lease.
func apply_preview_static_batches() -> bool:
	if _static_batch_lease != null:
		return static_batch_status == "ready"
	var declarations: Array = []
	for owner: Node3D in _static_render_roots:
		if not is_instance_valid(owner) or owner.get_parent() != self:
			static_batch_status = "fallback"
			static_batch_summary = {"ok": false, "errors": ["Static owner changed before planning"]}
			return false
		var source_id: String = str(owner.get_meta("source_id", ""))
		if source_id not in STATIC_RENDER_OWNER_IDS:
			static_batch_status = "fallback"
			static_batch_summary = {"ok": false, "errors": ["Static owner identity changed"]}
			return false
		declarations.append({"root": owner, "source_id": source_id, "static_authorized": true,
			"shared_sun_sky_only": true, "allow_static_gi_without_capture": true})
	var lease := StaticBatch.new()
	var started := Time.get_ticks_usec()
	static_batch_summary = lease.plan(self, declarations, 16.0)
	var planned := Time.get_ticks_usec()
	if not bool(static_batch_summary.get("ok", false)) or not lease.apply():
		static_batch_summary["ok"] = false
		static_batch_summary["errors"] = lease.errors.duplicate()
		lease.restore()
		static_batch_status = "fallback"
		return false
	static_batch_summary["plan_us"] = planned - started
	static_batch_summary["apply_us"] = Time.get_ticks_usec() - planned
	static_batch_summary["active"] = true
	_static_batch_lease = lease
	static_batch_status = "ready"
	return true

func restore_preview_static_batches(reason: String = "restored") -> void:
	if _static_batch_lease == null:
		return
	_static_batch_lease.restore()
	_static_batch_lease = null
	static_batch_summary["active"] = false
	static_batch_summary["restore_reason"] = reason
	static_batch_status = "restored"

func _build_water_surface() -> bool:
	# Build-time selection only. Never mutate water topology from a frame callback.
	water_status = "baseline_disabled"
	if not preview_water_detail_enabled or OS.get_cmdline_user_args().has("--preview-water-off"):
		return false
	water_status = "baseline_fallback"
	if not FileAccess.file_exists(water_data_path):
		water_errors.append("WATER_DATA_MISSING")
		return false
	var source_text: String = FileAccess.get_file_as_string(water_data_path).replace("\r\n", "\n")
	if source_text.sha256_text() != WATER_DATA_SHA256:
		water_errors.append("WATER_DATA_CHECKSUM")
		return false
	var parsed: Variant = JSON.parse_string(source_text)
	water_errors.append_array(WaterSurface.validate(parsed))
	if not water_errors.is_empty():
		return false
	water_errors.append_array(_validate_water_crop(parsed))
	if not water_errors.is_empty():
		return false
	var candidate: RefCounted = WaterSurface.new()
	var result: Dictionary = candidate.build(parsed, self)
	if not bool(result.get("ok", false)):
		water_errors.append_array(result.get("errors", PackedStringArray(["WATER_BUILD_FAILED"])))
		candidate.dispose() # Remove any owned partial resource before fallback.
		return false
	_water_host = candidate
	water_summary = result
	water_status = "detail_ready"
	return true

func _validate_water_crop(data: Dictionary) -> PackedStringArray:
	# Hash pins reviewed source depths; these checks prevent that valid package
	# being applied to a different currently admitted preview block/crop.
	var errors: PackedStringArray = []
	var surface: Dictionary = _block["surface"]
	for axis: int in range(3):
		if absf(float(data.originM[axis]) - float(_block.originM[axis])) > 0.000001:
			errors.append("WATER_BLOCK_ORIGIN")
	var cell: float = float(surface.cellSize)
	if absf(float(data.metresPerCell) - cell) > 0.000001:
		errors.append("WATER_BLOCK_CELL_SIZE")
	var expected_bounds: Dictionary = {"rMinInclusive": int(surface.startRow), "rMaxExclusive": int(surface.startRow) + int(surface.rows),
		"cMinInclusive": int(surface.startCol), "cMaxExclusive": int(surface.startCol) + int(surface.cols)}
	var bounds: Variant = data.get("previewBoundsRC")
	if not bounds is Dictionary:
		errors.append("WATER_BLOCK_BOUNDS")
	else:
		for key: String in expected_bounds:
			if not WaterSurface._number(bounds.get(key), 0, 100000) or float(bounds[key]) != float(expected_bounds[key]):
				errors.append("WATER_BLOCK_BOUNDS")
				break
	var water_palette: Dictionary = surface.palette.get("16", {})
	if water_palette.is_empty() or bool(water_palette.get("solid", true)) or absf(float(water_palette.get("heightM", INF)) - float(data.native.surfaceYM)) > 0.000001:
		errors.append("WATER_BLOCK_SURFACE_HEIGHT")
	var masks: Variant = surface.get("masks")
	if not masks is Dictionary or not masks.get("protectedMask") is Array:
		errors.append("WATER_PROTECTED_MASK_REQUIRED")
		return errors
	var protected: Array = masks.protectedMask
	if protected.size() != int(surface.rows):
		errors.append("WATER_PROTECTED_MASK_ROWS")
		return errors
	var expected: Dictionary = {}
	for row: int in range(int(surface.rows)):
		if not protected[row] is Array or protected[row].size() != int(surface.cols):
			errors.append("WATER_PROTECTED_MASK_COLUMNS")
			return errors
		for col: int in range(int(surface.cols)):
			var flag: Variant = protected[row][col]
			if not (flag is bool or ((flag is int or flag is float) and (flag == 0 or flag == 1))):
				errors.append("WATER_PROTECTED_MASK_VALUE")
				return errors
			if int(surface.grid[row][col]) != 16:
				continue
			if bool(protected[row][col]):
				errors.append("WATER_PROTECTED_CELL_UNSUPPORTED")
				continue
			expected[Vector2i(int(surface.startRow) + row, int(surface.startCol) + col)] = true
	var cells: Array = data.native.cells
	if cells.size() != 303 or expected.size() != cells.size():
		errors.append("WATER_BLOCK_CELL_COUNT")
	for record: Dictionary in cells:
		if not expected.has(Vector2i(int(record.r), int(record.c))):
			errors.append("WATER_BLOCK_FOOTPRINT")
			break
	return errors

func _dispose_water_surface() -> void:
	if _water_host != null:
		_water_host.dispose()
		_water_host = null

func _cache_jump_surface_contains() -> void:
	# Source traversalMapContains for this native crop only: nativePedestrianLand
	# OR waterAt. This is not full traversal occupancy, swimming or a new floor.
	_jump_surface_cells.clear()
	_jump_surface_offsets.clear()
	var surface: Dictionary = _block.surface
	var masks: Variant = surface.get("masks")
	if not masks is Dictionary:
		return
	for name: String in ["walkableMask", "policeMask", "protectedMask"]:
		var rows: Variant = masks.get(name)
		if not rows is Array or rows.size() != int(surface.rows):
			return
		for row: Variant in rows:
			if not row is Array or row.size() != int(surface.cols):
				return
			for flag: Variant in row:
				if not (flag is bool or ((flag is int or flag is float) and (flag == 0 or flag == 1))):
					return
	_jump_surface_cell_size = float(surface.cellSize)
	_jump_surface_start = Vector2i(int(surface.startCol), int(surface.startRow))
	_jump_surface_size = Vector2i(int(surface.cols), int(surface.rows))
	_jump_surface_cells.resize(_jump_surface_size.x * _jump_surface_size.y)
	for row: int in range(_jump_surface_size.y):
		for col: int in range(_jump_surface_size.x):
			var tile: int = int(surface.grid[row][col])
			var police: Variant = masks.policeMask[row][col]
			var land: bool = bool(masks.walkableMask[row][col]) or (tile == 9 and (police is int or police is float) and police == 1)
			var water: bool = tile == 16 and not bool(masks.protectedMask[row][col])
			_jump_surface_cells[row * _jump_surface_size.x + col] = 1 if land or water else 0
	for index: int in range(12):
		var angle: float = float(index) * PI / 6.0
		_jump_surface_offsets.append(Vector2(cos(angle), sin(angle)))

func preview_jump_surface_allowed(feet_world: Vector3, radius: float = 0.36) -> bool:
	# Exact source circle sample count: centre +12, bounded cached lookups only.
	# Player separately owns swept substeps, physical collision/height/ceiling.
	if _jump_surface_cells.is_empty() or not feet_world.is_finite() or not is_finite(radius) or radius <= 0.0:
		return false
	var local: Vector3 = to_local(feet_world)
	var centre: Vector2 = Vector2(local.x + _origin.x, local.z + _origin.z)
	if not _jump_surface_point_contains(centre):
		return false
	for offset: Vector2 in _jump_surface_offsets:
		if not _jump_surface_point_contains(centre + offset * radius):
			return false
	return true

func _jump_surface_point_contains(source_xz: Vector2) -> bool:
	if PalazzoGround.contains_world(to_global(Vector3(source_xz.x - _origin.x, 0, source_xz.y - _origin.z))): return true
	var col: float = source_xz.x / _jump_surface_cell_size - float(_jump_surface_start.x)
	var row: float = source_xz.y / _jump_surface_cell_size - float(_jump_surface_start.y)
	# Check signed fractions before conversion: negative positions never truncate
	# into the first cell. The exclusive far bounds stay exclusive.
	if not is_finite(col) or not is_finite(row) or col < 0.0 or row < 0.0 or col >= _jump_surface_size.x or row >= _jump_surface_size.y:
		return false
	return _jump_surface_cells[int(floor(row)) * _jump_surface_size.x + int(floor(col))] == 1

func _c4_sites() -> Array:
	if is_instance_valid(preview_palazzo) and preview_palazzo.status=="ready" and is_instance_valid(preview_palazzo.site):
		return [preview_palazzo.site]
	return []

func _exit_tree() -> void:
	if is_instance_valid(preview_c4): preview_c4.dispose()
	preview_c4=null
	if is_instance_valid(preview_c4_blast): preview_c4_blast.dispose()
	preview_c4_blast=null
	GameCursor.release()
	if is_instance_valid(preview_modular30): preview_modular30.dispose(false)
	if is_instance_valid(preview_palazzo): preview_palazzo.dispose()
	if preview_population != null:
		preview_population.dispose()
	# Parent still exists here; clear host-owned mesh/material before destruction.
	restore_preview_static_batches("scene_exit")
	_dispose_water_surface()

func _load_printshop_data() -> void:
	# Pin this reviewed generated package before passing structured data to the
	# adapter. A corrupt/unreviewed package keeps the complete exterior fallback.
	printshop_status = "exterior_fallback"
	if not FileAccess.file_exists(printshop_data_path):
		printshop_errors.append("Printshop package missing or checksum mismatch")
		return
	# Windows checkouts may convert text newlines. Hash and parse the same
	# canonical text; content changes still fail closed, CRLF/LF alone do not.
	var source_text: String = FileAccess.get_file_as_string(printshop_data_path).replace("\r\n", "\n")
	if source_text.sha256_text() != PRINTSHOP_DATA_SHA256:
		printshop_errors.append("Printshop package missing or checksum mismatch")
		return
	var parsed: Variant = JSON.parse_string(source_text)
	if not parsed is Dictionary:
		printshop_errors.append("Printshop package is not a dictionary")
		return
	_printshop_data = parsed

func _current_door_occupants() -> Array:
	_door_occupants.resize(1)
	# Read the actual collider; the current player radius is 0.30, not the
	# independent adapter test's conservative 0.36. Missing bounds fail closed.
	var occupant: Dictionary = _door_occupants[0]
	occupant.radius = 0.0
	occupant.height = 0.0
	if is_instance_valid(_player_capsule) and _player_capsule.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = _player_capsule.shape as CapsuleShape3D
		var frame: Transform3D = _player_capsule.global_transform
		occupant.height = capsule.height * frame.basis.y.length()
		occupant.radius = capsule.radius * maxf(frame.basis.x.length(), frame.basis.z.length())
		occupant.position = frame.origin - Vector3.UP * float(occupant.height) * 0.5
	if preview_population != null:
		_door_occupants.append_array(preview_population.occupants())
	return _door_occupants

func _current_door_action() -> Dictionary:
	if not preview_ready or not is_instance_valid(_player):
		return {}
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return {}
	if is_instance_valid(preview_palazzo):
		var palazzo_action: Dictionary = preview_palazzo.door_action()
		if not palazzo_action.is_empty(): return palazzo_action
	return _printshop.nearest_action(_player.global_position) if is_instance_valid(_printshop) else {}

func _update_door_hint() -> void:
	if _door_hint == null:
		return
	var action: Dictionary = _current_door_action()
	if action.get("owner", "") == "palazzo":
		_door_hint_world = action.world
	elif not _printshop_data.is_empty():
		_door_hint_world = _v3(_printshop_data.doors.public.anchor) + Vector3.UP * 2.2
	var hint: String = str(action.label) if not action.is_empty() else ""
	_door_hint_key.visible = not action.is_empty() and _door_feedback_seconds <= 0.0
	if not action.is_empty() and _door_feedback_seconds > 0.0:
		hint = "Дверь заблокирована"
	if _door_hint.text != hint:
		_door_hint.text = hint
		_door_hint_panel.reset_size()

func _position_door_hint() -> void:
	if _door_hint_panel == null:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	_door_hint_panel.visible = not _door_hint.text.is_empty() and camera != null and not camera.is_position_behind(_door_hint_world)
	if not _door_hint_panel.visible:
		return
	var screen: Vector2 = camera.unproject_position(_door_hint_world)
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var size: Vector2 = _door_hint_panel.size
	_door_hint_panel.position = Vector2(clampf(screen.x - size.x * 0.5, 12.0, maxf(12.0, viewport.x - size.x - 12.0)),
		clampf(screen.y - size.y, 12.0, maxf(12.0, viewport.y - size.y - 12.0)))

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_player) or not _player._free_mouse_look: return
	if preview_dead or preview_physics_fault:
		if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_R or event.keycode == KEY_R):
			get_viewport().set_input_as_handled()
			get_tree().reload_current_scene.call_deferred()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var palazzo_key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if palazzo_key in [KEY_K, KEY_J] and is_instance_valid(preview_palazzo):
		var command: Dictionary = preview_palazzo.request_full_collapse() if palazzo_key == KEY_K else preview_palazzo.request_reset()
		if command.get("ok", false): get_viewport().set_input_as_handled()
		return
	if event.physical_keycode != KEY_E and event.keycode != KEY_E:
		return
	if not is_instance_valid(_player) or _player._pose_authority != &"on_foot":
		return
	var action: Dictionary = _current_door_action()
	if action.is_empty():
		return
	var is_palazzo: bool = action.get("owner", "") == "palazzo"
	var result: Dictionary = preview_palazzo.request_door() if is_palazzo else _printshop.request_door(str(action.door), not bool(action.opening), _player.global_position, _current_door_occupants())
	if not is_palazzo and result.get("accepted", false) and preview_population != null:
		preview_population.door_started(str(action.door), bool(result.open))
	_door_feedback_seconds = 0.0
	if not bool(result.get("accepted", false)) and str(result.get("reason", "")) == "door-sweep-occupied":
		_door_feedback_seconds = 0.9
	_update_door_hint()
	get_viewport().set_input_as_handled()

func install_character_impact_source(resolver: Callable, reaction_profile: Dictionary, local_inertias: Dictionary) -> Dictionary:
	# Only a real source owner supplies accepted current contacts and force data.
	# No preview key, damage observation or arbitrary confirmed flag creates hits.
	if is_instance_valid(preview_character_impacts) or preview_dead or preview_physics_fault or not resolver.is_valid():
		return {"ok":false,"error":"impact_source_binding"}
	var host := PlayerImpactHost.new()
	host.name = "CharacterImpacts"
	add_child(host)
	var result: Dictionary = host.configure(_player, preview_transport, reaction_profile, local_inertias, resolver)
	if not result.get("ok", false):
		host.queue_free()
		return result
	preview_character_impacts = host
	return result


func _physics_process(delta: float) -> void:
	if not preview_ready:
		return
	_door_feedback_seconds = maxf(0.0, _door_feedback_seconds - delta)
	if is_instance_valid(_printshop): _printshop.advance(delta, _current_door_occupants())
	if preview_population != null:
		preview_population.step(delta)
	_update_door_hint()

func _setup_preview_perf() -> void:
	preview_perf = PreviewPerfAdapter.new()
	preview_perf.name = "PreviewPerf"
	add_child(preview_perf)
	# Explicit opt-in only. The default adapter has no process callback.
	if preview_perf_enabled or OS.get_cmdline_user_args().has("--preview-perf"):
		begin_preview_perf_capture()

func begin_preview_perf_capture(config: Dictionary = {}) -> bool:
	# PNG readback/encoding would contaminate an otherwise identical route.
	if not preview_ready or preview_perf == null or not _capture_path.is_empty():
		return false
	var supplied_context: Variant = config.get("context", {})
	if not supplied_context is Dictionary:
		return false
	var settings: Dictionary = config.duplicate(true)
	var context: Dictionary = supplied_context.duplicate(true)
	context["scene"] = "s01_preview_quarter"
	context["population"] = 0
	context["vehicles"] = 0
	context["block_data_path"] = block_data_path
	context["water_status"] = water_status
	context["static_batch_status"] = static_batch_status
	context["qualification"] = "Small preview quarter; not full-city gameplay acceptance"
	settings["context"] = context
	return preview_perf.begin_capture(settings)

func _show_load_error() -> void:
	set_process(false)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var label: Label = Label.new()
	label.position = Vector2(32, 32)
	label.text = "Не удалось загрузить квартал.\nДанные или ресурсы повреждены; сцена не запущена."
	label.add_theme_font_size_override("font_size", 22)
	layer.add_child(label)
	push_error("MAFIOZI_PREVIEW_REJECTED: " + "; ".join(validation_errors))

func _v3(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _build_lighting() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var atmosphere: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("738eaf")
	atmosphere.sky_horizon_color = Color("c6cfce")
	atmosphere.ground_bottom_color = Color("484c46")
	atmosphere.ground_horizon_color = Color("bec7c7")
	sky.sky_material = atmosphere
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 6.0
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "AfternoonSun"
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff0d8")
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100.0
	add_child(sun)

func _build_surface() -> void:
	var surface: Dictionary = _block["surface"]
	var grid: Array = surface["grid"]
	var palette: Dictionary = surface["palette"]
	var cell: float = float(surface["cellSize"])
	var detail_water: bool = _build_water_surface()
	var groups: Dictionary = {}
	for row in range(grid.size()):
		for col in range(grid[row].size()):
			var key: String = str(int(grid[row][col]))
			if not groups.has(key):
				groups[key] = []
			groups[key].append(Vector3((int(surface["startCol"]) + col + 0.5) * cell - _origin.x, float(palette[key]["heightM"]) - 0.02, (int(surface["startRow"]) + row + 0.5) * cell - _origin.z))
	for key: String in groups:
		if detail_water and key == "16":
			continue # Exactly one source plane batch replaces all old water boxes.
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(cell, 0.04, cell)
		mesh.material = _surface_materials[key]
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = groups[key].size()
		for i in range(multi.instance_count):
			multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, groups[key][i]))
		var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
		instance.name = "Surface_" + str(palette[key]["kind"])
		instance.multimesh = multi
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	# Merge consecutive dry cells into physical strips. No floor is created on water.
	for row in range(grid.size()):
		var col: int = 0
		while col < grid[row].size():
			var key: String = str(int(grid[row][col]))
			if not bool(palette[key]["solid"]):
				col += 1
				continue
			var first: int = col
			while col < grid[row].size() and str(int(grid[row][col])) == key:
				col += 1
			var body: StaticBody3D = StaticBody3D.new()
			var shape: BoxShape3D = BoxShape3D.new()
			shape.size = Vector3((col - first) * cell, 0.16, cell)
			var collision: CollisionShape3D = CollisionShape3D.new()
			collision.shape = shape
			body.position = Vector3((int(surface["startCol"]) + (first + col) * 0.5) * cell - _origin.x, float(palette[key]["heightM"]) - 0.08, (int(surface["startRow"]) + row + 0.5) * cell - _origin.z)
			body.add_child(collision)
			add_child(body)

func _add_asset(record: Dictionary) -> void:
	# Every scene passed preflight before any world/physics node was created.
	var resource: PackedScene = _resource_scenes[str(record["path"])]
	var parent: Node3D = Node3D.new()
	parent.name = str(record["id"])
	parent.set_meta("source_id", record["id"])
	var transform_data: Dictionary = record["transform"]
	parent.position = _v3(record["positionLocalM"])
	parent.rotation.y = deg_to_rad(float(transform_data.get("yawDegrees", 0)))
	var uniform: float = float(transform_data.get("uniformScale", 1))
	var horizontal: Array = transform_data.get("horizontalScale", [1, 1])
	parent.scale = Vector3(uniform * float(horizontal[0]), uniform, uniform * float(horizontal[1]))
	var visual: Node3D = resource.instantiate() as Node3D
	visual.position = _v3(transform_data.get("modelLocalOffsetM", [0, 0, 0]))
	parent.add_child(visual)
	add_child(parent)
	_hide_helpers(visual, record.get("effectiveHiddenNodeNames", []))
	if str(record["id"]) in STATIC_RENDER_OWNER_IDS:
		_static_render_roots.append(parent)
	if str(record["id"]) == PrintshopInterior.SOURCE_ID and not _printshop_data.is_empty():
		var interior: Node3D = PrintshopInterior.new()
		interior.name = "PrintshopInterior"
		add_child(interior)
		if interior.attach_existing(visual, record, _printshop_data):
			_printshop = interior
			printshop_status = "ready"
			return # Only this record's exactly three validated envelope bodies.
		printshop_errors.append_array(interior.errors)
		interior.restore_original()
		interior.free()
	for data: Dictionary in record.get("collisionBodiesM", []):
		var points: PackedVector3Array = PackedVector3Array()
		for point: Array in data["polygonXZ"]:
			points.append(Vector3(float(point[0]), float(data["minY"]), float(point[1])))
			points.append(Vector3(float(point[0]), float(data["maxY"]), float(point[1])))
		var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		shape.points = points
		var body: StaticBody3D = StaticBody3D.new()
		body.set_meta("source_id", record["id"])
		body.set_meta("source_index", data["sourceIndex"])
		var collider: CollisionShape3D = CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		add_child(body)

func _hide_helpers(node: Node, names: Array) -> void:
	for original: String in names:
		if str(node.name) == original or str(node.name) == original.validate_node_name():
			if node is Node3D:
				node.visible = false
	for child: Node in node.get_children():
		_hide_helpers(child, names)

func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.07, 0.9)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	style.border_width_left = 3
	style.border_color = Color("dfb968")
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	panel.add_child(stack)
	var title: Label = Label.new()
	title.text = "МАФИОЗИ · тестовый квартал"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color("ebc77f"))
	stack.add_child(title)
	_stats = Label.new()
	_stats.add_theme_color_override("font_color", Color("aabec8"))
	_stats.add_theme_font_size_override("font_size", 12)
	stack.add_child(_stats)
	var controls: Label = Label.new()
	controls.text = "Клик — управление · Esc — курсор\nWASD — идти · Shift — бег · Колесо — камера\nSpace — прыжок · 2×Space — бросок · C/Z — присесть/лечь"
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.offset_left = 470 if preview_weapons_enabled else 16
	controls.offset_top = -70 if preview_weapons_enabled else -46
	controls.add_theme_font_size_override("font_size", 12)
	controls.add_theme_color_override("font_shadow_color", Color.BLACK)
	controls.add_theme_constant_override("shadow_offset_x", 1)
	controls.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(controls)
	_door_hint_panel = PanelContainer.new()
	_door_hint_panel.name = "DoorActionAboveEntrance"
	_door_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_door_hint_panel.visible = false
	var door_style := StyleBoxFlat.new()
	door_style.bg_color = Color(0.035, 0.055, 0.07, 0.95)
	door_style.set_border_width_all(1)
	door_style.border_color = Color("dfb968")
	door_style.set_corner_radius_all(6)
	door_style.content_margin_left = 8
	door_style.content_margin_right = 8
	door_style.content_margin_top = 4
	door_style.content_margin_bottom = 4
	_door_hint_panel.add_theme_stylebox_override("panel", door_style)
	layer.add_child(_door_hint_panel)
	if is_instance_valid(_printshop):
		_door_hint_world = _v3(_printshop_data.doors.public.anchor)
		for body: Dictionary in _printshop_data.doors.public.bodies:
			_door_hint_world.y = maxf(_door_hint_world.y, float(body.maxY))
		_door_hint_world.y += 0.25
	var door_row := HBoxContainer.new()
	door_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	door_row.add_theme_constant_override("separation", 6)
	_door_hint_panel.add_child(door_row)
	_door_hint_key = PanelContainer.new()
	_door_hint_key.name = "InteractionKeyE"
	_door_hint_key.custom_minimum_size = Vector2(24, 24)
	_door_hint_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color("f7dc9c")
	key_style.border_color = Color("a27a35")
	key_style.set_border_width_all(1)
	key_style.border_width_bottom = 3
	key_style.set_corner_radius_all(5)
	_door_hint_key.add_theme_stylebox_override("panel", key_style)
	door_row.add_child(_door_hint_key)
	var key_label := Label.new()
	key_label.text = "E"
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.add_theme_color_override("font_color", Color("17202a"))
	key_label.add_theme_font_size_override("font_size", 16)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_door_hint_key.add_child(key_label)
	_door_hint = Label.new()
	_door_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_door_hint.add_theme_color_override("font_color", Color("f7dc9c"))
	_door_hint.add_theme_font_size_override("font_size", 14)
	_door_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	_door_hint.add_theme_constant_override("shadow_offset_x", 1)
	_door_hint.add_theme_constant_override("shadow_offset_y", 2)
	door_row.add_child(_door_hint)
	_build_update_panel(layer)

func _build_update_panel(layer: CanvasLayer) -> void:
	var notes := UpdatePanel.new()
	layer.add_child(notes)
	notes.setup("res://data/preview_updates.json", PREVIEW_RUNTIME_REVISION)

func _process(delta: float) -> void:
	if not preview_ready or _player == null:
		return
	_position_door_hint()
	if not preview_physics_fault and is_instance_valid(preview_transport) and preview_transport.character_physics != null and preview_transport.character_physics.mode == "FAULTED":
		_show_physics_fault()
	if not preview_dead and not preview_physics_fault and _player.global_position.y < -25.0:
		_die_outside_world()
	var now: int = Time.get_ticks_usec()
	if _water_host != null:
		_water_host.advance(float(now) / 1000000.0)
	_samples.append(float(now - _last_frame_usec) / 1000.0)
	_last_frame_usec = now
	_runtime_seconds += delta
	if not _capture_done and not _capture_path.is_empty() and _runtime_seconds > 5.0:
		_capture_done = true
		_save_preview_frame.call_deferred()
	if _samples.size() > 600:
		_samples.pop_front()
	_clock += delta
	if _clock < 1.0:
		return
	_clock = 0.0
	var sorted: Array[float] = _samples.duplicate()
	sorted.sort()
	var p95: float = sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))]
	_stats.text = "%d FPS · p95 %.1f мс" % [Engine.get_frames_per_second(), p95]
	if not _capture_path.is_empty() and _runtime_seconds < 12.0:
		print("PREVIEW_FRAME_SAMPLE ", JSON.stringify({"elapsed_seconds": _runtime_seconds, "fps": Engine.get_frames_per_second(), "frame_p95_ms": p95, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "limits": "Static small debug preview, not full gameplay or exported release benchmark"}))

func _save_preview_frame() -> void:
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	var result: Error = frame.save_png(_capture_path)
	print("PREVIEW_CAPTURE ", result, " ", _capture_path)

func _die_outside_world() -> void:
	# Explicit local-preview death; never teleport a still-occupied actor away
	# from a falling vehicle or silently grant walking authority.
	preview_dead = true
	if is_instance_valid(preview_transport):
		preview_transport.mark_dead()
	else:
		_player.set_preview_pose_authority(&"dead")
	_player.set_mouse_captured(false)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.03, 0.04, .72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var label := Label.new()
	label.text = "ВЫ ПОГИБЛИ\nПадение за пределы карты\n\nR — начать заново"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(label)

func _show_physics_fault() -> void:
	preview_physics_fault = true
	_player.set_mouse_captured(false)
	var layer := CanvasLayer.new()
	layer.layer = 21
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	layer.add_child(panel)
	var label := Label.new()
	label.text = "Не удалось восстановить движение персонажа.\nR — перезапустить тестовую сцену"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	panel.add_child(label)
	push_error("Character physics stopped: " + preview_transport.character_physics.fault_reason)


func _bind_final_dead_contact_port(measured_limits: Dictionary = FINAL_DEAD_CONTACT_LIMITS) -> bool:
	if preview_population == null or not is_instance_valid(_player) or not _player.has_method("set_final_dead_contact_owner"):
		final_dead_contact_status = "unavailable_player_or_population"
		return false
	var options := measured_limits.duplicate(true)
	if _final_dead_block_requested: options["contact_schema"] = "npc_final_dead_contact/v2"
	var registered: Dictionary = preview_population.setup_final_dead_contact(_player, options)
	if not registered.get("ok",false):
		final_dead_contact_status = str(registered.get("reason","owner_registration_failed"))
		return false
	if _final_dead_block_requested:
		if registered.get("schema") != "npc_final_dead_contact/v2":
			final_dead_contact_status = "v2_registration_schema_mismatch"
			return false
		var contract: Dictionary = preview_population.player_final_dead_block_contract()
		var pressure_bound: bool = _player.set_final_dead_pressure_owner(Callable(preview_population,"player_final_dead_contact_ready"), Callable(preview_population,"admit_player_final_dead_contact"), contract)
		final_dead_contact_status = "v2_bound_waiting_final_death" if pressure_bound else "v2_binding_failed_filters_unchanged"
		final_dead_block_contract_status = "active_movement1025_support1" if pressure_bound else "activation_failed_filters_unchanged"
		return pressure_bound
	var bound: bool = _player.set_final_dead_contact_owner(Callable(preview_population,"player_final_dead_contact_ready"), Callable(preview_population,"admit_player_final_dead_contact"))
	final_dead_contact_status = "bound_waiting_final_death" if bound else "binding_failed"
	return bound
