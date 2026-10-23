extends "res://scripts/tests/test_npc_ragdoll_recovery_optimized.gd"
## Real current main terrain, staging positions, colliders and cached skins.
## Source release remains explicitly TEST_ONLY. No live scene/FPS claim.
var residents: RefCounted
func valid(binding: Dictionary) -> bool:
	return residents != null and residents.physical_life_current(binding)
func run() -> void:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.preview_residents_enabled = true; scene.preview_resident_walk_enabled = false
	root.add_child(scene)
	var deadline := Time.get_ticks_msec()+15000
	while not scene.preview_ready and Time.get_ticks_msec()<deadline: await tick()
	check(scene.preview_ready and scene.population_status == "ready","actual main resident staging ready")
	if not scene.preview_ready or scene.population_status != "ready": scene.free(); quit(1); return
	residents = scene.preview_population.residents
	# Stop root's gameplay writers; retain exact physics geometry and actual
	# staged actor transforms. This fixture becomes the sole pose/life test owner.
	scene.set_process(false); scene.set_physics_process(false)
	await tick(); await tick()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR+"visual_manifest.json"))
	for entry: Dictionary in manifest.entries:
		var source_id: String = entry.bridge_id.trim_prefix("npc_")
		var record: Dictionary = residents._records[source_id]
		token = residents.target_from_collider(record.body)
		check(token.get("ok",false),"actual original walking target "+entry.bridge_id)
		if not token.get("ok",false): continue
		await scenario(entry,"actual_main",scene,{"actor":token.body,"rig":token.rig})
	recovery_us.sort()
	var attempted := 0; var completed := 0
	for row: Dictionary in rows:
		if row.collision_guard_seen: attempted += 1
		if row.stopped == "stood": completed += 1
	var report := {"checks":checks,"passed":errors.is_empty(),"errors":errors,"rows":rows,"actual_staged_locations":true,"attempted_rise_count":attempted,"completed_count":completed,"resident_count":rows.size(),"step_us_p50":recovery_us[recovery_us.size()/2] if not recovery_us.is_empty() else -1,"step_us_p95":recovery_us[int(recovery_us.size()*.95)] if not recovery_us.is_empty() else -1,"source_gate":"TEST_ONLY current-release fixture; not source integration","GPU":false,"full_scene_FPS":"NOT_RUN","main_sha256":FileAccess.get_sha256("res://scripts/main.gd"),"resident_host_sha256":FileAccess.get_sha256("res://scripts/npc_visual/preview_resident_host.gd"),"recovery_sha256":FileAccess.get_sha256("res://scripts/npc_visual/npc_ragdoll_recovery.gd")}
	report["cost"] = costs()
	report["legacy_bounds"] = force_legacy
	report["oracle"] = {"poses":oracle_poses,"vertices":oracle_vertices}
	var file := FileAccess.open("../../outputs/artist22_npc_recovery_optimized/"+result_prefix()+"MAIN_RESULT.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("NPC_RECOVERY_MAIN ",JSON.stringify(report)); scene.free(); quit(0 if errors.is_empty() else 1)
