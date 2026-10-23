extends SceneTree
const Player = preload("res://scripts/preview_player.gd")
const Melee = preload("res://scripts/combat/melee_pose.gd")
var checks := 0
var failures: Array[String] = []
var worst := 0.0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()
func expected_globals(player: CharacterBody3D, poses: Array) -> Array[Transform3D]:
	var frames: Array[Transform3D] = []
	for i in poses.size():
		var parent: int = player._pose_skeleton.get_bone_parent(i)
		frames.append(poses[i] if parent < 0 else frames[parent] * poses[i])
	return frames
func compare(player: CharacterBody3D, frames: Array[Transform3D], label: String) -> void:
	for i in frames.size():
		var got: Transform3D = player._pose_skeleton.get_bone_global_pose(i)
		var wanted := frames[i]
		var difference := maxf(got.origin.distance_to(wanted.origin),maxf(got.basis.x.distance_to(wanted.basis.x),maxf(got.basis.y.distance_to(wanted.basis.y),got.basis.z.distance_to(wanted.basis.z))))
		worst = maxf(worst,difference)
		check(difference < .00001,label+":"+str(player._pose_skeleton.get_bone_name(i)))
func run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var player := Player.new(); world.add_child(player); player.set_physics_process(false)
	var melee := Melee.new()
	check(melee.configure(player._pose_skeleton,player._pose_motion,player._locomotion._rest_poses,player._model_scale,player._visual),"actual hero bound")
	var base := {"valid":true,"poses":player._locomotion._rest_poses.duplicate(),"visual_offset":Vector3.ZERO,"visual_rotation":Quaternion.IDENTITY}
	var rest := expected_globals(player,base.poses)
	# These contact-phase poses exposed actual centimetre-scale deformation
	# with Skeleton3D.set_bone_pose's quaternion/scale decomposition.
	for action: Dictionary in [{"type":"kick","progress":.5},{"type":"punch","progress":.18/.62},{"type":"kick","progress":.18/.62}]:
		var selected: Dictionary = melee.sample(base,action,{},0,0,player._pose_epoch)
		check(selected.get("valid",false),"contact pose sampled")
		player._apply_selected_pose(selected)
		var frames := expected_globals(player,selected.poses)
		compare(player,frames,"exact displayed contact")
		await process_frame
		compare(player,frames,"engine frame retains displayed contact")
		player._apply_selected_pose(base)
		compare(player,rest,"ordinary pose clears override")
		check(not player._pose_affine_active,"ordinary writer releases affine state")
	for owner: StringName in [&"vehicle",&"physical_impact",&"on_foot"]:
		var selected: Dictionary = melee.sample(base,{"type":"kick","progress":.5},{},0,0,player._pose_epoch)
		player._apply_selected_pose(selected)
		var epoch: int = player._pose_epoch
		player.set_preview_pose_authority(owner,true)
		check(not player._pose_affine_active and player._pose_epoch == epoch+1,"new owner clears old override before writing")
		# Simulate an existing external owner writing ordinary local transforms:
		# a stale persistent override must not conceal that owner's pose.
		for i in 28: player._pose_skeleton.set_bone_pose(i,base.poses[i])
		compare(player,rest,"external local writer visible after handoff")
	print("MELEE_POSE_WRITER ",JSON.stringify({"checks":checks,"failures":failures,"max_global_matrix_error":worst,"scope":"Actual native hero and Skeleton3D frame/ownership transitions; no gameplay or GPU claim"}))
	world.free(); quit(0 if failures.is_empty() else 1)
