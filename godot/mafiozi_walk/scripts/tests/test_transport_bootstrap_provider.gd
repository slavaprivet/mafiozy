extends SceneTree

const Catalog = preload("res://scripts/transport/transport_descriptor_catalog.gd")
const Bootstrap = preload("res://scripts/transport/transport_bootstrap_provider.gd")
var failures: Array[String] = []
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1; if not value: failures.append(message)

func run() -> void:
	var catalog := Catalog.new(); check(catalog.load_file(), "catalog")
	var provider := Bootstrap.new(); check(provider.configure(catalog), "tracked factory: " + provider.error)
	check(provider.factory_slots().size() == 8, "eight source civilian factory slots")
	var request := {"session_id": "preview-native-1", "session_generation": 1, "session_source_clock": 1000, "roster_source_clock": 1001,
		"factory_slot_id": "parked-sedan", "parking_id": "parking:REBUILD-VISUAL-hospital-001:bay:0", "origin_m":{"x":395.65,"y":0.0,"z":45.1}}
	var issued: Dictionary = provider.new_session(request); check(issued.code == "OK", "explicit source new-session birth")
	var packet: Dictionary = issued.packet; var vehicle: Dictionary = packet.roster.vehicles[0]
	check(vehicle.vehicle_id == "local_vehicle_1" and vehicle.life_generation == 1, "source first local identity and generation")
	check(vehicle.profile_id == "compact_sedan" and vehicle.parking_id == request.parking_id, "source model profile at real map parking anchor")
	var source_bay: Dictionary = catalog.parking_bay(request.parking_id)
	check(is_equal_approx(float(vehicle.position_m.x), float(source_bay.position_m.x) - 395.65) and is_equal_approx(float(vehicle.position_m.z), float(source_bay.position_m.z) - 45.1), "source parking anchor is localized once by explicit Godot origin")
	check(vehicle.birth.source_world_position_m == source_bay.position_m and vehicle.birth.origin_m == request.origin_m, "birth retains source-world position and origin provenance")
	check(vehicle.birth.kind == "SOURCE_NEW_SESSION_FACTORY" and String(vehicle.birth.source_sha256).length() == 64, "birth carries source provenance")
	check(packet.physics_births.size() == 1 and packet.physics_births[0].profile_descriptor.profile_id == "compact_sedan", "physics spawn interface is immutable descriptor pair")
	check(provider.new_session(request).code == "DUPLICATE", "identical issue is idempotent")
	var changed := request.duplicate(); changed.parking_id = "parking:REBUILD-VISUAL-hospital-001:bay:1"
	check(provider.new_session(changed).code == "ALREADY_ISSUED", "session cannot fork a second first birth")
	var changed_origin := request.duplicate(true); changed_origin.origin_m.x += 1.0
	check(provider.new_session(changed_origin).code == "ALREADY_ISSUED", "origin is part of idempotent session identity")
	var legacy := request.duplicate(true); legacy.session_id = "preview-native-zero"; legacy.erase("origin_m")
	var legacy_packet: Dictionary = provider.new_session(legacy).packet
	check(legacy_packet.roster.vehicles[0].position_m == catalog.parking_bay(legacy.parking_id).position_m and legacy_packet.session.provenance.origin_m == {"x":0.0,"y":0.0,"z":0.0}, "omitted legacy origin is explicit zero without moving source parking")
	var imported := provider.import_existing({"session_id":"save-1","session_generation":4,"mode":"IMPORTED_EXISTING","source_clock":20}, {"session_id":"save-1","session_generation":4,"source_clock":21,"roster_revision":9,"actors":[],"vehicles":[]})
	check(imported.code == "OK" and imported.packet.physics_births.is_empty(), "imported existing path creates zero births")
	print(JSON.stringify({"checks":checks,"failures":failures,"scope":"tracked new-session source factory; imported saves never birth"}))
	quit(0 if failures.is_empty() else 1)
func _initialize() -> void: run.call_deferred()
