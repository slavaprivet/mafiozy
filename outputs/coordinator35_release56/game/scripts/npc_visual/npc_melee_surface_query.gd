extends RefCounted
## Queries the displayed original triangles cached by the existing wound owner.
## No HP, collider, pose or mesh writes. Only active swings call this bounded query.
const Triangle = preload("res://scripts/npc_visual/npc_melee_triangle_contact.gd")
const MAX_TRIANGLES := 12000
const MAX_VERTICES := 12000
var triangles_tested := 0
var vertices_skinned := 0

static func capture_pose(cache: RefCounted) -> Dictionary:
	if cache==null or not cache._valid():return {}
	var mesh_ids: Array[int]=[]
	var mesh_frames: Array[Transform3D]=[]
	var visible: Array[bool]=[]
	for surface: Dictionary in cache._surfaces:
		var mesh: MeshInstance3D=surface.node.get_ref()
		mesh_ids.append(mesh.mesh.get_instance_id());mesh_frames.append(mesh.global_transform)
		visible.append(mesh.is_visible_in_tree())
	return {"cache_id":cache.get_instance_id(),"frame":Engine.get_physics_frames(),"rig_id":cache._rig.get_instance_id(),"rig_version":cache._rig.get_version(),"poses":cache._bone_poses(),"mesh_ids":mesh_ids,"mesh_frames":mesh_frames,"visible":visible}

func sweep(surface_cache: RefCounted, from: Vector3, to: Vector3, radius: float, confirm: Callable=Callable(), previous_pose: Dictionary={}, limb_box: AABB=AABB()) -> Dictionary:
	triangles_tested=0; vertices_skinned=0
	if surface_cache==null or not surface_cache._valid() or not from.is_finite() or not to.is_finite() or not is_finite(radius) or radius<=0.0 or radius>.5:
		return {"valid":false,"reason":"geometry_or_sweep"}
	var box:=AABB(from.min(to),from.max(to)-from.min(to)).grow(radius+.00001)
	var poses: Array[Transform3D]=surface_cache._bone_poses()
	var moving: bool=confirm.is_valid()
	# The union of the actual limb endpoint boxes encloses every linearly
	# interpolated vertex. Avoid the much larger circumscribing sphere box.
	if moving and limb_box.size.length_squared()>0.0:box=limb_box.grow(.00201)
	if moving and (previous_pose.get("cache_id")!=surface_cache.get_instance_id() or previous_pose.get("frame",-2)!=Engine.get_physics_frames()-1 or previous_pose.get("rig_id")!=surface_cache._rig.get_instance_id() or previous_pose.get("rig_version")!=surface_cache._rig.get_version()):
		return {"valid":false,"reason":"previous_target_pose"}
	var best: Dictionary={}
	var pending: Array[Dictionary]=[]
	var sweep_center: Vector3=(from+to)*.5
	for sid in surface_cache._surfaces.size():
		var surface: Dictionary=surface_cache._surfaces[sid]
		var mesh: MeshInstance3D=surface.node.get_ref()
		if not mesh.is_visible_in_tree():continue
		var matrices: Array[Transform3D]=surface_cache._matrices(surface,poses)
		var old_matrices: Array[Transform3D]=[]
		if moving:
			if previous_pose.mesh_ids.size()!=surface_cache._surfaces.size() or previous_pose.mesh_ids[sid]!=mesh.mesh.get_instance_id():return {"valid":false,"reason":"target_mesh_changed"}
			if not previous_pose.visible[sid]:continue
			old_matrices=surface_cache._matrices(surface,previous_pose.poses)
		var posed: Dictionary={}
		var old_posed: Dictionary={}
		for cluster: Dictionary in surface.clusters:
			var bounds:=AABB(); var first:=true
			for bind: int in cluster.bounds:
				var frame: Transform3D=mesh.global_transform if bind<0 else matrices[bind]
				var part: AABB=frame*cluster.bounds[bind]
				if moving:
					var old_frame: Transform3D=previous_pose.mesh_frames[sid] if bind<0 else old_matrices[bind]
					part=part.merge(old_frame*cluster.bounds[bind])
				bounds=part if first else bounds.merge(part); first=false
			if not box.intersects(bounds.grow(.00001)):continue
			var indices: PackedInt32Array=cluster.indices
			for offset in range(0,indices.size(),3):
				triangles_tested+=1
				if triangles_tested>MAX_TRIANGLES:
					var uncertainty: Dictionary={"valid":false,"reason":"triangle_budget"}
					return _confirm_candidates(surface_cache,pending,confirm,uncertainty) if moving else _incomplete_result(surface_cache,best,uncertainty)
				var face:=Vector3i(indices[offset],indices[offset+1],indices[offset+2])
				for index: int in [face.x,face.y,face.z]:
					if not posed.has(index):
						vertices_skinned+=2 if moving else 1
						if vertices_skinned>MAX_VERTICES:
							var uncertainty: Dictionary={"valid":false,"reason":"vertex_budget"}
							return _confirm_candidates(surface_cache,pending,confirm,uncertainty) if moving else _incomplete_result(surface_cache,best,uncertainty)
						posed[index]=surface_cache._vertex(surface,index,matrices)
						if moving:old_posed[index]=previous_pose.mesh_frames[sid]*surface.vertices[index] if surface.skin==null else surface_cache._vertex(surface,index,old_matrices)
				var a: Vector3=posed[face.x];var b: Vector3=posed[face.y];var c: Vector3=posed[face.z]
				var target_box:=AABB(a.min(b).min(c),a.max(b).max(c)-a.min(b).min(c))
				if moving:
					for index: int in [face.x,face.y,face.z]:target_box=target_box.expand(old_posed[index])
				if not box.intersects(target_box.grow(.00001)):continue
				# Moving targets cannot be culled against their final triangle alone.
				var hit: Dictionary={"valid":true,"hit":true,"normal":(b-a).cross(c-a).normalized()} if moving else Triangle.sample(from,to,radius,a,b,c)
				if not hit.get("valid",false):return hit
				if not hit.get("hit",false):continue
				hit.surface_index=sid;hit.face_indices=face;hit.triangle=PackedVector3Array([a,b,c])
				if moving:
					hit.previous_triangle=PackedVector3Array([old_posed[face.x],old_posed[face.y],old_posed[face.z]])
					hit.skin_material=surface.skin_material
					var center: Vector3=(a+b+c+old_posed[face.x]+old_posed[face.y]+old_posed[face.z])/6.0
					hit.order_distance=center.distance_squared_to(sweep_center)
					hit.order_index=triangles_tested
					# Bounded by the existing triangle/vertex enumeration caps.
					# Ordering only: no face is rejected by this heuristic distance.
					pending.append(hit)
					continue
				if best.is_empty() or hit.score<best.score:
					best=hit;best.surface_index=sid;best.face_indices=face
					best.barycentric=hit.weights;best.skin_material=surface.skin_material
	if moving:return _confirm_candidates(surface_cache,pending,confirm)
	if not surface_cache._valid():return {"valid":false,"reason":"geometry_changed"}
	return {"valid":true,"hit":false} if best.is_empty() else best

func _confirm_candidates(surface_cache: RefCounted,pending: Array[Dictionary],confirm: Callable,uncertainty: Dictionary={}) -> Dictionary:
	if not surface_cache._valid():return {"valid":false,"reason":"geometry_changed"}
	pending.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return int(a.order_index)<int(b.order_index) if a.order_distance==b.order_distance else float(a.order_distance)<float(b.order_distance))
	for hit: Dictionary in pending:
		var refined: Variant=confirm.call(hit)
		if not refined is Dictionary or not refined.get("valid",false):return _incomplete_result(surface_cache,{}, {"valid":false,"reason":"limb_confirmation","detail":refined})
		if not refined.get("hit",false):continue
		if refined.normal.dot(hit.normal)<0:refined.normal=-refined.normal
		refined.surface_index=hit.surface_index;refined.face_indices=hit.face_indices
		refined.barycentric=refined.weights;refined.skin_material=hit.skin_material
		# Exact proof, unchanged material anchor and final lifetime guard. Parent
		# still owns LOS/victim choice/one-HP-event. No earliest contact is claimed.
		if not surface_cache._valid():return {"valid":false,"reason":"geometry_changed"}
		refined.query_selection="first_proven_contact"
		refined.query_order="posed_centroid_near_sweep_center"
		return refined if uncertainty.is_empty() else _incomplete_result(surface_cache,refined,uncertainty)
	if not surface_cache._valid():return {"valid":false,"reason":"geometry_changed"}
	return {"valid":true,"hit":false} if uncertainty.is_empty() else uncertainty

func _incomplete_result(surface_cache: RefCounted,best: Dictionary,uncertainty: Dictionary) -> Dictionary:
	# Later uncertainty cannot erase a contact already proved on another face.
	# This is the best proved contact, not a claim to have found the earliest one.
	# Lifetime changes still invalidate every proof; absence of proof stays closed.
	if not surface_cache._valid():return {"valid":false,"reason":"geometry_changed"}
	if best.is_empty() or not best.get("valid",false) or not best.get("hit",false):return uncertainty
	if not recoverable_uncertainty(uncertainty):return uncertainty
	var result: Dictionary=best.duplicate()
	result.query_incomplete=true
	result.query_uncertainty=uncertainty.duplicate(true)
	return result

static func recoverable_uncertainty(uncertainty: Dictionary) -> bool:
	# Schema, pose identity and geometry-lifetime refusals are not budget uncertainty.
	var reason: String=str(uncertainty.get("reason",""))
	if reason=="limb_confirmation":
		var detail: Variant=uncertainty.get("detail")
		if not detail is Dictionary:return false
		if detail.get("reason")=="distance_budget_or_unresolved":
			return detail.get("first_unresolved_reason") in ["frame_chunk_budget","frame_face_budget","frame_distance_budget","candidate_distance_budget","distance_budget","unresolved_at_depth"]
		return detail.get("reason") in ["distance_budget","unresolved_at_depth"]
	return reason in ["triangle_budget","vertex_budget"]
