extends RefCounted
## Purchase transaction of the local shop, for every kind of good.
## Order is deliberate: validate the item is available -> debit the wallet -> ask
## the owner (arsenal for guns, backpack for armor and consumables) to accept it ->
## keep the receipt. A refused delivery pays the exact price back, so a failed
## purchase can never keep money, and a repeated purchase id is answered from the
## receipt instead of charging twice. Availability policy itself (owned already,
## carry limit reached) belongs to the owner, not to this module.
const MAX_RECEIPTS := 256
var _ready := false
var _error := ""
var _catalog: RefCounted
var _wallet: RefCounted
var _available: Callable
var _deliver: Callable
var _receipts: Dictionary = {}
var _order: Array = []
var _serial := 0
var _purchases := 0
var _refusals := 0
var _replays := 0

func configure(catalog: RefCounted, wallet: RefCounted, available: Callable, deliver: Callable) -> Dictionary:
	if _ready:
		return {"ok": false, "reason": "already_configured"}
	if catalog == null or wallet == null or not catalog.ready() or not wallet.ready():
		return _fail("binding")
	if not available.is_valid() or available.get_argument_count() != 1:
		return _fail("available_signature")
	if not deliver.is_valid() or deliver.get_argument_count() != 2:
		return _fail("deliver_signature")
	_catalog = catalog
	_wallet = wallet
	_available = available
	_deliver = deliver
	_ready = true
	return {"ok": true, "scope": "local_preview_purchase", "items": _catalog.item_count()}

func ready() -> bool:
	return _ready

func error() -> String:
	return _error

func purchase(item_id: String, purchase_id: String = "") -> Dictionary:
	if not _ready:
		return {"ok": false, "reason": "lifetime", "cash": 0}
	if not _catalog.has(item_id):
		return _refuse("unknown_item")
	var ticket := purchase_id.strip_edges()
	if ticket.is_empty():
		ticket = _new_purchase_id(item_id)
	if _receipts.has(ticket):
		_replays += 1
		return {"ok": true, "replayed": true, "receipt": (_receipts[ticket] as Dictionary).duplicate(true), "cash": _wallet.cash()}
	var allowed: Dictionary = _available.call(item_id)
	if not bool(allowed.get("ok", false)):
		return _refuse(str(allowed.get("reason", "unavailable")))
	var price: int = _catalog.price(item_id)
	var debit: Dictionary = _wallet.spend(price)
	if not debit.get("ok", false):
		_refusals += 1
		return {"ok": false, "reason": str(debit.get("reason", "cash")), "cash": _wallet.cash(), "price": price}
	var accepted: Dictionary = _deliver.call(item_id, _new_item_uid(item_id))
	if not accepted.get("ok", false):
		var refund: Dictionary = _wallet.grant(price)
		_refusals += 1
		return {
			"ok": false,
			"reason": "delivery_refused:" + str(accepted.get("reason", "unknown")),
			"cash": _wallet.cash(),
			"price": price,
			"refunded": bool(refund.get("ok", false))
		}
	var receipt := {
		"purchase_id": ticket,
		"item_id": item_id,
		"kind": _catalog.kind(item_id),
		"price": price,
		"cash_after": _wallet.cash(),
		"frame": Engine.get_physics_frames(),
		"session": get_instance_id()
	}
	_store(ticket, receipt)
	_purchases += 1
	return {"ok": true, "replayed": false, "receipt": receipt.duplicate(true), "cash": _wallet.cash()}

func snapshot() -> Dictionary:
	return {
		"ready": _ready,
		"error": _error,
		"purchases": _purchases,
		"refusals": _refusals,
		"replays": _replays,
		"receipts": _receipts.size(),
		"wallet": _wallet.snapshot() if _wallet != null else {},
		"catalog": _catalog.snapshot() if _catalog != null else {}
	}

func _store(ticket: String, receipt: Dictionary) -> void:
	_receipts[ticket] = receipt.duplicate(true)
	_order.append(ticket)
	while _order.size() > MAX_RECEIPTS:
		var oldest: String = str(_order.pop_front())
		_receipts.erase(oldest)

func _refuse(reason: String) -> Dictionary:
	_refusals += 1
	return {"ok": false, "reason": reason, "cash": _wallet.cash()}

func _fail(reason: String) -> Dictionary:
	_error = reason
	_ready = false
	return {"ok": false, "reason": reason}

func _new_purchase_id(item_id: String) -> String:
	_serial += 1
	return "shop-purchase-%d-%s-%d" % [get_instance_id(), item_id, _serial]

func _new_item_uid(item_id: String) -> String:
	_serial += 1
	return "shop-item-%d-%s-%d" % [get_instance_id(), item_id, _serial]
