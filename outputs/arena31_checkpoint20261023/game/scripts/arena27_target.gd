extends "res://scripts/weapons/sword_prototype.gd"
## Only this isolated laboratory changes target life/AI. Contact laws are inherited.
var lab_fixed := true
var _lab_trace_enabled28 := OS.get_cmdline_user_args().has("--lab-trace=1")
var lab_regrow := true
var lab_armored := true
var lab_resets := 0
var lab_last_hit: Dictionary = {}
var lab_events: Array[Dictionary] = []
var _lab_restore_at := 0
var _lab_reset_pending := false
var _lab_origin := Vector3(0, 0.02, -2)
const LAB_DEBRIS_LIFETIME_MS := 3000
var _lab_original_nodes: Array[Dictionary] = []
var _lab_spawn_armored := true
var _lab_spawn_fixed := true
var _lab_pose_ready := false
var lab_fast_resets := 0
var lab_last_reset_usec := 0
var lab_last_reset_reason := "initial"
var _lab_posed_arrays: Dictionary = {}
var lab_pose_cache_hits := 0
var _lab_head_templates: Array[Dictionary] = []
var _lab_hidden_headwear: Array[Dictionary] = []
var _lab_gore_updated := false

func _place_targets() -> Dictionary:
	return {"dummy": false, "pole": false}

func _cut_skin_arrays39(source: Array, binds: Array[Transform3D], undo: bool) -> Array:
	if undo or not lab_fixed:
		return super._cut_skin_arrays39(source, binds, undo)
	# Exact array and transform comparison guards both hash collisions and pose
	# changes. This only skips repeated skinning, never a cut or cap operation.
	var key := source.hash()
	var cached: Dictionary = _lab_posed_arrays.get(key, {})
	if not cached.is_empty() and cached.source == source and cached.binds == binds:
		lab_pose_cache_hits += 1
		return cached.posed
	var posed := super._cut_skin_arrays39(source, binds, false)
	if _lab_posed_arrays.size() >= 32: _lab_posed_arrays.erase(_lab_posed_arrays.keys()[0])
	_lab_posed_arrays[key] = {"source":source,"binds":binds.duplicate(),"posed":posed}
	return posed

func _dress_knight() -> void:
	if lab_armored:
		set_npc_armor31({"head":"light_head","torso":"light_torso","hands":"light_hands","legs":"light_legs","feet":"light_feet"})

func lab_spawn() -> bool:
	var ok := _spawn_resident_knight(_lab_origin)
	if ok:
		_npc_body.rotation.y = PI
		_lab_pose_ready = false
		if lab_fixed: _lab_pose()
		_lab_capture_original()
		for entry: Dictionary in _npc_debris:
			if is_instance_valid(entry.get("node")): _lab_debris_ignore_owner28(entry.node)
	return ok

func _lab_pose() -> void:
	if not is_instance_valid(_npc_rig): return
	if _lab_pose_ready:
		_apply_npc_severed()
		return
	_npc_rig.reset_bone_poses()
	# Raise the complete arm chains from the resident's arms-down rest pose.
	for side: String in ["l", "r"]:
		var upper := _npc_rig.find_bone("upperarm_"+side)
		var fore := _npc_rig.find_bone("forearm_"+side)
		var hand := _npc_rig.find_bone("hand_"+side)
		var parent := _npc_rig.get_bone_parent(upper)
		var parent_pose := _npc_chain(parent)
		var rest_upper := _npc_rig.get_bone_rest(upper)
		var rest_fore := _npc_rig.get_bone_rest(fore)
		var rest_hand := _npc_rig.get_bone_rest(hand)
		var sign_x := signf((parent_pose * rest_upper).origin.x)
		var direction := Vector3(sign_x, 0, 0)
		var upper_pose := _npc_point_bone(upper,rest_upper,rest_fore.origin,parent_pose.basis,direction)
		_npc_point_bone(fore,rest_fore,rest_hand.origin,(parent_pose*upper_pose).basis,direction)
	_npc_motion.rotation = Vector3(0, PI, 0)
	_apply_npc_severed()
	if is_instance_valid(_npc_sword): _npc_sword.visible = false
	_lab_pose_ready = true

func _update_city_npc(delta: float) -> void:
	if not is_instance_valid(_npc_rig): return
	if not lab_fixed:
		super._update_city_npc(delta)
		return
	_ensure_player_hitboxes50()
	_lab_pose()
	_update_npc_bleed(delta)
	if lab_regrow and (_npc_dead or not _npc_severed.is_empty()):
		if _lab_restore_at == 0: _lab_restore_at = Time.get_ticks_msec() + 450
		if Time.get_ticks_msec() >= _lab_restore_at: lab_reset()

func _npc_receive_impulse31(part: String, speed: float, direction: Vector3, damage: float) -> void:
	if not lab_fixed: super._npc_receive_impulse31(part, speed, direction, damage)

func _queue_npc_corpse31(point: Vector3, direction: Vector3, speed: float) -> void:
	if not lab_fixed: super._queue_npc_corpse31(point, direction, speed)

func _npc_take_blade_part(part: String, point: Vector3, speed: float, direction: Vector3, damage: float, sever_contact: bool = false, penetrates: bool = true) -> void:
	var before := _npc_hp
	super._npc_take_blade_part(part, point, speed, direction, damage, sever_contact, penetrates)
	lab_last_hit = {"part":part,"speed":speed,"damage":before - _npc_hp,"contact":str(point),"sever":_npc_severed.keys(),"fixed_target":lab_fixed,"time_ms":Time.get_ticks_msec()}
	lab_events.append(lab_last_hit.duplicate(true))
	if lab_events.size() > 200: lab_events.pop_front()
	if _lab_trace_enabled28: print("ARENA27_CONTACT ", JSON.stringify(lab_last_hit))

func lab_reset() -> void:
	if _lab_reset_pending: return
	_lab_reset_pending = true
	_lab_reset_now.call_deferred()

func _lab_reset_now() -> void:
	var started := Time.get_ticks_usec()
	if _lab_restore_original():
		_lab_restore_at = 0
		lab_resets += 1
		lab_fast_resets += 1
		_lab_reset_pending = false
		lab_last_reset_usec = Time.get_ticks_usec() - started
		if _lab_trace_enabled28: print("ARENA27_RESTORE ", JSON.stringify({"ok":true,"generation":lab_resets,"fixed":lab_fixed,"reused_actor":true,"usec":lab_last_reset_usec}))
		return
	# Explicit laboratory reset: discard the old actor, rebuild all meshes,
	# skeleton, hit volumes, armour and health as one consistent generation.
	var old_body := _npc_body
	var old_corpse := _npc_corpse31
	_lab_original_nodes.clear()
	_npc_rig = null
	_npc_body = null
	_npc_sword = null
	_npc_corpse31 = null
	if is_instance_valid(old_corpse): old_corpse.free()
	elif is_instance_valid(old_body): old_body.free()
	if is_instance_valid(_npc_dropped_sword31):
		_ground_swords.erase(_npc_dropped_sword31)
		_npc_dropped_sword31.queue_free()
	_npc_knocked_until_ms31 = 0
	_npc_pain_until_ms = 0
	_npc_hit_push31 = Vector3.ZERO
	_npc_engaged = false
	_npc_state = "wait"
	_npc_timer = 0.0
	_npc_hit_ms = -10000
	_npc_blade_ms = -10000
	_lab_restore_at = 0
	lab_resets += 1
	var ok := lab_spawn()
	_lab_reset_pending = false
	lab_last_reset_usec = Time.get_ticks_usec() - started
	if _lab_trace_enabled28: print("ARENA27_RESTORE ", JSON.stringify({"ok":ok,"generation":lab_resets,"fixed":lab_fixed,"reused_actor":false,"usec":lab_last_reset_usec}))

func _lab_capture_original() -> void:
	_lab_original_nodes.clear()
	_lab_release_head_templates()
	_lab_hidden_headwear.clear()
	_lab_spawn_armored = lab_armored
	_lab_spawn_fixed = lab_fixed
	# Severing replaces meshes; the immutable original resources can be reused.
	# Detached decorations get new copies of the same originals; the removed
	# head keeps its own visible decorations for its entire debris lifetime.
	for anchor: Node in _npc_rig.find_children("*", "BoneAttachment3D", true, false):
		if str(anchor.bone_name) not in ["head", "socket_head"]: continue
		for child: Node in anchor.get_children():
			if not child is Node3D or child is CollisionObject3D or child is CollisionShape3D: continue
			if not child.find_children("*", "CollisionObject3D", true, false).is_empty(): continue
			var visuals: Array[Node] = child.find_children("*", "MeshInstance3D", true, false)
			if child is MeshInstance3D: visuals.append(child)
			var rigid := not visuals.is_empty()
			for visual: Node in visuals:
				if visual.skin != null: rigid = false
			if rigid:
				var template := child.duplicate()
				_lab_stamp_head_copy(child, template)
				_lab_head_templates.append({"node":child,"parent":anchor,"template":template})
	if is_instance_valid(_npc_armor_visual31):
		var hidden: Dictionary = _npc_armor_visual31.get("_hidden_headwear")
		for mesh: Node in hidden:
			if is_instance_valid(mesh): _lab_hidden_headwear.append({"path":_npc_body.get_path_to(mesh),"visible":hidden[mesh]})
	for node: Node in _npc_body.find_children("*", "Node3D", true, false):
		var row := {"node":node,"parent":node.get_parent(),"path":_npc_body.get_path_to(node),"visible":node.visible}
		if node is MeshInstance3D:
			row["mesh"] = node.mesh
			row["material"] = node.material_override
			var overrides: Array[Material] = []
			for index in node.get_surface_override_material_count():
				overrides.append(node.get_surface_override_material(index))
			row["overrides"] = overrides
		if node is CollisionObject3D:
			row["layer"] = node.collision_layer
			row["mask"] = node.collision_mask
		_lab_original_nodes.append(row)

func _lab_restore_original() -> bool:
	if not lab_fixed or not _lab_spawn_fixed or lab_armored != _lab_spawn_armored: return false
	if not is_instance_valid(_npc_body) or not is_instance_valid(_npc_rig) or not is_instance_valid(_npc_sword): return false
	if is_instance_valid(_npc_corpse31) or _lab_original_nodes.is_empty(): return false
	var replaced: Dictionary = {}
	for entry: Dictionary in _lab_head_templates:
		if is_instance_valid(entry.node) and entry.node.get_parent() == entry.parent: continue
		if not is_instance_valid(entry.parent): return false
		var copy: Node3D = entry.template.duplicate()
		entry.parent.add_child(copy)
		entry.node = copy
		var copies: Array[Node] = copy.find_children("*", "Node", true, false)
		copies.append(copy)
		for node: Node in copies:
			if node.has_meta("lab_source_path28"): replaced[str(node.get_meta("lab_source_path28"))] = node
	for row: Dictionary in _lab_original_nodes:
		if replaced.has(str(row.path)):
			row.node = replaced[str(row.path)]
			row.parent = row.node.get_parent()
		elif not is_instance_valid(row.node): return false
		var node: Node = row.node
		if node.is_queued_for_deletion() or node.get_parent() != row.parent:
			lab_last_reset_reason = "changed_parent:" + str(row.path)
			print("LAB28_REBUILD ",lab_last_reset_reason)
			return false
	_npc_severed.clear()
	_npc_mesh_cut_parts39.clear()
	_npc_head_mesh_cut31 = false
	_npc_part_hp.clear()
	_npc_dead = false
	_npc_hp = NPC_MAX_HP57
	_npc_disarmed = false
	_npc_engaged = false
	_npc_state = "wait"
	_npc_timer = 0.0
	_npc_hit_ms = -10000
	_npc_blade_ms = -10000
	_npc_knocked_until_ms31 = 0
	_npc_pain_until_ms = 0
	_npc_flinch_until_ms31 = 0
	_npc_hit_push31 = Vector3.ZERO
	_npc_bleed_until_ms = 0
	_npc_bleed_accum = 0.0
	_npc_bleed_bone27 = -1
	_npc_corpse_pending31 = false
	_npc_body.global_position = _lab_origin
	_npc_body.rotation = Vector3(0, PI, 0)
	_npc_body.velocity = Vector3.ZERO
	if is_instance_valid(_npc_armor_visual31): _npc_armor_visual31.reset_severed()
	for row: Dictionary in _lab_original_nodes:
		var node: Node3D = row.node
		node.visible = row.visible
		if node is MeshInstance3D:
			node.mesh = row.mesh
			node.material_override = row.material
			for index in row.overrides.size(): node.set_surface_override_material(index, row.overrides[index])
			if node.has_meta("physical_cut_retained33"): node.remove_meta("physical_cut_retained33")
		if node is CollisionObject3D:
			node.collision_layer = row.layer
			node.collision_mask = row.mask
	if is_instance_valid(_npc_armor_visual31):
		var hidden: Dictionary = _npc_armor_visual31.get("_hidden_headwear")
		hidden.clear()
		for saved: Dictionary in _lab_hidden_headwear:
			for row: Dictionary in _lab_original_nodes:
				if row.path == saved.path and is_instance_valid(row.node): hidden[row.node] = saved.visible
	_lab_pose_ready = false
	_lab_pose()
	return true

func _lab_release_head_templates() -> void:
	for entry: Dictionary in _lab_head_templates:
		if is_instance_valid(entry.template): entry.template.free()
	_lab_head_templates.clear()

func _lab_stamp_head_copy(source: Node, copy: Node) -> void:
	# Godot rewrites automatic @ names in duplicates; stable metadata reconnects
	# pristine rows without relying on the new generated names.
	copy.set_meta("lab_source_path28", str(_npc_body.get_path_to(source)))
	for index in source.get_child_count():
		_lab_stamp_head_copy(source.get_child(index), copy.get_child(index))

func _exit_tree() -> void:
	_lab_release_head_templates()
	super._exit_tree()

func _spawn_cut_debris(gone_arrays: Array, gone_cap: Array, from: MeshInstance3D, push: Vector3, outer_materials: Array[Material] = [], owner_body: PhysicsBody3D = null) -> void:
	var first := _npc_debris.size()
	super._spawn_cut_debris(gone_arrays, gone_cap, from, push, outer_materials, owner_body)
	for index in range(first, _npc_debris.size()):
		var node: Node = _npc_debris[index].get("node")
		if is_instance_valid(node):
			node.set_meta("lab_expire_ms28", Time.get_ticks_msec() + LAB_DEBRIS_LIFETIME_MS)
			_lab_debris_ignore_owner28(node)

func _throw_stump(kind: String, at: Vector3, direction: Vector3, speed: float) -> void:
	super._throw_stump(kind, at, direction, speed)
	if not _stumps.is_empty():
		var stump: Node3D = _stumps.back()
		stump.set_meta("lab_expire_ms28", Time.get_ticks_msec() + LAB_DEBRIS_LIFETIME_MS)
		# Blood uses parallel velocity/timer arrays. Keep rigid pieces exclusively
		# in _stumps so interleaved blood bursts cannot shift those indices.
		_npc_gore.erase(stump)

func _update_gore(delta: float) -> void:
	_lab_gore_updated = true
	super._update_gore(delta)

func _process(delta: float) -> void:
	_lab_gore_updated = false
	super._process(delta)
	if not _lab_gore_updated: _update_gore(delta)
	# Expiry also runs with bow/empty hands/death, outside melee's early returns.
	_lab_expire_debris(Time.get_ticks_msec())

func _lab_expire_debris(now: int) -> void:
	for index in range(_npc_debris.size() - 1, -1, -1):
		var node: Node = _npc_debris[index].get("node")
		if not is_instance_valid(node):
			_npc_debris.remove_at(index)
		elif now >= int(node.get_meta("lab_expire_ms28", now + LAB_DEBRIS_LIFETIME_MS)):
			node.queue_free()
			_npc_debris.remove_at(index)
	for index in range(_stumps.size() - 1, -1, -1):
		var node: Node3D = _stumps[index]
		if not is_instance_valid(node):
			_stumps.remove_at(index)
		elif now >= int(node.get_meta("lab_expire_ms28", now + LAB_DEBRIS_LIFETIME_MS)):
			_npc_gore.erase(node)
			node.queue_free()
			_stumps.remove_at(index)
	_stump_count = _stumps.size()

func lab_clear_debris() -> void:
	for entry: Dictionary in _npc_debris:
		var node: Node = entry.get("node")
		if is_instance_valid(node): node.queue_free()
	_npc_debris.clear()
	for node: Node3D in _stumps:
		if is_instance_valid(node): node.queue_free()
	_stumps.clear()

func _lab_debris_ignore_owner28(body: RigidBody3D) -> void:
	# Hit volumes are separate AnimatableBody nodes; excluding only CharacterBody
	# leaves regenerated head/limb volumes supporting the detached piece in air.
	if not is_instance_valid(_npc_body): return
	body.add_collision_exception_with(_npc_body)
	for hit: CollisionObject3D in _npc_body.find_children("*","CollisionObject3D",true,false):
		if hit.has_meta("sword_npc_part"): body.add_collision_exception_with(hit)

func _production_resolve_contact29(hit: Dictionary, points: PackedVector3Array, now: int, touched: Dictionary) -> void:
	super._resolve_contact(hit,points,now,touched)

func _production_update_city_npc29(delta: float) -> void:
	super._update_city_npc(delta)
