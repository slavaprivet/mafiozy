extends RefCounted
## Native reaction prevents other corpse segments from falling through held steel.
## The pierced family remains owned by the exact finite bore/contact solver.
const LAYER := 1 << 22
const Puncture = preload("res://scripts/combat/puncture29.gd")
var body: AnimatableBody3D
var shape_node: CollisionShape3D
var identity := 0
var shapes: Dictionary = {}
var exclusions: Dictionary = {}
var ragdoll_identity := 0

func update(host: Node) -> void:
	var weapon: Node3D = host.get("_sword")
	if not is_instance_valid(weapon):return
	if not is_instance_valid(body):
		body=AnimatableBody3D.new();body.name="HeldSteel31"
		body.collision_layer=0;body.collision_mask=0;body.sync_to_physics=false
		host.add_child(body);body.top_level=true
		shape_node=CollisionShape3D.new();body.add_child(shape_node)
	var enabled:bool=host.get("_selected") and not host.get("_sword_grounded") and not host.get("_unarmed") and str(host.get("_weapon_id")) in ["sword","spear","axe","sledge","mace"]
	if not enabled:body.collision_layer=0;return
	if identity!=weapon.get_instance_id():
		if host.get("_solid_weapon29")._sample_identity!=weapon.get_instance_id():body.collision_layer=0;return
		identity=weapon.get_instance_id()
		var key:String=str(host.get("_weapon_id"))
		if not shapes.has(key):
			var points:=PackedVector3Array()
			for row:Dictionary in host.get("_solid_weapon29")._samples:points.append(row.local)
			if points.size()<4:body.collision_layer=0;identity=0;return
			var convex:=ConvexPolygonShape3D.new();convex.points=points;convex.margin=.001
			shapes[key]=convex
		shape_node.shape=shapes[key]
	if body.global_transform!=weapon.global_transform:body.global_transform=weapon.global_transform
	if body.collision_layer!=LAYER:body.collision_layer=LAYER
	var ragdoll=host.get("_deep_collapse29").ragdoll
	if not is_instance_valid(ragdoll) or not ragdoll.active:return
	if ragdoll_identity!=ragdoll.get_instance_id():
		ragdoll_identity=ragdoll.get_instance_id()
		for ref:WeakRef in exclusions.values():
			var old=ref.get_ref()
			if is_instance_valid(old):body.remove_collision_exception_with(old)
		exclusions.clear()
	var channel:Dictionary=host.get_meta("puncture29_channel",{})
	var family:=""
	if channel.get("valid",false) and channel.get("active",false) and float(channel.get("cut_depth",0))>0.0 and int(channel.get("weapon_instance_id",-1))==identity:
		var bone:=int(channel.get("bone",-1))
		if bone>=0:family=Puncture._family(str(ragdoll.rig.get_bone_name(bone)).replace("spine_01","spine"))
	for segment:RigidBody3D in ragdoll.physical.owned_bodies():
		if bool(segment.get_meta("ragdoll_removed31",false)):continue
		if segment.collision_mask&LAYER==0:segment.collision_mask|=LAYER
		var skip:bool=not family.is_empty() and family==Puncture._family(str(segment.name).replace("spine_01","spine"))
		var id:=segment.get_instance_id()
		if skip and not exclusions.has(id):body.add_collision_exception_with(segment);exclusions[id]=weakref(segment)
		elif not skip and exclusions.has(id):body.remove_collision_exception_with(segment);exclusions.erase(id)
