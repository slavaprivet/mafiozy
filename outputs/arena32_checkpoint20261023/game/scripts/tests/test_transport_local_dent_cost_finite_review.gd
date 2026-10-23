extends SceneTree

const Dent=preload("res://scripts/transport/candidates/transport_local_dent_cost_candidate.gd")
const ORACLE_PATH="res://data/transport/local_dent_oracle.json"
var checks:=0
var failures: Array[String]=[]

func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)

func same_bytes(a: PackedFloat32Array,b: PackedFloat32Array) -> bool:
	return a.to_byte_array()==b.to_byte_array()

func run() -> void:
	var normal:=PackedFloat64Array([0.0,0.0,1.0])
	var point:=PackedFloat64Array([0.0,0.0,0.0])
	var tiny:=PackedFloat32Array([0.0,0.0,0.0, .2,0.0,0.0])
	var malformed:=Dent.new()
	check(malformed.configure(PackedFloat32Array(),1).error=="positions","empty configure rejected")
	check(malformed.configure(PackedFloat32Array([0.0,0.0]),1).error=="positions","unaligned configure rejected")
	var too_large:=PackedFloat32Array(); too_large.resize(Dent.MAX_POSITION_VALUES+3)
	check(malformed.configure(too_large,1).error=="positions","oversized configure rejected before use")
	var nan_initial:=tiny.duplicate(); nan_initial[-1]=NAN
	check(malformed.configure(nan_initial,1).error=="nonfinite_positions","nonfinite configure rejected")

	# A pinned source step remains byte-identical through stage and commit.
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ORACLE_PATH)); var source: Dictionary=fixture.steps[0]
	var oracle:=Dent.new(); var source_before:=PackedFloat32Array(source.before)
	check(oracle.configure(source_before,1).ok,"oracle configure")
	var source_stage:=oracle.apply(source_before,PackedFloat64Array(source.local_point),PackedFloat64Array(source.local_normal),float(source.damage),{},1)
	check(source_stage.ok and same_bytes(source_stage.positions,PackedFloat32Array(source.after)) and same_bytes(source_stage.base,PackedFloat32Array(source.state.base)) and same_bytes(source_stage.offset,PackedFloat32Array(source.state.offset)),"pinned source stage byte parity")
	check(oracle.commit(source_stage.stage_token).ok and same_bytes(oracle.snapshot().offset,PackedFloat32Array(source.state.offset)),"pinned source commit deterministic")
	oracle.dispose()

	# The last value of the bounded maximum must be scanned. A rejected request
	# must not create pending state or advance committed cap/rebase.
	var maximum:=PackedFloat32Array(); maximum.resize(Dent.MAX_POSITION_VALUES); maximum.fill(0.0)
	var provider:=Dent.new(); check(provider.configure(maximum,7).ok,"90k configure")
	var baseline:=provider.snapshot()
	var late_nan:=maximum.duplicate(); late_nan[-1]=NAN
	var late_inf:=maximum.duplicate(); late_inf[-1]=INF
	check(provider.apply(late_nan,point,normal,24.0,{},7).error=="nonfinite_positions","late 90k NaN rejected")
	check(provider.apply(late_inf,point,normal,24.0,{},7).error=="nonfinite_positions","late 90k INF rejected")
	var after_nonfinite:=provider.snapshot()
	check(not after_nonfinite.pending and same_bytes(after_nonfinite.base,baseline.base) and same_bytes(after_nonfinite.offset,baseline.offset) and after_nonfinite.max_depth==baseline.max_depth,"nonfinite failures leave transaction atomic")

	# A no-hit stage still follows source cap semantics. Returned base/offset are
	# copies; mutating them cannot reach private pending arrays moved by commit.
	var far:=PackedFloat64Array([100.0,100.0,100.0])
	var nohit:=provider.apply(maximum,far,normal,24.0,{},7)
	check(nohit.ok and nohit.affected==0 and nohit.changed==0 and same_bytes(nohit.positions,maximum),"bounded no-hit positions exact")
	nohit.base[0]=17.0; nohit.base[-1]=19.0; nohit.offset[0]=23.0; nohit.offset[-1]=29.0
	check(provider.commit(nohit.stage_token).ok,"no-hit commit")
	var committed:=provider.snapshot()
	check(committed.max_depth==Dent.BULLET_MAX_DEPTH and committed.base[0]==0.0 and committed.base[-1]==0.0 and committed.offset[0]==0.0 and committed.offset[-1]==0.0,"private pending base and offset isolated at both ends")

	# Collision cap must not advance on abort, then must persist after commit and
	# a later bullet.
	var collision:=provider.apply(maximum,far,normal,1.0,{"impactSpeed":30.0},7)
	check(collision.ok and collision.max_depth==Dent.COLLISION_MAX_DEPTH,"collision cap staged")
	check(provider.abort(collision.stage_token).ok and provider.snapshot().max_depth==Dent.BULLET_MAX_DEPTH,"abort does not advance collision cap")
	var collision2:=provider.apply(maximum,far,normal,1.0,{"impactSpeed":30.0},7)
	check(provider.commit(collision2.stage_token).ok and provider.snapshot().max_depth==Dent.COLLISION_MAX_DEPTH,"collision cap committed")
	var bullet:=provider.apply(maximum,far,normal,1.0,{},7)
	check(bullet.max_depth==Dent.COLLISION_MAX_DEPTH and provider.commit(bullet.stage_token).ok and provider.snapshot().max_depth==Dent.COLLISION_MAX_DEPTH,"later bullet preserves collision cap")

	# Even an outside vertex with corrupted private offset must be caught by the
	# final whole-buffer finite guard, with no pending transaction published.
	provider._offset[-1]=NAN
	var outside_corruption:=provider.apply(maximum,point,normal,24.0,{},7)
	check(outside_corruption.error=="nonfinite_result" and not provider.snapshot().pending,"outside-vertex nonfinite output rejected before pending publication")
	provider.dispose(); malformed.dispose()
	print("TRANSPORT_LOCAL_DENT_COST_FINITE_REVIEW ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"candidate_sha":FileAccess.get_sha256("res://scripts/transport/candidates/transport_local_dent_cost_candidate.gd"),"scope":"functional finite/private-transaction review only; no heavy perf/GPU/LIVE"}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
