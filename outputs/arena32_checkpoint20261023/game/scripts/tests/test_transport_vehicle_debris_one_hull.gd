extends SceneTree

const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Frozen=preload("res://scripts/transport/transport_vehicle_debris.gd")
const OneHull=preload("res://scripts/transport/candidates/transport_vehicle_debris_one_hull.gd")
const SAMPLE_FRAMES:=120
var checks:=0
var failures: Array[String]=[]

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var mode:=OS.get_environment("DEBRIS_ONE_HULL_MODE")
	if mode.is_empty(): await _fidelity()
	else: await _stress(mode)

func _fidelity() -> void:
	var world:=_world(); var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var left_loaded:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path); var right_loaded:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path)
	check(left_loaded.get("ok",false) and right_loaded.get("ok",false),"two actual hatch visuals load")
	if not failures.is_empty(): finish({}); return
	var left=left_loaded.visual; var right=right_loaded.visual; world.add_child(left.root); world.add_child(right.root)
	left.root.global_position=Vector3(-6,2.5,0); right.root.global_position=Vector3(6,2.5,0)
	var frozen:=Frozen.new(); var candidate:=OneHull.new(); var left_sources:=_sources(left); var right_sources:=_sources(right)
	var a: Dictionary=frozen.configure(left.root,world,_rows(left_sources)); var b: Dictionary=candidate.configure(right.root,world,_rows(right_sources))
	check(a.get("ok",false) and b.get("ok",false),"frozen and one-hull configure")
	check(a.get("hulls",0)==76 and b.get("hulls",0)==10,"76 compound hulls become ten assembly hulls")
	var support_ok:=true; var concatenation_ok:=true; var cavity_rows: Array=[]; var total_filled:=0; var total_single_inside:=0
	for i in 10:
		var base_entry: Dictionary=frozen._entries[i]; var one_entry: Dictionary=candidate._entries[i]; var union:=PackedVector3Array()
		for hull: ConvexPolygonShape3D in base_entry.hulls: union.append_array(hull.points)
		var one_points: PackedVector3Array=one_entry.hulls[0].points
		if union.to_byte_array()!=one_points.to_byte_array(): concatenation_ok=false
		if not _support_equal(base_entry.hulls,one_points): support_ok=false
		var cavities:=_cavity_sample(base_entry.hulls,one_entry.hulls[0],9)
		cavity_rows.append({"assembly":i,"compound_hulls":base_entry.hulls.size(),"single_inside_samples":cavities.single_inside,"filled_gap_samples":cavities.filled,"filled_fraction":cavities.filled_fraction})
		total_filled+=cavities.filled; total_single_inside+=cavities.single_inside
	check(concatenation_ok,"single hull receives exact concatenation of all original points")
	check(support_ok,"single hull preserves compound support in sampled directions")
	check(total_filled==0,"single hull does not fill compound cavities")
	var private:=_private_counts(candidate); check(private.meshes==76 and private.materials==76,"all 76 private visual meshes/materials remain")
	await _ready([frozen,candidate]); var motions:=_motions()
	check(frozen.launch(motions).get("ok",false) and candidate.launch(motions).get("ok",false),"both paths launch")
	var settle:=0
	while candidate.stats().sleeping<10 and settle<900: await physics_frame; settle+=1
	check(candidate.stats().sleeping==10,"one-hull bodies collide and sleep")
	check(candidate.bodies().all(func(body: RigidBody3D): return body.global_position.is_finite()),"one-hull bodies remain finite")
	frozen.reset(); candidate.reset(); frozen.dispose(); candidate.dispose(); left.dispose(); right.dispose()
	finish({"support_equal":support_ok,"exact_union_points":concatenation_ok,"filled_gap_samples":total_filled,"single_inside_samples":total_single_inside,"filled_fraction":float(total_filled)/maxi(1,total_single_inside),"cavities":cavity_rows,"settle_frames":settle,"private":private})

func _stress(mode: String) -> void:
	var parts:=mode.split(":"); var kind:=String(parts[0]); var count:=int(parts[1]) if parts.size()==2 else 0
	check(kind in ["frozen","one"] and count in [1,3,10],"valid stress mode")
	if not failures.is_empty(): finish({}); return
	var world:=_world(); var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json"); var visuals: Array=[]; var rows: Array=[]
	for i in count:
		var loaded:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path); check(loaded.get("ok",false),"visual "+str(i))
		if not loaded.get("ok",false): finish({}); return
		var visual=loaded.visual; visuals.append(visual); world.add_child(visual.root); visual.root.global_position=Vector3((i%5)*12,2.5,(i/5)*12); rows.append(_rows(_sources(visual)))
	await process_frame; await process_frame
	var memory_before:=int(Performance.get_monitor(Performance.MEMORY_STATIC)); var helpers: Array=[]; var configure: Array=[]
	for i in count:
		var helper: RefCounted=Frozen.new() if kind=="frozen" else OneHull.new(); var at:=Time.get_ticks_usec(); var result: Dictionary=helper.configure(visuals[i].root,world,rows[i]); configure.append(Time.get_ticks_usec()-at)
		check(result.get("ok",false) and result.get("hulls",0)==(76 if kind=="frozen" else 10),"configure "+str(i)); helpers.append(helper)
	await process_frame; await process_frame
	var configured_memory:=int(Performance.get_monitor(Performance.MEMORY_STATIC))-memory_before
	await _ready(helpers)
	for helper in helpers: check(helper.launch(_motions()).get("ok",false),"launch")
	var awake:=await _physics_samples(SAMPLE_FRAMES); var settle:=SAMPLE_FRAMES
	while _sleeping(helpers)<count*10 and settle<1200: await physics_frame; settle+=1
	check(_sleeping(helpers)==count*10,"all bodies naturally settle")
	var settled:=await _physics_samples(SAMPLE_FRAMES)
	var private_meshes:=0; var private_materials:=0
	for helper in helpers:
		var private:=_private_counts(helper); private_meshes+=private.meshes; private_materials+=private.materials
	check(private_meshes==count*76 and private_materials==count*76,"private visual resources retained")
	finish({"mode":kind,"providers":count,"bodies":count*10,"hulls":count*(76 if kind=="frozen" else 10),"configure_us":configure,"configure_total_us":_sum(configure),"configured_memory_static_delta":configured_memory,"awake_physics_ms":_distribution(awake),"settled_physics_ms":_distribution(settled),"settle_frames":settle,"private_meshes":private_meshes,"private_materials":private_materials})
	for helper in helpers: helper.reset(); helper.dispose()
	for visual in visuals: visual.dispose()

func _world() -> Node3D:
	var world:=Node3D.new(); root.add_child(world); var ground:=StaticBody3D.new(); ground.collision_layer=1; world.add_child(ground)
	var collision:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=Vector3(160,.5,160); collision.shape=shape; collision.position.y=-.25; ground.add_child(collision); return world

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

func _motions() -> Array:
	var result: Array=[]
	for i in 10: result.append({"linear_velocity":Vector3(i*.12,2.0+i*.05,-1),"angular_velocity":Vector3(.2,i*.08,-.3)})
	return result

func _support_equal(compound: Array,one: PackedVector3Array) -> bool:
	var directions: Array[Vector3]=[]
	for x in [-1.0,0.0,1.0]:
		for y in [-1.0,0.0,1.0]:
			for z in [-1.0,0.0,1.0]:
				if x!=0 or y!=0 or z!=0: directions.append(Vector3(x,y,z).normalized())
	for direction in directions:
		var a:=-INF; var b:=-INF
		for hull: ConvexPolygonShape3D in compound:
			for point in hull.points: a=maxf(a,point.dot(direction))
		for point in one: b=maxf(b,point.dot(direction))
		if a!=b: return false
	return true

func _cavity_sample(compound: Array,one: ConvexPolygonShape3D,resolution: int) -> Dictionary:
	var single_planes:=_planes(one); var compound_planes: Array=[]
	for hull: ConvexPolygonShape3D in compound: compound_planes.append(_planes(hull))
	var points:=one.points; var minimum:=Vector3(INF,INF,INF); var maximum:=Vector3(-INF,-INF,-INF)
	for point in points: minimum=minimum.min(point); maximum=maximum.max(point)
	var single_inside:=0; var filled:=0
	for xi in resolution:
		for yi in resolution:
			for zi in resolution:
				var point:=Vector3(lerpf(minimum.x,maximum.x,(xi+.5)/resolution),lerpf(minimum.y,maximum.y,(yi+.5)/resolution),lerpf(minimum.z,maximum.z,(zi+.5)/resolution))
				if not _inside(point,single_planes): continue
				single_inside+=1; var original:=false
				for planes: Array in compound_planes:
					if _inside(point,planes): original=true; break
				if not original: filled+=1
	return {"single_inside":single_inside,"filled":filled,"filled_fraction":float(filled)/maxi(1,single_inside)}

func _planes(shape: ConvexPolygonShape3D) -> Array:
	var mesh:=shape.get_debug_mesh(); var arrays: Array=mesh.surface_get_arrays(0); var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]; var indices:=PackedInt32Array(); var index_value: Variant=arrays[Mesh.ARRAY_INDEX]
	if index_value is PackedInt32Array: indices=index_value
	var center:=Vector3.ZERO
	for point in shape.points: center+=point
	center/=maxi(1,shape.points.size()); var planes: Array=[]
	var triangle_count: int=(indices.size() if not indices.is_empty() else vertices.size())/3
	for triangle in triangle_count:
		var ia:=indices[triangle*3] if not indices.is_empty() else triangle*3; var ib:=indices[triangle*3+1] if not indices.is_empty() else triangle*3+1; var ic:=indices[triangle*3+2] if not indices.is_empty() else triangle*3+2
		var plane:=Plane(vertices[ia],vertices[ib],vertices[ic])
		if plane.distance_to(center)>0: plane=Plane(-plane.normal,-plane.d)
		planes.append(plane)
	return planes

func _inside(point: Vector3,planes: Array) -> bool:
	for plane: Plane in planes:
		if plane.distance_to(point)>.0001: return false
	return true

func _private_counts(helper: RefCounted) -> Dictionary:
	var meshes: Dictionary={}; var materials: Dictionary={}
	for entry: Dictionary in helper._entries: _collect_private(entry.template,meshes,materials)
	return {"meshes":meshes.size(),"materials":materials.size()}

func _collect_private(node: Node3D,meshes: Dictionary,materials: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh!=null:
		meshes[node.mesh.get_instance_id()]=true
		for surface in node.mesh.get_surface_count():
			var material: Material=node.get_active_material(surface)
			if material!=null: materials[material.get_instance_id()]=true
	for child in node.get_children():
		if child is Node3D: _collect_private(child,meshes,materials)

func _ready(helpers: Array) -> void:
	while helpers.any(func(helper): return not helper.stats().ready):
		for helper in helpers:
			if not helper.stats().ready: check(helper.prewarm_step(10).get("ok",false),"prewarm")
		await physics_frame

func _sleeping(helpers: Array) -> int:
	var count:=0
	for helper in helpers: count+=int(helper.stats().sleeping)
	return count

func _physics_samples(frames: int) -> Array:
	var result: Array=[]
	for i in frames:
		await physics_frame; result.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))*1000.0)
	return result

func _sum(values: Array) -> int:
	var result:=0
	for value in values: result+=int(value)
	return result

func _distribution(values: Array) -> Dictionary:
	var sorted:=values.duplicate(); sorted.sort(); var count:=sorted.size()
	return {"count":count,"p50":(float(sorted[count/2-1])+float(sorted[count/2]))*.5,"p95":sorted[mini(count-1,int(ceil(count*.95))-1)],"max":sorted[-1]}

func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_VEHICLE_DEBRIS_ONE_HULL ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"scope":"isolated actual-hatch compound-vs-single-convex experiment; no production/GPU/FPS/adoption"}))
	quit(1 if not failures.is_empty() else 0)
