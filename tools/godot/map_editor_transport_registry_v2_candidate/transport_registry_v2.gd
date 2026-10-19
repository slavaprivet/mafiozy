extends "res://transport_registry.gd"
## Rail geometry is admitted only after exact source visual owner construction.
## Does not assign a new route/train identity or activate motion.
func configure(factory: RefCounted,owner: Callable = Callable()) -> Dictionary:
	if not factory._roots.has("railway") or factory._train_roots.size()!=3: return _fail("Rail geometry HOLD trusted source visual owner")
	for id: String in factory._records:
		if not factory._parts.has(id) or factory._parts[id].is_empty(): return _fail("All265 native source linkages required")
	var configured := super.configure(factory,owner)
	if configured.ok:
		configured.railway = "32-source-native-links-owner-required"
		configured.nativeObjects = _records.size()
	return configured
func _bound(id: String) -> void:
	super._bound(id)
	var bounds: Variant = _bounds.get(id)
	for part: Dictionary in _factory._parts.get(id,[]):
		var batch: Dictionary = _factory._batches[part.batch]
		if batch.source.has("geometry"): continue
		for child: Node in batch.node.get_children():
			if not child is MeshInstance3D or child.mesh==null: continue
			var frame: Transform3D = batch.node.transform * child.transform
			frame.origin -= _factory._origin
			var box: AABB = frame * child.mesh.get_aabb()
			bounds = box if bounds==null else bounds.merge(box)
	if bounds!=null: _bounds[id] = bounds
func capture_install_checkpoint() -> Dictionary:
	var checkpoint := super.capture_install_checkpoint()
	if not checkpoint.ok: return checkpoint
	var extra := []
	var geometry: Array[Node] = []
	for batch: Dictionary in _factory._batches.values():
		if batch.node is MeshInstance3D: geometry.append(batch.node)
	for car: Node3D in _factory._train_roots:
		extra.append({"node":weakref(car),"children":car.get_children().map(func(node: Node): return weakref(node))})
		geometry.append_array(car.get_children())
	for node: Node in geometry:
		if not node is MeshInstance3D: return _fail("Unexpected train geometry dependency")
		extra.append({"node":weakref(node),"parent":weakref(node.get_parent()),"mesh":node.mesh,"material":node.material_override,"frame":node.transform,"immutable_child":node.get_parent() in _factory._train_roots})
	_tokens[checkpoint.token.get_instance_id()].state.rail_dependencies = extra
	return checkpoint
func restore_install_checkpoint(capsule: Dictionary) -> Dictionary:
	if not capsule.get("token") is RefCounted or not _tokens.has(capsule.token.get_instance_id()): return _fail("Unadmitted rail checkpoint")
	var state: Dictionary = _tokens[capsule.token.get_instance_id()].state
	for binding: Dictionary in state.get("rail_dependencies",[]):
		var node: Variant = binding.node.get_ref()
		if not is_instance_valid(node) or not node.is_inside_tree(): return _fail("Original rail dependency gone; keep paused")
		if binding.has("children"):
			if node.get_child_count()!=binding.children.size(): return _fail("Train child ownership changed")
			for index in binding.children.size():
				if node.get_child(index)!=binding.children[index].get_ref(): return _fail("Original train child ownership changed")
		elif node.get_parent()!=binding.parent.get_ref() or node.mesh!=binding.mesh or node.material_override!=binding.material or (binding.immutable_child and node.transform!=binding.frame):
			return _fail("Original rail mesh/material/offset replaced; keep paused")
	return super.restore_install_checkpoint(capsule)
