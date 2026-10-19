extends SceneTree
const Builder = preload("res://scripts/map_editor/authored_readonly_builder.gd")
var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var builder = Builder.new()
	var refused: Dictionary = builder.begin(world, true)
	check(not refused.get("ok", false) and refused.get("error", "") == "not-actual-main-owner", "borrow request refuses non-owner host")
	builder = Builder.new()
	var begun: Dictionary = builder.begin(world)
	check(begun.get("ok", false), "exact catalog/activation admitted")
	check(begun.get("total", -1) == 242 and begun.get("borrowed", -1) == 0, "authored scope")
	var steps := 0
	var overruns := 0
	while begun.get("ok", false) and builder.status().state == "BUILDING" and steps < 243:
		var result: Dictionary = builder.step(1, 2000)
		check(result.get("ok", false), "bounded step " + str(steps) + ": " + str(result.get("error", "")))
		if not result.get("ok", false): break
		check(result.get("processed", -1) == 1, "one source object per step")
		if result.get("budget_exceeded", false): overruns += 1
		steps += 1
	var status: Dictionary = builder.status()
	check(status.state == "COMPLETE_READONLY", "all authored native visuals complete")
	check(status.covered == 242 and status.owned == 242 and status.borrowed == 0, "exact authored key coverage")
	check(builder.get("_factory").loads == 196, "196 distinct verified native GLB loads")
	var preview: Node3D = builder.get("_preview")
	check(preview.get_child_count() == 242, "242 unique preview roots")
	check(preview.visible, "preview visible only after complete coverage")
	var ids: Dictionary = {}
	for child: Node in preview.get_children():
		var id := str(child.get_meta("source_id", ""))
		check(not id.is_empty() and not ids.has(id), "unique native source ID " + id)
		ids[id] = true
		check(not child.get_meta("gameplay_active", true), "preview has no gameplay authority")
	check(ids.size() == 242, "native root identity set complete")
	builder.close()
	check(builder.status().state == "CLOSED" and world.get_child_count() == 0, "preview cleanup")
	world.free()
	var report := {"checks": checks, "failures": failures, "authored": ids.size(), "resources": 196, "steps": steps, "budgetOverruns": overruns, "maxStepUsec": status.max_step_usec, "editorReady": false, "gpu": false}
	print(JSON.stringify(report))
	if not failures.is_empty():
		for error in failures: push_error(error)
	quit(0 if failures.is_empty() else 1)
