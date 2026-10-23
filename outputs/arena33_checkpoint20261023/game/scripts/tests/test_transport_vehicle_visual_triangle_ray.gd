extends SceneTree
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Ray=preload("res://scripts/transport/candidates/transport_vehicle_visual_triangle_ray.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func triangle(z: float,transparent: bool=false) -> MeshInstance3D:
	var arrays:=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-1,-1,z),Vector3(1,-1,z),Vector3(0,1,z)])
	var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var mat:=StandardMaterial3D.new(); mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	if transparent: mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0,mat)
	var instance:=MeshInstance3D.new(); instance.mesh=mesh
	return instance
func run() -> void:
	var runner:=Ray.new(); var world:=Node3D.new(); root.add_child(world)
	var body:=Node3D.new(); world.add_child(body)
	var hidden_parent:=Node3D.new(); body.add_child(hidden_parent)
	var front:=triangle(0); hidden_parent.add_child(front); hidden_parent.visible=false
	var rear:=triangle(-.5); body.add_child(rear)
	var origin:=Vector3(0,0,1); var direction:=Vector3.FORWARD
	var hit: Dictionary=runner.cast(body,origin,direction,5.0,"fallback")
	check(hit.ok and hit.hit.get("object")==front and absf(hit.hit.distance_m-1.0)<.000001,"fallback uses direct mesh visibility even under hidden parent")
	hit=runner.cast(body,origin,direction,1.65,"contact")
	check(hit.ok and hit.hit.get("object")==rear,"contact excludes hidden parent")
	hidden_parent.visible=true; front.set_meta("source_metadata",{"vehicleWheelId":"front_left"})
	hit=runner.cast(body,origin,direction,1.65,"contact")
	check(hit.ok and hit.hit.get("object")==rear,"contact excludes wheel ancestry")
	front.remove_meta("source_metadata")
	var front_mat:=front.mesh.surface_get_material(0) as StandardMaterial3D
	front_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	hit=runner.cast(body,origin,direction,5.0,"fallback")
	check(hit.ok and hit.hit.get("object")==rear,"transparent front triangle skipped")
	front.set_meta("source_material_array",true)
	hit=runner.cast(body,origin,direction,5.0,"fallback")
	check(hit.ok and hit.hit.get("object")==front,"Three material array transparent property is undefined in fallback")
	hit=runner.cast(body,origin,direction,1.65,"contact")
	check(hit.ok and hit.hit.get("object")==front,"Three material array remains contact candidate despite transparent surface")
	front.remove_meta("source_material_array")
	front_mat.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
	var effects_root:=Node3D.new(); effects_root.set_meta("source_name","Vehicle_damage_effects"); body.add_child(effects_root)
	var effect:=triangle(.5); effects_root.add_child(effect)
	hit=runner.cast(body,origin,direction,5.0,"fallback")
	check(hit.ok and hit.hit.get("object")==effect,"fallback can hit non-mark effect mesh")
	hit=runner.cast(body,origin,direction,1.65,"contact")
	check(hit.ok and hit.hit.get("object")==front,"contact excludes damage effects subtree")
	hit=runner.cast(body,origin,direction,5.0,"fallback",[effect])
	check(hit.ok and hit.hit.get("object")==front,"explicit source raycast-disabled mark excluded from fallback")
	effects_root.free()
	var arrays: Array=front.mesh.surface_get_arrays(0); var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	for i in positions.size(): positions[i].z=-.2
	arrays[Mesh.ARRAY_VERTEX]=positions
	var deformed:=ArrayMesh.new(); deformed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); deformed.surface_set_material(0,front_mat); front.mesh=deformed
	hit=runner.cast(body,origin,direction,5.0,"fallback")
	check(hit.ok and hit.hit.get("object")==front and absf(hit.hit.distance_m-1.2)<.000001,"current deformed mesh positions read without stale cache")
	check(not runner.cast(body,origin,Vector3.ZERO,5.0,"fallback").ok,"invalid ray fails closed")
	body.free()
	var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var loaded:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path)
	check(loaded.ok,"real hatch import")
	var metrics: Dictionary={}
	if loaded.ok:
		var visual: RefCounted=loaded.visual; world.add_child(visual.root)
		visual.root.global_transform=Transform3D(Basis(Vector3.UP,.31),Vector3(5,1.5,-2))
		var center: Vector3=visual.root.global_transform*Vector3(0,.75,0)
		var start:=Time.get_ticks_usec()
		var real: Dictionary=runner.cast(visual.root,center+Vector3.BACK*4,Vector3.FORWARD,5.0,"fallback")
		metrics.fallback_us=Time.get_ticks_usec()-start
		check(real.ok and not real.hit.is_empty(),"real hatch current visual triangle fallback hit")
		start=Time.get_ticks_usec()
		var panel: Dictionary=runner.cast(visual.root,center+Vector3.BACK*2,Vector3.FORWARD,1.65,"contact")
		metrics.panel_us=Time.get_ticks_usec()-start
		check(panel.ok,"real hatch panel candidate query completes")
		metrics.fallback_triangles=real.get("tested_triangles",0)
		metrics.panel_triangles=panel.get("tested_triangles",0)
		metrics.panel_hit=not panel.hit.is_empty()
		visual.dispose()
	world.free()
	print("TRANSPORT_VISUAL_TRIANGLE_RAY ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"scope":"isolated visual ArrayMesh candidate, not LIVE"}))
	quit(0 if failures.is_empty() else 1)
