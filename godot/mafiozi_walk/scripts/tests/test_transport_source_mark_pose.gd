extends SceneTree

const Pose=preload("res://scripts/transport/transport_source_mark_pose.gd")
const ORACLE_PATH="res://data/transport/source_mark_pose_oracle.json"
const ORACLE_SHA="98b31923aca988ed3b8f1b2f857c1e212080a2a455344cb2cc7697468753badc"
const MARK_ORACLE_SHA="85762dbdd103f86428d16e89225384355f96fa46662f7f514b205dbd26d9750d"
const ITERATIONS:=100000
const NATIVE_EPSILON:=2.0e-6

var checks:=0
var failures: Array[String]=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var bytes:=FileAccess.get_file_as_bytes(ORACLE_PATH); var fixture: Variant=JSON.parse_string(bytes.get_string_from_utf8())
	check(_sha(bytes)==ORACLE_SHA,"pinned Three compose oracle")
	check(fixture is Dictionary and fixture.schema=="mafiozi.transport-source-mark-pose-oracle.v1" and fixture.source.three_revision=="180" and fixture.source.mark_fixture.sha256==MARK_ORACLE_SHA,"SHA-bound mark source receipt")
	for row: Dictionary in fixture.rows:
		var position:=_f64le(row.position_f64_le); var quaternion:=_f64le(row.raw_quaternion_f64_le); var scale:=_f64le(row.scale_f64_le); var expected:=_f64le(row.matrix_f64_le)
		var result:=Pose.compose(position,quaternion,scale)
		check(result.ok,"compose "+row.label)
		if not result.ok: continue
		check(result.matrix_f64.to_byte_array()==expected.to_byte_array(),"exact raw Three column-major matrix "+row.label+" "+JSON.stringify(_first_difference(result.matrix_f64,expected)))
		check(_native_near(result.native_transform,expected),"explicit native columns "+row.label)
	var scratch: Dictionary=fixture.rows.filter(func(row): return String(row.label).contains("collision_scratch"))[0]
	var scratch_result:=Pose.compose(_f64le(scratch.position_f64_le),_f64le(scratch.raw_quaternion_f64_le),_f64le(scratch.scale_f64_le))
	check(absf(_length(_f64le(scratch.raw_quaternion_f64_le))-1.0)>.01 and absf(scratch_result.native_transform.basis.determinant()-_matrix_determinant(_f64le(scratch.matrix_f64_le)))<NATIVE_EPSILON,"nonunit scratch quaternion remains a nonorthogonal raw matrix")
	var sign_a:=Pose.compose(_f64le(fixture.rows[1].position_f64_le),_f64le(fixture.rows[1].raw_quaternion_f64_le),_f64le(fixture.rows[1].scale_f64_le))
	var sign_b: Dictionary=fixture.rows.filter(func(row): return row.label=="quaternion_sign_pair")[0]; var sign_result:=Pose.compose(_f64le(sign_b.position_f64_le),_f64le(sign_b.raw_quaternion_f64_le),_f64le(sign_b.scale_f64_le))
	check(sign_a.matrix_f64.to_byte_array()==sign_result.matrix_f64.to_byte_array(),"raw quaternion sign pair composes identically")
	var parent:=Pose.compose(_f64le(fixture.parent.position_f64_le),_f64le(fixture.parent.raw_quaternion_f64_le),_f64le(fixture.parent.scale_f64_le))
	check(parent.ok and parent.matrix_f64.to_byte_array()==_f64le(fixture.parent.matrix_f64_le).to_byte_array(),"parent source compose exact")
	var native_world: Transform3D=parent.native_transform*scratch_result.native_transform
	check(_native_near(native_world,_f64le(fixture.parent.scratch_world_matrix_f64_le)),"native parent multiplication applies the same local frame exactly once")
	_rejection_checks()
	var sample: Dictionary=fixture.rows[0]; var position:=_f64le(sample.position_f64_le); var quaternion:=_f64le(sample.raw_quaternion_f64_le); var scale:=_f64le(sample.scale_f64_le); var checksum:=0.0; var begin:=Time.get_ticks_usec()
	for i in ITERATIONS:
		var result:=Pose.compose(position,quaternion,scale); checksum+=result.matrix_f64[0]
	var elapsed:=Time.get_ticks_usec()-begin
	check(is_finite(checksum),"benchmark consumed composed matrices")
	finish({"rows":fixture.rows.size(),"iterations":ITERATIONS,"benchmark_us":elapsed,"ns_per_compose":float(elapsed)*1000.0/ITERATIONS,"checksum":checksum})

func _rejection_checks() -> void:
	var position:=PackedFloat64Array([0,0,0]); var quaternion:=PackedFloat64Array([0,0,0,1]); var scale:=PackedFloat64Array([1,1,1])
	check(Pose.compose(PackedFloat64Array([0,0]),quaternion,scale).error=="position","position length rejected")
	check(Pose.compose(PackedFloat64Array([NAN,0,0]),quaternion,scale).error=="position","nonfinite position rejected")
	check(Pose.compose(position,PackedFloat64Array([0,0,INF,1]),scale).error=="quaternion","nonfinite raw quaternion rejected")
	check(Pose.compose(position,quaternion,PackedFloat64Array([1,0,1])).error=="scale","zero scale rejected")
	check(Pose.compose(position,quaternion,PackedFloat64Array([1,-1,1])).error=="scale","negative scale rejected")
	check(Pose.compose(position,PackedFloat64Array([1e308,1e308,1e308,1e308]),scale).error=="nonfinite_result","finite inputs producing overflow rejected")
	check(Pose.compose(PackedFloat64Array([1e200,0,0]),quaternion,scale).error=="native_overflow","finite position outside native precision rejected")
	check(Pose.compose(position,quaternion,PackedFloat64Array([1e200,1,1])).error=="native_overflow","finite scale outside native precision rejected")
	check(Pose.compose(position,quaternion,PackedFloat64Array([1e-200,1,1])).error=="native_overflow","positive scale underflow in native precision rejected")

func _f64(values: Array) -> PackedFloat64Array:
	var result:=PackedFloat64Array(); result.resize(values.size())
	for i in values.size(): result[i]=float(values[i])
	return result
func _f64le(encoded: String) -> PackedFloat64Array:
	var bytes:=Marshalls.base64_to_raw(encoded); var result:=PackedFloat64Array(); result.resize(bytes.size()/8)
	for i in result.size(): result[i]=bytes.decode_double(i*8)
	return result
func _native_near(transform: Transform3D,expected: Variant) -> bool:
	var actual:=[transform.basis.x.x,transform.basis.x.y,transform.basis.x.z,0.0,transform.basis.y.x,transform.basis.y.y,transform.basis.y.z,0.0,transform.basis.z.x,transform.basis.z.y,transform.basis.z.z,0.0,transform.origin.x,transform.origin.y,transform.origin.z,1.0]
	for i in 16:
		if absf(float(actual[i])-float(expected[i]))>NATIVE_EPSILON: return false
	return true
func _matrix_determinant(matrix: Variant) -> float:
	var a:=float(matrix[0]); var b:=float(matrix[4]); var c:=float(matrix[8]); var d:=float(matrix[1]); var e:=float(matrix[5]); var f:=float(matrix[9]); var g:=float(matrix[2]); var h:=float(matrix[6]); var i:=float(matrix[10])
	return a*(e*i-f*h)-b*(d*i-f*g)+c*(d*h-e*g)
func _first_difference(actual: PackedFloat64Array,expected: PackedFloat64Array) -> Dictionary:
	for i in actual.size():
		if actual.to_byte_array().slice(i*8,i*8+8)!=expected.to_byte_array().slice(i*8,i*8+8): return {"index":i,"actual":actual[i],"expected":expected[i],"delta":actual[i]-expected[i]}
	return {}
func _length(values: Variant) -> float:
	var squared:=0.0
	for value in values: squared+=float(value)*float(value)
	return sqrt(squared)
func _sha(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes); return context.finish().hex_encode()
func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_SOURCE_MARK_POSE "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"oracle_sha":ORACLE_SHA,"mark_oracle_sha":MARK_ORACLE_SHA,"metrics":metrics,"scope":"pure raw source matrix plus explicit native columns; no nodes, normalization, axis flip or authority"}))
	quit(0 if failures.is_empty() else 1)
