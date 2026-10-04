extends RefCounted
## Owns the NEW local-session account. It never edits a source packet or HP.
## No receipt/mirror callback can grant money. Bank credits come from this
## account's prior cash deposits; the initial personal bank balance is zero.
const MAX_MONEY := 2147483647
const SHOP := "REBUILD-VISUAL-print_shop-001"
const ITEM := "newspaper"
const PRICE := 3
const ORDINARY_ROLES := ["pensioner","housewife","student","businessman","worker","homeless"]
const BankSite = preload("npc_local_bank_site.gd")
var _host: RefCounted
var _health: RefCounted
var _token := {}
var _account := {}
var _order := {}
var _visit: WeakRef
var _bank_site: RefCounted
var _busy := false
var _disposed := false
var _last_now := -1.0
var _service_serial := 0
var _services := {}

static func source_initial_cash(id: String) -> int:
	var h := 2166136261
	var text := id+":wallet"
	for i in text.length():
		h = ((h ^ text.unicode_at(i)) * 16777619) & 0xffffffff
	return 35 + int(floor(float(h) / 4294967296.0 * 85.0))

static func ordinary_record_matches(record: Dictionary, token: Dictionary) -> bool:
	var row: Variant=record.get("row")
	if not row is Dictionary or not row.get("source_raw") is Dictionary or not row.get("bridge_row") is Dictionary: return false
	var raw: Dictionary=row.source_raw
	var bridge: Dictionary=row.bridge_row
	var id: String=str(token.get("source_id",""))
	return not id.is_empty() and row.get("source_id")==id and raw.get("id")==id and bridge.get("id")==token.get("bridge_id") and row.get("descriptor_sha256")==token.get("descriptor_sha256") and bridge.get("role") in ORDINARY_ROLES and raw.get("_arcKey")==bridge.get("role") and not raw.get("_empireBoss",false) and not bridge.get("police",false) and not bridge.get("empireBoss",false) and int(record.get("generation",-1))==int(token.get("life_generation",-2))

func configure(host: RefCounted, token: Dictionary, health_owner: RefCounted) -> Dictionary:
	if _host != null or _disposed or not is_instance_valid(host) or not host.target_current(token): return _fail("current_walker_required")
	if not is_instance_valid(health_owner) or health_owner.get("_host") != host or health_owner.get("_token") != token: return _fail("actual_health_owner_required")
	var record: Dictionary = host._records[token.source_id]
	if not ordinary_record_matches(record,token): return _fail("matching_original_ordinary_row_required")
	var claim: Variant = record.get("local_account_owner24")
	if claim is WeakRef and is_instance_valid(claim.get_ref()): return _fail("account_already_owned")
	_host = host; _health = health_owner; _token = token.duplicate()
	if not _life_current(): _host = null; return _fail("current_living_owner_required")
	# A replacement executor reuses the exact existing account. It cannot reset
	# spent cash by disposing/reconfiguring within the same source life.
	if record.has("local_account24"):
		_account = record.local_account24
		if _account.get("session_id") != token.session_id or _account.get("life_generation") != token.life_generation: return _fail("account_life_mismatch")
	else:
		if record.row.source_raw.has("_residentWallet"): return _fail("existing_wallet_import_required")
		var cash := source_initial_cash(token.source_id)
		_account = {"session_id":token.session_id,"source_id":token.source_id,"life_generation":token.life_generation,"cash":cash,"bank":0,"deposit_seen":false,"initial_total":cash,"spent":0,"inventory":{},"receipts":[],"sequence":0,"order_serial":0,"pending_purchase":{},"settled_visits":{}}
		record.local_account24 = _account
	record.local_account_owner24 = weakref(self)
	return {"ok":true,"scope":"new_local_session_account","server_authority":false,"cash":_account.cash,"bank":_account.bank}

func _life_current() -> bool:
	if _disposed or not Thread.is_main_thread() or not is_instance_valid(_host) or not _host.target_current(_token): return false
	if not is_instance_valid(_health) or _health.get("_host") != _host or _health.get("_token") != _token or _health.get("_ready") != true: return false
	var current: Dictionary = _health._current(_health._binding)
	if current.is_empty() or not is_same(current.get("row"),_health.get("_row")): return false
	var row: Dictionary = current.row
	return ordinary_record_matches(_host._records[_token.source_id],_token) and row.get("source_id") == _token.source_id and row.get("life_generation") == _token.life_generation and float(row.get("hp",0)) > 0 and not row.get("dead",false) and not row.get("_medicalDowned",false) and not row.get("_forcedCrawl",false)

func _current() -> bool:
	if not _life_current() or _account.is_empty(): return false
	var record: Dictionary = _host._records[_token.source_id]
	var claim: Variant = record.get("local_account_owner24")
	return claim is WeakRef and claim.get_ref() == self and is_same(record.get("local_account24"),_account) and conserved()

func _interrupted() -> bool:
	if not _current(): return true
	var row: Dictionary = _health._row
	for flag: String in ["_policeCuffed","_evacuated","_carriedByAmbulance","_hostile","_fighting","_fightingMelee","snitching"]:
		if row.get(flag,false): return true
	var now: float = _health._now()
	for timer: String in ["panicUntil","_knockedUntil","_meleeStunnedUntil","_npcSurrenderUntil","_npcHelpingUntil","_alertUntil"]:
		if float(row.get(timer,0)) > now: return true
	return float(row.get("_talking",0)) > now and not row.get("_civilianActivity",false)

func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
func conserved() -> bool:
	return not _account.is_empty() and _account.cash >= 0 and _account.bank >= 0 and _account.cash <= MAX_MONEY and _account.bank <= MAX_MONEY and _account.cash + _account.bank + _account.spent == _account.initial_total

## Called by the agenda before travelling. Insufficient cash retains this
## exact goal/item; a successful own-bank withdrawal resumes the same purchase.
func plan_purchase(goal_id: String, now_ms: float) -> Dictionary:
	if _busy or not _current() or goal_id.is_empty() or not is_finite(now_ms) or now_ms < _last_now: return _fail("purchase_lifetime_or_clock")
	_last_now = now_ms
	if now_ms < float(_account.inventory.get(ITEM,{}).get("next_need_at",0)): return _fail("source_need_cooldown")
	if _account.pending_purchase.is_empty():
		_account.pending_purchase = {"goal_id":goal_id,"building_id":SHOP,"item":ITEM,"price":PRICE}
	elif _account.pending_purchase.goal_id != goal_id: return _fail("pending_purchase_owned")
	if _account.cash < PRICE:
		return {"ok":true,"kind":"bank","operation":"withdraw","amount":PRICE-_account.cash,"funded":_account.bank >= PRICE-_account.cash,"reason":"own_bank_empty" if _account.bank < PRICE-_account.cash else "cash_insufficient","resume":_account.pending_purchase.duplicate(true)}
	return {"ok":true,"kind":"shop","purchase":_account.pending_purchase.duplicate(true)}

func _physical_shop(visit: RefCounted, tolerance: float) -> bool:
	if not _current() or not is_instance_valid(visit) or visit.get("_host") != _host or visit.get("_token") != _token or visit.get("_phase") != "BROWSING" or not visit._current(): return false
	var body: CharacterBody3D = _token.body
	var route: RefCounted = visit._route_owner.get_ref()
	if not is_instance_valid(route) or not route._current() or route.interior != visit._interior.get_ref(): return false
	if route.interior.SOURCE_ID != SHOP or route.interior.door_fraction("public") != 1.0 or not body.is_on_floor(): return false
	if Vector2(body.global_position.x-visit._inside.x,body.global_position.z-visit._inside.z).length() > tolerance: return false
	# Reuse the exact certified floor/source-square/current-obstacle seam; a
	# BROWSING string or forged arrival callback alone cannot authorize checkout.
	route._floors.clear()
	return route._source_segment(body.global_position,body.global_position) and route._capsule_clear(body.global_position) and route._native_square_clear(body.global_position,body.global_position)

func arrive_shop(visit: RefCounted, now_ms: float) -> Dictionary:
	if _busy or _interrupted() or not is_finite(now_ms) or now_ms < _last_now or not _physical_shop(visit,.04*4.1): return _fail("physical_shop_arrival_required")
	if not _order.is_empty() and not _order.get("settled",false): return _fail("checkout_owned")
	var visit_key := str(visit.get_instance_id())+":"+str(visit._since)
	if _account.settled_visits.has(visit_key): return _fail("visit_already_settled")
	if _account.pending_purchase.is_empty():
		var planned := plan_purchase("shop:"+str(_account.order_serial+1),now_ms)
		if not planned.get("ok",false): return planned
	if _account.cash < PRICE: return _fail("cash_insufficient_bank_required")
	if now_ms < float(_account.inventory.get(ITEM,{}).get("next_need_at",0)): return _fail("source_need_cooldown")
	_last_now = now_ms; _account.order_serial += 1; _visit = weakref(visit)
	_order = {"id":_token.source_id+":"+str(_account.order_serial),"visit_key":visit_key,"goal_id":_account.pending_purchase.goal_id,"phase":"browse","since":now_ms,"pay_at":now_ms+1800.0,"complete_at":now_ms+3100.0,"settled":false}
	visit._until = maxf(visit._until,now_ms+3700.0)
	return {"ok":true,"order":_order.duplicate(true)}

func tick_shop(visit: RefCounted, now_ms: float) -> Dictionary:
	if _busy or _order.is_empty() or _visit == null or _visit.get_ref() != visit: return _fail("checkout_not_owned")
	if _order.settled: return {"ok":true,"phase":_order.phase,"duplicate":true}
	if not is_finite(now_ms) or now_ms < _last_now: return _fail("clock")
	var elapsed := now_ms-_last_now
	_last_now = now_ms
	if _interrupted() or not _physical_shop(visit,.08*4.1): return cancel_shop(visit,"source_interruption_or_arrival_lost")
	if _health.should_pause_walk():
		_order.since += elapsed; _order.pay_at += elapsed; _order.complete_at += elapsed
		return {"ok":true,"phase":_order.phase,"paused":true}
	_order.phase = "browse" if now_ms < _order.pay_at else "pay"
	if now_ms < _order.complete_at: return {"ok":true,"phase":_order.phase}
	# No external callbacks, awaits or resource loads between final proof and
	# debit/inventory/journal writes. Source account is the sole money owner.
	_busy = true
	if _account.cash < PRICE:
		_order.settled = true; _order.phase = "declined"; _account.settled_visits[_order.visit_key] = true; _busy = false
		return _fail("cash_insufficient_bank_required")
	_account.cash -= PRICE; _account.spent += PRICE
	var old: Dictionary = _account.inventory.get(ITEM,{})
	_account.inventory[ITEM] = {"quantity":int(old.get("quantity",0))+1,"next_need_at":now_ms+300000.0}
	_order.settled = true; _order.phase = "complete"; _account.settled_visits[_order.visit_key] = true
	var receipt := _commit_receipt("purchase",PRICE,now_ms,{"order_id":_order.id,"goal_id":_order.goal_id,"building_id":SHOP,"item":ITEM})
	_account.pending_purchase = {}; _busy = false
	return {"ok":true,"phase":"complete","receipt":receipt}

func cancel_shop(visit: RefCounted, reason: String) -> Dictionary:
	if _busy or _order.is_empty() or _visit == null or _visit.get_ref() != visit: return _fail("checkout_not_owned")
	if not _order.settled:
		_order.settled = true; _order.phase = "cancelled"; _order.reason = reason; _account.settled_visits[_order.visit_key] = true
	return {"ok":true,"phase":_order.phase}

## Bind concrete current scene bodies, not a caller's verified/arrival boolean.
func bind_bank(scene: Node3D) -> Dictionary:
	if _busy or not _current() or _bank_site != null: return _fail("bank_lifetime")
	var site := BankSite.new()
	var result: Dictionary = site.configure(scene,_host,_token)
	if result.get("ok",false): _bank_site = site
	return result

func bank_transfer(operation: String, amount: int, now_ms: float) -> Dictionary:
	if _busy or _interrupted() or operation not in ["deposit","withdraw"] or amount <= 0 or not is_finite(now_ms) or now_ms < _last_now: return _fail("bank_request")
	if not is_instance_valid(_bank_site): return _fail("original_bank_native_site_missing")
	var evidence: Dictionary = _bank_site.current_arrival()
	if not evidence.get("ok",false): return evidence
	if not _current(): return _fail("actor_life_changed")
	if operation == "withdraw" and (amount > _account.bank or amount > MAX_MONEY-_account.cash): return _fail("own_bank_insufficient")
	if operation == "deposit" and (amount > _account.cash or amount > MAX_MONEY-_account.bank): return _fail("cash_insufficient")
	_busy = true; _last_now = now_ms
	if operation == "withdraw": _account.bank -= amount; _account.cash += amount
	else: _account.cash -= amount; _account.bank += amount; _account.deposit_seen = true
	var receipt := _commit_receipt(operation,amount,now_ms,{"building_id":BankSite.BUILDING,"position":evidence.position})
	var resume: Dictionary = _account.pending_purchase.duplicate(true) if not _account.pending_purchase.is_empty() and _account.cash >= PRICE else {}
	_busy = false
	return {"ok":true,"receipt":receipt,"resume_purchase":resume}

func _commit_receipt(kind: String, amount: int, now: float, extra: Dictionary) -> Dictionary:
	_account.sequence += 1
	var receipt := {"id":_token.session_id+":"+_token.source_id+":"+str(_account.sequence),"sequence":_account.sequence,"kind":kind,"amount":amount,"at":now,"cash_after":_account.cash,"bank_after":_account.bank,"scope":"new_local_session_account"}
	receipt.merge(extra); _account.receipts.append(receipt)
	if _account.receipts.size() > 8: _account.receipts.pop_front()
	return receipt.duplicate(true)

## The agenda owns travel. For shop, pass the genuine configured visit object;
## for bank, pass null only AFTER walking to the original bank service zone.
func begin_service(goal: Dictionary, visit: RefCounted, now_ms: float) -> Dictionary:
	if not _current() or _busy or not goal.get("goal_id") is String or str(goal.goal_id).is_empty(): return _fail("service_goal")
	for existing: Dictionary in _services.values():
		# A cancelled checkout has made no purchase. Preserve the pending goal
		# and permit a new physical visit; settled success remains idempotent.
		if existing.goal_id == goal.goal_id and existing.status != "CANCELLED": return {"ok":true,"service_id":existing.id,"status":existing.status,"duplicate":true}
	if _services.size() >= 256: return _fail("bounded_service_journal_full")
	var result: Dictionary
	if goal.get("kind") == "shop":
		result = plan_purchase(goal.goal_id,now_ms)
		if not result.get("ok",false) or result.get("kind") != "shop": return result
		result = arrive_shop(visit,now_ms)
	elif goal.get("kind") == "bank": result = bank_transfer(str(goal.get("operation","")),int(goal.get("amount",0)),now_ms)
	else: return _fail("unknown_service")
	if not result.get("ok",false): return result
	_service_serial += 1
	var record := {"id":_service_serial,"goal_id":goal.goal_id,"kind":goal.kind,"visit":weakref(visit) if is_instance_valid(visit) else null,"status":"PENDING" if goal.kind == "shop" else "COMPLETE","result":result}
	_services[_service_serial] = record
	return {"ok":true,"service_id":_service_serial,"status":record.status,"result":result.duplicate(true)}

func poll_service(service_id: int, now_ms: float) -> Dictionary:
	if not _services.has(service_id): return _fail("unknown_service")
	var record: Dictionary = _services[service_id]
	if record.status == "PENDING":
		var visit: RefCounted = record.visit.get_ref()
		var result := tick_shop(visit,now_ms)
		record.result = result
		if result.get("phase") == "complete": record.status = "COMPLETE"
		elif not result.get("ok",false) or result.get("phase") in ["cancelled","declined"]: record.status = "CANCELLED"
	return {"ok":true,"service_id":service_id,"goal_id":record.goal_id,"status":record.status,"result":record.result.duplicate(true)}

func cancel_service(service_id: int) -> Dictionary:
	if not _services.has(service_id): return _fail("unknown_service")
	var record: Dictionary = _services[service_id]
	if record.status == "PENDING":
		cancel_shop(record.visit.get_ref(),"agenda_cancelled"); record.status = "CANCELLED"
	return {"ok":true,"service_id":service_id,"status":record.status,"refund":false}

func snapshot() -> Dictionary:
	return {"scope":"new_local_session_account","server_authority":false,"account":_account.duplicate(true),"order":_order.duplicate(true),"conserved":conserved(),"bank_bound":is_instance_valid(_bank_site)}

func dispose() -> void:
	if _busy: return
	_disposed = true
	if is_instance_valid(_host) and _host._records.has(_token.get("source_id")):
		var record: Dictionary = _host._records[_token.source_id]
		var claim: Variant = record.get("local_account_owner24")
		if claim is WeakRef and claim.get_ref() == self: record.erase("local_account_owner24")
	# The account stays with this source life. Disposal never refunds/reseeds it.
	if _bank_site!=null: _bank_site.dispose()
	_bank_site = null; _visit = null; _host = null; _health = null
