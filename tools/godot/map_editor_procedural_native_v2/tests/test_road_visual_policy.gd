extends SceneTree
const Factory = preload("res://scripts/procedural_factory.gd")
const Policy = preload("res://scripts/road_visual_policy.gd")
const SHA := "82e6ef82a824e002d0f315972ffd3d967102b7c36256371699992bcfb76220dd"
var checks := 0
var failures: Array[String] = []
var max_matrix_error := 0.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var factory := Factory.new()
	_expect(factory.configure(SHA, Callable(self, "_admit")), "admitted source factory")
	var built: Dictionary = factory.build_roads()
	get_root().add_child(built.root)
	var policy := Policy.new()
	_expect(policy.configure(factory), "road visual-only policy configured")
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://road_oracle.json"))
	var total_writes := 0
	for sample: Dictionary in oracle.samples:
		var report: Dictionary = policy.update(0, sample.focusNative, sample.time)
		total_writes += int(report.writes)
		_expect(report.phases == sample.phases and report.time == sample.time, "all original signal phases exact")
		for key in sample.chunks:
			_expect(policy._groups[key].visible == sample.chunks[key], "all112 original equipment sphere cutoffs exact")
		for key in sample.meshes:
			var expected: Dictionary = sample.meshes[key]
			if str(key).begins_with("RoadPaint:"):
				_expect(factory._paint_batches[key].node.visible == expected.visible, "all59 original paint sphere visibility exact")
			else:
				_expect(factory._batches[key].node.visible == expected.visible, "all8 original road batch visibility exact")
			if expected.matrices != null:
				var matrices := PackedFloat32Array(expected.matrices)
				for index in 60:
					var submitted: Transform3D = policy._submitted[key][index]
					var frame := factory._transform(matrices, index * 16)
					max_matrix_error = maxf(max_matrix_error, _error(submitted, frame))
					_expect(submitted == frame, "all180 original phase matrices exact Float32")
		for source: Dictionary in factory._manifest.roads.equipmentChunks:
			var batch: Dictionary = factory._batches[source.batch]
			for index in source.instanceIndices:
				var expected: Transform3D = batch.transforms[index]
				if not sample.chunks[source.key]:
					expected.basis = Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
				_expect(policy._submitted[source.batch][index] == expected, "only source-hidden equipment collapsed")
		var idle: Dictionary = policy.update(0, sample.focusNative, sample.time)
		_expect(idle.writes == 0 and idle.distanceChecks == 0, "identical focus/time no distance work and no uploads")
	_expect(policy._phase(0, 0, 17) == "amber" and policy._phase(-44, 1, 39) == "amber", "offset negative modulo exact source")
	var id := "road-traffic_signal-0"
	var original := factory.object_transform(id)
	var shifted := original
	shifted.origin += Vector3(1200, 0, 0)
	policy.update(0, null, 0)
	_expect(factory.set_object_transform(id, shifted), "trusted edited signal")
	var after: Dictionary = policy.update(0, null, 0)
	_expect(after.writes >= factory._parts[id].size(), "dirty visual policy reapplies changed parts")
	_expect(factory.undo(), "trusted edited signal undo")
	policy.update(0, null, 0)
	var light_part: Dictionary = factory._parts[id].filter(func(part: Dictionary) -> bool: return part.batch == "TrafficBulbs:green")[0]
	_expect(policy._submitted[light_part.batch][light_part.index] == light_part.original, "signal undo preserves original bulb matrix exact")
	for group: Dictionary in policy._groups.values():
		_expect(group.sphere == group.source.sourceBoundingSphere, "undo restores exact original culling sphere")
	_expect(factory.delete_object(id), "trusted signal deleted")
	policy.update(0, null, 0)
	_expect(absf(policy._submitted[light_part.batch][light_part.index].basis.determinant()) < 0.0000001, "deleted bulb not resurrected by phase update")
	_expect(factory.undo(), "trusted signal deletion undo")
	policy.update(0, null, 0)
	_expect(policy._submitted[light_part.batch][light_part.index] == light_part.original, "deleted signal restored exact original lens")
	var raw_time := policy.time
	policy.update(-1, null, null)
	_expect(policy.time == raw_time, "negative delta cannot reverse source clock")
	policy.update(NAN, null, null)
	_expect(policy.time == raw_time, "nonfinite delta ignored")
	print("ROAD_SOURCE_POLICY_QA ", JSON.stringify({"checks": checks, "failures": failures, "oracleSamples": oracle.samples.size(), "sourceChunks":112,"sourcePaintMeshes":59,"sourceSignals":60,"maxMatrixDifference":max_matrix_error,"totalChangedInstanceWrites":total_writes,"scope":"exact source CPU visibility and submitted matrices; no GPU or traffic authority"}))
	built.root.free()
	quit(0 if failures.is_empty() else 1)

func _admit(_request: Dictionary) -> Dictionary:
	return {"approved":true,"commit":Callable(self,"_accept"),"rollback":Callable(self,"_rollback")}

func _accept() -> bool:
	return true

func _rollback() -> void:
	pass

func _error(a: Transform3D, b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin), maxf(a.basis.x.distance_to(b.basis.x), maxf(a.basis.y.distance_to(b.basis.y), a.basis.z.distance_to(b.basis.z))))

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition and failures.size() < 40:
		failures.append(message)
