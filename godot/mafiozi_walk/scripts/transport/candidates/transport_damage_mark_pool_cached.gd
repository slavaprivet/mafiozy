extends "res://scripts/transport/transport_damage_mark_pool.gd"
## Candidate hot-loop optimization only. It preserves the full 32-slot scan,
## resource/layout guards, source visibility/hierarchy, raw local poses and
## atomic validation. Target validity/global transforms are cached per unique
## bound WeakRef for this call. A Node transform write is skipped only when the
## current and desired Transform3D compare exactly equal (no epsilon).

var _scratch_visible:=PackedByteArray()
var _scratch_transforms: Array[Transform3D]=[]
var _cache_indices: Dictionary={}
var _cache_valid:=PackedByteArray()
var _cache_transforms: Array[Transform3D]=[]

func configure(vehicle_root_value: Variant,external_parent_value: Variant,target_bindings_value: Variant,generation_value: Variant) -> Dictionary:
	var result: Dictionary=super.configure(vehicle_root_value,external_parent_value,target_bindings_value,generation_value)
	if not result.get("ok",false): return result
	_scratch_visible.resize(POOL_SIZE); _scratch_visible.fill(0)
	_scratch_transforms.resize(POOL_SIZE)
	_cache_valid.resize(POOL_SIZE); _cache_valid.fill(0)
	_cache_transforms.resize(POOL_SIZE)
	for slot in POOL_SIZE:
		_scratch_transforms[slot]=Transform3D.IDENTITY
		_cache_transforms[slot]=Transform3D.IDENTITY
	return result

func reconcile_targets(expected_generation: Variant) -> Dictionary:
	var state:=_state(expected_generation)
	if not state.ok: return state
	if not _slots_valid(): return _error("slot_state")
	if not _finite_transform(_effects_root.global_transform): return _error("external_root")
	var effects_inverse:=_effects_root.global_transform.affine_inverse()
	_scratch_visible.fill(0); _cache_valid.fill(0); _cache_indices.clear()
	var cache_count:=0; var visible:=0
	for slot in POOL_SIZE:
		if _slot_active[slot]==0: continue
		var source_id:=_slot_sources[slot]; var cache_index: int=int(_cache_indices.get(source_id,-1))
		if cache_index<0:
			cache_index=cache_count; cache_count+=1; _cache_indices[source_id]=cache_index
			var target: Variant=null
			if _bindings.has(source_id): target=(_bindings[source_id].target as WeakRef).get_ref()
			if target is MeshInstance3D and is_instance_valid(target) and _target_valid(target):
				var target_transform: Transform3D=target.global_transform
				if not _finite_transform(target_transform): return _error("target_transform")
				_cache_valid[cache_index]=1; _cache_transforms[cache_index]=target_transform
		if _cache_valid[cache_index]==0: continue
		var next_transform:=effects_inverse*_cache_transforms[cache_index]*_slot_local_poses[slot]
		if not _finite_transform(next_transform): return _error("transform")
		_scratch_transforms[slot]=next_transform; _scratch_visible[slot]=1; visible+=1
	# Mutation starts only after every active target and desired pose validates.
	var changed:=0; var transform_writes:=0; var exact_transform_skips:=0
	for slot in POOL_SIZE:
		var should_show:=_scratch_visible[slot]!=0
		if should_show:
			if _slots[slot].transform==_scratch_transforms[slot]: exact_transform_skips+=1
			else: _slots[slot].transform=_scratch_transforms[slot]; transform_writes+=1
		if _slots[slot].visible!=should_show: _slots[slot].visible=should_show; changed+=1
	return {"ok":true,"generation":_generation,"checked":POOL_SIZE,"changed":changed,"visible":visible,"cursor":_cursor,"unique_targets":cache_count,"transform_writes":transform_writes,"exact_transform_skips":exact_transform_skips}

func dispose() -> void:
	_scratch_visible=PackedByteArray(); _scratch_transforms.clear(); _cache_indices.clear(); _cache_valid=PackedByteArray(); _cache_transforms.clear()
	super.dispose()
