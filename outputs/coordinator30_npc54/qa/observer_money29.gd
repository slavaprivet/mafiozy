extends "observer28.gd"
const MoneyVisual = preload("res://scripts/shop/npc_money_popup28.gd")
var _money_rows: Array[Dictionary] = []
var _money_id := 0
var _money_started := 0
var _money_duplicate_ok := false
var _money_capture := false
var _money_done := false

func _process(delta: float) -> void:
	super._process(delta)
	if _money_id > 0 and is_instance_valid(_follow_body):
		_camera.global_position = _follow_body.global_position + Vector3(-1.3,1.8,2.2)
		_camera.look_at(_follow_body.global_position + Vector3.UP*1.55)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _money_done or not is_instance_valid(_follow_body): return
	var popup: Label3D = _follow_body.get_node_or_null("NpcMoneySpend28") as Label3D
	if popup == null:
		if _money_id > 0 and Time.get_ticks_msec() - _money_started > 2100: _finish_money()
		return
	if _money_id == 0:
		_money_id = popup.get_instance_id(); _money_started = Time.get_ticks_msec()
		var pop: RefCounted = get_tree().current_scene.get("preview_population")
		var life: RefCounted = pop.daily._lives["resident_1"]
		var receipt: Dictionary = life.get("_economy28").get("_receipt")
		MoneyVisual.show_debit(_follow_body, receipt); MoneyVisual.show_debit(_follow_body, receipt)
		_money_duplicate_ok = _follow_body.get_node("NpcMoneySpend28").get_instance_id() == _money_id
		_money_rows.append({"receipt":receipt.duplicate(true),"event":_follow_body.get_meta("npc_money28_last_event"),"text":popup.text})
	_money_rows.append({"ms":Time.get_ticks_msec()-_money_started,"height":popup.position.y,"red":popup.modulate.r,"green":popup.modulate.g,"alpha":popup.modulate.a})
	if not _money_capture and Time.get_ticks_msec()-_money_started > 350:
		_money_capture = true; _capture_money.call_deferred()

func _capture_money() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("spend_red.png"))

func _finish_money() -> void:
	_money_done = true
	var first: Dictionary = _money_rows[1]; var last: Dictionary = _money_rows[-1]
	var receipt: Dictionary = _money_rows[0].receipt
	var checks := {"actual_debit":receipt.inside and receipt.amount>=5 and receipt.amount<=50 and receipt.cash_before-receipt.cash_after==receipt.amount,
		"one_popup_per_receipt":_money_duplicate_ok,"red":first.red>first.green*2,
		"rises":last.height-first.height>.30,"fades":last.alpha<.1,"retired":_follow_body.get_node_or_null("NpcMoneySpend28")==null}
	var passed: bool = checks.values().all(func(value: Variant) -> bool:return value==true)
	var file := FileAccess.open(_out.path_join("MONEY29.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"rows":_money_rows,"npc_relocated":false,"synthetic_receipts":false},"\t"));file.close()
	print("MONEY29_FINISH ",JSON.stringify(checks)); get_tree().quit(0 if passed else 1)
