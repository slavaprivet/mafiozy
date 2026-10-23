extends RefCounted
## A lateral spear contact constrains the displayed steel/haft before the regular
## sweep runs. Tip-first entry and an existing puncture channel keep their owner.
const Puncture = preload("res://scripts/combat/puncture29.gd")
const Wound = preload("res://scripts/combat/local_wound28.gd")
const SAMPLE_SPACING := 0.045
const CONTACT_SKIN := 0.032
var _previous := Transform3D.IDENTITY
var _previous_player := Vector3.ZERO
var _identity := ""
var _ready := false
var _delta := 1.0 / 60.0
var _last_wound: Dictionary = {}
var contacts := 0
var shaft_contacts := 0
var blade_contacts := 0
var wounds := 0
var max_grip_error := 0.0
var max_support_error := 0.0
var unresolved := 0
var last_unresolved: Dictionary = {}
var _block: Dictionary = {}
var _safe_bones: Dictionary = {}
var safe_fallbacks := 0
var last_world_clear := true
var last_self_clear := true
var last_contact: Dictionary = {}
var trace: Array[Dictionary] = []

func set_delta(value: float) -> void:
	_delta = clampf(value, 0.001, 0.1)

func invalidate(_reason: String = "reset") -> void:
	_ready = false
	_identity = ""
	_last_wound.clear()
	_block.clear()
	_safe_bones.clear()

func _enabled(host: Node) -> bool:
	return str(host.get("_weapon_id")) == "spear" and not host.get("_sword_grounded") and not host.get("_unarmed") and host.get("_selected") and not host.get("_throwing") and not host.get("_spear_cast_pending31") and not bool(host.get("_world").get("preview_dead"))

func _remember(host: Node, weapon: Node3D) -> void:
	_previous = weapon.global_transform
	_previous_player = host.get("_player").global_position
	var rig: Skeleton3D = host.get("_rig")
	_safe_bones.clear()
	for side: StringName in [&"left", &"right"]:
		var arm: Dictionary = host.call("_arm_set",side)
		for key in ["clav","upper","fore","hand"]:
			_safe_bones[int(arm[key])] = rig.get_bone_pose(int(arm[key]))
	_ready = true

func constrain_pose(host: Node) -> Dictionary:
	if not _enabled(host):
		invalidate("inactive")
		return {}
	var weapon: Node3D = host.get("_sword")
	if not is_instance_valid(weapon): return {}
	var embedded: RefCounted = host.get("_embedded29")
	if embedded.active(host):
		invalidate("embedded")
		return {}
	var identity := "%s:%s" % [weapon.get_instance_id(), host.get("lab_resets")]
	if identity != _identity:
		invalidate("equipment")
		_identity = identity
	var current := weapon.global_transform
	var player: CharacterBody3D = host.get("_player")
	if not _ready or current.origin.distance_to(_previous.origin) > 0.4 or player.global_position.distance_to(_previous_player) > 0.4:
		_remember(host, weapon)
		_block.clear()
	var tip_local := Puncture.tip_local(host)
	var tip_step := current * tip_local - _previous * tip_local
	var holder_step := player.global_position - _previous_player
	var axial_holder := Puncture.axial_contact("spear", false, holder_step, current.basis.x) and current.basis.x.normalized().dot(_previous.basis.x.normalized()) > 0.999
	# Never promote a shaft ray to puncture. The existing foremost-tip skin sweep
	# owns a forward, aligned movement and all its depth/lifecycle constraints.
	_update_block(host, current)
	# A coarse front-leaf hitbox can precede actual skin. Walking axially with an
	# unchanged shaft orientation must still reach the exact tip/skin query even
	# when gait IK adds a small transverse tip displacement. An already blocked
	# wooden shaft does not get this exception.
	if axial_holder and not _block.is_empty() and float(_block.x) >= _blade_start(weapon): _block.clear()
	if _block.is_empty() and (axial_holder or Puncture.axial_contact("spear", false, tip_step, current.basis.x)):
		_remember(host, weapon)
		return {}
	var collision := _swept_body(host, current, tip_local.x)
	if collision.is_empty():
		_remember(host, weapon)
		return {}
	var motion: Vector3 = collision.motion
	var travel := motion.length()
	var fraction := maxf(0.0, float(collision.fraction) - CONTACT_SKIN / maxf(travel, 0.000001))
	var accepted := _previous.interpolate_with(current, fraction)
	var normal: Vector3 = collision.normal
	if collision.get("overlap", false):
		accepted.origin += normal * maxf(0.0, CONTACT_SKIN - normal.dot(accepted * Vector3(float(collision.sample_x), 0, 0) - Vector3(collision.position)))
	var collider: Node3D = collision.get("collider")
	if is_instance_valid(collider):
		_block = {"collider": weakref(collider), "point": collider.to_local(collision.position), "normal": collider.global_basis.inverse() * normal, "x": collision.sample_x, "part": collision.part}
	var axis := accepted.basis.x.normalized()
	var omega: Vector3 = host.get("_omega")
	var gradient := axis.cross(normal)
	var into := omega.dot(gradient)
	if into < 0.0 and gradient.length_squared() > 0.000001:
		# Remove incoming rotation, retaining tangential motion and only a small
		# bounded rebound. The accepted transform prevents positional tunnelling.
		omega -= gradient * (into / gradient.length_squared())
		omega += gradient.normalized() * minf(0.45, -into * 0.10)
	host.set("_omega", omega)
	_apply_pose(host, accepted, collision)
	contacts += 1
	var metal := float(collision.sample_x) >= _blade_start(weapon)
	if metal: blade_contacts += 1
	else: shaft_contacts += 1
	last_contact = {"spear_lateral": true, "metal": metal, "part": collision.part, "sample_x": collision.sample_x, "fraction": fraction, "requested_travel": travel, "rejected_travel": travel * (1.0 - fraction), "normal": normal, "position": collision.position, "local_wound": false}
	var accepted_point: Vector3 = weapon.global_transform * Vector3(float(collision.sample_x),0,0)
	last_contact["accepted_gap"] = normal.dot(accepted_point-Vector3(collision.position))
	last_contact["outward_correction"] = normal.dot(accepted_point-current*Vector3(float(collision.sample_x),0,0))
	last_contact["outward_rotation_speed"] = Vector3(host.get("_omega")).cross(weapon.global_basis.x*float(collision.sample_x)).dot(normal)
	if trace.size()<24: trace.append({"contact":last_contact.duplicate(),"tip_step":tip_step,"holder_step":holder_step,"axial_holder":axial_holder,"axis":current.basis.x,"previous_axis":_previous.basis.x})
	var now := Time.get_ticks_msec()
	if metal and travel / _delta > 0.12 and now - int(_last_wound.get(collision.part, -10000)) >= 220:
		_last_wound[collision.part] = now
		var wound := Wound.apply(host, collision.part, collision.position, motion / _delta, axis, travel / _delta)
		last_contact["wound_result"] = wound
		if wound.get("ok", false):
			last_contact.local_wound = true
			if wound.get("created", false):
				wounds += 1
				host.set("clay_local_wounds28", int(host.get("clay_local_wounds28")) + 1)
	host.set("clay_last_contact28", last_contact.duplicate(true))
	# The base sweep must compare against the actual accepted pose on the next
	# frame, never against the rejected through-body candidate.
	host.set("_prev_points", PackedVector3Array())
	_remember(host, weapon)
	return last_contact

func _blade_start(weapon: Node3D) -> float:
	# The authored leaf is the front PrismMesh, distinct from wooden haft and
	# metal collar/butt. Read its transformed AABB, not an arbitrary tip fraction.
	for node: Node in weapon.get_children():
		if node is MeshInstance3D and node.mesh is PrismMesh:
			return (node.transform * node.mesh.get_aabb()).position.x
	return 1.54

func _swept_body(host: Node, current: Transform3D, front: float) -> Dictionary:
	var player: CharacterBody3D = host.get("_player")
	var target: Node3D = host.get("_npc_body")
	if not is_instance_valid(target) or current.origin.distance_to(target.global_position) > front + 2.0: return {}
	var excluded: Array[RID] = [player.get_rid(), target.get_rid()]
	var corpse: CollisionObject3D = host.get("_npc_corpse31")
	if is_instance_valid(corpse): excluded.append(corpse.get_rid())
	var space := player.get_world_3d().direct_space_state
	var best: Dictionary = {}
	if not _block.is_empty():
		var collider: Node3D = _block.collider.get_ref()
		var point: Vector3 = collider.to_global(_block.point)
		var normal: Vector3 = (collider.global_basis * Vector3(_block.normal)).normalized()
		var sample := Vector3(float(_block.x), 0, 0)
		var before := _previous * sample
		var after := current * sample
		var distance := normal.dot(after - point)
		if distance < CONTACT_SKIN:
			var old_distance := normal.dot(before - point)
			var fraction := clampf((old_distance - CONTACT_SKIN) / maxf(0.000001, old_distance - distance), 0.0, 1.0)
			best = {"fraction": fraction, "position": point, "normal": normal, "part": _block.part, "motion": after - before, "sample_x": _block.x, "collider": collider, "overlap": old_distance < CONTACT_SKIN}
	var count := int(ceil((front + 0.30) / SAMPLE_SPACING))
	var sphere := SphereShape3D.new()
	sphere.radius = 0.026
	var blade_start:=_blade_start(host.get("_sword"))
	for index in count + 1:
		var x := lerpf(-0.30, front, float(index) / count)
		var sample := Vector3(x, 0, 0)
		var from := _previous * sample
		var to := current * sample
		# Detect initial/stationary overlap too. Obtain its exit surface by a ray
		# from outside the hitbox; never invent a zero normal from an inside ray.
		var overlap := PhysicsShapeQueryParameters3D.new()
		overlap.shape = sphere
		overlap.transform = Transform3D(Basis.IDENTITY, from)
		overlap.collision_mask = 1
		overlap.exclude = excluded
		# The front leaf can be inside the coarse limb hitbox while still outside
		# posed skin. A stationary front overlap must not tilt it out of a genuine
		# axial tip trajectory between two draw/physics callbacks. Its lateral
		# crossing is still swept below; existing side contact has its plane above.
		var overlaps: Array=space.intersect_shape(overlap,4) if x<blade_start else []
		for row: Dictionary in overlaps:
			var body: Node3D = row.get("collider")
			if not is_instance_valid(body) or not body.has_meta("sword_npc_part"): continue
			var part := str(body.get_meta("sword_npc_part", ""))
			if part.is_empty() or host.get("_npc_severed").has(part): continue
			var outward := (from - body.global_position).normalized()
			if outward.length_squared() < 0.5: outward = -current.basis.z
			var exit_query := PhysicsRayQueryParameters3D.create(from + outward * 0.8, from - outward * 0.04, 1, excluded)
			var surface := space.intersect_ray(exit_query)
			if surface.is_empty() or surface.get("collider") != body: continue
			if to.distance_squared_to(from) > 0.00000001 and (to-from).dot(Vector3(surface.normal)) > 0.0: continue
			best = {"fraction": 0.0, "position": surface.position, "normal": surface.normal, "part": part, "motion": to-from, "sample_x": x, "collider": body, "overlap": true}
			break
		if from.distance_squared_to(to) < 0.00000001: continue
		var query := PhysicsRayQueryParameters3D.create(from, to, 1, excluded)
		query.hit_from_inside = false
		var hit := space.intersect_ray(query)
		if hit.is_empty(): continue
		var collider: Object = hit.get("collider")
		if not is_instance_valid(collider) or not collider.has_meta("sword_npc_part"): continue
		var part := str(collider.get_meta("sword_npc_part", ""))
		if part.is_empty() or host.get("_npc_severed").has(part): continue
		var normal: Vector3 = hit.normal
		if normal.length_squared() < 0.5: continue
		var fraction := from.distance_to(hit.position) / from.distance_to(to)
		if best.is_empty() or fraction < float(best.fraction):
			best = {"fraction": fraction, "position": hit.position, "normal": normal.normalized(), "part": part, "motion": to - from, "sample_x": x, "collider": collider}
	return best

func _update_block(host: Node, current: Transform3D) -> void:
	if _block.is_empty(): return
	var collider: Node3D = _block.collider.get_ref()
	if not is_instance_valid(collider) or host.get("_npc_severed").has(_block.part):
		_block.clear()
		return
	var point: Vector3 = collider.to_global(_block.point)
	var normal: Vector3 = (collider.global_basis * Vector3(_block.normal)).normalized()
	var sample := current * Vector3(float(_block.x), 0, 0)
	var gap := normal.dot(sample - point)
	var tangent := sample - point - normal * gap
	if gap > 0.07 or tangent.length() > 0.30: _block.clear()

func _apply_pose(host: Node, accepted: Transform3D, contact: Dictionary) -> void:
	var axis := accepted.basis.x.normalized()
	var rig: Skeleton3D = host.get("_rig")
	var arm: Dictionary = host.call("_arm_set", &"right")
	var origin := accepted.origin
	var normal: Vector3 = contact.normal
	var actual_grip := Vector3.ZERO
	var local_axis := Vector3.ZERO
	var clear := false
	for attempt in 24:
		if attempt==12:
			origin=_previous.origin
			axis=_previous.basis.x.normalized()
		var grip := origin - axis * float(host.call("_grip_origin_offset"))
		var local_grip := rig.global_transform.affine_inverse() * grip
		local_axis = (rig.global_basis.inverse() * axis).normalized()
		host.call("_pose_arm_ik", arm.clav, arm.upper, arm.fore, arm.hand, arm.rest_upper, arm.rest_fore, arm.rest_hand, arm.offset, local_grip, local_axis, 1.0, true, arm.pole)
		rig.force_update_all_bone_transforms()
		actual_grip = host.call("_palm_position", &"right")
		origin = actual_grip + axis * float(host.call("_grip_origin_offset"))
		var clearance := normal.dot(origin + axis * float(contact.sample_x) - Vector3(contact.position))
		last_self_clear=bool(host.call("_self_blade_clear_at51", axis, origin))
		last_world_clear=_world_clear(host,axis,origin)
		clear = clearance >= CONTACT_SKIN - 0.002 and last_self_clear and last_world_clear
		if clear: break
		# If the exact impact pose is unreachable, slide the anchor outward and
		# gradually open the angle. Always attach steel to the achieved palm.
		if attempt !=11 and attempt<23:
			origin += normal * maxf(0.0, CONTACT_SKIN - clearance)
			if attempt > 1: axis = (axis + normal * 0.06).normalized()
	var support := rig.global_transform.affine_inverse() * actual_grip - local_axis * float(host.get("_two_hand_offset_rig"))
	host.call("_pose_support", &"left", support)
	rig.force_update_all_bone_transforms()
	max_grip_error = maxf(max_grip_error, Vector3(host.call("_palm_position", &"right")).distance_to(actual_grip))
	max_support_error = maxf(max_support_error, Vector3(host.call("_palm_position", &"left")).distance_to(rig.global_transform * support))
	if not clear:
		unresolved += 1
		last_unresolved = {"self_clear":host.call("_self_blade_clear_at51",axis,origin),"clearance":normal.dot(origin+axis*float(contact.sample_x)-Vector3(contact.position)),"contact":contact.duplicate(),"origin":origin,"axis":axis}
		# Restore the last accepted arm pose instead of publishing a failed IK
		# candidate. Steel stays attached to the actual palm of those safe bones.
		for bone: int in _safe_bones:rig.set_bone_pose(bone,_safe_bones[bone])
		rig.force_update_all_bone_transforms()
		axis=_previous.basis.x.normalized()
		origin=Vector3(host.call("_palm_position",&"right"))+axis*float(host.call("_grip_origin_offset"))
		safe_fallbacks+=1
	host.set("_dir", axis)
	host.set("_sword_origin", origin)
	host.call("_place_sword", origin, axis)

func _world_clear(host: Node,axis: Vector3,origin: Vector3)->bool:
	var player:CharacterBody3D=host.get("_player")
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.028;capsule.height=1.84
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=capsule
	query.transform=host.call("_blade_shape_transform",axis,origin+axis*.92)
	query.collision_mask=1;query.exclude=[player.get_rid()]
	var target:Node=host.get("_npc_body")
	var rig:Node=host.get("_npc_rig")
	var corpse:Node=host.get("_npc_corpse31")
	for row:Dictionary in player.get_world_3d().direct_space_state.intersect_shape(query,32):
		var body:Node=row.get("collider")
		if body==target or body==corpse or player.is_ancestor_of(body) or (is_instance_valid(rig) and rig.is_ancestor_of(body)):continue
		return false
	return true

func status() -> Dictionary:
	return {"contacts": contacts, "shaft_contacts": shaft_contacts, "blade_contacts": blade_contacts, "wounds": wounds, "max_grip_error": max_grip_error, "max_support_error": max_support_error, "unresolved": unresolved,"safe_fallbacks":safe_fallbacks,"self_clear":last_self_clear,"world_clear":last_world_clear, "last_unresolved":last_unresolved,"last_contact": last_contact,"trace":trace}
