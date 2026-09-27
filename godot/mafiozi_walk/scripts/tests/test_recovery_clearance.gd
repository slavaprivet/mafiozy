extends SceneTree
const Player = preload("res://scripts/preview_player.gd")
const Pose = preload("res://scripts/character_physics/character_physics_pose.gd")
const Clearance = preload("res://scripts/character_physics/recovery_clearance.gd")
var geometry: Array = []
var checks := 0
var failures: Array[String] = []
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok and failures.size()<20: failures.append(label)
func floor_y(_x: float,_z: float) -> float: return 0.0
func collect(p: Node,rig: Skeleton3D) -> void:
	for node: Node in p.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		if mesh.skin == null: continue
		var binds: Array[Transform3D]=[];var ids:=PackedInt32Array()
		for i in mesh.skin.get_bind_count():
			binds.append(mesh.skin.get_bind_pose(i));ids.append(rig.find_bone(str(mesh.skin.get_bind_name(i))))
		for s in mesh.mesh.get_surface_count():
			var a:=mesh.mesh.surface_get_arrays(s)
			geometry.append({"positions":a[Mesh.ARRAY_VERTEX],"joints":a[Mesh.ARRAY_BONES],"weights":a[Mesh.ARRAY_WEIGHTS],"binds":binds,"ids":ids})
func escaped(rig: Skeleton3D,box: AABB) -> float:
	var bones: Array[Transform3D]=[];var excess:=0.0
	for i in rig.get_bone_count(): bones.append(rig.global_transform*rig.get_bone_global_pose(i))
	for mesh: Dictionary in geometry:
		for v in mesh.positions.size():
			var point:=Vector3.ZERO
			for influence in 4:
				var at: int=v*4+influence;var weight: float=mesh.weights[at]
				if weight<=0: continue
				var bind: int=mesh.joints[at]
				point+=(bones[mesh.ids[bind]]*mesh.binds[bind]*mesh.positions[v])*weight
			for axis in 3: excess=maxf(excess,maxf(box.position[axis]-point[axis],point[axis]-box.end[axis]))
	return excess
func run() -> void:
	var p:=Player.new();root.add_child(p);p.set_physics_process(false)
	var rig: Skeleton3D=p._pose_skeleton;collect(p,rig)
	var pose:=Pose.new();check(pose.configure(rig,p._pose_motion,p._locomotion._rest_poses,p._model_scale,p._pose_motion),"actual rig")
	var clearance:=Clearance.new();check(clearance.configure(pose),"prepared bound")
	var cost: Array[int]=[];var maximum_padding:=0.0;var native_padding:=0.0;var maximum_escape:=0.0;var frames:=0
	var world: Transform3D=p._pose_motion.get_parent().global_transform
	for phase: float in [.0,.3,.5,.7,.9]:
		var initial: Dictionary=pose.sample(phase,1,Callable(),null,p._pose_epoch)
		check(clearance.snapshot(initial,world,false).get("valid",false),"uncached initial")
		for step in 10:
			var a: Dictionary=pose.standing_blend(initial,float(step)/10,floor_y,p._pose_epoch)
			var began:=Time.get_ticks_usec();var sa: Dictionary=clearance.snapshot(a,world);cost.append(Time.get_ticks_usec()-began)
			var b: Dictionary=pose.standing_blend(initial,float(step+1)/10,floor_y,p._pose_epoch)
			began=Time.get_ticks_usec();var sb: Dictionary=clearance.snapshot(b,world);var swept: Dictionary=clearance.between(sa,sb);cost.append(Time.get_ticks_usec()-began)
			check(sa.get("valid",false) and sb.get("valid",false) and swept.get("valid",false),"accepted snapshots")
			if not swept.get("valid",false): continue
			maximum_padding=maxf(maximum_padding,swept.angular_padding_m)
			for part in 5:
				var t:=float(part)/4;var mixed: Dictionary=a.duplicate(true)
				for bone in mixed.poses.size():
					var qa: Quaternion=a.poses[bone].basis.orthonormalized().get_rotation_quaternion()
					var qb: Quaternion=b.poses[bone].basis.orthonormalized().get_rotation_quaternion()
					mixed.poses[bone].basis=Basis(qa.slerp(qb,t))*Basis.from_scale(a.poses[bone].basis.get_scale())
				mixed.visual_rotation=(a.visual_rotation as Quaternion).slerp(b.visual_rotation,t)
				mixed.visual_offset=(a.visual_offset as Vector3).lerp(b.visual_offset,t)
				p._apply_selected_pose(mixed);frames+=1
				maximum_escape=maxf(maximum_escape,escaped(rig,swept.bounds))
				check(maximum_escape<.00001,"all8338 vertices within swept bound")
			check(not clearance.snapshot(a,world).get("valid",false) or a.poses==b.poses,"stale cache rejected")
		# Actual .9s getup at 60Hz: incremental padding should be small.
		for step in 54:
			var a: Dictionary=pose.standing_blend(initial,float(step)/54,floor_y,p._pose_epoch)
			var sa: Dictionary=clearance.snapshot(a,world,step>0)
			var b: Dictionary=pose.standing_blend(initial,float(step+1)/54,floor_y,p._pose_epoch)
			var sb: Dictionary=clearance.snapshot(b,world)
			var swept: Dictionary=clearance.between(sa,sb)
			check(swept.get("valid",false),"60Hz next pose bound")
			if swept.get("valid",false): native_padding=maxf(native_padding,swept.angular_padding_m)
	var final: Dictionary=pose.standing_blend(pose.sample(.3,1,Callable(),null,p._pose_epoch),.5,floor_y,p._pose_epoch)
	var good: Dictionary=clearance.snapshot(final,world)
	var stale: Dictionary=good.duplicate();stale.epoch=int(good.epoch)+1
	check(not clearance.between(good,stale).get("valid",false),"epoch mismatch")
	stale=good.duplicate();stale.world=Transform3D(world.basis,world.origin+Vector3.RIGHT)
	check(not clearance.between(good,stale).get("valid",false),"parent rebase mismatch")
	cost.sort()
	var result: Dictionary={"checks":checks,"failures":failures,"full_skin_frames":frames,"vertices_per_frame":8338,"maximum_escape_m":maximum_escape,"padding_10step_m":maximum_padding,"padding_60Hz_m":native_padding,"cpu_us":{"p50":cost[cost.size()/2],"p95":cost[int(cost.size()*.95)]},"qualification":"Bounded CPU geometry test, no GPU/whole-scene FPS claim. Continuous path is local shortest slerps plus linear visual offset."}
	var file:=FileAccess.open("res://../../outputs/coordinator21_vehicle_liveqa/recovery_clearance_test.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("RECOVERY_CLEARANCE ",JSON.stringify(result));pose.dispose();p.free();quit(0 if failures.is_empty() else 1)
func _initialize()->void: run.call_deferred()
