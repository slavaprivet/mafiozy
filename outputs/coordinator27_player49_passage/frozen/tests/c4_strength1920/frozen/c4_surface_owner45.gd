extends RefCounted
## Any live physical scenery in this world, including static panes and ground.
## Characters/corpses are occluders, never placement surfaces. No scene mutation.
const MAX_ANCESTORS := 64

static func resolve(body: Variant, world: Node3D, actor: CharacterBody3D) -> Node3D:
	if not is_instance_valid(body) or not body is PhysicsBody3D or body is CharacterBody3D: return null
	if not body.is_inside_tree() or body.is_queued_for_deletion() or body.collision_layer==0 or body.get_meta("fracture_active",false): return null
	if not body.global_transform.is_finite() or absf(body.global_basis.determinant())<.000001: return null
	if not is_instance_valid(world) or not world.is_inside_tree() or world.is_queued_for_deletion() or not world.is_ancestor_of(body): return null
	if not is_instance_valid(actor) or body==actor or actor.is_ancestor_of(body): return null
	if body.has_meta("ragdoll_bone") or body.has_meta("actor_id"): return null
	if body.has_meta("c4_surface_visual"):
		var reference: Variant=body.get_meta("c4_surface_visual")
		if not reference is WeakRef: return null
		var visual: Variant=reference.get_ref()
		if not is_instance_valid(visual) or not visual is Node3D or not visual.is_visible_in_tree(): return null
	var node: Node=body.get_parent()
	var site_owner: Node3D=null
	for depth: int in MAX_ANCESTORS:
		if not is_instance_valid(node) or node.is_queued_for_deletion(): return null
		if node==world: return site_owner if site_owner!=null else world
		if node is Skeleton3D or node is CharacterBody3D or node.has_meta("actor_id") or node.has_meta("ragdoll_bone"): return null
		if node.has_method("validate_pane_contact") and node.has_method("owns_collider"):
			# Actual OwnedWindowGlazing is a helper, not a building site. Its native
			# ownership checks validate pane identity/frame and helper generation.
			if not node.owns_collider(body): return null
		elif site_owner==null and node is Node3D and node.has_method("owns_collider") and node.get("site_ready") is bool:
			if node.get("site_ready")!=true or node.get("rebuilding")==true: return null
			# Collapse is persistent until reset; it does not retire living rubble
			# or the static ground. Active fracture parents were rejected above.
			if node.get("collapsing")==true and body is RigidBody3D and not node.owns_collider(body): return null
			site_owner=node
		node=node.get_parent()
	return null

static func source_id(body: PhysicsBody3D, owner: Node3D, world: Node3D) -> String:
	if owner!=world: return str(owner.get("source_id"))
	if body.has_meta("vehicle_id"): return "VEHICLE:"+str(body.get_meta("vehicle_id"))
	var node: Node=body
	for depth: int in MAX_ANCESTORS:
		if node==null or node==world: break
		var id: String=str(node.get_meta("source_id",""))
		if not id.is_empty(): return id
		node=node.get_parent()
	return "MAP-SURFACE:"+str(body.get_instance_id())

static func generation(owner: Node3D, world: Node3D) -> int:
	return int(owner.get("rebuild_generation")) if owner!=world else -1

static func contact_current(body: PhysicsBody3D, point: Vector3, world: Node3D) -> bool:
	var node: Node=body.get_parent()
	for depth: int in MAX_ANCESTORS:
		if not is_instance_valid(node): return false
		if node==world: return true
		if node.has_method("validate_pane_contact"):
			var result: Variant=node.validate_pane_contact(body,point)
			if not result is Dictionary or not result.get("ok",false): return false
		node=node.get_parent()
	return false

static func capture_shape(body: PhysicsBody3D, shape_index: int) -> Dictionary:
	if shape_index<0: return {}
	var owner_id: int=body.shape_find_owner(shape_index)
	if not body.get_shape_owners().has(owner_id) or body.is_shape_owner_disabled(owner_id): return {}
	var count: int=body.shape_owner_get_shape_count(owner_id)
	if count>64: return {}
	for local_index: int in count:
		if body.shape_owner_get_shape_index(owner_id,local_index)!=shape_index: continue
		var shape: Shape3D=body.shape_owner_get_shape(owner_id,local_index)
		if not is_instance_valid(shape): return {}
		return {"owner_id":owner_id,"local_index":local_index,"shape":weakref(shape),"transform":body.shape_owner_get_transform(owner_id)}
	return {}

static func shape_current(body: PhysicsBody3D, binding: Dictionary) -> bool:
	if binding.is_empty() or not body.get_shape_owners().has(binding.owner_id) or body.is_shape_owner_disabled(binding.owner_id): return false
	if body.shape_owner_get_shape_count(binding.owner_id)<=int(binding.local_index) or body.shape_owner_get_transform(binding.owner_id)!=binding.transform: return false
	var shape: Variant=binding.shape.get_ref()
	return is_instance_valid(shape) and body.shape_owner_get_shape(binding.owner_id,binding.local_index)==shape

static func world_normal(body: PhysicsBody3D, local_normal: Vector3) -> Vector3:
	# Normals are covectors. Inverse transpose also handles scaled static props.
	return (body.global_basis.inverse().transposed()*local_normal).normalized()
