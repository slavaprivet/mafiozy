extends SceneTree
const Player=preload("res://scripts/preview_player.gd")
const Pose=preload("res://scripts/character_physics/character_physics_pose.gd")
const Helper=preload("res://scripts/character_physics/recovery_surface_bounds.gd")
var checks:=0
var failures:=[]
func _initialize():run.call_deferred()
func check(value:bool,label:String):
	checks+=1
	if not value:failures.append(label)
func floor_y(_x:float,_z:float)->float:return 0.0
func stats(values:Array)->Dictionary:
	values.sort();return {"samples":values.size(),"p50_us":values[values.size()/2],"p95_us":values[int(values.size()*.95)],"max_us":values[-1]}
func run():
	var hash=FileAccess.get_sha256("res://scripts/character_physics/recovery_surface_bounds.gd")
	var p=Player.new();root.add_child(p);p.set_physics_process(false)
	var prepared=Pose.new();check(prepared.configure(p._pose_skeleton,p._pose_motion,p._locomotion._rest_poses,p._model_scale,p._pose_motion),"actual full skin configured")
	var helper=Helper.new();check(helper.configure(prepared),"refinement configure");check(not helper.configure(prepared),"no rebind")
	var body=StaticBody3D.new();var node=CollisionShape3D.new();node.shape=BoxShape3D.new();body.add_child(node);root.add_child(body)
	var fixture_path="res://scripts/tests/fixtures/recovery_surface_bounds.bin"
	check(FileAccess.get_sha256(fixture_path)=="43150a81badb6435cb89e6a5c66b56207c8f555e1780b5d0a2986efe8bacb835","exact captured fixture receipt")
	var fixtures: Array=FileAccess.open(fixture_path,FileAccess.READ).get_var()
	var rows:=[];var costs:=[];var snapshot_costs:=[];var reuse_costs:=[]
	for index in fixtures.size():
		var f:Dictionary=fixtures[index]
		node.transform=f.box_transform;node.shape.size=f.box_size
		helper.reset()
		var t=Time.get_ticks_usec();var a=helper.snapshot(f.previous,f.world,false);var b=helper.snapshot(f.proposed,f.world,false);snapshot_costs.append(Time.get_ticks_usec()-t)
		check(a.get("valid",false) and b.get("valid",false),"captured actual pair "+str(index))
		t=Time.get_ticks_usec();var proof=helper.prove_box_separation(a,b,node);costs.append(Time.get_ticks_usec()-t)
		check(proof.get("proven",false)==(-f.continuous_plane_upper_bound>.001),"captured separation must exceed retained1mm margin "+str(index)+str(proof))
		t=Time.get_ticks_usec();var repeat=helper.prove_box_separation(a,b,node);reuse_costs.append(Time.get_ticks_usec()-t)
		check(proof==repeat,"same pair cached deterministic")
		rows.append({"index":index,"actual_elapsed":f.elapsed,"proof":proof,"reference_continuous_separation_m":-f.continuous_plane_upper_bound})
		# Move the real captured car box just past the independently measured
		# maximum skin X. Endpoint penetration is a mandatory rejection.
		var record:Dictionary=helper._record(b);var inverse:Transform3D=node.global_transform.affine_inverse();var maximum:=-INF
		for point:Vector3 in record.points:maximum=maxf(maximum,(inverse*point).x+node.shape.size.x*.5)
		var shift=-maximum+.001299
		node.position-=node.basis.x*shift
		var inside:=0;var deepest:=0.0;inverse=node.global_transform.affine_inverse()
		for point:Vector3 in record.points:
			var q=(inverse*point).abs()-node.shape.size*.5
			if maxf(q.x,maxf(q.y,q.z))<0:inside+=1;deepest=maxf(deepest,-maxf(q.x,maxf(q.y,q.z)))
		check(inside>0 and deepest>.0012,"TEST_ONLY translated captured box actually contains skin")
		check(not helper.prove_box_separation(a,b,node).proven,"true1299micrometer endpoint penetration rejected")
		node.transform=f.box_transform
		var skew=node.transform;skew.basis.x+=skew.basis.y*.01;node.transform=skew
		check(not helper.prove_box_separation(a,b,node).proven,"unsupported sheared shape rejected")
		node.transform=f.box_transform
	var f:Dictionary=fixtures[0];helper.reset();node.transform=f.box_transform
	# Genuine captured trajectory, box shifted slightly closer. Endpoints stay
	# separated but full-interval curvature padding now needs subdivision.
	var sf:Dictionary=fixtures[1];node.transform=sf.box_transform
	var sa=helper.snapshot(sf.previous,sf.world,false);var sb=helper.snapshot(sf.proposed,sf.world,false)
	node.position-=node.basis.x*.0015
	check(not helper.prove_box_separation(sa,sb,node,.001,1).proven,"one interval cannot prove near-car path")
	var t=Time.get_ticks_usec();var subdivided=helper.prove_box_separation(sa,sb,node);var subdivision_cost=Time.get_ticks_usec()-t
	check(subdivided.proven and subdivided.parts>1,"bounded subdivision proves still-separated actual path")
	node.transform=f.box_transform;helper.reset()
	var a=helper.snapshot(f.previous,f.world,false);var b=helper.snapshot(f.proposed,f.world,false)
	var changed=b.duplicate();changed.epoch+=1
	check(not helper.prove_box_separation(a,changed,node).proven,"mutated handle cannot change epoch")
	check(not helper.prove_box_separation(a,b,node,0.0).proven,"cannot remove physical margin")
	check(not helper.prove_box_separation(a,b,node,.001,16).proven,"bounded subdivision limit")
	node.disabled=true;check(not helper.prove_box_separation(a,b,node).proven,"disabled box not mistaken for live proof");node.disabled=false
	var c=helper.snapshot(f.proposed,f.world,false)
	check(not helper.prove_box_separation(a,c,node).proven,"evicted handle rejected")
	helper.reset();var far:Transform3D=f.world;far.origin.x=1000.0
	a=helper.snapshot(f.previous,far,false);far.origin.x+=.005;b=helper.snapshot(f.proposed,far,false)
	check(not helper.prove_box_separation(a,b,node).proven,"5mm parent change at1000m rejected exactly")
	var malformed=f.previous.duplicate(true);malformed.poses[0].origin.x=NAN
	check(not helper.snapshot(malformed,f.world,false).get("valid",false),"nonfinite local translation rejected")
	# Build real prepared cache, then prove uncached old-pose reconstruction
	# does not overwrite it. No fake cache is installed by the test.
	p.global_transform=f.world
	var selected=prepared.standing_blend(f.previous,.2,floor_y,f.previous.authority_epoch)
	check(selected.get("valid",false),"actual standing cache produced")
	var cached=prepared._deformed.duplicate();var frames=prepared._frames.duplicate()
	helper.reset();a=helper.snapshot(f.previous,f.world,false);b=helper.snapshot(selected,f.world,true)
	check(a.valid and b.valid and cached==prepared._deformed and frames==prepared._frames,"previous reconstruction preserves exact prepared next cache")
	var old=helper.snapshot(f.previous,f.world,true)
	check(not old.get("valid",false),"wrong prepared snapshot cache rejected")
	var mesh:MeshInstance3D=p._pose_motion.find_children("*","MeshInstance3D",true,false)[0]
	var skeleton_path=mesh.skeleton;mesh.skeleton=NodePath(".")
	check(not helper.snapshot(f.previous,f.world,false).get("valid",false),"same mesh cannot switch skeleton binding")
	mesh.skeleton=skeleton_path
	var resource=mesh.mesh;mesh.mesh=null
	check(not helper.snapshot(f.previous,f.world,false).get("valid",false),"removed actual source mesh rejected")
	mesh.mesh=resource
	check(helper.snapshot(f.previous,f.world,false).get("valid",false),"same unchanged mesh restored")
	resource.emit_changed()
	check(not helper.snapshot(f.previous,f.world,false).get("valid",false),"resource mutation invalidates cached geometry")
	var queued=Helper.new();check(queued.configure(prepared),"fresh queue-lifecycle observer")
	var extra=MeshInstance3D.new();extra.mesh=mesh.mesh;extra.skin=mesh.skin
	mesh.get_parent().add_child(extra);extra.skeleton=skeleton_path
	check(not queued.snapshot(f.previous,f.world,false).get("valid",false),"new descendant rendered geometry invalidates fullskin proof")
	var stale=Helper.new();check(not stale.configure(prepared),"prepared geometry missing already-added mesh cannot configure")
	extra.free()
	var queued_only=Helper.new();check(queued_only.configure(prepared),"fresh exact geometry after extra removed")
	var disposed=Helper.new();check(disposed.configure(prepared),"disposable observer configure")
	disposed.dispose();disposed.dispose()
	check(not resource.changed.is_connected(Callable(disposed,"_invalidate_geometry")) and not root.get_tree().node_added.is_connected(Callable(disposed,"_on_node_added")),"dispose disconnects every external lifetime signal")
	p.queue_free();check(not helper.prove_box_separation(a,b,node).proven,"queued source rig rejected")
	check(not queued_only.snapshot(f.previous,f.world,false).get("valid",false),"queued source ancestry rejected independently of resource invalidation")
	helper.dispose();queued.dispose();queued_only.dispose();stale.dispose();prepared.dispose();body.free();await process_frame
	check(hash==FileAccess.get_sha256("res://scripts/character_physics/recovery_surface_bounds.gd"),"helper bytes unchanged")
	var report={"checks":checks,"passed":failures.is_empty(),"failures":failures,"sha":hash,"fixtures":rows,"snapshot_pair_cpu":stats(snapshot_costs),"first_proof_cpu":stats(costs),"cached_pair_proof_cpu":stats(reuse_costs),"subdivision_case":{"proof":subdivided,"cpu_us":subdivision_cost},"scope":"Actual captured fullskin/car geometry. Headless CPU only, no driver integration/GPU/FPS acceptance."}
	FileAccess.open("res://../../outputs/coordinator21_melee_recovery_diagnostic/surface_bounds_test.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RECOVERY_SURFACE_BOUNDS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
