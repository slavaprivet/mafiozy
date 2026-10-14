extends RefCounted
## Data-only preparation cache for vehicle deformation. It never owns visible
## meshes and returns a new ArrayMesh plus mutable packed-array copies per car.

const Subdivision=preload("res://scripts/transport/transport_mesh_subdivision.gd")
const REQUIRED_PROVENANCE: Array[String]=["source_sha256","visual_manifest_sha256","asset_generation"]
const DEFAULT_MAX_ENTRIES:=16
const DEFAULT_MAX_PAYLOAD_BYTES:=128*1024*1024
const DEFAULT_MAX_INSTANCE_BINDINGS:=4096

var _entries: Dictionary={}
var _instance_bindings: Dictionary={}
var _max_entries:=DEFAULT_MAX_ENTRIES
var _max_payload_bytes:=DEFAULT_MAX_PAYLOAD_BYTES
var _max_instance_bindings:=DEFAULT_MAX_INSTANCE_BINDINGS
var _started:=false
var _disposed:=false

func configure_limits(max_entries: int=DEFAULT_MAX_ENTRIES,max_payload_bytes: int=DEFAULT_MAX_PAYLOAD_BYTES,max_instance_bindings: int=DEFAULT_MAX_INSTANCE_BINDINGS) -> bool:
	if _disposed or _started or max_entries<1 or max_entries>256 or max_payload_bytes<1 or max_payload_bytes>1024*1024*1024 or max_instance_bindings<1 or max_instance_bindings>65536: return false
	_max_entries=max_entries; _max_payload_bytes=max_payload_bytes; _max_instance_bindings=max_instance_bindings
	return true

## visual must expose root/profile_id/nodes like vehicle_visual.gd. Provenance
## names the source algorithm and imported asset generation; it grants no event
## or gameplay authority.
func acquire(visual: RefCounted,body: Node3D,profile: Dictionary,provenance: Dictionary) -> Dictionary:
	if _disposed: return _error("disposed")
	var contract:=_contract(visual,body,profile,provenance)
	if not contract.ok: return contract
	var scanned:=_scan(visual,body)
	if not scanned.ok: return scanned
	_started=true; _prune_dead_bindings()
	var key:=_entry_key(profile,provenance)
	for source: Dictionary in scanned.rows:
		var node_id: int=source.node.get_instance_id()
		if _instance_bindings.has(node_id) and (_instance_bindings[node_id] as Dictionary).cache_key!=key: return _error("provenance_changed")
	var status: String
	var pending_entry: Dictionary={}
	if not _entries.has(key):
		if _entries.size()>=_max_entries: return _error("entry_limit")
		var built:=_build(scanned.rows,profile,provenance,_max_payload_bytes-_payload_bytes())
		if not built.ok: return built
		pending_entry=built.entry; status="BUILT"
	else:
		status="HIT"
	var entry: Dictionary=pending_entry if not pending_entry.is_empty() else _entries[key]
	if entry.profile!=profile or entry.provenance!=provenance: return _error("cache_collision")
	var validation:=_validate_rows(scanned.rows,entry.rows,key)
	if not validation.ok: return validation
	if not pending_entry.is_empty(): _entries[key]=pending_entry
	var instance_rows: Array=[]
	for i in entry.rows.size():
		var source: Dictionary=scanned.rows[i]; var blueprint: Dictionary=entry.rows[i]
		var prepared:=ArrayMesh.new(); var surfaces: Array=[]
		for surface_index in blueprint.surfaces.size():
			var cached: Dictionary=blueprint.surfaces[surface_index]
			var arrays: Array=cached.arrays.duplicate(true)
			prepared.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var output:=prepared.get_surface_count()-1
			prepared.surface_set_material(output,source.mesh.surface_get_material(surface_index))
			prepared.surface_set_name(output,cached.name)
			var base: PackedVector3Array=(cached.arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
			surfaces.append({"arrays":arrays.duplicate(true),"base":base,"prepared_base":base.duplicate(),"vertex_bindings":(cached.vertex_bindings as PackedInt32Array).duplicate(),"node_indices":(cached.node_indices as PackedByteArray).duplicate(),"node_weights":(cached.node_weights as PackedFloat64Array).duplicate(),"mask":cached.mask,"material":source.mesh.surface_get_material(surface_index),"name":cached.name,"last_written":PackedVector3Array(),"last_displacement":PackedVector3Array()})
		instance_rows.append({"label":source.label,"node":source.node,"original":source.mesh,"prepared":prepared,"surfaces":surfaces,"frame":source.frame,"reach_bounds_source":blueprint.reach_bounds_source,"original_positions":_mesh_positions(source.mesh),"last_offsets":PackedVector3Array(),"external_dirty":false})
	return {"ok":true,"status":status,"cache_key":key,"profile":entry.profile.duplicate(true),"provenance":entry.provenance.duplicate(true),"rows":instance_rows,"blueprint_payload_bytes_estimate":entry.blueprint_payload_bytes_estimate,"candidate_meshes":instance_rows.size()}

func clear() -> void: _entries.clear(); _instance_bindings.clear()
func stats() -> Dictionary:
	_prune_dead_bindings()
	return {"ok":not _disposed,"entries":_entries.size(),"instance_bindings":_instance_bindings.size(),"blueprint_payload_bytes_estimate":_payload_bytes(),"limits":{"entries":_max_entries,"payload_bytes":_max_payload_bytes,"instance_bindings":_max_instance_bindings}}
func dispose() -> void: _entries.clear(); _instance_bindings.clear(); _disposed=true

func _contract(visual: RefCounted,body: Node3D,profile: Dictionary,provenance: Dictionary) -> Dictionary:
	if visual==null or not is_instance_valid(body) or not body.is_inside_tree() or not is_instance_valid(visual.get("root")) or not visual.get("nodes") is Dictionary: return _error("visual")
	if not visual.get("profile_id") is String or visual.get("profile_id")!=profile.get("id"): return _error("profile")
	if not body.is_ancestor_of(visual.get("root")): return _error("boundary")
	for field in ["halfWidth","halfLength","height"]:
		if not (profile.get(field) is float or profile.get(field) is int) or not is_finite(float(profile[field])) or float(profile[field])<=0: return _error("profile")
	for field in REQUIRED_PROVENANCE:
		if not provenance.get(field) is String or (provenance.get(field) as String).is_empty(): return _error("provenance")
	if not _is_sha256(provenance.source_sha256) or not _is_sha256(provenance.visual_manifest_sha256): return _error("provenance")
	return {"ok":true}

func _scan(visual: RefCounted,body: Node3D) -> Dictionary:
	var visual_root: Node3D=visual.get("root"); var rows: Array=[]; var seen: Dictionary={}
	var keys: Array=(visual.get("nodes") as Dictionary).keys(); keys.sort()
	for key_value: Variant in keys:
		var node: Variant=(visual.get("nodes") as Dictionary)[key_value]
		if not node is MeshInstance3D or not node.mesh is ArrayMesh or seen.has(node) or not visual_root.is_ancestor_of(node): continue
		seen[node]=true
		var count:=0; var all_transparent:=true
		for surface in node.mesh.get_surface_count():
			count+=node.mesh.surface_get_array_len(surface)
			var material: Material=node.mesh.surface_get_material(surface)
			if not material is BaseMaterial3D or material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED: all_transparent=false
		if all_transparent or count>90000: continue
		var excluded:=false; var parent: Node=node
		while parent!=visual_root and parent!=null:
			var metadata: Dictionary=parent.get_meta("source_metadata",{})
			var source_name: String=parent.get_meta("source_name","")
			if metadata.has("vehicleWheelId") or metadata.get("crashDeform",true)==false or source_name.begins_with("Interior_") or source_name.contains("damage_effects"): excluded=true; break
			parent=parent.get_parent()
		if excluded: continue
		var frame:=_relative_transform(body,node)
		if absf(frame.basis.determinant())<.000001: return _error("singular_mesh")
		rows.append({"label":str(key_value),"node":node,"mesh":node.mesh,"mesh_id":node.mesh.get_instance_id(),"fingerprint":_mesh_fingerprint(node.mesh),"frame":frame})
	if rows.is_empty(): return _error("meshes")
	return {"ok":true,"rows":rows}

func _build(rows: Array,profile: Dictionary,provenance: Dictionary,payload_budget: int) -> Dictionary:
	var blueprint_rows: Array=[]; var payload:=0
	for source: Dictionary in rows:
		var result:=Subdivision.subdivide(source.mesh,.15,9000)
		if not result.get("ok",false): return result
		var gx:=PackedFloat64Array([-float(profile.halfWidth),0.0,float(profile.halfWidth)])
		var gy:=PackedFloat64Array([.28,float(profile.height)*.46,float(profile.height)*.91])
		var gz:=PackedFloat64Array([-float(profile.halfLength),-float(profile.halfLength)*.5,0.0,float(profile.halfLength)*.5,float(profile.halfLength)])
		var surfaces: Array=[]
		for surface in result.mesh.get_surface_count():
			var arrays: Array=result.mesh.surface_get_arrays(surface); var base: PackedVector3Array=(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
			var node_indices:=PackedByteArray(); var node_weights:=PackedFloat64Array(); var vertex_bindings:=PackedInt32Array(); vertex_bindings.resize(base.size())
			var bindings_by_point: Dictionary={}; var mask:=0
			for vertex_index in base.size():
				var point: Vector3=source.frame*base[vertex_index]
				if bindings_by_point.has(point): vertex_bindings[vertex_index]=bindings_by_point[point]; continue
				var binding_index:=bindings_by_point.size(); bindings_by_point[point]=binding_index; vertex_bindings[vertex_index]=binding_index
				# Source gridInterval uses <=, retaining the left interval with blend 1
				# exactly on internal boundaries. This matters to conservative masks.
				var sx:=-point.x; var sy:=point.y; var sz:=-point.z
				var xi:=_grid_cell_index(sx,gx); var yi:=_grid_cell_index(sy,gy); var zi:=_grid_cell_index(sz,gz)
				var lower:=zi*9+yi*3+xi; var xt:=_grid_cell_blend(sx,gx,xi); var yt:=_grid_cell_blend(sy,gy,yi); var zt:=_grid_cell_blend(sz,gz,zi)
				for zz in 2:
					for yy in 2:
						for xx in 2:
							var node_index:=lower+zz*9+yy*3+xx; mask|=1<<node_index; node_indices.append(node_index)
							node_weights.append((xt if xx else 1.0-xt)*(yt if yy else 1.0-yt)*(zt if zz else 1.0-zt))
			surfaces.append({"arrays":arrays.duplicate(true),"vertex_bindings":vertex_bindings,"node_indices":node_indices,"node_weights":node_weights,"mask":mask,"name":result.mesh.surface_get_name(surface)})
		var blueprint_row={"label":source.label,"mesh_id":source.mesh_id,"fingerprint":source.fingerprint,"frame":source.frame,"reach_bounds_source":_source_bounds(source.frame,source.mesh.get_aabb()),"surfaces":surfaces}
		payload+=_variant_bytes(blueprint_row)
		if payload>payload_budget: return _error("payload_budget")
		blueprint_rows.append(blueprint_row)
	var entry={"profile":profile.duplicate(true),"provenance":provenance.duplicate(true),"rows":blueprint_rows}
	entry.blueprint_payload_bytes_estimate=payload
	return {"ok":true,"entry":entry}

func _validate_rows(current: Array,cached: Array,cache_key: String) -> Dictionary:
	if current.size()!=cached.size(): return _error("topology_changed")
	var pending_bindings: Array=[]
	for i in current.size():
		var now: Dictionary=current[i]; var prior: Dictionary=cached[i]
		if now.label!=prior.label: return _error("topology_changed")
		if now.fingerprint!=prior.fingerprint: return _error("geometry_changed")
		if now.frame!=prior.frame: return _error("assembly_frame_changed")
		# Imported scene instances may own distinct but byte-identical ArrayMesh
		# resources. Exact content/provenance admits the new instance once; after
		# that, replacing its bound mesh is closed even with identical content.
		var node_id: int=now.node.get_instance_id()
		if _instance_bindings.has(node_id):
			var binding: Dictionary=_instance_bindings[node_id]
			var bound_node: Variant=(binding.node_ref as WeakRef).get_ref()
			if bound_node!=now.node or binding.cache_key!=cache_key or binding.mesh_id!=now.mesh_id: return _error("mesh_replaced")
		else:
			pending_bindings.append({"node_id":node_id,"node_ref":weakref(now.node),"mesh_id":now.mesh_id,"cache_key":cache_key})
	if _instance_bindings.size()+pending_bindings.size()>_max_instance_bindings: return _error("instance_binding_limit")
	for binding: Dictionary in pending_bindings:
		_instance_bindings[binding.node_id]=binding
	return {"ok":true}

func _prune_dead_bindings() -> void:
	var dead: Array=[]
	for node_id: Variant in _instance_bindings:
		var binding: Dictionary=_instance_bindings[node_id]
		if not binding.get("node_ref") is WeakRef or not is_instance_valid((binding.node_ref as WeakRef).get_ref()): dead.append(node_id)
	for node_id: Variant in dead: _instance_bindings.erase(node_id)

func _payload_bytes() -> int:
	var total:=0
	for entry: Dictionary in _entries.values(): total+=int(entry.blueprint_payload_bytes_estimate)
	return total

static func _entry_key(profile: Dictionary,provenance: Dictionary) -> String:
	return str(profile.get("id"))+"|"+str(provenance.source_sha256)+"|"+str(provenance.visual_manifest_sha256)+"|"+str(provenance.asset_generation)

static func _mesh_fingerprint(mesh: ArrayMesh) -> String:
	var context:=HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(mesh.get_surface_count()))
	for surface in mesh.get_surface_count():
		context.update(var_to_bytes(mesh.surface_get_primitive_type(surface)))
		context.update(var_to_bytes(mesh.surface_get_name(surface)))
		context.update(var_to_bytes(mesh.surface_get_arrays(surface)))
	return context.finish().hex_encode()

static func _grid_cell_index(value: float,grid: PackedFloat64Array) -> int:
	if value<=grid[0]: return 0
	for i in grid.size()-1:
		if value<=grid[i+1]: return i
	return grid.size()-2

static func _grid_cell_blend(value: float,grid: PackedFloat64Array,index: int) -> float:
	return clampf((value-grid[index])/(grid[index+1]-grid[index]),0.0,1.0)

static func _relative_transform(ancestor: Node3D,node: Node3D) -> Transform3D:
	var result:=Transform3D.IDENTITY; var current: Node3D=node
	while current!=ancestor:
		result=current.transform*result
		current=current.get_parent() as Node3D
	return result

static func _source_bounds(frame: Transform3D,bounds: AABB) -> AABB:
	var result:=AABB()
	for corner in 8:
		var local:=bounds.position+Vector3(bounds.size.x if corner&1 else 0.0,bounds.size.y if corner&2 else 0.0,bounds.size.z if corner&4 else 0.0)
		var native:=frame*local; var source:=Vector3(-native.x,native.y,-native.z)
		if corner==0: result=AABB(source,Vector3.ZERO)
		else: result=result.expand(source)
	return result

static func _mesh_positions(mesh: ArrayMesh) -> Array:
	var result: Array=[]
	for surface in mesh.get_surface_count(): result.append((mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate())
	return result

static func _variant_bytes(value: Variant) -> int:
	if value is PackedVector3Array: return value.size()*12
	if value is PackedVector2Array: return value.size()*8
	if value is PackedFloat64Array: return value.size()*8
	if value is PackedFloat32Array or value is PackedInt32Array: return value.size()*4
	if value is PackedByteArray: return value.size()
	if value is PackedColorArray: return value.size()*16
	if value is Array:
		var total:=0
		for item in value: total+=_variant_bytes(item)
		return total
	if value is Dictionary:
		var total:=0
		for item in value.values(): total+=_variant_bytes(item)
		return total
	if value is String: return value.length()
	return 8

static func _is_sha256(value: String) -> bool:
	if value.length()!=64: return false
	for character in value:
		if not character.to_lower() in "0123456789abcdef": return false
	return true

static func _error(code: String) -> Dictionary: return {"ok":false,"error":code}
