extends Node
## Released steel is physically welded to its actual wounded segment.
## One model, one owned collider, and one incremental mass contribution.
const Finish=preload("res://scripts/weapons/weapon_model_finish31.gd")
const Puncture=preload("res://scripts/combat/puncture29.gd")
var host_ref:WeakRef
var model:Node3D
var body:PhysicsBody3D
var joint:Generic6DOFJoint3D # Compatibility diagnostic: weld needs no joint.
var live_anchor:AnimatableBody3D
var owned_shape:CollisionShape3D
var channel:Dictionary={}
var held:=false
var active:=false
var release_reason:=""
var saved_pose:=Transform3D.IDENTITY
var bone_weapon_local:=Transform3D.IDENTITY
var grip_offset:=0.0
var support_offset:=0.0
var two_handed:=false
var tip_local:=Vector3.ZERO
var rear_extent:=0.0
var forward_extent:=0.0
var weapon_mass:=1.0
var mass_added:=0.0
var owns_body:=false
var former_holder:WeakRef
var holder_grace:=false
var holder_grace_cleared:=false
var _holder_query:=PhysicsShapeQueryParameters3D.new()

static func attachment(item:Node)->Node:
	if not is_instance_valid(item) or not item.has_meta("embedded_drop31"):return null
	var value:Node=item.get_meta("embedded_drop31")
	return value if is_instance_valid(value) else null

static func candidate(host:Node)->bool:
	var row:Dictionary=host.get_meta("puncture29_channel",{})
	var weapon:Node3D=host.get("_sword")
	return is_instance_valid(weapon) and row.get("valid",false) and row.get("active",false) and row.get("actual_hit",false) and not row.get("withdrawn",false) and float(row.get("current_depth",row.get("cut_depth",0.0)))>0.0001 and int(row.get("weapon_instance_id",-1))==weapon.get_instance_id()

func _anchor()->Transform3D:
	var ref:WeakRef=channel.get("rig_ref")
	var rig:Skeleton3D=ref.get_ref() if ref!=null else null
	var bone:=int(channel.get("bone",-1))
	if not is_instance_valid(rig) or bone<0 or bone>=rig.get_bone_count():return Transform3D(Basis.IDENTITY,Vector3.INF)
	return rig.global_transform*rig.get_bone_global_pose(bone)

func start(host:Node)->bool:
	if not candidate(host):return false
	host_ref=weakref(host);model=host.get("_sword")
	channel=Dictionary(host.get_meta("puncture29_channel")).duplicate()
	channel.active=true;channel.withdrawn=false;channel.held=false
	if not _anchor().origin.is_finite():return false
	saved_pose=model.global_transform;bone_weapon_local=_anchor().affine_inverse()*saved_pose
	tip_local=Puncture.tip_local(host)
	rear_extent=float(host.call("weapon_rear_extent"));forward_extent=.06+float(host.get("_weapon_length"))
	grip_offset=float(host.call("_grip_origin_offset"))
	two_handed=str(host.get("_weapon_id")) in ["spear","axe","sledge"] or bool(host.get("_half_sword"))
	support_offset=float(host.get("_two_hand_offset_rig"));weapon_mass=maxf(.3,float(host.get("_weapon_mass")))
	active=true;_bind(host)
	if not is_instance_valid(body):active=false;return false
	model.set_meta("embedded_drop31",self)
	set_physics_process(true);set_process(true)
	process_priority=100
	return true

func _make_shape(owner:PhysicsBody3D)->CollisionShape3D:
	var unique:Dictionary={}
	for node:Node in model.find_children("*","MeshInstance3D",true,false):
		var mesh_node:MeshInstance3D=node
		if mesh_node.mesh==null or not mesh_node.is_visible_in_tree():continue
		var relative:=owner.global_transform.affine_inverse()*mesh_node.global_transform
		for vertex:Vector3 in mesh_node.mesh.get_faces():unique[relative*vertex]=true
	if unique.size()<4:return null
	var points:=PackedVector3Array()
	for point:Vector3 in unique:points.append(point)
	var convex:=ConvexPolygonShape3D.new();convex.points=points;convex.margin=.001
	var shape:=CollisionShape3D.new();shape.name="EmbeddedWeaponHull31";shape.shape=convex
	owner.add_child(shape)
	return shape

func _bind(host:Node)->void:
	var target:RigidBody3D
	var corpse:RigidBody3D=host.get("_npc_corpse31")
	if bool(host.get("_npc_dead")) and is_instance_valid(corpse) and corpse.has_meta("ragdoll31"):
		target=corpse.get_meta("ragdoll31").body_for_bone(int(channel.bone))
	if is_instance_valid(target):
		if body==target:return
		model.reparent(host.get("_world"),true)
		_remove_native()
		body=target;owns_body=false
		model.reparent(body,true)
		owned_shape=_make_shape(body)
		body.mass+=weapon_mass;mass_added=weapon_mass
		body.sleeping=false
		return
	if not is_instance_valid(body):
		live_anchor=AnimatableBody3D.new();live_anchor.name="EmbeddedLivingSteel31"
		live_anchor.sync_to_physics=false;live_anchor.collision_layer=1;live_anchor.collision_mask=1
		var world:Node3D=host.get("_world")
		live_anchor.transform=world.global_transform.affine_inverse()*saved_pose
		world.add_child(live_anchor);body=live_anchor;owns_body=true
		model.reparent(body,true);owned_shape=_make_shape(body)
		var player:PhysicsBody3D=host.get("_player")
		if is_instance_valid(player) and bool(host.call("_self_blade_clear_at51",model.global_basis.x.normalized(),model.global_position)):
			former_holder=weakref(player);holder_grace=true
			body.add_collision_exception_with(player)
			_holder_query.exclude=[body.get_rid()];_holder_query.collision_mask=player.collision_layer
		var actor:PhysicsBody3D=host.get("_npc_body")
		if is_instance_valid(actor):body.add_collision_exception_with(actor)
		var rig:Skeleton3D=channel.rig_ref.get_ref()
		var family:=Puncture._family(str(rig.get_bone_name(int(channel.bone))).replace("spine_01","spine"))
		for hit:Node in rig.find_children("*","PhysicsBody3D",true,false):
			if hit.has_meta("sword_npc_part") and Puncture._family(str(hit.get_meta("sword_npc_part")))==family:body.add_collision_exception_with(hit)
	_update_living_pose()

func _update_living_pose()->void:
	if not owns_body or not is_instance_valid(body):return
	var pose:=(_anchor()*bone_weapon_local).orthonormalized()
	if pose.origin.is_finite() and body.global_transform!=pose:body.global_transform=pose

func _valid()->bool:
	var host:Node=host_ref.get_ref() if host_ref!=null else null
	var wound_ref:WeakRef=channel.get("node_ref")
	return is_instance_valid(host) and int(channel.get("generation",-1))==int(host.get("lab_resets")) and is_instance_valid(model) and is_instance_valid(body) and model.get_parent()==body and wound_ref!=null and is_instance_valid(wound_ref.get_ref()) and _anchor().origin.is_finite()

func _physics_process(_delta:float)->void:
	if held:return
	if not _valid():dispose("target_or_equipment_invalid");return
	_bind(host_ref.get_ref());_update_holder_grace()

func _process(_delta:float)->void:
	if active and not held and _valid():_update_living_pose()

func _update_holder_grace()->void:
	if not holder_grace or not owns_body:return
	var player:PhysicsBody3D=former_holder.get_ref() if former_holder!=null else null
	if not is_instance_valid(player):holder_grace=false;return
	if not is_instance_valid(owned_shape):return
	_holder_query.shape=owned_shape.shape;_holder_query.transform=owned_shape.global_transform
	var overlaps:=body.get_world_3d().direct_space_state.intersect_shape(_holder_query,32)
	for hit:Dictionary in overlaps:
		if hit.get("rid")==player.get_rid():return
	if overlaps.size()>=32:return
	body.remove_collision_exception_with(player);holder_grace=false;holder_grace_cleared=true

func _remove_native()->void:
	if is_instance_valid(owned_shape):owned_shape.disabled=true;owned_shape.queue_free()
	owned_shape=null
	if is_instance_valid(body):
		if body is RigidBody3D and mass_added>0.:body.mass=maxf(.1,body.mass-mass_added)
		var player:PhysicsBody3D=former_holder.get_ref() if former_holder!=null else null
		if owns_body:
			if is_instance_valid(player):body.remove_collision_exception_with(player)
			body.collision_layer=0;body.collision_mask=0
			if not is_instance_valid(model) or model.get_parent()!=body:body.queue_free()
	mass_added=0.;owns_body=false;holder_grace=false;body=null;live_anchor=null

func can_regrab(host:Node)->bool:
	if not active or not _valid():return false
	var rig:Skeleton3D=host.get("_rig")
	var axis:=model.global_basis.x.normalized()
	var grip:=model.global_position-axis*grip_offset
	# Q may currently present another weapon. Use this stored weapon's geometry,
	# with the same native head/torso clearance law, before changing selection.
	var chest:Vector3=rig.global_transform*rig.get_bone_global_pose(int(host.get("_bone_chest"))).origin
	var pelvis:Vector3=rig.global_transform*rig.get_bone_global_pose(int(host.get("_bone_pelvis"))).origin
	var head:Vector3=rig.global_transform*rig.get_bone_global_pose(int(host.get("_bone_head"))).origin
	var rear:=model.global_position-axis*rear_extent
	var tip:=model.global_position+axis*forward_extent
	if float(host.call("_segment_distance",rear,tip,chest,pelvis))<.20 or float(host.call("_segment_distance",rear,tip,head,head))<.18:return false
	for side:StringName in ([&"right",&"left"] if two_handed else [&"right"]):
		var arm:Dictionary=host.call("_arm_set",side)
		var shoulder:Vector3=rig.global_transform*rig.get_bone_global_pose(int(arm.upper)).origin
		var desired:=grip-axis*support_offset*rig.global_basis.get_scale().x if side==&"left" else grip
		var reach:float=(Transform3D(arm.rest_fore).origin.length()+Transform3D(arm.rest_hand).origin.length())*rig.global_basis.get_scale().x
		if desired.distance_to(shoulder)>reach+.04:return false
	if not _regrab_world_clear(host,axis):return false
	return true

func _regrab_world_clear(host:Node,axis:Vector3)->bool:
	# Preflight the existing held-spear world envelope before ledger mutation.
	# Only this retiring wrapper and the target owned by the exact bore solver
	# are excluded, matching the ordinary embedded held-world check.
	var player:PhysicsBody3D=host.get("_player")
	var capsule:=CapsuleShape3D.new();capsule.radius=.03;capsule.height=maxf(.06,tip_local.x)
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule
	query.transform=host.call("_blade_shape_transform",axis,model.global_position+axis*tip_local.x*.5)
	query.collision_mask=1;query.exclude=[player.get_rid(),body.get_rid()]
	var target:Node=channel.rig_ref.get_ref()
	var actor:CollisionObject3D=host.get("_npc_body")
	var corpse:CollisionObject3D=host.get("_npc_corpse31")
	var excluded:=query.exclude
	if is_instance_valid(actor):excluded.append(actor.get_rid())
	if is_instance_valid(corpse):
		excluded.append(corpse.get_rid())
		if corpse.has_meta("ragdoll31"):
			for rid:RID in corpse.get_meta("ragdoll31").physical.body_rids():
				if not excluded.has(rid):excluded.append(rid)
	query.exclude=excluded
	for hit:Dictionary in player.get_world_3d().direct_space_state.intersect_shape(query,32):
		var collider:Node=hit.get("collider")
		if is_instance_valid(target) and is_instance_valid(collider) and (collider==target or target.is_ancestor_of(collider)):continue
		return false
	return true

func prepare_regrab(host:Node)->void:
	held=true;saved_pose=model.global_transform
	# The corpse itself is never queued or disabled: only our shape/mass retire.
	model.reparent(host.get("_world"),true)
	_remove_native()
	host.set_meta("embedded_regrab31",self)

func restore(host:Node)->bool:
	if not held or not is_instance_valid(model) or host.get("_sword")!=model:return false
	var original:Dictionary=channel.duplicate();original.valid=true;original.active=true;original.withdrawn=false;original.held=true
	model.global_transform=saved_pose
	host.set_meta("puncture29_channel",original)
	host.set("_sword_origin",saved_pose.origin);host.set("_dir",saved_pose.basis.x.normalized());host.set("_edge_direction",saved_pose.basis.y.normalized());host.set("_arm_ready_ms",0)
	if str(original.weapon)=="spear":host.get("_embedded29").pose(host)
	else:
		var rig:Skeleton3D=host.get("_rig")
		var arm:Dictionary=host.call("_arm_set",&"right")
		var grip:Vector3=rig.global_transform.affine_inverse()*(saved_pose.origin-saved_pose.basis.x*grip_offset)
		var axis:Vector3=(rig.global_basis.inverse()*saved_pose.basis.x).normalized()
		host.call("_pose_arm_ik",arm.clav,arm.upper,arm.fore,arm.hand,arm.rest_upper,arm.rest_fore,arm.rest_hand,arm.offset,grip,axis,1.0,true,arm.pole)
		rig.force_update_all_bone_transforms();host.call("_place_sword",saved_pose.origin,saved_pose.basis.x)
		host.get("_sword_puncture_resistance29").adopt_regrab31(host)
	if host.has_meta("embedded_regrab31"):host.remove_meta("embedded_regrab31")
	# A safety failure may already have handed the model to a new attachment.
	# Never erase that replacement ownership while retiring this old helper.
	if model.has_meta("embedded_drop31") and model.get_meta("embedded_drop31")==self:model.remove_meta("embedded_drop31")
	active=false;release_reason="regrabbed_same_wound";queue_free()
	return true

func dispose(reason:String)->void:
	active=false;release_reason=reason
	var host:Node=host_ref.get_ref() if host_ref!=null else null
	var world:Node3D=host.get("_world") if is_instance_valid(host) else null
	if is_instance_valid(model) and is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion():
		var pose:=model.global_transform
		var velocity:=Vector3.ZERO;var angular:=Vector3.ZERO
		if body is RigidBody3D:
			angular=body.angular_velocity;velocity=body.linear_velocity+angular.cross(model.global_position-body.global_position)
		model.reparent(world,true);_remove_native()
		var free_body:=preload("res://scripts/weapons/weapon_drop_body27.gd").new()
		free_body.name="ReleasedEmbeddedSteel31";free_body.set_meta("weapon_ground_drop28",true)
		free_body.mass=weapon_mass;free_body.collision_layer=1;free_body.collision_mask=1;free_body.continuous_cd=true
		free_body.transform=world.global_transform.affine_inverse()*pose;world.add_child(free_body)
		model.reparent(free_body,true)
		var shape:=_make_shape(free_body)
		if is_instance_valid(shape):free_body.set_drop_shape27(shape)
		free_body.linear_velocity=velocity;free_body.angular_velocity=angular
	else:_remove_native()
	if is_instance_valid(model) and model.has_meta("embedded_drop31") and model.get_meta("embedded_drop31")==self:model.remove_meta("embedded_drop31")
	queue_free()

func _exit_tree()->void:
	# Teardown never creates a body. A live-world invalidation uses dispose above.
	_remove_native()

func status()->Dictionary:
	var anchor:=_anchor()
	var wound_ref:WeakRef=channel.get("node_ref")
	var wound:Node=wound_ref.get_ref() if wound_ref!=null else null
	var depth:float=((model.global_transform*tip_local)-anchor*Vector3(channel.get("entry_local",Vector3.ZERO))).dot(model.global_basis.x.normalized()) if is_instance_valid(model) and anchor.origin.is_finite() else 0.0
	return {"active":active,"held":held,"weapon_id":channel.get("weapon",""),"depth":depth,"target_id":wound.get_instance_id() if is_instance_valid(wound) else -1,"owner_body_id":body.get_instance_id() if is_instance_valid(body) else -1,"holder_grace":holder_grace,"holder_grace_cleared":holder_grace_cleared,"compound":not owns_body,"mass_added":mass_added,"reason":release_reason}
