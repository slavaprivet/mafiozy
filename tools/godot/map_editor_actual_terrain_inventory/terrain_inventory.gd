extends RefCounted
## Strict read-only inventory. Reports/source reconstruction never grant ownership.
const SOURCE_MAIN_SHA := "0916381441df9a9d111006aed2b34e4e1c2ec195ee24609757a552b388017571"
class Snapshot extends RefCounted:
	var issuer: WeakRef
	var main: WeakRef
	var parent: WeakRef
	var signature := ""
var _checks := 0
var _errors := []
func require(ok: bool,label: String) -> void:
	_checks += 1
	if not ok: _errors.append(label)
static func sha(value: Variant) -> String:
	var bytes: PackedByteArray = value if value is PackedByteArray else var_to_bytes(value)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()
func live(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()
func capture(main: Node3D) -> Dictionary:
	_checks = 0
	_errors = []
	if not live(main) or main.get_script()==null or main.get_script().resource_path!="res://scripts/main.gd":
		return {"ok":false,"errors":["Genuine live original main required"]}
	if sha(FileAccess.get_file_as_bytes("res://scripts/main.gd"))!=SOURCE_MAIN_SHA:
		return {"ok":false,"errors":["Original source version changed; independent source review required"]}
	require(main.preview_ready,"Original main source ready")
	require(main.global_transform==Transform3D.IDENTITY,"Original identity terrain parent")
	require(main.is_visible_in_tree(),"Original terrain parent visible in tree")
	require(main._block==JSON.parse_string(FileAccess.get_file_as_string(main.block_data_path)),"Original live block exactly matches admitted source file")
	var source: Dictionary = main._block.surface
	var grid: Array = source.grid
	var palette: Dictionary = source.palette
	var cell: float = source.cellSize
	var origin: Vector3 = main._origin
	var expected := {}
	var strips := {}
	var dry_cells := 0
	var water_cells := 0
	var source_convex := {}
	for records: Array in [main._block.buildings,main._block.decor]:
		for record: Dictionary in records:
			for data: Dictionary in record.get("collisionBodiesM",[]):
				var points := PackedVector3Array()
				for point: Array in data.polygonXZ:
					points.append(Vector3(float(point[0]),float(data.minY),float(point[1])))
					points.append(Vector3(float(point[0]),float(data.maxY),float(point[1])))
				source_convex[str(record.id)+":"+str(data.sourceIndex)] = points
	require(grid.size()==int(source.rows),"Source grid rows")
	for row in grid.size():
		require(grid[row].size()==int(source.cols),"Source grid columns")
		for col in grid[row].size():
			var key := str(int(grid[row][col]))
			if not expected.has(key): expected[key] = []
			expected[key].append(Vector3((int(source.startCol)+col+.5)*cell-origin.x,float(palette[key].heightM)-.02,(int(source.startRow)+row+.5)*cell-origin.z))
			if bool(palette[key].solid): dry_cells += 1
			if key=="16": water_cells += 1
		var col := 0
		while col<grid[row].size():
			var key := str(int(grid[row][col]))
			if not bool(palette[key].solid):
				col += 1
				continue
			var first: int = col
			while col<grid[row].size() and str(int(grid[row][col]))==key: col += 1
			var position := Vector3((int(source.startCol)+(first+col)*.5)*cell-origin.x,float(palette[key].heightM)-.08,(int(source.startRow)+row+.5)*cell-origin.z)
			var size := Vector3((col-first)*cell,.16,cell)
			var signature := sha([Transform3D(Basis.IDENTITY,position),Transform3D.IDENTITY,size])
			require(not strips.has(signature),"Unique source dry strip")
			strips[signature] = {"row":row,"first":first,"end_exclusive":col,"tile":key,"position":position,"size":size}
	var report := {"schema":"actual-main-terrain-readonly-inventory/v1","main_id":main.get_instance_id(),"parent_id":main.get_parent().get_instance_id(),"main_frame":main.global_transform,"origin":origin,"source_grid_sha":sha(source),"source_script_sha":sha(FileAccess.get_file_as_bytes("res://scripts/main.gd")),"block_file_sha":sha(FileAccess.get_file_as_bytes(main.block_data_path)),"water_file_sha":sha(FileAccess.get_file_as_bytes(main.water_data_path)),"cells":int(source.rows)*int(source.cols),"dry_cells":dry_cells,"source_water_cells":water_cells,"groups":[],"strips":[],"nonterrain_source_convex":[],"uncertain_direct_bodies":[],"water_status":main.water_status,"jump":{},"gpu":false,"editor_adoption_ready":false,"navigation_accepted":false}
	var surface_nodes := {}
	var matched_strips := {}
	var water_nodes := []
	var matched_convex := {}
	for node: Node in main.get_children():
		if node.name=="SourceNativeWater": water_nodes.append(node)
		if str(node.name).begins_with("Surface_"):
			require(live(node) and node is MultiMeshInstance3D,"Live direct Surface MultiMesh node")
			if not node is MultiMeshInstance3D: continue
			require(not surface_nodes.has(str(node.name)),"No duplicate Surface node")
			surface_nodes[str(node.name)] = node
		if not node is StaticBody3D: continue
		require(live(node),"Direct body lifetime")
		var shapes := []
		for child: Node in node.get_children():
			if child is CollisionShape3D: shapes.append(child)
		if shapes.size()==1 and shapes[0].shape is ConvexPolygonShape3D and node.has_meta("source_id"):
			var key := str(node.get_meta("source_id"))+":"+str(node.get_meta("source_index","UNVERIFIED"))
			var verified: bool = source_convex.has(key) and shapes[0].shape.points==source_convex[key] and node.transform==Transform3D.IDENTITY and shapes[0].transform==Transform3D.IDENTITY and node.get_child_count()==1 and live(shapes[0]) and not shapes[0].disabled and node.collision_layer==1 and node.collision_mask==1 and not matched_convex.has(key)
			require(verified,"Nonterrain convex must match exact original source descriptor, not metadata alone")
			if not verified:
				report.uncertain_direct_bodies.append(str(node.get_path()))
				continue
			matched_convex[key] = true
			report.nonterrain_source_convex.append({"node_id":node.get_instance_id(),"source_id":str(node.get_meta("source_id")),"source_index":node.get_meta("source_index"),"shape_id":shapes[0].shape.get_instance_id(),"points_sha":sha(shapes[0].shape.points.to_byte_array()),"margin":shapes[0].shape.margin,"frame":node.transform,"shape_frame":shapes[0].transform,"layer":node.collision_layer,"mask":node.collision_mask,"disabled":shapes[0].disabled})
			continue
		if shapes.size()!=1 or not shapes[0].shape is BoxShape3D or node.get_child_count()!=1:
			report.uncertain_direct_bodies.append(str(node.get_path()))
			require(false,"Uncertain direct body cannot be silently adopted as nonterrain")
			continue
		var collider: CollisionShape3D = shapes[0]
		var signature := sha([node.transform,collider.transform,collider.shape.size])
		if not strips.has(signature):
			report.uncertain_direct_bodies.append(str(node.get_path()))
			require(false,"Unmatched/wrong native dry-floor strip")
			continue
		require(not matched_strips.has(signature),"No duplicate native dry-floor strip")
		matched_strips[signature] = true
		require(live(collider) and not collider.disabled and node.collision_layer==1 and node.collision_mask==1,"Original dry-floor shape/filter/lifetime")
		report.strips.append({"node_id":node.get_instance_id(),"shape_node_id":collider.get_instance_id(),"shape_id":collider.shape.get_instance_id(),"parent_id":node.get_parent().get_instance_id(),"frame":node.transform,"shape_frame":collider.transform,"size":collider.shape.size,"margin":collider.shape.margin,"layer":node.collision_layer,"mask":node.collision_mask,"disabled":collider.disabled,"source":strips[signature]})
	require(matched_strips.size()==strips.size(),"No missing native dry-floor strips")
	var expected_names := {}
	for key: String in expected:
		if key=="16" and main.water_status=="detail_ready": continue
		var name := "Surface_"+str(palette[key].kind)
		expected_names[name] = true
		require(surface_nodes.has(name),"Expected original Surface group present: "+name)
		if not surface_nodes.has(name): continue
		var node: MultiMeshInstance3D = surface_nodes[name]
		var multi: MultiMesh = node.multimesh
		require(multi!=null and multi.mesh is BoxMesh,"Original Surface MM/BoxMesh resource")
		if multi==null or not multi.mesh is BoxMesh: continue
		require(node.transform==Transform3D.IDENTITY and node.visible and node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Original Surface node pose/shadow")
		require(node.is_visible_in_tree() and node.layers==1 and node.material_overlay==null and multi.visible_instance_count==-1,"Original Surface visibility/layer/overlay/full batch")
		require(multi.instance_count==expected[key].size() and multi.transform_format==MultiMesh.TRANSFORM_3D and not multi.use_colors and not multi.use_custom_data,"Exact original Surface batch count/format")
		require(multi.mesh.size==Vector3(cell,.04,cell) and multi.mesh.material==main._surface_materials[key] and node.material_override==null,"Exact original Surface shared material/box size")
		var construction := PackedFloat32Array()
		for position: Vector3 in expected[key]: construction.append_array(PackedFloat32Array([1,0,0,position.x,0,1,0,position.y,0,0,1,position.z]))
		var actual: PackedFloat32Array = multi.buffer
		var observed := actual.size()==construction.size()
		if observed: require(actual.to_byte_array()==construction.to_byte_array(),"Available actual MM buffer equals source construction")
		report.groups.append({"name":name,"tile":key,"node_id":node.get_instance_id(),"parent_id":node.get_parent().get_instance_id(),"mm_id":multi.get_instance_id(),"mesh_id":multi.mesh.get_instance_id(),"material_id":multi.mesh.material.get_instance_id(),"frame":node.transform,"box_size":multi.mesh.size,"instance_count":multi.instance_count,"visible_instance_count":multi.visible_instance_count,"layers":node.layers,"shadow":node.cast_shadow,"material_overlay_id":node.material_overlay.get_instance_id() if node.material_overlay!=null else 0,"custom_aabb":multi.custom_aabb,"source_construction_sha":sha(construction.to_byte_array()),"actual_buffer_available":observed,"actual_buffer_sha":sha(actual.to_byte_array()) if observed else "UNAVAILABLE_DUMMY_RENDERER_NOT_PROOF"})
	require(surface_nodes.size()==expected_names.size(),"No extra/duplicate/wrong Surface groups")
	# Jump guard source caches, not floors/swimming/nav approval.
	var jump := PackedByteArray()
	jump.resize(int(source.rows)*int(source.cols))
	for row in int(source.rows):
		for col in int(source.cols):
			var tile: int = int(grid[row][col])
			var police: Variant = source.masks.policeMask[row][col]
			var land: bool = bool(source.masks.walkableMask[row][col]) or (tile==9 and (police is int or police is float) and police==1)
			var water: bool = tile==16 and not bool(source.masks.protectedMask[row][col])
			jump[row*int(source.cols)+col] = 1 if land or water else 0
	var offsets := PackedVector2Array()
	for i in 12:
		var angle: float = float(i)*PI/6.0
		offsets.append(Vector2(cos(angle),sin(angle)))
	require(main._jump_surface_cells==jump and main._jump_surface_offsets==offsets,"Exact original jump bytes and12 offsets")
	require(main._jump_surface_cell_size==cell and main._jump_surface_start==Vector2i(source.startCol,source.startRow) and main._jump_surface_size==Vector2i(source.cols,source.rows),"Exact original jump crop units/anchors")
	report.jump = {"cells_sha":sha(main._jump_surface_cells),"offsets_sha":sha(main._jump_surface_offsets.to_byte_array()),"cell_size":main._jump_surface_cell_size,"start":main._jump_surface_start,"size":main._jump_surface_size}
	if main.water_status=="detail_ready":
		require(main._water_host!=null and main._water_host._built and water_nodes.size()==1,"One original water owner /sole node")
		if main._water_host!=null and water_nodes.size()==1:
			var node: MeshInstance3D = main._water_host._instance
			if not live(node) or node.mesh==null or node.mesh.get_surface_count()!=1 or main._water_host._factory==null or node.mesh.surface_get_material(0)==null:
				return {"ok":false,"errors":["Original water dependencies/lifetime unavailable"],"report":report}
			require(water_nodes[0]==node and live(node) and node.get_parent()==main and node.transform==Transform3D.IDENTITY and node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Water actual owner-instance linkage/pose/shadow")
			require(node.get_child_count()==0 and main._water_host._cell_count==water_cells,"Water no colliders /original cellcount")
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main.water_data_path))
			var positions := PackedVector3Array()
			var indices := PackedInt32Array()
			var depths := PackedFloat32Array()
			for i in data.native.cells.size():
				var record: Dictionary = data.native.cells[i]
				for j in 6:
					var corner: Array = data.native.vertexOrder[j]
					positions.append(Vector3((record.c+corner[0])*cell,data.native.surfaceYM,(record.r+corner[1])*cell)-origin)
					indices.append(i*6+[0,2,1,3,5,4][j])
					depths.append(record.depths[j])
			var arrays: Array = node.mesh.surface_get_arrays(0)
			require(arrays[Mesh.ARRAY_VERTEX].to_byte_array()==positions.to_byte_array() and arrays[Mesh.ARRAY_INDEX]==indices,"Actual water vertices/indices exact source construction")
			var observed_depths: PackedByteArray = arrays[Mesh.ARRAY_CUSTOM0].to_byte_array() if arrays[Mesh.ARRAY_CUSTOM0] is PackedFloat32Array else arrays[Mesh.ARRAY_CUSTOM0]
			require(observed_depths==depths.to_byte_array(),"Actual water custom depth bytes exact source")
			report.water = {"owner_id":main._water_host.get_instance_id(),"node_id":node.get_instance_id(),"mesh_id":node.mesh.get_instance_id(),"material_id":node.mesh.surface_get_material(0).get_instance_id(),"factory_id":main._water_host._factory.get_instance_id(),"frame":node.transform,"cell_count":water_cells,"vertices_sha":sha(arrays[Mesh.ARRAY_VERTEX].to_byte_array()),"indices_sha":sha(arrays[Mesh.ARRAY_INDEX].to_byte_array()),"depths_sha":sha(observed_depths),"normals_observed_sha":sha(arrays[Mesh.ARRAY_NORMAL].to_byte_array()),"normal_note":"Actual decoded native codec normals retained; no regenerated normal equivalence claim"}
	else:
		require(main._water_host==null and water_nodes.is_empty(),"Fallback water cannot have duplicate native owner")
		report.water = {"owner_id":0,"status":main.water_status,"detail_admitted":false}
	report.checks = _checks
	report.errors = _errors.duplicate()
	var snapshot := Snapshot.new()
	snapshot.issuer = weakref(self)
	snapshot.main = weakref(main)
	snapshot.parent = weakref(main.get_parent())
	snapshot.signature = sha(report)
	return {"ok":_errors.is_empty(),"report":report,"snapshot":snapshot}

func verify_snapshot(main: Node3D,snapshot: RefCounted) -> Dictionary:
	if not snapshot is Snapshot or snapshot.issuer.get_ref()!=self or snapshot.main.get_ref()!=main or not live(main) or not is_instance_valid(snapshot.parent.get_ref()) or main.get_parent()!=snapshot.parent.get_ref():
		return {"ok":false,"error":"Inventory lifetime/parent/issuer changed"}
	var current: Dictionary = capture(main)
	if not current.ok:
		return {"ok":false,"report":current.get("report",{}),"error":"Original terrain dependencies/source changed","errors":current.get("errors",current.get("report",{}).get("errors",[]))}
	var equal: bool = sha(current.report)==snapshot.signature
	return {"ok":equal,"report":current.report,"error":"" if equal else "Original terrain node/resource/enumerated state changed"}
