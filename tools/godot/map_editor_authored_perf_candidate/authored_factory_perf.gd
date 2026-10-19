extends "res://scripts/map_editor/catalog_factory.gd"
## Memoises only the original name predicate. Never prunes original scene nodes.
const MAX_CONTEXTS := 64
var _hide_contexts := {}
var _hide_depth := 0
var _hide_decisions := {}
var _explicit_names := {}
func configure(data: Dictionary,root_path: String="res://assets/map_editor/",trusted_adapters: Dictionary={}) -> bool:
	_hide_contexts.clear()
	return super.configure(data,root_path,trusted_adapters)
func _hide_helpers(node: Node,explicit_names: Array) -> void:
	if _hide_depth==0:
		var texts: Array[String] = []
		for original in explicit_names: texts.append(str(original))
		var signature := _helpers.get_pattern()+":"+JSON.stringify(texts)
		if not _hide_contexts.has(signature):
			if _hide_contexts.size()>=MAX_CONTEXTS: _hide_contexts.erase(_hide_contexts.keys()[0])
			var names := {}
			for original: String in texts:
				names[original] = true
				names[original.validate_node_name()] = true
			_hide_contexts[signature] = {"names":names,"decisions":{}}
		_hide_decisions = _hide_contexts[signature].decisions
		_explicit_names = _hide_contexts[signature].names
	_hide_depth += 1
	var name := str(node.name)
	if not _hide_decisions.has(name): _hide_decisions[name] = _explicit_names.has(name) or _helpers.search(name)!=null
	if _hide_decisions[name] and node is Node3D: node.visible = false
	for child: Node in node.get_children(): _hide_helpers(child,explicit_names)
	_hide_depth -= 1
