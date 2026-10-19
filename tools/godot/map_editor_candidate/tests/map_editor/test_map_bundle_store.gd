extends SceneTree
const Bundle = preload("res://scripts/map_editor/map_bundle.gd")
const BundleStore = preload("res://scripts/map_editor/map_bundle_store.gd")
const Patch = preload("res://scripts/map_editor/map_patch.gd")
var checks := 0
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func _initialize() -> void:
	var hash := "b".repeat(64)
	var baseline := {"schema_version": 1, "map_id": "bundle-file-test", "metadata": {}, "objects": [{"id": "house", "kind": "building", "model": "house", "source": {"owner": 3}, "transform": {"position": [0, 0, 0], "rotation": [0, 0, 0], "scale": [1, 1, 1]}}]}
	var edited: Dictionary = baseline.duplicate(true)
	edited.objects[0].transform.position = [5, 0, 9]
	var requirements := {"house": [hash]}
	var resources := {hash: true}
	var ground := {"fixture": "trusted-ground", "cells": [3, 7]}
	var validator := func(value: Dictionary) -> Dictionary: return {"ok": Patch._canonical(value) == Patch._canonical(ground)}
	var first := Bundle.create(baseline, edited, requirements, "Первая", ground, validator)
	check(first.ok, "create combined bundle")
	var path := "user://maps/bundle-store-test-%s.json" % Time.get_ticks_usec()
	check(BundleStore.save_bundle(first.bundle, baseline, requirements, resources, path, validator).ok, "save admitted object and ground file")
	var loaded := BundleStore.load_bundle(baseline, requirements, resources, path, validator)
	check(loaded.ok and not loaded.recovered and loaded.document.objects[0].transform.position == [5.0, 0.0, 9.0] and Patch._canonical(loaded.ground_patch) == Patch._canonical(ground), "readback both parts")
	check(not BundleStore.load_bundle(baseline, requirements, {}, path, validator).ok, "missing resources rejected on read")
	check(not BundleStore.load_bundle(baseline, requirements, resources, path).ok, "missing ground owner rejected on read")
	check(not BundleStore.save_bundle(first.bundle, baseline, requirements, resources, "user://maps/../bad.json", validator).ok, "traversal rejected")
	var second := Bundle.create(baseline, edited, requirements, "Вторая", ground, validator)
	check(BundleStore.save_bundle(second.bundle, baseline, requirements, resources, path, validator).ok, "second save produces healthy backup")
	var invalid: Dictionary = second.bundle.duplicate(true)
	invalid.label = "несовпадающая сумма"
	check(not BundleStore.save_bundle(invalid, baseline, requirements, resources, path, validator).ok, "corrupt candidate refused before overwrite")
	loaded = BundleStore.load_bundle(baseline, requirements, resources, path, validator)
	check(loaded.get("label", "") == "Вторая", "rejected save leaves primary: " + str(loaded))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	loaded = BundleStore.load_bundle(baseline, requirements, resources, path, validator)
	check(loaded.ok and loaded.recovered and loaded.label == "Первая", "recover healthy combined backup")
	check(BundleStore.save_bundle(second.bundle, baseline, requirements, resources, path, validator).ok, "repair corrupted primary")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken again")
	file.close()
	loaded = BundleStore.load_bundle(baseline, requirements, resources, path, validator)
	check(loaded.ok and loaded.recovered and loaded.label == "Первая", "corrupt primary never replaces healthy backup")
	var wrong: Dictionary = baseline.duplicate(true)
	wrong.metadata["revision"] = 2
	check(not BundleStore.load_bundle(wrong, requirements, resources, path, validator).ok, "backup cannot bypass source binding")
	for suffix: String in ["", ".bak", ".tmp"]:
		var owned_path := ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(owned_path): DirAccess.remove_absolute(owned_path)
	for failure: String in failures: push_error(failure)
	print("map_bundle_store: ", checks, " checks, failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
