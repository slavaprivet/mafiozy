extends RefCounted
## The laboratory actor shares the exact posed skin used by melee. Native
## world hits remain authoritative in front of it; no movement capsule or
## ragdoll shell can impersonate a tissue surface.
var _rig_id := 0
var _parts: Dictionary = {}
var _proxies: Array[WeakRef] = []

func _prepare(host: Node) -> Skeleton3D:
	var rig:Skeleton3D=host.get("_npc_rig")
	if not is_instance_valid(rig):return null
	if rig.get_instance_id()!=_rig_id:
		_rig_id=rig.get_instance_id();_parts.clear();_proxies.clear()
		for node:Node in rig.find_children("*","CollisionObject3D",true,false):
			if node.has_meta("sword_npc_part"):
				_parts[str(node.get_meta("sword_npc_part"))]=weakref(node)
				_proxies.append(weakref(node))
	return rig

func ray(host: Node, space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int, excluded: Array[RID]) -> Dictionary:
	var rig:=_prepare(host)
	var solid:RefCounted=host.get("_solid_weapon29")
	if not is_instance_valid(rig) or solid==null or not solid.has_method("skin_hits"):return {"supported":false}
	var omit:Array[RID]=excluded.duplicate()
	for ref:WeakRef in _proxies:
		var proxy:CollisionObject3D=ref.get_ref()
		if is_instance_valid(proxy):omit.append(proxy.get_rid())
	var corpse:CollisionObject3D=host.get("_npc_corpse31")
	if is_instance_valid(corpse) and corpse.has_meta("ragdoll31"):
		for rid:RID in corpse.get_meta("ragdoll31").physical.body_rids():
			if not omit.has(rid):omit.append(rid)
	var query:=PhysicsRayQueryParameters3D.create(from,to,mask,omit)
	query.hit_from_inside=true
	var world_hit:=space.intersect_ray(query)
	var end:Vector3=world_hit.position if not world_hit.is_empty() else to
	var hits:Array[Dictionary]=solid.skin_hits(host,from,end,"")
	if hits.is_empty():return {"supported":true,"hit":world_hit}
	var first:Dictionary=hits[0]
	var bone:=int(first.bone)
	if bone<0 or bone>=rig.get_bone_count():
		# An unbound cap still stops the projectile, but cannot name a tissue
		# part or receive bone damage by guessing an index.
		return {"supported":true,"hit":{"position":first.point,"normal":first.normal,"collider":null,"unbound_surface31":true}}
	var part:=str(rig.get_bone_name(bone))
	if part.begins_with("spine"):part="chest"
	if part=="neck":part="head"
	var part_ref:WeakRef=_parts.get(part)
	var collider:Node=part_ref.get_ref() if part_ref!=null else host.get("_npc_body")
	return {"supported":true,"hit":{"position":first.point,"normal":first.normal,"collider":collider,"actual_skin31":true,"part31":part,"bone31":bone,"rig31":weakref(rig)}}

func embed_depth(host: Node, hit: Dictionary, direction: Vector3, requested: float) -> float:
	if not bool(hit.get("actual_skin31",false)):return requested
	# A thin limb must not acquire the old unconditional ten-centimetre hole.
	# The next real surface bounds finite insertion; no through-shot is invented.
	var point:Vector3=hit.position
	var start:=point+direction*.001
	var hits:Array[Dictionary]=host.get("_solid_weapon29").skin_hits(host,start,point+direction*maxf(.25,requested+.01),str(hit.part31))
	for row:Dictionary in hits:
		var distance:float=(Vector3(row.point)-point).dot(direction)
		if distance>.003:return minf(requested,maxf(.001,distance-.001))
	return requested

func follow(entry: Dictionary, node: Node3D) -> void:
	var ref:WeakRef=entry.get("skin_rig31")
	var rig:Skeleton3D=ref.get_ref() if ref!=null else null
	var bone:=int(entry.get("skin_bone31",-1))
	if not is_instance_valid(rig) or bone<0 or bone>=rig.get_bone_count():return
	node.global_transform=rig.global_transform*rig.get_bone_global_pose(bone)*Transform3D(entry.skin_local31)

func contact_guard(hit: Dictionary, result: Dictionary) -> Dictionary:
	var point:Vector3=hit.position
	if bool(hit.get("actual_skin31",false)):
		var rig:Skeleton3D=hit.rig31.get_ref()
		var frame:Transform3D=rig.global_transform*rig.get_bone_global_pose(int(hit.bone31))
		return {"rig":hit.rig31,"bone":hit.bone31,"local":frame.affine_inverse()*point,"result":result}
	var collider:Node3D=hit.get("collider") as Node3D
	return {"collider":weakref(collider) if is_instance_valid(collider) else null,"local":collider.to_local(point) if is_instance_valid(collider) else point,"result":result}

func guard_point(guard: Dictionary) -> Vector3:
	var ref:WeakRef=guard.get("rig")
	if ref!=null:
		var rig:Skeleton3D=ref.get_ref()
		if not is_instance_valid(rig):return Vector3.INF
		return rig.global_transform*rig.get_bone_global_pose(int(guard.bone))*Vector3(guard.local)
	ref=guard.get("collider")
	var collider:Node3D=ref.get_ref() if ref!=null else null
	return collider.to_global(guard.local) if is_instance_valid(collider) else Vector3(guard.local)

func same_guard(guard: Dictionary, hit: Dictionary) -> bool:
	if guard.is_empty() or guard_point(guard).distance_to(hit.position)>.03:return false
	var ref:WeakRef=guard.get("rig")
	if ref!=null:
		return bool(hit.get("actual_skin31",false)) and ref.get_ref()==hit.rig31.get_ref() and int(guard.bone)==int(hit.bone31)
	ref=guard.get("collider")
	return ref!=null and ref.get_ref()==hit.get("collider")

func detached_by_cut(entry: Dictionary, rig: Skeleton3D, cut: Dictionary) -> bool:
	var bone:=int(entry.get("skin_bone31",-1))
	var poses:Array=cut.get("bone_poses31",[])
	if bone<0 or bone>=poses.size() or not entry.has("skin_hit_local31"):return false
	var scope:=str(cut.get("scope",""))
	if scope=="_clay_torso":
		var branches:Dictionary=cut.get("branches31",{})
		for branch:String in branches:
			var root:=rig.find_bone(branch)
			if root>=0 and _descendant(rig,bone,root):return bool(branches[branch])
	else:
		var root:=rig.find_bone(scope)
		if root<0 or not _descendant(rig,bone,root):return false
	var point:Vector3=Transform3D(cut.rig_snapshot31)*Transform3D(poses[bone])*Vector3(entry.skin_hit_local31)
	var plane:Plane=cut.plane
	var distance:=plane.distance_to(point)
	if absf(distance)<.000001:return false
	return (distance>=0.0)!=(plane.distance_to(Vector3(cut.keep))>=0.0)

func _descendant(rig: Skeleton3D, bone: int, ancestor: int) -> bool:
	while bone>=0:
		if bone==ancestor:return true
		bone=rig.get_bone_parent(bone)
	return false
