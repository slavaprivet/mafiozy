extends SceneTree
const Visual = preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Panels = preload("res://scripts/vehicle_visual/vehicle_compartments.gd")
var checks := 0
var errors: Array[String] = []
var max_error := 0.0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		errors.append(label)

func point(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

func compare_node(visual, expected: Dictionary, label: String) -> void:
	var node: Node3D = visual.nodes.get(expected.key)
	check(node != null, label + " bound")
	if node == null:
		return
	var q: Array = expected.quaternion
	var wanted := Quaternion(q[0], q[1], q[2], q[3])
	var difference := maxf(node.position.distance_to(point(expected.position)), node.scale.distance_to(point(expected.scale)))
	difference = maxf(difference, 1.0 - absf(node.quaternion.dot(wanted)))
	max_error = maxf(max_error, difference)
	check(difference < 0.00001 and node.visible == expected.visible, label + " actual source pose/visibility")

func compare_sample(visual, panels, expected: Dictionary) -> void:
	for kind: String in ["hood", "trunk"]:
		check(absf(panels.amount(kind) - float(expected[kind].amount)) < 0.000001, kind + " actual source spring")
		compare_node(visual, expected[kind + "_hinge"], kind)
	compare_node(visual, expected.engine_bay, "engine bay")
	for row: Dictionary in expected.engine_children:
		compare_node(visual, row, "engine " + str(row.name))
	for row: Dictionary in expected.support_nodes:
		compare_node(visual, row, "support " + str(row.name))

func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("../../outputs/coordinator21_vehicle_compartments/source_oracle.json"))
	var catalog := Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	check(catalog.get("ok", false), "actual catalogue admitted")
	for row: Dictionary in source.rows:
		var result := Visual.instantiate_visual(catalog.entries[row.profile_id], catalog.base_path)
		check(result.get("ok", false), str(row.profile_id) + " actual native GLB")
		if not result.get("ok", false):
			continue
		var visual = result.visual
		root.add_child(visual.root)
		var panels := Panels.new()
		check(panels.configure(visual).ok, "companion matches actual private visual")
		compare_sample(visual, panels, row.samples[0])
		check(panels.set_open("hood", true) and panels.set_open("trunk", true), "open both")
		var si := 1
		for frame in range(1, 61):
			panels.step(1.0 / 60.0)
			if frame in [1, 6, 15, 30, 60]:
				compare_sample(visual, panels, row.samples[si])
				si += 1
		check(not panels.is_animating(), "settled open has zero work")
		var bounds := panels.cargo_bounds()
		check(not bounds.is_empty() and panels.contains_item((bounds.min + bounds.max) * 0.5, Vector3.ZERO), "native cargo basis centre contained")
		check(not panels.contains_item(bounds.max + Vector3.ONE, Vector3.ONE), "outside cargo rejected")
		panels.set_open("hood", false)
		panels.set_open("trunk", false)
		for frame in 60:
			panels.step(1.0 / 60.0)
		compare_sample(visual, panels, row.samples[-1])
		check(not panels.is_animating(), "settled closed has zero work")
		var original: Transform3D = visual.nodes[visual.entry.controls.hood].transform
		for frame in 100:
			panels.step(0.016)
		check(original == visual.nodes[visual.entry.controls.hood].transform, "closed idle leaves pose untouched")
		# Reversal must keep current pose and velocity; target change has no snap.
		panels.set_open("hood", true)
		panels.step(0.1)
		var before := panels.amount("hood")
		panels.set_open("hood", false)
		check(panels.amount("hood") == before, "reversal target has no teleport")
		panels.step(0.01)
		check(panels.amount("hood") > before, "reversal preserves positive velocity before deceleration")
		panels.dispose()
		check(not panels.is_animating() and not panels.set_open("hood", true), "disposed control rejects mutation")
		visual.dispose()
	# Two separately imported visuals must keep independent moving poses.
	var a = Visual.instantiate_visual(catalog.entries.compact_sedan, catalog.base_path).visual
	var b = Visual.instantiate_visual(catalog.entries.compact_sedan, catalog.base_path).visual
	root.add_child(a.root)
	root.add_child(b.root)
	var pa := Panels.new()
	var pb := Panels.new()
	pa.configure(a)
	pb.configure(b)
	pa.set_open("hood", true)
	pa.step(0.1)
	check(pa.amount("hood") > 0.0 and pb.amount("hood") == 0.0 and b.nodes[b.entry.controls.hood].rotation.x == 0.0, "independent private vehicle pose")
	pa.dispose()
	pb.dispose()
	a.dispose()
	b.dispose()
	print("VEHICLE_COMPARTMENTS ", JSON.stringify({"checks": checks, "passed": errors.is_empty(), "errors": errors, "max_pose_error": max_error, "profiles": source.rows.size(), "scope": "actual source oracle/native panels, no inventory or LIVE"}))
	quit(0 if errors.is_empty() else 1)
