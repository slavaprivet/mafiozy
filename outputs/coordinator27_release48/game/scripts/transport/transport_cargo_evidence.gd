extends RefCounted

# Reads the exact bound visual without owning meshes, panels or inventory.
# Vertex capture occurs once; current transforms are sampled on placement only.
const DATA_PATH := "res://assets/vehicle_visual/compartments.json"
var _visual
var _compartments
var _lid: Node3D
var _lid_meshes: Array = []
var _floors: Array[Node3D] = []
var _floor_proven := false

func configure(visual, compartments) -> Dictionary:
	if _visual != null: return {"ok":false,"error":"already_configured"}
	if visual == null or compartments == null or not is_instance_valid(visual.root): return {"ok":false,"error":"missing_visual"}
	if compartments.get("_visual") != visual: return {"ok":false,"error":"compartment_instance"}
	var file := FileAccess.open(DATA_PATH,FileAccess.READ)
	if file == null or file.get_length() > 524288: return {"ok":false,"error":"data_size"}
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("schema", "") != "mafiozi.vehicle-compartments.v1": return {"ok":false,"error":"data"}
	var spec: Dictionary = data.get("profiles", {}).get(visual.profile_id, {})
	if spec.get("visual_sha256", "") != visual.entry.get("sha256", ""): return {"ok":false,"error":"visual_hash"}
	var lid := visual.nodes.get(spec.get("panels", {}).get("trunk", {}).get("lid", "")) as Node3D
	if lid == null: return {"ok":false,"error":"lid_binding"}
	var floor_pattern := RegEx.new()
	floor_pattern.compile("^(Trunk_cargo_floor|Trunk_floor|Cargo_floor)$|_BedFloor$")
	var cached: Array = []; var floors: Array[Node3D] = []
	for node in visual.nodes.values():
		if not node is MeshInstance3D: continue
		if floor_pattern.search(String(node.get_meta("source_name", ""))) != null and not (node == lid or lid.is_ancestor_of(node)) and _source_visible(node,visual.root) and node.mesh != null:
			for surface in node.mesh.get_surface_count():
				if node.mesh.surface_get_array_len(surface) > 0: floors.append(node); break
		if not (node == lid or lid.is_ancestor_of(node)): continue
		var vertices := PackedVector3Array()
		for surface in node.mesh.get_surface_count():
			vertices.append_array(node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
		if not vertices.is_empty(): cached.append({"node":node,"mesh":node.mesh,"vertices":vertices})
	if cached.is_empty(): return {"ok":false,"error":"lid_geometry"}
	_visual = visual; _compartments = compartments; _lid = lid; _lid_meshes = cached; _floors = floors; _floor_proven = not floors.is_empty()
	return {"ok":true,"lid_meshes":cached.size(),"floor_candidates":floors.size()}

func sample() -> Dictionary:
	if _visual == null or not is_instance_valid(_visual.root) or not is_instance_valid(_lid) or not _visual.root.is_inside_tree(): return {}
	if _compartments.get("_visual") != _visual: return {}
	if not _visual.root.is_ancestor_of(_lid): return {}
	if absf(_visual.root.global_transform.basis.determinant()) < .000001: return {}
	var bounds: Dictionary = _compartments.cargo_bounds()
	if bounds.is_empty(): return {}
	# Source freezes floor presence during construction, before later visibility
	# changes. Render pooling/hiding cannot erase that authenticated geometry.
	var has_floor := _floor_proven
	for floor_node in _floors:
		if not is_instance_valid(floor_node) or not _visual.root.is_ancestor_of(floor_node) or _lid.is_ancestor_of(floor_node) or floor_node == _lid: return {}
	var inverse: Transform3D = _visual.root.global_transform.affine_inverse()
	var lo := Vector3(INF,INF,INF); var hi := Vector3(-INF,-INF,-INF)
	for row in _lid_meshes:
		var node := row.node as MeshInstance3D
		# A replacement mesh invalidates captured geometry; damage owns refresh.
		if not is_instance_valid(node) or node.mesh != row.mesh or not (node == _lid or _lid.is_ancestor_of(node)): return {}
		var transform: Transform3D = inverse * node.global_transform
		for vertex in row.vertices:
			# GLTFDocument returns an identity AuxScene above the RY(pi) wrapper;
			# relative imported mesh transforms already include source->native.
			var point: Vector3 = transform * vertex
			lo = lo.min(point); hi = hi.max(point)
	if not lo.is_finite() or not hi.is_finite(): return {}
	var profile: Dictionary = _compartments.access_profile("trunk")
	return {"bounds":AABB(bounds.min,bounds.max-bounds.min),"has_floor":has_floor,"lid_bounds":AABB(lo,hi-lo),"lid_visible":_lid.visible,"amount":_compartments.amount("trunk"),"mode":profile.get("mode", ""),"available":true,"visual_sha256":_visual.entry.get("sha256", "")}

func dispose() -> void:
	_visual = null; _compartments = null; _lid = null; _lid_meshes.clear(); _floors.clear(); _floor_proven = false

static func _source_visible(node: Node3D, visual_root: Node3D) -> bool:
	var current: Node = node
	while current != null:
		if current is Node3D and not current.visible: return false
		if current == visual_root: return true
		current = current.get_parent()
	return false

func invalidate_geometry() -> void:
	# Damage/deformation owners call this before changing vertices in place.
	# A fresh configure is required after the authoritative geometry settles.
	dispose()
