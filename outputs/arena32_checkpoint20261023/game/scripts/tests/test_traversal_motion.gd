extends SceneTree

const Motion = preload("res://scripts/traversal/traversal_motion.gd")
const SOURCE_ORACLE_JS := """
import {pathToFileURL} from 'node:url';
import {join} from 'node:path';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const root=process.argv[1];
const file=join(root,'hero_traversal.mjs');
const source=await import(pathToFileURL(file));
const plan={kind:'mantle',start:{x:1.25,y:.4,z:-2.5},edge:{x:1.85,y:1.55,z:-2.1},destination:{x:3.45,y:1.55,z:-1.1},direction:{x:.8,z:.6},clearanceY:1.69,duration:1.13};
const samples=[0,.04,.199,.2,.279,.28,.5,.759,.76,.91,1].map(p=>source.sampleTraversal(plan,p));
console.log(JSON.stringify({plan,samples,sha256:createHash('sha256').update(readFileSync(file)).digest('hex')}));
"""

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)


func _run() -> void:
	var source_root := ProjectSettings.globalize_path("res://../../assets/maps/city_rebuild_v1")
	var output: Array = []
	var exit_code := OS.execute("node", ["--input-type=module", "--eval", SOURCE_ORACLE_JS, source_root], output, true)
	_check(exit_code == 0 and not output.is_empty(), "actual hero_traversal source oracle executes")
	if exit_code != 0 or output.is_empty():
		_finish({})
		return
	var oracle: Variant = JSON.parse_string(str(output[0]))
	_check(oracle is Dictionary and oracle.has("samples"), "source oracle JSON")
	if not oracle is Dictionary:
		_finish({})
		return
	var source_plan: Dictionary = oracle.plan
	var support_rid := RID()
	var plan := {
		"admitted": true,
		"kind": source_plan.kind,
		"from_feet": _vec(source_plan.start),
		"edge_position": _vec(source_plan.edge),
		"destination_feet": _vec(source_plan.destination),
		"direction": Vector3(float(source_plan.direction.x), 0.0, float(source_plan.direction.z)),
		"clearance_y_m": float(source_plan.clearanceY),
		"duration_s": float(source_plan.duration),
		"rise_m": 1.15,
		"support_kind": "vehicle",
		"support_id": "fixture-car-7",
		"support_rid": support_rid,
		"support_transform": Transform3D(Basis.from_euler(Vector3(0,.3,0)), Vector3(8,0,-2)),
		"destination_support_local": Vector3(.4,1.55,-.2),
	}
	var state: Dictionary = Motion.begin(plan)
	_check(state.valid and not state.done and state.status == "active", "admitted probe receipt starts active motion")
	_check(state.plan.support_id == "fixture-car-7" and state.plan.support_kind == "vehicle", "support identity retained")
	_check(state.plan.support_transform == plan.support_transform and state.plan.destination_support_local == plan.destination_support_local, "support frame metadata retained")
	var max_position_error := 0.0
	var max_height_error := 0.0
	for index in range(oracle.samples.size()):
		var expected: Dictionary = oracle.samples[index]
		var sample: Dictionary = Motion.sample_state(state, float(expected.progress))
		var expected_position := Vector3(float(expected.x), float(expected.y), float(expected.z))
		max_position_error = maxf(max_position_error, sample.root_position.distance_to(expected_position))
		max_height_error = maxf(max_height_error, absf(float(sample.collision_height_m) - float(expected.height)))
		_check(sample.kind == expected.kind and sample.direction.distance_to(Vector3(.8,0,.6)) < .000001, "source kind and normalized direction sample %d" % index)
	_check(max_position_error < .000001, "all root samples equal executed hero_traversal source")
	_check(max_height_error < .000001, "all collision-height samples equal executed hero_traversal source")
	_check(Motion.sample_state(state,.279).pose_phase == "lift" and Motion.sample_state(state,.28).pose_phase == "carry", "exact source lift/carry boundary")
	_check(Motion.sample_state(state,.759).pose_phase == "carry" and Motion.sample_state(state,.76).pose_phase == "land", "exact source carry/land boundary")
	_check(Motion.sample_state(state,1).pose_phase == "complete", "completion pose phase")
	_check(absf(float(state.yaw_rad) - atan2(-.8,-.6)) < .000001, "yaw follows native preview -Z heading convention")

	# Absolute elapsed sampling must end on the same source point regardless of
	# frame partition. This compares state, not merely an analytic direct sample.
	var one: Dictionary = Motion.begin(plan)
	one = Motion.commit(one, Motion.propose(one, .83))
	var split: Dictionary = Motion.begin(plan)
	for delta: float in [.03,.04,.011,.2,.006,.139,.07,.334]:
		split = Motion.commit(split, Motion.propose(split, delta))
	_check(absf(float(one.elapsed_s)-float(split.elapsed_s)) < .000001, "split elapsed equals one-frame elapsed")
	_check(one.root_position.distance_to(split.root_position) < .000001 and absf(float(one.progress)-float(split.progress)) < .000001, "trajectory deterministic across dt partition")
	_check(one.pose_phase == split.pose_phase and absf(float(one.collision_height_m)-float(split.collision_height_m)) < .000001, "pose phase deterministic across dt partition")

	var before := state.duplicate(true)
	var proposal: Dictionary = Motion.propose(state, .72)
	_check(state == before, "proposal never mutates trajectory state")
	_check(proposal.sweep_samples.size() > 1 and proposal.sweep_samples[-1].root_position == proposal.root_position, "frame proposal includes bounded ordered sweep roots")
	var accepted := maxi(1, proposal.sweep_samples.size() / 2)
	var last_safe: Dictionary = proposal.sweep_samples[accepted - 1]
	var blocked: Dictionary = Motion.commit(state, proposal, accepted, "vehicle_started_moving")
	_check(blocked.done and blocked.blocked and not blocked.aborted and blocked.status == "blocked", "partial physical acceptance is terminal blocked")
	_check(blocked.root_position == last_safe.root_position and absf(float(blocked.elapsed_s)-float(last_safe.elapsed_s)) < .000001, "blocked state holds last accepted root and clock")
	var held: Dictionary = Motion.propose(blocked, 10.0)
	_check(held.terminal and held.sweep_samples.is_empty() and held.root_position == blocked.root_position, "blocked terminal never restarts or moves")

	var no_accept: Dictionary = Motion.commit(state, proposal, 0, "headroom_changed")
	_check(no_accept.root_position == state.root_position and no_accept.progress == state.progress, "block before first sweep preserves current safe root")
	var aborted: Dictionary = Motion.abort(one, "authority_lost")
	_check(aborted.done and aborted.aborted and not aborted.blocked and aborted.root_position == one.root_position, "abort is terminal at last accepted root")
	_check(Motion.propose(aborted,.2).terminal and Motion.propose(aborted,.2).root_position == one.root_position, "aborted state remains stable")

	var complete: Dictionary = Motion.begin(plan)
	complete = Motion.commit(complete, Motion.propose(complete, 4.0))
	_check(complete.done and complete.status == "complete" and complete.root_position == plan.destination_feet, "large valid dt clamps to exact destination")
	_check(absf(float(complete.collision_height_m)-Motion.STANDING_HEIGHT_M) < .000001, "completion restores standing collision height")
	_check(not Motion.begin({"admitted":false}).valid, "unadmitted plan rejected")
	var invalid_direction := plan.duplicate(true)
	invalid_direction.direction = Vector3.ZERO
	_check(not Motion.begin(invalid_direction).valid, "zero direction rejected")
	var invalid_duration := plan.duplicate(true)
	invalid_duration.duration_s = .4
	_check(not Motion.begin(invalid_duration).valid, "duration outside exact source range rejected")
	_check(not Motion.propose(state,NAN).valid and not Motion.propose(state,-.1).valid, "invalid deltas rejected without advancing state")
	var stale := Motion.propose(state,.1)
	var advanced := Motion.commit(state,stale)
	var stale_result := Motion.commit(advanced,stale)
	_check(stale_result.done and stale_result.aborted and stale_result.reason == "stale_or_invalid_proposal", "stale proposal terminates without applying old root")
	_finish({"source_sha256":oracle.sha256,"max_source_root_error_m":max_position_error,"max_source_height_error_m":max_height_error,
		"sweep_samples":proposal.sweep_samples.size(),"motion_sha256":FileAccess.get_sha256("res://scripts/traversal/traversal_motion.gd")})


func _vec(value: Dictionary) -> Vector3:
	return Vector3(float(value.x),float(value.y),float(value.z))


func _finish(metrics: Dictionary) -> void:
	print("TRAVERSAL_MOTION_TEST ", JSON.stringify({"passed":_failures.is_empty(),"checks":_checks,"failures":_failures,
		"metrics":metrics,"scope":"pure proposals only; no player/physics/scene writes, no LIVE/FPS acceptance"}))
	quit(0 if _failures.is_empty() else 1)
