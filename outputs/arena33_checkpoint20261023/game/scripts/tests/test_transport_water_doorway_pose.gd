extends SceneTree

const Pose = preload("res://scripts/transport/transport_water_doorway_pose.gd")
const Catalog = preload("res://scripts/transport/transport_descriptor_catalog.gd")
var failures: Array[String] = []
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func near3(actual: Vector3, expected: Vector3, epsilon := .000001) -> bool:
	return actual.distance_to(expected) <= epsilon

func run() -> void:
	check(FileAccess.get_sha256("res://../../assets/maps/city_rebuild_v1/vehicle_water_exit.mjs") == Pose.WATER_EXIT_SOURCE_SHA256, "water wrapper source SHA pinned")
	check(FileAccess.get_sha256("res://../../assets/maps/city_rebuild_v1/vehicle_seats.mjs") == Pose.SEATS_SOURCE_SHA256, "seat source SHA pinned")
	check(FileAccess.get_sha256("res://../../assets/maps/city_rebuild_v1/car_entry.mjs") == Pose.ENTRY_SOURCE_SHA256, "entryPose source SHA pinned")
	check(FileAccess.get_sha256("res://data/transport/vehicle_descriptors.v1.json") == Pose.DESCRIPTORS_SHA256, "native descriptor SHA pinned")
	check(FileAccess.get_sha256("res://../../tools/godot/export_vehicle_visual.mjs") == Pose.VISUAL_EXPORTER_SHA256, "actual factory anchor exporter SHA pinned")
	check(FileAccess.get_sha256("res://../../tools/godot/export_transport_descriptors.mjs") == Pose.DESCRIPTOR_EXPORTER_SHA256, "descriptor projection exporter SHA pinned")
	check(FileAccess.get_sha256("res://scripts/transport/transport_descriptor_catalog.gd") == Pose.CATALOG_SHA256, "catalog reader SHA pinned")
	var catalog := Catalog.new(); check(catalog.load_file(), "actual native descriptor catalog loads")
	var transform := Transform3D(Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)), Vector3(10, -4, 7))
	var fleet_seats := 0
	for profile_id in catalog.profiles:
		var profile := catalog.profile(profile_id)
		for seat_value in profile.seats:
			var seat: Dictionary = seat_value
			var near := Pose.water_departure_point(transform, seat, 1.9, 1.0)
			var far := Pose.water_departure_point(transform, seat, 2.4, 1.0)
			var expected_dx := -float(seat.source_side) * .5
			check(near.ok and far.ok and is_equal_approx(float(far.local_position_m.x) - float(near.local_position_m.x), expected_dx) and is_equal_approx(float(far.local_position_m.y), float(seat.anchor_local_m.y)), "%s/%s projects both source distances and retained seat Y" % [profile_id, seat.id])
			fleet_seats += 1
	check(fleet_seats > 4, "all exported fleet profile seats are covered")
	for seat_id in Pose.SEAT_IDS:
		var seat := catalog.seat("city_hatchback", seat_id)
		var anchor := Vector3(float(seat.anchor_local_m.x), float(seat.anchor_local_m.y), float(seat.anchor_local_m.z))
		var seated := Pose.water_seat_point(transform, seat)
		check(seated.ok and near3(seated.world_position_m, transform * anchor), "%s seat uses full tilted and sunk vehicle transform" % seat_id)
		var start := Pose.water_departure_point(transform, seat, 1.9, 0.0)
		check(start.ok and near3(start.local_position_m, anchor) and is_equal_approx(float(start.seat_blend), 1.0), "%s exit begins at own seat" % seat_id)
		var finish := Pose.water_departure_point(transform, seat, 1.9, 1.0)
		var approach := Vector3(float(seat.approach_local_m.x), float(seat.approach_local_m.y), float(seat.approach_local_m.z))
		var expected_finish := Vector3(approach.x, anchor.y, approach.z)
		check(finish.ok and near3(finish.local_position_m, expected_finish) and near3(finish.world_position_m, transform * expected_finish), "%s doorway exit preserves local seat Y outside" % seat_id)
		var farther := Pose.water_departure_point(transform, seat, 2.4, 1.0)
		var expected_farther := expected_finish; expected_farther.x -= float(seat.source_side) * .5
		check(farther.ok and near3(farther.local_position_m, expected_farther, .000002), "%s source second exit candidate extends .5m along own door side" % seat_id)
	var front := catalog.seat("city_hatchback", "front_left")
	var middle := Pose.water_departure_point(transform, front, 1.9, .5)
	check(is_equal_approx(float(middle.seat_blend), .5), "source exit smoothstep midpoint is exact")
	check(near3(middle.local_position_m, Vector3(-1.069299994, -.0196, -.665), .000002), "source midpoint interpolates only native local X/Z")
	check(near3(middle.world_position_m, Vector3(9.335, -5.069299994, 6.9804), .000002), "fixed tilted transform numeric oracle matches")
	var before := front.duplicate(true); var defensive := Pose.water_departure_point(transform, front, 1.9, .25); defensive.local_position_m = Vector3.ZERO
	check(front == before, "returned receipt cannot mutate descriptor")
	check(not Pose.water_departure_point(transform, front, 1.9, NAN).ok, "nonfinite progress fails closed")
	var wrong := front.duplicate(true); wrong.door_id = "rear_left"
	check(not Pose.water_seat_point(transform, wrong).ok, "seat to own-door identity is required")
	var malformed := front.duplicate(true); malformed.id = 17
	check(not Pose.water_seat_point(transform, malformed).ok, "non-string seat identity fails closed before StringName coercion")
	var invalid_transform := transform; invalid_transform.origin = Vector3(NAN, -4, 7)
	check(not Pose.water_seat_point(invalid_transform, front).ok, "nonfinite vehicle transform fails closed")
	var samples := PackedFloat64Array()
	for block in range(20):
		var started := Time.get_ticks_usec()
		for iteration in range(1000): Pose.water_departure_point(transform, front, 1.9 if iteration % 2 == 0 else 2.4, float(iteration % 101) / 100.0)
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	samples.sort()
	var cost := {"calls": 20000, "block_mean_us_p50": (samples[9] + samples[10]) * .5, "block_mean_us_p95": samples[18]}
	check(samples[18] < 100.0, "pure doorway pose remains bounded below 100us p95 block mean")
	print(JSON.stringify({"checks": checks, "failures": failures, "engine": Engine.get_version_info().string, "cost": cost, "scope": "pure water doorway pose; no actor movement, collision, Root or swim adoption"}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
