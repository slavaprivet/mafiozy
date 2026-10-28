extends SceneTree
const Blend = preload("res://scripts/vehicle_visual/vehicle_exit_pose_blend.gd")
const Occupant = preload("res://scripts/vehicle_visual/vehicle_occupant_pose.gd")
const Player = preload("res://scripts/preview_player.gd")
var checks := 0
var failures: Array[String] = []
var floor_kind := "flat"
var geometry: Array = []
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok and failures.size()<25: failures.append(label)
func floor_y(x: float,z: float) -> float:
	if floor_kind=="slope": return .3*x+.18*z
	if floor_kind=="step": return .23 if x>13.17 else 0.0
	return 0.0
func invalid_floor(_x: float,_z: float) -> float: return NAN
func collect(player: Node3D,rig: Skeleton3D) -> int:
	var count:=0
	for node: Node in player.find_children("*","MeshInstance3D",true,false):
		var mesh:=node as MeshInstance3D
		if mesh.skin==null: continue
		var binds: Array[Transform3D]=[];var ids:=PackedInt32Array()
		for i in mesh.skin.get_bind_count():
			binds.append(mesh.skin.get_bind_pose(i));ids.append(rig.find_bone(str(mesh.skin.get_bind_name(i))))
		for s in mesh.mesh.get_surface_count():
			var arrays:=mesh.mesh.surface_get_arrays(s)
			count+=arrays[Mesh.ARRAY_VERTEX].size()
			geometry.append({"positions":arrays[Mesh.ARRAY_VERTEX],"joints":arrays[Mesh.ARRAY_BONES],"weights":arrays[Mesh.ARRAY_WEIGHTS],"binds":binds,"ids":ids})
	return count
func skin(rig: Skeleton3D) -> Dictionary:
	var bones: Array[Transform3D]=[]
	for i in rig.get_bone_count(): bones.append(rig.get_bone_global_pose(i))
	var minimum:=INF;var points:=PackedVector3Array()
	for mesh: Dictionary in geometry:
		for v in mesh.positions.size():
			var point:=Vector3.ZERO
			for influence in 4:
				var at: int=v*4+influence
				var weight: float=mesh.weights[at]
				if weight<=0: continue
				var bind: int=mesh.joints[at]
				point+=(bones[mesh.ids[bind]]*mesh.binds[bind]*mesh.positions[v])*weight
			point=rig.global_transform*point
			minimum=minf(minimum,point.y-floor_y(point.x,point.z));points.append(point)
	return {"minimum":minimum,"points":points}
func run() -> void:
	var player:=Player.new();root.add_child(player);player.set_physics_process(false)
	var rig: Skeleton3D=player._pose_skeleton
	var component:=Blend.new();var occupant:=Occupant.new()
	check(component.configure(rig,player._pose_motion,player._locomotion._rest_poses,player._model_scale,player._pose_motion),"actual skin prepared in inherited cache")
	check(occupant.configure(rig,player._pose_motion,player._locomotion._rest_poses,player._model_scale),"actual occupant prepared")
	check(collect(player,rig)==8338,"independent all8338 original vertices")
	var costs: Array[int]=[];var lowest:=INF;var max_adjacent_vertex:=0.0;var max_endpoint_vertex:=0.0;var max_lift:=0.0
	var latest: Dictionary={}
	for side: int in [-1,1]:
		for kind: String in ["flat","slope","step"]:
			floor_kind=kind;player.position=Vector3(13,floor_y(13,-7),-7);player._visual.rotation.y=.7
			var physical_before:=player.global_transform
			var previous_points:=PackedVector3Array()
			for i in 28:
				var p:=.55+.45*float(i)/27.0
				var fold:=smoothstep(0,1,(1-p-.12)/.36)
				var options: Dictionary={"fold":fold,"reach":sin(PI*p)*.8,"side":side,"dt":1.0/60.0,"gripBlend":0.0,"pose":{"phase":"exit"}}
				var sampled: Dictionary=occupant.sample({"id":"front_left" if side<0 else "front_right","can_drive":side<0,"side":side,"recline":.12},options,null,7)
				check(sampled.get("valid",false),"real occupant source valid")
				var began:=Time.get_ticks_usec()
				latest=component.blend_release(sampled,p,floor_y,null,7)
				if i>0: costs.append(Time.get_ticks_usec()-began)
				check(latest.get("valid",false),"actual occupant origin/scale accepted "+str(latest.get("reason","")))
				if not latest.get("valid",false): continue
				check(player.global_transform==physical_before,"no physical root writes")
				max_lift=maxf(max_lift,float(latest.get("floor_lift",0)))
				player._apply_selected_pose(latest)
				var bounds:=skin(rig)
				if i>0:
					lowest=minf(lowest,float(bounds.minimum));check(bounds.minimum>=-.00003,"full mixed skin floor clear "+str(bounds.minimum))
				if not previous_points.is_empty():
					for v in previous_points.size(): max_adjacent_vertex=maxf(max_adjacent_vertex,previous_points[v].distance_to(bounds.points[v]))
				previous_points=bounds.points
				if i==27:
					var canonical: Dictionary=component.sample(0,1,floor_y,null,7)
					player._apply_selected_pose(canonical)
					var target:=skin(rig)
					for v in target.points.size(): max_endpoint_vertex=maxf(max_endpoint_vertex,target.points[v].distance_to(bounds.points[v]))
					check(max_endpoint_vertex<.0001,"release endpoint matches grounded canonical p0")
	check(not component.blend_release(latest,.8,invalid_floor,null,7).get("valid",false),"unknown floor rejects")
	check(not component.blend_release(latest,.8,floor_y,null,8).get("valid",false),"stale epoch rejects")
	costs.sort()
	var report: Dictionary={"checks":checks,"failures":failures,"all_skin_vertices":8338,"frames":168,
		"minimum_clearance_m":lowest,"max_adjacent_vertex_m":max_adjacent_vertex,"max_release_to_roll_vertex_m":max_endpoint_vertex,"max_mixed_floor_lift_m":max_lift,
		"cpu_us":{"p50":costs[costs.size()/2],"p95":costs[int(costs.size()*.95)],"samples":costs.size()},
		"qualification":"Actual male occupant samples, flat/slope/step, independently skinned every8338 vertex. Adjacent steps span .016667 release-progress (~9.17ms of .55s release), no GPU or loaded FPS claim."}
	var file:=FileAccess.open("res://../../outputs/coordinator21_vehicle_liveqa/exit_pose_blend_test.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("EXIT_POSE_BLEND_TEST ",JSON.stringify(report))
	component.dispose();player.free();quit(0 if failures.is_empty() else 1)
func _initialize() -> void: run.call_deferred()
