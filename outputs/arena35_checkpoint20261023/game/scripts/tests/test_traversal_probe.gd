extends SceneTree

const Probe = preload("res://scripts/traversal/traversal_probe.gd")

const MASK := 1
const START_Z := 1.5
const LANE_SPACING := 12.0

var checks := 0
var failures: Array[String] = []
var _world: Node3D
var _probe: RefCounted


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func run() -> void:
	_world = Node3D.new()
	_world.name = "TraversalProbePhysicsFixture"
	root.add_child(_world)
	_build_fixtures()
	# Physics queries must see server-owned shapes, not only nodes in the tree.
	await physics_frame
	await physics_frame
	_probe = Probe.new()
	_probe.configure(_world.get_world_3d().direct_space_state, MASK)

	_test_flat_and_curb()
	_test_thin_vault()
	_test_mantle_platform()
	_test_tall_rejected()
	_test_low_ceiling_rejected()
	_test_unsupported_landing_rejected()
	_test_shore_limits()
	_test_vehicle_supports()
	_test_static_seam()
	var profile := _profile_probe_cost()

	print("TRAVERSAL_PROBE_TEST ", JSON.stringify({
		"passed": failures.is_empty(),
		"checks": checks,
		"failures": failures.slice(0, 20),
		"failure_count": failures.size(),
		"profile": profile,
		"runtime_integrated": false,
		"live": false,
	}))
	_world.free()
	quit(0 if failures.is_empty() else 1)


func _build_fixtures() -> void:
	# Lane 0: unbroken flat ground.
	_floor(0, Vector3(0, -.1, 0), Vector3(6, .2, 8), "flat-floor")
	_area_box(0, "interaction-trigger", Vector3(0,1.0,.3), Vector3(3,2.0,.8))

	# Lane 1: a kerb below the traversal edge threshold.
	_floor(1, Vector3(0, -.1, 0), Vector3(6, .2, 8), "curb-floor")
	_box(1, "curb", Vector3(0, .09, .52), Vector3(3, .18, .36))

	# Lane 2: 1.1 m tall, thin in the direction of travel. There is a real
	# supported landing behind it, so this is a vault rather than a perch.
	_floor(2, Vector3(0, -.1, 0), Vector3(6, .2, 8), "vault-floor")
	_box(2, "thin-vault-1_1m", Vector3(0, .55, .52), Vector3(3, 1.1, .34))

	# Lane 3: a 1.2 m high/wide authored platform with no far-side floor.
	# Its top is the physical destination of the mantle.
	_floor(3, Vector3(0, -.1, 1.72), Vector3(6, .2, 1.9), "mantle-start-floor")
	_box(3, "mantle-platform-1_2m", Vector3(0, .6, .10), Vector3(3, 1.2, 1.2))

	# Lane 4: the same approach but a 2.5 m wall, above every allowed rise.
	_floor(4, Vector3(0, -.1, 0), Vector3(6, .2, 8), "tall-floor")
	_box(4, "too-tall-2_5m", Vector3(0, 1.25, .52), Vector3(3, 2.5, .34))

	# Lane 5: a valid thin vault geometrically, with a low overhead beam over
	# the carry segment. Full-height start and destination remain unobstructed.
	_floor(5, Vector3(0, -.1, 0), Vector3(6, .2, 8), "ceiling-floor")
	_box(5, "ceiling-vault", Vector3(0, .55, .52), Vector3(3, 1.1, .34))
	_box(5, "low-overhead-beam", Vector3(0, 1.76, .24), Vector3(3, .22, .72))

	# Lane 6: no landing floor and a top too narrow for the five-point support
	# footprint. A ray hit alone must never authorize a destination.
	_floor(6, Vector3(0, -.1, 1.72), Vector3(6, .2, 1.9), "unsupported-start-floor")
	_box(6, "unsupported-narrow-top", Vector3(0, .4, .55), Vector3(3, .8, .24))

	# Lanes 7..9: physical shore shelves. Water itself is supplied through the
	# explicit source-style depth callback, while dry support remains real.
	_floor(7, Vector3(0, .875, -.30), Vector3(4, 1.75, 1.2), "shore-1_75m")
	_floor(8, Vector3(0, 1.05, -.30), Vector3(4, 2.1, 1.2), "shore-2_1m")
	_floor(9, Vector3(0, .60, -1.50), Vector3(4, 1.2, 1.2), "shore-beyond-reach")

	# Lane 10: stationary authored vehicle roof. It uses the same group and
	# stable identity metadata exposed by the native vehicle body contract.
	_floor(10, Vector3(0, -.1, 1.72), Vector3(6, .2, 1.9), "vehicle-start-floor")
	var parked := _box(10, "parked-car", Vector3(0, .675, .08), Vector3(2.2, 1.35, 1.45))
	parked.add_to_group("native_vehicle_body")
	parked.set_meta("vehicle_id", "fixture-parked-car")
	parked.set_meta("traversal_support_kind", "vehicle")

	# Lane 11: identical roof on a moving real RigidBody3D. No alternate
	# landing exists, so accepting it would prove the stability gate was skipped.
	_floor(11, Vector3(0, -.1, 1.72), Vector3(6, .2, 1.9), "moving-start-floor")
	var moving := RigidBody3D.new()
	moving.name = "moving-car"
	moving.collision_layer = MASK
	moving.collision_mask = MASK
	moving.gravity_scale = 0.0
	moving.position = _lane_point(11, Vector3(0, .675, .08))
	moving.add_to_group("native_vehicle_body")
	moving.set_meta("vehicle_id", "fixture-moving-car")
	moving.set_meta("traversal_support_kind", "vehicle")
	_add_box_shape(moving, Vector3(2.2, 1.35, 1.45))
	_world.add_child(moving)
	moving.linear_velocity = Vector3(.65, 0, 0)

	# Lane 12: far landing spans two coplanar static bodies.
	_floor(12,Vector3(0,-.1,2.0),Vector3(6,.2,4.0),"seam-approach")
	_box(12,"seam-vault",Vector3(0,.55,.52),Vector3(3,1.1,.34))
	_floor(12,Vector3(-1.5,-.1,-.8),Vector3(3,.2,2.3),"seam-left")
	_floor(12,Vector3(1.5,-.1,-.8),Vector3(3,.2,2.3),"seam-right")

	# Lanes 13/14: real rigid vehicle bodies, parked on first input vs moving slowly.
	_floor(13,Vector3(0,-.1,1.72),Vector3(6,.2,1.9),"rigid-parked-start")
	var rigid_parked := _rigid_box(13,"rigid-parked",Vector3(0,.675,.08),Vector3(2.2,1.35,1.45))
	rigid_parked.freeze = true
	rigid_parked.set_meta("vehicle_id","fixture-rigid-parked")
	_floor(14,Vector3(0,-.1,1.72),Vector3(6,.2,1.9),"rigid-slow-start")
	var rigid_slow := _rigid_box(14,"rigid-slow",Vector3(0,.675,.08),Vector3(2.2,1.35,1.45))
	rigid_slow.gravity_scale = 0.0
	rigid_slow.can_sleep = false
	rigid_slow.linear_velocity = Vector3(.05,0,0)
	rigid_slow.set_meta("vehicle_id","fixture-rigid-slow")


func _test_flat_and_curb() -> void:
	var flat := _receipt(0)
	_assert_receipt_shape(flat, "flat")
	check(not bool(flat.admitted) and flat.reason == "no_traversal_edge", "flat ground has no traversal action")
	var curb := _receipt(1)
	_assert_receipt_shape(curb, "curb")
	var curb_is_low_vault: bool = bool(curb.admitted) and curb.kind == "vault" and float(curb.rise_m) < .25
	check(curb_is_low_vault or (not bool(curb.admitted) and curb.reason == "no_traversal_edge"), "kerb is ordinary step or bounded low vault")


func _test_thin_vault() -> void:
	var result := _receipt(2)
	_assert_receipt_shape(result, "thin vault")
	check(bool(result.admitted), "thin 1.1m obstacle admitted")
	check(result.kind == "vault", "thin obstacle resolves to vault")
	check(bool(result.start_clear) and bool(result.destination_clear) and bool(result.support_clear) and bool(result.path_clear), "vault has full physical clearance receipt")
	check(result.destination_feet.z < .35 and absf(float(result.destination_feet.y)) < .03, "vault lands physically behind obstacle")
	check(absf(float(result.edge_position.y)-1.1)<.04, "vault edge anchor stays on obstacle top for hand contacts")
	check(float(result.obstacle_width_m) > 0.0 and float(result.duration_s) >= .85 and float(result.duration_s) <= 1.25, "vault receipt has bounded geometry and timing")


func _test_mantle_platform() -> void:
	var result := _receipt(3)
	_assert_receipt_shape(result, "mantle")
	check(bool(result.admitted) and result.kind == "mantle", "1.2m platform admits mantle")
	check(absf(float(result.rise_m) - 1.2) < .04, "mantle preserves actual 1.2m rise")
	check(absf(float(result.destination_feet.y) - 1.2) < .04 and result.destination_feet.z < .48, "mantle destination is supported platform top")


func _test_tall_rejected() -> void:
	var result := _receipt(4)
	_assert_receipt_shape(result, "tall")
	check(not bool(result.admitted), "2.5m obstacle rejected")
	check(result.reason in ["obstacle_too_high", "no_supported_destination", "trajectory_blocked"], "tall rejection has closed reason")


func _test_low_ceiling_rejected() -> void:
	var result := _receipt(5)
	_assert_receipt_shape(result, "low ceiling")
	check(not bool(result.admitted), "low ceiling rejects otherwise valid vault")
	check(not bool(result.path_clear) or result.reason == "trajectory_blocked", "ceiling denial is path-clearance based")


func _test_unsupported_landing_rejected() -> void:
	var result := _receipt(6)
	_assert_receipt_shape(result, "unsupported")
	check(not bool(result.admitted), "unsupported landing rejected")
	check(not bool(result.support_clear), "unsupported landing never claims support")


func _test_shore_limits() -> void:
	var accepted := _receipt(7, {"swimming": true, "water_depth_at": Callable(self, "_water_depth").bind(.30)})
	_assert_receipt_shape(accepted, "shore 1.75")
	check(bool(accepted.admitted) and accepted.kind == "shore", "1.75m shore admitted")
	check(absf(float(accepted.rise_m) - 1.75) < .04, "shore receipt preserves 1.75m rise")

	var too_high := _receipt(8, {"swimming": true, "water_depth_at": Callable(self, "_water_depth").bind(.30)})
	_assert_receipt_shape(too_high, "shore 2.1")
	check(not bool(too_high.admitted) and too_high.reason == "obstacle_too_high", "2.1m shore rejected above source limit")

	var beyond := _receipt(9, {"swimming": true, "water_depth_at": Callable(self, "_water_depth").bind(-.90)})
	_assert_receipt_shape(beyond, "shore beyond reach")
	check(not bool(beyond.admitted) and beyond.reason == "obstacle_out_of_reach", "shore beyond 2.2m reach rejected")


func _test_vehicle_supports() -> void:
	var parked := _receipt(10, {"now_s": 10.0})
	_assert_receipt_shape(parked, "parked vehicle")
	check(bool(parked.admitted) and parked.kind == "mantle", "stationary vehicle roof admits mantle")
	check(parked.support_kind == "vehicle" and parked.support_id == "fixture-parked-car", "vehicle support identity retained")
	check(absf(float(parked.rise_m) - 1.35) < .04, "vehicle roof uses actual physical height")

	var moving := _receipt(11, {"now_s": 10.0})
	_assert_receipt_shape(moving, "moving vehicle")
	check(not bool(moving.admitted), "moving RigidBody vehicle roof rejected")
	check(moving.support_kind == "" and not bool(moving.support_clear), "moving vehicle cannot become traversal support")

	var rigid_parked := _receipt(13,{"now_s":10.0})
	_assert_receipt_shape(rigid_parked,"rigid parked vehicle")
	check(rigid_parked.admitted and rigid_parked.support_id == "fixture-rigid-parked", "sleeping/frozen rigid vehicle admits on first input")
	var rigid_slow := _receipt(14,{"now_s":10.0})
	_assert_receipt_shape(rigid_slow,"rigid slow vehicle")
	check(not rigid_slow.admitted and not rigid_slow.support_clear, "slow awake vehicle is rejected before world-space traversal")


func _test_static_seam() -> void:
	var seam := _receipt(12)
	_assert_receipt_shape(seam,"static seam")
	check(seam.admitted and seam.kind == "vault", "coplanar static support seam admits a safe landing")


func _receipt(lane: int, options: Dictionary = {}) -> Dictionary:
	var start := _lane_point(lane, Vector3(0, 0, START_Z))
	return _probe.probe(start, Vector3(0, 0, -1), options)


func _assert_receipt_shape(result: Dictionary, label: String) -> void:
	for key: String in ["admitted", "kind", "reason", "destination_feet", "rise_m", "obstacle_width_m", "support_kind", "support_id", "duration_s", "clearance_y_m", "start_clear", "destination_clear", "support_clear", "path_clear"]:
		check(result.has(key), label + " receipt field " + key)
	check(result.get("admitted") is bool and result.get("destination_feet") is Vector3, label + " receipt core field types")
	check(result.get("kind") is String and result.get("reason") is String, label + " receipt reason field types")
	for key: String in ["rise_m", "obstacle_width_m", "duration_s", "clearance_y_m"]:
		check(is_finite(float(result.get(key, NAN))), label + " finite " + key)


func _profile_probe_cost() -> Dictionary:
	var costs: Array[int] = []
	for index in 72:
		var started := Time.get_ticks_usec()
		_receipt(0)
		var elapsed := Time.get_ticks_usec() - started
		if index >= 8:
			costs.append(elapsed)
	costs.sort()
	return {
		"samples": costs.size(),
		"flat_probe_p50_us": costs[31],
		"flat_probe_p95_us": costs[60],
		"qualification": "isolated warmed headless CPU with real PhysicsDirectSpaceState3D; not LIVE and not FPS",
	}


func _water_depth(at: Vector3, shoreline_z: float) -> float:
	return 1.0 if at.z > shoreline_z else 0.0


func _floor(lane: int, center: Vector3, size: Vector3, surface_id: String) -> StaticBody3D:
	var body := _box(lane, surface_id, center, size)
	body.set_meta("surface_id", surface_id)
	return body


func _box(lane: int, body_name: String, center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = MASK
	body.collision_mask = MASK
	body.position = _lane_point(lane, center)
	_add_box_shape(body, size)
	_world.add_child(body)
	return body


func _add_box_shape(body: CollisionObject3D, size: Vector3) -> void:
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)


func _area_box(lane: int, node_name: String, center: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.collision_layer = MASK
	area.position = _lane_point(lane,center)
	_add_box_shape(area,size)
	_world.add_child(area)
	return area


func _rigid_box(lane: int, node_name: String, center: Vector3, size: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = node_name
	body.collision_layer = MASK
	body.position = _lane_point(lane,center)
	body.add_to_group("native_vehicle_body")
	body.set_meta("traversal_support_kind","vehicle")
	_add_box_shape(body,size)
	_world.add_child(body)
	return body


func _lane_point(lane: int, local: Vector3) -> Vector3:
	return Vector3(float(lane) * LANE_SPACING + local.x, local.y, local.z)
