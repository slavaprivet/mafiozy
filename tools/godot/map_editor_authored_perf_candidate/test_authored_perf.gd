extends SceneTree
const BaseFactory = preload("res://scripts/map_editor/catalog_factory.gd")
const FastFactory = preload("res://authored_factory_perf.gd")
const BaseRegistry = preload("res://scripts/map_editor/object_registry.gd")
const FastRegistry = preload("res://authored_registry_perf.gd")
var checks := 0
var failures := []
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func structure(root: Node3D) -> Array:
	var result := []
	var nodes := [root]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		nodes.append_array(node.get_children())
		# Unnamed native collision nodes receive distinct runtime @IDs. Preserve
		# exact authored names, but compare topology by original child indices.
		var topology := []
		var ancestor: Node = node
		while ancestor!=root:
			topology.push_front(ancestor.get_index())
			ancestor = ancestor.get_parent()
		var row := {"topology":topology,"class":node.get_class()}
		if node!=root and not str(node.name).begins_with("@"): row.name = str(node.name)
		if node is Node3D: row.merge({"pose":node.transform,"visible":node.visible})
		if node is MeshInstance3D:
			row.mesh = node.mesh
			row.cast_shadow = node.cast_shadow
			row.materials = []
			for index in node.mesh.get_surface_count(): row.materials.append(node.get_active_material(index))
		if node is CollisionObject3D: row.merge({"layer":node.collision_layer,"mask":node.collision_mask})
		if node is CollisionShape3D: row.merge({"type":node.shape.get_class(),"points":node.shape.points.to_byte_array(),"margin":node.shape.margin})
		result.append(row)
	return result
func snapshots_equal(a: Dictionary,b: Dictionary) -> bool:
	for field in ["base","record","editable","bounds","deleted","opaque","opaque_transport","transform_extra","transform_extra_transport"]:
		if a[field]!=b[field]: return false
	for field in ["bodies","participants"]:
		if a[field].size()!=b[field].size(): return false
		for index in a[field].size():
			for key in a[field][index]:
				if key=="node":
					if a[field][index][key].get_ref()!=b[field][index][key].get_ref(): return false
				elif a[field][index][key]!=b[field][index][key]: return false
	return true
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	var original := BaseFactory.new()
	var candidate := FastFactory.new()
	check(original.configure(catalog) and candidate.configure(catalog),"catalog admit")
	var host := Node3D.new()
	root.add_child(host)
	var base_registry := BaseRegistry.new()
	var fast_registry := FastRegistry.new()
	for object: Dictionary in catalog.objects:
		if not object.has("resourceId"): continue
		var a: Dictionary = original.spawn_key(object.key,{"exterior_collisions":true})
		var b: Dictionary = candidate.spawn_key(object.key,{"exterior_collisions":true})
		host.add_child(a.root)
		host.add_child(b.root)
		check(a.ok and b.ok and a.pending==b.pending,"exact source gates")
		check(a.resource==b.resource,"same original PackedScene")
		check(structure(a.root)==structure(b.root),"all actual nodes pose/helper/mesh/material/shape/layers exact")
		var record := {"kind":object.dataset,"model":object.resourceId,"source":object.sourceRecord.duplicate(true)}
		check(base_registry.register_object(object.key,a.root,record).ok and fast_registry.register_object(object.key,a.root,record).ok,"same source root register")
		check(snapshots_equal(base_registry._entries[object.key],fast_registry._entries[object.key]),"exact WeakRefs/participants/bodies/bounds/opaque source")
	check(base_registry.source_document("audit")==fast_registry.source_document("audit"),"source document no content change")
	# Dependency behavior must match even for descendant/external duplicate bodies.
	var own := Node3D.new()
	var descendant := StaticBody3D.new()
	var detached := StaticBody3D.new()
	var external_child := StaticBody3D.new()
	host.add_child(own)
	own.add_child(descendant)
	host.add_child(detached)
	detached.add_child(external_child)
	var dependencies := [descendant,detached,external_child,detached]
	check(base_registry.register_object("fixture",own,{"kind":"fixture"},dependencies).ok and fast_registry.register_object("fixture",own,{"kind":"fixture"},dependencies).ok,"same dependency admission")
	check(snapshots_equal(base_registry._entries.fixture,fast_registry._entries.fixture),"detached and descendant dependency exact semantics")
	# Exact names, not broad substring heuristics; explicit validated names,
	# hidden-parent children, non-Node3D nodes and predicate revision invalidation.
	var fixture := Node3D.new()
	for name in ["COLON","Columns","NavalMuseum","Facade_proxyDecoration","Facade_col_ornament","COL_wall","collision_surface","Socket_anchor"]:
		var node := Node3D.new()
		node.name = name
		fixture.add_child(node)
	var named := Node3D.new()
	named.name = "explicit_name"
	fixture.add_child(named)
	var copy: Node3D = fixture.duplicate()
	original._hide_helpers(fixture,["explicit/name"])
	candidate._hide_helpers(copy,["explicit/name"])
	check(structure(fixture)==structure(copy),"exact source helper names fixture")
	original._helpers.compile("^COLON$")
	candidate._helpers.compile("^COLON$")
	fixture.get_node("COLON").visible = true
	copy.get_node("COLON").visible = true
	original._hide_helpers(fixture,[])
	candidate._hide_helpers(copy,[])
	check(structure(fixture)==structure(copy),"changed original predicate invalidates cache signature")
	fixture.free()
	copy.free()
	host.free()
	var records := []
	# Reconfigure removes predicate and contexts from fixture state.
	original = BaseFactory.new()
	candidate = FastFactory.new()
	original.configure(catalog)
	candidate.configure(catalog)
	for round in 8:
		var variants := ["baseline","helperOnly","registryOnly","both"]
		for step in 4:
			var variant: String = variants[(step+round)%4]
			var factory: RefCounted = candidate if variant in ["helperOnly","both"] else original
			var registry: RefCounted = FastRegistry.new() if variant in ["registryOnly","both"] else BaseRegistry.new()
			host = Node3D.new()
			root.add_child(host)
			var begin := Time.get_ticks_usec()
			for object: Dictionary in catalog.objects:
				if not object.has("resourceId"): continue
				var built: Dictionary = factory.spawn_key(object.key,{"exterior_collisions":true})
				host.add_child(built.root)
				check(registry.register_object(object.key,built.root,{"kind":object.dataset,"model":object.resourceId,"source":object.sourceRecord.duplicate(true)},[],built.pending.is_empty()).ok,"all measured exact source IDs")
			records.append({"round":round,"warmup":round==0,"variant":variant,"spawnRegisterUsec":Time.get_ticks_usec()-begin})
			host.free()
	print("AUTHORED_PERF_QA "+JSON.stringify({"checks":checks,"failures":failures,"samples":records,"sourceObjects":242,"placedGLBs":33,"admittedPaletteGLBs":196,"scope":"actual native exact scene/resource/shape and registry snapshots, noGPU/FPS"}))
	quit(0 if failures.is_empty() else 1)
