extends Node
const Sim = preload("res://water_contact_simulator.gd")
const Fx = preload("res://water_contact_fx.gd")
var checks := 0
var failures: Array[String] = []
var _water_mode := "lake"
var _random_value := 0.4
var _random_seed := -1
var _scripted_fan := false
var _random_calls := 0
var _water_records := {"lake": {"level":0.0,"depth":1.0,"floor":-1.0}, "narrow":{"level":0.0,"depth":0.7}, "shallow":{"level":0.0,"depth":0.04}, "thin":{"level":0.0,"depth":0.01}, "raised":{"level":1.0,"depth":1.0}, "floor":{"level":0.0,"floor":-1.0}}

func _water(x: float, z: float) -> Variant:
	match _water_mode:
		"narrow": return _water_records.narrow if x >= 0 and x <= 0.6 else null
		"shallow": return _water_records.shallow if x >= 0 else null
		"shore": return _water_records.lake if x > 0 else null
		"split_level": return _water_records.lake if x > 0 else _water_records.raised
		"floor": return _water_records.floor if x < 0.5 else {"level":0,"floor":-0.01}
	return _water_records.lake if absf(x) < 20 and absf(z) < 20 else null

func _random() -> float:
	if _scripted_fan:
		var i := _random_calls; _random_calls += 1
		if i < 150 and i%6 == 0: return float(i/6)/25
		return .4 if i < 152 else .1
	if _random_seed < 0: return _random_value
	_random_seed = (_random_seed * 1664525 + 1013904223) & 0xffffffff
	return float(_random_seed) / 4294967296.0
func _ground(_x: float, _z: float) -> float: return 0.0
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 40: failures.append(label)

func _compare(expected: Variant, actual: Variant, path: String) -> void:
	if (expected is int or expected is float) and (actual is int or actual is float):
		_check(absf(float(expected) - float(actual)) <= 1e-8 * maxf(1, absf(float(expected))), path + " expected=" + str(expected) + " actual=" + str(actual))
	elif expected is Dictionary and actual is Dictionary:
		for key in expected: _compare(expected[key], actual.get(key), path + "." + key)
	elif expected is Array and actual is Array:
		_check(expected.size() == actual.size(), path + ".size")
		for i in range(mini(expected.size(),actual.size())): _compare(expected[i], actual[i], path + "[" + str(i) + "]")
	else: _check(expected == actual, path + " expected=" + str(expected) + " actual=" + str(actual))

func _snapshot(sim: RefCounted) -> Dictionary:
	var result := {"stats":sim.stats(),"ripples":sim.get_ripples()}
	for key in ["droplets","rings","foam"]:
		var particles := []
		for p in sim.get(key):
			var item := {"active":p.active}
			if p.active:
				var fields: Array = ["x","y","z","age","life","radius"]
				if key == "droplets": fields.append_array(["vx","vy","vz"])
				if key == "rings": fields.append("strength")
				if key == "foam": fields.append("angle")
				for field in fields: item[field] = p.get(field)
			particles.append(item)
		result[key] = particles
	return result

func _hero(x: float, y: float) -> Dictionary: return {"id":"hero","position":Vector3(x,y,0)}

static func buffer_transform(mm: MultiMesh, index: int) -> Transform3D:
	# Headless dummy renderer's per-instance getters return identity after bulk
	# upload. Verify the actual upload packet; real pixels are checked separately.
	var b := mm.buffer; var at := index * Fx.STRIDE
	return Transform3D(Basis(Vector3(b[at],b[at+4],b[at+8]),Vector3(b[at+1],b[at+5],b[at+9]),Vector3(b[at+2],b[at+6],b[at+10])),Vector3(b[at+3],b[at+7],b[at+11]))

func _ready() -> void:
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/oracle.json"))
	var frames := 0
	for c in oracle.cases:
		_water_mode = c.water; _random_value = c.options.get("constantRandom",0.4); _random_seed = int(c.options.get("seededRandom",-1))
		_scripted_fan = c.options.get("scriptedFan",false); _random_calls = 0
		var options: Dictionary = c.options.duplicate(true)
		options.waterAt = _water; options.random = _random
		if options.has("groundHeight"): options.groundHeight = _ground
		var sim := Sim.new(); _check(sim.configure(options), "configure:" + c.name)
		var pool_ids := []
		for p in sim.droplets: pool_ids.append(p.get_instance_id())
		for f in c.frames:
			var before := JSON.stringify(f.input)
			sim.update(f.dt,f.input)
			_compare(f.expected,_snapshot(sim),c.name + "/" + str(frames))
			_check(before == JSON.stringify(f.input),"immutable input")
			frames += 1
		for i in range(sim.droplets.size()): _check(pool_ids[i] == sim.droplets[i].get_instance_id(), "pooled identity")
		sim.dispose(); sim.dispose(); sim.update(.05,{"hero":_hero(0,-1)})
		_compare(c.disposed,_snapshot(sim),c.name + "/dispose")
	_water_mode = "lake"; _random_value = .4; _random_seed = -1; _scripted_fan = false
	var invalid := Sim.new(); _check(not invalid.configure({}),"missing water rejects setup")
	var s := Sim.new(); s.configure({"waterAt":_water,"random":_random})
	for dt in [NAN,INF,-1.0,0.0]: s.update(dt,{"hero":_hero(0,0)})
	_check(s.now == 0,"invalid dt does not advance")
	s.dispose()
	_visual_checks()
	print("WATER_FX_RESULT=" + JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"source_cases":oracle.cases.size(),"source_frames":frames,"failures":failures,"render_scope":"native buffers/geometry/material, graphical capture separate"}))
	get_tree().quit(0 if failures.is_empty() else 1)

func _visual_checks() -> void:
	var fx := Fx.new(); add_child(fx)
	_check(fx.setup({"waterAt":_water,"random":_random}),"fx setup")
	_check(fx.get_child_count() == 3,"three batch nodes")
	_check(fx.drops.multimesh.instance_count == 240 and fx.circles.multimesh.instance_count == 288 and fx.froth.multimesh.instance_count == 72,"default source capacities")
	_check(not fx.setup({"waterAt":_water}),"repeat setup rejects")
	fx.advance(.05,{"hero":_hero(0,1)}); fx.advance(.05,{"hero":_hero(0,-.2)})
	_check(fx.stats().activeDroplets > 12 and fx.stats().drawCalls == 3,"visible impact batches")
	_check(fx.circles.multimesh.visible_instance_count == 12,"full ring arcs")
	var p: RefCounted = fx.simulator.droplets[0]
	var actual := buffer_transform(fx.drops.multimesh,0)
	_check(actual.origin.distance_to(Vector3(p.x,p.y,p.z)) < 1e-6,"uploaded packet transform matches source particle")
	_check(fx.drops.multimesh.buffer[12] > .99,"uploaded shader alpha instance data")
	for mesh in [fx.drops,fx.circles,fx.froth]:
		_check(mesh is MultiMeshInstance3D and mesh.get_child_count() == 0,"no collider/raycast interception")
		_check(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"source no shadow cast")
		_check(mesh.material_override.shader.code.contains("INSTANCE_CUSTOM.x"),"source alpha hook")
		_check(mesh.material_override.render_priority == 3,"source render order")
	_check(fx.drops.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() == 108,"SphereGeometry 6x4 topology 36 triangles")
	_check(fx.circles.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() == 18,"RingGeometry segment topology 6 triangles")
	_check(fx.froth.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() == 21,"CircleGeometry topology 7 triangles")
	var created: int = fx.simulator.particle_objects_created
	for frame in range(45):
		var ripple: Dictionary = fx.get_ripples()[0]
		var tx := buffer_transform(fx.circles.multimesh,0)
		var vertices: PackedVector3Array = fx.circles.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var inner := INF; var outer := 0.0
		for v in vertices:
			var world := tx * v
			var distance := Vector2(world.x-ripple.x,world.z-ripple.z).length()
			inner = minf(inner,distance); outer = maxf(outer,distance)
		_check(absf((inner+outer)/2 - Sim.ripple_radius(ripple.age)) < 1e-5,"ring wavefront center")
		fx.advance(.04,{"hero":_hero(0,-.2)})
	_check(created == fx.simulator.particle_objects_created and fx.buffer_capacity_resizes == 3,"fixed pools and buffer capacity")
	fx.dispose(); fx.dispose()
	_check(fx.get_child_count() == 0 and fx.get_parent() == null and fx.stats().drawCalls == 0,"deterministic resource detach")
	fx.free()
	for mode in ["shore","split_level"]:
		_water_mode = mode
		var clipped := Fx.new(); add_child(clipped); clipped.setup({"waterAt":_water,"random":_random,"maxRings":1})
		clipped.advance(.05,{"hero":_hero(.01,1)}); clipped.advance(.05,{"hero":_hero(.01,-.2)})
		var arcs: MultiMesh = clipped.circles.multimesh
		_check(arcs.visible_instance_count > 0 and arcs.visible_instance_count < 12,"shore/height clips arcs")
		var vertices: PackedVector3Array = arcs.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i in range(arcs.visible_instance_count):
			for v in vertices: _check((buffer_transform(arcs,i)*v).x >= -1e-7,"no arc geometry on dry/different-height water")
		clipped.dispose(); clipped.free()
	_water_mode = "lake"
	var removed := Fx.new(); add_child(removed); removed.setup({"waterAt":_water})
	remove_child(removed)
	_check(removed.get_child_count() == 0 and removed.simulator.disposed,"external removal cleanup")
	removed.free()
