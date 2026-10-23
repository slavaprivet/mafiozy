extends RefCounted
## Shared CPU geometry only. Actor transforms, posed vertices and query state
## never enter this cache. Weak mesh ownership permits retired cut meshes to die.
const MAX_MESHES := 128
const MAX_VARIANTS := 8
static var _meshes: Dictionary = {}
static var _clock := 0
static var hits := 0
static var misses := 0

static func get_surfaces(mesh: ArrayMesh, bind_bones: PackedInt32Array, bone_names: PackedStringArray) -> Array:
	_clock += 1
	var key := mesh.get_instance_id()
	var row: Dictionary = _meshes.get(key, {})
	if not row.is_empty() and row.mesh.get_ref() == mesh:
		for variant: Dictionary in row.variants:
			if variant.bind_bones == bind_bones and variant.bone_names == bone_names:
				row.used = _clock; variant.used = _clock; hits += 1
				return variant.surfaces
	misses += 1
	return []

static func put_surfaces(mesh: ArrayMesh, bind_bones: PackedInt32Array, bone_names: PackedStringArray, surfaces: Array) -> void:
	_clock += 1
	# Cleanup is bounded and occurs only on a cold topology insertion.
	for old_key: int in _meshes.keys():
		if _meshes[old_key].mesh.get_ref() == null: _meshes.erase(old_key)
	var key := mesh.get_instance_id()
	if not _meshes.has(key):
		if _meshes.size() >= MAX_MESHES:
			var oldest: int = _meshes.keys()[0]
			for old_key: int in _meshes:
				if int(_meshes[old_key].used) < int(_meshes[oldest].used): oldest = old_key
			_meshes.erase(oldest)
		_meshes[key] = {"mesh": weakref(mesh), "used": _clock, "variants": []}
	var row: Dictionary = _meshes[key]
	row.used = _clock
	for variant: Dictionary in row.variants:
		if variant.bind_bones == bind_bones and variant.bone_names == bone_names:
			variant.surfaces = surfaces; variant.used = _clock
			return
	if row.variants.size() >= MAX_VARIANTS:
		var oldest := 0
		for index: int in row.variants.size():
			if int(row.variants[index].used) < int(row.variants[oldest].used): oldest = index
		row.variants.remove_at(oldest)
	row.variants.append({"bind_bones": bind_bones.duplicate(), "bone_names": bone_names.duplicate(), "surfaces": surfaces, "used": _clock})

static func report() -> Dictionary:
	return {"meshes": _meshes.size(), "hits": hits, "misses": misses, "limit": MAX_MESHES}
