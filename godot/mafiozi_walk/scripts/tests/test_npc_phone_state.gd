extends SceneTree
const State = preload("res://scripts/npc_visual/npc_phone_state.gd")
var checks := 0
var failures := 0
var admitted := true
var identity := {"session_id": "synthetic-test-only", "actor_id": "resident_72", "bridge_id": "npc_resident_72", "life_generation": 1, "source_receipt_sha256": "e9262db60404e538636274565b9a1d6d79de487804af9c7ee99646209b58e096"}

func _initialize() -> void:
	var state = State.new()
	check(state.bind(identity, guard).ok, "bind")
	check(not state.bind(identity, guard).ok, "immutable binding")
	for index in range(8):
		var result: Dictionary = state.update(frame(index, true), 0.1, index * 0.1)
		check(result.ok, "source frame")
		var expected := "draw" if index < 2 else ("raise" if index < 7 else "hold")
		check(result.presentation.phase == expected, "phase")
		check(not result.presentation.authority_written, "no authority")
	var before: Dictionary = state.snapshot()
	check(state.update(frame(7, true), 0.1, 1.0).duplicate, "duplicate")
	check(state.snapshot() == before, "duplicate does not advance")
	for index in range(8, 14):
		var result: Dictionary = state.update(frame(index, false), 0.1, index * 0.1)
		check(result.ok, "stow update")
		check(result.presentation.phase == ("stow" if index < 13 else "idle"), "stow timing")
	var corpse := frame(14, false)
	corpse.raw._corpsePhoneCall = {"until": 5000.0}
	check(state.update(corpse, 0.1, 2.0).presentation.visible, "EMS separate call")
	var dead := frame(15, true)
	dead.raw.dead = true
	check(not state.update(dead, 0.1, 2.0).presentation.visible, "death hides")
	var hidden := frame(16, true)
	hidden.visible = false
	check(not state.update(hidden, 0.1, 2.0).presentation.visible, "hidden")
	var blocked := frame(17, true)
	blocked.phone_blocked = true
	check(not state.update(blocked, 0.1, 2.0).presentation.visible, "blocked")
	check(state.update(frame(18, true), 100.0, 2.0).presentation.phase_time == 0.1, "delta clamp")
	admitted = false
	check(not state.update(frame(19, true), 0.1, 2.0).ok, "guard denies")
	check(not state.snapshot().visible, "admission loss hides")
	admitted = true
	var pending := frame(19, true)
	pending.raw._npcInitialPlacementPending = true
	check(not state.update(pending, 0.1, 2.0).ok, "pending rejects")
	var wrong := frame(19, true)
	wrong.life_generation = 2
	check(not state.update(wrong, 0.1, 2.0).ok, "generation rejects")
	for value: Variant in [{}, [], "x", null, true]:
		var malformed := frame(19, true)
		malformed.raw = value
		check(not state.update(malformed, 0.1, 2.0).ok, "malformed raw")
	for value: Variant in [{}, [], "x", true]:
		var malformed := frame(19, true)
		malformed.raw._witnessCallUntil = value
		check(not state.update(malformed, 0.1, 2.0).ok, "malformed deadline")
	for value: Variant in [{}, [], "x", true]:
		var malformed := frame(19, true)
		malformed.raw._corpsePhoneCall = value
		check(not state.update(malformed, 0.1, 2.0).ok, "malformed EMS")
	check(state.update(frame(19, true), 0.1, 2.0).ok, "recovery current frame")
	check(not state.update(frame(18, true), 0.1, 2.0).ok, "stale rejects")
	var conflict := frame(19, true)
	conflict.event_id = "conflict"
	check(not state.update(conflict, 0.1, 2.0).ok, "conflict rejects")
	print(JSON.stringify({"checks": checks, "failures": failures, "synthetic_only": true}))
	quit(0 if failures == 0 else 1)

func frame(index: int, calling: bool) -> Dictionary:
	var result := identity.duplicate(true)
	result.merge({"event_id": "source-test-episode", "source_frame": index, "source_now_ms": float(index * 100), "visible": true, "phone_blocked": false,
		"raw": {"id": "resident_72", "_npcInitialPlacementPending": false, "dead": false, "snitching": calling, "_witnessStage": "calling", "_witnessCallUntil": 5000.0}})
	return result

func guard(_who: Dictionary, _frame: Dictionary) -> bool:
	return admitted

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
