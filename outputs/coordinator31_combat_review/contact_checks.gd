extends SceneTree

var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
	print("CONTACT_CHECK ", label, " ", ok)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var sword = load("res://scripts/weapons/sword_prototype.gd").new()
	root.add_child(sword)
	# Parallel overlapping segments: independent endpoint clamping gives an
	# incorrect distance here and misses steel crossing the torso.
	check(absf(sword._segment_distance(Vector3.ZERO, Vector3(3,0,0), Vector3(1,0,0), Vector3(2,0,0))) < 0.00001, "parallel_overlap")
	check(absf(sword._segment_distance(Vector3.ZERO, Vector3.ZERO, Vector3(-1,1,0), Vector3(1,1,0)) - 1.0) < 0.00001, "point_segment")
	check(absf(sword._segment_distance(Vector3.ZERO, Vector3.RIGHT, Vector3(2,1,0), Vector3(2,2,0)) - sqrt(2.0)) < 0.00001, "endpoint_reprojection")
	var model := Node3D.new()
	root.add_child(model)
	sword.set("_sword", model)
	check(sword._edge_motion(Vector3.UP) > 0.999, "edge_cut")
	check(sword._edge_motion(Vector3.BACK) < 0.001, "flat_not_cut")
	check(sword._edge_motion(Vector3.RIGHT) < 0.001, "point_not_cut")
	sword.set("_sword_origin", Vector3(0,0.45,0))
	sword.set("_contact_anchor", Vector3(0,0.45,0))
	sword.set("_contact_plane", Plane(Vector3.UP, 0))
	sword.set("_contact_plane_active", true)
	var wanted := Vector3(0,-1,-0.1).normalized()
	var settled: Vector3 = sword._contact_direction(wanted)
	var spread := 0.0
	var lowest := 99.0
	for i in 600:
		var direction: Vector3 = sword._contact_direction(wanted)
		spread = maxf(spread, direction.distance_to(settled))
		lowest = minf(lowest, 0.45 + direction.y * 1.21)
	check(lowest >= 0.0179, "ground_contact_no_penetration")
	check(spread < 0.000001, "ground_contact_no_repeated_bounce")
	check(sword._contact_direction(Vector3.UP, true).distance_to(Vector3.UP) < 0.000001, "withdraw_freely")
	check(not sword.get("_contact_plane_active"), "withdraw_releases_contact")
	model.queue_free()
	sword.queue_free()
	print("CONTACT_CHECK_RESULT ", JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
