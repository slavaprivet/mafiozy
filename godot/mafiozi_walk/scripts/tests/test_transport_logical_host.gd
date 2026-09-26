extends SceneTree

const Catalog = preload("res://scripts/transport/transport_descriptor_catalog.gd")
const Host = preload("res://scripts/transport/transport_logical_host.gd")
var failures: Array[String] = []
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func actor(id: String = "actor:max", generation: int = 4) -> Dictionary:
	return {"actor_id": id, "life_generation": generation}

func vehicle(generation: int = 7) -> Dictionary:
	return {"vehicle_id": "vehicle:source:compact-001", "life_generation": generation}

func receipt(action: String, clock: int, seat_id: String = "front_left", actor_ref: Dictionary = actor(), vehicle_ref: Dictionary = vehicle()) -> Dictionary:
	return {"provider": "GODOT_PHYSICS_SPACE_V1", "action": action, "source_clock": clock,
		"actor_id": actor_ref.actor_id, "actor_generation": actor_ref.life_generation,
		"vehicle_id": vehicle_ref.vehicle_id, "vehicle_generation": vehicle_ref.life_generation,
		"door_id": seat_id, "reachable": true, "path_clear": true, "destination_clear": true}

func roster(clock: int, revision: int, occupants: Dictionary = {}, generation: int = 7) -> Dictionary:
	return {"session_id": "session:test", "session_generation": 2, "source_clock": clock, "roster_revision": revision,
		"actors": [{"actor_id": "actor:max", "life_generation": 4, "active": true}, {"actor_id": "actor:passenger", "life_generation": 1, "active": true}],
		"vehicles": [{"vehicle_id": "vehicle:source:compact-001", "life_generation": generation, "active": true,
			"profile_id": "compact_sedan", "position_m": {"x": 10.0, "y": 0.0, "z": 20.0}, "yaw_rad": 0.0, "seats": occupants}]}

func hold(host: RefCounted, token: String, action: String, start: int, actor_ref: Dictionary = actor(), vehicle_ref: Dictionary = vehicle()) -> Dictionary:
	var result: Dictionary = {}
	for offset in [100000, 200000, 300000]:
		var clock: int = start + int(offset)
		result = host.advance_hold(token, true, clock, receipt(action, clock, "front_left", actor_ref, vehicle_ref))
	return result

func run() -> void:
	var catalog := Catalog.new(); check(catalog.load_file(), "catalog ready")
	var host := Host.new(); host.configure(catalog)
	check(host.begin_session({"session_id": "session:test", "mode": "NEW_SESSION_BOOTSTRAP", "session_generation": 2, "source_clock": 1000000}).code == "OK", "explicit bootstrap session")
	check(host.publish_roster(roster(2000000, 1)).code == "OK", "explicit authoritative roster creates source actors/vehicle")
	check(host.publish_roster(roster(1999999, 2)).code == "STALE_CLOCK", "backwards source clock refused")
	var board_clock := 2100000
	var board: Dictionary = host.begin_board(actor(), vehicle(), "front_left", board_clock, receipt("BOARD", board_clock))
	check(board.code == "HOLDING", "safe physical board lease begins")
	var early := host.advance_hold(board.token, true, 2200000, receipt("BOARD", 2200000))
	check(early.code == "HOLDING" and early.remaining_us == 200000, "hold cannot complete early")
	var middle := host.advance_hold(board.token, true, 2300000, receipt("BOARD", 2300000))
	check(middle.code == "HOLDING", "continuous E still holding")
	var boarded := host.advance_hold(board.token, true, 2400000, receipt("BOARD", 2400000))
	check(boarded.code == "BOARDED", "continuous physical 0.3s hold boards")
	check(host.driver(vehicle()).get("actor_id") == "actor:max", "front-left occupant receives driver authority")
	var duplicate := host.begin_board({"actor_id": "actor:passenger", "life_generation": 1}, vehicle(), "front_left", 2500000, receipt("BOARD", 2500000, "front_left", {"actor_id": "actor:passenger", "life_generation": 1}))
	check(duplicate.code == "OCCUPIED", "occupied driver seat refuses duplicate")
	var exit_clock := 2600000
	var exit_claim := host.begin_exit(actor(), vehicle(), "front_left", exit_clock, receipt("EXIT", exit_clock))
	check(exit_claim.code == "HOLDING", "safe exit lease begins")
	var exited := hold(host, exit_claim.token, "EXIT", exit_clock)
	check(exited.code == "EXITED" and host.driver(vehicle()).is_empty(), "physical 0.3s exit clears driver")
	var unsafe_clock := 3000000
	var unsafe := receipt("BOARD", unsafe_clock); unsafe.destination_clear = false; unsafe.reachable = false
	check(host.begin_board(actor(), vehicle(), "front_left", unsafe_clock, unsafe).code == "UNSAFE_ACCESS", "blocked approach fails closed")
	var gap_clock := 3100000
	var gap_claim := host.begin_board(actor(), vehicle(), "front_left", gap_clock, receipt("BOARD", gap_clock))
	check(host.advance_hold(gap_claim.token, true, gap_clock + 120001, receipt("BOARD", gap_clock + 120001)).code == "CONTINUITY_LOST", "missing hold samples cannot fake 0.3s")
	var approach: Dictionary = host.approach_world_pose(vehicle(), "front_left")
	check(approach.get("position_m", {}).get("x", 0.0) < 9.0 and approach.get("door_id") == "front_left", "left-door approach transformed into Godot world")

	var imported := Host.new(); imported.configure(catalog)
	check(imported.begin_session({"session_id": "session:test", "mode": "IMPORTED_EXISTING", "session_generation": 2, "source_clock": 4000000}).code == "OK", "explicit imported-existing session")
	check(imported.publish_roster(roster(4100000, 1)).code == "OK", "initial import contains explicit existing roster")
	var imported_clock := 4200000
	var imported_claim := imported.begin_board(actor(), vehicle(), "front_left", imported_clock, receipt("BOARD", imported_clock))
	var awaiting := hold(imported, imported_claim.token, "BOARD", imported_clock)
	check(awaiting.code == "AWAITING_SOURCE" and imported.driver(vehicle()).is_empty(), "imported session emits command without stealing source authority")
	check(awaiting.command.action == "BOARD" and awaiting.command.command_id == imported_claim.token, "source command retains stable lease identity")
	check(imported.publish_roster(roster(4600000, 2, {"front_left": actor()})).code == "OK", "source acknowledgement published")
	check(imported.driver(vehicle()).get("actor_id") == "actor:max" and imported.diagnostics().leases == 0, "source acknowledgement confirms seat and settles lease")
	check(imported.publish_roster(roster(4700000, 3, {}, 8)).code == "OK", "same vehicle id may start a newer explicit lifetime")
	check(imported.driver(vehicle()).is_empty(), "stale generation cannot address replacement vehicle")
	print(JSON.stringify({"checks": checks, "failures": failures, "bootstrap": host.diagnostics(), "imported": imported.diagnostics(), "scope": "logical authority and physical receipts; no visual/GPU claim"}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
