extends SceneTree
const Player=preload("res://scripts/preview_player.gd")
const OUT="../../outputs/coordinator21_melee_combined/project/hero.bin"
func _initialize()->void: run.call_deferred()
func run()->void:
	var world:=Node3D.new();root.add_child(world)
	var player:=Player.new();world.add_child(player);player.set_physics_process(false)
	var skeleton:Skeleton3D=player._pose_skeleton
	var vertices:=PackedVector3Array();var indices:=PackedInt32Array()
	var begin:=Time.get_ticks_usec()
	for mesh:MeshInstance3D in player._visual.find_children("*","MeshInstance3D",true,false):
		if mesh.skin==null:continue
		var frames:Array[Transform3D]=[]
		for bind in mesh.skin.get_bind_count():
			var name:=str(mesh.skin.get_bind_name(bind))
			var bone:=skeleton.find_bone(name) if not name.is_empty() else mesh.skin.get_bind_bone(bind)
			frames.append(skeleton.global_transform*skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
		for surface in mesh.mesh.get_surface_count():
			var arrays:Array=mesh.mesh.surface_get_arrays(surface)
			var source:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			var local_indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			var offset:=vertices.size()
			for i in source.size():
				var point:=Vector3.ZERO
				for w in 4:
					var at:=i*4+w
					if weights[at]>0:point+=(frames[bones[at]]*source[i])*weights[at]
				vertices.append(point)
			for i in (local_indices.size() if not local_indices.is_empty() else source.size()):
				indices.append(offset+(local_indices[i] if not local_indices.is_empty() else i))
	var targets:={}
	for name:String in ["head","chest","forearm_l","shin_r"]:
		targets[name]=(skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(name))).origin
	var report:={"vertices":vertices,"indices":indices,"targets":targets,"skin_us":Time.get_ticks_usec()-begin,"player_sha":FileAccess.get_sha256("res://scripts/preview_player.gd")}
	var f:=FileAccess.open(OUT,FileAccess.WRITE);f.store_var(report);f.close()
	print("CAPTURE ",vertices.size()," vertices / ",indices.size()/3," triangles, skin_us=",report.skin_us)
	world.free();quit()
