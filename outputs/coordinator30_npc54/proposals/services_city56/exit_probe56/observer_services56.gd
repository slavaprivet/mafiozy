extends Node
## Actual shared city, four original lives. Only explicitly journalled initial
## energy/cash setup and one PLAYER placement; no NPC/route/HP/receipt shortcuts.
const Registry = preload("res://scripts/venues/npc_venue_registry29.gd")
const Physical = preload("res://scripts/hospital/npc_physical_route51.gd")
const Counts = preload("observer_counts56.gd")
const KINDS: Array[String] = ["hospital", "restaurant", "bank", "shop"]
const RECEIPTS := {"bank":"local_bank_grant28", "restaurant":"local_restaurant_purchase28", "shop":"local_shop_purchase28"}
var _out := ""
var _duration := 240
var _expected := 10
var _start_ms := 0
var _ready_ms := 0
var _next_sample := 0
var _next_select := 0
var _finished := false
var _pop: RefCounted
var _registry: RefCounted
var _staff: Node
var _scene: Node3D
var _player: CharacterBody3D
var _camera: Camera3D
var _weapons: Node
var _cases: Dictionary = {}
var _wanted: Array[String] = []
var _composition: Dictionary = {}
var _initializations: Array[Dictionary] = []
var _samples: Array[Dictionary] = []
var _failures: Array[String] = []
var _shots: Array[Dictionary] = []
var _terminals: Array[Dictionary] = []
var _player_setup: Dictionary = {}
var _positions: Dictionary = {}
var _travel: Dictionary = {}
var _fired := 0
var _stable := 0
var _last_fire := -100000
var _fire_down := false
var _aim_done := false
var _aim_started := 0
var _max_observer_us := 0
var _max_sample_us := 0

func _ready() -> void:
	process_physics_priority = 1000
	_start_ms = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): _out = arg.trim_prefix("--qa-out=")
		if arg.begins_with("--qa-duration="): _duration = int(arg.trim_prefix("--qa-duration="))
		if arg.begins_with("--qa-residents="): _expected = int(arg.trim_prefix("--qa-residents="))
	if _out.is_empty(): _finish("qa_output_required")
	elif _expected < 10 or _expected > 280 or _expected % 10 != 0: _finish("batch_of_ten_required_287_forbidden")

func _v(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x, a.z-b.z).length()

func _live_ids() -> Array[String]:
	var result: Array[String] = []
	for id: String in _pop.residents._records:
		var body: Variant = _pop.residents._records[id].get("body")
		if is_instance_valid(body) and body.is_inside_tree(): result.append(id)
	result.sort()
	return result

func _staff_count() -> int:
	var count := 0
	if not is_instance_valid(_staff): return 0
	for row: Dictionary in _staff._rows.values():
		if is_instance_valid(row.actor) and row.actor.is_inside_tree(): count += 1
	return count

func _bind() -> bool:
	_scene = get_tree().current_scene as Node3D
	_pop = _scene.get("preview_population")
	if _pop == null or not _pop.city_ready or not _pop.city_stream_complete(): return false
	_staff = _scene.get("preview_venue_staff29")
	if _staff_count() != 12: return false
	_registry = Registry.for_scene(_scene)
	var packet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/npc_city/session_packet.json"))
	for row: Dictionary in packet.rows:
		if _wanted.size() >= _expected: break
		_wanted.append(str(row.source_id))
	_wanted.sort()
	var actual: Array[String] = _live_ids()
	var daily: Array = _pop.daily._lives.keys(); daily.sort()
	if _wanted.size() != _expected or actual != _wanted or daily != _wanted or _pop.hit_owners.size() != _expected:
		_finish("requested_original_identity_set_missing"); return false
	var sites: Variant = _scene.get("preview_service_sites29")
	_composition = {"original_ids":actual,"original_count":actual.size(),"daily_count":daily.size(),"health_owners":_pop.hit_owners.size(),"staff_count":_staff_count(),"staff_report":_staff.report.duplicate(true),"new_sites":sites.snapshot() if sites != null else {},"venues":[]}
	for venue: String in _staff._rows:
		var entry: Dictionary = _registry.entry(venue)
		var clone: Node3D = _staff._rows[venue].clone.get_ref()
		_composition.venues.append({"venue":venue,"kind":entry.get("kind"),"clone":str(clone.name),"door":_v(entry.door),"inward":_v(entry.normal),"outside":_v(entry.outside),"service_point":_v(entry.service_point29)})
	_player = _scene.get("_player"); _weapons = _scene.get("preview_weapons")
	if not is_instance_valid(_player) or not is_instance_valid(_weapons): _finish("player_weapon_owner_missing"); return false
	_camera = _player.get_preview_camera()
	_weapons.shot_emitted.connect(_shot)
	_weapons.effects.projectile_resolved.connect(_terminal)
	_ready_ms = Time.get_ticks_msec()
	print("SERVICES56_READY ", JSON.stringify({"originals":actual.size(),"staff":12,"duration_after_startup_s":_duration}))
	return true

func _eligible(life: RefCounted, kind: String) -> bool:
	if life._disposed or not life._host.target_current(life._token): return false
	var body: CharacterBody3D = life._token.body
	if not body.is_on_floor() or life._health.should_pause_walk() or life.threat_physics_active30() or life._attention29.active or life._visit != null: return false
	if not life._hospital_stage.is_empty() or life._economy28 == null or life._economy28.active() or not life._economy28._pending.is_empty(): return false
	if life._ambient29 != null and life._ambient29.active(): return false
	var hp: Dictionary = life._life()
	if hp.is_empty() or float(hp.hp) != 60.0 or float(hp.max_hp) != 60.0: return false
	if life._energy < 50.0 or not life._account.conserved(): return false
	if kind == "bank" and (life._roam51_active or life._phase not in ["IDLE", "RESTING"]): return false
	if kind in ["restaurant", "shop"]:
		if life._now < life._restaurant28_retry_at or life._now < life._economy28._retry_at: return false
		# Predict the owner's next normal food choice without consuming its RNG.
		# The pending purchase itself is created by the production energy branch.
		if not life._roam51_active and (life._phase not in ["IDLE", "RESTING"] or life._next_decision > life._now + 50.0): return false
		var rng := RandomNumberGenerator.new(); rng.seed = life._economy28._rng.seed; rng.state = life._economy28._rng.state
		var predicted: String = "restaurant" if rng.randi_range(0, 1) == 0 else "shop"
		if predicted != kind: return false
	return true

func _select(kind: String) -> void:
	var best: RefCounted
	var nearest: Dictionary = {}
	var best_distance := INF
	for id: String in _pop.daily._lives:
		if _cases.values().any(func(c: Dictionary) -> bool: return c.id == id): continue
		var life: RefCounted = _pop.daily._lives[id]
		if not _eligible(life, kind): continue
		var position: Vector3 = life._token.body.global_position
		for venue: Dictionary in _composition.venues:
			if venue.kind != kind: continue
			var point: Vector3 = Vector3(venue.outside[0], venue.outside[1], venue.outside[2])
			var door: Vector3 = Vector3(venue.door[0], venue.door[1], venue.door[2])
			var inward: Vector3 = Vector3(venue.inward[0], venue.inward[1], venue.inward[2])
			if (position-door).dot(inward) >= -1.1: continue
			var distance: float = _flat(position, point)
			if distance < best_distance:
				best_distance = distance; best = life; nearest = venue
	if best == null: return
	var body: CharacterBody3D = best._token.body
	var id: String = best._token.source_id
	var account: Dictionary = best._account.snapshot()
	var known: Dictionary = {}
	for receipt: Dictionary in account.account.receipts: known[str(receipt.id)] = true
	var row: Dictionary = {"id":id,"kind":kind,"life":best,"health":best._health,"body":body,"token":best._token.duplicate(),"start_position":body.global_position,"last_position":body.global_position,"travel_m":0.0,"max_physics_displacement_m":0.0,"start_completed":int(best._completed[kind]),"last_hp":float(best._life().hp),"min_hp":float(best._life().hp),"last_revision":-1,"seen_receipts":known,"health_receipts":[],"money_receipts":[],"heal_receipts":[],"route_events":[],"service":{},"staff_serving":{},"geometry":{},"geometry_raw":{},"route_id":0,"route_phase":"","service_frame":-100,"entered":false,"treated":false,"outbound":false,"completed":false,"exit":{},"energy_restored":false,"selection":{"source_id":id,"body_id":body.get_instance_id(),"generation":best._token.life_generation,"position":_v(body.global_position),"nearest_venue":nearest,"distance_to_nearest_outside_m":best_distance,"owner_phase":best._phase,"energy_before":best._energy,"account_before":account,"rng_state_read_only":str(best._economy28._rng.state),"selected_ms":Time.get_ticks_msec()}}
	_cases[kind] = row
	row["exterior_seen"] = false
	row.selection["initial_hp"] = float(best._life().hp)
	if kind in ["restaurant", "shop"]:
		var before: float = best._energy
		best._energy = 19.0
		_initializations.append({"kind":"qa_initial_energy56","source_id":id,"before":before,"after":19.0,"frame":Engine.get_physics_frames(),"service_receipt":false,"rng_modified":false,"pending_purchase_written":false})
	elif kind == "bank":
		var wallet: Dictionary = best._account._account
		var cash_before: int = int(wallet.cash)
		wallet.cash = 0; wallet.initial_total -= cash_before
		# Explicit setup receipt, separate from production settlement receipts.
		var receipt: Dictionary = best._account._commit_receipt("qa_initial_wallet56", cash_before, best._health._now(), {"cash_before":cash_before,"cash_delta":-cash_before,"qa_setup":true,"service_receipt":false,"server_authority":false})
		row.seen_receipts[str(receipt.id)] = true
		_initializations.append(receipt)
		if not best._account.conserved(): _finish("qa_wallet_initialization_not_conserved"); return
	print("SERVICES56_SELECTED ", JSON.stringify({"kind":kind,"source_id":id,"distance_m":best_distance,"initial_energy":best._energy,"cash":best._account._account.cash}))
	if kind == "hospital":
		if not _place_player(body): _finish("no_supported_clear_player_shooting_position"); return
		_player.set_mouse_captured(true)
		var equip: Dictionary = _weapons.equip("tt_pistol")
		if not equip.get("ok", false): _finish("native_tt_equip_refused"); return
		_button(MOUSE_BUTTON_RIGHT, false)
		_aim_started = Time.get_ticks_msec()

func _place_player(target: CharacterBody3D) -> bool:
	var probe := Physical.new()
	if not probe.configure(_player): return false
	var before: Vector3 = _player.global_position
	for radius: float in [6.0, 8.0, 10.0]:
		for index: int in range(16):
			var angle: float = TAU * float(index) / 16.0
			var seed: Vector3 = target.global_position + Vector3(cos(angle), 0, sin(angle)) * radius
			var floor: Variant = probe.floor_at(seed, target.global_position.y)
			if not floor is Vector3 or not probe.standing(floor): continue
			var query := PhysicsRayQueryParameters3D.create(floor + Vector3.UP * 1.45, target.global_position + Vector3.UP * 1.05, 0xffffffff, [_player.get_rid()])
			var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or not _cases.hospital.health._owns_collider(hit.get("collider")): continue
			_player.set_preview_pose_authority(&"on_foot", true)
			_player.global_position = floor
			_player_setup = {"qa_player_only_relocation":true,"count":1,"from":_v(before),"to":_v(floor),"support_and_capsule_checked":true,"npc_relocations":0,"frame":Engine.get_physics_frames()}
			return true
	return false

## Input and authenticated callback pipeline adapted from injury30 native proof.
func _button(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button; event.pressed = pressed
	event.position = get_viewport().get_visible_rect().size * .5; event.global_position = event.position
	get_viewport().push_input(event, true)

func _shot(shot: Dictionary, muzzle: Dictionary, _origin: Vector3, _direction: Vector3) -> void:
	_shots.append({"shot_id":str(shot.get("shotId", str(shot.get("weaponId"))+":"+str(shot.get("sequence")))),"weapon":shot.get("weaponId"),"frame":Engine.get_physics_frames(),"muzzle":_v(muzzle.get("origin", Vector3.ZERO))})

func _terminal(receipt: Dictionary) -> void:
	var collider: Variant = receipt.get("collider")
	_terminals.append({"shot_id":str(receipt.get("shotId", "")),"status":receipt.get("status"),"weapon":receipt.get("weaponId"),"frame":Engine.get_physics_frames(),"owned":_cases.has("hospital") and _cases.hospital.health._owns_collider(collider),"collider_id":collider.get_instance_id() if is_instance_valid(collider) else 0})

func _aim(away: bool = false) -> bool:
	var body: CharacterBody3D = _cases.hospital.body
	var health: RefCounted = _cases.hospital.health
	var target: Vector3 = body.global_position + Vector3(0, 1.05, 0)
	var direction: Vector3 = (target - _camera.global_position).normalized()
	var yaw: float = atan2(-direction.x, -direction.z) + (PI if away else 0.0)
	var pitch: float = .44 if away else asin(clampf(direction.y, -.98, .98))
	var motion := InputEventMouseMotion.new()
	motion.position = get_viewport().get_visible_rect().size * .5; motion.global_position = motion.position
	motion.relative = Vector2(-wrapf(yaw-_player._camera_yaw, -PI, PI)*.35/_player.mouse_sensitivity, -(pitch-_player._camera_pitch)*.35/_player.mouse_sensitivity)
	get_viewport().push_input(motion, true)
	if away: return false
	var hit: Dictionary = _weapons._projectile_ray({"origin":_camera.global_position,"direction":-_camera.global_basis.z,"range":100.0})
	var muzzle: Dictionary = _weapons.presentation.current_muzzle()
	if not muzzle.get("ok", false) or not hit.has("point") or not health._owns_collider(hit.get("collider")): return false
	var along: Vector3 = (hit.point-muzzle.origin).normalized()
	var muzzle_hit: Dictionary = _weapons._projectile_ray({"origin":muzzle.origin,"direction":along,"range":muzzle.origin.distance_to(hit.point)+.03})
	return health._owns_collider(muzzle_hit.get("collider")) and (-_camera.global_basis.z).angle_to(direction)<.006 and float(_weapons.fire_state.cooldown)<=0 and float(_weapons.fire_state.reloadRemaining)<=0 and int(_weapons.fire_state.magazine)>0

func _fire_step(now: int) -> void:
	if not _cases.has("hospital"): return
	if _aim_done:
		_aim(true)
		return
	var hp: float = float(_cases.hospital.health._row.hp)
	if hp <= 0 or bool(_cases.hospital.health._row.get("dead", false)): _finish("nonfatal_shots_became_fatal"); return
	if hp <= 12.01:
		_aim_done = true
		_cases.hospital["hp_after_tt"] = hp
		_weapons.cancel_inputs()
		_weapons.equip("none")
		_aim(true)
		return
	if now-_aim_started > 30000: _finish("two_native_tt_hits_not_completed"); return
	if _fired > 0 and _cases.hospital.health.should_pause_walk():
		_stable = 0
		_aim()
		return
	_stable = _stable + 1 if _aim() else 0
	if _fired < 2 and _stable >= 5 and now-_last_fire > 800:
		_button(MOUSE_BUTTON_LEFT, true); _fire_down = true
		_fired += 1; _last_fire = now; _stable = 0

func _observe(kind: String, delta: float) -> void:
	var c: Dictionary = _cases[kind]
	var life: RefCounted = c.life
	if not is_instance_valid(c.body) or not life._host.target_current(c.token) or life._disposed:
		_finish("selected_original_life_changed:"+kind); return
	var body: CharacterBody3D = c.body
	var position: Vector3 = body.global_position
	var displacement: float = position.distance_to(c.last_position)
	c.max_physics_displacement_m = maxf(c.max_physics_displacement_m, displacement)
	c.travel_m += _flat(position, c.last_position); c.last_position = position
	if displacement > maxf(.65, delta * 12.0): _finish("selected_body_discontinuity:"+kind); return
	if c.completed: return # Preserve the first complete service; later normal visits remain active.
	var row: Dictionary = life._life()
	if row.is_empty() or float(row.hp)<=0 or bool(row.get("dead",false)): _finish("selected_life_not_alive:"+kind); return
	var hp: float = float(row.hp)
	c.min_hp = minf(c.min_hp, hp)
	var route: RefCounted = life._dsh_simple if kind == "hospital" else life._economy28._route
	var frame: int = Engine.get_physics_frames()
	if route != null and not c.completed:
		if not route._venue.is_empty() and (route.get_instance_id() != c.route_id or route._venue != c.geometry.get("venue", "")):
			if c.money_receipts.is_empty() and c.heal_receipts.is_empty():
				c.service = {}; c.staff_serving = {}; c.service_frame = -100
				c.exterior_seen = false; c.entered = false; c.outbound = false
			c.route_id = route.get_instance_id()
			c.geometry_raw = {"door":route._door,"inward":route._inward,"outside":route._outside}
			c.geometry = {"venue":route._venue,"key":route._key,"door":_v(route._door),"inward":_v(route._inward),"outside":_v(route._outside)}
		if route._phase != c.route_phase:
			c.route_phase = route._phase
			c.route_events.append({"frame":frame,"ms":Time.get_ticks_msec(),"phase":route._phase,"position":_v(position),"venue":route._venue,"depth":route.depth_inside(),"reason":route.last_reason()})
			if c.route_events.size() > 128: c.route_events.pop_front()
		if route._phase == "INBOUND" and route.depth_inside() < -1.1: c.exterior_seen = true
		if c.exterior_seen and route._entered and route.depth_inside() > .55: c.entered = true
		if route._phase in ["OUTBOUND", "PORTAL_WAIT_OUT", "OUTSIDE"]: c.outbound = true
		if route._phase == "INSIDE" and route.is_inside():
			var entry: Dictionary = _registry.entry(route._venue)
			if entry.has("service_point29") and _registry.service_owner29(route._key, route._venue, route) and position.distance_to(entry.service_point29) <= .42:
				c.service_frame = frame
				if c.service.is_empty(): c.service = {"frame":frame,"position":_v(position),"service_point":_v(entry.service_point29),"distance_m":position.distance_to(entry.service_point29),"on_floor":body.is_on_floor(),"venue":route._venue,"key":route._key}
				if _staff._rows.has(route._venue):
					var actor: Node = _staff._rows[route._venue].actor
					if actor.serving29 and _registry.service_customer29(route._venue) == body and c.staff_serving.is_empty(): c.staff_serving = {"frame":frame,"venue":route._venue,"staff":actor.snapshot29(),"customer_body_id":body.get_instance_id()}
	if life._hospital_stage == "TREATING": c.treated = true
	var health_receipt: Dictionary = c.health.last_result
	if int(health_receipt.get("revision", -1)) > int(c.last_revision):
		c.last_revision = int(health_receipt.get("revision", -1))
		if health_receipt.get("applied", false):
			var compact: Dictionary = {"event_id":health_receipt.get("event_id"),"revision":health_receipt.get("revision"),"reason":health_receipt.get("reason"),"binding":health_receipt.get("binding",{}),"hit":health_receipt.get("hit",{}),"hospital":health_receipt.get("hospital",{}),"hp":hp,"frame":frame}
			if not compact.hit.is_empty(): c.health_receipts.append(compact)
			if not compact.hospital.is_empty(): c.heal_receipts.append(compact)
	if hp > float(c.last_hp) + .001 and kind == "hospital":
		if frame-int(c.service_frame)>1 or health_receipt.get("hospital",{}).is_empty(): _finish("heal_without_current_native_service"); return
		c["healed"] = is_equal_approx(hp, float(row.max_hp))
	c.last_hp = hp
	var account: Dictionary = life._account.snapshot()
	if not account.conserved: _finish("account_not_conserved:"+kind); return
	for receipt: Dictionary in account.account.receipts:
		if c.seen_receipts.has(str(receipt.id)): continue
		c.seen_receipts[str(receipt.id)] = true
		if receipt.kind == RECEIPTS.get(kind, ""):
			if frame-int(c.service_frame)>1: _finish("settlement_without_current_native_service:"+kind); return
			c.money_receipts.append(receipt.duplicate(true))
			c.energy_restored = float(life._energy) > 99.0
	if not c.completed and int(life._completed[kind]) > int(c.start_completed):
		if c.geometry_raw.is_empty(): _finish("completion_without_route_geometry:"+kind); return
		var depth: float = (position-c.geometry_raw.door).dot(c.geometry_raw.inward)
		var outside_distance: float = _flat(position, c.geometry_raw.outside)
		var selected_key: String = str(c.geometry.key)
		var released: bool = not _registry.ledger.requests.has(selected_key) and not _registry._service29.keys.has(selected_key)
		c.exit = {"frame":frame,"ms":Time.get_ticks_msec(),"position":_v(position),"depth":depth,"outside_distance_m":outside_distance,"on_floor":body.is_on_floor(),"selected_claim_released":released,"account":account,"energy":life._energy,"hp":hp}
		c.completed = c.entered and c.outbound and depth < -1.1 and outside_distance <= .42 and body.is_on_floor() and released
		if not c.completed: _finish("completion_without_physical_exit:"+kind); return
		print("SERVICES56_COMPLETED ", JSON.stringify({"kind":kind,"source_id":c.id,"elapsed_s":float(Time.get_ticks_msec()-_ready_ms)/1000.0,"travel_m":c.travel_m,"exit":c.exit}))

# Read-only bounded 1Hz diagnosis; never changes routes, doors or RNG.
func _route_debug(c: Dictionary, kind: String) -> Dictionary:
	if c.completed: return {}
	var visit: RefCounted = c.life._dsh_simple if kind == "hospital" else c.life._economy28._route
	if visit == null or visit._drive == null: return {}
	var drive: RefCounted = visit._drive
	var result: Dictionary = {"leg":visit._leg,"legs":visit._legs,"inner":visit._inner,"door_target":visit._door_owner.get("target") if is_instance_valid(visit._door_owner) else null,"drive_target":drive._target,"drive_phase":drive._phase,"attempts":drive._attempts,"way":drive._way,"reason":drive._last_reason,"avoidance":drive._avoidance29_state.duplicate(true),"service_watch":drive._service_watch30.duplicate(true)}
	if drive._route != null:
		result["route"] = drive._route.diagnostics()
		result["points"] = drive._route.route.duplicate()
	if drive._guide != null: result["guide"] = drive._guide.diagnostics()
	return result

func _sample(now: int) -> void:
	var started: int = Time.get_ticks_usec()
	var actual: Array[String] = _live_ids()
	if actual != _wanted or _pop.daily._lives.size() != _expected or _pop.hit_owners.size() != _expected or _staff_count() != 12:
		_finish("full_population_or_staff_changed"); return
	for id: String in _pop.daily._lives:
		var body: CharacterBody3D = _pop.daily._lives[id]._token.body
		if _positions.has(id):
			var moved: float = _flat(body.global_position, _positions[id])
			if moved < 10.0: _travel[id] = float(_travel.get(id,0.0)) + moved
		_positions[id] = body.global_position
	var selected: Dictionary = {}
	for kind: String in _cases:
		var c: Dictionary = _cases[kind]
		selected[kind] = {"source_id":c.id,"phase":c.life._phase,"hospital":c.life._hospital_stage,"economy":c.life._economy28._phase,"goal":c.life._goal.get("kind",""),"position":_v(c.body.global_position),"hp":c.last_hp,"energy":c.life._energy,"cash":c.life._account._account.cash,"route_phase":c.route_phase,"completed":c.completed,"travel_m":c.travel_m,"drive_debug":_route_debug(c,kind)}
	var sample: Dictionary = {"ms":now,"elapsed_s":float(now-_ready_ms)/1000.0,"original_count":actual.size(),"staff":_staff_count(),"phases":Counts.sample(_pop.daily),"selected":selected}
	_samples.append(sample)
	_max_sample_us = maxi(_max_sample_us, Time.get_ticks_usec()-started)
	if _samples.size()%5 == 0: print("SERVICES56_PROGRESS ", JSON.stringify(sample))

func _physics_process(delta: float) -> void:
	if _finished: return
	var started: int = Time.get_ticks_usec()
	var now: int = Time.get_ticks_msec()
	if _ready_ms == 0:
		if now-_start_ms > 120000: _finish("startup_timeout"); return
		_bind(); return
	if _fire_down: _button(MOUSE_BUTTON_LEFT, false); _fire_down = false
	if now-_ready_ms > _duration*1000: _finish("service_deadline_after_startup"); return
	if now >= _next_select and _cases.size() < 4:
		_next_select = now+250
		# Food cases first; their normal priority path starts before the gunshot.
		for kind: String in ["restaurant", "shop", "bank", "hospital"]:
			if not _cases.has(kind): _select(kind)
			if _finished: return
	_fire_step(now)
	if _finished: return
	for kind: String in _cases:
		_observe(kind, delta)
		if _finished: return
	if now >= _next_sample:
		_next_sample = now+1000; _sample(now)
		if _finished: return
	if _cases.size() == 4 and _cases.values().all(func(c: Dictionary) -> bool: return c.completed):
		_finish("complete"); return
	_max_observer_us = maxi(_max_observer_us, Time.get_ticks_usec()-started)

func _finish(reason: String) -> void:
	if _finished: return
	_finished = true; set_physics_process(false)
	if is_instance_valid(_weapons): _weapons.cancel_inputs()
	if reason != "complete": _failures.append(reason)
	var checks: Dictionary = {"four_unique_original_lives":_cases.size()==4,"composition_batch_and_12":_composition.get("original_count",0)==_expected and _composition.get("staff_count",0)==12,"two_actual_tt_shots":_shots.size()==2 and _fired==2,"native_two_owned_terminals":_terminals.filter(func(t: Dictionary) -> bool: return t.status=="hit" and t.owned and t.weapon=="tt_pistol").size()==2}
	var cases: Dictionary = {}
	for kind: String in _cases:
		var c: Dictionary = _cases[kind]
		checks[kind+"_actual_service_and_staff"] = not c.service.is_empty() and not c.staff_serving.is_empty()
		checks[kind+"_physical_entry_exit"] = c.completed and c.entered and c.outbound and c.travel_m > 1.0
		if kind == "hospital":
			checks["hospital_60_to_12_to_60"] = c.get("hp_after_tt",-1.0)==12.0 and c.get("healed",false) and c.exit.get("hp",0)==60.0
			checks["hospital_actual_treatment_receipt"] = c.treated and c.heal_receipts.size()==1 and float(c.heal_receipts[0].hospital.get("treatment_ms",0))>=1500.0
			var chain: bool = c.health_receipts.size()==2
			for receipt: Dictionary in c.health_receipts:
				var matched := false
				for terminal: Dictionary in _terminals:
					if terminal.owned and terminal.status=="hit" and str(receipt.event_id).ends_with(":"+str(terminal.shot_id)) and _shots.any(func(s: Dictionary) -> bool: return s.shot_id==terminal.shot_id): matched = true
				chain = chain and matched and receipt.hit.get("weapon_id")=="tt_pistol" and float(receipt.hit.get("damage",0))==24.0
			checks["shot_terminal_health_chain"] = chain
		else:
			var paid: bool = c.money_receipts.size()==1
			if paid:
				var receipt: Dictionary = c.money_receipts[0]
				paid = receipt.kind==RECEIPTS[kind] and bool(receipt.inside) and float(receipt.dwell_ms)>=2000.0 and int(receipt.life_generation)==int(c.token.life_generation)
				if kind == "bank": paid = paid and receipt.cash_before==0 and receipt.cash_after==1000 and receipt.own_bank_debit==false
				else: paid = paid and receipt.amount>=5 and receipt.amount<=50 and receipt.cash_before-receipt.cash_after==receipt.amount and bool(receipt.saved_purchase.restore_energy)
			checks[kind+"_authoritative_receipt"] = paid
			if kind in ["restaurant", "shop"]: checks[kind+"_energy_restored_after_purchase"] = c.energy_restored
		var exported: Dictionary = c.duplicate()
		for key: String in ["life","health","body","token","last_position","start_position","seen_receipts","geometry_raw"]: exported.erase(key)
		cases[kind] = exported
	for key: String in checks:
		if not checks[key]: _failures.append(key)
	var passed: bool = _failures.is_empty()
	var report: Dictionary = {"schema":"mafiozi.services_city56/v2","expected_residents":_expected,"passed":passed,"reason":reason,"failures":_failures,"checks":checks,"composition":_composition,"cases":cases,"qa_initializations":_initializations,"player_setup":_player_setup,"shots":_shots,"native_terminals":_terminals,"samples":_samples,"city_travel_m":_travel,"elapsed_after_startup_s":float(Time.get_ticks_msec()-_ready_ms)/1000.0 if _ready_ms>0 else 0.0,"startup_s":float(_ready_ms-_start_ms)/1000.0 if _ready_ms>0 else -1.0,"max_observer_us":_max_observer_us,"max_sample_us":_max_sample_us,"bank_semantics":"Existing local_bank_grant28, physical staff service; no own-bank debit/withdrawal claim","npc_relocations":0,"synthetic_damage":false,"observer_service_settlements":0,"route_or_rng_writes":0,"movement_disabled":false,"new_venues_created_by_observer":false,"performance_accepted":false,"visual_verified":false}
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
		var file := FileAccess.open(_out.path_join("SERVICES56.json"), FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"\t")); file.close()
	print("SERVICES56_RESULT ", JSON.stringify({"passed":passed,"reason":reason,"checks":checks,"failures":_failures}))
	get_tree().quit(0 if passed else 1)
