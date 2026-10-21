extends SceneTree

const Catalog = preload("res://scripts/transport/transport_descriptor_catalog.gd")
const Preloader = preload("res://scripts/transport/transport_parking_access_preloader.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func await_result(preloader: RefCounted) -> Dictionary:
	for i in 180:
		var result: Dictionary = preloader.poll()
		if result.code != "PENDING": return result
		await process_frame
	return {"code": "TIMEOUT"}

func run() -> void:
	var catalog := Catalog.new()
	check(catalog.load_file(), "tracked descriptor catalog loads")
	var preloader := Preloader.new()
	check(preloader.poll().code == "IDLE", "preloader starts idle")
	var began := Time.get_ticks_usec()
	check(preloader.begin(catalog) == "PENDING", "source parking load starts on a worker")
	var begin_us := Time.get_ticks_usec() - began
	check(preloader.begin(catalog) == "BUSY", "one active load owns the immutable catalog")
	var max_poll_us := 0
	var polls := 0
	var result: Dictionary = {}
	for i in 180:
		var polled := Time.get_ticks_usec()
		result = preloader.poll()
		polls += 1
		max_poll_us = maxi(max_poll_us, Time.get_ticks_usec() - polled)
		if result.code != "PENDING": break
		await process_frame
	var ready_elapsed_us := Time.get_ticks_usec() - began
	check(result.code == "READY", "worker parses and validates full source sidecar: " + JSON.stringify(result))
	if result.code == "READY":
		check(result.parking.stats().lots == 39 and result.parking.stats().bays == 59 and result.parking.stats().sign_colliders == 57, "ready object retains all source parking and sign data")
	check(preloader.poll().code == "IDLE", "completed worker is joined exactly once")
	check(preloader.begin(catalog, "res://data/transport/absent_parking_access.json") == "PENDING", "failed file starts isolated worker")
	var missing: Dictionary = await await_result(preloader)
	check(missing.code == "ERROR" and missing.error == "OPEN_FAILED", "worker file failure is returned without publishing data")
	preloader.close()
	check(preloader.poll().code == "IDLE", "close leaves no live worker")
	print("TRANSPORT_PARKING_ACCESS_PRELOADER ", JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty(), "begin_us": begin_us, "max_poll_us": max_poll_us, "polls": polls, "ready_elapsed_us": ready_elapsed_us, "scope": "background load only; no LIVE adoption"}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
