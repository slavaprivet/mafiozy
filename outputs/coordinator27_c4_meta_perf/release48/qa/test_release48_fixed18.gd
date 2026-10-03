extends "test_release48_focus.gd"
## Fixed equal native time in both variants; preserve real Q and live NPC motion.
## Immediate no-settle input regression is recorded separately.
var scene_ready_frame48: int = -1

func observe_site45(node: Node) -> void:
	super.observe_site45(node)
	# main creates PreviewPerf immediately after NPC setup and preview_ready=true,
	# in the same physics tick, before the first population.step. Read-only anchor.
	if node.name == "PreviewPerf" and node.get_parent() == game and game.preview_ready:
		if not check(scene_ready_frame48 < 0,"single native scene/NPC ready anchor"): return
		scene_ready_frame48 = Engine.get_physics_frames()
		evidence.scene_ready_anchor48 = {"physics_frame":scene_ready_frame48,"population":Perf45.population(game),"source":"main._setup_preview_perf after NPC setup and preview_ready"}

func hold_one45(index: int) -> bool:
	if index == 0:
		var target_frame: int = scene_ready_frame48 + 110
		if not check(scene_ready_frame48 >= 0 and Engine.get_physics_frames() <= target_frame,"first actual aim completed within fixed warmup boundary"): return false
		await step(target_frame - Engine.get_physics_frames())
		if finished: return false
		evidence.first_hold_boundary48 = {"anchor":"native scene/NPC ready","anchor_frame":scene_ready_frame48,"begin_frame":Engine.get_physics_frames(),"relative_physics_frames":Engine.get_physics_frames()-scene_ready_frame48,"required_physics_frames":110}
		if not check(Engine.get_physics_frames()-scene_ready_frame48 == 110,"first native hold starts at equal relative physics frame"): return false
	return await super.hold_one45(index)

func q_choice(button: Button, label: String) -> bool:
	if not await super.q_choice(button,label): return false
	if finished or button!=equipment._button: return not finished
	var previous: Transform3D=camera.global_transform
	var actor_start: Vector3=player.global_position
	var row: Dictionary={"label":label,"begin_frame":Engine.get_physics_frames(),
		"begin_ticks_usec":Time.get_ticks_usec(),"camera_before":Perf45.vector(previous.origin),
		"maximum_frames":18,"fixed_physics_frames":18,"required_stable_frames":3,"position_epsilon_m":.0005,
		"angle_epsilon_rad":.0001,"samples":[]}
	if not evidence.has("settle_after_q47"): evidence.settle_after_q47=[]
	evidence.settle_after_q47.append(row)
	var stable: int=0
	for _frame: int in 18:
		await step()
		if finished: return false
		var current: Transform3D=camera.global_transform
		var movement: float=current.origin.distance_to(previous.origin)
		var angle: float=current.basis.get_rotation_quaternion().angle_to(previous.basis.get_rotation_quaternion())
		var contact: Dictionary=equipment._target()
		row.samples.append({"physics_frame":Engine.get_physics_frames(),"camera_position":Perf45.vector(current.origin),
			"movement_m":movement,"angle_rad":angle,"contact":Perf45.vector(contact.point) if not contact.is_empty() else null})
		stable=stable+1 if movement<=.0005 and angle<=.0001 else 0
		previous=current
	row["stable_frames"]=stable; row["end_frame"]=Engine.get_physics_frames(); row["end_ticks_usec"]=Time.get_ticks_usec()
	row["actor_drift_m"]=player.global_position.distance_to(actor_start)
	return check(row.samples.size()==18 and stable>=3 and row.actor_drift_m<.001,"native Q camera settled before LMB without actor movement: "+label)
