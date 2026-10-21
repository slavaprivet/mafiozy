extends SceneTree
const Reader=preload("res://scripts/traversal/traversal_rig_contact_reader.gd")
const Player=preload("res://scripts/preview_player.gd")
const Melee=preload("res://scripts/combat/melee_pose.gd")
var checks:=0
var failures: Array[String]=[]
var costs: Array[int]=[]
var worst:=0.0

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var player:=Player.new(); world.add_child(player); player.set_physics_process(false)
	player.global_position=Vector3(4,.1,-7)
	var skeleton: Skeleton3D=player._pose_skeleton
	var anchors: Dictionary={}
	for key: String in Reader.KEYS: anchors[key]={"bone":key,"local":Vector3(.015,.01,-.02)}
	var reader:=Reader.new()
	check(reader.configure(player,skeleton,anchors).valid,"actual imported hero anchor registration")
	var melee:=Melee.new()
	check(melee.configure(skeleton,player._pose_motion,player._locomotion._rest_poses,player._model_scale,player._visual),"real source pose sampler")
	var base:={"valid":true,"poses":player._locomotion._rest_poses.duplicate(),"visual_offset":Vector3.ZERO,"visual_rotation":Quaternion.IDENTITY}
	for action: Dictionary in [{"type":"kick","progress":.5},{"type":"punch","progress":.18/.62},{"type":"kick","progress":.18/.62}]:
		var selected: Dictionary=melee.sample(base,action,{},0,0,player._pose_epoch)
		check(selected.valid,"source full-affine pose sampled")
		# TEST_ONLY existing sole writer. Reader never writes these matrices.
		player._apply_selected_pose(selected)
		var frames: Array[Transform3D]=[]
		for i in selected.poses.size():
			var parent:=skeleton.get_bone_parent(i)
			frames.append(selected.poses[i] if parent<0 else frames[parent]*selected.poses[i])
		var expected:={"valid":true,"root_position":player.global_position,"contacts":{}}
		for key: String in Reader.KEYS:
			var bone:=skeleton.find_bone(key)
			expected.contacts[key]={"world":skeleton.global_transform*(frames[bone]*anchors[key].local),"weight":1.0,"available":true}
		var captured: Dictionary=reader.capture()
		for key: String in Reader.KEYS:
			var error: float=captured.points[key].distance_to(expected.contacts[key].world)
			worst=maxf(worst,error); check(error<.00001,"actual full matrix registered anchor "+key)
		var measured: Dictionary=reader.measure(expected)
		check(measured.valid and measured.joint_anchor_gate_passed and measured.loaded_contacts==4,"registered actual anchors meet partial gate")
		check(not measured.visual_acceptance_complete and not measured.skin_clearance_checked,"joint anchors cannot masquerade as visual skin acceptance")
		await process_frame
		check(reader.measure(expected).joint_anchor_gate_passed,"engine frame retains measured affine pose")
		var future: Dictionary=expected.duplicate(true); future.root_position+=Vector3(.002,0,0)
		check(not reader.measure(future).joint_anchor_gate_passed,"future-root display mismatch fails1mm gate")
		var near: Dictionary=expected.duplicate(true); near.contacts.hand_l.world+=Vector3(.049,0,0)
		check(reader.measure(near).joint_anchor_gate_passed,"49mm loaded anchor difference allowed")
		near.contacts.hand_l.world+=Vector3(.002,0,0)
		check(not reader.measure(near).joint_anchor_gate_passed,"51mm loaded anchor difference fails")
		var unavailable: Dictionary=expected.duplicate(true); unavailable.contacts.hand_l.available=false
		check(not reader.measure(unavailable).joint_anchor_gate_passed,"unavailable loaded anchor fails")
		for i in 192:
			var began:=Time.get_ticks_usec(); var result: Dictionary=reader.measure(expected)
			if i>=64: costs.append(Time.get_ticks_usec()-began)
			check(result.joint_anchor_gate_passed,"warmed registered anchor measurement")
		# Check reader did not alter actor, rig origins, basis or selected overrides.
		for i in frames.size():
			check(skeleton.get_bone_global_pose(i).is_equal_approx(frames[i]),"read-only reader retains source global matrices")
	var ordinary: Dictionary=reader.capture()
	var ladder_descriptor: Dictionary={"valid":true,"lower":player.global_position,"normal":Vector3(0,0,1),"right":Vector3(1,0,0),"width":.8,"rung_spacing":.28,"yaw_rad":0.0}
	var Ladder=load("res://scripts/traversal/ladder_pose.gd")
	var proposal: Dictionary=Ladder.propose(ladder_descriptor,{"root_position":player.global_position,"travelled_m":1.0,"mount_progress":1.0,"dismount_progress":0.0})
	var unimplemented: Dictionary=reader.measure(proposal)
	check(unimplemented.valid and not unimplemented.joint_anchor_gate_passed,"unapplied ladder proposal fails actual hero contact gate")
	check(reader.capture().points==ordinary.points,"proposal measurement never applies rig")
	reader.dispose(); check(not reader.capture().valid,"disposed registration cannot supply stale pose")
	costs.sort()
	print("TRAVERSAL_RIG_CONTACT_READER_TEST ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"max_anchor_matrix_error_m":worst,"cpu_us":{"samples":costs.size(),"p50":costs[costs.size()/2],"p95":costs[int(costs.size()*.95)]},"scope":"actual imported hero joint-anchor measurement; no fullskin/LIVE/traversal writer acceptance"}))
	world.free(); quit(0 if failures.is_empty() else 1)

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
