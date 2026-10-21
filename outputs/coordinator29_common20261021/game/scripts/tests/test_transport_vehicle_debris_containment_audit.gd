extends SceneTree

const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Debris=preload("res://scripts/transport/transport_vehicle_debris.gd")
const STRICT_MARGIN:=.00001
const AMBIGUOUS_TOLERANCE:=.0001
var checks:=0
var failures: Array[String]=[]

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var world:=Node3D.new(); root.add_child(world); var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var loaded:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path); check(loaded.get("ok",false),"actual hatch loads")
	if not loaded.get("ok",false): finish({}); return
	var visual=loaded.visual; world.add_child(visual.root); visual.root.global_transform=Transform3D((Basis(Vector3.UP,.43)*Basis(Vector3.FORWARD,.27)).scaled(Vector3(1.08,.94,1.03)),Vector3(2,1,-3))
	var helper:=Debris.new(); var configured: Dictionary=helper.configure(visual.root,world,_rows(_sources(visual)))
	check(configured.get("ok",false) and configured.get("assemblies",0)==10 and configured.get("hulls",0)==76,"frozen actual 10/76 configures")
	if not configured.get("ok",false): helper.dispose(); visual.dispose(); finish({}); return
	var strict: Array=[]; var ambiguous: Array=[]; var pairs_tested:=0; var assembly_rows: Array=[]
	for assembly_index in helper._entries.size():
		var entry: Dictionary=helper._entries[assembly_index]; var cooked: Array=[]
		for hull_index in entry.hulls.size():
			var shape:=entry.hulls[hull_index] as ConvexPolygonShape3D; var debug_vertices:=_debug_vertices(shape); var planes:=_planes(shape)
			check(not debug_vertices.is_empty() and planes.size()>=4,"cooked proof data "+str(assembly_index)+":"+str(hull_index))
			cooked.append({"vertices":debug_vertices,"planes":planes})
		var assembly_strict:=0; var assembly_ambiguous:=0
		for inner_index in entry.hulls.size():
			for outer_index in entry.hulls.size():
				if inner_index==outer_index: continue
				pairs_tested+=1; var proof:=_containment(cooked[inner_index].vertices,cooked[outer_index].planes)
				if proof.strict:
					strict.append(_row(entry,assembly_index,inner_index,outer_index,proof)); assembly_strict+=1
				elif proof.ambiguous:
					ambiguous.append(_row(entry,assembly_index,inner_index,outer_index,proof)); assembly_ambiguous+=1
		assembly_rows.append({"assembly_index":assembly_index,"source":String(entry.source.name),"hulls":entry.hulls.size(),"strict_containments":assembly_strict,"ambiguous_pairs":assembly_ambiguous})
	check(pairs_tested==_expected_pairs(helper._entries),"every ordered same-assembly pair tested")
	check(strict.is_empty(),"no strictly contained cooked component hull")
	helper.dispose(); visual.dispose()
	finish({"assemblies":assembly_rows,"pairs_tested":pairs_tested,"strict_count":strict.size(),"strict":strict,"ambiguous_count":ambiguous.size(),"ambiguous":ambiguous,"strict_margin_m":STRICT_MARGIN,"ambiguous_tolerance_m":AMBIGUOUS_TOLERANCE})

func _containment(inner_vertices: PackedVector3Array,outer_planes: Array) -> Dictionary:
	var maximum:=-INF; var minimum:=INF
	for vertex in inner_vertices:
		for plane: Plane in outer_planes:
			var distance:=plane.distance_to(vertex); maximum=maxf(maximum,distance); minimum=minf(minimum,distance)
	return {"strict":maximum<=-STRICT_MARGIN,"ambiguous":maximum<=AMBIGUOUS_TOLERANCE and maximum>-STRICT_MARGIN,"max_signed_distance_m":maximum,"min_signed_distance_m":minimum,"inner_cooked_vertices":inner_vertices.size(),"outer_planes":outer_planes.size()}

func _row(entry: Dictionary,assembly_index: int,inner_index: int,outer_index: int,proof: Dictionary) -> Dictionary:
	return {"assembly_index":assembly_index,"assembly_source":String(entry.source.name),"inner_hull":inner_index,"inner_source":_binding_name(entry,inner_index),"outer_hull":outer_index,"outer_source":_binding_name(entry,outer_index),"max_signed_distance_m":proof.max_signed_distance_m,"min_signed_distance_m":proof.min_signed_distance_m,"inner_cooked_vertices":proof.inner_cooked_vertices,"outer_planes":proof.outer_planes}

func _binding_name(entry: Dictionary,index: int) -> String:
	if index>=entry.bindings.size(): return "<no-parallel-binding>"
	var node:=entry.bindings[index].node as Node
	return String(node.get_meta("source_name",node.name)) if is_instance_valid(node) else "<freed>"

func _debug_vertices(shape: ConvexPolygonShape3D) -> PackedVector3Array:
	var mesh:=shape.get_debug_mesh(); var arrays: Array=mesh.surface_get_arrays(0); return arrays[Mesh.ARRAY_VERTEX]

func _planes(shape: ConvexPolygonShape3D) -> Array:
	var mesh:=shape.get_debug_mesh(); var arrays: Array=mesh.surface_get_arrays(0); var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]; var indices:=PackedInt32Array(); var value: Variant=arrays[Mesh.ARRAY_INDEX]
	if value is PackedInt32Array: indices=value
	var center:=Vector3.ZERO
	for point in shape.points: center+=point
	center/=maxi(1,shape.points.size()); var planes: Array=[]; var triangle_count: int=(indices.size() if not indices.is_empty() else vertices.size())/3
	for triangle in triangle_count:
		var ia:=indices[triangle*3] if not indices.is_empty() else triangle*3; var ib:=indices[triangle*3+1] if not indices.is_empty() else triangle*3+1; var ic:=indices[triangle*3+2] if not indices.is_empty() else triangle*3+2
		var plane:=Plane(vertices[ia],vertices[ib],vertices[ic])
		if plane.distance_to(center)>0: plane=Plane(-plane.normal,-plane.d)
		planes.append(plane)
	return planes

func _expected_pairs(entries: Array) -> int:
	var result:=0
	for entry: Dictionary in entries: result+=entry.hulls.size()*(entry.hulls.size()-1)
	return result

func _sources(visual: RefCounted) -> Array:
	var result: Array=[]
	for id in ["front_left","rear_left","front_right","rear_right"]: result.append(visual.doors[id])
	for source_name in ["Hood_lid","Trunk_lid"]:
		for node in visual.nodes.values():
			if node.get_meta("source_name","")==source_name: result.append(node); break
	for id in ["front_left","front_right","rear_left","rear_right"]: result.append(visual.wheels[id].pivot)
	return result

func _rows(sources: Array) -> Array:
	var result: Array=[]
	for i in sources.size(): result.append({"source":sources[i],"mass_kg":18.0+i,"collision_layer":8,"collision_mask":3,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.08})
	return result

func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_VEHICLE_DEBRIS_CONTAINMENT_AUDIT ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"scope":"read-only cooked convex pairwise containment proof; no candidate removal/perf/GPU/adoption"}))
	quit(1 if not failures.is_empty() else 0)
