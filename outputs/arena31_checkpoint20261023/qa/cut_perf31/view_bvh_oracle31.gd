extends SceneTree
const Views=preload("res://scripts/combat/contact_view_bvh31.gd")
var out: String
var checks: Dictionary={}
var errors: Array=[]
var rays:=0
var rng:=RandomNumberGenerator.new()

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): out=arg.trim_prefix("--qa-out=")
	rng.seed=318467
	run.call_deferred()

func verify(label: String, tree: RefCounted, keys: Array, boxes: Array[AABB], flags: PackedByteArray) -> void:
	tree.update(keys,boxes,flags)
	var passed:=true
	for i in 220:
		var a:=Vector3(rng.randf_range(-6,6),rng.randf_range(-4,4),rng.randf_range(-6,6))
		var b:=Vector3(rng.randf_range(-6,6),rng.randf_range(-4,4),rng.randf_range(-6,6))
		if i<boxes.size() and boxes[i].position.is_finite() and boxes[i].end.is_finite():
			var axis:=Vector3.RIGHT if i%2==0 else Vector3.FORWARD
			a=boxes[i].get_center()-axis*8; b=boxes[i].get_center()+axis*8
		if i%19==0: b=a
		var expected:=PackedInt32Array()
		for view in boxes.size():
			if flags[view]==0 or boxes[view].intersects_segment(a,b): expected.append(view)
		var actual: PackedInt32Array=tree.candidates(a,b)
		actual.sort(); expected.sort(); rays+=1
		if actual!=expected:
			passed=false
			if errors.size()<12: errors.append({"case":label,"from":a,"to":b,"actual":actual,"expected":expected})
	checks[label]=passed

func run() -> void:
	# Allow the scheduler to register this otherwise sub-second native fixture.
	await create_timer(2.0).timeout
	var tree=Views.new()
	var keys: Array=[]; var boxes: Array[AABB]=[]; var flags:=PackedByteArray()
	for i in 73:
		keys.append(["surface_%d"%i,i+100])
		var centre:=Vector3(rng.randf_range(-4,4),rng.randf_range(-2,2),rng.randf_range(-4,4))
		var size:=Vector3(rng.randf_range(.01,1),rng.randf_range(.01,1),rng.randf_range(.01,1))
		boxes.append(AABB(centre-size*.5,size)); flags.append(1)
	verify("all_safe",tree,keys,boxes,flags)
	var builds: int=tree.builds; var refits: int=tree.refits
	tree.update(keys,boxes,flags)
	checks.exact_repeat_no_rebuild=tree.builds==builds and tree.refits==refits
	for i in boxes.size(): boxes[i]=Transform3D(Basis(Vector3.UP,float(i)*.071),Vector3(.31,-.12,.77))*boxes[i]
	verify("moving_refit",tree,keys,boxes,flags)
	checks.pose_change_no_topology_rebuild=tree.builds==builds and tree.refits==refits+1
	keys.reverse(); boxes.reverse(); flags.reverse()
	verify("identity_reorder",tree,keys,boxes,flags)
	checks.reorder_rebuilds_once=tree.builds==builds+1
	flags.fill(0); verify("all_unsafe",tree,keys,boxes,flags)
	for i in flags.size(): flags[i]=1 if i%3!=0 else 0
	verify("safe_membership_changes",tree,keys,boxes,flags)
	boxes[0]=AABB(Vector3(NAN,NAN,NAN),Vector3.ONE); flags[0]=0
	verify("nonfinite_unsafe",tree,keys,boxes,flags)
	var actor=Views.new()
	var other_boxes: Array[AABB]=[]
	for box: AABB in boxes: other_boxes.append(AABB(box.position+Vector3(3,.5,-2),box.size))
	verify("second_actor",actor,keys,other_boxes,flags)
	verify("first_actor_unchanged",tree,keys,boxes,flags)
	var empty_boxes: Array[AABB]=[]
	verify("empty_after_nonempty",tree,[],empty_boxes,PackedByteArray())
	verify("restore_after_empty",tree,keys,boxes,flags)
	var passed:=not checks.values().has(false)
	var file:=FileAccess.open(out+"/RESULT.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"rays":rays,"errors":errors,"scope":"Independent exhaustive AABB selection. No scene, skin, triangle or gameplay behavior assertion.","counters":{"builds":tree.builds,"refits":tree.refits,"visits":tree.visits,"view_tests":tree.view_tests,"returned":tree.returned}},"  "))
	file.close()
	for i in 8: await process_frame
	quit(0 if passed else 2)
