extends SceneTree
## Isolated deterministic file-failpoint test. No production game or GPU claim.
const Bundle = preload("res://scripts/map_editor/map_bundle.gd")
const Store = preload("res://scripts/map_editor/map_bundle_store.gd")
const Patch = preload("res://scripts/map_editor/map_patch.gd")

var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func same(a: Dictionary, b: Dictionary) -> bool:
	return Patch._canonical(a) == Patch._canonical(b)
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var baseline := {"schema_version": 1, "map_id": "recovery-fixture", "metadata": {}, "objects": [{"id": "house", "kind": "building", "model": "house", "transform": {"position": [0, 0, 0], "rotation": [0, 0, 0], "scale": [1, 1, 1]}}]}
	var old_created: Dictionary = Bundle.create(baseline, baseline, {"house": []}, "Old complete map")
	var edited: Dictionary = baseline.duplicate(true)
	edited.objects[0].transform.position[0] = 4
	var new_created: Dictionary = Bundle.create(baseline, edited, {"house": []}, "New complete map")
	check(old_created.ok and new_created.ok, "both complete combined bundles admitted")
	if not old_created.ok or not new_created.ok:
		finish()
		return
	var old_bundle: Dictionary = old_created.bundle
	var new_bundle: Dictionary = new_created.bundle
	var requirements := {"house": []}
	var resources := {}
	var prefix := "user://maps/tests/recovery-" + str(Time.get_ticks_usec()) + "-"
	for phase: String in ["before_temp_write", "after_temp_verified", "after_backup_verified", "after_primary_removed", "before_promote", "after_promote"]:
		var path := prefix + phase + ".json"
		check(Store.save_bundle(old_bundle, baseline, requirements, resources, path).ok, phase + ": old bundle saved")
		var fault := func(step: String) -> bool: return step == phase
		var result: Dictionary = Store.save_bundle(new_bundle, baseline, requirements, resources, path, Callable(), fault)
		check(not result.ok and result.get("phase") == phase, phase + ": deterministic refusal reached")
		var recovered: Dictionary = Store.load_bundle(baseline, requirements, resources, path)
		var expected: Dictionary = new_bundle if phase == "after_promote" else old_bundle
		check(recovered.ok and same(recovered.get("bundle", {}), expected), phase + ": exactly old or new complete bundle loads")
		if phase in ["after_primary_removed", "before_promote"]: check(recovered.get("recovered", false), phase + ": validated backup selected")
	var fresh_path := prefix + "fresh.json"
	var stop_after_temp := func(step: String) -> bool: return step == "after_temp_verified"
	var first_result: Dictionary = Store.save_bundle(old_bundle, baseline, requirements, resources, fresh_path, Callable(), stop_after_temp)
	check(not first_result.ok, "first save interrupted after verified temp")
	var temp_recovered: Dictionary = Store.load_bundle(baseline, requirements, resources, fresh_path)
	check(temp_recovered.ok and temp_recovered.get("recovered", false) and same(temp_recovered.get("bundle", {}), old_bundle), "only verified temp is recoverable")
	var stop_before_write := func(step: String) -> bool: return step == "before_temp_write"
	var second_result: Dictionary = Store.save_bundle(new_bundle, baseline, requirements, resources, fresh_path, Callable(), stop_before_write)
	check(not second_result.ok, "second save interrupted before overwriting only temp")
	var preserved: Dictionary = Store.load_bundle(baseline, requirements, resources, fresh_path)
	check(preserved.ok and preserved.get("recovered", false) and same(preserved.get("bundle", {}), old_bundle), "prior temp was verified in backup before overwrite")
	var complete: Dictionary = Store.save_bundle(new_bundle, baseline, requirements, resources, fresh_path)
	var completed: Dictionary = Store.load_bundle(baseline, requirements, resources, fresh_path)
	check(complete.ok and completed.ok and same(completed.get("bundle", {}), new_bundle), "subsequent complete save promotes new bundle")
	finish()

func finish() -> void:
	for failure: String in failures: push_error(failure)
	print("MAP_BUNDLE_RECOVERY_QA ", JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures, "godotHeadlessOnly": true, "productionWired": false, "crashDurabilityProved": false}))
	quit(0 if failures.is_empty() else 1)
