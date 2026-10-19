extends SceneTree
const Binding=preload("res://scripts/transport/transport_deformation_cell_binding.gd")
const ORACLE_PATH="res://data/transport/vehicle_deformation_cell_boundary_oracle.json"
const ORACLE_SHA="482a9a9ffef72c05cf9a4997b29c6853855f7fc07b55c2879d176507f0fdb5df"
const SOURCE_PATH="res://../../assets/maps/city_rebuild_v1/vehicle_crash.mjs"
const SOURCE_SHA="cceffb5b6e65a1d180e8860d471351bf04340439ad605a66d6143daf53b20e44"
const ITERATIONS:=100000
var checks:=0
var failures: Array[String]=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var bytes:=FileAccess.get_file_as_bytes(ORACLE_PATH)
	check(_sha(bytes)==ORACLE_SHA,"pinned boundary oracle")
	check(_sha(FileAccess.get_file_as_bytes(SOURCE_PATH))==SOURCE_SHA,"pinned actual vehicle_crash source")
	var oracle: Variant=JSON.parse_string(bytes.get_string_from_utf8())
	check(oracle is Dictionary and oracle.schema=="mafiozi.transport-deformation-cell-boundary-oracle.v1" and oracle.source.sha256==SOURCE_SHA,"source-extracted oracle receipt")
	if not oracle is Dictionary: finish({}); return
	var mismatch_labels: Array[String]=[]; var max_blend_error:=0.0
	for row: Dictionary in oracle.rows:
		var actual: Dictionary
		if row.input_kind=="source_float64": actual=Binding.bind_source(oracle.profile,_packed64(row.source_point))
		else: actual=Binding.bind_native(oracle.profile,_vector(row.native_point))
		check(actual.ok,"helper accepts "+row.label)
		if not actual.ok: continue
		check(actual.cell==_vector3i(row.cell),"source cell "+row.label)
		var wanted_blend:=_packed64(row.blend); max_blend_error=maxf(max_blend_error,_max_component_error_f64(actual.blend_f64,wanted_blend))
		check(_max_component_error_f64(actual.blend_f64,wanted_blend)<=1e-15,"source Float64 blend "+row.label)
		check(actual.blend==Vector3(actual.blend_f64[0],actual.blend_f64[1],actual.blend_f64[2]),"presentation blend explicitly derived "+row.label)
		check(_bytes_equal(actual.node_indices,row.node_indices),"source node order "+row.label)
		check(actual.mask_lo==int(row.mask_lo) and actual.mask_hi==int(row.mask_hi),"source masks "+row.label)
		var legacy:=_legacy_binding(oracle.profile,_packed64(row.source_point))
		if legacy.cell!=actual.cell or legacy.mask_lo!=actual.mask_lo or legacy.mask_hi!=actual.mask_hi: mismatch_labels.append(row.label)
	var by_label: Dictionary={}
	for row: Dictionary in oracle.rows: by_label[row.label]=row
	check(_vector3i(by_label.scalar_x_zero_exact64.cell)==Vector3i(0,0,1) and is_equal_approx(float(by_label.scalar_x_zero_exact64.blend[0]),1.0),"source exact x=0 owns left cell")
	check(_vector3i(by_label.scalar_z_neg_half_exact64.cell)==Vector3i(0,0,0) and is_equal_approx(float(by_label.scalar_z_neg_half_exact64.blend[2]),1.0),"source exact negative half-length owns left cell")
	check(_vector3i(by_label.scalar_z_pos_half_exact64.cell)==Vector3i(0,0,2) and is_equal_approx(float(by_label.scalar_z_pos_half_exact64.blend[2]),1.0),"source exact positive half-length owns left cell")
	check(_vector3i(by_label.scalar_y_min_exact64.cell).y==0 and is_equal_approx(float(by_label.scalar_y_min_exact64.blend[1]),0.0),"source y minimum")
	check(_vector3i(by_label.scalar_y_mid_exact64.cell).y==0 and is_equal_approx(float(by_label.scalar_y_mid_exact64.blend[1]),1.0),"source y middle owns left cell")
	check(_vector3i(by_label.scalar_y_max_exact64.cell).y==1 and is_equal_approx(float(by_label.scalar_y_max_exact64.blend[1]),1.0),"source y maximum")
	for required in ["scalar_x_zero_exact64","scalar_z_neg_half_exact64","scalar_z_zero_exact64","scalar_z_pos_half_exact64","x_zero_prev","x_zero"]:
		check(required in mismatch_labels,"frozen arithmetic boundary mismatch proven "+required)
	check(not Binding.bind_native({},Vector3.ZERO).ok,"missing profile rejected")
	check(Binding.bind_native({"halfWidth":1.0,"halfLength":2.0,"height":.5},Vector3.ZERO).error=="profile_grid","non-increasing profile grid rejected")
	check(Binding.bind_native(oracle.profile,Vector3(NAN,0,0)).error=="point","nonfinite native point rejected")
	check(Binding.bind_source(oracle.profile,PackedFloat64Array([0.0,INF,0.0])).error=="point","nonfinite source scalar rejected")
	var sample: Dictionary=oracle.rows[0]; var sample_point:=_vector(sample.native_point); var begin:=Time.get_ticks_usec(); var checksum:=0
	for i in ITERATIONS:
		var result:=Binding.bind_native(oracle.profile,sample_point); checksum+=result.mask_lo&1
	var elapsed:=Time.get_ticks_usec()-begin
	check(checksum>=0,"benchmark consumed")
	finish({"rows":oracle.rows.size(),"legacy_mismatches":mismatch_labels.size(),"mismatch_labels":mismatch_labels,"max_blend_error":max_blend_error,"queries":ITERATIONS,"total_us":elapsed,"us_per_query":float(elapsed)/ITERATIONS})
func _legacy_binding(profile: Dictionary,p: PackedFloat64Array) -> Dictionary:
	var xv:=clampf((p[0]+float(profile.halfWidth))/(float(profile.halfWidth)*2.0)*2.0,0.0,2.0)
	var zv:=clampf((p[2]+float(profile.halfLength))/(float(profile.halfLength)*2.0)*4.0,0.0,4.0)
	var y:=PackedFloat64Array([.28,float(profile.height)*.46,float(profile.height)*.91]); var yi:=_source_interval(y,p[1])
	var xi:=mini(1,int(floor(xv))); var zi:=mini(3,int(floor(zv))); var lo:=0; var hi:=0
	for zz in 2:
		for yy in 2:
			for xx in 2:
				var index:=((zi+zz)*3+yi+yy)*3+xi+xx
				if index<32: lo|=1<<index
				else: hi|=1<<(index-32)
	return {"cell":Vector3i(xi,yi,zi),"mask_lo":lo,"mask_hi":hi}
func _source_interval(values: PackedFloat64Array,value: float) -> int:
	if value<=values[0]: return 0
	var last:=values.size()-1
	if value>=values[last]: return last-1
	for i in last:
		if value<=values[i+1]: return i
	return last-1
func _packed64(values: Array) -> PackedFloat64Array:
	return PackedFloat64Array([float(values[0]),float(values[1]),float(values[2])])
func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]),float(values[1]),float(values[2]))
func _vector3i(values: Array) -> Vector3i:
	return Vector3i(int(values[0]),int(values[1]),int(values[2]))
func _bytes_equal(actual: PackedByteArray,wanted: Array) -> bool:
	if actual.size()!=wanted.size(): return false
	for i in actual.size():
		if actual[i]!=int(wanted[i]): return false
	return true
func _max_component_error(a: Vector3,b: Vector3) -> float:
	return maxf(absf(a.x-b.x),maxf(absf(a.y-b.y),absf(a.z-b.z)))
func _max_component_error_f64(a: PackedFloat64Array,b: PackedFloat64Array) -> float:
	return maxf(absf(a[0]-b[0]),maxf(absf(a[1]-b[1]),absf(a[2]-b[2])))
func _sha(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes); return context.finish().hex_encode()
func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_DEFORMATION_CELL_BINDING ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"source_sha":SOURCE_SHA,"oracle_sha":ORACLE_SHA,"scope":"source-exact prepared cell/blend/node-mask binding only; frozen deformation unchanged"}))
	quit(0 if failures.is_empty() else 1)
