extends "res://scripts/destruction/palazzo/palazzo_structural_site.gd"
## Isolated candidate: original foundation volume becomes ordinary owned stone.
## World plaza, main/player, C4 authority and accepted support rules are inherited.
const FOUNDATION_SIZE := Vector3(8.5, .22, 6.5)
const FOUNDATION_AT := Vector3(0, .19, 0)
const FOUNDATION_COLOR := Color("d8d0b9")
const FOUNDATION_COLS := 4
const FOUNDATION_ROWS := 3
const FOUNDATION_CHUNK_COUNT := FOUNDATION_COLS * FOUNDATION_ROWS
var foundation_chunks: Array[RigidBody3D] = []
var _foundation_source_removed := false
var _foundation_source_error := ""
var _foundation_batches_this_build := 0
var _foundation_owned_without_chunks := 0

func _build_site() -> void:
	super._build_site()
	# This is cold construction before the first physics step/support configure,
	# never a runtime delete used to clear a measured passage.
	var original: StaticBody3D = get_node_or_null("OriginalFoundation") as StaticBody3D
	if not is_instance_valid(original) or original.get_parent() != self or not original.transform.is_equal_approx(Transform3D(Basis.IDENTITY, FOUNDATION_AT)):
		_foundation_source_error = "original_foundation_identity_or_frame"; return
	var count := 0
	for child: Node in original.get_children():
		if not child is CollisionShape3D: continue
		count += 1
		if child.disabled or not child.transform.is_equal_approx(Transform3D.IDENTITY) or not child.shape is BoxShape3D or not child.shape.size.is_equal_approx(FOUNDATION_SIZE):
			_foundation_source_error = "original_foundation_geometry"; return
	if count != 1:
		_foundation_source_error = "original_foundation_shape_count"; return
	remove_child(original)
	original.free()
	_foundation_source_removed = true

func _build_building() -> void:
	foundation_chunks.clear()
	_foundation_batches_this_build = 0
	# The source would otherwise batch the architecture before these chunks
	# existed. Build all meshes once, then submit one inherited batch build.
	var requested_batching: bool = batched
	batched = false
	super._build_building()
	_foundation_owned_without_chunks = _owned_bodies.size()
	if _foundation_source_removed and _foundation_source_error.is_empty():
		var cell := Vector3(FOUNDATION_SIZE.x / FOUNDATION_COLS, FOUNDATION_SIZE.y, FOUNDATION_SIZE.z / FOUNDATION_ROWS)
		for row: int in FOUNDATION_ROWS:
			for column: int in FOUNDATION_COLS:
				var at := FOUNDATION_AT + Vector3(-FOUNDATION_SIZE.x * .5 + (column + .5) * cell.x, 0, -FOUNDATION_SIZE.z * .5 + (row + .5) * cell.z)
				# Finished-site piece() preserves exact intact box/mesh size and
				# registers source ownership, initial pose, ordinary rigid physics.
				var body: RigidBody3D = piece("FoundationChunk", cell, at, FOUNDATION_COLOR)
				body.set_meta("foundation_chunk", true)
				body.set_meta("foundation_grid", Vector2i(column, row))
				body.set_meta("foundation_generation", rebuild_generation)
				body.set_meta("pooled_fragments", [])
				foundation_chunks.append(body)
	else:
		_finished_errors.append("foundation_candidate:" + _foundation_source_error)
	batched = requested_batching
	if batched:
		_build_batches()
		_foundation_batches_this_build += 1
	_finished_initial_sections = pieces.size()

func get_stats() -> Dictionary:
	var result: Dictionary = super.get_stats()
	var intact := 0
	var detached := 0
	var invalid := 0
	for body: RigidBody3D in foundation_chunks:
		if not is_instance_valid(body) or not owns_collider(body): invalid += 1; continue
		if body.get_meta("detached", false): detached += 1
		elif body.freeze and (body.collision_layer & 1) != 0: intact += 1
	result.foundation = {"candidate":true, "source_static_removed_during_cold_build":_foundation_source_removed, "source_error":_foundation_source_error, "chunks":foundation_chunks.size(), "intact":intact, "detached":detached, "invalid":invalid, "grid":[FOUNDATION_COLS, FOUNDATION_ROWS], "size":[FOUNDATION_SIZE.x, FOUNDATION_SIZE.y, FOUNDATION_SIZE.z], "centre":[FOUNDATION_AT.x, FOUNDATION_AT.y, FOUNDATION_AT.z], "top_y":.30, "hidden_foundation_pool":0, "owned_without_foundation":_foundation_owned_without_chunks, "additional_owned_bodies":FOUNDATION_CHUNK_COUNT, "batch_builds_this_generation":_foundation_batches_this_build, "generation":rebuild_generation, "actual_C4_passage":"NOT_RUN", "loaded_scene_performance":"NOT_RUN"}
	return result
