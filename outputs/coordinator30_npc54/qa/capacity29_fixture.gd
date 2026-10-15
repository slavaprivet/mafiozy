extends SceneTree
## Headless ledger fixture: creates ZERO residents, bodies or buildings.
const Capacity = preload("res://scripts/venues/npc_venue_capacity29.gd")
var checks: Array[String] = []
var failures: Array[String] = []

func check(ok: bool, name: String) -> void:
	checks.append(name)
	if not ok: failures.append(name)

func _initialize() -> void:
	var cap: RefCounted = Capacity.new()
	cap.register("near", "restaurant", 6); cap.register("far", "restaurant", 4)
	var choices: Array = [{"venue":"near","cost":5.0},{"venue":"far","cost":30.0}]
	for i: int in range(286): cap.request(str(i) + ":life1", "restaurant", choices, 0)
	check(cap.snapshot().waiting == 276, "286_request_admission_10_wait_276")
	check(cap.poll("6:life1", 0).venue == "far", "nearest_free_spills_to_second_copy")
	check(cap.request("0:life1", "bank", choices, 0).reason == "other_service_owned", "one_service_per_life")
	var served: Array[int] = []
	var now := 0
	for batch: int in range(100):
		if cap.requests.is_empty(): break
		now += 250
		var granted: Array = []
		var keys: Array = cap.requests.keys(); keys.reverse()
		for key: Variant in keys:
			if cap.poll(str(key), now).state == "reserved": granted.append(key)
		granted.sort_custom(func(a: Variant, b: Variant) -> bool: return int(cap.requests[a].sequence) < int(cap.requests[b].sequence))
		for key: Variant in granted:
			served.append(int(str(key).get_slice(":", 0))); cap.touch(str(key), now, true)
		for key: Variant in granted: cap.release(str(key), now, "death" if batch % 7 == 0 else "physical_exit")
		for site: Dictionary in cap.venues.values(): check(site.slots.size() <= site.capacity, "capacity_batch_" + str(batch))
	var ordered: bool = served.size() == 286
	for i: int in range(served.size()): ordered = ordered and served[i] == i
	check(ordered and cap.requests.is_empty(), "286_fifo_independent_of_reverse_poll_order")
	cap.request("same:life1", "restaurant", choices, now); cap.release("same:life1", now, "death")
	cap.request("same:life2", "restaurant", choices, now); cap.release("same:life1", now, "stale_cancel")
	check(cap.poll("same:life2", now).state == "reserved", "new_life_survives_stale_old_cancel")
	cap = Capacity.new(); cap.register("one", "bank", 1)
	var one: Array = [{"venue":"one","cost":1.0}]
	cap.request("inside", "bank", one, 0); cap.touch("inside", 0, true)
	cap.request("waiting", "bank", one, 0); cap.maintain(121000)
	check(cap.poll("inside", 121000).state == "reserved" and cap.poll("waiting", 121000).state == "lost", "bounded_wait_does_not_expire_living_inside")
	cap.unregister("one", 121001)
	check(cap.poll("inside", 121001).state == "lost", "removed_building_releases_no_completion")
	cap = Capacity.new(); cap.register("one", "shop", 2)
	for key: String in ["a", "b"]: cap.request(key, "shop", one, 0); cap.touch(key, 0)
	check(cap.portal_request("a", "one") and not cap.portal_request("b", "one"), "one_door_crossing_at_a_time")
	cap.release("a", 100, "cancel")
	check(cap.portal_request("b", "one"), "cancel_frees_room_and_portal")
	cap = Capacity.new(); cap.register("one", "shop", 1)
	var result: Dictionary = {}
	for i: int in range(513): result = cap.request(str(i), "shop", one, 0)
	check(result.get("reason") == "request_bound" and cap.snapshot().requests == 512, "global_request_bound_512")
	cap.maintain(16000)
	check(cap.poll("0", 16000).state == "lost" and cap.poll("1", 16000).state == "reserved", "unclaimed_offer_expires_and_promotes_fifo")
	cap = Capacity.new(); cap.register("near", "restaurant", 1); cap.register("far", "restaurant", 1)
	cap.request("owner", "restaurant", [{"venue":"near","cost":1.0}], 0); cap.touch("owner", 0)
	cap.request("old_near", "restaurant", [{"venue":"near","cost":1.0}], 0)
	check(cap.request("later_far", "restaurant", [{"venue":"far","cost":5.0}], 0).state == "reserved", "independent_free_venue_not_blocked_by_old_other_waiter")
	cap.request("new_near", "restaurant", [{"venue":"near","cost":1.0}], 0)
	cap.release("owner", 1, "physical_exit")
	check(cap.poll("old_near", 1).state == "reserved" and cap.poll("new_near", 1).state == "waiting", "oldest_compatible_waiter_wins_slot")
	var report: Dictionary = {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks.size(),"failures":failures,"residents_spawned":0,"requests":286,"scope":"native admission ledger only, no physical or performance acceptance"}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):
			var file := FileAccess.open(arg.trim_prefix("--qa-out="), FileAccess.WRITE)
			if file != null: file.store_string(JSON.stringify(report, "  ") + "\n")
	print("VENUES29_CAPACITY ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
