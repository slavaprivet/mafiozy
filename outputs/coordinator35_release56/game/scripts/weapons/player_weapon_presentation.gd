extends RefCounted
## Presentation only. The player remains the sole bone/pose authority writer.
const Pose = preload("res://scripts/weapons/weapon_pose.gd")
const Catalog = preload("res://scripts/weapon_visual/weapon_visual_catalog.gd")
var _player: WeakRef
var _rig: Skeleton3D
var _actor: Node3D
var _motion: Node3D
var _mount: Node3D
var _visual: Node3D
var _catalog: RefCounted
var _pose: RefCounted
var _rig_rest := Transform3D.IDENTITY
var _normalized_rest := Transform3D.IDENTITY
var _socket := -1
var _source_height := 0.0
var _height := 0.0
var _identity: Array = []
var _bind_nodes: Array[Node3D] = []
var _bind_frames: Array[Transform3D] = []
var _weapon: Dictionary = {}
var _pending: Dictionary = {}
var _receipt: Dictionary = {}
var _generation := 0
var _serial := 0
var _ready := false

func _owner() -> Node3D:
	if not _ready or _player == null: return null
	var player := _player.get_ref() as Node3D
	if not is_instance_valid(player) or not player.is_inside_tree(): return null
	for node: Node in [player, _actor, _motion, _rig, _mount]:
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree(): return null
	if not player.is_ancestor_of(_actor) or not _actor.is_ancestor_of(_motion) or not _motion.is_ancestor_of(_rig) or _mount.get_parent() != _rig: return null
	if player.get("_pose_skeleton") != _rig or player.get("_pose_motion") != _motion or player.get("_visual") != _actor: return null
	var ancestor: Node = _rig
	while ancestor != null:
		if ancestor.is_queued_for_deletion(): return null
		ancestor = ancestor.get_parent()
	if not player.has_meta("actor_id") or not player.has_meta("life_generation"): return null
	if player.get_meta("actor_id") != _identity[0] or player.get_meta("life_generation") != _identity[1]: return null
	if player.get("_source_height") != _source_height or player.get("model_target_height") != _height: return null
	for i: int in _bind_nodes.size():
		if not is_instance_valid(_bind_nodes[i]) or _bind_nodes[i].transform != _bind_frames[i]: return null
	return player

func _allowed(player: Node3D) -> bool:
	return player != null and player.get("_pose_authority") == &"on_foot"

func configure(player: Node3D) -> Dictionary:
	if _ready or not Thread.is_main_thread() or not is_instance_valid(player) or not player.is_inside_tree(): return {"ok":false,"error":"binding"}
	var rig := player.get("_pose_skeleton") as Skeleton3D
	var motion := player.get("_pose_motion") as Node3D
	var actor := player.get("_visual") as Node3D
	if rig == null or motion == null or actor == null or not motion.is_ancestor_of(rig) or not actor.is_ancestor_of(motion): return {"ok":false,"error":"hierarchy"}
	var normalized := motion.get_node_or_null("UniformModelScale") as Node3D
	if normalized == null or not normalized.is_ancestor_of(rig): return {"ok":false,"error":"normalized_node"}
	var names := PackedStringArray(); var parents := PackedInt32Array(); var rest: Array[Transform3D] = []
	for i: int in rig.get_bone_count():
		names.append(rig.get_bone_name(i)); parents.append(rig.get_bone_parent(i)); rest.append(rig.get_bone_rest(i))
	var rig_rest := motion.global_transform.affine_inverse()*rig.global_transform
	var pose := Pose.new()
	if not pose.configure(names,parents,rest,rig_rest): return {"ok":false,"error":"source_rig"}
	var source: Variant=player.get("_source_height"); var height: Variant=player.get("model_target_height")
	if not Pose._number(source) or not Pose._number(height) or source <= 0 or height < 1 or height > 3:
		pose.dispose(); return {"ok":false,"error":"dimensions"}
	var catalog := Catalog.new(); var opened: Dictionary = catalog.open()
	if not opened.ok: pose.dispose(); return opened
	_player=weakref(player); _rig=rig; _motion=motion; _actor=actor; _pose=pose; _catalog=catalog
	_rig_rest=rig_rest; _normalized_rest=motion.global_transform.affine_inverse()*normalized.global_transform
	_socket=rig.find_bone("socket_weapon"); _source_height=source; _height=height
	_identity=[player.get_meta("actor_id") if player.has_meta("actor_id") else null,player.get_meta("life_generation") if player.has_meta("life_generation") else null]
	var bind_node: Node3D=rig
	while bind_node != motion:
		_bind_nodes.append(bind_node); _bind_frames.append(bind_node.transform)
		bind_node=bind_node.get_parent() as Node3D
	_mount=Node3D.new(); _mount.name="OriginalWeaponPresentation"; rig.add_child(_mount)
	_ready=true
	return {"ok":true,"bone_count":names.size()}

func _remove_visual() -> void:
	_generation+=1; _pending.clear(); _receipt.clear(); _weapon.clear()
	if is_instance_valid(_visual): _visual.free()
	_visual=null

func equip(id: String) -> Dictionary:
	if not Thread.is_main_thread(): return {"ok":false,"error":"thread"}
	var player:=_owner()
	if not _allowed(player): _remove_visual(); return {"ok":false,"error":"pose_authority"}
	if id == "none": _remove_visual(); return {"ok":true,"weapon_id":"none"}
	if id == _weapon.get("id") and is_instance_valid(_visual): return {"ok":true,"weapon_id":id}
	var created: Dictionary=_catalog.instantiate_weapon(id)
	if not created.ok: return created
	_remove_visual(); _visual=created.visual; _mount.add_child(_visual); _visual.visible=false
	var profile: Dictionary=_visual.profile()
	_weapon={"id":id,"two_handed":profile.two_handed,"source_metadata":profile.source_metadata,"reload_magazine_local":null}
	for mesh: MeshInstance3D in _visual.geometry_nodes():
		if mesh.get_meta("weapon_animation_slot","") == "magazine":
			_weapon.reload_magazine_local=(mesh.get_meta("weapon_rest") as Transform3D).origin; break
	return {"ok":true,"weapon_id":id}

func decorate(base: Dictionary, aim: Dictionary={}, posture: Dictionary={}, phase: float=0.0, gait: float=0.0, epoch: int=0) -> Dictionary:
	if not Thread.is_main_thread(): return base
	_pending.clear(); _receipt.clear()
	var player:=_owner()
	if not _allowed(player): _remove_visual(); return base
	if _weapon.is_empty() or not is_instance_valid(_visual): return base
	_visual.visible=false
	if epoch != player.get("_pose_epoch"): return base
	var frame: Dictionary=Pose.make_frame(_actor.global_transform,_actor.global_rotation.y,base,_rig_rest,_normalized_rest,_height,_source_height)
	var selected: Dictionary=_pose.sample(base,_weapon,frame,aim,posture,phase,gait,epoch)
	if not selected.get("valid",false): return base
	_serial+=1
	_pending={"serial":_serial,"generation":_generation,"epoch":epoch,"before_revision":player.get("_pose_revision"),"actor_world":_actor.global_transform,"reload":aim.get("reloadProgress",0.0),"prone":posture.get("prone",0.0)}
	selected.weapon_presentation={"serial":_serial,"generation":_generation,"epoch":epoch}
	return selected

func after_pose_applied(selected: Dictionary) -> Dictionary:
	if not Thread.is_main_thread(): return {"ok":false,"error":"thread"}
	_receipt.clear()
	var player:=_owner()
	if not _allowed(player): _remove_visual(); return {"ok":false,"error":"pose_authority"}
	if _pending.is_empty() or not is_instance_valid(_visual):
		invalidate_pose(); return {"ok":false,"error":"no_pending_pose"}
	var token: Variant=selected.get("weapon_presentation")
	if not selected.get("valid",false) or not token is Dictionary or token.get("serial") != _pending.serial or token.get("generation") != _generation or token.get("epoch") != player.get("_pose_epoch"):
		invalidate_pose(); return {"ok":false,"error":"stale_selection"}
	if player.get("_pose_revision") != _pending.before_revision+1 or _actor.global_transform != _pending.actor_world or not selected.get("weapon") is Dictionary or selected.weapon.get("id") != _weapon.id or not Pose._frame(selected.weapon.get("local_to_socket")):
		invalidate_pose(); return {"ok":false,"error":"unapplied_selection"}
	# Read the writer's CURRENT displayed socket. No bone writes or skin capture.
	_mount.transform=_rig.get_bone_global_pose(_socket)
	_visual.transform=selected.weapon.local_to_socket
	_visual.apply_reload(_pending.reload,_pending.prone); _visual.visible=true
	var shot: Dictionary=_visual.shot_transform()
	if not shot.ok: invalidate_pose(); return shot
	_receipt=shot.duplicate()
	_receipt.merge({"weapon_id":_weapon.id,"pose_epoch":_pending.epoch,"pose_revision":player.get("_pose_revision"),"equip_generation":_generation,"sample_serial":_serial,"actor_id":_identity[0],"life_generation":_identity[1]})
	_receipt["_rig_world"]=_rig.global_transform; _receipt["_socket_pose"]=_mount.transform; _receipt["_visual_local"]=_visual.transform
	_pending.clear()
	return current_muzzle()

func current_muzzle() -> Dictionary:
	if not Thread.is_main_thread(): return {"ok":false,"error":"thread"}
	var player:=_owner()
	if not _allowed(player): _remove_visual(); return {"ok":false,"error":"pose_authority"}
	if _receipt.is_empty(): return {"ok":false,"error":"no_current_muzzle"}
	if not is_instance_valid(_visual) or _visual.is_queued_for_deletion() or _visual.get_parent()!=_mount or not _visual.is_visible_in_tree():
		invalidate_pose(); return {"ok":false,"error":"no_current_muzzle"}
	if player.get("_pose_epoch") != _receipt.pose_epoch or player.get("_pose_revision") != _receipt.pose_revision or _generation != _receipt.equip_generation or _rig.global_transform != _receipt._rig_world or _rig.get_bone_global_pose(_socket) != _receipt._socket_pose or _mount.transform != _receipt._socket_pose or _visual.transform != _receipt._visual_local:
		invalidate_pose(); return {"ok":false,"error":"stale_muzzle"}
	var shot: Dictionary=_visual.shot_transform()
	if not shot.get("ok",false) or shot.origin != _receipt.origin or shot.direction != _receipt.direction or shot.ejection_origin != _receipt.ejection_origin:
		invalidate_pose(); return {"ok":false,"error":"changed_muzzle"}
	var result:=_receipt.duplicate(); result.erase("_rig_world"); result.erase("_socket_pose"); result.erase("_visual_local")
	return result

func invalidate_pose() -> void:
	if not Thread.is_main_thread(): return
	_pending.clear(); _receipt.clear()
	if is_instance_valid(_visual): _visual.visible=false
	if _ready and not _allowed(_owner()): _remove_visual()

func dispose() -> void:
	if not Thread.is_main_thread(): return
	_remove_visual()
	if is_instance_valid(_mount): _mount.free()
	if _pose != null: _pose.dispose()
	if _catalog != null: _catalog.close()
	_pose=null; _catalog=null; _mount=null; _rig=null; _actor=null; _motion=null; _player=null; _identity.clear(); _bind_nodes.clear(); _bind_frames.clear(); _ready=false
