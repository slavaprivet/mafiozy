extends SceneTree

const Plan=preload("res://scripts/transport/transport_damage_mark_plan.gd")
const ORACLE_PATH="res://data/transport/damage_mark_oracle.json"
const ORACLE_SHA="85762dbdd103f86428d16e89225384355f96fa46662f7f514b205dbd26d9750d"
const SOURCE_SHA="e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92"
const ITERATIONS:=100000
const EPSILON:=2.0e-12

var checks:=0
var failures: Array[String]=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var bytes:=FileAccess.get_file_as_bytes(ORACLE_PATH); var fixture: Variant=JSON.parse_string(bytes.get_string_from_utf8())
	check(_sha(bytes)==ORACLE_SHA,"pinned actual-source mark oracle")
	check(fixture is Dictionary and fixture.schema=="mafiozi.transport-damage-mark-oracle.v1" and fixture.source.vehicle_damage.sha256==SOURCE_SHA and fixture.source.three_revision=="180","instrumented source receipt")
	check(fixture.contract.pool_size==Plan.POOL_SIZE and fixture.contract.scratch_modulo==Plan.SCRATCH_MODULO,"bounded source pool contract")
	for row: Dictionary in fixture.cases:
		var point:=_f64(row.local_point); var normal:=_f64(row.local_normal); var result: Dictionary
		if row.kind.begins_with("bullet"): result=Plan.plan_bullet(int(row.cursor_before),point,normal,float(row.input.damage))
		elif row.kind=="collision_scratch": result=Plan.plan_collision_scratch(int(row.cursor_before),point,normal,_f64(row.local_tangent),float(row.input.impact_speed),float(row.input.slide_speed))
		else: result=Plan.plan_collision_round(int(row.cursor_before),point,normal)
		check(result.ok,"plan "+row.kind+" cursor "+str(row.cursor_before))
		if not result.ok: continue
		check(result.slot==int(row.slot) and result.next_cursor==int(row.cursor_after),"slot/cursor "+row.kind+" cursor "+str(row.cursor_before))
		check(result.slot_kind==("scratch" if int(row.slot)%3==0 else "crater"),"physical slot geometry "+row.kind)
		check(_near(result.position,row.position),"surface offset position "+row.kind)
		check(_near_quaternion(result.quaternion,row.quaternion),"orientation "+row.kind)
		check(_near(result.scale,row.scale),"scale "+row.kind)
		check(absf(float(result.angle_after_increment)-float(row.angle_after_increment))<=EPSILON,"2.399 final cursor angle "+row.kind)
	check(int(fixture.cases[0].slot)%3!=0 and int(fixture.cases[3].slot)==1,"bullets skip scratch slots across wrap")
	check(int(fixture.cases[6].slot)==30 and int(fixture.cases[7].slot)==3,"round collision and sliding scratch select distinct source slots")
	var scratch: Dictionary=fixture.cases[7]; var scratch_dot:=float(scratch.local_normal[0])*float(scratch.local_tangent[0])+float(scratch.local_normal[1])*float(scratch.local_tangent[1])+float(scratch.local_normal[2])*float(scratch.local_tangent[2])
	check(absf(scratch_dot)>.1 and absf(_length(scratch.quaternion)-1.0)>.01,"oracle preserves nonorthogonal nonuniform-scale scratch basis without quaternion normalization")
	_rejection_checks()
	var sample: Dictionary=fixture.cases[1]; var point:=_f64(sample.local_point); var normal:=_f64(sample.local_normal); var checksum:=0; var begin:=Time.get_ticks_usec()
	for i in ITERATIONS:
		var result:=Plan.plan_bullet(31,point,normal,49.0); checksum+=int(result.slot)+int(result.next_cursor)
	var elapsed:=Time.get_ticks_usec()-begin
	check(checksum==ITERATIONS*(31+32),"benchmark consumed deterministic plans")
	finish({"cases":fixture.cases.size(),"iterations":ITERATIONS,"benchmark_us":elapsed,"ns_per_plan":float(elapsed)*1000.0/ITERATIONS,"checksum":checksum})

func _rejection_checks() -> void:
	var point:=PackedFloat64Array([0.0,0.0,0.0]); var normal:=PackedFloat64Array([0.0,0.0,1.0]); var tangent:=PackedFloat64Array([1.0,0.0,0.0])
	check(Plan.plan_bullet(-1,point,normal,1.0).error=="cursor","negative cursor rejected")
	check(Plan.plan_bullet(1.0,point,normal,1.0).error=="cursor","noninteger cursor rejected")
	check(Plan.plan_bullet(Plan.MAX_SAFE_CURSOR+1,point,normal,1.0).error=="cursor","unsafe JS cursor rejected")
	check(Plan.plan_collision_round(Plan.MAX_SAFE_CURSOR,point,normal).error=="cursor","round increment cannot cross JS safe integer")
	check(Plan.plan_bullet(Plan.MAX_SAFE_CURSOR,point,normal).error=="cursor","bullet skip/increment cannot cross JS safe integer")
	check(Plan.plan_collision_scratch(Plan.MAX_SAFE_CURSOR,point,normal,tangent,1.0,1.5).error=="cursor","scratch alignment cannot cross JS safe integer")
	check(Plan.plan_bullet(5,point,normal).scale==PackedFloat64Array([0.75+sqrt(24.0)*0.16,0.75+sqrt(24.0)*0.16,0.75+sqrt(24.0)*0.16]),"private mark default damage is 24")
	check(Plan.plan_bullet(0,PackedFloat64Array([NAN,0,0]),normal,1.0).error=="point","nonfinite point rejected")
	check(Plan.plan_bullet(0,point,PackedFloat64Array([0,0,2]),1.0).error=="normal","nonunit normal rejected")
	check(Plan.plan_bullet(0,point,normal,-1.0).error=="damage","negative damage rejected")
	check(Plan.plan_bullet(0,point,normal,NAN).error=="damage","nonfinite damage rejected")
	check(Plan.plan_collision_scratch(0,point,normal,tangent,2.0,1.499999).error=="slide_speed","scratch threshold enforced")
	check(Plan.plan_collision_scratch(0,point,normal,PackedFloat64Array([0,0,2]),2.0,1.5).error=="tangent","unit transformed tangent required")
	check(Plan.plan_collision_scratch(0,point,normal,tangent,-1.0,1.5).error=="impact_speed","negative impact rejected")
	check(Plan.plan_collision_scratch(0,point,normal,tangent,1.0,INF).error=="slide_speed","nonfinite slide rejected")

func _f64(values: Array) -> PackedFloat64Array:
	return PackedFloat64Array([float(values[0]),float(values[1]),float(values[2])])
func _near(actual: PackedFloat64Array,expected: Array) -> bool:
	if actual.size()!=expected.size(): return false
	for i in actual.size():
		if absf(actual[i]-float(expected[i]))>EPSILON: return false
	return true
func _near_quaternion(actual: PackedFloat64Array,expected: Array) -> bool:
	if _near(actual,expected): return true
	var negated: Array=[]
	for value in expected: negated.append(-float(value))
	return _near(actual,negated)
func _length(values: Array) -> float:
	var squared:=0.0
	for value in values: squared+=float(value)*float(value)
	return sqrt(squared)
func _sha(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes); return context.finish().hex_encode()
func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_DAMAGE_MARK_PLAN "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"oracle_sha":ORACLE_SHA,"source_sha":SOURCE_SHA,"metrics":metrics,"scope":"pure local transform/cursor plan; host owns contact query, surface reprojection, nodes and authority"}))
	quit(0 if failures.is_empty() else 1)
