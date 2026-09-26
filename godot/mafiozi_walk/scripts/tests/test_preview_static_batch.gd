extends SceneTree
const Batch = preload("res://scripts/preview_static_batch.gd")
var checks := 0
var failures := 0
var world: Node3D
var owner: Node3D
var nodes: Array[MeshInstance3D] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func make_mesh(lods: bool = false) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.UP, Vector3.RIGHT, Vector3(1, 1, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {2.0: PackedInt32Array([0, 1, 2])} if lods else {})
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.6, 0.8)
	mesh.surface_set_material(0, material)
	return mesh

func reset_scene() -> void:
	if is_instance_valid(world):
		world.free()
	world = Node3D.new()
	root.add_child(world)
	owner = Node3D.new()
	owner.name = "AuditedStaticOwner"
	owner.set_meta("source_id", "LAMP-test")
	world.add_child(owner)
	owner.scale = Vector3(1.02, 1.0, 1.02)
	nodes.clear()
	for index: int in range(2):
		var node := MeshInstance3D.new()
		node.name = "StaticDetail%d" % index
		node.mesh = make_mesh()
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		node.position = Vector3(2 + index * 3, 2, 2)
		owner.add_child(node)
		nodes.append(node)

func declarations() -> Array:
	return [{"root": owner, "source_id": "LAMP-test", "static_authorized": true, "shared_sun_sky_only": true}]

func run() -> void:
	reset_scene()
	var helper := Batch.new()
	var before := [nodes[0].global_transform, nodes[1].global_transform]
	var meshes := [nodes[0].mesh, nodes[1].mesh]
	var body := StaticBody3D.new()
	body.set_meta("source_id", "LAMP-test")
	owner.add_child(body)
	var body_id := body.get_instance_id()
	var start := Time.get_ticks_usec()
	var stats: Dictionary = helper.plan(world, declarations())
	var plan_us := Time.get_ticks_usec() - start
	check(stats.ok, "Valid plan")
	check(stats.batched_sources == 2 and stats.batch_nodes == 1, "Separate identical resources deduplicated")
	check(stats.surface_submissions_before == 2 and stats.surface_submissions_after == 1, "Surface estimate")
	check(nodes[0].visible and nodes[1].visible, "Planning is read-only")
	check(helper.apply(), "Apply valid plan")
	check(not nodes[0].visible and not nodes[1].visible, "Only source leaves hidden")
	var batches := helper.batch_nodes()
	check(batches.size() == 1, "One batch")
	if batches.size() == 1:
		var batch: MultiMeshInstance3D = batches[0]
		var receipt: Dictionary = helper.batch_receipts()[0]
		check(batch.get_parent() == owner, "Owner visibility ancestry retained")
		check(batch.multimesh.mesh == meshes[0], "Original canonical resource reused")
		check(not batch.multimesh.use_colors and not batch.multimesh.use_custom_data, "No color/data modulation introduced")
		for index: int in range(2):
			var uploaded: Transform3D = receipt.instance_transforms[index]
			var reconstructed := batch.global_transform * uploaded
			check(reconstructed.is_equal_approx(before[index]), "World transform parity")
			check(Batch._positive_orthogonal(uploaded.basis, true), "Uniform residual")
			var local_box: AABB = uploaded * meshes[index].get_aabb()
			check(receipt.custom_aabb.encloses(local_box) or receipt.custom_aabb == local_box, "CPU custom bounds contain geometry")
			for normal: Vector3 in [Vector3(1, 1, 1).normalized(), Vector3.UP, Vector3.RIGHT]:
				var original: Vector3 = before[index].basis.inverse().transposed() * normal
				var actual: Vector3 = batch.global_basis.inverse().transposed() * uploaded.basis * normal
				check(original.normalized().is_equal_approx(actual.normalized()), "Factored nonuniform normal parity")
		owner.visible = false
		check(not batch.is_visible_in_tree(), "Owner hidden state inherited")
		owner.visible = true
	check(owner.get_meta("source_id") == "LAMP-test" and body.get_instance_id() == body_id, "IDs and collision authority remain")
	check(nodes[0].mesh == meshes[0] and nodes[1].mesh == meshes[1], "Source resources untouched")
	check(not helper.apply(), "Double apply rejected")
	helper.restore()
	helper.restore()
	check(nodes[0].visible and nodes[1].visible and helper.batch_nodes().is_empty(), "Idempotent restore")
	stats = helper.plan(world, declarations())
	check(stats.ok and helper.apply(), "Rebuild after restore")
	helper.restore()
	# Render/geometry differences and invalid owners must never manufacture profit.
	for scenario: String in ["color", "shadow", "layers", "lod", "reflection", "transparent", "next_pass", "door", "non_leaf", "chunk", "gi", "negative", "shear", "printshop", "authorization"]:
		reset_scene()
		var declared := declarations()
		match scenario:
			"color": nodes[1].mesh.surface_get_material(0).albedo_color = Color.RED
			"shadow": nodes[1].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			"layers": nodes[1].layers = 2
			"lod": nodes[1].mesh = make_mesh(true)
			"reflection": owner.add_child(ReflectionProbe.new())
			"transparent": nodes[1].mesh.surface_get_material(0).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			"next_pass": nodes[1].mesh.surface_get_material(0).next_pass = StandardMaterial3D.new()
			"door": nodes[1].name = "Door_Leaf"
			"non_leaf": nodes[1].add_child(Node3D.new())
			"chunk": nodes[1].position.x = 15.5
			"gi": nodes[1].gi_mode = GeometryInstance3D.GI_MODE_STATIC
			"negative": nodes[1].scale.x = -1
			"shear": nodes[1].basis = Basis(Vector3(1, 0.1, 0), Vector3.UP, Vector3.BACK)
			"printshop": owner.set_meta("source_id", Batch.PRINTSHOP_ID); declared[0].source_id = Batch.PRINTSHOP_ID
			"authorization": declared[0].static_authorized = false
		stats = helper.plan(world, declared)
		check(stats.batch_nodes == 0, "No unsafe merge: " + scenario)
		check(nodes[0].visible and nodes[1].visible, "Rejected plan leaves source visible: " + scenario)
		helper.restore()
	# Precommit validation catches changes after the caller reviews the dry plan.
	for scenario: String in ["transform", "material", "freed", "host"]:
		reset_scene()
		helper.plan(world, declarations())
		match scenario:
			"transform": nodes[1].position.x += 0.25
			"material": nodes[1].mesh.surface_get_material(0).roughness = 0.3
			"freed": nodes[1].free()
			"host": world.position.x = 2
		check(not helper.apply(), "Changed snapshot rejects commit: " + scenario)
		check(nodes[0].visible, "Failed commit leaves originals: " + scenario)
		helper.restore()
	reset_scene()
	for node: MeshInstance3D in nodes:
		node.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	var static_declaration := declarations()
	static_declaration[0]["allow_static_gi_without_capture"] = true
	stats = helper.plan(world, static_declaration)
	check(stats.ok and stats.batch_nodes == 1, "Explicit GI_STATIC without capture admission")
	check(helper.apply(), "Admitted static GI commit")
	check(helper.batch_nodes()[0].gi_mode == GeometryInstance3D.GI_MODE_STATIC, "GI flag preserved")
	helper.restore()
	helper.plan(world, static_declaration)
	var probe := ReflectionProbe.new()
	world.add_child(probe)
	check(not helper.apply(), "Global probe inserted after plan rejects commit")
	check(nodes[0].visible and nodes[1].visible, "GI drift is fail-closed")
	helper.restore()
	probe.free()
	world.free()
	print("STATIC_BATCH_TEST checks=", checks, " failures=", failures, " synthetic_plan_us=", plan_us, "; CPU/resource tests, no GPU/FPS")
	quit(0 if failures == 0 else 1)
