extends SceneTree
const Kernel=preload("res://scripts/combat/melee_triangle_contact.gd")
const Index=preload("res://scripts/combat/melee_triangle_index.gd")
const Player=preload("res://scripts/preview_player.gd")
var errors:Array[String]=[]
func _initialize()->void:run.call_deferred()
func run()->void:
	var frozen:=FileAccess.get_sha256("res://scripts/combat/melee_triangle_contact.gd")
	var world:=Node3D.new();root.add_child(world)
	var player:=Player.new();world.add_child(player);player.set_physics_process(false)
	var skeleton:Skeleton3D=player._pose_skeleton
	var triangles:Array=[];var bounds:Array[AABB]=[];var vertices_count:=0
	var all_vertices:=PackedVector3Array();var all_indices:=PackedInt32Array()
	var began:=Time.get_ticks_usec()
	for mesh:MeshInstance3D in player._visual.find_children("*","MeshInstance3D",true,false):
		if mesh.skin==null:continue
		var frames:Array[Transform3D]=[]
		for bind in mesh.skin.get_bind_count():
			var name:=str(mesh.skin.get_bind_name(bind))
			var bone:=skeleton.find_bone(name) if not name.is_empty() else mesh.skin.get_bind_bone(bind)
			frames.append(skeleton.global_transform*skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
		for surface in mesh.mesh.get_surface_count():
			var arrays:Array=mesh.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			var deformed:=PackedVector3Array();deformed.resize(vertices.size());vertices_count+=vertices.size()
			for v in vertices.size():
				var point:=Vector3.ZERO
				for w in 4:
					var at:=v*4+w
					if weights[at]>0:point+=(frames[bones[at]]*vertices[v])*weights[at]
				deformed[v]=point
			var offset:=all_vertices.size();all_vertices.append_array(deformed)
			var count:=indices.size() if not indices.is_empty() else vertices.size()
			for i in range(0,count,3):
				var a:=deformed[indices[i] if not indices.is_empty() else i]
				var b:=deformed[indices[i+1] if not indices.is_empty() else i+1]
				var c:=deformed[indices[i+2] if not indices.is_empty() else i+2]
				for j in 3:all_indices.append(offset+(indices[i+j] if not indices.is_empty() else i+j))
				triangles.append([a,b,c]);bounds.append(AABB(a,Vector3.ZERO).expand(b).expand(c))
	var setup_us:=Time.get_ticks_usec()-began
	var index:=Index.new();began=Time.get_ticks_usec()
	var built:Dictionary=index.configure(all_indices,all_vertices,0)
	var build_us:=Time.get_ticks_usec()-began
	if built.status!="READY":errors.append("build failed")
	var refits:Array[int]=[]
	for iteration in 64:
		began=Time.get_ticks_usec()
		var result:Dictionary=index.refit(all_vertices,iteration+1)
		if iteration>=16:refits.append(Time.get_ticks_usec()-began)
		if result.status!="READY":errors.append("refit failed")
	var refit_totals:Array[int]=[];var refit_slices:Array[int]=[];var refit_starts:Array[int]=[];var refit_slice_count:=0
	for iteration in 64:
		began=Time.get_ticks_usec()
		var start:Dictionary=index.begin_refit(all_vertices,65+iteration)
		if iteration>=16:refit_starts.append(Time.get_ticks_usec()-began)
		refit_slice_count=0
		for step in 100000:
			var slice_began:=Time.get_ticks_usec()
			var result:Dictionary=index.advance_refit(start.refit_id,Index.MAX_VERTICES,Index.MAX_TRIANGLES*2,1000)
			if iteration>=16:refit_slices.append(Time.get_ticks_usec()-slice_began)
			refit_slice_count+=1
			if result.status=="READY":break
			if result.status!="PENDING":errors.append("bounded refit failed");break
		if iteration>=16:refit_totals.append(Time.get_ticks_usec()-began)
	var cases:Array=[]
	for bone_name:String in ["head","chest","forearm_l","shin_r"]:
		var target:Vector3=(skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(bone_name))).origin
		for radius:float in [.10,.14]:
			var from:=target+Vector3(0,0,.50);var to:=target-Vector3(0,0,.10)
			var query:=AABB(from,Vector3.ZERO).expand(to).grow(radius)
			var contacts:Array=[{"from":from,"to":to,"radius":radius}]
			var scans:Array[int]=[];var linear_times:Array[int]=[];var indexed_times:Array[int]=[];var slice_times:Array[int]=[]
			var candidates:=0;var stats:Dictionary={}
			for iteration in 64:
				began=Time.get_ticks_usec();var ids:=PackedInt32Array()
				for i in bounds.size():
					if query.intersects(bounds[i]):ids.append(i)
				if iteration>=16:scans.append(Time.get_ticks_usec()-began)
				candidates=ids.size()
				began=Time.get_ticks_usec();var best:=INF;var winner:=-1;var expected:Dictionary={}
				for i:int in ids:
					var tri:Array=triangles[i]
					var hit:Dictionary=Kernel.sample(from,to,radius,tri[0],tri[1],tri[2])
					if hit.hit and hit.score<best:best=hit.score;winner=i;expected=hit
				if iteration>=16:linear_times.append(Time.get_ticks_usec()-began)
				began=Time.get_ticks_usec()
				var start:Dictionary=index.begin_query(contacts,128)
				var answer:Dictionary={}
				for step in 100000:
					var slice_began:=Time.get_ticks_usec()
					answer=index.advance_query(start.query_id,64,16,1000)
					if iteration>=16:slice_times.append(Time.get_ticks_usec()-slice_began)
					if answer.status!="PENDING":break
				if iteration>=16:indexed_times.append(Time.get_ticks_usec()-began)
				if answer.status!="COMPLETE" or answer.triangle_index!=winner or answer.candidate!=expected:
					if errors.size()<20:errors.append(bone_name+str(radius)+" selection mismatch")
				stats=answer.get("stats",{})
			cases.append({"bone":bone_name,"radius_m":radius,"linear_candidates":candidates,"cheap_cached_aabb_scan_us":summary(scans),"linear_kernel_only_us":summary(linear_times),"indexed_query_total_us":summary(indexed_times),"indexed_slice_us":summary(slice_times),"stats":stats,"samples":48})
	index.dispose();world.free()
	if FileAccess.get_sha256("res://scripts/combat/melee_triangle_contact.gd")!=frozen:errors.append("kernel changed during benchmark")
	var report:={"passed":errors.is_empty(),"errors":errors,"kernel_sha256":frozen,"index_sha256":FileAccess.get_sha256("res://scripts/combat/melee_triangle_index.gd"),"vertices":vertices_count,"triangles":triangles.size(),"fixture_skin_and_bounds_setup_us":setup_us,"topology_build_us":build_us,"full_refit_us":summary(refits),"bounded_refit_total_us":summary(refit_totals),"bounded_refit_slice_us":summary(refit_slices),"bounded_refit_begin_us":summary(refit_starts),"last_refit_slices":refit_slice_count,"nodes":built.get("nodes",0),"cases":cases,"scope":"Actual hero skin at stationary current pose; exact same triangles, sweeps and kernel for scan/index. Build once and full refit measured separately. Refit excludes upstream skin deformation; fixture setup includes skin plus test linear bounds. No authority/occlusion or full game FPS claim."}
	var file:=FileAccess.open("../../outputs/melee_triangle_index/cost.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MELEE_INDEX_ACTUAL_SKIN_COST ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
func summary(values:Array[int])->Dictionary:
	values.sort()
	return {"p50":values[int(values.size()*.5)],"p95":values[mini(int(values.size()*.95),values.size()-1)],"max":values[-1]}
