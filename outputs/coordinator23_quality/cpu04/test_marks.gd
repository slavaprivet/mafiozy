extends SceneTree
const Candidate=preload("res://scripts/weapons/weapon_surface_impacts.gd")
const Art=preload("res://scripts/weapons/impact_mark_art.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and not failures.has(label): failures.append(label); print("MARK_ART_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var variants: Array=Art.build()
	check(variants.size()==4,"four_prebuilt_variants")
	var triangles:=0
	for variant: Dictionary in variants:
		for key: String in ["back","rim","core"]:
			var arrays: Array=variant[key].surface_get_arrays(0)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]: check(vertex.is_finite() and Vector2(vertex.x,vertex.y).length()<=.035001,"finite_inside_source_radius")
			for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]: check(normal.distance_to(Vector3.BACK)<.002,"normal_source_positive_Z")
			triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
	var world:=Node3D.new(); root.add_child(world)
	var collider:=Node3D.new(); world.add_child(collider); collider.set_meta("impactSurface","masonry")
	var fx:=Candidate.new(); check(fx.configure(world),"original_source_data_configure")
	for surface: String in ["masonry","metal","wood","glass"]:
		collider.set_meta("impactSurface",surface)
		var index: int=fx._mark_cursor%fx.MARK_CAP
		check(fx.hit({"collider":collider,"point":Vector3(1,2,3),"normal":Vector3.RIGHT,"projectile_kind":"round"}),"actual_hit:"+surface)
		var entry: Dictionary=fx._marks[index]
		check(entry.life==5.0,"source_5_second_life")
		check(entry.node.global_position.is_equal_approx(Vector3(1.004,2,3)),"source_4mm_normal_offset")
		check(entry.node.global_basis.z.normalized().dot(Vector3.RIGHT)>.999,"surface_alignment")
		check(is_equal_approx(entry.node.scale.x,.58 if surface=="glass" else .72),"source_world_scale")
		check(entry.node.material_override.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED,"dark_recess_unlit")
		check(entry.node.material_override.depth_draw_mode==BaseMaterial3D.DEPTH_DRAW_DISABLED,"source_depth_write_off_depth_test_retained")
		check(not entry.node.material_override.no_depth_test,"wall_occlusion_retained")
		check(entry.edge.material_override.vertex_color_use_as_albedo==(surface!="glass"),"glass_original_rim")
		if surface=="glass": check(entry.node.mesh==entry.source_meshes[0],"glass_mesh_original")
	var index: int=fx._mark_cursor%fx.MARK_CAP
	check(fx.hit({"collider":collider,"point":Vector3.ZERO,"normal":Vector3.UP,"explosive":true}),"explosive_source")
	check(fx._marks[index].node.mesh==fx._marks[index].source_meshes[0] and is_equal_approx(fx._marks[index].node.scale.x,1.65),"scorch_preserved")
	collider.position=Vector3(4,0,0); fx.advance(.1)
	check(fx._marks[0].node.global_position.is_equal_approx(Vector3(5.004,2,3)),"attached_moving_surface")
	for n: int in 90: fx.hit({"collider":collider,"point":Vector3.ZERO,"normal":Vector3.BACK})
	check(fx.stats().marks==72 and fx._marks.size()==72,"bounded_original_pool72")
	fx.advance(5.1); check(fx.stats().marks==0,"all_original_expiry")
	var report: Dictionary={"checks":checks,"failures":failures,"pass":failures.is_empty(),"total_triangles_four_variants":triangles,"GPU_checked":false,"production_changed":false}
	FileAccess.open(get_script().resource_path.get_base_dir().path_join("MARK_RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MARK_ART_COMPONENT_RESULT ",JSON.stringify(report)); fx.dispose(); world.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
