extends SceneTree

const Pose = preload("res://scripts/transport/transport_source_mark_pose.gd")
const ORACLE_PATH = "res://data/transport/source_mark_pose_oracle.json"
const EXPECTED_ORACLE_SHA = "98b31923aca988ed3b8f1b2f857c1e212080a2a455344cb2cc7697468753badc"
const EPSILON := 3.0e-6

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _run() -> void:
	var bytes := FileAccess.get_file_as_bytes(ORACLE_PATH)
	var fixture: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
	_check(_sha(bytes) == EXPECTED_ORACLE_SHA, "frozen oracle receipt")

	var scratch: Dictionary
	for row: Dictionary in fixture.rows:
		var result := Pose.compose(_decode(row.position_f64_le), _decode(row.raw_quaternion_f64_le), _decode(row.scale_f64_le))
		_check(result.ok, "compose " + row.label)
		if result.ok:
			_check(result.matrix_f64.to_byte_array() == _decode(row.matrix_f64_le).to_byte_array(), "exact bytes " + row.label)
		if row.label == "mark_7_collision_scratch":
			scratch = row

	var identity: Dictionary = Pose.compose(PackedFloat64Array([-0.25, 0.5, 1.75]), PackedFloat64Array([0, 0, 0, 1]), PackedFloat64Array([0.5, 2.25, 4]))
	var probe: Vector3 = identity.native_transform * Vector3(2, 3, -1)
	_check(_near_vec(probe, Vector3(0.75, 7.25, -2.25)), "same local frame has no axis flip")

	var scratch_result := Pose.compose(_decode(scratch.position_f64_le), _decode(scratch.raw_quaternion_f64_le), _decode(scratch.scale_f64_le))
	var basis: Basis = scratch_result.native_transform.basis
	_check(absf(basis.x.dot(basis.y)) > 0.05, "raw nonunit quaternion remains nonorthogonal")

	var parent := Pose.compose(_decode(fixture.parent.position_f64_le), _decode(fixture.parent.raw_quaternion_f64_le), _decode(fixture.parent.scale_f64_le))
	var world: Transform3D = parent.native_transform * scratch_result.native_transform
	_check(_transform_near(world, _decode(fixture.parent.scratch_world_matrix_f64_le)), "parent applies local pose exactly once")

	var p := PackedFloat64Array([0, 0, 0])
	var q := PackedFloat64Array([0, 0, 0, 1])
	var s := PackedFloat64Array([1, 1, 1])
	_check(Pose.compose(PackedFloat64Array([INF, 0, 0]), q, s).error == "position", "nonfinite rejected")
	_check(Pose.compose(PackedFloat64Array([1e200, 0, 0]), q, s).error == "native_overflow", "native position overflow rejected")
	_check(Pose.compose(p, q, PackedFloat64Array([1e200, 1, 1])).error == "native_overflow", "native scale overflow rejected")
	_check(Pose.compose(p, q, PackedFloat64Array([1e-200, 1, 1])).error == "native_overflow", "positive native scale underflow rejected")
	_check(Pose.compose(p, PackedFloat64Array([1e308, 1e308, 1e308, 1e308]), s).error == "nonfinite_result", "finite intermediate overflow rejected")
	_check(not Pose.compose([0.0, 0.0, 0.0], q, s).ok, "non-authoritative array type rejected")

	print("TRANSPORT_SOURCE_MARK_POSE_REVIEW " + JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "oracle_sha": EXPECTED_ORACLE_SHA, "scope": "independent CPU pose adversarial review"}))
	quit(0 if failures.is_empty() else 1)

func _decode(encoded: String) -> PackedFloat64Array:
	var bytes := Marshalls.base64_to_raw(encoded)
	var values := PackedFloat64Array()
	values.resize(bytes.size() / 8)
	for index in values.size():
		values[index] = bytes.decode_double(index * 8)
	return values

func _transform_near(transform: Transform3D, expected: PackedFloat64Array) -> bool:
	var actual := [transform.basis.x.x, transform.basis.x.y, transform.basis.x.z, 0.0, transform.basis.y.x, transform.basis.y.y, transform.basis.y.z, 0.0, transform.basis.z.x, transform.basis.z.y, transform.basis.z.z, 0.0, transform.origin.x, transform.origin.y, transform.origin.z, 1.0]
	for index in 16:
		if absf(float(actual[index]) - expected[index]) > EPSILON:
			return false
	return true

func _near_vec(actual: Vector3, expected: Vector3) -> bool:
	return actual.distance_to(expected) <= EPSILON

func _sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
