extends SceneTree
const Baseline = preload("res://landmarks_resource_factory.gd")
const Optimized = preload("res://landmarks_cached_factory.gd")
const SHA := "4e459bda9cf6a9ab752667bc8a55fe36a6a6c4d7350a7d5ddc64e08c6a8c490c"
var checks := 0
var failed := false

func require(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		if not failed: push_error(reason)
		failed = true

func percentile(samples: PackedInt64Array) -> Dictionary:
	samples.sort()
	return {"p50_us": samples[int(samples.size() * 0.5) - 1], "p95_us": samples[int(samples.size() * 0.95) - 1]}

func _init() -> void:
	var old = Baseline.new()
	var improved = Optimized.new()
	require(old.configure("res://source", SHA).ok and improved.configure("res://source", SHA).ok, "Source SHA")
	var before_start := Time.get_ticks_usec()
	require(old.build_resources().ok, "Old resource build")
	var before_cold := Time.get_ticks_usec() - before_start
	var after_start := Time.get_ticks_usec()
	require(improved.build_resources().ok, "New resource build")
	var after_cold := Time.get_ticks_usec() - after_start
	var owner := func(request: Dictionary) -> Dictionary: return {"ok": true, "source_sha256": SHA, "key": request.key, "paused_lease": true, "collider_nav_committed": true}
	var before := {}
	var after := {}
	var cold_plans := {}
	for key in ["protected-landmarks:red-bridge", "protected-landmarks:police-island"]:
		var started := Time.get_ticks_usec()
		var old_plan: Dictionary = old.placement_plan(key)
		var old_first := Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		var new_plan: Dictionary = improved.placement_plan(key)
		cold_plans[key] = {"before_us": old_first, "after_us": Time.get_ticks_usec() - started}
		require(old_plan == new_plan, "Identical first native plan")
		var initial: Dictionary = improved.checkpoint()
		for step in range(40):
			var basis := Basis(Vector3.UP, float(step) * 0.07).scaled(Vector3(0.8 + step * 0.01, 1.1, 1.3))
			var frame := Transform3D(basis, Vector3(step * 11, -step * 0.2, -step * 7))
			var a: Dictionary = old.preview_edit(key, frame, step % 7 == 0)
			var b: Dictionary = improved.preview_edit(key, frame, step % 7 == 0)
			require(a == b, "Exact source plan and tight culling AABB rotation/scale/delete parity")
			require(improved.commit_edit(b, owner).ok and old.commit_edit(a, owner).ok, "Owner transaction")
			require(old.undo(owner).ok and improved.undo(owner).ok, "Undo parity")
			require(old.redo(owner).ok and improved.redo(owner).ok, "Redo parity")
			require(old.state(key) == improved.state(key), "State parity")
		var snapshot: Dictionary = improved.checkpoint()
		require(snapshot.mesh_ids == initial.mesh_ids and snapshot.multimesh_ids == initial.multimesh_ids, "Resource identities survive all edit history")
		var old_samples := PackedInt64Array()
		var new_samples := PackedInt64Array()
		for sample in range(120):
			var frame := Transform3D(Basis(Vector3.UP, sample * 0.03), Vector3(sample, 0, -sample))
			# Interleave both orderings to avoid systematic scheduling or warm-up advantage.
			if sample % 2 == 0:
				started = Time.get_ticks_usec()
				var a: Dictionary = old.preview_edit(key, frame)
				old_samples.append(Time.get_ticks_usec() - started)
				started = Time.get_ticks_usec()
				var b: Dictionary = improved.preview_edit(key, frame)
				new_samples.append(Time.get_ticks_usec() - started)
				require(a == b, "Warm parity")
			else:
				started = Time.get_ticks_usec()
				var b: Dictionary = improved.preview_edit(key, frame)
				new_samples.append(Time.get_ticks_usec() - started)
				started = Time.get_ticks_usec()
				var a: Dictionary = old.preview_edit(key, frame)
				old_samples.append(Time.get_ticks_usec() - started)
				require(a == b, "Warm parity reversed")
		before[key] = percentile(old_samples)
		after[key] = percentile(new_samples)
		var public: Dictionary = improved.placement_plan(key)
		public.owned_parts[0].source_frame = Transform3D(Basis.IDENTITY, Vector3(123456, 0, 0))
		require(improved.placement_plan(key) == old.placement_plan(key), "Public plan cannot mutate cached frame")
		var mesh: ArrayMesh = improved.mesh_resource(improved.source_part(improved.placement_plan(key).owned_parts[0].part_id).geometry)
		if mesh != null:
			mesh.emit_changed()
			require(not improved.placement_plan(key).ok, "Changed resource invalidates cached owner bounds")
			# Stop this key's optimized work after resource invalidation; other independently owned key remains valid.
		if key == "protected-landmarks:red-bridge": require(improved.placement_plan("protected-landmarks:police-island").ok, "Unrelated owner is not spuriously invalidated")
	var report := {"checks": checks, "before_cold_resources_us": before_cold, "after_cold_resources_us": after_cold, "cold_plans": cold_plans, "before": before, "after": after, "cache_builds": improved.cold_plan_builds, "gpu_used": false, "scene_admitted": false}
	print(JSON.stringify(report))
	print("PASS" if not failed else "FAIL", " optimized landmark cache parity")
	old.dispose()
	improved.dispose()
	quit(1 if failed else 0)
