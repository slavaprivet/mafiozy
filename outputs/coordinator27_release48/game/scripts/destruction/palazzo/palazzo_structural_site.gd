extends "palazzo_finished_site.gd"
## Finished facade with the same bounded support helper used by support39.
const Support = preload("building_support.gd")
var support_setup: Dictionary={}
var _support_ground: Array[StaticBody3D]=[]

func _ready() -> void:
	super._ready()
	if site_ready: configure_structure()

func configure_structure(ground: Array[StaticBody3D]=[]) -> Dictionary:
	_support_ground=ground.duplicate()
	if _structure!=null: _structure.dispose()
	_structure=Support.new()
	support_setup=_structure.configure(self,{"ground_bodies":_support_ground})
	if not support_setup.get("ok",false):
		site_error="structural_support:"+str(support_setup)
		push_error(site_error)
	return support_setup.duplicate(true)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _structure!=null and site_ready and not rebuilding and not collapsing:
		_structure.advance(delta)

func _door_finished() -> void:
	super._door_finished()
	_mark_structure_dirty()

func reset_building() -> void:
	if rebuilding or not site_ready: return
	if _structure!=null: _structure.cancel()
	await super.reset_building()
	if is_inside_tree() and site_ready and not rebuilding: configure_structure(_support_ground)

func _support_expand_piece(body: RigidBody3D) -> Array[RigidBody3D]:
	var chunks: Array[RigidBody3D]=[]
	if not owns_collider(body) or not body.freeze or body.get_meta("detached",false): return chunks
	if body.get_meta("pooled_fragments",[]).is_empty() or body.get_meta("fracture_active",false):
		chunks.append(body); return chunks
	if body==_door: _stop_door()
	_break_glass_for_wall(body)
	for chunk: RigidBody3D in body.get_meta("pooled_fragments"):
		chunk.transform=body.transform*Transform3D(Basis.IDENTITY,chunk.get_meta("panel_center"))
		chunk.show(); chunk.collision_layer=1; chunk.collision_mask=1|RUBBLE_LAYER
		if not pieces.has(chunk): pieces.append(chunk)
		_queue_render(chunk)
		if not chunk.get_meta("detached",false): chunks.append(chunk)
	pieces.erase(body); initial_transforms.erase(body.get_instance_id())
	body.hide(); _queue_render(body)
	for child: Node in body.get_children():
		if child is CollisionShape3D: child.disabled=true
	body.collision_layer=0; body.collision_mask=0; body.set_meta("fracture_active",true)
	_sync_batches()
	site_status="structural_collapse"
	# The caller finishes its own transfer batch before requesting a fresh graph.
	return chunks

func get_stats() -> Dictionary:
	var stats: Dictionary=super.get_stats()
	stats.structural_setup=support_setup.duplicate(true)
	if _structure!=null: stats.structural=_structure.diagnostics()
	return stats

func _exit_tree() -> void:
	if _structure!=null: _structure.dispose(); _structure=null
	if is_instance_valid(_glazing): _glazing.dispose(); _glazing=null
