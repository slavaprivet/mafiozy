extends SceneTree
const Cache = preload("res://scripts/npc_visual/npc_visual_cache.gd")
const Loader = preload("res://scripts/npc_visual/npc_visual_loader.gd")
const HelperPath := "res://scripts/character_physics/local_hit_reaction.gd"
const Directory := "res://assets/npc_visual/session/prepared"
const ManifestSHA := "3c07e72938a0918fa32de33ca442bf07cb50f21f0916b8b091b552473bd9aac0"
const Out := "C:/Users/Слава/Desktop/Мафиози/outputs/astra21_local_hit_preflight_tests/"
const Selected := ["spine_01", "chest", "head", "upperarm_l", "forearm_l", "upperarm_r", "forearm_r"]
var checks := 0
var failures: Array[String] = []
var metrics: Array = []
var preflight_metrics: Array = []
var helper: GDScript
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and not label in failures: failures.append(label)
func _initialize() -> void:
	call_deferred("run")
func frames_for(rest: Array, parents: Array, heading: float = 0.0, source_root: Transform3D = Transform3D.IDENTITY) -> Dictionary:
	var frames: Dictionary = {}
	var global_root := Transform3D(Basis(Vector3.UP, heading), Vector3(2.1, 0.2, -3.7)) * source_root
	for i in rest.size():
		frames[Loader.BONES[i]] = (global_root if parents[i] < 0 else frames[Loader.BONES[parents[i]]]) * rest[i]
	return frames
func new_sampler(id: String, epoch: Variant, rig: Dictionary) -> RefCounted:
	var sampler: RefCounted = helper.new()
	check(sampler.bind(id, epoch, rig).ok, "bind actual rig " + id)
	return sampler
func event(id: String, epoch: Variant, key: String, point: Vector3, impulse: Vector3) -> Dictionary:
	return {"actor_id": id, "epoch_id": epoch, "event_id": key, "world_point": point, "impulse_ns": impulse}
func velocity(sampler: RefCounted, name: String) -> Vector3:
	return sampler.snapshot().velocity_rad_s.get(name, Vector3.ZERO)
func active_sample(sampler: RefCounted, base: Array, label: String) -> Dictionary:
	var sample: Dictionary = sampler.sample(0.01, base)
	check(sample.get("ok", false) and sample.get("valid", false), "valid sample " + label)
	return sample
func reject_atomic(sampler: RefCounted, input: Dictionary, frames: Dictionary, label: String) -> void:
	var before := var_to_bytes(sampler.snapshot())
	var candidate: Dictionary = sampler.can_add_hit(input, frames)
	check(not candidate.ok and var_to_bytes(sampler.snapshot()) == before, "old negative preflight pure reject " + label)
	var committed: Dictionary = sampler.add_hit(input, frames)
	check(not committed.ok and candidate == committed, "reject dictionary parity " + label)
	check(var_to_bytes(sampler.snapshot()) == before, "reject state atomic " + label)
func preflight_case(id: String, rig: Dictionary, rest: Array, frames: Dictionary, seed: Dictionary, candidate: Dictionary, candidate_frames: Dictionary, label: String) -> void:
	var can := new_sampler(id, 7, rig)
	var direct := new_sampler(id, 7, rig)
	can.add_hit(seed, frames); direct.add_hit(seed, frames)
	can.sample(0.01, rest); direct.sample(0.01, rest)
	var before := var_to_bytes(can.snapshot())
	var event_before := var_to_bytes(candidate)
	var frames_before := var_to_bytes(candidate_frames)
	var first: Dictionary = can.can_add_hit(candidate, candidate_frames)
	for i in 20:
		check(can.can_add_hit(candidate, candidate_frames) == first, "repeat pure preflight result " + label)
		check(var_to_bytes(can.snapshot()) == before, "repeat preflight no state advance/reservation " + label)
	check(var_to_bytes(candidate) == event_before and var_to_bytes(candidate_frames) == frames_before, "preflight caller event/frames untouched " + label)
	var committed: Dictionary = can.add_hit(candidate, candidate_frames)
	var direct_result: Dictionary = direct.add_hit(candidate, candidate_frames)
	check(first == committed and committed == direct_result, "preflight vs commit error/projection dictionary parity " + label)
	check(var_to_bytes(can.snapshot()) == var_to_bytes(direct.snapshot()), "20 preflights then commit same exact direct state " + label)
	if first.ok:
		check(not can.can_add_hit(candidate, candidate_frames).ok and not can.add_hit(candidate, candidate_frames).ok, "both reject replay after commit " + label)
	else: check(var_to_bytes(can.snapshot()) == before, "rejected preflight/commit atomic " + label)
func preflight_actual(id: String, rig: Dictionary, rest: Array, frames: Dictionary, point: Vector3, impulse: Vector3) -> void:
	var seed := event(id, 7, "already_active", point, impulse)
	var valid := event(id, 7, "valid_candidate", point, impulse)
	preflight_case(id, rig, rest, frames, seed, valid, frames, "active valid")
	preflight_case(id, rig, rest, frames, seed, seed, frames, "already replayed")
	preflight_case(id, rig, rest, frames, seed, event("foreign", 7, "badactor", point, impulse), frames, "wrong actor")
	preflight_case(id, rig, rest, frames, seed, event(id, "7", "badtype", point, impulse), frames, "typed epoch")
	preflight_case(id, rig, rest, frames, seed, event(id, 7, "nan", point, Vector3(NAN, 0, 0)), frames, "nonfinite J")
	preflight_case(id, rig, rest, frames, seed, event(id, 7, "distant", point + Vector3(10, 0, 0), impulse), frames, "distant")
	var bad := frames.duplicate()
	var head: Transform3D = bad.head
	bad.head = Transform3D(head.basis.scaled(Vector3.ONE * 2), head.origin)
	preflight_case(id, rig, rest, frames, seed, valid, bad, "bad world scale")
	bad = frames.duplicate()
	head = bad.head
	bad.head = Transform3D(head.basis, head.origin + Vector3(0.2, 0, 0))
	preflight_case(id, rig, rest, frames, seed, valid, bad, "bad world length")
	var unbound: RefCounted = helper.new()
	var unbound_bytes := var_to_bytes(unbound.snapshot())
	check(unbound.can_add_hit(valid, frames) == unbound.add_hit(valid, frames), "unbound preflight/commit parity")
	check(var_to_bytes(unbound.snapshot()) == unbound_bytes, "unbound preflight atomic")
	var perf: Dictionary = {"actor_id": id, "samples": 2000, "warmups": 50}
	for mode: String in ["old_add", "can", "add", "both"]:
		var sampler: RefCounted
		if mode == "old_add":
			var old: GDScript = load(Out + "historical_b8b9/helper.gd") as GDScript
			check(FileAccess.get_sha256(Out + "historical_b8b9/helper.gd") == "b8b9d6fae7aef0109c17cc27a2b8802154c395c8f51b9d107f9cdd40c1582519", "old baseline helper pinned")
			sampler = old.new()
			check(sampler.bind(id, 7, rig).ok, "old same actual rig bind")
		else: sampler = new_sampler(id, 7, rig)
		var times: Array[int] = []
		for i in 2050:
			# Reset outside clock: identical clear state, same real frames/event for each mode.
			sampler.reset(100 + i)
			var input := event(id, 100 + i, "timing", point, impulse)
			var start := Time.get_ticks_usec()
			if mode in ["can", "both"]: sampler.can_add_hit(input, frames)
			if mode != "can": sampler.add_hit(input, frames)
			if i >= 50: times.append(Time.get_ticks_usec() - start)
		times.sort()
		perf[mode] = {"p50_us": times[1000], "p95_us": times[1900], "max_us": times[-1]}
	preflight_metrics.append(perf)
func preflight_overflow() -> void:
	# Deliberately extreme synthetic topology positions, not a production rig.
	var rest: Array = []
	for i in 28: rest.append(Transform3D.IDENTITY)
	rest[7] = Transform3D(Basis.IDENTITY, Vector3(1e37, 0, 0))
	rest[9] = Transform3D(Basis.IDENTITY, Vector3(0, 1, 0))
	rest[10] = Transform3D(Basis.IDENTITY, Vector3(0, 1, 0))
	var inertia: Dictionary = {}
	for name: String in Selected: inertia[name] = 1.0
	var rig := {"names": Loader.BONES, "parents": Loader.PARENTS, "rest_local": rest, "inertia_kg_m2": inertia}
	var sampler := new_sampler("synthetic_overflow", 7, rig)
	var frames := frames_for(rest, Loader.PARENTS)
	var input := event("synthetic_overflow", 7, "overflow", frames.upperarm_l.origin + Vector3(0, 0.5, 0), Vector3(0, 0, 300))
	var before := var_to_bytes(sampler.snapshot())
	var can: Dictionary = sampler.can_add_hit(input, frames)
	check(not can.ok and can.get("error") == "angular_overflow", "finite synthetic ancestor torque overflow rejected in preflight")
	check(var_to_bytes(sampler.snapshot()) == before and can == sampler.add_hit(input, frames) and var_to_bytes(sampler.snapshot()) == before, "overflow preflight/commit exact atomic parity")
func composed_canary(id: String, rig: Dictionary, rest: Array, parents: Array, source_root: Transform3D, name: String, endpoint: String, euler: Vector3) -> void:
	var base := rest.duplicate()
	var index: int = Loader.BONES.find(name)
	var canonical: Transform3D = rest[index]
	var base_q := canonical.basis.orthonormalized().get_rotation_quaternion() * Quaternion.from_euler(euler)
	base[index] = Transform3D(Basis(base_q).scaled(canonical.basis.get_scale()), canonical.origin)
	var frames := frames_for(base, parents, 0.73, source_root)
	var joint: Transform3D = frames[name]
	var end: Transform3D = frames[endpoint]
	var point := joint.origin.lerp(end.origin, 0.45) + joint.basis.orthonormalized() * Vector3(0.008, 0.006, 0.01)
	var impulse := joint.basis.orthonormalized() * Vector3(0.7, 0.3, -0.5)
	var sampler := new_sampler(id, 7, rig)
	var admitted: Dictionary = sampler.add_hit(event(id, 7, "composed_" + name, point, impulse), frames)
	check(admitted.ok and admitted.get("target") == name, "actual composed contact target " + name)
	var torque := joint.basis.orthonormalized().transposed() * (point - joint.origin).cross(impulse)
	var initial := Vector3(torque.x / 1.1, torque.y / 1.3, torque.z / 1.7)
	check(velocity(sampler, name).distance_to(initial) < 0.000001, "composed frame golden local torque " + name)
	var omega := 18.0 if name == "head" else 16.0
	var theta := initial * 0.01 * exp(-omega * 0.01)
	var dq := Quaternion(theta.normalized(), theta.length())
	var expected_basis := Basis(base_q * dq).scaled(canonical.basis.get_scale())
	var sampled: Dictionary = sampler.sample(0.01, base)
	var actual: Basis = sampled.poses[index].basis
	check(actual.x.distance_to(expected_basis.x) < 0.000001 and actual.y.distance_to(expected_basis.y) < 0.000001 and actual.z.distance_to(expected_basis.z) < 0.000001, "current-axis qbase exp(theta) composed canary " + name)
	check(sampled.poses[index].origin == canonical.origin, "composed canary origin unchanged " + name)
func run_fixture(receipt: Dictionary, manifest_bytes: PackedByteArray) -> void:
	var loaded := Cache.load_verified(manifest_bytes, ManifestSHA, receipt.entry.bridge_id, receipt.entry.descriptor_sha256, Directory)
	check(loaded.ok, "actual frozen cache admission " + receipt.entry.bridge_id)
	if not loaded.ok: return
	var actor: Dictionary = loaded.cache.instantiate_actor()
	check(actor.ok, "actual private actor")
	if not actor.ok: return
	root.add_child(actor.visual)
	var skeleton: Skeleton3D = actor.skeleton
	var rest: Array[Transform3D] = []
	var parents: Array = []
	for i in skeleton.get_bone_count():
		check(skeleton.get_bone_name(i) == Loader.BONES[i], "source canonical bone " + str(i))
		rest.append(skeleton.get_bone_rest(i))
		parents.append(skeleton.get_bone_parent(i))
	check(rest.size() == 28 and parents == Loader.PARENTS, "actual 28 source hierarchy")
	# These positive diagonal inertias are explicit isolated calibration fixtures.
	# They are NOT inferred body masses or source-authoritative inertias.
	var inertia: Dictionary = {}
	for name: String in Selected: inertia[name] = Vector3(1.1, 1.3, 1.7)
	var rig := {"names": Loader.BONES.duplicate(), "parents": parents, "rest_local": rest, "inertia_kg_m2": inertia}
	var id: String = receipt.entry.bridge_id
	var sampler := new_sampler(id, 7, rig)
	var frames := frames_for(rest, parents, 0.73, skeleton.global_transform)
	for i in rest.size():
		var actual_world: Transform3D = Transform3D(Basis(Vector3.UP, 0.73), Vector3(2.1, 0.2, -3.7)) * skeleton.global_transform * skeleton.get_bone_global_pose(i)
		check(frames[Loader.BONES[i]].origin.distance_to(actual_world.origin) < 0.00001, "source current normalized world bone " + str(i))
	var arm: Transform3D = frames.upperarm_l
	var elbow: Transform3D = frames.forearm_l
	var point := arm.origin.lerp(elbow.origin, 0.45) + arm.basis.orthonormalized() * Vector3(0, 0.035, 0.025)
	var impulse := arm.basis.orthonormalized() * Vector3(0.18, 0.11, -0.14)
	preflight_actual(id, rig, rest, frames, point, impulse)
	var base_bytes := var_to_bytes(rest)
	var rig_bytes := var_to_bytes(rig)
	var frames_bytes := var_to_bytes(frames)
	var untouched_skin: Array = []
	for mesh: MeshInstance3D in actor.meshes: untouched_skin.append(var_to_bytes(mesh.mesh.get("_surfaces")))
	var idle: Dictionary = sampler.sample(0.1, rest)
	check(idle.ok and not idle.active and idle.residual_energy_j == 0.0 and idle.poses == rest, "zero idle retains EXACT actual base")
	var plus := event(id, 7, "torque_plus", point, impulse)
	var admitted: Dictionary = sampler.add_hit(plus, frames)
	check(admitted.ok and admitted.get("target") == "upperarm_l", "actual arm hit admitted nearest segment")
	var positive := velocity(sampler, "upperarm_l")
	var expected := arm.basis.orthonormalized().transposed() * (point - arm.origin).cross(impulse)
	expected = Vector3(expected.x / 1.1, expected.y / 1.3, expected.z / 1.7)
	check(positive.distance_to(expected) < 0.000001, "world r cross J transformed to current local inertia frame")
	var chest: Transform3D = frames.chest
	var chest_expected := chest.basis.orthonormalized().transposed() * (point - chest.origin).cross(impulse)
	chest_expected = Vector3(chest_expected.x / 1.1, chest_expected.y / 1.3, chest_expected.z / 1.7) * 0.35
	check(velocity(sampler, "chest").distance_to(chest_expected) < 0.000001, "next selected ancestor weight skips clavicle")
	check(positive.length() > 0.000001, "off-centre nonzero torque")
	var opposite := new_sampler(id, 7, rig)
	check(opposite.add_hit(event(id, 7, "torque_minus", point, -impulse), frames).ok, "opposite impulse admitted")
	check((velocity(opposite, "upperarm_l") + positive).length() < 0.000001, "torque sign reverses with opposite J")
	var different := new_sampler(id, 7, rig)
	var point2 := arm.origin.lerp(elbow.origin, 0.70) + arm.basis.orthonormalized() * Vector3(0, 0.035, 0.025)
	check(different.add_hit(event(id, 7, "different_point", point2, impulse), frames).ok, "different contact admitted")
	check((velocity(different, "upperarm_l") - positive).length() > 0.000001, "actual contact lever changes torque")
	var rotated := new_sampler(id, 7, rig)
	var turn := Transform3D(Basis(Vector3.UP, 1.2), Vector3(-1, 0.3, 2))
	var turned_frames: Dictionary = {}
	for name: String in frames: turned_frames[name] = turn * frames[name]
	check(rotated.add_hit(event(id, 7, "heading", turn * point, turn.basis * impulse), turned_frames).ok, "globally rotated source heading hit admitted")
	check(velocity(rotated, "upperarm_l").distance_to(positive) < 0.000001, "global heading rotation preserves local torque")
	var zero := new_sampler(id, 7, rig)
	check(zero.add_hit(event(id, 7, "zero", point, Vector3.ZERO), frames).ok and not zero.sample(0.1, rest).active, "zero supplied impulse no random reaction")
	var analytic := new_sampler(id, 7, rig)
	analytic.add_hit(event(id, 7, "analytic", point, impulse), frames)
	var analytic_sample: Dictionary = analytic.sample(0.01, rest)
	var expected_theta := positive * 0.01 * exp(-16.0 * 0.01)
	var expected_speed := positive * (1.0 - 16.0 * 0.01) * exp(-16.0 * 0.01)
	check(analytic.snapshot().theta_rad.upperarm_l.distance_to(expected_theta) < 0.000001, "critical spring zero-displacement analytic angle")
	check(velocity(analytic, "upperarm_l").distance_to(expected_speed) < 0.000001 and analytic_sample.active, "critical spring analytic velocity")
	composed_canary(id, rig, rest, parents, skeleton.global_transform, "upperarm_l", "forearm_l", Vector3(0.31, -0.23, 0.27))
	composed_canary(id, rig, rest, parents, skeleton.global_transform, "head", "socket_head", Vector3(0.22, 0.27, -0.20))
	var outside := rest.duplicate()
	outside[5] = Transform3D(rest[5].basis * Basis(Quaternion.from_euler(Vector3(0.12, 0.9, 0.17))), rest[5].origin)
	var outside_frames := frames_for(outside, parents, 0.73, skeleton.global_transform)
	var outside_sampler := new_sampler(id, 7, rig)
	check(outside_sampler.add_hit(event(id, 7, "outside", outside_frames.head.origin, Vector3(1, 0.3, 0.7)), outside_frames).ok, "outside envelope valid source base hit")
	check(outside_sampler.sample(0.01, outside).poses[5] == outside[5], "any outside envelope axis retains ENTIRE bone exact")
	var moved_base := rest.duplicate()
	moved_base[3] = Transform3D(rest[3].basis * Basis(Vector3.UP, 0.035), rest[3].origin)
	var empty_sampler := new_sampler(id, "moving", rig)
	check(empty_sampler.sample(0.01, moved_base).poses == moved_base, "movement base rotations retained EXACT idle")
	var sample := active_sample(sampler, moved_base, id)
	check(sample.active and sample.selected_pose.size() == 7 and sample.residual_energy_j > 0.0, "selected reaction active energy")
	for i in rest.size():
		var pose: Transform3D = sample.poses[i]
		check(pose.origin == moved_base[i].origin, "actual rest length/local origin retained " + str(i))
		check(pose.basis.get_scale().distance_to(moved_base[i].basis.get_scale()) < 0.000001, "actual source local scale retained " + str(i))
		if not Loader.BONES[i] in Selected: check(pose == moved_base[i], "root pelvis legs untouched " + Loader.BONES[i])
	var selected_input := {"valid": true, "poses": moved_base, "visual_offset": Vector3(1, 2, 3), "visual_rotation": Quaternion(Vector3.UP, 0.21), "authority_epoch": 7}
	var selected_bytes := var_to_bytes(selected_input)
	var applied: Dictionary = sampler.apply_to_selected(0.01, selected_input)
	check(applied.valid and applied.visual_offset == selected_input.visual_offset and applied.visual_rotation == selected_input.visual_rotation and applied.authority_epoch == 7, "base selection metadata retained exact")
	check(var_to_bytes(selected_input) == selected_bytes, "selection input not mutated")
	var metadata_before := var_to_bytes(sampler.snapshot())
	var invalid_metadata := selected_input.duplicate()
	invalid_metadata.visual_offset = "bad"
	check(not sampler.apply_to_selected(0.01, invalid_metadata).get("ok", false), "malformed selection metadata rejected")
	check(var_to_bytes(sampler.snapshot()) == metadata_before, "invalid metadata does not advance spring")
	for bad_selection: Dictionary in [{"valid": false, "poses": rest}, {"valid": true, "poses": rest, "authority_epoch": "7"}, {"valid": true, "poses": rest, "visual_rotation": Quaternion(0, 0, 0, 2)}]:
		check(not sampler.apply_to_selected(0.01, bad_selection).get("ok", false), "invalid selection valid/epoch/rotation rejected")
		check(var_to_bytes(sampler.snapshot()) == metadata_before, "invalid selection metadata atomic")
	var minimal: Dictionary = sampler.apply_to_selected(0.0, {"valid": true, "poses": rest})
	check(minimal.ok and not minimal.has("visual_offset") and not minimal.has("visual_rotation") and not minimal.has("authority_epoch"), "missing optional metadata remains missing")
	reject_atomic(sampler, plus, frames, "replayed event")
	reject_atomic(sampler, event("wrong", 7, "wrongactor", point, impulse), frames, "wrong actor")
	reject_atomic(sampler, event(id, "7", "typeepoch", point, impulse), frames, "epoch int/string differs")
	reject_atomic(sampler, event(id, 6, "stale", point, impulse), frames, "stale epoch")
	reject_atomic(sampler, event(id, 7, "far", point + Vector3(100, 100, 100), impulse), frames, "far contact")
	reject_atomic(sampler, event(id, 7, "nan", Vector3(NAN, 0, 0), impulse), frames, "nonfinite contact")
	reject_atomic(sampler, event(id, 7, "excessJ", point, Vector3(301, 0, 0)), frames, "out of contract J")
	var bad_frames := frames.duplicate()
	bad_frames.head = Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
	reject_atomic(sampler, event(id, 7, "singular", point, impulse), bad_frames, "singular joint frame")
	bad_frames = frames.duplicate()
	bad_frames.erase("head")
	reject_atomic(sampler, event(id, 7, "missingframe", point, impulse), bad_frames, "missing frame")
	var state_before := var_to_bytes(sampler.snapshot())
	check(not sampler.sample(0.01, rest.slice(0, 27)).get("ok", false), "short base rejected")
	check(var_to_bytes(sampler.snapshot()) == state_before, "malformed base state atomic")
	var wrong_origin := rest.duplicate()
	wrong_origin[3] = Transform3D(rest[3].basis, rest[3].origin + Vector3(0.1, 0, 0))
	check(not sampler.sample(0.01, wrong_origin).get("ok", false), "base changed local length rejected")
	check(var_to_bytes(sampler.snapshot()) == state_before, "base length reject atomic")
	var wrong_scale := rest.duplicate()
	wrong_scale[3] = Transform3D(rest[3].basis.scaled(Vector3.ONE * 2), rest[3].origin)
	check(not sampler.sample(0.01, wrong_scale).get("ok", false), "base changed local scale rejected")
	check(var_to_bytes(sampler.snapshot()) == state_before, "base scale reject atomic")
	bad_frames = frames.duplicate()
	bad_frames.forearm_l = Transform3D(elbow.basis, elbow.origin + Vector3(0.2, 0, 0))
	reject_atomic(sampler, event(id, 7, "badlength", point, impulse), bad_frames, "finite changed world segment length")
	check(not sampler.sample(NAN, rest).get("ok", false), "NaN delta rejected")
	check(not sampler.sample(-0.1, rest).get("ok", false), "negative delta rejected")
	check(var_to_bytes(sampler.snapshot()) == state_before, "invalid delta no advance")
	var snapshot_copy: Dictionary = sampler.snapshot()
	snapshot_copy.theta_rad.clear()
	snapshot_copy.event_ids.clear()
	check(var_to_bytes(sampler.snapshot()) == state_before, "snapshot defensive dictionary and array copies")
	var bad_rig := rig.duplicate(true)
	bad_rig.inertia_kg_m2.head = Vector3(0, 1, 1)
	var fresh: RefCounted = helper.new()
	check(not fresh.bind(id, 7, bad_rig).ok, "nonpositive test inertia rejected")
	check(not fresh.bind(id, -1, rig).ok and not fresh.bind(id, "", rig).ok, "invalid epoch bind rejected")
	var wrong_parents := rig.duplicate(true)
	wrong_parents.parents[3] = 1
	check(not fresh.bind(id, 7, wrong_parents).ok, "wrong source canonical parent relation rejected")
	check(not sampler.bind(id, 7, rig).ok, "rebind existing sampler rejected")
	check(var_to_bytes(sampler.snapshot()) == state_before, "rebind atomic")
	var dt_a := new_sampler(id, 7, rig)
	var dt_b := new_sampler(id, 7, rig)
	dt_a.add_hit(event(id, 7, "dt", point, impulse), frames)
	dt_b.add_hit(event(id, 7, "dt", point, impulse), frames)
	check(dt_a.sample(10.0, rest).poses == dt_b.sample(0.1, rest).poses and dt_a.snapshot() == dt_b.snapshot(), "large dt clamps to same exact .1 integration")
	for i in 160:
		check(sampler.add_hit(event(id, 7, "repeated_" + str(i), point, impulse.normalized() * 300), frames).ok, "bounded repeat hit")
		sample = active_sample(sampler, rest, "repeat")
		for name: String in Selected:
			check(velocity(sampler, name).length() <= 8.000001, "bounded angular velocity " + name)
			check(sampler.snapshot().theta_rad.get(name, Vector3.ZERO).length() <= 0.250001, "bounded additive angle " + name)
		for name: String in Selected:
			var bone_i: int = Loader.BONES.find(name)
			var rest_q := rest[bone_i].basis.orthonormalized().get_rotation_quaternion()
			var pose_q: Quaternion = sample.poses[bone_i].basis.orthonormalized().get_rotation_quaternion()
			var angle := (rest_q.inverse() * pose_q).get_euler()
			var low := Vector3(-0.35, -0.45, -0.30)
			var high := Vector3(0.35, 0.45, 0.30)
			if name == "head": low = Vector3(-0.65, -0.65, -0.45); high = Vector3(0.65, 0.65, 0.45)
			elif name.begins_with("upperarm"): low = Vector3.ONE * -2.6; high = Vector3.ONE * 2.6
			elif name.begins_with("forearm"): low = Vector3(-2.53, -0.15, -0.15); high = Vector3(0.087, 0.15, 0.15)
			check(angle.x >= low.x - 0.00001 and angle.y >= low.y - 0.00001 and angle.z >= low.z - 0.00001 and angle.x <= high.x + 0.00001 and angle.y <= high.y + 0.00001 and angle.z <= high.z + 0.00001, "actual rest-relative envelope " + name)
		var posed_world := frames_for(sample.poses, parents, 0.73, skeleton.global_transform)
		check(posed_world.foot_l == frames.foot_l and posed_world.foot_r == frames.foot_r and posed_world.pelvis == frames.pelvis, "source normalized feet and pelvis worldframes untouched")
	check(sampler.snapshot().event_ids.size() <= 128, "defensive dedup bound")
	var prior_energy: float = sampler.snapshot().get("residual_energy_j", sample.residual_energy_j)
	for i in 500:
		sample = active_sample(sampler, rest, "settle")
		check(sample.residual_energy_j <= prior_energy + 0.000001, "critical spring energy does not grow")
		prior_energy = sample.residual_energy_j
	check(not sample.active and sample.poses == rest and sample.residual_energy_j == 0.0, "settles to EXACT incoming base")
	sampler.reset("new-epoch")
	check(not sampler.sample(0.01, rest).active, "epoch reset clears energy")
	reject_atomic(sampler, event(id, 7, "oldafterreset", point, impulse), frames, "old epoch after reset")
	check(sampler.add_hit(event(id, "new-epoch", "torque_plus", point, impulse), frames).ok, "new epoch may reuse old event key")
	sampler.reset("new-epoch")
	reject_atomic(sampler, event(id, "new-epoch", "torque_plus", point, impulse), frames, "same epoch reset retains replay window")
	var timings: Array[int] = []
	for i in 2050:
		if i % 10 == 0: sampler.add_hit(event(id, "new-epoch", "timing_" + str(i), point, impulse.normalized() * 100), frames)
		var start := Time.get_ticks_usec()
		sampler.sample(0.01, rest)
		if i >= 50: timings.append(Time.get_ticks_usec() - start)
	timings.sort()
	metrics.append({"actor_id": id, "sex": actor.descriptor.sex, "source_skeleton_world_scale": str(skeleton.global_transform.basis.get_scale()), "source_head_world": str(frames.head.origin), "samples": 2000, "warmups": 50, "active_hit_refresh_every": 10, "sample_p50_us": timings[1000], "sample_p95_us": timings[1900], "sample_max_us": timings[-1]})
	check(var_to_bytes(rest) == base_bytes and var_to_bytes(rig) == rig_bytes and var_to_bytes(frames) == frames_bytes, "actual caller arrays and frame data immutable")
	for i in actor.meshes.size(): check(var_to_bytes(actor.meshes[i].mesh.get("_surfaces")) == untouched_skin[i], "actual skin geometry unchanged")
	actor.visual.free()
func run() -> void:
	helper = load(HelperPath) as GDScript
	if helper == null:
		check(false, "helper unavailable")
		finish()
		return
	var bytes := FileAccess.get_file_as_bytes(Directory + "/manifest.json")
	check(Loader._hash(bytes) == ManifestSHA, "actual frozen 3c07 prepared manifest")
	var manifest: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
	for receipt: Dictionary in manifest.entries: run_fixture(receipt, bytes)
	preflight_overflow()
	finish()
func finish() -> void:
	var result := {"status": "PASS_CPU_ONLY" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures, "helper_sha256": FileAccess.get_sha256(HelperPath), "test_sha256": FileAccess.get_sha256("res://scripts/tests/test_local_hit_reaction.gd"), "manifest_sha256": ManifestSHA, "inertia_provenance": "EXPLICIT_SYNTHETIC_TEST_DIAGONALS_NOT_SOURCE_MASS", "metrics": metrics, "preflight_metrics": preflight_metrics, "limits": ["No rigid-body simulation, source HP, actor birth, GPU or FPS claim", "Actual three source-derived male/female rigs; inertias isolated test choices", "Overflow rig is an explicit synthetic malformed/extreme test fixture"]}
	DirAccess.make_dir_recursive_absolute(Out)
	var file := FileAccess.open(Out + "RESULT.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
