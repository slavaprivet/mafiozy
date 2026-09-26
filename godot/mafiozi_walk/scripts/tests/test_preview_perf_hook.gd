extends SceneTree
## Real main scene admission for opt-in diagnostics, without a GPU window.
const MainScene = preload("res://scenes/main.tscn")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = MainScene.instantiate()
	check(not main.begin_preview_perf_capture(), "not-ready main rejects capture")
	root.add_child(main)
	await process_frame
	check(main.preview_ready, "actual main ready")
	var perf: Node = main.preview_perf
	check(perf != null, "one adapter attached")
	check(main.get_node("PreviewPerf") == perf, "stable adapter node")
	var opted_in := OS.get_cmdline_user_args().has("--preview-perf")
	check(perf.is_capturing() == opted_in and perf.is_processing() == opted_in, "default OFF or explicit CLI ON")
	if opted_in:
		perf.finish_capture()
	for i in range(5):
		await process_frame
	check(not perf.is_processing(), "OFF remains without callback")
	var config := {"capacity": 100, "warmup_us": 0, "context": {"scenario": "hook-headless", "population": 999}}
	check(main.begin_preview_perf_capture(config), "explicit API begin")
	check(config.context.population == 999, "caller metadata not mutated")
	for i in range(6):
		await process_frame
	var report: Dictionary = perf.finish_capture()
	check(report.accepted_total >= 5 and report.accepted_total <= 7, "one timestamp per actual process tick")
	check(report.context.population == 0 and report.context.vehicles == 0, "actual quarter population overrides caller guess")
	check(report.context.scenario == "hook-headless", "scenario metadata retained")
	check(report.context.display_server == "headless" and report.monitors_at_report.gpu_frame_ms == null, "headless never claims GPU performance")
	check(not perf.is_processing(), "finish returns adapter to OFF")
	check(main.begin_preview_perf_capture(config), "restart admitted")
	check(not main.begin_preview_perf_capture({"context": []}) and perf.is_capturing(), "invalid metadata preserves active capture")
	check(not main.begin_preview_perf_capture({"capacity": 0}) and perf.is_capturing(), "invalid capacity preserves active capture")
	perf.finish_capture()
	main._capture_path = "user://not-written-perf-hook-test.png"
	check(not main.begin_preview_perf_capture(config) and not perf.is_processing(), "PNG capture cannot contaminate measurement")
	main._capture_path = ""
	main.queue_free()
	await process_frame
	var enabled = MainScene.instantiate()
	enabled.preview_perf_enabled = true
	root.add_child(enabled)
	await process_frame
	check(enabled.preview_perf.is_capturing(), "explicit scene export opt-in")
	enabled.queue_free()
	await process_frame
	print("PREVIEW_PERF_HOOK_TEST ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "cli_opt_in": opted_in, "live": false, "fps": false}))
	quit(0 if failures.is_empty() else 1)
