extends RefCounted
## Physical wreck debris only. Damage, blast choice and launch RNG stay with host.
## Candidate: ArrayMesh surface data is duplicated once without recursively
## duplicating nested material Resources. The existing loop below still creates
## one explicit private active-material copy for every surface.
const MAX_ASSEMBLIES := 10
const MAX_VERTICES := 2_000_000
static var _mesh_resource_property_names: Array[StringName]=[]

var _vehicle_root: Node3D
var _debris_parent: Node3D
var _entries: Array = []
var _bodies: Array[RigidBody3D] = []
var _prewarm_cursor := 0
var _prewarm_hull_cursor := 0
var _prewarm_frame := -1
var _ready := false
var _owner: CollisionObject3D
var _launched := false
var _disposed := false

## ordered rows: {source, mass_kg, collision_layer/mask, linear/angular_damp,
## friction, bounce}. These physical values are caller authority.
## The first ten rows are the source explosion pool. All geometry is prepared here.
func configure(vehicle_root: Node3D, debris_parent: Node3D, ordered: Array, owner: CollisionObject3D = null) -> Dictionary:
	if _disposed or _vehicle_root != null: return {"ok":false,"error":"already_configured"}
	if not is_instance_valid(vehicle_root) or not is_instance_valid(debris_parent) or not vehicle_root.is_inside_tree() or not debris_parent.is_inside_tree():
		return {"ok":false,"error":"missing_tree"}
	if absf(vehicle_root.global_transform.basis.determinant()) < .000001 or absf(debris_parent.global_transform.basis.determinant()) < .000001:
		return {"ok":false,"error":"singular_transform"}
	if ordered.is_empty(): return {"ok":false,"error":"assemblies"}
	if owner != null and (not is_instance_valid(owner) or not owner.is_inside_tree()): return {"ok":false,"error":"owner"}
	var staged: Array = []
	var seen: Dictionary = {}
	var vertex_count := 0
	for i in mini(ordered.size(), MAX_ASSEMBLIES):
		var row: Variant = ordered[i]
		if not row is Dictionary:
			_free_staged(staged); return {"ok":false,"error":"assembly_row"}
		var source := row.get("source") as Node3D
		var mass := float(row.get("mass_kg", NAN))
		var layer: Variant = row.get("collision_layer")
		var mask: Variant = row.get("collision_mask")
		var linear_damp := float(row.get("linear_damp",NAN))
		var angular_damp := float(row.get("angular_damp",NAN))
		var friction := float(row.get("friction",NAN))
		var bounce := float(row.get("bounce",NAN))
		if not is_instance_valid(source) or not source.is_inside_tree() or source == vehicle_root or not vehicle_root.is_ancestor_of(source) or seen.has(source):
			_free_staged(staged); return {"ok":false,"error":"assembly_source"}
		for prior in seen:
			if source.is_ancestor_of(prior) or prior.is_ancestor_of(source):
				_free_staged(staged); return {"ok":false,"error":"assembly_overlap"}
		if not is_finite(mass) or mass <= 0.0 or not layer is int or not mask is int or layer < 0 or mask < 0 or not is_finite(linear_damp) or linear_damp < 0.0 or not is_finite(angular_damp) or angular_damp < 0.0 or not is_finite(friction) or friction < 0.0 or friction > 1.0 or not is_finite(bounce) or bounce < 0.0 or bounce > 1.0:
			_free_staged(staged); return {"ok":false,"error":"physics_contract"}
		seen[source] = true
		var copied := _copy_subtree(source, true)
		if not copied.ok:
			_free_staged(staged); return {"ok":false,"error":copied.error}
		var hulls: Array = []
		var bindings: Array = []
		var states: Array = []
		var inverse := source.global_transform.affine_inverse()
		var rigid_basis := Basis(source.global_transform.basis.get_rotation_quaternion())
		var bake_basis := rigid_basis.inverse() * source.global_transform.basis
		var state_stack: Array[Node] = [source]
		while not state_stack.is_empty():
			var state_node: Node = state_stack.pop_back()
			if state_node is Node3D:
				states.append({"node":state_node,"parent":state_node.get_parent(),"visible":state_node.visible,"transform":state_node.transform,"mesh":state_node.mesh if state_node is MeshInstance3D else null})
			for child: Node in state_node.get_children(): state_stack.append(child)
		var stack: Array[Node] = [source]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			if node is Node3D and not node.visible: continue
			if node is MeshInstance3D:
				if not _opaque_mesh(node): continue
				bindings.append({"node":node,"mesh":node.mesh})
				var points := PackedVector3Array()
				var relative: Transform3D = inverse * node.global_transform
				for surface in node.mesh.get_surface_count():
					var arrays: Array = node.mesh.surface_get_arrays(surface)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					vertex_count += vertices.size()
					if vertex_count > MAX_VERTICES:
						copied.node.free(); _free_staged(staged); return {"ok":false,"error":"vertex_limit"}
					for vertex in vertices:
						var point: Vector3 = bake_basis * (relative * vertex)
						if not point.is_finite():
							copied.node.free(); _free_staged(staged); return {"ok":false,"error":"geometry_nonfinite"}
						points.append(point)
				if points.size() >= 4:
					var shape := ConvexPolygonShape3D.new()
					shape.points = points
					hulls.append(shape)
			for child: Node in node.get_children(): stack.append(child)
		if hulls.is_empty():
			copied.node.free(); _free_staged(staged); return {"ok":false,"error":"assembly_geometry"}
		var body := RigidBody3D.new()
		body.name = "Vehicle_debris_" + str(i) + "_" + String(source.name)
		body.mass = mass
		body.collision_layer = 0
		body.collision_mask = 0
		body.can_sleep = true
		body.linear_damp = linear_damp
		body.angular_damp = angular_damp
		var physics_material:=PhysicsMaterial.new(); physics_material.friction=friction; physics_material.bounce=bounce
		body.physics_material_override=physics_material
		body.freeze = true
		copied.node.visible = false
		body.add_child(copied.node)
		var collisions: Array[CollisionShape3D]=[]
		for hull: ConvexPolygonShape3D in hulls:
			var collision := CollisionShape3D.new(); collision.shape=hull; collisions.append(collision)
		body.set_meta("source_assembly",String(source.name)); body.set_meta("assembly_index",i)
		staged.append({"source":source,"template":copied.node,"body":body,"collisions":collisions,"hulls":hulls,"bindings":bindings,"states":states,"node_count":states.size(),"bake_basis":bake_basis,"mass":mass,"layer":layer,"mask":mask,"visible":true})
	_vehicle_root = vehicle_root
	_debris_parent = debris_parent
	_owner = owner
	_entries = staged
	return {"ok":true,"assemblies":_entries.size(),"hulls":_hull_count(),"vertices":vertex_count,"capped":ordered.size()>MAX_ASSEMBLIES}

## Register a bounded number of complete frozen bodies outside the impact frame.
## Call again on a later physics frame after the cursor completes to obtain READY.
func prewarm_step(budget: int = 1) -> Dictionary:
	if _disposed or _vehicle_root == null: return {"ok":false,"error":"not_configured"}
	if _launched: return {"ok":false,"error":"already_launched"}
	if budget < 1 or budget > MAX_ASSEMBLIES: return {"ok":false,"error":"budget"}
	if not is_instance_valid(_debris_parent) or not _debris_parent.is_inside_tree(): return {"ok":false,"error":"missing_tree"}
	var added := 0
	while _prewarm_cursor < _entries.size() and added < budget:
		var entry: Dictionary = _entries[_prewarm_cursor]
		var body: RigidBody3D = entry.body
		if body.get_parent()==null:
			_debris_parent.add_child(body)
			var source_transform: Transform3D = entry.source.global_transform
			body.global_transform=Transform3D(Basis(source_transform.basis.get_rotation_quaternion()),source_transform.origin)
			if _owner != null: body.add_collision_exception_with(_owner)
			body.sleeping=true; added+=1; _prewarm_frame=Engine.get_physics_frames()
		elif _prewarm_hull_cursor < entry.collisions.size():
			body.add_child(entry.collisions[_prewarm_hull_cursor]); _prewarm_hull_cursor+=1; added+=1; _prewarm_frame=Engine.get_physics_frames()
		else:
			_prewarm_cursor+=1; _prewarm_hull_cursor=0
	if _prewarm_cursor == _entries.size() and Engine.get_physics_frames() > _prewarm_frame: _ready=true
	return {"ok":true,"state":"READY" if _ready else "WARMING","ready":_ready,"added":added,"prepared":_prewarm_cursor,"total":_entries.size()}

## motions are host-authoritative {linear_velocity: Vector3, angular_velocity: Vector3}.
func launch(motions: Array) -> Dictionary:
	if _disposed or _vehicle_root == null: return {"ok":false,"error":"not_configured"}
	if _launched: return {"ok":false,"error":"already_launched"}
	if not _ready: return {"ok":false,"error":"PREWARM_PENDING"}
	if not is_instance_valid(_debris_parent) or not _debris_parent.is_inside_tree() or motions.size() != _entries.size():
		return {"ok":false,"error":"launch_contract"}
	if _owner != null and (not is_instance_valid(_owner) or not _owner.is_inside_tree()): return {"ok":false,"error":"owner_changed"}
	# Validate the entire launch before moving any prepared visual or hiding a source.
	for i in _entries.size():
		var motion: Variant = motions[i]
		if not motion is Dictionary or not motion.get("linear_velocity") is Vector3 or not motion.get("angular_velocity") is Vector3:
			return {"ok":false,"error":"launch_motion"}
		var linear: Vector3 = motion.linear_velocity
		var angular: Vector3 = motion.angular_velocity
		if not linear.is_finite() or not angular.is_finite():
			return {"ok":false,"error":"launch_nonfinite"}
		var entry: Dictionary = _entries[i]
		var source: Node3D = entry.source
		if not is_instance_valid(entry.body) or entry.body.get_parent()!=_debris_parent or entry.body.get_child_count()!=entry.collisions.size()+1:
			return {"ok":false,"error":"prepared_body_changed"}
		if not is_instance_valid(source) or not source.is_inside_tree() or not _vehicle_root.is_ancestor_of(source) or not source.visible:
			return {"ok":false,"error":"source_changed"}
		var current_rigid := Basis(source.global_transform.basis.get_rotation_quaternion())
		var current_bake := current_rigid.inverse() * source.global_transform.basis
		if not current_bake.is_equal_approx(entry.bake_basis):
			return {"ok":false,"error":"source_scale_changed"}
		if _descendant_node_count(source) != entry.node_count: return {"ok":false,"error":"hierarchy_changed"}
		for state: Dictionary in entry.states:
			var state_node := state.node as Node3D
			if not is_instance_valid(state_node) or state_node.get_parent() != state.parent or state_node.visible != state.visible:
				return {"ok":false,"error":"hierarchy_changed"}
			if state_node != source and not state_node.transform.is_equal_approx(state.transform): return {"ok":false,"error":"assembly_pose_changed"}
			if state_node is MeshInstance3D and state_node.mesh != state.mesh:
				return {"ok":false,"error":"geometry_changed"}
		for binding: Dictionary in entry.bindings:
			var mesh_node := binding.node as MeshInstance3D
			if not is_instance_valid(mesh_node) or mesh_node.mesh != binding.mesh or not (mesh_node == source or source.is_ancestor_of(mesh_node)):
				return {"ok":false,"error":"geometry_changed"}
	var staged: Array[RigidBody3D] = []
	for i in _entries.size():
		var motion: Dictionary = motions[i]
		var linear: Vector3 = motion.linear_velocity
		var angular: Vector3 = motion.angular_velocity
		var entry: Dictionary = _entries[i]
		var body: RigidBody3D = entry.body
		var visual: Node3D = entry.template
		body.set_meta("launch_linear_velocity", linear)
		body.set_meta("launch_angular_velocity", angular)
		staged.append(body)
	# No source visibility or scene-tree mutation occurs before every row validates.
	for i in staged.size():
		var body := staged[i]
		var entry: Dictionary = _entries[i]
		entry.visible = entry.source.visible
		var source_transform: Transform3D = entry.source.global_transform
		body.global_transform = Transform3D(Basis(source_transform.basis.get_rotation_quaternion()),source_transform.origin)
		entry.template.transform=Transform3D(entry.bake_basis,Vector3.ZERO)
		entry.template.visible=true
		body.collision_layer=entry.layer; body.collision_mask=entry.mask
		body.freeze=false; body.sleeping=false
		body.linear_velocity = body.get_meta("launch_linear_velocity")
		body.angular_velocity = body.get_meta("launch_angular_velocity")
		entry.source.visible = false
	_bodies = staged
	_launched = true
	return {"ok":true,"bodies":_bodies.size(),"hulls":_hull_count()}

func bodies() -> Array[RigidBody3D]:
	return _bodies.duplicate()

func reset() -> void:
	for i in _entries.size():
		var entry: Dictionary = _entries[i]
		if _launched and is_instance_valid(entry.source): entry.source.visible = entry.visible
		if is_instance_valid(entry.body):
			entry.body.freeze=true; entry.body.sleeping=true; entry.body.collision_layer=0; entry.body.collision_mask=0
			entry.template.visible=false
	_bodies.clear()
	_launched = false

func dispose() -> void:
	if _disposed: return
	reset()
	for entry: Dictionary in _entries:
		for collision in entry.collisions:
			if is_instance_valid(collision) and collision.get_parent()==null: collision.free()
		if is_instance_valid(entry.body): entry.body.free()
	_entries.clear()
	_vehicle_root = null
	_debris_parent = null
	_owner = null
	_disposed = true

## Required before any in-place deformation of cached source mesh vertices.
## Reconfigure a new provider after invalidation; launched debris keeps its copy.
func invalidate_geometry() -> bool:
	if _launched or _disposed: return false
	dispose()
	return true

func stats() -> Dictionary:
	var sleeping := 0
	for body in _bodies:
		if is_instance_valid(body) and body.sleeping: sleeping += 1
	return {"configured":_entries.size(),"prepared":_prewarm_cursor,"ready":_ready,"launched":_launched,"bodies":_bodies.size(),"sleeping":sleeping,"persistent":true}

func _copy_subtree(source: Node3D, root_node: bool) -> Dictionary:
	if not source.visible: return {"ok":false,"error":"assembly_invisible"}
	if source is MeshInstance3D and not _opaque_mesh(source): return {"ok":false,"error":"assembly_transparent"} if root_node else {"ok":true,"node":null}
	var copy: Node3D
	if source is MeshInstance3D:
		var mesh_copy: Mesh = source.mesh.duplicate(false)
		for surface in mesh_copy.get_surface_count():
			var material: Material = source.get_active_material(surface)
			if material == null: return {"ok":false,"error":"material_missing"}
			mesh_copy.surface_set_material(surface, material.duplicate(true))
		# Surface materials above are explicitly private. Reject any other nested
		# Mesh Resource that shallow duplication would still share (for example a
		# future imported shadow mesh) instead of silently weakening ownership.
		for name: StringName in _mesh_resource_properties(source.mesh):
			var source_value: Variant=source.mesh.get(name)
			if source_value is Resource and mesh_copy.get(name)==source_value: return {"ok":false,"error":"shared_nested_mesh_resource"}
		var instance := MeshInstance3D.new()
		instance.mesh = mesh_copy
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		copy = instance
	else:
		copy = Node3D.new()
	copy.name = source.name
	copy.transform = Transform3D.IDENTITY if root_node else source.transform
	for child: Node in source.get_children():
		if not child is Node3D: continue
		var result := _copy_subtree(child, false)
		if not result.ok:
			copy.free(); return result
		if result.node != null: copy.add_child(result.node)
	return {"ok":true,"node":copy}

static func _mesh_resource_properties(mesh: Mesh) -> Array[StringName]:
	if not _mesh_resource_property_names.is_empty(): return _mesh_resource_property_names
	for property: Dictionary in mesh.get_property_list():
		if (int(property.get("usage",0))&PROPERTY_USAGE_STORAGE)==0 or int(property.get("type",TYPE_NIL))!=TYPE_OBJECT: continue
		_mesh_resource_property_names.append(StringName(property.get("name","")))
	return _mesh_resource_property_names

func _opaque_mesh(node: MeshInstance3D) -> bool:
	if node.mesh == null: return false
	for surface in node.mesh.get_surface_count():
		var material := node.get_active_material(surface)
		if material == null: return false
		if material is BaseMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: return false
	return true

func _hull_count() -> int:
	var count := 0
	for entry: Dictionary in _entries: count += entry.hulls.size()
	return count

static func _descendant_node_count(source: Node3D) -> int:
	var count:=0; var stack: Array[Node]=[source]
	while not stack.is_empty():
		var node: Node=stack.pop_back()
		if node is Node3D: count+=1
		for child: Node in node.get_children(): stack.append(child)
	return count

static func _free_staged(entries: Array) -> void:
	for entry: Dictionary in entries:
		for collision in entry.get("collisions",[]):
			if is_instance_valid(collision) and collision.get_parent()==null: collision.free()
		if is_instance_valid(entry.get("body")): entry.body.free()
		elif is_instance_valid(entry.get("template")): entry.template.free()

static func _free_bodies(values: Array) -> void:
	for body in values:
		if is_instance_valid(body): body.free()
