extends SceneTree
## Real full catalog metadata, data-only model benchmark; no GPU/game startup claim.
const Document = preload("res://scripts/map_editor/map_document.gd")
const Trusted = preload("res://scripts/map_editor/trusted_json.gd")
var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Supply the original catalog absolute path as one user argument")
		quit(1)
		return
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not catalog is Dictionary or not catalog.get("objects") is Array:
		push_error("Original catalog is unavailable")
		quit(1)
		return
	var source := {"schema_version": 1, "map_id": "full-catalog-model-qa", "metadata": {"source": catalog.get("schema"), "receipt": {"nested": [1, {"value": "unchanged"}]}}, "custom_header": {"nested": ["original"]}, "objects": []}
	for row: Dictionary in catalog.objects:
		var position: Variant = row.get("positionLocalM")
		if not position is Array: position = [0,0,0]
		source.objects.append({"id": row.key, "kind": "catalog-source", "model": str(row.get("assetId", "")), "source": row.duplicate(true), "transform": {"position": position.duplicate(), "rotation": [0,0,0], "scale": [1,1,1], "original": {"receipt": row.key}}})
	check(source.objects.size() == 9901, "actual complete 9901 catalog records")
	var model := Document.new()
	var samples: Array[int] = []
	for iteration in 6:
		var started := Time.get_ticks_usec()
		var result: Dictionary = model.load_document(source)
		var elapsed := Time.get_ticks_usec() - started
		check(result.ok, "full source model load " + str(iteration))
		if iteration > 0: samples.append(elapsed)
	check(Trusted.equal(source, model.to_dictionary()), "every exact source/header/transform value preserved")
	source.metadata.receipt.nested[1].value = "caller-mutated"
	source.custom_header.nested[0] = "caller-mutated"
	source.objects[0].source["caller-extra"] = true
	var exported: Dictionary = model.to_dictionary()
	check(exported.metadata.receipt.nested[1].value == "unchanged" and exported.custom_header.nested[0] == "original" and not exported.objects[0].source.has("caller-extra"), "input deep detachment")
	exported.metadata.receipt.nested[1].value = "export-mutated"
	exported.custom_header.nested[0] = "export-mutated"
	exported.objects[0].source["export-extra"] = true
	var second: Dictionary = model.to_dictionary()
	check(second.metadata.receipt.nested[1].value == "unchanged" and second.custom_header.nested[0] == "original" and not second.objects[0].source.has("export-extra"), "output deep detachment")
	var invalid: Dictionary = second.duplicate(true)
	invalid["extra"] = Vector3.ONE
	check(not model.load_document(invalid).ok, "non JSON header rejected")
	invalid = second.duplicate(true)
	invalid.objects[1].id = invalid.objects[0].id
	check(not model.load_document(invalid).ok, "duplicate IDs rejected")
	invalid = second.duplicate(true)
	invalid.objects[0].transform.scale = [1,0,1]
	check(not model.load_document(invalid).ok, "invalid scale rejected")
	check(Trusted.equal(second, model.to_dictionary()), "all rejection paths leave model intact")
	samples.sort()
	print(JSON.stringify({"suite": "full-catalog-data-model", "records": source.objects.size(), "checks": checks, "failures": failures, "loadCpuP50Usec": samples[2], "loadCpuP95Usec": samples[4], "gpu": false, "productionWired": false}))
	quit(0 if failures.is_empty() else 1)
