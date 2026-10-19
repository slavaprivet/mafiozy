extends SceneTree
const Inventory = preload("C:/Users/Слава/Desktop/Мафиози/tools/godot/map_editor_native_building_adoption_candidate/inventory.gd")
var count := 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	count += 1
	if not condition: failures.append(message); push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	await process_frame
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Node3D = scene.instantiate()
	# Let real native bodies enter their space during normal bootstrap. Setting
	# PROCESS_MODE_DISABLED before _ready incorrectly disables their physics space.
	root.add_child(main)
	var bootstrap_frames := 0
	while not bool(main.get("preview_ready")) and bootstrap_frames < 120:
		bootstrap_frames += 1
		await physics_frame
	check(bool(main.get("preview_ready")), "actual owner preview_ready attained within bounded bootstrap")
	if not bool(main.get("preview_ready")):
		main.queue_free(); quit(1); return
	# One synchronous read-only audit follows; no gameplay pause is claimed.
	var block: Dictionary = main.get("_block")
	check(not block.is_empty(), "actual block admitted by real main")
	check(str(main.get("printshop_status")) == "ready", "actual printshop attached")
	var full_path := "C:/Users/Слава/Desktop/Мафиози/assets/maps/city_rebuild_v1/buildings_placement.v1.json"
	var bytes := FileAccess.get_file_as_bytes(full_path)
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
	var sha := hash.finish().hex_encode()
	check(sha == str(block.sources[0].sha256), "full source placement SHA pinned by actual block")
	var full: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
	var inspector := Inventory.new()
	var before: Array = inspector.fingerprint(main)
	var report: Dictionary = inspector.inspect(main, block.buildings, full.instances, main.get("_printshop"))
	check(report.ok, "all native building identities resolved: " + str(report.errors))
	check(inspector.fingerprint(main) == before, "inventory leaves exact native hierarchy/resources/frames/filters untouched")
	check(report.crop_building_count == 8, "actual crop has eight buildings")
	check(report.full_building_count == 75, "all original placed house source includes 75 buildings")
	check(report.outside_crop_building_ids.size() == 67, "67 source buildings outside current preview crop classified, not fabricated")
	check(not report.authority_admitted, "inventory grants no editor permissions")
	var rows: Array = []
	var ordinary := 0; var special_count := 0; var ordinary_bodies := 0
	for row: Dictionary in report.rows:
		check(row.visual.get_parent() == main, "source visual belongs directly to main: " + row.source_id)
		check(row.visual.get_meta("source_id") == row.source_id, "exact source identity: " + row.source_id)
		check(not row.editable_admitted, "no invented building edit permission")
		var kinds: Dictionary = {}
		if row.special:
			special_count += 1
			check(row.special_owner.get_parent() == main, "printshop adapter is sibling, not visual descendant")
			check(row.special_owner.global_transform == Transform3D.IDENTITY, "actual interior source coordinates are world-local")
			check(not row.special_bodies.is_empty(), "actual generated interior bodies found")
			for body: StaticBody3D in row.special_bodies:
				check(body.get_meta("source_id") == row.source_id, "interior body exact source id")
				check(not body.has_meta("source_index"), "interior kinds replace source-index envelope")
				var kind := str(body.get_meta("interior_kind")); kinds[kind] = int(kinds.get(kind, 0)) + 1
			var data: Dictionary = row.special_owner.get("_data")
			for key: String in data.anchors:
				var a: Array = data.anchors[key]
				check(row.special_owner.anchor(key) == Vector3(a[0], a[1], a[2]), "anchor uses source data, not visual root: " + key)
			check(row.special_owner.get("_doors").size() == 2, "public and staff source doors")
		else:
			ordinary += 1
			for body: StaticBody3D in row.native_sibling_bodies:
				ordinary_bodies += 1
				check(body.get_parent() == main and not row.visual.is_ancestor_of(body), "detached native sibling collision")
				check(body.transform == Transform3D.IDENTITY, "absolute native collision points not root-local")
				var matched: Dictionary = {}
				for record: Dictionary in block.buildings:
					if record.id != row.source_id: continue
					for spec: Dictionary in record.collisionBodiesM:
						if int(spec.sourceIndex) == int(body.get_meta("source_index")): matched = spec
				var points := PackedVector3Array()
				for p: Array in matched.polygonXZ:
					points.append(Vector3(p[0], matched.minY, p[1])); points.append(Vector3(p[0], matched.maxY, p[1]))
				check(body.get_child(0).shape.points == points, "actual sibling keeps exact source convex points")
		rows.append({"source_id": row.source_id, "visual_instance_id": row.visual.get_instance_id(),
			"source_indices": row.source_indices, "native_siblings": row.native_sibling_bodies.size(),
			"special": row.special, "special_body_kinds": kinds})
	check(ordinary == 7 and special_count == 1, "seven ordinary homes plus actual printshop special owner")
	var batch_report: Array = []
	var lease: RefCounted = main.get("_static_batch_lease")
	if lease != null:
		check(str(main.get("static_batch_status")) == "ready", "native startup batch owner reports ready")
		var receipt_rows: Array = lease.batch_receipts()
		check(not receipt_rows.is_empty(), "actual batch CPU upload receipts supplied")
		for receipt: Dictionary in receipt_rows:
			var node: Node = receipt.batch.get_ref()
			check(is_instance_valid(node) and main.is_ancestor_of(node) and node.get_parent().has_meta("source_id"), "batch parent is original visual owner")
			check(str(node.get_parent().get_meta("source_id")) in receipt.source_ids, "batch source id binds actual original visual parent")
			for source_id: String in receipt.source_ids:
				check(source_id != Inventory.PRINTSHOP, "printshop never claimed by exterior batch")
			for reference: WeakRef in receipt.source_nodes:
				var source_node: Node = reference.get_ref()
				check(is_instance_valid(source_node) and main.is_ancestor_of(source_node), "batch receipt original source node remains under real owner")
			batch_report.append({"source_ids": receipt.source_ids, "source_nodes": receipt.source_nodes.size(),
				"mesh_payload_sha256": receipt.mesh_payload_sha256, "material_payload_sha256": receipt.material_payload_sha256})
	check(inspector.fingerprint(main) == before, "all proof reads leave exact source unchanged")
	# Native lifecycle/schema negatives use a separate explicitly synthetic owner.
	var fixture := Node3D.new(); root.add_child(fixture)
	var visual := Node3D.new(); visual.set_meta("source_id", "fixture"); fixture.add_child(visual)
	var body := StaticBody3D.new(); body.set_meta("source_id", "fixture"); body.set_meta("source_index", 0); fixture.add_child(body)
	var record := {"id": "fixture", "collisionBodiesM": [{"sourceIndex": 0}]}
	check(inspector.inspect(fixture, [record, record], [record]).ok == false, "duplicate admitted record IDs refuse")
	check(inspector.inspect(fixture, [{"id": "unknown", "collisionBodiesM": []}], [record]).ok == false, "unknown source record refuses")
	check(inspector.inspect(fixture, [record], [record, record]).ok == false, "ambiguous full source refuses")
	visual.queue_free()
	check(inspector.inspect(fixture, [record], [record]).ok == false, "queued visual refuses before deferred deletion")
	body.queue_free()
	check("queued-collider:fixture" in inspector.inspect(fixture, [record], [record]).errors, "queued sibling collider explicitly refuses")
	fixture.queue_free()
	check(inspector.inspect(fixture, [record], [record]).ok == false, "queued native owner refuses")
	var special_fixture := Node3D.new(); root.add_child(special_fixture)
	var special_visual := Node3D.new(); special_visual.set_meta("source_id", Inventory.PRINTSHOP); special_fixture.add_child(special_visual)
	var adapter := Node3D.new(); special_fixture.add_child(adapter)
	var special_record := {"id": Inventory.PRINTSHOP, "collisionBodiesM": []}
	var special_body := StaticBody3D.new(); adapter.add_child(special_body)
	special_body.queue_free()
	check("queued-special-collider:" + Inventory.PRINTSHOP in inspector.inspect(special_fixture, [special_record], [special_record], adapter).errors, "queued interior collider explicitly refuses")
	adapter.queue_free()
	check(inspector.inspect(special_fixture, [special_record], [special_record], adapter).ok == false, "queued special owner refuses")
	special_fixture.queue_free()
	var output := {"checks": count, "failures": failures, "gpu": false, "production_admitted": false,
		"full_map_complete": false, "full_buildings": 75, "crop_buildings": 8,
		"outside_crop_building_ids": report.outside_crop_building_ids,
		"placement_sha256": sha, "ordinary_building_bodies": ordinary_bodies,
		"actual_preview_ready": bool(main.get("preview_ready")), "bootstrap_wait_physics_frames": bootstrap_frames,
		"static_batch_status": main.get("static_batch_status"), "batch_receipts": batch_report, "rows": rows}
	var report_name := "BUILDING_BATCH_INVENTORY_REPORT.json" if lease != null else "BUILDING_INVENTORY_REPORT.json"
	var file := FileAccess.open("res://" + report_name, FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t")); file.close()
	print("NATIVE BUILDING INVENTORY ", count, " checks ", failures.size(), " failures")
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
