extends Node3D
## Walk glass_breakage.mjs port. Presentation only; caller owns damage/collision.
## Hit contract: object, surface_index, face_index (within that surface), world
## position, LOCAL normal, optional instance_id. No nearest-pane approximation.
signal panel_fractured(receipt: Dictionary)
signal fracture_rejected(receipt: Dictionary)

const SOURCE := "assets/maps/city_rebuild_v1/glass_breakage.mjs"
const FRACTURE_DELAY := 0.085
var limits := {"shards":192,"panels":80,"per_hit":28}
var ground_height := Callable()
var ground_y := 0.035
var _records: Dictionary = {}
var _decorations: Array[Dictionary] = []
var _pending: Array[Dictionary] = []
var _shards: Array[Dictionary] = []
var _active: Dictionary = {}
var _particles: MultiMeshInstance3D
var _crack_material: StandardMaterial3D
var _rim_material: StandardMaterial3D
var _cursor := 0
var _total_broken := 0
var _configured := false
var _disposed := false
var _random_state := 0
var _render_observer := Callable()

func configure(options: Dictionary = {}) -> bool:
	if _configured or _disposed: return false
	limits.shards = clampi(int(options.get("max_shards",192)),8,512)
	limits.panels = clampi(int(options.get("max_decorated_panels",80)),1,256)
	limits.per_hit = clampi(int(options.get("shards_per_hit",28)),6,64)
	ground_height = options.get("ground_height",Callable())
	ground_y = float(options.get("ground_y",0.035))
	_render_observer = options.get("render_observer",Callable())
	name = "World_Glass_Shards"
	set_meta("breakableGlass",false)
	_crack_material = _material(Color("d8f2e9"),0.89,0.0,1.0)
	_crack_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rim_material = _material(Color("82b5b1"),0.68,0.18,0.2)
	var shard_material := _material(Color("b4dfdc"),0.73,0.23,0.12)
	shard_material.vertex_color_use_as_albedo = true
	shard_material.vertex_color_is_srgb = false
	shard_material.clearcoat_enabled = true
	shard_material.clearcoat = 1.0
	var xyz := PackedFloat32Array([-.5,-.35,0,.5,-.32,0,-.12,.58,0,-.5,-.35,.028,-.12,.58,.028,.5,-.32,.028,-.5,-.35,0,-.5,-.35,.028,.5,-.32,0,.5,-.32,0,-.5,-.35,.028,.5,-.32,.028,.5,-.32,0,.5,-.32,.028,-.12,.58,0,-.12,.58,0,.5,-.32,.028,-.12,.58,.028,-.12,.58,0,-.12,.58,.028,-.5,-.35,0,-.5,-.35,0,-.12,.58,.028,-.5,-.35,.028])
	var vertices := PackedVector3Array()
	for i in range(0,xyz.size(),3): vertices.append(Vector3(xyz[i],xyz[i+1],xyz[i+2]))
	_particles = MultiMeshInstance3D.new()
	_particles.name = "Flying_Glass_Shards"
	_particles.set_meta("breakableGlass",false)
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_particles.multimesh = MultiMesh.new()
	_particles.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_particles.multimesh.use_colors = true
	_particles.multimesh.mesh = _mesh(vertices,Mesh.PRIMITIVE_TRIANGLES)
	_particles.material_override = shard_material
	_particles.multimesh.instance_count = limits.shards
	add_child(_particles)
	for i: int in limits.shards:
		_shards.append({"source":null,"position":Vector3.ZERO,"velocity":Vector3.ZERO,"rotation":Vector3.ZERO,"spin":Vector3.ZERO,"size":0.0,"life":0.0})
		_particles.multimesh.set_instance_transform(i,_zero())
	_configured = true
	return true

static func is_breakable_glass(node: GeometryInstance3D, material: Material, mixed: bool = false) -> bool:
	if not is_instance_valid(node): return false
	var node_has := node.has_meta("breakableGlass")
	var material_has: bool = material != null and material.has_meta("breakableGlass")
	if (node_has and node.get_meta("breakableGlass") == false) or (material_has and material.get_meta("breakableGlass") == false): return false
	if (node_has and node.get_meta("breakableGlass") == true) or (material_has and material.get_meta("breakableGlass") == true): return true
	if material != null and _glass_label(material.resource_name): return true
	if not mixed and _glass_label(str(node.name)): return true
	return material != null and float(material.get_meta("transmission",0.0)) > 0.0 and float(material.get_meta("opacity",1.0)) != 0.0

static func _glass_label(label: String) -> bool:
	var lower := label.to_lower()
	for word: String in ["glass","glazing","windshield","windscreen"]:
		if lower.contains(word): return true
	return false

static func _primitive(mesh:Mesh,surface:int) -> int:
	if mesh is ArrayMesh: return mesh.surface_get_primitive_type(surface)
	# Godot PrimitiveMesh does not expose ArrayMesh's surface-type accessor.
	# These built-in resources generate triangle surfaces; points remain points.
	if mesh is PointMesh: return Mesh.PRIMITIVE_POINTS
	if mesh is PrimitiveMesh: return Mesh.PRIMITIVE_TRIANGLES
	return -1

func prepare(root: Node) -> int:
	if _disposed or not _configured or not is_instance_valid(root): return 0
	var count := 0
	if (root is MeshInstance3D or root is MultiMeshInstance3D) and not root.get_meta("glassEffect",false) and not _records.has(root):
		var geometry: Mesh = root.mesh if root is MeshInstance3D else root.multimesh.mesh if root.multimesh != null else null
		if geometry != null and (not geometry is ArrayMesh or geometry.get_blend_shape_count() == 0) and (not root is MeshInstance3D or root.skin == null):
			var included := false
			for surface: int in geometry.get_surface_count():
				if _primitive(geometry,surface)==Mesh.PRIMITIVE_TRIANGLES and is_breakable_glass(root,_surface_material(root,geometry,surface),geometry.get_surface_count()>1): included = true
			if included:
				_records[root] = {"object":root,"geometry":geometry,"original_multimesh":null,"replacements":{},"owned_mesh":null,"arrays":{},"analysis":{},"broken":{}}
				count += 1
	for child: Node in root.get_children(): count += prepare(child)
	return count

static func _surface_material(node: GeometryInstance3D, geometry: Mesh, surface: int) -> Material:
	if node.material_override != null: return node.material_override
	if node is MeshInstance3D:
		var overridden: Material = node.get_surface_override_material(surface)
		if overridden != null: return overridden
	return geometry.surface_get_material(surface)

## Panels connect through full welded edges, never corner-only contacts.
static func discover_panels(node: GeometryInstance3D, geometry: Mesh = null) -> Dictionary:
	if geometry == null:
		geometry = node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh != null else null
	var result := {"panels":[],"face_panel":{},"surfaces":[]}
	if geometry == null: return result
	var parents: Dictionary = {}
	var edges: Dictionary = {}
	var faces: Dictionary = {}
	var offset := 0
	for si: int in geometry.get_surface_count():
		var arrays: Array = geometry.surface_get_arrays(si)
		result.surfaces.append(arrays)
		if _primitive(geometry,si) != Mesh.PRIMITIVE_TRIANGLES: continue
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var face_count := int((indices.size() if not indices.is_empty() else positions.size())/3)
		var material: Material = _surface_material(node,geometry,si)
		if not is_breakable_glass(node,material,geometry.get_surface_count()>1):
			offset += face_count
			continue
		var material_key := material.get_instance_id() if material != null else 0
		for fi: int in face_count:
			var v: Array[Vector3] = []
			for j: int in 3: v.append(positions[indices[fi*3+j] if not indices.is_empty() else fi*3+j])
			if (v[1]-v[0]).cross(v[2]-v[0]).length_squared() < 1e-16: continue
			var face := "%d:%d" % [si,fi]
			parents[face] = face
			faces[face] = {"surface":si,"face":fi,"id":offset+fi}
			for e: int in 3:
				var a := _vertex_key(v[e])
				var b := _vertex_key(v[(e+1)%3])
				if a == b: continue
				var edge := str(material_key)+":"+(a+"|"+b if a<b else b+"|"+a)
				if edges.has(edge): parents[_find(parents,face)] = _find(parents,edges[edge])
				else: edges[edge] = face
		offset += face_count
	var grouped: Dictionary = {}
	for face: String in parents:
		var key := _find(parents,face)
		if not grouped.has(key): grouped[key] = {"id":faces[key].id,"faces":[]}
		grouped[key].faces.append(faces[face])
		result.face_panel[face] = grouped[key]
	result.panels = grouped.values()
	return result

static func _vertex_key(v: Vector3) -> String:
	# JS Math.round uses floor(x+.5), including negative coordinates.
	return "%d,%d,%d" % [int(floor(v.x*1e5+.5)),int(floor(v.y*1e5+.5)),int(floor(v.z*1e5+.5))]

static func _find(parents: Dictionary, key: String) -> String:
	var root := key
	while parents[root] != root: root = parents[root]
	var current := key
	while current != root:
		var next: String = parents[current]
		parents[current] = root
		current = next
	return root

func _analysis(record: Dictionary) -> Dictionary:
	if record.analysis.is_empty(): record.analysis = discover_panels(record.object,record.geometry)
	return record.analysis

func _resolve(intersection: Dictionary) -> Dictionary:
	var target: Variant = intersection.get("object")
	if not is_instance_valid(target): return {}
	var record: Dictionary = _records.get(target,{})
	var instance_id := int(intersection.get("instance_id",-1))
	if record.is_empty():
		for candidate: Dictionary in _records.values():
			for id: int in candidate.replacements:
				if candidate.replacements[id] == target:
					record = candidate
					instance_id = id
	if record.is_empty():
		prepare(target)
		record = _records.get(target,{})
	if record.is_empty(): return {}
	if record.object is MultiMeshInstance3D and (instance_id<0 or instance_id>=record.object.multimesh.instance_count): return {}
	var face_key := "%d:%d" % [int(intersection.get("surface_index",-1)),int(intersection.get("face_index",-1))]
	var panel: Dictionary = _analysis(record).face_panel.get(face_key,{})
	if panel.is_empty(): return {}
	return {"record":record,"panel":panel,"instance_id":instance_id,"key":("mesh" if instance_id<0 else str(instance_id))+":"+str(panel.id)}

func _target_for(record: Dictionary, instance_id: int) -> MeshInstance3D:
	if record.object is MeshInstance3D:
		if record.owned_mesh == null:
			# An opaque-wall cutter may have already changed unrelated surfaces.
			var current: Mesh = record.object.mesh
			record.arrays[-1] = _copy_surfaces(current)
			record.owned_mesh = _rebuilt_mesh(current,record.arrays[-1])
			record.object.mesh = record.owned_mesh
			record.arrays[-1] = _copy_surfaces(record.owned_mesh)
		return record.object
	if record.replacements.has(instance_id): return record.replacements[instance_id]
	var source: MultiMeshInstance3D = record.object
	if record.original_multimesh == null:
		record.original_multimesh = source.multimesh
		# Resource.duplicate does not promise an independent renderer-owned
		# MultiMesh transform buffer. Populate a fresh owner explicitly.
		var original: MultiMesh = source.multimesh
		var private := MultiMesh.new()
		private.transform_format = original.transform_format
		private.use_colors = original.use_colors
		private.use_custom_data = original.use_custom_data
		private.mesh = original.mesh
		private.instance_count = original.instance_count
		private.visible_instance_count = original.visible_instance_count
		private.custom_aabb = original.custom_aabb
		for id: int in original.instance_count:
			private.set_instance_transform(id,original.get_instance_transform(id))
			if original.use_colors: private.set_instance_color(id,original.get_instance_color(id))
			if original.use_custom_data: private.set_instance_custom_data(id,original.get_instance_custom_data(id))
		source.multimesh = private
	var transform: Transform3D = source.multimesh.get_instance_transform(instance_id)
	record.arrays[instance_id] = _copy_surfaces(record.geometry)
	var target := MeshInstance3D.new()
	target.name = str(source.name)+"_BrokenInstance_"+str(instance_id)
	target.set_meta("glassEffect",true)
	target.mesh = _rebuilt_mesh(record.geometry,record.arrays[instance_id])
	record.arrays[instance_id] = _copy_surfaces(target.mesh)
	target.material_override = source.material_override
	target.material_overlay = source.material_overlay
	target.cast_shadow = source.cast_shadow
	target.layers = source.layers
	target.transform = transform
	# MultiMesh custom colours would otherwise disappear on a detached instance.
	if source.multimesh.use_colors:
		var tint: Color = source.multimesh.get_instance_color(instance_id)
		for si: int in target.mesh.get_surface_count():
			var material: Material = _surface_material(source,record.geometry,si)
			if material is BaseMaterial3D:
				var copy: BaseMaterial3D = material.duplicate()
				copy.albedo_color *= tint
				target.set_surface_override_material(si,copy)
		if source.material_override != null: target.material_override = null
	source.add_child(target)
	source.multimesh.set_instance_transform(instance_id,_zero())
	record.replacements[instance_id] = target
	return target

static func _copy_surfaces(geometry: Mesh) -> Array:
	var result: Array = []
	for si: int in geometry.get_surface_count():
		var arrays: Array = geometry.surface_get_arrays(si).duplicate(true)
		result.append(arrays)
	return result

static func _rebuilt_mesh(original: Mesh, surfaces: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for si: int in surfaces.size():
		# Retain custom channel encodings; do not feed the vertex-presence flags.
		var format: int = original.surface_get_format(si) if original is ArrayMesh else 0
		var custom_flags := 0
		for shift: int in [Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT]: custom_flags |= format & (Mesh.ARRAY_FORMAT_CUSTOM_MASK << shift)
		mesh.add_surface_from_arrays(_primitive(original,si),surfaces[si],[],{},custom_flags)
		mesh.surface_set_material(si,original.surface_get_material(si))
	return mesh

func hit(intersection: Dictionary, settings: Dictionary = {}) -> Dictionary:
	var object: Variant = intersection.get("object")
	var point: Variant = intersection.get("position")
	if _disposed or not _configured or not is_instance_valid(object) or not object is Node3D or not object.is_inside_tree() or not object.is_visible_in_tree() or not point is Vector3 or not point.is_finite(): return {"broken":false,"reason":"invalid-hit"}
	var found := _resolve(intersection)
	if found.is_empty(): return {"broken":false,"reason":"not-glass-panel"}
	var record: Dictionary = found.record
	if record.broken.has(found.key): return {"broken":false,"reason":"already-broken","panel_id":found.key}
	var current: MeshInstance3D = record.object if record.object is MeshInstance3D else record.replacements.get(found.instance_id)
	if current != null and not _panel_revision_matches(record,current,found.instance_id,found.panel): return {"broken":false,"reason":"stale-glass-surface"}
	if absf(object.global_transform.basis.determinant())<1e-12: return {"broken":false,"reason":"singular-transform"}
	var target := _target_for(record,found.instance_id)
	if absf(target.global_transform.basis.determinant())<1e-12: return {"broken":false,"reason":"singular-transform"}
	var local_point := target.to_local(point)
	var normal: Vector3 = intersection.get("normal",Vector3.BACK)
	if not normal.is_finite() or normal.length_squared()<1e-16: normal = Vector3.BACK
	record.broken[found.key] = true
	_random_state = (int(found.panel.id+1)*7919+maxi(0,found.instance_id)*113+_total_broken*601)&0xffffffff
	var decoration := _decorate(record,target,found.panel,local_point,normal,found.key,found.instance_id)
	_total_broken += 1
	var receipt := {"broken":true,"panel_id":found.key,"object":record.object,"instance_id":found.instance_id,"triangles":found.panel.faces.size(),"shards":0,"weapon_id":settings.get("weapon_id",null)}
	if decoration.is_empty():
		_fracture({"record":record,"target":target,"panel":found.panel,"instance_id":found.instance_id,"fractured":false,"receipt":receipt})
	else:
		receipt.shards = _spawn_shards(decoration,settings)
		decoration.receipt = receipt
	return receipt

func _surface(record: Dictionary, panel: Dictionary, local_point: Vector3, normal: Vector3) -> Dictionary:
	normal = normal.normalized()
	var u := (Vector3.UP if absf(normal.y)<0.9 else Vector3.RIGHT).cross(normal).normalized()
	var v := normal.cross(u).normalized()
	var triangles: Array = []
	var vertices: Array[Vector2] = []
	var bounds := AABB()
	var initialized := false
	for face: Dictionary in panel.faces:
		var arrays: Array = record.analysis.surfaces[face.surface]
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var tri: Array[Vector3] = []
		for j: int in 3:
			var pos := positions[indices[face.face*3+j] if not indices.is_empty() else face.face*3+j]
			tri.append(pos)
			vertices.append(Vector2((pos-local_point).dot(u),(pos-local_point).dot(v)))
			bounds = bounds.expand(pos) if initialized else AABB(pos,Vector3.ZERO)
			initialized = true
		triangles.append(tri)
	return {"hull":_hull(vertices),"normal":normal,"u":u,"v":v,"triangles":triangles,"depth":maxf(0.1,bounds.size.length()),"point":local_point}

static func _hull(points: Array[Vector2]) -> Array[Vector2]:
	var unique: Dictionary = {}
	for p: Vector2 in points: unique["%.5f:%.5f" % [p.x,p.y]] = p
	var sorted: Array = unique.values()
	sorted.sort_custom(func(a: Vector2,b: Vector2): return a.x<b.x or (a.x==b.x and a.y<b.y))
	var lo: Array[Vector2] = []
	var hi: Array[Vector2] = []
	for p: Vector2 in sorted:
		while lo.size()>1 and (lo[-1]-lo[-2]).cross(p-lo[-2])<=0.0: lo.pop_back()
		lo.append(p)
	sorted.reverse()
	for p: Vector2 in sorted:
		while hi.size()>1 and (hi[-1]-hi[-2]).cross(p-hi[-2])<=0.0: hi.pop_back()
		hi.append(p)
	if not lo.is_empty(): lo.pop_back()
	if not hi.is_empty(): hi.pop_back()
	lo.append_array(hi)
	return lo

static func _surface_point(surface: Dictionary, uv: Vector2) -> Vector3:
	var plane: Vector3 = surface.point+surface.u*uv.x+surface.v*uv.y
	var origin: Vector3 = plane+surface.normal*surface.depth
	var nearest := INF
	var best := plane
	for tri: Array in surface.triangles:
		var intersection: Variant = Geometry3D.ray_intersects_triangle(origin,-surface.normal,tri[0],tri[1],tri[2])
		if intersection is Vector3:
			var distance: float = origin.distance_squared_to(intersection)
			if distance<nearest:
				nearest = distance
				best = intersection
	return best+surface.normal*0.002

func _decorate(record: Dictionary,target: MeshInstance3D,panel: Dictionary,point: Vector3,normal: Vector3,key: String,instance_id: int) -> Dictionary:
	var surface := _surface(record,panel,point,normal)
	var hull: Array = surface.hull
	if hull.size()<3: return {}
	var centroid := Vector2.ZERO
	for p: Vector2 in hull: centroid += p
	centroid /= float(hull.size())
	var center := Vector2.ZERO.lerp(centroid,0.025)
	var segments := PackedVector3Array()
	var rim := PackedVector3Array()
	var spokes: Array[Vector2] = []
	for i: int in hull.size():
		var a: Vector2 = hull[i]
		var b: Vector2 = hull[(i+1)%hull.size()]
		var steps := mini(12,maxi(2,int(ceil(a.distance_to(b)/0.22))))
		for j: int in steps:
			var outer_a := a.lerp(b,float(j)/steps)
			var outer_b := a.lerp(b,float(j+1)/steps)
			var inner_a := outer_a.lerp(center,0.012+_random()*0.045)
			var inner_b := outer_b.lerp(center,0.012+_random()*0.045)
			for uv: Vector2 in [outer_a,outer_b,inner_a,inner_a,outer_b,inner_b]: rim.append(_surface_point(surface,uv))
			if spokes.size()<42:
				var end := outer_a.lerp(outer_b,0.2+_random()*0.6)
				var mid := center.lerp(end,0.30+_random()*0.27)
				mid = mid.lerp(centroid,_random()*0.035)
				_add_line(segments,surface,center,mid)
				_add_line(segments,surface,mid,end)
				var branch := mid.lerp(end,0.30).lerp(outer_b,0.12)
				_add_line(segments,surface,mid,branch)
				spokes.append(end)
	for fraction: float in [0.13,0.29,0.51,0.76]:
		for i: int in spokes.size(): _add_line(segments,surface,center.lerp(spokes[i],fraction*(0.86+_random()*0.22)),center.lerp(spokes[(i+1)%spokes.size()],fraction*(0.86+_random()*0.22)))
	var root := Node3D.new()
	root.name = "Broken_Glass_Edges"
	root.set_meta("glassEffect",true)
	root.set_meta("breakableGlass",false)
	target.add_child(root)
	var cracks := MeshInstance3D.new()
	cracks.mesh = _mesh(segments,Mesh.PRIMITIVE_LINES)
	cracks.material_override = _crack_material
	cracks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cracks)
	var edges := MeshInstance3D.new()
	edges.mesh = _mesh(rim,Mesh.PRIMITIVE_TRIANGLES)
	edges.material_override = _rim_material
	edges.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	edges.set_meta("breakableGlass",false)
	edges.visible = false
	root.add_child(edges)
	var decoration := {"root":root,"cracks":cracks,"edges":edges,"age":0.0,"target":target,"panel":panel,"key":key,"record":record,"fractured":false,"surface":surface,"instance_id":instance_id,"receipt":{}}
	_decorations.append(decoration)
	_pending.append(decoration)
	while _decorations.size()>limits.panels:
		var old: Dictionary = _decorations.pop_front()
		_pending.erase(old)
		_fracture(old)
		if is_instance_valid(old.root): old.root.free()
	return decoration

static func _add_line(lines: PackedVector3Array,surface: Dictionary,a: Vector2,b: Vector2) -> void:
	lines.append(_surface_point(surface,a))
	lines.append(_surface_point(surface,b))

static func _same_surface(a: Array,b: Array) -> bool:
	if a.size()!=b.size(): return false
	for i: int in a.size():
		# Native ArrayMesh may represent an absent index as null or empty packed.
		if i==Mesh.ARRAY_INDEX and (a[i]==null or a[i].is_empty()) and (b[i]==null or b[i].is_empty()): continue
		if a[i]!=b[i]: return false
	return true

static func _panel_revision_matches(record: Dictionary,target: MeshInstance3D,instance_id: int,panel: Dictionary) -> bool:
	if target.mesh == null: return false
	var expected: Array = record.arrays.get(instance_id,record.analysis.surfaces)
	var seen: Dictionary = {}
	for face: Dictionary in panel.faces:
		var si: int = face.surface
		if seen.has(si): continue
		seen[si] = true
		if si>=target.mesh.get_surface_count() or si>=expected.size(): return false
		if not _same_surface(target.mesh.surface_get_arrays(si),expected[si]): return false
		if target.mesh.surface_get_material(si)!=record.geometry.surface_get_material(si): return false
	return true

func _fracture(d: Dictionary) -> void:
	if d.fractured or not is_instance_valid(d.target): return
	d.fractured = true
	if not _panel_revision_matches(d.record,d.target,d.instance_id,d.panel):
		d.record.broken.erase(d.get("key",d.receipt.get("panel_id","")))
		_total_broken = maxi(0,_total_broken-1)
		if d.has("root") and is_instance_valid(d.root): d.root.visible = false
		var rejected: Dictionary = d.receipt.duplicate()
		rejected.broken = false
		rejected.reason = "stale-glass-surface"
		fracture_rejected.emit(rejected)
		return
	# Read CURRENT mesh, preserving every other surface changed since our hit.
	# Only this pane's surface arrays are copied into the latest wall revision.
	var current: Mesh = d.target.mesh
	var surfaces: Array = _copy_surfaces(current)
	for face: Dictionary in d.panel.faces:
		var indices: PackedInt32Array = surfaces[face.surface][Mesh.ARRAY_INDEX] if surfaces[face.surface][Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if indices.is_empty():
			for i: int in surfaces[face.surface][Mesh.ARRAY_VERTEX].size(): indices.append(i)
		indices[face.face*3+1] = indices[face.face*3]
		indices[face.face*3+2] = indices[face.face*3]
		surfaces[face.surface][Mesh.ARRAY_INDEX] = indices
	d.target.mesh = _rebuilt_mesh(current,surfaces)
	d.record.arrays[d.instance_id] = _copy_surfaces(d.target.mesh)
	if d.instance_id<0: d.record.owned_mesh = d.target.mesh
	if d.has("edges") and is_instance_valid(d.edges): d.edges.visible = true
	if d.has("cracks") and is_instance_valid(d.cracks): d.cracks.visible = false
	panel_fractured.emit(d.receipt.duplicate())

func _spawn_shards(d: Dictionary,settings: Dictionary) -> int:
	var world: Transform3D = d.target.global_transform
	var normal: Vector3 = (world.basis*d.surface.normal).normalized()
	var side: Vector3 = (world.basis*d.surface.u).normalized()
	var up: Vector3 = (world.basis*d.surface.v).normalized()
	var direction: Vector3 = settings.get("direction",-normal)
	direction = direction.normalized() if direction.is_finite() else -normal
	var impulse := float(settings.get("impulse",20.0))
	if not is_finite(impulse) or impulse == 0.0: impulse = 20.0
	var power := clampf(sqrt(maxf(1.0,impulse))/3.0,0.5,4.0)
	var hull: Array = d.surface.hull
	for j: int in limits.per_hit:
		var a: Vector2 = hull[j%hull.size()]
		var b: Vector2 = hull[(j+1)%hull.size()]
		var uv := a.lerp(b,_random())*sqrt(_random())
		var position: Vector3 = world*_surface_point(d.surface,uv)
		var size := 0.028+_random()*0.11
		var slot := _cursor%int(limits.shards)
		_cursor += 1
		var particle: Dictionary = _shards[slot]
		particle.source = d.record.object
		particle.position = position
		particle.velocity = direction*power*(0.6+_random())+side*(_random()-0.5)*power*2.0+up*(_random()-0.4)*power*1.8
		particle.rotation = Vector3(_random()*6.0,_random()*6.0,_random()*6.0)
		particle.spin = Vector3((_random()-0.5)*18.0,(_random()-0.5)*18.0,(_random()-0.5)*18.0)
		particle.size = size
		particle.life = 2.2+_random()*1.2
		var velocity: Variant = settings.get("velocity")
		if velocity is Vector3 and velocity.is_finite(): particle.velocity += velocity
		_active[slot] = true
		var color := _hsl(0.47+_random()*0.04,0.16+_random()*0.12,0.58+_random()*0.27)
		_particles.multimesh.set_instance_color(slot,color)
		# Optional audit of the actual render submission, never a parallel color
		# simulation. Dummy RenderingServer cannot return MultiMesh buffer data.
		if _render_observer.is_valid(): _render_observer.call(slot,color)
	return limits.per_hit

func advance(dt: float) -> bool:
	if not is_finite(dt) or dt<0.0: return false
	if _disposed or not _configured: return false
	dt = minf(dt,0.1)
	if _pending.is_empty() and _active.is_empty(): return true
	for i in range(_pending.size()-1,-1,-1):
		var d: Dictionary = _pending[i]
		d.age += dt
		if d.age>=FRACTURE_DELAY:
			_fracture(d)
			_pending.remove_at(i)
	if _active.is_empty(): return true
	var inverse := global_transform.affine_inverse()
	for slot: int in _active.keys():
		var shard: Dictionary = _shards[slot]
		shard.life -= dt
		if shard.life<=0.0:
			shard.source = null
			_active.erase(slot)
			_particles.multimesh.set_instance_transform(slot,_zero())
			continue
		shard.velocity.y -= 9.81*dt
		shard.position += shard.velocity*dt
		var floor_y := float(ground_height.call(shard.position.x,shard.position.z)) if ground_height.is_valid() else ground_y
		if not is_finite(floor_y): floor_y = ground_y
		if shard.position.y<floor_y+shard.size*0.1:
			shard.position.y = floor_y+shard.size*0.1
			shard.velocity.y = -shard.velocity.y*0.24 if absf(shard.velocity.y)>0.4 else 0.0
			shard.velocity.x *= exp(-dt*8.0)
			shard.velocity.z *= exp(-dt*8.0)
			shard.spin *= exp(-dt*9.0)
		shard.rotation += shard.spin*dt
		var basis := Basis.from_euler(shard.rotation,EULER_ORDER_XYZ).scaled(Vector3.ONE*shard.size*minf(1.0,maxf(0.0,shard.life)/0.3))
		_particles.multimesh.set_instance_transform(slot,inverse*Transform3D(basis,shard.position))
	return true

func shatter_all(root: Node,settings: Dictionary = {}) -> Dictionary:
	prepare(root)
	var broken := 0
	for record: Dictionary in _records.values():
		var object: Node3D = record.object
		if not is_instance_valid(object) or not (object==root or root.is_ancestor_of(object)) or not object.is_visible_in_tree(): continue
		var instance_count: int = object.multimesh.instance_count if object is MultiMeshInstance3D else 1
		for id: int in instance_count:
			for panel: Dictionary in _analysis(record).panels:
				var face: Dictionary = panel.faces[0]
				var arrays: Array = record.analysis.surfaces[face.surface]
				var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
				var v: Array[Vector3] = []
				for j: int in 3: v.append(positions[indices[face.face*3+j] if not indices.is_empty() else face.face*3+j])
				var normal := (v[1]-v[0]).cross(v[2]-v[0]).normalized()
				var point := (v[0]+v[1]+v[2])/3.0
				if object is MultiMeshInstance3D:
					var original: MultiMesh = record.original_multimesh if record.original_multimesh!=null else object.multimesh
					point = original.get_instance_transform(id)*point
				var receipt := hit({"object":object,"instance_id":id if object is MultiMeshInstance3D else -1,"surface_index":face.surface,"face_index":face.face,"position":object.global_transform*point,"normal":normal},settings)
				if receipt.get("broken",false): broken += 1
	return {"broken":broken}

func reset(root: Node = null) -> void:
	var selected: Dictionary = {}
	for object: Variant in _records:
		if root == null or (is_instance_valid(object) and (root==object or root.is_ancestor_of(object))): selected[object] = true
	for i in range(_decorations.size()-1,-1,-1):
		var d: Dictionary = _decorations[i]
		if selected.has(d.record.object):
			_pending.erase(d)
			if is_instance_valid(d.root): d.root.free()
			_decorations.remove_at(i)
	for object: Variant in selected:
		var record: Dictionary = _records[object]
		if is_instance_valid(object):
			if record.owned_mesh!=null and object is MeshInstance3D:
				# Restore only glass owned by this port. Concurrent opaque wall cuts
				# survive reset. A changed glass surface belongs to its newer writer.
				var current: Mesh = object.mesh
				var restored: Array = []
				for si: int in current.get_surface_count(): restored.append(current.surface_get_arrays(si))
				var source_surfaces: Array = record.analysis.surfaces
				var expected: Array = record.arrays[-1]
				var restored_any := false
				for si: int in mini(source_surfaces.size(),restored.size()):
					if is_breakable_glass(object,_surface_material(object,record.geometry,si),record.geometry.get_surface_count()>1) and _same_surface(restored[si],expected[si]):
						restored[si] = source_surfaces[si]
						restored_any = true
				if restored_any:
					var equals_original: bool = restored.size()==record.geometry.get_surface_count()
					for si: int in restored.size():
						if si>=source_surfaces.size() or not _same_surface(restored[si],source_surfaces[si]) or current.surface_get_material(si)!=record.geometry.surface_get_material(si): equals_original = false
					object.mesh = record.geometry if equals_original else _rebuilt_mesh(current,restored)
			for replacement: Variant in record.replacements.values():
				if is_instance_valid(replacement): replacement.free()
			if record.original_multimesh!=null: object.multimesh = record.original_multimesh
		record.owned_mesh = null
		record.original_multimesh = null
		record.replacements.clear()
		record.arrays.clear()
		record.broken.clear()
	for slot: int in _active.keys():
		if selected.has(_shards[slot].source):
			_shards[slot].source = null
			_shards[slot].life = 0.0
			_active.erase(slot)
			_particles.multimesh.set_instance_transform(slot,_zero())
	_total_broken = 0
	for record: Dictionary in _records.values(): _total_broken += record.broken.size()

func dispose() -> void:
	if _disposed: return
	reset()
	_records.clear()
	_disposed = true
	if is_instance_valid(_particles): _particles.free()
	_particles = null
	_shards.clear()
	_crack_material = null
	_rim_material = null
	_render_observer = Callable()

func stats() -> Dictionary:
	return {"registered_meshes":_records.size(),"broken_panels":_total_broken,"decorated_panels":_decorations.size(),"active_shards":_active.size(),"pending_fractures":_pending.size(),"limits":limits.duplicate()}

func _random() -> float:
	_random_state = (1664525*_random_state+1013904223)&0xffffffff
	return float(_random_state)/4294967296.0

static func _zero() -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO)

static func _material(color: Color,alpha: float,metalness: float,roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color,alpha)
	material.metallic = metalness
	material.roughness = roughness
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

static func _mesh(vertices: PackedVector3Array,primitive: Mesh.PrimitiveType) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	if primitive==Mesh.PRIMITIVE_TRIANGLES:
		var normals := PackedVector3Array()
		for i in range(0,vertices.size(),3):
			var normal := (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).normalized()
			for j: int in 3: normals.append(normal)
		arrays[Mesh.ARRAY_NORMAL] = normals
	var result := ArrayMesh.new()
	if not vertices.is_empty(): result.add_surface_from_arrays(primitive,arrays)
	return result

static func _hsl(h: float,s: float,l: float) -> Color:
	if s==0.0: return Color(l,l,l)
	var p := l*(1.0+s) if l<=0.5 else l+s-l*s
	var q := 2.0*l-p
	return Color(_hue(q,p,h+1.0/3.0),_hue(q,p,h),_hue(q,p,h-1.0/3.0))

static func _hue(p: float,q: float,t: float) -> float:
	t = fposmod(t,1.0)
	if t<1.0/6.0: return p+(q-p)*6.0*t
	if t<0.5: return q
	if t<2.0/3.0: return p+(q-p)*6.0*(2.0/3.0-t)
	return p
