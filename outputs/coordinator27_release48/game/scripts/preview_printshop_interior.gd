extends Node3D
## Source-generated, one-building adapter. Root retains game/action authority.
## Call attach_existing on a scene-root child before removing the three old bodies.

const InteriorFinish = preload("res://scripts/preview_interior_finish.gd")
# Proven by actual source generator customProgramCacheKey, not floorCollision.
const FINISH_ROLES := {15: {"name":"InteriorFinish_concrete", "floor":true}, 16: {"name":"InteriorFinish_brick", "floor":false}}
var _finish_factory: RefCounted

const SOURCE_ID := "REBUILD-VISUAL-print_shop-001"
const ASSET_SHA := "ad7b8ef7e7e4143f0e989b7a585c03bb9bd1c13d5efb8689cf67ebcb92ac4d97"
var ready_for_use: bool = false
var errors: PackedStringArray = []
var _data: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _material_cache: Dictionary = {}
var _doors: Dictionary = {}
var _restores: Array[Dictionary] = []
var _visual: Node3D


func attach_existing(visual: Node3D, building: Dictionary, data: Dictionary) -> bool:
	if ready_for_use or _visual != null:
		return false
	errors.clear()
	if str(data.get("schema", "")) != "mafiozi-printshop-interior-v1" or str(data.get("sourceId", "")) != SOURCE_ID or str(building.get("id", "")) != SOURCE_ID:
		errors.append("Wrong building/schema")
	if str(data.get("assetSha256", "")) != ASSET_SHA or str(building.get("binding", {}).get("sha256", "")) != ASSET_SHA:
		errors.append("Source binding mismatch")
	if data.get("transform", {}) != building.get("transform", {}):
		errors.append("Source placement mismatch")
	var replace_indices: Array = data.get("replaceCollisionSourceIndices", [])
	if replace_indices.size() != 3 or int(replace_indices[0]) != 0 or int(replace_indices[1]) != 1 or int(replace_indices[2]) != 2 or building.get("collisionBodiesM", []).size() != 3:
		errors.append("Expected exactly three exterior collision bodies")
	if visual == null or visual.has_meta("printshop_interior_attached"):
		errors.append("Missing or already attached visual")
	if not errors.is_empty():
		return false
	if not global_transform.is_equal_approx(Transform3D.IDENTITY):
		errors.append("Adapter must use scene-root preview coordinates")
	var placement: Dictionary = building.transform
	if not _finite_array(data.get("originM"), 3) or not _v3(data.originM).is_equal_approx(_v3(placement.positionM) - _v3(building.positionLocalM)):
		errors.append("Preview origin mismatch")
	var uniform: float = float(placement.uniformScale)
	var horizontal: Array = placement.horizontalScale
	var basis := Basis(Vector3.UP, deg_to_rad(float(placement.yawDegrees))) * Basis.from_scale(Vector3(uniform * float(horizontal[0]), uniform, uniform * float(horizontal[1])))
	var expected := Transform3D(basis, _v3(building.positionLocalM)) * Transform3D(Basis.IDENTITY, _v3(placement.modelLocalOffsetM))
	if not visual.global_transform.is_equal_approx(expected):
		errors.append("Existing visual has a different placement")
	_validate_package(data)
	if not errors.is_empty():
		return false
	var original: Dictionary = {}
	_collect_meshes(visual, original)
	for override: Dictionary in data.get("overrides", []):
		if not original.has(_normalize(str(override.sourceName))):
			errors.append("Missing original mesh: " + str(override.sourceName))
	for hidden: String in data.get("hideOriginalNames", []):
		if not original.has(_normalize(hidden)):
			errors.append("Missing moving source mesh: " + hidden)
	if not errors.is_empty():
		return false
	_data = data
	# Build resources first: a rejected package must leave source visuals intact.
	for spec: Dictionary in data.overrides:
		_mesh(spec)
	for spec: Dictionary in data.meshes:
		_mesh(spec)
	if not errors.is_empty():
		_mesh_cache.clear()
		_material_cache.clear()
		_release_finish_factory()
		return false
	_visual = visual
	for key: String in data.doors:
		var spec: Dictionary = data.doors[key]
		var pivot := Node3D.new()
		pivot.name = "SourceDoor_" + key
		pivot.transform = _matrix(spec.transform)
		add_child(pivot)
		_doors[key] = {"node": pivot, "base": pivot.transform, "fraction": 0.0, "target": 0.0, "spec": spec, "bounds": []}
		for body: Dictionary in spec.bodies:
			var vertices := PackedVector3Array()
			for point: Array in body.pointsLocal:
				vertices.append(_v3(point))
			var bounds := AABB(vertices[0], Vector3.ZERO)
			for point: Vector3 in vertices:
				bounds = bounds.expand(point)
			_doors[key].bounds.append(bounds)
			_add_convex(vertices, pivot, "door:" + key)
	for spec: Dictionary in data.meshes:
		var mesh: ArrayMesh = _mesh(spec)
		if mesh.get_surface_count() == 0:
			continue
		var target: Node3D = self if str(spec.motion).is_empty() else _doors[str(spec.motion)].node
		var visual_part: Node3D
		if spec.has("instances"):
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.use_colors = spec.has("instanceColorsLinear")
			multi.mesh = mesh
			multi.instance_count = spec.instances.size()
			for i: int in range(multi.instance_count):
				multi.set_instance_transform(i, _matrix(spec.instances[i]))
				if multi.use_colors:
					multi.set_instance_color(i, _linear_color(spec.instanceColorsLinear[i]))
			var batch := MultiMeshInstance3D.new()
			batch.multimesh = multi
			visual_part = batch
		else:
			var instance := MeshInstance3D.new()
			instance.mesh = mesh
			visual_part = instance
		visual_part.name = str(spec.name) if not str(spec.name).is_empty() else "SourceGeneratedPart"
		visual_part.transform = _matrix(spec.transform)
		target.add_child(visual_part)
		if bool(spec.floorCollision):
			_add_floor_faces(mesh, spec)
	for body: Dictionary in data.staticBodies:
		var vertices := PackedVector3Array()
		for p: Array in body.polygonXZ:
			vertices.append(Vector3(float(p[0]), float(body.minY), float(p[1])))
			vertices.append(Vector3(float(p[0]), float(body.maxY), float(p[1])))
		_add_convex(vertices, self, "source-static")
	for spec: Dictionary in data.overrides:
		var node: MeshInstance3D = original[_normalize(str(spec.sourceName))]
		_restores.append({"node": node, "mesh": node.mesh, "visible": node.visible})
		node.mesh = _mesh(spec)
		node.visible = node.mesh.get_surface_count() > 0
	for name_value: String in data.hideOriginalNames:
		var node: MeshInstance3D = original[_normalize(name_value)]
		_restores.append({"node": node, "mesh": node.mesh, "visible": node.visible})
		node.visible = false
	visual.set_meta("printshop_interior_attached", true)
	ready_for_use = true
	return true


func anchor(key: String) -> Vector3:
	return _v3(_data.anchors[key]) if _data.get("anchors", {}).has(key) else Vector3.INF


func nearest_action(actor_position: Vector3) -> Dictionary:
	var best: Dictionary = {}
	if not ready_for_use:
		return best
	for key: String in _doors:
		# The source service leaf is controlled by staff, not a player purchase/action shortcut.
		if key != "public":
			continue
		var d: Dictionary = _doors[key]
		var distance: float = actor_position.distance_to(_v3(d.spec.anchor))
		if distance <= float(d.spec.proximity) and (best.is_empty() or distance < float(best.distance)):
			best = {"door": key, "source_id": SOURCE_ID, "distance": distance, "opening": float(d.target) > 0.5, "label": "Закрыть дверь" if float(d.target) > 0.5 else "Открыть дверь"}
	return best


func request_door(key: String, open: bool, actor_position: Vector3, occupants: Array) -> Dictionary:
	if not ready_for_use or not _doors.has(key) or not actor_position.is_finite():
		return {"accepted": false, "reason": "invalid-door-request"}
	var d: Dictionary = _doors[key]
	if key == "service" and open and actor_position.distance_to(anchor("doorInside")) > 0.25:
		return {"accepted": false, "reason": "staff-not-at-door"}
	if key == "public" and actor_position.distance_to(_v3(d.spec.anchor)) > float(d.spec.proximity):
		return {"accepted": false, "reason": "out-of-range"}
	var target: float = 1.0 if open else 0.0
	if not _sweep_clear(d, float(d.fraction), target, occupants):
		return {"accepted": false, "reason": "door-sweep-occupied"}
	d.target = target
	return {"accepted": true, "open": open}


func advance(delta: float, occupants: Array) -> void:
	if not ready_for_use or not is_finite(delta) or delta <= 0.0:
		return
	for key: String in _doors:
		var d: Dictionary = _doors[key]
		if is_equal_approx(float(d.fraction), float(d.target)):
			continue
		var next: float = move_toward(float(d.fraction), float(d.target), minf(delta, 0.1) / float(d.spec.duration))
		if not _sweep_clear(d, float(d.fraction), next, occupants):
			continue
		d.fraction = next
		var angle: float = float(d.spec.angle) * next * next * (3.0 - 2.0 * next)
		d.node.transform = d.base * Transform3D(Basis(Vector3.UP, angle), Vector3.ZERO)


func door_fraction(key: String) -> float:
	return float(_doors[key].fraction) if _doors.has(key) else -1.0


func restore_original() -> void:
	for saved: Dictionary in _restores:
		if is_instance_valid(saved.node):
			saved.node.mesh = saved.mesh
			saved.node.visible = saved.visible
	_restores.clear()
	if is_instance_valid(_visual):
		_visual.remove_meta("printshop_interior_attached")
	_visual = null
	ready_for_use = false
	for child: Node in get_children():
		child.free()
	_doors.clear()
	_mesh_cache.clear()
	_material_cache.clear()
	_release_finish_factory()


func _release_finish_factory() -> void:
	if _finish_factory != null:
		_finish_factory.dispose()
	_finish_factory = null


func _sweep_clear(door: Dictionary, from: float, to: float, occupants: Array) -> bool:
	if occupants.size() > 64:
		return false
	var a: float = float(door.spec.angle) * smoothstep(0.0, 1.0, from)
	var b: float = float(door.spec.angle) * smoothstep(0.0, 1.0, to)
	var steps: int = maxi(1, ceili(absf(b - a) / 0.035))
	for occupant: Variant in occupants:
		if not occupant is Dictionary or not occupant.get("position") is Vector3:
			return false
		var p: Vector3 = occupant.position
		var radius: float = float(occupant.get("radius", 0.0))
		var height: float = float(occupant.get("height", 0.0))
		if not p.is_finite() or not is_finite(radius) or not is_finite(height) or radius <= 0.0 or height <= 0.0:
			return false
		for step: int in range(steps + 1):
			var angle: float = lerpf(a, b, float(step) / float(steps))
			var frame: Transform3D = door.base * Transform3D(Basis(Vector3.UP, angle), Vector3.ZERO)
			var local: Vector3 = frame.affine_inverse() * p
			for bounds: AABB in door.bounds:
				if local.y >= bounds.end.y or local.y + height <= bounds.position.y:
					continue
				var dx: float = maxf(maxf(bounds.position.x - local.x, 0.0), local.x - bounds.end.x)
				var dz: float = maxf(maxf(bounds.position.z - local.z, 0.0), local.z - bounds.end.z)
				if Vector2(dx, dz).length() < radius + 0.03:
					return false
	return true


func _collect_meshes(node: Node, result: Dictionary) -> void:
	if node is MeshInstance3D:
		var key: String = _normalize(str(node.name))
		if result.has(key):
			errors.append("Ambiguous source mesh: " + key)
		result[key] = node
	for child: Node in node.get_children():
		_collect_meshes(child, result)


func _validate_package(data: Dictionary) -> void:
	for key: String in ["geometry", "materials", "meshes", "overrides", "staticBodies", "hideOriginalNames"]:
		if not data.get(key) is Array or data[key].is_empty():
			errors.append("Missing package array: " + key)
	if not errors.is_empty():
		return
	for geometry: Variant in data.geometry:
		if not geometry is Dictionary or not geometry.get("attributes") is Dictionary or not geometry.attributes.get("position") is Dictionary:
			errors.append("Invalid geometry descriptor")
			return
		var position: Variant = geometry.attributes.position.get("values")
		if not position is Array or position.size() % 3 != 0:
			errors.append("Invalid geometry positions")
			return
		var count: int = position.size() / 3
		for key: String in geometry.attributes:
			var attribute: Dictionary = geometry.attributes[key]
			var width: int = int(attribute.get("size", 0))
			if width < 2 or width > 4 or not attribute.get("values") is Array or attribute.values.size() != count * width:
				errors.append("Invalid geometry attribute")
				return
			for value: Variant in attribute.values:
				if not _finite_number(value):
					errors.append("Non-finite geometry attribute")
					return
		if geometry.get("indices") != null:
			if not geometry.indices is Array or geometry.indices.size() % 3 != 0:
				errors.append("Invalid triangle index array")
				return
			for index: Variant in geometry.indices:
				if not _finite_number(index) or int(index) != float(index) or int(index) < 0 or int(index) >= count:
					errors.append("Triangle index outside source vertices")
					return
	for spec: Variant in data.meshes + data.overrides:
		if not spec is Dictionary or int(spec.get("geometry", -1)) < 0 or int(spec.get("geometry", -1)) >= data.geometry.size() or not spec.get("materials") is Array or spec.materials.is_empty():
			errors.append("Invalid mesh descriptor")
			return
		for index: Variant in spec.materials:
			if not _finite_number(index) or int(index) < 0 or int(index) >= data.materials.size():
				errors.append("Material index outside source materials")
				return
		if spec.has("transform") and not _finite_array(spec.transform, 16):
			errors.append("Invalid mesh transform")
			return
		for matrix: Variant in spec.get("instances", []):
			if not _finite_array(matrix, 16):
				errors.append("Invalid source instance transform")
				return
		if spec.has("instanceColorsLinear"):
			if spec.instanceColorsLinear.size() != spec.get("instances", []).size():
				errors.append("Instance color count mismatch")
				return
			for color: Variant in spec.instanceColorsLinear:
				if not _finite_array(color, 3):
					errors.append("Invalid source instance color")
					return
	for material: Dictionary in data.materials:
		if not _finite_array(material.get("colorLinear"), 3) or not _finite_array(material.get("emissiveLinear"), 3):
			errors.append("Invalid source material color")
			return
	for key: String in ["public", "service"]:
		if not data.get("doors", {}).has(key) or not _finite_array(data.doors[key].get("transform"), 16):
			errors.append("Missing physical door")
			return
	for body: Dictionary in data.staticBodies:
		if not body.get("polygonXZ") is Array or body.polygonXZ.size() < 3 or not _finite_number(body.get("minY")) or not _finite_number(body.get("maxY")) or float(body.minY) >= float(body.maxY):
			errors.append("Invalid source collision body")
			return
		for point: Variant in body.polygonXZ:
			if not _finite_array(point, 2):
				errors.append("Invalid collision polygon")
				return


func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


func _finite_array(value: Variant, length: int) -> bool:
	if not value is Array or value.size() != length:
		return false
	for item: Variant in value:
		if not _finite_number(item):
			return false
	return true


func _normalize(value: String) -> String:
	var result: String = ""
	for c: String in value.to_lower():
		if c >= "a" and c <= "z" or c >= "0" and c <= "9":
			result += c
	return result


func _mesh(spec: Dictionary) -> ArrayMesh:
	var key: String = str(spec.geometry) + ":" + str(spec.materials) + ":" + str(spec.has("instanceColorsLinear"))
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var result := ArrayMesh.new()
	_mesh_cache[key] = result
	var source: Dictionary = _data.geometry[int(spec.geometry)]
	var attributes: Dictionary = source.attributes
	var vertices: Array = attributes.position.values
	var count: int = vertices.size() / 3
	if count == 0:
		return result
	var source_indices: Array = source.indices if source.indices != null else range(count)
	# Three ignores BoxGeometry's six material groups for a single material.
	var groups: Array = source.groups if spec.materials.size() > 1 and not source.groups.is_empty() else [{"start": 0, "count": source_indices.size(), "materialIndex": 0}]
	for group: Dictionary in groups:
		if int(group.count) < 3:
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		var points := PackedVector3Array()
		for i: int in range(0, vertices.size(), 3):
			points.append(Vector3(vertices[i], vertices[i + 1], vertices[i + 2]))
		arrays[Mesh.ARRAY_VERTEX] = points
		if attributes.has("normal"):
			var normals := PackedVector3Array()
			var values: Array = attributes.normal.values
			for i: int in range(0, values.size(), 3):
				normals.append(Vector3(values[i], values[i + 1], values[i + 2]))
			arrays[Mesh.ARRAY_NORMAL] = normals
		if attributes.has("uv"):
			var coords := PackedVector2Array()
			var values: Array = attributes.uv.values
			for i: int in range(0, values.size(), 2):
				coords.append(Vector2(values[i], values[i + 1]))
			arrays[Mesh.ARRAY_TEX_UV] = coords
		if attributes.has("color"):
			var colors := PackedColorArray()
			var values: Array = attributes.color.values
			var size: int = int(attributes.color.size)
			for i: int in range(0, values.size(), size):
				colors.append(Color(values[i], values[i + 1], values[i + 2], values[i + 3] if size == 4 else 1.0))
			arrays[Mesh.ARRAY_COLOR] = colors
		var indices := PackedInt32Array()
		# Three/glTF front faces are CCW; Godot ArrayMesh front faces are CW.
		for i: int in range(int(group.start), int(group.start + group.count), 3):
			indices.append(int(source_indices[i]))
			indices.append(int(source_indices[i + 2]))
			indices.append(int(source_indices[i + 1]))
		arrays[Mesh.ARRAY_INDEX] = indices
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(result.get_surface_count() - 1, _material(int(spec.materials[int(group.materialIndex)]), spec.has("instanceColorsLinear") or attributes.has("color")))
	return result


func _material(index: int, colored: bool) -> Material:
	var key: String = str(index) + ":" + str(colored)
	if _material_cache.has(key):
		return _material_cache[key]
	var source: Dictionary = _data.materials[index]
	# Preserve the exact original StandardMaterial path for all other materials,
	# vertex/instance colors, unsupported factors or uncertain source identities.
	if not colored and FINISH_ROLES.has(index) and source.get("name") == FINISH_ROLES[index].name:
		if _finish_factory == null:
			_finish_factory = InteriorFinish.new()
		var finish: ShaderMaterial = _finish_factory.material_for(source,FINISH_ROLES[index].floor,_v3(_data.originM))
		if finish != null:
			finish.set_meta("source_linear_color",source.colorLinear)
			finish.set_meta("source_procedural_shader_pending",false)
			_material_cache[key] = finish
			return finish
	var material := StandardMaterial3D.new()
	material.albedo_color = _linear_color(source.colorLinear).linear_to_srgb()
	material.albedo_color.a = float(source.opacity)
	material.roughness = float(source.roughness)
	material.metallic = float(source.metalness)
	material.vertex_color_use_as_albedo = colored
	material.vertex_color_is_srgb = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED if bool(source.doubleSided) else BaseMaterial3D.CULL_BACK
	if bool(source.transparent):
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var emissive: Color = _linear_color(source.emissiveLinear)
	if emissive.r + emissive.g + emissive.b > 0.0:
		material.emission_enabled = true
		material.emission = emissive.linear_to_srgb()
		material.emission_energy_multiplier = float(source.emissiveIntensity)
	material.set_meta("source_linear_color", source.colorLinear)
	material.set_meta("source_procedural_shader_pending", source.sourceProceduralShader)
	_material_cache[key] = material
	return material


func _add_floor_faces(mesh: ArrayMesh, spec: Dictionary) -> void:
	var faces: PackedVector3Array = mesh.get_faces()
	var transformed := PackedVector3Array()
	var instances: Array = spec.get("instances", [])
	if instances.is_empty():
		instances = [[1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]]
	for instance: Array in instances:
		var matrix: Transform3D = _matrix(spec.transform) * _matrix(instance)
		for point: Vector3 in faces:
			transformed.append(matrix * point)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(transformed)
	shape.backface_collision = true
	_add_shape(shape, self, "source-floor-ceiling")


func _add_convex(points: PackedVector3Array, parent: Node3D, kind: String) -> void:
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	_add_shape(shape, parent, kind)


func _add_shape(shape: Shape3D, parent: Node3D, kind: String) -> void:
	var body := StaticBody3D.new()
	body.set_meta("source_id", SOURCE_ID)
	body.set_meta("interior_kind", kind)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _linear_color(value: Array) -> Color:
	return Color(float(value[0]), float(value[1]), float(value[2]))


func _v3(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _matrix(value: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(value[0], value[1], value[2]), Vector3(value[4], value[5], value[6]), Vector3(value[8], value[9], value[10])), Vector3(value[12], value[13], value[14]))
