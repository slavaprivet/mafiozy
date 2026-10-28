extends Node3D
## Visual equipment tied to existing live merlons; never adds collision or actors.
## Call install(castle) after castle.install(). All transforms are castle-local.

var _anchors: Array[Dictionary] = []
var _installed := false
var _elapsed := 0.0
var _batches := 0
var _hidden := 0
var _triangles := 0

func install(castle: Node3D) -> Dictionary:
	if _installed: return {"ok": false, "reason": "already_installed"}
	var cells: Variant = castle.get("_cells")
	if not cells is Array: return {"ok": false, "reason": "no_cells"}
	_installed = true
	name = "WallDefense24"
	castle.add_child(self)
	var mesh := _shield_mesh()
	_triangles = mesh.surface_get_array_len(0) / 3
	var groups: Dictionary = {}
	for cell: Dictionary in cells:
		if cell.get("group", "") != "south_merlon" or int(cell.get("row", -1)) != 1: continue
		var at: Vector3 = cell["at"]
		# Leave gate towers and corners clear; one shield every eight metres.
		if absf(at.x) < 15.0 or absf(at.x) > 56.0 or int(cell.get("column", 0)) % 8 != 0: continue
		if not bool(cell.get("alive", false)): continue
		var key := int(floor(at.x / 26.0))
		if not groups.has(key): groups[key] = []
		groups[key].append(cell)
	for key: int in groups:
		var selected: Array = groups[key]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = selected.size()
		for slot: int in selected.size():
			var cell: Dictionary = selected[slot]
			var at: Vector3 = cell["at"]
			at += Vector3(0, -.10, .36)
			var lean := float(int(cell["column"]) % 3 - 1) * .045
			multi.set_instance_transform(slot, Transform3D(Basis(Vector3.FORWARD, lean), at))
			_anchors.append({"cell": cell, "multi": multi, "slot": slot, "at": at, "live": true})
		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(node)
		_batches += 1
	set_process(not _anchors.is_empty())
	return {"ok": true, "stats": get_stats()}

func get_stats() -> Dictionary:
	return {"shields": _anchors.size(), "hidden": _hidden, "batches": _batches,
		"triangles": _triangles * _anchors.size(), "shared_meshes": 1,
		"physics_bodies": 0, "shadow_draws": 0}

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < .10: return
	_elapsed = 0.0
	# Only the selected dictionaries, never scan the castle each frame.
	for anchor: Dictionary in _anchors:
		if not bool(anchor["live"]) or bool(anchor["cell"].get("alive", false)): continue
		var multi: MultiMesh = anchor["multi"]
		# Keep the old origin so hiding never stretches this chunk's culling bounds.
		multi.set_instance_transform(int(anchor["slot"]), Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), anchor["at"]))
		anchor["live"] = false
		_hidden += 1
	if _hidden == _anchors.size(): set_process(false)

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
	surface.set_color(tint)
	for v: Vector3 in [a, b, c]: surface.add_vertex(v)

func _box(surface: SurfaceTool, center: Vector3, size: Vector3, rotation: Vector3, tint: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var basis := Basis.from_euler(rotation)
	surface.set_color(tint)
	for index: int in indices: surface.add_vertex(center + basis * vertices[index])

func _shield_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := Color(.25, .19, .11)
	var paint := Color(.25, .035, .026)
	# Raised bronze rim, dark red convex face and a hammered central boss.
	var rings := [Vector3(.0, .0, .23), Vector3(.14, .18, .17), Vector3(.43, .59, .09), Vector3(.49, .65, .08)]
	for ring: int in 3:
		for segment: int in 20:
			var angle0 := TAU * float(segment) / 20.0
			var angle1 := TAU * float(segment + 1) / 20.0
			var r0: Vector3 = rings[ring]
			var r1: Vector3 = rings[ring + 1]
			var a := Vector3(cos(angle0) * r0.x, sin(angle0) * r0.y, r0.z)
			var b := Vector3(cos(angle1) * r0.x, sin(angle1) * r0.y, r0.z)
			var c := Vector3(cos(angle0) * r1.x, sin(angle0) * r1.y, r1.z)
			var d := Vector3(cos(angle1) * r1.x, sin(angle1) * r1.y, r1.z)
			var tint := rim if ring != 1 else paint.lightened(.025 * float(segment % 3))
			_triangle(surface, a, c, b, tint)
			_triangle(surface, b, c, d, tint)
	# Distinct pale chevron; narrow gouges reveal wood under the red paint.
	for side: float in [-1.0, 1.0]:
		_box(surface, Vector3(side * .20, -.19, .15), Vector3(.055, .36, .016), Vector3(0, 0, side * -.65), Color(.57, .43, .22))
	for y: float in [.31, -.36]:
		_box(surface, Vector3(.13, y, .15), Vector3(.23, .012, .012), Vector3(0, 0, -.35), Color(.43, .29, .14))
	# One embedded arrow, including paired fletching, shares the same draw.
	_box(surface, Vector3(-.22, .22, .45), Vector3(.018, .018, .70), Vector3(.10, -.16, 0), Color(.26, .17, .08))
	_box(surface, Vector3(-.275, .19, .73), Vector3(.11, .012, .15), Vector3(0, -.16, 0), Color(.38, .35, .29))
	_box(surface, Vector3(-.275, .19, .73), Vector3(.012, .11, .15), Vector3(0, -.16, 0), Color(.38, .35, .29))
	surface.generate_normals()
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = .77
	material.metallic = .18
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	return mesh
