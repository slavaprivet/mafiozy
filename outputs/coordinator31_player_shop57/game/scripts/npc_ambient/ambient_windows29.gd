extends Node
## One scene-local, weak glazing index. Native visibility/ray tests stay in the caller.
## Newly added panes are registered; destroyed panes are rejected/pruned on use.
const META := "npc_ambient_windows29"
var _scene: WeakRef
var _panes: Dictionary = {}
var _builds := 0

static func for_scene(scene: Node3D) -> Node:
	var existing: Variant = scene.get_meta(META) if scene.has_meta(META) else null
	if existing is WeakRef and is_instance_valid(existing.get_ref()):
		var existing_index: Node = existing.get_ref()
		if existing_index.get_parent() == scene and not existing_index.is_queued_for_deletion(): return existing_index
	var index: Node = load("res://scripts/npc_ambient/ambient_windows29.gd").new()
	index.name = "AmbientWindowIndex29"
	scene.add_child(index)
	index._scene = weakref(scene)
	# One original-order scan for the scene, not one scene traversal per resident/action.
	for owner: Node in scene.find_children("OwnedWindowGlazing", "Node3D", true, false):
		for child: Node in owner.get_children(): index._register(child)
	index._builds += 1
	scene.get_tree().node_added.connect(index._register)
	scene.set_meta(META, weakref(index))
	return index

func _register(node: Node) -> void:
	if not node is StaticBody3D or _scene == null: return
	var scene: Node = _scene.get_ref()
	var parent: Node = node.get_parent()
	if not is_instance_valid(scene) or parent == null or parent.name != "OwnedWindowGlazing" or not parent is Node3D or not scene.is_ancestor_of(node): return
	_panes[node.get_instance_id()] = weakref(node)

func panes() -> Array[WeakRef]:
	var result: Array[WeakRef] = []
	for id: int in _panes.keys():
		var node: Variant = _panes[id].get_ref()
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree():
			_panes.erase(id)
		else: result.append(_panes[id])
	return result

func snapshot() -> Dictionary:
	return {"scene_scans":_builds, "weak_panes":_panes.size()}
