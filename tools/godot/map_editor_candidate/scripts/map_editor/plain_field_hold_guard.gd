extends RefCounted
## Negative-safe prerequisite only. Never authorizes script-field coalescing:
## Godot exposes no sufficient compiled-member/lifecycle attestation here.
## Reads native Script/Node metadata; NEVER reads participant script fields,
## calls old Host, or invokes a source-owner Callable.
var _owner: WeakRef
var _owner_parent: WeakRef
var _bindings: Array = []
var _held: Array = []
var _retained := false
var _configured := false
static func failure(message: String) -> Dictionary: return {"ok": false, "state": "HOLD", "error": message}
static func _plain_shape(script: GDScript, fields: Array) -> bool:
	if fields.is_empty(): return true # Entire helper script binding, not var approval.
	if script.get_base_script() != null: return false
	var source := script.source_code
	if RegEx.create_from_string("(?m)^\\s*func\\s+_(get|set|get_property_list)\\s*\\(").search(source) != null: return false
	for field: Variant in fields:
		if not field is String or RegEx.create_from_string("^[A-Za-z_][A-Za-z_0-9]*$").search(field) == null: return false
		# Deliberately conservative: duplicate/nested/annotated/comment-string
		# declarations of the same name refuse rather than guessing a parser tree.
		var declarations := RegEx.create_from_string("\\bvar\\s+" + field + "\\b").search_all(source)
		if declarations.size() != 1: return false
		var declaration: String = source.get_slice("\n", source.left(declarations[0].get_start()).count("\n")).trim_suffix("\r")
		var simple := RegEx.create_from_string("^var\\s+" + field + "(?:\\s*:\\s*[A-Za-z_][A-Za-z_0-9]*(?:\\[[A-Za-z_][A-Za-z_0-9]*\\])?)?\\s*(?:=|:=)\\s*(?:-?[0-9]+(?:\\.[0-9]+)?|true|false|\\{\\}|\\[\\]|[A-Za-z_][A-Za-z_0-9]*\\.(?:ZERO|IDENTITY)|\"[^\"#\\\\]*\"|&\"[^\"#\\\\]*\")\\s*(?:#.*)?$")
		if simple.search(declaration) == null or script.has_script_method("@" + field + "_getter") or script.has_script_method("@" + field + "_setter"): return false
	return true
func configure(owner: Node, source_bindings: Array, native_hold_inventory: Array) -> Dictionary:
	if not Thread.is_main_thread() or _configured or not is_instance_valid(owner) or not owner.is_inside_tree() or source_bindings.is_empty(): return failure("Current owner and explicit source bindings required")
	var captured: Array = []
	for supplied: Variant in source_bindings:
		if not supplied is Dictionary or not supplied.get("object") is Object or not supplied.get("scripts") is Array or supplied.scripts.is_empty(): return failure("Explicit live object and exact full Script chain required")
		var object: Object = supplied.object
		if not is_instance_valid(object) or not supplied.get("fields", []) is Array: return failure("Invalid source field binding")
		var actual: Script = object.get_script()
		var chain: Array = []
		for admission: Variant in supplied.scripts:
			if not admission is Dictionary or not admission.get("script") is GDScript or not admission.get("sha256") is String or admission.script != actual or actual.source_code.sha256_text() != admission.sha256: return failure("Unadmitted Script instance/source SHA or inheritance chain")
			chain.append({"script": actual, "source": actual.source_code, "instance": actual.get_instance_id()})
			actual = actual.get_base_script()
		if actual != null or not _plain_shape(chain[0].script, supplied.get("fields", [])): return failure("Getter/annotation/multiline/inherited/ambiguous field source shape refused")
		var parent: WeakRef = null
		if object is Node:
			if not object.is_inside_tree() or (object != owner and not owner.is_ancestor_of(object)): return failure("Foreign source node")
			parent = weakref(object.get_parent())
		var identity: Dictionary = supplied.get("identity", {})
		for key in identity:
			if not object.has_meta(key) or object.get_meta(key) != identity[key]: return failure("Source lifetime metadata mismatch")
		captured.append({"object": weakref(object), "instance": object.get_instance_id(), "parent": parent, "chain": chain, "identity": identity.duplicate(true)})
	var held: Array = []
	for supplied: Variant in native_hold_inventory:
		if not supplied is Dictionary or not supplied.get("node") is Node: return failure("Explicit native hold participant required")
		var node: Node = supplied.node
		if not node.is_inside_tree() or (node != owner and not owner.is_ancestor_of(node)): return failure("Foreign native hold participant")
		var identity: Dictionary = supplied.get("identity", {})
		for key in identity:
			if not node.has_meta(key) or node.get_meta(key) != identity[key]: return failure("Hold lifetime mismatch")
		held.append({"node": weakref(node), "parent": weakref(node.get_parent()), "instance": node.get_instance_id(), "identity": identity.duplicate(true), "stop_input": supplied.get("stop_input", true)})
	_owner = weakref(owner)
	_owner_parent = weakref(owner.get_parent())
	_bindings = captured
	_held = held
	_configured = true
	return {"ok": true, "configured_only": true, "source_shape_checked": true, "state": "HOLD", "compiled_plainness_attested": false}
func _source_unchanged() -> bool:
	var owner: Node = _owner.get_ref() if _owner != null else null
	if not is_instance_valid(owner) or not owner.is_inside_tree() or owner.get_parent() != _owner_parent.get_ref(): return false
	for binding: Dictionary in _bindings:
		var object: Object = binding.object.get_ref()
		if not is_instance_valid(object) or object.get_instance_id() != binding.instance: return false
		if object is Node and (not object.is_inside_tree() or object.get_parent() != binding.parent.get_ref() or (object != owner and not owner.is_ancestor_of(object))): return false
		for key in binding.identity:
			if not object.has_meta(key) or object.get_meta(key) != binding.identity[key]: return false
		var actual: Script = object.get_script()
		for saved: Dictionary in binding.chain:
			if actual != saved.script or actual.get_instance_id() != saved.instance or actual.source_code != saved.source: return false
			actual = actual.get_base_script()
		if actual != null: return false
	return true
func _hold_surviving_owned() -> void:
	var owner: Node = _owner.get_ref() if _owner != null else null
	if not is_instance_valid(owner) or not owner.is_inside_tree(): return
	for saved: Dictionary in _held:
		var node: Node = saved.node.get_ref()
		if not is_instance_valid(node) or not node.is_inside_tree() or node.get_parent() != saved.parent.get_ref() or node.get_instance_id() != saved.instance or (node != owner and not owner.is_ancestor_of(node)): continue
		var live := true
		for key in saved.identity:
			if not node.has_meta(key) or node.get_meta(key) != saved.identity[key]: live = false
		if not live: continue # Never take a new generation's authority.
		node.set_process(false)
		node.set_physics_process(false)
		if saved.stop_input: node.set_process_input(false)
		node.set_process_unhandled_input(false)
		node.set_process_unhandled_key_input(false)
		node.set_process_shortcut_input(false)
		if node is Timer: node.paused = true
		if node is RigidBody3D:
			node.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			node.freeze = true
		if node is AnimationMixer: node.active = false
func before_input() -> Dictionary:
	if not Thread.is_main_thread() or not _configured: return failure("Unconfigured/off-thread source lifecycle guard")
	var unchanged := _source_unchanged()
	# ALWAYS HOLD until genuine load+ALL-reload lifecycle capsule exists. Even
	# perfect source equality cannot prove a reverted named-getter reload safe.
	if not unchanged: _retained = true
	_hold_surviving_owned()
	return {"ok": false, "handled": true, "state": "HOLD", "source_unchanged": unchanged, "retained": _retained, "legacy_authorized": false, "compiled_plainness_attested": false, "required": "Genuine source-owner compile/load and ALL source-code/reload lifecycle capsule; no generic trust bool"}
