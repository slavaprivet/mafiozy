extends "res://scripts/arena27_target.gd"
const BloodFlow32 = preload("res://scripts/combat/blood_flow32.gd")
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
var _spear_contact_resume29 = preload("res://scripts/combat/spear_contact_resume29.gd").new()
var _solid_weapon29 = preload("res://scripts/combat/weapon_solid_contact29.gd").new()
var _twohand_response29 = preload("res://scripts/weapons/twohand_response29.gd").new()
var _swing_presentation30 = preload("res://scripts/weapons/swing_presentation30.gd").new()
var _cut_organs31 = preload("res://scripts/combat/cut_organs31.gd").new()
var _shield_control31 = preload("res://scripts/combat/shield_control31.gd").new()
var _armor_contact31 = preload("res://scripts/combat/armor_contact31.gd").new()
var _held_steel31 = preload("res://scripts/combat/held_steel31.gd").new()
var _solid_dispatching29 := false
var _solid_dispatch_fresh29 := false
var _solid_part_colliders29: Dictionary = {}
var _sword_puncture_resistance29 = preload("res://scripts/combat/sword_puncture_resistance29.gd").new()
var _blood_visual_resume29 = preload("res://scripts/combat/blood_contact_resume29.gd").new()
var _blood_kind_resume29 := "cut"
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
var lab_armor_tier30 := "light"

func _dress_knight() -> void:
	if not lab_armored or lab_armor_tier30 == "none": return
	var loadout := {}
	for slot: String in ["head","torso","hands","legs","feet"]:
		loadout[slot] = lab_armor_tier30+"_"+slot
	set_npc_armor31(loadout)

func _lab_restore_original() -> bool:
	if lab_armored and str(_npc_armor_loadout31.get("head","")) != lab_armor_tier30+"_head": return false
	return super._lab_restore_original()

func _clay_passive_contact28() -> bool:
	if _shield_guard_active29(): return false
	return _ready and _active() and not _held and not _unarmed and not _sword_grounded and _weapon_id in ["sword","spear"] and is_instance_valid(_sword) and _sword.visible and is_instance_valid(_player)

func _clay_reset_passive28() -> void:
	_clay_idle_points28=PackedVector3Array()
	_clay_idle_identity28=""
	_clay_idle_frame28=-1

func _clay_invalidate_motion28() -> void:
	_swing_presentation30.clear(self, "equipment")
	if has_method("combat_audio_reset30"): call("combat_audio_reset30")
	_spear_contact_resume29.invalidate("equipment")
	if _solid_weapon29 != null: _solid_weapon29.invalidate("equipment")
	_solid_part_colliders29.clear()
	_sword_puncture_resistance29.clear("equipment")
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
	set_meta("defer_embedded_restore31",true)
	var ok:=super.try_pickup_sword(allow_inactive)
	remove_meta("defer_embedded_restore31")
	if ok:
		_clay_invalidate_motion28()
		_embedded29.restore_regrab31(self)
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


func _puncture_permission29(part: String, entry: Vector3, axis: Vector3, speed: float, normal: Vector3 = Vector3.ZERO) -> bool:
	var armor:Dictionary=_armor_contact31.evaluate(self,part,entry,axis*speed,normal,"stab")
	_armor_contact31.respond(self,armor,entry,axis*speed)
	return bool(armor.penetrates)

func _puncture_accepted29(_part: String, _entry: Vector3, _axis: Vector3, _speed: float, _normal: Vector3 = Vector3.ZERO) -> void:
	pass

func _puncture_path_blocked29(from: Vector3, tip: Vector3, entry: Vector3) -> bool:
	# An independent foremost-tip probe must respect earlier steel/world contact.
	var fraction:=clampf(from.distance_to(entry)/maxf(from.distance_to(tip),.000001),0.0,1.0)
	if is_instance_valid(_npc_sword) and _npc_sword.visible:
		if not Interception31.segment(_npc_sword,from,entry).is_empty():return true
		if _prev_points.size()==SWEEP_SEGMENTS+1:
			for index in _prev_points.size():
				var next:=_sword_origin+_dir*(.06+_weapon_length*float(index)/SWEEP_SEGMENTS)
				if not Interception31.segment(_npc_sword,_prev_points[index],_prev_points[index].lerp(next,fraction)).is_empty():return true
	var excluded:Array[RID]=[_player.get_rid()]
	if is_instance_valid(_npc_body):excluded.append(_npc_body.get_rid())
	if is_instance_valid(_npc_corpse31):excluded.append(_npc_corpse31.get_rid())
	if is_instance_valid(_npc_rig) and _npc_rig.has_meta("ragdoll31"):
		var corpse_adapter:Node=_npc_rig.get_meta("ragdoll31")
		if is_instance_valid(corpse_adapter):excluded.append_array(corpse_adapter.physical.body_rids())
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
	var solid_owned: bool = _solid_weapon29 != null and _solid_weapon29.owns_body_contacts(self)
	if not solid_owned and not _shield_guard_active29() and _weapon_id in ["spear","sword"] and is_instance_valid(_sword):
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

func _register_clash(at:Vector3)->void:
	# A second steel impact inside the sound cooldown still consumes the swing.
	if _solid_weapon29!=null:_solid_weapon29.interrupt_free_swing34()
	super._register_clash(at)

func _guard_self_blade(wanted:Vector3)->Vector3:
	var resolved:=super._guard_self_blade(wanted)
	if resolved.distance_squared_to(wanted)>1e-10 and _solid_weapon29!=null:_solid_weapon29.interrupt_free_swing34()
	return resolved

func _resolve_contact(hit: Dictionary, points: PackedVector3Array, now: int, touched: Dictionary) -> void:
	if _shield_guard_active29(): return
	var collider: Object = hit.get("collider")
	if not _solid_dispatching29 and _solid_weapon29!=null and is_instance_valid(collider) and not collider.has_meta("sword_npc_part"):
		_solid_weapon29.interrupt_free_swing34()
	if not _solid_dispatching29 and _solid_weapon29 != null and _solid_weapon29.owns_body_contacts(self) and is_instance_valid(collider) and collider.has_meta("sword_npc_part"):
		return
	if not _solid_dispatching29 or _solid_dispatch_fresh29: _contact_reaction29.observe(self,hit)
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
	var armor:Dictionary=_armor_contact31.evaluate(self,part,hit.position,motion,hit.get("normal",Vector3.ZERO),"slice")
	_armor_contact31.respond(self,armor,hit.position,motion)
	var effective_cutting_speed:=cutting_speed*float(armor.speed_factor)
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
	# A first solid impact may occur millimetres into this physics tick. Its
	# validated free run-up belongs to this one impact, never to held pressure.
	var free_travel:=float(hit.get("_free_travel34",0.0)) if _solid_dispatching29 and _solid_dispatch_fresh29 and _weapon_id=="sword" else 0.0
	var strike_travel:=maxf(float(history.travel),travel+free_travel)
	var strong := bool(armor.penetrates) and effective_cutting_speed>=CLAY_SEVER_SPEED28 and alignment>=CLAY_SEVER_EDGE28 and strike_travel>=CLAY_SEVER_TRAVEL28
	clay_last_contact28={"part":part,"speed":motion.length(),"cutting_speed":cutting_speed,"effective_cutting_speed":effective_cutting_speed,"armor":armor,"edge_alignment":alignment,"travel":history.travel,"free_travel34":free_travel,"strike_travel34":strike_travel,"strong":strong,"world_point":str(hit.position)}
	_clay_contact_history28[part]=history
	_resistance28.observe(self,hit,points,now)
	if _async_cut28.busy(): return
	if not armor.penetrates:return
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
	var wound: Dictionary=_clay_local_wound_script28.apply(self,part,hit.position,motion,axis,motion.length()*float(armor.speed_factor))
	if not wound.get("ok",false):return
	history.last_wound=now;history.wound_point=hit.position
	_clay_contact_history28[part]=history
	clay_local_wounds28+=1
	if not armor.protected and has_method("combat_audio_event30"):
		call("combat_audio_event30", "slice", wound.get("world_point", hit.position), clampf(motion.length()/7.0,.12,1.0), part)
	if wound.has("world_point") and not wound.get("handles_blood",false):_clay_wound_burst28(wound.world_point,-motion,4)
	clay_last_contact28["local_wound"]=true
	lab_last_hit=clay_last_contact28.duplicate(true)
	lab_events.append(lab_last_hit.duplicate(true))
	if lab_events.size()>200:lab_events.pop_front()

func _solid_collider29(part: String) -> CollisionObject3D:
	if part.begins_with("spine"): part = "chest"
	if part == "neck": part = "head"
	if part.begins_with("clavicle_"): part = part.replace("clavicle_", "upperarm_")
	var reference: WeakRef = _solid_part_colliders29.get(part)
	var cached: CollisionObject3D = reference.get_ref() if reference != null else null
	if is_instance_valid(cached) and cached.collision_layer != 0: return cached
	if not is_instance_valid(_npc_rig): return null
	for node: Node in _npc_rig.find_children("*", "CollisionObject3D", true, false):
		if str(node.get_meta("sword_npc_part", "")) == part and node.collision_layer != 0:
			_solid_part_colliders29[part] = weakref(node)
			return node
	return null

# The solid solver supplies a real swept skin hit at the unconstrained requested
# pose. This dispatch preserves wound/damage rules; only that solver may publish
# the final held pose. A scratch or queued cut does not make intact skin passable.
func _solid_contact29(contact: Dictionary) -> Dictionary:
	if not contact.get("exact_skin", false) or _shield_guard_active29(): return {"accepted":false}
	var kind := str(contact.get("kind", "blunt"))
	var part := str(contact.get("part", ""))
	var motion: Vector3 = contact.get("motion", Vector3.ZERO)
	var speed := motion.length()
	if bool(contact.get("fresh",false)) and is_instance_valid(_npc_corpse31) and _npc_corpse31.has_meta("ragdoll31"):
		_npc_corpse31.get_meta("ragdoll31").impact(contact.position,motion,maxf(.1,_weapon_mass)*speed)
		set_meta("solid_impulse_frame31",Engine.get_physics_frames())
	if kind == "tip" and _weapon_id in ["sword", "spear"]:
		var tip_to: Vector3 = contact.get("tip_to", contact.get("to", Puncture29.tip_world(self)))
		var tip_from: Vector3 = contact.get("tip_from", contact.get("from", tip_to))
		var elapsed := maxf(0.001, float(contact.get("delta", get_physics_process_delta_time())))
		var wound := PunctureWound29.apply_puncture29(self, "", tip_to, _dir, tip_to, tip_from, elapsed)
		clay_last_contact28 = {"puncture":true,"actual_tip":true,"result":wound,"solid_contact":true}
		if wound.get("ok", false) and wound.get("created", false):
			clay_local_wounds28 += 1
			lab_last_hit = clay_last_contact28.duplicate(true)
			lab_events.append(lab_last_hit.duplicate(true))
			if lab_events.size() > 200: lab_events.pop_front()
		return {"accepted":wound.get("ok",false),"puncture":wound.get("ok",false),"result":wound}
	var collider := _solid_collider29(part)
	if not is_instance_valid(collider) or speed < 0.0001: return {"accepted":false}
	var from: Vector3 = contact.get("from", contact.position)
	var to: Vector3 = contact.get("approach_to", contact.get("to", contact.position))
	var hit := {"collider":collider,"rid":collider.get_rid(),"position":contact.position,"normal":contact.normal,"_velocity":motion,"_speed":speed,"_index":0}
	hit._free_travel34=float(contact.get("free_travel34",0.0))
	var previous := _prev_points
	var passive := _clay_idle_sweep28
	_prev_points = PackedVector3Array([from])
	_clay_idle_sweep28 = not _held and _active() and not _sword_grounded and not _unarmed
	_solid_dispatching29 = true
	_solid_dispatch_fresh29 = bool(contact.get("fresh", false))
	var before_cuts := clay_cuts
	var before_wounds := clay_local_wounds28
	var before_hp := _npc_hp
	if kind == "blunt":
		if _solid_dispatch_fresh29 and _held:
			# Base handling owns the real damage/audio/armour response. Its old
			# positional approximation must not compete with the solid solver.
			var direction_before := _dir
			var omega_before := _omega
			var block_before := _block_push
			var body_before := _body_push
			var crush_before := _weapon_crush
			# The coarse sweep has already recorded this body collider, but only
			# the solid manifold can confirm a fresh skin impact. Keep other
			# contacts intact and retain the native strength/cooldown gates.
			var contact_prev_before := _contact_prev
			var contact_gap_before := _contact_gap
			_contact_prev = _contact_prev.duplicate()
			_contact_gap = _contact_gap.duplicate()
			_contact_prev.erase(collider.get_instance_id())
			_contact_gap.erase(collider.get_instance_id())
			_contact_reaction29.observe(self, hit)
			_weapon_crush = true
			super._resolve_contact(hit, PackedVector3Array([to]), now_ms(), {})
			_contact_prev = contact_prev_before
			_contact_gap = contact_gap_before
			_weapon_crush = crush_before
			_dir = direction_before
			_omega = omega_before
			_block_push = block_before
			_body_push = body_before
	elif _weapon_id == "spear":
		if _solid_dispatch_fresh29 and speed >= 0.12:
			var armor:Dictionary=_armor_contact31.evaluate(self,part,contact.position,motion,contact.normal,"slice")
			_armor_contact31.respond(self,armor,contact.position,motion)
			var wound:Dictionary={"ok":false,"reason":"protected_surface"}
			if armor.penetrates:wound=PunctureWound29.apply(self, part, contact.position, motion, _dir, speed*float(armor.speed_factor))
			if wound.get("ok", false) and wound.get("created", false):
				clay_local_wounds28 += 1
				if not armor.protected and has_method("combat_audio_event30"): call("combat_audio_event30", "slice", contact.position, clampf(speed/7.0,.12,1.0), part)
			clay_last_contact28 = {"part":part,"solid_contact":true,"spear_lateral":true,"local_wound":wound.get("ok",false),"armor":armor}
	else:
		_resolve_contact(hit, PackedVector3Array([to]), now_ms(), {})
	_solid_dispatching29 = false
	_solid_dispatch_fresh29 = false
	_prev_points = previous
	_clay_idle_sweep28 = passive
	return {"accepted":true,"puncture":false,"queued":_async_cut28.busy(),"cuts":clay_cuts-before_cuts,"wounds":clay_local_wounds28-before_wounds,"damage":before_hp-_npc_hp}

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
	if ok:
		_async_cut28.warm(self)
		_deep_collapse29.prepare(self)
	return ok

func _process(delta: float) -> void:
	_swing_presentation30.restore(self)
	_cut_organs31.tick(self)
	_shield_control31.face(self,delta)
	_solid_weapon29.set_delta(delta)
	_twohand_response29.apply_visuals(self)
	_sync_shield_guard29()
	super._process(delta)
	_sync_shield_guard29()
	if _ready and is_instance_valid(_npc_rig) and _puncture_prepared_generation30!=lab_resets:
		Puncture29.prepare(self)
		_cut_organs31.prepare()
		_puncture_prepared_generation30=lab_resets
	_clay_sweep_carried28()
	_async_cut28.poll(self)
	# Base animation, world contacts and asynchronous topology settle first.
	# Publish the attached, body-safe weapon exactly once before rendering.
	if _ready and is_instance_valid(_world) and is_instance_valid(_rig):
		_sword_puncture_resistance29.constrain_pose(self, delta)
		# The target's drag/reaction settles after the base hand attachment.
		# Rebuild the embedded grip against that final anchor before validation.
		if _weapon_id == "spear" and not _sword_grounded:
			_embedded29.pose(self)
		_solid_weapon29.constrain_pose(self, delta)
		_held_steel31.update(self)
		if has_method("_combat_audio_tick30"): call("_combat_audio_tick30", delta)
		_swing_presentation30.present(self, delta)

func _physics_process(delta: float) -> void:
	if _ready:_held_steel31.update(self)
	_swing_presentation30.restore(self)
	super._physics_process(delta)

func is_steering() -> bool:
	if _shield_guard_active29():
		return _active() and not bool(_world.get("preview_dead")) and not _player._mount_mode and not _player._swimming and not _player._vehicle_hold
	return super.is_steering()

func _place_shield() -> void:
	if not _shield_control31.place(self):super._place_shield()

func _lab_melee_limits29(speed: float, acceleration: float) -> Vector2:
	return _twohand_response29.limits(_weapon_id, speed, acceleration)

func _lab_melee_rate29(rate: float) -> float:
	return _twohand_response29.motion_rate(_weapon_id, rate)

func _solid_tip_committed29() -> bool:
	return _solid_weapon29 == null or not _solid_weapon29.owns_body_contacts(self) or bool(_solid_weapon29._publish_safe)

func constrain_contact_walk29(value: Vector3, delta: float) -> Vector3:
	if _npc_dead and _weapon_id=="sword":
		_sword_puncture_resistance29.constrain_pose(self,delta)
	var constrained: Vector3 = _solid_weapon29.constrain_walk_velocity(self, value, delta)
	return _sword_puncture_resistance29.constrain_walk_velocity(self, constrained, delta)

func _input(event: InputEvent) -> void:
	_shield_control31.input(self,event)
	if is_instance_valid(_player):
		var weapons = _player.get("_weapon_host")
		if is_instance_valid(weapons) and weapons.has_method("sandbox_drop_input29") and weapons.sandbox_drop_input29(event):
			get_viewport().set_input_as_handled()
			return
	super._input(event)

func _exit_tree() -> void:
	_cut_organs31.clear()
	_async_cut28.dispose()
	super._exit_tree()

func set_selected(value: bool) -> void:
	if value!=_selected:
		_async_cut28.cancel("selection_changed")
		_clay_invalidate_motion28()
	super.set_selected(value)

func _lab_reset_now() -> void:
	var axes:Node = get("_hatchet32") if "_hatchet32" in self else null
	if is_instance_valid(axes): axes.before_target_reset32()
	BloodFlow32.clear_host(self)
	_clay_wounds.clear()
	# The base reset can free the corpse synchronously. Detach only this
	# actor's registered embedded weapons before their parent bodies disappear.
	# dispose preserves each model and inventory entry as a physical world drop.
	var retired:Dictionary={}
	for item in _ground_swords:
		if not is_instance_valid(item):continue
		var attachment:Node=_embedded29.dropped_attachment31(item)
		if not is_instance_valid(attachment) or retired.has(attachment.get_instance_id()):continue
		var owner_ref:WeakRef=attachment.host_ref
		if owner_ref==null or owner_ref.get_ref()!=self:continue
		retired[attachment.get_instance_id()]=true
		attachment.dispose("target_reset")
	super._lab_reset_now()

func drop_sword_to_ground(require_embedded31:bool=false) -> bool:
	var dropped := super.drop_sword_to_ground(require_embedded31)
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
		if not predecorated and is_instance_valid(_npc_armor_visual31) and before<_npc_debris.size():
			_npc_armor_visual31.cut_rigid31(context,_clay_branches,_npc_debris[before].node)
		if not predecorated: clay_last_anatomy = ClayAnatomy28.decorate(self, _clay_plane, before)
		# Anatomy only rebuilds the cap UV/material arrays. Refresh CURRENT sites;
		# wounds from earlier removed caps must retain their obsolete resource guard.
		for site: Dictionary in _clay_cap_sites:
			var mesh: MeshInstance3D = site.mesh.get_ref()
			if is_instance_valid(mesh) and mesh.mesh != null: site.kept_mesh = weakref(mesh.mesh)
		_clay_register_wounds(before, normal)
		_cut_organs31.release(self,context,before)
	clay_last_geometry = {"branches":_clay_branches.duplicate(), "cap_points":_clay_cap_points.size(), "rigid_pieces":_npc_debris.size()-before}
	var event := {"clay":true,"ok":ok,"part":part,"speed":speed,"damage":0.0,"contact":str(point),"plane_normal":str(normal),"plane_d":normal.dot(point),"scope":scope,"debris_added":_npc_debris.size()-before,"fixed_target":lab_fixed,"time_ms":Time.get_ticks_msec()}
	clay_attempts.append(event.duplicate(true))
	if clay_attempts.size()>100: clay_attempts.pop_front()
	if not ok:
		if _lab_trace_enabled28: print("CLAY27_REFUSED ",JSON.stringify(event))
		return false
	clay_commit_profile28["register_usec"]=Time.get_ticks_usec()-finish_phase;finish_phase=Time.get_ticks_usec()
	clay_cuts += 1
	if has_method("combat_audio_event30"):
		call("combat_audio_event30", "sever", point, clampf(speed/7.0,.2,1.0), "sever:%s:%s"%[lab_resets,clay_cuts])
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
	if is_instance_valid(_deep_collapse29.ragdoll):_deep_collapse29.ragdoll.on_cut(part,_clay_branches,head_gone)
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
	_blood_visual_resume29.style_spawned(self,first,at,direction,_blood_kind_resume29)

func _clay_register_wounds(first: int, normal: Vector3) -> void:
	if first >= _npc_debris.size(): return
	var body: RigidBody3D = _npc_debris[first].node
	for site: Dictionary in _clay_cap_sites:
		var wound := site.duplicate()
		wound["body"] = weakref(body)
		wound["body_point"] = body.to_local(site.world)
		wound["body_normal"] = body.global_basis.inverse() * normal
		wound["normal"] = normal
		var source_mesh:MeshInstance3D = site.mesh.get_ref()
		if is_instance_valid(source_mesh):
			var basis32 := _clay_wound_basis32(wound,_cut_skin_transforms39(source_mesh))
			if absf(basis32.determinant()) > 0.000001:
				wound["normal_rest32"] = basis32.transposed()*normal
		wound["generation"] = lab_resets
		wound["started"] = Time.get_ticks_msec()
		wound["expires"] = Time.get_ticks_msec()+12000
		wound["flow_key32"] = str(body.get_instance_id())+"_"+str(_clay_wounds.size())
		_clay_wounds.append(wound)

func _clay_wound_basis32(wound:Dictionary, binds:Array) -> Basis:
	var blended := Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
	for slot:int in wound.bones.size():
		var bone:int = wound.bones[slot]
		var weight:float = wound.weights[slot]
		if weight <= 0.0 or bone < 0 or bone >= binds.size(): continue
		var basis32:Basis = Transform3D(binds[bone]).basis
		blended.x += basis32.x*weight
		blended.y += basis32.y*weight
		blended.z += basis32.z*weight
	var mesh:MeshInstance3D = wound.mesh.get_ref()
	return mesh.global_basis*blended if is_instance_valid(mesh) else Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)

func _clay_retained_wound(wound: Dictionary) -> Vector3:
	var mesh: MeshInstance3D = wound.mesh.get_ref()
	if not is_instance_valid(mesh) or mesh.mesh == null or mesh.mesh != wound.kept_mesh.get_ref(): return Vector3.INF
	var binds := _cut_skin_transforms39(mesh)
	if wound.has("normal_rest32"):
		var basis32 := _clay_wound_basis32(wound,binds)
		if absf(basis32.determinant()) > 0.000001:
			wound.normal = (basis32.inverse().transposed()*Vector3(wound.normal_rest32)).normalized()
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
	# Only committed cuts own these streams; contact/HP timers cannot create one.
	_clay_emit_accum += delta
	if _clay_emit_accum < 0.04: return
	_clay_emit_accum = 0.0
	var now := Time.get_ticks_msec()
	for index: int in range(_clay_wounds.size()-1,-1,-1):
		var wound: Dictionary = _clay_wounds[index]
		if now >= int(wound.expires) or int(wound.generation) != lab_resets:
			_clay_wounds.remove_at(index)
			continue
		var age := float(now-int(wound.started))*0.001
		var strength := 1.0-clampf((age-2.0)/10.0,0.0,1.0)*0.85
		var retained := _clay_retained_wound(wound)
		var mesh:MeshInstance3D = wound.mesh.get_ref()
		var key:String = str(wound.flow_key32)
		if retained.is_finite() and is_instance_valid(mesh):
			BloodFlow32.touch(self,"cap_keep_"+key,retained,wound.normal,strength,lab_resets,mesh)
		# The detached piece has its own finite physical lifetime. Its removal must
		# not also stop bleeding at the retained stump.
		var body:RigidBody3D = wound.body.get_ref()
		if is_instance_valid(body):
			BloodFlow32.touch(self,"cap_piece_"+key,body.to_global(wound.body_point),-(body.global_basis*Vector3(wound.body_normal)).normalized(),strength*0.65,lab_resets,body)


# Called only by the finite wound controller at an actual wound-surface site.
func _clay_wound_burst28(at: Vector3, direction: Vector3, count: int) -> void:
	_clay_blood_allowed = true
	_blood_kind_resume29 = "wound"
	_spray_blood(at, direction, mini(count,4))
	_clay_blood_allowed = false
	_blood_kind_resume29 = "cut"

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
	if _npc_corpse_pending31 or is_instance_valid(_npc_corpse31) or not is_instance_valid(_npc_body): return
	_npc_corpse_pending31 = true
	_deep_collapse29.start_corpse.call_deferred(self,_npc_body.get_instance_id(),point,direction,speed)



var _impaled_drag29 := preload("res://scripts/combat/impaled_drag29.gd").new()

func _embedded_drag29(channel: Dictionary, requested_world_delta: Vector3, delta: float) -> Dictionary:
	return _impaled_drag29.request(self,channel,requested_world_delta,delta)
