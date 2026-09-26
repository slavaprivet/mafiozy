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
		"door_id": seat_id, "door_ready": true, "distance_to_target_m": 0.0, "arrival_ready": true,
		"reachable": true, "start_clear": true, "path_clear": true, "destination_clear": true, "support_clear": true}

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

func transition(host: RefCounted, token: String, action: String, clock: int) -> Dictionary:
	var evidence := {"provider":"TRANSPORT_ACTOR_TRANSITION_V1","action":action,"token":token,"source_clock":clock,"pose_done":true,"physical_safe":true}
	evidence["seat_reached" if action == "BOARD" else "outside_reached"] = true
	if action == "EXIT": evidence.merge({"source_exit_kind":"walk","door_release_done":true,"recovery_done":true,"grounded":true,"blocked":false})
	return host.complete_transition(token, clock, evidence)

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
	check(boarded.code == "TRANSITION_REQUIRED" and host.driver(vehicle()).is_empty(), "hold alone cannot claim seat before physical transition")
	check(host.complete_transition(board.token, 3500000, {}).code == "TRANSITION_ACTIVE", "1.2s native boarding cannot finish before its shared clock")
	boarded = transition(host, board.token, "BOARD", 3600000)
	check(boarded.code == "BOARDED", "confirmed physical seat arrival boards")
	check(host.driver(vehicle()).get("actor_id") == "actor:max", "front-left occupant receives driver authority")
	var duplicate := host.begin_board({"actor_id": "actor:passenger", "life_generation": 1}, vehicle(), "front_left", 5100000, receipt("BOARD", 5100000, "front_left", {"actor_id": "actor:passenger", "life_generation": 1}))
	check(duplicate.code == "OCCUPIED", "occupied driver seat refuses duplicate")
	var exit_clock := 5200000
	var exit_claim := host.begin_exit(actor(), vehicle(), "front_left", exit_clock, receipt("EXIT", exit_clock))
	check(exit_claim.code == "HOLDING", "safe exit lease begins")
	var exited := hold(host, exit_claim.token, "EXIT", exit_clock)
	check(exited.code == "TRANSITION_REQUIRED" and not host.driver(vehicle()).is_empty(), "exit hold retains occupant during transition")
	var premature_exit := {"provider":"TRANSPORT_ACTOR_TRANSITION_V1","action":"EXIT","token":exit_claim.token,"source_clock":exit_clock + 900000,"pose_done":true,"physical_safe":true,"outside_reached":true,"source_exit_kind":"walk","door_release_done":true,"recovery_done":true,"grounded":true,"blocked":false}
	check(host.complete_transition(exit_claim.token, exit_clock + 900000, premature_exit).code == "TRANSITION_ACTIVE", "exit cannot finish before release plus walk recovery")
	exited = transition(host, exit_claim.token, "EXIT", exit_clock + 1500000)
	check(exited.code == "EXITED" and host.driver(vehicle()).is_empty(), "confirmed outside arrival clears driver")
	var unsafe_clock := 8200000
	var unsafe := receipt("BOARD", unsafe_clock); unsafe.destination_clear = false; unsafe.reachable = false
	check(host.begin_board(actor(), vehicle(), "front_left", unsafe_clock, unsafe).code == "UNSAFE_ACCESS", "blocked approach fails closed")
	var gap_clock := 8300000
	var gap_claim := host.begin_board(actor(), vehicle(), "front_left", gap_clock, receipt("BOARD", gap_clock))
	check(host.advance_hold(gap_claim.token, true, gap_clock + 120001, receipt("BOARD", gap_clock + 120001)).code == "CONTINUITY_LOST", "missing hold samples cannot fake 0.3s")
	var approach: Dictionary = host.approach_world_pose(vehicle(), "front_left")
	check(approach.get("position_m", {}).get("x", 0.0) < 9.0 and approach.get("door_id") == "front_left", "left-door approach transformed into Godot world")

	var imported := Host.new(); imported.configure(catalog)
	check(imported.begin_session({"session_id": "session:test", "mode": "IMPORTED_EXISTING", "session_generation": 2, "source_clock": 4000000}).code == "OK", "explicit imported-existing session")
	check(imported.publish_roster(roster(4100000, 1)).code == "OK", "initial import contains explicit existing roster")
	check(imported.sync_native_vehicle_pose(vehicle(), Vector3(99, 0, 99), .5, 4150000).code == "SOURCE_AUTHORITY", "imported session refuses local native pose authority")
	var imported_clock := 4200000
	var imported_claim := imported.begin_board(actor(), vehicle(), "front_left", imported_clock, receipt("BOARD", imported_clock))
	var awaiting := hold(imported, imported_claim.token, "BOARD", imported_clock)
	check(awaiting.code == "TRANSITION_REQUIRED", "imported hold also requires physical transition")
	awaiting = transition(imported, imported_claim.token, "BOARD", imported_clock + 2900000)
	check(awaiting.code == "AWAITING_SOURCE" and imported.driver(vehicle()).is_empty(), "imported transition emits command without stealing source authority")
	check(awaiting.command.action == "BOARD" and awaiting.command.command_id == imported_claim.token, "source command retains stable lease identity")
	check(imported.publish_roster(roster(7200000, 2, {"front_left": actor()})).code == "OK", "source acknowledgement published")
	check(imported.driver(vehicle()).get("actor_id") == "actor:max" and imported.diagnostics().leases == 0, "source acknowledgement confirms seat and settles lease")
	check(imported.publish_roster(roster(7300000, 3, {}, 8)).code == "OK", "same vehicle id may start a newer explicit lifetime")
	check(imported.driver(vehicle()).is_empty(), "stale generation cannot address replacement vehicle")
	var peers := Host.new(); peers.configure(catalog)
	peers.begin_session({"session_id": "session:test", "mode": "NEW_SESSION_BOOTSTRAP", "session_generation": 2, "source_clock": 5000000})
	peers.publish_roster(roster(5100000, 1))
	var shared_tick := 5200000; var passenger := {"actor_id": "actor:passenger", "life_generation": 1}
	check(peers.begin_board(actor(), vehicle(), "front_left", shared_tick, receipt("BOARD", shared_tick)).code == "HOLDING", "first actor admitted at shared source tick")
	check(peers.begin_board(passenger, vehicle(), "front_right", shared_tick, receipt("BOARD", shared_tick, "front_right", passenger)).code == "HOLDING", "second actor may act at same authoritative source tick")
	print(JSON.stringify({"checks": checks, "failures": failures, "bootstrap": host.diagnostics(), "imported": imported.diagnostics(), "scope": "logical authority and physical receipts; no visual/GPU claim"}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
