extends SceneTree
## Read-only observer of one resident's ordinary hospital -> bank -> food cycle.
## Start flags select HP/energy/wallet; no teleports, fake arrivals, or settlements.
const Registry = preload("res://scripts/venues/npc_venue_registry29.gd")
var game: Node3D
var output := ""
var duration := 240
var started := 0
var ready_ms := 0
var sampled := 0
var samples: Array = []
var evidence: Dictionary = {}
var serving: Dictionary = {}
var violations: Array = []
var previous_hp := -1.0
var previous_receipts := 0
var previous_route: Dictionary = {}
var finished := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): output = arg.trim_prefix("--qa-out=")
		if arg.begins_with("--qa-duration="): duration = int(arg.trim_prefix("--qa-duration="))
	started = Time.get_ticks_msec()
	game = load("res://scenes/main_city.tscn").instantiate()
	root.add_child(game); current_scene = game
	while not finished:
		await physics_frame
		await process_frame
		observe()

func observe() -> void:
	var now: int = Time.get_ticks_msec()
	var pop: Variant = game.get("preview_population")
	if pop == null or not bool(pop.get("city_ready")):
		if now - started > 90000: finish("bootstrap_timeout")
		return
	if ready_ms == 0: ready_ms = now
	var life: Variant = pop.daily._lives.get("resident_1")
	if life == null: return
	var body: CharacterBody3D = life._token.body
	var host: Node = game.preview_venue_staff29
	var registry: RefCounted = Registry.for_scene(game)
	var hospital: String = str(life._hospital_stage)
	var economy: RefCounted = life._economy28
	var economy_state: Dictionary = economy.snapshot()
	var route: Variant = life._dsh_simple if not hospital.is_empty() else economy._route
	var kind: String = "hospital" if not hospital.is_empty() else str(economy._kind)
	var route_state: Dictionary = route.snapshot() if route != null else {}
	var active_service := false
	var venue: String = str(route_state.get("venue", ""))
	if route != null and route.is_inside():
		active_service = registry.service_owner29(route._key, venue, route)
		var entry: Dictionary = registry.entry(venue)
		var distance: float = body.global_position.distance_to(entry.get("service_point29", Vector3.INF))
		if active_service and distance <= .42:
			evidence[kind] = {"frame":Engine.get_physics_frames(),"venue":venue,"position":body.global_position,"service_point":entry.service_point29,"distance":distance,"on_floor":body.is_on_floor(),"phase":route_state.phase}
	if is_instance_valid(host) and host._rows.has(venue):
		var staff: CharacterBody3D = host._rows[venue].actor
		if active_service and staff.serving29 and registry.service_customer29(venue) == body:
			serving[kind] = {"frame":Engine.get_physics_frames(),"staff":staff.snapshot29(),"resident_position":body.global_position}
	var hp: float = float(life._life().hp)
	var account: Dictionary = life._account.snapshot()
	var receipts: Array = account.account.receipts
	var bank := 0; var food := 0
	for receipt: Dictionary in receipts:
		if receipt.kind == "local_bank_grant28": bank += 1
		if receipt.kind in ["local_shop_purchase28", "local_restaurant_purchase28"]: food += 1
	if previous_hp >= 0 and hp > previous_hp and not (active_service or previous_route.get("service", false)):
		violations.append("healed without verified staff position")
	# The preexisting test_wallet_initialization28 receipt is initial state,
	# not a venue transaction; observe only actual bank/food settlements here.
	if bank + food > previous_receipts and not (active_service or previous_route.get("service", false)):
		violations.append("settled without verified staff position")
	previous_hp = hp; previous_receipts = bank + food
	previous_route = {"service":active_service,"kind":kind}
	var complete: bool = int(life._completed.get("hospital",0)) >= 1 and bank == 1 and food == 1 and not economy.active() and economy._roams >= 1 and registry.ledger.requests.is_empty() and registry._service29.keys.is_empty()
	if now - sampled >= 500 or complete or now - ready_ms >= duration * 1000:
		sampled = now
		var row := {"ready_ms":now-ready_ms,"hp":hp,"max_hp":life._life().max_hp,"energy":life._energy,"hospital":hospital,"hospital_completed":life._completed.get("hospital",0),"economy":economy_state,"account":account,"route":route_state,"position":body.global_position,"service":active_service,"staff_count":host._rows.size() if is_instance_valid(host) else 0,"resident_count":pop.daily._lives.size(),"service_claims":registry._service29.keys.size(),"capacity_claims":registry.ledger.requests.size()}
		samples.append(row)
		print("STAFF30_CYCLE ", JSON.stringify(row))
	if complete:
		finish("cycle_physically_complete")
	elif now - ready_ms >= duration * 1000: finish("bounded_cycle_timeout")

func finish(reason: String) -> void:
	if finished: return
	finished = true
	var result := {"reason":reason,"samples":samples,"physical_service_evidence":evidence,"staff_serving_evidence":serving,"violations":violations,"performance_accepted":false,"visual_verified":false}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result,"\t")); file.close()
	print("STAFF30_CYCLE_FINISH ", reason)
	quit(0 if reason == "cycle_physically_complete" and violations.is_empty() else 1)
