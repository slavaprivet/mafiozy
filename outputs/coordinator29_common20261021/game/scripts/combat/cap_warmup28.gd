extends RefCounted
## Loading only. Render the real cap shader on both rigid and skinned geometry
## before the arena announces ready, so first contact does not compile it.
const Anatomy = preload("res://scripts/combat/cut_anatomy28.gd")
static var warmed := false

static func run(owner: Node, host: Node) -> Dictionary:
	if DisplayServer.get_name()=="headless":return {"skipped":"headless"}
	if warmed:return {"skipped":"already_warmed"}
	var started:=Time.get_ticks_usec()
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(16,16)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	owner.add_child(viewport)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.4
	camera.position=Vector3(0,0,2);camera.current=true
	viewport.add_child(camera)
	var light:=DirectionalLight3D.new();viewport.add_child(light)
	var rig:=Skeleton3D.new();rig.name="WarmSkeleton28"
	rig.add_bone("cap");viewport.add_child(rig)
	var frame:={"u":Vector3.RIGHT,"v":Vector3.UP,"n":Vector3.BACK,"origin":Vector3.ZERO}
	var anatomy:=Anatomy._anatomy(host.get("_npc_rig"),frame)
	for mode in 4:
		var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
		var vertices:=PackedVector3Array([Vector3(-0.25,-0.25,0),Vector3(0.25,-0.25,0),Vector3(0.25,0.25,0),Vector3(-0.25,0.25,0)])
		var uv:=PackedVector2Array([Vector2(-0.25,-0.25),Vector2(0.25,-0.25),Vector2(0.25,0.25),Vector2(-0.25,0.25)])
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK,Vector3.BACK])
		arrays[Mesh.ARRAY_TEX_UV]=uv
		arrays[Mesh.ARRAY_TEX_UV2]=uv
		arrays[Mesh.ARRAY_COLOR]=PackedColorArray([Color.WHITE,Color.WHITE,Color.WHITE,Color.WHITE])
		arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
		var skinned:=mode>=2
		# Detached caps retain their packed skin attributes even without a skeleton.
		arrays[Mesh.ARRAY_BONES]=PackedInt32Array([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0])
		arrays[Mesh.ARRAY_WEIGHTS]=PackedFloat32Array([1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0])
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(0,Anatomy._material(anatomy,{"arrays":arrays,"uv":uv},mode%2==1))
		var visual:=MeshInstance3D.new();visual.mesh=mesh
		viewport.add_child(visual)
		visual.position=Vector3(-0.3 if mode%2==0 else 0.3,-0.3 if mode<2 else 0.3,0)
		if skinned:
			var skin:=Skin.new();skin.add_bind(0,Transform3D.IDENTITY)
			visual.skin=skin;visual.skeleton=visual.get_path_to(rig)
	for i in 3:
		await owner.get_tree().process_frame
		await RenderingServer.frame_post_draw
	viewport.queue_free()
	warmed=true
	return {"rendered_frames":3,"variants":4,"usec":Time.get_ticks_usec()-started}
