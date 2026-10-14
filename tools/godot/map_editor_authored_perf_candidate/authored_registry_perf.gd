extends "res://scripts/map_editor/object_registry.gd"
## Identical participants and snapshots; collect root bodies/bounds in one walk.
func register_object(id: String,root: Node3D,record: Dictionary,dependencies: Array=[],editable: bool=true) -> Dictionary:
	if id.is_empty() or _entries.has(id) or not is_instance_valid(root): return {"ok":false,"error":"Invalid or duplicate identity"}
	if not root.is_inside_tree() or not root.global_transform.basis.determinant()>0.000001: return {"ok":false,"error":"Invalid source transform"}
	var participants: Array = []
	var seen := {}
	for node: Variant in [root]+dependencies:
		if not node is Node3D or not is_instance_valid(node) or not node.is_inside_tree(): return {"ok":false,"error":"Missing dependent node"}
		if seen.has(node.get_instance_id()): continue
		seen[node.get_instance_id()] = true
		if node!=root and root.is_ancestor_of(node): continue
		participants.append({"node":weakref(node),"frame":node.global_transform,"visible":node.visible})
	var bodies: Array = []
	var bounds: Array = []
	_collect_root(root,root.global_transform.affine_inverse(),bodies,bounds,{})
	for participant: Dictionary in participants:
		if participant.node.get_ref()!=root: _collect_bodies(participant.node.get_ref(),bodies,{})
	_entries[id] = {"root":weakref(root),"base":root.global_transform,"participants":participants,"bodies":bodies,"record":record.duplicate(true),"editable":editable,"bounds":bounds,"deleted":false}
	var opaque := record.duplicate(true)
	opaque.erase("transform")
	opaque.id = id
	var extra: Dictionary = record.get("transform",{}).duplicate(true)
	for key in ["position","rotation","scale"]: extra.erase(key)
	_entries[id].opaque = opaque
	_entries[id].opaque_transport = TrustedJSON.transport(opaque)
	_entries[id].transform_extra = extra
	_entries[id].transform_extra_transport = TrustedJSON.transport(extra)
	return {"ok":true}
func _collect_root(node: Node,inverse: Transform3D,bodies: Array,bounds: Array,seen: Dictionary) -> void:
	if node is CollisionObject3D and not seen.has(node.get_instance_id()):
		seen[node.get_instance_id()] = true
		bodies.append({"node":weakref(node),"layer":node.collision_layer,"mask":node.collision_mask})
	if node is MeshInstance3D and node.mesh!=null and node.is_visible_in_tree(): bounds.append((inverse*node.global_transform)*node.get_aabb())
	for child: Node in node.get_children(): _collect_root(child,inverse,bodies,bounds,seen)
