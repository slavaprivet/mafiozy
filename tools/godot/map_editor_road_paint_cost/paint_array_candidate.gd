extends "res://scripts/procedural_factory.gd"
## CPU-only diagnostic: skip copying the OLD vertex array that is replaced anyway.
## Nonvertex channels are explicitly duplicated; shallow Packed channel aliases unsafe.
func copy_paint_channels(original: Array) -> Array:
	var result: Array = []
	result.resize(original.size())
	for channel_index in original.size():
		if channel_index == Mesh.ARRAY_VERTEX: continue
		var channel: Variant = original[channel_index]
		if channel == null: continue
		if channel is Array or channel is Dictionary:
			result[channel_index] = channel.duplicate(true)
		else: result[channel_index] = channel.duplicate()
	return result
func _paint_commit(id: String, frame: Transform3D, deleted: bool) -> bool:
	if not _road_adapter.is_valid(): return false
	var part: Dictionary = _paint_ids[id]
	var batch: Dictionary = _paint_batches[part.batch]
	var vertices: PackedVector3Array = batch.current.duplicate()
	var delta := Transform3D(frame.basis, frame.origin + _origin) * (_source_frames[id] as Transform3D).affine_inverse()
	for index in range(int(part.first), int(part.first) + 6):
		vertices[index] = (_source_frames[id] as Transform3D).origin if deleted else delta * batch.base[index]
	var arrays: Array = copy_paint_channels(batch.arrays)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var replacement := ArrayMesh.new()
	replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	replacement.set_meta("source_geometry", _meshes[batch.source.geometry].get_meta("source_geometry"))
	var command := {"kind":"paint","id":id,"batch":part.batch,"before":batch.current,"after":vertices,"meshBefore":batch.node.mesh,"meshAfter":replacement,"deletedBefore":_deleted.get(id,false),"deletedAfter":deleted,"frameBefore":_current_frames[id],"frameAfter":frame}
	if not _perform(command,true,"delete" if deleted else "transform"): return false
	_deleted[id] = deleted; _current_frames[id] = frame
	_history.append(command); _redo.clear()
	return true
