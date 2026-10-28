extends SceneTree
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const REPEATS:=24
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var loaded:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path)
	check(loaded.ok,"actual hatch GLB")
	if not loaded.ok: finish({}); return
	var visual=loaded.visual; world.add_child(visual.root)
	var baseline_wait_us: Array[float]=[]
	for frame in REPEATS:
		var baseline_at:=Time.get_ticks_usec(); await physics_frame; baseline_wait_us.append(Time.get_ticks_usec()-baseline_at)
	var lid: Node3D
	for node in visual.nodes.values():
		if node.get_meta("source_name","")=="Hood_lid": lid=node; break
	var assemblies:={"door":visual.doors.front_left,"lid":lid,"wheel":visual.wheels.front_left.pivot}
	var metrics:={}
	for kind: String in assemblies:
		var source: Node3D=assemblies[kind]
		check(source!=null,"actual assembly "+kind)
		check(_bulk_transform_parity(source)<.000001,"builtin bulk transform exact parity "+kind)
		var dent:=_deform_extreme_vertex(source,.08)
		check(dent.ok,"representative source deformation "+kind)
		var scalar_transform_us: Array[float]=[]; var bulk_transform_us: Array[float]=[]
		for iteration in REPEATS:
			var transform_at:=Time.get_ticks_usec(); _transform_points(source,false); scalar_transform_us.append(Time.get_ticks_usec()-transform_at)
			transform_at=Time.get_ticks_usec(); _transform_points(source,true); bulk_transform_us.append(Time.get_ticks_usec()-transform_at)
		var fresh_us: Array[float]=[]; var sample: Dictionary
		for iteration in REPEATS:
			var at:=Time.get_ticks_usec(); sample=_build_private(source); fresh_us.append(Time.get_ticks_usec()-at)
			check(sample.ok,"fresh exact build "+kind)
			if iteration+1<REPEATS: sample.visual.free()
		var current_max:=-INF
		for shape: ConvexPolygonShape3D in sample.shapes:
			for point in shape.points: current_max=maxf(current_max,point.x)
		check(absf(current_max-float(dent.expected_max_x))<.00001,"collision points use current deformed geometry "+kind)
		var body:=RigidBody3D.new(); body.freeze=true; body.sleeping=true; body.collision_layer=0; body.collision_mask=0; world.add_child(body)
		var shapes: Array[ConvexPolygonShape3D]=sample.shapes
		for shape in shapes:
			var collision:=CollisionShape3D.new(); collision.shape=shape; body.add_child(collision)
		await physics_frame; await physics_frame
		var update_us: Array[float]=[]; var activation_wait_us: Array[float]=[]
		for iteration in REPEATS:
			var at:=Time.get_ticks_usec()
			for shape_index in shapes.size():
				var points: PackedVector3Array=sample.points[shape_index].duplicate()
				# Alternate one exact extreme by 2 mm so the backend cannot elide rebuild.
				if not points.is_empty(): points[0].x+=.002 if iteration%2==0 else -.002
				shapes[shape_index].points=points
			update_us.append(Time.get_ticks_usec()-at)
			var wait_at:=Time.get_ticks_usec(); await physics_frame; activation_wait_us.append(Time.get_ticks_usec()-wait_at)
		var exact_refresh_us: Array[float]=[]
		for iteration in REPEATS:
			var at:=Time.get_ticks_usec(); var refreshed:=_build_private(source,false)
			for shape_index in shapes.size(): shapes[shape_index].points=refreshed.points[shape_index]
			exact_refresh_us.append(Time.get_ticks_usec()-at)
			refreshed.visual.free()
		check(body.get_child_count()==shapes.size() and shapes.all(func(s): return s.points.size()>=4),"existing compound hulls retained "+kind)
		metrics[kind]={"mesh_hulls":shapes.size(),"vertices":sample.vertices,"scalar_transform_p50_us":_percentile(scalar_transform_us,.50),"scalar_transform_p95_us":_percentile(scalar_transform_us,.95),"bulk_transform_p50_us":_percentile(bulk_transform_us,.50),"bulk_transform_p95_us":_percentile(bulk_transform_us,.95),"fresh_private_p50_us":_percentile(fresh_us,.50),"fresh_private_p95_us":_percentile(fresh_us,.95),"fresh_private_max_us":fresh_us.max(),"reuse_points_p50_us":_percentile(update_us,.50),"reuse_points_p95_us":_percentile(update_us,.95),"reuse_points_max_us":update_us.max(),"exact_refresh_clone_and_reuse_p50_us":_percentile(exact_refresh_us,.50),"exact_refresh_clone_and_reuse_p95_us":_percentile(exact_refresh_us,.95),"exact_refresh_clone_and_reuse_max_us":exact_refresh_us.max(),"activation_wait_p50_us":_percentile(activation_wait_us,.50),"activation_wait_p95_us":_percentile(activation_wait_us,.95),"activation_wait_max_us":activation_wait_us.max()}
		body.free(); sample.visual.free()
	metrics["baseline"]={"frame_wait_p50_us":_percentile(baseline_wait_us,.50),"frame_wait_p95_us":_percentile(baseline_wait_us,.95),"frame_wait_max_us":baseline_wait_us.max()}
	visual.dispose(); finish(metrics)

func _deform_extreme_vertex(source: Node3D, amount: float) -> Dictionary:
	var chosen: MeshInstance3D; var chosen_surface:=-1; var chosen_index:=-1; var best:=-INF
	var inverse:=source.global_transform.affine_inverse(); var stack: Array[Node]=[source]
	while not stack.is_empty():
		var node: Node=stack.pop_back()
		if node is Node3D and not node.visible: continue
		if node is MeshInstance3D and _opaque(node):
			var relative: Transform3D=inverse*node.global_transform
			for surface in node.mesh.get_surface_count():
				var vertices: PackedVector3Array=node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for index in vertices.size():
					var x: float=(relative*vertices[index]).x
					if x>best: best=x; chosen=node; chosen_surface=surface; chosen_index=index
		for child: Node in node.get_children(): stack.append(child)
	if chosen==null: return {"ok":false}
	var replacement:=ArrayMesh.new()
	var chosen_relative: Transform3D=inverse*chosen.global_transform
	for surface in chosen.mesh.get_surface_count():
		var arrays: Array=chosen.mesh.surface_get_arrays(surface)
		if surface==chosen_surface:
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate(); vertices[chosen_index]+=chosen_relative.basis.inverse()*Vector3(amount,0,0); arrays[Mesh.ARRAY_VERTEX]=vertices
		replacement.add_surface_from_arrays(chosen.mesh.surface_get_primitive_type(surface),arrays)
		replacement.surface_set_material(surface,chosen.mesh.surface_get_material(surface))
	chosen.mesh=replacement
	var changed: PackedVector3Array=replacement.surface_get_arrays(chosen_surface)[Mesh.ARRAY_VERTEX]
	return {"ok":true,"expected_max_x":(chosen_relative*changed[chosen_index]).x}

func _build_private(source: Node3D, create_shapes: bool=true) -> Dictionary:
	var visual:=Node3D.new(); visual.name=source.name
	var inverse:=source.global_transform.affine_inverse(); var points_list: Array[PackedVector3Array]=[]; var shapes: Array[ConvexPolygonShape3D]=[]; var vertices_total:=0
	var pending: Array=[{"source":source,"copy":visual,"root":true}]
	while not pending.is_empty():
		var row: Dictionary=pending.pop_back(); var node: Node3D=row.source; var copy: Node3D=row.copy
		if node is MeshInstance3D and _opaque(node):
			var private_mesh: Mesh=node.mesh.duplicate(true)
			for surface in private_mesh.get_surface_count():
				var material: Material=node.get_active_material(surface)
				if material!=null: private_mesh.surface_set_material(surface,material.duplicate(true))
			var mesh_copy:=MeshInstance3D.new(); mesh_copy.mesh=private_mesh; mesh_copy.transform=Transform3D.IDENTITY if row.root else node.transform
			if row.root: visual.free(); visual=mesh_copy; copy=mesh_copy
			else: copy.add_child(mesh_copy); copy=mesh_copy
			var relative: Transform3D=inverse*node.global_transform; var points:=PackedVector3Array()
			for surface in node.mesh.get_surface_count():
				var vertices: PackedVector3Array=node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]; vertices_total+=vertices.size()
				var transformed: PackedVector3Array=relative*vertices
				points.append_array(transformed)
			if points.size()>=4:
				points_list.append(points)
				if create_shapes:
					var shape:=ConvexPolygonShape3D.new(); shape.points=points; shapes.append(shape)
		for child: Node in node.get_children():
			if not child is Node3D or not child.visible: continue
			var child_copy:=Node3D.new(); child_copy.name=child.name; child_copy.transform=child.transform; copy.add_child(child_copy)
			pending.append({"source":child,"copy":child_copy,"root":false})
	return {"ok":not points_list.is_empty(),"visual":visual,"points":points_list,"shapes":shapes,"vertices":vertices_total}

func _bulk_transform_parity(source: Node3D) -> float:
	var inverse:=source.global_transform.affine_inverse(); var stack: Array[Node]=[source]; var maximum:=0.0
	while not stack.is_empty():
		var node: Node=stack.pop_back()
		if node is Node3D and not node.visible: continue
		if node is MeshInstance3D and _opaque(node):
			var relative: Transform3D=inverse*node.global_transform
			for surface in node.mesh.get_surface_count():
				var vertices: PackedVector3Array=node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				var bulk: PackedVector3Array=relative*vertices
				for index in vertices.size(): maximum=maxf(maximum,bulk[index].distance_to(relative*vertices[index]))
		for child: Node in node.get_children(): stack.append(child)
	return maximum

func _transform_points(source: Node3D, bulk: bool) -> int:
	var inverse:=source.global_transform.affine_inverse(); var stack: Array[Node]=[source]; var count:=0
	while not stack.is_empty():
		var node: Node=stack.pop_back()
		if node is Node3D and not node.visible: continue
		if node is MeshInstance3D and _opaque(node):
			var relative: Transform3D=inverse*node.global_transform
			for surface in node.mesh.get_surface_count():
				var vertices: PackedVector3Array=node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				if bulk:
					var transformed: PackedVector3Array=relative*vertices; count+=transformed.size()
				else:
					var transformed:=PackedVector3Array()
					for vertex in vertices: transformed.append(relative*vertex)
					count+=transformed.size()
		for child: Node in node.get_children(): stack.append(child)
	return count

func _opaque(node: MeshInstance3D) -> bool:
	if node.mesh==null: return false
	for surface in node.mesh.get_surface_count():
		var material: Material=node.get_active_material(surface)
		if material==null or material is BaseMaterial3D and material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED: return false
	return true
func _percentile(values: Array[float], fraction: float) -> float:
	var sorted:=values.duplicate(); sorted.sort(); return sorted[clampi(int(ceil((sorted.size()-1)*fraction)),0,sorted.size()-1)]
func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_DEBRIS_REFRESH_COST ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"repeats":REPEATS,"metrics":metrics,"scope":"actual hatch deformed door/lid/wheel isolated headless CPU; no runtime adoption or GPU"}))
	quit(0 if failures.is_empty() else 1)
