extends Node3D
## Finite cosmetic incision: original closed triangle topology is never edited.
## The opening removes the actual exterior material, with recessed tissue walls
## and an anatomical cap behind it. Actual punctures bleed over finite time;
## incisions keep their historical cosmetic behavior.
const CUTOUT = preload("res://scripts/combat/local_wound28.gdshader")
const Anatomy = preload("res://scripts/combat/cut_anatomy28.gd")
const Puncture29 = preload("res://scripts/combat/puncture29.gd")
const BloodFlow32 = preload("res://scripts/combat/blood_flow32.gd")
const SurfaceQuery33=preload("res://scripts/combat/wound_surface_query33.gd")
const MAX_WOUNDS := 8
const BLOOD_WINDOW_MS := 3000
const DRIP_INTERVAL_MS := 140
const PUNCTURE_MAX_DRIPS29 := 320
const MAX_BLEED_HP_PER_SECOND29 := 3.0
const PUNCTURE_VISIBLE_DEPTH29 := 0.0001
static var _warm_cutout31:ShaderMaterial

static func warm31()->void:
	# Compile the shared shader during actor loading. This material is never
	# installed on the actor, so an untouched actor keeps its exact materials.
	if _warm_cutout31!=null:return
	_warm_cutout31=ShaderMaterial.new()
	_warm_cutout31.shader=CUTOUT
	_warm_cutout31.set_shader_parameter("wound_count",0)
	_warm_cutout31.get_rid()

var host: Node
var rig: Skeleton3D
var generation := -1
var wounds: Array[Dictionary] = []
var originals: Array[Dictionary] = []
var materials: Array[ShaderMaterial] = []
var attempts: Dictionary = {}
var wall_material: StandardMaterial3D
var last_result: Dictionary = {}
var last_frames: Array[Transform3D] = []
var suspended := false
var puncture_materials29: Array[ShaderMaterial] = []
var profile31:Dictionary={}
var surface_query33:RefCounted=SurfaceQuery33.new()

func _profile_start31()->int:
	return Time.get_ticks_usec() if is_instance_valid(host) and bool(host.get_meta("profile_cut31",false)) else 0

func _profile_end31(name:String,started:int)->void:
	if started==0:return
	var elapsed:=Time.get_ticks_usec()-started
	var row:Dictionary=profile31.get(name,{"calls":0,"total_usec":0,"max_usec":0})
	row.calls+=1;row.total_usec+=elapsed;row.max_usec=maxi(row.max_usec,elapsed)
	profile31[name]=row;host.set_meta("wound_profile31",profile31)

func _skin_nodes31()->Array[MeshInstance3D]:
	# Exactly the legacy bones-stream selection, using renderer metadata rather
	# than downloading every mesh's complete vertex arrays to find that stream.
	var result:Array[MeshInstance3D]=[]
	if not is_instance_valid(rig) or rig.get_parent()==null:return result
	for node:MeshInstance3D in rig.get_parent().find_children("*","MeshInstance3D",true,false):
		if not node.mesh is ArrayMesh:continue
		for surface in node.mesh.get_surface_count():
			if (node.mesh.surface_get_format(surface)&Mesh.ARRAY_FORMAT_BONES)!=0 and node.mesh.surface_get_array_len(surface)>0:
				result.append(node);break
	return result

static func apply(owner: Node, part: String, point: Vector3, motion: Vector3, blade_axis: Vector3, speed: float) -> Dictionary:
	var controller: Node = owner.get_meta("local_wound28_controller") if owner.has_meta("local_wound28_controller") else null
	if not is_instance_valid(controller):
		controller = load("res://scripts/combat/local_wound28.gd").new()
		controller.host = owner
		owner.add_child(controller)
		owner.set_meta("local_wound28_controller", controller)
	return controller.incise(part, point, motion, blade_axis, speed)

static func before_full_cut(owner: Node) -> void:
	var controller: Node = owner.get_meta("local_wound28_controller") if owner.has_meta("local_wound28_controller") else null
	if is_instance_valid(controller): controller.suspend_wounds()

static func apply_puncture29(owner: Node, part: String, point: Vector3, axis: Vector3, tip: Vector3, previous_tip: Vector3 = Vector3.INF, tip_delta: float = 1.0/60.0) -> Dictionary:
	var controller: Node = owner.get_meta("local_wound28_controller") if owner.has_meta("local_wound28_controller") else null
	if not is_instance_valid(controller):
		controller = load("res://scripts/combat/local_wound28.gd").new()
		controller.host = owner
		owner.add_child(controller)
		owner.set_meta("local_wound28_controller",controller)
	var started:int=controller._profile_start31()
	var result:Dictionary=controller.puncture29(part,point,axis,tip,previous_tip,tip_delta)
	controller._profile_end31("puncture_total",started)
	return result

static func advance_active29(owner: Node, tip: Vector3) -> void:
	if not owner.has_meta("local_wound28_controller"): return
	var controller: Node = owner.get_meta("local_wound28_controller")
	if not is_instance_valid(controller): return
	var channel: Dictionary = owner.get_meta("puncture29_channel",{})
	if not channel.get("valid",false) or channel.get("withdrawn",false): return
	for wound: Dictionary in controller.get("wounds"):
		if wound.get("puncture",false) and channel.get("node_ref",null)!=null and channel.node_ref.get_ref()==wound.node:
			controller.call("_advance_puncture29",wound,tip)
			controller.call("_update_uniforms")
			return

static func finish_full_cut(owner: Node, ok: bool) -> void:
	var controller: Node = owner.get_meta("local_wound28_controller") if owner.has_meta("local_wound28_controller") else null
	if is_instance_valid(controller): controller.finish_cut(ok)

func suspend_wounds() -> void:
	BloodFlow32.clear_host(host)
	_sync_actor()
	_invalidate_channel29()
	if suspended:return
	suspended=true
	for row:Dictionary in originals:
		if not _owns_material_row(row):continue
		var node:MeshInstance3D=row.node.get_ref()
		if not is_instance_valid(node) or node.mesh==null:continue
		row["wound_surfaces"]=[]
		for index in node.mesh.get_surface_count():row.wound_surfaces.append(node.get_surface_override_material(index))
		node.material_override=row.override
		for index in row.surfaces.size():node.set_surface_override_material(index,row.surfaces[index])
	for wound:Dictionary in wounds:wound.node.visible=false

func finish_cut(ok:bool)->void:
	_sync_actor()
	if not suspended:return
	suspended=false
	if ok:
		# Full cut already installed its own surfaces. Do not restore old slots
		# over a new flesh/bone cap or over reindexed exterior material slots.
		originals.clear()
		clear_wounds()
		return
	for row:Dictionary in originals:
		if not _owns_material_row(row):continue
		var node:MeshInstance3D=row.node.get_ref()
		if not is_instance_valid(node) or node.mesh==null:continue
		node.material_override=null
		for index in row.get("wound_surfaces",[]).size():node.set_surface_override_material(index,row.wound_surfaces[index])
	for wound:Dictionary in wounds:wound.node.visible=_visible_injury29(wound)

func _owns_material_row(row: Dictionary) -> bool:
	var node: MeshInstance3D = row.node.get_ref()
	if not is_instance_valid(node) or node.mesh == null: return false
	# Reset and full cuts may reuse the MeshInstance with a different resource.
	# A saved override belongs only to the exact source mesh and actor generation.
	return int(row.generation) == int(host.get("lab_resets")) and node.mesh == row.mesh.get_ref()

func clear_wounds(restore_materials: bool = true) -> void:
	surface_query33.clear()
	BloodFlow32.clear_host(host)
	_invalidate_channel29()
	for material: ShaderMaterial in puncture_materials29:
		material.set_shader_parameter("puncture_count29" if material.shader == Anatomy.CUT_SHADER else "wound_count",0)
	for row: Dictionary in originals:
		if not restore_materials or not _owns_material_row(row): continue
		var node: MeshInstance3D = row.node.get_ref()
		if not is_instance_valid(node): continue
		node.material_override = row.override
		for index in row.surfaces.size():
			if node.mesh != null and index < node.mesh.get_surface_count():
				node.set_surface_override_material(index, row.surfaces[index])
	for wound: Dictionary in wounds:
		_remove_drops(wound)
		if is_instance_valid(wound.node): wound.node.queue_free()
	wounds.clear(); originals.clear(); materials.clear(); attempts.clear(); puncture_materials29.clear()
	last_result = {}
	last_frames.clear();suspended=false

func _sync_actor() -> void:
	var next_rig: Skeleton3D = host.get("_npc_rig")
	var next_generation: int = host.get("lab_resets")
	if next_rig != rig or next_generation != generation:
		# The host has already restored its authoritative mesh/material snapshot.
		# Retiring this controller must not replay overrides from the prior actor.
		clear_wounds(false)
		rig = next_rig
		generation = next_generation

func incise(part: String, point: Vector3, motion: Vector3, blade_axis: Vector3, _speed: float) -> Dictionary:
	_sync_actor()
	if not is_instance_valid(rig): return {"ok":false,"reason":"no_actor"}
	var now := Time.get_ticks_msec()
	# Repeated sweep rays reuse the same groove; failures also have a bounded
	# retry rate so collider-only contacts cannot rescan the entire skin every ray.
	for wound: Dictionary in wounds:
		if _visible_injury29(wound) and wound.part == part and wound.node.global_position.distance_to(point)<0.09:
			return {"ok":true,"visible_wound":true,"created":false,"world_point":wound.node.global_position,"emitter_node":wound.node,"handles_blood":true}
	if wounds.size()>=MAX_WOUNDS: return {"ok":false,"reason":"wound_budget"}
	if now-int(attempts.get(part,-10000))<180: return {"ok":false,"reason":"contact_cooldown"}
	attempts[part] = now
	var surface := _surface_point(point,part)
	if surface.is_empty(): return {"ok":false,"reason":"no_actual_surface"}
	var bone := rig.find_bone(part)
	if bone<0: bone=rig.find_bone("chest")
	if bone<0: return {"ok":false,"reason":"no_anchor"}
	var bone_world := rig.global_transform*rig.get_bone_global_pose(bone)
	var at: Vector3 = surface.point
	var normal: Vector3 = surface.normal
	if normal.dot(at-bone_world.origin)<0.0: normal=-normal
	var u := blade_axis-normal*blade_axis.dot(normal)
	if u.length_squared()<0.001: u=motion-normal*motion.dot(normal)
	if u.length_squared()<0.001: u=normal.cross(Vector3.UP if absf(normal.y)<0.9 else Vector3.RIGHT)
	u=u.normalized()
	var v := normal.cross(u).normalized()
	var half_length := 0.045
	var half_width := 0.008
	var target := _bone_target(part,at,normal)
	var depth := clampf((at-target).dot(normal),0.012,0.16)
	var frame := Transform3D(Basis(u,v,normal),at)
	var node := Node3D.new()
	node.name="LocalIncision28"
	add_child(node)
	node.global_transform=frame
	var cap_frame := {"u":u,"v":v,"n":normal,"origin":at-normal*depth}
	var anatomy := Anatomy._anatomy(rig,cap_frame)
	var ring:=_lens_ring28(half_length,half_width)
	var cap := MeshInstance3D.new()
	cap.name="RecessedBoneAndTissue"
	cap.mesh=_lens_mesh28(ring,depth,true)
	cap.material_override=Anatomy._material(anatomy,{},false)
	node.add_child(cap)
	if wall_material==null:
		wall_material=StandardMaterial3D.new()
		wall_material.albedo_color=Color(0.30,0.018,0.025)
		wall_material.roughness=0.28
		wall_material.metallic_specular=0.60
		wall_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var wall:=MeshInstance3D.new()
	wall.name="IncisionWalls"
	wall.mesh=_lens_mesh28(ring,depth,false)
	wall.material_override=wall_material
	node.add_child(wall)
	if materials.is_empty(): _install_materials()
	wounds.append({"node":node,"part":part,"bone":bone,"local":bone_world.affine_inverse()*frame,"length":half_length,"width":half_width,"depth":depth,"emit_until":now+BLOOD_WINDOW_MS,"emit_at":now,"drops":[],"emitted":0,"ring":ring})
	_update_uniforms()
	last_result={"ok":true,"visible_wound":true,"created":true,"world_point":at,"emitter_node":node,"depth":depth,"surface_distance":surface.distance,"bone_sections":anatomy.starts.size(),"count":wounds.size(),"handles_blood":true}
	return last_result

func _invalidate_channel29() -> void:
	if is_instance_valid(host) and host.has_meta("puncture29_channel"):
		var channel: Dictionary = host.get_meta("puncture29_channel")
		channel.valid = false
		channel.active = false

func puncture29(part: String, point: Vector3, axis: Vector3, tip: Vector3, previous_tip: Vector3 = Vector3.INF, tip_delta: float = 1.0/60.0) -> Dictionary:
	_sync_actor()
	if suspended or not is_instance_valid(rig): return {"ok":false,"reason":"unavailable_actor"}
	axis = axis.normalized()
	var existing: Dictionary = host.get_meta("puncture29_channel",{})
	var pending: Dictionary = {}
	if existing.get("valid",false) and not existing.get("withdrawn",false) and int(existing.get("weapon_instance_id",-1)) == host.get("_sword").get_instance_id():
		for wound: Dictionary in wounds:
			if wound.get("puncture",false) and existing.node_ref.get_ref() == wound.node:
				if float(wound.depth) <= PUNCTURE_VISIBLE_DEPTH29 and previous_tip.is_finite():
					# The supplied point may be a proposed tip behind the skin. Compare
					# the freshly validated skin intersection below, never that argument.
					pending = wound
					break
				_advance_puncture29(wound,tip)
				return {"ok":true,"created":false,"puncture":true,"through":wound.through,"depth":wound.depth,"world_point":wound.node.global_position,"handles_blood":true}
	if not previous_tip.is_finite():return {"ok":false,"reason":"missing_continuous_tip_segment"}
	var tip_step := tip-previous_tip
	if tip_step.length() < 0.000001 or tip_step.length() > 0.40 or tip_step.normalized().dot(axis) < 0.80:return {"ok":false,"reason":"not_continuous_tip_thrust"}
	var speed := tip_step.length()/maxf(tip_delta,0.000001)
	# Entry follows real tip travel, but the bore follows the steel's accepted
	# orientation. The embedded solver must not rotate the shaft to a walk tangent.
	for wound: Dictionary in wounds:
		if not pending.is_empty(): break
		if not wound.get("puncture",false) or not _visible_injury29(wound): continue
		var local: Vector3 = wound.node.to_local(tip)
		var previous_local: Vector3 = wound.node.to_local(previous_tip)
		if Vector2(local.x,local.y).length() < float(wound.length) and previous_local.z >= 0.0 and local.z < 0.0 and (-wound.node.global_basis.z).dot(axis) > 0.9:
			host.set_meta("puncture29_contact_context",{"from":previous_tip,"to":tip,"entry":wound.node.global_position,"physics_frame":Engine.get_physics_frames(),"weapon_instance_id":host.get("_sword").get_instance_id()})
			if host.has_method("_puncture_path_blocked29") and host.call("_puncture_path_blocked29",previous_tip,tip,wound.node.global_position):return {"ok":false,"reason":"nearer_barrier"}
			var surface_normal:Vector3=wound.node.global_basis*Vector3(wound.get("normal_local",Vector3.BACK))
			if host.has_method("_puncture_permission29") and not host.call("_puncture_permission29",wound.part,wound.node.global_position,axis,speed,surface_normal):return {"ok":false,"reason":"protected_surface"}
			_activate_channel29(wound)
			_advance_puncture29(wound,tip)
			if host.has_method("_puncture_accepted29"):host.call("_puncture_accepted29",wound.part,wound.node.global_position,axis,speed,surface_normal)
			return {"ok":true,"created":false,"puncture":true,"through":wound.through,"depth":wound.depth,"world_point":wound.node.global_position,"handles_blood":true}
	if wounds.size() >= MAX_WOUNDS and pending.is_empty(): return {"ok":false,"reason":"wound_budget"}
	var now := Time.get_ticks_msec()
	var path_started:=_profile_start31()
	var path := Puncture29.entry_path(host,previous_tip,tip,axis)
	_profile_end31("entry_path",path_started)
	if not path.get("ok",false): return path
	var depth := (tip-Vector3(path.entry)).dot(axis)
	if depth < 0.000001: return {"ok":false,"reason":"tip_before_skin"}
	if (previous_tip-Vector3(path.entry)).dot(axis) > 0.001:return {"ok":false,"reason":"tip_already_inside_no_new_entry"}
	var bone := int(path.get("bone",-1))
	if bone >= 0: part = str(rig.get_bone_name(bone))
	else: bone = rig.find_bone(part)
	if bone < 0: bone = rig.find_bone("chest")
	if bone < 0: return {"ok":false,"reason":"no_anchor"}
	host.set_meta("puncture29_contact_context",{"from":previous_tip,"to":tip,"entry":Vector3(path.entry),"physics_frame":Engine.get_physics_frames(),"weapon_instance_id":host.get("_sword").get_instance_id()})
	if host.has_method("_puncture_path_blocked29") and host.call("_puncture_path_blocked29",previous_tip,tip,Vector3(path.entry)):return {"ok":false,"reason":"nearer_barrier"}
	if host.has_method("_puncture_permission29") and not host.call("_puncture_permission29",part,Vector3(path.entry),axis,speed,Vector3(path.normal)):return {"ok":false,"reason":"protected_surface"}
	if not pending.is_empty():
		var current_frame := rig.global_transform*rig.get_bone_global_pose(pending.bone)*Transform3D(pending.local)
		if current_frame.origin.distance_squared_to(Vector3(path.entry)) <= PUNCTURE_VISIBLE_DEPTH29*PUNCTURE_VISIBLE_DEPTH29 and (-current_frame.basis.z).normalized().dot(axis) >= 0.999999:
			_advance_puncture29(pending,tip)
			return {"ok":true,"created":false,"puncture":true,"through":pending.through,"depth":pending.depth,"world_point":current_frame.origin,"handles_blood":true}
	var bone_world := rig.global_transform*rig.get_bone_global_pose(bone)
	var normal := -axis
	var creation_started:=_profile_start31()
	var weapon: Node3D = host.get("_sword")
	var u: Vector3 = weapon.global_basis.y - normal*weapon.global_basis.y.dot(normal)
	u = u.normalized() if u.length_squared()>.0001 else normal.cross(Vector3.UP).normalized()
	var v := normal.cross(u).normalized()
	var frame := Transform3D(Basis(u,v,normal),path.entry)
	var reseeded := not pending.is_empty()
	var node: Node3D = pending.node if reseeded else Node3D.new()
	if not reseeded:
		node.name = "PunctureChannel29"
		add_child(node)
	else:
		# All crossing, nearer-barrier and surface-permission checks passed.
		# Reuse only the invisible preview's resources; committed wounds never
		# enter this branch and no tentative depth/bleed is carried into it.
		existing.valid = false
		existing.active = false
	node.visible = false
	node.global_transform = frame
	var profile := Puncture29.tip_profile(host,depth)
	var width := profile.x
	var height := profile.y
	var mouth := _puncture_mouth29(str(host.get("_weapon_id")),profile,depth)
	var ring := Puncture29.ring(mouth.x,mouth.y)
	if wall_material == null:
		wall_material = StandardMaterial3D.new()
		wall_material.albedo_color = Color(0.30,0.018,0.025)
		wall_material.roughness = 0.28
		wall_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wall: MeshInstance3D = pending.wall if reseeded else MeshInstance3D.new()
	wall.name = "OpenTissueTunnel29"
	wall.material_override = wall_material
	wall.mesh = null
	if not reseeded: node.add_child(wall)
	var wound: Dictionary = pending if reseeded else {}
	wound.clear()
	wound.merge({"node":node,"part":part,"bone":bone,"local":bone_world.affine_inverse()*frame,"length":width,"width":height,"depth":0.0,"skin_depth":path.length,"emit_until":now+BLOOD_WINDOW_MS,"emit_at":now,"drops":[],"emitted":0,"ring":ring,"puncture":true,"through":false,"wall":wall,"last_tip":tip,"weapon":str(host.get("_weapon_id")),"weapon_instance_id":host.get("_sword").get_instance_id()})
	wound.mouth_length29=mouth.x;wound.mouth_width29=mouth.y
	wound.accepted_speed31=speed
	wound.normal_local=frame.basis.inverse()*Vector3(path.normal)
	_profile_end31("create_node_profile",creation_started)
	if materials.is_empty(): _install_materials()
	if not reseeded: wounds.append(wound)
	_activate_channel29(wound)
	_advance_puncture29(wound,tip)
	_update_uniforms()
	if host.has_method("_puncture_accepted29"):host.call("_puncture_accepted29",part,Vector3(path.entry),axis,speed,Vector3(path.normal))
	last_result = {"ok":true,"created":not reseeded,"reseeded_preview":reseeded,"puncture":true,"through":wound.through,"depth":wound.depth,"skin_depth":path.length,"world_point":path.entry,"exit_world":path.exit,"actual_skin_intersections":path.intersections,"handles_blood":true,"count":wounds.size()}
	return last_result

static func _puncture_mouth29(weapon: String, steel: Vector2, depth: float) -> Vector2:
	if weapon != "sword": return steel
	# Only the rendered tissue opening expands. The real steel dimensions still
	# own channel radius, re-entry and embedded movement. A first touch stays small.
	var opening := smoothstep(0.002,0.045,depth)
	return Vector2(maxf(steel.x*(1.0+0.12*opening),lerpf(0.004,0.026,opening)),maxf(steel.y,lerpf(0.004,0.013,opening)))

func _activate_channel29(wound: Dictionary) -> void:
	var existing: Dictionary = host.get_meta("puncture29_channel",{})
	if existing.get("valid",false) and not existing.get("withdrawn",false) and existing.get("node_ref",null) != null and existing.node_ref.get_ref() == wound.node and int(existing.get("weapon_instance_id",-1)) == host.get("_sword").get_instance_id() and str(existing.get("weapon","")) == str(host.get("_weapon_id")): return
	var bone_world := rig.global_transform*rig.get_bone_global_pose(wound.bone)
	var entry: Vector3 = wound.node.global_position
	var axis: Vector3 = -wound.node.global_basis.z
	var exit := entry+axis*float(wound.skin_depth)
	var channel := {"valid":true,"active":true,"actual_hit":true,"generation":generation,"weapon":str(host.get("_weapon_id")),"weapon_instance_id":host.get("_sword").get_instance_id(),"rig_ref":weakref(rig),"bone":wound.bone,"entry_local":bone_world.affine_inverse()*entry,"exit_local":bone_world.affine_inverse()*exit,"axis_local":bone_world.basis.inverse()*axis,"entry_world":entry,"exit_world":exit,"axis_world":axis,"radius":wound.length,"max_depth":wound.depth,"current_depth":wound.depth,"node_ref":weakref(wound.node)}
	host.set_meta("puncture29_channel",channel)
	channel.tip_offset = Puncture29.tip_local(host).x
	channel.max_depth = float(wound.skin_depth)+0.04
	channel.cut_depth = wound.depth
	wound.weapon = str(host.get("_weapon_id"))
	wound.weapon_instance_id = host.get("_sword").get_instance_id()

func _advance_puncture29(wound: Dictionary, tip: Vector3) -> void:
	# A requested/probed pose is not penetration. The final solid-contact owner
	# must have committed the attached steel before geometry, blood or health grow.
	if host.has_method("_solid_tip_committed29") and not host.call("_solid_tip_committed29"): return
	var channel: Dictionary = host.get_meta("puncture29_channel",{})
	if not channel.get("valid",false) or not channel.get("actual_hit",false) or channel.get("withdrawn",false): return
	if int(channel.get("generation",-1)) != generation or channel.get("rig_ref",null) == null or channel.rig_ref.get_ref() != rig: return
	if channel.get("node_ref",null) == null or channel.node_ref.get_ref() != wound.node: return
	var current_weapon: Node3D = host.get("_sword")
	if not is_instance_valid(current_weapon) or int(channel.get("weapon_instance_id",-1)) != current_weapon.get_instance_id(): return
	if str(channel.get("weapon","")) != str(host.get("_weapon_id")): return
	# The host may commit before this child's _process. Measure the accepted tip
	# in the current bone frame, never the previous rendered wound transform.
	wound.node.global_transform = rig.global_transform*rig.get_bone_global_pose(wound.bone)*Transform3D(wound.local)
	var local: Vector3 = wound.node.to_local(tip)
	var depth := -local.z
	if channel.get("node_ref",null) != null and channel.node_ref.get_ref() == wound.node:
		channel.entry_world = wound.node.global_position
		channel.axis_world = -wound.node.global_basis.z
		channel.exit_world = channel.entry_world+channel.axis_world*float(wound.skin_depth)
		channel.current_depth = depth
		channel.tip_depth = depth
	# A prospective entry which never opened visible tissue is not an embedded
	# weapon. Cancel it only from the final accepted tip outside the same bore;
	# do not manufacture a withdrawal or retain an immortal active preview.
	if not _visible_injury29(wound) and depth < -PUNCTURE_VISIBLE_DEPTH29:
		channel.valid = false
		channel.active = false
		channel.cancelled31 = true
		channel.release_reason = "pending_tip_outside"
		return
	# Sword has no embedded spear owner to close the channel on exit. Retire
	# only after real penetration; retain its injury and finite bleed budget.
	if str(channel.get("weapon","")) == "sword" and float(wound.depth) > PUNCTURE_VISIBLE_DEPTH29 and depth < -PUNCTURE_VISIBLE_DEPTH29:
		channel.withdrawn = true
		channel.valid = false
		channel.active = false
		return
	# A deflection cannot paint a new passage sideways. The separate constraint
	# owns withdrawal/locking; this geometry only grows inside the original bore.
	if Vector2(local.x,local.y).length() > float(wound.length)+0.012: return
	depth = clampf(depth,0.0,float(wound.skin_depth))
	if depth <= float(wound.depth)+0.0001: return
	var accepted_at31:=Time.get_ticks_usec()
	if wound.has("accepted_at31") and accepted_at31-int(wound.accepted_at31)>1000:
		wound.accepted_speed31=(depth-float(wound.depth))/(float(accepted_at31-int(wound.accepted_at31))*0.000001)
	wound.accepted_at31=accepted_at31
	wound.depth = depth
	wound.node.visible = depth > PUNCTURE_VISIBLE_DEPTH29
	# Only a deeper accepted passage increases this finite injury. Holding,
	# withdrawing, dropping or reselecting cannot restart its bleed budget.
	var ratio := clampf(depth/maxf(0.008,float(wound.skin_depth)),0.0,1.0)
	var duration := lerpf(8.0,20.0,ratio)
	var rate := lerpf(0.25,1.50,ratio)
	var previous_budget := float(wound.get("bleed_budget29",0.0))
	var budget := duration*rate
	wound.bleed_left29 = float(wound.get("bleed_left29",0.0))+maxf(0.0,budget-previous_budget)
	wound.bleed_budget29 = maxf(previous_budget,budget)
	wound.bleed_rate29 = rate
	wound.bleed_ratio29 = ratio
	wound.bleed_seconds29 = maxf(float(wound.get("bleed_seconds29",0.0)),duration)
	wound.emit_until = Time.get_ticks_msec()+int(duration*1000.0)
	wound.through = depth >= float(wound.skin_depth)-0.0001
	var profile_started:=_profile_start31()
	var profile := Puncture29.tip_profile(host,depth)
	_profile_end31("tip_profile",profile_started)
	wound.length=maxf(float(wound.length),profile.x)
	wound.width=maxf(float(wound.width),profile.y)
	var mouth := _puncture_mouth29(str(wound.weapon),Vector2(wound.length,wound.width),depth)
	wound.mouth_length29=maxf(float(wound.get("mouth_length29",wound.length)),mouth.x)
	wound.mouth_width29=maxf(float(wound.get("mouth_width29",wound.width)),mouth.y)
	wound.ring=Puncture29.ring(wound.mouth_length29,wound.mouth_width29)
	var upload_started:=_profile_start31()
	wound.wall.mesh = Puncture29.channel_mesh(wound.ring,depth,not wound.through)
	_profile_end31("channel_mesh_upload",upload_started)
	if not channel.is_empty(): channel.cut_depth = depth
	if host.has_method("_deep_puncture29"): host.call("_deep_puncture29",wound,channel,depth)
	last_frames.clear()

func _process(delta: float) -> void:
	if not is_instance_valid(host): return
	_sync_actor()
	# Death can reparent this same rig into its physical corpse. The real bore
	# remains attached until withdrawal or an actual identity/equipment change.
	if bool(host.get("_unarmed")) or bool(host.get("_sword_grounded")): _invalidate_channel29()
	_retire_pending29()
	if suspended or wounds.is_empty() or not is_instance_valid(rig): return
	var now:=Time.get_ticks_msec()
	for wound:Dictionary in wounds:
		wound.node.global_transform=rig.global_transform*rig.get_bone_global_pose(wound.bone)*Transform3D(wound.local)
		if wound.get("puncture",false):
			var weapon: Node3D = host.get("_sword")
			var same_weapon := is_instance_valid(weapon) and weapon.get_instance_id() == int(wound.weapon_instance_id) and str(host.get("_weapon_id")) == str(wound.weapon)
			var advancing := bool(host.get("_held")) or (host.has_method("_clay_passive_contact28") and bool(host.call("_clay_passive_contact28")))
			if same_weapon and advancing and not bool(host.get("_blocking")):
				var tip := Puncture29.tip_world(host)
				if tip.distance_to(Vector3(wound.last_tip)) < 0.40: _advance_puncture29(wound,tip)
				wound.last_tip = tip
		var flowing32 := _flow32(wound,now)
		if not flowing32 and _visible_injury29(wound) and now<int(wound.emit_until) and now>=int(wound.emit_at) and host.has_method("_clay_wound_burst28"):
			_emit_drip(wound,now)
			wound.emit_at=now+_drip_interval29(wound)
	_tick_bleeding29(delta)
	_update_uniforms()

func _flow32(wound: Dictionary, now: int) -> bool:
	if not _visible_injury29(wound) or now>=int(wound.emit_until): return false
	var area := 4.0*float(wound.get("mouth_length29",wound.length))*float(wound.get("mouth_width29",wound.width))
	var severity := clampf(sqrt(maxf(0.0,area)/0.003)*clampf(float(wound.depth)/0.02,0.0,1.0),0.0,1.0)
	if severity<0.25: return false
	var remaining := float(int(wound.emit_until)-now)/1000.0
	var local := _lower_lip29(wound)
	var point: Vector3=wound.node.to_global(local)
	var normal: Vector3=wound.node.global_basis.z
	var accepted := BloodFlow32.touch(host,"local_"+str(wound.node.get_instance_id()),point,normal,severity*minf(1.0,remaining),generation,wound.node)
	wound["flow_point32"]=point
	wound["flow_strength32"]=severity
	return accepted

static func _drip_interval29(wound: Dictionary) -> int:
	if not wound.get("puncture",false): return DRIP_INTERVAL_MS
	return int(lerpf(220.0,65.0,clampf(float(wound.get("bleed_ratio29",0.0)),0.0,1.0)))

static func _visible_injury29(wound: Dictionary) -> bool:
	return not wound.get("puncture",false) or float(wound.get("depth",0.0)) > PUNCTURE_VISIBLE_DEPTH29

func _retire_pending29() -> void:
	var channel: Dictionary = host.get_meta("puncture29_channel",{})
	var pending_node: Node = null
	if channel.get("valid",false) and not channel.get("withdrawn",false) and channel.get("node_ref",null) != null:
		pending_node=channel.node_ref.get_ref()
	for index in range(wounds.size()-1,-1,-1):
		var wound: Dictionary=wounds[index]
		if _visible_injury29(wound) or wound.node == pending_node: continue
		if is_instance_valid(wound.node): wound.node.queue_free()
		wounds.remove_at(index)

func _tick_bleeding29(delta: float) -> void:
	if suspended or not is_instance_valid(rig) or rig != host.get("_npc_rig") or generation != int(host.get("lab_resets")): return
	if bool(host.get("_lab_reset_pending")): return
	if bool(host.get("_npc_dead")): return
	# Damage follows simulated elapsed time and the injury, independently of
	# the currently selected weapon. A long stalled frame never dumps a burst.
	var dt := clampf(delta,0.0,0.10)
	var total := 0.0
	var active: Array[Dictionary] = []
	for wound: Dictionary in wounds:
		if not wound.get("puncture",false) or not is_instance_valid(wound.node): continue
		var seconds := minf(dt,float(wound.get("bleed_seconds29",0.0)))
		wound.bleed_seconds29=maxf(0.0,float(wound.get("bleed_seconds29",0.0))-dt)
		var amount := minf(float(wound.get("bleed_left29",0.0)),seconds*float(wound.get("bleed_rate29",0.0)))
		if amount<=0.0: continue
		active.append({"wound":wound,"amount":amount});total+=amount
	if total<=0.0: return
	var scale := minf(1.0,MAX_BLEED_HP_PER_SECOND29*dt/total)
	var damage := 0.0
	for row: Dictionary in active:
		var amount: float=row.amount*scale
		row.wound.bleed_left29=maxf(0.0,float(row.wound.bleed_left29)-amount)
		row.wound.bleed_damage29=float(row.wound.get("bleed_damage29",0.0))+amount
		damage+=amount
	host.set("_npc_hp",maxf(0.0,float(host.get("_npc_hp"))-damage))
	if float(host.get("_npc_hp"))<=0.0:
		var source: Dictionary=active[0].wound
		host.call("_npc_die_from_vital_wound31",source.node.global_position,-source.node.global_basis.z,0.0,false)

static func _sword_puncture29(wound: Dictionary) -> bool:
	return bool(wound.get("puncture",false)) and str(wound.get("weapon",""))=="sword"

static func _lower_lip29(wound: Dictionary) -> Vector3:
	var ring: Array[Vector3]=wound.ring
	var lowest := INF
	var local := Vector3.ZERO
	for i in ring.size():
		var candidate := ring[i].lerp(ring[(i+1)%ring.size()],0.5)
		var height: float=wound.node.to_global(candidate).y
		if height<lowest:
			lowest=height;local=candidate
	# Start just inside the actual polygon wall at its lip.
	local*=0.94
	local.z=-minf(0.0015,float(wound.depth)*0.1)
	return local

func _emit_drip(wound:Dictionary,now:int)->void:
	if not _visible_injury29(wound): return
	if wound.get("puncture",false) and int(wound.emitted)>=PUNCTURE_MAX_DRIPS29:return
	# Emit from the real recessed wall near its lip, not from the air in the
	# opening's centre. Use the exact polygon edge shared by wall and cutout.
	var ring:Array[Vector3]=wound.ring
	var edge:int=2+int(wound.emitted)%8
	if int(wound.emitted)%2==1:edge=ring.size()-edge-1
	var local:Vector3=ring[edge].lerp(ring[(edge+1)%ring.size()],0.5)
	local.z=-minf(0.0015,float(wound.depth)*0.1)
	if wound.get("puncture",false):local=_lower_lip29(wound)
	var drip_direction: Vector3 = wound.node.global_basis.z
	if wound.get("puncture",false) and wound.get("through",false) and int(wound.emitted)%2 == 1:
		local.z = -float(wound.depth)+0.0015
		drip_direction = -drip_direction
	var at:Vector3=wound.node.to_global(local)
	var gore:Array=host.get("_npc_gore")
	var first:=gore.size()
	host.call("_clay_wound_burst28",at,drip_direction,1)
	var velocities:Array=host.get("_blood_velocities")
	var timers:Array=host.get("_blood_timers")
	for index in range(first,gore.size()):
		var drop:Node3D=gore[index]
		if not is_instance_valid(drop) or index>=velocities.size() or index>=timers.size():continue
		drop.global_position=at
		if wound.get("puncture",false) and drop is MeshInstance3D:
			# The inherited source spheres are 4-10 cm across. Specify actual
			# millimetres here rather than multiplying that variable source size.
			var size: Vector3=drop.mesh.get_aabb().size
			drop.global_basis=Basis.IDENTITY
			var intensity := clampf(float(wound.get("bleed_ratio29",0.0)),0.0,1.0)
			var diameter := lerpf(0.003,0.006,intensity)
			var length := lerpf(0.008,0.018,intensity)
			drop.scale=Vector3(diameter/maxf(size.x,0.0001),length/maxf(size.y,0.0001),diameter/maxf(size.z,0.0001))
		elif not bool(drop.get_meta("cap_blood29",false)):
			# A styled incision drop already has its final millimetre dimensions.
			# Keep the historical scale only for the original inherited spheres.
			drop.scale=Vector3.ONE*0.08
		drop.set_meta("local_wound28",true)
		velocities[index]=drip_direction*0.06+Vector3.DOWN*0.12
		timers[index]=minf(1.0,maxf(0.02,float(int(wound.emit_until)-now)/1000.0))
		wound.drops.append(weakref(drop))
		wound.emitted=int(wound.emitted)+1
	wound["last_drip_local"]=local
	wound["last_drip_world"]=at

func _remove_drops(wound:Dictionary)->void:
	if not is_instance_valid(host):return
	var gore:Array=host.get("_npc_gore")
	var velocities:Array=host.get("_blood_velocities")
	var timers:Array=host.get("_blood_timers")
	for ref:WeakRef in wound.get("drops",[]):
		var drop:Node=ref.get_ref()
		if not is_instance_valid(drop):continue
		var index:=gore.find(drop)
		if index>=0:
			gore.remove_at(index)
			if index<velocities.size():velocities.remove_at(index)
			if index<timers.size():timers.remove_at(index)
			host.set("_blood_count",maxi(0,int(host.get("_blood_count"))-1))
		drop.queue_free()

func _update_uniforms() -> void:
	var visible_wounds: Array[Dictionary] = []
	for wound: Dictionary in wounds:
		if _visible_injury29(wound): visible_wounds.append(wound)
	var frames:Array[Transform3D]=[]
	for wound:Dictionary in visible_wounds:frames.append(wound.node.global_transform)
	if frames==last_frames:return
	last_frames=frames
	var centers:Array[Vector4]=[];var us:Array[Vector4]=[];var vs:Array[Vector4]=[];var ns:Array[Vector4]=[]
	for wound:Dictionary in visible_wounds:
		var t:Transform3D=wound.node.global_transform
		centers.append(Vector4(t.origin.x,t.origin.y,t.origin.z,1.0 if wound.get("puncture",false) else 0.0))
		us.append(Vector4(t.basis.x.x,t.basis.x.y,t.basis.x.z,wound.get("mouth_length29",wound.length)))
		vs.append(Vector4(t.basis.y.x,t.basis.y.y,t.basis.y.z,wound.get("mouth_width29",wound.width)))
		ns.append(Vector4(t.basis.z.x,t.basis.z.y,t.basis.z.z,wound.depth))
	while centers.size()<MAX_WOUNDS:
		centers.append(Vector4.ZERO);us.append(Vector4.ZERO);vs.append(Vector4.ZERO);ns.append(Vector4.ZERO)
	for material:ShaderMaterial in materials:
		material.set_shader_parameter("wound_count",visible_wounds.size())
		material.set_shader_parameter("wound_origin",centers);material.set_shader_parameter("wound_u",us)
		material.set_shader_parameter("wound_v",vs);material.set_shader_parameter("wound_n",ns)
	# Earlier incisions have their own tissue/bone cap and side walls. They must
	# share the bore, otherwise a visible skin hole would stop at an intact cap.
	var puncture_count := 0
	var pc: Array[Vector4] = []; var pu: Array[Vector4] = []; var pv: Array[Vector4] = []; var pn: Array[Vector4] = []
	for i in visible_wounds.size():
		if not visible_wounds[i].get("puncture",false): continue
		pc.append(centers[i]); pu.append(us[i]); pv.append(vs[i]); pn.append(ns[i]); puncture_count += 1
	while pc.size()<MAX_WOUNDS:pc.append(Vector4.ZERO);pu.append(Vector4.ZERO);pv.append(Vector4.ZERO);pn.append(Vector4.ZERO)
	if puncture_count == 0:return
	for wound: Dictionary in wounds:
		if wound.get("puncture",false): continue
		for child in wound.node.get_children():
			if not child is MeshInstance3D:continue
			var material: Material = child.material_override
			if material is StandardMaterial3D:
				var clipped := ShaderMaterial.new();clipped.shader=CUTOUT
				clipped.set_shader_parameter("base_color",material.albedo_color)
				clipped.set_shader_parameter("base_roughness",material.roughness)
				child.material_override=clipped;material=clipped
			if material is ShaderMaterial and not puncture_materials29.has(material):puncture_materials29.append(material)
	for node: MeshInstance3D in _skin_nodes31():
		if node.mesh == null:continue
		for surface in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(surface)
			if material is ShaderMaterial and material.shader == Anatomy.CUT_SHADER and not puncture_materials29.has(material):puncture_materials29.append(material)
	for material: ShaderMaterial in puncture_materials29:
		var anatomy := material.shader == Anatomy.CUT_SHADER
		material.set_shader_parameter("puncture_count29" if anatomy else "wound_count",puncture_count)
		for pair in [["channel_origin29","wound_origin",pc],["channel_u29","wound_u",pu],["channel_v29","wound_v",pv],["channel_n29","wound_n",pn]]:
			material.set_shader_parameter(pair[0] if anatomy else pair[1],pair[2])

func _install_materials() -> void:
	var started:=_profile_start31()
	var cache:Dictionary={}
	for node:MeshInstance3D in _skin_nodes31():
		if node.mesh==null:continue
		var row:Dictionary={"node":weakref(node),"mesh":weakref(node.mesh),"generation":generation,"override":node.material_override,"surfaces":[]}
		for i in node.mesh.get_surface_count():row.surfaces.append(node.get_surface_override_material(i))
		originals.append(row)
		var active:Array[Material]=[]
		for i in node.mesh.get_surface_count():active.append(node.get_active_material(i))
		node.material_override=null
		for i in active.size():
			var original:Material=active[i]
			if original!=null and not original is StandardMaterial3D:continue
			var key:int=original.get_instance_id() if original!=null else 0
			if not cache.has(key):
				var material:=ShaderMaterial.new();material.shader=CUTOUT
				if original is StandardMaterial3D:
					material.set_shader_parameter("base_color",original.albedo_color)
					material.set_shader_parameter("base_roughness",original.roughness)
					material.set_shader_parameter("base_metallic",original.metallic)
					material.set_shader_parameter("use_vertex_color",original.vertex_color_use_as_albedo)
					material.set_shader_parameter("vertex_color_is_srgb",original.vertex_color_is_srgb)
					material.set_shader_parameter("base_uv_scale",Vector2(original.uv1_scale.x,original.uv1_scale.y))
					material.set_shader_parameter("base_uv_offset",Vector2(original.uv1_offset.x,original.uv1_offset.y))
					if original.albedo_texture!=null:
						material.set_shader_parameter("base_texture",original.albedo_texture)
						material.set_shader_parameter("has_texture",true)
				cache[key]=material;materials.append(material)
			node.set_surface_override_material(i,cache[key])
	_profile_end31("install_materials",started)

func _surface_point(point:Vector3,part:String)->Dictionary:
	var started:=_profile_start31()
	var result:Dictionary=surface_query33.nearest(host,_skin_nodes31(),point,part,Callable(self,"_triangle_point"))
	if result.get("fallback33",false):result=_surface_point_legacy33(point,part)
	_profile_end31("surface_point33",started)
	return result

func _surface_point_legacy33(point:Vector3,part:String)->Dictionary:
	var best:Dictionary={};var distance:=0.075
	for node:MeshInstance3D in _skin_nodes31():
		if node.mesh==null or not node.is_visible_in_tree():continue
		var binds:Array[Transform3D]=host.call("_cut_skin_transforms39",node)
		var relevant:Dictionary=host.call("_npc_limb_bind_ids",node,part)
		if relevant.is_empty():continue
		for surface in node.mesh.get_surface_count():
			var arrays:Array=node.mesh.surface_get_arrays(surface)
			var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			var posed:Dictionary={}
			if indices.is_empty():
				for i in points.size():indices.append(i)
			for i in range(0,indices.size(),3):
				var belongs:=false
				for corner in 3:
					for slot in 4:
						var k:int=indices[i+corner]*4+slot
						if k<weights.size() and weights[k]>0.05 and relevant.has(bones[k]):belongs=true
				if not belongs:continue
				for corner in 3:
					var vertex:int=indices[i+corner]
					if posed.has(vertex):continue
					var position:=Vector3.ZERO;var total:=0.0
					for slot in 4:
						var k:int=vertex*4+slot
						if k>=weights.size() or weights[k]<=0.0 or bones[k]<0 or bones[k]>=binds.size():continue
						position+=(binds[bones[k]]*points[vertex])*weights[k];total+=weights[k]
					posed[vertex]=node.to_global(position if total>0.0 else points[vertex])
				var a:Vector3=posed[indices[i]];var b:Vector3=posed[indices[i+1]];var c:Vector3=posed[indices[i+2]]
				var near:=_triangle_point(point,a,b,c)
				var d:=near.distance_to(point)
				if d<distance:
					var normal:Vector3=(b-a).cross(c-a).normalized()
					if normal.length_squared()<0.5:continue
					distance=d;best={"point":near,"normal":normal,"distance":d}
	return best

static func _triangle_point(p:Vector3,a:Vector3,b:Vector3,c:Vector3)->Vector3:
	var ab:=b-a;var ac:=c-a;var ap:=p-a;var d1:=ab.dot(ap);var d2:=ac.dot(ap)
	if d1<=0.0 and d2<=0.0:return a
	var bp:=p-b;var d3:=ab.dot(bp);var d4:=ac.dot(bp)
	if d3>=0.0 and d4<=d3:return b
	var vc:=d1*d4-d3*d2
	if vc<=0.0 and d1>=0.0 and d3<=0.0:return a+ab*(d1/(d1-d3))
	var cp:=p-c;var d5:=ab.dot(cp);var d6:=ac.dot(cp)
	if d6>=0.0 and d5<=d6:return c
	var vb:=d5*d2-d1*d6
	if vb<=0.0 and d2>=0.0 and d6<=0.0:return a+ac*(d2/(d2-d6))
	var va:=d3*d6-d5*d4
	if va<=0.0 and d4-d3>=0.0 and d5-d6>=0.0:return b+(c-b)*((d4-d3)/((d4-d3)+(d5-d6)))
	var denom:=va+vb+vc
	if absf(denom)<0.00000001:return a
	return a+ab*(vb/denom)+ac*(vc/denom)

func _bone_target(part:String,point:Vector3,normal:Vector3)->Vector3:
	var ends:Dictionary={"upperarm":"forearm","forearm":"hand","hand":"socket_hand","thigh":"shin","shin":"foot","head":"socket_head","chest":"neck","pelvis":"spine_01"}
	var suffix:="_l" if part.ends_with("_l") else "_r" if part.ends_with("_r") else ""
	var base:=part.trim_suffix(suffix) if not suffix.is_empty() else part
	var a:=Anatomy._point(rig,part)
	var b:=Anatomy._point(rig,str(ends.get(base,base))+suffix)
	if a.distance_squared_to(b)<0.000001:b=a+Vector3.UP*0.03
	var t:=clampf((point-a).dot(b-a)/(b-a).length_squared(),0,1)
	var center:=a.lerp(b,t)
	var radius:=0.019 if base=="upperarm" else 0.023 if base=="thigh" else 0.020 if base=="shin" else 0.011
	return center+normal*radius*0.55

static func _lens_profile28(x:float)->Vector2:
	var width:float=(1.0-x*x)*(1.0-0.055*absf(sin(x*8.0)))
	var shift:float=0.035*sin(x*9.0)*(1.0-x*x)
	return Vector2(clampf(-width*(1.0-0.03*sin(x*13.0))+shift,-1,1),clampf(width*(1.0+0.03*sin(x*11.0))+shift,-1,1))

static func _lens_ring28(half_length:float,half_width:float)->Array[Vector3]:
	var ring:Array[Vector3]=[]
	for i in 13:
		var x:=float(i)/6.0-1.0
		ring.append(Vector3(x*half_length,_lens_profile28(x).y*half_width,0))
	for i in range(11,0,-1):
		var x:=float(i)/6.0-1.0
		ring.append(Vector3(x*half_length,_lens_profile28(x).x*half_width,0))
	return ring

static func _lens_mesh28(ring:Array[Vector3],depth:float,cap:bool)->ArrayMesh:
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ring.size():
		var a:Vector3=ring[i];var b:Vector3=ring[(i+1)%ring.size()]
		var c:=b-Vector3(0,0,depth);var d:=a-Vector3(0,0,depth)
		var points:Array=[Vector3(0,0,-depth),d,c] if cap else [a,b,c,a,c,d]
		for point:Vector3 in points:
			if cap:tool.set_uv2(Vector2(point.x,point.y))
			tool.add_vertex(point)
	tool.generate_normals()
	return tool.commit()

func _exit_tree()->void:
	clear_wounds()
