class_name NativeTraversalRigContactReader
extends RefCounted
## Read-only post-writer measurements of registered joint-local anchors.
## Does NOT prove skin, weapon, obstacle clearance, visual quality or frame FPS.
const PROVIDER:="GODOT_TRAVERSAL_RIG_CONTACT_READER_V1"
const KEYS:=["hand_l","hand_r","foot_l","foot_r"]
const ROOT_LIMIT_M:=.001
const CONTACT_LIMIT_M:=.05
const LOADED_WEIGHT:=.8
var _actor: CharacterBody3D
var _skeleton: Skeleton3D
var _bindings: Array[Dictionary]=[]
var _bone_count:=0
var _space: World3D

func configure(actor: Variant,skeleton: Variant,anchors: Dictionary) -> Dictionary:
	dispose()
	if not _node_valid(actor) or not actor is CharacterBody3D or not _node_valid(skeleton) or not skeleton is Skeleton3D or not actor.is_ancestor_of(skeleton) or actor.get_world_3d()!=skeleton.get_world_3d(): return _invalid("rig_unavailable")
	if anchors.size()!=KEYS.size(): return _invalid("anchors_required")
	var bindings: Array[Dictionary]=[]
	var indices: Dictionary={}
	for key: String in KEYS:
		var binding: Variant=anchors.get(key)
		if not binding is Dictionary or not binding.get("bone") is String and not binding.get("bone") is StringName or not binding.get("local") is Vector3:
			return _invalid("invalid_anchor")
		var name:=str(binding.bone)
		var index: int=skeleton.find_bone(name)
		if index<0 or not binding.local.is_finite(): return _invalid("invalid_anchor")
		if indices.has(index): return _invalid("duplicate_anchor_bone")
		indices[index]=true
		bindings.append({"key":key,"name":name,"index":index,"parent":skeleton.get_bone_parent(index),"local":binding.local})
	_actor=actor; _skeleton=skeleton; _bindings=bindings
	_bone_count=skeleton.get_bone_count(); _space=actor.get_world_3d()
	return {"provider":PROVIDER,"valid":true,"reason":"configured","joint_anchor_only":true}

func capture() -> Dictionary:
	if not _node_valid(_actor) or not _node_valid(_skeleton) or not _actor.is_ancestor_of(_skeleton) or _actor.get_world_3d()!=_space or _skeleton.get_world_3d()!=_space: return _invalid("rig_unavailable")
	if _skeleton.get_bone_count()!=_bone_count: return _invalid("rig_binding_changed")
	if not _actor.global_position.is_finite() or not _finite(_skeleton.global_transform): return _invalid("nonfinite_rig")
	var points: Dictionary={}
	for binding: Dictionary in _bindings:
		if _skeleton.get_bone_name(binding.index)!=binding.name or _skeleton.get_bone_parent(binding.index)!=binding.parent: return _invalid("rig_binding_changed")
		var frame:=_skeleton.get_bone_global_pose(binding.index)
		if not _finite(frame): return _invalid("nonfinite_rig")
		# Full matrix multiplication preserves native override shear/scale.
		var world: Vector3=_skeleton.global_transform*(frame*binding.local)
		if not world.is_finite(): return _invalid("nonfinite_rig")
		points[binding.key]=world
	return {"provider":PROVIDER,"valid":true,"reason":"captured","actual_root":_actor.global_position,"points":points,"joint_anchor_only":true,"displayed_root_checked":false,"skin_clearance_checked":false,"visual_acceptance_complete":false}

func measure(expected: Dictionary) -> Dictionary:
	var actual:=capture()
	if not actual.valid: return actual
	if not bool(expected.get("valid",false)) or not expected.get("root_position") is Vector3 or not expected.root_position.is_finite(): return _invalid("invalid_pose")
	var wanted:=_contacts(expected)
	if not wanted.valid: return wanted
	var root_error: float=actual.actual_root.distance_to(expected.root_position)
	var errors: Dictionary={}
	var loaded:=0
	var passed:=root_error<=ROOT_LIMIT_M
	for key: String in KEYS:
		var contact: Dictionary=wanted.contacts[key]
		var distance: float=actual.points[key].distance_to(contact.world)
		var is_loaded: bool=contact.weight>=LOADED_WEIGHT
		if is_loaded:
			loaded+=1
			passed=passed and contact.available and distance<=CONTACT_LIMIT_M
		errors[key]={"actual":actual.points[key],"target":contact.world,"error_m":distance,"weight":contact.weight,"loaded":is_loaded,"available":contact.available}
	return {"provider":PROVIDER,"valid":true,"reason":"measured","physical_root_error_m":root_error,"physical_root_gate_passed":root_error<=ROOT_LIMIT_M,"contacts":errors,"loaded_contacts":loaded,"contact_gate_applicable":loaded>0,"joint_anchor_gate_passed":passed and loaded>0,"joint_anchor_only":true,"displayed_root_checked":false,"skin_clearance_checked":false,"visual_acceptance_complete":false}

func dispose() -> void:
	_actor=null; _skeleton=null; _bindings.clear(); _space=null; _bone_count=0

func _contacts(pose: Dictionary) -> Dictionary:
	var contacts: Dictionary={}
	for key: String in KEYS:
		var contact: Variant
		if pose.get("contacts") is Dictionary:
			contact=pose.contacts.get(key)
		elif pose.get("palms") is Dictionary and pose.get("feet") is Dictionary:
			contact=pose.palms.get(key.right(1)) if key.begins_with("hand") else pose.feet.get(key.right(1))
		else: return _invalid("contacts_required")
		if not contact is Dictionary: return _invalid("contacts_required")
		var world: Variant=contact.get("world",contact.get("contact_world"))
		var weight: Variant=contact.get("weight",contact.get("contact_weight",contact.get("plant_weight")))
		var available: Variant=contact.get("available",contact.get("contact_available"))
		if not world is Vector3 or not world.is_finite() or not weight is float and not weight is int or not available is bool: return _invalid("invalid_contact")
		if not is_finite(float(weight)) or float(weight)<0.0 or float(weight)>1.0: return _invalid("invalid_contact")
		contacts[key]={"world":world,"weight":float(weight),"available":available}
	return {"valid":true,"contacts":contacts}

func _node_valid(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node and node.is_inside_tree() and not node.is_queued_for_deletion()

func _finite(frame: Transform3D) -> bool:
	return frame.origin.is_finite() and frame.basis.x.is_finite() and frame.basis.y.is_finite() and frame.basis.z.is_finite()

func _invalid(reason: String) -> Dictionary:
	return {"provider":PROVIDER,"valid":false,"reason":reason,"joint_anchor_gate_passed":false,"joint_anchor_only":true,"displayed_root_checked":false,"skin_clearance_checked":false,"visual_acceptance_complete":false}
