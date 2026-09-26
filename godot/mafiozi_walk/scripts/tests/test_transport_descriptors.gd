extends SceneTree

const Catalog = preload("res://scripts/transport/transport_descriptor_catalog.gd")
var failures: Array[String] = []
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func run() -> void:
	var catalog := Catalog.new()
	check(catalog.load_file(), "descriptor loads: " + catalog.error)
	check(catalog.profiles.size() == 12, "all 12 actual source profiles")
	check(catalog.parking.size() == 59, "all 59 current source parking bays")
	var sedan: Dictionary = catalog.profile("compact_sedan")
	check(sedan.get("model_sha256", "").length() == 64, "source model identity retained")
	check(sedan.get("seat_count") == 4 and sedan.get("doors", []).size() == 4, "four authored sedan seats and doors")
	check(catalog.seat("compact_sedan", "front_left").get("can_drive") == true, "driver remains front left")
	check(float(catalog.seat("compact_sedan", "front_left").get("anchor_local_m", {}).get("x")) < 0.0, "source left seat converts to Godot -X left")
	check(catalog.seat("compact_sedan", "front_right").get("can_drive") == false, "front right remains passenger")
	check(float(sedan.get("wheelbase_m")) > 2.0 and float(sedan.get("mass_kg")) > 1000.0, "physical source profile exported in SI")
	var ambulance: Dictionary = catalog.profile("city_ambulance")
	check(ambulance.get("seat_count") == 2 and ambulance.get("doors", []).size() == 2, "two-seat source vehicle is not given invented rear seats")
	var first_bay: Dictionary = catalog.parking_bay("parking:REBUILD-VISUAL-hospital-001:bay:0")
	check(first_bay.get("building_id") == "REBUILD-VISUAL-hospital-001", "stable authored hospital parking identity")
	check(is_equal_approx(float(first_bay.get("width_m")), 3.2) and is_equal_approx(float(first_bay.get("length_m")), 5.4), "parking dimensions retained")
	check(catalog.document.get("lifecycle_contract", {}).get("births") == "explicit_authoritative_roster_only", "descriptor forbids implicit births")
	print(JSON.stringify({"checks": checks, "failures": failures, "profiles": catalog.profiles.size(), "parking_bays": catalog.parking.size(), "scope": "tracked source descriptor export; no runtime births or GPU claim"}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
