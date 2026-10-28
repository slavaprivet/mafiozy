extends Node
## Reuse the existing native articulated body. The same wounded rig survives;
## no animation or interpolated topple drives its bones.
const Body = preload("res://scripts/npc_visual/npc_body.gd")
var host: Node
var rig: Skeleton3D
var actor: CharacterBody3D
var physical = Body.new()
var primary: RigidBody3D
var active := false
var status: Dictionary = {}
var _last_frames: Dictionary = {}
var _bones: Dictionary = {}
var _reparenting := false
var removed:Dictionary={}

func prepare(owner_host: Node) -> void:
	host=owner_host;rig=host.get("_npc_rig");actor=host.get("_npc_body")
	process_priority=-100
	set_process(false);set_physics_process(false)
	var started:=Time.get_ticks_usec()
	var result:Dictionary=physical.configure(rig,host.get("_world"),{"total_mass_kg":70.0,"collision_layer":1,"collision_mask":1})
	status={"prepared_usec":Time.get_ticks_usec()-started,"prepare":result,"active":false,"bone_writes":0,"awake":0}
	if not result.get("ok",false):return
	_refit_feet()
	primary=physical._bodies.chest
	for i in rig.get_bone_count():_bones[str(rig.get_bone_name(i))]=i
	var hits:=rig.find_children("*","CollisionObject3D",true,false)
	for body:RigidBody3D in physical.owned_bodies():
		for hit:Node in hits:
			if not hit is RigidBody3D:body.add_collision_exception_with(hit)
	primary.set_meta("ragdoll31",self)
	rig.set_meta("ragdoll31",self)

func _refit_feet() -> void:
	# A capsule enclosing a boot toe becomes a large sphere penetrating the
	# floor at activation. Use the same authored rest vertices as a convex sole.
	# All readback/hull construction is startup-only; body/bone frames stay exact.
	var points:Dictionary={"foot_l":PackedVector3Array(),"foot_r":PackedVector3Array()}
	for node:MeshInstance3D in rig.get_parent().find_children("*","MeshInstance3D",true,false):
		if node.mesh==null or node.skin==null:continue
		var names:Array[String]=[];var binds:Array[Transform3D]=[]
		for i in node.skin.get_bind_count():
			var name:=str(node.skin.get_bind_name(i))
			if name.is_empty():name=str(rig.get_bone_name(node.skin.get_bind_bone(i)))
			names.append(name);binds.append(node.skin.get_bind_pose(i))
		for surface in node.mesh.get_surface_count():
			var arrays:=node.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			if bones.size()!=vertices.size()*4:continue
			for v in vertices.size():
				var maximum:=0.0;var owner_name:=""
				for slot in 4:
					var index:=v*4+slot
					if weights[index]>maximum:maximum=weights[index];owner_name=names[bones[index]]
				if not points.has(owner_name):continue
				var world:=Vector3.ZERO
				for slot in 4:
					var index:=v*4+slot
					if weights[index]<=0:continue
					world+=Transform3D(physical._rest[names[bones[index]]])*binds[bones[index]]*vertices[v]*weights[index]
				points[owner_name].append(Transform3D(physical._rest_body[owner_name]).affine_inverse()*world)
	var report:Dictionary={}
	for key:String in points:
		if points[key].size()<4:continue
		var shape:=ConvexPolygonShape3D.new();shape.points=points[key];shape.margin=.002
		physical._shapes[key].shape=shape
		var low:=INF
		for p:Vector3 in points[key]:low=minf(low,(Transform3D(physical._rest_body[key])*p).y)
		report[key]={"vertices":points[key].size(),"rest_low_y":low}
	status.foot_support=report

func start(life_id: int,point: Vector3,direction: Vector3,speed: float) -> bool:
	host.set("_npc_corpse_pending31",false)
	if active or not is_instance_valid(primary) or not is_instance_valid(actor) or actor.get_instance_id()!=life_id or not bool(host.get("_npc_dead")):return false
	var started:=Time.get_ticks_usec()
	var frames:Dictionary=physical.capture_world_frames()
	# The pool is a world sibling: rigid descendants of a moving skeleton wake
	# on inherited transform notifications even beneath a top-level node.
	var actor_parent:=actor.get_parent()
	_reparenting=true
	primary.global_transform=frames.chest*physical._bone_to_body.chest
	primary.reparent(host.get("_world"),true)
	actor.reparent(primary,true)
	var result:Dictionary=physical.start(frames,actor.velocity)
	status.start=result
	if not result.get("ok",false):
		actor.reparent(actor_parent,true)
		primary.reparent(physical._root,true)
		_reparenting=false
		return false
	_reparenting=false
	# Fallback reconciliation for cuts committed before this adapter received
	# an explicit on_cut hook. Direct limb markers retain their proximal stump.
	for part:String in host.get("_npc_severed"):
		_mark_cut31(part,{},part=="head")
	_apply_removed31()
	actor.collision_layer=0;actor.collision_mask=0
	var hull:CollisionShape3D=host.get("_npc_hull31")
	if is_instance_valid(hull):hull.disabled=true
	var dropped:RigidBody3D=host.get("_npc_dropped_sword31")
	for body:RigidBody3D in physical.owned_bodies():
		if is_instance_valid(dropped):body.add_collision_exception_with(dropped)
	host.set("_npc_corpse31",primary);host.set("_npc_hit_push31",Vector3.ZERO)
	active=true;status.active=true
	set_process(true);set_physics_process(true)
	impact(point,direction,maxf(0.0,speed)*maxf(0.1,float(host.get("_weapon_mass"))))
	_sync()
	status.activation_usec=Time.get_ticks_usec()-started
	return true

func on_cut(part:String,branches:Dictionary,head_gone:bool)->void:
	_mark_cut31(part,branches,head_gone)
	if active:_apply_removed31()

func _descendant31(name:String,ancestor:String)->bool:
	var index:int=rig.find_bone(name)
	while index>=0:
		if str(rig.get_bone_name(index))==ancestor:return true
		index=rig.get_bone_parent(index)
	return false

func _mark_cut31(part:String,branches:Dictionary,head_gone:bool)->void:
	for key:String in physical.BODY_NAMES:
		if head_gone and key=="head":removed[key]=true
		# The directly cut segment retains a real proximal stump. Only its
		# strict descendants have entirely moved to the detached mesh body.
		if part not in ["head","chest","pelvis"] and key!=part and _descendant31(key,part):removed[key]=true
		for branch:String in branches:
			if branches[branch] and _descendant31(key,branch):removed[key]=true

func _apply_removed31()->void:
	for row:Dictionary in physical._joints:
		if removed.has(row.parent) or removed.has(row.child):
			row.node.node_a=NodePath("");row.node.node_b=NodePath("")
	var mass:=0.0
	for key:String in physical.BODY_NAMES:
		var body:RigidBody3D=physical._bodies[key]
		if removed.has(key):
			body.set_meta("ragdoll_removed31",true)
			body.collision_layer=0;body.collision_mask=0
			physical._shapes[key].disabled=true
			body.freeze=true;body.sleeping=true
			body.linear_velocity=Vector3.ZERO;body.angular_velocity=Vector3.ZERO
		else:mass+=body.mass
	status.removed=removed.keys();status.retained_mass_kg=mass
	status.active_bodies=physical.BODY_NAMES.size()-removed.size()

func body_for_bone(bone: int) -> RigidBody3D:
	if not is_instance_valid(rig) or bone<0:return primary
	var key:String=physical._bone_owner.get(str(rig.get_bone_name(bone)),"chest")
	if removed.has(key):return primary
	return physical._bodies.get(key,primary)

func impact(point: Vector3,direction: Vector3,impulse_ns: float) -> void:
	if not active or not point.is_finite() or not direction.is_finite() or direction.length_squared()<1e-12:return
	var impulse:=direction.normalized()*clampf(impulse_ns,0.0,120.0)
	# Overlapping fitted chest/head proxies can both contain a neck impact.
	# Resolve that tie by the actual closest segment centre, not array order.
	var selected:RigidBody3D=primary
	var distance:=INF
	for body:RigidBody3D in physical.owned_bodies():
		if body.get_meta("ragdoll_removed31",false):continue
		var next:=body.global_position.distance_squared_to(point)
		if next<distance:selected=body;distance=next
	selected.sleeping=false
	selected.apply_impulse(impulse,point-selected.global_position)
	status.last_impulse={"ok":true,"bone":str(selected.name),"impulse":impulse,"point":point}

func _process(_delta: float) -> void:_sync()
func _physics_process(_delta: float) -> void:_sync()

func _sync() -> void:
	if not active or not is_instance_valid(rig):return
	var awake:=0
	for body:RigidBody3D in physical.owned_bodies():
		if not body.get_meta("ragdoll_removed31",false) and not body.sleeping:awake+=1
	status.awake=awake
	if awake==0:return
	var inverse:=rig.global_transform.affine_inverse()
	# Do not call diagnostic snapshot: its contact/inertia enumeration is not
	# needed to copy sixteen native transforms into the existing skin.
	var frames:Dictionary={}
	for key:String in physical.BODY_NAMES:
		if removed.has(key):
			var index:int=physical.BODY_NAMES.find(key)
			var parent:String=physical.PARENTS[index]
			frames[key]=Transform3D(frames[parent])*Transform3D(physical._initial[parent]).affine_inverse()*physical._initial[key]
		else:frames[key]=physical._bodies[key].global_transform*physical._body_to_bone[key]
	for name:String in physical._bones:
		if not frames.has(name):
			var owner_name:String=physical._bone_owner[name]
			frames[name]=frames[owner_name]*Transform3D(physical._initial[owner_name]).affine_inverse()*physical._initial[name]
		var bone:int=_bones[name]
		var pose:Transform3D=inverse*Transform3D(frames[name])
		if _last_frames.get(bone,Transform3D())==pose:continue
		rig.set_bone_global_pose_override(bone,pose,1.0,true)
		_last_frames[bone]=pose;status.bone_writes=int(status.bone_writes)+1
	rig.force_update_all_bone_transforms()

func _exit_tree() -> void:
	if _reparenting:return
	if is_instance_valid(physical._root):physical._root.queue_free()
