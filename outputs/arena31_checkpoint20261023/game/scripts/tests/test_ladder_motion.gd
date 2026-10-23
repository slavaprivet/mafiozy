extends SceneTree

const Descriptor = preload("res://scripts/traversal/ladder_descriptor.gd")
const Motion = preload("res://scripts/traversal/ladder_motion.gd")
const Pose = preload("res://scripts/traversal/ladder_pose.gd")
var checks := 0
var failures: Array[String] = []
var descriptor: Dictionary


func _initialize() -> void:
	descriptor = Descriptor.normalize({"id":"motion", "lower":Vector3(0,0,1), "upper":Vector3(0,5,-.9), "outward":Vector3(0,0,1)})
	var up := Motion.begin(descriptor.lower,descriptor,"lower")
	check(up.valid and up.direction == 1, "lower E starts ascent")
	var up_result := finish(up)
	check(up_result.state.done and up_result.state.root_position == descriptor.step_off_point, "ascent completes at exact roof step-off")
	check(up_result.seen_mount and up_result.seen_dismount, "ascent exposes mount and dismount blends")

	var slow := finish(Motion.begin(descriptor.step_off_point,descriptor,"upper"))
	check(slow.state.root_position == descriptor.lower and slow.seen_dismount and slow.terminal_pose_weight <= .0001, "descent releases pose at exact lower endpoint")
	var fast_state := Motion.slide_down(Motion.begin(descriptor.step_off_point,descriptor,"upper"))
	var fast := finish(fast_state)
	check(fast.state.root_position == descriptor.lower and fast.seconds < slow.seconds*.72 and fast.seen_dismount and fast.terminal_pose_weight <= .0001, "active descent slide is faster, exact and releases pose")

	var reverse := Motion.begin(descriptor.lower,descriptor,"lower")
	for index in 60:
		reverse = advance(reverse,1.0/60.0)
	var before: Vector3 = reverse.root_position
	var reversed := Motion.slide_down(reverse)
	check(reversed.root_position == before and reversed.direction == -1 and reversed.sliding, "Ctrl reverses ascent without teleport")
	var reversed_done := finish(reversed)
	check(reversed_done.state.root_position == descriptor.lower and reversed_done.terminal_pose_weight <= .0001, "reversed ascent releases at safe lower endpoint")

	var cancelled := Motion.slide_down(Motion.begin(descriptor.step_off_point,descriptor,"upper"))
	cancelled = advance(cancelled,.2)
	cancelled = Motion.cancel(cancelled)
	check(cancelled.cancelling and not cancelled.sliding, "E during slide slows attached descent")
	var cancelled_done := finish(cancelled)
	check(cancelled_done.state.root_position == descriptor.lower and cancelled_done.terminal_pose_weight <= .0001, "slide cancel releases only at safe bottom")

	var ordinary := Motion.begin(descriptor.lower,descriptor,"lower")
	ordinary = advance(ordinary,.35)
	ordinary = Motion.cancel(ordinary)
	check(ordinary.cancelling and not ordinary.sliding, "ordinary E cancel reverses traversed history")
	var ordinary_done := finish(ordinary)
	check(ordinary_done.state.root_position == descriptor.lower and ordinary_done.terminal_pose_weight <= .0001, "ordinary cancel returns and releases at safe start")
	var descent_cancel := Motion.begin(descriptor.step_off_point,descriptor,"upper")
	descent_cancel = advance(descent_cancel,.35)
	var descent_cancel_root: Vector3 = descent_cancel.root_position
	descent_cancel = Motion.cancel(descent_cancel)
	var descent_cancelled_done := finish(descent_cancel)
	check(descent_cancel.root_position == descent_cancel_root, "descent cancel reverses without command-time root jump")
	check(descent_cancelled_done.state.root_position == descriptor.step_off_point and descent_cancelled_done.terminal_pose_weight <= .0001,
		"descent cancel returns and releases at safe roof start")

	for hz: int in [10,30,60,144]:
		var cadence_down := finish(Motion.begin(descriptor.step_off_point,descriptor,"upper"),hz)
		var cadence_slide := finish(Motion.slide_down(Motion.begin(descriptor.step_off_point,descriptor,"upper")),hz)
		check(cadence_down.state.done and cadence_down.state.root_position == descriptor.lower and cadence_down.terminal_pose_weight <= .0001,
			"ordinary bottom dismount completes without pose snap at %d Hz" % hz)
		check(cadence_slide.state.done and cadence_slide.state.root_position == descriptor.lower and cadence_slide.terminal_pose_weight <= .0001,
			"Ctrl slide bottom dismount completes without pose snap at %d Hz" % hz)
	var releasing := Motion.begin(descriptor.step_off_point,descriptor,"upper")
	while not bool(releasing.get("releasing",false)):
		releasing = advance(releasing,1.0/60.0)
	var release_before := float(releasing.dismount_progress)
	releasing = advance(releasing,0.0)
	check(is_equal_approx(float(releasing.dismount_progress),release_before) and not releasing.done, "dt=0 never advances bottom release")

	var blocked := Motion.begin(descriptor.lower,descriptor,"lower")
	var proposal := Motion.propose(blocked,.1)
	var partial := Motion.commit(blocked,proposal,1,"dynamic_blocked")
	check(not partial.done and partial.blocked and partial.root_position == proposal.sweep_samples[0].root_position, "partial sweep stays active at last safe root")
	check(not Motion.propose(blocked,NAN).valid and not Motion.propose(blocked,-.1).valid, "invalid deltas reject")
	print("LADDER_MOTION_TEST ", JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,
		"slow_seconds":slow.seconds,"slide_seconds":fast.seconds,"scope":"pure proposals; no body writes"}))
	quit(0 if failures.is_empty() else 1)


func advance(state: Dictionary, delta: float) -> Dictionary:
	var proposal: Dictionary = Motion.propose(state,delta)
	return Motion.commit(state,proposal)


func finish(initial: Dictionary, hz: int = 60) -> Dictionary:
	var state := initial
	var seconds := 0.0
	var seen_mount := false
	var seen_dismount := false
	while not bool(state.done) and seconds < 20.0:
		var proposal: Dictionary = Motion.propose(state,1.0/float(hz))
		for sample: Dictionary in proposal.sweep_samples:
			seen_mount = seen_mount or float(sample.mount_progress) < 1.0
			seen_dismount = seen_dismount or float(sample.dismount_progress) > 0.0
		state = Motion.commit(state,proposal)
		seconds += 1.0/float(hz)
	var pose: Dictionary = Pose.propose(descriptor,{"root_position":state.root_position,"travelled_m":state.travelled_m,
		"direction":state.direction,"sliding":state.sliding,"mount_progress":state.mount_progress,"dismount_progress":state.dismount_progress})
	return {"state":state,"seconds":seconds,"seen_mount":seen_mount,"seen_dismount":seen_dismount,"terminal_pose_weight":pose.weight}


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
