extends RefCounted
## Source water facts for the verified S01 crop. No combined ground or admission.
## Reuses the source landscape sampler; never derives gameplay from shader depth.
const Landscape = preload("res://scripts/npc_visual/npc_source_landscape_support.gd")
const BLOCK_SHA := "1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e"
var _provider: RefCounted
var _owner: WeakRef
var _origin_x := 0.0
var _origin_y := 0.0
var _origin_z := 0.0
var _min_x := 0.0
var _min_z := 0.0
var _max_x := 0.0
var _max_z := 0.0
var _fault := ""

static func _hash(bytes: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): h.update(bytes)
	return h.finish().hex_encode()

static func _unknown(reason: String) -> Dictionary:
	return {"known":false,"defined":false,"value":null,"error":reason,"physical_admission":false,"combined_ground":false}

func configure(owner: Node, block_bytes: PackedByteArray, terrain_bytes: PackedByteArray) -> Dictionary:
	if not Thread.is_main_thread(): return {"ok":false,"error":"thread"}
	if _provider != null or _owner != null or not _fault.is_empty(): return {"ok":false,"error":"state"}
	if not is_instance_valid(owner) or not owner.is_inside_tree() or owner.is_queued_for_deletion(): return {"ok":false,"error":"owner"}
	# Block export is LF JSON. Do not silently normalize or rebind another crop.
	if _hash(block_bytes) != BLOCK_SHA or _hash(terrain_bytes) != Landscape.DATA_SHA: return {"ok":false,"error":"static_bytes"}
	var block: Dictionary = JSON.parse_string(block_bytes.get_string_from_utf8())
	var packet: Dictionary = JSON.parse_string(terrain_bytes.get_string_from_utf8())
	var surface: Dictionary = block.surface
	var topology: Dictionary = packet.data.topology
	# Full source topology supplies shoreline neighbours outside the visible crop.
	for r in int(surface.rows):
		for c in int(surface.cols):
			var sr: int = r + int(surface.startRow)
			var sc: int = c + int(surface.startCol)
			if surface.grid[r][c] != topology.grid[sr][sc]: return {"ok":false,"error":"crop_tile"}
			for key: String in surface.masks:
				if not topology.has(key) or surface.masks[key][r][c] != topology[key][sr][sc]: return {"ok":false,"error":"crop_mask"}
	var candidate: RefCounted = Landscape.new()
	var setup: Dictionary = candidate.configure(terrain_bytes, {
		"data_sha256":Landscape.DATA_SHA,"source_world_sha256":Landscape.SOURCE_SHA,
		"context_sha256":Landscape.CONTEXT_SHA,"session_id":Landscape.SESSION,"phase":Landscape.PHASE,
		"snapshot_id":"S01_STATIC_CROP:" + BLOCK_SHA,"revision":0})
	if not setup.get("ok", false): return setup
	# Keep original JSON doubles; converting origin through Vector3 loses precision.
	_origin_x = float(block.originM[0]); _origin_y = float(block.originM[1]); _origin_z = float(block.originM[2])
	_min_x = float(surface.boundsLocalM.min[0]); _min_z = float(surface.boundsLocalM.min[2])
	_max_x = float(surface.boundsLocalM.max[0]); _max_z = float(surface.boundsLocalM.max[2])
	_owner = weakref(owner); _provider = candidate
	owner.tree_exiting.connect(_on_owner_exit, CONNECT_ONE_SHOT)
	return {"ok":true,"physical_admission":false,"combined_ground":false,"static_crop_sha256":BLOCK_SHA}

func _on_owner_exit() -> void:
	dispose("owner_retired")

func water_at(local_x: float, local_z: float) -> Dictionary:
	if not Thread.is_main_thread(): return _unknown("thread")
	if _provider == null or _owner == null or not _fault.is_empty(): return _unknown(_fault if not _fault.is_empty() else "unconfigured")
	var owner: Node = _owner.get_ref()
	if not is_instance_valid(owner) or not owner.is_inside_tree():
		dispose("owner_retired")
		return _unknown("owner_retired")
	var ancestor: Node = owner
	while ancestor != null:
		if ancestor.is_queued_for_deletion():
			dispose("owner_retired")
			return _unknown("owner_retired")
		ancestor = ancestor.get_parent()
	if not is_finite(local_x) or not is_finite(local_z): return _unknown("coordinates")
	if local_x < _min_x or local_x >= _max_x or local_z < _min_z or local_z >= _max_z: return _unknown("outside_crop")
	var result: Dictionary = _provider.water_at(local_x + _origin_x, local_z + _origin_z)
	if result.get("known", false) and result.get("defined", false) and result.value is Dictionary:
		# Provider returns owned dictionaries. Preserve source proof and world values.
		result["source_world_value"] = result.value.duplicate()
		result.value.level -= _origin_y
		result.value.floor -= _origin_y
	result["coordinate_space"] = "preview_local_metres"
	result["static_crop_sha256"] = BLOCK_SHA
	return result

func dispose(reason: String = "disposed") -> void:
	if not Thread.is_main_thread(): return
	if _fault.is_empty(): _fault = reason
	var owner: Node = _owner.get_ref() if _owner != null else null
	if is_instance_valid(owner) and owner.tree_exiting.is_connected(_on_owner_exit):
		owner.tree_exiting.disconnect(_on_owner_exit)
	if _provider != null: _provider.invalidate(_fault)
	_provider = null
	_owner = null
