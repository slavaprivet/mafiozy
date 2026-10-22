extends SceneTree
const Original = preload("D:/MafioziCombat31/c33_coordination/arena30_presentation/game/scripts/combat/weapon_solid_contact29.gd")
const OriginalPuncture = preload("D:/MafioziCombat31/c33_coordination/arena30_presentation/game/scripts/combat/puncture29.gd")
var out:String
var checks:Dictionary={}
func _initialize():
	create_timer(90).timeout.connect(func():quit(2))
	run.call_deferred()
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
	root.size=Vector2i(1280,720)
	var packed=load("res://scenes/arena27.tscn")
	var scene=packed.instantiate();root.add_child(scene);current_scene=scene
	for tick in 120:
		if scene.get("lab_ready")==true:break
		await physics_frame
	if scene.get("lab_ready")!=true:
		FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":false,"checks":{"startup":false}}));quit(1);return
	var host:Node=scene.lab
	var actual:RefCounted=host.get("_solid_weapon29")
	host.lab_regrow=false
	actual.warm_contact31(host)
	var before_bvh:int=actual.bvh_builds31
	var before_cut:int=host.clay_cuts
	var rig:Skeleton3D=host._npc_rig
	var point:Vector3=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("chest")).origin-Vector3.UP*.12
	checks["queue_accepted"]=host._clay_queue_slice28("chest",point,Vector3.RIGHT*6.,6.)
	for i in 600:
		await process_frame
		if not host._async_cut28.busy():break
	checks["actual_geometry_cut"]=host.clay_cuts==before_cut+1
	checks["contact_built_in_worker"]=int(host.clay_last_async28.get("contact_worker_usec31",0))>0
	actual.warm_contact31(host)
	checks["no_new_main_thread_BVH"]=actual.bvh_builds31==before_bvh
	var original=Original.new()
	original._phase_running=true;actual._phase_running=true;actual._phase_prepared=false
	var domain:=AABB(Vector3(-3,-1,-5),Vector3(6,5,8))
	original._prepare(host,domain);actual._prepare(host,domain)
	var rays:Array=[]
	var random:=RandomNumberGenerator.new();random.seed=311024
	for n in 180:
		var p:=Vector3(random.randf_range(-.6,.6),random.randf_range(.05,1.8),random.randf_range(-2.4,-1.0))
		var direction:=Vector3(random.randf_range(-1,1),random.randf_range(-1,1),random.randf_range(-1,1)).normalized()
		rays.append([p-direction*.7,p+direction*.7])
	var tris:Array=original._triangles
	for n in range(0,tris.size(),maxi(1,tris.size()/100)):
		var tri:Dictionary=tris[n]
		var p:Vector3=(tri.a+tri.b+tri.c)/3.0
		for length:float in [.02,.0001,.00001]:rays.append([p-tri.normal*length,p+tri.normal*length])
	var mismatches:Array=[];var raw_old:Array=[];var raw_new:Array=[]
	var begun:=Time.get_ticks_usec()
	for ray in rays:raw_old.append(original._segment(ray[0],ray[1]))
	var old_usec:=Time.get_ticks_usec()-begun;begun=Time.get_ticks_usec()
	for ray in rays:raw_new.append(actual._segment(ray[0],ray[1]))
	var new_usec:=Time.get_ticks_usec()-begun
	var max_error:=0.0;var total_hits:=0
	for n in rays.size():
		var a:Dictionary=raw_old[n];var b:Dictionary=raw_new[n]
		if a.is_empty()!=b.is_empty():mismatches.append({"ray":rays[n],"old":a,"new":b});continue
		if not a.is_empty():
			total_hits+=1
			var error:float=Vector3(a.position).distance_to(b.position);max_error=maxf(max_error,error)
			if error>.00002 or a.part!=b.part:mismatches.append({"ray":rays[n],"old":a,"new":b,"error":error})
	checks["nearest_matches_world_triangles"]=mismatches.is_empty()
	var skin_mismatches:Array=[]
	for n in 50:
		var a:Array=OriginalPuncture._hits(host,"",rays[n][0],rays[n][1])
		var b:Array=actual.skin_hits(host,rays[n][0],rays[n][1])
		if a.size()!=b.size():skin_mismatches.append({"ray":rays[n],"old":a,"new":b});continue
		for i in a.size():
			if Vector3(a[i].point).distance_to(b[i].point)>.00002 or a[i].bone!=b[i].bone:skin_mismatches.append({"ray":rays[n],"old":a,"new":b});break
	checks["skin_hits_match_original"]=skin_mismatches.is_empty()
	checks["real_hits_compared"]=total_hits>50
	var status:Dictionary=actual.status()
	checks["all_triangles_partitioned"]=int(status.rigid_triangles31)+int(status.mixed_triangles31)==tris.size()
	var result={"passed":not checks.values().has(false),"checks":checks,"rays":rays.size(),"hits":total_hits,"old_usec":old_usec,"new_usec":new_usec,"max_error":max_error,"mismatches":mismatches,"skin_mismatches":skin_mismatches,"status":status,"async":host.clay_last_async28,"scope":"Actual geometry cut via queue API, exact nearest-hit oracle, and no new main-thread BVH builds. Not a weapon-input or frame-time acceptance.","old_triangles":tris.size()}
	FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	actual._phase_running=false;scene.queue_free();current_scene=null
	for i in 6:await process_frame
	quit(0 if result.passed else 1)
