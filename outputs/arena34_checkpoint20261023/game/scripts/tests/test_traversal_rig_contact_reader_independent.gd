extends SceneTree

const Reader=preload("res://scripts/traversal/traversal_rig_contact_reader.gd")

var checks:=0
var failures: Array[String]=[]
var world: Node3D


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	world=Node3D.new(); root.add_child(world)
	await _affine_read_only_and_formats()
	await _invalid_configuration()
	await _measurement_boundaries()
	await _lifetime_reparent_and_bone_identity()
	if checks==0: failures.append("test_did_not_execute")
	print("TRAVERSAL_RIG_CONTACT_READER_INDEPENDENT_TEST ",JSON.stringify({"passed":failures.is_empty(),
		"checks":checks,"failures":failures,"scope":"joint-anchor gate only; no skin, weapon, LIVE or full visual acceptance"}))
	world.free(); quit(0 if failures.is_empty() else 1)


func _affine_read_only_and_formats() -> void:
	var fixture: Dictionary=await _fixture()
	var reader=fixture.reader
	var configured: Dictionary=reader.configure(fixture.actor,fixture.skeleton,fixture.anchors)
	var actor_before: Transform3D=fixture.actor.global_transform
	var skeleton_before: Transform3D=fixture.skeleton.global_transform
	var bones_before: Array[Transform3D]=[]
	for index in fixture.skeleton.get_bone_count(): bones_before.append(fixture.skeleton.get_bone_global_pose(index))
	var captured: Dictionary=reader.capture()
	check(configured.valid and configured.joint_anchor_only and captured.valid, "valid actual Skeleton3D anchor reader configures and captures")
	for key: String in Reader.KEYS:
		var anchor: Dictionary=fixture.anchors[key]
		var index: int=fixture.skeleton.find_bone(str(anchor.bone))
		var expected: Vector3=fixture.skeleton.global_transform*(fixture.skeleton.get_bone_global_pose(index)*anchor.local)
		check(captured.points[key].distance_to(expected)<=.000001, "full affine point retained for "+key)
	check(captured.actual_root==fixture.actor.global_position and captured.joint_anchor_only
		and not captured.displayed_root_checked and not captured.skin_clearance_checked and not captured.visual_acceptance_complete,
		"capture labels joint-anchor-only result without false visual claim")
	var ladder_pose: Dictionary=_ladder_pose(captured,1.0,true)
	var ladder: Dictionary=reader.measure(ladder_pose)
	check(ladder.valid and ladder.loaded_contacts==4 and ladder.joint_anchor_gate_passed,
		"ladder contacts normalize and pass four loaded exact anchors")
	var traversal_pose: Dictionary=_traversal_pose(captured,1.0,true)
	var traversal: Dictionary=reader.measure(traversal_pose)
	check(traversal.valid and traversal.loaded_contacts==4 and traversal.joint_anchor_gate_passed,
		"traversal palms/feet normalize and pass four loaded exact anchors")
	check(traversal.joint_anchor_only and not traversal.skin_clearance_checked and not traversal.visual_acceptance_complete,
		"measurement never claims skin, weapon or full visual acceptance")
	check(fixture.actor.global_transform==actor_before and fixture.skeleton.global_transform==skeleton_before,
		"capture and measure never write actor or skeleton transforms")
	var bone_unchanged:=true
	for index in bones_before.size(): bone_unchanged=bone_unchanged and fixture.skeleton.get_bone_global_pose(index)==bones_before[index]
	check(bone_unchanged, "capture and measure never write bone poses")
	_destroy(fixture); await _sync()


func _invalid_configuration() -> void:
	var fixture: Dictionary=await _fixture()
	var reader=fixture.reader
	var missing: Dictionary=fixture.anchors.duplicate(true); missing.erase("foot_r")
	check(reader.configure(fixture.actor,fixture.skeleton,missing).reason=="anchors_required", "missing anchor key rejected")
	var extra: Dictionary=fixture.anchors.duplicate(true); extra.extra={"bone":&"Root","local":Vector3.ZERO}
	check(reader.configure(fixture.actor,fixture.skeleton,extra).reason=="anchors_required", "extra anchor key rejected")
	var bad_local: Dictionary=fixture.anchors.duplicate(true); bad_local.hand_l.local=Vector3(NAN,0,0)
	check(reader.configure(fixture.actor,fixture.skeleton,bad_local).reason=="invalid_anchor", "nonfinite local anchor rejected")
	var missing_bone: Dictionary=fixture.anchors.duplicate(true); missing_bone.hand_l.bone=&"Missing"
	check(reader.configure(fixture.actor,fixture.skeleton,missing_bone).reason=="invalid_anchor", "missing bone rejected")
	var bad_type: Dictionary=fixture.anchors.duplicate(true); bad_type.hand_l.bone=42
	check(reader.configure(fixture.actor,fixture.skeleton,bad_type).reason=="invalid_anchor", "non-string bone identity rejected")
	var duplicate: Dictionary=fixture.anchors.duplicate(true); duplicate.hand_r.bone=duplicate.hand_l.bone
	check(reader.configure(fixture.actor,fixture.skeleton,duplicate).reason=="duplicate_anchor_bone", "duplicate limb bone identity rejected")
	var foreign:=Skeleton3D.new(); world.add_child(foreign); foreign.add_bone("Root")
	check(reader.configure(fixture.actor,foreign,fixture.anchors).reason=="rig_unavailable", "skeleton outside actor hierarchy rejected")
	check(reader.configure(null,fixture.skeleton,fixture.anchors).reason=="rig_unavailable", "null actor public configure rejected")
	check(reader.configure(fixture.actor,null,fixture.anchors).reason=="rig_unavailable", "null skeleton public configure rejected")
	check(reader.configure(fixture.holder,fixture.skeleton,fixture.anchors).reason=="rig_unavailable", "wrong actor node type rejected")
	check(reader.configure(fixture.actor,fixture.holder,fixture.anchors).reason=="rig_unavailable", "wrong skeleton node type rejected")
	foreign.queue_free(); _destroy(fixture); await _sync()

	fixture=await _fixture(); reader=fixture.reader
	var freed_actor: CharacterBody3D=fixture.actor
	fixture.skeleton.reparent(fixture.scene,true); freed_actor.free()
	check(reader.configure(freed_actor,fixture.skeleton,fixture.anchors).reason=="rig_unavailable",
		"previously freed actor reference is rejected at public configure boundary")
	_destroy(fixture); await _sync()
	fixture=await _fixture(); reader=fixture.reader
	var freed_skeleton: Skeleton3D=fixture.skeleton; freed_skeleton.free()
	check(reader.configure(fixture.actor,freed_skeleton,fixture.anchors).reason=="rig_unavailable",
		"previously freed skeleton reference is rejected at public configure boundary")
	_destroy(fixture); await _sync()


func _measurement_boundaries() -> void:
	var fixture: Dictionary=await _fixture(); var reader=fixture.reader
	check(reader.configure(fixture.actor,fixture.skeleton,fixture.anchors).valid, "measurement fixture configured")
	var captured: Dictionary=reader.capture()
	var pose: Dictionary=_ladder_pose(captured,0.0,true)
	pose.contacts.hand_l.weight=.8; pose.contacts.hand_l.world+=Vector3(.0499,0,0)
	var contact_inside: Dictionary=reader.measure(pose)
	check(contact_inside.joint_anchor_gate_passed and contact_inside.loaded_contacts==1, "weight .8 and contact below 5cm pass")
	pose.contacts.hand_l.world+=Vector3(.0002,0,0)
	check(not reader.measure(pose).joint_anchor_gate_passed, "loaded contact above 5cm fails")
	pose=_ladder_pose(captured,0.0,true); pose.contacts.hand_l.weight=.8; pose.contacts.hand_l.available=false
	check(not reader.measure(pose).joint_anchor_gate_passed, "high-weight unavailable contact fails")
	pose=_ladder_pose(captured,0.0,true); pose.contacts.hand_l.weight=.799; pose.contacts.hand_l.available=false; pose.contacts.hand_l.world+=Vector3(5,0,0)
	var unloaded: Dictionary=reader.measure(pose)
	check(not unloaded.joint_anchor_gate_passed and not unloaded.contact_gate_applicable and unloaded.loaded_contacts==0 and not unloaded.contacts.hand_l.loaded,
		"zero loaded contacts remain diagnostic and cannot produce false green")
	pose=_ladder_pose(captured,1.0,true); pose.root_position+=Vector3(.00099,0,0)
	var root_inside: Dictionary=reader.measure(pose)
	check(root_inside.joint_anchor_gate_passed and root_inside.physical_root_gate_passed
		and root_inside.physical_root_error_m<Reader.ROOT_LIMIT_M and not root_inside.displayed_root_checked,
		"physical root error below 1mm passes without claiming displayed-root check")
	pose.root_position=captured.actual_root+Vector3(.00101,0,0)
	var root_outside: Dictionary=reader.measure(pose)
	check(not root_outside.joint_anchor_gate_passed and not root_outside.physical_root_gate_passed,
		"physical root error above 1mm fails")
	for bad: Variant in [NAN,-.01,1.01,"1",true]:
		pose=_ladder_pose(captured,1.0,true); pose.contacts.hand_l.weight=bad
		check(reader.measure(pose).reason=="invalid_contact", "invalid contact weight rejected: "+str(bad))
	pose=_ladder_pose(captured,1.0,true); pose.contacts.hand_l.world=Vector3(NAN,0,0)
	check(reader.measure(pose).reason=="invalid_contact", "nonfinite contact target rejected")
	pose=_ladder_pose(captured,1.0,true); pose.contacts.hand_l.erase("available")
	check(reader.measure(pose).reason=="invalid_contact", "missing contact availability rejected")
	check(reader.measure({}).reason=="invalid_pose", "missing pose root/validity rejected")
	pose={"valid":true,"root_position":captured.actual_root}
	check(reader.measure(pose).reason=="contacts_required", "missing contact family rejected")
	_destroy(fixture); await _sync()


func _lifetime_reparent_and_bone_identity() -> void:
	var fixture: Dictionary=await _fixture(); var reader=fixture.reader
	check(reader.configure(fixture.actor,fixture.skeleton,fixture.anchors).valid, "lifetime fixture configured")
	var before: Dictionary=reader.capture()
	var alternate:=Node3D.new(); fixture.actor.add_child(alternate)
	fixture.skeleton.reparent(alternate,true); await _sync()
	var under_actor: Dictionary=reader.capture()
	check(under_actor.valid and under_actor.points==before.points, "reparent within actor preserves valid world affine anchors")
	fixture.actor.global_position+=Vector3(2,.5,-1); await _sync()
	var moved: Dictionary=reader.capture()
	check(moved.valid and moved.actual_root==fixture.actor.global_position
		and moved.points.hand_l.distance_to(before.points.hand_l+Vector3(2,.5,-1))<=.00001,
		"actor reparented hierarchy movement updates captured world anchors")
	fixture.skeleton.reparent(world,true); await _sync()
	check(reader.capture().reason=="rig_unavailable", "skeleton reparent outside actor invalidates reader")
	_destroy(fixture); await _sync()

	for mutation: String in ["count","name","parent"]:
		fixture=await _fixture(); reader=fixture.reader; reader.configure(fixture.actor,fixture.skeleton,fixture.anchors)
		match mutation:
			"count": fixture.skeleton.add_bone("Added")
			"name": fixture.skeleton.set_bone_name(fixture.skeleton.find_bone("HandL"),"Changed")
			"parent": fixture.skeleton.set_bone_parent(fixture.skeleton.find_bone("FootL"),fixture.skeleton.find_bone("HandL"))
		fixture.skeleton.force_update_all_bone_transforms(); await _sync()
		check(reader.capture().reason=="rig_binding_changed", "bone "+mutation+" mutation invalidates identity lease")
		_destroy(fixture); await _sync()

	fixture=await _fixture(); reader=fixture.reader; reader.configure(fixture.actor,fixture.skeleton,fixture.anchors); reader.dispose()
	check(reader.capture().reason=="rig_unavailable", "dispose revokes node references")
	_destroy(fixture); await _sync()
	fixture=await _fixture(); reader=fixture.reader; reader.configure(fixture.actor,fixture.skeleton,fixture.anchors); fixture.actor.queue_free(); await _sync()
	check(reader.capture().reason=="rig_unavailable", "queued actor lifetime invalidates capture")
	reader.dispose(); _destroy(fixture); await _sync()
	fixture=await _fixture(); reader=fixture.reader; reader.configure(fixture.actor,fixture.skeleton,fixture.anchors); fixture.skeleton.free()
	check(reader.capture().reason=="rig_unavailable", "directly freed skeleton fails closed while actor remains alive")
	reader.dispose(); _destroy(fixture); await _sync()


func _fixture() -> Dictionary:
	var scene:=Node3D.new(); world.add_child(scene)
	var actor:=CharacterBody3D.new(); actor.name="actor"; actor.position=Vector3(3,2,-4); scene.add_child(actor)
	var holder:=Node3D.new(); holder.name="rig-holder"; holder.transform=Transform3D(Basis(Vector3(1.0,.12,0),Vector3(.18,.92,.06),Vector3(0,.14,1.08)),Vector3(.3,.2,-.1)); actor.add_child(holder)
	var skeleton:=Skeleton3D.new(); skeleton.name="actual-skeleton"; skeleton.transform=Transform3D(Basis(Vector3(.96,.03,.02),Vector3(.08,1.04,.04),Vector3(.01,.09,.94)),Vector3(.1,.4,.2)); holder.add_child(skeleton)
	for name: String in ["Root","HandL","HandR","FootL","FootR"]: skeleton.add_bone(name)
	for index in range(1,5): skeleton.set_bone_parent(index,0)
	skeleton.set_bone_rest(0,Transform3D(Basis.IDENTITY,Vector3(0,.9,0)))
	skeleton.set_bone_rest(1,Transform3D(Basis(Vector3(1,.05,0),Vector3(.03,.98,.04),Vector3(0,.02,1.02)),Vector3(-.55,.65,.05)))
	skeleton.set_bone_rest(2,Transform3D(Basis(Vector3(.99,-.04,.01),Vector3(.02,1.01,-.03),Vector3(0,.03,.97)),Vector3(.55,.65,.05)))
	skeleton.set_bone_rest(3,Transform3D(Basis.IDENTITY,Vector3(-.22,-.9,.03)))
	skeleton.set_bone_rest(4,Transform3D(Basis.IDENTITY,Vector3(.22,-.9,.03)))
	skeleton.force_update_all_bone_transforms(); await _sync()
	var anchors:={
		"hand_l":{"bone":&"HandL","local":Vector3(-.08,.02,.12)},
		"hand_r":{"bone":&"HandR","local":Vector3(.08,.02,.12)},
		"foot_l":{"bone":&"FootL","local":Vector3(-.03,-.06,.15)},
		"foot_r":{"bone":&"FootR","local":Vector3(.03,-.06,.15)},
	}
	return {"scene":scene,"actor":actor,"holder":holder,"skeleton":skeleton,"anchors":anchors,"reader":Reader.new()}


func _ladder_pose(captured: Dictionary,weight: float,available: bool) -> Dictionary:
	var contacts:={}
	for key: String in Reader.KEYS: contacts[key]={"world":captured.points[key],"weight":weight,"available":available}
	return {"valid":true,"root_position":captured.actual_root,"contacts":contacts}


func _traversal_pose(captured: Dictionary,weight: float,available: bool) -> Dictionary:
	return {"valid":true,"root_position":captured.actual_root,
		"palms":{"l":{"contact_world":captured.points.hand_l,"contact_weight":weight,"contact_available":available},
			"r":{"contact_world":captured.points.hand_r,"contact_weight":weight,"contact_available":available}},
		"feet":{"l":{"contact_world":captured.points.foot_l,"plant_weight":weight,"contact_available":available},
			"r":{"contact_world":captured.points.foot_r,"plant_weight":weight,"contact_available":available}}}


func _destroy(fixture: Dictionary) -> void:
	if fixture.get("reader")!=null: fixture.reader.dispose()
	if is_instance_valid(fixture.get("scene")): fixture.scene.queue_free()


func _sync() -> void:
	await physics_frame; await physics_frame


func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
