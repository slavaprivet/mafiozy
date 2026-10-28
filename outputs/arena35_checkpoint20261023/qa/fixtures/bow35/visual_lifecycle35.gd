extends "flight35.gd"
var profile35:Dictionary={}
var background35:=false
func ticks(n:int):
	if not background35 and is_instance_valid(scene):
		for child:Node in scene.get_children():
			if child is WorldEnvironment:child.environment.background_color=Color("b9c6d3")
		background35=true
	await super.ticks(n)
func finish():
	if is_instance_valid(bow) and bow.has_method("_update_arrow_readability35") and bow.last_fired_index()>=0:
		var node:Node3D=bow._arrows[bow.last_fired_index()].node
		var id:int=node.get_instance_id()
		# The width update must keep following the current camera after weapon switch.
		scene.get("preview_weapons").equip("sword")
		await ticks(5)
		checks["flight_readability_after_switch"]=not bow._selected and float(node.get_meta("readability_width35",1.))>1.5
		bow.set_physics_process(false)
		bow._set_arrow_readability35(node,1.)
		if node.has_meta("arrow_rear31"):node.remove_meta("arrow_rear31")
		var rear_before:float=bow._arrow_rear31(node)
		var roots:Transform3D=node.transform
		var z_before:Array=[]
		var parts:Array=[]
		for child:Node in node.get_children():
			if child is MeshInstance3D:
				checks["baked_mesh_identity_"+str(parts.size())]=child.transform.is_equal_approx(Transform3D.IDENTITY)
				parts.append(child)
				for vertex:Vector3 in child.mesh.get_faces():z_before.append((child.transform*vertex).z)
		bow._set_arrow_readability35(node,3.)
		node.remove_meta("arrow_rear31")
		var rear_after:float=bow._arrow_rear31(node)
		checks["physical_rear_exactly_unchanged"]=rear_before==rear_after
		checks["visual_root_exactly_unchanged"]=roots==node.transform
		var z_after:Array=[]
		for child:MeshInstance3D in parts:
			for vertex:Vector3 in child.mesh.get_faces():z_after.append((child.transform*vertex).z)
		checks["all_local_vertex_z_exactly_unchanged"]=z_before==z_after
		bow._stop_arrow_flight31(node)
		checks["impact_audio_independent_reset"]=true
		for child:MeshInstance3D in parts:checks.impact_audio_independent_reset=checks.impact_audio_independent_reset and child.scale==Vector3.ONE
		bow._set_arrow_readability35(node,2.)
		bow._stop_arrow_flight31(node)
		checks["already_stopped_audio_also_resets"]=parts[0].scale==Vector3.ONE
		bow._set_arrow_readability35(node,3.)
		bow._recycle(bow.last_fired_index())
		var recycled:Node3D=bow._take_arrow()
		checks["same_node_reuse_near_scale"]=recycled.get_instance_id()==id and parts[0].scale==Vector3.ONE
		# Bounded CPU overhead of the only new loop, using actual finished arrow
		# meshes. This isolated timer is not a whole-scene/exclusive FPS claim.
		for count:int in [1,44]:
			while bow._arrows.size()<count:
				var item:Node3D=bow._build_arrow(scene)
				item.global_position=camera.global_position-camera.global_basis.z*(10.+float(bow._arrows.size()))
				bow._arrows.append({"node":item,"alive":true,"stuck":false,"velocity":Vector3.ZERO})
			var samples:Array=[]
			for repeat in 100:
				var started:int=Time.get_ticks_usec()
				for batch in 20:bow._update_arrow_readability35()
				samples.append(float(Time.get_ticks_usec()-started)/20.)
			samples.sort()
			profile35[str(count)]={"median_us":samples[50],"p95_us":samples[95],"max_us":samples[-1]}
		checks["readability44_p95_under_half_ms"]=float(profile35["44"].p95_us)<500.
		FileAccess.open(out+"/PROFILE.json",FileAccess.WRITE).store_string(JSON.stringify(profile35,"  "))
	await super.finish()
