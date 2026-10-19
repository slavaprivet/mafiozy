extends RefCounted
## One local user's shop/bank cycle. Route proves real entry/exit; Account owns money.
## No source-save write, teleports, fallback arrival, or separate display wallet.
const Route = preload("res://scripts/hospital/npc_restaurant_visit28.gd")
const MoneyPopup = preload("npc_money_popup28.gd")
const DWELL_MS := 2000.0
const RETRY_MS := 8000.0
var _life: WeakRef
var _host: RefCounted
var _account: RefCounted
var _token: Dictionary = {}
var _scene: Node3D
var _map := RID()
var _route: RefCounted
var _kind := ""
var _phase := "IDLE"
var _serial := 0
var _committed := false
var _interrupted := ""
var _dwell_started := -1.0
var _dwell_last := -1.0
var _dwell_anchor := Vector3.INF
var _dwell_hp := -1.0
var _dwell_revision := -1
var _exit_retry_at := 0.0
var _retry_at := 0.0
var _now := 0.0
var _roams := 0
var _rng := RandomNumberGenerator.new()
var _pending: Dictionary = {}
var _last_roam_goal := ""
var _planned_amount := 0
var _receipt: Dictionary = {}
var _completion: Dictionary = {}
var _reason := ""
var _routine_failures58 := 0
var _routine_defer_until58 := 0.0

func configure(life: RefCounted, account: RefCounted, scene: Node3D, map: RID) -> Dictionary:
	if _life != null or not is_instance_valid(life) or not is_instance_valid(account) or not is_instance_valid(scene): return {"ok":false,"reason":"economy_configuration"}
	_life = weakref(life); _account = account; _host = life.get("_host"); _token = life.get("_token").duplicate()
	_scene = scene; _map = map
	var result: Dictionary = account.configure_test_economy28(life)
	if not result.get("ok", false): _reason = str(result.get("reason", "account_policy_refused")); return result
	_rng.randomize()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--city-sandbox-seed="):
			var value: String = argument.trim_prefix("--city-sandbox-seed=")
			if value.is_valid_int(): _rng.seed = int(value) + int(_token.get("life_generation", 0))
	_log("configured", "random_sandbox;cash_cap=1000")
	return {"ok":true,"authority":"local_account24_user_test_policy"}

func _agenda() -> RefCounted:
	return _life.get_ref() if _life != null and is_instance_valid(_life.get_ref()) else null

func random_unit() -> float:
	return _rng.randf()

func current() -> bool:
	var life: RefCounted = _agenda()
	return is_instance_valid(life) and not life.get("_disposed") and is_instance_valid(_host) and _host.target_current(_token) and life.get("_account") == _account and life.get("_token") == _token

## Called only by the physical roam owner's arrived branch, never on begin/blocked.
func note_roam_arrived(goal_id: String) -> String:
	if not current() or goal_id.is_empty() or goal_id == _last_roam_goal: return ""
	_last_roam_goal = goal_id; _roams += 1
	var roll: int = _rng.randi_range(0, 99)
	var action: String = "shop" if roll < 20 else ("ambient" if roll < 55 else "walk")
	if action == "shop" and _pending.is_empty(): _choose_purchase("shop", false)
	_log("roam_arrived", "count=" + str(_roams) + ";roll=" + str(roll) + ";action=" + action)
	return action

func _choose_purchase(kind: String, energy: bool) -> void:
	_pending = {"kind":kind,"price":_rng.randi_range(5, 50),"restore_energy":energy}
	_routine_failures58=0; _routine_defer_until58=0.0
	_log("purchase_chosen", JSON.stringify(_pending))

## Routine chooses only a purpose; this owner still chooses/stores the price,
## obtains the actual venue, and retains the same purchase through a bank detour.
func request_routine58(kind: String, ticket: String) -> bool:
	if not current() or active() or ticket.is_empty() or kind not in ["shop", "restaurant"]: return false
	if not _pending.is_empty(): return _pending.get("routine_ticket58", "") == ticket
	_choose_purchase(kind, kind == "restaurant")
	_pending["routine_ticket58"] = ticket
	return true

func request_food() -> void:
	if not current(): return
	# Actual urgent energy need outranks discretionary overnight/defer policy.
	_routine_failures58=0; _routine_defer_until58=0.0
	if _pending.is_empty(): _choose_purchase("restaurant" if _rng.randi_range(0, 1) == 0 else "shop", true)
	else: _pending.restore_energy = true

func required_cash() -> int:
	return int(_pending.get("price", 1))

func has_pending_need() -> bool:
	if not current(): return false
	return not _pending.is_empty() or int(_account.snapshot().account.get("cash", 0)) == 0

func desired_kind(now_ms: float) -> String:
	if not current() or active() or now_ms < _retry_at or routine_deferred58(now_ms): return ""
	var state: Dictionary = _account.snapshot()
	if not state.get("conserved", false): return ""
	var wallet: Dictionary = state.get("account", {})
	var cash: int = int(wallet.get("cash", -1))
	if cash == 0 or (not _pending.is_empty() and cash < required_cash()): return "bank"
	return str(_pending.get("kind", ""))

## A discretionary purchase may be retried after ordinary activities; hunger/bank cannot.
func optional_purchase56() -> bool:
	return _pending.get("kind") == "shop" and not bool(_pending.get("restore_energy", false)) and int(_account._account.get("cash", 0)) >= required_cash()

func optional_retry56(now_ms: float) -> bool:
	return not active() and now_ms < _retry_at and optional_purchase56()

func active() -> bool:
	return _phase in ["WAITING", "INBOUND", "DWELL", "OUTBOUND", "EXIT_RETRY"]

func begin(kind: String, now_ms: float) -> bool:
	if not current() or active() or kind not in ["shop", "restaurant", "bank"] or kind != desired_kind(now_ms): return false
	_now = now_ms; _kind = kind; _receipt = {}; _completion = {}; _committed = false; _interrupted = ""
	_dwell_started = -1.0; _dwell_last = -1.0
	_route = Route.new()
	var body: CharacterBody3D = _token.get("body")
	var sign: String = "МАГАЗИН" if kind == "shop" else ("РЕСТОРАН" if kind == "restaurant" else "БАНК")
	if not _route.begin(_scene, body, _map, str(_token.source_id), sign):
		_reason = _route.last_reason(); _route.cancel(); _route = null
		_phase = "IDLE"; _retry_at = now_ms + RETRY_MS; _routine_failure58(now_ms); _log("blocked", _reason); return false
	_phase = "WAITING" if _route.snapshot().phase == "WAITING" else "INBOUND"
	if _phase == "WAITING" and optional_purchase56():
		# No entry/money has occurred. Keep this exact purchase, release the capacity
		# request and browse the city until a staggered retry instead of standing 120s.
		_route.cancel(); _route = null; _phase = "IDLE"
		_reason = "optional_capacity_deferred"; _retry_at = now_ms + RETRY_MS + _rng.randf_range(0.0, 4000.0)
		_routine_failure58(now_ms)
		_log("deferred", _reason); return false
	var reserved: Dictionary = _account.begin_economy28(self, kind, now_ms)
	if not reserved.get("ok", false):
		_reason = str(reserved.get("reason", "account_reservation_refused"))
		_route.cancel(); _route = null; _phase = "IDLE"; _retry_at = now_ms + RETRY_MS
		_routine_failure58(now_ms)
		_log("blocked", _reason); return false
	_serial = int(reserved.serial)
	_planned_amount = required_cash() if kind != "bank" else 0
	_reason = ""; _log("started", "signed_clone;planned=" + str(_planned_amount))
	return true

func current_inside() -> bool:
	return current() and _route != null and _phase == "DWELL" and _route.is_inside()

func request_priority(reason: String) -> void:
	if not active(): return
	_interrupted = reason; _dwell_started = -1.0

func _request_exit(reason: String) -> void:
	_dwell_started = -1.0
	if _route.begin_exit(): _phase = "OUTBOUND"; _log("leaving", reason)
	else: _phase = "EXIT_RETRY"; _exit_retry_at = _now + 1500.0; _log("exit_blocked", reason)

func step(delta: float, now_ms: float, row: Dictionary) -> String:
	_now = now_ms
	if not current(): cancel("current_life_lost"); return "done"
	if not active() or _route == null: return "done"
	var life: RefCounted = _agenda()
	if life._hospital51_below_threshold(row): request_priority("hospital")
	elif life.dsh_energy_on() and life.dsh_energy() < 20.0: request_food()
	if not _interrupted.is_empty() and _phase not in ["OUTBOUND", "EXIT_RETRY"]:
		if _route.needs_exit(): _request_exit(_interrupted + "_priority")
		else: _finish(false, _interrupted + "_before_entry")
		return "active" if active() else "done"
	if _phase == "EXIT_RETRY":
		_route.stand(delta)
		if _now >= _exit_retry_at: _request_exit("retry")
		return "active"
	if _phase == "DWELL":
		_route.stand(delta)
		if not current_inside(): _request_exit("live_interior_lost"); return "active"
		var health: RefCounted = life.get("_health")
		var adapter: Variant = health.get("_adapter")
		if not is_instance_valid(adapter) or not adapter._fresh(): _request_exit("health_owner_changed"); return "active"
		var body: CharacterBody3D = _token.body
		_route.publish_service_dwell29(_kind)
		var revision: int = int(adapter._revision)
		var moved: bool = _dwell_anchor.is_finite() and body.global_position.distance_to(_dwell_anchor) > .05
		if _dwell_started < 0.0 or _now - _dwell_last > 250.0 or moved or revision != _dwell_revision or float(row.hp) != _dwell_hp:
			_dwell_started = _now; _dwell_anchor = body.global_position; _dwell_hp = float(row.hp); _dwell_revision = revision
		_dwell_last = _now
		if _now - _dwell_started < DWELL_MS: return "active"
		var settled: Dictionary = _account.settle_economy28(self, _kind, _planned_amount, _now)
		if not settled.get("ok", false): _request_exit("settlement_refused:" + str(settled.get("reason", "unknown"))); return "active"
		_committed = true; _receipt = settled.receipt.duplicate(true)
		if _kind != "bank":
			_receipt["routine_ticket58"] = str(_pending.get("routine_ticket58", ""))
			if bool(_pending.get("restore_energy", false)) or _kind == "restaurant":
				var energy_result: Dictionary = life._economy28_restore_energy(self, _receipt)
				_receipt.merge(energy_result)
			life._routine58_paid(self, _receipt)
			_pending.clear()
			MoneyPopup.show_debit(_token.body, _receipt)
		_log("paid" if _kind != "bank" else "funded", "inside_still_2000ms")
		_request_exit("transaction_committed")
		return "active"
	var result: String = _route.step(delta)
	if result == "waiting": _phase = "WAITING"
	elif result == "walking" and _phase == "WAITING": _phase = "INBOUND"
	if result == "entered": _phase = "DWELL"; _dwell_started = -1.0; _log("entered", "live_floor_and_door_plane")
	elif result == "exited": _finish(_committed, "physical_exit")
	elif result == "blocked":
		if _phase == "OUTBOUND": _phase = "EXIT_RETRY"; _exit_retry_at = _now + 1500.0; _log("exit_blocked", _route.last_reason())
		elif _route.needs_exit(): _request_exit("inbound_blocked_inside")
		else: _finish(false, _route.last_reason())
	return "active" if active() else "done"

func pause() -> void:
	# Do not accumulate a dwell while an existing combat/health owner holds the body.
	_dwell_started = -1.0

func _finish(completed: bool, reason: String) -> void:
	if completed and (not _committed or not _route.is_outside()): completed = false
	_completion = {"kind":_kind,"completed":completed,"committed":_committed,"reason":reason,"priority":_interrupted,"receipt":_receipt.duplicate(true)}
	_log("complete" if completed else "interrupted", reason)
	_route.cancel(); _route = null; _account.release_economy28(self)
	_phase = "IDLE"; _dwell_started = -1.0
	_retry_at = _now + 1000.0 if completed or not _interrupted.is_empty() else _now + RETRY_MS
	if not completed and _interrupted.is_empty(): _routine_failure58(_now)

func take_completion() -> Dictionary:
	var result: Dictionary = _completion
	_completion = {}
	return result

func cancel(reason: String) -> void:
	if _route != null: _route.cancel(); _route = null
	if is_instance_valid(_account): _account.release_economy28(self)
	_phase = "IDLE"; _dwell_started = -1.0; _reason = reason
	_pending.clear(); _completion.clear(); _receipt.clear(); _last_roam_goal = ""
	if is_instance_valid(_token.get("body")): MoneyPopup.clear(_token.body)

func _log(stage: String, reason: String) -> void:
	var wallet: Dictionary = _account.snapshot().get("account", {}) if is_instance_valid(_account) else {}
	print("NPC_ECONOMY28 id=", str(_token.get("source_id", "")), " kind=", _kind, " stage=", stage,
		" cash=", wallet.get("cash", -1), " serial=", _serial, " reason=", reason, " frame=", Engine.get_physics_frames())

func snapshot() -> Dictionary:
	return {"kind":_kind,"phase":_phase,"serial":_serial,"committed":_committed,"priority":_interrupted,"roams":_roams,"pending":_pending.duplicate(true),"routine_failures58":_routine_failures58,"routine_defer_until58":_routine_defer_until58,"planned_amount":_planned_amount,"receipt":_receipt.duplicate(true),"retry_at":_retry_at,"reason":_reason,"route":_route.snapshot() if _route != null else {}}

func has_routine_pending58() -> bool:
	return current() and not str(_pending.get("routine_ticket58", "")).is_empty()

func routine_deferred58(now_ms: float) -> bool:
	return not active() and has_routine_pending58() and now_ms < _routine_defer_until58

func _routine_failure58(now_ms: float) -> void:
	if not has_routine_pending58() or _committed: return
	_routine_failures58 += 1
	if _routine_failures58 < 3: return
	_routine_failures58 = 0
	_routine_defer_until58 = now_ms + 45000.0
	_log("routine_deferred58", "three_failed_venue_attempts;ticket_and_price_retained;until=" + str(_routine_defer_until58))
