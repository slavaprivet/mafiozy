extends SceneTree

const BurnPlan=preload("res://scripts/transport/transport_source_burn_plan.gd")
const ORACLE_PATH="res://data/transport/source_burn_oracle.json"
const ORACLE_SHA="625040555e6a4dcab21491e1ec6d0267e25a1db65a852a82f2da3f7019a0df9c"
const SOURCE_SHA="e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92"
const ITERATIONS:=100000

var checks:=0
var failures: Array[String]=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var bytes:=FileAccess.get_file_as_bytes(ORACLE_PATH); var fixture: Variant=JSON.parse_string(bytes.get_string_from_utf8())
	check(_sha(bytes)==ORACLE_SHA,"pinned actual-source oracle")
	check(fixture is Dictionary and fixture.schema=="mafiozi.transport-source-burn-oracle.v1" and fixture.source.vehicle_damage.sha256==SOURCE_SHA and fixture.source.three_revision=="180","source and Three receipt")
	var target:=_f64le(fixture.target.linear_rgb_f64_le)
	check(target.to_byte_array()==BurnPlan.target_linear_rgb().to_byte_array(),"pinned Three linear target exact")
	for row: Dictionary in fixture.numeric:
		var input:=_f64le(row.input_rgb_f64_le); var expected:=_f64le(row.after_rgb_f64_le); var callback:=_f64le(row.callback_rgb_f64_le)
		var result:=BurnPlan.plan(input,true)
		check(result.ok and result.apply_burn,"eligible plan "+row.label)
		if result.ok:
			check(result.linear_rgb.to_byte_array()==expected.to_byte_array(),"exact source f64 burn "+row.label+" "+JSON.stringify(_first_difference(result.linear_rgb,expected)))
			check(result.linear_rgb.to_byte_array()==callback.to_byte_array() and result.roughness==float(row.roughness) and result.alpha_unchanged,"callback observes planned burn "+row.label)
		check(row.callback_before_detach==true,"source callback precedes detach "+row.label)
	var untouched:=PackedFloat64Array([-2.0,3.5,9.0]); var ineligible:=BurnPlan.plan(untouched,false)
	check(ineligible.ok and not ineligible.apply_burn and ineligible.linear_rgb.to_byte_array()==untouched.to_byte_array() and ineligible.alpha_unchanged,"host-ineligible color returned untouched")
	_semantic_receipts(fixture.semantics)
	_rejections()
	var sample:=PackedFloat64Array([.18,.42,.77]); var checksum:=0.0; var begin:=Time.get_ticks_usec()
	for i in ITERATIONS:
		var result:=BurnPlan.plan(sample,true); checksum+=result.linear_rgb[0]
	var elapsed:=Time.get_ticks_usec()-begin
	check(is_finite(checksum),"benchmark consumed plans")
	finish({"numeric_rows":fixture.numeric.size(),"semantic_rows":fixture.semantics.size(),"iterations":ITERATIONS,"benchmark_us":elapsed,"ns_per_plan":float(elapsed)*1000.0/ITERATIONS,"checksum":checksum})

func _semantic_receipts(rows: Dictionary) -> void:
	var opaque: Dictionary=rows.captured_opaque
	check(opaque.callback_snapshot.debris_children==0 and opaque.callback_snapshot.door_visible==true and opaque.debris_count==1 and opaque.door_visible==false,"opaque source order char callback detach")
	check(_same_json_rgb(opaque.callback_snapshot.original_rgb,opaque.detached.rgb) and float(opaque.detached.roughness)==.99,"opaque detached clone sees burn")
	var replaced: Dictionary=rows.replaced_identity
	check(not _same_json_rgb(replaced.original_after.rgb,replaced.detached.rgb) and _same_json_rgb(replaced.current_after.rgb,replaced.detached.rgb) and float(replaced.detached.roughness)==.27,"replacement is copied uncharred while captured identity chars")
	var array_row: Dictionary=rows.array_material
	check(_same_json_rgb(array_row.original_after.rgb,[.31,.52,.73]) and array_row.detached.size()==2 and _same_json_rgb(array_row.current_after[0].rgb,array_row.detached[0].rgb),"array material is not independently captured for burn")
	var transparent: Dictionary=rows.transparent_material
	check(_same_json_rgb(transparent.original_after.rgb,[.31,.52,.73]) and transparent.debris_count==0 and transparent.detached==null,"transparent material neither chars nor detaches")
	var made_transparent: Dictionary=rows.captured_opaque_toggled_transparent
	check(_same_json_rgb(made_transparent.original_after.rgb,[.31,.52,.73]) and made_transparent.original_after.roughness==.41 and made_transparent.debris_count==0,"explosion-time transparent flag prevents captured burn and detach")
	var made_opaque: Dictionary=rows.captured_transparent_toggled_opaque
	check(made_opaque.original_after.roughness==.99 and not _same_json_rgb(made_opaque.original_after.rgb,[.31,.52,.73]) and made_opaque.debris_count==0,"explosion-time opaque flag permits burn but construction glass capture still prevents detach")
	var mutated: Dictionary=rows.callback_mutates_current
	check(mutated.callback_snapshot.debris_children==0 and _same_json_rgb(mutated.current_after.rgb,[.05,.6,.2]) and _same_json_rgb(mutated.detached.rgb,mutated.current_after.rgb),"generic callback mutation is visible to later detach copy")
	var throwing: Dictionary=rows.callback_throws
	check(throwing.thrown=="oracle_callback_throw" and throwing.original_after.roughness==.99 and throwing.door_visible==true and throwing.debris_count==0,"throwing callback leaves char but prevents hide and detach")

func _rejections() -> void:
	check(BurnPlan.plan([0.0,0.0,0.0],true).get("error","")=="rgb","ordinary array rejected")
	check(BurnPlan.plan(PackedFloat64Array([0.0,0.0]),true).get("error","")=="rgb","wrong RGB length rejected")
	check(BurnPlan.plan(PackedFloat64Array([0.0,NAN,0.0]),true).get("error","")=="rgb","nonfinite RGB rejected")
	check(BurnPlan.plan(PackedFloat64Array([0.0,0.0,0.0]),1).get("error","")=="eligibility","nonboolean eligibility rejected")
	var hdr:=BurnPlan.plan(PackedFloat64Array([1e308,-1e308,1e308]),true)
	check(hdr.ok and hdr.linear_rgb[0]>1e306 and hdr.linear_rgb[1]<-1e306,"finite HDR is neither clamped nor rejected")

func _same_json_rgb(a: Variant,b: Variant) -> bool:
	if not a is Array or not b is Array or a.size()!=3 or b.size()!=3: return false
	for i in 3:
		if float(a[i])!=float(b[i]): return false
	return true
func _f64le(encoded: String) -> PackedFloat64Array:
	var bytes:=Marshalls.base64_to_raw(encoded); var result:=PackedFloat64Array(); result.resize(bytes.size()/8)
	for i in result.size(): result[i]=bytes.decode_double(i*8)
	return result
func _first_difference(actual: PackedFloat64Array,expected: PackedFloat64Array) -> Dictionary:
	for i in actual.size():
		if actual.to_byte_array().slice(i*8,i*8+8)!=expected.to_byte_array().slice(i*8,i*8+8): return {"index":i,"actual":actual[i],"expected":expected[i],"delta":actual[i]-expected[i]}
	return {}
func _sha(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes); return context.finish().hex_encode()
func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_SOURCE_BURN_PLAN "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"oracle_sha":ORACLE_SHA,"source_sha":SOURCE_SHA,"metrics":metrics,"scope":"pure exact source linear burn plan; host supplies eligibility, alpha/native conversion/material stamps/callback order/authority"}))
	quit(0 if failures.is_empty() else 1)
