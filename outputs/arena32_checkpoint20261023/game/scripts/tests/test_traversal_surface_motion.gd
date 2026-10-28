extends SceneTree

const Surface = preload("res://scripts/traversal/traversal_surface_motion.gd")
const SPACING := 12.0
var checks := 0
var failures: Array[String] = []
var world: Node3D
var motion: RefCounted
var actor: CharacterBody3D


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	_build()
	_build_actor()
	await physics_frame
	await physics_frame
	motion = Surface.new()
	motion.configure(world.get_world_3d().direct_space_state, 1)

	var curb := _route(0, 1.5, -.5)
	check(curb.moved and curb.auto_step and absf(float(curb.step_rise_m)-.32)<.025, "32 cm kerb is a physical auto-step")
	check(float(curb.foot_lift_m) >= .30 and curb.position.y > .30, "kerb exposes foot lift and raised support")
	var curb_actual := _apply_route(curb, Vector3(0,0,1.5))
	check(curb_actual.accepted == curb.path_points.size() and curb_actual.end_error < .0001, "kerb execution path clears the actual player capsule")
	check(_contains_vertical_step(curb.path_points), "kerb execution separates world-up lift from horizontal crossing")
	var npc_curb := _route(0, 1.5, -.5, {"actor_kind":"pedestrian"})
	check(npc_curb == curb, "player and NPC consume identical kerb semantics")

	var medium := _route(1, 1.5, -.5)
	check(not medium.moved and medium.traversal_requested, "52 cm obstacle stays explicit traversal")
	check(medium.reason in ["collision","rise"], "medium obstacle does not become a stair")

	var threshold := _route(2, 1.2, -.8)
	check(threshold.moved and threshold.auto_step and float(threshold.foot_lift_m) >= .16, "building threshold is stepped with foot lift")
	check(absf(float(threshold.position.y)) < .025, "narrow threshold returns to interior floor")

	var low_headroom := _route(3, 1.2, -.8)
	check(not low_headroom.moved and low_headroom.reason == "headroom", "doorway threshold respects full standing headroom")

	var hill := _route(4, .8, -.2)
	check(hill.moved and hill.ascent_mode == "walk" and hill.position.y > .5, "continuous supported hill walks")
	var hill_raw := Vector3(4.0*SPACING,.11,.8)
	var hill_support: Dictionary = motion._support(hill_raw,hill_raw.y)
	var hill_start: Vector3 = motion._find_clear_root(Vector3(hill_raw.x,hill_support.position.y,hill_raw.z),motion._clearance_budget(hill_support))
	hill_start += Vector3.UP * Surface.FLOOR_SKIN_M
	var hill_sweep: Dictionary = motion.route(hill_start,Vector3(4.0*SPACING,0,-.2))
	var hill_actual := _apply_route(hill_sweep, hill_start)
	check(hill_actual.accepted == hill_sweep.path_points.size() and hill_actual.end_error < .0001, "walkable hill path clears the actual player capsule from a physically resolved root")
	var scramble := _route(5, .8, .20)
	check(scramble.moved and scramble.ascent_mode == "scramble" and is_equal_approx(float(scramble.speed_scale),.48), "steep supported mountain requests scramble")
	var npc_scramble := _route(5, .8, .20, {"actor_kind":"pedestrian"})
	check(npc_scramble == scramble, "NPC and player share mountain route")
	var cliff := _route(6, .8, .20)
	check(not cliff.moved and cliff.reason in ["terrain_face","collision"], "near-vertical face stays blocked")

	var car := _route(7, 1.5, -.5)
	check(not car.moved and car.reason == "vehicle" and car.traversal_requested, "low vehicle never becomes an automatic stair")
	var car_actor := _route(0, 1.5, -.5, {"actor_kind":"vehicle"})
	check(not car_actor.moved and car_actor.reason == "pedestrian_only", "vehicle routing cannot consume pedestrian surface rules")

	var ledge := _route(8, .6, -.6, {"ledge_policy":"block"})
	check(not ledge.moved and ledge.reason == "ledge_drop", "NPC-style ledge policy blocks large drop")
	var fall := _route(8, .6, -.6, {"ledge_policy":"free-fall"})
	check(fall.moved and fall.reason == "free_fall" and fall.vertical_transition.fall_distance > 1.0, "player-style ledge starts physical fall without y snap")

	var compound := _route(9, 1.2, -.8)
	check(not compound.moved and compound.reason in ["collision","rise"], "compound floor RID never hides its wall shape")
	var trigger := _route(10, 1.2, -.8)
	check(trigger.moved and trigger.reason == "clear", "non-solid interaction Area3D never blocks physical walking")
	var void_block := _route(11, .6, -.6, {"ledge_policy":"block"})
	var void_fall := _route(11, .6, -.6, {"ledge_policy":"free-fall"})
	check(not void_block.moved and void_block.reason == "ledge_drop" and not void_block.vertical_transition.ground_known, "unknown deep void blocks NPC at edge")
	check(void_fall.moved and void_fall.reason == "free_fall" and not void_fall.vertical_transition.ground_known, "unknown deep void starts player gravity fall")
	var sloped_vehicle := _route(12, .8, .2)
	check(not sloped_vehicle.moved and sloped_vehicle.reason == "vehicle", "sloped vehicle cannot masquerade as terrain scramble")
	var path_clear := true
	for point: Vector3 in hill.path_points:
		path_clear = path_clear and motion._capsule_clear(point)
	check(path_clear, "every proposed ramp point fits the actual player capsule")

	var profile := _profile()
	print("TRAVERSAL_SURFACE_TEST ", JSON.stringify({"passed":failures.is_empty(), "checks":checks,
		"failures":failures, "profile":profile,
		"scope":"shared player/NPC physical step, slope and ledge proposals; no body writes or LIVE claim"}))
	world.free()
	quit(0 if failures.is_empty() else 1)


func _build() -> void:
	# 0: raised sidewalk/kerb.
	_floor(0, Vector3(0,-.1,0), Vector3(4,.2,5))
	_box(0, "raised-sidewalk", Vector3(0,.16,-1.15), Vector3(4,.32,3.5))
	# 1: same footprint above automatic step height.
	_floor(1, Vector3(0,-.1,0), Vector3(4,.2,5))
	_box(1, "medium-obstacle", Vector3(0,.26,-1.15), Vector3(4,.52,3.5))
	# 2: narrow doorway sill with same-height floor beyond.
	_floor(2, Vector3(0,-.1,0), Vector3(4,.2,5))
	_box(2, "door-threshold", Vector3(0,.09,.22), Vector3(3,.18,.22))
	# 3: sill plus an authored low lintel; raised standing capsule cannot pass.
	_floor(3, Vector3(0,-.1,0), Vector3(4,.2,5))
	_box(3, "blocked-threshold", Vector3(0,.09,.22), Vector3(3,.18,.22))
	_box(3, "low-lintel", Vector3(0,1.91,.08), Vector3(3,.18,.7))
	# 4..6: real sloped collision wedges.
	_wedge(4, .55)
	_wedge(5, 1.55)
	_wedge(6, 3.2)
	# 7: vehicle-shaped low obstacle.
	_floor(7, Vector3(0,-.1,0), Vector3(4,.2,5))
	var vehicle := _box(7, "parked-low-car", Vector3(0,.15,-1.15), Vector3(3,.3,3.5))
	vehicle.set_meta("vehicle_id", "surface-car")
	vehicle.set_meta("traversal_support_kind", "vehicle")
	# 8: high ledge ending at z=0.
	_box(8, "high-ledge", Vector3(0,1.0,.8), Vector3(4,2.0,1.6))
	_floor(8, Vector3(0,-.1,-1.2), Vector3(4,.2,2.4))
	# 9: one body owns both floor and a full wall; support exclusion would tunnel.
	var compound := StaticBody3D.new()
	compound.name = "compound-floor-wall"
	compound.position.x = 9.0*SPACING
	compound.collision_layer = 1
	compound.set_meta("surface_kind", "ground")
	_add_box(compound, Vector3(0,-.1,0),Vector3(4,.2,5))
	_add_box(compound, Vector3(0,1.0,.15),Vector3(4,2.0,.2))
	world.add_child(compound)
	# 10: a physical floor plus a non-solid interaction trigger.
	_floor(10,Vector3(0,-.1,0),Vector3(4,.2,5))
	var area := Area3D.new()
	area.name = "door-interaction-trigger"
	area.position = Vector3(10.0*SPACING,1.0,.15)
	area.collision_layer = 1
	_add_box(area,Vector3.ZERO,Vector3(3,2,.8))
	world.add_child(area)
	# 11: platform above a void deeper than the support ray budget.
	_box(11,"void-platform",Vector3(0,1.0,.8),Vector3(4,2.0,1.6))
	# 12: tilted vehicle surface must retain explicit traversal ownership.
	_wedge(12,.55,"vehicle")


func _route(lane: int, start_z: float, target_z: float, options: Dictionary = {}) -> Dictionary:
	return motion.route(Vector3(float(lane)*SPACING, _start_y(lane), start_z), Vector3(float(lane)*SPACING,0,target_z), options)


func _start_y(lane: int) -> float:
	return 2.0 if lane in [8,11] else (.11 if lane == 4 else (.31 if lane == 5 else (.64 if lane == 6 else 0.0)))


func _profile() -> Dictionary:
	var costs: Array[int] = []
	for index in 72:
		var started := Time.get_ticks_usec()
		motion.route(Vector3(0,0,1.5),Vector3(0,0,1.4))
		if index >= 8:
			costs.append(Time.get_ticks_usec()-started)
	costs.sort()
	return {"samples":costs.size(), "flat_frame_p50_us":costs[31], "flat_frame_p95_us":costs[60],
		"qualification":"isolated warmed headless real-physics route; not LIVE or FPS"}


func _build_actor() -> void:
	actor = CharacterBody3D.new()
	actor.name = "SurfaceExecutionActor"
	actor.position = Vector3(1000,0,1000)
	actor.collision_layer = 2
	actor.collision_mask = 1
	actor.safe_margin = .001
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .30
	capsule.height = 1.9
	collision.shape = capsule
	collision.position.y = .95
	actor.add_child(collision)
	world.add_child(actor)


func _apply_route(receipt: Dictionary, start: Vector3) -> Dictionary:
	actor.position = start
	var accepted := 0
	var blocked := {}
	for point: Vector3 in receipt.path_points:
		var collision := actor.move_and_collide(point-actor.position, true)
		if collision != null:
			blocked = {"from":actor.position,"target":point,"normal":collision.get_normal(),"travel":collision.get_travel()}
			break
		actor.move_and_collide(point-actor.position)
		accepted += 1
	return {"accepted":accepted, "end_error":actor.position.distance_to(receipt.position),"blocked":blocked}


func _contains_vertical_step(points_value: Variant) -> bool:
	var points: Array = points_value if points_value is Array else []
	for index in range(1,points.size()):
		var previous: Vector3 = points[index-1]
		var current: Vector3 = points[index]
		if absf(current.y-previous.y) > .04 and Vector2(current.x-previous.x,current.z-previous.z).length() < .0001:
			return true
	return false


func _floor(lane: int, local: Vector3, size: Vector3) -> StaticBody3D:
	var floor := _box(lane, "ground-%d" % lane, local, size)
	floor.set_meta("surface_kind", "ground")
	return floor


func _box(lane: int, node_name: String, local: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = Vector3(float(lane)*SPACING+local.x,local.y,local.z)
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body


func _wedge(lane: int, grade: float, kind: String = "terrain") -> void:
	var body := StaticBody3D.new()
	body.name = "terrain-wedge-%d" % lane
	body.position.x = float(lane)*SPACING
	body.collision_layer = 1
	body.set_meta("surface_kind", "terrain")
	if kind == "vehicle":
		body.set_meta("vehicle_id","sloped-vehicle")
		body.set_meta("traversal_support_kind","vehicle")
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var front_y := 0.0
	var back_y := grade * 2.0
	shape.points = PackedVector3Array([
		Vector3(-2,-.2,1),Vector3(2,-.2,1),Vector3(-2,-.2,-1),Vector3(2,-.2,-1),
		Vector3(-2,front_y,1),Vector3(2,front_y,1),Vector3(-2,back_y,-1),Vector3(2,back_y,-1),
	])
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)


func _add_box(body: CollisionObject3D, local: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.position = local
	collision.shape = shape
	body.add_child(collision)


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
