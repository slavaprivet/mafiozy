extends "res://scripts/arena27_target.gd"
const ClayAnatomy28 = preload("res://scripts/combat/cut_anatomy28.gd")
const Puncture29 = preload("res://scripts/combat/puncture29.gd")
const PunctureWound29 = preload("res://scripts/combat/local_wound28.gd")
## Laboratory sharp contact: a light moving stroke opens a local wound; a
## sufficiently fast transverse cutting stroke severs the actual posed surface.
## Production damage/armour/velocity gates remain inherited outside this subclass.
var _contact_reaction29 = preload("res://scripts/combat/contact_reaction29.gd").new()
var clay_cuts := 0
var clay_last_async28: Dictionary = {}
var clay_commit_profile28: Dictionary = {}
var _async_cut28 = preload("res://scripts/combat/async_cut28.gd").new()
var _resistance28 = preload("res://scripts/combat/blade_resistance28.gd").new()
var clay_attempts: Array[Dictionary] = []
var _clay_plane := Plane()
var _clay_keep_point := Vector3.ZERO
var _clay_cap_points: Array[Vector3] = []
var _clay_branches: Dictionary = {}
var _clay_blood_allowed := false
var clay_last_geometry: Dictionary = {}
var clay_last_anatomy: Dictionary = {}
var _clay_cap_sites: Array[Dictionary] = []
var _clay_wounds: Array[Dictionary] = []
var _clay_emit_accum := 0.0
const CLAY_SEVER_SPEED28 := 3.2
const CLAY_SEVER_TRAVEL28 := 0.04
const CLAY_SEVER_EDGE28 := 0.55
const CLAY_CONTACT_GAP28 := 150
var _clay_contact_history28: Dictionary = {}
var _clay_local_wound_script28: GDScript
var clay_local_wounds28 := 0
var clay_last_contact28: Dictionary = {}
var _clay_idle_sweep28 := false
var _clay_idle_points28 := PackedVector3Array()
var _clay_idle_identity28 := ""
var _clay_idle_frame28 := -1
var _clay_idle_player28 := Vector3.ZERO
var clay_idle_sweeps28 := 0
var _puncture_tip_history29: Array[Dictionary] = []
var _puncture_previous_tip29 := Vector3.INF
var _puncture_tip_frame29 := -1
var _puncture_player29 := Vector3.ZERO
var _puncture_prepared_generation30 := -1

func _clay_passive_contact28() -> bool:
	if _shield_guard_active29(): return false
	return _ready and _active() and not _held and not _unarmed and not _sword_grounded and _weapon_id in ["sword","spear"] and is_instance_valid(_sword) and _sword.visible and is_instance_valid(_player)

func _clay_reset_passive28() -> void:
	_clay_idle_points28=PackedVector3Array()
	_clay_idle_identity28=""
	_clay_idle_frame28=-1

func _clay_invalidate_motion28() -> void:
	_clay_reset_passive28()
	_puncture_tip_history29.clear()
	_puncture_previous_tip29 = Vector3.INF
	_puncture_tip_frame29 = -1
	if has_meta("puncture29_channel"):
		var channel: Dictionary = get_meta("puncture29_channel")
		channel.valid = false
		channel.active = false
	_prev_points=PackedVector3Array()
	_clay_contact_history28.clear()
	_resistance28.clear("equipment")

func set_weapon(id: String) -> bool:
	var previous:=_weapon_id
	var ok:=super.set_weapon(id)
	if _weapon_id!=previous: _clay_invalidate_motion28()
	return ok

func try_pickup_sword(allow_inactive: bool = false) -> bool:
	var ok:=super.try_pickup_sword(allow_inactive)
	if ok: _clay_invalidate_motion28()
	return ok

func _clay_sweep_carried28() -> void:
	if not _clay_passive_contact28():
		_clay_reset_passive28()
		return
	var frame:=Engine.get_physics_frames()
	if frame==_clay_idle_frame28:return
	var identity:="%s:%s:%s"%[_weapon_id,_sword.get_instance_id(),lab_resets]
	var points:=PackedVector3Array()
	for i in SWEEP_SEGMENTS+1:
		points.append(_sword_origin+_dir*(0.06+_weapon_length*float(i)/SWEEP_SEGMENTS))
	var step_frames:=frame-_clay_idle_frame28
	var delta:=float(step_frames)/float(Engine.physics_ticks_per_second)
	var continuous:=identity==_clay_idle_identity28 and step_frames>0 and step_frames<=3 and _clay_idle_points28.size()==points.size()
	if continuous:
		# Equip/reset/warp trajectories do not represent travel of an existing blade.
		continuous=_player.global_position.distance_to(_clay_idle_player28)<=maxf(0.4,delta*16.0)
		for i in points.size():
			if points[i].distance_to(_clay_idle_points28[i])>maxf(0.4,delta*20.0):continuous=false
	if continuous:
		_prev_points=_clay_idle_points28
		_clay_idle_sweep28=true
		_sweep(delta)
		_clay_idle_sweep28=false
		clay_idle_sweeps28+=1
	_clay_idle_points28=points
	_clay_idle_identity28=identity
	_clay_idle_frame28=frame
	_clay_idle_player28=_player.global_position


func _puncture_permission29(_part: String, _entry: Vector3, _axis: Vector3, _speed: float, _normal: Vector3 = Vector3.ZERO) -> bool:
	# Production adapters can apply armour to the exact skin crossing.
	return true

func _puncture_accepted29(_part: String, _entry: Vector3, _axis: Vector3, _speed: float, _normal: Vector3 = Vector3.ZERO) -> void:
	pass

func _puncture_path_blocked29(from: Vector3, tip: Vector3, entry: Vector3) -> bool:
	# An independent foremost-tip probe must respect earlier steel/world contact.
	var fraction:=clampf(from.distance_to(entry)/maxf(from.distance_to(tip),.000001),0.0,1.0)
	if is_instance_valid(_npc_sword) and _npc_sword.visible:
		var steel_a:=_npc_sword.global_position
		var steel_b:=steel_a+_npc_sword.global_basis.x.normalized()*(.06+float(WEAPONS["sword"]["length"]))
		if _segment_distance(from,entry,steel_a,steel_b)<=BLADE_TOUCH_RADIUS:return true
		if _prev_points.size()==SWEEP_SEGMENTS+1:
			for index in _prev_points.size():
				var next:=_sword_origin+_dir*(.06+_weapon_length*float(index)/SWEEP_SEGMENTS)
				if _segment_distance(_prev_points[index],_prev_points[index].lerp(next,fraction),steel_a,steel_b)<=BLADE_TOUCH_RADIUS:return true
	var excluded:Array[RID]=[_player.get_rid()]
	if is_instance_valid(_npc_body):excluded.append(_npc_body.get_rid())
	if is_instance_valid(_npc_corpse31):excluded.append(_npc_corpse31.get_rid())
	var space:=_player.get_world_3d().direct_space_state
	for attempt in 24:
		var query:=PhysicsRayQueryParameters3D.create(from,entry,1,excluded)
		query.hit_from_inside=true
		var hit:=space.intersect_ray(query)
		if hit.is_empty():return false
		var collider:Object=hit.get("collider")
		if is_instance_valid(collider) and collider is CollisionObject3D and collider.has_meta("sword_npc_part") and _npc_rig.is_ancestor_of(collider):
			excluded.append(collider.get_rid())
			continue
		return true
	return true

func _puncture_near_actor30(from: Vector3, to: Vector3) -> bool:
	if not is_instance_valid(_npc_rig): return false
	# A cheap conservative articulated bound precedes any posed-skin work.
	# It covers every limb, not just the shaft collider's reported body part.
	for index in _npc_rig.get_bone_count():
		var center:Vector3=_npc_rig.global_transform*_npc_rig.get_bone_global_pose(index).origin
		if center.distance_squared_to(Geometry3D.get_closest_point_to_segment(center,from,to))<.45*.45:return true
	return false

func _sweep(delta: float) -> void:
	if not _shield_guard_active29() and _weapon_id in ["spear","sword"] and is_instance_valid(_sword):
		var tip := Puncture29.tip_world(self)
		var frame := Engine.get_physics_frames()
		var step_frames := frame-_puncture_tip_frame29
		var continuous := _puncture_previous_tip29.is_finite() and step_frames>=0 and step_frames<=3 and tip.distance_to(_puncture_previous_tip29)<=0.40 and _player.global_position.distance_to(_puncture_player29)<=0.40
		if continuous and (_held or _clay_idle_sweep28) and not _async_cut28.busy():
			var step:=tip-_puncture_previous_tip29
			if Puncture29.axial_contact(_weapon_id,_weapon_crush,step,_dir) and _puncture_near_actor30(_puncture_previous_tip29,tip):
				var begun:=Time.get_ticks_usec()
				var wound:=PunctureWound29.apply_puncture29(self,"",tip,_dir,tip,_puncture_previous_tip29,delta)
				clay_last_contact28={"puncture":true,"actual_tip":true,"result":wound,"query_usec":Time.get_ticks_usec()-begun}
				if wound.get("ok",false) and wound.get("created",false):
					clay_local_wounds28+=1
					lab_last_hit=clay_last_contact28.duplicate(true)
					lab_events.append(lab_last_hit.duplicate(true))
					if lab_events.size()>200:lab_events.pop_front()
		_puncture_previous_tip29=tip;_puncture_tip_frame29=frame;_puncture_player29=_player.global_position
	super._sweep(delta)

func _resolve_contact(hit: Dictionary, points: PackedVector3Array, now: int, touched: Dictionary) -> void:
	if _shield_guard_active29(): return
	_contact_reaction29.observe(self,hit)
	var collider: Object = hit.get("collider")
	if not is_instance_valid(collider) or not collider.has_meta("sword_npc_part") or _weapon_crush:
		super._resolve_contact(hit, points, now, touched)
		return
	if not _held and not _clay_idle_sweep28: return
	var motion: Vector3 = hit.get("_velocity", Vector3.ZERO)
	if motion.length_squared() <= 0.00000001: return
	var part := str(collider.get_meta("sword_npc_part", ""))
	if part.is_empty() or _npc_severed.has(part): return
	var axis := _dir.normalized()
	var axial_tip := Puncture29.axial_contact(_weapon_id,_weapon_crush,motion,axis)
	if _weapon_id == "spear" or axial_tip:
		# A shaft travelling lengthwise cannot become a transverse sever. The
		# actual tip must have reached posed skin before a local channel is opened.
		if not axial_tip:
			# The spear shaft still meets tissue resistance; only its front tip pierces.
			_resistance28.observe(self,hit,points,now)
			return
		if points.is_empty() or _async_cut28.busy(): return
		if _prev_points.size() != points.size(): return
		# The actual foremost point owns punctures above. A shaft collider must not
		# rescan old tip history or create a second hole at its own hit position.
		PunctureWound29.advance_active29(self,Puncture29.tip_world(self))
		return
	var transverse := motion - axis * motion.dot(axis)
	var cutting_speed := transverse.length()
	var alignment := absf(motion.normalized().dot(_edge_axis(axis)))
	var sample := int(hit.get("_index",-1))
	var step := Vector3.ZERO
	if sample >= 0 and sample < points.size() and sample < _prev_points.size():
		step = points[sample] - _prev_points[sample]
	var travel := (step-axis*step.dot(axis)).length()
	var history: Dictionary = _clay_contact_history28.get(part,{})
	if history.is_empty() or now-int(history.time)>CLAY_CONTACT_GAP28 or int(history.generation)!=lab_resets or str(history.get("weapon",""))!=_weapon_id or motion.dot(Vector3(history.motion))<=0.0:
		history={"travel":0.0,"last_wound":-10000,"wound_point":Vector3.INF}
	history.travel = float(history.travel)+travel
	history.time=now;history.generation=lab_resets;history.motion=motion;history.weapon=_weapon_id
	var strong := cutting_speed>=CLAY_SEVER_SPEED28 and alignment>=CLAY_SEVER_EDGE28 and float(history.travel)>=CLAY_SEVER_TRAVEL28
	clay_last_contact28={"part":part,"speed":motion.length(),"cutting_speed":cutting_speed,"edge_alignment":alignment,"travel":history.travel,"strong":strong,"world_point":str(hit.position)}
	_clay_contact_history28[part]=history
	_resistance28.observe(self,hit,points,now)
	if _async_cut28.busy(): return
	if strong:
		if _clay_queue_slice28(part,hit.position,motion,motion.length()):
			_clay_contact_history28.erase(part)
			return
	# A slow blade can progressively open finite wounds, but accumulating time
	# or damage never turns a stationary/light touch into a full sever.
	if now-int(history.last_wound)<150 and Vector3(history.wound_point).distance_to(hit.position)<0.04:return
	if _clay_local_wound_script28==null:
		_clay_local_wound_script28=load("res://scripts/combat/local_wound28.gd")
	if _clay_local_wound_script28==null:return
	var wound: Dictionary=_clay_local_wound_script28.apply(self,part,hit.position,motion,axis,motion.length())
	if not wound.get("ok",false):return
	history.last_wound=now;history.wound_point=hit.position
	_clay_contact_history28[part]=history
	clay_local_wounds28+=1
	if wound.has("world_point") and not wound.get("handles_blood",false):_clay_wound_burst28(wound.world_point,-motion,4)
	clay_last_contact28["local_wound"]=true
	lab_last_hit=clay_last_contact28.duplicate(true)
	lab_events.append(lab_last_hit.duplicate(true))
	if lab_events.size()>200:lab_events.pop_front()

func _clay_prepare_cut28(part: String, point: Vector3, motion: Vector3, speed: float) -> Dictionary:
	if not is_instance_valid(_npc_rig): return {}
	# A swept blade spans blade axis and travel. Their CROSS product is the
	# cutting plane normal; using travel as normal cuts perpendicular to the pass.
	var normal := _dir.cross(motion)
	if normal.length_squared() <= 0.00000001:
		# An axial push still has a blade plane, defined by its visible cutting edge.
		normal = _dir.cross(_edge_axis(_dir))
	if normal.length_squared() <= 0.00000001: return {}
	normal = normal.normalized()
	var base := part.trim_suffix("_l").trim_suffix("_r")
	var scope := "neck" if base == "head" else part
	if base in ["chest", "pelvis"]: scope = "_clay_torso"
	# Include the complete connected limb skin so blended weights at elbows
	# and knees do not leave the cut loop open. The plane stays at the impact.
	if base in ["forearm","hand"]: scope = "upperarm" + ("_l" if part.ends_with("_l") else "_r")
	if base in ["shin","foot"]: scope = "thigh" + ("_l" if part.ends_with("_l") else "_r")
	var keep_bone := _npc_rig.find_bone("pelvis" if base in ["head", "chest", "pelvis"] else part)
	var keep := point - normal * 0.1
	if keep_bone >= 0:
		keep = _npc_rig.global_transform * _npc_rig.get_bone_global_pose(keep_bone).origin
		if absf(normal.dot(keep-point)) < 0.0001:
			var parent := _npc_rig.get_bone_parent(keep_bone)
			if parent >= 0: keep = _npc_rig.global_transform * _npc_rig.get_bone_global_pose(parent).origin
		if absf(normal.dot(keep-point)) < 0.0001: keep = point - normal * 0.1
	_clay_plane = Plane(normal, normal.dot(point))
	_clay_keep_point = keep
	_clay_cap_points.clear()
	_clay_cap_sites.clear()
	_clay_branches.clear()
	if scope == "_clay_torso": _clay_route_branches()
	var head_gone: bool = base == "head" or bool(_clay_branches.get("neck", false))
	return {"part":part,"point":point,"motion":motion,"speed":speed,"base":base,"scope":scope,"keep":keep,"head_gone":head_gone,"plane":_clay_plane}

func _clay_slice(part: String, point: Vector3, motion: Vector3, speed: float) -> bool:
	var context := _clay_prepare_cut28(part,point,motion,speed)
	if context.is_empty(): return false
	var before := _npc_debris.size()
	var ok := npc_cut_body(_clay_plane,context.keep,context.scope,context.head_gone)
	return _clay_complete_cut28(context,before,ok)

func _clay_queue_slice28(part: String, point: Vector3, motion: Vector3, speed: float) -> bool:
	if _shield_guard_active29(): return false
	if _async_cut28.busy(): return false
	var context := _clay_prepare_cut28(part,point,motion,speed)
	return not context.is_empty() and _async_cut28.begin(self,context)

func _clay_async_resolved28(success: bool) -> void:
	_resistance28.resolved(self,success)

func lab_spawn() -> bool:
	var ok := super.lab_spawn()
	if ok: _async_cut28.warm(self)
	return ok

func _process(delta: float) -> void:
	_sync_shield_guard29()
	super._process(delta)
	_sync_shield_guard29()
	if _ready and is_instance_valid(_npc_rig) and _puncture_prepared_generation30!=lab_resets:
		Puncture29.prepare(self)
		_puncture_prepared_generation30=lab_resets
	_clay_sweep_carried28()
	_async_cut28.poll(self)

func _exit_tree() -> void:
	_async_cut28.dispose()
	super._exit_tree()

func set_selected(value: bool) -> void:
	if value!=_selected:
		_async_cut28.cancel("selection_changed")
		_clay_invalidate_motion28()
	super.set_selected(value)

func drop_sword_to_ground() -> bool:
	var dropped := super.drop_sword_to_ground()
	if dropped:
		_async_cut28.cancel("weapon_dropped")
		_clay_invalidate_motion28()
	return dropped

func _steer(delta: float) -> void:
	var prior_dir := _dir
	var prior_omega := _omega
	super._steer(delta)
	_resistance28.steer(self,delta,prior_dir,prior_omega)

func _clay_complete_cut28(context: Dictionary, before: int, ok: bool, predecorated: bool = false) -> bool:
	var part: String=context.part
	var point: Vector3=context.point
	var motion: Vector3=context.motion
	var speed: float=context.speed
	var base: String=context.base
	var scope: String=context.scope
	var head_gone: bool=context.head_gone
	var normal: Vector3=context.plane.normal
	var finish_phase:=Time.get_ticks_usec()
	clay_commit_profile28={}
	if ok:
		_clay_join_layers(before)
		if not predecorated: clay_last_anatomy = ClayAnatomy28.decorate(self, _clay_plane, before)
		# Anatomy only rebuilds the cap UV/material arrays. Refresh CURRENT sites;
		# wounds from earlier removed caps must retain their obsolete resource guard.
		for site: Dictionary in _clay_cap_sites:
			var mesh: MeshInstance3D = site.mesh.get_ref()
			if is_instance_valid(mesh) and mesh.mesh != null: site.kept_mesh = weakref(mesh.mesh)
		_clay_register_wounds(before, normal)
	clay_last_geometry = {"branches":_clay_branches.duplicate(), "cap_points":_clay_cap_points.size(), "rigid_pieces":_npc_debris.size()-before}
	var event := {"clay":true,"ok":ok,"part":part,"speed":speed,"damage":0.0,"contact":str(point),"plane_normal":str(normal),"plane_d":normal.dot(point),"scope":scope,"debris_added":_npc_debris.size()-before,"fixed_target":lab_fixed,"time_ms":Time.get_ticks_msec()}
	clay_attempts.append(event.duplicate(true))
	if clay_attempts.size()>100: clay_attempts.pop_front()
	if not ok:
		if _lab_trace_enabled28: print("CLAY27_REFUSED ",JSON.stringify(event))
		return false
	clay_commit_profile28["register_usec"]=Time.get_ticks_usec()-finish_phase;finish_phase=Time.get_ticks_usec()
	clay_cuts += 1
	_npc_mesh_cut_parts39[part] = true
	if head_gone:
		_npc_head_mesh_cut31 = true
		# Head visuals now belong to detached debris, not to the live armour
		# controller. It must not restore visibility through freed mesh keys.
		if is_instance_valid(_npc_armor_visual31):
			var hidden: Dictionary = _npc_armor_visual31.get("_hidden_headwear")
			hidden.clear()
	for branch: String in _clay_branches:
		if not _clay_branches[branch]: continue
		var lost := "head" if branch == "neck" else branch
		_npc_mesh_cut_parts39[lost] = true
		_npc_severed[lost] = true
		_disable_severed_npc_hitboxes31(lost)
	_npc_severed[part] = true
	_disable_severed_npc_hitboxes31(part)
	if is_instance_valid(_npc_armor_visual31): _npc_armor_visual31.on_severed(part,true)
	if base in ["head","chest","pelvis"]: _npc_dead = true
	lab_last_hit = event.duplicate(true)
	lab_last_hit["sever"] = _npc_severed.keys()
	lab_events.append(lab_last_hit.duplicate(true))
	if lab_events.size()>200: lab_events.pop_front()
	clay_commit_profile28["flags_usec"]=Time.get_ticks_usec()-finish_phase;finish_phase=Time.get_ticks_usec()
	# Only an actual cap can emit blood. Collider contact alone is not a wound.
	_clay_blood_allowed = true
	for cap_point: Vector3 in _clay_cap_points:
		_spray_blood(cap_point, motion, 3)
	_clay_blood_allowed = false
	clay_commit_profile28["blood_usec"]=Time.get_ticks_usec()-finish_phase
	if _lab_trace_enabled28: print("CLAY27_CUT ",JSON.stringify(lab_last_hit))
	return true

# Skeleton attachment connectivity is independent of the pose of distal vertices.
# The torso owns neck, both shoulder chains and both hip chains as whole branches.
func _clay_route_branches() -> void:
	var keep_front := _clay_plane.distance_to(_clay_keep_point) >= 0.0
	for branch: String in ["neck", "upperarm_l", "upperarm_r", "thigh_l", "thigh_r"]:
		var bone := _npc_rig.find_bone(branch)
		if bone < 0: continue
		var attachment := _npc_rig.global_transform * _npc_rig.get_bone_global_pose(bone).origin
		_clay_branches[branch] = (_clay_plane.distance_to(attachment) >= 0.0) != keep_front

func _npc_limb_bind_ids(mesh_node: MeshInstance3D, part_key: String, target_rig: Skeleton3D = null) -> Dictionary:
	if part_key != "_clay_torso": return super._npc_limb_bind_ids(mesh_node, part_key, target_rig)
	if mesh_node.skin == null: return {}
	var all_binds: Dictionary = {}
	for index: int in mesh_node.skin.get_bind_count(): all_binds[index] = true
	var kept: Dictionary = {}
	var gone: Dictionary = {}
	for branch: String in _clay_branches:
		var ids := super._npc_limb_bind_ids(mesh_node, branch, target_rig)
		if _clay_branches[branch]: gone.merge(ids)
		else: kept.merge(ids)
	all_binds["_clay_keep"] = kept
	all_binds["_clay_gone"] = gone
	if "_FABRIC" in str(mesh_node.name):
		var chest := _npc_rig.find_bone("chest")
		var centre := _npc_rig.global_transform * _npc_rig.get_bone_global_pose(chest).origin
		all_binds["_clay_body_centre"] = mesh_node.to_local(_clay_plane.project(centre))
	return all_binds

func _spawn_cut_debris(gone_arrays: Array, gone_cap: Array, from: MeshInstance3D, push: Vector3, outer_materials: Array[Material] = [], owner_body: PhysicsBody3D = null) -> void:
	if not gone_cap.is_empty():
		var vertices: PackedVector3Array = gone_cap[Mesh.ARRAY_VERTEX]
		# Use a real cap vertex; an average across disconnected contours could lie
		# in empty space between the body and a sleeve.
		if not vertices.is_empty():
			var world_point := from.to_global(vertices[0])
			_clay_cap_points.append(world_point)
			var binds := _cut_skin_transforms39(from)
			var rest_cap := _cut_skin_arrays39(gone_cap, binds, true)
			var bones: PackedInt32Array = rest_cap[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = rest_cap[Mesh.ARRAY_WEIGHTS]
			_clay_cap_sites.append({"mesh":weakref(from), "kept_mesh":weakref(from.mesh), "rest":rest_cap[Mesh.ARRAY_VERTEX][0],
				"bones":bones.slice(0,4), "weights":weights.slice(0,4), "world":world_point})
	var first := _npc_debris.size()
	super._spawn_cut_debris(gone_arrays, gone_cap, from, push, outer_materials, owner_body)
	for index: int in range(first, _npc_debris.size()):
		var visual: MeshInstance3D = _npc_debris[index].visual
		visual.set_meta("cut_source_mesh28", str(from.name))
		visual.set_meta("cut_source_visible28", from.is_visible_in_tree())

func _clay_join_layers(first: int) -> void:
	if first >= _npc_debris.size(): return
	var body: RigidBody3D = _npc_debris[first].node
	for index: int in range(_npc_debris.size()-1, first, -1):
		var other: RigidBody3D = _npc_debris[index].node
		for child: Node in other.get_children():
			if child is Node3D: child.reparent(body, true)
		body.mass += other.mass
		_npc_debris.remove_at(index)
		other.queue_free()
	body.name = "ClayConnectedCut"

func _spray_blood(at: Vector3, direction: Vector3, count: int) -> void:
	if not _clay_blood_allowed: return
	var first := _npc_gore.size()
	super._spray_blood(at, direction, count)
	# The inherited visual spread jitters the spawn by up to 9 cm. Start ON the
	# actual cap instead; the existing velocity spread disperses drops afterwards.
	for index: int in range(first, _npc_gore.size()):
		if is_instance_valid(_npc_gore[index]): _npc_gore[index].global_position = at

func _clay_register_wounds(first: int, normal: Vector3) -> void:
	if first >= _npc_debris.size(): return
	var body: RigidBody3D = _npc_debris[first].node
	for site: Dictionary in _clay_cap_sites:
		var wound := site.duplicate()
		wound["body"] = weakref(body)
		wound["body_point"] = body.to_local(site.world)
		wound["body_normal"] = body.global_basis.inverse() * normal
		wound["normal"] = normal
		wound["generation"] = lab_resets
		wound["expires"] = Time.get_ticks_msec()+3000
		_clay_wounds.append(wound)

func _clay_retained_wound(wound: Dictionary) -> Vector3:
	var mesh: MeshInstance3D = wound.mesh.get_ref()
	if not is_instance_valid(mesh) or mesh.mesh == null or mesh.mesh != wound.kept_mesh.get_ref(): return Vector3.INF
	var binds := _cut_skin_transforms39(mesh)
	var point := Vector3.ZERO
	var total := 0.0
	for slot: int in wound.bones.size():
		var index: int = wound.bones[slot]
		var weight: float = wound.weights[slot]
		if weight <= 0.0 or index < 0 or index >= binds.size(): continue
		point += (binds[index] * Vector3(wound.rest)) * weight
		total += weight
	return mesh.to_global(point) if total > 0.99 else Vector3.INF

func _update_npc_bleed(delta: float) -> void:
	# The generic damage timer has no authority to create a wound in clay mode.
	_clay_emit_accum += delta
	var emit := _clay_emit_accum >= 0.065
	if emit: _clay_emit_accum = 0.0
	for index: int in range(_clay_wounds.size()-1,-1,-1):
		var wound: Dictionary = _clay_wounds[index]
		var body: RigidBody3D = wound.body.get_ref()
		if Time.get_ticks_msec() >= wound.expires or not is_instance_valid(body):
			_clay_wounds.remove_at(index)
			continue
		if not emit: continue
		_clay_blood_allowed = true
		var retained := _clay_retained_wound(wound) if wound.generation == lab_resets else Vector3.INF
		if retained.is_finite(): _spray_blood(retained, wound.normal, 2)
		_spray_blood(body.to_global(wound.body_point), -(body.global_basis * Vector3(wound.body_normal)).normalized(), 2)
		_clay_blood_allowed = false


# Called only by the finite wound controller at an actual wound-surface site.
func _clay_wound_burst28(at: Vector3, direction: Vector3, count: int) -> void:
	_clay_blood_allowed = true
	_spray_blood(at, direction, mini(count,4))
	_clay_blood_allowed = false

func _clay_dynamic_pose29() -> bool:
	# Capability stays stable while a queued cut is computing, including at rest.
	return true

func _update_city_npc(delta: float) -> void:
	_contact_reaction29.before_pose(self)
	if _impaled_drag29.advance(self,delta):
		_ensure_player_hitboxes50()
		_update_npc_bleed(delta)
		_apply_npc_severed()
	else:
		super._update_city_npc(delta)
	_contact_reaction29.after_pose(self,delta)

var _deep_collapse29 = preload("res://scripts/combat/deep_puncture29.gd").new()

func _deep_puncture29(wound: Dictionary, channel: Dictionary, depth: float) -> void:
	_deep_collapse29.observe(self,wound,channel,depth)

func _deep_topple29(direction: Vector3) -> void:
	_deep_collapse29.topple(self,direction)

func _queue_npc_corpse31(point: Vector3, direction: Vector3, speed: float) -> void:
	if _deep_collapse29.triggered_for(self):
		if _npc_corpse_pending31 or is_instance_valid(_npc_corpse31) or not is_instance_valid(_npc_body): return
		_npc_corpse_pending31 = true
		_start_npc_corpse31.call_deferred(_npc_body.get_instance_id(),point,direction,speed)
		return
	super._queue_npc_corpse31(point,direction,speed)



var _impaled_drag29 := preload("res://scripts/combat/impaled_drag29.gd").new()

func _embedded_drag29(channel: Dictionary, requested_world_delta: Vector3, delta: float) -> Dictionary:
	return _impaled_drag29.request(self,channel,requested_world_delta,delta)
