extends SceneTree

var charts: Array = []
var events: Array = []
var checks: Dictionary = {}
var result_path := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): result_path = arg.trim_prefix("--out=")
	call_deferred("run31")

func transition31(state: Node, target: String, event: String, delay: String = "0", expression: String = "") -> void:
	var transition := Transition.new()
	transition.name = "To" + target
	transition.to = NodePath("../../" + target)
	transition.event = event
	transition.delay_in_seconds = delay
	if not expression.is_empty():
		var guard := ExpressionGuard.new()
		guard.expression = expression
		transition.guard = guard
	state.add_child(transition)

func make31(index: int) -> Dictionary:
	var chart := StateChart.new()
	chart.name = "ResidentDiagnostic" + str(index)
	chart.initial_expression_properties = {"door_open": false, "inner_clear": false}
	var parent := CompoundState.new()
	parent.name = "Service"
	parent.initial_state = NodePath("Opening")
	chart.add_child(parent)
	var states := {}
	for label in ["Opening", "Crossing", "Recover", "Threat", "Ordinary"]:
		var state := AtomicState.new()
		state.name = label
		state.state_entered.connect(func(): events.append({"resident": index, "state": label, "ms": Time.get_ticks_msec()}))
		parent.add_child(state)
		states[label] = state
	transition31(states.Opening, "Crossing", "cross", "0", "door_open and inner_clear")
	transition31(states.Opening, "Recover", "", "0.15")
	transition31(states.Opening, "Threat", "threat")
	transition31(states.Crossing, "Ordinary", "complete")
	transition31(states.Threat, "Ordinary", "quiet", "0.08")
	root.add_child(chart)
	return {"chart": chart, "states": states}

func run31() -> void:
	for index in range(10): charts.append(make31(index))
	await process_frame
	await process_frame
	checks["all_10_initial_opening"] = charts.all(func(x): return x.states.Opening.active)
	for row in charts: row.chart.send_event("cross")
	checks["guard_refuses_closed_door"] = charts.all(func(x): return x.states.Opening.active)
	for index in range(0, 5):
		charts[index].chart.set_expression_property("door_open", true)
		charts[index].chart.send_event("cross")
	checks["guard_refuses_occupied_inner"] = charts.slice(0, 5).all(func(x): return x.states.Opening.active)
	for index in range(0, 5):
		charts[index].chart.set_expression_property("inner_clear", true)
		charts[index].chart.send_event("cross")
	checks["five_cross_after_both_conditions"] = charts.slice(0, 5).all(func(x): return x.states.Crossing.active)
	for index in range(5, 8): charts[index].chart.send_event("threat")
	checks["threat_interrupts_wait"] = charts.slice(5, 8).all(func(x): return x.states.Threat.active)
	await create_timer(0.25).timeout
	checks["bounded_timeout_for_two_blocked"] = charts.slice(8, 10).all(func(x): return x.states.Recover.active)
	checks["exited_state_cancels_pending_timeout"] = charts.slice(5, 8).all(func(x): return x.states.Threat.active)
	for index in range(5): charts[index].chart.send_event("complete")
	for index in range(5, 8): charts[index].chart.send_event("quiet")
	await create_timer(0.15).timeout
	checks["eight_finish_or_resume_ordinary"] = charts.slice(0, 8).all(func(x): return x.states.Ordinary.active)
	checks["trace_all_residents"] = range(10).all(func(i): return events.any(func(e): return e.resident == i))
	var result := {"engine": Engine.get_version_info(), "checks": checks, "events": events,
		"passed": checks.values().all(func(v): return v), "scope": "isolated upstream StateCharts semantics; synthetic inputs, no NPC physics, no city integration or performance claim"}
	var file := FileAccess.open(result_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	print("STATECHARTS31 ", JSON.stringify(result))
	quit(0 if result.passed else 2)

