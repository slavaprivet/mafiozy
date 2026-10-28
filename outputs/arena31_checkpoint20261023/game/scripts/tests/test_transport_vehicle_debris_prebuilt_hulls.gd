extends SceneTree
const Visual = preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Baseline = preload("res://scripts/transport/transport_vehicle_debris.gd")
const Candidate = preload("res://scripts/transport/candidates/transport_vehicle_debris_prebuilt_hulls.gd")
var failures: Array[String] = []
var checks := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _initialize() -> void: run.call_deferred()

func _sources(visual: RefCounted) -> Array:
	var found: Array = []
	for id in ["front_left", "rear_left", "front_right", "rear_right"]: found.append(visual.doors[id])
	for name in ["Hood_lid", "Trunk_lid"]:
		for node in visual.nodes.values():
			if node.get_meta("source_name", "") == name: found.append(node); break
	for id in ["front_left", "front_right", "rear_left", "rear_right"]: found.append(visual.wheels[id].pivot)
	return found

func _rows(sources: Array) -> Array:
	var rows: Array = []
	for i in sources.size(): rows.append({"source":sources[i],"mass_kg":18.0+i,"collision_layer":8,"collision_mask":3,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.08})
	return rows

func _hull_bytes_equal(left: RefCounted, right: RefCounted) -> bool:
	if left._entries.size() != right._entries.size(): return false
	for i in left._entries.size():
		var a: Array = left._entries[i].hulls
		var b: Array = right._entries[i].hulls
		if a.size() != b.size(): return false
		for j in a.size():
			if a[j].points.to_byte_array() != b[j].points.to_byte_array(): return false
	return true

func _sample(world: Node3D, catalogue: Dictionary, moved: bool, revision: int, mutate: bool) -> Dictionary:
	var loaded := Visual.instantiate_visual(catalogue.entries.city_hatchback, catalogue.base_path)
	if not loaded.get("ok", false): return {"ok":false,"error":"load"}
	var visual: RefCounted = loaded.visual
	world.add_child(visual.root)
	visual.root.global_transform = Transform3D((Basis(Vector3.UP,.43)*Basis(Vector3.FORWARD,.27)).scaled(Vector3(1.08,.94,1.03)), Vector3(0,2.5,0))
	if moved: visual.root.global_transform = Transform3D(Basis(Vector3.UP,.8)*visual.root.global_transform.basis, Vector3(15,2.5,-3))
	var sources := _sources(visual)
	if mutate:
		var stack: Array[Node] = [sources[0]]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			if node is MeshInstance3D and node.mesh is ArrayMesh:
				var mesh: ArrayMesh = node.mesh
				var arrays: Array = mesh.surface_get_arrays(0)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				vertices[0].x += .125
				arrays[Mesh.ARRAY_VERTEX] = vertices
				var material: Material = mesh.surface_get_material(0)
				mesh.surface_remove(0)
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				mesh.surface_set_material(0,material)
				break
			for child in node.get_children(): stack.append(child)
	var rows := _rows(sources)
	var owner := AnimatableBody3D.new(); world.add_child(owner)
	var baseline := Baseline.new(); var candidate := Candidate.new()
	var memory_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var before := Time.get_ticks_usec(); var base_result: Dictionary = baseline.configure(visual.root,world,rows,owner); var baseline_us := Time.get_ticks_usec()-before
	before = Time.get_ticks_usec(); var candidate_result: Dictionary = candidate.configure(visual.root,world,rows,owner,"city_hatchback",revision); var candidate_us := Time.get_ticks_usec()-before
	var memory_configured := Performance.get_monitor(Performance.MEMORY_STATIC)
	var receipt_ok: bool = base_result.get("ok",false) and candidate_result.get("ok",false) and base_result.get("hulls",0)==76 and candidate_result.get("hulls",0)==76 and base_result.get("vertices",0)==candidate_result.get("vertices",-1)
	var equal := receipt_ok and _hull_bytes_equal(baseline,candidate)
	var independent: bool = receipt_ok and baseline._entries[0].hulls[0] != candidate._entries[0].hulls[0]
	var provider_shape: ConvexPolygonShape3D = candidate._entries[0].hulls[0] if receipt_ok else null
	var original_points: PackedByteArray = baseline._entries[0].hulls[0].points.to_byte_array() if receipt_ok else PackedByteArray()
	if provider_shape != null:
		var edited := provider_shape.points
		edited[0].x += 3.0
		provider_shape.points = edited
	var baseline_unchanged: bool = receipt_ok and baseline._entries[0].hulls[0].points.to_byte_array()==original_points
	baseline.dispose(); candidate.dispose(); visual.dispose(); owner.free()
	return {"ok":receipt_ok,"equal":equal,"independent":independent,"baseline_unchanged":baseline_unchanged,"baseline_us":baseline_us,"candidate_us":candidate_us,"reused":candidate_result.get("reused_hulls",-1),"vertices":base_result.get("vertices",0),"memory_before":memory_before,"memory_configured":memory_configured,"memory_after_dispose":Performance.get_monitor(Performance.MEMORY_STATIC)}

func run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var catalogue := Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	check(catalogue.get("ok",false),"catalogue")
	if not catalogue.get("ok",false): finish({}); return
	var cold := _sample(world,catalogue,false,0,false)
	var warm := _sample(world,catalogue,false,0,false)
	var deformed_same_revision := _sample(world,catalogue,false,0,true)
	var moved := _sample(world,catalogue,true,0,false)
	var revised := _sample(world,catalogue,false,1,true)
	for label in ["cold","warm","deformed_same_revision","moved","revised"]:
		var row: Dictionary = {"cold":cold,"warm":warm,"deformed_same_revision":deformed_same_revision,"moved":moved,"revised":revised}[label]
		check(row.get("ok",false),label+" 10/76 configuration")
		check(row.get("equal",false),label+" byte-exact hulls")
		check(row.get("independent",false) and row.get("baseline_unchanged",false),label+" provider alias isolation")
	check(cold.get("reused",-1)==0,"cold build")
	check(warm.get("reused",-1)==76,"warm identical profile")
	check(deformed_same_revision.get("reused",76)<76,"in-place deformation invalidates cached hull despite same revision")
	check(moved.get("reused",-1)==0,"moved vehicle rebuilds byte-exact hulls")
	check(revised.get("reused",-1)==0,"new revision rebuilds all hulls")
	finish({"cold":cold,"warm":warm,"deformed_same_revision":deformed_same_revision,"moved":moved,"revised":revised,"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"scope":"actual visual GLB, 10 assemblies/76 compound hulls, CPU/headless; no full scene GPU"})

func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_DEBRIS_PREBUILT ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics}))
	quit(0 if failures.is_empty() else 1)
