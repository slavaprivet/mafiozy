extends SceneTree
## Actual NPC-enabled source main; report absence rather than create fake NPCs.
const Pause = preload("C:/Users/Слава/Desktop/Мафиози/tools/godot/map_editor_candidate/scripts/map_editor/scene_pause_owner.gd")
var scene: Node3D
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func admit(_request: Dictionary) -> bool:
	# No real population/nav pause receipt currently exists. Refuse honestly.
	return false # Even a future method's mere presence is not an owned receipt.
func ready(_receipt: Dictionary) -> bool: return false
func resume_admission(_receipt: Dictionary, _objects: Dictionary, _ground: Dictionary) -> bool: return false
func ground() -> Dictionary: return {}
func run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	scene.preview_residents_enabled = true
	scene.preview_transport_enabled = true
	root.add_child(scene)
	for i in 600:
		if scene.preview_ready: break
		await physics_frame
	check(scene.preview_ready and scene.preview_population != null, "Actual NPC-enabled source main completed startup")
	if not scene.preview_ready or scene.preview_population == null:
		finish({"status": scene.population_status}); return
	var population: RefCounted = scene.preview_population
	for i in 90: await physics_frame
	var snapshot: Dictionary = population.snapshot()
	var diagnostics: Dictionary = population.navigation.diagnostics() if population.navigation != null else {}
	var occupants: Array = population.occupants()
	check(snapshot.has("residents") and snapshot.residents.get("rows") is Array, "Actual source resident rows reported without synthesizing replacements")
	check(not population.has_method("prepare_editor_pause") and not population.navigation.has_method("prepare_editor_pause"), "Missing real NPC/nav pending-query pause receipt confirmed")
	var phase_before: String = scene.preview_transport.phase
	var input_before: bool = scene._player.is_processing_unhandled_input()
	var body: RigidBody3D = scene.preview_transport.body
	var freeze_before: bool = body.freeze
	var helper := Pause.new()
	check(helper.configure(scene, [{"node": scene}, {"node": scene._player}, {"node": scene.preview_transport}], [{"node": body, "identity": {"vehicle_id": body.get_meta("vehicle_id"), "life_generation": body.get_meta("life_generation")}}], {"admit_pause": admit, "validate_resume": resume_admission, "transaction_ready": ready, "ground_patch": ground}).ok, "Explicit existing source-node inventory configured for admission-negative test")
	var refusal: Dictionary = helper.pause_gameplay({"owner_id": scene.get_instance_id(), "request_id": "npc-owner-receipt-required"})
	check(not refusal.ok and not helper.state().leased, "Missing real NPC pending-query owner receipt refuses pause before any mutation")
	check(scene.preview_transport.phase == phase_before and body.freeze == freeze_before and scene._player.is_processing_unhandled_input() == input_before, "Refused NPC-enabled editor entry does not alter real game flags/body/phase")
	finish({"population_status": scene.population_status, "actual_source_rows": snapshot.residents.rows.size(), "actual_spawned": occupants.size(), "resident_rows": snapshot.residents.rows, "nav": {"state": diagnostics.get("state"), "records": diagnostics.get("records"), "backend_jobs": diagnostics.get("backend", {}).get("jobs"), "bakes_inflight": diagnostics.get("backend", {}).get("bakes_inflight")}, "eightNPCPauseVerified": false, "npcOwnerReceiptExists": false})
func finish(report: Dictionary) -> void:
	if is_instance_valid(scene): scene.free()
	report.merge({"suite": "actual-npc-pause-admission", "checks": checks, "failures": failures, "gpu": false})
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
