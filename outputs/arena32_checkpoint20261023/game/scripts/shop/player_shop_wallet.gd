extends RefCounted
## Local player wallet for the preview session. The wallet is the single money
## owner of the shop: a purchase debits it first, and a refused grant must pay the
## exact same amount back. Nothing else in the shop writes cash.
const MAX_MONEY := 100000000
var _ready := false
var _cash := 0
var _spent := 0
var _earned := 0
var _last_spend := 0
var _spends := 0

func configure(starting_cash: Variant) -> Dictionary:
	if _ready:
		return {"ok": false, "reason": "already_configured"}
	if not (starting_cash is int or starting_cash is float):
		return {"ok": false, "reason": "cash_type"}
	var value := float(starting_cash)
	if not is_finite(value) or value < 0.0 or value > float(MAX_MONEY):
		return {"ok": false, "reason": "cash_range"}
	_cash = int(floor(value))
	_ready = true
	return {"ok": true, "cash": _cash, "scope": "local_preview_wallet"}

func ready() -> bool:
	return _ready

func cash() -> int:
	return _cash

func spend(amount: Variant) -> Dictionary:
	if not _ready:
		return {"ok": false, "reason": "lifetime", "cash": _cash}
	if not (amount is int or amount is float):
		return {"ok": false, "reason": "amount_type", "cash": _cash}
	var price := int(floor(float(amount)))
	if price <= 0 or price > MAX_MONEY:
		return {"ok": false, "reason": "amount_range", "cash": _cash}
	if price > _cash:
		return {"ok": false, "reason": "cash_insufficient", "cash": _cash, "needed": price}
	_cash -= price
	_spent += price
	_last_spend = price
	_spends += 1
	return {"ok": true, "cash": _cash, "spent": price}

func grant(amount: Variant) -> Dictionary:
	if not _ready:
		return {"ok": false, "reason": "lifetime", "cash": _cash}
	if not (amount is int or amount is float):
		return {"ok": false, "reason": "amount_type", "cash": _cash}
	var value := int(floor(float(amount)))
	if value <= 0 or value > MAX_MONEY or _cash + value > MAX_MONEY:
		return {"ok": false, "reason": "amount_range", "cash": _cash}
	_cash += value
	_earned += value
	return {"ok": true, "cash": _cash, "granted": value}

func snapshot() -> Dictionary:
	return {
		"ready": _ready,
		"cash": _cash,
		"spent_total": _spent,
		"earned_total": _earned,
		"last_spend": _last_spend,
		"spends": _spends,
		"scope": "local_preview_wallet"
	}
