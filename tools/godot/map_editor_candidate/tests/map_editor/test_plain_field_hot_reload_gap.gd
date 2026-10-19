extends SceneTree
## A real native regression: text/hash/metadata cannot attest compiled getter
## bindings. No participant field is read until the final explicit probe.
var checks := 0
var failed := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed += 1
		push_error(label)
func _initialize() -> void:
	var script := GDScript.new()
	var original := "extends Node\nvar clock: int = 0\nvar effects: int = 0\nfunc read_clock() -> int:\n\teffects += 1\n\treturn 9\n"
	script.source_code = original
	check(script.reload() == OK, "Original direct plain var compiled by native Godot")
	var source_sha := script.source_code.sha256_text()
	var original_instance := script.get_instance_id()
	var original_methods := script.get_script_method_list()
	var original_properties := script.get_script_property_list()
	var notifications := [0]
	script.changed.connect(func(): notifications[0] += 1)
	var changed := original.replace("var clock: int = 0\n", "var clock: int = 0:\n\tget = read_clock\n")
	script.source_code = changed
	check(notifications[0] == 0, "source_code setter emits no Resource.changed")
	check(script.reload(true) == OK and notifications[0] == 0, "Native reload(true) emits no Resource.changed")
	script.source_code = original # Does NOT recompile; getter remains installed.
	check(script.source_code == original and script.source_code.sha256_text() == source_sha, "Exact SourceString and SHA reverted to original")
	check(script.get_instance_id() == original_instance, "Exact resource instance unchanged")
	check(script.get_base_script() == null and script.get_instance_base_type() == "Node", "Native inheritance metadata still identical")
	check(script.get_script_method_list() == original_methods, "Named getter alias uses existing method; compiled method metadata identical")
	check(script.get_script_property_list() == original_properties, "Native property metadata identical")
	check(not script.has_script_method("@clock_getter"), "No generated getter name to detect named alias")
	var node: Node = script.new()
	check(node.get("effects") == 0, "All attempted readonly metadata checks avoided getter invocation")
	check(node.get("clock") == 9 and node.get("effects") == 1, "Explicit probe proves hidden compiled getter executes despite every matching readonly check")
	node.free()
	print(JSON.stringify({"suite":"plain-field-hot-reload-gap", "checks":checks,"failures":failed,"source_equality_is_bytecode_attestation":false,"resource_changed_tracks_reload":false,"named_getter_alias_visible_in_metadata":false,"production_wired":false,"required":"real source-owner load/lifecycle capsule or native compiled-member attestation"}))
	quit(0 if failed == 0 else 1)
