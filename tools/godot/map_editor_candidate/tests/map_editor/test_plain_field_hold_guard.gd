extends SceneTree
const Guard = preload("res://scripts/map_editor/plain_field_hold_guard.gd")
var checks := 0
var failed := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var owner := Node3D.new()
	root.add_child(owner)
	var source := "extends Node3D\nsignal tapped\nvar clock: int = 0\nfunc read_clock() -> int:\n\ttapped.emit()\n\treturn 9\n"
	var script := GDScript.new()
	script.source_code = source
	check(script.reload() == OK, "Native script plain source")
	var actor: Node3D = script.new()
	owner.add_child(actor)
	actor.set_meta("generation", 7)
	var taps := [0]
	actor.connect("tapped", func(): taps[0] += 1)
	var body := RigidBody3D.new()
	body.gravity_scale = 0
	owner.add_child(body)
	body.set_meta("generation", 3)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	var timer := Timer.new()
	owner.add_child(timer)
	timer.start(20)
	var player := AnimationPlayer.new()
	owner.add_child(player)
	var guard := Guard.new()
	var inventory := [{"node": owner, "stop_input": false}, {"node": actor, "identity": {"generation": 7}}, {"node": body, "identity": {"generation": 3}}, {"node": timer}, {"node": player}]
	var bindings := [{"object": actor, "scripts": [{"script": script, "sha256": source.sha256_text()}], "fields": ["clock"], "identity": {"generation": 7}}]
	var configured: Dictionary = guard.configure(owner, bindings, inventory)
	check(configured.ok and configured.state == "HOLD" and configured.configured_only and not configured.compiled_plainness_attested, "Shape metadata config never grants lifecycle permission")
	var result: Dictionary = guard.before_input()
	check(not result.ok and result.handled and result.source_unchanged and not result.legacy_authorized and result.state == "HOLD", "Unchanged plain source stays HOLD without genuine lifecycle owner")
	check(taps[0] == 0 and body.freeze and timer.paused and not player.active and not actor.is_physics_processing(), "No field invocation; native surviving owners held")
	var old_left := timer.time_left
	var dirty_source := source.replace("var clock: int = 0\n", "var clock: int = 0:\n\tget = read_clock\n")
	script.source_code = dirty_source
	check(script.reload(true) == OK, "Real hotreload installed getter")
	result = guard.before_input()
	check(not result.source_unchanged and result.retained and result.handled and not result.legacy_authorized and taps[0] == 0, "Detected mutation retains hold BEFORE oldHost or getter")
	script.source_code = source
	result = guard.before_input()
	check(result.source_unchanged and result.retained and not result.ok and taps[0] == 0, "Text revert cannot clear previous retained fault or invoke hidden alias")
	check(timer.time_left == old_left and body.freeze and not player.active, "No source clock/physics/animation rewind on guard failure")
	var hidden_guard := Guard.new()
	check(hidden_guard.configure(owner, bindings, inventory).ok, "Named alias spoof is not falsely claimed detectable by source shape")
	result = hidden_guard.before_input()
	check(result.source_unchanged and not result.retained and result.state == "HOLD" and not result.compiled_plainness_attested and taps[0] == 0, "Even undetectable namedalias stays HOLD; lifecycle never fabricated")
	var replacement := GDScript.new()
	replacement.source_code = source
	check(replacement.reload() == OK, "Replacement exact source compiled")
	actor.set_script(replacement)
	result = hidden_guard.before_input()
	check(not result.source_unchanged and result.retained and taps[0] == 0, "Resource replacement refuses before any captured field read")
	actor.set_script(script)
	var parent := Node3D.new()
	owner.add_child(parent)
	actor.reparent(parent)
	result = hidden_guard.before_input()
	check(not result.source_unchanged and result.retained and body.freeze and not player.active, "Parent changes retained without claiming new source ownership")
	actor.reparent(owner)
	actor.set_meta("generation", 8)
	result = hidden_guard.before_input()
	check(not result.source_unchanged and result.retained and actor.get_meta("generation") == 8, "Generation change not overwritten")
	var wrong_hash := Guard.new()
	bindings[0].scripts[0].sha256 = "0000"
	check(not wrong_hash.configure(owner, bindings, inventory).ok, "Caller cannot admit source using wrong SHA")
	bindings[0].scripts[0].sha256 = source.sha256_text()
	actor.set_meta("generation", 7)
	var inline := GDScript.new()
	inline.source_code = "extends Node3D\nvar clock: int:\n\tget:\n\t\treturn 9\n"
	check(inline.reload() == OK, "Inline native getter compiled")
	actor.set_script(inline)
	var getter_guard := Guard.new()
	var getter_binding := [{"object": actor, "scripts": [{"script": inline, "sha256": inline.source_code.sha256_text()}], "fields": ["clock"]}]
	check(not getter_guard.configure(owner, getter_binding, inventory).ok, "Source customgetter rejected at shape boundary")
	var inherited := GDScript.new()
	inherited.source_code = "extends \"res://tests/map_editor/fixtures/plain_field_base.gd\"\n"
	check(inherited.reload() == OK and inherited.get_base_script() != null, "Actual script inheritance fixture")
	actor.set_script(inherited)
	var inherited_guard := Guard.new()
	var base: GDScript = inherited.get_base_script()
	var inherited_binding := [{"object": actor, "scripts": [{"script": inherited, "sha256": inherited.source_code.sha256_text()}], "fields": ["clock"]}]
	check(not inherited_guard.configure(owner, inherited_binding, inventory).ok, "Missing explicit base resource chain refuses")
	inherited_binding[0].scripts.append({"script": base, "sha256": base.source_code.sha256_text()})
	check(not inherited_guard.configure(owner, inherited_binding, inventory).ok, "Inherited selected variable stays ambiguous/refused even with exact full source chain")
	var offthread := Thread.new()
	offthread.start(func(): return hidden_guard.before_input())
	check(not offthread.wait_to_finish().ok, "Off-thread guard never touches native actor/source state")
	owner.free()
	print(JSON.stringify({"suite":"plain-field-negative-hold-guard", "checks":checks,"failures":failed,"field_getters_invoked":taps[0],"compiled_plainness_attested":false,"lifecycle_state":"HOLD","legacy_host_invoked":false,"production_wired":false,"gpu":false}))
	quit(0 if failed == 0 else 1)
