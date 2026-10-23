extends SceneTree

const Dent=preload("res://scripts/transport/transport_local_dent.gd")
var checks:=0
var failures: Array[String]=[]

func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)

func f32(values: Array) -> PackedFloat32Array:
	return PackedFloat32Array(values)

func run() -> void:
	var initial:=f32([0.0,0.0,0.0, .05,0.0,0.0, .2,0.0,0.0])
	var point:=PackedFloat64Array([0.0,0.0,0.0]); var normal:=PackedFloat64Array([0.0,0.0,1.0])
	var provider:=Dent.new()
	check(provider.configure(initial,1).ok,"configure")
	var before:=provider.snapshot()
	var first: Dictionary=provider.apply(initial,point,normal,64.0,{},1)
	check(first.ok and provider.snapshot().pending,"apply stages without commit")
	check(provider.snapshot().base==before.base and provider.snapshot().offset==before.offset and provider.snapshot().max_depth==before.max_depth,"stage does not advance committed rebase")
	check(provider.apply(initial,point,normal,64.0,{},1).error=="pending_commit","second stage fenced")
	var impostor:=Dent.DentStageToken.new()
	check(provider.commit(impostor).error=="stale_stage" and provider.snapshot().pending,"wrong token cannot consume stage")
	check(provider.abort(first.stage_token).ok and not provider.snapshot().pending,"abort clears exact stage")
	check(provider.snapshot().base==before.base and provider.snapshot().offset==before.offset and provider.snapshot().max_depth==before.max_depth,"abort leaves committed state exact")
	check(provider.commit(first.stage_token).error=="stale_stage","aborted token stays stale")

	var second: Dictionary=provider.apply(initial,point,normal,64.0,{},1)
	var expected_positions: PackedFloat32Array=second.positions.duplicate()
	var expected_offset: PackedFloat32Array=second.offset.duplicate()
	# Returned arrays do not alias the pending state.
	second.positions[0]=99.0; second.offset[0]=99.0; second.base[0]=99.0
	check(provider.commit(second.stage_token).ok,"exact token commits")
	check(provider.snapshot().offset==expected_offset and provider.snapshot().base[0]!=99.0,"caller result mutation cannot mutate pending internals")
	check(provider.abort(second.stage_token).error=="stale_stage","committed token stays stale")

	# A failed reset must preserve the pending transaction; a valid replacement
	# invalidates it and changes the generation atomically.
	var third: Dictionary=provider.apply(expected_positions,point,normal,64.0,{},1)
	check(provider.reset(initial,1,false).error=="generation" and provider.snapshot().pending,"failed reset preserves pending stage")
	check(provider.commit(third.stage_token).ok,"pending stage remains committable after failed reset")
	var fourth: Dictionary=provider.apply(third.positions,point,normal,64.0,{},1)
	var replacement:=f32([1.0,0.0,0.0, 1.05,0.0,0.0, 1.2,0.0,0.0])
	check(provider.reset(replacement,2,false).ok and not provider.snapshot().pending,"valid replacement clears pending")
	check(provider.commit(fourth.stage_token).error=="stale_stage","replacement invalidates old token")
	check(provider.snapshot().generation==2 and provider.snapshot().base==replacement,"replacement state exact")

	# Demonstrate the remaining host contract gap: commit authenticates only the
	# opaque token. It cannot prove the host installed the exact staged positions.
	var mismatch_stage: Dictionary=provider.apply(replacement,PackedFloat64Array([1.0,0.0,0.0]),normal,64.0,{},2)
	var wrong_host_positions: PackedFloat32Array=mismatch_stage.positions.duplicate(); wrong_host_positions[0]+=.05
	var mismatch_commit: Dictionary=provider.commit(mismatch_stage.stage_token)
	var snap:=provider.snapshot()
	var rebase_if_host_used_wrong: float=wrong_host_positions[0]-snap.offset[0]
	check(mismatch_commit.ok and rebase_if_host_used_wrong!=snap.base[0],"token-only commit admits wrong host buffer; caller must enforce exact install")

	provider.dispose()
	check(provider.snapshot().error=="lifetime" and provider.commit(impostor).error=="lifetime","disposed lifetime closed")
	print("TRANSPORT_LOCAL_DENT_TRANSACTION_REVIEW ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"remaining_gap":"commit token cannot attest exact host position buffer","scope":"pure staged dent transaction; no render/GPU/LIVE"}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
