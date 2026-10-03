extends RefCounted
## SOURCE CANDIDATE. Pure selected-pose decorator; never writes live bones.
## Native post-writer receipts are mandatory; IK predictions are diagnostics.
signal pose_applied(frame: Transform3D)
const Visuals = preload("c4_visuals.gd")
const FRAME_BONES := {"right_socket":"socket_hand_r","left_socket":"socket_hand_l","right_shoulder":"upperarm_r","right_elbow":"forearm_r","left_shoulder":"upperarm_l","left_elbow":"forearm_l"}
const MAX_RIGHT_ERROR_M := 0.025
const MAX_LEFT_ERROR_M := 0.035
const MAX_TOOL_ANGLE := 0.20
const MAX_TARGET_DRIFT_M := 0.005
const ARM_MASK := 1 | 2 | 512 | 1048576 | 256 | 1024
var _player: WeakRef
var _rig: Skeleton3D
var _motion: Node3D
var _motion_parent: Node3D
var _rig_to_motion := Transform3D.IDENTITY
var _rig_version := -1
var _actor_id: Variant
var _life: Variant
var _parents := PackedInt32Array()
var _ids: Dictionary={}
var _rest_hands: Array[Basis]=[]
var _socket_to_tool := Basis.IDENTITY
var _local: Array[Transform3D]=[]
var _world: Array[Transform3D]=[]
var _rig_world := Transform3D.IDENTITY
var _request: Dictionary={}
var _receipt: Dictionary={}
var _serial := 0
var _sample_serial := 0
var _consumed_serial := -1
var _epoch := -1
var _posture := ""
var _holding := false
var _ready := false
var _disposed := false
var _samples := 0
var _max_decorate_usec := 0
var _last_reason := "not_configured"
var _right_error := INF
var _left_error := INF
var _tool_angle := INF

func configure(player: CharacterBody3D) -> Dictionary:
	if _ready or _disposed or not Thread.is_main_thread() or not is_instance_valid(player) or not player.is_inside_tree(): return _fail("owner_lifetime")
	for method: String in ["set_equipment_pose_decorator","equipment_pose_owner_is","equipment_pose_allowed","current_equipment_pose_receipt"]:
		if not player.has_method(method): return _fail("root_equipment_hook_missing")
	if not player.has_signal("equipment_pose_applied"): return _fail("root_completion_missing")
	var rig: Variant=player.get("_pose_skeleton")
	var motion: Variant=player.get("_pose_motion")
	if not rig is Skeleton3D or not motion is Node3D or not motion.is_ancestor_of(rig) or rig.get_bone_count()!=28: return _fail("native_rig_required")
	if not motion.get_parent_node_3d() is Node3D or not player.is_ancestor_of(motion) or not motion.scale.is_equal_approx(Vector3.ONE): return _fail("native_unit_motion_hierarchy_required")
	if not player.has_meta("actor_id") or not player.has_meta("life_generation"): return _fail("native_life_required")
	for name: String in ["upperarm_r","forearm_r","hand_r","socket_hand_r","upperarm_l","forearm_l","hand_l","socket_hand_l"]:
		_ids[name]=rig.find_bone(name)
		if int(_ids[name])<0: return _fail("native_arm_bone_missing")
	for side: String in ["r","l"]:
		if rig.get_bone_parent(_ids["forearm_"+side])!=_ids["upperarm_"+side] or rig.get_bone_parent(_ids["hand_"+side])!=_ids["forearm_"+side] or rig.get_bone_parent(_ids["socket_hand_"+side])!=_ids["hand_"+side]: return _fail("native_arm_chain_required")
	_player=weakref(player); _rig=rig; _motion=motion; _motion_parent=motion.get_parent_node_3d(); _rig_version=rig.get_version()
	_actor_id=player.get_meta("actor_id"); _life=player.get_meta("life_generation")
	_rig_to_motion=motion.global_transform.affine_inverse()*rig.global_transform
	_parents.resize(28); _local.resize(28); _world.resize(28)
	for index: int in 28:
		_parents[index]=rig.get_bone_parent(index)
		if _parents[index]>=index: return _fail("native_parent_order_required")
	var visual: Node3D=player.get("_visual")
	if not is_instance_valid(visual): return _fail("native_visual_required")
	for side: String in ["r","l"]:
		_rest_hands.append((visual.global_basis.inverse()*rig.global_basis*rig.get_bone_global_rest(_ids["hand_"+side]).basis).orthonormalized())
	var hand_to_surface: Basis=Basis(Vector3.UP,PI)*Basis(Vector3.RIGHT,-PI*.5)*_rest_hands[0]
	_socket_to_tool=(hand_to_surface*rig.get_bone_rest(_ids.socket_hand_r).basis.orthonormalized()).inverse()
	if not player.set_equipment_pose_decorator(Callable(self,"decorate_pose")): return _fail("equipment_slot_owned")
	player.equipment_pose_applied.connect(_completed)
	_ready=true; _last_reason="ready"
	return {"ok":true,"backend":"pure_root_decorator44","actual_post_writer_receipt_required":true,"legacy_modifier_created":false}

func _fail(reason: String) -> Dictionary:
	_last_reason=reason
	return {"ok":false,"reason":reason}

func _current() -> bool:
	var player: Variant=_player.get_ref() if _player!=null else null
	if not _ready or _disposed or not is_instance_valid(player) or not player.is_inside_tree() or player.is_queued_for_deletion(): return false
	if not is_instance_valid(_rig) or not _rig.is_inside_tree() or _rig.is_queued_for_deletion() or not is_instance_valid(_motion) or not _motion.is_inside_tree() or _motion.is_queued_for_deletion(): return false
	if not is_instance_valid(_motion_parent) or _motion_parent.is_queued_for_deletion() or _motion.get_parent_node_3d()!=_motion_parent or not player.is_ancestor_of(_motion) or not _motion.is_ancestor_of(_rig) or not _motion.scale.is_equal_approx(Vector3.ONE): return false
	return player.get("_pose_skeleton")==_rig and player.get("_pose_motion")==_motion and _rig.get_version()==_rig_version and player.get_meta("actor_id",null)==_actor_id and player.get_meta("life_generation",null)==_life and player.equipment_pose_owner_is(Callable(self,"decorate_pose"))

func _stable_posture() -> String:
	if not _current(): return ""
	var weapons: Variant=_player.get_ref().get("_weapon_host")
	if not is_instance_valid(weapons) or weapons.get("posture")==null: return ""
	var state: Dictionary=weapons.posture.posture_state()
	if state.get("blocked",true): return ""
	if state.get("target")=="stand" and float(state.get("value",-1))==0.0: return "stand"
	if state.get("target")=="crouch" and float(state.get("value",-1))==1.0: return "crouch"
	return "" # No claimed prone or transition/kneel support.

func _allowed() -> bool:
	return _current() and _player.get_ref().equipment_pose_allowed() and (not _holding or int(_player.get_ref().get("_pose_epoch"))==_epoch) and not _stable_posture().is_empty() and (not _holding or _stable_posture()==_posture)

func begin_hold() -> Dictionary:
	cancel()
	if not _allowed(): return _fail("native_pose_or_posture_unavailable")
	_serial+=1; _epoch=int(_player.get_ref().get("_pose_epoch")); _posture=_stable_posture(); _holding=true
	return {"ok":true,"request_serial":_serial}

func prepare_hold(dt: float, progress: float, target: Dictionary) -> Dictionary:
	if not _holding or not _allowed(): cancel(); return _fail("native_pose_or_posture_changed")
	if not is_finite(dt) or dt<=0 or dt>.25 or not is_finite(progress) or progress<0 or progress>1: cancel(); return _fail("sample_input")
	if target.get("pose_serial")!=_serial or not is_instance_valid(target.get("body")) or not is_instance_valid(target.get("owner")): cancel(); return _fail("target_lifetime")
	if not target.get("point") is Vector3 or not target.point.is_finite() or not target.get("normal") is Vector3 or not target.normal.is_finite() or target.normal.length_squared()<.99: cancel(); return _fail("target_frame")
	var normal: Vector3=target.normal.normalized()
	var tool_basis: Basis=Visuals.surface_basis(normal)
	var reach: float=Visuals._smooth(progress,0,.18)
	var secure: float=Visuals._smooth(progress,.38,.50)*(1.0-Visuals._smooth(progress,.82,.94))
	var touch: float=sin(clampf((progress-.40)/.46,0,1)*TAU*2.0)*.009*secure
	var center: Vector3=target.point+normal*(.082+.16*(1.0-reach))
	_sample_serial+=1
	_request={"owner_id":get_instance_id(),"request_serial":_serial,"sample_serial":_sample_serial,"actor_id":_actor_id,"life_generation":_life,"pose_epoch":_epoch,"source_frame":Engine.get_physics_frames(),"progress":progress,"target_point":target.point,"normal":normal,"target_frame":target.body.global_transform,"target_body_id":target.body.get_instance_id(),"target_owner_id":target.owner.get_instance_id(),"target_generation":target.owner_generation,"tool_basis":tool_basis,"right_goal":center+tool_basis.x*.065+tool_basis.y*(touch+.022*secure),"left_goal":center-tool_basis.x*.085-tool_basis.y*.018}
	for name: String in FRAME_BONES: _request[name]=int(_ids[FRAME_BONES[name]])
	_request.make_read_only()
	_last_reason="awaiting_post_writer"
	return {"ok":true,"request_serial":_serial,"sample_serial":_sample_serial}

func cancel() -> void:
	_holding=false; _request={}; _receipt={}; _posture=""
	_right_error=INF; _left_error=INF; _tool_angle=INF

func _update_world() -> void:
	for index: int in 28: _world[index]=(_rig_world if _parents[index]<0 else _world[_parents[index]])*_local[index]

func _set_world_basis(index: int, basis: Basis) -> void:
	var parent: Basis=_rig_world.basis if _parents[index]<0 else _world[_parents[index]].basis
	# Preserve every local origin exactly. World rotations preserve segment length;
	# affine inverse-parent matrices go through the EXISTING affine sole writer.
	_local[index].basis=parent.inverse()*basis
	_update_world()

func _point_bone(index: int, end: int, target: Vector3) -> void:
	var before: Vector3=_world[end].origin-_world[index].origin
	var after: Vector3=target-_world[index].origin
	if before.length_squared()<.000001 or after.length_squared()<.000001: return
	_set_world_basis(index,Basis(Quaternion(before.normalized(),after.normalized()))*_world[index].basis)

func _reach(side: String, goal: Vector3, desired_rotation: Basis, blend: float) -> void:
	if blend<=0.0: return
	var upper: int=_ids["upperarm_"+side]; var fore: int=_ids["forearm_"+side]
	var hand: int=_ids["hand_"+side]; var socket: int=_ids["socket_hand_"+side]
	var original_rotation: Quaternion=_world[hand].basis.orthonormalized().get_rotation_quaternion()
	var rotation: Quaternion=original_rotation.slerp(desired_rotation.get_rotation_quaternion(),blend)
	var desired_hand: Basis=Basis(rotation*original_rotation.inverse())*_world[hand].basis
	var grip: Vector3=_world[socket].origin.lerp(goal,blend)
	var wrist: Vector3=grip-desired_hand*_local[socket].origin
	var shoulder: Vector3=_world[upper].origin
	var a: float=shoulder.distance_to(_world[fore].origin)
	var b: float=_world[fore].origin.distance_to(_world[hand].origin)
	var direction: Vector3=wrist-shoulder
	if a<.001 or b<.001 or direction.length_squared()<.000001: return
	var distance: float=clampf(direction.length(),absf(a-b)+.0001,a+b-.0001)
	direction=direction.normalized()
	var pole: Vector3=_request.tool_basis.x*(.6 if side=="r" else -.6)+Vector3.DOWN*.8+_request.normal*.15
	pole-=direction*pole.dot(direction)
	if pole.length_squared()<.000001: pole=direction.cross(Vector3.RIGHT if absf(direction.x)<.9 else Vector3.UP)
	pole=pole.normalized()
	var along: float=(a*a-b*b+distance*distance)/(2.0*distance)
	var elbow: Vector3=shoulder+direction*along+pole*sqrt(maxf(0,a*a-along*along))
	_point_bone(upper,fore,elbow); _point_bone(fore,hand,shoulder+direction*distance)
	_set_world_basis(hand,desired_hand)

func decorate_pose(_dt: float, selected: Dictionary) -> Dictionary:
	if not _holding or _request.is_empty() or not _allowed() or selected.has("melee"): return selected
	var age: int=Engine.get_physics_frames()-int(_request.source_frame)
	if age<0 or age>1 or not selected.get("valid",false) or not selected.get("poses") is Array or selected.poses.size()!=28: return selected
	var offset: Variant=selected.get("visual_offset")
	var rotation: Variant=selected.get("visual_rotation",Quaternion.IDENTITY)
	if not offset is Vector3 or not offset.is_finite() or not rotation is Quaternion or not rotation.is_finite() or not rotation.is_normalized(): return selected
	var started: int=Time.get_ticks_usec()
	for index: int in 28:
		var frame: Variant=selected.poses[index]
		if not frame is Transform3D or not frame.is_finite() or absf(frame.basis.determinant())<.0000001: return selected
		_local[index]=frame
	# Never read the previous live bone/motion pose as the incoming base.
	_rig_world=_motion_parent.global_transform*Transform3D(Basis(rotation),offset)*_rig_to_motion
	_update_world()
	var hand_orientation: Basis=_request.tool_basis*Basis(Vector3.UP,PI)*Basis(Vector3.RIGHT,-PI*.5)
	_reach("r",_request.right_goal,hand_orientation*_rest_hands[0],Visuals._smooth(_request.progress,0,.18))
	_reach("l",_request.left_goal,hand_orientation*_rest_hands[1],Visuals._smooth(_request.progress,.04,.24))
	for frame: Transform3D in _local:
		if not frame.is_finite(): return selected
	var result: Dictionary=selected.duplicate()
	result.poses=_local.duplicate(); result.equipment_pose=_request
	_samples+=1; _max_decorate_usec=maxi(_max_decorate_usec,Time.get_ticks_usec()-started)
	return result

func _completed(receipt: Dictionary) -> void:
	if not _holding or not _allowed() or _request.is_empty() or not is_same(receipt.get("request"),_request): return
	if not is_same(receipt,_player.get_ref().current_equipment_pose_receipt()): return
	_receipt=receipt
	var sample: Dictionary=held_frame()
	if sample.get("ok",false): pose_applied.emit(sample.frame)

func held_frame() -> Dictionary:
	if not _holding or not _allowed() or _receipt.is_empty(): return {"ok":false}
	var displayed: Dictionary=_receipt.request
	if displayed.request_serial!=_serial: return {"ok":false}
	if not is_same(_receipt,_player.get_ref().current_equipment_pose_receipt()): return {"ok":false}
	var right: Transform3D=_receipt.frames.right_socket
	var left: Transform3D=_receipt.frames.left_socket
	var tool: Basis=right.basis.orthonormalized()*_socket_to_tool
	_right_error=right.origin.distance_to(displayed.right_goal); _left_error=left.origin.distance_to(displayed.left_goal)
	_tool_angle=tool.get_rotation_quaternion().angle_to(displayed.tool_basis.get_rotation_quaternion())
	# Actual palm anchors the visual; model centre is behind its front-side grip.
	return {"ok":true,"frame":Transform3D(tool,right.origin-tool.x*.065-tool.z*.037),"right_hand_error_m":_right_error,"left_hand_error_m":_left_error,"tool_angle_radians":_tool_angle,"pose_revision":_receipt.pose_revision}

func _arms_clear() -> bool:
	var player: CharacterBody3D=_player.get_ref()
	var space: PhysicsDirectSpaceState3D=player.get_world_3d().direct_space_state
	for side: String in ["right","left"]:
		for pair: Array in [[side+"_shoulder",side+"_elbow"],[side+"_elbow",side+"_socket"]]:
			var start: Vector3=_receipt.frames[pair[0]].origin
			var end: Vector3=_receipt.frames[pair[1]].origin
			if start.distance_squared_to(end)<.000001: return false
			var query:=PhysicsRayQueryParameters3D.create(start,end,ARM_MASK,[player.get_rid()])
			query.hit_from_inside=true
			if not space.intersect_ray(query).is_empty(): return false
	return true

## Synchronous one-use admission. Only caller's freshly revalidated target may
## consume the EXACT current native receipt; timer/solver success is insufficient.
func consume_completion(target: Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or _consumed_serial==_serial or _request.is_empty() or _receipt.is_empty(): return _fail("no_unconsumed_receipt")
	if not is_same(_receipt.get("request"),_request): return _fail("final_request_not_applied")
	if target.get("pose_serial")!=_serial or float(_request.progress)!=1.0 or Engine.get_physics_frames()<=int(target.get("completion_frame",Engine.get_physics_frames())): return _fail("final_sample_pending")
	var actual: Dictionary=held_frame()
	if not actual.get("ok",false): return _fail("stale_native_receipt")
	if not is_instance_valid(target.get("body")) or not is_instance_valid(target.get("owner")): return _fail("target_retired")
	if target.body.get_instance_id()!=_request.target_body_id or target.owner.get_instance_id()!=_request.target_owner_id or target.owner_generation!=_request.target_generation or target.body.global_transform!=_request.target_frame: return _fail("target_generation_or_frame_changed")
	if target.point.distance_to(_request.target_point)>MAX_TARGET_DRIFT_M or target.normal.dot(_request.normal)<.999: return _fail("target_contact_changed")
	if _right_error>MAX_RIGHT_ERROR_M or _left_error>MAX_LEFT_ERROR_M or _tool_angle>MAX_TOOL_ANGLE: return _fail("actual_hands_cannot_reach")
	if not _arms_clear(): return _fail("actual_arm_path_blocked")
	if not is_same(_receipt,_player.get_ref().current_equipment_pose_receipt()): return _fail("pose_changed_during_commit")
	_consumed_serial=_serial; _last_reason="actual_reach_consumed"
	return {"ok":true,"request_serial":_serial,"sample_serial":_sample_serial,"pose_revision":_receipt.pose_revision,"physics_frame":_receipt.physics_frame,"actual_frame":actual.frame,"right_hand_error_m":_right_error,"left_hand_error_m":_left_error,"tool_angle_radians":_tool_angle}

func snapshot() -> Dictionary:
	return {"ready":_current(),"holding":_holding,"request_serial":_serial,"sample_serial":_sample_serial,"consumed_serial":_consumed_serial,"last_reason":_last_reason,"samples":_samples,"max_decorate_usec":_max_decorate_usec,"right_hand_error_m":_right_error,"left_hand_error_m":_left_error,"tool_angle_radians":_tool_angle,"maximum_completion_arm_rays":4,"rendered_skin_verified":false,"loaded_scene_performance":"unverified"}

func dispose() -> void:
	if _disposed: return
	cancel()
	var player: Variant=_player.get_ref() if _player!=null else null
	if is_instance_valid(player):
		if player.equipment_pose_applied.is_connected(_completed): player.equipment_pose_applied.disconnect(_completed)
		player.set_equipment_pose_decorator(Callable(),Callable(self,"decorate_pose"))
	_disposed=true; _ready=false; _rig=null; _motion=null; _motion_parent=null; _player=null
