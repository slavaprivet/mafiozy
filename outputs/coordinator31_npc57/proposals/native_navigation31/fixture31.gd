extends Node
const Physical = preload("res://scripts/hospital/npc_physical_route51.gd")
const Passage = preload("res://scripts/navigation/npc_passage31.gd")
const Site = preload("res://scripts/venues/npc_compact_service_site29.gd")
const Registry = preload("res://scripts/venues/npc_venue_registry29.gd")
class Residents extends RefCounted:
	var _records: Dictionary = {}
	func occupants() -> Array:
		var result: Array = []
		for record: Dictionary in _records.values():
			if is_instance_valid(record.body): result.append({"position":record.body.global_position})
		return result
class Population extends RefCounted:
	var residents := Residents.new()
	func occupants() -> Array: return []
class World extends Node3D:
	var preview_population := Population.new()
	var preview_venue_staff29: Node
	var _player: CharacterBody3D
	var _origin := Vector3.ZERO
	var _block: Dictionary = {}
var world: World
var ground: StaticBody3D
var bodies: Array[CharacterBody3D] = []
var routes: Array = []
var goals: Array[Vector3] = []
var core: RefCounted
var core_script: Script
var algorithm := "custom"
var case_set := "full"
var out := ""
var checks: Dictionary = {}
var results: Array = []
var physics_misses := 0
var minimum_delta := INF
var maximum_delta := 0.0
var serial := 0
var run_started := 0
var monitor_ids: Dictionary = {}

func _ready() -> void:
	Engine.physics_ticks_per_second = 60; Engine.time_scale = 1.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--algorithm="): algorithm = arg.trim_prefix("--algorithm=")
		if arg.begins_with("--case-set="): case_set = arg.trim_prefix("--case-set=")
		if arg.begins_with("--qa-out="): out = arg.trim_prefix("--qa-out=")
	assert(algorithm in ["custom","rvo"] and case_set in ["smoke","full"])
	core_script = load(get_script().resource_path.get_base_dir().path_join("rvo31.gd")) if algorithm == "rvo" else load("res://scripts/navigation/npc_local_avoidance29.gd")
	for label: String in ["TIME_NAVIGATION_PROCESS","TIME_PHYSICS_PROCESS","TIME_PROCESS","TIME_FPS"]:
		if ClassDB.class_has_integer_constant("Performance",label): monitor_ids[label] = ClassDB.class_get_integer_constant("Performance",label)
	_run.call_deferred()

func check(label: String, ok: bool) -> void:
	checks[label] = ok; print("RVO31_CHECK ", label, " ", ok)

func step() -> void:
	await get_tree().physics_frame
	if not Engine.is_in_physics_frame(): physics_misses += 1
	minimum_delta = minf(minimum_delta, get_physics_process_delta_time())
	maximum_delta = maxf(maximum_delta, get_physics_process_delta_time())

func actor(id: String, at: Vector3, npc: bool = true) -> CharacterBody3D:
	var body := CharacterBody3D.new(); body.name = id; body.collision_layer = 1; body.collision_mask = 1
	var shape := CollisionShape3D.new(); var capsule := CapsuleShape3D.new(); capsule.radius = .36; capsule.height = 1.9
	shape.shape = capsule; shape.position.y = .95; body.add_child(shape); world.add_child(body); body.global_position = at
	if npc: world.preview_population.residents._records[id] = {"body":body,"row":{"source_id":id},"generation":serial}
	return body

func box_body(label: String, at: Vector3, size: Vector3, layer: int = 1) -> StaticBody3D:
	var body := StaticBody3D.new(); body.name = label; body.collision_layer = layer
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = size; shape.shape = box
	body.add_child(shape); world.add_child(body); body.global_position = at
	return body

func reset(starts: Array[Vector3], targets: Array[Vector3]) -> void:
	if core != null and core.has_method("dispose"): core.dispose()
	core = null
	for body: CharacterBody3D in bodies:
		if is_instance_valid(body): body.queue_free()
	bodies.clear(); routes.clear(); goals.clear(); world.preview_population.residents._records.clear()
	await step(); await step()
	serial += 1; core = core_script.new()
	for i: int in range(starts.size()):
		var body: CharacterBody3D = actor("resident_" + str(i + 1), starts[i])
		var route: RefCounted = Physical.new(); assert(route.configure(body))
		bodies.append(body); routes.append(route); goals.append(targets[i])
	await step(); await step()
	for i: int in range(bodies.size()):
		var floor: Variant = routes[i].floor_at(bodies[i].global_position, bodies[i].global_position.y)
		if floor is Vector3: bodies[i].global_position = floor
	# These are initial placements only. No position writes during measured movement.
	await step(); await step()

func _key(i: int) -> String:
	return "resident_" + str(i + 1) + ":life:" + str(serial)

func monitors() -> Dictionary:
	var values: Dictionary = {}
	for label: String in monitor_ids: values[label] = Performance.get_monitor(int(monitor_ids[label]))
	return values

func run_motion(name: String, ticks: int, expected_complete: bool) -> Dictionary:
	var passage: Node = Passage.for_scene(world)
	var started: int = Time.get_ticks_usec(); var start_frame: int = Engine.get_physics_frames()
	var arrived: Array[bool] = []; arrived.resize(bodies.size()); arrived.fill(false)
	var travelled: Array[float] = []; travelled.resize(bodies.size()); travelled.fill(0.0)
	var idle_frames: Array[int] = []; idle_frames.resize(bodies.size()); idle_frames.fill(0)
	var max_idle_frames: Array[int] = []; max_idle_frames.resize(bodies.size()); max_idle_frames.fill(0)
	var max_step := 0.0; var min_separation := INF; var snapshots: Array = []
	var adapter_us := 0; var physics_us := 0; var move_calls := 0; var hold_calls := 0; var executed := 0
	var snapshot_failures := 0
	for tick: int in range(ticks):
		await step(); executed += 1
		passage.refresh()
		var inputs: Array = []
		for i: int in range(bodies.size()):
			var input: RefCounted = core_script.FrameInput.new()
			input.key = _key(i); input.position = bodies[i].global_position; input.velocity = bodies[i].velocity
			input.radius = .36; input.height = 1.9; input.waiting = arrived[i]; input.passage31 = passage.body_zone(bodies[i])
			inputs.append(input)
		var adapter_start: int = Time.get_ticks_usec()
		if not core.snapshot(inputs, Engine.get_physics_frames(), Time.get_ticks_msec()): snapshot_failures += 1
		adapter_us += Time.get_ticks_usec() - adapter_start
		for i: int in range(bodies.size()):
			var body: CharacterBody3D = bodies[i]; var before: Vector3 = body.global_position
			var toward: Vector3 = goals[i] - before; toward.y = 0.0
			if toward.length() < .16: arrived[i] = true
			adapter_start = Time.get_ticks_usec()
			var steering: Dictionary = core.steer(_key(i), toward.normalized(), 1.8)
			adapter_us += Time.get_ticks_usec() - adapter_start
			var physical_start: int = Time.get_ticks_usec()
			var direction: Vector3 = steering.direction
			var distance: float = minf(toward.length(), 1.8 / 60.0 * float(steering.ratio))
			if arrived[i] or distance < .00001 or bool(steering.waiting):
				routes[i].hold(1.0 / 60.0); hold_calls += 1
			else:
				var ahead: Vector3 = before + direction * minf(.4, toward.length())
				var support: Variant = routes[i].floor_at(ahead, before.y)
				if support is Vector3 and absf(support.y - before.y) <= Physical.STEP + .01:
					routes[i].move(direction, distance, 1.0 / 60.0); move_calls += 1
				else: routes[i].hold(1.0 / 60.0); hold_calls += 1
			physics_us += Time.get_ticks_usec() - physical_start
			var displacement: float = Vector2(body.global_position.x - before.x, body.global_position.z - before.z).length()
			travelled[i] += displacement; max_step = maxf(max_step, displacement)
			if displacement < .001 and not arrived[i]: idle_frames[i] += 1
			else: idle_frames[i] = 0
			max_idle_frames[i] = maxi(max_idle_frames[i], idle_frames[i])
		for a: int in range(bodies.size()):
			for b: int in range(a + 1, bodies.size()):
				min_separation = minf(min_separation, Vector2(bodies[a].global_position.x - bodies[b].global_position.x, bodies[a].global_position.z - bodies[b].global_position.z).length())
		if tick % 60 == 0:
			var positions: Array = []
			for body: CharacterBody3D in bodies: positions.append([body.global_position.x,body.global_position.y,body.global_position.z])
			snapshots.append({"tick":tick,"positions":positions,"core":core.diagnostics(),"passage":passage.diagnostics(),"engine_monitors":monitors()})
		if arrived.all(func(value: bool) -> bool: return value): break
	var record := {"case":name,"actors":bodies.size(),"expected_complete":expected_complete,"arrived":arrived,"complete_count":arrived.count(true),"ticks":executed,"sim_s":float(Engine.get_physics_frames()-start_frame)/60.0,"wall_s":float(Time.get_ticks_usec()-started)/1000000.0,"travel_m":travelled,"max_idle_s":float(max_idle_frames.max())/60.0,"max_step_m":max_step,"min_separation_m":min_separation,"adapter_us":adapter_us,"native_physics_us":physics_us,"move_calls":move_calls,"hold_calls":hold_calls,"snapshot_failures":snapshot_failures,"core":core.diagnostics(),"snapshots":snapshots}
	results.append(record)
	check(name + "_no_snapshot_failure", snapshot_failures == 0)
	check(name + "_native_no_teleport", max_step <= .06)
	if expected_complete: check(name + "_all10_complete", arrived.count(true) == 10)
	if algorithm == "rvo": check(name + "_real_server_callbacks", int(core.diagnostics().callbacks) > 0)
	print("RVO31_CASE ", name, " complete=", arrived.count(true), " sim_s=", record.sim_s, " idle=", record.max_idle_s, " adapter_us=", adapter_us)
	return record

func _run() -> void:
	run_started = Time.get_ticks_usec()
	world = World.new(); world.name = "NativeRVO31"; get_tree().root.add_child(world); get_tree().current_scene = world
	var grid: Array = []
	for z: int in range(80):
		var row: Array = []
		for x: int in range(80): row.append(1)
		grid.append(row)
	world._block = {"surface":{"grid":grid,"palette":{"1":{"solid":true,"kind":"grass","heightM":0.0},"2":{"solid":false,"kind":"water","heightM":-2.0}},"cellSize":1.0,"startCol":-40,"startRow":-40}}
	ground = box_body("RealGround", Vector3(0,-.1,0), Vector3(80,.2,80))
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new(); world.add_child(camera); camera.position = Vector3(0,22,18); camera.look_at(Vector3.ZERO); camera.current = true
		var light := DirectionalLight3D.new(); world.add_child(light); light.rotation_degrees = Vector3(-60,0,0)
	await step(); await step()
	var starts: Array[Vector3] = []; var targets: Array[Vector3] = []
	for i: int in range(10):
		starts.append(Vector3(-5,.003,-12 + i * 1.2)); targets.append(Vector3(-3,.003,-12 + i * 1.2))
	await reset(starts, targets)
	await run_motion("open_parallel", 240, true)
	if case_set == "full":
		starts.clear(); targets.clear()
		for i: int in range(10):
			var lane: int = i / 2; var sign_x: float = -1.0 if i % 2 == 0 else 1.0
			starts.append(Vector3(sign_x * 5,.003,-8 + lane * 2.8)); targets.append(Vector3(-sign_x * 5,.003,-8 + lane * 2.8))
		await reset(starts, targets)
		await run_motion("symmetric_headon", 720, true)
		starts.clear(); targets.clear()
		for i: int in range(10):
			var angle: float = TAU * float(i) / 10.0
			var at := Vector3(cos(angle) * 5,.003,sin(angle) * 5)
			starts.append(at); targets.append(Vector3(-at.x,.003,-at.z))
		await reset(starts, targets)
		await run_motion("crossing10", 720, true)
	# Real compact service geometry, real leaf, exact accepted passage service.
	var site: Node3D = Site.new(); site.name = "RealCompactShop31"; site.source_id = "rvo31_shop"
	site.service_kind = "shop"; site.service_sign = "МАГАЗИН"; site.native_ground29.assign([ground])
	site.set_meta("dsh_town_extra",true); site.set_meta("venue_capacity29",4); site.set_meta("venue_closed29",true); world.add_child(site)
	check("real_compact_site_bound", bool(site.bind_service(world).get("ok",false)))
	var seed: CharacterBody3D = actor("registry_seed",Vector3(0,.003,6),false)
	await step(); await step()
	var registry: RefCounted = Registry.for_scene(world)
	registry.refresh(seed,Time.get_ticks_msec(),"shop")
	check("real_native_door_registered",registry._entries.size() == 1)
	seed.queue_free()
	var swing: Node3D = site._swing29
	swing.request_door("public",true,swing.anchor,[])
	for tick: int in range(120):
		await step()
		if swing.door_fraction("public") >= .999: break
	check("real_door_fully_open", swing.door_fraction("public") >= .999)
	starts.clear(); targets.clear()
	for i: int in range(10):
		var x: float = float(i / 2 - 2) * .2
		var inward: bool = i % 2 == 0
		starts.append(Vector3(x,.243 if not inward else .003,1.0 if not inward else 5.5))
		targets.append(Vector3(x,.003 if not inward else .243,5.5 if not inward else 1.0))
	await reset(starts, targets)
	var doorway: Dictionary = await run_motion("narrow_door_two_flows10", 600, true)
	check("doorway_native_overlap", float(doorway.min_separation_m) < .35)
	var passage: Node = Passage.for_scene(world)
	check("doorway_symmetric_native_exceptions", bodies[0].get_collision_exceptions().has(bodies[1]) and bodies[1].get_collision_exceptions().has(bodies[0]))
	var ray := PhysicsRayQueryParameters3D.create(bodies[0].global_position+Vector3(-.5,1,0),bodies[0].global_position+Vector3(.5,1,0),1)
	check("hit_ray_still_hits_npc", world.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") is CharacterBody3D)
	# Lifecycle layer change before fresh refresh must retire native permission.
	bodies[1].collision_layer = 512
	await step(); passage.refresh()
	check("death_layer_native_exceptions_retired", not bodies[0].get_collision_exceptions().has(bodies[1]))
	check("corpse512_capsule_blocked", not routes[0].standing(bodies[1].global_position))
	# All initial actor positions for these safety cases are outside the passage.
	starts.clear(); targets.clear()
	for i: int in range(10):
		starts.append(Vector3(12,.003,-30+i*3.0)); targets.append(Vector3(17,.003,-30+i*3.0))
	await reset(starts, targets)
	var wall: StaticBody3D = box_body("Wall",Vector3(14,1,-30),Vector3(.2,2,1.1))
	var player: CharacterBody3D = actor("player",Vector3(14,.003,-27),false); world._player = player
	var debris: StaticBody3D = box_body("Debris512",Vector3(14,.6,-24),Vector3(.5,1.2,1.1),512)
	await step(); await step()
	await run_motion("wall_player_debris", 180, false)
	check("wall_native_blocked", bodies[0].global_position.x < 13.56)
	check("player_native_blocked", bodies[1].global_position.x < 13.30)
	check("debris512_native_blocked", bodies[2].global_position.x < 13.40)
	check("outside_no_peer_exceptions", bodies.all(func(body: CharacterBody3D) -> bool: return body.get_collision_exceptions().is_empty()))
	check("closed_door_not_excluded", not bodies[0].get_collision_exceptions().has(swing.leaf))
	# A closed real leaf remains a blocked capsule query, independently of steering.
	swing.request_door("public",false,swing.anchor,[])
	for tick: int in range(120):
		await step()
		if swing.door_fraction("public") <= .001: break
	check("real_closed_door_blocks", swing.door_fraction("public") <= .001 and not routes[0].standing(Vector3(0,.243,3.5)))
	check("moves_in_real_physics_context", physics_misses == 0)
	check("fixed60hz", Engine.physics_ticks_per_second == 60 and absf(minimum_delta-1.0/60.0) < .000001 and absf(maximum_delta-1.0/60.0) < .000001)
	if core.has_method("dispose"):
		core.dispose(); check("native_agents_freed", int(core.diagnostics().actors) == 0)
	var record := {"algorithm":algorithm,"case_set":case_set,"checks":checks,"cases":results,"physics_context_misses":physics_misses,"min_delta":minimum_delta,"max_delta":maximum_delta,"wall_s":float(Time.get_ticks_usec()-run_started)/1000000.0,"full_city_acceptance":false,"fps_comparison_valid":false,"source_physics":"exact frozen57 Route/Surface/Passage","adapter_timing_excludes_native_server_compute":algorithm=="rvo","available_engine_monitors":monitor_ids.keys(),"engine_monitor_scope":"whole NavigationServer/physics/process, periodic engine monitor values, not isolated RVO self-time"}
	var file := FileAccess.open(out.path_join("NATIVE.json"),FileAccess.WRITE); file.store_string(JSON.stringify(record,"\t")); file.close()
	world.queue_free(); await step(); await step(); get_tree().quit(0)
