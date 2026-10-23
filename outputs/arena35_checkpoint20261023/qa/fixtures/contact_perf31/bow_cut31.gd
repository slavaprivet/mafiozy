extends "bow_input31.gd"
func finish():
	if not checks.get("actual_posed_skin_hit",false):super.finish();return
	var entry:Dictionary=bow._arrows[bow.last_fired_index()]
	var arrow:Node3D=entry.node
	var original_id:=arrow.get_instance_id()
	scene._lab_equip(0)
	await ticks(4)
	var rig:Skeleton3D=host._npc_rig
	var point:Vector3=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("chest")).origin-Vector3.UP*.12
	var before:=int(host.clay_cuts)
	checks["real_cut_api_queued"]=host._clay_queue_slice28("chest",point,Vector3.RIGHT*6.,6.)
	rows.append({"phase":"cut_input","bone":rig.get_bone_name(int(entry.skin_bone31)),"material_local":entry.skin_hit_local31,"context":host._async_cut28.context})
	for i in 600:
		await ticks(1)
		if int(host.clay_cuts)>before:break
	checks["real_geometry_committed"]=int(host.clay_cuts)==before+1
	checks["same_arrow_exact_piece"]=is_instance_valid(arrow) and arrow.get_instance_id()==original_id and int(entry.get("cut_piece31",-1))==arrow.get_parent().get_instance_id() and arrow.get_parent() is RigidBody3D
	checks["old_bone_follow_retired"]=not entry.has("skin_rig31")
	if is_instance_valid(arrow) and arrow.get_parent() is RigidBody3D:
		var local:=arrow.transform
		await ticks(20)
		checks["detached_follow_stable"]=arrow.transform.is_equal_approx(local)
	rows.append({"cut_scope":"Real native bow shot, then direct actual geometry API cut; not a mouse-cut acceptance test.","cut":host.clay_last_async28,"arrow_parent":str(arrow.get_parent()) if is_instance_valid(arrow) else "gone","cut_piece":entry.get("cut_piece31",-1)})
	super.finish()
