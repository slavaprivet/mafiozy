extends SceneTree

const Catalog = preload("res://scripts/transport/transport_descriptor_catalog.gd")
const Parking = preload("res://scripts/transport/transport_parking_access.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func run() -> void:
	var catalog := Catalog.new()
	check(catalog.load_file(), "tracked descriptor catalog loads")
	var access := Parking.new()
	check(access.load_file(catalog), "tracked source parking signs load")
	var fixtures: Array = access.sign_colliders_native()
	check(fixtures.size() == 57, "all 57 source sign colliders exist")
	var bodies: Array[StaticBody3D] = []
	var built := Time.get_ticks_usec()
	for fixture in fixtures:
		var sign: Dictionary = access.sign(fixture.id)
		var body := StaticBody3D.new()
		body.position = Vector3(float(sign.x), 0.0, float(sign.z))
		body.collision_layer = 1
		body.set_meta("source_id", fixture.id)
		var shape := ConvexPolygonShape3D.new()
		var local_points := PackedVector3Array()
		for vertex in fixture.vertices_m:
			local_points.append(vertex - body.position)
		shape.points = local_points
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		root.add_child(body)
		bodies.append(body)
	var build_us := Time.get_ticks_usec() - built
	await physics_frame
	await physics_frame
	var state := root.get_world_3d().direct_space_state
	var first: Dictionary = access.sign(fixtures[0].id)
	var center := Vector3(float(first.x), 0.0, float(first.z))
	var ray := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 4.0, center - Vector3.UP, 1)
	var hit := state.intersect_ray(ray)
	check(not hit.is_empty() and hit.collider.get_meta("source_id", "") == first.id, "native physics ray hits exact source sign collider")
	check(absf(float(hit.position.y) - 2.9) < .001, "native sign top retains source 2.9m collision height within physics precision: " + str(hit.position.y))
	var beside := state.intersect_ray(PhysicsRayQueryParameters3D.create(center + Vector3(.3, 4, 0), center + Vector3(.3, -1, 0), 1))
	check(beside.is_empty(), "space beside source 0.15m octagon stays open")
	for body in bodies: body.queue_free()
	await physics_frame
	print("TRANSPORT_PARKING_SIGN_COLLISION ", JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty(), "static_signs": fixtures.size(), "build_us": build_us, "scope": "isolated real Godot static collision; no scene/LIVE integration"}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
