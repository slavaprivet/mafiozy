extends SceneTree
## Opt-in headless parity only: no gameplay owner, collision/nav or GPU claim.
const Eager = preload("res://scripts/procedural_factory.gd")
const Incremental = preload("res://scripts/incremental_factory.gd")
const RoadPolicy = preload("res://scripts/road_visual_policy.gd")
const SOURCE_SHA := "82e6ef82a824e002d0f315972ffd3d967102b7c36256371699992bcfb76220dd"
var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var eager: RefCounted = Eager.new()
	check(eager.configure(SOURCE_SHA), "eager exact source configured")
	if not eager.errors.is_empty(): _finish(); return
	var eager_build: Dictionary = eager.build_exploration()
	check(eager_build.ok and eager_build.batches == 464 and eager_build.objects == 2440, "eager exploration baseline")
	if not eager_build.ok: _finish(); return
	var incremental: RefCounted = Incremental.new()
	check(not incremental.configure(SOURCE_SHA), "eager bypass refused")
	check(not incremental.configure_step().ok and not incremental.build_batch_step().ok and not incremental.finish_exploration().ok and not incremental.begin_roads().ok and not incremental.finish_all().ok, "pre-begin calls refuse")
	var begun: Dictionary = incremental.begin_configure(SOURCE_SHA)
	check(begun.ok and begun.phase == "BUFFERS", "incremental begin")
	check(not incremental.begin_configure(SOURCE_SHA).ok, "second configure refused")
	var config_steps := 0
	for step in 1000:
		var result: Dictionary = incremental.configure_step(16)
		check(result.ok, "configuration step")
		if not result.ok: break
		config_steps += 1
		if result.complete: break
		await process_frame
	check(incremental._incremental_phase == "READY" and config_steps > 100 and incremental._expected_batch_counts.size() == 9394, "bounded configuration/index completes")
	check(not incremental.configure_step(0).ok and not incremental.configure_step(65).ok, "invalid step budgets refused")
	check(incremental._buffers.size() == 982 and incremental._meshes.size() == 86 and incremental._materials.size() == 10 and incremental._source_records.size() == 9394, "exact resource/ID census")
	for receipt: Dictionary in eager._manifest.buffers:
		check(incremental._buffers[receipt.sha256] == eager._buffers[receipt.sha256], "source buffer bytes identical")
	for geometry: Dictionary in eager._manifest.geometries:
		check(incremental._geometry_arrays[geometry.id] == eager._geometry_arrays[geometry.id], "source geometry arrays identical")
		check(incremental._meshes[geometry.id].surface_get_arrays(0) == eager._meshes[geometry.id].surface_get_arrays(0), "native mesh surface arrays identical")
	for descriptor: Dictionary in eager._manifest.materials:
		var a: StandardMaterial3D = eager._materials[descriptor.id]
		var b: StandardMaterial3D = incremental._materials[descriptor.id]
		check(a.albedo_color == b.albedo_color and a.roughness == b.roughness and a.metallic == b.metallic and a.emission == b.emission and a.emission_energy_multiplier == b.emission_energy_multiplier and a.cull_mode == b.cull_mode and a.transparency == b.transparency and a.shading_mode == b.shading_mode, "native material properties identical")
	check(not incremental.build_roads().ok, "road owner explicitly refused")
	check(not incremental.build_exploration().ok, "eager exploration bypass refused")
	var began_build: Dictionary = incremental.begin_exploration()
	check(began_build.ok and began_build.renderedIds == 0 and incremental._root.get_parent() == null, "detached exploration root")
	check(not incremental.begin_exploration().ok and not incremental.build_batch_step(0).ok and not incremental.build_batch_step(5).ok, "concurrent build and invalid budgets refused")
	check(not incremental.set_object_transform("explore-city-focus-0", Transform3D.IDENTITY) and not incremental.delete_object("explore-city-focus-0") and not incremental.undo() and not incremental.redo(), "partial owner edits refused")
	check(not incremental.finish_exploration().ok, "partial publication refused")
	check(not incremental.source_stage_complete("road-paint-0"), "road source ID cannot complete during exploration")
	var build_steps := 0
	for step in 500:
		var result: Dictionary = incremental.build_batch_step(2)
		check(result.ok and result.renderedIds == 0, "batch step no premature rendering claim")
		if not result.ok: break
		build_steps += 1
		if result.complete: break
		await process_frame
	check(incremental._incremental_cursor == 464 and build_steps == 232, "464 source batches across process frames")
	var built: Dictionary = incremental.finish_exploration()
	check(built.ok and built.batches == 464 and built.objects == 2440 and built.renderedIds == 0 and not built.has("root") and incremental._root.get_parent() == null, "exact detached exploration stage receipt")
	check(incremental._parts.keys().size() == eager._parts.keys().size() and incremental.initial_upload_calls == eager.initial_upload_calls, "IDs and uploads parity")
	for source: Dictionary in eager._manifest.exploration.batches:
		var a: Dictionary = eager._batches[source.key]
		var b: Dictionary = incremental._batches[source.key]
		check(a.source == b.source and a.transforms == b.transforms and a.colors == b.colors and a.initial_native_buffer == b.initial_native_buffer, "original batch CPU submission identical")
		check(a.mesh.instance_count == b.mesh.instance_count and a.mesh.mesh.get_meta("source_geometry") == b.mesh.mesh.get_meta("source_geometry") and a.node.material_override.get_meta("source_material") == b.node.material_override.get_meta("source_material"), "mesh/material/batch identity recipe parity")
		check(a.node.cast_shadow == b.node.cast_shadow and a.chunk == b.chunk, "shadow and LOD chunk parity")
	for id: String in eager._parts:
		check(incremental._parts.has(id) and incremental._parts[id] == eager._parts[id] and incremental.object_transform(id) == eager.object_transform(id), "exact source ID parts/frame parity")
	var focus := Vector3(1000, 0, 1000)
	check(not incremental.update_lod(focus).ok and not incremental.set_object_transform("explore-city-focus-0", Transform3D.IDENTITY), "partial exploration not editable or publishable")
	var eager_road: Dictionary = eager.build_roads()
	check(eager_road.ok and eager_road.controls == 505 and eager_road.markings == 6449, "eager original road baseline")
	check(not incremental.build_roads().ok, "eager road bypass refused")
	var began_road: Dictionary = incremental.begin_roads()
	check(began_road.ok and began_road.renderedIds == 0 and incremental._roads_root.get_parent() == null, "detached road root")
	check(not incremental.begin_roads().ok and not incremental.build_road_batch_step(0).ok and not incremental.build_road_batch_step(5).ok and not incremental.finish_all().ok, "partial road publication and invalid budgets refused")
	var road_steps := 0
	for step in 100:
		var result: Dictionary = incremental.build_road_batch_step(2)
		check(result.ok and result.renderedIds == 0, "road batch step no premature rendering claim")
		if not result.ok: break
		road_steps += 1
		if result.complete: break
		await process_frame
	check(incremental._road_cursor == 67 and road_steps == 34, "67 original road batches across process frames")
	var all: Dictionary = incremental.finish_all()
	check(all.ok and all.geometryReadyIds == 9394 and all.renderedIds == 0 and all.explorationRoot == incremental._root and all.roadsRoot == incremental._roads_root, "full detached geometry closure, not rendered scene")
	check(incremental._road_ids.size() == 505 and incremental._paint_ids.size() == 6449 and incremental.road_upload_calls == 8, "source control/marking/shared upload counts")
	for id: String in eager._source_records:
		check(incremental.source_stage_complete(id) and incremental._completed_batch_counts[id] == incremental._expected_batch_counts[id], "all mapped source batches complete per ID")
	for source: Dictionary in eager._manifest.roads.batches:
		if source.kind == "merged-original-paint":
			var a: Dictionary = eager._paint_batches[source.key]
			var b: Dictionary = incremental._paint_batches[source.key]
			check(a.source == b.source and a.base == b.base and a.current == b.current and a.node.mesh.get_meta("source_geometry") == b.node.mesh.get_meta("source_geometry"), "paint source geometry/vertex range parity")
			check(a.node.material_override.get_meta("source_material") == b.node.material_override.get_meta("source_material") and a.node.transform == b.node.transform and a.node.cast_shadow == b.node.cast_shadow, "paint material/transform/shadow parity")
			for index in source.objectIds.size(): check(incremental._paint_ids[str(source.objectIds[index])] == eager._paint_ids[str(source.objectIds[index])] and incremental.resolve_paint_vertex(source.key,index * 6) == str(source.objectIds[index]), "paint six-vertex ID slot parity")
			continue
		var a: Dictionary = eager._batches[source.key]
		var b: Dictionary = incremental._batches[source.key]
		check(a.source == b.source and a.transforms == b.transforms and a.colors == b.colors and a.initial_native_buffer == b.initial_native_buffer and a.stride == b.stride, "equipment/traffic CPU upload parity")
		check(a.mesh.instance_count == b.mesh.instance_count and a.node.material_override.get_meta("source_material") == b.node.material_override.get_meta("source_material") and a.node.transform == b.node.transform and a.node.cast_shadow == b.node.cast_shadow, "equipment/traffic mesh/material/source placement parity")
	var eager_policy: RefCounted = RoadPolicy.new()
	var incremental_policy: RefCounted = RoadPolicy.new()
	check(eager_policy.configure(eager) and incremental_policy.configure(incremental), "original road visual policy attached to both exact factories")
	for time in [-44.0, -0.01, 0.0, 17.0, 20.0, 22.0, 39.0, 42.0, 61.0]:
		var a: Dictionary = eager_policy.update(0.0, [400.0,0.0,400.0], time)
		var b: Dictionary = incremental_policy.update(0.0, [400.0,0.0,400.0], time)
		check(a == b and a.ok, "source traffic phase and range policy parity")
		for key: String in eager._batches:
			if key.begins_with("RoadEquipment_") or key.begins_with("TrafficBulbs:"):
				check(eager._batches[key].node.visible == incremental._batches[key].node.visible and eager._batches[key].transforms == incremental._batches[key].transforms, "road visual batch parity")
	check(incremental.update_lod(focus) == eager.update_lod(focus), "LOD policy parity after full closure")
	var stale: RefCounted = Incremental.new()
	check(not stale.begin_configure("0".repeat(64)).ok and stale._incremental_phase == "FAILED", "wrong source SHA terminal refusal")
	check(not stale.configure_step().ok and not stale.begin_exploration().ok, "failed source cannot continue")
	if is_instance_valid(eager_build.root): eager_build.root.free()
	if is_instance_valid(eager_road.root): eager_road.root.free()
	if all.ok and is_instance_valid(all.explorationRoot): all.explorationRoot.free()
	if all.ok and is_instance_valid(all.roadsRoot): all.roadsRoot.free()
	_finish(config_steps,build_steps,road_steps)

func _finish(config_steps: int = 0, build_steps: int = 0, road_steps: int = 0) -> void:
	print(JSON.stringify({"suite":"incremental-procedural-geometry-source-parity","checks":checks,"failures":failures,"configSteps":config_steps,"explorationBatchSteps":build_steps,"roadBatchSteps":road_steps,"geometryReadyIds":9394,"renderedIds":0,"gpu":false}))
	quit(0 if failures.is_empty() else 1)
